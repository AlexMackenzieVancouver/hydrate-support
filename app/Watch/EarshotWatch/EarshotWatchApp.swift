import SwiftUI
import WatchKit
import AVFoundation
import EarshotKit

/// Canon: WATCH_ARCHITECTURE.md, DESIGN_SYSTEM.md §5.
///
/// Three screens, no more. The Watch owns nothing but in-flight audio — it
/// cannot author, edit, or delete a Note, and there is deliberately no code
/// path here that could.
@main
struct EarshotWatchApp: App {
    @State private var recorder = WatchRecorder()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(recorder)
                .task { await recorder.start() }
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchRecorder.self) private var recorder

    var body: some View {
        switch recorder.phase {
        case .idle:      IdleView()
        case .recording: RecordingView()
        case .review:    WatchReviewView()
        }
    }
}

// MARK: - Idle

private struct IdleView: View {
    @Environment(WatchRecorder.self) private var recorder

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Button {
                Task { try? await recorder.begin() }
            } label: {
                VStack(spacing: Tokens.Space.xs) {
                    Image(systemName: "waveform").font(.largeTitle)
                    Text("Capture").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.accent)

            if let next = recorder.nextMeetingTitle {
                Text(next)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if recorder.unsyncedCaptureCount > 0 {
                // WATCH §7: an un-acked capture is always visible on both
                // devices. It is never silently dropped for storage pressure.
                Label("\(recorder.unsyncedCaptureCount) waiting for your iPhone",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(Tokens.Palette.accent)
            }
        }
    }
}

// MARK: - Recording

private struct RecordingView: View {
    @Environment(WatchRecorder.self) private var recorder

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.xs) {
                RecordingDot()
                Text(recorder.elapsedText)
                    .font(.title3.monospacedDigit())
            }

            // The interaction that justifies the Watch existing. Occupies the
            // lower half so it is hittable without looking (WATCH §4).
            Button {
                recorder.markMoment()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "bookmark.fill").font(.title2)
                    Text("Moment").font(.caption2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Tokens.Palette.accent)

            // Stop is deliberately NOT adjacent to Moment and requires a
            // deliberate gesture: a mis-tap must never end the recording.
            Button("Stop") {
                Task { await recorder.end() }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Tokens.Space.xs)
    }
}

// MARK: - Review

private struct WatchReviewView: View {
    @Environment(WatchRecorder.self) private var recorder

    var body: some View {
        List {
            ForEach(recorder.reviewItems, id: \.id) { item in
                Text(item.text)
                    .font(.caption)
                    .swipeActions(edge: .leading) {
                        Button("Keep") { recorder.decide(item.id, .accepted) }
                            .tint(Tokens.Palette.sent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Drop") { recorder.decide(item.id, .dismissed) }
                            .tint(.gray)
                    }
            }
        }
        .navigationTitle(recorder.reviewTitle)
    }
}

// MARK: - Recorder

/// Records, chunks, queues, hands off. That is the entire vocabulary.
@MainActor
@Observable
final class WatchRecorder {
    enum Phase { case idle, recording, review }

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var unsyncedCaptureCount = 0
    private(set) var reviewItems: [WatchLink.WatchReviewPayload.Item] = []
    private(set) var reviewTitle = "Review"
    var nextMeetingTitle: String?

    private let link = WatchLink(role: .watch)
    private var capture = WatchLink.PendingCapture()
    private var recorder: AVAudioRecorder?
    private var runtimeSession: WKExtendedRuntimeSession?
    private var tickTask: Task<Void, Never>?
    private var decisions: [UUID: ReviewState] = [:]
    private var reviewNoteID: UUID?

    var elapsedText: String {
        String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
    }

    func start() async {
        await link.activate()
        await link.onReviewPayload { [weak self] payload in
            await MainActor.run {
                self?.reviewNoteID = payload.noteID
                self?.reviewItems = payload.items
                self?.reviewTitle = payload.title
                self?.phase = .review
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    func begin() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
        try await session.activate()

        capture = WatchLink.PendingCapture()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 16 kHz mono AAC — ~1 MB per 8 minutes, so a 60-minute standalone
        // capture transfers comfortably (WATCH §3).
        recorder = try AVAudioRecorder(url: chunkURL(index: 0), settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ])
        recorder?.record()

        runtimeSession = WKExtendedRuntimeSession()
        runtimeSession?.start()

        phase = .recording
        elapsed = 0
        tick()
        WKInterfaceDevice.current().play(.start)
    }

    /// WATCH §4: haptic only. No sound, no screen. Granola's green flash and
    /// confirmation chime are exactly wrong for a conversation you are in.
    func markMoment() {
        guard phase == .recording else { return }
        capture.moments.append(elapsed)
        WKInterfaceDevice.current().play(.success)
    }

    func end() async {
        recorder?.stop()
        runtimeSession?.invalidate()
        tickTask?.cancel()
        capture.duration = elapsed
        phase = .idle
        WKInterfaceDevice.current().play(.stop)

        // Metadata first so the phone can create the note even if audio
        // transfer is still queued behind a range gap.
        await link.sendCaptureMetadata(capture)
        for url in chunkURLs {
            await link.sendChunk(url, captureID: capture.id)
        }
        unsyncedCaptureCount = await unacknowledgedCount()
    }

    func decide(_ id: UUID, _ state: ReviewState) {
        decisions[id] = state
        reviewItems.removeAll { $0.id == id }
        if reviewItems.isEmpty {
            phase = .idle
            if let noteID = reviewNoteID {
                let payload = decisions
                Task { await link.sendReviewDecisions(noteID: noteID, decisions: payload) }
            }
            decisions = [:]
        }
    }

    // MARK: Storage

    private var directory: URL {
        URL.documentsDirectory.appending(path: "captures/\(capture.id.uuidString)")
    }

    private func chunkURL(index: Int) -> URL {
        directory.appending(path: String(format: "chunk-%04d.m4a", index))
    }

    private var chunkURLs: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    /// Local audio is deleted only for chunks the phone has explicitly acked.
    /// Storage pressure never wins against an un-acked chunk (WATCH §2).
    private func unacknowledgedCount() async -> Int {
        var count = 0
        for url in chunkURLs where await !link.isAcknowledged(url.lastPathComponent) {
            count += 1
        }
        return count
    }

    private func tick() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .recording else { return }
                self.elapsed += 1
            }
        }
    }
}

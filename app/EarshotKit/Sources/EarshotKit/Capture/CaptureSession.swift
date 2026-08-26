import Foundation
import AVFoundation
import Observation

/// Owns a live capture: microphone, chunked disk writes, Moments, and the
/// stream feeding the transcriber.
///
/// Canon: PRD F-1 → F-6, RFC §5.
///
/// The invariant that outranks everything else here: **losing the transcript
/// must never lose the audio, and losing the audio must never lose the user's
/// typed notes.** Failures degrade inward, one layer at a time, and are
/// reported quietly rather than modally — nothing may steal focus mid-meeting
/// (DESIGN_SYSTEM §4).
@MainActor
@Observable
public final class CaptureSession {
    public private(set) var state: CaptureState = .idle
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var moments: [TimeInterval] = []
    public private(set) var liveSegments: [TranscriptChunk] = []

    /// Set when transcription drops out but recording continues. Rendered in
    /// the transcript pane, never as an alert (DESIGN_SYSTEM §6).
    public private(set) var transcriptionNotice: String?

    public let noteID: UUID

    private let engine = AVAudioEngine()
    private let chunkWriter: ChunkWriter
    private let transcriber: any TranscriptionEngine
    private var bufferContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var transcriptionTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var startDate: Date?

    public init(
        noteID: UUID = UUID(),
        transcriber: any TranscriptionEngine,
        chunkWriter: ChunkWriter
    ) {
        self.noteID = noteID
        self.transcriber = transcriber
        self.chunkWriter = chunkWriter
    }

    // MARK: Lifecycle

    public func start() async throws {
        guard state == .idle else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream(
            bufferingPolicy: .bufferingNewest(64)
        )
        bufferContinuation = continuation

        try chunkWriter.open(format: format)

        // Real-time thread. Per RFC §5 this does no allocation, no logging,
        // and no awaiting — it hands the buffer off and returns.
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [chunkWriter, continuation] buffer, _ in
            chunkWriter.append(buffer)
            continuation.yield(buffer)
        }

        engine.prepare()
        try engine.start()

        startDate = .now
        state = .recording
        startTicking()
        startTranscribing(stream)
    }

    public func stop() async {
        guard state == .recording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        bufferContinuation?.finish()
        tickTask?.cancel()
        transcriptionTask?.cancel()
        chunkWriter.close()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .transcribing
    }

    /// F-4. Must remain correct with the screen off and the app backgrounded,
    /// because that is exactly when it is used.
    public func markMoment(source: MomentSource = .phone) {
        guard state == .recording else { return }
        moments.append(elapsed)
    }

    // MARK: Internals

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date.now.timeIntervalSince(start)
            }
        }
    }

    private func startTranscribing(_ stream: AsyncStream<AVAudioPCMBuffer>) {
        transcriptionTask = Task { [weak self, transcriber] in
            guard let self else { return }
            do {
                for try await chunk in transcriber.transcribe(stream) {
                    if Task.isCancelled { return }
                    self.absorb(chunk)
                }
            } catch {
                // Recording continues. This is the whole point of the layered
                // degradation rule above — the audio is still being written.
                self.transcriptionNotice = "Transcript paused. Still recording — you won't lose the audio."
            }
        }
    }

    private func absorb(_ chunk: TranscriptChunk) {
        // Volatile hypotheses replace the trailing volatile line rather than
        // appending, so the live pane doesn't appear to rewrite itself under
        // the reader (F-3).
        if let last = liveSegments.last, !last.isFinal {
            liveSegments[liveSegments.count - 1] = chunk
        } else {
            liveSegments.append(chunk)
        }
        transcriptionNotice = nil
    }
}

/// Continuously writes audio to disk in short chunks.
///
/// F-6: a force-quit, a battery death, or a crash loses at most the final
/// chunk. Nothing in the capture path may buffer audio in memory for longer
/// than one chunk.
public final class ChunkWriter: @unchecked Sendable {
    public let directory: URL
    public let chunkDuration: TimeInterval

    private var file: AVAudioFile?
    private var chunkIndex = 0
    private var framesInChunk: AVAudioFrameCount = 0
    private var format: AVAudioFormat?
    private let lock = NSLock()

    public init(directory: URL, chunkDuration: TimeInterval = 10) {
        self.directory = directory
        self.chunkDuration = chunkDuration
    }

    public func open(format: AVAudioFormat) throws {
        lock.lock(); defer { lock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.format = format
        try rollOver()
    }

    public func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard let file, let format else { return }
        try? file.write(from: buffer)
        framesInChunk += buffer.frameLength

        let framesPerChunk = AVAudioFrameCount(format.sampleRate * chunkDuration)
        if framesInChunk >= framesPerChunk {
            try? rollOver()
        }
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        file = nil
    }

    public var chunkURLs: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "caf" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    private func rollOver() throws {
        guard let format else { return }
        let url = directory.appendingPathComponent(String(format: "chunk-%04d.caf", chunkIndex))
        file = try AVAudioFile(forWriting: url, settings: format.settings)
        // Audio is user content at rest: protected, and excluded from backup
        // unless the user turns on sync (RFC §7).
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        chunkIndex += 1
        framesInChunk = 0
    }
}

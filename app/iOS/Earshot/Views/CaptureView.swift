import SwiftUI
import EarshotKit

/// The one screen that matters.
///
/// Canon: DESIGN_SYSTEM.md §4, PRD F-1 → F-5.
///
/// Four rules, in priority order, that override any other consideration on
/// this screen:
/// 1. The notes pane never drops below 40% of the height. The machine does not
///    get to crowd the human.
/// 2. Nothing steals keyboard focus mid-meeting. No modal, no toast, no
///    permission prompt — all permissions are resolved before capture starts.
/// 3. The Moment button works without looking.
/// 4. A transcription failure never surfaces as an alert; capture continues.
struct CaptureView: View {
    @Environment(Services.self) private var services
    @Environment(\.dismiss) private var dismiss

    let note: Note
    @State private var session: CaptureSession?
    @State private var splitFraction: CGFloat = 0.55
    @FocusState private var notesFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header

                notesPane
                    .frame(height: max(geometry.size.height * splitFraction,
                                       geometry.size.height * 0.4))

                divider(in: geometry)

                transcriptPane
                    .frame(maxHeight: .infinity)

                controls
            }
        }
        .background(Tokens.Palette.paper)
        .navigationBarBackButtonHidden()
        .task {
            // Permissions and engine warm-up happen before the first frame the
            // user could type into, so rule 2 above holds.
            let session = CaptureSession(
                noteID: note.id,
                transcriber: services.transcriber,
                chunkWriter: ChunkWriter(directory: Self.audioDirectory(for: note))
            )
            self.session = session
            try? await session.start()
            notesFocused = true
        }
    }

    // MARK: Panes

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            RecordingDot()
            Text(Self.elapsedText(session?.elapsed ?? 0))
                .font(Tokens.Typography.timestamp)
                .monospacedDigit()
                .foregroundStyle(Tokens.Palette.graphite)
            TextField("Untitled", text: Binding(
                get: { note.title },
                set: { note.title = $0 }
            ))
            .font(Tokens.Typography.sectionTitle)
            .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .background(Tokens.Palette.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording, \(Self.elapsedText(session?.elapsed ?? 0)) elapsed")
    }

    /// The user's own words. Serif, full-contrast ink, and the first responder
    /// on open — because this is a notepad first and a machine second.
    private var notesPane: some View {
        TextEditor(text: Binding(
            get: { note.notes },
            set: { note.notes = $0 }
        ))
        .font(Tokens.Typography.noteBody)
        .foregroundStyle(Tokens.Palette.ink)
        .scrollContentBackground(.hidden)
        .background(Tokens.Palette.paper)
        .focused($notesFocused)
        .padding(.horizontal, Tokens.Space.l)
        .accessibilityLabel("Your notes")
    }

    private func divider(in geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Tokens.Palette.rule)
            .frame(height: 0.5)
            .overlay {
                Capsule()
                    .fill(Tokens.Palette.rule)
                    .frame(width: 36, height: 4)
            }
            .contentShape(Rectangle().inset(by: -Tokens.Space.m))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let proposed = splitFraction + value.translation.height / geometry.size.height
                        splitFraction = min(max(proposed, 0.4), 0.85)
                    }
            )
            .accessibilityHidden(true)
    }

    private var transcriptPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    if let notice = session?.transcriptionNotice {
                        // Rule 4: quiet, inline, non-blocking. Copy fixed in
                        // DESIGN_SYSTEM.md §6 — not improvised here.
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(Tokens.Palette.accent)
                            .padding(.vertical, Tokens.Space.xs)
                    }

                    ForEach(Array((session?.liveSegments ?? []).enumerated()), id: \.offset) { index, chunk in
                        TranscriptRow(chunk: chunk)
                            .id(index)
                    }
                }
                .padding(.horizontal, Tokens.Space.l)
                .padding(.vertical, Tokens.Space.m)
            }
            .background(Tokens.Palette.card)
            .onChange(of: session?.liveSegments.count ?? 0) { _, count in
                withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Tokens.Space.xl) {
            Button {
                session?.markMoment()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.title2)
                    .frame(width: Tokens.momentButtonSize, height: Tokens.momentButtonSize)
                    .background(Tokens.Palette.accent.opacity(0.12), in: Circle())
                    .foregroundStyle(Tokens.Palette.accent)
            }
            .accessibilityLabel("Mark this moment")

            Spacer()

            Button("Stop") {
                Task {
                    await session?.stop()
                    await persistAndSummarize()
                    dismiss()
                }
            }
            .font(.headline)
            .foregroundStyle(Tokens.Palette.ink)
            .padding(.horizontal, Tokens.Space.xl)
            .padding(.vertical, Tokens.Space.m)
            .background(Tokens.Palette.rule, in: Capsule())
        }
        .padding(Tokens.Space.l)
        .background(Tokens.Palette.card)
    }

    // MARK: Plumbing

    private func persistAndSummarize() async {
        guard let session else { return }
        note.duration = session.elapsed
        note.captureState = .transcribing

        for chunk in session.liveSegments where chunk.isFinal {
            let segment = TranscriptSegment(
                text: chunk.text, start: chunk.start, end: chunk.end
            )
            segment.note = note
            services.container.mainContext.insert(segment)
        }
        for offset in session.moments {
            let moment = Moment(offset: offset, source: .phone)
            moment.note = note
            services.container.mainContext.insert(moment)
        }
        try? services.container.mainContext.save()
        await services.summarize(note)
    }

    static func audioDirectory(for note: Note) -> URL {
        URL.applicationSupportDirectory
            .appending(path: "audio/\(note.id.uuidString)")
    }

    static func elapsedText(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct TranscriptRow: View {
    let chunk: TranscriptChunk

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(CaptureView.elapsedText(chunk.start))
                .font(Tokens.Typography.timestamp)
                .foregroundStyle(Tokens.Palette.graphite.opacity(0.7))
            Text(chunk.text)
                .font(Tokens.Typography.transcriptBody)
                .foregroundStyle(Tokens.Palette.graphite)
        }
        // Volatile hypotheses render faded so the pane doesn't appear to
        // rewrite itself under the reader (F-3).
        .opacity(chunk.isFinal ? 1 : 0.55)
    }
}

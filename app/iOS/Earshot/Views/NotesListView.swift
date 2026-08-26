import SwiftUI
import SwiftData
import EarshotKit

/// Home. Must load in under 200ms with 5,000 notes — the free tier promises
/// unlimited history (F-28, PRD §8), which makes list performance a product
/// requirement rather than an optimisation.
struct NotesListView: View {
    @Environment(Services.self) private var services
    @Query(sort: \Note.startedAt, order: .reverse) private var notes: [Note]
    @State private var search = ""
    @State private var activeNote: Note?
    @State private var showingConsent = false

    var body: some View {
        List {
            if let interrupted = notes.first(where: { $0.captureState == .interrupted }) {
                RecoveryRow(note: interrupted)
            }

            ForEach(grouped, id: \.day) { group in
                Section(group.day.formatted(date: .complete, time: .omitted)) {
                    ForEach(group.notes) { note in
                        NavigationLink(value: note.id) {
                            NoteRow(note: note)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "Search your conversations")
        .navigationTitle("Earshot")
        .navigationDestination(for: UUID.self) { id in
            if let note = try? services.repository.note(id: id) {
                NoteDetailView(note: note)
            }
        }
        .overlay(alignment: .bottom) { captureButton }
        .overlay { if notes.isEmpty { emptyState } }
        .fullScreenCover(item: $activeNote) { note in
            NavigationStack { CaptureView(note: note) }
        }
        .sheet(isPresented: $showingConsent) {
            ConsentSheet { beginCapture() }
        }
    }

    // MARK: Pieces

    private var captureButton: some View {
        Button {
            // F-5: consent is resolved *before* capture, never mid-meeting,
            // because rule 2 of the capture screen forbids stealing focus once
            // recording has started.
            if Consent.requiresEveryTimePrompt(userHandlesItThemselves: handlesConsentThemselves) {
                showingConsent = true
            } else {
                beginCapture()
            }
        } label: {
            Label("Capture", systemImage: "waveform")
                .font(.headline)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.vertical, Tokens.Space.l)
                .background(Tokens.Palette.accent, in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.bottom, Tokens.Space.xl)
        .accessibilityHint("Starts recording and transcribing on this iPhone")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing here yet", systemImage: "waveform")
        } description: {
            // Copy fixed in DESIGN_SYSTEM.md §6.
            Text("Tap capture when your next conversation starts — nothing leaves this iPhone.")
        }
    }

    private var handlesConsentThemselves: Bool {
        UserDefaults.standard.bool(forKey: "consent.userHandlesItThemselves")
    }

    private func beginCapture() {
        let recipe = Recipe.autoSelected(
            from: Recipe.builtIns, title: "", attendeeCount: 0, shelfName: nil
        )
        activeNote = try? services.repository.createNote(title: "", recipeID: recipe.id)
    }

    private var filtered: [Note] {
        guard !search.isEmpty else { return notes }
        return notes.filter { note in
            note.resolvedTitle.localizedCaseInsensitiveContains(search)
                || note.notes.localizedCaseInsensitiveContains(search)
                || note.digestSummary?.localizedCaseInsensitiveContains(search) == true
        }
    }

    private var grouped: [(day: Date, notes: [Note])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.startedAt) }
            .map { (day: $0.key, notes: $0.value) }
            .sorted { $0.day > $1.day }
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(note.resolvedTitle)
                .font(Tokens.Typography.noteBody)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)

            HStack(spacing: Tokens.Space.s) {
                Text(note.startedAt.formatted(date: .omitted, time: .shortened))
                if note.duration > 0 {
                    Text("· \(Int(note.duration / 60)) min")
                }
                if !note.moments.isEmpty {
                    Label("\(note.moments.count)", systemImage: "bookmark.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                }
                let pending = note.unreviewedActionItems.count
                if pending > 0 {
                    // Undelivered work is the one other thing the accent is
                    // allowed to mark (DESIGN_SYSTEM §2).
                    Text("\(pending) to review")
                        .foregroundStyle(Tokens.Palette.accent)
                }
            }
            .font(.caption)
            .foregroundStyle(Tokens.Palette.graphite)
        }
        .padding(.vertical, Tokens.Space.xs)
    }
}

/// F-6. A capture that died mid-recording is offered back, not silently lost.
private struct RecoveryRow: View {
    @Environment(Services.self) private var services
    let note: Note

    var body: some View {
        Button {
            Task { await services.summarize(note) }
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Label("Unfinished recording", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(Tokens.Palette.accent)
                Text("Earshot stopped unexpectedly during \(note.resolvedTitle). The audio is still here — tap to finish the notes.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.Palette.graphite)
            }
        }
    }
}

/// F-5. Shown before the first capture, and every time in all-party-consent
/// regions until the user says they handle it themselves.
private struct ConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("consent.userHandlesItThemselves") private var handlesItThemselves = false
    let onProceed: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                Text("Tell the room")
                    .font(.title2.bold())

                Text(Consent.scriptToReadAloud)
                    .font(Tokens.Typography.noteBody)
                    .padding(Tokens.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.Palette.card, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))

                Text(Consent.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(Tokens.Palette.graphite)

                Toggle("I handle this myself — stop asking", isOn: $handlesItThemselves)
                    .font(.footnote)

                Spacer()

                Button {
                    dismiss()
                    onProceed()
                } label: {
                    Text("Start capture")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.m)
                        .background(Tokens.Palette.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }
            .padding(Tokens.Space.xl)
            .background(Tokens.Palette.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

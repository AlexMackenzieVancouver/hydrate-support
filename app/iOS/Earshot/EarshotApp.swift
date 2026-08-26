import SwiftUI
import SwiftData
import EventKit
import EarshotKit

@main
struct EarshotApp: App {
    @State private var services = Services()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(services.entitlements)
                .tint(Tokens.Palette.accent)
                .task { await services.start() }
                // F-19: completing a reminder in Reminders closes the action
                // item here. Driven by the change notification, never a poll.
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    Task { await services.reconcileDeliveredItems() }
                }
        }
        .modelContainer(services.container)
    }
}

/// Composition root. Every protocol conformance in `EarshotKit` is chosen
/// here and nowhere else, which is what keeps the quality ladder (RFC §6) a
/// composition decision rather than branching scattered through views.
@MainActor
@Observable
final class Services {
    let container: ModelContainer
    let repository: NoteRepository
    let entitlements = Entitlements()
    let watchLink = WatchLink(role: .phone)

    private(set) var ladder = QualityLadder(rung: .templateOnly)
    private(set) var transcriber: any TranscriptionEngine = SpeechAnalyzerEngine()
    private(set) var deliveries: DeliveryCoordinator

    private let remindersTarget = RemindersDelivery()

    init() {
        let schema = Schema([
            Note.self, TranscriptSegment.self, ActionItem.self,
            Moment.self, Speaker.self, Shelf.self, DeliveryReceipt.self
        ])
        // `cloudKitDatabase: .none` is deliberate and load-bearing: sync is a
        // Pro feature the user turns on, not a default that quietly copies
        // meeting audio off the device (F-24).
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        container = try! ModelContainer(for: schema, configurations: [configuration])
        repository = NoteRepository(context: container.mainContext)
        deliveries = DeliveryCoordinator(targets: [remindersTarget, MarkdownDelivery(folderBookmark: nil)])
    }

    func start() async {
        ladder = await QualityLadder.resolve()
        await entitlements.start()
        await entitlements.loadProducts()
        await watchLink.activate()
        await wireWatch()
    }

    /// The Watch hands off audio and Moments. It never authors a Note — the
    /// phone does, here, on the main actor (WATCH §2).
    private func wireWatch() async {
        await watchLink.onCaptureMetadata { [weak self] capture in
            await self?.ingest(capture)
        }
        await watchLink.onReviewDecisions { [weak self] noteID, decisions in
            await MainActor.run {
                try? self?.repository.applyReviewDecisions(decisions, noteID: noteID)
            }
        }
    }

    private func ingest(_ capture: WatchLink.PendingCapture) async {
        guard let note = try? repository.createNote(
            title: "",
            recipeID: Recipe.standardID
        ) else { return }
        note.startedAt = capture.startedAt
        note.duration = capture.duration
        note.captureState = .transcribing
        for offset in capture.moments {
            let moment = Moment(offset: offset, source: .watch)
            moment.note = note
            container.mainContext.insert(moment)
        }
        try? container.mainContext.save()
    }

    func reconcileDeliveredItems() async {
        guard let notes = try? repository.allNotes() else { return }
        let ids = notes.flatMap { $0.actionItems.compactMap(\.externalID) }
        let completed = await remindersTarget.completedExternalIDs(from: ids)
        try? repository.markComplete(externalIDs: completed)
    }

    func summarize(_ note: Note) async {
        note.captureState = .enhancing
        let input = SummarizationInput(
            title: note.resolvedTitle,
            userNotes: note.notes,
            transcript: note.segments
                .sorted { $0.start < $1.start }
                .map { TranscriptLine(speaker: "Speaker \($0.speakerIndex + 1)", text: $0.text, offset: $0.start) },
            moments: note.moments.map(\.offset).sorted(),
            recipe: Recipe.builtIns.first { $0.id == note.recipeID } ?? .standard,
            shelfContext: note.shelf?.context
        )

        do {
            let digest = try await ladder.makeSummarizer().summarize(input)
            try repository.apply(digest, to: note)
        } catch {
            // Never leave a note stuck mid-enhancement with no explanation.
            // Falling back is fine; falling back silently is not (F-14).
            if let digest = try? await TemplateSummarizer().summarize(input) {
                try? repository.apply(digest, to: note)
            } else {
                note.captureState = .ready
            }
        }
    }
}

struct RootView: View {
    @Environment(Services.self) private var services

    var body: some View {
        NavigationStack {
            NotesListView()
        }
        .background(Tokens.Palette.paper)
    }
}

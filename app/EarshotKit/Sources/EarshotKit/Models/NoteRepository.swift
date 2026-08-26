import Foundation
import SwiftData
import Observation

/// The single writer for every `Note`.
///
/// Canon: RFC §5, WATCH_ARCHITECTURE.md §2, and the ios-app-os state-ownership
/// gate. Nothing else in the codebase — not the Watch, not a background task,
/// not a delivery target — mutates a `Note` except through this type on the
/// main actor.
@MainActor
@Observable
public final class NoteRepository {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Reading

    public func allNotes() throws -> [Note] {
        try context.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
    }

    public func note(id: UUID) throws -> Note? {
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Captures that died mid-recording. Offered for recovery at launch (F-6) —
    /// audio chunks are already on disk, so nothing is lost but the last ten
    /// seconds.
    public func interruptedNotes() throws -> [Note] {
        let recording = CaptureState.recording.rawValue
        let interrupted = CaptureState.interrupted.rawValue
        return try context.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.captureState.rawValue == recording
                                     || $0.captureState.rawValue == interrupted }
            )
        )
    }

    // MARK: Writing

    @discardableResult
    public func createNote(id: UUID = UUID(), title: String, recipeID: String, shelf: Shelf? = nil) throws -> Note {
        let note = Note(id: id, title: title, recipeID: recipeID, captureState: .recording)
        note.shelf = shelf
        context.insert(note)
        try context.save()
        return note
    }

    /// Applies a finished digest.
    ///
    /// Note what this does *not* touch: `note.notes`. The user's own words are
    /// input to the summarizer and are never written back over. That is F-11,
    /// and it is the thing this category's users actually love about the
    /// incumbent (E-6) — breaking it would make everything else pointless.
    public func apply(_ digest: MeetingDigest, to note: Note) throws {
        note.enhancedMarkdown = digest.markdown
        note.enhancementTier = digest.tier
        note.digestSummary = digest.summary
        note.digestDecisions = digest.decisions
        note.digestOpenQuestions = digest.openQuestions

        for extracted in digest.actionItems {
            let item = ActionItem(
                text: extracted.text,
                assignee: extracted.assignee,
                dueDate: extracted.dueDate,
                sourceOffset: extracted.sourceOffset
            )
            item.note = note
            context.insert(item)
        }

        note.captureState = .ready
        try context.save()
    }

    /// F-11's escape hatch: one tap recovers the raw notes. Because the two
    /// layers were never merged, this is a deletion rather than a diff — which
    /// is why it can be promised at all.
    public func stripEnhancement(from note: Note) throws {
        note.enhancedMarkdown = nil
        note.enhancementTier = nil
        note.digestSummary = nil
        note.digestDecisions = []
        note.digestOpenQuestions = []
        try context.save()
    }

    public func record(_ receipt: DeliveryReceipt, on note: Note, externalIDs: [UUID: String], targetName: String) throws {
        receipt.note = note
        context.insert(receipt)
        for item in note.actionItems {
            if let external = externalIDs[item.id] {
                item.externalID = external
                item.deliveredTo = targetName
            }
        }
        // Same transaction as the outbound call, per RFC §7. An outbound call
        // with no receipt is a unit-test failure.
        try context.save()
    }

    /// F-19. Called on `EKEventStoreChanged`, not on a poll — completing the
    /// reminder in Reminders closes the loop here, which is the only way
    /// follow-through is observable rather than assumed.
    public func markComplete(externalIDs: [String]) throws {
        guard !externalIDs.isEmpty else { return }
        let items = try context.fetch(FetchDescriptor<ActionItem>())
        for item in items where item.externalID.map(externalIDs.contains) == true {
            item.isComplete = true
        }
        try context.save()
    }

    public func applyReviewDecisions(_ decisions: [UUID: ReviewState], noteID: UUID) throws {
        guard let note = try note(id: noteID) else { return }
        for item in note.actionItems {
            if let state = decisions[item.id] { item.review = state }
        }
        try context.save()
    }

    // MARK: Speakers

    /// F-8: naming a voice once names it forever. Matching is deliberately
    /// conservative (`Diarization.confirmThreshold`) — we would rather ask than
    /// mislabel, because E-2 says a wrong name is worse than no name.
    public func matchSpeaker(voicePrint: [Float]) throws -> Speaker? {
        let speakers = try context.fetch(FetchDescriptor<Speaker>())
        var best: (Speaker, Double)?
        for speaker in speakers {
            guard let stored = speaker.voicePrint else { continue }
            let score = Diarization.similarity(stored, voicePrint)
            if score > (best?.1 ?? Diarization.confirmThreshold) {
                best = (speaker, score)
            }
        }
        return best?.0
    }

    /// F-10: renaming applies retroactively across the whole meeting and
    /// forward to every future one.
    public func nameSpeaker(_ speaker: Speaker, as name: String, voicePrint: [Float]?) throws {
        speaker.name = name
        speaker.attribution = .manual
        if let voicePrint { speaker.voicePrint = voicePrint }
        try context.save()
    }

    public func deleteSpeaker(_ speaker: Speaker) throws {
        // The voice print goes with it. It never existed anywhere else — not in
        // exports, not in sync payloads (RFC §3).
        context.delete(speaker)
        try context.save()
    }
}

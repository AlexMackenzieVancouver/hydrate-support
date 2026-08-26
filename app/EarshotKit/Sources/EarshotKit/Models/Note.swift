import Foundation
import SwiftData

/// The system of record for a captured conversation.
///
/// Canon: PRD F-11 (the user's own words are a separate, never-overwritten
/// field), F-18 (delivery receipts live with the note), RFC §4.
///
/// Ownership: the iPhone's `NoteRepository` is the only writer. The Watch never
/// authors or mutates a `Note` — see WATCH_ARCHITECTURE.md §2.
@Model
public final class Note {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var startedAt: Date
    public var duration: TimeInterval

    /// What the user typed, verbatim. Nothing in this codebase may write to
    /// this property except direct user editing. This is the F-11 guarantee.
    public var notes: String

    /// The machine layer, kept separate so "strip AI" is a deletion, not a diff.
    public var enhancedMarkdown: String?

    /// Which rung of the quality ladder produced `enhancedMarkdown` (RFC §6).
    /// Surfaced in the UI whenever it is not `.onDevice` — silent degradation
    /// is a defect (F-14).
    public var enhancementTier: EnhancementTier?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.note)
    public var segments: [TranscriptSegment]

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.note)
    public var actionItems: [ActionItem]

    @Relationship(deleteRule: .cascade, inverse: \Moment.note)
    public var moments: [Moment]

    @Relationship(deleteRule: .cascade, inverse: \DeliveryReceipt.note)
    public var receipts: [DeliveryReceipt]

    public var shelf: Shelf?
    public var recipeID: String

    /// Local path only. Never uploaded, never included in a share payload.
    public var audioFilename: String?

    /// Set while a capture is in flight or recovering. A note with
    /// `captureState == .interrupted` is offered for recovery at launch (F-6).
    public var captureState: CaptureState

    public var digestSummary: String?
    public var digestDecisions: [String]
    public var digestOpenQuestions: [String]

    public init(
        id: UUID = UUID(),
        title: String = "",
        startedAt: Date = .now,
        duration: TimeInterval = 0,
        notes: String = "",
        recipeID: String = Recipe.standardID,
        captureState: CaptureState = .idle
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.duration = duration
        self.notes = notes
        self.enhancedMarkdown = nil
        self.enhancementTier = nil
        self.segments = []
        self.actionItems = []
        self.moments = []
        self.receipts = []
        self.shelf = nil
        self.recipeID = recipeID
        self.audioFilename = nil
        self.captureState = captureState
        self.digestSummary = nil
        self.digestDecisions = []
        self.digestOpenQuestions = []
    }
}

public extension Note {
    /// A display title that never shows an empty row in the list.
    var resolvedTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        let firstLine = notes.split(separator: "\n").first.map(String.init) ?? ""
        if !firstLine.isEmpty { return String(firstLine.prefix(60)) }
        return startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    /// True when nothing about this note has ever left the device.
    /// The common case, and the one the Privacy Ledger celebrates (F-27).
    var isFullyLocal: Bool { receipts.isEmpty }

    var unreviewedActionItems: [ActionItem] {
        actionItems.filter { $0.review == .pending }
    }
}

public enum CaptureState: String, Codable, Sendable {
    case idle
    case recording
    /// Process died mid-capture. Audio chunks are on disk (F-6).
    case interrupted
    case transcribing
    case enhancing
    case ready
}

/// Which rung of RFC §6 produced a note's enhancement. Displayed to the user
/// for every value except `.onDevice`.
public enum EnhancementTier: String, Codable, Sendable {
    /// Apple Foundation Models, on device. The default and the goal.
    case onDevice
    /// Map-reduce over windows because the transcript exceeded model context.
    case onDeviceChunked
    /// Deterministic extraction. Honest, less fluent, still entirely local.
    case template
    /// User's own key, explicitly confirmed for this note. Content left the device.
    case remoteBYOK

    public var isLocal: Bool { self != .remoteBYOK }

    /// Non-nil when the UI must state the tier in effect (F-14).
    public var disclosure: String? {
        switch self {
        case .onDevice:
            return nil
        case .onDeviceChunked:
            return "Long conversation — summarised in sections on this iPhone."
        case .template:
            return "Written by plain extraction, not the on-device model. Nothing was sent anywhere."
        case .remoteBYOK:
            return "Summarised by your own cloud model. The transcript left this iPhone."
        }
    }
}

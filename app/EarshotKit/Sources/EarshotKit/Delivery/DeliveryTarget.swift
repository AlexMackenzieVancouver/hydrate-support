import Foundation

/// Somewhere a finished note can go.
///
/// This protocol is the product thesis in code. Every 2026 round-up of this
/// category lands on the same criticism: *transcription is table stakes;
/// nothing is good at what happens after transcription — action items get
/// captured but don't move anywhere* (evidence E-3, E-7). A note that stays in
/// the notes app has failed, however good the summary is.
///
/// Canon: PRD F-16 → F-19.
public protocol DeliveryTarget: Sendable {
    var id: String { get }
    var displayName: String { get }
    /// Whether using this target means bytes crossing the network. Drives the
    /// Privacy Ledger's headline distinction and the confirmation copy (F-27).
    var leavesTheDevice: Bool { get }
    var requiredTier: Tier { get }

    /// Exactly what would be sent, rendered for human inspection. Shown before
    /// anything happens, every time a target is used for the first time (F-17).
    func preview(_ payload: DeliveryPayload) async throws -> DeliveryPreview

    /// Performs the delivery. Implementations MUST return a receipt; the caller
    /// writes it in the same transaction (RFC §7).
    func deliver(_ payload: DeliveryPayload) async throws -> DeliveryResult
}

public struct DeliveryPayload: Sendable {
    public let noteID: UUID
    public let title: String
    public let date: Date
    public let markdown: String
    /// Only items the user accepted. Dismissed and pending items are never
    /// delivered (F-17).
    public let acceptedActions: [DeliverableAction]
    public let transcriptIncluded: Bool

    public init(
        noteID: UUID,
        title: String,
        date: Date,
        markdown: String,
        acceptedActions: [DeliverableAction],
        transcriptIncluded: Bool = false
    ) {
        self.noteID = noteID
        self.title = title
        self.date = date
        self.markdown = markdown
        self.acceptedActions = acceptedActions
        self.transcriptIncluded = transcriptIncluded
    }
}

public struct DeliverableAction: Sendable, Hashable {
    public let id: UUID
    public let text: String
    public let assignee: String?
    public let dueDate: Date?

    public init(id: UUID, text: String, assignee: String?, dueDate: Date?) {
        self.id = id
        self.text = text
        self.assignee = assignee
        self.dueDate = dueDate
    }
}

public struct DeliveryPreview: Sendable {
    /// One line per thing that will be created, in the words the user will see
    /// at the destination. Not a summary of a summary.
    public let lines: [String]
    public let destination: String
    /// Non-nil only when bytes leave the device. Rendered in `accent` with the
    /// exact hostname, never a friendly product name.
    public let networkWarning: String?

    public init(lines: [String], destination: String, networkWarning: String? = nil) {
        self.lines = lines
        self.destination = destination
        self.networkWarning = networkWarning
    }
}

public struct DeliveryResult: Sendable {
    public let itemCount: Int
    public let payloadSummary: String
    /// Maps `ActionItem.id` → external identifier, so completing the item at
    /// its destination can mark it done here (F-19). This mapping is the whole
    /// reason follow-through is observable rather than assumed.
    public let externalIDs: [UUID: String]

    public init(itemCount: Int, payloadSummary: String, externalIDs: [UUID: String] = [:]) {
        self.itemCount = itemCount
        self.payloadSummary = payloadSummary
        self.externalIDs = externalIDs
    }
}

public enum Tier: String, Sendable, Codable, CaseIterable {
    case free
    case pro
}

public enum DeliveryError: Error, Sendable {
    case permissionDenied(String)
    case notConfigured
    case requiresPro
    case destinationUnavailable(String)
}

/// Rules that fire deliveries automatically once a note is reviewed.
///
/// Configured once per meeting type; the point is that the user stops thinking
/// about it. Never automatic on a target's first use — the first run always
/// goes through the preview sheet (F-17).
public struct DeliveryRule: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var targetID: String
    public var appliesToShelfID: UUID?
    public var appliesToRecipeID: String?
    public var includeTranscript: Bool
    /// Set to true only after the user has confirmed this target once.
    public var confirmedOnce: Bool

    public init(
        id: UUID = UUID(),
        targetID: String,
        appliesToShelfID: UUID? = nil,
        appliesToRecipeID: String? = nil,
        includeTranscript: Bool = false,
        confirmedOnce: Bool = false
    ) {
        self.id = id
        self.targetID = targetID
        self.appliesToShelfID = appliesToShelfID
        self.appliesToRecipeID = appliesToRecipeID
        self.includeTranscript = includeTranscript
        self.confirmedOnce = confirmedOnce
    }

    public func applies(shelfID: UUID?, recipeID: String) -> Bool {
        if let required = appliesToShelfID, required != shelfID { return false }
        if let required = appliesToRecipeID, required != recipeID { return false }
        return true
    }
}

import Foundation
import SwiftData

/// A commitment made in the conversation.
///
/// This is the entity the whole product is built around. The category's own
/// 2026 reviewers converged on one criticism — *action items get captured but
/// don't move anywhere* (E-7) — so an `ActionItem` is not finished when it is
/// extracted. It is finished when it exists somewhere the user actually works,
/// and it round-trips completion back here (F-16, F-19).
@Model
public final class ActionItem {
    public var id: UUID
    public var text: String

    /// Only set when the assignee was actually stated. We never guess who owes
    /// what — a fabricated assignee is the fastest way to lose trust in the
    /// extraction entirely.
    public var assignee: String?

    /// Only set when a date was actually stated in the conversation.
    public var dueDate: Date?

    /// Transcript offset this was extracted from, so "why does it think this?"
    /// is always one tap from an answer.
    public var sourceOffset: TimeInterval?

    public var review: ReviewState
    public var isComplete: Bool

    /// `EKReminder.calendarItemIdentifier` once delivered, which is what makes
    /// F-19's round-trip possible: ticking it off in Reminders ticks it off here.
    public var externalID: String?
    public var deliveredTo: String?

    public var note: Note?

    public init(
        id: UUID = UUID(),
        text: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        sourceOffset: TimeInterval? = nil
    ) {
        self.id = id
        self.text = text
        self.assignee = assignee
        self.dueDate = dueDate
        self.sourceOffset = sourceOffset
        self.review = .pending
        self.isComplete = false
        self.externalID = nil
        self.deliveredTo = nil
    }
}

/// Extraction is a proposal, not a fact. Nothing is delivered until accepted
/// (F-17), and the accept rate is a launch metric — it is how we measure
/// extraction quality honestly rather than by vibes.
public enum ReviewState: String, Codable, Sendable {
    case pending
    case accepted
    case dismissed
}

/// A record of something leaving the device.
///
/// Written inside the same transaction as the outbound call. An outbound call
/// with no receipt is a unit-test failure (RFC §7). Backs the Privacy Ledger
/// (F-18, F-27).
@Model
public final class DeliveryReceipt {
    public var id: UUID
    public var targetID: String
    public var targetName: String
    public var deliveredAt: Date
    public var itemCount: Int

    /// Human-readable description of exactly what left, shown verbatim in the
    /// Privacy Ledger. Written for a suspicious reader, not a reassured one.
    public var payloadSummary: String

    /// False for on-device destinations (Reminders, Files). True only when
    /// bytes crossed the network — the distinction the Ledger leads with.
    public var leftTheDevice: Bool

    public var note: Note?

    public init(
        id: UUID = UUID(),
        targetID: String,
        targetName: String,
        itemCount: Int,
        payloadSummary: String,
        leftTheDevice: Bool
    ) {
        self.id = id
        self.targetID = targetID
        self.targetName = targetName
        self.deliveredAt = .now
        self.itemCount = itemCount
        self.payloadSummary = payloadSummary
        self.leftTheDevice = leftTheDevice
    }
}

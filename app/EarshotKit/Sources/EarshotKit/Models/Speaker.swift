import Foundation
import SwiftData

/// A named voice that persists across meetings.
///
/// This entity is the direct answer to E-2 — Granola renders transcripts as
/// continuous text with no speaker labels, and infers names from calendar
/// invitees with accuracy that collapses past three participants.
///
/// Canon: PRD F-7, F-8, F-9, F-10.
@Model
public final class Speaker {
    @Attribute(.unique) public var id: UUID
    public var name: String

    /// 256-float embedding from the diarizer. Never exported, never synced,
    /// never included in a share payload (RFC §3). Deleted with the speaker.
    public var voicePrint: [Float]?

    /// How this speaker's name was arrived at. Drives the UI's confidence
    /// affordance: a `.calendarHint` name is shown with a dotted underline and
    /// asks for confirmation, because a wrong name is worse than no name.
    public var attribution: SpeakerAttribution

    public var isMe: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        voicePrint: [Float]? = nil,
        attribution: SpeakerAttribution = .manual,
        isMe: Bool = false
    ) {
        self.id = id
        self.name = name
        self.voicePrint = voicePrint
        self.attribution = attribution
        self.isMe = isMe
        self.createdAt = .now
    }
}

public enum SpeakerAttribution: String, Codable, Sendable {
    /// The user typed this name. Highest confidence; never overridden.
    case manual
    /// Matched against a stored voice print above threshold (F-8).
    case matched
    /// Suggested from the calendar attendee list. A hint only — F-9 forbids
    /// this from being treated as an assignment.
    case calendarHint

    public var needsConfirmation: Bool { self == .calendarHint }
}

/// One contiguous run of speech attributed to a single voice.
public struct SpeakerTurn: Sendable, Hashable, Codable {
    public let speakerIndex: Int
    public let start: TimeInterval
    public let end: TimeInterval
    /// Diarizer confidence, 0...1. Below `Diarization.confirmThreshold` the UI
    /// shows the chip as unconfirmed rather than guessing.
    public let confidence: Double

    public init(speakerIndex: Int, start: TimeInterval, end: TimeInterval, confidence: Double) {
        self.speakerIndex = speakerIndex
        self.start = start
        self.end = end
        self.confidence = confidence
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }
}

public enum Diarization {
    /// Cosine-similarity threshold for auto-naming a voice from a stored print.
    /// Deliberately conservative: we would rather ask than mislabel (RFC §3).
    public static let confirmThreshold: Double = 0.82

    public static func similarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Double = 0, normA: Double = 0, normB: Double = 0
        for i in a.indices {
            let x = Double(a[i]), y = Double(b[i])
            dot += x * y
            normA += x * x
            normB += y * y
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}

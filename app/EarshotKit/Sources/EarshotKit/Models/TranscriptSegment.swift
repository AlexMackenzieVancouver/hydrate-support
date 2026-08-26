import Foundation
import SwiftData

/// One utterance in the transcript, with its speaker.
@Model
public final class TranscriptSegment {
    public var id: UUID
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval

    /// Diarizer-local index (0, 1, 2…). Resolved to a `Speaker` via
    /// `speakerID` once the voice is named or matched.
    public var speakerIndex: Int
    public var speakerID: UUID?

    /// False while the transcriber is still refining this hypothesis. Volatile
    /// segments render at reduced opacity so the live pane doesn't appear to
    /// rewrite itself under the reader (F-3).
    public var isFinal: Bool

    public var note: Note?

    public init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        speakerIndex: Int = 0,
        speakerID: UUID? = nil,
        isFinal: Bool = true
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.speakerIndex = speakerIndex
        self.speakerID = speakerID
        self.isFinal = isFinal
    }
}

/// A timestamped bookmark the user dropped mid-conversation.
///
/// Moments are *hard anchors*: `Summarizer` implementations must address every
/// Moment in their output, and the map-reduce chunker may never drop one
/// (RFC §3). This is what makes a wrist tap worth having (WATCH §4).
@Model
public final class Moment {
    public var id: UUID
    public var offset: TimeInterval
    public var source: MomentSource
    /// Optional text the user added afterwards, when reviewing.
    public var annotation: String?
    public var note: Note?

    public init(
        id: UUID = UUID(),
        offset: TimeInterval,
        source: MomentSource,
        annotation: String? = nil
    ) {
        self.id = id
        self.offset = offset
        self.source = source
        self.annotation = annotation
    }
}

public enum MomentSource: String, Codable, Sendable {
    case phone
    case watch
    case shortcut
}

/// A local folder that carries standing context into summarisation.
///
/// Granola's Spaces, without the requirement to be an enterprise customer
/// (PRD F-20, and E-5 — the pivot that lost the original audience).
@Model
public final class Shelf {
    @Attribute(.unique) public var id: UUID
    public var name: String

    /// Injected into the summarizer prompt for every note filed here: project
    /// glossary, participant roles, what "done" means on this project.
    public var context: String

    /// Recipe applied by default to notes filed on this shelf (F-13).
    public var defaultRecipeID: String?

    @Relationship(deleteRule: .nullify, inverse: \Note.shelf)
    public var notes: [Note]

    public init(id: UUID = UUID(), name: String, context: String = "") {
        self.id = id
        self.name = name
        self.context = context
        self.defaultRecipeID = nil
        self.notes = []
    }
}

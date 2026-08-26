import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns a transcript plus the user's own notes into a structured digest.
///
/// Canon: RFC §3 and §6, PRD F-11 through F-15.
///
/// The contract every implementation owes:
/// 1. It **never** rewrites `Note.notes`. The user's words are input, not
///    material. (F-11 — this is the thing Granola's users actually love, E-6.)
/// 2. It **must** address every `Moment`. A wrist tap that vanishes from the
///    output makes the Watch pointless (WATCH §4).
/// 3. It reports which tier produced the result so the UI can disclose it.
///    Silent degradation is a defect (F-14).
public protocol Summarizer: Sendable {
    var tier: EnhancementTier { get }
    var isAvailable: Bool { get async }
    func summarize(_ input: SummarizationInput) async throws -> MeetingDigest
}

public struct SummarizationInput: Sendable {
    public let title: String
    /// The user's own notes. Read-only to every summarizer.
    public let userNotes: String
    public let transcript: [TranscriptLine]
    public let moments: [TimeInterval]
    public let recipe: Recipe
    /// Standing context from the note's Shelf, if any (F-20).
    public let shelfContext: String?

    public init(
        title: String,
        userNotes: String,
        transcript: [TranscriptLine],
        moments: [TimeInterval],
        recipe: Recipe,
        shelfContext: String? = nil
    ) {
        self.title = title
        self.userNotes = userNotes
        self.transcript = transcript
        self.moments = moments
        self.recipe = recipe
        self.shelfContext = shelfContext
    }
}

public struct TranscriptLine: Sendable, Hashable {
    public let speaker: String
    public let text: String
    public let offset: TimeInterval

    public init(speaker: String, text: String, offset: TimeInterval) {
        self.speaker = speaker
        self.text = text
        self.offset = offset
    }
}

public enum SummarizationError: Error, Sendable {
    case modelUnavailable
    case contextExceeded(tokenEstimate: Int)
    case refusedByGuardrails
}

// MARK: - Structured output

#if canImport(FoundationModels)

/// Guided generation is mandatory (RFC §3). We never ask a 3B on-device model
/// for prose and then parse structure back out of it — we ask for the structure
/// directly. This is the single change that makes on-device summarisation
/// viable for F-12 rather than a demo.
@Generable
public struct GeneratedDigest: Sendable {
    @Guide(description: "Three to five sentences on what the conversation was actually about. No preamble, no 'In this meeting'.")
    public var summary: String

    @Guide(description: "Decisions that were actually settled. Empty if nothing was settled — do not invent closure.")
    public var decisions: [String]

    @Guide(description: "Commitments someone made out loud.")
    public var actionItems: [GeneratedAction]

    @Guide(description: "Questions raised and left unanswered.")
    public var openQuestions: [String]
}

@Generable
public struct GeneratedAction: Sendable {
    @Guide(description: "The commitment, as a short imperative sentence.")
    public var text: String

    @Guide(description: "Who owes it, ONLY if a name was said aloud. Otherwise leave empty.")
    public var assignee: String

    @Guide(description: "When it is due, ONLY if a date or deadline was said aloud. Otherwise leave empty.")
    public var due: String
}

#endif

/// Framework-independent result. What the app stores and renders.
public struct MeetingDigest: Sendable, Hashable {
    public var summary: String
    public var decisions: [String]
    public var actionItems: [ExtractedAction]
    public var openQuestions: [String]
    /// Rendered from the Recipe's sections, in the Recipe's order.
    public var markdown: String
    public var tier: EnhancementTier

    public init(
        summary: String,
        decisions: [String],
        actionItems: [ExtractedAction],
        openQuestions: [String],
        markdown: String,
        tier: EnhancementTier
    ) {
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.markdown = markdown
        self.tier = tier
    }
}

public struct ExtractedAction: Sendable, Hashable {
    public var text: String
    public var assignee: String?
    public var dueDate: Date?
    public var sourceOffset: TimeInterval?

    public init(text: String, assignee: String? = nil, dueDate: Date? = nil, sourceOffset: TimeInterval? = nil) {
        self.text = text
        self.assignee = assignee
        self.dueDate = dueDate
        self.sourceOffset = sourceOffset
    }
}

// MARK: - Primary: Apple Foundation Models, on device

/// The default summarizer: Apple's on-device LLM via the Foundation Models
/// framework (evidence E-9). Free, offline, and the reason `PRD §8` can promise
/// unlimited AI notes on the free tier while Granola meters history at
/// 30 days (E-1).
public actor FoundationModelsSummarizer: Summarizer {
    public nonisolated let tier: EnhancementTier = .onDevice

    /// Conservative ceiling before we switch to map-reduce. Better to chunk one
    /// meeting too eagerly than to lose the back half of a long one.
    private let contextTokenBudget = 3_500

    public init() {}

    public var isAvailable: Bool {
        get async {
            #if canImport(FoundationModels)
            if case .available = SystemLanguageModel.default.availability { return true }
            return false
            #else
            return false
            #endif
        }
    }

    public func summarize(_ input: SummarizationInput) async throws -> MeetingDigest {
        #if canImport(FoundationModels)
        guard await isAvailable else { throw SummarizationError.modelUnavailable }

        let estimate = TokenEstimate.forInput(input)
        if estimate > contextTokenBudget {
            return try await ChunkedSummarizer(base: self).summarize(input)
        }

        let session = LanguageModelSession(instructions: Self.instructions(for: input))
        let response = try await session.respond(
            to: Self.prompt(for: input),
            generating: GeneratedDigest.self
        )
        return Self.digest(from: response.content, recipe: input.recipe, tier: .onDevice)
        #else
        throw SummarizationError.modelUnavailable
        #endif
    }

    #if canImport(FoundationModels)
    static func instructions(for input: SummarizationInput) -> String {
        var text = """
        You help someone finish the notes they took during a conversation.

        Rules you must not break:
        - The user's own notes are the spine of the output. Fill their gaps. \
        Never contradict them, never reword them, never replace their framing with yours.
        - Only state what was actually said. If a decision was not reached, say it was not reached. \
        Never invent an owner or a deadline that nobody spoke aloud.
        - Plain, specific language. No corporate filler, no "the team discussed", no summary of the summary.
        """

        if !input.moments.isEmpty {
            // Moments are hard anchors (WATCH §4) — they are the moments the
            // user physically reached for their wrist to mark.
            let stamps = input.moments.map { Self.timestamp($0) }.joined(separator: ", ")
            text += "\n- The user marked these timestamps as important: \(stamps). \
            Every one of them must be reflected somewhere in your output."
        }

        if let shelf = input.shelfContext, !shelf.isEmpty {
            text += "\n\nStanding context for this project:\n\(shelf)"
        }

        let sectionBrief = input.recipe.sections
            .map { "- \($0.title): \($0.instruction)" }
            .joined(separator: "\n")
        text += "\n\nThe finished note has these sections:\n\(sectionBrief)"

        return text
    }

    static func prompt(for input: SummarizationInput) -> String {
        let lines = input.transcript
            .map { "[\(Self.timestamp($0.offset))] \($0.speaker): \($0.text)" }
            .joined(separator: "\n")

        let notes = input.userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        // F-15: a meeting where the user typed nothing still has to work.
        let notesBlock = notes.isEmpty
            ? "(The user did not type any notes. Work from the transcript alone.)"
            : notes

        return """
        Conversation: \(input.title)

        THE USER'S OWN NOTES:
        \(notesBlock)

        TRANSCRIPT:
        \(lines)
        """
    }

    static func digest(from generated: GeneratedDigest, recipe: Recipe, tier: EnhancementTier) -> MeetingDigest {
        let actions = generated.actionItems.map { action in
            ExtractedAction(
                text: action.text,
                assignee: action.assignee.isEmpty ? nil : action.assignee,
                dueDate: DatePhrase.parse(action.due)
            )
        }
        let digest = MeetingDigest(
            summary: generated.summary,
            decisions: generated.decisions,
            actionItems: actions,
            openQuestions: generated.openQuestions,
            markdown: "",
            tier: tier
        )
        return MarkdownRenderer.render(digest, recipe: recipe)
    }
    #endif

    static func timestamp(_ offset: TimeInterval) -> String {
        let total = Int(offset.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Long conversations

/// Map-reduce for transcripts past the model's context (RFC §3, ladder rung 4).
///
/// Windows the transcript, summarises each window, then reduces the window
/// digests. Every window containing a Moment carries that Moment's instruction,
/// and the reduce pass is forbidden from dropping one.
public struct ChunkedSummarizer: Summarizer {
    public let tier: EnhancementTier = .onDeviceChunked
    private let base: FoundationModelsSummarizer
    private let windowSeconds: TimeInterval = 600

    public init(base: FoundationModelsSummarizer) {
        self.base = base
    }

    public var isAvailable: Bool {
        get async { await base.isAvailable }
    }

    public func summarize(_ input: SummarizationInput) async throws -> MeetingDigest {
        let windows = Self.windows(of: input.transcript, seconds: windowSeconds)
        var partials: [MeetingDigest] = []

        for window in windows {
            let momentsHere = input.moments.filter { moment in
                guard let first = window.first, let last = window.last else { return false }
                return moment >= first.offset && moment <= last.offset
            }
            let slice = SummarizationInput(
                title: input.title,
                userNotes: input.userNotes,
                transcript: window,
                moments: momentsHere,
                recipe: input.recipe,
                shelfContext: input.shelfContext
            )
            partials.append(try await base.summarize(slice))
        }

        return Self.reduce(partials, recipe: input.recipe)
    }

    static func windows(of lines: [TranscriptLine], seconds: TimeInterval) -> [[TranscriptLine]] {
        guard let start = lines.first?.offset else { return [] }
        var result: [[TranscriptLine]] = []
        var current: [TranscriptLine] = []
        var windowStart = start

        for line in lines {
            if line.offset - windowStart > seconds, !current.isEmpty {
                result.append(current)
                current = []
                windowStart = line.offset
            }
            current.append(line)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Union, not re-summarisation — re-summarising summaries is where detail
    /// goes to die, and it is exactly how a marked Moment gets dropped.
    static func reduce(_ partials: [MeetingDigest], recipe: Recipe) -> MeetingDigest {
        let digest = MeetingDigest(
            summary: partials.map(\.summary).joined(separator: " "),
            decisions: partials.flatMap(\.decisions).deduplicated(),
            actionItems: partials.flatMap(\.actionItems).deduplicated(by: \.text),
            openQuestions: partials.flatMap(\.openQuestions).deduplicated(),
            markdown: "",
            tier: .onDeviceChunked
        )
        return MarkdownRenderer.render(digest, recipe: recipe)
    }
}

enum TokenEstimate {
    /// Deliberately pessimistic (~3.5 chars/token). Chunking one meeting too
    /// eagerly costs a second; overflowing context loses the end of a meeting.
    static func forInput(_ input: SummarizationInput) -> Int {
        let chars = input.userNotes.count
            + input.transcript.reduce(0) { $0 + $1.text.count + $1.speaker.count + 12 }
            + (input.shelfContext?.count ?? 0)
        return Int(Double(chars) / 3.5)
    }
}

extension Array where Element: Hashable {
    func deduplicated() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    func deduplicated<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(key($0)).inserted }
    }
}

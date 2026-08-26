import Foundation

/// The honest floor of the quality ladder (RFC §6, rung 3).
///
/// No LLM. Deterministic extraction over the transcript. Runs on any device,
/// in any locale, offline, in milliseconds. Less fluent than the on-device
/// model and the UI says so in those words (F-14) — but it never fabricates,
/// and being deterministic it is the only summarizer we can hold to golden-file
/// tests (RFC §8), which makes it the regression baseline for the whole
/// intelligence layer.
public struct TemplateSummarizer: Summarizer {
    public let tier: EnhancementTier = .template
    public var isAvailable: Bool { get async { true } }

    public init() {}

    public func summarize(_ input: SummarizationInput) async throws -> MeetingDigest {
        let sentences = input.transcript.flatMap { line in
            Self.sentences(in: line.text).map { (text: $0, offset: line.offset, speaker: line.speaker) }
        }

        let decisions = sentences
            .filter { Self.decisionCues.matches($0.text) }
            .map { Self.tidy($0.text) }
            .deduplicated()

        let actions = sentences
            .filter { Self.commitmentCues.matches($0.text) }
            .map { candidate in
                ExtractedAction(
                    text: Self.tidy(candidate.text),
                    assignee: Self.assignee(in: candidate.text, speaker: candidate.speaker),
                    dueDate: DatePhrase.parse(candidate.text),
                    sourceOffset: candidate.offset
                )
            }
            .deduplicated(by: \.text)

        let questions = sentences
            .filter { $0.text.hasSuffix("?") }
            .map { Self.tidy($0.text) }
            .deduplicated()

        // Moments are hard anchors, so the lines around each one are always
        // carried into the summary even when no cue phrase fired.
        let anchored = input.moments.compactMap { moment in
            input.transcript
                .min(by: { abs($0.offset - moment) < abs($1.offset - moment) })
                .map { Self.tidy($0.text) }
        }

        let opening = input.userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryParts = ([opening.isEmpty ? nil : opening] + anchored.map { "Marked: \($0)" })
            .compactMap { $0 }
        let summary = summaryParts.isEmpty
            ? "A \(Int(input.transcript.last?.offset ?? 0) / 60)-minute conversation. No decisions or commitments were detected."
            : summaryParts.joined(separator: "\n\n")

        let digest = MeetingDigest(
            summary: summary,
            decisions: Array(decisions.prefix(12)),
            actionItems: Array(actions.prefix(20)),
            openQuestions: Array(questions.prefix(10)),
            markdown: "",
            tier: .template
        )
        return MarkdownRenderer.render(digest, recipe: input.recipe)
    }

    // MARK: Cues

    /// Phrases that reliably precede a settled decision in spoken English.
    /// Tuned against the 20-transcript corpus in `Tests/Corpus` — changes here
    /// must be justified by a measured change in that corpus, not by intuition.
    static let decisionCues = CueSet([
        "we'll go with", "we will go with", "let's go with", "we decided",
        "we've decided", "the decision is", "we're going to", "we are going with",
        "agreed", "sounds like a plan", "that's settled", "final answer",
        "we're not going to", "we'll hold off", "let's park"
    ])

    static let commitmentCues = CueSet([
        "i'll", "i will", "i can", "let me", "i'm going to",
        "can you", "could you", "you'll", "please", "we need to",
        "action item", "take that away", "i'll follow up", "send me",
        "by friday", "by monday", "by the end of", "before the"
    ])

    struct CueSet {
        let cues: [String]
        init(_ cues: [String]) { self.cues = cues }
        func matches(_ text: String) -> Bool {
            let lower = text.lowercased()
            return cues.contains { lower.contains($0) }
        }
    }

    static func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 12 }
    }

    static func tidy(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip the verbal throat-clearing that makes extracted lines unreadable.
        for filler in ["um ", "uh ", "you know ", "i mean ", "like, "] where s.lowercased().hasPrefix(filler) {
            s = String(s.dropFirst(filler.count))
        }
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    /// Only returns a name when one was actually spoken. `nil` beats a guess —
    /// a fabricated owner is the fastest way to lose trust in extraction
    /// altogether (see `ActionItem`).
    static func assignee(in text: String, speaker: String) -> String? {
        let lower = text.lowercased()
        if lower.hasPrefix("i'll") || lower.hasPrefix("i will") || lower.hasPrefix("i can") {
            return speaker
        }
        if let range = lower.range(of: "can you"), range.lowerBound == lower.startIndex {
            return nil // addressed to someone, but who was not stated in words
        }
        return nil
    }
}

/// Renders a digest through a Recipe's sections, in the Recipe's order.
public enum MarkdownRenderer {
    public static func render(_ digest: MeetingDigest, recipe: Recipe) -> MeetingDigest {
        var out = digest
        var lines: [String] = []

        for section in recipe.sections {
            let body = content(for: section, digest: digest)
            if body.isEmpty && !section.isRequired { continue }
            lines.append("## \(section.title)")
            lines.append(body.isEmpty ? "_Nothing recorded._" : body)
            lines.append("")
        }

        out.markdown = lines.joined(separator: "\n")
        return out
    }

    /// Sections are matched by title against the digest's known fields, and a
    /// Recipe's custom section falls back to the summary rather than rendering
    /// blank — a custom Recipe should never produce a worse note than Standard.
    private static func content(for section: Recipe.Section, digest: MeetingDigest) -> String {
        let title = section.title.lowercased()
        switch true {
        case title.contains("decision"):
            return digest.decisions.map { "- \($0)" }.joined(separator: "\n")
        case title.contains("action"), title.contains("committed"), title.contains("next"):
            return digest.actionItems.map { item in
                var line = "- [ ] \(item.text)"
                if let who = item.assignee { line += " — **\(who)**" }
                if let when = item.dueDate {
                    line += " _(\(when.formatted(date: .abbreviated, time: .omitted)))_"
                }
                return line
            }.joined(separator: "\n")
        case title.contains("question"), title.contains("open"), title.contains("revisit"):
            return digest.openQuestions.map { "- \($0)" }.joined(separator: "\n")
        default:
            return digest.summary
        }
    }
}

/// Parses only the date phrasings people actually say out loud in meetings.
/// Returns `nil` for anything ambiguous — see `ActionItem`: an invented
/// deadline is worse than no deadline.
public enum DatePhrase {
    public static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return nil }

        if lower.contains("today") { return calendar.startOfDay(for: now) }
        if lower.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        if lower.contains("next week") {
            return calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))
        }
        if lower.contains("end of the month") || lower.contains("end of month") {
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return nil }
            return calendar.date(byAdding: .day, value: -1, to: interval.end)
        }

        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                        "thursday": 5, "friday": 6, "saturday": 7]
        for (name, index) in weekdays where lower.contains(name) {
            var components = DateComponents()
            components.weekday = index
            return calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            )
        }

        // Fall back to the system detector, which handles "March 3rd" and
        // "the 14th" across locales far better than anything hand-rolled.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = detector.firstMatch(in: text, range: range), let date = match.date {
                return date
            }
        }
        return nil
    }
}

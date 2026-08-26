import Foundation

/// An output template: which sections a finished note has, and how each is
/// written.
///
/// Canon: PRD F-13. Matches Granola's Recipes, and adds auto-selection so the
/// right template is chosen without the user remembering to pick it.
public struct Recipe: Sendable, Codable, Hashable, Identifiable {
    public static let standardID = "builtin.standard"

    public let id: String
    public var name: String
    public var sections: [Section]
    public var isBuiltIn: Bool
    /// Rules that pick this Recipe automatically. First match wins, evaluated
    /// in the user's ordering.
    public var autoSelect: [AutoSelectRule]

    public struct Section: Sendable, Codable, Hashable, Identifiable {
        public let id: String
        public var title: String
        /// Passed to the summarizer as the instruction for this section only.
        /// Keep each one narrow — a 3B on-device model does far better with
        /// five small asks than one large one (RFC §3).
        public var instruction: String
        public var isRequired: Bool

        public init(id: String = UUID().uuidString, title: String, instruction: String, isRequired: Bool = true) {
            self.id = id
            self.title = title
            self.instruction = instruction
            self.isRequired = isRequired
        }
    }

    public enum AutoSelectRule: Sendable, Codable, Hashable {
        case titleContains(String)
        case attendeeCountAtMost(Int)
        case attendeeCountAtLeast(Int)
        case shelfNamed(String)

        public func matches(title: String, attendeeCount: Int, shelfName: String?) -> Bool {
            switch self {
            case .titleContains(let needle):
                return title.localizedCaseInsensitiveContains(needle)
            case .attendeeCountAtMost(let n):
                return attendeeCount <= n
            case .attendeeCountAtLeast(let n):
                return attendeeCount >= n
            case .shelfNamed(let name):
                return shelfName?.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        sections: [Section],
        isBuiltIn: Bool = false,
        autoSelect: [AutoSelectRule] = []
    ) {
        self.id = id
        self.name = name
        self.sections = sections
        self.isBuiltIn = isBuiltIn
        self.autoSelect = autoSelect
    }
}

public extension Recipe {
    /// The three that ship free (PRD §8). Custom Recipes are the Pro upsell —
    /// convenience and depth, never access to your own data.
    static let builtIns: [Recipe] = [.standard, .oneToOne, .interview]

    static let standard = Recipe(
        id: Recipe.standardID,
        name: "Standard",
        sections: [
            .init(title: "Summary",
                  instruction: "Three to five sentences on what this conversation was actually about. No preamble."),
            .init(title: "Decisions",
                  instruction: "Only decisions that were actually settled. If nothing was settled, say so."),
            .init(title: "Action items",
                  instruction: "Commitments someone made. Include who and when only if it was stated aloud."),
            .init(title: "Open questions",
                  instruction: "Questions raised and left unanswered.", isRequired: false)
        ],
        isBuiltIn: true
    )

    static let oneToOne = Recipe(
        id: "builtin.oneToOne",
        name: "1:1",
        sections: [
            .init(title: "What they raised",
                  instruction: "Topics the other person brought up, in their framing, not yours."),
            .init(title: "What I committed to",
                  instruction: "Only commitments made by the note-taker."),
            .init(title: "To revisit next time",
                  instruction: "Threads left open, to open with next time.", isRequired: false),
            .init(title: "Signals",
                  instruction: "Anything said about morale, workload, or career. Quote, do not interpret.",
                  isRequired: false)
        ],
        isBuiltIn: true,
        autoSelect: [.titleContains("1:1"), .titleContains("one-on-one"), .attendeeCountAtMost(2)]
    )

    static let interview = Recipe(
        id: "builtin.interview",
        name: "Interview",
        sections: [
            .init(title: "Background",
                  instruction: "The candidate's relevant experience as they described it."),
            .init(title: "Evidence",
                  instruction: "Specific claims with the example given. Quote where possible; never embellish."),
            .init(title: "Concerns",
                  instruction: "Gaps or hesitations, tied to what was actually said.", isRequired: false),
            .init(title: "Questions for next round",
                  instruction: "What is still unknown after this conversation.", isRequired: false)
        ],
        isBuiltIn: true,
        autoSelect: [.titleContains("interview"), .titleContains("screen")]
    )

    /// First matching rule wins; falls back to Standard. Never surprises the
    /// user silently — the chosen Recipe is named on the review screen and is
    /// one tap to change.
    static func autoSelected(
        from recipes: [Recipe],
        title: String,
        attendeeCount: Int,
        shelfName: String?
    ) -> Recipe {
        for recipe in recipes {
            for rule in recipe.autoSelect
            where rule.matches(title: title, attendeeCount: attendeeCount, shelfName: shelfName) {
                return recipe
            }
        }
        return .standard
    }
}

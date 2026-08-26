import SwiftUI

/// Canon: P3-design/DESIGN_SYSTEM.md §2. Nothing in the app hardcodes a colour,
/// a font, or a spacing value.
public enum Tokens {

    // MARK: Colour

    public enum Palette {
        /// The user's own words. The highest-contrast ink in the app.
        public static let ink = Color("ink", bundle: .module)
        /// AI-authored text — deliberately one step back. This is the F-11
        /// guarantee made visible: at a glance you can see which words are yours.
        public static let graphite = Color("graphite", bundle: .module)
        public static let paper = Color("paper", bundle: .module)
        public static let card = Color("card", bundle: .module)
        public static let rule = Color("rule", bundle: .module)
        /// Recording, Moments, undelivered items. Nothing else — the accent
        /// means something only because it is rationed.
        public static let accent = Color("accent", bundle: .module)
        public static let sent = Color("sent", bundle: .module)
    }

    // MARK: Type

    /// Serif for the human, sans for the machine. This split survives
    /// greyscale, Dynamic Type, and screenshots — it is the most robust signal
    /// we have for "these are your words, those are not".
    public enum Typography {
        public static let noteBody = Font.system(.body, design: .serif)
        public static let machineBody = Font.system(.body, design: .default)
        public static let transcriptBody = Font.system(.callout, design: .default)
        public static let timestamp = Font.system(.caption, design: .monospaced)
        public static let sectionTitle = Font.system(.headline, design: .default)
    }

    // MARK: Space — 4pt scale, no magic numbers

    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let card: CGFloat = 14
        public static let chip: CGFloat = 7
    }

    /// The Moment button must be reachable and hittable without looking.
    /// Floor, not a target (DESIGN_SYSTEM §4.3).
    public static let momentButtonSize: CGFloat = 64
}

/// The recording indicator. A trust surface, not decoration (F-5), so
/// `reduceMotion` swaps the pulse for a static filled dot — never for nothing.
public struct RecordingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    public init() {}

    public var body: some View {
        Circle()
            .fill(Tokens.Palette.accent)
            .frame(width: 10, height: 10)
            .opacity(reduceMotion ? 1 : (pulsing ? 1 : 0.45))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
            .accessibilityLabel("Recording")
    }
}

/// Machine-authored text. Carries the VoiceOver prefix that gives non-visual
/// users the same signal the serif/sans split gives sighted ones (PRD §10).
public struct MachineText: View {
    private let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(Tokens.Typography.machineBody)
            .foregroundStyle(Tokens.Palette.graphite)
            .accessibilityLabel("Added by Earshot: \(text)")
    }
}

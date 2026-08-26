import Foundation

/// Recording etiquette and law, treated as a product surface rather than a
/// legal disclaimer buried in Settings.
///
/// Canon: PRD F-5. No competitor in the 2026 field does this, and it is the
/// single most common reason people are nervous about carrying one of these
/// apps into a room. Getting it right is cheap; getting it wrong is the kind of
/// mistake that ends a product.
public enum Consent {

    /// Regions where all parties to a conversation must consent to recording.
    /// Deliberately over-inclusive: a needless prompt costs a tap, a missing
    /// one can cost the user their job.
    ///
    /// Not legal advice, and the app says so in those words. Reviewed each
    /// release; see canon/P4-technical/PRIVACY.md.
    public static let allPartyRegions: Set<String> = [
        // US two-party-consent states
        "US-CA", "US-DE", "US-FL", "US-IL", "US-MD", "US-MA", "US-MI",
        "US-MT", "US-NV", "US-NH", "US-OR", "US-PA", "US-WA",
        // Countries with broadly equivalent requirements
        "DE", "FR", "AT", "CH", "NL", "BE", "ES", "IT", "PL", "SE",
        "DK", "FI", "NO", "IE", "PT", "CZ", "JP", "KR", "AU-VIC", "AU-WA", "CA-QC"
    ]

    public static func requiresEveryTimePrompt(
        region: String? = Locale.current.region?.identifier,
        subdivision: String? = nil,
        userHandlesItThemselves: Bool
    ) -> Bool {
        if userHandlesItThemselves { return false }
        guard let region else { return true } // Unknown region → ask. Fail safe.
        if let subdivision, allPartyRegions.contains("\(region)-\(subdivision)") { return true }
        return allPartyRegions.contains(region)
    }

    /// A sentence to read aloud. Short enough that saying it isn't awkward,
    /// specific enough to be real consent.
    public static let scriptToReadAloud = """
    I'm taking notes with an app that transcribes on my phone — nothing gets \
    uploaded, and I can turn it off. Is that alright with everyone?
    """

    public static let disclaimer = """
    Recording laws vary by where you and the people you're talking to are. \
    Earshot flags places where everyone usually has to agree, but this isn't \
    legal advice and the responsibility is yours.
    """
}

/// Every byte that has ever left the device, per note.
///
/// Canon: PRD F-18, F-27, RFC §7.
///
/// This is a direct inversion of E-4, where the incumbent shares notes to
/// anyone-with-the-link by default and leaves model-training on by default even
/// on paid tiers. The empty state of this screen is the *goal* state, and the
/// copy says so: "Nothing has ever left this device. That's the idea."
public struct PrivacyLedger: Sendable {
    public struct Entry: Sendable, Hashable, Identifiable {
        public let id: UUID
        public let noteTitle: String
        public let target: String
        public let at: Date
        public let summary: String
        public let leftTheDevice: Bool

        public init(id: UUID, noteTitle: String, target: String, at: Date, summary: String, leftTheDevice: Bool) {
            self.id = id
            self.noteTitle = noteTitle
            self.target = target
            self.at = at
            self.summary = summary
            self.leftTheDevice = leftTheDevice
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public init(notes: [Note]) {
        self.entries = notes.flatMap { note in
            note.receipts.map { receipt in
                Entry(
                    id: receipt.id,
                    noteTitle: note.resolvedTitle,
                    target: receipt.targetName,
                    at: receipt.deliveredAt,
                    summary: receipt.payloadSummary,
                    leftTheDevice: receipt.leftTheDevice
                )
            }
        }
        .sorted { $0.at > $1.at }
    }

    /// The number the screen leads with. Usually zero, and that is the point.
    public var networkEntries: [Entry] { entries.filter(\.leftTheDevice) }

    public var hasEverLeftTheDevice: Bool { !networkEntries.isEmpty }

    /// The commitment behind F-25. There is no toggle for this, because a
    /// toggle implies a default, and a default implies it was once otherwise.
    public static let trainingPolicy = """
    Earshot has never trained a model on anything you said, written, or \
    recorded, and there is no setting to change that. There is no setting \
    because there is nothing to turn off.
    """
}

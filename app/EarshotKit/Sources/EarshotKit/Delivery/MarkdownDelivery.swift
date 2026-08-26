import Foundation

/// Writes one `.md` file per note to a user-chosen folder — an Obsidian vault,
/// iCloud Drive, anywhere in Files.
///
/// Free tier, deliberately. Export is a right, not a feature (F-23): the user's
/// own words must always have an exit that we cannot revoke in a later release.
/// This is the direct answer to E-1, where the incumbent's rebrand put a
/// 30-day wall in front of people's own history.
public actor MarkdownDelivery: DeliveryTarget {
    public nonisolated let id = "target.markdown"
    public nonisolated let displayName = "Markdown file"
    public nonisolated let leavesTheDevice = false
    public nonisolated let requiredTier: Tier = .free

    /// Security-scoped bookmark to the folder the user picked once.
    private let folderBookmark: Data?

    public init(folderBookmark: Data?) {
        self.folderBookmark = folderBookmark
    }

    public func preview(_ payload: DeliveryPayload) async throws -> DeliveryPreview {
        let folder = try resolveFolder()
        return DeliveryPreview(
            lines: ["\(Self.filename(for: payload)) — \(Self.render(payload).count) characters"],
            destination: folder.lastPathComponent,
            networkWarning: nil
        )
    }

    public func deliver(_ payload: DeliveryPayload) async throws -> DeliveryResult {
        let folder = try resolveFolder()
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

        let url = folder.appendingPathComponent(Self.filename(for: payload))
        try Self.render(payload).write(to: url, atomically: true, encoding: .utf8)

        return DeliveryResult(
            itemCount: 1,
            payloadSummary: "Wrote \(url.lastPathComponent) to \(folder.lastPathComponent). Stayed on this iPhone."
        )
    }

    private func resolveFolder() throws -> URL {
        guard let folderBookmark else { throw DeliveryError.notConfigured }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: folderBookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale { throw DeliveryError.notConfigured }
        return url
    }

    static func filename(for payload: DeliveryPayload) -> String {
        let date = payload.date.formatted(.iso8601.year().month().day())
        let safe = payload.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = safe.isEmpty ? "Conversation" : String(safe.prefix(60))
        return "\(date) \(stem).md"
    }

    /// YAML front matter so the file is useful in Obsidian/Logseq immediately,
    /// and open enough that leaving Earshot costs the user nothing.
    static func render(_ payload: DeliveryPayload) -> String {
        var out = """
        ---
        title: "\(payload.title)"
        date: \(payload.date.formatted(.iso8601))
        source: earshot
        id: \(payload.noteID.uuidString)
        ---

        # \(payload.title)

        """
        out += payload.markdown

        if !payload.acceptedActions.isEmpty {
            out += "\n\n## Committed\n"
            for action in payload.acceptedActions {
                var line = "- [ ] \(action.text)"
                if let who = action.assignee { line += " — **\(who)**" }
                if let due = action.dueDate {
                    line += " 📅 \(due.formatted(.iso8601.year().month().day()))"
                }
                out += line + "\n"
            }
        }
        return out
    }
}

/// Runs the rules and writes the receipts.
///
/// One rule this type enforces above all: **a target's first use always goes
/// through the preview sheet**, no matter what the rule says (F-17). Automation
/// is something the user grants after seeing what happens, never something they
/// discover afterwards.
public struct DeliveryCoordinator: Sendable {
    private let targets: [String: any DeliveryTarget]

    public init(targets: [any DeliveryTarget]) {
        self.targets = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0) })
    }

    public func target(id: String) -> (any DeliveryTarget)? { targets[id] }

    public func preview(_ payload: DeliveryPayload, targetID: String) async throws -> DeliveryPreview {
        guard let target = targets[targetID] else { throw DeliveryError.notConfigured }
        return try await target.preview(payload)
    }

    /// Returns the rules that may fire without asking, and those that must
    /// stop at the preview sheet first.
    public func partition(
        rules: [DeliveryRule],
        shelfID: UUID?,
        recipeID: String,
        tier: Tier
    ) -> (automatic: [DeliveryRule], needsConfirmation: [DeliveryRule]) {
        let applicable = rules.filter { rule in
            guard rule.applies(shelfID: shelfID, recipeID: recipeID) else { return false }
            guard let target = targets[rule.targetID] else { return false }
            return target.requiredTier == .free || tier == .pro
        }
        return (
            automatic: applicable.filter(\.confirmedOnce),
            needsConfirmation: applicable.filter { !$0.confirmedOnce }
        )
    }

    public func deliver(_ payload: DeliveryPayload, targetID: String) async throws -> (DeliveryResult, DeliveryReceipt) {
        guard let target = targets[targetID] else { throw DeliveryError.notConfigured }
        let result = try await target.deliver(payload)
        let receipt = DeliveryReceipt(
            targetID: target.id,
            targetName: target.displayName,
            itemCount: result.itemCount,
            payloadSummary: result.payloadSummary,
            leftTheDevice: target.leavesTheDevice
        )
        return (result, receipt)
    }
}

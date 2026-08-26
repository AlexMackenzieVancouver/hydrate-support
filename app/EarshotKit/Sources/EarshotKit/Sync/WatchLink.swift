import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// The only channel between wrist and phone.
///
/// Canon: WATCH_ARCHITECTURE.md §2, §7.
///
/// The state-ownership rule this type exists to make structurally true:
/// **the phone owns every Note; the Watch owns nothing but in-flight audio.**
/// The Watch's vocabulary here is `append` and `hand off`. There is no verb on
/// this actor by which a Watch can author, edit, or delete a note — which
/// eliminates watch/phone divergence by construction rather than by discipline.
public actor WatchLink: NSObject {
    public enum Role: Sendable { case phone, watch }

    public struct PendingCapture: Sendable, Codable, Hashable {
        public let id: UUID
        public let startedAt: Date
        public var chunkFilenames: [String]
        public var moments: [TimeInterval]
        public var duration: TimeInterval

        public init(
            id: UUID = UUID(),
            startedAt: Date = .now,
            chunkFilenames: [String] = [],
            moments: [TimeInterval] = [],
            duration: TimeInterval = 0
        ) {
            self.id = id
            self.startedAt = startedAt
            self.chunkFilenames = chunkFilenames
            self.moments = moments
            self.duration = duration
        }
    }

    /// Compact enough for `updateApplicationContext`, which has a hard size
    /// limit and drops intermediate values. Action items only, truncated —
    /// the wrist gets the decision, not the document (WATCH §5).
    public struct WatchReviewPayload: Sendable, Codable, Hashable {
        public struct Item: Sendable, Codable, Hashable {
            public let id: UUID
            public let text: String
            public init(id: UUID, text: String) {
                self.id = id
                self.text = String(text.prefix(60))
            }
        }
        public let noteID: UUID
        public let title: String
        public let items: [Item]

        public init(noteID: UUID, title: String, items: [Item]) {
            self.noteID = noteID
            self.title = String(title.prefix(40))
            self.items = Array(items.prefix(8))
        }
    }

    private let role: Role
    private var onCaptureChunk: (@Sendable (UUID, URL) async -> Void)?
    private var onCaptureMetadata: (@Sendable (PendingCapture) async -> Void)?
    private var onReviewDecisions: (@Sendable (UUID, [UUID: ReviewState]) async -> Void)?
    private var onReviewPayload: (@Sendable (WatchReviewPayload) async -> Void)?

    /// Chunks the phone has confirmed. The Watch deletes local audio only for
    /// IDs in this set — an un-acked chunk survives reboot and retries
    /// indefinitely, and storage pressure never wins against one (WATCH §2).
    private var acknowledgedChunks: Set<String> = []

    public init(role: Role) {
        self.role = role
        super.init()
    }

    public func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    // MARK: Handlers (set by whichever app target owns this link)

    public func onCaptureChunk(_ handler: @escaping @Sendable (UUID, URL) async -> Void) {
        onCaptureChunk = handler
    }

    public func onCaptureMetadata(_ handler: @escaping @Sendable (PendingCapture) async -> Void) {
        onCaptureMetadata = handler
    }

    public func onReviewDecisions(_ handler: @escaping @Sendable (UUID, [UUID: ReviewState]) async -> Void) {
        onReviewDecisions = handler
    }

    public func onReviewPayload(_ handler: @escaping @Sendable (WatchReviewPayload) async -> Void) {
        onReviewPayload = handler
    }

    // MARK: Watch → phone

    /// Queued, background-safe, and survives the app being killed. Transfers
    /// resume when the phone comes back in range — the Watch never surfaces a
    /// range error mid-conversation (WATCH §7).
    public func sendChunk(_ url: URL, captureID: UUID) {
        #if canImport(WatchConnectivity)
        WCSession.default.transferFile(url, metadata: [
            "captureID": captureID.uuidString,
            "kind": "audioChunk"
        ])
        #endif
    }

    public func sendCaptureMetadata(_ capture: PendingCapture) {
        #if canImport(WatchConnectivity)
        guard let data = try? JSONEncoder().encode(capture) else { return }
        WCSession.default.transferUserInfo(["kind": "captureMetadata", "payload": data])
        #endif
    }

    public func sendReviewDecisions(noteID: UUID, decisions: [UUID: ReviewState]) {
        #if canImport(WatchConnectivity)
        let encoded = decisions.reduce(into: [String: String]()) { $0[$1.key.uuidString] = $1.value.rawValue }
        guard let data = try? JSONSerialization.data(withJSONObject: encoded) else { return }
        WCSession.default.transferUserInfo([
            "kind": "reviewDecisions",
            "noteID": noteID.uuidString,
            "payload": data
        ])
        #endif
    }

    // MARK: Phone → watch

    public func acknowledge(chunkNamed name: String) {
        acknowledgedChunks.insert(name)
        #if canImport(WatchConnectivity)
        try? WCSession.default.updateApplicationContext([
            "kind": "chunkAck",
            "acked": Array(acknowledgedChunks)
        ])
        #endif
    }

    public func sendReviewPayload(_ payload: WatchReviewPayload) {
        #if canImport(WatchConnectivity)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? WCSession.default.updateApplicationContext(["kind": "review", "payload": data])
        #endif
    }

    public func isAcknowledged(_ name: String) -> Bool { acknowledgedChunks.contains(name) }

    // MARK: Receiving

    fileprivate func handleFile(_ url: URL, metadata: [String: Any]) async {
        guard let raw = metadata["captureID"] as? String, let id = UUID(uuidString: raw) else { return }
        await onCaptureChunk?(id, url)
    }

    fileprivate func handleUserInfo(_ info: [String: Any]) async {
        switch info["kind"] as? String {
        case "captureMetadata":
            guard let data = info["payload"] as? Data,
                  let capture = try? JSONDecoder().decode(PendingCapture.self, from: data) else { return }
            await onCaptureMetadata?(capture)

        case "reviewDecisions":
            guard let data = info["payload"] as? Data,
                  let raw = info["noteID"] as? String,
                  let noteID = UUID(uuidString: raw),
                  let map = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
            var decisions: [UUID: ReviewState] = [:]
            for (key, value) in map {
                if let id = UUID(uuidString: key), let state = ReviewState(rawValue: value) {
                    decisions[id] = state
                }
            }
            await onReviewDecisions?(noteID, decisions)

        default:
            break
        }
    }

    fileprivate func handleContext(_ context: [String: Any]) async {
        switch context["kind"] as? String {
        case "chunkAck":
            if let acked = context["acked"] as? [String] {
                acknowledgedChunks.formUnion(acked)
            }
        case "review":
            guard let data = context["payload"] as? Data,
                  let payload = try? JSONDecoder().decode(WatchReviewPayload.self, from: data) else { return }
            await onReviewPayload?(payload)
        default:
            break
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchLink: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {}

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The transferred file is deleted when this returns, so copy it out
        // before hopping actors.
        let metadata = file.metadata ?? [:]
        let inbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("inbox-\(UUID().uuidString).caf")
        try? FileManager.default.copyItem(at: file.fileURL, to: inbox)
        Task { await handleFile(inbox, metadata: metadata) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { await handleUserInfo(userInfo) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { await handleContext(context) }
    }
}
#endif

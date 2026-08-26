import Foundation
import StoreKit
import Observation

/// What the user has paid for — and, more importantly, what they can never be
/// charged for later.
///
/// Canon: PRD §8, STRATEGY_BRIEF "Monetization".
///
/// The free tier here is not a trial. E-1 is the loudest complaint in this
/// category: the incumbent's rebrand put a 30-day wall in front of people's own
/// notes. Earshot's answer is structural — the free capabilities below run
/// entirely on-device at zero marginal cost (E-8, E-9, E-10), so there is
/// nothing to meter even if we wanted to.
public enum Feature: String, CaseIterable, Sendable {
    // Free forever. This list is frozen by canon.
    case unlimitedMeetings
    case unlimitedHistory
    case onDeviceNotes
    case diarization
    case voicePrints
    case moments
    case builtInRecipes
    case remindersDelivery
    case markdownDelivery
    case fullExport
    case watchApp

    // Pro: convenience and reach, never access to your own data.
    case threads
    case preRead
    case customRecipes
    case calendarDelivery
    case mailDelivery
    case webhookDelivery
    case crossDeviceSync
    case longRecordingEscalation

    public var tier: Tier {
        switch self {
        case .unlimitedMeetings, .unlimitedHistory, .onDeviceNotes, .diarization,
             .voicePrints, .moments, .builtInRecipes, .remindersDelivery,
             .markdownDelivery, .fullExport, .watchApp:
            return .free
        case .threads, .preRead, .customRecipes, .calendarDelivery, .mailDelivery,
             .webhookDelivery, .crossDeviceSync, .longRecordingEscalation:
            return .pro
        }
    }
}

@MainActor
@Observable
public final class Entitlements {
    public private(set) var tier: Tier = .free
    public private(set) var products: [Product] = []

    public static let monthlyID = "com.earshot.pro.monthly"
    public static let yearlyID = "com.earshot.pro.yearly"

    private var updatesTask: Task<Void, Never>?

    public init() {}

    public func can(_ feature: Feature) -> Bool {
        feature.tier == .free || tier == .pro
    }

    public func start() async {
        await refresh()
        // StoreKit 2 directly — no third-party SDK. Canon: RFC §9, which
        // records the deviation from the ios-app-os RevenueCat default and why
        // (two products, iOS-only in v1, and a privacy requirement a
        // third-party SDK complicates).
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    public func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                active = transaction.revocationDate == nil
            }
        }
        tier = active ? .pro : .free
    }

    public func loadProducts() async {
        products = (try? await Product.products(for: [Self.monthlyID, Self.yearlyID])) ?? []
    }

    public func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result, case .verified(let transaction) = verification {
            await transaction.finish()
            await refresh()
        }
    }

    deinit { updatesTask?.cancel() }
}

/// Shown in Settings, verbatim, and enforced in CI.
///
/// `monetization-guardian` diffs `Feature.tier` against PRD §8 on every commit.
/// A free capability moving to Pro fails the build — which is the point: the
/// promise is only worth making if it is mechanically impossible to quietly
/// break later (E-5).
public enum PricingPromise {
    public static let text = """
    Everything Earshot can do on your iPhone, it does for free — unlimited \
    conversations, unlimited history, unlimited AI notes, forever. Not a trial. \
    Not a 30-day window on your own past.

    We can promise that because the AI runs on your iPhone and costs us nothing \
    per minute.

    Pro adds reach: asking questions across your whole archive, briefs before \
    meetings, custom templates, and pushing notes to Calendar, Mail, and your own \
    tools. Nothing that works today will move behind that paywall in a later \
    release.
    """
}

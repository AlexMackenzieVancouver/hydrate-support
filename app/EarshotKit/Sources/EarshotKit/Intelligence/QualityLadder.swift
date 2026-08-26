import Foundation

/// Resolves which summarizer is in effect, and — just as importantly — what
/// the user is told about it.
///
/// Canon: RFC §6, PRD F-14. The rule this type exists to enforce: **the app
/// states the tier in effect for any note not produced on-device by the primary
/// model.** A silent downgrade is a defect, not a compromise. So is a silent
/// upload.
public struct QualityLadder: Sendable {
    public enum Rung: Sendable, Equatable {
        /// Apple Intelligence available. The intended path.
        case onDevice
        /// Device capable, model still downloading. Queue the note; tell the user.
        case modelDownloading
        /// Device can't run the on-device model. Deterministic extraction.
        case templateOnly
        /// User explicitly opted this note into their own cloud model.
        case remoteBYOK
    }

    public let rung: Rung

    public init(rung: Rung) {
        self.rung = rung
    }

    /// Resolved once at launch, re-checked when model availability changes.
    public static func resolve(
        foundationModels: FoundationModelsSummarizer = .init(),
        userOptedIntoRemote: Bool = false
    ) async -> QualityLadder {
        if userOptedIntoRemote { return .init(rung: .remoteBYOK) }
        if await foundationModels.isAvailable { return .init(rung: .onDevice) }
        #if canImport(FoundationModels)
        // Distinguish "not capable" from "not ready yet" — they need different
        // sentences, and telling a capable device it isn't is a lie the user
        // will discover.
        if SystemLanguageModelProbe.isDownloading { return .init(rung: .modelDownloading) }
        #endif
        return .init(rung: .templateOnly)
    }

    public func makeSummarizer() -> any Summarizer {
        switch rung {
        case .onDevice, .modelDownloading:
            return FoundationModelsSummarizer()
        case .templateOnly:
            return TemplateSummarizer()
        case .remoteBYOK:
            return TemplateSummarizer() // Replaced by RemoteSummarizer in IMPL-11.
        }
    }

    /// Shown verbatim on the note. `nil` only for the intended path.
    /// Copy is fixed in DESIGN_SYSTEM.md §6 — do not improvise it per-screen.
    public var disclosure: String? {
        switch rung {
        case .onDevice:
            return nil
        case .modelDownloading:
            return "The on-device model is still downloading. Your notes will finish themselves when it lands — nothing was sent anywhere."
        case .templateOnly:
            return "This iPhone can't run the on-device model, so Earshot is using plain extraction — accurate, just less fluent. Nothing was sent anywhere."
        case .remoteBYOK:
            return "Summarised by your own cloud model. The transcript left this iPhone."
        }
    }

    /// True when the user must see an explicit, itemised confirmation before
    /// anything runs (F-17, F-24). Only ever true for the remote rung.
    public var requiresUploadConfirmation: Bool { rung == .remoteBYOK }
}

#if canImport(FoundationModels)
import FoundationModels

enum SystemLanguageModelProbe {
    static var isDownloading: Bool {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            return reason == .modelNotReady
        }
        return false
    }
}
#endif

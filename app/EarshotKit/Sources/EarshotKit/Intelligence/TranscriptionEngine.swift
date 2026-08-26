import Foundation
import AVFoundation

#if canImport(Speech)
import Speech
#endif

/// Streaming, on-device speech-to-text.
///
/// Canon: RFC §3, PRD F-3. Every implementation must be free and local — no
/// per-minute cost anywhere in this protocol's conformances, because Bet 1 of
/// the strategy brief collapses the moment transcription has a marginal price.
public protocol TranscriptionEngine: Sendable {
    /// True when this engine can run right now on this device.
    var isAvailable: Bool { get async }

    /// Streams hypotheses as they arrive. Volatile results are emitted with
    /// `isFinal == false` so the live pane can render them at reduced opacity
    /// rather than appearing to rewrite itself under the reader.
    func transcribe(
        _ audio: AsyncStream<AVAudioPCMBuffer>
    ) -> AsyncThrowingStream<TranscriptChunk, Error>

    /// Batch path, used for Watch captures that arrive after the fact and for
    /// recovery of an interrupted capture (F-6).
    func transcribeFile(at url: URL) async throws -> [TranscriptChunk]
}

public struct TranscriptChunk: Sendable, Hashable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let isFinal: Bool

    public init(text: String, start: TimeInterval, end: TimeInterval, isFinal: Bool) {
        self.text = text
        self.start = start
        self.end = end
        self.isFinal = isFinal
    }
}

public enum TranscriptionError: Error, Sendable {
    case unavailableOnThisDevice
    case localeUnsupported(Locale)
    case modelNotInstalled
    case audioFormatUnsupported
}

// MARK: - Primary: Apple SpeechAnalyzer (iOS 26+)

/// The default engine. `SpeechAnalyzer` + `SpeechTranscriber` is Apple's
/// long-form on-device ASR, explicitly built for meetings and conversations
/// (evidence E-8). No model download, no network, no per-minute cost.
///
/// This is the single fact that makes the free tier in `STRATEGY_BRIEF.md`
/// economically possible rather than charitable.
public actor SpeechAnalyzerEngine: TranscriptionEngine {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public var isAvailable: Bool {
        get async {
            #if canImport(Speech)
            // Availability is a function of locale support and whether the
            // asset for that locale has been installed.
            return await Self.assetInstalled(for: locale)
            #else
            return false
            #endif
        }
    }

    #if canImport(Speech)
    private static func assetInstalled(for locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            return false
        }
        let installed = await SpeechTranscriber.installedLocales
        return installed.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
    }

    /// Requests the on-device asset if the locale is supported but not yet
    /// installed. Corresponds to rung 2 of the quality ladder (RFC §6): we
    /// queue the note and tell the user it will be ready when the model is,
    /// rather than silently falling back.
    public func ensureModelInstalled() async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
    #endif

    public func transcribe(
        _ audio: AsyncStream<AVAudioPCMBuffer>
    ) -> AsyncThrowingStream<TranscriptChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                #if canImport(Speech)
                do {
                    let transcriber = SpeechTranscriber(
                        locale: self.locale,
                        preset: .progressiveTranscription
                    )
                    let analyzer = SpeechAnalyzer(modules: [transcriber])

                    let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
                    try await analyzer.start(inputSequence: inputSequence)

                    // Feed the recorder's buffers in. The audio tap itself does
                    // no work beyond enqueueing (RFC §5) — this is where the
                    // hop off the real-time thread has already happened.
                    let pump = Task {
                        for await buffer in audio {
                            inputBuilder.yield(AnalyzerInput(buffer: buffer))
                        }
                        inputBuilder.finish()
                    }

                    for try await result in transcriber.results {
                        let range = result.range
                        continuation.yield(
                            TranscriptChunk(
                                text: String(result.text.characters),
                                start: range.start.seconds,
                                end: range.end.seconds,
                                isFinal: result.isFinal
                            )
                        )
                    }

                    await pump.value
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: TranscriptionError.unavailableOnThisDevice)
                #endif
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func transcribeFile(at url: URL) async throws -> [TranscriptChunk] {
        #if canImport(Speech)
        let file = try AVAudioFile(forReading: url)
        let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        var chunks: [TranscriptChunk] = []
        let collector = Task {
            for try await result in transcriber.results where result.isFinal {
                chunks.append(
                    TranscriptChunk(
                        text: String(result.text.characters),
                        start: result.range.start.seconds,
                        end: result.range.end.seconds,
                        isFinal: true
                    )
                )
            }
        }

        try await analyzer.analyzeSequence(from: file)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await collector.value
        return chunks
        #else
        throw TranscriptionError.unavailableOnThisDevice
        #endif
    }
}

// MARK: - Fallback

/// Fallback engine for devices or locales `SpeechAnalyzer` doesn't cover,
/// backed by Parakeet TDT v3 on the Neural Engine via FluidAudio (MIT /
/// Apache-2.0, evidence E-10).
///
/// Wired behind the same protocol so the quality ladder stays a composition
/// decision rather than branching scattered through the views (RFC §3).
public actor FluidAudioEngine: TranscriptionEngine {
    public init() {}

    public var isAvailable: Bool {
        get async { true }
    }

    public func transcribe(
        _ audio: AsyncStream<AVAudioPCMBuffer>
    ) -> AsyncThrowingStream<TranscriptChunk, Error> {
        // Implementation lands in IMPL-04 (see P5-implementation/BACKLOG.md).
        // Deliberately not stubbed with fake output: an engine that silently
        // returns nothing is worse than one that reports unavailability, and
        // F-14 forbids silent degradation.
        AsyncThrowingStream { $0.finish(throwing: TranscriptionError.modelNotInstalled) }
    }

    public func transcribeFile(at url: URL) async throws -> [TranscriptChunk] {
        throw TranscriptionError.modelNotInstalled
    }
}

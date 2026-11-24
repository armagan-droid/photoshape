import CompositionKit
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writes the card's short summary with Apple's on-device language model (spec 05 Hikâye 9, Constitution 2.1.0).
/// Only `SystemLanguageModel`, which runs on the device; Private Cloud Compute is never used (FR-024).
/// Returns nil whenever the model is missing, not ready or does not speak the language, or when its answer fails
/// the check twice (9.2, 9.3). The card is complete without a summary.
enum ExampleSummaryWriter {
    static func write(_ input: ExampleSummaryInput) async -> String? {
        guard !input.isEmpty else { return nil }
        #if DEBUG
        // UI tests: a fixed answer goes through the same check; or no model at all.
        if let stub = UserDefaults.standard.string(forKey: "UITestSummary") {
            return SummaryChecker.isAcceptable(stub, input: input) ? stub : nil
        }
        if UserDefaults.standard.bool(forKey: "DisableExampleSummary") { return nil }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return await writeWithModel(input) }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func writeWithModel(_ input: ExampleSummaryInput) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            Diagnostics.log("summary: model unavailable \(model.availability)")
            return nil
        }
        guard model.supportsLocale(Locale(identifier: input.language)) else {
            Diagnostics.log("summary: language \(input.language) not supported")
            return nil
        }
        // First try the most likely answer; the retry samples a little (9.3).
        let attempts = [GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 160),
                        GenerationOptions(temperature: 0.5, maximumResponseTokens: 160)]
        for options in attempts {
            let session = LanguageModelSession(model: model, instructions: input.instructions)
            do {
                let text = try await session.respond(to: input.prompt, options: options).content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let problems = SummaryChecker.problems(text, input: input)
                Diagnostics.log("summary: \(problems.isEmpty ? "ok" : "rejected \(problems)") \(text)")
                if problems.isEmpty { return text }
            } catch {
                Diagnostics.log("summary: failed \(error)")
                return nil
            }
        }
        return nil
    }
    #endif
}

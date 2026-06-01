import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum CaptureCoachRunSource: String, Codable, Equatable, Sendable {
    case foundationModels
    case deterministicFallback
}

struct CaptureCoachRun: Codable, Equatable, Sendable {
    let source: CaptureCoachRunSource
    let response: CaptureCoachResponse
    let fallbackReason: String?
}

protocol CaptureCoachModelGenerating: Sendable {
    func response(for request: CaptureCoachRequest) async throws -> CaptureCoachResponse
}

struct CaptureCoachEngine: Sendable {
    private let makeModelGenerator: @Sendable () -> (any CaptureCoachModelGenerating)?

    init(
        makeModelGenerator: @escaping @Sendable () -> (any CaptureCoachModelGenerating)? = { nil }
    ) {
        self.makeModelGenerator = makeModelGenerator
    }

    func response(for request: CaptureCoachRequest) async -> CaptureCoachRun {
        guard request.context.intelligence.isUsable else {
            return deterministicRun(
                for: request,
                reason: "Apple Intelligence unavailable: \(request.context.intelligence.status)"
            )
        }

        guard let modelGenerator = makeModelGenerator() else {
            return deterministicRun(
                for: request,
                reason: "Foundation Models provider unavailable in this runtime."
            )
        }

        do {
            let modelResponse = try await modelGenerator.response(for: request)
            let validated = CaptureCoachResponseValidator.validated(modelResponse, for: request)
            guard !validated.suggestions.isEmpty else {
                return deterministicRun(
                    for: request,
                    reason: "Foundation Models returned no actionable capture suggestions."
                )
            }
            return CaptureCoachRun(
                source: .foundationModels,
                response: validated,
                fallbackReason: nil
            )
        } catch {
            return deterministicRun(
                for: request,
                reason: "Foundation Models failed: \(error.localizedDescription)"
            )
        }
    }

    private func deterministicRun(
        for request: CaptureCoachRequest,
        reason: String
    ) -> CaptureCoachRun {
        CaptureCoachRun(
            source: .deterministicFallback,
            response: DeterministicCaptureCoach.response(for: request),
            fallbackReason: reason
        )
    }
}

extension CaptureCoachEngine {
    static var live: CaptureCoachEngine {
        CaptureCoachEngine {
            #if canImport(FoundationModels) && !targetEnvironment(simulator)
            if #available(iOS 26.0, *) {
                return FoundationModelsCaptureCoachGenerator()
            }
            #endif
            return nil
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A concise capture-coach response for an exposure-bracketing camera app.")
struct FoundationModelsCaptureCoachPayload: Sendable {
    @Guide(description: "Whether the generated response used the on-device Apple Intelligence model.")
    var usedAppleIntelligence: Bool

    @Guide(description: "One to five concise camera guidance suggestions.", .count(1...5))
    var suggestions: [FoundationModelsCaptureCoachSuggestion]
}

@available(iOS 26.0, *)
@Generable(description: "One concise, actionable camera-coaching suggestion.")
struct FoundationModelsCaptureCoachSuggestion: Sendable {
    @Guide(description: "Suggestion priority.", .anyOf(["info", "warning", "critical"]))
    var priority: String

    @Guide(description: "A short title, ideally three words or fewer.")
    var title: String

    @Guide(description: "Why this suggestion matters, grounded only in the structured context.")
    var rationale: String

    @Guide(description: "A concrete action the photographer can take now.")
    var action: String

    @Guide(description: "Structured source signals used for this suggestion.", .maximumCount(5))
    var sourceSignals: [String]
}

@available(iOS 26.0, *)
struct FoundationModelsCaptureCoachGenerator: CaptureCoachModelGenerating {
    private let model: SystemLanguageModel
    private let options: GenerationOptions

    init(
        model: SystemLanguageModel = .default,
        options: GenerationOptions = GenerationOptions(
            sampling: .greedy,
            temperature: 0.1,
            maximumResponseTokens: 700
        )
    ) {
        self.model = model
        self.options = options
    }

    func response(for request: CaptureCoachRequest) async throws -> CaptureCoachResponse {
        let session = LanguageModelSession(
            model: model,
            instructions: request.systemInstruction
        )
        let response = try await session.respond(
            to: request.userPrompt,
            generating: FoundationModelsCaptureCoachPayload.self,
            includeSchemaInPrompt: true,
            options: options
        )
        return response.content.captureCoachResponse(for: request)
    }
}

@available(iOS 26.0, *)
private extension FoundationModelsCaptureCoachPayload {
    func captureCoachResponse(for request: CaptureCoachRequest) -> CaptureCoachResponse {
        CaptureCoachResponse(
            schemaVersion: CaptureCoachResponse.currentSchemaVersion,
            task: request.task,
            usedAppleIntelligence: true,
            availabilityStatus: request.context.intelligence.status,
            suggestions: suggestions.map(\.captureCoachSuggestion),
            disclosure: ""
        )
    }
}

@available(iOS 26.0, *)
private extension FoundationModelsCaptureCoachSuggestion {
    var captureCoachSuggestion: CaptureCoachSuggestion {
        CaptureCoachSuggestion(
            priority: CaptureCoachSuggestion.Priority(rawValue: priority.lowercased()) ?? .info,
            title: title,
            rationale: rationale,
            action: action,
            sourceSignals: sourceSignals
        )
    }
}
#endif

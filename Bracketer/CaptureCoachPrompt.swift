import Foundation

enum CaptureCoachTask: String, Codable, Equatable, Sendable {
    case preCaptureGuidance
    case reviewNarrative
}

struct CaptureCoachRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let task: CaptureCoachTask
    let maxSuggestions: Int
    let context: CaptureContextSummary
    let systemInstruction: String
    let userPrompt: String

    static func make(
        task: CaptureCoachTask,
        context: CaptureContextSummary,
        maxSuggestions: Int = 3
    ) -> CaptureCoachRequest {
        let resolvedMaxSuggestions = min(max(maxSuggestions, 1), 5)
        return CaptureCoachRequest(
            schemaVersion: Self.currentSchemaVersion,
            task: task,
            maxSuggestions: resolvedMaxSuggestions,
            context: context,
            systemInstruction: Self.systemInstruction,
            userPrompt: Self.userPrompt(task: task, context: context, maxSuggestions: resolvedMaxSuggestions)
        )
    }

    private static let systemInstruction = """
    You are Bracketer's local capture coach. Use only the structured context provided by the app. Do not claim to inspect raw photos, Photos asset identifiers, precise coordinates, or data that is not present in the context. Return concise, actionable camera guidance.
    """

    private static func userPrompt(
        task: CaptureCoachTask,
        context: CaptureContextSummary,
        maxSuggestions: Int
    ) -> String {
        """
        Task: \(task.rawValue)
        Max suggestions: \(maxSuggestions)
        Context:
        \(context.compactPromptContext)
        """
    }
}

struct CaptureCoachSuggestion: Codable, Equatable, Sendable {
    enum Priority: String, Codable, Equatable, Sendable {
        case info
        case warning
        case critical
    }

    let priority: Priority
    let title: String
    let rationale: String
    let action: String
    let sourceSignals: [String]
}

struct CaptureCoachResponse: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let task: CaptureCoachTask
    let usedAppleIntelligence: Bool
    let availabilityStatus: String
    let suggestions: [CaptureCoachSuggestion]
    let disclosure: String
}

enum CaptureCoachResponseValidator {
    static func validated(
        _ response: CaptureCoachResponse,
        for request: CaptureCoachRequest
    ) -> CaptureCoachResponse {
        let filteredSuggestions = response.suggestions
            .filter { suggestion in
                !suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !suggestion.action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .prefix(request.maxSuggestions)

        return CaptureCoachResponse(
            schemaVersion: CaptureCoachResponse.currentSchemaVersion,
            task: request.task,
            usedAppleIntelligence: request.context.intelligence.isUsable && response.usedAppleIntelligence,
            availabilityStatus: request.context.intelligence.status,
            suggestions: Array(filteredSuggestions),
            disclosure: Self.disclosure(for: request.context)
        )
    }

    private static func disclosure(for context: CaptureContextSummary) -> String {
        if context.privacy.rawPhotoBytesIncluded
            || context.privacy.assetIdentifiersIncluded
            || context.privacy.locationCoordinatesIncluded {
            return "Generated from expanded capture data; review privacy-sensitive details before sharing."
        }

        return "Generated from structured camera state only; no raw photo bytes, asset identifiers, or precise coordinates were included."
    }
}

enum DeterministicCaptureCoach {
    static func response(for request: CaptureCoachRequest) -> CaptureCoachResponse {
        let context = request.context
        var suggestions: [CaptureCoachSuggestion] = []

        if context.frameAnalysis.hasHighlightWarning {
            suggestions.append(CaptureCoachSuggestion(
                priority: .warning,
                title: "Protect highlights",
                rationale: "The structured frame analysis reports \(context.frameAnalysis.highlightClippingPercent)% highlight clipping.",
                action: "Lower exposure compensation or bias the bracket center downward before capture.",
                sourceSignals: ["highlight clipping"]
            ))
        }

        if context.frameAnalysis.hasShadowWarning {
            suggestions.append(CaptureCoachSuggestion(
                priority: .warning,
                title: "Lift shadow detail",
                rationale: "The structured frame analysis reports \(context.frameAnalysis.shadowClippingPercent)% shadow clipping.",
                action: "Raise exposure compensation slightly or keep a wider bracket around the center exposure.",
                sourceSignals: ["shadow clipping"]
            ))
        }

        if context.frameAnalysis.isAvailable,
           context.settings.focusPeakingEnabled,
           context.frameAnalysis.focusRegionCount == 0 {
            suggestions.append(CaptureCoachSuggestion(
                priority: .info,
                title: "Check focus contrast",
                rationale: "Focus peaking is enabled, but the structured analysis did not find strong edge regions.",
                action: "Tap the subject edge or increase focus peaking sensitivity before starting the bracket.",
                sourceSignals: ["focus peaking"]
            ))
        }

        if !context.intelligence.isUsable {
            suggestions.append(CaptureCoachSuggestion(
                priority: .info,
                title: "Apple Intelligence unavailable",
                rationale: context.intelligence.detail,
                action: context.intelligence.recoveryAction ?? "Continue with deterministic capture guidance.",
                sourceSignals: ["apple intelligence availability"]
            ))
        }

        if suggestions.isEmpty {
            suggestions.append(CaptureCoachSuggestion(
                priority: .info,
                title: "Ready to capture",
                rationale: "The structured context does not report exposure, focus, device, or intelligence blockers.",
                action: "Start the bracket and review the manifest after capture.",
                sourceSignals: ["capture context"]
            ))
        }

        let response = CaptureCoachResponse(
            schemaVersion: CaptureCoachResponse.currentSchemaVersion,
            task: request.task,
            usedAppleIntelligence: false,
            availabilityStatus: context.intelligence.status,
            suggestions: suggestions,
            disclosure: ""
        )

        return CaptureCoachResponseValidator.validated(response, for: request)
    }
}

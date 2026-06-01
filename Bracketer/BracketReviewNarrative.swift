import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct BracketNarrativeContext: Codable, Equatable, Sendable {
    struct Intelligence: Codable, Equatable, Sendable {
        let status: String
        let detail: String
        let recoveryAction: String?
        let isUsable: Bool

        init(availability: IntelligenceFeatureAvailability) {
            status = availability.statusTitle
            detail = availability.statusDetail
            recoveryAction = availability.recoveryAction
            isUsable = availability.isUsable
        }
    }

    struct Privacy: Codable, Equatable, Sendable {
        let rawPhotoBytesIncluded: Bool
        let assetIdentifiersIncluded: Bool
        let locationCoordinatesIncluded: Bool
        let userVisibleGeneratedCopy: Bool
        let notes: [String]
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let manifestSource: String
    let manifestSchemaVersion: Int
    let capturedAt: Date
    let shotCount: Int
    let exposureSpreadLabel: String
    let evLabels: [String]
    let selectedPosition: String?
    let selectedEVLabel: String?
    let bestExposureLabel: String?
    let missingShotCount: Int
    let failedShotCount: Int
    let rawAvailableCount: Int
    let processedAvailableCount: Int
    let fileTypes: [String]
    let clippingWarnings: [String]
    let recipeTitle: String?
    let recipeSource: String?
    let intelligence: Intelligence
    let privacy: Privacy

    static func make(
        manifest: BracketManifest,
        sequence: BracketReviewSequence?,
        intelligenceAvailability: IntelligenceFeatureAvailability
    ) -> BracketNarrativeContext {
        let evLabels = manifest.shots.map(\.displayLabel)
        let exposureSpreadLabel: String
        if let first = evLabels.first, let last = evLabels.last {
            exposureSpreadLabel = "\(first) to \(last)"
        } else {
            exposureSpreadLabel = "No exposure labels"
        }

        return BracketNarrativeContext(
            schemaVersion: Self.currentSchemaVersion,
            manifestSource: manifest.source.rawValue,
            manifestSchemaVersion: manifest.schemaVersion,
            capturedAt: manifest.capturedAt,
            shotCount: manifest.shots.count,
            exposureSpreadLabel: exposureSpreadLabel,
            evLabels: evLabels,
            selectedPosition: sequence?.selectedPositionLabel,
            selectedEVLabel: sequence?.selectedShot?.displayLabel,
            bestExposureLabel: manifest.shots.first(where: \.isBestExposureCandidate)?.displayLabel,
            missingShotCount: manifest.shots.filter { $0.captureState == "Missing" }.count,
            failedShotCount: manifest.shots.filter { $0.captureState.localizedCaseInsensitiveContains("failed") }.count,
            rawAvailableCount: manifest.shots.filter { $0.availableRepresentations.contains("RAW") }.count,
            processedAvailableCount: manifest.shots.filter { $0.availableRepresentations.contains("Processed") }.count,
            fileTypes: manifest.shots.map(\.fileType).uniquePreservingOrder(),
            clippingWarnings: manifest.shots
                .flatMap(\.clippingWarnings)
                .uniquePreservingOrder(),
            recipeTitle: manifest.recipe?.title,
            recipeSource: manifest.recipe?.source,
            intelligence: Intelligence(availability: intelligenceAvailability),
            privacy: Privacy(
                rawPhotoBytesIncluded: false,
                assetIdentifiersIncluded: false,
                locationCoordinatesIncluded: false,
                userVisibleGeneratedCopy: false,
                notes: [
                    "Manifest and review sequence fields only",
                    "No raw image pixels",
                    "No Photos asset identifiers",
                    "No precise location coordinates"
                ]
            )
        )
    }

    var compactPromptContext: String {
        promptFacts.joined(separator: "\n")
    }

    var promptFacts: [String] {
        var facts = [
            "Manifest: schema \(manifestSchemaVersion), source \(manifestSource), \(shotCount) shots.",
            "Exposure spread: \(exposureSpreadLabel); EV labels \(evLabels.joined(separator: ", ")).",
            "Best exposure candidate: \(bestExposureLabel ?? "unknown").",
            "Current selection: \(selectedPosition ?? "none")\(selectedEVLabel.map { " at \($0)" } ?? "").",
            "Availability: \(missingShotCount) missing, \(failedShotCount) failed, RAW available for \(rawAvailableCount), processed available for \(processedAvailableCount).",
            "File types: \(fileTypes.isEmpty ? "unknown" : fileTypes.joined(separator: ", ")).",
            "Clipping warnings: \(clippingWarnings.isEmpty ? "none" : clippingWarnings.joined(separator: ", ")).",
            "Apple Intelligence: \(intelligence.status). \(intelligence.detail)",
            "Privacy: no raw photo bytes, no asset identifiers, no location coordinates, no user-visible generated copy."
        ]

        if let recipeTitle {
            facts.append("Applied recipe: \(recipeTitle) from \(recipeSource ?? "unknown source").")
        } else {
            facts.append("Applied recipe: none.")
        }

        return facts
    }
}

struct BracketReviewNarrativeRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let context: BracketNarrativeContext
    let systemInstruction: String
    let userPrompt: String

    static func make(context: BracketNarrativeContext) -> BracketReviewNarrativeRequest {
        BracketReviewNarrativeRequest(
            schemaVersion: Self.currentSchemaVersion,
            context: context,
            systemInstruction: Self.systemInstruction,
            userPrompt: Self.userPrompt(context: context)
        )
    }

    private static let systemInstruction = """
    You are Bracketer's local review narrator. Use only the structured manifest and review context. Do not claim to inspect raw pixels, Photos asset identifiers, exact coordinates, lens data, ISO, shutter speed, aperture, or metadata that is not present. Return a concise review explanation for an exposure-bracket sequence.
    """

    private static func userPrompt(context: BracketNarrativeContext) -> String {
        """
        Task: reviewNarrative
        Context:
        \(context.compactPromptContext)
        """
    }
}

struct BracketReviewNarrativeResponse: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let usedAppleIntelligence: Bool
    let availabilityStatus: String
    let title: String
    let summary: String
    let mergeAdvice: String
    let warnings: [String]
    let tags: [String]
    let disclosure: String

    var accessibilityValue: String {
        var parts = [
            title,
            summary,
            "Advice: \(mergeAdvice)"
        ]
        if !warnings.isEmpty {
            parts.append("Warnings: \(warnings.joined(separator: ", "))")
        }
        if !tags.isEmpty {
            parts.append("Tags: \(tags.joined(separator: ", "))")
        }
        parts.append(usedAppleIntelligence ? "Generated with Apple Intelligence" : "Deterministic review")
        return parts.joined(separator: " | ")
    }
}

enum BracketReviewNarrativeResponseValidator {
    static func validated(
        _ response: BracketReviewNarrativeResponse,
        for request: BracketReviewNarrativeRequest
    ) -> BracketReviewNarrativeResponse {
        BracketReviewNarrativeResponse(
            schemaVersion: BracketReviewNarrativeResponse.currentSchemaVersion,
            usedAppleIntelligence: request.context.intelligence.isUsable && response.usedAppleIntelligence,
            availabilityStatus: request.context.intelligence.status,
            title: clean(response.title, fallback: "Bracket review"),
            summary: clean(response.summary, fallback: defaultSummary(for: request.context)),
            mergeAdvice: clean(response.mergeAdvice, fallback: defaultMergeAdvice(for: request.context)),
            warnings: response.warnings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)
                .map { String($0) },
            tags: response.tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(6)
                .map { String($0) },
            disclosure: disclosure(for: request.context)
        )
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func defaultSummary(for context: BracketNarrativeContext) -> String {
        "Reviewing \(context.shotCount) planned exposures from \(context.exposureSpreadLabel)."
    }

    private static func defaultMergeAdvice(for context: BracketNarrativeContext) -> String {
        if context.missingShotCount > 0 || context.failedShotCount > 0 {
            return "Resolve missing or failed shots before treating this as a complete HDR merge source."
        }
        return "Keep the manifest with any exported merge or archive."
    }

    private static func disclosure(for context: BracketNarrativeContext) -> String {
        if context.privacy.rawPhotoBytesIncluded
            || context.privacy.assetIdentifiersIncluded
            || context.privacy.locationCoordinatesIncluded {
            return "Generated from expanded review data; inspect privacy-sensitive details before sharing."
        }

        return "Generated from manifest and review state only; no raw photo bytes, asset identifiers, or precise coordinates were included."
    }
}

enum DeterministicBracketReviewNarrative {
    static func response(for request: BracketReviewNarrativeRequest) -> BracketReviewNarrativeResponse {
        let context = request.context
        let bestExposure = context.bestExposureLabel ?? "the closest-to-center exposure"
        let selected = selectedSummary(for: context)
        var summary = "Reviewed \(context.shotCount) planned exposures from \(context.exposureSpreadLabel); best exposure candidate is \(bestExposure). \(selected)"
        if let recipeTitle = context.recipeTitle {
            summary += " Recipe: \(recipeTitle) from \(context.recipeSource ?? "unknown source")."
        }

        let response = BracketReviewNarrativeResponse(
            schemaVersion: BracketReviewNarrativeResponse.currentSchemaVersion,
            usedAppleIntelligence: false,
            availabilityStatus: context.intelligence.status,
            title: title(for: context),
            summary: summary,
            mergeAdvice: mergeAdvice(for: context),
            warnings: warnings(for: context),
            tags: tags(for: context),
            disclosure: ""
        )

        return BracketReviewNarrativeResponseValidator.validated(response, for: request)
    }

    static func run(for request: BracketReviewNarrativeRequest, fallbackReason: String) -> BracketReviewNarrativeRun {
        BracketReviewNarrativeRun(
            source: .deterministicFallback,
            response: response(for: request),
            fallbackReason: fallbackReason
        )
    }

    private static func title(for context: BracketNarrativeContext) -> String {
        if context.missingShotCount > 0 || context.failedShotCount > 0 {
            return "Partial \(context.shotCount)-shot bracket"
        }
        return "\(context.shotCount)-shot \(context.manifestSource) bracket"
    }

    private static func selectedSummary(for context: BracketNarrativeContext) -> String {
        guard let selectedPosition = context.selectedPosition else {
            return "No review shot is selected."
        }
        if let selectedEVLabel = context.selectedEVLabel {
            return "Current selection is \(selectedPosition) at \(selectedEVLabel)."
        }
        return "Current selection is \(selectedPosition)."
    }

    private static func mergeAdvice(for context: BracketNarrativeContext) -> String {
        if context.missingShotCount > 0 || context.failedShotCount > 0 {
            return "Do not treat this as a complete HDR source until missing or failed shots are resolved."
        }
        if !context.clippingWarnings.isEmpty {
            return "Use the center shot as merge anchor and inspect clipped edge exposures before export."
        }
        if context.rawAvailableCount > 0 {
            return "Prefer RAW representations for merge/export and keep the manifest with the output."
        }
        return "Use processed files for a quick proof and keep the manifest with the output."
    }

    private static func warnings(for context: BracketNarrativeContext) -> [String] {
        var warnings: [String] = []
        if context.missingShotCount > 0 {
            warnings.append("\(context.missingShotCount) planned shots are missing")
        }
        if context.failedShotCount > 0 {
            warnings.append("\(context.failedShotCount) planned shots failed")
        }
        warnings.append(contentsOf: context.clippingWarnings)
        return warnings.uniquePreservingOrder()
    }

    private static func tags(for context: BracketNarrativeContext) -> [String] {
        var tags = [
            "\(context.shotCount) shots",
            context.manifestSource,
            context.rawAvailableCount > 0 ? "RAW available" : "processed only"
        ]
        if let recipeTitle = context.recipeTitle {
            tags.append("recipe: \(recipeTitle)")
        }
        return tags
    }
}

enum BracketReviewNarrativeRunSource: String, Codable, Equatable, Sendable {
    case foundationModels
    case deterministicFallback
}

struct BracketReviewNarrativeRun: Codable, Equatable, Sendable {
    let source: BracketReviewNarrativeRunSource
    let response: BracketReviewNarrativeResponse
    let fallbackReason: String?

    var sourceLabel: String {
        if source == .foundationModels && response.usedAppleIntelligence {
            return "Generated with Apple Intelligence"
        }
        return "Deterministic review"
    }

    var accessibilityValue: String {
        "\(sourceLabel) | \(response.accessibilityValue)"
    }
}

protocol BracketReviewNarrativeModelGenerating: Sendable {
    func response(for request: BracketReviewNarrativeRequest) async throws -> BracketReviewNarrativeResponse
}

struct BracketReviewNarrativeEngine: Sendable {
    private let makeModelGenerator: @Sendable () -> (any BracketReviewNarrativeModelGenerating)?

    init(
        makeModelGenerator: @escaping @Sendable () -> (any BracketReviewNarrativeModelGenerating)? = { nil }
    ) {
        self.makeModelGenerator = makeModelGenerator
    }

    func response(for request: BracketReviewNarrativeRequest) async -> BracketReviewNarrativeRun {
        guard request.context.intelligence.isUsable else {
            return DeterministicBracketReviewNarrative.run(
                for: request,
                fallbackReason: "Apple Intelligence unavailable: \(request.context.intelligence.status)"
            )
        }

        guard let modelGenerator = makeModelGenerator() else {
            return DeterministicBracketReviewNarrative.run(
                for: request,
                fallbackReason: "Foundation Models review narrator unavailable in this runtime."
            )
        }

        do {
            let modelResponse = try await modelGenerator.response(for: request)
            let validated = BracketReviewNarrativeResponseValidator.validated(modelResponse, for: request)
            return BracketReviewNarrativeRun(
                source: .foundationModels,
                response: validated,
                fallbackReason: nil
            )
        } catch {
            return DeterministicBracketReviewNarrative.run(
                for: request,
                fallbackReason: "Foundation Models failed: \(error.localizedDescription)"
            )
        }
    }
}

extension BracketReviewNarrativeEngine {
    static var live: BracketReviewNarrativeEngine {
        BracketReviewNarrativeEngine {
            #if canImport(FoundationModels) && !targetEnvironment(simulator)
            if #available(iOS 26.0, *) {
                return FoundationModelsBracketReviewNarrativeGenerator()
            }
            #endif
            return nil
        }
    }
}

struct BracketReviewNarrativeCard: View {
    let run: BracketReviewNarrativeRun
    let isLoading: Bool
    let onRegenerate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.response.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .accessibilityIdentifier("review.narrative.title")

                    Text(run.sourceLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(run.response.usedAppleIntelligence ? .green : .white.opacity(0.58))
                        .accessibilityIdentifier("review.narrative.source")
                }

                Spacer()

                Button(action: onRegenerate) {
                    Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .disabled(isLoading)
                .accessibilityLabel("Regenerate review narrative")
                .accessibilityIdentifier("review.narrative.regenerate")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.72))
                .accessibilityLabel("Dismiss review narrative")
                .accessibilityIdentifier("review.narrative.dismiss")
            }

            Text(run.response.summary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .accessibilityIdentifier("review.narrative.summary")

            Text(run.response.mergeAdvice)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.yellow.opacity(0.9))
                .accessibilityIdentifier("review.narrative.advice")

            if !run.response.warnings.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(run.response.warnings.prefix(3).enumerated()), id: \.offset) { index, warning in
                        Text(warning)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.13), in: Capsule())
                            .accessibilityIdentifier("review.narrative.warning.\(index)")
                    }
                }
            }

            ReviewNarrativeProbe(
                identifier: "review.narrative.card",
                label: "Review Narrative Card",
                value: run.accessibilityValue
            )
        }
        .padding(14)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReviewNarrativeProbe: View {
    let identifier: String
    let label: String
    let value: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A concise review narrative for an exposure-bracket sequence.")
struct FoundationModelsBracketReviewNarrativePayload: Sendable {
    @Guide(description: "Whether the generated response used the on-device Apple Intelligence model.")
    var usedAppleIntelligence: Bool

    @Guide(description: "A short review title.")
    var title: String

    @Guide(description: "One concise paragraph summarizing the bracket from structured manifest context.")
    var summary: String

    @Guide(description: "One concise export or merge recommendation.")
    var mergeAdvice: String

    @Guide(description: "Important warnings from manifest state only.", .maximumCount(4))
    var warnings: [String]

    @Guide(description: "Short workflow tags from manifest state only.", .maximumCount(6))
    var tags: [String]
}

@available(iOS 26.0, *)
struct FoundationModelsBracketReviewNarrativeGenerator: BracketReviewNarrativeModelGenerating {
    private let model: SystemLanguageModel
    private let options: GenerationOptions

    init(
        model: SystemLanguageModel = .default,
        options: GenerationOptions = GenerationOptions(
            sampling: .greedy,
            temperature: 0.1,
            maximumResponseTokens: 600
        )
    ) {
        self.model = model
        self.options = options
    }

    func response(for request: BracketReviewNarrativeRequest) async throws -> BracketReviewNarrativeResponse {
        let session = LanguageModelSession(
            model: model,
            instructions: request.systemInstruction
        )
        let response = try await session.respond(
            to: request.userPrompt,
            generating: FoundationModelsBracketReviewNarrativePayload.self,
            includeSchemaInPrompt: true,
            options: options
        )
        return response.content.reviewNarrativeResponse(for: request)
    }
}

@available(iOS 26.0, *)
private extension FoundationModelsBracketReviewNarrativePayload {
    func reviewNarrativeResponse(for request: BracketReviewNarrativeRequest) -> BracketReviewNarrativeResponse {
        BracketReviewNarrativeResponse(
            schemaVersion: BracketReviewNarrativeResponse.currentSchemaVersion,
            usedAppleIntelligence: true,
            availabilityStatus: request.context.intelligence.status,
            title: title,
            summary: summary,
            mergeAdvice: mergeAdvice,
            warnings: warnings,
            tags: tags,
            disclosure: ""
        )
    }
}
#endif

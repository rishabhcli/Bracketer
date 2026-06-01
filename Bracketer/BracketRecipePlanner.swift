import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct BracketRecipePlan: Codable, Equatable, Sendable {
    let requestedShotCount: Int
    let resolvedShotCount: Int
    let evStep: Float
    let centerBias: Float
    let evLabels: [String]
    let normalizationReason: String?

    init(evStep: Float, requestedShotCount: Int, centerBias: Float = 0) {
        let plan = BracketPlan(
            evStep: evStep,
            requestedShotCount: requestedShotCount,
            centerBias: centerBias
        )
        self.requestedShotCount = requestedShotCount
        self.resolvedShotCount = plan.shotCount
        self.evStep = plan.evStep
        self.centerBias = plan.centerBias
        self.evLabels = plan.shots.map(\.displayLabel)
        self.normalizationReason = plan.normalizationReason
    }

    var bracketPlan: BracketPlan {
        BracketPlan(
            evStep: evStep,
            requestedShotCount: resolvedShotCount,
            centerBias: centerBias
        )
    }

    var accessibilitySummary: String {
        "\(resolvedShotCount) shots | \(evLabels.joined(separator: ", ")) | Center \(BracketEVFormatter.displayLabel(for: centerBias))"
    }
}

struct BracketRecipeRecommendation: Codable, Equatable, Sendable {
    let title: String
    let plan: BracketRecipePlan
    let rationale: String
    let action: String
    let sourceSignals: [String]
    let confidence: Double

    var compactEvidenceSummary: String {
        "Confidence \(confidenceDisplay) | Sources: \(sourceSignalDisplay)"
    }

    private var confidenceDisplay: String {
        String(format: "%.2f", min(max(confidence, 0), 1))
    }

    private var sourceSignalDisplay: String {
        let trimmedSignals = sourceSignals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmedSignals.isEmpty else {
            return "No source signals recorded"
        }
        let visibleSignals = trimmedSignals.prefix(4).joined(separator: ", ")
        let remainingCount = trimmedSignals.count - min(trimmedSignals.count, 4)
        return remainingCount > 0 ? "\(visibleSignals) + \(remainingCount) more" : visibleSignals
    }
}

struct AppliedBracketRecipeRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let source: BracketRecipeRunSource
    let plan: BracketRecipePlan
    let appliedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        source: BracketRecipeRunSource,
        plan: BracketRecipePlan,
        appliedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.plan = plan
        self.appliedAt = appliedAt
    }

    var accessibilityValue: String {
        "\(title) | \(plan.accessibilitySummary) | Source: \(source.rawValue)"
    }

    func matchesRecipe(_ other: AppliedBracketRecipeRecord) -> Bool {
        title == other.title
            && source == other.source
            && plan == other.plan
    }
}

struct AdaptiveCapturePlanningProfile: Codable, Equatable, Sendable {
    enum IntentKind: String, Codable, Equatable, Sendable {
        case highDynamicRange
        case motionSensitive
        case stableDetailed
        case currentSettings
    }

    enum SceneConditionKind: String, Codable, Equatable, Sendable {
        case interiorWindow
        case backlitSky
        case fastSubject
        case stableArchitecture
        case unspecified
    }

    enum DynamicRangeLevel: String, Codable, Equatable, Sendable {
        case unknown
        case normal
        case wide
        case extreme
    }

    enum MotionStabilityLevel: String, Codable, Equatable, Sendable {
        case unknown
        case stable
        case handheld
        case motionSensitive
    }

    enum RiskLevel: String, Codable, Equatable, Sendable {
        case unknown
        case low
        case medium
        case high
    }

    struct Intent: Codable, Equatable, Sendable {
        let kind: IntentKind
        let title: String
        let sourceSignals: [String]
    }

    struct SceneCondition: Codable, Equatable, Sendable {
        let kind: SceneConditionKind
        let title: String
        let sourceSignals: [String]
    }

    struct DynamicRangeEstimate: Codable, Equatable, Sendable {
        let level: DynamicRangeLevel
        let score: Double
        let rationale: String
        let sourceSignals: [String]
    }

    struct MotionStabilityEstimate: Codable, Equatable, Sendable {
        let level: MotionStabilityLevel
        let sourceSignals: [String]
    }

    struct HighlightShadowRisk: Codable, Equatable, Sendable {
        let highlight: RiskLevel
        let shadow: RiskLevel
        let combined: RiskLevel
        let sourceSignals: [String]
    }

    struct LensCapability: Codable, Equatable, Sendable {
        let lensSummary: String
        let supportsProRAW: Bool?
        let status: String
        let sourceSignals: [String]
    }

    struct StrategyRecommendation: Codable, Equatable, Sendable {
        let title: String
        let detail: String
        let sourceSignals: [String]
    }

    struct CaptureStrategy: Codable, Equatable, Sendable {
        let timer: StrategyRecommendation
        let format: StrategyRecommendation
        let lens: StrategyRecommendation
        let stabilization: StrategyRecommendation

        var sourceSignals: [String] {
            [
                timer.sourceSignals,
                format.sourceSignals,
                lens.sourceSignals,
                stabilization.sourceSignals
            ]
                .flatMap { $0 }
                .uniquePreservingOrder()
        }

        var accessibilityValue: String {
            [
                "Timer: \(timer.title)",
                "Format: \(format.title)",
                "Lens: \(lens.title)",
                "Stabilization: \(stabilization.title)"
            ].joined(separator: " | ")
        }
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let intent: Intent
    let sceneCondition: SceneCondition
    let dynamicRange: DynamicRangeEstimate
    let motionStability: MotionStabilityEstimate
    let highlightShadowRisk: HighlightShadowRisk
    let lensCapability: LensCapability
    let recommendedPlan: BracketRecipePlan
    let captureStrategy: CaptureStrategy
    let confidence: Double
    let explanation: String
    let privacyBoundary: String

    var sourceSignals: [String] {
        [
            intent.sourceSignals,
            sceneCondition.sourceSignals,
            dynamicRange.sourceSignals,
            motionStability.sourceSignals,
            highlightShadowRisk.sourceSignals,
            lensCapability.sourceSignals,
            captureStrategy.sourceSignals
        ]
            .flatMap { $0 }
            .uniquePreservingOrder()
    }

    var accessibilityValue: String {
        [
            "Adaptive Capture Planning Profile",
            "Intent: \(intent.title)",
            "Scene: \(sceneCondition.title)",
            "Dynamic range: \(dynamicRange.level.rawValue) score \(String(format: "%.2f", dynamicRange.score))",
            "Motion: \(motionStability.level.rawValue)",
            "Highlight risk: \(highlightShadowRisk.highlight.rawValue)",
            "Shadow risk: \(highlightShadowRisk.shadow.rawValue)",
            "Lens: \(lensCapability.status)",
            "Recipe: \(recommendedPlan.accessibilitySummary)",
            "Strategy: \(captureStrategy.accessibilityValue)",
            "Confidence: \(String(format: "%.2f", confidence))",
            explanation,
            privacyBoundary
        ].joined(separator: " | ")
    }

    static func make(
        prompt: String,
        context: CaptureContextSummary
    ) -> AdaptiveCapturePlanningProfile {
        let normalizedPrompt = prompt.lowercased()
        let frame = context.frameAnalysis
        let sceneCondition = makeSceneCondition(prompt: normalizedPrompt)
        let motionStability = makeMotionStability(prompt: normalizedPrompt, context: context)
        let highlightShadowRisk = makeHighlightShadowRisk(frame: frame)
        let dynamicRange = makeDynamicRange(
            prompt: normalizedPrompt,
            frame: frame,
            sceneCondition: sceneCondition,
            highlightShadowRisk: highlightShadowRisk
        )
        let intent = makeIntent(
            dynamicRange: dynamicRange,
            motionStability: motionStability,
            sceneCondition: sceneCondition
        )
        let recommendedPlan = makeRecommendedPlan(
            intent: intent,
            dynamicRange: dynamicRange,
            context: context
        )
        let confidence = makeConfidence(
            frame: frame,
            prompt: normalizedPrompt,
            dynamicRange: dynamicRange,
            motionStability: motionStability
        )
        let lensSummary = resolvedLensSummary(for: context.device)
        let lensCapability = LensCapability(
            lensSummary: lensSummary,
            supportsProRAW: context.device?.supportsProRAW,
            status: context.device.map {
                "\(lensSummary); ProRAW \($0.supportsProRAW ? "supported" : "unavailable")"
            } ?? "Device capability snapshot unavailable",
            sourceSignals: context.device == nil ? ["device capability snapshot unavailable"] : ["device capability snapshot"]
        )
        let captureStrategy = makeCaptureStrategy(
            intent: intent,
            sceneCondition: sceneCondition,
            dynamicRange: dynamicRange,
            motionStability: motionStability,
            lensCapability: lensCapability,
            context: context
        )

        return AdaptiveCapturePlanningProfile(
            schemaVersion: currentSchemaVersion,
            intent: intent,
            sceneCondition: sceneCondition,
            dynamicRange: dynamicRange,
            motionStability: motionStability,
            highlightShadowRisk: highlightShadowRisk,
            lensCapability: lensCapability,
            recommendedPlan: recommendedPlan,
            captureStrategy: captureStrategy,
            confidence: confidence,
            explanation: makeExplanation(intent: intent, dynamicRange: dynamicRange, motionStability: motionStability),
            privacyBoundary: "Profile derived from typed scene description and structured capture context only; no raw photo bytes, Photos asset identifiers, precise coordinates, or physical-device proof were inspected."
        )
    }

    private static func makeSceneCondition(prompt: String) -> SceneCondition {
        if prompt.containsAny(["tripod", "architecture", "landscape", "real estate"]) {
            return SceneCondition(kind: .stableArchitecture, title: "Stable detailed scene", sourceSignals: ["stable-scene prompt"])
        }
        if prompt.containsAny(["interior", "window"]) {
            return SceneCondition(kind: .interiorWindow, title: "Interior window", sourceSignals: ["scene prompt"])
        }
        if prompt.containsAny(["sunset", "sunrise", "backlit", "bright sky"]) {
            return SceneCondition(kind: .backlitSky, title: "Backlit sky", sourceSignals: ["scene prompt"])
        }
        if prompt.containsAny(["moving", "street", "portrait", "people", "fast"]) {
            return SceneCondition(kind: .fastSubject, title: "Fast subject", sourceSignals: ["motion-sensitive prompt"])
        }
        return SceneCondition(kind: .unspecified, title: "Unspecified scene", sourceSignals: prompt.isEmpty ? [] : ["scene prompt"])
    }

    private static func makeMotionStability(
        prompt: String,
        context: CaptureContextSummary
    ) -> MotionStabilityEstimate {
        if prompt.containsAny(["moving", "street", "portrait", "people", "fast"]) {
            return MotionStabilityEstimate(level: .motionSensitive, sourceSignals: ["motion-sensitive prompt"])
        }
        if prompt.contains("handheld") {
            return MotionStabilityEstimate(level: .handheld, sourceSignals: ["handheld prompt"])
        }
        if prompt.containsAny(["tripod", "architecture", "landscape", "real estate"]) {
            return MotionStabilityEstimate(level: .stable, sourceSignals: ["stable-scene prompt"])
        }
        if !prompt.isEmpty && (context.capture.timer != "Off" || context.settings.showLevel) {
            return MotionStabilityEstimate(level: .stable, sourceSignals: ["stability context"])
        }
        return MotionStabilityEstimate(level: .unknown, sourceSignals: [])
    }

    private static func makeHighlightShadowRisk(
        frame: CaptureContextSummary.FrameAnalysis
    ) -> HighlightShadowRisk {
        HighlightShadowRisk(
            highlight: riskLevel(percent: frame.highlightClippingPercent, hasWarning: frame.hasHighlightWarning),
            shadow: riskLevel(percent: frame.shadowClippingPercent, hasWarning: frame.hasShadowWarning),
            combined: riskLevel(
                percent: max(frame.highlightClippingPercent, frame.shadowClippingPercent),
                hasWarning: frame.hasHighlightWarning || frame.hasShadowWarning
            ),
            sourceSignals: frame.guidanceSignals
        )
    }

    private static func makeDynamicRange(
        prompt: String,
        frame: CaptureContextSummary.FrameAnalysis,
        sceneCondition: SceneCondition,
        highlightShadowRisk: HighlightShadowRisk
    ) -> DynamicRangeEstimate {
        let hasExtremePrompt = prompt.containsAny(["extreme", "hdr", "stage", "spotlight", "neon", "very dark"])
        let hasWidePrompt = prompt.containsAny(["high contrast", "bright window", "bright sky", "dark furniture"])
        let promptScore = hasExtremePrompt ? 0.55 : (hasWidePrompt ? 0.35 : 0)
        let sceneScore: Double
        switch sceneCondition.kind {
        case .interiorWindow, .backlitSky:
            sceneScore = 0.25
        default:
            sceneScore = 0
        }
        let frameScore = Double(frame.highlightClippingPercent + frame.shadowClippingPercent) / 200.0
        let warningScore = (frame.hasHighlightWarning ? 0.15 : 0) + (frame.hasShadowWarning ? 0.15 : 0)
        let score = min(1, promptScore + sceneScore + frameScore + warningScore)
        let level: DynamicRangeLevel
        if !frame.isAvailable && prompt.isEmpty {
            level = .unknown
        } else if hasExtremePrompt || frame.highlightClippingPercent >= 40 || frame.shadowClippingPercent >= 40 || (!hasWidePrompt && score >= 0.9) {
            level = .extreme
        } else if hasWidePrompt || score >= 0.38 || highlightShadowRisk.highlight == .high || highlightShadowRisk.shadow == .high {
            level = .wide
        } else {
            level = .normal
        }
        return DynamicRangeEstimate(
            level: level,
            score: score,
            rationale: dynamicRangeRationale(
                level: level,
                hasExtremePrompt: hasExtremePrompt,
                hasWidePrompt: hasWidePrompt,
                frame: frame
            ),
            sourceSignals: [
                hasExtremePrompt ? ["extreme dynamic range prompt"] : [],
                hasWidePrompt ? ["high contrast prompt"] : [],
                sceneCondition.sourceSignals,
                frame.guidanceSignals,
                level == .unknown ? ["missing frame analysis"] : []
            ].flatMap { $0 }.uniquePreservingOrder()
        )
    }

    private static func makeIntent(
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate,
        sceneCondition: SceneCondition
    ) -> Intent {
        if dynamicRange.level == .extreme {
            return Intent(
                kind: .highDynamicRange,
                title: "Extreme dynamic range",
                sourceSignals: dynamicRange.sourceSignals
            )
        }
        if motionStability.level == .motionSensitive || sceneCondition.kind == .fastSubject {
            return Intent(kind: .motionSensitive, title: "Motion-sensitive capture", sourceSignals: motionStability.sourceSignals)
        }
        if dynamicRange.level == .wide {
            return Intent(
                kind: .highDynamicRange,
                title: "High dynamic range",
                sourceSignals: dynamicRange.sourceSignals
            )
        }
        if motionStability.level == .stable || sceneCondition.kind == .stableArchitecture {
            return Intent(kind: .stableDetailed, title: "Stable detailed capture", sourceSignals: motionStability.sourceSignals)
        }
        return Intent(kind: .currentSettings, title: "Use current settings", sourceSignals: ["current bracket context"])
    }

    private static func makeRecommendedPlan(
        intent: Intent,
        dynamicRange: DynamicRangeEstimate,
        context: CaptureContextSummary
    ) -> BracketRecipePlan {
        switch intent.kind {
        case .highDynamicRange:
            return BracketRecipePlan(
                evStep: 2.0,
                requestedShotCount: dynamicRange.level == .extreme ? 7 : 5,
                centerBias: context.bracket.centerBias
            )
        case .motionSensitive:
            return BracketRecipePlan(evStep: 1.0, requestedShotCount: 3, centerBias: context.bracket.centerBias)
        case .stableDetailed:
            return BracketRecipePlan(evStep: 1.0, requestedShotCount: 5, centerBias: context.bracket.centerBias)
        case .currentSettings:
            return BracketRecipePlan(
                evStep: context.bracket.evStep,
                requestedShotCount: context.bracket.resolvedShotCount,
                centerBias: context.bracket.centerBias
            )
        }
    }

    private static func resolvedLensSummary(for device: CaptureContextSummary.Device?) -> String {
        guard let device else {
            return "Lens capability snapshot unavailable"
        }
        let summary = device.lensSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? "Lens capability snapshot unavailable" : summary
    }

    private static func makeCaptureStrategy(
        intent: Intent,
        sceneCondition: SceneCondition,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate,
        lensCapability: LensCapability,
        context: CaptureContextSummary
    ) -> CaptureStrategy {
        CaptureStrategy(
            timer: makeTimerRecommendation(
                intent: intent,
                dynamicRange: dynamicRange,
                motionStability: motionStability,
                context: context
            ),
            format: makeFormatRecommendation(
                intent: intent,
                dynamicRange: dynamicRange,
                motionStability: motionStability,
                lensCapability: lensCapability,
                context: context
            ),
            lens: makeLensRecommendation(
                sceneCondition: sceneCondition,
                motionStability: motionStability,
                lensCapability: lensCapability
            ),
            stabilization: makeStabilizationRecommendation(
                intent: intent,
                dynamicRange: dynamicRange,
                motionStability: motionStability
            )
        )
    }

    private static func makeTimerRecommendation(
        intent: Intent,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate,
        context: CaptureContextSummary
    ) -> StrategyRecommendation {
        if motionStability.level == .motionSensitive || motionStability.level == .handheld {
            return StrategyRecommendation(
                title: isTimerOff(context.capture.timer) ? "Keep timer off" : "Turn timer off",
                detail: "Start immediately so motion-sensitive subjects do not change before the bracket begins.",
                sourceSignals: motionStability.sourceSignals + ["capture timer"]
            )
        }

        if intent.kind == .highDynamicRange || dynamicRange.level == .wide || dynamicRange.level == .extreme {
            return StrategyRecommendation(
                title: isTimerOff(context.capture.timer) ? "Use 3s timer" : "Keep \(context.capture.timer) timer",
                detail: "Give the phone a short settling window before the bracket to reduce shake.",
                sourceSignals: dynamicRange.sourceSignals + ["capture timer"]
            )
        }

        if intent.kind == .stableDetailed {
            return StrategyRecommendation(
                title: isTimerOff(context.capture.timer) ? "Use 3s timer" : "Keep \(context.capture.timer) timer",
                detail: "Use a short delay or remote trigger when the scene is stable enough for a tighter five-shot pass.",
                sourceSignals: motionStability.sourceSignals + ["capture timer"]
            )
        }

        return StrategyRecommendation(
            title: isTimerOff(context.capture.timer) ? "Keep timer off" : "Keep \(context.capture.timer) timer",
            detail: "No stronger timer change is justified by the available structured signals.",
            sourceSignals: ["capture timer"]
        )
    }

    private static func makeFormatRecommendation(
        intent: Intent,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate,
        lensCapability: LensCapability,
        context: CaptureContextSummary
    ) -> StrategyRecommendation {
        let currentFormat = context.capture.format
        let currentIsRaw = currentFormat.localizedCaseInsensitiveContains("raw")
        let wantsLatitude = intent.kind == .highDynamicRange
            || dynamicRange.level == .wide
            || dynamicRange.level == .extreme
            || intent.kind == .stableDetailed

        if motionStability.level == .motionSensitive && !wantsLatitude {
            return StrategyRecommendation(
                title: currentIsRaw ? "Keep current format" : "Use HEIF/JPEG",
                detail: "Prioritize a shorter bracket and the current save path for changing subjects.",
                sourceSignals: motionStability.sourceSignals + ["capture format"]
            )
        }

        if wantsLatitude {
            if lensCapability.supportsProRAW == true {
                return StrategyRecommendation(
                    title: currentIsRaw ? "Keep ProRAW" : "Prefer ProRAW",
                    detail: "ProRAW is available in the device snapshot and preserves more latitude for high dynamic range review.",
                    sourceSignals: lensCapability.sourceSignals + ["capture format"]
                )
            }
            if lensCapability.supportsProRAW == false {
                return StrategyRecommendation(
                    title: "Use HEIF/JPEG",
                    detail: "ProRAW is unavailable in the device snapshot, so keep the processed capture path honest.",
                    sourceSignals: lensCapability.sourceSignals + ["capture format"]
                )
            }
            return StrategyRecommendation(
                title: currentIsRaw ? "Keep ProRAW" : "Keep current format",
                detail: "Device ProRAW support is not present in the structured context, so keep the current format without claiming extra capability.",
                sourceSignals: lensCapability.sourceSignals + ["capture format"]
            )
        }

        return StrategyRecommendation(
            title: currentIsRaw ? "Keep ProRAW" : "Keep current format",
            detail: "No structured signal requires a format change.",
            sourceSignals: ["capture format"]
        )
    }

    private static func makeLensRecommendation(
        sceneCondition: SceneCondition,
        motionStability: MotionStabilityEstimate,
        lensCapability: LensCapability
    ) -> StrategyRecommendation {
        let lensSummary = lensCapability.lensSummary
        guard lensCapability.supportsProRAW != nil else {
            return StrategyRecommendation(
                title: "Keep current lens",
                detail: "Lens capability snapshot is unavailable, so the planner will not invent a lens switch.",
                sourceSignals: lensCapability.sourceSignals
            )
        }

        if (sceneCondition.kind == .interiorWindow || sceneCondition.kind == .stableArchitecture)
            && lensSummary.localizedCaseInsensitiveContains("Ultra Wide") {
            return StrategyRecommendation(
                title: "Prefer Ultra Wide",
                detail: "The device snapshot lists Ultra Wide and the scene reads as an interior or architectural composition.",
                sourceSignals: lensCapability.sourceSignals + sceneCondition.sourceSignals
            )
        }

        if motionStability.level == .motionSensitive || motionStability.level == .handheld {
            return StrategyRecommendation(
                title: "Prefer Wide",
                detail: "Wide lens is the safest default for handheld or moving subjects in the available lens summary.",
                sourceSignals: lensCapability.sourceSignals + motionStability.sourceSignals
            )
        }

        if lensSummary.localizedCaseInsensitiveContains("Wide") {
            return StrategyRecommendation(
                title: "Prefer Wide",
                detail: "Wide lens is available in the structured device snapshot and is the safest default bracket lens.",
                sourceSignals: lensCapability.sourceSignals
            )
        }

        return StrategyRecommendation(
            title: "Keep current lens",
            detail: "No supported lens switch is justified by the available structured signals.",
            sourceSignals: lensCapability.sourceSignals
        )
    }

    private static func makeStabilizationRecommendation(
        intent: Intent,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate
    ) -> StrategyRecommendation {
        if motionStability.level == .motionSensitive || motionStability.level == .handheld {
            return StrategyRecommendation(
                title: "Brace handheld",
                detail: "Brace elbows, keep the bracket short, and capture before the subject changes.",
                sourceSignals: motionStability.sourceSignals
            )
        }

        if intent.kind == .stableDetailed {
            return StrategyRecommendation(
                title: "Use support",
                detail: "Use a tripod, ledge, or two-handed brace before starting the tighter detail bracket.",
                sourceSignals: motionStability.sourceSignals
            )
        }

        if intent.kind == .highDynamicRange || dynamicRange.level == .wide || dynamicRange.level == .extreme {
            return StrategyRecommendation(
                title: "Stabilize bracket",
                detail: "Use a tripod, ledge, or two-handed brace so the wider bracket stays alignable.",
                sourceSignals: dynamicRange.sourceSignals
            )
        }

        return StrategyRecommendation(
            title: "Normal handheld stance",
            detail: "No structured signal requires extra stabilization beyond a steady normal capture.",
            sourceSignals: ["current bracket context"]
        )
    }

    private static func isTimerOff(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("Off") == .orderedSame
    }

    private static func makeConfidence(
        frame: CaptureContextSummary.FrameAnalysis,
        prompt: String,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate
    ) -> Double {
        var confidence = frame.isAvailable ? 0.58 : 0.42
        if !prompt.isEmpty { confidence += 0.12 }
        if dynamicRange.level == .wide || dynamicRange.level == .extreme { confidence += 0.12 }
        if motionStability.level != .unknown { confidence += 0.08 }
        return min(0.9, confidence)
    }

    private static func makeExplanation(
        intent: Intent,
        dynamicRange: DynamicRangeEstimate,
        motionStability: MotionStabilityEstimate
    ) -> String {
        "Selected \(intent.title) from \(dynamicRange.level.rawValue) dynamic range and \(motionStability.level.rawValue) motion/stability signals."
    }

    private static func dynamicRangeRationale(
        level: DynamicRangeLevel,
        hasExtremePrompt: Bool,
        hasWidePrompt: Bool,
        frame: CaptureContextSummary.FrameAnalysis
    ) -> String {
        if level == .unknown {
            return "No typed scene or frame-analysis signal was available."
        }
        if hasExtremePrompt {
            return "The typed scene description explicitly asked for an extreme HDR-style recipe."
        }
        if frame.hasHighlightWarning && frame.hasShadowWarning {
            return "Frame analysis reports simultaneous highlight and shadow clipping risk."
        }
        if frame.hasHighlightWarning {
            return "Frame analysis reports highlight clipping risk."
        }
        if frame.hasShadowWarning {
            return "Frame analysis reports shadow clipping risk."
        }
        if hasWidePrompt {
            return "The typed scene description indicates a high-contrast bracket with important bright and dark regions."
        }
        return "The typed scene and frame-analysis signals did not indicate extreme clipping."
    }

    private static func riskLevel(percent: Int, hasWarning: Bool) -> RiskLevel {
        if percent >= 35 || (hasWarning && percent >= 20) { return .high }
        if percent >= 10 || hasWarning { return .medium }
        return .low
    }
}

struct BracketRecipeRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let naturalLanguagePrompt: String
    let maxRecommendations: Int
    let context: CaptureContextSummary
    let systemInstruction: String
    let userPrompt: String

    static func make(
        prompt: String,
        context: CaptureContextSummary,
        maxRecommendations: Int = 3
    ) -> BracketRecipeRequest {
        let resolvedMaxRecommendations = min(max(maxRecommendations, 1), 5)
        let resolvedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return BracketRecipeRequest(
            schemaVersion: Self.currentSchemaVersion,
            naturalLanguagePrompt: resolvedPrompt,
            maxRecommendations: resolvedMaxRecommendations,
            context: context,
            systemInstruction: Self.systemInstruction,
            userPrompt: Self.userPrompt(
                prompt: resolvedPrompt,
                context: context,
                maxRecommendations: resolvedMaxRecommendations
            )
        )
    }

    private static let systemInstruction = """
    You are Bracketer's local bracket recipe planner. Convert the user's scene description and the app's structured camera context into safe exposure-bracketing recipes. Use only 3, 5, or 7 shots. Keep recommendations concise, preserve photographer control, and never claim to inspect raw photos, Photos asset identifiers, precise coordinates, or unavailable visual content.
    """

    private static func userPrompt(
        prompt: String,
        context: CaptureContextSummary,
        maxRecommendations: Int
    ) -> String {
        """
        Scene description:
        \(prompt.isEmpty ? "No natural language scene description was provided." : prompt)

        Max bracket recipes: \(maxRecommendations)
        Structured camera context:
        \(context.compactPromptContext)
        """
    }
}

struct BracketRecipeResponse: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let usedAppleIntelligence: Bool
    let availabilityStatus: String
    let recommendations: [BracketRecipeRecommendation]
    let disclosure: String
}

enum BracketRecipeResponseValidator {
    static func validated(
        _ response: BracketRecipeResponse,
        for request: BracketRecipeRequest
    ) -> BracketRecipeResponse {
        let recommendations = response.recommendations
            .compactMap { recommendation -> BracketRecipeRecommendation? in
                let title = recommendation.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let action = recommendation.action.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !action.isEmpty else { return nil }

                let plan = BracketRecipePlan(
                    evStep: recommendation.plan.evStep,
                    requestedShotCount: recommendation.plan.requestedShotCount,
                    centerBias: recommendation.plan.centerBias
                )

                return BracketRecipeRecommendation(
                    title: title,
                    plan: plan,
                    rationale: recommendation.rationale.trimmingCharacters(in: .whitespacesAndNewlines),
                    action: action,
                    sourceSignals: Array(recommendation.sourceSignals.prefix(6)),
                    confidence: min(max(recommendation.confidence, 0), 1)
                )
            }
            .prefix(request.maxRecommendations)

        return BracketRecipeResponse(
            schemaVersion: BracketRecipeResponse.currentSchemaVersion,
            usedAppleIntelligence: request.context.intelligence.isUsable && response.usedAppleIntelligence,
            availabilityStatus: request.context.intelligence.status,
            recommendations: Array(recommendations),
            disclosure: disclosure(for: request.context)
        )
    }

    private static func disclosure(for context: CaptureContextSummary) -> String {
        if context.privacy.rawPhotoBytesIncluded
            || context.privacy.assetIdentifiersIncluded
            || context.privacy.locationCoordinatesIncluded {
            return "Recipe generated from expanded capture data; review privacy-sensitive details before sharing."
        }

        return "Recipe generated from structured camera state and the typed scene description only; no raw photo bytes, asset identifiers, or precise coordinates were included."
    }
}

enum DeterministicBracketRecipePlanner {
    static func response(for request: BracketRecipeRequest) -> BracketRecipeResponse {
        var recommendations: [BracketRecipeRecommendation] = [
            primaryRecommendation(for: request)
        ]

        if request.context.frameAnalysis.hasHighlightWarning {
            recommendations.append(
                recommendation(
                    title: "Highlight-safe variant",
                    plan: BracketRecipePlan(
                        evStep: 1.0,
                        requestedShotCount: 3,
                        centerBias: min(request.context.bracket.centerBias, -0.3)
                    ),
                    rationale: "The structured frame analysis reports highlight clipping, so a darker center keeps the top end safer.",
                    action: "Bias the center exposure darker before starting the bracket.",
                    sourceSignals: ["highlight clipping"],
                    confidence: 0.72
                )
            )
        }

        let response = BracketRecipeResponse(
            schemaVersion: BracketRecipeResponse.currentSchemaVersion,
            usedAppleIntelligence: false,
            availabilityStatus: request.context.intelligence.status,
            recommendations: recommendations,
            disclosure: ""
        )

        return BracketRecipeResponseValidator.validated(response, for: request)
    }

    private static func primaryRecommendation(for request: BracketRecipeRequest) -> BracketRecipeRecommendation {
        let profile = AdaptiveCapturePlanningProfile.make(
            prompt: request.naturalLanguagePrompt,
            context: request.context
        )

        if profile.dynamicRange.level == .extreme {
            return recommendation(
                title: "Extreme dynamic range",
                plan: profile.recommendedPlan,
                rationale: profile.dynamicRange.rationale,
                action: "\(profile.captureStrategy.stabilization.title). \(profile.captureStrategy.timer.title). \(profile.captureStrategy.format.title).",
                sourceSignals: sourceSignals(profile: profile, extra: ["adaptive dynamic range profile", "extreme range"]),
                confidence: 0.86
            )
        }

        if profile.motionStability.level == .motionSensitive || profile.motionStability.level == .handheld {
            return recommendation(
                title: "Fast handheld capture",
                plan: profile.recommendedPlan,
                rationale: "The prompt suggests motion or handheld shooting where a shorter sequence reduces alignment risk.",
                action: "\(profile.captureStrategy.stabilization.title). \(profile.captureStrategy.timer.title). \(profile.captureStrategy.lens.title).",
                sourceSignals: sourceSignals(profile: profile, extra: ["adaptive motion profile"]),
                confidence: 0.78
            )
        }

        if profile.intent.kind == .highDynamicRange || profile.dynamicRange.level == .wide {
            return recommendation(
                title: "High contrast scene",
                plan: profile.recommendedPlan,
                rationale: profile.dynamicRange.rationale,
                action: "\(profile.captureStrategy.stabilization.title). \(profile.captureStrategy.timer.title). \(profile.captureStrategy.format.title).",
                sourceSignals: sourceSignals(profile: profile, extra: ["adaptive dynamic range profile", "high contrast"]),
                confidence: 0.82
            )
        }

        if profile.intent.kind == .stableDetailed {
            return recommendation(
                title: "Stable detailed capture",
                plan: profile.recommendedPlan,
                rationale: "The prompt suggests a stable scene where more samples can help preserve tonal nuance.",
                action: "\(profile.captureStrategy.stabilization.title). \(profile.captureStrategy.timer.title). \(profile.captureStrategy.lens.title).",
                sourceSignals: sourceSignals(profile: profile, extra: ["adaptive stability profile"]),
                confidence: 0.74
            )
        }

        return recommendation(
            title: "Current recipe",
            plan: BracketRecipePlan(
                evStep: request.context.bracket.evStep,
                requestedShotCount: request.context.bracket.resolvedShotCount,
                centerBias: request.context.bracket.centerBias
            ),
            rationale: "No stronger scene signal was present, so the current bracket plan remains appropriate.",
            action: "\(profile.captureStrategy.stabilization.title). \(profile.captureStrategy.timer.title). \(profile.captureStrategy.format.title).",
            sourceSignals: sourceSignals(profile: profile, extra: ["adaptive current-settings profile"]),
            confidence: 0.66
        )
    }

    private static func recommendation(
        title: String,
        plan: BracketRecipePlan,
        rationale: String,
        action: String,
        sourceSignals: [String],
        confidence: Double
    ) -> BracketRecipeRecommendation {
        BracketRecipeRecommendation(
            title: title,
            plan: plan,
            rationale: rationale,
            action: "\(action) Recipe: \(plan.accessibilitySummary).",
            sourceSignals: sourceSignals,
            confidence: confidence
        )
    }

    private static func sourceSignals(
        profile: AdaptiveCapturePlanningProfile,
        extra: [String]
    ) -> [String] {
        (extra + profile.sourceSignals).uniquePreservingOrder()
    }
}

enum BracketRecipeRunSource: String, Codable, Equatable, Sendable {
    case foundationModels
    case deterministicFallback
}

struct BracketRecipeRun: Codable, Equatable, Sendable {
    let source: BracketRecipeRunSource
    let response: BracketRecipeResponse
    let fallbackReason: String?
}

protocol BracketRecipeModelGenerating: Sendable {
    func response(for request: BracketRecipeRequest) async throws -> BracketRecipeResponse
}

struct BracketRecipeEngine: Sendable {
    private let makeModelGenerator: @Sendable () -> (any BracketRecipeModelGenerating)?

    init(
        makeModelGenerator: @escaping @Sendable () -> (any BracketRecipeModelGenerating)? = { nil }
    ) {
        self.makeModelGenerator = makeModelGenerator
    }

    func response(for request: BracketRecipeRequest) async -> BracketRecipeRun {
        guard request.context.intelligence.isUsable else {
            return deterministicRun(
                for: request,
                reason: "Apple Intelligence unavailable: \(request.context.intelligence.status)"
            )
        }

        guard let modelGenerator = makeModelGenerator() else {
            return deterministicRun(
                for: request,
                reason: "Foundation Models bracket recipe provider unavailable in this runtime."
            )
        }

        do {
            let modelResponse = try await modelGenerator.response(for: request)
            let validated = BracketRecipeResponseValidator.validated(modelResponse, for: request)
            guard !validated.recommendations.isEmpty else {
                return deterministicRun(
                    for: request,
                    reason: "Foundation Models returned no bracket recipes."
                )
            }
            return BracketRecipeRun(
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
        for request: BracketRecipeRequest,
        reason: String
    ) -> BracketRecipeRun {
        BracketRecipeRun(
            source: .deterministicFallback,
            response: DeterministicBracketRecipePlanner.response(for: request),
            fallbackReason: reason
        )
    }
}

extension BracketRecipeEngine {
    static var live: BracketRecipeEngine {
        BracketRecipeEngine {
            #if canImport(FoundationModels) && !targetEnvironment(simulator)
            if #available(iOS 26.0, *) {
                return FoundationModelsBracketRecipeGenerator()
            }
            #endif
            return nil
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A concise bracket-recipe response for an exposure-bracketing camera app.")
struct FoundationModelsBracketRecipePayload: Sendable {
    @Guide(description: "Whether the generated response used the on-device Apple Intelligence model.")
    var usedAppleIntelligence: Bool

    @Guide(description: "One to five bracket recipe recommendations.", .count(1...5))
    var recommendations: [FoundationModelsBracketRecipeRecommendation]
}

@available(iOS 26.0, *)
@Generable(description: "One bracket recipe recommendation.")
struct FoundationModelsBracketRecipeRecommendation: Sendable {
    @Guide(description: "A short title for the bracket recipe.")
    var title: String

    @Guide(description: "Supported shot count. Use 3, 5, or 7.")
    var shotCount: Int

    @Guide(description: "Positive exposure step in EV.")
    var evStep: Double

    @Guide(description: "Center exposure bias in EV.")
    var centerBias: Double

    @Guide(description: "Why this bracket recipe fits the structured context.")
    var rationale: String

    @Guide(description: "A concrete action the photographer can take now.")
    var action: String

    @Guide(description: "Structured source signals used for this recommendation.", .maximumCount(6))
    var sourceSignals: [String]

    @Guide(description: "Confidence from 0 to 1.")
    var confidence: Double
}

@available(iOS 26.0, *)
struct FoundationModelsBracketRecipeGenerator: BracketRecipeModelGenerating {
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

    func response(for request: BracketRecipeRequest) async throws -> BracketRecipeResponse {
        let session = LanguageModelSession(
            model: model,
            instructions: request.systemInstruction
        )
        let response = try await session.respond(
            to: request.userPrompt,
            generating: FoundationModelsBracketRecipePayload.self,
            includeSchemaInPrompt: true,
            options: options
        )
        return response.content.bracketRecipeResponse(for: request)
    }
}

@available(iOS 26.0, *)
private extension FoundationModelsBracketRecipePayload {
    func bracketRecipeResponse(for request: BracketRecipeRequest) -> BracketRecipeResponse {
        BracketRecipeResponse(
            schemaVersion: BracketRecipeResponse.currentSchemaVersion,
            usedAppleIntelligence: true,
            availabilityStatus: request.context.intelligence.status,
            recommendations: recommendations.map(\.bracketRecipeRecommendation),
            disclosure: ""
        )
    }
}

@available(iOS 26.0, *)
private extension FoundationModelsBracketRecipeRecommendation {
    var bracketRecipeRecommendation: BracketRecipeRecommendation {
        BracketRecipeRecommendation(
            title: title,
            plan: BracketRecipePlan(
                evStep: Float(evStep),
                requestedShotCount: shotCount,
                centerBias: Float(centerBias)
            ),
            rationale: rationale,
            action: action,
            sourceSignals: sourceSignals,
            confidence: confidence
        )
    }
}
#endif

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum IntelligenceFeatureAvailability: Equatable, Sendable {
    case available
    case disabledByUser
    case sdkUnavailable
    case frameworkUnavailable
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case localeUnsupported(identifier: String)
    case simulatorUnsupported
    case unknown(reason: String)

    var isUsable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var statusTitle: String {
        switch self {
        case .available:
            return "Available"
        case .disabledByUser:
            return "Disabled"
        case .sdkUnavailable:
            return "SDK unavailable"
        case .frameworkUnavailable:
            return "Framework unavailable"
        case .deviceNotEligible:
            return "Device not eligible"
        case .appleIntelligenceNotEnabled:
            return "Not enabled"
        case .modelNotReady:
            return "Model not ready"
        case .localeUnsupported:
            return "Locale unsupported"
        case .simulatorUnsupported:
            return "Simulator unsupported"
        case .unknown:
            return "Unknown"
        }
    }

    var statusDetail: String {
        switch self {
        case .available:
            return "On-device Apple Intelligence features can run."
        case .disabledByUser:
            return "Generative camera assistance is turned off for this app."
        case .sdkUnavailable:
            return "This build cannot import Foundation Models."
        case .frameworkUnavailable:
            return "The running OS does not expose Foundation Models."
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off in Settings."
        case .modelNotReady:
            return "The on-device model is still downloading or preparing."
        case .localeUnsupported(let identifier):
            return "Apple Intelligence does not support the current locale: \(identifier)."
        case .simulatorUnsupported:
            return "Simulator builds keep generative features disabled; test them with deterministic fakes."
        case .unknown(let reason):
            return reason
        }
    }

    var recoveryAction: String? {
        switch self {
        case .available:
            return nil
        case .disabledByUser:
            return "Enable Apple Intelligence features in Bracketer settings."
        case .sdkUnavailable:
            return "Build with an Xcode SDK that includes Foundation Models."
        case .frameworkUnavailable:
            return "Run on iOS 26 or newer with Foundation Models support."
        case .deviceNotEligible:
            return "Use an Apple Intelligence-capable iPhone."
        case .appleIntelligenceNotEnabled:
            return "Settings > Apple Intelligence & Siri > Apple Intelligence"
        case .modelNotReady:
            return "Keep the device online and plugged in until the model is ready."
        case .localeUnsupported:
            return "Use an Apple Intelligence-supported language and region."
        case .simulatorUnsupported:
            return "Use UI-test fakes in simulator or verify on a physical device."
        case .unknown:
            return "Retry later or export diagnostics."
        }
    }

    var accessibilityValue: String {
        var parts = ["Apple Intelligence", statusTitle, statusDetail]
        if let recoveryAction {
            parts.append("Action: \(recoveryAction)")
        }
        return parts.joined(separator: " | ")
    }
}

enum IntelligenceRuntimeDiagnosticState: String, Codable, Equatable, Sendable {
    case deterministicFallback
    case readyForLiveRun
    case liveAppleIntelligence
    case inconclusiveFoundationModels
}

struct IntelligenceRuntimeDiagnostic: Codable, Equatable, Sendable {
    let state: IntelligenceRuntimeDiagnosticState
    let title: String
    let detail: String
    let action: String
    let sourceSummary: String

    init(
        availability: IntelligenceFeatureAvailability,
        captureCoachRun: CaptureCoachRun,
        bracketRecipeRun: BracketRecipeRun
    ) {
        let coachUsedLiveModel = captureCoachRun.source == .foundationModels
            && captureCoachRun.response.usedAppleIntelligence
        let recipeUsedLiveModel = bracketRecipeRun.source == .foundationModels
            && bracketRecipeRun.response.usedAppleIntelligence
        let anyFoundationModelSource = captureCoachRun.source == .foundationModels
            || bracketRecipeRun.source == .foundationModels

        let resolvedSourceSummary = [
            Self.componentSummary(
                label: "Coach",
                source: captureCoachRun.source.rawValue,
                usedAppleIntelligence: captureCoachRun.response.usedAppleIntelligence
            ),
            Self.componentSummary(
                label: "Recipe",
                source: bracketRecipeRun.source.rawValue,
                usedAppleIntelligence: bracketRecipeRun.response.usedAppleIntelligence
            ),
        ].joined(separator: ". ")
        sourceSummary = resolvedSourceSummary

        if coachUsedLiveModel || recipeUsedLiveModel {
            let liveComponents = [
                coachUsedLiveModel ? "Capture Coach" : nil,
                recipeUsedLiveModel ? "Bracket Recipe" : nil,
            ].compactMap { $0 }

            state = .liveAppleIntelligence
            title = "Live Apple Intelligence observed"
            detail = "Foundation Models output observed for \(liveComponents.joined(separator: " and "))."
            action = "Keep this run as physical-device proof and compare its suggestions against deterministic fallback."
        } else if anyFoundationModelSource {
            state = .inconclusiveFoundationModels
            title = "Foundation Models inconclusive"
            detail = "A Foundation Models source returned without usedAppleIntelligence proof."
            action = "Rerun the same coach or recipe action on device and keep the result bundle."
        } else if availability.isUsable {
            state = .readyForLiveRun
            title = "Ready for live Apple Intelligence"
            detail = "Availability is ready, but this session has not observed Foundation Models output yet."
            action = "Refresh Capture Coach or plan a Bracket Recipe on an Apple Intelligence-capable iPhone."
        } else {
            state = .deterministicFallback
            title = "Deterministic fallback active"
            detail = "Availability: \(availability.statusTitle). \(resolvedSourceSummary)."
            action = availability.recoveryAction
                ?? "Run on an Apple Intelligence-capable iPhone to collect live Foundation Models proof."
        }
    }

    var accessibilityValue: String {
        "\(title) | \(detail) | Action: \(action)"
    }

    private static func componentSummary(
        label: String,
        source: String,
        usedAppleIntelligence: Bool
    ) -> String {
        "\(label): \(source) \(usedAppleIntelligence ? "with Apple Intelligence" : "without Apple Intelligence")"
    }
}

enum FoundationModelRuntimeAvailability: Equatable, Sendable {
    case available
    case frameworkUnavailable
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknownUnavailable
}

struct IntelligenceAvailabilityResolver: Equatable, Sendable {
    var userEnabled: Bool
    var runningInSimulator: Bool
    var localeIdentifier: String
    var localeSupported: Bool?

    init(
        userEnabled: Bool = true,
        runningInSimulator: Bool,
        localeIdentifier: String = Locale.current.identifier,
        localeSupported: Bool? = nil
    ) {
        self.userEnabled = userEnabled
        self.runningInSimulator = runningInSimulator
        self.localeIdentifier = localeIdentifier
        self.localeSupported = localeSupported
    }

    func resolve(runtimeAvailability: FoundationModelRuntimeAvailability?) -> IntelligenceFeatureAvailability {
        guard userEnabled else {
            return .disabledByUser
        }

        if runningInSimulator {
            return .simulatorUnsupported
        }

        if localeSupported == false {
            return .localeUnsupported(identifier: localeIdentifier)
        }

        guard let runtimeAvailability else {
            return .sdkUnavailable
        }

        switch runtimeAvailability {
        case .available:
            return .available
        case .frameworkUnavailable:
            return .frameworkUnavailable
        case .deviceNotEligible:
            return .deviceNotEligible
        case .appleIntelligenceNotEnabled:
            return .appleIntelligenceNotEnabled
        case .modelNotReady:
            return .modelNotReady
        case .unknownUnavailable:
            return .unknown(reason: "Foundation Models reported an unavailable state Bracketer does not recognize yet.")
        }
    }
}

enum IntelligenceAvailabilityService {
    static func currentAvailability(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        userEnabled: Bool = true,
        locale: Locale = .autoupdatingCurrent
    ) -> IntelligenceFeatureAvailability {
        if let forced = forcedAvailability(from: arguments) {
            return forced
        }

        guard userEnabled else {
            return .disabledByUser
        }

        if isRunningInSimulator {
            return .simulatorUnsupported
        }

        let resolver = IntelligenceAvailabilityResolver(
            userEnabled: true,
            runningInSimulator: isRunningInSimulator,
            localeIdentifier: locale.identifier,
            localeSupported: currentLocaleSupport(locale)
        )

        return resolver.resolve(runtimeAvailability: currentFoundationModelRuntimeAvailability())
    }

    static func forcedAvailability(from arguments: [String]) -> IntelligenceFeatureAvailability? {
        if arguments.contains("-ui-testing-intelligence-available") {
            return .available
        }
        if arguments.contains("-ui-testing-intelligence-disabled-by-user") {
            return .disabledByUser
        }
        if arguments.contains("-ui-testing-intelligence-unavailable-device") {
            return .deviceNotEligible
        }
        if arguments.contains("-ui-testing-intelligence-unavailable-disabled") {
            return .appleIntelligenceNotEnabled
        }
        if arguments.contains("-ui-testing-intelligence-model-not-ready") {
            return .modelNotReady
        }
        if arguments.contains("-ui-testing-intelligence-sdk-unavailable") {
            return .sdkUnavailable
        }
        return nil
    }

    private static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func currentLocaleSupport(_ locale: Locale) -> Bool? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.supportsLocale(locale)
        }
        return nil
        #else
        return nil
        #endif
    }

    private static func currentFoundationModelRuntimeAvailability() -> FoundationModelRuntimeAvailability? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            @unknown default:
                return .unknownUnavailable
            }
        }
        return .frameworkUnavailable
        #else
        return nil
        #endif
    }
}

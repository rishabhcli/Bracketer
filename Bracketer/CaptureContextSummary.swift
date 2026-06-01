import Foundation
import CoreLocation

struct CaptureContextSettings: Codable, Equatable, Sendable {
    let shootingMode: String
    let showGrid: Bool
    let gridType: String
    let showLevel: Bool
    let focusPeakingEnabled: Bool
    let focusPeakingColorName: String
    let focusPeakingIntensityPercent: Int
    let showHistogram: Bool
    let showZebras: Bool

    init(
        shootingMode: String,
        showGrid: Bool,
        gridType: String,
        showLevel: Bool,
        focusPeakingEnabled: Bool,
        focusPeakingColorName: String,
        focusPeakingIntensity: Float,
        showHistogram: Bool,
        showZebras: Bool
    ) {
        self.shootingMode = shootingMode
        self.showGrid = showGrid
        self.gridType = gridType
        self.showLevel = showLevel
        self.focusPeakingEnabled = focusPeakingEnabled
        self.focusPeakingColorName = focusPeakingColorName
        self.focusPeakingIntensityPercent = Self.percent(from: focusPeakingIntensity)
        self.showHistogram = showHistogram
        self.showZebras = showZebras
    }

    private static func percent(from value: Float) -> Int {
        guard value.isFinite else { return 0 }
        return Int((min(max(value, 0), 1) * 100).rounded())
    }
}

struct CaptureContextSummary: Codable, Equatable, Sendable {
    struct Bracket: Codable, Equatable, Sendable {
        let requestedShotCount: Int
        let resolvedShotCount: Int
        let evStep: Float
        let centerBias: Float
        let evLabels: [String]
        let normalizationReason: String?
    }

    struct Device: Codable, Equatable, Sendable {
        struct Issue: Codable, Equatable, Sendable {
            let id: String
            let title: String
            let severity: String
            let actionPath: String
        }

        let modelIdentifier: String
        let systemVersion: String
        let statusSummary: String
        let capabilityLevel: String
        let lensSummary: String
        let supportsProRAW: Bool
        let photosPermission: String
        let locationPermission: String
        let notificationPermission: String
        let freeStorageMB: Int64?
        let isLowPowerModeEnabled: Bool
        let issues: [Issue]
    }

    struct Capture: Codable, Equatable, Sendable {
        let format: String
        let flash: String
        let isFlashAvailable: Bool
        let timer: String
        let location: String
    }

    struct FrameAnalysis: Codable, Equatable, Sendable {
        let isAvailable: Bool
        let sampleCount: Int
        let shadowClippingPercent: Int
        let highlightClippingPercent: Int
        let hasShadowWarning: Bool
        let hasHighlightWarning: Bool
        let zebraShadowRegions: Int
        let zebraHighlightRegions: Int
        let focusRegionCount: Int
        let guidanceSignals: [String]
    }

    struct Review: Codable, Equatable, Sendable {
        let shotCount: Int
        let selectedPosition: String
        let selectedEVLabel: String?
        let availableShotCount: Int
        let missingShotCount: Int
        let failedShotCount: Int
        let rawAvailableCount: Int
        let clippingWarnings: [String]
        let manifestSource: String?
        let manifestSchemaVersion: Int?
    }

    struct Intelligence: Codable, Equatable, Sendable {
        let status: String
        let detail: String
        let recoveryAction: String?
        let isUsable: Bool
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
    let bracket: Bracket
    let device: Device?
    let capture: Capture
    let settings: CaptureContextSettings
    let frameAnalysis: FrameAnalysis
    let review: Review?
    let intelligence: Intelligence
    let privacy: Privacy

    static func make(
        plan: BracketPlan,
        deviceSnapshot: DeviceCapabilitySnapshot?,
        captureConfiguration: EffectiveCaptureConfiguration,
        settings: CaptureContextSettings,
        frameAnalysis: HistogramFrameAnalysis?,
        reviewSequence: BracketReviewSequence?,
        manifest: BracketManifest?,
        intelligenceAvailability: IntelligenceFeatureAvailability
    ) -> CaptureContextSummary {
        CaptureContextSummary(
            schemaVersion: Self.currentSchemaVersion,
            bracket: Bracket(plan: plan),
            device: deviceSnapshot.map(Device.init(snapshot:)),
            capture: Capture(configuration: captureConfiguration),
            settings: settings,
            frameAnalysis: FrameAnalysis(analysis: frameAnalysis),
            review: reviewSequence.map { Review(sequence: $0, manifest: manifest) },
            intelligence: Intelligence(availability: intelligenceAvailability),
            privacy: Privacy.defaultLocalSummary
        )
    }

    var compactPromptContext: String {
        promptFacts.joined(separator: "\n")
    }

    var promptFacts: [String] {
        var facts: [String] = [
            "Bracket: \(bracket.resolvedShotCount) shots at +/-\(cleanNumber(bracket.evStep)) EV; offsets \(bracket.evLabels.joined(separator: ", ")).",
            "Capture: \(capture.format), flash \(capture.flash), timer \(capture.timer), location \(capture.location).",
            "Settings: \(settings.shootingMode), grid \(settings.showGrid ? settings.gridType : "off"), level \(settings.showLevel ? "on" : "off"), focus peaking \(settings.focusPeakingEnabled ? "\(settings.focusPeakingColorName) \(settings.focusPeakingIntensityPercent)%" : "off"), histogram \(settings.showHistogram ? "on" : "off"), zebras \(settings.showZebras ? "on" : "off").",
            "Frame analysis: \(frameAnalysis.isAvailable ? "\(frameAnalysis.sampleCount) samples" : "unavailable"), shadows \(frameAnalysis.shadowClippingPercent)%, highlights \(frameAnalysis.highlightClippingPercent)%, zebra regions \(frameAnalysis.zebraShadowRegions) shadow / \(frameAnalysis.zebraHighlightRegions) highlight, focus regions \(frameAnalysis.focusRegionCount).",
            "Apple Intelligence: \(intelligence.status). \(intelligence.detail)"
        ]

        if let normalizationReason = bracket.normalizationReason {
            facts.append("Bracket normalization: \(normalizationReason)")
        }

        if let device {
            facts.append("Device: \(device.statusSummary), \(device.capabilityLevel), lenses \(device.lensSummary), ProRAW \(device.supportsProRAW ? "supported" : "unavailable"), issues \(device.issues.count).")
        } else {
            facts.append("Device: compatibility snapshot unavailable.")
        }

        if !frameAnalysis.guidanceSignals.isEmpty {
            facts.append("Signals: \(frameAnalysis.guidanceSignals.joined(separator: ", ")).")
        }

        if let review {
            facts.append("Review: \(review.shotCount) shots, selected \(review.selectedPosition), available \(review.availableShotCount), missing \(review.missingShotCount), failed \(review.failedShotCount), RAW available \(review.rawAvailableCount), manifest \(review.manifestSource ?? "none").")
        } else {
            facts.append("Review: no bracket review loaded.")
        }

        facts.append("Privacy: no raw photo bytes, no asset identifiers, no location coordinates, no user-visible generated copy.")
        return facts
    }

    private func cleanNumber(_ value: Float) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

private extension CaptureContextSummary.Bracket {
    init(plan: BracketPlan) {
        self.requestedShotCount = plan.requestedShotCount
        self.resolvedShotCount = plan.shotCount
        self.evStep = plan.evStep
        self.centerBias = plan.centerBias
        self.evLabels = plan.shots.map(\.displayLabel)
        self.normalizationReason = plan.normalizationReason
    }
}

private extension CaptureContextSummary.Device {
    init(snapshot: DeviceCapabilitySnapshot) {
        self.modelIdentifier = snapshot.modelIdentifier
        self.systemVersion = snapshot.systemVersion
        self.statusSummary = snapshot.statusSummary
        self.capabilityLevel = snapshot.capabilityLevel.contextDisplayName
        self.lensSummary = [
            snapshot.hasWideLens ? "Wide" : nil,
            snapshot.hasUltraWideLens ? "Ultra Wide" : nil,
            snapshot.hasTelephotoLens ? "Telephoto" : nil
        ].compactMap { $0 }.joined(separator: ", ")
        self.supportsProRAW = snapshot.supportsProRAW
        self.photosPermission = snapshot.photosAuthorization.contextDisplayName
        self.locationPermission = snapshot.locationAuthorization.contextDisplayName
        self.notificationPermission = snapshot.notificationAuthorization.contextDisplayName
        self.freeStorageMB = snapshot.freeStorageMB
        self.isLowPowerModeEnabled = snapshot.isLowPowerModeEnabled
        self.issues = snapshot.issues.map { issue in
            Issue(
                id: issue.id,
                title: issue.title,
                severity: issue.severity.rawValue,
                actionPath: issue.actionPath
            )
        }
    }
}

private extension CaptureContextSummary.Capture {
    init(configuration: EffectiveCaptureConfiguration) {
        self.format = configuration.formatDisplayName
        self.flash = configuration.flashDisplayName
        self.isFlashAvailable = configuration.isFlashAvailable
        self.timer = configuration.timerDisplayName
        self.location = configuration.locationState.displayName
    }
}

private extension CaptureContextSummary.FrameAnalysis {
    init(analysis: HistogramFrameAnalysis?) {
        guard let analysis else {
            self.isAvailable = false
            self.sampleCount = 0
            self.shadowClippingPercent = 0
            self.highlightClippingPercent = 0
            self.hasShadowWarning = false
            self.hasHighlightWarning = false
            self.zebraShadowRegions = 0
            self.zebraHighlightRegions = 0
            self.focusRegionCount = 0
            self.guidanceSignals = ["Frame analysis unavailable"]
            return
        }

        self.isAvailable = true
        self.sampleCount = analysis.sampleCount
        self.shadowClippingPercent = Self.percent(from: analysis.clipping.shadowClippedFraction)
        self.highlightClippingPercent = Self.percent(from: analysis.clipping.highlightClippedFraction)
        self.hasShadowWarning = analysis.clipping.hasShadowWarning
        self.hasHighlightWarning = analysis.clipping.hasHighlightWarning
        self.zebraShadowRegions = analysis.zebraMap.shadowRegionCount
        self.zebraHighlightRegions = analysis.zebraMap.highlightRegionCount
        self.focusRegionCount = analysis.focusPeakingMap.regions.count

        var signals: [String] = []
        if hasShadowWarning { signals.append("shadow clipping risk") }
        if hasHighlightWarning { signals.append("highlight clipping risk") }
        if focusRegionCount > 0 { signals.append("focus contrast detected") }
        if signals.isEmpty { signals.append("no strong exposure or focus warning") }
        self.guidanceSignals = signals
    }

    private static func percent(from fraction: Float) -> Int {
        guard fraction.isFinite else { return 0 }
        return Int((min(max(fraction, 0), 1) * 100).rounded())
    }
}

private extension CaptureContextSummary.Review {
    init(sequence: BracketReviewSequence, manifest: BracketManifest?) {
        self.shotCount = sequence.shots.count
        self.selectedPosition = sequence.selectedPositionLabel
        self.selectedEVLabel = sequence.selectedShot?.displayLabel
        self.availableShotCount = sequence.shots.filter { $0.captureState == .available }.count
        self.missingShotCount = sequence.shots.filter { $0.captureState == .missing }.count
        self.failedShotCount = sequence.shots.filter { shot in
            if case .failed = shot.captureState { return true }
            return false
        }.count
        self.rawAvailableCount = sequence.shots.filter { $0.availableRepresentations.contains(.raw) }.count
        self.clippingWarnings = sequence.shots
            .flatMap(\.clippingWarnings)
            .map(\.displayName)
            .uniquePreservingOrder()
        self.manifestSource = manifest?.source.rawValue
        self.manifestSchemaVersion = manifest?.schemaVersion
    }
}

private extension CaptureContextSummary.Intelligence {
    init(availability: IntelligenceFeatureAvailability) {
        self.status = availability.statusTitle
        self.detail = availability.statusDetail
        self.recoveryAction = availability.recoveryAction
        self.isUsable = availability.isUsable
    }
}

private extension CaptureContextSummary.Privacy {
    static let defaultLocalSummary = CaptureContextSummary.Privacy(
        rawPhotoBytesIncluded: false,
        assetIdentifiersIncluded: false,
        locationCoordinatesIncluded: false,
        userVisibleGeneratedCopy: false,
        notes: [
            "Structured capture state only",
            "No raw image pixels",
            "No Photos asset identifiers",
            "No precise location coordinates"
        ]
    )
}

private extension DeviceCapabilityLevel {
    var contextDisplayName: String {
        switch self {
        case .full:
            return "Full"
        case .standard:
            return "Standard"
        case .basic:
            return "Basic"
        case .unsupported:
            return "Unsupported"
        }
    }
}

private extension DevicePermissionState {
    var contextDisplayName: String {
        switch self {
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        case .notDetermined:
            return "Not determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

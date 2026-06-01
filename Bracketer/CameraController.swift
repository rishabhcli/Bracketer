import Foundation
import SwiftUI
import AVFoundation
import CoreMedia
import Photos
import CoreLocation
import UIKit
import UserNotifications
import CoreHaptics
import Combine

private enum Constants {
    static let defaultEVStep: Float = 1.0
    static let preferredTimescale: CMTimeScale = 1_000_000
    static let sessionQueueLabel = "bracketer.session.queue"
    static let aeSettleMaxWait: TimeInterval = 2.0
    static let aeSettlePollInterval: TimeInterval = 0.02
    static let aeOffsetThreshold: Float = 0.10
    static let bracketTimeoutSeconds: TimeInterval = 30.0
    static let minimumStorageMB: Int64 = 500
}

enum CameraKind: CaseIterable, Identifiable {
    case ultraWide, wide, telephoto, twoX, eightX
    var id: String { label }
    var label: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide: return "1×"
        case .twoX: return "2×"
        case .telephoto: return "4×"
        case .eightX: return "8×"
        }
    }
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide, .twoX: return .builtInWideAngleCamera
        case .telephoto, .eightX: return .builtInTelephotoCamera
        }
    }
}

struct CamError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionPath: String?
    let capabilityIssue: DeviceCapabilityIssue?
    let isRecoverable: Bool

    init(
        title: String = "Error",
        message: String,
        actionPath: String? = nil,
        capabilityIssue: DeviceCapabilityIssue? = nil,
        isRecoverable: Bool = true
    ) {
        self.title = title
        self.message = message
        self.actionPath = actionPath
        self.capabilityIssue = capabilityIssue
        self.isRecoverable = isRecoverable
    }

    init(issue: DeviceCapabilityIssue, isRecoverable: Bool? = nil) {
        self.init(
            title: issue.title,
            message: issue.detail,
            actionPath: issue.actionPath,
            capabilityIssue: issue,
            isRecoverable: isRecoverable ?? (issue.severity == .warning)
        )
    }

    var alertMessage: String {
        guard let actionPath, !actionPath.isEmpty else { return message }
        return "\(message)\n\nAction: \(actionPath)"
    }
}

enum CameraRuntimeFailure: Error, Equatable {
    case cameraPermissionDenied
    case photosAddPermissionDenied
    case backCameraUnavailable
    case cameraSessionFailed(reason: String)
    case lowStorage(freeMB: Int64, minimumStorageMB: Int64)

    var capabilityIssue: DeviceCapabilityIssue {
        switch self {
        case .cameraPermissionDenied:
            return .cameraAccessDenied()
        case .photosAddPermissionDenied:
            return .photosAddAccessDenied()
        case .backCameraUnavailable:
            return .cameraUnavailable()
        case .cameraSessionFailed(let reason):
            return .cameraSessionFailed(reason: reason)
        case .lowStorage(let freeMB, let minimumStorageMB):
            return .lowStorage(freeMB: freeMB, minimumStorageMB: minimumStorageMB)
        }
    }

    var camError: CamError {
        CamError(issue: capabilityIssue, isRecoverable: false)
    }

    var diagnosticCategory: CameraRuntimeDiagnosticEvent.Category {
        switch self {
        case .cameraPermissionDenied, .photosAddPermissionDenied:
            return .permissions
        case .backCameraUnavailable, .cameraSessionFailed:
            return .session
        case .lowStorage:
            return .storage
        }
    }
}

struct CameraRuntimeDiagnosticEvent: Identifiable, Equatable, Sendable {
    enum Category: String, Equatable, Sendable {
        case startup = "Startup"
        case permissions = "Permissions"
        case session = "Session"
        case lens = "Lens"
        case planning = "Planning"
        case capture = "Capture"
        case storage = "Storage"
        case recovery = "Recovery"
        case photos = "Photos"
        case review = "Review"
        case histogram = "Histogram"
    }

    enum Severity: String, Equatable, Sendable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
    }

    let id: Int
    let category: Category
    let severity: Severity
    let title: String
    let detail: String
    let actionPath: String?
    let durationMilliseconds: Int?
    let recordedAt: Date

    var accessibilityValue: String {
        var parts = ["\(severity.rawValue)", "\(category.rawValue)", title, detail]
        if let actionPath, !actionPath.isEmpty {
            parts.append("Action: \(actionPath)")
        }
        if let durationMilliseconds {
            parts.append("Duration: \(durationMilliseconds) ms")
        }
        return parts.joined(separator: " | ")
    }

    var exportLine: String {
        var parts = [
            "Event \(id)",
            Self.exportTimestamp(for: recordedAt),
            severity.rawValue,
            category.rawValue,
            title,
            detail
        ]
        if let actionPath, !actionPath.isEmpty {
            parts.append("Action: \(actionPath)")
        }
        if let durationMilliseconds {
            parts.append("Duration: \(durationMilliseconds) ms")
        }
        return parts.joined(separator: " | ")
    }

    private static func exportTimestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

struct CameraRuntimeDiagnostics: Equatable, Sendable {
    private(set) var events: [CameraRuntimeDiagnosticEvent]
    let maxEvents: Int

    init(events: [CameraRuntimeDiagnosticEvent] = [], maxEvents: Int = 30) {
        self.events = Array(events.suffix(maxEvents))
        self.maxEvents = maxEvents
    }

    var latest: CameraRuntimeDiagnosticEvent? {
        events.last
    }

    var summaryAccessibilityValue: String {
        guard let latest else { return "0 events | No diagnostics" }
        return "\(events.count) events | Latest: \(latest.severity.rawValue) \(latest.category.rawValue) | \(latest.title)"
    }

    var latestAccessibilityValue: String {
        latest?.accessibilityValue ?? "No diagnostics"
    }

    var exportText: String {
        var lines = [
            "Bracketer Diagnostics",
            "Events: \(events.count)",
            "Max Events: \(maxEvents)"
        ]

        guard !events.isEmpty else {
            lines.append("No diagnostics recorded.")
            return lines.joined(separator: "\n")
        }

        lines.append(contentsOf: events.map(\.exportLine))
        return lines.joined(separator: "\n")
    }

    func recording(
        category: CameraRuntimeDiagnosticEvent.Category,
        severity: CameraRuntimeDiagnosticEvent.Severity,
        title: String,
        detail: String,
        actionPath: String? = nil,
        durationMilliseconds: Int? = nil,
        recordedAt: Date = Date()
    ) -> CameraRuntimeDiagnostics {
        let nextID = (events.last?.id ?? 0) + 1
        let event = CameraRuntimeDiagnosticEvent(
            id: nextID,
            category: category,
            severity: severity,
            title: title,
            detail: detail,
            actionPath: actionPath,
            durationMilliseconds: durationMilliseconds,
            recordedAt: recordedAt
        )
        return CameraRuntimeDiagnostics(events: events + [event], maxEvents: maxEvents)
    }

    func recording(
        issue: DeviceCapabilityIssue,
        category: CameraRuntimeDiagnosticEvent.Category,
        recordedAt: Date = Date()
    ) -> CameraRuntimeDiagnostics {
        recording(
            category: category,
            severity: issue.severity == .blocker ? .error : .warning,
            title: issue.title,
            detail: issue.detail,
            actionPath: issue.actionPath,
            recordedAt: recordedAt
        )
    }
}

enum CameraRuntimePerformanceThresholds {
    static let photoSaveWarningMilliseconds = 1_500
    static let reviewImageLoadWarningMilliseconds = 1_000
    static let reviewMetadataLoadWarningMilliseconds = 1_000
    static let histogramProcessingWarningMilliseconds = 50

    static func severity(
        durationMilliseconds: Int,
        warningThresholdMilliseconds: Int
    ) -> CameraRuntimeDiagnosticEvent.Severity {
        durationMilliseconds >= warningThresholdMilliseconds ? .warning : .info
    }
}

struct EffectiveCaptureConfiguration: Equatable {
    enum LocationState: Equatable {
        case on
        case pending
        case off
        case unknown

        init(authorizationStatus: CLAuthorizationStatus) {
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self = .on
            case .notDetermined:
                self = .pending
            case .denied, .restricted:
                self = .off
            @unknown default:
                self = .unknown
            }
        }

        var displayName: String {
            switch self {
            case .on:
                return "On"
            case .pending:
                return "Pending"
            case .off:
                return "Off"
            case .unknown:
                return "Unknown"
            }
        }
    }

    let isRawEnabled: Bool
    let flashMode: FlashMode
    let isFlashAvailable: Bool
    let timerMode: TimerMode
    let locationState: LocationState

    static func resolve(
        isRawEnabled: Bool,
        flashMode: FlashMode,
        isFlashAvailable: Bool,
        timerMode: TimerMode,
        locationAuthorizationStatus: CLAuthorizationStatus
    ) -> EffectiveCaptureConfiguration {
        EffectiveCaptureConfiguration(
            isRawEnabled: isRawEnabled,
            flashMode: flashMode,
            isFlashAvailable: isFlashAvailable,
            timerMode: timerMode,
            locationState: LocationState(authorizationStatus: locationAuthorizationStatus)
        )
    }

    var formatDisplayName: String {
        isRawEnabled ? "ProRAW" : "HEIF/JPEG"
    }

    var formatBadgeLabel: String {
        isRawEnabled ? "RAW" : "HEIF"
    }

    var flashDisplayName: String {
        isFlashAvailable ? flashMode.displayName : "Unavailable"
    }

    var flashBadgeLabel: String {
        isFlashAvailable ? flashMode.displayName : "N/A"
    }

    var flashIconName: String {
        isFlashAvailable ? flashMode.iconName : "bolt.slash.circle.fill"
    }

    var timerDisplayName: String {
        timerMode.displayName
    }

    var timerBadgeLabel: String? {
        timerMode == .off ? nil : timerMode.displayName
    }

    var locationDisplayName: String {
        locationState.displayName
    }
}

final class CameraController: NSObject, ObservableObject, @unchecked Sendable {
    @Published var lastError: CamError?
    @Published private(set) var runtimeDiagnostics = CameraRuntimeDiagnostics()
    @Published var isProRAWEnabled: Bool = false
    @Published var selectedCamera: CameraKind = .wide
    @Published var availableCameraKinds: [CameraKind] = [.wide]
    @Published var isInitializing: Bool = false
    @Published private(set) var bracketSequenceState: BracketSequenceState = .idle
    @Published var isCapturing: Bool = false
    @Published var captureProgress: Int = 0
    @Published var countdownSecondsRemaining: Int?
    @Published var currentISO: Float = 100.0
    @Published var currentShutterSpeedText: String = "1/60"
    @Published var lastBracketAssets: [PHAsset] = []
    @Published var lastBracketReviewSequence: BracketReviewSequence?
    @Published var lastBracketManifest: BracketManifest?
    @Published var lastBracketProject: BracketProject?
    @Published var restoredProjectReviewSnapshot: BracketProjectReviewSnapshot?
    @Published private(set) var bracketProjectLibrarySnapshot = BracketProjectLibrarySnapshot.empty
    @Published var activeBracketRecipeRecord: AppliedBracketRecipeRecord?
    @Published var storesGeneratedProjectNotes = false
    @Published var simulatedBracketReview: SimulatedBracketReview?
    @Published var showImageViewer = false
    @Published var currentLensSupportsRaw: Bool = false
    var intelligenceAvailabilityForProjectNotes: IntelligenceFeatureAvailability = .simulatorUnsupported

    @Published var teleUses12MP: Bool = false

    // Manual control capabilities (updated when lens changes)
    @Published var minISO: Float = 50
    @Published var maxISO: Float = 3200
    @Published var minShutterSpeed: Float = 0.00001
    @Published var maxShutterSpeed: Float = 1.0
    @Published var maxWBGain: Float = 4.0

    // Bracketing configuration
    private var activeBracketPlan: BracketPlan?
    private let projectStore: FileBracketProjectStore

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: Constants.sessionQueueLabel)
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?

    private var baseWBGains = AVCaptureDevice.WhiteBalanceGains(redGain: 1, greenGain: 1, blueGain: 1)
    private var baseISO: Float = 100.0
    private var baseShutterSpeed: CMTime = CMTime(value: 1, timescale: 100)
    private var baseFocusPosition: Float = 0.0

    private var sequenceInFlight: Bool = false
    private var sequenceStep: Int = 0
    private var sequenceTimestamp: Int?
    private var bracketAssetIds: [String] = []
    private var sequenceHadLocationSample = false
    private var rawPixelFormat: OSType?
    private var maxPhotoDims: CMVideoDimensions?

    private let locationProvider = LocationProvider()
    let histogramProcessor = HistogramProcessor()
    private let captureMotionRecorder = CaptureMotionRecorder()
    private var exposureUpdateTimer: Timer?
    private var notificationAuthorizationGranted = false
    private var cancellables = Set<AnyCancellable>()
    private var bracketTimeoutTask: DispatchWorkItem?
    private var countdownTask: Task<Void, Never>?
    private var simulatedCaptureTask: Task<Void, Never>?
    private var usesSimulatedCaptureForUITests = false
    private var activeCaptureStartTime: TimeInterval?
    private var hasResolvedPermissions = false
    private var hasConfiguredSession = false

    // Orientation management - weak reference to avoid retain cycle
    weak var orientationManager: OrientationManager? {
        didSet {
            setupOrientationObserver()
        }
    }

    init(projectStore: FileBracketProjectStore = .defaultStore()) {
        self.projectStore = projectStore
        super.init()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-projects") {
            try? projectStore.deleteAll()
        }
        lastBracketProject = try? projectStore.latest()
        refreshBracketProjectLibrary()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-simulated-camera") {
            usesSimulatedCaptureForUITests = true
            isInitializing = false
            availableCameraKinds = [.wide]
            selectedCamera = .wide
            currentLensSupportsRaw = false
        }
    }

    var isFlashAvailable: Bool {
        device?.hasFlash ?? false
    }

    func effectiveCaptureConfiguration(
        flashMode: FlashMode,
        timerMode: TimerMode
    ) -> EffectiveCaptureConfiguration {
        EffectiveCaptureConfiguration.resolve(
            isRawEnabled: isProRAWEnabled,
            flashMode: flashMode,
            isFlashAvailable: isFlashAvailable,
            timerMode: timerMode,
            locationAuthorizationStatus: locationProvider.authorizationStatus
        )
    }

    func recordLatestBracketProject(
        manifest: BracketManifest,
        reviewSequence: BracketReviewSequence?,
        sidecar: BracketManifestSidecar? = nil
    ) {
        let projectSidecar = sidecar ?? BracketManifestSidecar.make(
            manifest: manifest,
            narrativeRun: storedGeneratedProjectNoteRun(
                manifest: manifest,
                reviewSequence: reviewSequence
            ),
            storesGeneratedNote: storesGeneratedProjectNotes
        )
        let project = BracketProject.make(
            manifest: manifest,
            reviewSequence: reviewSequence,
            sidecar: projectSidecar,
            diagnosticsSummary: runtimeDiagnostics.summaryAccessibilityValue
        )
        lastBracketProject = project

        do {
            try projectStore.save(project)
            refreshBracketProjectLibrary()
        } catch {
            recordDiagnostic(
                category: .storage,
                severity: .warning,
                title: "Project persistence failed",
                detail: error.localizedDescription,
                actionPath: "Settings > About > Export Diagnostics"
            )
        }
    }

    private func storedGeneratedProjectNoteRun(
        manifest: BracketManifest,
        reviewSequence: BracketReviewSequence?
    ) -> BracketReviewNarrativeRun? {
        guard storesGeneratedProjectNotes else { return nil }
        let request = BracketReviewNarrativeRequest.make(
            context: BracketNarrativeContext.make(
                manifest: manifest,
                sequence: reviewSequence,
                intelligenceAvailability: intelligenceAvailabilityForProjectNotes
            )
        )
        return DeterministicBracketReviewNarrative.run(
            for: request,
            fallbackReason: "Stored project note generated locally from manifest and review metadata."
        )
    }

    @discardableResult
    func updateLatestProjectResourceInspection(
        shotResources: BracketProjectResourceInspection.ShotResources,
        inspectedAt: Date = Date()
    ) throws -> BracketProject {
        do {
            let latestProject = try projectStore.latest()
            let projectID = lastBracketProject?.id ?? latestProject?.id ?? "latest"
            guard let project = lastBracketProject ?? latestProject else {
                throw BracketProjectResourceInspectionUpdateError.projectNotFound(projectID)
            }
            let inspection = project.resourceInspection?.replacingShotResources(
                shotResources,
                in: project,
                inspectedAt: inspectedAt
            ) ?? BracketProjectResourceInspection.make(
                project: project,
                source: .photosAssetResource,
                inspectedAt: inspectedAt,
                shotResources: [shotResources]
            )
            let updatedProject = project.withResourceInspection(inspection, updatedAt: inspectedAt)
            try projectStore.save(updatedProject)
            main {
                self.lastBracketProject = updatedProject
            }
            refreshBracketProjectLibrary()
            return updatedProject
        } catch {
            recordDiagnostic(
                category: .photos,
                severity: .warning,
                title: "Project resource inspection failed",
                detail: error.localizedDescription,
                actionPath: "Open the latest bracket review again, then export diagnostics."
            )
            throw error
        }
    }

    @discardableResult
    func updateLatestProjectThumbnailInspection(
        shotThumbnail: BracketProjectThumbnailInspection.ShotThumbnail,
        inspectedAt: Date = Date()
    ) throws -> BracketProject {
        do {
            let latestProject = try projectStore.latest()
            let projectID = lastBracketProject?.id ?? latestProject?.id ?? "latest"
            guard let project = lastBracketProject ?? latestProject else {
                throw BracketProjectThumbnailInspectionUpdateError.projectNotFound(projectID)
            }
            let inspection = project.thumbnailInspection?.replacingShotThumbnail(
                shotThumbnail,
                in: project,
                inspectedAt: inspectedAt
            ) ?? BracketProjectThumbnailInspection.make(
                project: project,
                source: .photosImageManager,
                inspectedAt: inspectedAt,
                shotThumbnails: [shotThumbnail]
            )
            let updatedProject = project.withThumbnailInspection(inspection, updatedAt: inspectedAt)
            try projectStore.save(updatedProject)
            main {
                self.lastBracketProject = updatedProject
            }
            refreshBracketProjectLibrary()
            return updatedProject
        } catch {
            recordDiagnostic(
                category: .photos,
                severity: .warning,
                title: "Project thumbnail inspection failed",
                detail: error.localizedDescription,
                actionPath: "Open the latest bracket review again, then export diagnostics."
            )
            throw error
        }
    }

    func refreshBracketProjectLibrary(searchText: String = "") {
        do {
            let snapshot = try projectStore.librarySnapshot(searchText: searchText)
            main { self.bracketProjectLibrarySnapshot = snapshot }
        } catch {
            let snapshot = BracketProjectLibrarySnapshot.failure(error.localizedDescription)
            main { self.bracketProjectLibrarySnapshot = snapshot }
        }
    }

    func restoreLatestProjectReview(
        source: String = "Project Handoff",
        openedAt: Date = Date()
    ) -> BracketProjectReviewSnapshot? {
        do {
            guard let project = try projectStore.latest() else {
                recordDiagnostic(
                    category: .review,
                    severity: .warning,
                    title: "Project review unavailable",
                    detail: "No saved Bracketer project is available to restore.",
                    actionPath: "Capture a bracket, then open the project again."
                )
                return nil
            }
            return restoreProjectReview(project: project, source: source, openedAt: openedAt)
        } catch {
            recordProjectReviewRestoreFailure(error)
            return nil
        }
    }

    func restoreProjectReview(
        projectID: String,
        source: String = "Project Handoff",
        openedAt: Date = Date()
    ) -> BracketProjectReviewSnapshot? {
        do {
            guard let project = try projectStore.load(id: projectID) else {
                recordDiagnostic(
                    category: .review,
                    severity: .warning,
                    title: "Project review unavailable",
                    detail: "Saved project \(projectID) could not be found.",
                    actionPath: "Open Settings > About > Project Library and choose an available project."
                )
                return nil
            }
            return restoreProjectReview(project: project, source: source, openedAt: openedAt)
        } catch {
            recordProjectReviewRestoreFailure(error)
            return nil
        }
    }

    func clearRestoredProjectReview() {
        restoredProjectReviewSnapshot = nil
    }

    func importProjectArchiveText(
        _ archiveText: String,
        importedAt: Date = Date(),
        conflictPolicy: BracketProjectImportConflictPolicy = .keepBoth
    ) throws -> BracketProjectImportBundle {
        do {
            let importBundle = try projectStore.importArchiveText(
                archiveText,
                importedAt: importedAt,
                conflictPolicy: conflictPolicy
            )
            let project = importBundle.project
            let sequence = BracketReviewSequence.make(manifest: project.manifest)
            main {
                self.lastBracketProject = project
                self.lastBracketManifest = project.manifest
                self.lastBracketReviewSequence = sequence
            }
            refreshBracketProjectLibrary()
            return importBundle
        } catch {
            recordDiagnostic(
                category: .storage,
                severity: .warning,
                title: "Project import failed",
                detail: error.localizedDescription,
                actionPath: "Settings > About > Import Project Bundle"
            )
            throw error
        }
    }

    func previewProjectArchiveText(
        _ archiveText: String,
        importedAt: Date = Date(),
        conflictPolicy: BracketProjectImportConflictPolicy = .keepBoth
    ) throws -> BracketProjectImportPreview {
        do {
            return try projectStore.importPreview(
                archiveText,
                importedAt: importedAt,
                conflictPolicy: conflictPolicy
            )
        } catch {
            recordDiagnostic(
                category: .storage,
                severity: .warning,
                title: "Project import preview failed",
                detail: error.localizedDescription,
                actionPath: "Settings > About > Import Project Bundle"
            )
            throw error
        }
    }

    func updateProjectCuration(
        projectID: String,
        isFavorite: Bool,
        acceptedTags: [String],
        userNote: String?,
        updatedAt: Date = Date()
    ) throws -> BracketProject {
        do {
            guard let updatedProject = try projectStore.updateCuration(
                id: projectID,
                isFavorite: isFavorite,
                acceptedTags: acceptedTags,
                userNote: userNote,
                updatedAt: updatedAt
            ) else {
                throw BracketProjectCurationError.projectNotFound(projectID)
            }
            let sequence = BracketReviewSequence.make(manifest: updatedProject.manifest)
            main {
                self.lastBracketProject = updatedProject
                self.lastBracketManifest = updatedProject.manifest
                self.lastBracketReviewSequence = sequence
            }
            refreshBracketProjectLibrary()
            return updatedProject
        } catch {
            recordDiagnostic(
                category: .storage,
                severity: .warning,
                title: "Project curation failed",
                detail: error.localizedDescription,
                actionPath: "Settings > About > Project Library"
            )
            throw error
        }
    }

    deinit {
        exposureUpdateTimer?.invalidate()
        countdownTask?.cancel()
        simulatedCaptureTask?.cancel()
        cancellables.removeAll()
    }

    func enableSimulatedCaptureForUITests() {
        usesSimulatedCaptureForUITests = true
        main {
            self.isInitializing = false
            self.availableCameraKinds = [.wide]
            self.selectedCamera = .wide
            self.currentLensSupportsRaw = false
        }
    }

    private func restoreProjectReview(
        project: BracketProject,
        source: String,
        openedAt: Date
    ) -> BracketProjectReviewSnapshot? {
        do {
            try projectStore.setCurrentProjectID(project.id)
            let snapshot = BracketProjectReviewSnapshot(
                project: project,
                openedAt: openedAt,
                source: source
            )
            main {
                self.lastBracketProject = project
                self.lastBracketManifest = project.manifest
                self.lastBracketReviewSequence = snapshot.sequence
                self.restoredProjectReviewSnapshot = snapshot
                self.showImageViewer = false
            }
            refreshBracketProjectLibrary()
            return snapshot
        } catch {
            recordProjectReviewRestoreFailure(error)
            return nil
        }
    }

    private func recordProjectReviewRestoreFailure(_ error: Error) {
        recordDiagnostic(
            category: .review,
            severity: .warning,
            title: "Project review restore failed",
            detail: error.localizedDescription,
            actionPath: "Open Settings > About > Project Library and retry."
        )
    }

    private func setupOrientationObserver() {
        // Use Task @MainActor to safely access @MainActor-isolated properties
        Task { @MainActor [weak self] in
            guard let self = self, let orientationManager = self.orientationManager else { return }

            // Observe orientation changes and update photo output rotation
            orientationManager.$currentOrientation
                .dropFirst() // Skip initial value
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    // Already on main actor from publisher delivery
                    Task { @MainActor [weak self] in
                        guard let self = self, let orientationManager = self.orientationManager else { return }
                        let angle = orientationManager.videoRotationAngle(for: orientationManager.effectiveOrientation)
                        self.sessionQueue.async {
                            self.applyRotationWithAngle(angle, to: self.photoOutput.connection(with: .video))
                        }
                    }
                }
                .store(in: &self.cancellables)

            Logger.camera("Orientation observer connected")
        }
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        sessionQueue.async {
            self.previewLayer = layer
            layer.videoGravity = .resizeAspectFill
            // Preview layer is not rotated - stays fixed to device screen
            // Only photo output connection is rotated via OrientationManager
            self.applyRotationAsync()
        }
    }

    func start() async {
        if isInitializing {
            return
        }

        let startupStart = CACurrentMediaTime()
        recordDiagnostic(
            category: .startup,
            severity: .info,
            title: "Camera Startup",
            detail: "Starting camera runtime services."
        )
        main { self.isInitializing = true }
        do {
            let permissionsStart = CACurrentMediaTime()
            if !hasResolvedPermissions {
                try await requestPermissions()
                hasResolvedPermissions = true
            }
            recordDiagnostic(
                category: .permissions,
                severity: .info,
                title: "Permissions Ready",
                detail: "Camera and Photos add permissions are available.",
                durationMilliseconds: Self.elapsedMilliseconds(since: permissionsStart)
            )
        } catch {
            main {
                let startupError = self.camError(for: error)
                let category = (error as? CameraRuntimeFailure)?.diagnosticCategory ?? .recovery
                self.recordDiagnostic(for: startupError, category: category)
                self.lastError = startupError
                self.isInitializing = false
            }
            return
        }

        if !hasConfiguredSession {
            await configureSession(initialKind: selectedCamera)
            hasConfiguredSession = true
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.histogramProcessor.skipProcessing = false
            if !self.session.isRunning {
                self.session.startRunning()
                Logger.cameraSession("started")
                self.recordDiagnostic(
                    category: .session,
                    severity: .info,
                    title: "Session Running",
                    detail: "AVCaptureSession started."
                )
                self.recordDiagnostic(
                    category: .startup,
                    severity: .info,
                    title: "Camera Startup Complete",
                    detail: "Camera runtime services are active.",
                    durationMilliseconds: Self.elapsedMilliseconds(since: startupStart)
                )
            }
        }

        locationProvider.start()

        main {
            self.isInitializing = false
            if self.exposureUpdateTimer == nil {
                self.exposureUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    self?.updateExposureUI()
                }
            }
        }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.sequenceInFlight {
                self.finishSequence(
                    terminalState: .cancelled(plan: self.activeBracketPlan, reason: "Runtime stopped"),
                    shouldFetchAssets: false,
                    shouldNotify: false
                )
            }

            self.histogramProcessor.skipProcessing = true
            self.locationProvider.stop()

            if self.session.isRunning {
                self.session.stopRunning()
                Logger.cameraSession("stopped")
                self.recordDiagnostic(
                    category: .session,
                    severity: .info,
                    title: "Session Stopped",
                    detail: "AVCaptureSession stopped."
                )
            }
        }

        main {
            self.isInitializing = false
            self.countdownSecondsRemaining = nil
            self.exposureUpdateTimer?.invalidate()
            self.exposureUpdateTimer = nil
        }
    }

    func setExposureCompensation(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let dev = self.device else { return }

            let supportedRange = -dev.maxExposureTargetBias...dev.maxExposureTargetBias
            let clampedBias = min(max(bias, supportedRange.lowerBound), supportedRange.upperBound)

            do {
                try dev.lockForConfiguration()
                dev.setExposureTargetBias(clampedBias, completionHandler: nil)
                dev.unlockForConfiguration()
                Logger.camera("Set exposure compensation bias: \(clampedBias)")
            } catch {
                Logger.camera("Failed to set exposure compensation: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func requestPermissions() async throws {
        let camOK = await AVCaptureDevice.requestAccess(for: .video)
        Logger.permissionRequest("Camera", granted: camOK)
        guard camOK else {
            throw CameraRuntimeFailure.cameraPermissionDenied
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        let photosOK = status == .authorized || status == .limited
        Logger.permissionRequest("Photos Add", granted: photosOK)
        guard photosOK else {
            throw CameraRuntimeFailure.photosAddPermissionDenied
        }
        locationProvider.requestWhenInUse()
        notificationAuthorizationGranted = await requestNotificationAuthorization()
    }

    private func requestNotificationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureSession(initialKind: CameraKind) async {
        let configurationStart = CACurrentMediaTime()
        recordDiagnostic(
            category: .session,
            severity: .info,
            title: "Session Configuration",
            detail: "Configuring \(initialKind.label) camera session."
        )
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                self.histogramProcessor.attachToSession(self.session)

                self.setInput(kind: initialKind)
                self.discoverAvailableCameraKinds()
                self.selectBestPhotoFormat()
                self.configureProRAW()
                self.configureMaxPhotoDimensions()

                self.session.commitConfiguration()
                self.recordDiagnostic(
                    category: .session,
                    severity: .info,
                    title: "Session Configured",
                    detail: "Configured \(self.selectedCamera.label) camera session with \(self.availableCameraKinds.count) discovered lens option(s).",
                    durationMilliseconds: Self.elapsedMilliseconds(since: configurationStart)
                )
                cont.resume()
            }
        }
        sessionQueue.async {
            // Apply rotation to photo output (not preview layer)
            self.applyRotationAsync()
            self.applyZoomForSelectedCamera(kind: initialKind)
        }
    }

    private func configureMaxPhotoDimensions() {
        let desire48 = CMVideoDimensions(width: 8064, height: 6048)
        let desire12 = CMVideoDimensions(width: 4032, height: 3024)

        // iOS 26+ only - maxPhotoDimensions always available
        if let dev = self.device {
            let supported = dev.activeFormat.supportedMaxPhotoDimensions
            let targetDims: CMVideoDimensions
            switch self.selectedCamera {
            case .twoX, .eightX:
                targetDims = (self.teleUses12MP ? desire12 : desire48)
            default:
                targetDims = desire48
            }

                if supported.contains(where: { $0.width == targetDims.width && $0.height == targetDims.height }) {
                    self.photoOutput.maxPhotoDimensions = targetDims
                    self.maxPhotoDims = targetDims
            } else if let best = supported.max(by: { ($0.width * $0.height) < ($1.width * $1.height) }) {
                self.photoOutput.maxPhotoDimensions = best
                self.maxPhotoDims = best
            }
        }
    }

    func presentMostRecentAsset() {
        sessionQueue.async {
            if self.simulatedBracketReview != nil {
                self.main { self.showImageViewer = true }
                return
            }

            if !self.lastBracketAssets.isEmpty {
                self.main { self.showImageViewer = true }
                return
            }
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1
            let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            guard let asset = result.firstObject else {
                Logger.photo("No recent assets available to present")
                return
            }
            self.main {
                self.lastBracketAssets = [asset]
                self.lastBracketReviewSequence = nil
                self.lastBracketManifest = nil
                self.lastBracketProject = nil
                self.showImageViewer = true
            }
        }
    }

    func switchCamera(to kind: CameraKind) {
        guard selectedCamera != kind else { return }
        // Provide haptic feedback for lens switching
        main { HapticManager.shared.lensSwitched() }
        sessionQueue.async {
            // Keep track of which logical camera we are switching to
            self.session.beginConfiguration()
            if let existing = self.input {
                self.session.removeInput(existing)
                self.input = nil
            }
            self.setInput(kind: kind)
            self.selectBestPhotoFormat()
            self.configureProRAW()
            self.configureMaxPhotoDimensions()
            self.session.commitConfiguration()

            // Apply rotation to photo output after camera switch
            self.applyRotationAsync()
            self.applyZoomForSelectedCamera(kind: kind)
            self.main { self.selectedCamera = kind }
        }
    }

    private func discoverAvailableCameraKinds() {
        let allKinds: [CameraKind] = [.ultraWide, .wide, .twoX, .telephoto, .eightX]
        var discovered: [CameraKind] = []

        for kind in allKinds {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [kind.deviceType],
                mediaType: .video,
                position: .back
            )
            if !discovery.devices.isEmpty {
                discovered.append(kind)
            }
        }

        if discovered.isEmpty {
            discovered = [.wide]
        }

        main {
            self.availableCameraKinds = discovered
        }
    }

    private func setInput(kind: CameraKind) {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [kind.deviceType],
            mediaType: .video,
            position: .back
        )
        guard let dev = discovery.devices.first else {
            self.postError(.backCameraUnavailable)
            return
        }
        Logger.camera("Selected lens \(kind.label) (\(dev.localizedName)) with \(dev.formats.count) formats")
        self.device = dev
        do {
            let inp = try AVCaptureDeviceInput(device: dev)
            if self.session.canAddInput(inp) {
                self.session.addInput(inp)
                self.input = inp
                self.recordDiagnostic(
                    category: .lens,
                    severity: .info,
                    title: "Lens Input Ready",
                    detail: "\(kind.label) \(dev.localizedName) input added with \(dev.formats.count) format(s)."
                )
            }
        } catch {
            self.postError(.cameraSessionFailed(reason: error.localizedDescription))
        }
        self.updateDeviceCapabilities()
    }

    private func selectBestPhotoFormat() {
        guard let dev = self.device else { return }
        // iOS 26+ only - format selection always available
        do {
            try dev.lockForConfiguration()
            defer { dev.unlockForConfiguration() }

            let desire48 = (width: Int32(8064), height: Int32(6048))
            let desire12 = (width: Int32(4032), height: Int32(3024))
            let target = ((self.selectedCamera == .twoX || self.selectedCamera == .eightX) && self.teleUses12MP) ? desire12 : desire48

            // Prefer formats that support the target size and RAW if available
            let preferredFormats = dev.formats.sorted { a, b in
                let aDims = a.supportedMaxPhotoDimensions
                let bDims = b.supportedMaxPhotoDimensions
                let aHasTarget = aDims.contains { $0.width == target.width && $0.height == target.height }
                let bHasTarget = bDims.contains { $0.width == target.width && $0.height == target.height }
                if aHasTarget != bHasTarget { return aHasTarget && !bHasTarget }
                // Fall back to larger total pixel count
                let aMax = aDims.max(by: { ($0.width * $0.height) < ($1.width * $1.height) })
                let bMax = bDims.max(by: { ($0.width * $0.height) < ($1.width * $1.height) })
                let aPixels = Int64((aMax?.width ?? 0) * (aMax?.height ?? 0))
                let bPixels = Int64((bMax?.width ?? 0) * (bMax?.height ?? 0))
                return aPixels > bPixels
            }

            for fmt in preferredFormats {
                dev.activeFormat = fmt
                // If ProRAW is desired, ensure RAW is available
                if self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty {
                    continue
                }
                // If we reached here, we found a suitable format
                break
            }
            let supportsRaw = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
            Logger.camera("Lens \(self.selectedCamera.label) active format: \(String(describing: dev.activeFormat)) RAW supported: \(supportsRaw)")
            main { self.currentLensSupportsRaw = supportsRaw }
        } catch {
            self.postError("Format selection failed: \(error.localizedDescription)")
        }
    }

    private func configureProRAW() {
        let supportsRaw = self.photoOutput.isAppleProRAWSupported && !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
        if supportsRaw {
            self.photoOutput.isAppleProRAWEnabled = true
            self.main {
                self.isProRAWEnabled = true
                self.currentLensSupportsRaw = true
            }
        } else {
            self.photoOutput.isAppleProRAWEnabled = false
            self.main {
                self.isProRAWEnabled = false
                self.currentLensSupportsRaw = false
            }
        }
        Logger.photo("ProRAW supported: \(self.photoOutput.isAppleProRAWSupported), available RAW types: \(self.photoOutput.availableRawPhotoPixelFormatTypes.count), enabled: \(self.photoOutput.isAppleProRAWEnabled)")
    }

    /// Apply video rotation with pre-computed angle (thread-safe, can be called from sessionQueue)
    /// Note: We do not rotate the preview layer - only the photo output connection
    private func applyRotationWithAngle(_ angle: CGFloat, to connection: AVCaptureConnection?) {
        guard let conn = connection else { return }

        if conn.isVideoRotationAngleSupported(angle) {
            conn.videoRotationAngle = angle
        }
        if conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = false
        }

        Logger.camera("Applied rotation: \(angle)°")
    }

    /// Apply rotation by fetching orientation from main actor and dispatching to sessionQueue
    /// Must be called when you need fresh orientation data
    private func applyRotationAsync() {
        Task { @MainActor in
            guard let orientationManager = self.orientationManager else { return }
            let angle = orientationManager.videoRotationAngle(for: orientationManager.effectiveOrientation)
            self.sessionQueue.async {
                self.applyRotationWithAngle(angle, to: self.photoOutput.connection(with: .video))
            }
        }
    }

    private func applyZoomForSelectedCamera(kind: CameraKind? = nil) {
        guard let dev = self.device else { return }

        let logicalCamera = kind ?? self.selectedCamera

        do {
            try dev.lockForConfiguration()
            switch logicalCamera {
            case .twoX:
                dev.videoZoomFactor = min(max(2.0, dev.minAvailableVideoZoomFactor), dev.maxAvailableVideoZoomFactor)
            case .eightX:
                // Base telephoto is 4x; apply additional digital zoom to reach an 8x view when possible
                let desiredZoom: CGFloat = 8.0
                let clampedZoom = min(max(desiredZoom, dev.minAvailableVideoZoomFactor), dev.maxAvailableVideoZoomFactor)
                dev.videoZoomFactor = clampedZoom
            default:
                dev.videoZoomFactor = 1.0
            }
            dev.unlockForConfiguration()
        } catch {
            self.postError("Zoom configuration failed: \(error.localizedDescription)")
        }
    }

    func toggleProRAW() {
        sessionQueue.async {
            guard self.photoOutput.isAppleProRAWSupported,
                  !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty else {
                Logger.camera("Attempted to toggle ProRAW on unsupported lens")
                return
            }
            self.photoOutput.isAppleProRAWEnabled.toggle()
            self.main { self.isProRAWEnabled = self.photoOutput.isAppleProRAWEnabled }
            Logger.photo("ProRAW supported: \(self.photoOutput.isAppleProRAWSupported), enabled: \(self.photoOutput.isAppleProRAWEnabled)")
        }
    }

    // MARK: - Manual Camera Controls

    /// Update published min/max capabilities from the current device's active format
    private func updateDeviceCapabilities() {
        guard let dev = self.device else { return }
        let isoMin = dev.activeFormat.minISO
        let isoMax = dev.activeFormat.maxISO
        let durMin = Float(CMTimeGetSeconds(dev.activeFormat.minExposureDuration))
        let durMax = Float(CMTimeGetSeconds(dev.activeFormat.maxExposureDuration))
        let wbMax = dev.maxWhiteBalanceGain
        main {
            self.minISO = isoMin
            self.maxISO = isoMax
            self.minShutterSpeed = max(durMin, 0.00001)
            self.maxShutterSpeed = durMax
            self.maxWBGain = wbMax
        }
        Logger.camera("Device capabilities: ISO \(isoMin)-\(isoMax), shutter \(durMin)-\(durMax)s, WB gain max \(wbMax)")
    }

    func setManualISO(_ iso: Float) {
        sessionQueue.async { [weak self] in
            guard let self = self, let dev = self.device else { return }
            let clamped = min(max(iso, dev.activeFormat.minISO), dev.activeFormat.maxISO)
            do {
                try dev.lockForConfiguration()
                dev.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: clamped)
                dev.unlockForConfiguration()
                Logger.camera("Set manual ISO: \(clamped)")
            } catch {
                Logger.camera("Failed to set ISO: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func setManualShutterSpeed(_ duration: Float) {
        sessionQueue.async { [weak self] in
            guard let self = self, let dev = self.device else { return }
            let minDur = CMTimeGetSeconds(dev.activeFormat.minExposureDuration)
            let maxDur = CMTimeGetSeconds(dev.activeFormat.maxExposureDuration)
            let clamped = min(max(Double(duration), minDur), maxDur)
            let cmTime = CMTimeMakeWithSeconds(clamped, preferredTimescale: Constants.preferredTimescale)
            do {
                try dev.lockForConfiguration()
                dev.setExposureModeCustom(duration: cmTime, iso: AVCaptureDevice.currentISO)
                dev.unlockForConfiguration()
                Logger.camera("Set manual shutter: \(clamped)s")
            } catch {
                Logger.camera("Failed to set shutter speed: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func setManualWhiteBalance(temperature: Float) {
        sessionQueue.async { [weak self] in
            guard let self = self, let dev = self.device else { return }
            let tempTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: temperature, tint: 0
            )
            var gains = dev.deviceWhiteBalanceGains(for: tempTint)
            gains = self.clampWBGains(gains, for: dev)
            do {
                try dev.lockForConfiguration()
                dev.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                dev.unlockForConfiguration()
                Logger.camera("Set manual WB: \(temperature)K")
            } catch {
                Logger.camera("Failed to set white balance: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func setManualFocus(position: Float) {
        sessionQueue.async { [weak self] in
            guard let self = self, let dev = self.device else { return }
            let clamped = min(max(position, 0), 1)
            do {
                try dev.lockForConfiguration()
                dev.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
                dev.unlockForConfiguration()
                Logger.camera("Set manual focus: \(clamped)")
            } catch {
                Logger.camera("Failed to set focus: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func resetToAutoExposure() {
        sessionQueue.async { [weak self] in
            guard let self = self, let dev = self.device else { return }
            do {
                try dev.lockForConfiguration()
                if dev.isExposureModeSupported(.continuousAutoExposure) {
                    dev.exposureMode = .continuousAutoExposure
                }
                if dev.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    dev.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                if dev.isFocusModeSupported(.continuousAutoFocus) {
                    dev.focusMode = .continuousAutoFocus
                }
                dev.setExposureTargetBias(0, completionHandler: nil)
                dev.unlockForConfiguration()
                Logger.camera("Reset to auto exposure/WB/focus")
            } catch {
                Logger.camera("Failed to reset to auto: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func captureLockdownBracket(
        evStep: Float = Constants.defaultEVStep,
        shotCount: Int = 3,
        flashMode: FlashMode = .off,
        timerMode: TimerMode = .off,
        exposureCompensation: Float = 0
    ) {
        guard !bracketSequenceState.isActive && !sequenceInFlight && countdownTask == nil else { return }
        let plan = BracketPlan(evStep: evStep, requestedShotCount: shotCount, centerBias: exposureCompensation)
        recordDiagnostic(
            category: .planning,
            severity: plan.normalizationReason == nil ? .info : .warning,
            title: "Bracket Plan",
            detail: "\(plan.shotCount) shot(s), \(plan.evStep) EV step, center bias \(plan.centerBias)."
        )

        if let normalizationReason = plan.normalizationReason {
            postError(normalizationReason)
        }

        if usesSimulatedCaptureForUITests {
            beginBracketCapture(
                plan: plan,
                flashMode: flashMode,
                exposureCompensation: exposureCompensation
            )
            return
        }

        if let storageFailure = storagePreflightFailure() {
            postError(storageFailure)
            return
        }

        if timerMode == .off {
            beginBracketCapture(
                plan: plan,
                flashMode: flashMode,
                exposureCompensation: exposureCompensation
            )
        } else {
            startCountdownAndCapture(
                plan: plan,
                flashMode: flashMode,
                timerMode: timerMode,
                exposureCompensation: exposureCompensation
            )
        }
    }

    private func startCountdownAndCapture(
        plan: BracketPlan,
        flashMode: FlashMode,
        timerMode: TimerMode,
        exposureCompensation: Float
    ) {
        let countdownSeconds = timerMode.seconds
        guard countdownSeconds > 0 else {
            beginBracketCapture(
                plan: plan,
                flashMode: flashMode,
                exposureCompensation: exposureCompensation
            )
            return
        }

        main {
            self.countdownSecondsRemaining = countdownSeconds
        }

        countdownTask = Task { [weak self] in
            guard let self else { return }

            defer {
                self.main {
                    self.countdownSecondsRemaining = nil
                }
                self.countdownTask = nil
            }

            for remaining in stride(from: countdownSeconds, through: 1, by: -1) {
                if Task.isCancelled {
                    return
                }

                self.main {
                    self.countdownSecondsRemaining = remaining
                }

                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }

            if Task.isCancelled {
                return
            }

            self.beginBracketCapture(
                plan: plan,
                flashMode: flashMode,
                exposureCompensation: exposureCompensation
            )
        }
    }

    private func beginBracketCapture(
        plan: BracketPlan,
        flashMode: FlashMode,
        exposureCompensation: Float
    ) {
        if usesSimulatedCaptureForUITests {
            recordDiagnostic(
                category: .capture,
                severity: .info,
                title: "Simulated Bracket Capture",
                detail: "Starting deterministic UI-test bracket capture."
            )
            beginSimulatedBracketCapture(plan: plan)
            return
        }

        let resolvedFlashMode = resolveFlashMode(flashMode)
        setBracketSequenceState(.preparing(plan: plan))

        sessionQueue.async {
            guard let dev = self.device else {
                self.failSequence(plan: plan, message: "Camera device not available")
                return
            }

            self.sequenceInFlight = true
            self.activeBracketPlan = plan
            self.activeCaptureStartTime = CACurrentMediaTime()
            self.captureMotionRecorder.start()
            self.histogramProcessor.skipProcessing = true
            self.sequenceTimestamp = Int(Date().timeIntervalSince1970)
            self.sequenceHadLocationSample = false
            self.rawPixelFormat = self.chooseRawPixelFormat()

            // Lock orientation to ensure all bracketed photos have the same orientation
            Task { @MainActor [weak self] in
                self?.orientationManager?.lockOrientation()
            }

            let evOffsets = plan.evOffsets
            Logger.camera("Starting bracket capture with \(plan.shotCount) shots at ±\(plan.evStep) EV: \(evOffsets)")
            self.recordDiagnostic(
                category: .capture,
                severity: .info,
                title: "Bracket Capture Started",
                detail: "\(plan.shotCount) shot(s) with offsets \(evOffsets)."
            )

            // Prepare device for auto exposure to establish baseline
            do {
                try dev.lockForConfiguration()
                if dev.isExposureModeSupported(.continuousAutoExposure) {
                    dev.exposureMode = .continuousAutoExposure
                }
                if dev.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    dev.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                if dev.isFocusModeSupported(.continuousAutoFocus) {
                    dev.focusMode = .continuousAutoFocus
                }
                let supportedRange = -dev.maxExposureTargetBias...dev.maxExposureTargetBias
                let clampedBias = min(max(exposureCompensation, supportedRange.lowerBound), supportedRange.upperBound)
                dev.setExposureTargetBias(clampedBias, completionHandler: nil)
                dev.unlockForConfiguration()
            } catch {
                self.failSequence(plan: plan, message: "Auto baseline failed: \(error.localizedDescription)")
                return
            }

            // Wait for AE to settle before capturing bracket
            self.settleAutoExposure { [weak self] in
                guard let self = self else { return }
                self.applyRotationAsync()
                self.main {
                    HapticManager.shared.captureStarted()
                }
                self.setBracketSequenceState(.capturing(plan: plan, currentIndex: 0, completedShots: 0))

                // Schedule bracket timeout safety net
                self.scheduleBracketTimeout()

                if let rawFmt = self.rawPixelFormat {
                    self.captureBracketSequenceWithAPI(
                        evOffsets: evOffsets,
                        rawFormat: rawFmt,
                        flashMode: resolvedFlashMode
                    )
                } else {
                    Logger.camera("RAW unavailable for \(self.selectedCamera.label); falling back to processed HEIF bracket.")
                    self.captureBracketSequenceProcessed(
                        evOffsets: evOffsets,
                        flashMode: resolvedFlashMode
                    )
                }
            }
        }
    }

    // MARK: - Apple Bracketing API Implementation
    private func captureBracketSequenceWithAPI(
        evOffsets: [Float],
        rawFormat: OSType,
        flashMode: AVCaptureDevice.FlashMode
    ) {
        // Create bracketed still image settings using Apple's API
        let bracketSettings: [AVCaptureBracketedStillImageSettings] = evOffsets.map { evOffset in
            AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: evOffset)
        }

        // Create photo settings for bracketed capture
        let photoSettings = AVCapturePhotoBracketSettings(
            rawPixelFormatType: rawFormat,
            processedFormat: nil,
            bracketedSettings: bracketSettings
        )

        // iOS 26+ only - maxPhotoDimensions and photoQualityPrioritization always available
        if let dims = self.maxPhotoDims {
            photoSettings.maxPhotoDimensions = dims
        }
        photoSettings.flashMode = flashMode

        // Store expected shot count for progress tracking
        self.sequenceStep = 0

        Logger.camera("Capturing bracket with \(bracketSettings.count) exposures using AVCapturePhotoBracketSettings")

        // Capture the entire bracket atomically
        self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    private func captureBracketSequenceProcessed(
        evOffsets: [Float],
        flashMode: AVCaptureDevice.FlashMode
    ) {
        let bracketSettings: [AVCaptureBracketedStillImageSettings] = evOffsets.map {
            AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: $0)
        }

        let preferredCodec = self.photoOutput.availablePhotoCodecTypes.contains(.hevc) ? AVVideoCodecType.hevc : .jpeg
        let photoSettings = AVCapturePhotoBracketSettings(
            rawPixelFormatType: 0,
            processedFormat: [AVVideoCodecKey: preferredCodec],
            bracketedSettings: bracketSettings
        )
        if let dims = self.maxPhotoDims {
            photoSettings.maxPhotoDimensions = dims
        }
        photoSettings.flashMode = flashMode
        self.sequenceStep = 0
        Logger.camera("Capturing processed bracket (\(preferredCodec.rawValue)) with \(bracketSettings.count) exposures")
        self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    private func preferredQualityPrioritization() -> AVCapturePhotoOutput.QualityPrioritization {
        let maxPriority = photoOutput.maxPhotoQualityPrioritization

        // For bracketed capture on iOS 26 we've seen crashes when requesting
        // a priority higher than what the output effectively supports.
        // To be absolutely safe, clamp to .balanced or .speed only.
        switch maxPriority {
        case .speed:
            return .speed
        case .balanced:
            return .balanced
        case .quality:
            // .quality may not be reliably supported for ProRAW brackets,
            // so prefer .balanced even if .quality is reported as available.
            return .balanced
        @unknown default:
            return .speed
        }
    }

    private func resolveFlashMode(_ selectedFlashMode: FlashMode) -> AVCaptureDevice.FlashMode {
        guard let device, device.hasFlash else {
            return .off
        }

        switch selectedFlashMode {
        case .auto:
            return .auto
        case .on:
            return .on
        case .off:
            return .off
        }
    }

    private func settleAutoExposure(timeout: TimeInterval = Constants.aeSettleMaxWait, poll: TimeInterval = Constants.aeSettlePollInterval, threshold: Float = Constants.aeOffsetThreshold, completion: @escaping () -> Void) {
        let start = CACurrentMediaTime()
        func check() {
            // Safely unwrap self and device to prevent crashes if deallocated
            guard let device = self.device else {
                completion()
                return
            }
            let off = device.exposureTargetOffset
            if abs(off) <= threshold {
                completion()
                return
            }
            if CACurrentMediaTime() - start >= timeout {
                completion() // timeout, proceed with best effort
                return
            }
            self.sessionQueue.asyncAfter(deadline: .now() + poll) { [weak self] in
                guard self != nil else {
                    completion()
                    return
                }
                check()
            }
        }
        self.sessionQueue.async { [weak self] in
            guard self != nil else {
                completion()
                return
            }
            check()
        }
    }


    // MARK: - Storage & Timeout Helpers

    private func storagePreflightFailure() -> CameraRuntimeFailure? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                let freeMB = freeSize / (1024 * 1024)
                if freeMB < Constants.minimumStorageMB {
                    Logger.camera("Low storage: \(freeMB) MB available")
                    return .lowStorage(freeMB: freeMB, minimumStorageMB: Constants.minimumStorageMB)
                }
            }
        } catch {
            Logger.error("Could not check storage: \(error.localizedDescription)")
        }
        return nil
    }

    private func scheduleBracketTimeout() {
        bracketTimeoutTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, self.sequenceInFlight else { return }
            guard let plan = self.activeBracketPlan else {
                self.finishSequence(terminalState: .failed(plan: nil, message: "Bracket capture timed out without an active plan."), shouldFetchAssets: false, shouldNotify: false)
                return
            }
            Logger.error("Bracket capture timed out after \(Constants.bracketTimeoutSeconds)s")
            self.postError("Bracket capture timed out. Please try again.")
            self.finishSequence(terminalState: .timedOut(plan: plan), shouldFetchAssets: false, shouldNotify: false)
        }
        bracketTimeoutTask = task
        sessionQueue.asyncAfter(deadline: .now() + Constants.bracketTimeoutSeconds, execute: task)
    }

    private func beginSimulatedBracketCapture(plan: BracketPlan) {
        simulatedCaptureTask?.cancel()
        activeBracketPlan = plan
        activeCaptureStartTime = CACurrentMediaTime()
        sequenceInFlight = true
        sequenceHadLocationSample = false
        simulatedBracketReview = nil
        lastBracketManifest = nil
        lastBracketProject = nil
        setBracketSequenceState(.preparing(plan: plan))

        simulatedCaptureTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)

            for shot in plan.shots {
                guard !Task.isCancelled else { return }
                self?.setBracketSequenceState(
                    .capturing(plan: plan, currentIndex: shot.index, completedShots: shot.index)
                )
                try? await Task.sleep(nanoseconds: 350_000_000)
            }

            guard !Task.isCancelled else { return }
            self?.setBracketSequenceState(.saving(plan: plan, savedCount: plan.shotCount))
            try? await Task.sleep(nanoseconds: 250_000_000)

            guard !Task.isCancelled else { return }
            self?.main {
                guard let self else { return }
                let durationMilliseconds = self.activeCaptureStartTime.map(Self.elapsedMilliseconds)
                let completedState = BracketSequenceState.completed(
                    plan: plan,
                    assetIdentifiers: plan.shots.map { "simulated-\($0.filenameLabel)" }
                )
                let simulatedReview = SimulatedBracketReview.make(plan: plan)
                let sequence = simulatedReview.sequence
                let manifest = simulatedReview.manifest(
                    recipe: self.activeBracketRecipeRecord,
                    captureMotion: .unavailable(
                        source: "simulated camera harness",
                        captureDurationMilliseconds: durationMilliseconds ?? 0
                    )
                )
                self.simulatedBracketReview = simulatedReview
                self.lastBracketReviewSequence = sequence
                self.lastBracketManifest = manifest
                self.recordLatestBracketProject(
                    manifest: manifest,
                    reviewSequence: sequence
                )
                self.sequenceInFlight = false
                self.sequenceStep = 0
                self.activeBracketPlan = nil
                self.activeCaptureStartTime = nil
                self.simulatedCaptureTask = nil
                self.setBracketSequenceState(completedState)
                self.showImageViewer = true
                self.recordTerminalDiagnostic(
                    for: completedState,
                    durationMilliseconds: durationMilliseconds
                )
            }
        }
    }

    private func failSequence(plan: BracketPlan?, message: String) {
        postError(message)
        finishSequence(
            terminalState: .failed(plan: plan ?? activeBracketPlan, message: message),
            shouldFetchAssets: false,
            shouldNotify: false
        )
    }

    func cancelBracketCapture(reason: String = "Cancelled by user") {
        countdownTask?.cancel()
        countdownTask = nil

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.finishSequence(
                terminalState: .cancelled(plan: self.activeBracketPlan, reason: reason),
                shouldFetchAssets: false,
                shouldNotify: false
            )
        }
    }

    private func finishSequence(
        terminalState: BracketSequenceState? = nil,
        shouldFetchAssets: Bool = true,
        shouldNotify: Bool = true
    ) {
        simulatedCaptureTask?.cancel()
        simulatedCaptureTask = nil
        bracketTimeoutTask?.cancel()
        bracketTimeoutTask = nil
        let savedAssetIds = bracketAssetIds
        let plan = activeBracketPlan
        let captureDurationMilliseconds = activeCaptureStartTime.map(Self.elapsedMilliseconds)
        let captureMotion = captureMotionRecorder.finishSnapshot(
            durationMilliseconds: captureDurationMilliseconds
        )
        let capturedAt = sequenceTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
        let capturedFileType = rawPixelFormat == nil ? "HEIF/JPEG" : "RAW + Processed"

        if let dev = self.device {
            do {
                try dev.lockForConfiguration()
                if dev.isExposureModeSupported(.continuousAutoExposure) {
                    dev.exposureMode = .continuousAutoExposure
                }
                if dev.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    dev.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                if dev.isFocusModeSupported(.continuousAutoFocus) {
                    dev.focusMode = .continuousAutoFocus
                }
                dev.setExposureTargetBias(0, completionHandler: nil)
                dev.unlockForConfiguration()
            } catch {
                Logger.camera("Failed to restore auto modes after capture: \(error.localizedDescription)")
            }
        }

        if shouldFetchAssets {
            fetchBracketAssets(
                plan: plan,
                capturedAt: capturedAt,
                fileType: capturedFileType,
                captureMotion: captureMotion
            )
        } else {
            bracketAssetIds.removeAll()
            main {
                self.lastBracketReviewSequence = nil
                self.lastBracketManifest = nil
            }
        }

        self.sequenceInFlight = false
        self.sequenceStep = 0
        self.activeBracketPlan = nil
        self.histogramProcessor.skipProcessing = false
        self.rawPixelFormat = nil
        self.sequenceTimestamp = nil
        self.activeCaptureStartTime = nil
        self.sequenceHadLocationSample = false

        let resolvedTerminalState: BracketSequenceState
        if let terminalState {
            resolvedTerminalState = terminalState
        } else if let plan {
            resolvedTerminalState = .completed(plan: plan, assetIdentifiers: savedAssetIds)
        } else {
            resolvedTerminalState = .idle
        }
        setBracketSequenceState(resolvedTerminalState)
        recordTerminalDiagnostic(
            for: resolvedTerminalState,
            durationMilliseconds: captureDurationMilliseconds
        )

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Unlock orientation after bracket capture completes
            self.orientationManager?.unlockOrientation()
        }

        if notificationAuthorizationGranted && shouldNotify {
            scheduleCaptureCompletionNotification()
        }
    }

    private func captureDeviceSnapshot() -> BracketManifest.CaptureDeviceSnapshot? {
        let lensLabels = availableCameraKinds.map(\.label)
        guard let device else {
            return BracketManifest.CaptureDeviceSnapshot(
                logicalLensLabel: selectedCamera.label,
                cameraName: "\(selectedCamera.label) Camera",
                deviceType: selectedCamera.deviceType.rawValue,
                availableLensLabels: lensLabels.isEmpty ? [selectedCamera.label] : lensLabels,
                source: "capture session selection"
            )
        }

        return BracketManifest.CaptureDeviceSnapshot(
            logicalLensLabel: selectedCamera.label,
            cameraName: device.localizedName,
            deviceType: device.deviceType.rawValue,
            availableLensLabels: lensLabels.isEmpty ? [selectedCamera.label] : lensLabels,
            source: "AVCaptureDevice session"
        )
    }

    private func captureLocationSnapshot(
        locationSampleObserved: Bool
    ) -> BracketManifest.CaptureLocationSnapshot {
        let locationState = EffectiveCaptureConfiguration.LocationState(
            authorizationStatus: locationProvider.authorizationStatus
        )
        return BracketManifest.CaptureLocationSnapshot.make(
            authorizationState: locationState.displayName,
            locationSampleObserved: locationSampleObserved,
            source: "CoreLocation provider"
        )
    }

    private func fetchBracketAssets(
        plan: BracketPlan?,
        capturedAt: Date,
        fileType: String,
        captureMotion: BracketManifest.CaptureMotionSnapshot
    ) {
        let ids = self.bracketAssetIds
        guard !ids.isEmpty else { return }
        let captureDevice = captureDeviceSnapshot()
        let captureLocation = captureLocationSnapshot(
            locationSampleObserved: sequenceHadLocationSample
        )
        let fetchOptions = PHFetchOptions()
        let assetsResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: fetchOptions)

        // Build a map for quick lookup
        var map: [String: PHAsset] = [:]
        assetsResult.enumerateObjects { (asset, _, _) in
            map[asset.localIdentifier] = asset
        }

        var ordered: [PHAsset] = []
        for id in ids {
            if let a = map[id] { ordered.append(a) }
        }

        main {
            self.lastBracketAssets = ordered
            let sequence = plan.map { resolvedPlan in
                BracketReviewSequence.make(
                    plan: resolvedPlan,
                    assetIdentifiers: ordered.map(\.localIdentifier),
                    capturedAt: capturedAt,
                    fileType: fileType,
                    metadataAvailability: .unavailable(reason: "Metadata loads when a photo is selected in review"),
                    availableRepresentations: fileType.contains("RAW") ? [.processed, .raw] : [.processed]
                )
            }
            self.lastBracketReviewSequence = sequence
            if let resolvedPlan = plan, let resolvedSequence = sequence {
                let manifest = resolvedSequence.manifest(
                    groupIdentifier: ordered.first?.localIdentifier ?? "photos-\(Int(capturedAt.timeIntervalSince1970))",
                    source: .photos,
                    plan: resolvedPlan,
                    recipe: self.activeBracketRecipeRecord,
                    captureDevice: captureDevice,
                    captureLocation: captureLocation,
                    captureMotion: captureMotion
                )
                self.lastBracketManifest = manifest
                self.recordLatestBracketProject(
                    manifest: manifest,
                    reviewSequence: resolvedSequence
                )
            } else {
                self.lastBracketManifest = nil
                self.lastBracketProject = nil
            }
            self.showImageViewer = true
        }

        self.bracketAssetIds.removeAll()
    }

    private func clampWBGains(_ g: AVCaptureDevice.WhiteBalanceGains, for dev: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        let clamp: (Float) -> Float = { max(1.0, min(dev.maxWhiteBalanceGain, $0)) }
        return .init(redGain: clamp(g.redGain), greenGain: clamp(g.greenGain), blueGain: clamp(g.blueGain))
    }

    private func chooseRawPixelFormat() -> OSType? {
        let raw = photoOutput.availableRawPhotoPixelFormatTypes
        if photoOutput.isAppleProRAWEnabled {
            if let t = raw.first(where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }) { return t }
        }
        if let t = raw.first(where: { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }) { return t }
        return raw.first
    }

    private func postError(_ message: String) {
        postError(CamError(message: message))
    }

    private func postError(_ failure: CameraRuntimeFailure) {
        postError(failure.camError, category: failure.diagnosticCategory)
    }

    private func postError(_ error: CamError) {
        postError(error, category: .recovery)
    }

    private func postError(
        _ error: CamError,
        category: CameraRuntimeDiagnosticEvent.Category
    ) {
        recordDiagnostic(for: error, category: category)
        main { self.lastError = error }
    }

    private func recordDiagnostic(
        category: CameraRuntimeDiagnosticEvent.Category,
        severity: CameraRuntimeDiagnosticEvent.Severity,
        title: String,
        detail: String,
        actionPath: String? = nil,
        durationMilliseconds: Int? = nil
    ) {
        let loggerLevel: Logger.Level
        switch severity {
        case .info:
            loggerLevel = .info
        case .warning:
            loggerLevel = .warning
        case .error:
            loggerLevel = .error
        }
        let durationSuffix = durationMilliseconds.map { " (\($0) ms)" } ?? ""
        Logger.camera("[\(category.rawValue)] \(title): \(detail)\(durationSuffix)", level: loggerLevel)
        main {
            self.runtimeDiagnostics = self.runtimeDiagnostics.recording(
                category: category,
                severity: severity,
                title: title,
                detail: detail,
                actionPath: actionPath,
                durationMilliseconds: durationMilliseconds
            )
        }
    }

    private func recordDiagnostic(
        issue: DeviceCapabilityIssue,
        category: CameraRuntimeDiagnosticEvent.Category
    ) {
        recordDiagnostic(
            category: category,
            severity: issue.severity == .blocker ? .error : .warning,
            title: issue.title,
            detail: issue.detail,
            actionPath: issue.actionPath
        )
    }

    private func recordDiagnostic(
        for error: CamError,
        category: CameraRuntimeDiagnosticEvent.Category
    ) {
        if let issue = error.capabilityIssue {
            recordDiagnostic(issue: issue, category: category)
        } else {
            recordDiagnostic(
                category: category,
                severity: error.isRecoverable ? .warning : .error,
                title: error.title,
                detail: error.message,
                actionPath: error.actionPath
            )
        }
    }

    private func camError(for error: Error) -> CamError {
        if let failure = error as? CameraRuntimeFailure {
            return failure.camError
        }

        return CamError(
            title: "Camera Startup Failed",
            message: "Bracketer could not start the camera. \(error.localizedDescription)",
            isRecoverable: false
        )
    }

    private func setBracketSequenceState(_ state: BracketSequenceState) {
        main {
            self.bracketSequenceState = state
            self.isCapturing = state.isActive
            self.captureProgress = state.progress.completedShots
        }
    }

    private func recordTerminalDiagnostic(
        for state: BracketSequenceState,
        durationMilliseconds: Int? = nil
    ) {
        let severity: CameraRuntimeDiagnosticEvent.Severity?
        switch state.progress.phase {
        case .completed:
            severity = .info
        case .cancelled:
            severity = .warning
        case .timedOut, .failed:
            severity = .error
        case .idle, .preparing, .capturing, .saving:
            severity = nil
        }

        guard let severity else { return }
        recordDiagnostic(
            category: .capture,
            severity: severity,
            title: state.progress.title,
            detail: state.progress.subtitle,
            durationMilliseconds: durationMilliseconds
        )
    }

    private static func elapsedMilliseconds(since startTime: TimeInterval) -> Int {
        max(0, Int(((CACurrentMediaTime() - startTime) * 1_000).rounded()))
    }

    @inline(__always) private func main(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    private func scheduleCaptureCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Bracket Capture Complete"
        content.body = "Your bracketed exposure sequence has been saved to Photos."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "captureComplete-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.camera("Notification scheduling failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateExposureUI() {
        guard let dev = self.device else { return }
        let iso = dev.iso
        let duration = CMTimeGetSeconds(dev.exposureDuration)
        let shutterText = formatShutterSpeed(duration)

        main {
            self.currentISO = iso
            self.currentShutterSpeedText = shutterText
        }
    }

    private func formatShutterSpeed(_ duration: Double) -> String {
        if duration >= 1.0 {
            return String(format: "%.1fs", duration)
        } else {
            let fraction = 1.0 / duration
            if fraction < 10 {
                return String(format: "1/%.1f", fraction)
            } else {
                return String(format: "1/%.0f", fraction)
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            sessionQueue.async {
                self.failSequence(plan: self.activeBracketPlan, message: "Capture error: \(error.localizedDescription)")
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            sessionQueue.async {
                self.failSequence(plan: self.activeBracketPlan, message: "Capture error: missing photo data.")
            }
            return
        }
        let loc = locationProvider.latestLocation
        if loc != nil {
            sequenceHadLocationSample = true
        }

        // For bracketed capture, each photo comes through here
        // Build bracket label for this shot
        let plan = activeBracketPlan
        let currentStep = self.sequenceStep
        let bracketLabel: String?
        if let plan, plan.shots.indices.contains(currentStep) {
            bracketLabel = plan.shots[currentStep].filenameLabel
        } else {
            bracketLabel = nil
        }

        let timestamp = self.sequenceTimestamp ?? Int(Date().timeIntervalSince1970)
        let totalShots = plan?.shotCount ?? 0

        // Handle both RAW and processed photos
        if photo.isRawPhoto {
            PhotoSaver.saveRAW(
                data: data,
                suggestedFilename: "Bracket-\(timestamp).dng",
                location: loc,
                bracketLabel: bracketLabel
            ) { [weak self] result in
                self?.handlePhotoSaved(
                    result: result,
                    bracketLabel: bracketLabel,
                    currentStep: currentStep,
                    totalShots: totalShots
                )
            }
        } else {
            // Handle processed photos (HEIF/JPEG) when RAW is not available
            let processedFileExtension = self.photoOutput.availablePhotoCodecTypes.contains(.hevc) ? "heic" : "jpg"
            PhotoSaver.saveProcessed(
                data: data,
                suggestedFilename: "Bracket-\(timestamp).\(processedFileExtension)",
                location: loc,
                bracketLabel: bracketLabel
            ) { [weak self] result in
                self?.handlePhotoSaved(
                    result: result,
                    bracketLabel: bracketLabel,
                    currentStep: currentStep,
                    totalShots: totalShots
                )
            }
        }
    }

    /// Common handler for photo save completion - updates state on main queue
    private func handlePhotoSaved(result: PhotoSaveResult, bracketLabel: String?, currentStep: Int, totalShots: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let plan = self.activeBracketPlan

            if let assetId = result.assetIdentifier {
                self.bracketAssetIds.append(assetId)
                Logger.photo("Saved bracket photo \(currentStep + 1)/\(totalShots): \(bracketLabel ?? "unknown")")
            } else {
                Logger.photo("Failed to save bracket photo \(currentStep + 1)/\(totalShots)")
            }
            self.recordPhotoSaveDiagnostic(result: result, currentStep: currentStep, totalShots: totalShots)

            // Update progress
            self.sequenceStep += 1
            let progress = min(self.sequenceStep, totalShots)
            if let plan {
                if progress >= totalShots {
                    self.setBracketSequenceState(.saving(plan: plan, savedCount: self.bracketAssetIds.count))
                } else {
                    self.setBracketSequenceState(.capturing(plan: plan, currentIndex: progress, completedShots: progress))
                }
            }
            if progress < totalShots {
                HapticManager.shared.bracketShotCaptured()
            }
        }
    }

    private func recordPhotoSaveDiagnostic(result: PhotoSaveResult, currentStep: Int, totalShots: Int) {
        let severity: CameraRuntimeDiagnosticEvent.Severity
        if result.assetIdentifier == nil {
            severity = .error
        } else {
            severity = CameraRuntimePerformanceThresholds.severity(
                durationMilliseconds: result.durationMilliseconds,
                warningThresholdMilliseconds: CameraRuntimePerformanceThresholds.photoSaveWarningMilliseconds
            )
        }

        recordDiagnostic(
            category: .photos,
            severity: severity,
            title: result.assetIdentifier == nil ? "Photo Save Failed" : "Photo Saved",
            detail: "Saved shot \(currentStep + 1) of \(totalShots): \(result.filename).",
            durationMilliseconds: result.durationMilliseconds
        )
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            sessionQueue.async {
                self.failSequence(plan: self.activeBracketPlan, message: "Finish error: \(error.localizedDescription)")
            }
            return
        }

        // For bracketed capture, this is called once after all photos complete
        let totalShots = activeBracketPlan?.shotCount ?? sequenceStep
        Logger.camera("Bracket capture completed for sequence with \(totalShots) shots")

        self.main {
            HapticManager.shared.captureCompleted()
        }
        if let plan = activeBracketPlan {
            setBracketSequenceState(.saving(plan: plan, savedCount: bracketAssetIds.count))
        }

        // Finish the sequence
        sessionQueue.async {
            self.finishSequence()
        }
    }
}

struct PhotoSaveResult: Equatable, Sendable {
    let assetIdentifier: String?
    let filename: String
    let durationMilliseconds: Int

    var didSave: Bool {
        assetIdentifier != nil
    }
}

enum PhotoSaver {
    /// Save RAW photo data (DNG format) to Photo Library
    static func saveRAW(data: Data, suggestedFilename: String, location: CLLocation?, bracketLabel: String? = nil, completion: @escaping (PhotoSaveResult) -> Void) {
        let timestamp = extractTimestamp(from: suggestedFilename)
        let filename = bracketLabel.map { "Bracket-\($0)-\(timestamp).dng" } ?? "Bracket-\(timestamp).dng"
        savePhoto(data: data, filename: filename, location: location, completion: completion)
    }

    /// Save processed photo data (HEIF/JPEG format) to Photo Library
    static func saveProcessed(data: Data, suggestedFilename: String, location: CLLocation?, bracketLabel: String? = nil, completion: @escaping (PhotoSaveResult) -> Void) {
        let timestamp = extractTimestamp(from: suggestedFilename)
        let fileExtension = processedFileExtension(for: suggestedFilename)
        let filename = bracketLabel.map { "Bracket-\($0)-\(timestamp).\(fileExtension)" } ?? "Bracket-\(timestamp).\(fileExtension)"
        savePhoto(data: data, filename: filename, location: location, completion: completion)
    }

    static func processedFileExtension(for suggestedFilename: String) -> String {
        let fileExtension = URL(fileURLWithPath: suggestedFilename).pathExtension.lowercased()

        switch fileExtension {
        case "jpg", "jpeg":
            return "jpg"
        case "heif", "heic":
            return "heic"
        default:
            return "heic"
        }
    }

    /// Extract timestamp from filename or generate new one
    private static func extractTimestamp(from suggestedFilename: String) -> String {
        if let range = suggestedFilename.range(of: #"\d+"#, options: .regularExpression),
           let extracted = Int(suggestedFilename[range]) {
            return String(extracted)
        } else {
            return String(Int(Date().timeIntervalSince1970))
        }
    }

    /// Common photo save implementation
    private static func savePhoto(data: Data, filename: String, location: CLLocation?, completion: @escaping (PhotoSaveResult) -> Void) {
        var placeholderIdentifier: String?
        let saveStart = CACurrentMediaTime()
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            req.location = location
            req.creationDate = Date()
            let opts = PHAssetResourceCreationOptions()
            opts.originalFilename = filename
            req.addResource(with: .photo, data: data, options: opts)
            placeholderIdentifier = req.placeholderForCreatedAsset?.localIdentifier
        }, completionHandler: { success, error in
            if !success {
                Logger.photo("Failed to save photo '\(filename)': \(error?.localizedDescription ?? "Unknown error")")
            } else {
                Logger.photo("Saved photo: \(filename)")
            }
            let result = PhotoSaveResult(
                assetIdentifier: success ? placeholderIdentifier : nil,
                filename: filename,
                durationMilliseconds: max(0, Int(((CACurrentMediaTime() - saveStart) * 1_000).rounded()))
            )
            DispatchQueue.main.async {
                completion(result)
            }
        })
    }
}

final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var latestLocation: CLLocation?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestWhenInUse() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func start() { manager.startUpdatingLocation() }
    func stop() { manager.stopUpdatingLocation() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
    }
}

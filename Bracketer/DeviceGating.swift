import UIKit
import SwiftUI
import AVFoundation
import CoreLocation
import Photos
import UserNotifications

/// Capability level determines which features are available
enum DeviceCapabilityLevel: Equatable, Sendable {
    case full       // All lenses + ProRAW (iPhone 15/16/17 Pro)
    case standard   // Multiple lenses, no ProRAW
    case basic      // Wide lens only
    case unsupported // No camera or too-old OS
}

enum DevicePermissionState: Equatable, Sendable {
    case authorized
    case limited
    case notDetermined
    case denied
    case restricted
    case unknown

    init(photoAuthorizationStatus: PHAuthorizationStatus) {
        switch photoAuthorizationStatus {
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .unknown
        }
    }

    init(locationAuthorizationStatus: CLAuthorizationStatus) {
        switch locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .unknown
        }
    }

    init(notificationAuthorizationStatus: UNAuthorizationStatus) {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        @unknown default:
            self = .unknown
        }
    }
}

struct DeviceCapabilityIssue: Identifiable, Equatable, Sendable {
    enum Severity: String, Equatable, Sendable {
        case blocker
        case warning
    }

    let id: String
    let title: String
    let detail: String
    let actionPath: String
    let severity: Severity
}

extension DeviceCapabilityIssue {
    static func cameraAccessDenied() -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "camera.denied",
            title: "Camera Access",
            detail: "Bracketer needs camera permission to capture exposure brackets.",
            actionPath: "Settings > Privacy & Security > Camera > Bracketer",
            severity: .blocker
        )
    }

    static func cameraUnavailable(
        detail: String = "Bracket capture requires a usable wide back camera."
    ) -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "camera.unavailable",
            title: "Back Camera Unavailable",
            detail: detail,
            actionPath: "Use an iPhone with a back camera",
            severity: .blocker
        )
    }

    static func cameraSessionFailed(reason: String) -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "camera.session",
            title: "Camera Session Failed",
            detail: "Bracketer could not connect to the camera input. \(reason)",
            actionPath: "Settings > Privacy & Security > Camera > Bracketer",
            severity: .blocker
        )
    }

    static func photosAddAccessDenied() -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "photos.denied",
            title: "Photos Add Access",
            detail: "Bracketer needs permission to save bracketed captures to Photos.",
            actionPath: "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only",
            severity: .blocker
        )
    }

    static func photosAddAccessPending() -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "photos.pending",
            title: "Photos Add Access",
            detail: "Photos permission has not been requested yet.",
            actionPath: "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only",
            severity: .warning
        )
    }

    static func photosAddAccessUnknown() -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "photos.unknown",
            title: "Photos Add Access",
            detail: "The photos add access state could not be determined.",
            actionPath: "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only",
            severity: .warning
        )
    }

    static func lowStorage(freeMB: Int64, minimumStorageMB: Int64) -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "storage.low",
            title: "Low Storage",
            detail: "Only \(freeMB) MB is available; bracket capture needs at least \(minimumStorageMB) MB free.",
            actionPath: "Settings > General > iPhone Storage",
            severity: .blocker
        )
    }

    static func unknownStorage() -> DeviceCapabilityIssue {
        DeviceCapabilityIssue(
            id: "storage.unknown",
            title: "Storage Unknown",
            detail: "Available storage could not be checked.",
            actionPath: "Settings > General > iPhone Storage",
            severity: .warning
        )
    }
}

struct DeviceCapabilityInputs: Equatable, Sendable {
    var modelIdentifier: String
    var systemVersion: String
    var hasBackCamera: Bool
    var hasWideLens: Bool
    var hasUltraWideLens: Bool
    var hasTelephotoLens: Bool
    var hasFlash: Bool
    var supportsProRAW: Bool
    var photosAuthorization: DevicePermissionState
    var locationAuthorization: DevicePermissionState
    var notificationAuthorization: DevicePermissionState
    var freeStorageMB: Int64?
    var minimumStorageMB: Int64
    var isLowPowerModeEnabled: Bool
    var isSimulator: Bool

    init(
        modelIdentifier: String,
        systemVersion: String,
        hasBackCamera: Bool,
        hasWideLens: Bool,
        hasUltraWideLens: Bool,
        hasTelephotoLens: Bool,
        hasFlash: Bool,
        supportsProRAW: Bool,
        photosAuthorization: DevicePermissionState,
        locationAuthorization: DevicePermissionState,
        notificationAuthorization: DevicePermissionState,
        freeStorageMB: Int64?,
        minimumStorageMB: Int64 = 500,
        isLowPowerModeEnabled: Bool,
        isSimulator: Bool = false
    ) {
        self.modelIdentifier = modelIdentifier
        self.systemVersion = systemVersion
        self.hasBackCamera = hasBackCamera
        self.hasWideLens = hasWideLens
        self.hasUltraWideLens = hasUltraWideLens
        self.hasTelephotoLens = hasTelephotoLens
        self.hasFlash = hasFlash
        self.supportsProRAW = supportsProRAW
        self.photosAuthorization = photosAuthorization
        self.locationAuthorization = locationAuthorization
        self.notificationAuthorization = notificationAuthorization
        self.freeStorageMB = freeStorageMB
        self.minimumStorageMB = minimumStorageMB
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.isSimulator = isSimulator
    }
}

struct DeviceCapabilitySnapshot: Equatable, Sendable {
    let modelIdentifier: String
    let systemVersion: String
    let capabilityLevel: DeviceCapabilityLevel
    let hasBackCamera: Bool
    let hasWideLens: Bool
    let hasUltraWideLens: Bool
    let hasTelephotoLens: Bool
    let hasFlash: Bool
    let supportsProRAW: Bool
    let photosAuthorization: DevicePermissionState
    let locationAuthorization: DevicePermissionState
    let notificationAuthorization: DevicePermissionState
    let freeStorageMB: Int64?
    let minimumStorageMB: Int64
    let isLowPowerModeEnabled: Bool
    let issues: [DeviceCapabilityIssue]

    var isCompatibleDevice: Bool {
        !issues.contains { $0.severity == .blocker }
    }

    var blockingIssues: [DeviceCapabilityIssue] {
        issues.filter { $0.severity == .blocker }
    }

    var warningIssues: [DeviceCapabilityIssue] {
        issues.filter { $0.severity == .warning }
    }

    var statusSummary: String {
        if isCompatibleDevice {
            return warningIssues.isEmpty ? "Ready" : "Ready with warnings"
        }
        return "Blocked"
    }

    static func resolve(inputs: DeviceCapabilityInputs) -> DeviceCapabilitySnapshot {
        let capabilityLevel = resolveCapabilityLevel(inputs: inputs)
        var issues: [DeviceCapabilityIssue] = []

        if compareVersion(inputs.systemVersion, "26.0") < 0 {
            issues.append(DeviceCapabilityIssue(
                id: "ios.unsupported",
                title: "iOS 26 Required",
                detail: "Bracketer requires iOS 26 or later for the camera APIs it uses.",
                actionPath: "Settings > General > Software Update",
                severity: .blocker
            ))
        }

        if !inputs.hasBackCamera || !inputs.hasWideLens {
            issues.append(.cameraUnavailable())
        }

        appendPhotosIssue(for: inputs.photosAuthorization, issues: &issues)

        appendPermissionIssue(
            for: inputs.locationAuthorization,
            id: "location",
            title: "Location Metadata",
            deniedDetail: "Location is disabled, so captures will not include location metadata.",
            pendingDetail: "Location permission has not been requested yet.",
            actionPath: "Settings > Privacy & Security > Location Services > Bracketer > While Using the App",
            issues: &issues,
            deniedSeverity: .warning,
            pendingSeverity: .warning
        )

        appendPermissionIssue(
            for: inputs.notificationAuthorization,
            id: "notifications",
            title: "Capture Notifications",
            deniedDetail: "Notifications are disabled, so completion alerts will not appear outside the app.",
            pendingDetail: "Notification permission has not been requested yet.",
            actionPath: "Settings > Notifications > Bracketer > Allow Notifications",
            issues: &issues,
            deniedSeverity: .warning,
            pendingSeverity: .warning
        )

        if let freeStorageMB = inputs.freeStorageMB, freeStorageMB < inputs.minimumStorageMB {
            issues.append(.lowStorage(freeMB: freeStorageMB, minimumStorageMB: inputs.minimumStorageMB))
        } else if inputs.freeStorageMB == nil {
            issues.append(.unknownStorage())
        }

        if inputs.isLowPowerModeEnabled {
            issues.append(DeviceCapabilityIssue(
                id: "power.lowPower",
                title: "Low Power Mode",
                detail: "Low Power Mode may slow camera processing and background save work.",
                actionPath: "Settings > Battery > Low Power Mode",
                severity: .warning
            ))
        }

        if !inputs.hasUltraWideLens && !inputs.hasTelephotoLens {
            issues.append(DeviceCapabilityIssue(
                id: "lens.single",
                title: "Single Lens",
                detail: "Only the wide lens is available, so lens switching will be limited.",
                actionPath: "Use Wide lens capture controls",
                severity: .warning
            ))
        }

        if !inputs.hasFlash {
            issues.append(DeviceCapabilityIssue(
                id: "flash.unavailable",
                title: "Flash Unavailable",
                detail: "Flash controls will stay unavailable on this camera.",
                actionPath: "Use ambient light or an external light",
                severity: .warning
            ))
        }

        if !inputs.supportsProRAW {
            issues.append(DeviceCapabilityIssue(
                id: "raw.unavailable",
                title: "ProRAW Unavailable",
                detail: "RAW capture will stay unavailable on this device or lens.",
                actionPath: "Use HEIF/JPEG capture",
                severity: .warning
            ))
        }

        return DeviceCapabilitySnapshot(
            modelIdentifier: inputs.modelIdentifier,
            systemVersion: inputs.systemVersion,
            capabilityLevel: capabilityLevel,
            hasBackCamera: inputs.hasBackCamera,
            hasWideLens: inputs.hasWideLens,
            hasUltraWideLens: inputs.hasUltraWideLens,
            hasTelephotoLens: inputs.hasTelephotoLens,
            hasFlash: inputs.hasFlash,
            supportsProRAW: inputs.supportsProRAW,
            photosAuthorization: inputs.photosAuthorization,
            locationAuthorization: inputs.locationAuthorization,
            notificationAuthorization: inputs.notificationAuthorization,
            freeStorageMB: inputs.freeStorageMB,
            minimumStorageMB: inputs.minimumStorageMB,
            isLowPowerModeEnabled: inputs.isLowPowerModeEnabled,
            issues: issues
        )
    }

    private static func resolveCapabilityLevel(inputs: DeviceCapabilityInputs) -> DeviceCapabilityLevel {
        guard inputs.hasBackCamera, inputs.hasWideLens else { return .unsupported }
        if (inputs.hasUltraWideLens || inputs.hasTelephotoLens) && inputs.supportsProRAW {
            return .full
        }
        if inputs.hasUltraWideLens || inputs.hasTelephotoLens {
            return .standard
        }
        return .basic
    }

    private static func appendPhotosIssue(
        for state: DevicePermissionState,
        issues: inout [DeviceCapabilityIssue]
    ) {
        switch state {
        case .authorized, .limited:
            break
        case .notDetermined:
            issues.append(.photosAddAccessPending())
        case .denied, .restricted:
            issues.append(.photosAddAccessDenied())
        case .unknown:
            issues.append(.photosAddAccessUnknown())
        }
    }

    private static func appendPermissionIssue(
        for state: DevicePermissionState,
        id: String,
        title: String,
        deniedDetail: String,
        pendingDetail: String,
        actionPath: String,
        issues: inout [DeviceCapabilityIssue],
        deniedSeverity: DeviceCapabilityIssue.Severity = .blocker,
        pendingSeverity: DeviceCapabilityIssue.Severity = .warning
    ) {
        switch state {
        case .authorized, .limited:
            break
        case .notDetermined:
            issues.append(DeviceCapabilityIssue(
                id: "\(id).pending",
                title: title,
                detail: pendingDetail,
                actionPath: actionPath,
                severity: pendingSeverity
            ))
        case .denied, .restricted:
            issues.append(DeviceCapabilityIssue(
                id: "\(id).denied",
                title: title,
                detail: deniedDetail,
                actionPath: actionPath,
                severity: deniedSeverity
            ))
        case .unknown:
            issues.append(DeviceCapabilityIssue(
                id: "\(id).unknown",
                title: title,
                detail: "The \(title.lowercased()) state could not be determined.",
                actionPath: actionPath,
                severity: .warning
            ))
        }
    }

    static func compareVersion(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        let maxCount = max(v1Components.count, v2Components.count)

        for index in 0..<maxCount {
            let v1Value = index < v1Components.count ? v1Components[index] : 0
            let v2Value = index < v2Components.count ? v2Components[index] : 0

            if v1Value < v2Value { return -1 }
            if v1Value > v2Value { return 1 }
        }

        return 0
    }
}

/// Device compatibility gating system using capability-based detection
/// Supports any iPhone with adequate camera hardware instead of hardcoded model
final class DeviceGating: ObservableObject {
    static let shared = DeviceGating()

    @Published var isCompatibleDevice = false
    @Published var capabilityLevel: DeviceCapabilityLevel = .unsupported
    @Published var capabilitySnapshot: DeviceCapabilitySnapshot?
    @Published var deviceModel: String = ""
    @Published var iosVersion: String = ""
    @Published var compatibilityMessage: String = ""

    private init() {
        checkDeviceCompatibility()
    }

    private func checkDeviceCompatibility() {
        deviceModel = getDeviceModelIdentifier()
        iosVersion = UIDevice.current.systemVersion
        let snapshot = DeviceCapabilitySnapshot.resolve(inputs: currentCapabilityInputs())
        apply(snapshot: snapshot)
    }

    private func currentCapabilityInputs() -> DeviceCapabilityInputs {
        if let fake = fakeCapabilityInputsForUITests() {
            return fake
        }

        #if targetEnvironment(simulator)
        return DeviceCapabilityInputs(
            modelIdentifier: deviceModel,
            systemVersion: iosVersion,
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: true,
            hasTelephotoLens: true,
            hasFlash: true,
            supportsProRAW: true,
            photosAuthorization: .authorized,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: availableStorageMB(),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isSimulator: true
        )
        #else
        let discovery = cameraDiscovery()
        let deviceTypes = Set(discovery.devices.map { $0.deviceType })
        let hasWide = deviceTypes.contains(.builtInWideAngleCamera)
        let hasUltraWide = deviceTypes.contains(.builtInUltraWideCamera)
        let hasTelephoto = deviceTypes.contains(.builtInTelephotoCamera)
        let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        let isSimulator = false

        let photosAuthorization = DevicePermissionState(photoAuthorizationStatus: PHPhotoLibrary.authorizationStatus(for: .addOnly))
        let locationAuthorization = DevicePermissionState(locationAuthorizationStatus: CLLocationManager().authorizationStatus)
        let notificationAuthorization: DevicePermissionState = .unknown

        return DeviceCapabilityInputs(
            modelIdentifier: deviceModel,
            systemVersion: iosVersion,
            hasBackCamera: isSimulator || wideDevice != nil,
            hasWideLens: isSimulator || hasWide,
            hasUltraWideLens: isSimulator || hasUltraWide,
            hasTelephotoLens: isSimulator || hasTelephoto,
            hasFlash: isSimulator || (wideDevice?.hasFlash ?? false),
            supportsProRAW: isSimulator || detectProRAWSupport(wideDevice: wideDevice),
            photosAuthorization: photosAuthorization,
            locationAuthorization: locationAuthorization,
            notificationAuthorization: notificationAuthorization,
            freeStorageMB: availableStorageMB(),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isSimulator: isSimulator
        )
        #endif
    }

    private func fakeCapabilityInputsForUITests() -> DeviceCapabilityInputs? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing-device-capabilities-photos-denied")
            || arguments.contains("-ui-testing-device-capabilities-no-camera")
        else { return nil }

        let hasCamera = !arguments.contains("-ui-testing-device-capabilities-no-camera")
        let photosState: DevicePermissionState = arguments.contains("-ui-testing-device-capabilities-photos-denied") ? .denied : .authorized

        return DeviceCapabilityInputs(
            modelIdentifier: "UITestDevice",
            systemVersion: "26.4",
            hasBackCamera: hasCamera,
            hasWideLens: hasCamera,
            hasUltraWideLens: hasCamera,
            hasTelephotoLens: hasCamera,
            hasFlash: hasCamera,
            supportsProRAW: hasCamera,
            photosAuthorization: photosState,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: 10_000,
            isLowPowerModeEnabled: false,
            isSimulator: true
        )
    }

    private func cameraDiscovery() -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
    }

    private func detectCameraCapabilities() -> DeviceCapabilityLevel {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        let deviceTypes = Set(discovery.devices.map { $0.deviceType })

        let hasWide = deviceTypes.contains(.builtInWideAngleCamera)
        let hasUltraWide = deviceTypes.contains(.builtInUltraWideCamera)
        let hasTelephoto = deviceTypes.contains(.builtInTelephotoCamera)

        guard hasWide else { return .unsupported }

        // Check ProRAW support
        let hasProRAW = detectProRAWSupport(
            wideDevice: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        )

        if (hasUltraWide || hasTelephoto) && hasProRAW {
            return .full
        } else if hasUltraWide || hasTelephoto {
            return .standard
        } else {
            return .basic
        }
    }

    private func detectProRAWSupport(wideDevice: AVCaptureDevice?) -> Bool {
        guard let wideDevice else { return false }
        let output = AVCapturePhotoOutput()
        let session = AVCaptureSession()
        session.beginConfiguration()
        if let input = try? AVCaptureDeviceInput(device: wideDevice), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        return output.isAppleProRAWSupported
    }

    private func apply(snapshot: DeviceCapabilitySnapshot) {
        capabilitySnapshot = snapshot
        isCompatibleDevice = snapshot.isCompatibleDevice
        capabilityLevel = snapshot.capabilityLevel
        compatibilityMessage = compatibilityMessage(for: snapshot)
    }

    private func compatibilityMessage(for snapshot: DeviceCapabilitySnapshot) -> String {
        if snapshot.issues.isEmpty {
            return ""
        }

        return snapshot.issues.map { issue in
            "\(issue.title): \(issue.detail)\nAction: \(issue.actionPath)"
        }.joined(separator: "\n\n")
    }

    private func availableStorageMB() -> Int64? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                return freeSize / (1024 * 1024)
            }
        } catch {
            Logger.error("Could not check storage for device gating: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    private func compareVersion(_ version1: String, _ version2: String) -> Int {
        DeviceCapabilitySnapshot.compareVersion(version1, version2)
    }
    
    private func generateCompatibilityMessage(deviceOK: Bool, osOK: Bool) {
        switch (deviceOK, osOK) {
        case (false, false):
            compatibilityMessage = """
            This app requires an iPhone with a camera and iOS 26 or later.

            Current device: \(getDeviceDisplayName())
            Current iOS version: \(iosVersion)
            """
        case (false, true):
            compatibilityMessage = """
            This app requires an iPhone with a supported camera system.

            Current device: \(getDeviceDisplayName())
            iOS version: \(iosVersion)
            """
        case (true, false):
            compatibilityMessage = """
            This app requires iOS 26 or later.

            Device: \(getDeviceDisplayName())
            Current iOS version: \(iosVersion)

            Please update to iOS 26.0 or later to access the latest camera APIs.
            """
        case (true, true):
            compatibilityMessage = ""
        }
    }
    
    private func getDeviceDisplayName() -> String {
        // Map device identifiers to display names
        switch deviceModel {
        case "iPhone14,1": return "iPhone 13 mini"
        case "iPhone14,2": return "iPhone 13"
        case "iPhone14,3": return "iPhone 13 Pro"
        case "iPhone14,4": return "iPhone 13 Pro Max"
        case "iPhone15,1": return "iPhone 14"
        case "iPhone15,2": return "iPhone 14 Plus"
        case "iPhone15,3": return "iPhone 14 Pro"
        case "iPhone15,4": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 17 Pro Max"
        default: return "Unknown iPhone (\(deviceModel))"
        }
    }
}

/// Compatibility check view that blocks app usage on unsupported devices
struct DeviceCompatibilityView: View {
    @StateObject private var deviceGating = DeviceGating.shared
    
    var body: some View {
        if deviceGating.isCompatibleDevice {
            ModernContentView()
        } else {
            IncompatibleDeviceView()
        }
    }
}

/// Full-screen incompatibility warning with no bypass mechanism
struct IncompatibleDeviceView: View {
    @StateObject private var deviceGating = DeviceGating.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Liquid Glass background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Glassmorphism overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // App icon or camera symbol
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .white.opacity(0.3), radius: 20)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        Text("Professional Camera")
                            .font(ModernDesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .accessibilityIdentifier("deviceCompatibility.title")
                        
                        Text("Compatible Device Required")
                            .font(ModernDesignSystem.Typography.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .accessibilityIdentifier("deviceCompatibility.status")
                    }
                    
                    // Compatibility details card
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                        Text(deviceGating.compatibilityMessage)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .accessibilityIdentifier("deviceCompatibility.message")

                        if let snapshot = deviceGating.capabilitySnapshot {
                            ForEach(snapshot.issues) { issue in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.title)
                                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                                        .foregroundColor(.white)
                                    Text(issue.detail)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(issue.actionPath)
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .foregroundColor(.yellow.opacity(0.9))
                                        .accessibilityIdentifier("deviceCompatibility.issue.\(issue.id).action")
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("deviceCompatibility.issue.\(issue.id)")
                            }
                        }
                    }
                    .padding(ModernDesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                            .fill(.ultraThinMaterial)
                            .opacity(0.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .applyModernShadow(ModernDesignSystem.Shadows.large)
                    
                    // App Store redirect button
                    Button {
                        openAppStore()
                    } label: {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 18, weight: .semibold))
                            Text("View in App Store")
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, ModernDesignSystem.Spacing.xl)
                        .padding(.vertical, ModernDesignSystem.Spacing.md)
                        .background(
                            Capsule()
                                .liquidGlass(intensity: .prominent, tint: .white.opacity(0.2), interactive: true)
                        )
                    }
                    .buttonStyle(.plain)
                    .applyModernShadow(ModernDesignSystem.Shadows.medium)
                    .accessibilityIdentifier("deviceCompatibility.primaryAction")
                    
                    Spacer()
                    
                    // System requirements
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text("System Requirements")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("iPhone with camera • iOS 26.0+")
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(ModernDesignSystem.Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func openAppStore() {
        // In a real app, this would open the App Store page
        if let url = URL(string: "https://apps.apple.com/app/id0000000000") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("Compatible Device") {
    DeviceCompatibilityView()
        .onAppear {
            // Override for preview
            DeviceGating.shared.isCompatibleDevice = true
        }
}

#Preview("Incompatible Device") {
    IncompatibleDeviceView()
}

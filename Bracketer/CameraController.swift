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
    let message: String
    let isRecoverable: Bool
    init(message: String, isRecoverable: Bool = true) {
        self.message = message
        self.isRecoverable = isRecoverable
    }
}

final class CameraController: NSObject, ObservableObject, @unchecked Sendable {
    @Published var lastError: CamError?
    @Published var isProRAWEnabled: Bool = false
    @Published var selectedCamera: CameraKind = .wide
    @Published var availableCameraKinds: [CameraKind] = [.wide]
    @Published var isInitializing: Bool = false
    @Published var isCapturing: Bool = false
    @Published var captureProgress: Int = 0
    @Published var currentISO: Float = 100.0
    @Published var currentShutterSpeedText: String = "1/60"
    @Published var lastBracketAssets: [PHAsset] = []
    @Published var showImageViewer = false
    @Published var currentLensSupportsRaw: Bool = false

    @Published var teleUses12MP: Bool = false

    // Manual control capabilities (updated when lens changes)
    @Published var minISO: Float = 50
    @Published var maxISO: Float = 3200
    @Published var minShutterSpeed: Float = 0.00001
    @Published var maxShutterSpeed: Float = 1.0
    @Published var maxWBGain: Float = 4.0

    // Bracketing configuration
    private var plannedEVs: [Float] = []

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
    private var sequenceEVStep: Float = Constants.defaultEVStep
    private var sequenceStep: Int = 0
    private var sequenceTimestamp: Int?
    private var bracketAssetIds: [String] = []
    private var rawPixelFormat: OSType?
    private var maxPhotoDims: CMVideoDimensions?

    private let locationProvider = LocationProvider()
    let histogramProcessor = HistogramProcessor()
    private var exposureUpdateTimer: Timer?
    private var notificationAuthorizationGranted = false
    private var cancellables = Set<AnyCancellable>()
    private var bracketTimeoutTask: DispatchWorkItem?

    // Orientation management - weak reference to avoid retain cycle
    weak var orientationManager: OrientationManager? {
        didSet {
            setupOrientationObserver()
        }
    }

    override init() {
        super.init()
    }

    deinit {
        exposureUpdateTimer?.invalidate()
        cancellables.removeAll()
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
            self.applyRotationAsync(to: self.photoOutput.connection(with: .video))
        }
    }

    func start() async {
        main { self.isInitializing = true }
        do {
            try await requestPermissions()
        } catch {
            main {
                self.lastError = CamError(message: "Permissions: \(error.localizedDescription)", isRecoverable: false)
                self.isInitializing = false
            }
            return
        }

        await configureSession(initialKind: selectedCamera)
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
        locationProvider.start()

        main {
            self.isInitializing = false
            // Invalidate existing timer before creating a new one to prevent leaks
            self.exposureUpdateTimer?.invalidate()
            self.exposureUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateExposureUI()
            }
        }
    }

    private func requestPermissions() async throws {
        let camOK = await AVCaptureDevice.requestAccess(for: .video)
        guard camOK else {
            throw NSError(domain: "Bracketer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera access denied"])
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "Bracketer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"])
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
                cont.resume()
            }
        }
        sessionQueue.async {
            // Apply rotation to photo output (not preview layer)
            self.applyRotationAsync(to: self.photoOutput.connection(with: .video))
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
            self.applyRotationAsync(to: self.photoOutput.connection(with: .video))
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
            self.postError("Camera not available.")
            return
        }
        Logger.camera("Selected lens \(kind.label) (\(dev.localizedName)) with \(dev.formats.count) formats")
        self.device = dev
        do {
            let inp = try AVCaptureDeviceInput(device: dev)
            if self.session.canAddInput(inp) {
                self.session.addInput(inp)
                self.input = inp
            }
        } catch {
            self.postError("Camera input error: \(error.localizedDescription)")
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
    private func applyRotationAsync(to connection: AVCaptureConnection?) {
        Task { @MainActor in
            guard let orientationManager = self.orientationManager else { return }
            let angle = orientationManager.videoRotationAngle(for: orientationManager.effectiveOrientation)
            self.sessionQueue.async {
                self.applyRotationWithAngle(angle, to: connection)
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

    func captureLockdownBracket(evStep: Float = Constants.defaultEVStep, shotCount: Int = 3) {
        guard !isCapturing && !sequenceInFlight else { return }

        // Check available storage before starting
        if !checkAvailableStorage() {
            postError("Not enough storage space. Free up at least 500 MB to capture bracketed photos.")
            return
        }

        sessionQueue.async {
            guard let dev = self.device else {
                self.postError("Camera device not available")
                return
            }

            self.sequenceInFlight = true
            self.histogramProcessor.skipProcessing = true
            self.sequenceEVStep = evStep
            self.sequenceTimestamp = Int(Date().timeIntervalSince1970)
            self.rawPixelFormat = self.chooseRawPixelFormat()

            // Lock orientation to ensure all bracketed photos have the same orientation
            self.main {
                self.orientationManager?.lockOrientation()
            }

            // Build bracket plan based on parameters
            let evOffsets = self.buildBracketEVOffsets(evStep: evStep, shotCount: shotCount)
            self.plannedEVs = evOffsets
            Logger.camera("Starting bracket capture with \(shotCount) shots at ±\(evStep) EV: \(evOffsets)")

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
                dev.setExposureTargetBias(0, completionHandler: nil)
                dev.unlockForConfiguration()
            } catch {
                self.postError("Auto baseline failed: \(error.localizedDescription)")
                self.finishSequence()
                return
            }

            // Wait for AE to settle before capturing bracket
            self.settleAutoExposure { [weak self] in
                guard let self = self else { return }
                self.applyRotationAsync(to: self.photoOutput.connection(with: .video))
                self.main {
                    self.isCapturing = true
                    self.captureProgress = 0
                    HapticManager.shared.captureStarted()
                }

                // Schedule bracket timeout safety net
                self.scheduleBracketTimeout()

                if let rawFmt = self.rawPixelFormat {
                    self.captureBracketSequenceWithAPI(evOffsets: evOffsets, rawFormat: rawFmt)
                } else {
                    Logger.camera("RAW unavailable for \(self.selectedCamera.label); falling back to processed HEIF bracket.")
                    self.captureBracketSequenceProcessed(evOffsets: evOffsets)
                }
            }
        }
    }

    // MARK: - Apple Bracketing API Implementation
    private func captureBracketSequenceWithAPI(evOffsets: [Float], rawFormat: OSType) {
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
        photoSettings.flashMode = AVCaptureDevice.FlashMode.off

        // Store expected shot count for progress tracking
        self.sequenceStep = 0

        Logger.camera("Capturing bracket with \(bracketSettings.count) exposures using AVCapturePhotoBracketSettings")

        // Capture the entire bracket atomically
        self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    private func captureBracketSequenceProcessed(evOffsets: [Float]) {
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
        photoSettings.flashMode = AVCaptureDevice.FlashMode.off
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

    private func buildBracketEVOffsets(evStep: Float, shotCount: Int) -> [Float] {
        switch shotCount {
        case 3:
            return [-evStep, 0, +evStep]
        case 5:
            return [-2*evStep, -evStep, 0, +evStep, +2*evStep]
        case 7:
            return [-3*evStep, -2*evStep, -evStep, 0, +evStep, +2*evStep, +3*evStep]
        default:
            // Default to 3-shot bracket
            return [-evStep, 0, +evStep]
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

    private func checkAvailableStorage() -> Bool {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                let freeMB = freeSize / (1024 * 1024)
                if freeMB < Constants.minimumStorageMB {
                    Logger.camera("Low storage: \(freeMB) MB available")
                    return false
                }
            }
        } catch {
            Logger.error("Could not check storage: \(error.localizedDescription)")
        }
        return true
    }

    private func scheduleBracketTimeout() {
        bracketTimeoutTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, self.sequenceInFlight else { return }
            Logger.error("Bracket capture timed out after \(Constants.bracketTimeoutSeconds)s")
            self.postError("Bracket capture timed out. Please try again.")
            self.finishSequence()
        }
        bracketTimeoutTask = task
        sessionQueue.asyncAfter(deadline: .now() + Constants.bracketTimeoutSeconds, execute: task)
    }

    private func finishSequence() {
        bracketTimeoutTask?.cancel()
        bracketTimeoutTask = nil

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

        self.plannedEVs.removeAll()

        // Fetch the bracketed assets for the image viewer
        fetchBracketAssets()

        self.sequenceInFlight = false
        self.histogramProcessor.skipProcessing = false
        self.rawPixelFormat = nil
        self.sequenceTimestamp = nil

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isCapturing = false
            self.captureProgress = 0
            // Unlock orientation after bracket capture completes
            self.orientationManager?.unlockOrientation()
        }

        if notificationAuthorizationGranted {
            scheduleCaptureCompletionNotification()
        }
    }

    private func fetchBracketAssets() {
        let ids = self.bracketAssetIds
        guard !ids.isEmpty else { return }

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
        main { self.lastError = CamError(message: message) }
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
            postError("Capture error: \(error.localizedDescription)")
            return
        }
        guard let data = photo.fileDataRepresentation() else { return }
        let loc = locationProvider.latestLocation

        // For bracketed capture, each photo comes through here
        // Build bracket label for this shot
        let bracketLabel: String?
        let currentStep = self.sequenceStep
        if currentStep < self.plannedEVs.count {
            let ev = self.plannedEVs[currentStep]
            if ev == 0 {
                bracketLabel = "0EV"
            } else if ev > 0 {
                bracketLabel = "+\(String(format: "%.1f", ev))EV"
            } else {
                bracketLabel = "\(String(format: "%.1f", ev))EV"
            }
        } else {
            bracketLabel = nil
        }

        let timestamp = self.sequenceTimestamp ?? Int(Date().timeIntervalSince1970)
        let totalShots = self.plannedEVs.count

        // Handle both RAW and processed photos
        if photo.isRawPhoto {
            PhotoSaver.saveRAW(data: data,
                             suggestedFilename: "Bracket-\(timestamp).dng",
                             location: loc,
                             bracketLabel: bracketLabel) { [weak self] assetId in
                self?.handlePhotoSaved(assetId: assetId, bracketLabel: bracketLabel, currentStep: currentStep, totalShots: totalShots)
            }
        } else {
            // Handle processed photos (HEIF/JPEG) when RAW is not available
            PhotoSaver.saveProcessed(data: data,
                                    suggestedFilename: "Bracket-\(timestamp).heic",
                                    location: loc,
                                    bracketLabel: bracketLabel) { [weak self] assetId in
                self?.handlePhotoSaved(assetId: assetId, bracketLabel: bracketLabel, currentStep: currentStep, totalShots: totalShots)
            }
        }
    }

    /// Common handler for photo save completion - updates state on main queue
    private func handlePhotoSaved(assetId: String?, bracketLabel: String?, currentStep: Int, totalShots: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let assetId = assetId {
                self.bracketAssetIds.append(assetId)
                Logger.photo("Saved bracket photo \(currentStep + 1)/\(totalShots): \(bracketLabel ?? "unknown")")
            } else {
                Logger.photo("Failed to save bracket photo \(currentStep + 1)/\(totalShots)")
            }

            // Update progress
            self.sequenceStep += 1
            let progress = min(self.sequenceStep, totalShots)
            self.captureProgress = progress
            if progress < totalShots {
                HapticManager.shared.bracketShotCaptured()
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            postError("Finish error: \(error.localizedDescription)")
            self.finishSequence()
            return
        }

        // For bracketed capture, this is called once after all photos complete
        Logger.camera("Bracket capture completed for sequence with \(self.plannedEVs.count) shots")

        self.main {
            self.captureProgress = self.plannedEVs.count
            HapticManager.shared.captureCompleted()
        }

        // Finish the sequence
        sessionQueue.async {
            self.finishSequence()
        }
    }
}

enum PhotoSaver {
    /// Save RAW photo data (DNG format) to Photo Library
    static func saveRAW(data: Data, suggestedFilename: String, location: CLLocation?, bracketLabel: String? = nil, completion: @escaping (String?) -> Void) {
        let timestamp = extractTimestamp(from: suggestedFilename)
        let filename = bracketLabel.map { "Bracket-\($0)-\(timestamp).dng" } ?? "Bracket-\(timestamp).dng"
        savePhoto(data: data, filename: filename, location: location, completion: completion)
    }

    /// Save processed photo data (HEIF/JPEG format) to Photo Library
    static func saveProcessed(data: Data, suggestedFilename: String, location: CLLocation?, bracketLabel: String? = nil, completion: @escaping (String?) -> Void) {
        let timestamp = extractTimestamp(from: suggestedFilename)
        let filename = bracketLabel.map { "Bracket-\($0)-\(timestamp).heic" } ?? "Bracket-\(timestamp).heic"
        savePhoto(data: data, filename: filename, location: location, completion: completion)
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
    private static func savePhoto(data: Data, filename: String, location: CLLocation?, completion: @escaping (String?) -> Void) {
        var placeholderIdentifier: String?
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
            DispatchQueue.main.async {
                completion(success ? placeholderIdentifier : nil)
            }
        })
    }
}

final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var latestLocation: CLLocation?

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

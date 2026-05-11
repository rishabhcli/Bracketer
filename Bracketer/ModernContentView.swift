import SwiftUI
import Photos

// MARK: - Modern iOS Camera Interface
/// Apple Camera app inspired interface with Halide professional features
/// Implements iOS 18+ design patterns and modern camera controls

struct ModernContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraController()
    @StateObject private var motionManager = MotionLevelManager()
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var settings = SettingsStore()

    private let disablesStartupSideEffectsForAutomatedTests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-disable-camera-startup")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let enablesSimulatedCameraForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-simulated-camera")
    private let enablesReviewFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-review-fixture")
    private let usesZebraAnalysisFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-zebras")
    private let usesFocusPeakingFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-focus-peaking")
    private var forcedChromeLayoutIsLandscape: Bool? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-force-landscape-layout") { return true }
        if arguments.contains("-ui-testing-force-portrait-layout") { return false }
        return nil
    }

    // Transient UI state (not persisted)
    @State private var showProControls = false
    @State private var showSettings = false
    @State private var showModeChangeToast = false
    @State private var selectedZoom: CameraZoomLevel = .wide
    @State private var currentEVCompensation: Float = 0.0
    @State private var evCompensationLocked = false
    @State private var showHistogram =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-histogram")
    @State private var showZebras =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-zebras")

    // Cancellable task for toast auto-hide
    @State private var toastHideTask: DispatchWorkItem?

    private static let zebraUITestFrameAnalysis: HistogramFrameAnalysis? = {
        let pixels = [
            (255, 255, 255), (255, 255, 255), (128, 128, 128), (128, 128, 128),
            (255, 255, 255), (255, 255, 255), (128, 128, 128), (128, 128, 128),
            (0, 0, 0), (0, 0, 0), (128, 128, 128), (128, 128, 128),
            (0, 0, 0), (0, 0, 0), (128, 128, 128), (128, 128, 128),
        ].reduce(into: [UInt8]()) { bytes, pixel in
            bytes.append(UInt8(pixel.0))
            bytes.append(UInt8(pixel.1))
            bytes.append(UInt8(pixel.2))
            bytes.append(255)
        }

        return HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 4,
            height: 4,
            stepX: 1,
            stepY: 1,
            zebraColumns: 4,
            zebraRows: 4,
            zebraRegionWarningFraction: 0.5
        )
    }()

    private static let focusPeakingUITestFrameAnalysis: HistogramFrameAnalysis? = {
        let luminanceValues: [UInt8] = [
            0, 255, 0, 255,
            255, 0, 255, 0,
            0, 255, 0, 255,
            255, 0, 255, 0,
        ]
        let pixels = luminanceValues.reduce(into: [UInt8]()) { bytes, value in
            bytes.append(value)
            bytes.append(value)
            bytes.append(value)
            bytes.append(255)
        }

        return HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 4,
            height: 4,
            stepX: 1,
            stepY: 1,
            zebraColumns: 4,
            zebraRows: 4,
            zebraRegionWarningFraction: 0.5,
            focusThresholds: FocusPeakingThresholds(edgeThreshold: 20, regionWarningFraction: 0.5)
        )
    }()
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = forcedChromeLayoutIsLandscape ?? orientationManager.isLandscape
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let bracketProgress = camera.bracketSequenceState.progress
            ZStack {
                CameraChromeProbe(
                    identifier: "camera.chromeLayout",
                    label: "Camera Chrome Layout",
                    value: isLandscape ? "Landscape" : "Portrait"
                )
                CameraChromeProbe(
                    identifier: "camera.diagnostics.summary",
                    label: "Camera Diagnostics Summary",
                    value: camera.runtimeDiagnostics.summaryAccessibilityValue
                )
                CameraChromeProbe(
                    identifier: "camera.diagnostics.latest",
                    label: "Camera Latest Diagnostic",
                    value: camera.runtimeDiagnostics.latestAccessibilityValue
                )
                CameraChromeProbe(
                    identifier: "camera.diagnostics.export",
                    label: "Camera Diagnostics Export",
                    value: camera.runtimeDiagnostics.exportText
                )

                if isLandscape {
                    // In landscape, avoid overlaying controls on top of the preview:
                    // use a vertical stack with top bar, preview, then bottom controls.
                    VStack(spacing: 0) {
                        ModernTopBarEnhanced(
                            camera: camera,
                            currentShootingMode: $settings.currentShootingMode,
                            selectedEVStep: settings.selectedEVStep,
                            showProControls: $showProControls,
                            flashMode: $settings.flashMode,
                            timerMode: $settings.timerMode,
                            isGridActive: settings.showGrid,
                            isLevelActive: settings.showLevel,
                            onGridToggle: toggleGrid,
                            onLevelToggle: toggleLevel
                        )
                        .padding(.top, safeTop + 8)
                        .padding(.horizontal, 16)

                        cameraPreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ContextualBottomControls(
                            camera: camera,
                            showProControls: $showProControls,
                            showSettings: $showSettings,
                            selectedEVStep: $settings.selectedEVStep,
                            currentEVCompensation: $currentEVCompensation,
                            evCompensationLocked: $evCompensationLocked,
                            focusPeakingEnabled: $settings.focusPeakingEnabled,
                            focusPeakingColor: $settings.focusPeakingColor,
                            focusPeakingIntensity: $settings.focusPeakingIntensity,
                            bracketShotCount: $settings.bracketShotCount,
                            selectedZoom: $selectedZoom,
                            flashMode: $settings.flashMode,
                            timerMode: $settings.timerMode,
                            isGridActive: $settings.showGrid,
                            isLevelActive: $settings.showLevel,
                            currentShootingMode: $settings.currentShootingMode,
                            onGridToggle: toggleGrid,
                            onLevelToggle: toggleLevel
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, safeBottom + 20)
                    }
                } else {
                    // Portrait: keep the classic overlay layout (top bar and bottom controls
                    // floating over the preview) for an Apple Camera style look.
                    ZStack {
                        cameraPreview

                        // Top bar
                        VStack {
                            ModernTopBarEnhanced(
                                camera: camera,
                                currentShootingMode: $settings.currentShootingMode,
                                selectedEVStep: settings.selectedEVStep,
                                showProControls: $showProControls,
                                flashMode: $settings.flashMode,
                                timerMode: $settings.timerMode,
                                isGridActive: settings.showGrid,
                                isLevelActive: settings.showLevel,
                                onGridToggle: toggleGrid,
                                onLevelToggle: toggleLevel
                            )
                            .padding(.top, safeTop + 12)
                            Spacer()
                        }

                        // Bottom controls
                        VStack {
                            Spacer()
                            ContextualBottomControls(
                                camera: camera,
                                showProControls: $showProControls,
                                showSettings: $showSettings,
                                selectedEVStep: $settings.selectedEVStep,
                                currentEVCompensation: $currentEVCompensation,
                                evCompensationLocked: $evCompensationLocked,
                                focusPeakingEnabled: $settings.focusPeakingEnabled,
                                focusPeakingColor: $settings.focusPeakingColor,
                                focusPeakingIntensity: $settings.focusPeakingIntensity,
                                bracketShotCount: $settings.bracketShotCount,
                                selectedZoom: $selectedZoom,
                                flashMode: $settings.flashMode,
                                timerMode: $settings.timerMode,
                                isGridActive: $settings.showGrid,
                                isLevelActive: $settings.showLevel,
                                currentShootingMode: $settings.currentShootingMode,
                                onGridToggle: toggleGrid,
                                onLevelToggle: toggleLevel
                            )
                            .padding(.bottom, safeBottom + 12)
                        }
                    }
                }
                
                // Pro Controls Overlay
                if showProControls {
                    ModernProControls(
                        camera: camera,
                        showProControls: $showProControls,
                        selectedEVStep: $settings.selectedEVStep,
                        currentEVCompensation: $currentEVCompensation,
                        evCompensationLocked: $evCompensationLocked,
                        focusPeakingEnabled: $settings.focusPeakingEnabled,
                        focusPeakingColor: $settings.focusPeakingColor,
                        focusPeakingIntensity: $settings.focusPeakingIntensity,
                        showHistogram: $showHistogram,
                        showZebras: $showZebras,
                        bracketShotCount: $settings.bracketShotCount
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Settings Overlay - slides up from bottom (iOS style bottom sheet)
                if showSettings {
                    ModernSettingsPanel(
                        camera: camera,
                        showSettings: $showSettings,
                        showGrid: $settings.showGrid,
                        gridType: $settings.gridType,
                        showLevel: $settings.showLevel,
                        focusPeakingEnabled: $settings.focusPeakingEnabled,
                        focusPeakingColor: $settings.focusPeakingColor,
                        focusPeakingIntensity: $settings.focusPeakingIntensity,
                        teleUses12MP: $settings.teleUses12MP,
                        flashMode: $settings.flashMode,
                        timerMode: $settings.timerMode
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Loading and progress overlays
                if camera.isInitializing {
                    ModernLoadingOverlay()
                }

                if bracketProgress.shouldShowOverlay {
                    ModernCaptureProgress(progress: bracketProgress)
                }

                if let countdown = camera.countdownSecondsRemaining {
                    ModernCountdownOverlay(secondsRemaining: countdown)
                }

                // Mode change toast notification
                if showModeChangeToast {
                    VStack {
                        ModeChangeToast(mode: settings.currentShootingMode)
                            .padding(.top, 80)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }

                // Orientation lock indicator
                if orientationManager.isOrientationLocked {
                    VStack {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.rotation.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Orientation Locked")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.9))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(.top, safeTop + 64)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
                }

                if enablesReviewFixtureForUITests {
                    DeterministicImageReviewFixtureView(onDismiss: {})
                        .zIndex(1_000)
                }

            }
        }
        .ignoresSafeArea()
        .onChange(of: settings.currentShootingMode) { oldValue, newValue in
            if oldValue != newValue {
                showModeChangeToast = true
                HapticManager.shared.gridTypeChanged()

                // Cancel any existing toast hide task to prevent overlapping animations
                toastHideTask?.cancel()

                // Auto-hide toast after 2 seconds using cancellable task
                let task = DispatchWorkItem {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showModeChangeToast = false
                    }
                }
                toastHideTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
            }
        }
        .onChange(of: settings.showLevel) { _, newValue in
            motionManager.isLevelingActive = newValue
        }
        .onChange(of: selectedZoom) { _, newValue in
            HapticManager.shared.lensSwitched()
            camera.switchCamera(to: newValue.cameraKind)
        }
        .onChange(of: currentEVCompensation) { _, newValue in
            camera.setExposureCompensation(newValue)
        }
        .onChange(of: showProControls) { oldValue, newValue in
            if enablesSimulatedCameraForUITests && oldValue && !newValue {
                prepareSimulatedReviewFromUITest()
            }
        }
        .onChange(of: settings.teleUses12MP) { _, newValue in
            camera.teleUses12MP = newValue
            if camera.selectedCamera == .twoX || camera.selectedCamera == .eightX {
                camera.switchCamera(to: camera.selectedCamera)
            }
        }
        .task {
            // Connect orientation manager to camera
            camera.orientationManager = orientationManager
            camera.teleUses12MP = settings.teleUses12MP
            if usesFocusPeakingFixtureForUITests {
                settings.focusPeakingEnabled = true
                settings.focusPeakingColor = .green
                settings.focusPeakingIntensity = 0.8
            }
            if enablesSimulatedCameraForUITests {
                camera.enableSimulatedCaptureForUITests()
            }
            await resumeRuntimeServices()
            // Align the zoom UI with the active logical camera
            selectedZoom = CameraZoomLevel.forCameraKind(camera.selectedCamera)
        }
        .onAppear {
            motionManager.isLevelingActive = settings.showLevel
        }
        .environmentObject(orientationManager)
        .onDisappear {
            toastHideTask?.cancel()
            toastHideTask = nil
            suspendRuntimeServices()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await resumeRuntimeServices()
                }
            case .inactive, .background:
                suspendRuntimeServices()
            @unknown default:
                break
            }
        }
        .alert(item: $camera.lastError) { error in
            Alert(title: Text(error.title), message: Text(error.alertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $camera.showImageViewer) {
            // If we don't have assets for some reason, present a simple fallback
            if let simulatedReview = camera.simulatedBracketReview {
                SimulatedBracketReviewView(review: simulatedReview) {
                    camera.showImageViewer = false
                }
            } else if camera.lastBracketAssets.isEmpty {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("No photos available")
                            .foregroundColor(.white.opacity(0.9))
                            .font(.system(size: 18, weight: .semibold))
                        Button("Close") {
                            camera.showImageViewer = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ImageViewer(
                    bracketAssets: camera.lastBracketAssets,
                    reviewSequence: camera.lastBracketReviewSequence,
                    bracketManifest: camera.lastBracketManifest
                ) {
                    camera.showImageViewer = false
                }
            }
        }
    }
    
    private func toggleGrid() {
        settings.showGrid.toggle()
        HapticManager.shared.gridTypeChanged()
    }

    private func toggleLevel() {
        settings.showLevel.toggle()
        motionManager.isLevelingActive = settings.showLevel
        HapticManager.shared.gridTypeChanged()
    }

    @ViewBuilder
    private var cameraPreview: some View {
        if enablesSimulatedCameraForUITests {
            SimulatedCameraPreview(
                gridType: settings.gridType,
                showGrid: settings.showGrid
            )
        } else {
            ModernCameraPreview(
                camera: camera,
                motionManager: motionManager,
                orientationManager: orientationManager,
                showGrid: settings.showGrid,
                gridType: settings.gridType,
                showLevel: settings.showLevel,
                focusPeakingEnabled: settings.focusPeakingEnabled,
                focusPeakingColor: settings.focusPeakingColor,
                focusPeakingIntensity: settings.focusPeakingIntensity,
                showHistogram: showHistogram,
                showZebras: showZebras,
                frameAnalysisOverride: uiTestFrameAnalysisOverride
            )
        }
    }

    private var uiTestFrameAnalysisOverride: HistogramFrameAnalysis? {
        if usesFocusPeakingFixtureForUITests {
            return Self.focusPeakingUITestFrameAnalysis
        }
        if usesZebraAnalysisFixtureForUITests {
            return Self.zebraUITestFrameAnalysis
        }
        return nil
    }

    private func prepareSimulatedReviewFromUITest() {
        let plan = BracketPlan(
            evStep: settings.selectedEVStep,
            requestedShotCount: settings.bracketShotCount,
            centerBias: currentEVCompensation
        )
        let simulatedReview = SimulatedBracketReview.make(plan: plan)
        camera.simulatedBracketReview = simulatedReview
        camera.lastBracketManifest = simulatedReview.manifest
    }

    private func resumeRuntimeServices() async {
        guard !disablesStartupSideEffectsForAutomatedTests else { return }

        motionManager.start()
        motionManager.isLevelingActive = settings.showLevel
        await camera.start()
        camera.setExposureCompensation(currentEVCompensation)
    }

    private func suspendRuntimeServices() {
        guard !disablesStartupSideEffectsForAutomatedTests else { return }

        motionManager.stop()
        camera.stop()
    }
}

struct CameraChromeProbe: View {
    let identifier: String
    let label: String
    var value: String?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityIdentifier(identifier)
    }
}

private struct SimulatedCameraPreview: View {
    let gridType: GridType
    let showGrid: Bool

    var body: some View {
        GeometryReader { geo in
            let previewAspect: CGFloat = 3.0 / 4.0

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(white: 0.08),
                            Color(white: 0.16),
                            Color(white: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    if showGrid {
                        gridOverlay
                            .allowsHitTesting(false)
                    }
                }
                .aspectRatio(previewAspect, contentMode: .fit)
                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                .clipped()
            }
        }
        .accessibilityIdentifier("camera.simulatedPreview")
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var gridOverlay: some View {
        switch gridType {
        case .ruleOfThirds:
            RuleOfThirdsGrid()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        case .goldenRatio:
            GoldenRatioGrid()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        case .goldenSpiral:
            GoldenSpiralGrid()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        case .centerCrosshair:
            CenterCrosshairGrid()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Modern Camera Preview
struct ModernCameraPreview: View {
    let camera: CameraController
    @ObservedObject var motionManager: MotionLevelManager
    @ObservedObject var orientationManager: OrientationManager
    @ObservedObject private var histogramProcessor: HistogramProcessor
    let showGrid: Bool
    let gridType: GridType
    let showLevel: Bool
    let focusPeakingEnabled: Bool
    let focusPeakingColor: Color
    let focusPeakingIntensity: Float
    let showHistogram: Bool
    let showZebras: Bool
    let frameAnalysisOverride: HistogramFrameAnalysis?

    init(
        camera: CameraController,
        motionManager: MotionLevelManager,
        orientationManager: OrientationManager,
        showGrid: Bool,
        gridType: GridType,
        showLevel: Bool,
        focusPeakingEnabled: Bool,
        focusPeakingColor: Color,
        focusPeakingIntensity: Float,
        showHistogram: Bool,
        showZebras: Bool,
        frameAnalysisOverride: HistogramFrameAnalysis? = nil
    ) {
        self.camera = camera
        _motionManager = ObservedObject(wrappedValue: motionManager)
        _orientationManager = ObservedObject(wrappedValue: orientationManager)
        _histogramProcessor = ObservedObject(wrappedValue: camera.histogramProcessor)
        self.showGrid = showGrid
        self.gridType = gridType
        self.showLevel = showLevel
        self.focusPeakingEnabled = focusPeakingEnabled
        self.focusPeakingColor = focusPeakingColor
        self.focusPeakingIntensity = focusPeakingIntensity
        self.showHistogram = showHistogram
        self.showZebras = showZebras
        self.frameAnalysisOverride = frameAnalysisOverride
    }

    var body: some View {
        let frameAnalysis = frameAnalysisOverride ?? histogramProcessor.frameAnalysis

        ZStack {
            // Camera preview layer
            PreviewContainer(
                session: camera.session,
                onLayerReady: { _ in
                    // Preview ready callback
                },
                gridType: gridType,
                showGrid: showGrid,
                levelAngle: showLevel ? motionManager.levelAngleDegrees(for: orientationManager.currentOrientation) : 0,
                showHistogram: showHistogram,
                histogramData: frameAnalysis?.histogram ?? histogramProcessor.histogramData,
                showZebras: showZebras,
                frameAnalysis: frameAnalysis,
                focusPeakingEnabled: focusPeakingEnabled,
                focusPeakingColor: focusPeakingColor,
                focusPeakingIntensity: focusPeakingIntensity
            )
            CameraChromeProbe(
                identifier: "camera.histogramDiagnostics.summary",
                label: "Histogram Diagnostics Summary",
                value: histogramProcessor.processingDiagnostics.summaryAccessibilityValue
            )
            CameraChromeProbe(
                identifier: "camera.histogramDiagnostics.latest",
                label: "Histogram Latest Diagnostic",
                value: histogramProcessor.processingDiagnostics.latestAccessibilityValue
            )
        }
    }
}

// MARK: - Modern Components

struct ModernShootingModeIndicator: View {
    @Binding var selectedMode: ShootingMode

    var body: some View {
        Menu {
            ForEach(ShootingMode.allCases, id: \.self) { mode in
                Button {
                    guard selectedMode != mode else { return }
                    selectedMode = mode
                    HapticManager.shared.gridTypeChanged()
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: selectedMode.icon)
                    .font(ModernDesignSystem.Typography.caption)
                Text(selectedMode.rawValue)
                    .font(ModernDesignSystem.Typography.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .liquidGlass(intensity: .regular, tint: selectedMode.color.opacity(0.3), interactive: true)
            )
        }
        .accessibilityLabel("Shooting Mode")
        .accessibilityValue(selectedMode.rawValue)
        .accessibilityHint("Double-tap to choose a mode")
        .accessibilityIdentifier("camera.shootingModeButton")
    }
}

struct ModernBracketingIndicator: View {
    let evStep: Float

    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: "rectangle.stack")
                .font(ModernDesignSystem.Typography.caption)
            Text("±\(Int(evStep))")
                .font(ModernDesignSystem.Typography.monospaceSmall)
        }
        .foregroundColor(.white)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            Capsule()
                .liquidGlass(intensity: .regular, tint: .yellow.opacity(0.3), interactive: false)
        )
        .accessibilityLabel("Bracketing Step")
        .accessibilityValue("+/-\(String(format: "%.1f", evStep)) EV")
        .accessibilityIdentifier("camera.bracketingIndicator")
    }
}

struct ModernToggleButton: View {
    let icon: String
    let accessibilityID: String
    let accessibilityLabel: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .liquidGlass(
                        intensity: isActive ? .prominent : .regular,
                        tint: isActive ? .yellow.opacity(0.3) : nil,
                        interactive: true
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isActive ? .yellow : .white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isActive ? "On" : "Off")
        .accessibilityIdentifier(accessibilityID)
    }
}


struct ModernProControlButton: View {
    @Binding var showProControls: Bool

    var body: some View {
        Button {
            withAnimation(ModernDesignSystem.Animations.spring) {
                showProControls.toggle()
            }
            HapticManager.shared.panelToggled()
        } label: {
            ZStack {
                Circle()
                    .liquidGlass(
                        intensity: showProControls ? .prominent : .regular,
                        tint: showProControls ? .purple.opacity(0.3) : nil,
                        interactive: true
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "dial.min")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(showProControls ? .purple : .white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pro Controls")
        .accessibilityValue(showProControls ? "Open" : "Closed")
        .accessibilityIdentifier("camera.proControlsButton")
    }
}

struct ModernPhotoLibraryButton: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        Button {
            camera.presentMostRecentAsset()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .liquidGlass(intensity: .regular, tint: nil, interactive: true)
                    .frame(width: 44, height: 44)

                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo Library")
        .accessibilityIdentifier("camera.photoLibraryButton")
    }
}

struct ModernSettingsButton: View {
    @Binding var showSettings: Bool

    var body: some View {
        Button {
            withAnimation(ModernDesignSystem.Animations.spring) {
                showSettings.toggle()
            }
            HapticManager.shared.panelToggled()
        } label: {
            ZStack {
                Circle()
                    .liquidGlass(
                        intensity: showSettings ? .prominent : .regular,
                        tint: showSettings ? .blue.opacity(0.3) : nil,
                        interactive: true
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(showSettings ? .blue : .white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityValue(showSettings ? "Open" : "Closed")
        .accessibilityIdentifier("camera.settingsButton")
    }
}

struct CompactProControlsBadge: View {
    @Binding var showProControls: Bool

    var body: some View {
        Button {
            withAnimation(ModernDesignSystem.Animations.spring) {
                showProControls.toggle()
            }
            HapticManager.shared.panelToggled()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "dial.medium")
                    .font(.system(size: 11, weight: .semibold))
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(showProControls ? .purple : .white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .liquidGlass(
                        intensity: showProControls ? .prominent : .subtle,
                        tint: showProControls ? .purple.opacity(0.3) : nil,
                        interactive: true
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pro Controls")
        .accessibilityValue(showProControls ? "Open" : "Closed")
        .accessibilityIdentifier("camera.proControlsTopButton")
    }
}

// MARK: - Modern Loading Overlay
struct ModernLoadingOverlay: View {
    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.cameraOverlay.ignoresSafeArea()
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: ModernDesignSystem.Colors.cameraControlActive))
                
                Text("Initializing Camera")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .modernCardStyle(.overlay)
        }
    }
}

// MARK: - Modern Capture Progress
struct ModernCaptureProgress: View {
    let progress: BracketCaptureProgress

    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.cameraOverlay.ignoresSafeArea()

            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ProgressView(value: progress.fraction, total: 1)
                    .progressViewStyle(LinearProgressViewStyle(tint: ModernDesignSystem.Colors.cameraControlActive))
                    .frame(width: 200)

                VStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text(progress.title)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .accessibilityIdentifier("capture.progress.title")
                    Text(progress.subtitle)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .accessibilityIdentifier("capture.progress.subtitle")
                }

                Text("Keep device steady")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .modernCardStyle(.overlay)
        }
        .accessibilityIdentifier("capture.progress.overlay")
    }
}

struct ModernCountdownOverlay: View {
    let secondsRemaining: Int

    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.cameraOverlay.ignoresSafeArea()

            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("\(secondsRemaining)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlActive)
                    .monospacedDigit()

                Text("Timer countdown")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Text("Get ready for bracket capture")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .modernCardStyle(.overlay)
        }
    }
}

// MARK: - Enhanced Top Bar with iOS 26 Components

@available(iOS 26.0, *)
struct ModernTopBarEnhanced: View {
    let camera: CameraController
    @Binding var currentShootingMode: ShootingMode
    let selectedEVStep: Float
    @Binding var showProControls: Bool
    @Binding var flashMode: FlashMode
    @Binding var timerMode: TimerMode
    let isGridActive: Bool
    let isLevelActive: Bool
    let onGridToggle: () -> Void
    let onLevelToggle: () -> Void

    private var captureConfiguration: EffectiveCaptureConfiguration {
        camera.effectiveCaptureConfiguration(flashMode: flashMode, timerMode: timerMode)
    }

    var body: some View {
        HStack {
            // Left side - Status indicators only
            HStack(spacing: 8) {
                ModernTopBarStatusBadge(
                    icon: "photo",
                    label: captureConfiguration.formatBadgeLabel,
                    tint: camera.isProRAWEnabled ? .yellow.opacity(0.2) : .white.opacity(0.1)
                )

                ModernTopBarStatusBadge(
                    icon: captureConfiguration.flashIconName,
                    label: captureConfiguration.flashBadgeLabel,
                    tint: flashBadgeTint
                )

                if let timerBadgeLabel = captureConfiguration.timerBadgeLabel {
                    ModernTopBarStatusBadge(
                        icon: "timer",
                        label: timerBadgeLabel,
                        tint: .orange.opacity(0.2)
                    )
                }
            }

            Spacer()

            // Center - Mode indicator and bracketing (tappable for mode change)
            HStack(spacing: 8) {
                ModernShootingModeIndicator(selectedMode: $currentShootingMode)
                ModernBracketingIndicator(evStep: selectedEVStep)
            }

            Spacer()

            // Right side - Pro Controls badge
            HStack(spacing: 8) {
                CompactProControlsBadge(showProControls: $showProControls)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.95))
        .overlay(alignment: .topLeading) {
            CameraChromeProbe(identifier: "camera.topBar", label: "Camera Top Bar")
        }
    }

    private var flashBadgeTint: Color {
        guard camera.isFlashAvailable else {
            return .gray.opacity(0.18)
        }

        return flashMode == .off ? .white.opacity(0.1) : .yellow.opacity(0.2)
    }
}

struct ModernTopBarStatusBadge: View {
    let icon: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.white.opacity(0.95))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .liquidGlass(intensity: .subtle, tint: tint, interactive: false)
        )
    }
}

#Preview {
    ModernContentView()
}

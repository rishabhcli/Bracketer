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

    private let disablesStartupSideEffectsForUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing-disable-camera-startup")

    // Transient UI state (not persisted)
    @State private var showProControls = false
    @State private var showSettings = false
    @State private var showModeChangeToast = false
    @State private var selectedZoom: CameraZoomLevel = .wide
    @State private var currentEVCompensation: Float = 0.0
    @State private var evCompensationLocked = false

    // Cancellable task for toast auto-hide
    @State private var toastHideTask: DispatchWorkItem?
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = orientationManager.isLandscape
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            ZStack {
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

                        ModernCameraPreview(
                            camera: camera,
                            motionManager: motionManager,
                            orientationManager: orientationManager,
                            showGrid: settings.showGrid,
                            gridType: settings.gridType,
                            showLevel: settings.showLevel,
                            focusPeakingEnabled: settings.focusPeakingEnabled,
                            focusPeakingColor: settings.focusPeakingColor,
                            focusPeakingIntensity: settings.focusPeakingIntensity
                        )
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
                        ModernCameraPreview(
                            camera: camera,
                            motionManager: motionManager,
                            orientationManager: orientationManager,
                            showGrid: settings.showGrid,
                            gridType: settings.gridType,
                            showLevel: settings.showLevel,
                            focusPeakingEnabled: settings.focusPeakingEnabled,
                            focusPeakingColor: settings.focusPeakingColor,
                            focusPeakingIntensity: settings.focusPeakingIntensity
                        )

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

                if camera.isCapturing {
                    ModernCaptureProgress(
                        progress: camera.captureProgress,
                        evStep: settings.selectedEVStep,
                        totalShots: settings.bracketShotCount,
                        centerBias: currentEVCompensation
                    )
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
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $camera.showImageViewer) {
            // If we don't have assets for some reason, present a simple fallback
            if camera.lastBracketAssets.isEmpty {
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
                ImageViewer(bracketAssets: camera.lastBracketAssets) {
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

    private func resumeRuntimeServices() async {
        guard !disablesStartupSideEffectsForUITests else { return }

        motionManager.start()
        motionManager.isLevelingActive = settings.showLevel
        await camera.start()
        camera.setExposureCompensation(currentEVCompensation)
    }

    private func suspendRuntimeServices() {
        guard !disablesStartupSideEffectsForUITests else { return }

        motionManager.stop()
        camera.stop()
    }
}

// MARK: - Modern Camera Preview
struct ModernCameraPreview: View {
    let camera: CameraController
    @ObservedObject var motionManager: MotionLevelManager
    @ObservedObject var orientationManager: OrientationManager
    let showGrid: Bool
    let gridType: GridType
    let showLevel: Bool
    let focusPeakingEnabled: Bool
    let focusPeakingColor: Color
    let focusPeakingIntensity: Float

    var body: some View {
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
                showHistogram: false,
                histogramData: camera.histogramProcessor.histogramData,
                focusPeakingEnabled: focusPeakingEnabled,
                focusPeakingColor: focusPeakingColor,
                focusPeakingIntensity: focusPeakingIntensity
            )
        }
    }
}

// MARK: - Modern Top Bar (Apple Camera Style - Status Only)
struct ModernTopBar: View {
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
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ModernTopBarStatusBadge(
                    icon: "photo",
                    label: captureConfiguration.formatBadgeLabel,
                    tint: camera.isProRAWEnabled ? .yellow : .white.opacity(0.16)
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
                        tint: .orange.opacity(0.22)
                    )
                }
            }

            Spacer()

            // Center - Mode indicator and bracketing (tappable for mode change)
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ModernShootingModeIndicator(selectedMode: $currentShootingMode)
                ModernBracketingIndicator(evStep: selectedEVStep)
            }

            Spacer()

            // Right side - Pro Controls badge
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                CompactProControlsBadge(showProControls: $showProControls)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.95))
    }

    private var flashBadgeTint: Color {
        guard camera.isFlashAvailable else {
            return .gray.opacity(0.22)
        }

        return flashMode == .off ? .white.opacity(0.16) : .yellow.opacity(0.22)
    }
}

// MARK: - Modern Bottom Controls (Apple Camera Style)
struct ModernBottomControls: View {
    let camera: CameraController
    @Binding var showProControls: Bool
    @Binding var showSettings: Bool
    @Binding var selectedEVStep: Float
    @Binding var currentEVCompensation: Float
    @Binding var evCompensationLocked: Bool
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    @Binding var bracketShotCount: Int
    @Binding var flashMode: FlashMode
    @Binding var timerMode: TimerMode
    @Binding var isGridActive: Bool
    @Binding var isLevelActive: Bool
    let onGridToggle: () -> Void
    let onLevelToggle: () -> Void

    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Secondary controls row (moved from top bar)
            HStack(spacing: 16) {
                ModernFlashButton(flashMode: $flashMode, isAvailable: camera.isFlashAvailable)
                ModernTimerButton(timerMode: $timerMode)
                ModernToggleButton(
                    icon: "square.grid.3x3",
                    isActive: isGridActive,
                    onTap: onGridToggle
                )
                ModernToggleButton(
                    icon: "level",
                    isActive: isLevelActive,
                    onTap: onLevelToggle
                )
                ModernProControlButton(showProControls: $showProControls)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)

            // Main control row
            HStack(spacing: ModernDesignSystem.Spacing.xl) {
                // Photo library
                ModernPhotoLibraryButton(camera: camera)

                // Shutter button (larger for better prominence)
                ModernShutterButton(
                    isCapturing: camera.isCapturing,
                    progress: camera.captureProgress,
                    totalSteps: bracketShotCount
                ) {
                    camera.captureLockdownBracket(
                        evStep: selectedEVStep,
                        shotCount: bracketShotCount,
                        flashMode: flashMode,
                        timerMode: timerMode,
                        exposureCompensation: currentEVCompensation
                    )
                }

                // Settings
                ModernSettingsButton(showSettings: $showSettings)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Modern Components

struct ModernFlashButton: View {
    @Binding var flashMode: FlashMode
    let isAvailable: Bool

    var body: some View {
        FlashModeMenu(flashMode: $flashMode, isAvailable: isAvailable, style: .legacy)
    }
}

struct ModernTimerButton: View {
    @Binding var timerMode: TimerMode

    var body: some View {
        TimerModeMenu(timerMode: $timerMode, style: .legacy)
    }
}

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
    }
}

struct ModernToggleButton: View {
    let icon: String
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
        .accessibilityValue(isActive ? "On" : "Off")
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

struct ModernShutterButton: View {
    let isCapturing: Bool
    let progress: Int
    let totalSteps: Int
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.shutterPressed()
            action()
        } label: {
            ZStack {
                // Outer ring with glass effect (increased size)
                Circle()
                    .stroke(.white, lineWidth: 5)
                    .frame(width: 88, height: 88)

                // Inner button with liquid glass (increased size)
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.9)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .fill(isCapturing ? .red.opacity(0.3) : .white.opacity(0.2))
                    )
                    .scaleEffect(isCapturing ? 0.9 : 1.0)
                    .animation(ModernDesignSystem.Animations.spring, value: isCapturing)

                // Progress ring (increased size)
                if isCapturing {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress) / CGFloat(max(1, totalSteps)))
                        .stroke(
                            AngularGradient(
                                colors: [.yellow, .orange, .yellow],
                                center: .center
                            ),
                            lineWidth: 5
                        )
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .disabled(isCapturing)
        .scaleEffect(isCapturing ? 0.95 : 1.0)
        .animation(ModernDesignSystem.Animations.spring, value: isCapturing)
        .accessibilityLabel("Capture")
        .accessibilityValue(isCapturing ? "Capturing shot \(progress) of \(totalSteps)" : "Ready")
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
    let progress: Int
    let evStep: Float
    let totalShots: Int
    let centerBias: Float

    init(progress: Int, evStep: Float, totalShots: Int = 3, centerBias: Float = 0) {
        self.progress = progress
        self.evStep = evStep
        self.totalShots = totalShots
        self.centerBias = centerBias
    }

    private var evOffsets: [Float] {
        BracketSequencePlanner.evOffsets(evStep: evStep, shotCount: totalShots, centerBias: centerBias)
    }

    private var progressText: String {
        if progress == 0 {
            return "Preparing bracket..."
        } else if progress <= totalShots {
            let ev = evOffsets[progress - 1]
            if ev == 0 {
                return "Capturing 0 EV"
            } else if ev > 0 {
                return "Capturing +\(String(format: "%.1f", ev)) EV"
            } else {
                return "Capturing \(String(format: "%.1f", ev)) EV"
            }
        } else {
            return "Processing..."
        }
    }

    private var progressSubtext: String {
        if progress == 0 {
            return "Setting up exposure bracketing"
        } else if progress <= totalShots {
            return "Shot \(progress) of \(totalShots)"
        } else {
            return "Saving bracketed sequence"
        }
    }

    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.cameraOverlay.ignoresSafeArea()

            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ProgressView(value: Double(progress), total: Double(totalShots))
                    .progressViewStyle(LinearProgressViewStyle(tint: ModernDesignSystem.Colors.cameraControlActive))
                    .frame(width: 200)

                VStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text(progressText)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(progressSubtext)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                Text("Keep device steady")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .modernCardStyle(.overlay)
        }
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
    }

    private var flashBadgeTint: Color {
        guard camera.isFlashAvailable else {
            return .gray.opacity(0.18)
        }

        return flashMode == .off ? .white.opacity(0.1) : .yellow.opacity(0.2)
    }
}

// MARK: - Enhanced Bottom Controls with iOS 26 Components

@available(iOS 26.0, *)
struct ModernBottomControlsEnhanced: View {
    let camera: CameraController
    @Binding var showProControls: Bool
    @Binding var showSettings: Bool
    @Binding var selectedEVStep: Float
    @Binding var currentEVCompensation: Float
    @Binding var evCompensationLocked: Bool
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    @Binding var bracketShotCount: Int
    @Binding var selectedZoom: CameraZoomLevel
    @Binding var flashMode: FlashMode
    @Binding var timerMode: TimerMode
    @Binding var isGridActive: Bool
    @Binding var isLevelActive: Bool
    let onGridToggle: () -> Void
    let onLevelToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Secondary controls row (moved from top bar) - all in thumb reach
            HStack(spacing: 16) {
                FlashModeControl(flashMode: $flashMode, isAvailable: camera.isFlashAvailable)
                TimerModeControl(timerMode: $timerMode)
                ModernToggleButton(
                    icon: "square.grid.3x3",
                    isActive: isGridActive,
                    onTap: onGridToggle
                )
                ModernToggleButton(
                    icon: "level",
                    isActive: isLevelActive,
                    onTap: onLevelToggle
                )
                ModernProControlButton(showProControls: $showProControls)
            }
            .padding(.horizontal, 20)

            // Main control row with enhanced shutter button
            HStack(spacing: 40) {
                // Photo library
                ModernPhotoLibraryButton(camera: camera)

                // Enhanced shutter button (larger size)
                EnhancedShutterButton(
                    isCapturing: camera.isCapturing,
                    progress: Double(camera.captureProgress) / Double(max(1, bracketShotCount))
                ) {
                    camera.captureLockdownBracket(
                        evStep: selectedEVStep,
                        shotCount: bracketShotCount,
                        flashMode: flashMode,
                        timerMode: timerMode,
                        exposureCompensation: currentEVCompensation
                    )
                }

                // Settings
                ModernSettingsButton(showSettings: $showSettings)
            }
            .padding(.horizontal, 20)

            // Zoom selector at very bottom
            CameraZoomControl(
                selectedZoom: $selectedZoom,
                availableZoomLevels: CameraZoomLevel.iPhone17ProMaxLevels
            )
            .padding(.bottom, 40)
        }
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

import SwiftUI
import Photos

// MARK: - Modern iOS Camera Interface
/// Apple Camera app inspired interface with Halide professional features
/// Implements iOS 18+ design patterns and modern camera controls

struct ModernContentView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var motionManager = MotionLevelManager()
    @StateObject private var orientationManager = OrientationManager()

    // UI State
    @State private var showProControls = false
    @State private var showSettings = false
    @State private var showGrid = true
    @State private var showLevel = true
    @State private var focusPeakingEnabled = false
    @State private var focusPeakingColor = Color.red
    @State private var focusPeakingIntensity: Float = 0.5
    
    // Bracketing
    @State private var selectedEVStep: Float = 1.0
    @State private var currentEVCompensation: Float = 0.0
    @State private var evCompensationLocked = false
    @State private var bracketShotCount: Int = 3
    
    // Shooting modes
    @State private var currentShootingMode: ShootingMode = .auto
    @State private var gridType: GridType = .ruleOfThirds
    @State private var showModeChangeToast = false
    @State private var previousMode: ShootingMode = .auto

    // Camera controls (iOS 26+)
    @State private var selectedZoom: CameraZoomLevel = .wide
    @State private var flashMode: FlashMode = .off
    @State private var timerMode: TimerMode = .off

    // Focus peaking colors
    private let focusPeakingColors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple, .white]

    // Cancellable task for toast auto-hide
    @State private var toastHideTask: DispatchWorkItem?
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = orientationManager.isLandscape
            ZStack {
                if isLandscape {
                    // In landscape, avoid overlaying controls on top of the preview:
                    // use a vertical stack with top bar, preview, then bottom controls.
                    VStack(spacing: 0) {
                        ModernTopBarEnhanced(
                            camera: camera,
                            currentShootingMode: $currentShootingMode,
                            selectedEVStep: selectedEVStep,
                            showProControls: $showProControls,
                            flashMode: $flashMode,
                            timerMode: $timerMode,
                            isGridActive: showGrid,
                            isLevelActive: showLevel,
                            onGridToggle: toggleGrid,
                            onLevelToggle: toggleLevel
                        )
                        .padding(.top, 16)
                        .padding(.horizontal, 16)

                        ModernCameraPreview(
                            camera: camera,
                            motionManager: motionManager,
                            orientationManager: orientationManager,
                            showGrid: showGrid,
                            gridType: gridType,
                            showLevel: showLevel,
                            focusPeakingEnabled: focusPeakingEnabled,
                            focusPeakingColor: focusPeakingColor,
                            focusPeakingIntensity: focusPeakingIntensity
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ContextualBottomControls(
                            camera: camera,
                            showProControls: $showProControls,
                            showSettings: $showSettings,
                            selectedEVStep: $selectedEVStep,
                            currentEVCompensation: $currentEVCompensation,
                            evCompensationLocked: $evCompensationLocked,
                            focusPeakingEnabled: $focusPeakingEnabled,
                            focusPeakingColor: $focusPeakingColor,
                            focusPeakingIntensity: $focusPeakingIntensity,
                            bracketShotCount: $bracketShotCount,
                            selectedZoom: $selectedZoom,
                            flashMode: $flashMode,
                            timerMode: $timerMode,
                            isGridActive: $showGrid,
                            isLevelActive: $showLevel,
                            currentShootingMode: $currentShootingMode,
                            onGridToggle: toggleGrid,
                            onLevelToggle: toggleLevel
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                } else {
                    // Portrait: keep the classic overlay layout (top bar and bottom controls
                    // floating over the preview) for an Apple Camera style look.
                    ZStack {
                        ModernCameraPreview(
                            camera: camera,
                            motionManager: motionManager,
                            orientationManager: orientationManager,
                            showGrid: showGrid,
                            gridType: gridType,
                            showLevel: showLevel,
                            focusPeakingEnabled: focusPeakingEnabled,
                            focusPeakingColor: focusPeakingColor,
                            focusPeakingIntensity: focusPeakingIntensity
                        )

                        // Top bar
                        VStack {
                            ModernTopBarEnhanced(
                                camera: camera,
                                currentShootingMode: $currentShootingMode,
                                selectedEVStep: selectedEVStep,
                                showProControls: $showProControls,
                                flashMode: $flashMode,
                                timerMode: $timerMode,
                                isGridActive: showGrid,
                                isLevelActive: showLevel,
                                onGridToggle: toggleGrid,
                                onLevelToggle: toggleLevel
                            )
                            .padding(.top, 60)
                            Spacer()
                        }

                        // Bottom controls
                        VStack {
                            Spacer()
                            ContextualBottomControls(
                                camera: camera,
                                showProControls: $showProControls,
                                showSettings: $showSettings,
                                selectedEVStep: $selectedEVStep,
                                currentEVCompensation: $currentEVCompensation,
                                evCompensationLocked: $evCompensationLocked,
                                focusPeakingEnabled: $focusPeakingEnabled,
                                focusPeakingColor: $focusPeakingColor,
                                focusPeakingIntensity: $focusPeakingIntensity,
                                bracketShotCount: $bracketShotCount,
                                selectedZoom: $selectedZoom,
                                flashMode: $flashMode,
                                timerMode: $timerMode,
                                isGridActive: $showGrid,
                                isLevelActive: $showLevel,
                                currentShootingMode: $currentShootingMode,
                                onGridToggle: toggleGrid,
                                onLevelToggle: toggleLevel
                            )
                        }
                    }
                }
                
                // Pro Controls Overlay
                if showProControls {
                    ModernProControls(
                        camera: camera,
                        showProControls: $showProControls,
                        selectedEVStep: $selectedEVStep,
                        currentEVCompensation: $currentEVCompensation,
                        evCompensationLocked: $evCompensationLocked,
                        focusPeakingEnabled: $focusPeakingEnabled,
                        focusPeakingColor: $focusPeakingColor,
                        focusPeakingIntensity: $focusPeakingIntensity,
                        bracketShotCount: $bracketShotCount
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Settings Overlay - slides up from bottom (iOS style bottom sheet)
                if showSettings {
                    ModernSettingsPanel(
                        camera: camera,
                        showSettings: $showSettings,
                        showGrid: $showGrid,
                        gridType: $gridType,
                        showLevel: $showLevel,
                        focusPeakingEnabled: $focusPeakingEnabled,
                        focusPeakingColor: $focusPeakingColor,
                        focusPeakingIntensity: $focusPeakingIntensity
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
                        evStep: selectedEVStep
                    )
                }

                // Mode change toast notification
                if showModeChangeToast {
                    VStack {
                        ModeChangeToast(mode: currentShootingMode)
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
                        .padding(.top, 120)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: currentShootingMode) { oldValue, newValue in
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
        .onChange(of: showLevel) { _, newValue in
            motionManager.isLevelingActive = newValue
        }
        .onChange(of: selectedZoom) { _, newValue in
            HapticManager.shared.lensSwitched()
            camera.switchCamera(to: newValue.cameraKind)
        }
        .task {
            // Connect orientation manager to camera
            camera.orientationManager = orientationManager
            await camera.start()
            // Align the zoom UI with the active logical camera
            selectedZoom = CameraZoomLevel.forCameraKind(camera.selectedCamera)
        }
        .onAppear {
            motionManager.start()
            motionManager.isLevelingActive = showLevel
        }
        .environmentObject(orientationManager)
        .onDisappear {
            toastHideTask?.cancel()
            toastHideTask = nil
            motionManager.stop()
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
        showGrid.toggle()
        HapticManager.shared.gridTypeChanged()
    }
    
    private func toggleLevel() {
        showLevel.toggle()
        motionManager.isLevelingActive = showLevel
        HapticManager.shared.gridTypeChanged()
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
    let isGridActive: Bool
    let isLevelActive: Bool
    let onGridToggle: () -> Void
    let onLevelToggle: () -> Void

    var body: some View {
        HStack {
            // Left side - Status indicators only
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                if camera.isProRAWEnabled {
                    Text("ProRAW")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.8)
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
                ModernFlashButton(flashMode: $flashMode)
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
                    camera.captureLockdownBracket(evStep: selectedEVStep, shotCount: bracketShotCount)
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

    var body: some View {
        FlashModeMenu(flashMode: $flashMode, style: .legacy)
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
    
    private var progressText: String {
        switch progress {
        case 0: return "Preparing bracket..."
        case 1: return "Baseline (0 EV)"
        case 2: return "Overexposed (+\(Int(evStep)) EV)"
        case 3: return "Underexposed (-\(Int(evStep)) EV)"
        case 4: return "Processing..."
        default: return "Processing..."
        }
    }
    
    private var progressSubtext: String {
        switch progress {
        case 0: return "Setting up exposure bracketing"
        case 1: return "Auto exposure reference"
        case 2: return "Longer shutter speed"
        case 3: return "Shorter shutter speed"
        case 4: return "Saving bracketed sequence"
        default: return "Finalizing capture"
        }
    }
    
    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.cameraOverlay.ignoresSafeArea()
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ProgressView(value: Double(progress), total: 4.0)
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

    var body: some View {
        HStack {
            // Left side - Status indicators only
            HStack(spacing: 8) {
                if camera.isProRAWEnabled {
                    Text("ProRAW")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .liquidGlass(intensity: .subtle, tint: .yellow.opacity(0.2))
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
                FlashModeControl(flashMode: $flashMode)
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
                    camera.captureLockdownBracket(evStep: selectedEVStep, shotCount: bracketShotCount)
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

#Preview {
    ModernContentView()
}

import SwiftUI
import Photos

// MARK: - Modern iOS Camera Interface
/// Apple Camera app inspired interface with Halide professional features
/// Implements iOS 18+ design patterns and modern camera controls

struct ModernContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @StateObject private var camera = CameraController()
    @StateObject private var motionManager = MotionLevelManager()
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var appIntentRouter = BracketerAppIntentRouter.shared

    private let disablesStartupSideEffectsForAutomatedTests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-disable-camera-startup")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let enablesSimulatedCameraForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-simulated-camera")
    private let enablesReviewFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-review-fixture")
    private let opensLatestProjectReviewForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-open-latest-project-review")
    private let opensLatestReviewHandoffForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-open-latest-review-handoff")
    private let opensTimedCaptureHandoffForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-open-timed-capture-handoff")
    private let opensReviewAccessibilityFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-open-review-accessibility-fixture")
    private let usesZebraAnalysisFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-zebras")
    private let usesFocusPeakingFixtureForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-show-focus-peaking")
    private let intelligenceAvailability = IntelligenceAvailabilityService.currentAvailability()
    private var forcedChromeLayoutIsLandscape: Bool? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-force-landscape-layout") { return true }
        if arguments.contains("-ui-testing-force-portrait-layout") { return false }
        return nil
    }

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    private var motionAwareSpring: Animation? {
        ModernDesignSystem.Animations.motionAwareSpring(reduceMotionEnabled: effectiveAccessibilityReduceMotion)
    }

    private var bottomSheetTransition: AnyTransition {
        effectiveAccessibilityReduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var topNotificationTransition: AnyTransition {
        effectiveAccessibilityReduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private static var initialBracketRecipePrompt: String {
        let arguments = ProcessInfo.processInfo.arguments
        if let promptIndex = arguments.firstIndex(of: "-ui-testing-bracket-recipe-prompt"),
           arguments.indices.contains(promptIndex + 1) {
            return arguments[promptIndex + 1]
        }
        if arguments.contains("-ui-testing-bracket-recipe-prompt-high-contrast") {
            return "High contrast sunset through a bright window"
        }
        return ""
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
    @State private var refreshedCaptureCoachRun: CaptureCoachRun?
    @State private var isRefreshingCaptureCoach = false
    @State private var bracketRecipePrompt = Self.initialBracketRecipePrompt
    @State private var refreshedBracketRecipeRun: BracketRecipeRun?
    @State private var isPlanningBracketRecipe = false
    @State private var activeBracketRecipe: ActiveBracketRecipeSummary?
    @State private var activeBracketRecipeRecord: AppliedBracketRecipeRecord?
    @State private var selectedSettingsCategory: SettingsCategory = .viewfinder
    @State private var handledAppIntentRoutingIdentifier: String?
    @State private var didOpenProjectReviewForUITest = false
    @State private var didOpenTimedCaptureHandoffForUITest = false
    @State private var reviewAccessibilityFixtureSnapshot: BracketProjectReviewSnapshot?

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
                CameraChromeProbe(
                    identifier: "camera.intelligence.availability",
                    label: "Apple Intelligence Availability",
                    value: intelligenceAvailability.accessibilityValue
                )
                CameraChromeProbe(
                    identifier: "camera.captureContext.privacy",
                    label: "Capture Context Privacy",
                    value: captureContextPrivacyValue
                )
                CameraChromeProbe(
                    identifier: "camera.captureCoach.firstSuggestion",
                    label: "Capture Coach First Suggestion",
                    value: captureCoachFirstSuggestionValue
                )
                CameraChromeProbe(
                    identifier: "camera.captureCoach.source",
                    label: "Capture Coach Source",
                    value: captureCoachSourceValue
                )
                CameraChromeProbe(
                    identifier: "camera.bracketPlan.current",
                    label: "Current Bracket Plan",
                    value: currentBracketPlanAccessibilityValue
                )
                CameraChromeProbe(
                    identifier: "camera.appIntent.lastHandoff",
                    label: "App Intent Last Handoff",
                    value: appIntentRouter.lastHandoff?.accessibilityValue ?? "No App Intent handoff"
                )
                CameraChromeProbe(
                    identifier: "camera.appIntent.shortcutInventory",
                    label: "App Intent Shortcut Inventory",
                    value: BracketerShortcutTileInventory.current.accessibilityValue
                )
                CameraChromeProbe(
                    identifier: "camera.project.latest",
                    label: "Latest Bracket Project",
                    value: camera.lastBracketProject?.accessibilityValue ?? "No bracket project"
                )
                CameraChromeProbe(
                    identifier: "camera.project.reviewHandoff",
                    label: "Project Review Handoff",
                    value: camera.restoredProjectReviewSnapshot?.accessibilityValue ?? "No project review handoff"
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

                        if shouldShowGuidanceStack {
                            cameraGuidanceStack
                                .padding(.top, 10)
                                .padding(.horizontal, 16)
                        }

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

                        if shouldShowGuidanceStack {
                            VStack {
                                Spacer()
                                    .frame(height: safeTop + 78)
                                cameraGuidanceStack
                                    .padding(.horizontal, 16)
                                Spacer()
                            }
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
                    .transition(bottomSheetTransition)
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
                        timerMode: $settings.timerMode,
                        intelligenceAvailability: intelligenceAvailability,
                        captureCoachRun: currentCaptureCoachRun,
                        isRefreshingCaptureCoach: isRefreshingCaptureCoach,
                        refreshCaptureCoach: {
                            Task {
                                await refreshCaptureCoach()
                            }
                        },
                        bracketRecipePrompt: bracketRecipePromptBinding,
                        bracketRecipeRun: currentBracketRecipeRun,
                        isPlanningBracketRecipe: isPlanningBracketRecipe,
                        planBracketRecipe: {
                            Task {
                                await planBracketRecipe()
                            }
                        },
                        applyBracketRecipe: applyBracketRecipe,
                        appliedBracketRecipeValue: appliedBracketRecipeValue,
                        recentBracketRecipes: settings.recentBracketRecipes,
                        storesGeneratedProjectNotes: $settings.storesGeneratedProjectNotes,
                        selectedCategory: $selectedSettingsCategory
                    )
                    .transition(bottomSheetTransition)
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
                    .transition(topNotificationTransition)
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
                    .transition(topNotificationTransition)
                    .zIndex(99)
                }

                if enablesReviewFixtureForUITests {
                    DeterministicImageReviewFixtureView(onDismiss: {})
                        .zIndex(1_000)
                }

                if let reviewAccessibilityFixtureSnapshot {
                    BracketProjectReviewHandoffView(
                        snapshot: reviewAccessibilityFixtureSnapshot,
                        intelligenceAvailability: intelligenceAvailability
                    ) {
                        self.reviewAccessibilityFixtureSnapshot = nil
                    }
                    .zIndex(1_001)
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
                    withAnimation(
                        ModernDesignSystem.Animations.motionAware(
                            .spring(response: 0.3, dampingFraction: 0.7),
                            reduceMotionEnabled: effectiveAccessibilityReduceMotion
                        )
                    ) {
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
        .onChange(of: appIntentRouter.lastHandoff) { _, handoff in
            handleAppIntentHandoff(handoff)
        }
        .onChange(of: settings.teleUses12MP) { _, newValue in
            camera.teleUses12MP = newValue
            if camera.selectedCamera == .twoX || camera.selectedCamera == .eightX {
                camera.switchCamera(to: camera.selectedCamera)
            }
        }
        .onChange(of: settings.storesGeneratedProjectNotes) { _, newValue in
            camera.storesGeneratedProjectNotes = newValue
        }
        .task {
            // Connect orientation manager to camera
            camera.orientationManager = orientationManager
            camera.teleUses12MP = settings.teleUses12MP
            camera.storesGeneratedProjectNotes = settings.storesGeneratedProjectNotes
            camera.intelligenceAvailabilityForProjectNotes = intelligenceAvailability
            if usesFocusPeakingFixtureForUITests {
                settings.focusPeakingEnabled = true
                settings.focusPeakingColor = .green
                settings.focusPeakingIntensity = 0.8
            }
            if enablesSimulatedCameraForUITests {
                camera.enableSimulatedCaptureForUITests()
            }
            openReviewAccessibilityFixtureForUITestIfNeeded()
            await resumeRuntimeServices()
            // Align the zoom UI with the active logical camera
            selectedZoom = CameraZoomLevel.forCameraKind(camera.selectedCamera)
        }
        .onAppear {
            motionManager.isLevelingActive = settings.showLevel
            handleAppIntentHandoff(appIntentRouter.lastHandoff)
            openTimedCaptureHandoffForUITestIfNeeded()
            openLatestReviewHandoffForUITestIfNeeded()
            openLatestProjectReviewForUITestIfNeeded()
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
                SimulatedBracketReviewView(
                    review: simulatedReview,
                    appliedRecipeRecord: camera.activeBracketRecipeRecord,
                    intelligenceAvailability: intelligenceAvailability
                ) {
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
                    bracketManifest: camera.lastBracketManifest,
                    intelligenceAvailability: intelligenceAvailability,
                    onResourceInspectionUpdate: { shotResources in
                        _ = try? camera.updateLatestProjectResourceInspection(shotResources: shotResources)
                    },
                    onThumbnailInspectionUpdate: { shotThumbnail in
                        _ = try? camera.updateLatestProjectThumbnailInspection(shotThumbnail: shotThumbnail)
                    }
                ) {
                    camera.showImageViewer = false
                }
            }
        }
        .fullScreenCover(item: restoredProjectReviewBinding) { snapshot in
            BracketProjectReviewHandoffView(
                snapshot: snapshot,
                intelligenceAvailability: intelligenceAvailability
            ) {
                camera.clearRestoredProjectReview()
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

    private var captureContextSummary: CaptureContextSummary {
        let contextSettings = CaptureContextSettings(
            shootingMode: settings.currentShootingMode.rawValue,
            showGrid: settings.showGrid,
            gridType: settings.gridType.rawValue,
            showLevel: settings.showLevel,
            focusPeakingEnabled: settings.focusPeakingEnabled,
            focusPeakingColorName: focusPeakingColorName,
            focusPeakingIntensity: settings.focusPeakingIntensity,
            showHistogram: showHistogram,
            showZebras: showZebras
        )

        return CaptureContextSummary.make(
            plan: currentBracketPlan,
            deviceSnapshot: DeviceGating.shared.capabilitySnapshot,
            captureConfiguration: camera.effectiveCaptureConfiguration(
                flashMode: settings.flashMode,
                timerMode: settings.timerMode
            ),
            settings: contextSettings,
            frameAnalysis: uiTestFrameAnalysisOverride ?? camera.histogramProcessor.frameAnalysis,
            reviewSequence: camera.lastBracketReviewSequence,
            manifest: camera.lastBracketManifest,
            intelligenceAvailability: intelligenceAvailability
        )
    }

    private var captureCoachResponse: CaptureCoachResponse {
        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: captureContextSummary
        )
        return DeterministicCaptureCoach.response(for: request)
    }

    private var currentCaptureCoachRun: CaptureCoachRun {
        refreshedCaptureCoachRun ?? CaptureCoachRun(
            source: .deterministicFallback,
            response: captureCoachResponse,
            fallbackReason: "Not refreshed in this session."
        )
    }

    private var bracketRecipePromptBinding: Binding<String> {
        Binding(
            get: { bracketRecipePrompt },
            set: { newValue in
                bracketRecipePrompt = newValue
                refreshedBracketRecipeRun = nil
            }
        )
    }

    private var bracketRecipeResponse: BracketRecipeResponse {
        let request = BracketRecipeRequest.make(
            prompt: bracketRecipePrompt,
            context: captureContextSummary
        )
        return DeterministicBracketRecipePlanner.response(for: request)
    }

    private var currentBracketRecipeRun: BracketRecipeRun {
        refreshedBracketRecipeRun ?? BracketRecipeRun(
            source: .deterministicFallback,
            response: bracketRecipeResponse,
            fallbackReason: "Not planned in this session."
        )
    }

    private var captureContextPrivacyValue: String {
        captureContextSummary.privacy.notes.joined(separator: " | ")
    }

    private var captureCoachFirstSuggestionValue: String {
        guard let suggestion = currentCaptureCoachRun.response.suggestions.first else {
            return "No suggestions"
        }
        return "\(suggestion.title) | \(suggestion.rationale) | Action: \(suggestion.action)"
    }

    private var currentBracketPlan: BracketPlan {
        BracketPlan(
            evStep: settings.selectedEVStep,
            requestedShotCount: settings.bracketShotCount,
            centerBias: currentEVCompensation
        )
    }

    private var currentBracketPlanAccessibilityValue: String {
        let offsets = currentBracketPlan.shots.map(\.displayLabel).joined(separator: ", ")
        return "\(currentBracketPlan.shotCount) shots | \(offsets) | Center \(BracketEVFormatter.displayLabel(for: currentBracketPlan.centerBias))"
    }

    private var appliedBracketRecipeValue: String {
        activeBracketRecipe?.accessibilityValue ?? "No bracket recipe applied"
    }

    private var restoredProjectReviewBinding: Binding<BracketProjectReviewSnapshot?> {
        Binding(
            get: { camera.restoredProjectReviewSnapshot },
            set: { snapshot in
                if snapshot == nil {
                    camera.clearRestoredProjectReview()
                }
            }
        )
    }

    private var shouldShowGuidanceStack: Bool {
        !showProControls
            && !showSettings
            && !camera.bracketSequenceState.isActive
            && !camera.isInitializing
    }

    private var cameraGuidanceStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            CaptureCoachCompactCard(
                run: currentCaptureCoachRun,
                availability: intelligenceAvailability,
                action: openIntelligenceSettings
            )
            BracketPlanPreviewStrip(
                plan: currentBracketPlan,
                activeRecipe: activeBracketRecipe,
                action: openIntelligenceSettings
            )
        }
    }

    private var captureCoachSourceValue: String {
        let run = currentCaptureCoachRun
        return [
            run.source.rawValue,
            run.fallbackReason ?? "No fallback",
        ].joined(separator: " | ")
    }

    private var focusPeakingColorName: String {
        let colors: [(name: String, color: Color)] = [
            ("red", .red),
            ("blue", .blue),
            ("yellow", .yellow),
            ("green", .green),
            ("orange", .orange),
            ("purple", .purple),
            ("white", .white),
        ]
        return colors.first { $0.color == settings.focusPeakingColor }?.name ?? "custom"
    }

    @MainActor
    private func refreshCaptureCoach() async {
        guard !isRefreshingCaptureCoach else { return }

        isRefreshingCaptureCoach = true
        defer { isRefreshingCaptureCoach = false }

        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: captureContextSummary
        )
        refreshedCaptureCoachRun = await CaptureCoachEngine.live.response(for: request)
    }

    @MainActor
    private func planBracketRecipe() async {
        guard !isPlanningBracketRecipe else { return }

        isPlanningBracketRecipe = true
        defer { isPlanningBracketRecipe = false }

        let request = BracketRecipeRequest.make(
            prompt: bracketRecipePrompt,
            context: captureContextSummary
        )
        refreshedBracketRecipeRun = await BracketRecipeEngine.live.response(for: request)
    }

    private func applyBracketRecipe(_ recommendation: BracketRecipeRecommendation) {
        let appliedPlan = settings.applyBracketRecipePlan(recommendation.plan)
        let appliedRecipeRecord = AppliedBracketRecipeRecord(
            title: recommendation.title,
            source: currentBracketRecipeRun.source,
            plan: BracketRecipePlan(
                evStep: appliedPlan.evStep,
                requestedShotCount: appliedPlan.shotCount,
                centerBias: appliedPlan.centerBias
            )
        )
        currentEVCompensation = appliedPlan.centerBias
        camera.setExposureCompensation(appliedPlan.centerBias)
        refreshedCaptureCoachRun = nil
        activeBracketRecipeRecord = appliedRecipeRecord
        camera.activeBracketRecipeRecord = appliedRecipeRecord
        activeBracketRecipe = ActiveBracketRecipeSummary(
            record: appliedRecipeRecord
        )
        settings.recordAppliedBracketRecipe(appliedRecipeRecord)
        HapticManager.shared.panelToggled()
    }

    private func openIntelligenceSettings() {
        selectedSettingsCategory = .intelligence
        withAnimation(motionAwareSpring) {
            showSettings = true
        }
        HapticManager.shared.panelToggled()
    }

    private func handleAppIntentHandoff(_ handoff: BracketerAppIntentHandoff?) {
        guard let handoff else { return }
        guard handledAppIntentRoutingIdentifier != handoff.routingIdentifier else { return }

        handledAppIntentRoutingIdentifier = handoff.routingIdentifier
        applyAppIntentCapturePreparation(handoff)
        switch handoff.destination {
        case .camera:
            showSettings = false
            showProControls = false
        case .proControls:
            showSettings = false
            withAnimation(motionAwareSpring) {
                showProControls = true
            }
        case .intelligence:
            openIntelligenceSettings()
        case .review:
            let source = handoff.projectTitle.map { "Project Handoff: \($0)" } ?? "Project Handoff: Latest Review"
            if let projectIdentifier = handoff.projectIdentifier {
                _ = camera.restoreProjectReview(
                    projectID: projectIdentifier,
                    source: source,
                    openedAt: handoff.requestedAt
                )
            } else {
                _ = camera.restoreLatestProjectReview(
                    source: source,
                    openedAt: handoff.requestedAt
                )
            }
        }
    }

    private func applyAppIntentCapturePreparation(_ handoff: BracketerAppIntentHandoff) {
        settings.selectedEVStep = handoff.bracketPreset.evStep
        settings.bracketShotCount = handoff.bracketPreset.shotCount
        if let timerMode = handoff.timerMode {
            settings.timerMode = timerMode.timerMode
        }
    }

    private func openLatestProjectReviewForUITestIfNeeded() {
        guard opensLatestProjectReviewForUITests, !didOpenProjectReviewForUITest else { return }
        didOpenProjectReviewForUITest = true
        _ = camera.restoreLatestProjectReview(
            source: "UI Test Project Handoff",
            openedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func openTimedCaptureHandoffForUITestIfNeeded() {
        guard opensTimedCaptureHandoffForUITests, !didOpenTimedCaptureHandoffForUITest else { return }
        didOpenTimedCaptureHandoffForUITest = true
        let handoff = BracketerAppIntentHandoff(
            destination: .camera,
            bracketPreset: .fiveShotTwoEV,
            requestedAt: Date(timeIntervalSince1970: 0),
            timerMode: .threeSeconds
        )
        BracketerAppIntentRouter.shared.handle(handoff)
        handleAppIntentHandoff(handoff)
    }

    private func openLatestReviewHandoffForUITestIfNeeded() {
        guard opensLatestReviewHandoffForUITests, !didOpenProjectReviewForUITest else { return }
        didOpenProjectReviewForUITest = true
        let handoff = BracketerAppIntentHandoff(
            destination: .review,
            bracketPreset: .threeShotOneEV,
            requestedAt: Date(timeIntervalSince1970: 0),
            projectTitle: "Latest Review"
        )
        BracketerAppIntentRouter.shared.handle(handoff)
        handleAppIntentHandoff(handoff)
    }

    private func openReviewAccessibilityFixtureForUITestIfNeeded() {
        guard opensReviewAccessibilityFixtureForUITests, !didOpenProjectReviewForUITest else { return }
        didOpenProjectReviewForUITest = true
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: [
                "review-accessibility--4.0EV",
                "review-accessibility--2.0EV",
                "review-accessibility-0EV",
                "review-accessibility-+2.0EV",
                "review-accessibility-+4.0EV",
            ],
            capturedAt: Date(timeIntervalSince1970: 0),
            fileType: "RAW + Processed",
            metadataAvailability: .available(summary: "18 metadata keys / 4032 x 3024 / ISO 125 / Wide Camera"),
            availableRepresentations: [.processed, .raw]
        )
        let manifest = sequence.manifest(
            groupIdentifier: "review-accessibility-fixture",
            source: .photos,
            plan: plan,
            captureMotion: .unavailable(
                source: "UI-test review fixture motion manager not connected",
                captureDurationMilliseconds: 420
            )
        )
        let project = BracketProject.make(
            manifest: manifest,
            reviewSequence: sequence,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        camera.lastBracketProject = project
        camera.lastBracketManifest = manifest
        camera.lastBracketReviewSequence = sequence
        reviewAccessibilityFixtureSnapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 0),
            source: "UI Test Review Accessibility Fixture"
        )
    }

    private func prepareSimulatedReviewFromUITest() {
        let plan = BracketPlan(
            evStep: settings.selectedEVStep,
            requestedShotCount: settings.bracketShotCount,
            centerBias: currentEVCompensation
        )
        let simulatedReview = SimulatedBracketReview.make(plan: plan)
        camera.simulatedBracketReview = simulatedReview
        camera.activeBracketRecipeRecord = activeBracketRecipeRecord
        camera.storesGeneratedProjectNotes = settings.storesGeneratedProjectNotes
        camera.intelligenceAvailabilityForProjectNotes = intelligenceAvailability
        let sequence = simulatedReview.sequence
        let manifest = sequence.manifest(
            groupIdentifier: simulatedReview.id,
            source: .simulated,
            plan: simulatedReview.plan,
            recipe: activeBracketRecipeRecord
        )
        camera.lastBracketReviewSequence = sequence
        camera.lastBracketManifest = manifest
        camera.recordLatestBracketProject(
            manifest: manifest,
            reviewSequence: sequence
        )
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
        Text(label)
            .font(.system(size: 1))
            .foregroundColor(.white.opacity(0.01))
            .frame(width: 1, height: 1)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityIdentifier(identifier)
    }
}

private struct CaptureCoachCompactCard: View {
    let run: CaptureCoachRun
    let availability: IntelligenceFeatureAvailability
    let action: () -> Void

    private var suggestion: CaptureCoachSuggestion? {
        run.response.suggestions.first
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(sourceTitle)
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(tint)
                            .lineLimit(1)

                        Circle()
                            .fill(availability.isUsable ? ModernDesignSystem.Colors.success : ModernDesignSystem.Colors.warning)
                            .frame(width: 5, height: 5)
                    }

                    Text(suggestion?.title ?? "Capture Coach")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .lineLimit(1)

                    Text(suggestion?.action ?? "Open AI capture guidance.")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(width: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.46))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .liquidGlass(intensity: .regular, tint: tint.opacity(0.12), interactive: true)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture Coach")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("camera.captureCoach.card")
    }

    private var sourceTitle: String {
        switch run.source {
        case .foundationModels:
            return "Apple Intelligence"
        case .deterministicFallback:
            return "Deterministic Coach"
        }
    }

    private var iconName: String {
        switch run.source {
        case .foundationModels:
            return "sparkles"
        case .deterministicFallback:
            return "checklist"
        }
    }

    private var tint: Color {
        switch run.source {
        case .foundationModels:
            return ModernDesignSystem.Colors.accentTertiary
        case .deterministicFallback:
            return ModernDesignSystem.Colors.professional
        }
    }

    private var accessibilityValue: String {
        guard let suggestion else {
            return "\(run.source.rawValue) | No suggestions | \(run.fallbackReason ?? "No fallback")"
        }

        return [
            "\(suggestion.title) | \(suggestion.rationale) | Action: \(suggestion.action)",
            "Source: \(run.source.rawValue)",
            run.fallbackReason ?? "No fallback",
        ].joined(separator: " | ")
    }
}

private struct ActiveBracketRecipeSummary: Equatable {
    let title: String
    let source: BracketRecipeRunSource
    let plan: BracketRecipePlan

    init(record: AppliedBracketRecipeRecord) {
        self.title = record.title
        self.source = record.source
        self.plan = record.plan
    }

    var sourceLabel: String {
        switch source {
        case .foundationModels:
            return "Apple Intelligence"
        case .deterministicFallback:
            return "Deterministic"
        }
    }

    var accessibilityValue: String {
        "\(title) | \(plan.accessibilitySummary) | Source: \(source.rawValue)"
    }
}

private struct BracketPlanPreviewStrip: View {
    let plan: BracketPlan
    let activeRecipe: ActiveBracketRecipeSummary?
    let action: () -> Void

    var body: some View {
        Group {
            if activeRecipe != nil {
                Button(action: action) {
                    stripContent
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Settings AI")
            } else {
                stripContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bracket Plan")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("camera.bracketPlan.strip")
    }

    private var stripContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label("\(plan.shotCount) shot bracket", systemImage: "camera.aperture")
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("Center \(BracketEVFormatter.displayLabel(for: plan.centerBias))")
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .lineLimit(1)
            }

            if let activeRecipe {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ModernDesignSystem.Colors.accentTertiary)

                    Text(activeRecipe.title)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 6)

                    Text(activeRecipe.sourceLabel)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
            }

            HStack(spacing: 6) {
                ForEach(plan.shots) { shot in
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(shot.isCenterExposure ? ModernDesignSystem.Colors.success : tint(for: shot))
                            .frame(width: 5, height: barHeight(for: shot))

                        Text(shot.displayLabel)
                            .font(.system(size: 9, weight: shot.isCenterExposure ? .bold : .medium, design: .monospaced))
                            .foregroundColor(shot.isCenterExposure ? ModernDesignSystem.Colors.cameraControl : ModernDesignSystem.Colors.cameraControlSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .liquidGlass(intensity: .subtle, tint: .orange.opacity(0.10), interactive: false)
                )
        )
    }

    private func tint(for shot: BracketShot) -> Color {
        shot.evOffset < plan.centerBias ? ModernDesignSystem.Colors.professional : ModernDesignSystem.Colors.warning
    }

    private func barHeight(for shot: BracketShot) -> CGFloat {
        10 + CGFloat(min(abs(shot.evOffset - plan.centerBias), 4)) * 4
    }

    private var accessibilityValue: String {
        let offsets = plan.shots.map(\.displayLabel).joined(separator: ", ")
        let base = "\(plan.shotCount) shots | \(offsets) | Center \(BracketEVFormatter.displayLabel(for: plan.centerBias))"
        guard let activeRecipe else { return base }
        return "\(base) | Recipe: \(activeRecipe.title) | Source: \(activeRecipe.source.rawValue)"
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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding var showProControls: Bool

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    var body: some View {
        Button {
            withAnimation(
                ModernDesignSystem.Animations.motionAwareSpring(
                    reduceMotionEnabled: effectiveAccessibilityReduceMotion
                )
            ) {
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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding var showSettings: Bool

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    var body: some View {
        Button {
            withAnimation(
                ModernDesignSystem.Animations.motionAwareSpring(
                    reduceMotionEnabled: effectiveAccessibilityReduceMotion
                )
            ) {
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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding var showProControls: Bool

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    var body: some View {
        Button {
            withAnimation(
                ModernDesignSystem.Animations.motionAwareSpring(
                    reduceMotionEnabled: effectiveAccessibilityReduceMotion
                )
            ) {
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
            .frame(minWidth: 44, minHeight: 44)
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

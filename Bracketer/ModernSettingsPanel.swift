import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Modern Settings Panel
/// Apple Camera app inspired settings with iOS 18+ design patterns
/// Professional camera settings with modern interface

struct ModernSettingsPanel: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ObservedObject var camera: CameraController
    @Binding var showSettings: Bool
    @Binding var showGrid: Bool
    @Binding var gridType: GridType
    @Binding var showLevel: Bool
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    @Binding var teleUses12MP: Bool
    @Binding var flashMode: FlashMode
    @Binding var timerMode: TimerMode
    let intelligenceAvailability: IntelligenceFeatureAvailability
    let captureCoachRun: CaptureCoachRun
    let isRefreshingCaptureCoach: Bool
    let refreshCaptureCoach: () -> Void
    @Binding var bracketRecipePrompt: String
    let bracketRecipeRun: BracketRecipeRun
    let isPlanningBracketRecipe: Bool
    let planBracketRecipe: () -> Void
    let applyBracketRecipe: (BracketRecipeRecommendation) -> Void
    let appliedBracketRecipeValue: String
    let recentBracketRecipes: [AppliedBracketRecipeRecord]
    @Binding var storesGeneratedProjectNotes: Bool
    @Binding var selectedCategory: SettingsCategory

    private let focusPeakingColors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple, .white]

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    private var motionAwareSpring: Animation? {
        ModernDesignSystem.Animations.motionAwareSpring(reduceMotionEnabled: effectiveAccessibilityReduceMotion)
    }

    private var quickPresetData: [SettingsPresetButtonData] {
        [
            SettingsPresetButtonData(
                accessibilityID: "landscape",
                title: "Landscape",
                subtitle: "Balanced outdoor look",
                icon: "mountain.2.fill",
                tint: .blue.opacity(0.6)
            ) {
                showGrid = true
                gridType = .goldenRatio
                showLevel = true
                focusPeakingEnabled = false
                focusPeakingIntensity = 0.4
            },
            SettingsPresetButtonData(
                accessibilityID: "portrait",
                title: "Portrait",
                subtitle: "Mid grid, warm peaking",
                icon: "person.crop.square",
                tint: .pink.opacity(0.7)
            ) {
                showGrid = true
                gridType = .centerCrosshair
                showLevel = false
                focusPeakingEnabled = true
                focusPeakingColor = .orange
                focusPeakingIntensity = 0.65
            },
            SettingsPresetButtonData(
                accessibilityID: "studio",
                title: "Studio",
                subtitle: "Minimal UI, strong peaking",
                icon: "sparkles",
                tint: .purple.opacity(0.6)
            ) {
                showGrid = false
                showLevel = false
                focusPeakingEnabled = true
                focusPeakingColor = .green
                focusPeakingIntensity = 0.85
            },
            SettingsPresetButtonData(
                accessibilityID: "tripod",
                title: "Tripod",
                subtitle: "Precise leveling + grid",
                icon: "level",
                tint: .teal.opacity(0.6)
            ) {
                showGrid = true
                gridType = .ruleOfThirds
                showLevel = true
                focusPeakingEnabled = false
            }
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced background overlay with glass effect
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(motionAwareSpring) {
                            showSettings = false
                        }
                    }

                // Settings panel as bottom sheet
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: ModernDesignSystem.Spacing.md) {
                        // Drag handle (iOS style)
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(ModernDesignSystem.Colors.cameraControlSecondary)
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)

                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Settings")
                                    .font(ModernDesignSystem.Typography.title2)
                                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                                    .accessibilityIdentifier("settings.title")
                                Text(selectedCategory.subtitle)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            }

                            Spacer()

                            Button {
                                withAnimation(motionAwareSpring) {
                                    showSettings = false
                                }
                                HapticManager.shared.panelToggled()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .liquidGlass(intensity: .prominent, tint: .white.opacity(0.12), interactive: true)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.closeButton")
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)

                        Picker("Category", selection: $selectedCategory) {
                            ForEach(SettingsCategory.allCases) { category in
                                Text(category.title)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.categoryPicker")
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)

                        // Settings sections
                        ScrollView {
                            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                                ModernQuickPresetCard(presets: quickPresetData)

                                Group {
                                    switch selectedCategory {
                                    case .viewfinder:
                                        ModernViewfinderSettings(
                                            showGrid: $showGrid,
                                            gridType: $gridType,
                                            showLevel: $showLevel
                                        )
                                    case .focus:
                                        ModernFocusSettings(
                                            focusPeakingEnabled: $focusPeakingEnabled,
                                            focusPeakingColor: $focusPeakingColor,
                                            focusPeakingIntensity: $focusPeakingIntensity,
                                            focusPeakingColors: focusPeakingColors
                                        )
                                    case .capture:
                                        ModernCameraSettings(
                                            camera: camera,
                                            teleUses12MP: $teleUses12MP,
                                            selectedCamera: camera.selectedCamera,
                                            flashMode: flashMode,
                                            timerMode: timerMode
                                        )
                                    case .intelligence:
                                        ModernIntelligenceSettings(
                                            availability: intelligenceAvailability,
                                            captureCoachRun: captureCoachRun,
                                            isRefreshingCaptureCoach: isRefreshingCaptureCoach,
                                            refreshCaptureCoach: refreshCaptureCoach,
                                            bracketRecipePrompt: $bracketRecipePrompt,
                                            bracketRecipeRun: bracketRecipeRun,
                                            isPlanningBracketRecipe: isPlanningBracketRecipe,
                                            planBracketRecipe: planBracketRecipe,
                                            applyBracketRecipe: applyBracketRecipe,
                                            appliedBracketRecipeValue: appliedBracketRecipeValue,
                                            recentBracketRecipes: recentBracketRecipes
                                        )
                                    case .about:
                                        ModernAboutSection(
                                            diagnosticsReport: camera.runtimeDiagnostics.exportText,
                                            projectLibrarySnapshot: camera.bracketProjectLibrarySnapshot,
                                            intelligenceAvailability: intelligenceAvailability,
                                            captureCoachRun: captureCoachRun,
                                            bracketRecipeRun: bracketRecipeRun,
                                            storesGeneratedProjectNotes: $storesGeneratedProjectNotes,
                                            previewImportArchiveText: { archiveText, conflictPolicy in
                                                try camera.previewProjectArchiveText(
                                                    archiveText,
                                                    conflictPolicy: conflictPolicy
                                                )
                                            },
                                            importArchiveText: { archiveText, conflictPolicy in
                                                try camera.importProjectArchiveText(
                                                    archiveText,
                                                    conflictPolicy: conflictPolicy
                                                )
                                            },
                                            updateProjectCuration: { projectID, isFavorite, acceptedTags, userNote in
                                                try camera.updateProjectCuration(
                                                    projectID: projectID,
                                                    isFavorite: isFavorite,
                                                    acceptedTags: acceptedTags,
                                                    userNote: userNote
                                                )
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                            .padding(.bottom, ModernDesignSystem.Spacing.xl)
                        }
                        .accessibilityIdentifier("settings.scrollView")
                    }
                    .frame(maxHeight: geometry.size.height * 0.75)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .liquidGlass(intensity: .regular, tint: .white.opacity(0.1), interactive: true)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: -12)
                    )
                    .padding(.horizontal, 12)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }
}

// MARK: - Modern Viewfinder Settings
struct ModernViewfinderSettings: View {
    @Binding var showGrid: Bool
    @Binding var gridType: GridType
    @Binding var showLevel: Bool

    var body: some View {
        ModernSettingsCard(
            title: "Viewfinder",
            subtitle: "Composition tools",
            icon: "viewfinder"
        ) {
            ModernToggleRow(
                icon: "square.grid.3x3",
                title: "Grid Overlay",
                subtitle: "Show guides on the preview",
                tint: ModernDesignSystem.Colors.professional,
                accessibilityID: "grid",
                isOn: $showGrid
            )

            if showGrid {
                ModernDropdownPicker(
                    title: "Grid Style",
                    icon: "square.grid.3x3",
                    options: GridType.allCases,
                    selection: $gridType,
                    accessibilityID: "gridStyle",
                    labelProvider: { $0.rawValue }
                )
                .padding(.top, ModernDesignSystem.Spacing.sm)

                GridTypePreview(gridType: gridType)
                    .frame(height: 110)
                    .transition(.opacity.combined(with: .scale))
            }

            Divider()
                .background(Color.white.opacity(0.08))

            ModernToggleRow(
                icon: "level",
                title: "Level Indicator",
                subtitle: "Keep horizons perfectly straight",
                tint: ModernDesignSystem.Colors.warning,
                accessibilityID: "level",
                isOn: $showLevel
            )
        }
    }
}

// MARK: - Modern Focus Settings
struct ModernFocusSettings: View {
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    let focusPeakingColors: [Color]

    var body: some View {
        ModernSettingsCard(
            title: "Focus & Peaking",
            subtitle: "Manual assist options",
            icon: "eye"
        ) {
            ModernToggleRow(
                icon: "viewfinder.circle",
                title: "Focus Peaking",
                subtitle: "Highlight crisp edges",
                tint: ModernDesignSystem.Colors.success,
                accessibilityID: "focusPeaking",
                isOn: $focusPeakingEnabled
            )

            if focusPeakingEnabled {
                FocusPeakingColorPicker(
                    selectedColor: $focusPeakingColor,
                    colors: focusPeakingColors
                )
                FocusPeakingIntensitySlider(intensity: $focusPeakingIntensity)
            }
        }
    }
}

// MARK: - Modern Camera Settings
struct ModernCameraSettings: View {
    @ObservedObject var camera: CameraController
    @Binding var teleUses12MP: Bool
    let selectedCamera: CameraKind
    let flashMode: FlashMode
    let timerMode: TimerMode

    private var captureConfiguration: EffectiveCaptureConfiguration {
        camera.effectiveCaptureConfiguration(flashMode: flashMode, timerMode: timerMode)
    }

    private var captureBadges: [ModernSettingBadgeData] {
        [
            ModernSettingBadgeData(
                accessibilityID: "photoFormat",
                icon: "photo.on.rectangle",
                title: "Photo Format",
                value: captureConfiguration.formatDisplayName,
                tint: ModernDesignSystem.Colors.cameraControlActive
            ),
            ModernSettingBadgeData(
                accessibilityID: "flash",
                icon: "bolt.fill",
                title: "Flash",
                value: captureConfiguration.flashDisplayName,
                tint: captureConfiguration.isFlashAvailable
                    ? (flashMode == .off ? .gray : .yellow)
                    : .gray
            ),
            ModernSettingBadgeData(
                accessibilityID: "timer",
                icon: "timer",
                title: "Timer",
                value: captureConfiguration.timerDisplayName,
                tint: timerMode == .off ? .gray : .orange
            ),
            ModernSettingBadgeData(
                accessibilityID: "location",
                icon: "location.fill",
                title: "Location",
                value: captureConfiguration.locationDisplayName,
                tint: captureConfiguration.locationState == .on ? .orange : .gray
            )
        ]
    }

    var body: some View {
        ModernSettingsCard(
            title: "Capture",
            subtitle: "Formats & hardware",
            icon: "camera.aperture"
        ) {
            ModernSettingBadgeGrid(badges: captureBadges)

            Divider()
                .background(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "camera.aperture")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlActive)
                    Text("Telephoto Resolution")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Spacer()
                    Text(teleUses12MP ? "12MP" : "48MP")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                Picker("Tele Resolution", selection: $teleUses12MP) {
                    Text("48MP Detail").tag(false)
                    Text("12MP Low Light").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(!(selectedCamera == .twoX || selectedCamera == .eightX))

                Text("Choose 12MP for cleaner tele shots in low light, or 48MP for maximum detail.")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
        }
    }
}

// MARK: - Modern Intelligence Settings
struct ModernIntelligenceSettings: View {
    let availability: IntelligenceFeatureAvailability
    let captureCoachRun: CaptureCoachRun
    let isRefreshingCaptureCoach: Bool
    let refreshCaptureCoach: () -> Void
    @Binding var bracketRecipePrompt: String
    let bracketRecipeRun: BracketRecipeRun
    let isPlanningBracketRecipe: Bool
    let planBracketRecipe: () -> Void
    let applyBracketRecipe: (BracketRecipeRecommendation) -> Void
    let appliedBracketRecipeValue: String
    let recentBracketRecipes: [AppliedBracketRecipeRecord]

    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ModernSettingsCard(
                title: "Apple Intelligence",
                subtitle: "Local generative assistance",
                icon: "sparkles"
            ) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                        Image(systemName: availability.isUsable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(availability.isUsable ? ModernDesignSystem.Colors.success : ModernDesignSystem.Colors.warning)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(availability.statusTitle)
                                .font(ModernDesignSystem.Typography.bodyBold)
                                .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                                .accessibilityIdentifier("settings.intelligence.availability.title")

                            Text(availability.statusDetail)
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.intelligence.availability")
                    .accessibilityValue(availability.accessibilityValue)

                    if let recoveryAction = availability.recoveryAction {
                        Text(recoveryAction)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .accessibilityIdentifier("settings.intelligence.recoveryAction")
                    }

                    Text("Capture, review, and manifest export remain available without Apple Intelligence.")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ModernSettingsCard(
                title: "Runtime Proof",
                subtitle: runtimeDiagnostic.title,
                icon: runtimeDiagnosticIcon
            ) {
                HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: runtimeDiagnosticIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(runtimeDiagnosticTint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(runtimeDiagnostic.title)
                            .font(ModernDesignSystem.Typography.bodyBold)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                        Text(runtimeDiagnostic.detail)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(runtimeDiagnostic.sourceSummary)
                            .font(ModernDesignSystem.Typography.monospaceSmall)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(runtimeDiagnostic.action)
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.intelligence.runtimeDiagnostic")
                .accessibilityValue(runtimeDiagnostic.accessibilityValue)
            }

            ModernSettingsCard(
                title: "Capture Coach",
                subtitle: captureCoachSourceTitle,
                icon: captureCoachSourceIcon
            ) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Label(captureCoachSourceTitle, systemImage: captureCoachSourceIcon)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(captureCoachSourceTint)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("settings.intelligence.coach.source")
                            .accessibilityValue(captureCoachSourceValue)

                        Spacer()

                        Button(action: refreshCaptureCoach) {
                            ZStack {
                                if isRefreshingCaptureCoach {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshingCaptureCoach)
                        .accessibilityLabel("Refresh Capture Coach")
                        .accessibilityIdentifier("settings.intelligence.coach.refresh")
                    }

                    if let fallbackReason = captureCoachRun.fallbackReason {
                        Text(fallbackReason)
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.intelligence.coach.fallbackReason")
                    }

                    ForEach(Array(captureCoachRun.response.suggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                        CaptureCoachSuggestionRow(index: index, suggestion: suggestion)
                    }
                }
            }

            ModernSettingsCard(
                title: "Bracket Recipe",
                subtitle: bracketRecipeSourceTitle,
                icon: "slider.horizontal.3"
            ) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    TextField("Scene description", text: $bracketRecipePrompt, axis: .vertical)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                        .accessibilityIdentifier("settings.intelligence.recipe.prompt")

                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Label(bracketRecipeSourceTitle, systemImage: bracketRecipeSourceIcon)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(bracketRecipeSourceTint)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("settings.intelligence.recipe.source")
                            .accessibilityValue(bracketRecipeSourceValue)

                        Spacer()

                        Button(action: planBracketRecipe) {
                            ZStack {
                                if isPlanningBracketRecipe {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isPlanningBracketRecipe)
                        .accessibilityLabel("Plan Bracket Recipe")
                        .accessibilityIdentifier("settings.intelligence.recipe.plan")
                    }

                    if let fallbackReason = bracketRecipeRun.fallbackReason {
                        Text(fallbackReason)
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.intelligence.recipe.fallbackReason")
                    }

                    ForEach(Array(bracketRecipeRun.response.recommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                        BracketRecipeRecommendationRow(
                            index: index,
                            recommendation: recommendation,
                            apply: {
                                applyBracketRecipe(recommendation)
                            }
                        )
                    }

                    Text(appliedBracketRecipeValue)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.intelligence.recipe.applied")
                        .accessibilityValue(appliedBracketRecipeValue)

                    if !recentBracketRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                            Text("Recent Recipes")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)

                            ForEach(Array(recentBracketRecipes.prefix(3).enumerated()), id: \.element.id) { index, record in
                                AppliedBracketRecipeRow(index: index, record: record)
                            }
                        }
                    }
                }
            }
        }
    }

    private var captureCoachSourceTitle: String {
        switch captureCoachRun.source {
        case .foundationModels:
            return "Apple Intelligence"
        case .deterministicFallback:
            return "Deterministic"
        }
    }

    private var captureCoachSourceIcon: String {
        switch captureCoachRun.source {
        case .foundationModels:
            return "sparkles"
        case .deterministicFallback:
            return "checklist"
        }
    }

    private var captureCoachSourceTint: Color {
        switch captureCoachRun.source {
        case .foundationModels:
            return ModernDesignSystem.Colors.accentTertiary
        case .deterministicFallback:
            return ModernDesignSystem.Colors.professional
        }
    }

    private var captureCoachSourceValue: String {
        [
            captureCoachRun.source.rawValue,
            captureCoachRun.fallbackReason ?? "No fallback",
        ].joined(separator: " | ")
    }

    private var runtimeDiagnostic: IntelligenceRuntimeDiagnostic {
        IntelligenceRuntimeDiagnostic(
            availability: availability,
            captureCoachRun: captureCoachRun,
            bracketRecipeRun: bracketRecipeRun
        )
    }

    private var runtimeDiagnosticIcon: String {
        switch runtimeDiagnostic.state {
        case .liveAppleIntelligence:
            return "sparkles"
        case .readyForLiveRun:
            return "bolt.badge.checkmark"
        case .inconclusiveFoundationModels:
            return "questionmark.circle.fill"
        case .deterministicFallback:
            return "checklist"
        }
    }

    private var runtimeDiagnosticTint: Color {
        switch runtimeDiagnostic.state {
        case .liveAppleIntelligence:
            return ModernDesignSystem.Colors.accentTertiary
        case .readyForLiveRun:
            return ModernDesignSystem.Colors.success
        case .inconclusiveFoundationModels:
            return ModernDesignSystem.Colors.warning
        case .deterministicFallback:
            return ModernDesignSystem.Colors.professional
        }
    }

    private var bracketRecipeSourceTitle: String {
        switch bracketRecipeRun.source {
        case .foundationModels:
            return "Apple Intelligence"
        case .deterministicFallback:
            return "Deterministic"
        }
    }

    private var bracketRecipeSourceIcon: String {
        switch bracketRecipeRun.source {
        case .foundationModels:
            return "sparkles"
        case .deterministicFallback:
            return "slider.horizontal.3"
        }
    }

    private var bracketRecipeSourceTint: Color {
        switch bracketRecipeRun.source {
        case .foundationModels:
            return ModernDesignSystem.Colors.accentTertiary
        case .deterministicFallback:
            return ModernDesignSystem.Colors.professional
        }
    }

    private var bracketRecipeSourceValue: String {
        [
            bracketRecipeRun.source.rawValue,
            bracketRecipeRun.fallbackReason ?? "No fallback",
        ].joined(separator: " | ")
    }
}

struct CaptureCoachSuggestionRow: View {
    let index: Int
    let suggestion: CaptureCoachSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.title)
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    .lineLimit(2)

                Text(suggestion.action)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.intelligence.coach.suggestion.\(index)")
        .accessibilityValue("\(suggestion.title) | \(suggestion.rationale) | Action: \(suggestion.action)")
    }

    private var iconName: String {
        switch suggestion.priority {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch suggestion.priority {
        case .info:
            return ModernDesignSystem.Colors.professional
        case .warning:
            return ModernDesignSystem.Colors.warning
        case .critical:
            return ModernDesignSystem.Colors.error
        }
    }
}

struct BracketRecipeRecommendationRow: View {
    let index: Int
    let recommendation: BracketRecipeRecommendation
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.warning)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.title)
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .lineLimit(2)
                        .accessibilityIdentifier("settings.intelligence.recipe.recommendation.\(index)")
                        .accessibilityValue(accessibilityValue)

                    Text(recommendation.plan.accessibilitySummary)
                        .font(ModernDesignSystem.Typography.monospaceSmall)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)

                    Text(recommendation.compactEvidenceSummary)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.intelligence.recipe.evidence.\(index)")
                        .accessibilityValue(recommendation.compactEvidenceSummary)

                    Text(recommendation.action)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: apply) {
                Label("Apply", systemImage: "checkmark.circle.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ModernDesignSystem.Colors.cameraControlActive.opacity(0.25))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.intelligence.recipe.apply.\(index)")
            .accessibilityValue(accessibilityValue)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .contain)
    }

    private var accessibilityValue: String {
        "\(recommendation.title) | \(recommendation.plan.accessibilitySummary) | \(recommendation.rationale) | Action: \(recommendation.action)"
    }
}

struct AppliedBracketRecipeRow: View {
    let index: Int
    let record: AppliedBracketRecipeRecord

    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.professional)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    .lineLimit(2)

                Text(record.plan.accessibilitySummary)
                    .font(ModernDesignSystem.Typography.monospaceSmall)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .lineLimit(2)

                Text(record.source.rawValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.intelligence.recipe.recent.\(index)")
        .accessibilityValue(record.accessibilityValue)
    }
}

// MARK: - Modern About Section
struct ModernAboutSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    let diagnosticsReport: String
    let projectLibrarySnapshot: BracketProjectLibrarySnapshot
    let intelligenceAvailability: IntelligenceFeatureAvailability
    let captureCoachRun: CaptureCoachRun
    let bracketRecipeRun: BracketRecipeRun
    @Binding var storesGeneratedProjectNotes: Bool
    let previewImportArchiveText: (String, BracketProjectImportConflictPolicy) throws -> BracketProjectImportPreview
    let importArchiveText: (String, BracketProjectImportConflictPolicy) throws -> BracketProjectImportBundle
    let updateProjectCuration: (String, Bool, [String], String?) throws -> BracketProject

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        guard let build, build != version else {
            return version
        }

        return "\(version) (\(build))"
    }

    private var privacyTrustSnapshot: BracketerPrivacyTrustSnapshot {
        BracketerPrivacyTrustSnapshot.make(
            projectLibrary: projectLibrarySnapshot,
            intelligenceAvailability: intelligenceAvailability,
            captureCoachRun: captureCoachRun,
            bracketRecipeRun: bracketRecipeRun,
            storesGeneratedProjectNotes: storesGeneratedProjectNotes,
            diagnosticsReport: diagnosticsReport
        )
    }

    private var intelligenceRuntimeDiagnostic: IntelligenceRuntimeDiagnostic {
        IntelligenceRuntimeDiagnostic(
            availability: intelligenceAvailability,
            captureCoachRun: captureCoachRun,
            bracketRecipeRun: bracketRecipeRun
        )
    }

    private var physicalDeviceProofChecklist: BracketerPhysicalDeviceProofChecklist {
        BracketerPhysicalDeviceProofChecklist.make(
            projectLibrary: projectLibrarySnapshot,
            runtimeDiagnostic: intelligenceRuntimeDiagnostic,
            privacyTrust: privacyTrustSnapshot
        )
    }

    private var accessibilityAudit: BracketerAccessibilityAudit {
        BracketerAccessibilityAudit.make(
            environmentEvidence: accessibilityEnvironmentEvidence
        )
    }

    private var accessibilityScreenshotMatrix: BracketerAccessibilityScreenshotMatrix {
        BracketerAccessibilityScreenshotMatrix.accessibilityHeavy(
            environmentEvidence: accessibilityEnvironmentEvidence
        )
    }

    private var accessibilityEnvironmentEvidence: BracketerAccessibilityAudit.EnvironmentEvidence {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment") {
            return BracketerAccessibilityAudit.EnvironmentEvidence(
                source: "UI-test forced accessibility environment",
                dynamicTypeLabel: dynamicTypeSize.accessibilityAuditLabel,
                dynamicTypeIsAccessibilitySize: dynamicTypeSize.isAccessibilityAuditSize,
                reduceMotionEnabled: true,
                highContrastEnabled: true
            )
        }

        return BracketerAccessibilityAudit.EnvironmentEvidence(
            source: "SwiftUI and UIKit accessibility environment",
            dynamicTypeLabel: dynamicTypeSize.accessibilityAuditLabel,
            dynamicTypeIsAccessibilitySize: dynamicTypeSize.isAccessibilityAuditSize,
            reduceMotionEnabled: accessibilityReduceMotion,
            highContrastEnabled: UIAccessibility.isDarkerSystemColorsEnabled
        )
    }

    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ModernPrivacyTrustCenterSection(
                snapshot: privacyTrustSnapshot,
                storesGeneratedProjectNotes: $storesGeneratedProjectNotes
            )

            ModernAccessibilityAuditSection(
                audit: accessibilityAudit,
                screenshotMatrix: accessibilityScreenshotMatrix
            )

            ModernPhysicalDeviceProofChecklistSection(checklist: physicalDeviceProofChecklist)

            ModernProjectLibrarySection(
                snapshot: projectLibrarySnapshot,
                previewImportArchiveText: previewImportArchiveText,
                importArchiveText: importArchiveText,
                updateProjectCuration: updateProjectCuration
            )

            ModernSettingsCard(
                title: "About",
                subtitle: "Build information",
                icon: "info.circle"
            ) {
                ModernSettingRow(
                    icon: "app.badge",
                    title: "Version",
                    value: versionText,
                    action: {}
                )
                ModernSettingRow(
                    icon: "book.fill",
                    title: "Show Tutorial",
                    value: "",
                    action: {
                        hasCompletedOnboarding = false
                    }
                )
#if DEBUG
                ModernDiagnosticsExportRow(report: diagnosticsReport)
#endif
            }
        }
    }
}

private struct ModernPrivacyTrustCenterSection: View {
    let snapshot: BracketerPrivacyTrustSnapshot
    @Binding var storesGeneratedProjectNotes: Bool

    var body: some View {
        ModernSettingsCard(
            title: "Privacy & Trust",
            subtitle: "Local boundaries",
            icon: "hand.raised.fill"
        ) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text(snapshot.accessibilityValue)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.privacyTrust.summary")
                    .accessibilityValue(snapshot.accessibilityValue)

                ForEach(snapshot.rows) { row in
                    ModernPrivacyTrustRow(row: row)
                }

                GeneratedProjectNotesStorageToggleRow(
                    isOn: $storesGeneratedProjectNotes
                )
            }
        }
    }
}

private struct ModernAccessibilityAuditSection: View {
    let audit: BracketerAccessibilityAudit
    let screenshotMatrix: BracketerAccessibilityScreenshotMatrix

    var body: some View {
        ModernSettingsCard(
            title: "Accessibility",
            subtitle: "Inclusive design audit",
            icon: "accessibility"
        ) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text(audit.accessibilityValue)
                    .font(.footnote)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.accessibility.audit")
                    .accessibilityValue(audit.accessibilityValue)

                if let environmentEvidence = audit.environmentEvidence {
                    Text(environmentEvidence.accessibilityValue)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.accessibility.environment")
                        .accessibilityValue(environmentEvidence.accessibilityValue)
                }

                Text(screenshotMatrix.accessibilityValue)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.accessibility.screenshotMatrix")
                    .accessibilityValue(screenshotMatrix.accessibilityValue)

                ForEach(audit.rows) { row in
                    ModernAccessibilityAuditRow(row: row)
                }
            }
        }
    }
}

private struct ModernAccessibilityAuditRow: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast: ColorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let row: BracketerAccessibilityAudit.Row

    private var forcesAccessibilityEnvironmentForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    private var iconName: String {
        switch row.status {
        case .observed:
            return "eye.fill"
        case .verified:
            return "checkmark.circle.fill"
        case .followUpRequired:
            return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch row.status {
        case .observed:
            return ModernDesignSystem.Colors.accent
        case .verified:
            return ModernDesignSystem.Colors.success
        case .followUpRequired:
            return ModernDesignSystem.Colors.warning
        }
    }

    private var borderColor: Color {
        usesIncreasedContrast ? tint.opacity(0.95) : Color.white.opacity(0.08)
    }

    private var borderWidth: CGFloat {
        usesIncreasedContrast ? 2 : 1
    }

    private var usesIncreasedContrast: Bool {
        colorSchemeContrast == .increased || forcesAccessibilityEnvironmentForUITests
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize.isAccessibilityAuditSize
    }

    private var rowAccessibilityValue: String {
        [
            row.accessibilityValue,
            "Dynamic Type layout: \(usesStackedLayout ? "Stacked" : "Inline")",
        ].joined(separator: " | ")
    }

    var body: some View {
        Group {
            if usesStackedLayout {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: ModernDesignSystem.Spacing.sm) {
                        statusIcon
                        Text(row.status.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(tint)
                    }

                    textContent
                }
            } else {
                HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                    statusIcon
                    textContent
                }
            }
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.accessibility.audit.row.\(row.id)")
        .accessibilityValue(rowAccessibilityValue)
    }

    private var statusIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 20)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                .fixedSize(horizontal: false, vertical: true)
            Text(row.detail)
                .font(.callout)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension DynamicTypeSize {
    var accessibilityAuditLabel: String {
        switch self {
        case .xSmall:
            return "Extra Small"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .xLarge:
            return "Extra Large"
        case .xxLarge:
            return "Extra Extra Large"
        case .xxxLarge:
            return "Extra Extra Extra Large"
        case .accessibility1:
            return "Accessibility 1"
        case .accessibility2:
            return "Accessibility 2"
        case .accessibility3:
            return "Accessibility 3"
        case .accessibility4:
            return "Accessibility 4"
        case .accessibility5:
            return "Accessibility 5"
        @unknown default:
            return "Unknown"
        }
    }

    var isAccessibilityAuditSize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}

private struct GeneratedProjectNotesStorageToggleRow: View {
    @Binding var isOn: Bool

    private var statusText: String {
        isOn
            ? "Future project sidecars may include source-disclosed generated review notes."
            : "Future project sidecars omit generated review notes; in-session review cards still work."
    }

    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.professional)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text("Generated Notes Storage")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                Text(statusText)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ModernDesignSystem.Colors.professional)
                .accessibilityLabel("Store Generated Notes")
                .accessibilityIdentifier("settings.privacyTrust.generatedNotesStorage")
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
    }
}

private struct ModernPrivacyTrustRow: View {
    let row: BracketerPrivacyTrustSnapshot.Row

    private var iconName: String {
        switch row.id {
        case "localComputation":
            return "cpu"
        case "photosAccess":
            return "photo.on.rectangle"
        case "locationPolicy":
            return "location.slash"
        case "appleIntelligence":
            return "sparkles"
        case "generatedContent":
            return "text.bubble"
        case "diagnostics":
            return "stethoscope"
        case "exportBoundary":
            return "square.and.arrow.up"
        default:
            return "checkmark.shield"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.professional)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                Text(row.value)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.privacyTrust.row.\(row.id)")
        .accessibilityValue(row.accessibilityValue)
    }
}

private struct ModernPhysicalDeviceProofChecklistSection: View {
    let checklist: BracketerPhysicalDeviceProofChecklist
    @State private var isImportingPhysicalProofSubmission = false
    @State private var isImportingPhysicalLabWorkspace = false
    @State private var isImportingPhysicalLabReviewHandoffPackage = false
    @State private var isImportingPhysicalDeviceAvailabilityReport = false
    @State private var proofSubmissionPreviewStatus = "No physical proof submission previewed | physical-device-proof preview only | 0 of 8 physical submissions accepted remains unchanged"
    @State private var labWorkspacePreviewStatus = "No physical lab workspace previewed | physical-lab-workspace preview only | Import preview does not mutate runbooks or result-bundle indexes | No physical proof count changed"
    @State private var labReviewHandoffPackagePreviewStatus = "No physical lab handoff package previewed | physical-lab-review-handoff preview only | Import preview does not mutate runbooks or result-bundle indexes | No physical proof count changed"
    @State private var physicalDeviceAvailabilityReportPreviewStatus = ModernPhysicalDeviceProofChecklistSection.initialPhysicalDeviceAvailabilityReportPreviewStatus()

    private static let defaultDeviceAvailabilityReportPreviewStatus = "No host device availability report previewed | host-device-availability preview only | Connected unlocked iPhone still required | No physical proof count changed"

    private static func initialPhysicalDeviceAvailabilityReportPreviewStatus() -> String {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-preview-locked-device-availability-report") else {
            return defaultDeviceAvailabilityReportPreviewStatus
        }
        let report = BracketerHostDeviceAvailabilityReport.parse(
            """
            xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=00008150-00027C3E0108401C
            Run Destination Preflight: The destination is not ready.
            Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock Physical iPhone to Continue"
            NSLocalizedRecoverySuggestion=Xcode cannot launch BracketerTests on Physical iPhone because the device is locked.
            """
        )
        return [
            "Previewed ui-testing-locked-xcodebuild-preflight.txt",
            report.accessibilityValue,
            "Import preview does not mutate runbooks or result-bundle indexes",
            "No physical proof count changed"
        ].joined(separator: " | ")
    }

    private var captureMatrix: BracketerPhysicalCaptureMatrix {
        BracketerPhysicalCaptureMatrix.make()
    }

    private var physicalDeviceLabPreflight: BracketerPhysicalDeviceLabPreflight {
        BracketerPhysicalDeviceLabPreflight.make(catalog: captureRunbookCatalog)
    }

    private var verificationRunbook: BracketerVerificationRunbook {
        BracketerVerificationRunbook.make()
    }

    private var captureRunbookCatalog: BracketerPhysicalCaptureRunbookCatalog {
        BracketerPhysicalCaptureRunbookCatalog.make()
    }

    private var resultBundleIndex: BracketerPhysicalResultBundleIndex {
        BracketerPhysicalResultBundleIndex.make(runbooks: captureRunbookCatalog.runbooks)
    }

    private var proofIngestReadiness: BracketerPhysicalProofIngestReadiness {
        BracketerPhysicalProofIngestReadiness.make(
            catalog: captureRunbookCatalog,
            resultBundleIndex: resultBundleIndex
        )
    }

    private var nextPhysicalRunbook: BracketerPhysicalCaptureRunbook? {
        captureRunbookCatalog.runbooks.first(where: { $0.recordedProofs.isEmpty })
            ?? captureRunbookCatalog.runbooks.first
    }

    private var resultBundleCommandPlanDocument: BracketerPhysicalResultBundleCommandPlanDocument? {
        guard let runbook = nextPhysicalRunbook else { return nil }
        return try? BracketerPhysicalResultBundleCommandPlanDocument(runbook: runbook)
    }

    private var proofSubmissionTemplateDocument: BracketerPhysicalProofSubmissionDocument? {
        guard let runbook = nextPhysicalRunbook else { return nil }
        return try? BracketerPhysicalProofSubmissionDocument(templateFor: runbook)
    }

    private var labWorkspaceDocument: BracketerPhysicalLabWorkspaceDocument? {
        guard let runbook = nextPhysicalRunbook else { return nil }
        return try? BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            compactXCResultSummaryJSON: Self.labWorkspacePreviewCompactSummaryJSON,
            attachmentByteCount: 1
        )
    }

    private var labReviewHandoffPackage: BracketerPhysicalLabReviewHandoffPackage? {
        guard let labWorkspaceDocument else { return nil }
        return BracketerPhysicalLabReviewHandoffPackage(workspaceDocument: labWorkspaceDocument)
    }

    private static let labWorkspacePreviewCompactSummaryJSON = Data("""
    {
      "devicesAndConfigurations" : [
        {
          "device" : {
            "deviceName" : "Physical iPhone",
            "modelName" : "iPhone 17",
            "osBuildNumber" : "23E254a",
            "osVersion" : "26.4.1",
            "platform" : "iOS"
          },
          "testPlanConfiguration" : {
            "configurationName" : "Test Scheme Action"
          }
        }
      ],
      "environmentDescription" : "Bracketer Settings physical lab workspace preview",
      "expectedFailures" : 0,
      "failedTests" : 0,
      "finishTime" : 1779960720.0,
      "passedTests" : 168,
      "result" : "Passed",
      "skippedTests" : 0,
      "startTime" : 1779960660.0,
      "title" : "Test - Bracketer",
      "totalTestCount" : 168
    }
    """.utf8)

    var body: some View {
        ModernSettingsCard(
            title: "Device Proof",
            subtitle: "\(checklist.physicalProofCount)/\(checklist.requiredPhysicalProofCount) physical",
            icon: "iphone"
        ) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text(checklist.accessibilityValue)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.summary")
                    .accessibilityValue(checklist.accessibilityValue)

                ForEach(checklist.items) { item in
                    ModernPhysicalDeviceProofChecklistRow(item: item)
                }

                Text(checklist.deviceMatrixAccessibilityValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.matrix")
                    .accessibilityValue(checklist.deviceMatrixAccessibilityValue)

                Text(captureMatrix.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.captureMatrix")
                    .accessibilityValue(captureMatrix.accessibilityValue)

                Text(physicalDeviceLabPreflight.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.deviceLabPreflight")
                    .accessibilityValue(physicalDeviceLabPreflight.accessibilityValue)

                ModernPhysicalDeviceAvailabilityReportImportPreviewRow(
                    status: physicalDeviceAvailabilityReportPreviewStatus,
                    action: { isImportingPhysicalDeviceAvailabilityReport = true }
                )

                Text(verificationRunbook.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.verificationRunbook")
                    .accessibilityValue(verificationRunbook.accessibilityValue)

                Text(verificationRunbook.benchmarkSummaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.benchmarkCommands")
                    .accessibilityValue(verificationRunbook.benchmarkAccessibilityValue)

                Text(captureRunbookCatalog.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.captureRunbooks")
                    .accessibilityValue(captureRunbookCatalog.accessibilityValue)

                Text(resultBundleIndex.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.resultBundleIndex")
                    .accessibilityValue(resultBundleIndex.accessibilityValue)

                Text(proofIngestReadiness.summaryValue)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.deviceProof.proofIngestor")
                    .accessibilityValue(proofIngestReadiness.accessibilityValue)

                if let resultBundleCommandPlanDocument {
                    ModernPhysicalResultBundleCommandPlanExportRow(document: resultBundleCommandPlanDocument)
                }

                if let proofSubmissionTemplateDocument {
                    ModernPhysicalProofSubmissionTemplateExportRow(document: proofSubmissionTemplateDocument)
                }

                if let labWorkspaceDocument {
                    ModernPhysicalLabWorkspaceExportRow(document: labWorkspaceDocument)
                }

                if let labReviewHandoffPackage {
                    ModernPhysicalLabReviewHandoffPackageExportRow(package: labReviewHandoffPackage)
                }

                ModernPhysicalLabReviewHandoffPackageImportPreviewRow(
                    status: labReviewHandoffPackagePreviewStatus,
                    action: { isImportingPhysicalLabReviewHandoffPackage = true }
                )

                ModernPhysicalLabWorkspaceImportPreviewRow(
                    status: labWorkspacePreviewStatus,
                    action: { isImportingPhysicalLabWorkspace = true }
                )

                ModernPhysicalProofSubmissionImportPreviewRow(
                    status: proofSubmissionPreviewStatus,
                    action: { isImportingPhysicalProofSubmission = true }
                )
            }
        }
        .fileImporter(
            isPresented: $isImportingPhysicalProofSubmission,
            allowedContentTypes: BracketerPhysicalProofSubmissionDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            previewPhysicalProofSubmission(from: result)
        }
        .fileImporter(
            isPresented: $isImportingPhysicalLabWorkspace,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            previewPhysicalLabWorkspace(from: result)
        }
        .fileImporter(
            isPresented: $isImportingPhysicalLabReviewHandoffPackage,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "txt") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            previewPhysicalLabReviewHandoffPackage(from: result)
        }
        .fileImporter(
            isPresented: $isImportingPhysicalDeviceAvailabilityReport,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "txt") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            previewPhysicalDeviceAvailabilityReport(from: result)
        }
    }

    private func previewPhysicalDeviceAvailabilityReport(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                physicalDeviceAvailabilityReportPreviewStatus = "No host device availability report selected | host-device-availability preview only | No physical proof count changed"
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            let report = BracketerHostDeviceAvailabilityReport.parse(text)
            physicalDeviceAvailabilityReportPreviewStatus = [
                "Previewed \(url.lastPathComponent)",
                report.accessibilityValue,
                "Import preview does not mutate runbooks or result-bundle indexes",
                "No physical proof count changed"
            ].joined(separator: " | ")
        } catch {
            physicalDeviceAvailabilityReportPreviewStatus = "Host device availability report preview failed | host-device-availability preview only | \(error.localizedDescription)"
        }
    }

    private func previewPhysicalProofSubmission(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                proofSubmissionPreviewStatus = "No physical proof submission selected | physical-device-proof preview only"
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let previewFile = try BracketerPhysicalProofPreviewFileProvider().previewData(
                Data(contentsOf: url),
                filename: url.lastPathComponent,
                catalog: captureRunbookCatalog,
                resultBundleIndex: resultBundleIndex
            )
            proofSubmissionPreviewStatus = [
                "Previewed \(url.lastPathComponent)",
                previewFile.accessibilityValue,
                proofIngestReadiness.summaryValue,
                "Preview does not change physical proof counts"
            ].joined(separator: " | ")
        } catch {
            proofSubmissionPreviewStatus = "Physical proof submission preview failed | physical-device-proof preview only | \(error.localizedDescription)"
        }
    }

    private func previewPhysicalLabWorkspace(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                labWorkspacePreviewStatus = "No physical lab workspace selected | physical-lab-workspace preview only"
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let preview = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
                Data(contentsOf: url),
                filename: url.lastPathComponent,
                catalog: captureRunbookCatalog
            )
            labWorkspacePreviewStatus = [
                "Previewed \(url.lastPathComponent)",
                preview.accessibilityValue,
                "Preview does not change physical proof counts"
            ].joined(separator: " | ")
        } catch {
            let errorDescription = (error as? BracketerPhysicalLabWorkspaceReviewError)?.description
                ?? error.localizedDescription
            labWorkspacePreviewStatus = "Physical lab workspace preview failed | physical-lab-workspace preview only | \(errorDescription)"
        }
    }

    private func previewPhysicalLabReviewHandoffPackage(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                labReviewHandoffPackagePreviewStatus = "No physical lab handoff package selected | physical-lab-review-handoff preview only"
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let preview = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
                Data(contentsOf: url),
                filename: url.lastPathComponent,
                catalog: captureRunbookCatalog
            )
            labReviewHandoffPackagePreviewStatus = [
                "Previewed \(url.lastPathComponent)",
                preview.accessibilityValue,
                "Preview does not change physical proof counts"
            ].joined(separator: " | ")
        } catch {
            let errorDescription = (error as? BracketerPhysicalLabReviewHandoffPackageReviewError)?.description
                ?? (error as? BracketerPhysicalLabWorkspaceReviewError)?.description
                ?? error.localizedDescription
            labReviewHandoffPackagePreviewStatus = "Physical lab handoff package preview failed | physical-lab-review-handoff preview only | \(errorDescription)"
        }
    }
}

private struct ModernPhysicalResultBundleCommandPlanExportRow: View {
    let document: BracketerPhysicalResultBundleCommandPlanDocument

    var body: some View {
        ShareLink(item: document.documentText) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "terminal")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Command Plan")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text("Result-bundle digest and xcresulttool commands")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(document.filename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text("Copy/share only")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.commandPlan")
        .accessibilityValue([
            document.accessibilityValue,
            document.documentText
        ].joined(separator: " | "))
    }
}

private struct ModernPhysicalLabWorkspaceExportRow: View {
    let document: BracketerPhysicalLabWorkspaceDocument

    var body: some View {
        ShareLink(item: document.documentText) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Lab Workspace")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text("Runbook, command plan, seeded template")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(document.filename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text("Copy/share only")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.labWorkspace")
        .accessibilityValue([
            document.accessibilityValue,
            document.documentText
        ].joined(separator: " | "))
    }
}

private struct ModernPhysicalLabReviewHandoffPackageExportRow: View {
    let package: BracketerPhysicalLabReviewHandoffPackage

    var body: some View {
        ShareLink(item: package.documentText) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "shippingbox")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Lab Handoff")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text("Manifest, workspace, checklist")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(package.filename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text("Copy/share only")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.labReviewHandoffPackage")
        .accessibilityValue([
            package.accessibilityValue,
            "Payload filenames: \(package.filenames.joined(separator: ", "))"
        ].joined(separator: " | "))
    }
}

private struct ModernPhysicalProofSubmissionTemplateExportRow: View {
    let document: BracketerPhysicalProofSubmissionDocument

    var body: some View {
        ShareLink(item: document.documentText) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.arrow.up")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Proof Template")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text("Physical Proof Submission Template")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(document.filename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text("Preview only")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.exportTemplate")
        .accessibilityValue([
            document.accessibilityValue,
            "Physical Proof Submission Template",
            "preview only",
            document.documentText
        ].joined(separator: " | "))
    }
}

private struct ModernPhysicalProofSubmissionImportPreviewRow: View {
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Proof Submission")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview Proof Submission")
        .accessibilityValue(status)
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.importPreview")
    }
}

private struct ModernPhysicalDeviceAvailabilityReportImportPreviewRow: View {
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Device Availability")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview Device Availability")
        .accessibilityValue(status)
        .accessibilityIdentifier("settings.deviceProof.deviceAvailabilityReportImportPreview")
    }
}

private struct ModernPhysicalLabWorkspaceImportPreviewRow: View {
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "checklist")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Lab Workspace")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview Lab Workspace")
        .accessibilityValue(status)
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.labWorkspaceImportPreview")
    }
}

private struct ModernPhysicalLabReviewHandoffPackageImportPreviewRow: View {
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Lab Handoff")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview Lab Handoff")
        .accessibilityValue(status)
        .accessibilityIdentifier("settings.deviceProof.proofIngestor.labReviewHandoffPackageImportPreview")
    }
}

private struct ModernPhysicalDeviceProofChecklistRow: View {
    let item: BracketerPhysicalDeviceProofChecklist.Item

    private var iconName: String {
        switch item.id {
        case "liveFoundationModelsOutput":
            return "sparkles"
        case "photosResourceFetch", "photosBackedThumbnails", "photosSideBySidePixels":
            return "photo.on.rectangle"
        case "finalRenderedOutputBytes", "imageBundleByteExport", "filesShortcutsRoundTrip":
            return "doc.badge.arrow.up"
        case "lensExifProRAW":
            return "camera.aperture"
        case "locationPermissionPolicy":
            return "location.slash"
        case "spotlightHandoffContinuation":
            return "magnifyingglass"
        default:
            return "checkmark.shield"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.professional)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                Text(item.status.title)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.warning)
                Text(item.requiredPhysicalEvidence)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.deviceProof.item.\(item.id)")
        .accessibilityValue(item.accessibilityValue)
    }
}

private struct ModernProjectLibrarySection: View {
    let snapshot: BracketProjectLibrarySnapshot
    let previewImportArchiveText: (String, BracketProjectImportConflictPolicy) throws -> BracketProjectImportPreview
    let importArchiveText: (String, BracketProjectImportConflictPolicy) throws -> BracketProjectImportBundle
    let updateProjectCuration: (String, Bool, [String], String?) throws -> BracketProject
    @State private var searchText = ""
    @State private var isImportingProjectBundle = false
    @State private var isExportingProjectBundle = false
    @State private var exportDocument: BracketProjectArchiveDocument?
    @State private var exportStatus = "No Files export attempted"
    @State private var importStatus = "No project import attempted"
    @State private var didSeedFinalOutputReadinessAuditImportPreview = false
    @State private var importConflictPolicy: BracketProjectImportConflictPolicy = .keepBoth
    @State private var exportPreset: BracketProjectExportPreset = .clientHandoff
    @State private var exportPrivacyLevel: BracketProjectExportPrivacyLevel = .metadataOnly
    @State private var exportFilenameTemplate: BracketProjectExportFilenameTemplate = .datedSummary
    @State private var exportGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy = BracketProjectExportPreset.clientHandoff.generatedContentPolicy
    @State private var selectedSmartCollectionKind: BracketProjectSmartCollection.Kind?
    @State private var selectedFacetFilter: BracketProjectLibraryFacetFilter?
    @State private var selectedCapturedDay: String?
    @State private var selectedLensID: String?
    @State private var selectedLocationPolicyID: String?
    @State private var isShowingSearchRoute = false
    @State private var isShowingLibraryWorkspace = false

    private var searchSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText
        )
    }

    private var filteredSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText,
            smartCollectionKind: selectedSmartCollectionKind,
            facetFilter: selectedFacetFilter,
            capturedDay: selectedCapturedDay,
            lensID: selectedLensID,
            locationPolicyID: selectedLocationPolicyID
        )
    }

    private var facetBaseSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText,
            smartCollectionKind: selectedSmartCollectionKind
        )
    }

    private var dateBaseSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText,
            smartCollectionKind: selectedSmartCollectionKind,
            facetFilter: selectedFacetFilter
        )
    }

    private var lensBaseSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText,
            smartCollectionKind: selectedSmartCollectionKind,
            facetFilter: selectedFacetFilter,
            capturedDay: selectedCapturedDay
        )
    }

    private var locationBaseSnapshot: BracketProjectLibrarySnapshot {
        BracketProjectLibrarySnapshot.make(
            projects: snapshot.projects,
            currentProjectID: snapshot.currentProjectID,
            query: searchText,
            smartCollectionKind: selectedSmartCollectionKind,
            facetFilter: selectedFacetFilter,
            capturedDay: selectedCapturedDay,
            lensID: selectedLensID
        )
    }

    private var searchRoute: BracketProjectLibrarySearchRoute {
        BracketProjectLibrarySearchRoute(snapshot: filteredSnapshot)
    }

    private var libraryWorkspace: BracketProjectLibraryWorkspace {
        BracketProjectLibraryWorkspace(snapshot: filteredSnapshot)
    }

    private var latestExportBundle: BracketProjectExportBundle? {
        guard let latestProject = snapshot.latestProject else { return nil }
        return try? BracketProjectExportBundle.make(
            project: latestProject,
            privacyLevel: exportPrivacyLevel,
            filenameTemplate: exportFilenameTemplate,
            generatedContentPolicy: exportGeneratedContentPolicy
        )
    }

    private var finalOutputReadinessAuditImportPreviewSeedID: String {
        [
            snapshot.latestProject?.id ?? "none",
            snapshot.latestProject.map { String($0.updatedAt.timeIntervalSince1970) } ?? "0",
            String(snapshot.projects.count),
            exportPrivacyLevel.rawValue,
            exportFilenameTemplate.rawValue,
            exportGeneratedContentPolicy.rawValue,
            importConflictPolicy.rawValue
        ].joined(separator: "|")
    }

    var body: some View {
        ModernSettingsCard(
            title: "Project Library",
            subtitle: "\(filteredSnapshot.resultCount) saved",
            icon: "rectangle.stack"
        ) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text(filteredSnapshot.accessibilityValue)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.projects.summary")
                    .accessibilityValue(filteredSnapshot.accessibilityValue)

                ModernProjectSmartCollectionsRow(
                    collections: searchSnapshot.smartCollections,
                    selectedKind: selectedSmartCollectionKind,
                    selectCollection: { collection in
                        selectedSmartCollectionKind = selectedSmartCollectionKind == collection.kind ? nil : collection.kind
                    }
                )

                ModernProjectLibraryFacetFiltersRow(
                    facets: facetBaseSnapshot.facetFilters,
                    selectedFilter: selectedFacetFilter,
                    selectFilter: { facet in
                        selectedFacetFilter = selectedFacetFilter == facet.filter ? nil : facet.filter
                    }
                )

                ModernProjectLibraryDateFacetsRow(
                    dateFacets: dateBaseSnapshot.dateFacets,
                    selectedDay: selectedCapturedDay,
                    selectDay: { dateFacet in
                        selectedCapturedDay = selectedCapturedDay == dateFacet.day ? nil : dateFacet.day
                    }
                )

                ModernProjectLibraryLensFacetsRow(
                    lensFacets: lensBaseSnapshot.lensFacets,
                    selectedLensID: selectedLensID,
                    selectLens: { lensFacet in
                        selectedLensID = selectedLensID == lensFacet.id ? nil : lensFacet.id
                    }
                )

                ModernProjectLibraryLocationFacetsRow(
                    locationFacets: locationBaseSnapshot.locationFacets,
                    selectedLocationPolicyID: selectedLocationPolicyID,
                    selectLocation: { locationFacet in
                        selectedLocationPolicyID = selectedLocationPolicyID == locationFacet.id ? nil : locationFacet.id
                    }
                )

                ModernProjectLibrarySearchRouteRow(
                    route: searchRoute,
                    action: { isShowingSearchRoute = true }
                )

                ModernProjectLibraryWorkspaceButton(
                    workspace: libraryWorkspace,
                    action: { isShowingLibraryWorkspace = true }
                )

                ModernProjectExportPresetControl(
                    selectedPreset: exportPreset,
                    selectPreset: applyExportPreset
                )

                ModernProjectExportPrivacyControl(selection: $exportPrivacyLevel)

                ModernProjectExportFilenameTemplateControl(selection: $exportFilenameTemplate)

                ModernProjectExportGeneratedContentControl(selection: $exportGeneratedContentPolicy)

                if let latestExportBundle {
                    ModernProjectExportBundleRow(bundle: latestExportBundle)

                    ModernProjectDocumentExportRow(
                        bundle: latestExportBundle,
                        status: exportStatus,
                        action: {
                            prepareProjectDocumentExport(latestExportBundle)
                        }
                    )
                }

                ModernProjectImportConflictPolicyControl(selection: $importConflictPolicy)

                ModernProjectImportBundleRow(
                    status: importStatus,
                    conflictPolicy: importConflictPolicy,
                    action: { isImportingProjectBundle = true }
                )

                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    TextField("Search projects", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .accessibilityIdentifier("settings.projects.search")
                        .accessibilityValue(searchText.isEmpty ? "No search query" : searchText)
                        .onChange(of: searchText) { _, _ in
                            selectedSmartCollectionKind = nil
                            selectedFacetFilter = nil
                            selectedCapturedDay = nil
                            selectedLensID = nil
                            selectedLocationPolicyID = nil
                        }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
                )

                if let failure = snapshot.loadFailure {
                    Text(failure)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.projects.loadFailure")
                        .accessibilityValue(failure)
                } else if filteredSnapshot.projects.isEmpty {
                    Text(searchText.isEmpty ? "No bracket projects saved yet." : "No projects match this search.")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.projects.empty")
                        .accessibilityValue(searchText.isEmpty ? "No saved projects" : "No matching projects")
                } else {
                    ForEach(Array(filteredSnapshot.projects.prefix(4).enumerated()), id: \.element.id) { index, project in
                        ModernProjectLibraryRow(
                            index: index,
                            project: project,
                            isCurrent: project.id == snapshot.currentProjectID,
                            exportPrivacyLevel: exportPrivacyLevel,
                            exportFilenameTemplate: exportFilenameTemplate,
                            exportGeneratedContentPolicy: exportGeneratedContentPolicy,
                            updateCuration: updateProjectCuration
                        )
                    }

                    if filteredSnapshot.projects.count > 4 {
                        Text("\(filteredSnapshot.projects.count - 4) more matching projects")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .accessibilityIdentifier("settings.projects.more")
                    }
                }
            }
        }
        .task(id: finalOutputReadinessAuditImportPreviewSeedID) {
            seedFinalOutputReadinessAuditImportPreviewIfNeeded()
        }
        .onAppear {
            DispatchQueue.main.async {
                seedFinalOutputReadinessAuditImportPreviewIfNeeded()
            }
        }
        .fileImporter(
            isPresented: $isImportingProjectBundle,
            allowedContentTypes: BracketProjectArchiveDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            importProjectBundle(from: result)
        }
        .sheet(isPresented: $isShowingSearchRoute) {
            ModernProjectLibrarySearchRouteSheet(route: searchRoute)
        }
        .sheet(isPresented: $isShowingLibraryWorkspace) {
            ModernProjectLibraryWorkspaceSheet(
                workspace: libraryWorkspace,
                projects: filteredSnapshot.projects,
                exportPrivacyLevel: exportPrivacyLevel,
                exportFilenameTemplate: exportFilenameTemplate,
                exportGeneratedContentPolicy: exportGeneratedContentPolicy
            )
        }
        .fileExporter(
            isPresented: $isExportingProjectBundle,
            document: exportDocument,
            contentType: BracketProjectArchiveDocument.writableContentTypes[0],
            defaultFilename: exportDocument?.filename
        ) { result in
            completeProjectDocumentExport(result)
        }
    }

    private func seedFinalOutputReadinessAuditImportPreviewIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-preview-final-output-readiness-audit-import-failure"),
              !didSeedFinalOutputReadinessAuditImportPreview,
              let latestProject = snapshot.latestProject else {
            return
        }

        do {
            let bundle = try BracketProjectExportBundle.make(
                project: latestProject,
                privacyLevel: exportPrivacyLevel,
                filenameTemplate: exportFilenameTemplate,
                generatedContentPolicy: exportGeneratedContentPolicy
            )
            guard let mismatchedArchiveText = mismatchedFinalOutputReadinessAuditArchiveText(from: bundle) else {
                return
            }
            let status = finalOutputReadinessAuditPreviewStatus(for: mismatchedArchiveText)
            guard status.contains("Previewed ui-testing-final-output-readiness-audit-mismatch.txt") else {
                return
            }
            importStatus = status
            if status.contains("final-output-readiness-audit-mismatch") {
                didSeedFinalOutputReadinessAuditImportPreview = true
            }
        } catch {
            return
        }
    }

    private func mismatchedFinalOutputReadinessAuditArchiveText(
        from bundle: BracketProjectExportBundle
    ) -> String? {
        let pattern = #""blockerReasonCount"\s*:\s*\d+"#
        guard let range = bundle.archiveText.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return bundle.archiveText.replacingCharacters(
            in: range,
            with: #""blockerReasonCount" : -1"#
        )
    }

    private func finalOutputReadinessAuditPreviewStatus(for archiveText: String) -> String {
        do {
            _ = try previewImportArchiveText(archiveText, importConflictPolicy)
            return "UI testing final-output readiness audit mismatch fixture unexpectedly passed"
        } catch {
            let failure = BracketProjectImportPreviewFailure.make(
                error: error,
                conflictPolicy: importConflictPolicy
            )
            return [
                "Previewed ui-testing-final-output-readiness-audit-mismatch.txt",
                failure.failureKind,
                "Recovery: Re-export final-output readiness audit",
                failure.mutationSummary,
                "Duplicate policy: \(importConflictPolicy.displayName)",
                failure.recoverySuggestion,
                failure.accessibilityValue
            ].joined(separator: " | ")
        }
    }

    private func importProjectBundle(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                importStatus = "No import file selected"
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let document = try BracketProjectArchiveDocument(
                data: Data(contentsOf: url),
                filename: url.lastPathComponent
            )
            let importPreview = try previewImportArchiveText(document.archiveText, importConflictPolicy)
            let importBundle = try importArchiveText(document.archiveText, importConflictPolicy)
            importStatus = [
                "Document \(document.filename)",
                "Preview \(importPreview.actionSummary)",
                importPreview.finalOutputActionPlanSummary.map { "Final output action plan: \($0)" },
                "Imported \(importBundle.project.displayTitle)",
                "Duplicate policy: \(importConflictPolicy.displayName)",
                importBundle.conflictResolution,
                importBundle.project.privacy.accessibilityValue
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        } catch {
            let failure = BracketProjectImportPreviewFailure.make(
                error: error,
                conflictPolicy: importConflictPolicy
            )
            importStatus = failure.accessibilityValue
        }
    }

    private func prepareProjectDocumentExport(_ bundle: BracketProjectExportBundle) {
        do {
            exportDocument = try BracketProjectArchiveDocument(bundle: bundle)
            exportStatus = [
                "Ready to save \(bundle.archiveFilename) to Files",
                bundle.finalOutputActionPlanSummary.map { "Final output action plan: \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
            isExportingProjectBundle = true
        } catch {
            exportStatus = "Files export failed | \(error.localizedDescription)"
        }
    }

    private func completeProjectDocumentExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportStatus = [
                "Exported to Files",
                url.lastPathComponent,
                exportDocument?.accessibilityValue
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        case .failure(let error):
            exportStatus = "Files export failed | \(error.localizedDescription)"
        }
    }

    private func applyExportPreset(_ preset: BracketProjectExportPreset) {
        exportPreset = preset
        exportPrivacyLevel = preset.privacyLevel
        exportFilenameTemplate = preset.filenameTemplate
        exportGeneratedContentPolicy = preset.generatedContentPolicy
    }
}

private struct ModernProjectLibrarySearchRouteRow: View {
    let route: BracketProjectLibrarySearchRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.professional)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Search Route")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(route.dialogText)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Project Search Route")
        .accessibilityValue(route.accessibilityValue)
        .accessibilityIdentifier("settings.projects.library.searchRoute")
    }
}

private struct ModernProjectLibrarySearchRouteSheet: View {
    let route: BracketProjectLibrarySearchRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    Text(route.accessibilityValue)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(route.resultTitles.prefix(8).enumerated()), id: \.offset) { index, title in
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Text("\(index + 1)")
                                .font(ModernDesignSystem.Typography.monospaceSmall)
                                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                                .frame(width: 28, alignment: .leading)

                            Text(title)
                                .font(ModernDesignSystem.Typography.bodyBold)
                                .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                                .lineLimit(2)
                        }
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.projects.library.searchRoute.result.\(index)")
                        .accessibilityValue(title)
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.cameraBackground.ignoresSafeArea())
            .navigationTitle("Project Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.projects.library.searchRoute.close")
                }
            }
        }
        .accessibilityIdentifier("settings.projects.library.searchRoute.sheet")
        .accessibilityValue(route.accessibilityValue)
    }
}

private struct ModernProjectLibraryWorkspaceButton: View {
    let workspace: BracketProjectLibraryWorkspace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "rectangle.stack.badge.person.crop")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.professional)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Archive Workspace")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text("\(workspace.resultCount) projects with route, privacy, previews, and export actions")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "sidebar.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Project Archive Workspace")
        .accessibilityValue(workspace.accessibilityValue)
        .accessibilityIdentifier("settings.projects.library.workspaceButton")
    }
}

private struct ModernProjectLibraryWorkspaceSheet: View {
    let workspace: BracketProjectLibraryWorkspace
    let projects: [BracketProject]
    let exportPrivacyLevel: BracketProjectExportPrivacyLevel
    let exportFilenameTemplate: BracketProjectExportFilenameTemplate
    let exportGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy
    @Environment(\.dismiss) private var dismiss

    private var visibleProjects: [(offset: Int, project: BracketProject, summary: BracketProjectLibraryWorkspace.ProjectSummary)] {
        Array(zip(projects, workspace.projectSummaries).enumerated()).map {
            (offset: $0.offset, project: $0.element.0, summary: $0.element.1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project Archive Workspace")
                            .font(ModernDesignSystem.Typography.title)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        Text(workspace.route.dialogText)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(workspace.privacyBoundary)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.projects.library.workspace.summary")
                    .accessibilityValue(workspace.accessibilityValue)

                    if visibleProjects.isEmpty {
                        Text("No projects match this archive route.")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .accessibilityIdentifier("settings.projects.library.workspace.empty")
                    } else {
                        ForEach(visibleProjects, id: \.project.id) { item in
                            ModernProjectLibraryWorkspaceProjectRow(
                                index: item.offset,
                                project: item.project,
                                summary: item.summary,
                                exportPrivacyLevel: exportPrivacyLevel,
                                exportFilenameTemplate: exportFilenameTemplate,
                                exportGeneratedContentPolicy: exportGeneratedContentPolicy
                            )
                        }
                    }

                    if workspace.hasTruncatedResults {
                        Text("Showing \(workspace.visibleCount) of \(workspace.resultCount) matching projects.")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .accessibilityIdentifier("settings.projects.library.workspace.truncated")
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.cameraBackground.ignoresSafeArea())
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.projects.library.workspace.close")
                }
            }
        }
        .accessibilityIdentifier("settings.projects.library.workspace")
        .accessibilityValue(workspace.accessibilityValue)
    }
}

private struct ModernProjectLibraryWorkspaceProjectRow: View {
    let index: Int
    let project: BracketProject
    let summary: BracketProjectLibraryWorkspace.ProjectSummary
    let exportPrivacyLevel: BracketProjectExportPrivacyLevel
    let exportFilenameTemplate: BracketProjectExportFilenameTemplate
    let exportGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy

    private var bundle: BracketProjectExportBundle? {
        try? BracketProjectExportBundle.make(
            project: project,
            privacyLevel: exportPrivacyLevel,
            filenameTemplate: exportFilenameTemplate,
            generatedContentPolicy: exportGeneratedContentPolicy
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: summary.isCurrent ? "checkmark.seal.fill" : "rectangle.stack")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(summary.isCurrent ? .green : ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.title)
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(summary.subtitle)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summary.exportSummary)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Final output action plan: \(summary.finalOutputActionPlanSummary)")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if summary.isLatest {
                    Text("Latest")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(.green)
                }
            }

            Text(summary.previewSummary)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let bundle {
                ShareLink(item: bundle.archiveText) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export")
                            .font(ModernDesignSystem.Typography.caption)
                        Spacer(minLength: 8)
                        Text(bundle.generatedContentPolicy.displayName)
                            .font(ModernDesignSystem.Typography.caption2)
                    }
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                }
                .accessibilityIdentifier("settings.projects.library.workspace.result.\(index).exportBundle.shareButton")
                .accessibilityValue([summary.accessibilityValue, bundle.accessibilityValue, bundle.archiveText].joined(separator: " | "))
            }
        }
        .padding(.vertical, ModernDesignSystem.Spacing.md)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.projects.library.workspace.result.\(index)")
        .accessibilityValue(summary.accessibilityValue)
    }
}

private struct ModernProjectLibraryFacetFiltersRow: View {
    let facets: [BracketProjectLibraryFacet]
    let selectedFilter: BracketProjectLibraryFacetFilter?
    let selectFilter: (BracketProjectLibraryFacet) -> Void

    var body: some View {
        if !facets.isEmpty {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "camera.filters")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    Text("Library Facets")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                    Spacer(minLength: 8)

                    Text(selectedFilter?.title ?? "\(facets.count)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(facets) { facet in
                            Button {
                                selectFilter(facet)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: facet.filter.iconName)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(facet.title)
                                        .font(ModernDesignSystem.Typography.caption2)
                                    Text("\(facet.count)")
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(isSelected(facet) ? .black : ModernDesignSystem.Colors.cameraControl)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected(facet) ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(facet.title)
                            .accessibilityValue(facet.accessibilityValue)
                            .accessibilityIdentifier("settings.projects.facetFilters.\(facet.filter.rawValue)")
                        }
                    }
                }
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.projects.facetFilters")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var accessibilityValue: String {
        let selectedValue = selectedFilter.map { "Selected \($0.title)" } ?? "No facet selected"
        let facetValue = facets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return ["Selectable Facets", selectedValue, facetValue].joined(separator: " | ")
    }

    private func isSelected(_ facet: BracketProjectLibraryFacet) -> Bool {
        selectedFilter == facet.filter
    }
}

private struct ModernProjectLibraryDateFacetsRow: View {
    let dateFacets: [BracketProjectLibraryDateFacet]
    let selectedDay: String?
    let selectDay: (BracketProjectLibraryDateFacet) -> Void

    var body: some View {
        if !dateFacets.isEmpty {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    Text("Captured Dates")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                    Spacer(minLength: 8)

                    Text(selectedDay ?? "\(dateFacets.count)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(dateFacets) { dateFacet in
                            Button {
                                selectDay(dateFacet)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(dateFacet.day)
                                        .font(ModernDesignSystem.Typography.caption2)
                                    Text("\(dateFacet.count)")
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(isSelected(dateFacet) ? .black : ModernDesignSystem.Colors.cameraControl)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected(dateFacet) ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dateFacet.title)
                            .accessibilityValue(dateFacet.accessibilityValue)
                            .accessibilityIdentifier("settings.projects.dateFacets.\(dateFacet.day)")
                        }
                    }
                }
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.projects.dateFacets")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var accessibilityValue: String {
        let selectedValue = selectedDay.map { "Selected captured day \($0)" } ?? "No captured day selected"
        let dateValue = dateFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return ["Captured Date Facets", selectedValue, dateValue].joined(separator: " | ")
    }

    private func isSelected(_ dateFacet: BracketProjectLibraryDateFacet) -> Bool {
        selectedDay == dateFacet.day
    }
}

private struct ModernProjectLibraryLensFacetsRow: View {
    let lensFacets: [BracketProjectLibraryLensFacet]
    let selectedLensID: String?
    let selectLens: (BracketProjectLibraryLensFacet) -> Void

    var body: some View {
        if !lensFacets.isEmpty {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "camera.aperture")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    Text("Captured Lenses")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                    Spacer(minLength: 8)

                    Text(selectedLensTitle ?? "\(lensFacets.count)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(lensFacets) { lensFacet in
                            Button {
                                selectLens(lensFacet)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "camera.metering.center.weighted")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(lensFacet.title)
                                        .font(ModernDesignSystem.Typography.caption2)
                                    Text("\(lensFacet.count)")
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(isSelected(lensFacet) ? .black : ModernDesignSystem.Colors.cameraControl)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected(lensFacet) ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(lensFacet.title)
                            .accessibilityValue(lensFacet.accessibilityValue)
                            .accessibilityIdentifier("settings.projects.lensFacets.\(lensFacet.id)")
                        }
                    }
                }
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.projects.lensFacets")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var selectedLensTitle: String? {
        guard let selectedLensID else { return nil }
        return lensFacets.first { $0.id == selectedLensID }?.title
    }

    private var accessibilityValue: String {
        let selectedValue = selectedLensTitle.map { "Selected lens \($0)" } ?? "No lens selected"
        let lensValue = lensFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return ["Lens Facets", selectedValue, lensValue].joined(separator: " | ")
    }

    private func isSelected(_ lensFacet: BracketProjectLibraryLensFacet) -> Bool {
        selectedLensID == lensFacet.id
    }
}

private struct ModernProjectLibraryLocationFacetsRow: View {
    let locationFacets: [BracketProjectLibraryLocationFacet]
    let selectedLocationPolicyID: String?
    let selectLocation: (BracketProjectLibraryLocationFacet) -> Void

    var body: some View {
        if !locationFacets.isEmpty {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    Text("Location Policies")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                    Spacer(minLength: 8)

                    Text(selectedLocationTitle ?? "\(locationFacets.count)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(locationFacets) { locationFacet in
                            Button {
                                selectLocation(locationFacet)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(locationFacet.title)
                                        .font(ModernDesignSystem.Typography.caption2)
                                    Text("\(locationFacet.count)")
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(isSelected(locationFacet) ? .black : ModernDesignSystem.Colors.cameraControl)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected(locationFacet) ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(locationFacet.title)
                            .accessibilityValue(locationFacet.accessibilityValue)
                            .accessibilityIdentifier("settings.projects.locationFacets.\(locationFacet.id)")
                        }
                    }
                }
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.projects.locationFacets")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var selectedLocationTitle: String? {
        guard let selectedLocationPolicyID else { return nil }
        return locationFacets.first { $0.id == selectedLocationPolicyID }?.title
    }

    private var accessibilityValue: String {
        let selectedValue = selectedLocationTitle.map { "Selected location policy \($0)" } ?? "No location policy selected"
        let locationValue = locationFacets
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return ["Location Policy Facets", selectedValue, locationValue].joined(separator: " | ")
    }

    private func isSelected(_ locationFacet: BracketProjectLibraryLocationFacet) -> Bool {
        selectedLocationPolicyID == locationFacet.id
    }
}

private struct ModernProjectSmartCollectionsRow: View {
    let collections: [BracketProjectSmartCollection]
    let selectedKind: BracketProjectSmartCollection.Kind?
    let selectCollection: (BracketProjectSmartCollection) -> Void

    var body: some View {
        if !collections.isEmpty {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "tray.full")
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 20)

                    Text("Smart Collections")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                    Spacer(minLength: 8)

                    Text(selectedKind?.title ?? "\(collections.count)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(collections) { collection in
                            Button {
                                selectCollection(collection)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: collection.kind.iconName)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(collection.title)
                                        .font(ModernDesignSystem.Typography.caption2)
                                    Text("\(collection.count)")
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(isSelected(collection) ? .black : ModernDesignSystem.Colors.cameraControl)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected(collection) ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(collection.title)
                            .accessibilityValue(collection.accessibilityValue)
                            .accessibilityIdentifier("settings.projects.smartCollections.\(collection.kind.rawValue)")
                        }
                    }
                }
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.projects.smartCollections")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var accessibilityValue: String {
        let selectedValue = selectedKind.map { "Selected \($0.title)" } ?? "No collection selected"
        let collectionValue = collections
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return ["Smart Collections", selectedValue, collectionValue].joined(separator: " | ")
    }

    private func isSelected(_ collection: BracketProjectSmartCollection) -> Bool {
        selectedKind == collection.kind
    }
}

private struct ModernProjectExportPresetControl: View {
    let selectedPreset: BracketProjectExportPreset
    let selectPreset: (BracketProjectExportPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Export Preset")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(selectedPreset.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(BracketProjectExportPreset.allCases, id: \.self) { preset in
                        Button {
                            selectPreset(preset)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(preset.displayName)
                                    .font(ModernDesignSystem.Typography.caption2)
                            }
                            .foregroundColor(preset == selectedPreset ? .black : ModernDesignSystem.Colors.cameraControl)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(preset == selectedPreset ? ModernDesignSystem.Colors.cameraControlActive : Color.white.opacity(0.07))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.displayName)
                        .accessibilityValue(preset.accessibilityValue)
                        .accessibilityIdentifier("settings.projects.exportPreset.\(preset.rawValue)")
                    }
                }
            }

            Text(selectedPreset.accessibilityValue)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.projects.exportPreset")
        .accessibilityValue(selectedPreset.accessibilityValue)
    }
}

private struct ModernProjectExportPrivacyControl: View {
    @Binding var selection: BracketProjectExportPrivacyLevel

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lock.doc")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Export Privacy")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(selection.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }

            Picker("Export Privacy", selection: $selection) {
                ForEach(BracketProjectExportPrivacyLevel.allCases, id: \.self) { privacyLevel in
                    Text(privacyLevel.displayName).tag(privacyLevel)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.projects.exportPrivacyLevel")
            .accessibilityValue(selection.accessibilityValue)

            Text(selection.policyDescription)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
    }
}

private struct ModernProjectExportGeneratedContentControl: View {
    @Binding var selection: BracketProjectExportGeneratedContentPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Generated Content")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(selection.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }

            Picker("Generated Content", selection: $selection) {
                ForEach(BracketProjectExportGeneratedContentPolicy.allCases, id: \.self) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.projects.exportGeneratedContent")
            .accessibilityValue(selection.accessibilityValue)

            Text(selection.policyDescription)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
    }
}

private struct ModernProjectExportFilenameTemplateControl: View {
    @Binding var selection: BracketProjectExportFilenameTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Export Filename")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(selection.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }

            Picker("Export Filename", selection: $selection) {
                ForEach(BracketProjectExportFilenameTemplate.allCases, id: \.self) { template in
                    Text(template.displayName).tag(template)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.projects.exportFilenameTemplate")
            .accessibilityValue(selection.accessibilityValue)

            Text(selection.description)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
    }
}

private struct ModernProjectImportConflictPolicyControl: View {
    @Binding var selection: BracketProjectImportConflictPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Duplicate Imports")
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(selection.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }

            Picker("Duplicate Imports", selection: $selection) {
                ForEach(BracketProjectImportConflictPolicy.allCases, id: \.self) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.projects.importConflictPolicy")
            .accessibilityValue(selection.accessibilityValue)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
    }
}

private struct ModernProjectExportBundleRow: View {
    let bundle: BracketProjectExportBundle

    var body: some View {
        ShareLink(item: bundle.archiveText) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Project Bundle")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(bundle.summary)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(bundle.archiveFilename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text(bundle.privacyLevel.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.projects.exportBundle.shareButton")
        .accessibilityValue([bundle.accessibilityValue, bundle.archiveText].joined(separator: " | "))
    }
}

private struct ModernProjectDocumentExportRow: View {
    let bundle: BracketProjectExportBundle
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Save Project Archive")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                    Text(bundle.archiveFilename)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text("Files")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save Project Archive")
        .accessibilityValue([status, bundle.accessibilityValue].joined(separator: " | "))
        .accessibilityIdentifier("settings.projects.exportBundle.fileButton")
    }
}

private struct ModernProjectImportBundleRow: View {
    let status: String
    let conflictPolicy: BracketProjectImportConflictPolicy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Import Project Bundle")
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(status)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import Project Bundle")
        .accessibilityValue("\(status) | Duplicate policy: \(conflictPolicy.displayName)")
        .accessibilityIdentifier("settings.projects.importBundle.button")
    }
}

private struct ModernProjectLibraryRow: View {
    let index: Int
    let project: BracketProject
    let isCurrent: Bool
    let exportPrivacyLevel: BracketProjectExportPrivacyLevel
    let exportFilenameTemplate: BracketProjectExportFilenameTemplate
    let exportGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy
    let updateCuration: (String, Bool, [String], String?) throws -> BracketProject
    @State private var isFavorite: Bool
    @State private var tagsText: String
    @State private var noteText: String
    @State private var curationStatus = "No curation changes saved"

    init(
        index: Int,
        project: BracketProject,
        isCurrent: Bool,
        exportPrivacyLevel: BracketProjectExportPrivacyLevel,
        exportFilenameTemplate: BracketProjectExportFilenameTemplate,
        exportGeneratedContentPolicy: BracketProjectExportGeneratedContentPolicy,
        updateCuration: @escaping (String, Bool, [String], String?) throws -> BracketProject
    ) {
        self.index = index
        self.project = project
        self.isCurrent = isCurrent
        self.exportPrivacyLevel = exportPrivacyLevel
        self.exportFilenameTemplate = exportFilenameTemplate
        self.exportGeneratedContentPolicy = exportGeneratedContentPolicy
        self.updateCuration = updateCuration
        _isFavorite = State(initialValue: project.isFavorite)
        _tagsText = State(initialValue: project.acceptedTags.joined(separator: ", "))
        _noteText = State(initialValue: project.userNote ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: project.lifecycle == .reviewable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(project.lifecycle == .reviewable ? .green : .orange)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayTitle)
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .lineLimit(2)
                    Text(project.displaySubtitle)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                Button {
                    saveCuration(isFavorite: !isFavorite)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isFavorite ? .yellow : ModernDesignSystem.Colors.cameraControlSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove Favorite Project" : "Favorite Project")
                .accessibilityValue(isFavorite ? "Favorite" : "Not favorite")
                .accessibilityIdentifier("settings.projects.favorite.\(index)")

                if isCurrent {
                    Text("Current")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(.green)
                }
            }

            ModernProjectPreviewStrip(
                index: index,
                placeholders: project.previewPlaceholders
            )

            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                TextField("Tags", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .accessibilityIdentifier("settings.projects.tags.\(index)")
                    .accessibilityValue(tagsText.isEmpty ? "No tags" : tagsText)

                Button {
                    saveCuration(isFavorite: isFavorite)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save Project Curation")
                .accessibilityValue(curationStatus)
                .accessibilityIdentifier("settings.projects.saveCuration.\(index)")
            }

            TextField("Note", text: $noteText)
                .textInputAutocapitalization(.sentences)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .accessibilityIdentifier("settings.projects.note.\(index)")
                .accessibilityValue(noteText.isEmpty ? "No note" : noteText)

            Text(curationStatus)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .lineLimit(2)
                .accessibilityIdentifier("settings.projects.curationStatus.\(index)")
                .accessibilityValue(curationStatus)

            if let projectExportBundle {
                ModernProjectInlineExportBundleButton(
                    index: index,
                    bundle: projectExportBundle
                )
            }

            Text(project.id)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.projects.result.\(index)")
        .accessibilityValue(project.projectLibraryAccessibilityValue)
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var projectExportBundle: BracketProjectExportBundle? {
        try? BracketProjectExportBundle.make(
            project: project,
            privacyLevel: exportPrivacyLevel,
            filenameTemplate: exportFilenameTemplate,
            generatedContentPolicy: exportGeneratedContentPolicy
        )
    }

    private func saveCuration(isFavorite nextFavoriteState: Bool) {
        do {
            let updatedProject = try updateCuration(
                project.id,
                nextFavoriteState,
                parsedTags,
                noteText
            )
            isFavorite = updatedProject.isFavorite
            tagsText = updatedProject.acceptedTags.joined(separator: ", ")
            noteText = updatedProject.userNote ?? ""
            curationStatus = [
                "Saved",
                updatedProject.curationState.accessibilityValue,
                updatedProject.acceptedTags.isEmpty ? "No tags" : "Tags \(updatedProject.acceptedTags.joined(separator: ", "))",
                updatedProject.userNote == nil ? "No note" : "Note saved"
            ].joined(separator: " | ")
        } catch {
            curationStatus = "Save failed | \(error.localizedDescription)"
        }
    }
}

private struct ModernProjectPreviewStrip: View {
    let index: Int
    let placeholders: [BracketProject.PreviewPlaceholder]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(placeholders.prefix(7)) { placeholder in
                    VStack(spacing: 3) {
                        Image(systemName: placeholder.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color(for: placeholder))
                            .frame(height: 14)

                        Text(compactLabel(placeholder.displayLabel))
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(placeholder.shortStatus)
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(color(for: placeholder).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(color(for: placeholder).opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Project Preview Placeholders")
        .accessibilityValue(previewAccessibilityValue)
        .accessibilityIdentifier("settings.projects.result.\(index).previewStrip")
    }

    private var previewAccessibilityValue: String {
        let values = placeholders
            .map(\.accessibilityValue)
            .joined(separator: " ; ")
        return "Preview placeholders | \(values)"
    }

    private func color(for placeholder: BracketProject.PreviewPlaceholder) -> Color {
        if placeholder.shortStatus == "Missing" {
            return .orange
        }
        if placeholder.shortStatus == "Failed" {
            return .red
        }
        if placeholder.isBestExposureCandidate {
            return ModernDesignSystem.Colors.cameraControlActive
        }
        return ModernDesignSystem.Colors.cameraControlSecondary
    }

    private func compactLabel(_ label: String) -> String {
        label.replacingOccurrences(of: ".0 EV", with: " EV")
    }
}

private struct ModernProjectInlineExportBundleButton: View {
    let index: Int
    let bundle: BracketProjectExportBundle

    var body: some View {
        ShareLink(item: bundle.archiveText) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Export This Project")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer(minLength: 8)

                Text(bundle.filenameTemplate.displayName)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .accessibilityIdentifier("settings.projects.result.\(index).exportBundle.shareButton")
        .accessibilityValue([bundle.accessibilityValue, bundle.archiveText].joined(separator: " | "))
    }
}
#if DEBUG
private struct ModernDiagnosticsExportRow: View {
    let report: String

    var body: some View {
        ShareLink(item: report) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text("Export Diagnostics")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer()

                Text("Debug")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .accessibilityIdentifier("settings.diagnostics.shareButton")
        .accessibilityValue(report)
    }
}
#endif

// MARK: - Modern Setting Row
struct ModernSettingRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)

                Spacer()

                Text(value)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
            }
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .subtle, tint: .white.opacity(0.08), interactive: true)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Components

enum SettingsCategory: String, CaseIterable, Identifiable {
    case viewfinder, focus, capture, intelligence, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewfinder: return "Viewfinder"
        case .focus: return "Focus"
        case .capture: return "Capture"
        case .intelligence: return "AI"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .viewfinder: return "Composition, grids, leveling"
        case .focus: return "Focus peaking and assistance"
        case .capture: return "Format, metadata & hardware"
        case .intelligence: return "Apple Intelligence availability"
        case .about: return "Build info and acknowledgements"
        }
    }
}

struct SettingsPresetButtonData: Identifiable {
    let id = UUID()
    let accessibilityID: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void
}

struct ModernQuickPresetCard: View {
    let presets: [SettingsPresetButtonData]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ModernSettingsCard(
            title: "Quick Presets",
            subtitle: "Apply common setups instantly",
            icon: "sparkles"
        ) {
            LazyVGrid(columns: columns, spacing: ModernDesignSystem.Spacing.md) {
                ForEach(presets) { preset in
                    ModernQuickPresetButton(preset: preset)
                }
            }
        }
    }
}

struct ModernQuickPresetButton: View {
    let preset: SettingsPresetButtonData

    var body: some View {
        Button {
            HapticManager.shared.panelToggled()
            preset.action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(preset.title)
                    .font(ModernDesignSystem.Typography.bodyBold)
                    .foregroundColor(.white)
                Text(preset.subtitle)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .liquidGlass(intensity: .prominent, tint: preset.tint.opacity(0.6), interactive: true)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.preset.\(preset.accessibilityID)")
        .accessibilityValue(preset.title)
    }
}

struct ModernSettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    private let content: Content

    init(title: String, subtitle: String? = nil, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlActive)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ModernDesignSystem.Typography.bodyBold)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    if let subtitle {
                        Text(subtitle)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    }
                }

                Spacer()
            }

            content
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCardStyle(.glass)
    }
}

struct ModernDropdownPicker<Option: Identifiable & Equatable>: View {
    let title: String
    let icon: String
    let options: [Option]
    @Binding var selection: Option
    let accessibilityID: String
    let labelProvider: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .tracking(0.5)

            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option
                        HapticManager.shared.gridTypeChanged()
                    } label: {
                        HStack {
                            Text(labelProvider(option))
                            Spacer()
                            if option == selection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                    Text(labelProvider(selection))
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                        .accessibilityIdentifier("settings.picker.\(accessibilityID).value")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .liquidGlass(intensity: .regular, tint: .white.opacity(0.08), interactive: true)
                )
            }
            .accessibilityIdentifier("settings.picker.\(accessibilityID)")
            .accessibilityValue(labelProvider(selection))
        }
    }
}

struct ModernToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let tint: Color
    let accessibilityID: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.cameraControl)
                if let subtitle {
                    Text(subtitle)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
                .accessibilityIdentifier("settings.toggle.\(accessibilityID)")
        }
    }
}

struct GridTypePreview: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let gridType: GridType

    private var effectiveAccessibilityReduceMotion: Bool {
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            gridOverlay()
                .padding(16)
        }
        .animation(
            ModernDesignSystem.Animations.motionAware(
                .spring(response: 0.35, dampingFraction: 0.8),
                reduceMotionEnabled: effectiveAccessibilityReduceMotion
            ),
            value: gridType
        )
    }

    @ViewBuilder
    private func gridOverlay() -> some View {
        switch gridType {
        case .ruleOfThirds:
            RuleOfThirdsGrid()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        case .goldenRatio:
            GoldenRatioGrid()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        case .goldenSpiral:
            GoldenSpiralGrid()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        case .centerCrosshair:
            CenterCrosshairGrid()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
    }
}

struct FocusPeakingColorPicker: View {
    @Binding var selectedColor: Color
    let colors: [Color]

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("PEAKING COLOR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                .tracking(0.5)
                .accessibilityIdentifier("settings.focusPeakingColor.title")
                .accessibilityValue(colorName(selectedColor))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        HapticManager.shared.panelToggled()
                    } label: {
                        Circle()
                            .liquidGlass(
                                intensity: selectedColor == color ? .prominent : .regular,
                                tint: color.opacity(selectedColor == color ? 0.6 : 0.3),
                                interactive: true
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(color, lineWidth: selectedColor == color ? 3 : 1)
                            )
                            .overlay(
                                Group {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.focusPeakingColor.\(colorName(color))")
                    .accessibilityLabel("\(colorName(color).capitalized) Peaking Color")
                    .accessibilityValue(selectedColor == color ? "Selected" : "Not selected")
                }
            }
        }
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "red"
        case .blue: return "blue"
        case .yellow: return "yellow"
        case .green: return "green"
        case .orange: return "orange"
        case .purple: return "purple"
        case .white: return "white"
        default: return "custom"
        }
    }
}

struct FocusPeakingIntensitySlider: View {
    @Binding var intensity: Float

    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Text("INTENSITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ModernDesignSystem.Colors.cameraControlSecondary)
                    .tracking(0.5)
                Spacer()
                Text("\(Int(intensity * 100))%")
                    .font(ModernDesignSystem.Typography.monospace)
                    .foregroundColor(ModernDesignSystem.Colors.success)
                    .accessibilityIdentifier("settings.focusPeakingIntensity.value")
            }

            Slider(
                value: Binding(
                    get: { Double(intensity) },
                    set: { intensity = Float($0) }
                ),
                in: 0.1...1.0,
                step: 0.05
            )
            .accentColor(ModernDesignSystem.Colors.success)
            .accessibilityIdentifier("settings.focusPeakingIntensity.slider")
            .accessibilityValue("\(Int(intensity * 100))%")
        }
    }
}

struct ModernSettingBadgeGrid: View {
    let badges: [ModernSettingBadgeData]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: ModernDesignSystem.Spacing.md) {
            ForEach(badges) { badge in
                ModernSettingBadge(badge: badge)
            }
        }
    }
}

struct ModernSettingBadgeData: Identifiable {
    let id = UUID()
    let accessibilityID: String
    let icon: String
    let title: String
    let value: String
    let tint: Color
}

struct ModernSettingBadge: View {
    let badge: ModernSettingBadgeData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: badge.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(badge.tint.opacity(0.4))
                )

            Text(badge.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)
                .accessibilityIdentifier("settings.badge.\(badge.accessibilityID).title")

            Text(badge.value)
                .font(ModernDesignSystem.Typography.bodyBold)
                .foregroundColor(.white)
                .accessibilityIdentifier("settings.badge.\(badge.accessibilityID).value")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

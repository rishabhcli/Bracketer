import SwiftUI

// MARK: - Modern Settings Panel
/// Apple Camera app inspired settings with iOS 18+ design patterns
/// Professional camera settings with modern interface

struct ModernSettingsPanel: View {
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

    private let focusPeakingColors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple, .white]
    @State private var selectedCategory: SettingsCategory = .viewfinder

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
                        withAnimation(ModernDesignSystem.Animations.spring) {
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
                                withAnimation(ModernDesignSystem.Animations.spring) {
                                    showSettings = false
                                }
                                HapticManager.shared.panelToggled()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .liquidGlass(intensity: .prominent, tint: .white.opacity(0.12), interactive: true)
                                    )
                            }
                            .buttonStyle(.plain)
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
                                    case .about:
                                        ModernAboutSection(diagnosticsReport: camera.runtimeDiagnostics.exportText)
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

// MARK: - Modern About Section
struct ModernAboutSection: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    let diagnosticsReport: String

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        guard let build, build != version else {
            return version
        }

        return "\(version) (\(build))"
    }

    var body: some View {
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
    case viewfinder, focus, capture, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewfinder: return "Viewfinder"
        case .focus: return "Focus"
        case .capture: return "Capture"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .viewfinder: return "Composition, grids, leveling"
        case .focus: return "Focus peaking and assistance"
        case .capture: return "Format, metadata & hardware"
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
    let gridType: GridType

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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gridType)
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

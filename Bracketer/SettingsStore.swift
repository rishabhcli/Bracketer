import SwiftUI

// MARK: - Settings Persistence
/// Centralized settings store with UserDefaults persistence.
/// Replaces ephemeral @State properties so user preferences survive app restarts.

final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    enum Keys {
        static let showGrid = "settings.showGrid"
        static let gridType = "settings.gridType"
        static let showLevel = "settings.showLevel"
        static let focusPeakingEnabled = "settings.focusPeakingEnabled"
        static let focusPeakingColor = "settings.focusPeakingColor"
        static let focusPeakingIntensity = "settings.focusPeakingIntensity"
        static let selectedEVStep = "settings.selectedEVStep"
        static let bracketShotCount = "settings.bracketShotCount"
        static let shootingMode = "settings.shootingMode"
        static let flashMode = "settings.flashMode"
        static let timerMode = "settings.timerMode"
        static let teleUses12MP = "settings.teleUses12MP"
    }

    private enum Defaults {
        static let showGrid = true
        static let gridType = GridType.ruleOfThirds
        static let showLevel = true
        static let focusPeakingEnabled = false
        static let focusPeakingColor = Color.red
        static let focusPeakingIntensity: Float = 0.5
        static let selectedEVStep: Float = 1.0
        static let bracketShotCount = 3
        static let currentShootingMode = ShootingMode.auto
        static let flashMode = FlashMode.off
        static let timerMode = TimerMode.off
        static let teleUses12MP = false
    }

    private static let focusPeakingIntensityRange: ClosedRange<Float> = 0.1...1.0
    private static let supportedEVSteps: [Float] = [1.0, 2.0, 3.0]
    private static let supportedBracketShotCounts = BracketPlan.supportedShotCounts

    // MARK: - Viewfinder

    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Keys.showGrid) }
    }

    @Published var gridType: GridType {
        didSet { defaults.set(gridType.rawValue, forKey: Keys.gridType) }
    }

    @Published var showLevel: Bool {
        didSet { defaults.set(showLevel, forKey: Keys.showLevel) }
    }

    // MARK: - Focus Peaking

    @Published var focusPeakingEnabled: Bool {
        didSet { defaults.set(focusPeakingEnabled, forKey: Keys.focusPeakingEnabled) }
    }

    @Published var focusPeakingColor: Color {
        didSet { defaults.set(colorName(focusPeakingColor), forKey: Keys.focusPeakingColor) }
    }

    @Published var focusPeakingIntensity: Float {
        didSet {
            let resolved = Self.normalizedFocusPeakingIntensity(focusPeakingIntensity)
            if focusPeakingIntensity != resolved {
                focusPeakingIntensity = resolved
                return
            }
            defaults.set(resolved, forKey: Keys.focusPeakingIntensity)
        }
    }

    // MARK: - Bracketing

    @Published var selectedEVStep: Float {
        didSet {
            let resolved = Self.normalizedEVStep(selectedEVStep)
            if selectedEVStep != resolved {
                selectedEVStep = resolved
                return
            }
            defaults.set(resolved, forKey: Keys.selectedEVStep)
        }
    }

    @Published var bracketShotCount: Int {
        didSet {
            let resolved = Self.normalizedBracketShotCount(bracketShotCount)
            if bracketShotCount != resolved {
                bracketShotCount = resolved
                return
            }
            defaults.set(resolved, forKey: Keys.bracketShotCount)
        }
    }

    // MARK: - Shooting Mode & Controls

    @Published var currentShootingMode: ShootingMode {
        didSet { defaults.set(currentShootingMode.rawValue, forKey: Keys.shootingMode) }
    }

    @Published var flashMode: FlashMode {
        didSet { defaults.set(flashModeKey(flashMode), forKey: Keys.flashMode) }
    }

    @Published var timerMode: TimerMode {
        didSet { defaults.set(timerModeKey(timerMode), forKey: Keys.timerMode) }
    }

    @Published var teleUses12MP: Bool {
        didSet { defaults.set(teleUses12MP, forKey: Keys.teleUses12MP) }
    }

    // MARK: - Init (load persisted values)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.showGrid = defaults.object(forKey: Keys.showGrid) as? Bool ?? Defaults.showGrid
        self.gridType = GridType(rawValue: defaults.string(forKey: Keys.gridType) ?? "") ?? Defaults.gridType
        self.showLevel = defaults.object(forKey: Keys.showLevel) as? Bool ?? Defaults.showLevel

        self.focusPeakingEnabled = defaults.object(forKey: Keys.focusPeakingEnabled) as? Bool ?? Defaults.focusPeakingEnabled
        self.focusPeakingColor = Self.colorFromName(defaults.string(forKey: Keys.focusPeakingColor) ?? "red")
        self.focusPeakingIntensity = Self.normalizedFocusPeakingIntensity(
            Self.floatValue(forKey: Keys.focusPeakingIntensity, in: defaults) ?? Defaults.focusPeakingIntensity
        )

        self.selectedEVStep = Self.normalizedEVStep(
            Self.floatValue(forKey: Keys.selectedEVStep, in: defaults) ?? Defaults.selectedEVStep
        )
        self.bracketShotCount = Self.normalizedBracketShotCount(
            defaults.object(forKey: Keys.bracketShotCount) as? Int ?? Defaults.bracketShotCount
        )

        self.currentShootingMode = ShootingMode(rawValue: defaults.string(forKey: Keys.shootingMode) ?? "") ?? Defaults.currentShootingMode
        self.flashMode = Self.flashModeFromKey(defaults.string(forKey: Keys.flashMode) ?? Self.flashModeKey(Defaults.flashMode))
        self.timerMode = Self.timerModeFromKey(defaults.string(forKey: Keys.timerMode) ?? Self.timerModeKey(Defaults.timerMode))
        self.teleUses12MP = defaults.object(forKey: Keys.teleUses12MP) as? Bool ?? Defaults.teleUses12MP

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-settings") {
            resetToDefaults()
        } else {
            persistResolvedValues()
        }
    }

    // MARK: - Presets

    func applyPreset(_ preset: CameraPreset) {
        showGrid = preset.showGrid
        gridType = preset.gridType
        showLevel = preset.showLevel
        focusPeakingEnabled = preset.focusPeakingEnabled
        focusPeakingColor = preset.focusPeakingColor
        focusPeakingIntensity = preset.focusPeakingIntensity
    }

    func resetToDefaults() {
        showGrid = Defaults.showGrid
        gridType = Defaults.gridType
        showLevel = Defaults.showLevel
        focusPeakingEnabled = Defaults.focusPeakingEnabled
        focusPeakingColor = Defaults.focusPeakingColor
        focusPeakingIntensity = Defaults.focusPeakingIntensity
        selectedEVStep = Defaults.selectedEVStep
        bracketShotCount = Defaults.bracketShotCount
        currentShootingMode = Defaults.currentShootingMode
        flashMode = Defaults.flashMode
        timerMode = Defaults.timerMode
        teleUses12MP = Defaults.teleUses12MP
    }

    private func persistResolvedValues() {
        defaults.set(showGrid, forKey: Keys.showGrid)
        defaults.set(gridType.rawValue, forKey: Keys.gridType)
        defaults.set(showLevel, forKey: Keys.showLevel)
        defaults.set(focusPeakingEnabled, forKey: Keys.focusPeakingEnabled)
        defaults.set(colorName(focusPeakingColor), forKey: Keys.focusPeakingColor)
        defaults.set(focusPeakingIntensity, forKey: Keys.focusPeakingIntensity)
        defaults.set(selectedEVStep, forKey: Keys.selectedEVStep)
        defaults.set(bracketShotCount, forKey: Keys.bracketShotCount)
        defaults.set(currentShootingMode.rawValue, forKey: Keys.shootingMode)
        defaults.set(flashModeKey(flashMode), forKey: Keys.flashMode)
        defaults.set(timerModeKey(timerMode), forKey: Keys.timerMode)
        defaults.set(teleUses12MP, forKey: Keys.teleUses12MP)
    }

    private static func normalizedFocusPeakingIntensity(_ value: Float) -> Float {
        guard value.isFinite else { return Defaults.focusPeakingIntensity }
        return min(max(value, focusPeakingIntensityRange.lowerBound), focusPeakingIntensityRange.upperBound)
    }

    private static func floatValue(forKey key: String, in defaults: UserDefaults) -> Float? {
        defaults.object(forKey: key) == nil ? nil : defaults.float(forKey: key)
    }

    private static func normalizedEVStep(_ value: Float) -> Float {
        guard value.isFinite else { return Defaults.selectedEVStep }
        return nearestSupportedFloat(value, supportedValues: supportedEVSteps)
    }

    private static func normalizedBracketShotCount(_ value: Int) -> Int {
        guard let first = supportedBracketShotCounts.first else { return Defaults.bracketShotCount }
        let clamped = min(max(value, first), supportedBracketShotCounts.last ?? first)
        return supportedBracketShotCounts.min { abs($0 - clamped) < abs($1 - clamped) } ?? Defaults.bracketShotCount
    }

    private static func nearestSupportedFloat(_ value: Float, supportedValues: [Float]) -> Float {
        guard let first = supportedValues.first else { return value }
        let clamped = min(max(value, first), supportedValues.last ?? first)
        return supportedValues.min { abs($0 - clamped) < abs($1 - clamped) } ?? first
    }

    // MARK: - Color Mapping

    private static let colorMap: [(name: String, color: Color)] = [
        ("red", .red), ("blue", .blue), ("yellow", .yellow),
        ("green", .green), ("orange", .orange), ("purple", .purple), ("white", .white)
    ]

    private func colorName(_ color: Color) -> String {
        Self.colorMap.first { $0.color == color }?.name ?? "red"
    }

    private static func colorFromName(_ name: String) -> Color {
        colorMap.first { $0.name == name }?.color ?? .red
    }

    // MARK: - FlashMode Mapping

    private func flashModeKey(_ mode: FlashMode) -> String {
        Self.flashModeKey(mode)
    }

    private static func flashModeKey(_ mode: FlashMode) -> String {
        switch mode {
        case .auto: return "auto"
        case .on: return "on"
        case .off: return "off"
        }
    }

    private static func flashModeFromKey(_ key: String) -> FlashMode {
        switch key {
        case "auto": return .auto
        case "on": return .on
        default: return .off
        }
    }

    // MARK: - TimerMode Mapping

    private func timerModeKey(_ mode: TimerMode) -> String {
        Self.timerModeKey(mode)
    }

    private static func timerModeKey(_ mode: TimerMode) -> String {
        switch mode {
        case .off: return "off"
        case .threeSeconds: return "3s"
        case .tenSeconds: return "10s"
        }
    }

    private static func timerModeFromKey(_ key: String) -> TimerMode {
        switch key {
        case "3s": return .threeSeconds
        case "10s": return .tenSeconds
        default: return .off
        }
    }
}

// MARK: - Camera Presets

struct CameraPreset {
    let name: String
    let icon: String
    let showGrid: Bool
    let gridType: GridType
    let showLevel: Bool
    let focusPeakingEnabled: Bool
    let focusPeakingColor: Color
    let focusPeakingIntensity: Float

    static let landscape = CameraPreset(
        name: "Landscape", icon: "mountain.2.fill",
        showGrid: true, gridType: .goldenRatio, showLevel: true,
        focusPeakingEnabled: false, focusPeakingColor: .red, focusPeakingIntensity: 0.4
    )

    static let portrait = CameraPreset(
        name: "Portrait", icon: "person.crop.square",
        showGrid: true, gridType: .centerCrosshair, showLevel: false,
        focusPeakingEnabled: true, focusPeakingColor: .orange, focusPeakingIntensity: 0.65
    )

    static let studio = CameraPreset(
        name: "Studio", icon: "sparkles",
        showGrid: false, gridType: .ruleOfThirds, showLevel: false,
        focusPeakingEnabled: true, focusPeakingColor: .green, focusPeakingIntensity: 0.85
    )

    static let tripod = CameraPreset(
        name: "Tripod", icon: "level",
        showGrid: true, gridType: .ruleOfThirds, showLevel: true,
        focusPeakingEnabled: false, focusPeakingColor: .red, focusPeakingIntensity: 0.5
    )

    static let lowLight = CameraPreset(
        name: "Low Light", icon: "moon.fill",
        showGrid: false, gridType: .ruleOfThirds, showLevel: true,
        focusPeakingEnabled: true, focusPeakingColor: .white, focusPeakingIntensity: 0.7
    )
}

import SwiftUI

// MARK: - Settings Persistence
/// Centralized settings store with UserDefaults persistence.
/// Replaces ephemeral @State properties so user preferences survive app restarts.

final class SettingsStore: ObservableObject {
    private static let defaults = UserDefaults.standard

    private enum Keys {
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

    // MARK: - Viewfinder

    @Published var showGrid: Bool {
        didSet { Self.defaults.set(showGrid, forKey: Keys.showGrid) }
    }

    @Published var gridType: GridType {
        didSet { Self.defaults.set(gridType.rawValue, forKey: Keys.gridType) }
    }

    @Published var showLevel: Bool {
        didSet { Self.defaults.set(showLevel, forKey: Keys.showLevel) }
    }

    // MARK: - Focus Peaking

    @Published var focusPeakingEnabled: Bool {
        didSet { Self.defaults.set(focusPeakingEnabled, forKey: Keys.focusPeakingEnabled) }
    }

    @Published var focusPeakingColor: Color {
        didSet { Self.defaults.set(colorName(focusPeakingColor), forKey: Keys.focusPeakingColor) }
    }

    @Published var focusPeakingIntensity: Float {
        didSet { Self.defaults.set(focusPeakingIntensity, forKey: Keys.focusPeakingIntensity) }
    }

    // MARK: - Bracketing

    @Published var selectedEVStep: Float {
        didSet { Self.defaults.set(selectedEVStep, forKey: Keys.selectedEVStep) }
    }

    @Published var bracketShotCount: Int {
        didSet { Self.defaults.set(bracketShotCount, forKey: Keys.bracketShotCount) }
    }

    // MARK: - Shooting Mode & Controls

    @Published var currentShootingMode: ShootingMode {
        didSet { Self.defaults.set(currentShootingMode.rawValue, forKey: Keys.shootingMode) }
    }

    @Published var flashMode: FlashMode {
        didSet { Self.defaults.set(flashModeKey(flashMode), forKey: Keys.flashMode) }
    }

    @Published var timerMode: TimerMode {
        didSet { Self.defaults.set(timerModeKey(timerMode), forKey: Keys.timerMode) }
    }

    @Published var teleUses12MP: Bool {
        didSet { Self.defaults.set(teleUses12MP, forKey: Keys.teleUses12MP) }
    }

    // MARK: - Init (load persisted values)

    init() {
        let d = Self.defaults

        self.showGrid = d.object(forKey: Keys.showGrid) as? Bool ?? true
        self.gridType = GridType(rawValue: d.string(forKey: Keys.gridType) ?? "") ?? .ruleOfThirds
        self.showLevel = d.object(forKey: Keys.showLevel) as? Bool ?? true

        self.focusPeakingEnabled = d.object(forKey: Keys.focusPeakingEnabled) as? Bool ?? false
        self.focusPeakingColor = Self.colorFromName(d.string(forKey: Keys.focusPeakingColor) ?? "red")
        self.focusPeakingIntensity = d.object(forKey: Keys.focusPeakingIntensity) as? Float ?? 0.5

        self.selectedEVStep = d.object(forKey: Keys.selectedEVStep) as? Float ?? 1.0
        self.bracketShotCount = d.object(forKey: Keys.bracketShotCount) as? Int ?? 3

        self.currentShootingMode = ShootingMode(rawValue: d.string(forKey: Keys.shootingMode) ?? "") ?? .auto
        self.flashMode = Self.flashModeFromKey(d.string(forKey: Keys.flashMode) ?? "off")
        self.timerMode = Self.timerModeFromKey(d.string(forKey: Keys.timerMode) ?? "off")
        self.teleUses12MP = d.object(forKey: Keys.teleUses12MP) as? Bool ?? false
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

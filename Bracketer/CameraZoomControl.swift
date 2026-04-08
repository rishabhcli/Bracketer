import SwiftUI

/// Apple Camera app-style zoom lens selector
/// Shows available camera lenses (0.5x, 1x, 2x, 5x) with smooth transitions
@available(iOS 26.0, *)
struct CameraZoomControl: View {
    @Binding var selectedZoom: CameraZoomLevel
    let availableZoomLevels: [CameraZoomLevel]

    var body: some View {
        LiquidGlassContainer(tint: .white.opacity(0.15), intensity: .regular) {
            HStack(spacing: 16) {
                ForEach(availableZoomLevels, id: \.self) { level in
                    ZoomLevelButton(
                        level: level,
                        isSelected: selectedZoom == level,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedZoom = level
                            }
                            HapticManager.shared.exposureAdjusted()
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

@available(iOS 26.0, *)
struct ZoomLevelButton: View {
    let level: CameraZoomLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(level.displayText)
                    .font(.system(size: isSelected ? 18 : 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                if isSelected {
                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Camera Zoom Levels

enum CameraZoomLevel: Float, CaseIterable, Hashable {
    case ultraWide = 0.5
    case wide = 1.0
    case telephoto2x = 2.0
    case telephoto4x = 4.0
    case telephoto8x = 8.0

    var displayText: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide: return "1×"
        case .telephoto2x: return "2×"
        case .telephoto4x: return "4×"
        case .telephoto8x: return "8×"
        }
    }

    var opticalZoomFactor: CGFloat {
        return CGFloat(self.rawValue)
    }

    var description: String {
        switch self {
        case .ultraWide: return "Ultra Wide"
        case .wide: return "Wide"
        case .telephoto2x: return "Telephoto 2×"
        case .telephoto4x: return "Telephoto 4×"
        case .telephoto8x: return "Telephoto 8×"
        }
    }

    var cameraKind: CameraKind {
        switch self {
        case .ultraWide: return .ultraWide
        case .wide: return .wide
        case .telephoto2x: return .twoX
        case .telephoto4x: return .telephoto
        case .telephoto8x: return .eightX
        }
    }

    static var iPhone17ProMaxLevels: [CameraZoomLevel] {
        return [.ultraWide, .wide, .telephoto2x, .telephoto4x, .telephoto8x]
    }

    static var iPhone17ProLevels: [CameraZoomLevel] {
        return [.ultraWide, .wide, .telephoto2x, .telephoto4x]
    }

    static var standardLevels: [CameraZoomLevel] {
        return [.ultraWide, .wide, .telephoto2x]
    }

    static func levels(for kinds: [CameraKind]) -> [CameraZoomLevel] {
        var levels: [CameraZoomLevel] = []

        for kind in kinds {
            switch kind {
            case .ultraWide:
                if !levels.contains(.ultraWide) { levels.append(.ultraWide) }
            case .wide:
                if !levels.contains(.wide) { levels.append(.wide) }
            case .twoX:
                if !levels.contains(.telephoto2x) { levels.append(.telephoto2x) }
            case .telephoto:
                if !levels.contains(.telephoto4x) { levels.append(.telephoto4x) }
            case .eightX:
                if !levels.contains(.telephoto8x) { levels.append(.telephoto8x) }
            }
        }

        if levels.isEmpty {
            levels = [.wide]
        }
        return levels
    }

    static func forCameraKind(_ kind: CameraKind) -> CameraZoomLevel {
        switch kind {
        case .ultraWide: return .ultraWide
        case .wide: return .wide
        case .twoX: return .telephoto2x
        case .telephoto: return .telephoto4x
        case .eightX: return .telephoto8x
        }
    }
}

// MARK: - Flash Mode Control

@available(iOS 26.0, *)
struct FlashModeControl: View {
    @Binding var flashMode: FlashMode
    var isAvailable: Bool = true

    var body: some View {
        FlashModeMenu(flashMode: $flashMode, isAvailable: isAvailable, style: .modern)
    }
}

enum FlashMode: CaseIterable {
    case auto
    case on
    case off

    var iconName: String {
        switch self {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }

    var tintColor: Color? {
        switch self {
        case .auto: return nil
        case .on: return .yellow.opacity(0.5)
        case .off: return nil
        }
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }

    func next() -> FlashMode {
        let all = FlashMode.allCases
        let currentIndex = all.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}

// MARK: - Timer Mode Control

@available(iOS 26.0, *)
struct TimerModeControl: View {
    @Binding var timerMode: TimerMode

    var body: some View {
        TimerModeMenu(timerMode: $timerMode, style: .modern)
    }
}

enum TimerMode: CaseIterable {
    case off
    case threeSeconds
    case tenSeconds

    var seconds: Int {
        switch self {
        case .off: return 0
        case .threeSeconds: return 3
        case .tenSeconds: return 10
        }
    }

    var tintColor: Color? {
        switch self {
        case .off: return nil
        case .threeSeconds: return .orange.opacity(0.3)
        case .tenSeconds: return .orange.opacity(0.5)
        }
    }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .threeSeconds: return "3s"
        case .tenSeconds: return "10s"
        }
    }

    func next() -> TimerMode {
        let all = TimerMode.allCases
        let currentIndex = all.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}

extension FlashMode: Identifiable {
    var id: String { displayName }
}

extension TimerMode: Identifiable {
    var id: String { displayName }
}

// MARK: - Control Picker Helpers

enum ControlButtonStyle {
    case legacy
    case modern
}

struct FlashModeMenu: View {
    @Binding var flashMode: FlashMode
    let isAvailable: Bool
    let style: ControlButtonStyle

    var body: some View {
        Menu {
            ForEach(FlashMode.allCases) { mode in
                Button {
                    guard flashMode != mode else { return }
                    flashMode = mode
                    HapticManager.shared.exposureAdjusted()
                } label: {
                    Label(mode.displayName, systemImage: mode.iconName)
                }
            }
        } label: {
            FlashModeMenuLabel(
                flashMode: flashMode,
                isAvailable: isAvailable,
                style: style
            )
        }
        .accessibilityLabel("Flash Mode")
        .accessibilityValue(isAvailable ? flashMode.displayName : "Unavailable")
        .accessibilityHint(
            isAvailable
            ? "Double-tap to choose flash setting"
            : "Flash is unavailable on the active lens"
        )
        .disabled(!isAvailable)
    }
}

struct FlashModeMenuLabel: View {
    let flashMode: FlashMode
    let isAvailable: Bool
    let style: ControlButtonStyle

    var body: some View {
        ControlCircleLabel(
            style: style,
            tint: isAvailable ? flashMode.tintColor : .gray.opacity(0.25)
        ) {
            Image(systemName: isAvailable ? flashMode.iconName : "bolt.slash.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .opacity(isAvailable ? 1.0 : 0.9)
        }
    }

    private var iconColor: Color {
        guard isAvailable else {
            return .gray
        }

        return style == .legacy ? (flashMode == .off ? .white : .yellow) : .white
    }
}

struct TimerModeMenu: View {
    @Binding var timerMode: TimerMode
    let style: ControlButtonStyle

    var body: some View {
        Menu {
            ForEach(TimerMode.allCases) { option in
                Button {
                    guard timerMode != option else { return }
                    timerMode = option
                    HapticManager.shared.exposureAdjusted()
                } label: {
                    Label(option.displayName, systemImage: "timer")
                        .labelStyle(.titleAndIcon)
                }
            }
        } label: {
            TimerModeMenuLabel(timerMode: timerMode, style: style)
        }
        .accessibilityLabel("Timer Mode")
        .accessibilityValue(timerMode.displayName)
        .accessibilityHint("Double-tap to choose timer length")
    }
}

struct TimerModeMenuLabel: View {
    let timerMode: TimerMode
    let style: ControlButtonStyle

    var body: some View {
        ControlCircleLabel(style: style, tint: timerMode.tintColor) {
            if timerMode == .off {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Text(timerMode.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(style == .modern ? .white : .orange)
            }
        }
    }
}

struct ControlCircleLabel<Content: View>: View {
    let style: ControlButtonStyle
    let tint: Color?
    @ViewBuilder private let content: Content

    init(style: ControlButtonStyle, tint: Color?, @ViewBuilder content: () -> Content) {
        self.style = style
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .modern:
            Circle()
                .liquidGlass(
                    intensity: .regular,
                    tint: tint,
                    interactive: true
                )
        case .legacy:
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
                .overlay(
                    Circle()
                        .stroke(tint ?? .white.opacity(0.2), lineWidth: tint == nil ? 1 : 2)
                )
        }
    }
}

// MARK: - Enhanced Shutter Button

@available(iOS 26.0, *)
struct EnhancedShutterButton: View {
    let isCapturing: Bool
    let progress: Double
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Outer ring with glass effect (increased size for better prominence)
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)

                // Inner button with liquid glass (increased size)
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .scaleEffect(isPressed ? 0.85 : (isCapturing ? 0.9 : 1.0))
                    .overlay(
                        Circle()
                            .liquidGlass(
                                intensity: .prominent,
                                tint: isCapturing ? .red.opacity(0.5) : nil,
                                interactive: true
                            )
                            .scaleEffect(0.95)
                    )

                // Progress indicator (increased size)
                if isCapturing {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.yellow, .orange, .yellow],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    // Pulsing effect during capture (increased size)
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.orange.opacity(0.5))
                        .frame(width: 104, height: 104)
                        .scaleEffect(isCapturing ? 1.1 : 1.0)
                        .opacity(isCapturing ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isCapturing)
                }
            }
        }
        .buttonStyle(ShutterButtonStyle(isPressed: $isPressed))
        .disabled(isCapturing)
        .accessibilityLabel("Capture")
        .accessibilityValue(isCapturing ? "Capturing" : "Ready")
        .accessibilityIdentifier("camera.shutterButton")
    }
}

struct ShutterButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                isPressed = newValue
                if newValue {
                    HapticManager.shared.shutterPressed()
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Live Photo Toggle

@available(iOS 26.0, *)
struct LivePhotoToggle: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isEnabled.toggle()
            }
            HapticManager.shared.exposureAdjusted()
        } label: {
            ZStack {
                Circle()
                    .liquidGlass(
                        intensity: .regular,
                        tint: isEnabled ? .yellow.opacity(0.3) : nil,
                        interactive: true
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: isEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera Control Button (iPhone 16+)

@available(iOS 26.0, *)
struct CameraControlButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Haptic touch area
                RoundedRectangle(cornerRadius: 12)
                    .liquidGlass(intensity: .prominent, tint: .blue.opacity(0.3), interactive: true)
                    .frame(width: 60, height: 36)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    HapticManager.shared.captureStarted()
                }
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Zoom Control") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            CameraZoomControl(
                selectedZoom: .constant(.wide),
                availableZoomLevels: CameraZoomLevel.iPhone17ProMaxLevels
            )

            HStack(spacing: 20) {
                FlashModeControl(flashMode: .constant(.auto))
                TimerModeControl(timerMode: .constant(.off))
                LivePhotoToggle(isEnabled: .constant(true))
            }

            EnhancedShutterButton(
                isCapturing: false,
                progress: 0.0,
                action: {}
            )
        }
    }
}

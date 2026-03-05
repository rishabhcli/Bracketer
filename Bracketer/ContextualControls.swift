import SwiftUI

// MARK: - Contextual Control System
/// Smart control system that shows relevant controls based on shooting mode
/// Reduces clutter and improves UX by showing only what's needed

/// Control context determines which controls are shown in secondary row
enum ControlContext {
    case auto        // Simplified: Flash, Timer, Grid, Level, Pro
    case manual      // Advanced: ISO, Shutter, WB, Pro Controls
    case bracket     // Bracketing: EV Step, Shot Count, Pro Controls
    case night       // Night: Timer, Level, Pro Controls (no flash)

    static func from(mode: ShootingMode) -> ControlContext {
        switch mode {
        case .auto: return .auto
        case .manual: return .manual
        case .portrait: return .auto  // Portrait uses auto context
        case .night: return .night
        }
    }
}

// MARK: - Context-Aware Bottom Controls
@available(iOS 26.2, *)
struct ContextualBottomControls: View {
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
    @Binding var currentShootingMode: ShootingMode
    let onGridToggle: () -> Void
    let onLevelToggle: () -> Void

    private var context: ControlContext {
        ControlContext.from(mode: currentShootingMode)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Context-aware secondary controls row
            contextualSecondaryControls

            // Main control row (always visible)
            HStack(spacing: 44) {
                ModernPhotoLibraryButton(camera: camera)

                EnhancedShutterButton(
                    isCapturing: camera.isCapturing,
                    progress: Double(camera.captureProgress) / Double(max(1, bracketShotCount))
                ) {
                    camera.captureLockdownBracket(evStep: selectedEVStep, shotCount: bracketShotCount)
                }

                ModernSettingsButton(showSettings: $showSettings)
            }
            .padding(.horizontal, 20)

            // Zoom selector at very bottom
            CameraZoomControl(
                selectedZoom: $selectedZoom,
                availableZoomLevels: CameraZoomLevel.levels(for: camera.availableCameraKinds)
            )
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var contextualSecondaryControls: some View {
        switch context {
        case .auto:
            autoModeControls
        case .manual:
            manualModeControls
        case .bracket:
            bracketModeControls
        case .night:
            nightModeControls
        }
    }

    // AUTO mode: Essential controls only
    private var autoModeControls: some View {
        HStack(spacing: 20) {
            FlashModeControl(flashMode: $flashMode)
            TimerModeControl(timerMode: $timerMode)

            Spacer()
                .frame(width: 8)

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
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MANUAL mode: Pro controls prominent
    private var manualModeControls: some View {
        HStack(spacing: 20) {
            // Quick ISO indicator
            CompactStatusIndicator(
                icon: "camera.aperture",
                value: String(format: "ISO %.0f", camera.currentISO),
                color: .yellow
            )

            // Quick Shutter speed indicator
            CompactStatusIndicator(
                icon: "timer",
                value: camera.currentShutterSpeedText,
                color: .cyan
            )

            Spacer()

            ModernToggleButton(
                icon: "level",
                isActive: isLevelActive,
                onTap: onLevelToggle
            )
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // BRACKET mode: EV and shot count controls
    private var bracketModeControls: some View {
        HStack(spacing: 20) {
            // EV step selector
            EVStepQuickSelector(selectedEVStep: $selectedEVStep)

            // Shot count indicator
            CompactStatusIndicator(
                icon: "rectangle.stack",
                value: "\(bracketShotCount) shots",
                color: .orange
            )

            Spacer()
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // NIGHT mode: No flash, focus on stability
    private var nightModeControls: some View {
        HStack(spacing: 20) {
            TimerModeControl(timerMode: $timerMode)

            CompactStatusIndicator(
                icon: "moon.stars.fill",
                value: "Night",
                color: .blue
            )

            Spacer()

            ModernToggleButton(
                icon: "level",
                isActive: isLevelActive,
                onTap: onLevelToggle
            )
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Compact Status Indicator
@available(iOS 26.0, *)
struct CompactStatusIndicator: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .liquidGlass(intensity: .regular, tint: color.opacity(0.2), interactive: false)
        )
    }
}

// MARK: - EV Step Quick Selector
@available(iOS 26.0, *)
struct EVStepQuickSelector: View {
    @Binding var selectedEVStep: Float
    
    private let evSteps: [Float] = [1.0, 2.0, 3.0]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(evSteps, id: \.self) { step in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedEVStep = step
                    }
                    HapticManager.shared.exposureAdjusted()
                } label: {
                    Text("±\(Int(step))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedEVStep == step ? .black : .white)
                        .frame(width: 36, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .liquidGlass(
                                    intensity: selectedEVStep == step ? .prominent : .subtle,
                                    tint: selectedEVStep == step ? .yellow : nil,
                                    interactive: true
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

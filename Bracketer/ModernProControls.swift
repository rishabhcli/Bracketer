import SwiftUI

// MARK: - Modern Pro Controls Panel
/// Apple Camera app inspired pro controls with iOS 26 Liquid Glass design
/// Implements tinted glass effects for professional photography controls

@available(iOS 26.2, *)
struct ModernProControls: View {
    let camera: CameraController
    @Binding var showProControls: Bool
    @Binding var selectedEVStep: Float
    @Binding var currentEVCompensation: Float
    @Binding var evCompensationLocked: Bool
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    @Binding var showHistogram: Bool
    @Binding var showZebras: Bool
    @Binding var bracketShotCount: Int

    // Manual controls
    @State private var manualISO: Float = 100
    @State private var manualShutterSpeed: Float = 0.01
    @State private var whiteBalance: Float = 5500
    @State private var manualFocus: Float = 0.5

    // Section expand/collapse state - only Bracketing expanded by default
    @State private var isExposureExpanded: Bool = false
    @State private var isFocusExpanded: Bool = false
    @State private var isBracketingExpanded: Bool = true

    // Drag gesture state for dismiss
    @State private var dragOffset: CGFloat = 0

    private let focusPeakingColors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple, .white]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSheet()
                    }

                // Pro controls panel - bottom sheet
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.white.opacity(0.28))
                        .frame(width: 36, height: 5)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    HStack {
                        Text("Pro Controls")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))

                        Spacer()

                        Button {
                            dismissSheet()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(10)
                                .background(
                                    Circle()
                                        .liquidGlass(intensity: .regular, tint: .white.opacity(0.15), interactive: true)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pro.closeButton")
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 6)

                    ScrollView {
                        VStack(spacing: 20) {
                            ModernExposureControls(
                                camera: camera,
                                manualISO: $manualISO,
                                manualShutterSpeed: $manualShutterSpeed,
                                whiteBalance: $whiteBalance,
                                showHistogram: $showHistogram,
                                showZebras: $showZebras,
                                isExpanded: $isExposureExpanded
                            )

                            ModernFocusControls(
                                camera: camera,
                                manualFocus: $manualFocus,
                                focusPeakingEnabled: $focusPeakingEnabled,
                                focusPeakingColor: $focusPeakingColor,
                                focusPeakingIntensity: $focusPeakingIntensity,
                                focusPeakingColors: focusPeakingColors,
                                isExpanded: $isFocusExpanded
                            )

                            ModernBracketingControls(
                                selectedEVStep: $selectedEVStep,
                                currentEVCompensation: $currentEVCompensation,
                                evCompensationLocked: $evCompensationLocked,
                                bracketShotCount: $bracketShotCount,
                                isExpanded: $isBracketingExpanded
                            )
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 28)
                    }
                }
                .frame(maxHeight: geometry.size.height * 0.75)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .liquidGlass(intensity: .regular, tint: .white.opacity(0.08), interactive: true)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 32, x: 0, y: 18)
                )
                .padding(.horizontal, 10)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow dragging down
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            // Dismiss if dragged more than 100pt
                            if value.translation.height > 100 {
                                dismissSheet()
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showProControls = false
        }
    }
}

// MARK: - Modern Exposure Controls

@available(iOS 26.0, *)
struct ModernExposureControls: View {
    @ObservedObject var camera: CameraController
    @Binding var manualISO: Float
    @Binding var manualShutterSpeed: Float
    @Binding var whiteBalance: Float
    @Binding var showHistogram: Bool
    @Binding var showZebras: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Section header - tappable to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.exposureAdjusted()
            } label: {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow.opacity(0.85))
                    Text("Exposure")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .liquidGlass(intensity: .regular, tint: .yellow.opacity(0.2), interactive: true)
                )
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                VStack(spacing: 20) {
                    // ISO Control
                    ModernSliderControl(
                        title: "ISO",
                        value: $manualISO,
                        range: camera.minISO...camera.maxISO,
                        step: 25,
                        format: { "\(Int($0))" },
                        color: .yellow
                    )

                    // Shutter Speed Control
                    ModernSliderControl(
                        title: "Shutter",
                        value: $manualShutterSpeed,
                        range: camera.minShutterSpeed...camera.maxShutterSpeed,
                        step: 0.001,
                        format: formatShutterSpeed,
                        color: .cyan
                    )

                    // White Balance Control
                    ModernSliderControl(
                        title: "White Balance",
                        value: $whiteBalance,
                        range: 2500...10000,
                        step: 100,
                        format: { "\(Int($0))K" },
                        color: .orange
                    )

                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.yellow.opacity(0.9))
                        Text("Histogram")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Toggle("", isOn: $showHistogram)
                            .labelsHidden()
                            .tint(.yellow)
                            .accessibilityLabel("Histogram Overlay")
                            .accessibilityValue(showHistogram ? "On" : "Off")
                            .accessibilityIdentifier("pro.histogramToggle")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .liquidGlass(intensity: .subtle, tint: .yellow.opacity(0.15), interactive: true)
                    )

                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow.opacity(0.9))
                        Text("Zebras")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Toggle("", isOn: $showZebras)
                            .labelsHidden()
                            .tint(.yellow)
                            .accessibilityLabel("Zebra Overlay")
                            .accessibilityValue(showZebras ? "On" : "Off")
                            .accessibilityIdentifier("pro.zebraToggle")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .liquidGlass(intensity: .subtle, tint: .yellow.opacity(0.15), interactive: true)
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .proSectionCard(tint: .yellow)
        .onChange(of: manualISO) { _, newValue in
            camera.setManualISO(newValue)
        }
        .onChange(of: manualShutterSpeed) { _, newValue in
            camera.setManualShutterSpeed(newValue)
        }
        .onChange(of: whiteBalance) { _, newValue in
            camera.setManualWhiteBalance(temperature: newValue)
        }
    }

    private func formatShutterSpeed(_ duration: Float) -> String {
        if duration >= 1.0 {
            return String(format: "%.1fs", duration)
        } else {
            let fraction = 1.0 / duration
            if fraction < 10 {
                return String(format: "1/%.1f", fraction)
            } else {
                return String(format: "1/%.0f", fraction)
            }
        }
    }
}

// MARK: - Modern Focus Controls

@available(iOS 26.0, *)
struct ModernFocusControls: View {
    @ObservedObject var camera: CameraController
    @Binding var manualFocus: Float
    @Binding var focusPeakingEnabled: Bool
    @Binding var focusPeakingColor: Color
    @Binding var focusPeakingIntensity: Float
    let focusPeakingColors: [Color]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Section header - tappable to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.exposureAdjusted()
            } label: {
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.green.opacity(0.9))
                    Text("Focus")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .liquidGlass(intensity: .regular, tint: .green.opacity(0.2), interactive: true)
                )
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                VStack(spacing: 20) {
                    // Manual Focus Control
                    ModernSliderControl(
                        title: "Focus",
                        value: $manualFocus,
                        range: 0...1,
                        step: 0.01,
                        format: { "\(Int($0 * 100))%" },
                        color: .green
                    )

                    // Focus Peaking Toggle
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(.green.opacity(0.9))
                        Text("Focus Peaking")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Toggle("", isOn: $focusPeakingEnabled)
                            .labelsHidden()
                            .tint(.green)
                            .accessibilityLabel("Focus Peaking")
                            .accessibilityValue(focusPeakingEnabled ? "On" : "Off")
                            .accessibilityIdentifier("pro.focusPeakingToggle")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .liquidGlass(intensity: .subtle, tint: .green.opacity(0.15), interactive: true)
                    )

                    // Focus Peaking Controls
                    if focusPeakingEnabled {
                        VStack(spacing: 12) {
                            // Color selection
                            HStack {
                                Text("Color")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }

                            HStack(spacing: 12) {
                                ForEach(focusPeakingColors, id: \.self) { color in
                                    Button {
                                        focusPeakingColor = color
                                        HapticManager.shared.exposureAdjusted()
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .liquidGlass(
                                                    intensity: .regular,
                                                    tint: color.opacity(focusPeakingColor == color ? 0.45 : 0.25),
                                                    interactive: true
                                                )
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Circle()
                                                        .stroke(color, lineWidth: focusPeakingColor == color ? 3 : 1)
                                                )

                                            if focusPeakingColor == color {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Intensity control
                            ModernSliderControl(
                                title: "Intensity",
                                value: $focusPeakingIntensity,
                                range: 0.1...1.0,
                                step: 0.1,
                                format: { "\(Int($0 * 100))%" },
                                color: .green
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .proSectionCard(tint: .green)
        .onChange(of: manualFocus) { _, newValue in
            camera.setManualFocus(position: newValue)
        }
    }
}

// MARK: - Modern Bracketing Controls

@available(iOS 26.0, *)
struct ModernBracketingControls: View {
    @Binding var selectedEVStep: Float
    @Binding var currentEVCompensation: Float
    @Binding var evCompensationLocked: Bool
    @Binding var bracketShotCount: Int
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Section header - tappable to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.exposureAdjusted()
            } label: {
                HStack {
                    Image(systemName: "rectangle.stack")
                        .foregroundColor(.orange.opacity(0.9))
                    Text("Bracketing")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .liquidGlass(intensity: .regular, tint: .orange.opacity(0.2), interactive: true)
                )
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                VStack(spacing: 20) {
                    // EV Compensation with inline glass effect
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                evCompensationLocked.toggle()
                            }
                            HapticManager.shared.exposureAdjusted()
                        } label: {
                            Image(systemName: evCompensationLocked ? "lock.fill" : "lock.open")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(evCompensationLocked ? .red : .white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .liquidGlass(
                                            intensity: .prominent,
                                            tint: evCompensationLocked ? .red.opacity(0.5) : nil,
                                            interactive: true
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 4) {
                            HStack {
                                Text("EV Compensation")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text(formatEV(currentEVCompensation))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .monospacedDigit()
                            }

                            Slider(value: $currentEVCompensation, in: -4.0...4.0, step: 0.1)
                                .accentColor(.orange)
                                .disabled(evCompensationLocked)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .liquidGlass(intensity: .subtle, tint: .orange.opacity(0.15), interactive: true)
                    )

                    // Bracketing sequence visualization
                    ModernBracketingSequence(evStep: selectedEVStep, shotCount: bracketShotCount)

                    // EV Step selection
                    HStack(spacing: 12) {
                        ForEach([1, 2, 3], id: \.self) { value in
                            Button {
                                selectedEVStep = Float(value)
                                HapticManager.shared.exposureAdjusted()
                            } label: {
                                Text("±\(value)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(selectedEVStep == Float(value) ? .black : .white)
                                    .frame(minWidth: 60)
                                    .frame(height: 44)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .liquidGlass(
                                                intensity: selectedEVStep == Float(value) ? .prominent : .regular,
                                                tint: selectedEVStep == Float(value) ? .orange : nil,
                                                interactive: true
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pro.evStep.\(value)")
                        }
                    }

                    // Shot count selection
                    HStack(spacing: 12) {
                        ForEach([3, 5, 7], id: \.self) { count in
                            Button {
                                bracketShotCount = count
                                HapticManager.shared.exposureAdjusted()
                            } label: {
                                Text("\(count) shots")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(bracketShotCount == count ? .black : .white)
                                    .frame(minWidth: 70)
                                    .frame(height: 44)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .liquidGlass(
                                                intensity: bracketShotCount == count ? .prominent : .regular,
                                                tint: bracketShotCount == count ? .orange.opacity(0.5) : nil,
                                                interactive: true
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pro.shotCount.\(count)")
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .proSectionCard(tint: .orange)
    }

    private func formatEV(_ value: Float) -> String {
        if value == 0 {
            return "±0"
        }
        return String(format: "%+.1f", value)
    }
}

// MARK: - Modern Slider Control

@available(iOS 26.0, *)
struct ModernSliderControl: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let format: (Float) -> String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(format(value))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
            }

            Slider(value: $value, in: range, step: step) { editing in
                if !editing {
                    HapticManager.shared.exposureAdjusted()
                }
            }
            .accentColor(color)
            .accessibilityLabel(title)
            .accessibilityValue(format(value))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .liquidGlass(intensity: .subtle, tint: color.opacity(0.1), interactive: false)
        )
    }
}

// MARK: - Modern Bracketing Sequence

@available(iOS 26.0, *)
struct ModernBracketingSequence: View {
    let evStep: Float
    let shotCount: Int

    private var plan: BracketPlan {
        BracketPlan(evStep: evStep, requestedShotCount: shotCount)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(plan.shots) { shot in
                VStack(spacing: 2) {
                    Text(formatEV(shot.evOffset))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(shot.isCenterExposure ? .black : .white)
                    Text("EV")
                        .font(.system(size: 9))
                        .foregroundColor(shot.isCenterExposure ? .black.opacity(0.7) : .white.opacity(0.7))
                }
                .frame(width: 40, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .liquidGlass(
                            intensity: shot.isCenterExposure ? .prominent : .subtle,
                            tint: shot.isCenterExposure ? .orange : .white.opacity(0.1),
                            interactive: false
                        )
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func formatEV(_ value: Float) -> String {
        if BracketEVFormatter.isEffectivelyZero(value) {
            return "0"
        } else if value > 0 {
            return "+\(Int(value))"
        } else {
            return "\(Int(value))"
        }
    }
}

// MARK: - Pro Section Card Helper

private extension View {
    func proSectionCard(tint: Color) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.35),
                            tint.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.25), radius: 24, x: 0, y: 12)
        )
    }
}

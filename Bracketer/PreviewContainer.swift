import SwiftUI
import AVFoundation
import Combine

private enum Constants {
    static let gridLineWidth: CGFloat = 1.0
    static let gridOpacity: Double = 0.3
    static let levelIndicatorHeight: CGFloat = 2.0
    static let levelIndicatorWidthMultiplier: CGFloat = 0.6
}

// Grid type enumeration for different overlay patterns
enum GridType: String, CaseIterable, Identifiable {
    case ruleOfThirds = "Rule of Thirds"
    case goldenRatio = "Golden Ratio"
    case goldenSpiral = "Golden Spiral"
    case centerCrosshair = "Center Crosshair"

    var id: String { rawValue }
}

enum ShootingMode: String, CaseIterable {
    case auto = "AUTO"
    case manual = "MANUAL"
    case portrait = "PORTRAIT"
    case night = "NIGHT"

    var icon: String {
        switch self {
        case .auto: return "camera.fill"
        case .manual: return "dial.medium.fill"
        case .portrait: return "person.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .auto: return .white
        case .manual: return .purple
        case .portrait: return .blue
        case .night: return .indigo
        }
    }
}

struct PreviewContainer: View {
    let session: AVCaptureSession
    var onLayerReady: ((AVCaptureVideoPreviewLayer) -> Void)?
    var gridType: GridType = .ruleOfThirds
    var showGrid: Bool = true
    var levelAngle: Double = 0
    var showHistogram: Bool = false
    var histogramData: HistogramData? = nil
    var focusPeakingEnabled: Bool = false
    var focusPeakingColor: Color = .red
    var focusPeakingIntensity: Float = 0.5

    @EnvironmentObject var orientationManager: OrientationManager

    var body: some View {
        GeometryReader { geo in
            let previewAspect: CGFloat = orientationManager.isPortrait ? 3.0 / 4.0 : 4.0 / 3.0

            ZStack {
                // Background to fill the screen behind the 4:3 preview
                Color.black.ignoresSafeArea()

                // Centered camera preview with overlays, constrained to the preview bounds
                ZStack {
                    CameraPreviewLayerView(session: session, onLayerReady: onLayerReady)
                        .clipped()

                    if showGrid {
                        ZStack {
                            switch gridType {
                            case .ruleOfThirds:
                                RuleOfThirdsGrid()
                                    .stroke(Color.white.opacity(Constants.gridOpacity), lineWidth: Constants.gridLineWidth)
                            case .goldenRatio:
                                GoldenRatioGrid()
                                    .stroke(Color.white.opacity(Constants.gridOpacity), lineWidth: Constants.gridLineWidth)
                            case .goldenSpiral:
                                GoldenSpiralGrid()
                                    .stroke(Color.white.opacity(Constants.gridOpacity), lineWidth: Constants.gridLineWidth)
                            case .centerCrosshair:
                                CenterCrosshairGrid()
                                    .stroke(Color.white.opacity(Constants.gridOpacity), lineWidth: Constants.gridLineWidth)
                            }
                        }
                        .allowsHitTesting(false)
                    }

                    if levelAngle != 0 {
                        MotionLevelOverlay(angleDegrees: levelAngle)
                            .allowsHitTesting(false)
                    }

                    if showHistogram {
                        HistogramOverlay(histogramData: histogramData)
                            .allowsHitTesting(false)
                    }

                    if focusPeakingEnabled {
                        FocusPeakingOverlay(color: focusPeakingColor, intensity: focusPeakingIntensity)
                            .allowsHitTesting(false)
                    }
                }
                .aspectRatio(previewAspect, contentMode: .fit)
                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                .clipped()
            }
        }
    }
}

struct RuleOfThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        p.move(to: CGPoint(x: w/3, y: 0))
        p.addLine(to: CGPoint(x: w/3, y: h))

        p.move(to: CGPoint(x: 2*w/3, y: 0))
        p.addLine(to: CGPoint(x: 2*w/3, y: h))

        p.move(to: CGPoint(x: 0, y: h/3))
        p.addLine(to: CGPoint(x: w, y: h/3))

        p.move(to: CGPoint(x: 0, y: 2*h/3))
        p.addLine(to: CGPoint(x: w, y: 2*h/3))

        return p
    }
}

struct GoldenRatioGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let phi: CGFloat = 1.618033988749895 // Golden ratio

        // Golden ratio divisions
        let x1 = w / phi
        let x2 = w - x1
        let y1 = h / phi
        let y2 = h - y1

        // Vertical lines
        p.move(to: CGPoint(x: x1, y: 0))
        p.addLine(to: CGPoint(x: x1, y: h))

        p.move(to: CGPoint(x: x2, y: 0))
        p.addLine(to: CGPoint(x: x2, y: h))

        // Horizontal lines
        p.move(to: CGPoint(x: 0, y: y1))
        p.addLine(to: CGPoint(x: w, y: y1))

        p.move(to: CGPoint(x: 0, y: y2))
        p.addLine(to: CGPoint(x: w, y: y2))

        return p
    }
}

struct GoldenSpiralGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let center = CGPoint(x: w/2, y: h/2)
        // Removed unused phi constant as per instruction

        // Create a simplified golden spiral using quarter circles
        let radii: [CGFloat] = [min(w, h) * 0.1, min(w, h) * 0.15, min(w, h) * 0.25, min(w, h) * 0.4]

        for (i, radius) in radii.enumerated() {
            let startAngle = Angle(degrees: Double(i) * 90)
            let endAngle = Angle(degrees: Double(i + 1) * 90)

            p.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        }

        return p
    }
}

struct CenterCrosshairGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let centerX = w / 2
        let centerY = h / 2

        // Center crosshairs
        p.move(to: CGPoint(x: centerX, y: 0))
        p.addLine(to: CGPoint(x: centerX, y: h))

        p.move(to: CGPoint(x: 0, y: centerY))
        p.addLine(to: CGPoint(x: w, y: centerY))

        // Smaller crosshairs at rule of thirds intersections
        let thirdX = w / 3
        let thirdY = h / 3

        // Top intersections
        p.move(to: CGPoint(x: thirdX - 15, y: thirdY))
        p.addLine(to: CGPoint(x: thirdX + 15, y: thirdY))

        p.move(to: CGPoint(x: 2 * thirdX - 15, y: thirdY))
        p.addLine(to: CGPoint(x: 2 * thirdX + 15, y: thirdY))

        // Bottom intersections
        p.move(to: CGPoint(x: thirdX - 15, y: 2 * thirdY))
        p.addLine(to: CGPoint(x: thirdX + 15, y: 2 * thirdY))

        p.move(to: CGPoint(x: 2 * thirdX - 15, y: 2 * thirdY))
        p.addLine(to: CGPoint(x: 2 * thirdX + 15, y: 2 * thirdY))

        // Left intersections
        p.move(to: CGPoint(x: thirdX, y: thirdY - 15))
        p.addLine(to: CGPoint(x: thirdX, y: thirdY + 15))

        p.move(to: CGPoint(x: thirdX, y: 2 * thirdY - 15))
        p.addLine(to: CGPoint(x: thirdX, y: 2 * thirdY + 15))

        // Right intersections
        p.move(to: CGPoint(x: 2 * thirdX, y: thirdY - 15))
        p.addLine(to: CGPoint(x: 2 * thirdX, y: thirdY + 15))

        p.move(to: CGPoint(x: 2 * thirdX, y: 2 * thirdY - 15))
        p.addLine(to: CGPoint(x: 2 * thirdX, y: 2 * thirdY + 15))

        return p
    }
}

struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession
    var onLayerReady: ((AVCaptureVideoPreviewLayer) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        guard let layer = v.videoPreviewLayer else {
            Logger.error("Failed to get video preview layer")
            return v
        }

        layer.session = session
        layer.videoGravity = .resizeAspectFill

        // Configure video mirroring
        if let c = layer.connection, c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = false
        }

        onLayerReady?(layer)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        guard let layer = uiView.videoPreviewLayer else { return }
        layer.videoGravity = .resizeAspectFill
        // Note: Preview layer is NOT rotated - it stays fixed to match device screen
        // Only photo output connection is rotated (handled in CameraController)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        // No cleanup needed - coordinator no longer manages orientation
    }

    class Coordinator {
        let parent: CameraPreviewLayerView

        init(parent: CameraPreviewLayerView) {
            self.parent = parent
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }
}

enum HistogramMode {
    case rgbHistogram
    case luminanceWaveform
    case rgbWaveform
}

struct HistogramOverlay: View {
    @State private var currentMode: HistogramMode = .rgbHistogram
    @State private var isExpanded = false

    let histogramData: HistogramData?

    init(histogramData: HistogramData? = nil) {
        self.histogramData = histogramData
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(isExpanded ? 0.8 : 0.3)
                    .cornerRadius(12)

                VStack(spacing: 8) {
                    // Mode selector and controls
                    if isExpanded {
                        HStack {
                            Picker("Mode", selection: $currentMode) {
                                Text("RGB Hist").tag(HistogramMode.rgbHistogram)
                                Text("Luma Wave").tag(HistogramMode.luminanceWaveform)
                                Text("RGB Wave").tag(HistogramMode.rgbWaveform)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)

                            Spacer()

                            Button {
                                withAnimation(.spring()) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .liquidGlass(intensity: .regular, tint: .white.opacity(0.15), interactive: true)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    } else {
                        HStack {
                            Text(modeTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Button {
                                withAnimation(.spring()) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .liquidGlass(intensity: .regular, tint: .white.opacity(0.15), interactive: true)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    }

                    // Histogram/Waveform display
                    ZStack {
                        // Grid lines
                        HistogramGrid()

                        // Data visualization
                        if let data = histogramData {
                            switch currentMode {
                            case .rgbHistogram:
                                RGBHistogramView(data: data, height: isExpanded ? 120 : 60)
                            case .luminanceWaveform:
                                LuminanceWaveformView(data: data, height: isExpanded ? 120 : 60)
                            case .rgbWaveform:
                                RGBWaveformView(data: data, height: isExpanded ? 120 : 60)
                            }
                        } else {
                            Text("Analyzing...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(height: isExpanded ? 120 : 60)
                    .padding(.horizontal, 12)
                    .padding(.bottom, isExpanded ? 12 : 4)
                }
            }
            .frame(width: geo.size.width * (isExpanded ? 0.9 : 0.8), height: isExpanded ? 200 : 80)
            .position(x: geo.size.width / 2, y: geo.size.height - (isExpanded ? 120 : 60))
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.spring()) {
                            currentMode = nextMode(currentMode)
                        }
                    }
            )
        }
    }

    private var modeTitle: String {
        switch currentMode {
        case .rgbHistogram: return "RGB Histogram"
        case .luminanceWaveform: return "Luminance Waveform"
        case .rgbWaveform: return "RGB Waveform"
        }
    }

    private func nextMode(_ mode: HistogramMode) -> HistogramMode {
        switch mode {
        case .rgbHistogram: return .luminanceWaveform
        case .luminanceWaveform: return .rgbWaveform
        case .rgbWaveform: return .rgbHistogram
        }
    }
}

struct HistogramData {
    let red: [Float]
    let green: [Float]
    let blue: [Float]
    let luminance: [Float]

    // Computed properties for analysis
    var redPeak: Float { red.max() ?? 0 }
    var greenPeak: Float { green.max() ?? 0 }
    var bluePeak: Float { blue.max() ?? 0 }
    var luminancePeak: Float { luminance.max() ?? 0 }

    var overexposedPixels: Float {
        let threshold: Float = 0.95
        return zip(zip(red, green), blue)
            .filter { $0.0 > threshold || $0.1 > threshold || $1 > threshold }
            .count > 0 ? 1.0 : 0.0
    }

    var underexposedPixels: Float {
        let threshold: Float = 0.05
        return zip(zip(red, green), blue)
            .filter { $0.0 < threshold && $0.1 < threshold && $1 < threshold }
            .count > 0 ? 1.0 : 0.0
    }
}

struct HistogramGrid: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height

                // Vertical grid lines (every 64 values)
                for i in 1...3 {
                    let x = width * CGFloat(i) / 4
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                // Horizontal grid lines (quartiles)
                for i in 1...3 {
                    let y = height * CGFloat(i) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        }
    }
}

struct RGBHistogramView: View {
    let data: HistogramData
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Red channel
                Path { path in
                    let width = geo.size.width
                    let points = stride(from: 0, to: data.red.count, by: max(1, data.red.count / 64))
                        .map { index -> CGPoint in
                            let x = width * CGFloat(index) / CGFloat(data.red.count)
                            let y = height * (1 - CGFloat(data.red[index]))
                            return CGPoint(x: x, y: y)
                        }

                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.red.opacity(0.8), lineWidth: 1.5)

                // Green channel
                Path { path in
                    let width = geo.size.width
                    let points = stride(from: 0, to: data.green.count, by: max(1, data.green.count / 64))
                        .map { index -> CGPoint in
                            let x = width * CGFloat(index) / CGFloat(data.green.count)
                            let y = height * (1 - CGFloat(data.green[index]))
                            return CGPoint(x: x, y: y)
                        }

                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.green.opacity(0.8), lineWidth: 1.5)

                // Blue channel
                Path { path in
                    let width = geo.size.width
                    let points = stride(from: 0, to: data.blue.count, by: max(1, data.blue.count / 64))
                        .map { index -> CGPoint in
                            let x = width * CGFloat(index) / CGFloat(data.blue.count)
                            let y = height * (1 - CGFloat(data.blue[index]))
                            return CGPoint(x: x, y: y)
                        }

                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.blue.opacity(0.8), lineWidth: 1.5)

                // Exposure indicators
                if data.overexposedPixels > 0 {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 4, height: height * 0.1)
                        .position(x: geo.size.width - 2, y: height * 0.05)
                }

                if data.underexposedPixels > 0 {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 4, height: height * 0.1)
                        .position(x: 2, y: height * 0.95)
                }
            }
        }
    }
}

struct LuminanceWaveformView: View {
    let data: HistogramData
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let points = stride(from: 0, to: data.luminance.count, by: max(1, data.luminance.count / Int(width)))
                    .map { index -> CGPoint in
                        let x = width * CGFloat(index) / CGFloat(data.luminance.count)
                        let y = height * (1 - CGFloat(data.luminance[index]))
                        return CGPoint(x: x, y: y)
                    }

                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
        }
    }
}

struct RGBWaveformView: View {
    let data: HistogramData
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                let redPath = createWaveformPath(for: data.red, in: geo, offset: height * 0.2)
                redPath.stroke(Color.red.opacity(0.8), lineWidth: 1)

                let greenPath = createWaveformPath(for: data.green, in: geo, offset: height * 0.5)
                greenPath.stroke(Color.green.opacity(0.8), lineWidth: 1)

                let bluePath = createWaveformPath(for: data.blue, in: geo, offset: height * 0.8)
                bluePath.stroke(Color.blue.opacity(0.8), lineWidth: 1)
            }
        }
    }

    private func createWaveformPath(for channel: [Float], in geo: GeometryProxy, offset: CGFloat) -> Path {
        var path = Path()
        let width = geo.size.width
        let amplitude = height * 0.15

        let points = stride(from: 0, to: channel.count, by: max(1, channel.count / Int(width)))
            .map { index -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(channel.count)
                let y = offset + amplitude * CGFloat(channel[index] - 0.5)
                return CGPoint(x: x, y: y)
            }

        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }
}

struct FocusPeakingOverlay: View {
    let color: Color
    let intensity: Float

    // State for animation timing
    @State private var currentTime: TimeInterval = Date().timeIntervalSince1970

    // Focus peaking parameters
    private let focusAreas: [(CGPoint, CGFloat)] = [
        // Simulated focus areas - in real implementation, this would be calculated from camera feed analysis
        (CGPoint(x: 0.3, y: 0.4), 0.8),  // Strong focus area
        (CGPoint(x: 0.7, y: 0.3), 0.6),  // Medium focus area
        (CGPoint(x: 0.5, y: 0.6), 0.9),  // Very strong focus area
        (CGPoint(x: 0.2, y: 0.7), 0.4),  // Weak focus area
        (CGPoint(x: 0.8, y: 0.8), 0.7),  // Good focus area
        (CGPoint(x: 0.1, y: 0.2), 0.5),  // Medium focus area
        (CGPoint(x: 0.9, y: 0.5), 0.3),  // Weak focus area
        (CGPoint(x: 0.4, y: 0.1), 0.6),  // Medium focus area
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Focus peaking highlights - simulating edge detection
                ForEach(0..<focusAreas.count, id: \.self) { index in
                    let area = focusAreas[index]
                    let position = CGPoint(
                        x: area.0.x * geo.size.width,
                        y: area.0.y * geo.size.height
                    )
                    let strength = area.1 * CGFloat(intensity)

                    // Create focus peaking dots with varying sizes based on focus strength
                    FocusPeakingDot(
                        position: position,
                        strength: strength,
                        color: color
                    )
                }

                // Add some additional dynamic elements for more realistic effect
                ForEach(0..<8) { index in
                    let phase = Double(index) * .pi / 4
                    let animationOffset = sin(currentTime * 2 + phase) * 5

                    Circle()
                        .fill(color.opacity(0.3 * Double(intensity)))
                        .frame(width: 3, height: 3)
                        .position(
                            x: geo.size.width * 0.5 + cos(currentTime + phase) * 50 + animationOffset,
                            y: geo.size.height * 0.5 + sin(currentTime + phase) * 50 + animationOffset
                        )
                }
            }
        }
        .task {
            // Set up timer to update animation at ~20 FPS for smooth focus peaking animations
            // Using .task ensures automatic cancellation when the view disappears
            for await _ in Timer.publish(every: 0.05, on: .main, in: .common).autoconnect().values {
                currentTime = Date().timeIntervalSince1970
            }
        }
    }
}

struct FocusPeakingDot: View {
    let position: CGPoint
    let strength: CGFloat
    let color: Color

    // State for animation timing
    @State private var currentTime: TimeInterval = Date().timeIntervalSince1970

    var body: some View {
        ZStack {
            // Main focus dot
            Circle()
                .fill(color.opacity(Double(strength)))
                .frame(width: 4 + strength * 6, height: 4 + strength * 6)
                .position(position)

            // Edge highlight for stronger focus areas
            if strength > 0.7 {
                Circle()
                    .stroke(color.opacity(0.8), lineWidth: 1)
                    .frame(width: 8 + strength * 8, height: 8 + strength * 8)
                    .position(position)
            }

            // Pulsing effect for very strong focus
            if strength > 0.8 {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 12 + strength * 10, height: 12 + strength * 10)
                    .position(position)
                    .scaleEffect(1 + sin(currentTime * 3) * 0.1)
            }
        }
        .task {
            // Set up timer to update pulsing animation at ~20 FPS
            // Using .task ensures automatic cancellation when the view disappears
            for await _ in Timer.publish(every: 0.05, on: .main, in: .common).autoconnect().values {
                currentTime = Date().timeIntervalSince1970
            }
        }
    }
}

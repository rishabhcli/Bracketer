import AVFoundation
import CoreVideo
import QuartzCore
import SwiftUI

enum ExposureZebraClassification: Equatable, Sendable {
    case normal
    case shadowClipped
    case highlightClipped
}

struct ExposureZebraThresholds: Equatable, Sendable {
    let shadowLevel: UInt8
    let highlightLevel: UInt8

    init(shadowLevel: UInt8 = 5, highlightLevel: UInt8 = 250) {
        self.shadowLevel = min(shadowLevel, highlightLevel)
        self.highlightLevel = max(shadowLevel, highlightLevel)
    }

    func classification(red: UInt8, green: UInt8, blue: UInt8) -> ExposureZebraClassification {
        let luminance = HistogramFrameAnalyzer.luminance(red: red, green: green, blue: blue)
        if luminance <= shadowLevel { return .shadowClipped }
        if luminance >= highlightLevel { return .highlightClipped }
        return .normal
    }
}

struct ExposureClippingThresholds: Equatable, Sendable {
    let zebra: ExposureZebraThresholds
    let warningFraction: Float

    init(
        zebra: ExposureZebraThresholds = ExposureZebraThresholds(),
        warningFraction: Float = 0.01
    ) {
        self.zebra = zebra
        self.warningFraction = max(0, warningFraction)
    }
}

struct ExposureClippingMetrics: Equatable, Sendable {
    let sampledPixels: Int
    let shadowClippedPixels: Int
    let highlightClippedPixels: Int
    let thresholds: ExposureClippingThresholds

    var shadowClippedFraction: Float {
        guard sampledPixels > 0 else { return 0 }
        return Float(shadowClippedPixels) / Float(sampledPixels)
    }

    var highlightClippedFraction: Float {
        guard sampledPixels > 0 else { return 0 }
        return Float(highlightClippedPixels) / Float(sampledPixels)
    }

    var hasShadowWarning: Bool {
        shadowClippedFraction >= thresholds.warningFraction
    }

    var hasHighlightWarning: Bool {
        highlightClippedFraction >= thresholds.warningFraction
    }
}

struct ExposureZebraRegion: Equatable, Sendable {
    let tileIndex: Int
    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let classification: ExposureZebraClassification
    let strength: Float
}

struct ExposureZebraMap: Equatable, Sendable {
    let columns: Int
    let rows: Int
    let regions: [ExposureZebraRegion]

    var highlightRegionCount: Int {
        regions.filter { $0.classification == .highlightClipped }.count
    }

    var shadowRegionCount: Int {
        regions.filter { $0.classification == .shadowClipped }.count
    }
}

struct FocusPeakingThresholds: Equatable, Sendable {
    let edgeThreshold: UInt8
    let regionWarningFraction: Float

    init(edgeThreshold: UInt8 = 18, regionWarningFraction: Float = 0.2) {
        self.edgeThreshold = edgeThreshold
        self.regionWarningFraction = max(0, min(1, regionWarningFraction))
    }
}

struct FocusPeakingRegion: Equatable, Sendable {
    let tileIndex: Int
    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let strength: Float
}

struct FocusPeakingMap: Equatable, Sendable {
    let columns: Int
    let rows: Int
    let regions: [FocusPeakingRegion]
}

struct HistogramFrameAnalysis: Equatable, Sendable {
    let histogram: HistogramData
    let clipping: ExposureClippingMetrics
    let zebraMap: ExposureZebraMap
    let focusPeakingMap: FocusPeakingMap

    var sampleCount: Int {
        clipping.sampledPixels
    }
}

enum HistogramFrameAnalyzer {
    static func analyzeBGRA(
        buffer: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        stepX: Int = 4,
        stepY: Int = 4,
        thresholds: ExposureClippingThresholds = ExposureClippingThresholds(),
        zebraColumns: Int = 32,
        zebraRows: Int = 24,
        zebraRegionWarningFraction: Float = 0.25,
        focusThresholds: FocusPeakingThresholds = FocusPeakingThresholds()
    ) -> HistogramFrameAnalysis? {
        analyzeBytes(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            stepX: stepX,
            stepY: stepY,
            thresholds: thresholds,
            zebraColumns: zebraColumns,
            zebraRows: zebraRows,
            zebraRegionWarningFraction: zebraRegionWarningFraction,
            focusThresholds: focusThresholds
        ) { offset in
            (
                red: buffer[offset + 2],
                green: buffer[offset + 1],
                blue: buffer[offset]
            )
        }
    }

    static func analyzeBGRABytes(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int? = nil,
        stepX: Int = 4,
        stepY: Int = 4,
        thresholds: ExposureClippingThresholds = ExposureClippingThresholds(),
        zebraColumns: Int = 32,
        zebraRows: Int = 24,
        zebraRegionWarningFraction: Float = 0.25,
        focusThresholds: FocusPeakingThresholds = FocusPeakingThresholds()
    ) -> HistogramFrameAnalysis? {
        let rowBytes = bytesPerRow ?? width * 4
        guard bytes.count >= rowBytes * height else { return nil }

        return bytes.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return nil }
            return analyzeBGRA(
                buffer: baseAddress,
                width: width,
                height: height,
                bytesPerRow: rowBytes,
                stepX: stepX,
                stepY: stepY,
                thresholds: thresholds,
                zebraColumns: zebraColumns,
                zebraRows: zebraRows,
                zebraRegionWarningFraction: zebraRegionWarningFraction,
                focusThresholds: focusThresholds
            )
        }
    }

    static func analyzeRGBABytes(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int? = nil,
        stepX: Int = 4,
        stepY: Int = 4,
        thresholds: ExposureClippingThresholds = ExposureClippingThresholds(),
        zebraColumns: Int = 32,
        zebraRows: Int = 24,
        zebraRegionWarningFraction: Float = 0.25,
        focusThresholds: FocusPeakingThresholds = FocusPeakingThresholds()
    ) -> HistogramFrameAnalysis? {
        let rowBytes = bytesPerRow ?? width * 4
        guard bytes.count >= rowBytes * height else { return nil }

        return analyzeBytes(
            width: width,
            height: height,
            bytesPerRow: rowBytes,
            stepX: stepX,
            stepY: stepY,
            thresholds: thresholds,
            zebraColumns: zebraColumns,
            zebraRows: zebraRows,
            zebraRegionWarningFraction: zebraRegionWarningFraction,
            focusThresholds: focusThresholds
        ) { offset in
            (
                red: bytes[offset],
                green: bytes[offset + 1],
                blue: bytes[offset + 2]
            )
        }
    }

    static func luminance(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
        let value = Float(red) * 0.2126 + Float(green) * 0.7152 + Float(blue) * 0.0722
        return UInt8(min(255, max(0, Int(value))))
    }

    private static func analyzeBytes(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        stepX: Int,
        stepY: Int,
        thresholds: ExposureClippingThresholds,
        zebraColumns: Int,
        zebraRows: Int,
        zebraRegionWarningFraction: Float,
        focusThresholds: FocusPeakingThresholds,
        pixelAt: (Int) -> (red: UInt8, green: UInt8, blue: UInt8)
    ) -> HistogramFrameAnalysis? {
        guard width > 0, height > 0, bytesPerRow >= width * 4 else { return nil }

        var redBins = [Int](repeating: 0, count: 256)
        var greenBins = [Int](repeating: 0, count: 256)
        var blueBins = [Int](repeating: 0, count: 256)
        var luminanceBins = [Int](repeating: 0, count: 256)
        var sampledPixels = 0
        var shadowClippedPixels = 0
        var highlightClippedPixels = 0
        let xStride = max(1, stepX)
        let yStride = max(1, stepY)
        let columns = max(1, zebraColumns)
        let rows = max(1, zebraRows)
        let tileCount = columns * rows
        var tileSampleCounts = [Int](repeating: 0, count: tileCount)
        var tileShadowCounts = [Int](repeating: 0, count: tileCount)
        var tileHighlightCounts = [Int](repeating: 0, count: tileCount)
        var focusTileCandidateCounts = [Int](repeating: 0, count: tileCount)
        var focusTileEdgeCounts = [Int](repeating: 0, count: tileCount)
        var focusTileGradientSums = [Float](repeating: 0, count: tileCount)
        let sampleColumnCount = max(1, ((width - 1) / xStride) + 1)
        var previousRowLuminance = [UInt8?](repeating: nil, count: sampleColumnCount)

        for y in stride(from: 0, to: height, by: yStride) {
            let rowOffset = y * bytesPerRow
            var currentRowLuminance = [UInt8?](repeating: nil, count: sampleColumnCount)
            var previousLuminanceInRow: UInt8?
            var sampleColumn = 0

            for x in stride(from: 0, to: width, by: xStride) {
                let pixelOffset = rowOffset + x * 4
                let pixel = pixelAt(pixelOffset)
                let red = Int(pixel.red)
                let green = Int(pixel.green)
                let blue = Int(pixel.blue)
                let luma = Int(luminance(red: pixel.red, green: pixel.green, blue: pixel.blue))
                let lumaByte = UInt8(luma)

                redBins[red] += 1
                greenBins[green] += 1
                blueBins[blue] += 1
                luminanceBins[luma] += 1

                let classification = thresholds.zebra.classification(red: pixel.red, green: pixel.green, blue: pixel.blue)
                let tileX = min(columns - 1, x * columns / width)
                let tileY = min(rows - 1, y * rows / height)
                let tileIndex = tileY * columns + tileX
                tileSampleCounts[tileIndex] += 1

                var strongestGradient = 0
                var hasFocusNeighbor = false
                if let previousLuminanceInRow {
                    strongestGradient = max(strongestGradient, abs(luma - Int(previousLuminanceInRow)))
                    hasFocusNeighbor = true
                }
                if sampleColumn < previousRowLuminance.count, let aboveLuminance = previousRowLuminance[sampleColumn] {
                    strongestGradient = max(strongestGradient, abs(luma - Int(aboveLuminance)))
                    hasFocusNeighbor = true
                }
                if hasFocusNeighbor {
                    focusTileCandidateCounts[tileIndex] += 1
                    if strongestGradient >= Int(focusThresholds.edgeThreshold) {
                        focusTileEdgeCounts[tileIndex] += 1
                        focusTileGradientSums[tileIndex] += Float(strongestGradient) / 255.0
                    }
                }

                switch classification {
                case .normal:
                    break
                case .shadowClipped:
                    shadowClippedPixels += 1
                    tileShadowCounts[tileIndex] += 1
                case .highlightClipped:
                    highlightClippedPixels += 1
                    tileHighlightCounts[tileIndex] += 1
                }

                sampledPixels += 1
                previousLuminanceInRow = lumaByte
                if sampleColumn < currentRowLuminance.count {
                    currentRowLuminance[sampleColumn] = lumaByte
                }
                sampleColumn += 1
            }

            previousRowLuminance = currentRowLuminance
        }

        guard sampledPixels > 0 else { return nil }

        let clipping = ExposureClippingMetrics(
            sampledPixels: sampledPixels,
            shadowClippedPixels: shadowClippedPixels,
            highlightClippedPixels: highlightClippedPixels,
            thresholds: thresholds
        )
        let histogram = HistogramData(
            red: normalized(redBins),
            green: normalized(greenBins),
            blue: normalized(blueBins),
            luminance: normalized(luminanceBins),
            clipping: clipping
        )
        let zebraMap = ExposureZebraMap(
            columns: columns,
            rows: rows,
            regions: zebraRegions(
                columns: columns,
                rows: rows,
                tileSampleCounts: tileSampleCounts,
                tileShadowCounts: tileShadowCounts,
                tileHighlightCounts: tileHighlightCounts,
                warningFraction: zebraRegionWarningFraction
            )
        )
        let focusPeakingMap = FocusPeakingMap(
            columns: columns,
            rows: rows,
            regions: focusPeakingRegions(
                columns: columns,
                rows: rows,
                tileCandidateCounts: focusTileCandidateCounts,
                tileEdgeCounts: focusTileEdgeCounts,
                tileGradientSums: focusTileGradientSums,
                thresholds: focusThresholds
            )
        )

        return HistogramFrameAnalysis(
            histogram: histogram,
            clipping: clipping,
            zebraMap: zebraMap,
            focusPeakingMap: focusPeakingMap
        )
    }

    private static func normalized(_ bins: [Int]) -> [Float] {
        let peak = max(Float(bins.max() ?? 0), 1)
        return bins.map { Float($0) / peak }
    }

    private static func zebraRegions(
        columns: Int,
        rows: Int,
        tileSampleCounts: [Int],
        tileShadowCounts: [Int],
        tileHighlightCounts: [Int],
        warningFraction: Float
    ) -> [ExposureZebraRegion] {
        let warning = max(0, min(1, warningFraction))
        let tileWidth = 1.0 / Float(columns)
        let tileHeight = 1.0 / Float(rows)

        return tileSampleCounts.indices.compactMap { index in
            let sampleCount = tileSampleCounts[index]
            guard sampleCount > 0 else { return nil }

            let shadowFraction = Float(tileShadowCounts[index]) / Float(sampleCount)
            let highlightFraction = Float(tileHighlightCounts[index]) / Float(sampleCount)
            let classification: ExposureZebraClassification
            let strength: Float

            if highlightFraction >= shadowFraction {
                classification = .highlightClipped
                strength = highlightFraction
            } else {
                classification = .shadowClipped
                strength = shadowFraction
            }

            guard strength > 0, strength >= warning else { return nil }

            let column = index % columns
            let row = index / columns
            return ExposureZebraRegion(
                tileIndex: index,
                x: Float(column) * tileWidth,
                y: Float(row) * tileHeight,
                width: tileWidth,
                height: tileHeight,
                classification: classification,
                strength: min(1, strength)
            )
        }
    }

    private static func focusPeakingRegions(
        columns: Int,
        rows: Int,
        tileCandidateCounts: [Int],
        tileEdgeCounts: [Int],
        tileGradientSums: [Float],
        thresholds: FocusPeakingThresholds
    ) -> [FocusPeakingRegion] {
        let tileWidth = 1.0 / Float(columns)
        let tileHeight = 1.0 / Float(rows)

        return tileCandidateCounts.indices.compactMap { index in
            let candidateCount = tileCandidateCounts[index]
            guard candidateCount > 0 else { return nil }

            let edgeCount = tileEdgeCounts[index]
            let edgeFraction = Float(edgeCount) / Float(candidateCount)
            guard edgeFraction >= thresholds.regionWarningFraction else { return nil }

            let averageGradient = edgeCount > 0 ? tileGradientSums[index] / Float(edgeCount) : 0
            let column = index % columns
            let row = index / columns

            return FocusPeakingRegion(
                tileIndex: index,
                x: Float(column) * tileWidth,
                y: Float(row) * tileHeight,
                width: tileWidth,
                height: tileHeight,
                strength: min(1, max(edgeFraction, averageGradient))
            )
        }
    }
}

/// Processes camera feed frames to produce real-time histogram data.
/// Attaches as an AVCaptureVideoDataOutput delegate, samples pixels at reduced rate,
/// and publishes histogram bins for the UI.
final class HistogramProcessor: NSObject, ObservableObject, @unchecked Sendable {
    @Published var histogramData: HistogramData?
    @Published var frameAnalysis: HistogramFrameAnalysis?
    @Published var processingDiagnostics = CameraRuntimeDiagnostics()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "bracketer.histogram", qos: .utility)
    private var lastProcessedTime: CFAbsoluteTime = 0
    private let processingInterval: CFAbsoluteTime = 0.2 // ~5 FPS
    var skipProcessing = false

    override init() {
        super.init()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
    }

    func attachToSession(_ session: AVCaptureSession) {
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }

    func detachFromSession(_ session: AVCaptureSession) {
        session.removeOutput(videoOutput)
    }
}

extension HistogramProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedTime >= processingInterval else { return }
        guard !skipProcessing else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let processingStart = CACurrentMediaTime()

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        guard let analysis = HistogramFrameAnalyzer.analyzeBGRA(
            buffer: buffer,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        ) else { return }
        let durationMilliseconds = max(0, Int(((CACurrentMediaTime() - processingStart) * 1_000).rounded()))
        let severity = CameraRuntimePerformanceThresholds.severity(
            durationMilliseconds: durationMilliseconds,
            warningThresholdMilliseconds: CameraRuntimePerformanceThresholds.histogramProcessingWarningMilliseconds
        )

        DispatchQueue.main.async {
            self.frameAnalysis = analysis
            self.histogramData = analysis.histogram
            self.processingDiagnostics = self.processingDiagnostics.recording(
                category: .histogram,
                severity: severity,
                title: "Histogram Frame Processed",
                detail: "\(analysis.sampleCount) sampled pixel(s) from \(width)x\(height) frame.",
                durationMilliseconds: durationMilliseconds
            )
        }
    }
}

import AVFoundation
import CoreVideo
import SwiftUI

/// Processes camera feed frames to produce real-time histogram data.
/// Attaches as an AVCaptureVideoDataOutput delegate, samples pixels at reduced rate,
/// and publishes histogram bins for the UI.
final class HistogramProcessor: NSObject, ObservableObject, @unchecked Sendable {
    @Published var histogramData: HistogramData?

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

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // 256-bin histograms
        var redBins = [Int](repeating: 0, count: 256)
        var greenBins = [Int](repeating: 0, count: 256)
        var blueBins = [Int](repeating: 0, count: 256)
        var lumBins = [Int](repeating: 0, count: 256)

        // Sample every 4th pixel in both dimensions (16x reduction)
        let stepX = 4
        let stepY = 4
        var sampleCount = 0

        for y in stride(from: 0, to: height, by: stepY) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width, by: stepX) {
                let pixelOffset = rowOffset + x * 4
                // BGRA format
                let b = Int(buffer[pixelOffset])
                let g = Int(buffer[pixelOffset + 1])
                let r = Int(buffer[pixelOffset + 2])

                redBins[r] += 1
                greenBins[g] += 1
                blueBins[b] += 1

                // ITU-R BT.709 luminance
                let lum = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
                lumBins[min(255, lum)] += 1
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return }

        // Normalize to 0...1
        let maxRed = Float(redBins.max() ?? 1)
        let maxGreen = Float(greenBins.max() ?? 1)
        let maxBlue = Float(blueBins.max() ?? 1)
        let maxLum = Float(lumBins.max() ?? 1)

        let red = redBins.map { Float($0) / maxRed }
        let green = greenBins.map { Float($0) / maxGreen }
        let blue = blueBins.map { Float($0) / maxBlue }
        let luminance = lumBins.map { Float($0) / maxLum }

        let data = HistogramData(red: red, green: green, blue: blue, luminance: luminance)

        DispatchQueue.main.async {
            self.histogramData = data
        }
    }
}

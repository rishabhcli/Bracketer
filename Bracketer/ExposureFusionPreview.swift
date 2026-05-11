import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct ExposureFusionPreviewInput: Equatable {
    let evOffset: Float
    let image: CIImage

    init(evOffset: Float, image: CIImage) {
        self.evOffset = evOffset
        self.image = image
    }

    static func rgbaBytes(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        evOffset: Float
    ) -> ExposureFusionPreviewInput? {
        guard width > 0, height > 0, bytes.count >= width * height * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let image = CIImage(
            bitmapData: Data(bytes.prefix(width * height * 4)),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return ExposureFusionPreviewInput(evOffset: evOffset, image: image)
    }
}

struct ExposureFusionPreview: Equatable, Sendable {
    let width: Int
    let height: Int
    let rgbaBytes: [UInt8]
    let sourceCount: Int
    let evOffsets: [Float]

    var summary: String {
        guard let minEV = evOffsets.min(), let maxEV = evOffsets.max() else {
            return "No exposure fusion preview"
        }

        return "\(sourceCount) exposures fused from \(BracketEVFormatter.displayLabel(for: minEV)) to \(BracketEVFormatter.displayLabel(for: maxEV))"
    }

    var accessibilityValue: String {
        "\(summary) | \(width)x\(height)"
    }

    func makeCGImage() -> CGImage? {
        guard width > 0, height > 0, rgbaBytes.count >= width * height * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = Data(rgbaBytes.prefix(width * height * 4)) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

enum ExposureFusionPreviewGenerator {
    static func makePreview(
        inputs: [ExposureFusionPreviewInput],
        context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    ) -> ExposureFusionPreview? {
        guard let first = inputs.first else { return nil }
        let extent = first.image.extent.integral
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }
        guard inputs.allSatisfy({ $0.image.extent.integral.size == extent.size }) else { return nil }

        let renderedInputs = inputs.compactMap { input -> (evOffset: Float, bytes: [UInt8])? in
            guard let adjustedImage = exposureAdjustedImage(input.image, evOffset: -input.evOffset) else { return nil }
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            context.render(
                adjustedImage.cropped(to: extent),
                toBitmap: &bytes,
                rowBytes: width * 4,
                bounds: extent,
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            return (input.evOffset, bytes)
        }
        guard renderedInputs.count == inputs.count else { return nil }

        let fusedBytes = fusedRGBABytes(renderedInputs.map(\.bytes), width: width, height: height)
        return ExposureFusionPreview(
            width: width,
            height: height,
            rgbaBytes: fusedBytes,
            sourceCount: renderedInputs.count,
            evOffsets: renderedInputs.map(\.evOffset).sorted()
        )
    }

    static func makeDeterministicPreview(for sequence: BracketReviewSequence) -> ExposureFusionPreview? {
        let width = 3
        let height = 1
        let sceneLuminance: [Float] = [32, 128, 224]
        let inputs = sequence.shots.compactMap { shot in
            let exposureScale = pow(2.0, shot.evOffset)
            let bytes = sceneLuminance.reduce(into: [UInt8]()) { result, base in
                let value = UInt8(clamping: Int((base * exposureScale).rounded()))
                result.append(value)
                result.append(value)
                result.append(value)
                result.append(255)
            }
            return ExposureFusionPreviewInput.rgbaBytes(bytes, width: width, height: height, evOffset: shot.evOffset)
        }

        return makePreview(inputs: inputs)
    }

    private static func exposureAdjustedImage(_ image: CIImage, evOffset: Float) -> CIImage? {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = evOffset
        return filter.outputImage
    }

    private static func fusedRGBABytes(_ images: [[UInt8]], width: Int, height: Int) -> [UInt8] {
        let pixelCount = width * height
        var output = [UInt8](repeating: 0, count: pixelCount * 4)

        for pixelIndex in 0..<pixelCount {
            var redSum: Float = 0
            var greenSum: Float = 0
            var blueSum: Float = 0
            var alphaSum: Float = 0
            var weightSum: Float = 0
            let offset = pixelIndex * 4

            for image in images {
                let red = Float(image[offset])
                let green = Float(image[offset + 1])
                let blue = Float(image[offset + 2])
                let alpha = Float(image[offset + 3])
                let weight = wellExposednessWeight(red: red, green: green, blue: blue)
                redSum += red * weight
                greenSum += green * weight
                blueSum += blue * weight
                alphaSum += alpha * weight
                weightSum += weight
            }

            let divisor = max(weightSum, 0.0001)
            output[offset] = UInt8(clamping: Int((redSum / divisor).rounded()))
            output[offset + 1] = UInt8(clamping: Int((greenSum / divisor).rounded()))
            output[offset + 2] = UInt8(clamping: Int((blueSum / divisor).rounded()))
            output[offset + 3] = UInt8(clamping: Int((alphaSum / divisor).rounded()))
        }

        return output
    }

    private static func wellExposednessWeight(red: Float, green: Float, blue: Float) -> Float {
        let luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
        let distanceFromMidtone = abs(luminance - 0.5) * 2
        let midtoneWeight = pow(max(0, 1 - distanceFromMidtone), 2)
        return max(0.05, midtoneWeight)
    }
}

import SwiftUI
import MapKit
import CoreLocation
import Photos
import UIKit

/// Comprehensive EXIF metadata viewer with map integration and mini-histogram
/// Professional-grade metadata display for photography workflow
struct EXIFViewer: View {
    let asset: PHAsset
    let metadata: [String: Any]
    let image: UIImage?
    let onDismiss: () -> Void
    @State private var region = MKCoordinateRegion()
    @State private var histogramData: HistogramData?
    @State private var showDepthMapViewer = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        mainScrollView
            .overlay(depthMapOverlay)
            .onAppear {
                generateHistogramData()
            }
    }
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                histogramSection
                cameraSettingsSection
                technicalDetailsSection
                locationSection
                depthAnalysisSection
                rawExifSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private var headerSection: some View {
        HStack {
            Text("Image Information")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button {
                onDismiss()
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
            .accessibilityIdentifier("viewer.exifCloseButton")
        }
    }
    
    @ViewBuilder
    private var histogramSection: some View {
        if let histogramData = histogramData {
            MiniHistogramView(data: histogramData)
                .frame(height: 80)
                .cornerRadius(8)
        }
    }
    
    private var cameraSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Camera Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                EXIFItemView(
                    icon: "camera.aperture",
                    title: "Aperture",
                    value: formatAperture(metadata["FNumber"] as? Double)
                )

                EXIFItemView(
                    icon: "timer",
                    title: "Shutter Speed",
                    value: formatShutterSpeed(metadata["ExposureTime"] as? Double)
                )

                EXIFItemView(
                    icon: "lightbulb",
                    title: "ISO",
                    value: formatISO(metadata["ISOSpeedRatings"] as? [NSNumber])
                )

                EXIFItemView(
                    icon: "ruler",
                    title: "Focal Length",
                    value: formatFocalLength(metadata["FocalLength"] as? Double)
                )

                EXIFItemView(
                    icon: "camera.filters",
                    title: "White Balance",
                    value: formatWhiteBalance(metadata["WhiteBalance"] as? Int)
                )

                EXIFItemView(
                    icon: "flashlight.off.fill",
                    title: "Flash",
                    value: formatFlash(metadata["Flash"] as? Int)
                )
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Technical Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                EXIFItemView(
                    icon: "camera",
                    title: "Camera",
                    value: formatCameraInfo(metadata)
                )

                EXIFItemView(
                    icon: "cpu",
                    title: "Lens",
                    value: formatLensInfo(metadata)
                )

                EXIFItemView(
                    icon: "photo",
                    title: "Resolution",
                    value: formatResolution(metadata)
                )

                EXIFItemView(
                    icon: "doc",
                    title: "File Size",
                    value: formatFileSize(asset)
                )

                EXIFItemView(
                    icon: "calendar",
                    title: "Date Taken",
                    value: formatDate(asset.creationDate)
                )

                EXIFItemView(
                    icon: "mappin",
                    title: "GPS",
                    value: asset.location != nil ? "Available" : "Not Available"
                )
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var locationSection: some View {
        if let location = asset.location {
            VStack(alignment: .leading, spacing: 12) {
                Text("Location")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                locationMapView(for: location)

                Text(formatLocationDetails(location))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
    
    private func locationMapView(for location: CLLocation) -> some View {
        Map(initialPosition: .region(region)) {
            Marker("Photo", coordinate: location.coordinate)
        }
        .frame(height: 150)
        .cornerRadius(12)
        .allowsHitTesting(false)
        .onAppear {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    @ViewBuilder
    private var depthAnalysisSection: some View {
        if isPortraitMode {
            VStack(alignment: .leading, spacing: 12) {
                Text("Depth Analysis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                depthAnalysisButton
            }
            .padding(16)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
    
    private var depthAnalysisButton: some View {
        Button {
            showDepthMapViewer = true
        } label: {
            HStack {
                Image(systemName: "view.3d")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Depth Map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("3D focal plane analysis")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .liquidGlass(intensity: .regular, tint: .blue.opacity(0.35), interactive: true)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var rawExifSection: some View {
        DisclosureGroup {
            rawExifContent
        } label: {
            Text("Raw EXIF Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var rawExifContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                    exifDataRow(key: key)
                    Divider()
                        .background(Color.white.opacity(0.2))
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func exifDataRow(key: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 120, alignment: .leading)

            Text(String(describing: metadata[key] ?? "N/A"))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
        }
    }
    
    @ViewBuilder
    private var depthMapOverlay: some View {
        if showDepthMapViewer {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showDepthMapViewer = false
                }
            
            DepthMapViewer(image: image, depthData: nil)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private var isPortraitMode: Bool {
        // Check if this is a portrait mode photo
        // This would typically check the metadata for portrait mode indicators
        // For now, we'll assume it's portrait if we have depth-related metadata
        return metadata["DepthData"] != nil || metadata["PortraitEffectsMatte"] != nil
    }

    private func generateHistogramData() {
        guard let cgImage = image?.cgImage else { return }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel: Int = 4
        let bytesPerRow: Int = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: Int(height * bytesPerRow))

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var redBins = [Int](repeating: 0, count: 256)
        var greenBins = [Int](repeating: 0, count: 256)
        var blueBins = [Int](repeating: 0, count: 256)
        var lumBins = [Int](repeating: 0, count: 256)

        // Sample every 4th pixel in both dimensions for performance
        let step = 4
        for y in stride(from: 0, to: height, by: step) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width, by: step) {
                let offset = rowOffset + x * bytesPerPixel
                let r = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let b = Int(pixelData[offset + 2])

                redBins[r] += 1
                greenBins[g] += 1
                blueBins[b] += 1

                let lum = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
                lumBins[min(255, lum)] += 1
            }
        }

        let maxR = Float(redBins.max() ?? 1)
        let maxG = Float(greenBins.max() ?? 1)
        let maxB = Float(blueBins.max() ?? 1)
        let maxL = Float(lumBins.max() ?? 1)

        histogramData = HistogramData(
            red: redBins.map { Float($0) / maxR },
            green: greenBins.map { Float($0) / maxG },
            blue: blueBins.map { Float($0) / maxB },
            luminance: lumBins.map { Float($0) / maxL }
        )
    }

    private func formatAperture(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "f/%.1f", value)
    }

    private func formatShutterSpeed(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        if value >= 1.0 {
            return String(format: "%.1fs", value)
        } else {
            let fraction = 1.0 / value
            if fraction < 10 {
                return String(format: "1/%.1f", fraction)
            } else {
                return String(format: "1/%.0f", fraction)
            }
        }
    }

    private func formatISO(_ value: [NSNumber]?) -> String {
        guard let value = value, let iso = value.first?.intValue else { return "N/A" }
        return "\(iso)"
    }

    private func formatFocalLength(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.0fmm", value)
    }

    private func formatWhiteBalance(_ value: Int?) -> String {
        guard let value = value else { return "N/A" }
        switch value {
        case 0: return "Auto"
        case 1: return "Manual"
        default: return "Unknown"
        }
    }

    private func formatFlash(_ value: Int?) -> String {
        guard let value = value else { return "N/A" }
        return value == 0 ? "No Flash" : "Flash Fired"
    }

    private func formatCameraInfo(_ metadata: [String: Any]) -> String {
        let make = metadata["Make"] as? String ?? ""
        let model = metadata["Model"] as? String ?? ""
        return "\(make) \(model)".trimmingCharacters(in: .whitespaces)
    }

    private func formatLensInfo(_ metadata: [String: Any]) -> String {
        if let lensModel = metadata["LensModel"] as? String {
            return lensModel
        }
        return "Unknown Lens"
    }

    private func formatResolution(_ metadata: [String: Any]) -> String {
        let width = metadata["PixelWidth"] as? Int ?? 0
        let height = metadata["PixelHeight"] as? Int ?? 0
        return "\(width) × \(height)"
    }

    private func formatFileSize(_ asset: PHAsset) -> String {
        // This would need to be calculated from the asset
        // For now, return a placeholder
        return "~\(asset.pixelWidth * asset.pixelHeight * 3 / 1_000_000)MB"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        return dateFormatter.string(from: date)
    }

    private func formatLocationDetails(_ location: CLLocation) -> String {
        let latitude = String(format: "%.4f°", location.coordinate.latitude)
        let longitude = String(format: "%.4f°", location.coordinate.longitude)
        let altitude = String(format: "%.0fm", location.altitude)
        return "Lat: " + latitude + ", Lon: " + longitude + ", Alt: " + altitude
    }
}

// MARK: - Supporting Views and Models

struct EXIFItemView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MiniHistogramView: View {
    let data: HistogramData

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.3)
                    .cornerRadius(4)

                // RGB Histogram bars
                HStack(spacing: 1) {
                    ForEach(0..<64) { index in
                        VStack(spacing: 0) {
                            // Red
                            Rectangle()
                                .fill(Color.red.opacity(0.8))
                                .frame(height: CGFloat(data.red[index * 4]) * geo.size.height * 0.8)

                            // Green
                            Rectangle()
                                .fill(Color.green.opacity(0.8))
                                .frame(height: CGFloat(data.green[index * 4]) * geo.size.height * 0.8)

                            // Blue
                            Rectangle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(height: CGFloat(data.blue[index * 4]) * geo.size.height * 0.8)
                        }
                        .frame(width: geo.size.width / 64)
                    }
                }

                // Grid lines
                Path { path in
                    let height = geo.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.25))
                    path.addLine(to: CGPoint(x: geo.size.width, y: height * 0.25))

                    path.move(to: CGPoint(x: 0, y: height * 0.5))
                    path.addLine(to: CGPoint(x: geo.size.width, y: height * 0.5))

                    path.move(to: CGPoint(x: 0, y: height * 0.75))
                    path.addLine(to: CGPoint(x: geo.size.width, y: height * 0.75))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

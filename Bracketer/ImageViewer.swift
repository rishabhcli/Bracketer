import SwiftUI
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import MapKit

/// High-performance image viewer for bracketed photo sequences
/// Provides RAW/processed toggle, navigation, and professional review tools
struct ImageViewer: View {
    let onDismiss: () -> Void
    @State private var bracketAssets: [PHAsset]
    @State private var currentIndex = 0
    @State private var showProcessed = true
    @State private var showMetadata = false
    @State private var isLoading = false
    @State private var currentImage: UIImage?
    @State private var currentMetadata: [String: Any]?
    @State private var showDeleteConfirmation = false

    private let imageManager = PHCachingImageManager()

    init(bracketAssets: [PHAsset], onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _bracketAssets = State(initialValue: bracketAssets)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = currentImage {
                // Main image display
                ImageViewerContent(
                    image: image,
                    bracketAssets: bracketAssets,
                    currentIndex: currentIndex,
                    showProcessed: showProcessed,
                    onIndexChange: { newIndex in
                        currentIndex = newIndex
                        loadImage(at: newIndex)
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { gesture in
                            let horizontalAmount = gesture.translation.width
                            let verticalAmount = gesture.translation.height

                            if abs(horizontalAmount) > abs(verticalAmount) {
                                // Horizontal swipe - navigate bracket sequence
                                if horizontalAmount > 0 && currentIndex > 0 {
                                    currentIndex -= 1
                                    loadImage(at: currentIndex)
                                    HapticManager.shared.gridTypeChanged()
                                } else if horizontalAmount < 0 && currentIndex < bracketAssets.count - 1 {
                                    currentIndex += 1
                                    loadImage(at: currentIndex)
                                    HapticManager.shared.gridTypeChanged()
                                }
                            }
                        }
                )
            } else {
                // Loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading image...")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                }
            }

            // Top control bar
            VStack {
                HStack {
                    Button {
                        withAnimation(.easeInOut) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .liquidGlass(intensity: .regular, tint: .white.opacity(0.15), interactive: true)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")

                    Spacer()

                    // Bracket navigation
                    if bracketAssets.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<bracketAssets.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.yellow : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(16)
                    }

                    if currentIndex < bracketAssets.count {
                        let evText = evLabelForCurrentIndex()
                        Text(evText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                    }

                    Spacer()

                    // Metadata toggle
                    Button {
                        showMetadata.toggle()
                        HapticManager.shared.gridTypeChanged()
                    } label: {
                        Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(showMetadata ? .yellow : .white)
                            .padding(12)
                            .background(
                                Circle()
                                    .liquidGlass(intensity: .regular, tint: showMetadata ? .yellow.opacity(0.25) : .white.opacity(0.12), interactive: true)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo Info")
                    .accessibilityValue(showMetadata ? "Showing" : "Hidden")
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Bottom control bar
                HStack {
                    // RAW/Processed toggle
                    Button {
                        showProcessed.toggle()
                        loadImage(at: currentIndex, forceReload: true)
                        HapticManager.shared.gridTypeChanged()
                    } label: {
                        HStack(spacing: 8) {
                            Text(showProcessed ? "JPG" : "RAW")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Image(systemName: showProcessed ? "photo" : "r.square")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .liquidGlass(intensity: .regular, tint: .white.opacity(0.12), interactive: true)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            shareCurrentImage()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .liquidGlass(intensity: .regular, tint: .white.opacity(0.12), interactive: true)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share Photo")

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                                .padding(12)
                                .background(
                                    Circle()
                                        .liquidGlass(intensity: .prominent, tint: .red.opacity(0.25), interactive: true)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete Photo")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            // EXIF Viewer overlay
            if showMetadata, let metadata = currentMetadata, let image = currentImage {
                EXIFViewer(
                    asset: bracketAssets[currentIndex],
                    metadata: metadata,
                    image: image,
                    onDismiss: { showMetadata = false }
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Delete Photo?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteCurrentImage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently deleted from your library.")
        }
        .onAppear {
            loadImage(at: currentIndex)
        }
        .onDisappear {
            imageManager.stopCachingImagesForAllAssets()
        }
    }

    private func loadImage(at index: Int, forceReload: Bool = false) {
        guard index >= 0 && index < bracketAssets.count else { return }

        isLoading = true
        let asset = bracketAssets[index]

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        // Get screen from window scene context instead of deprecated UIScreen.main
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        let screenBounds = screen?.bounds ?? CGRect(x: 0, y: 0, width: 390, height: 844)
        let screenScale = screen?.scale ?? 3.0
        let targetSize = CGSize(width: screenBounds.width * screenScale,
                               height: screenBounds.height * screenScale)

        imageManager.requestImage(for: asset,
                                targetSize: targetSize,
                                contentMode: .aspectFit,
                                options: options) { image, info in
            DispatchQueue.main.async {
                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    Logger.error("Failed to load image: \(error.localizedDescription)")
                }

                self.currentImage = image
                self.isLoading = false

                // Load metadata
                if image != nil {
                    self.loadMetadata(for: asset)
                }
            }
        }
    }

    private func loadMetadata(for asset: PHAsset) {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        asset.requestContentEditingInput(with: options) { input, info in
            guard let input, let fullSizeImageURL = input.fullSizeImageURL else {
                DispatchQueue.main.async {
                    self.currentMetadata = nil
                }
                return
            }

            let fullImage = CIImage(contentsOf: fullSizeImageURL)
            DispatchQueue.main.async {
                self.currentMetadata = fullImage?.properties
            }
        }
    }

    private func shareCurrentImage() {
        guard currentIndex >= 0 && currentIndex < bracketAssets.count else { return }

        let asset = bracketAssets[currentIndex]
        let resources = PHAssetResource.assetResources(for: asset)

        // Prefer original RAW file, fall back to first available resource
        let resource = resources.first { $0.type == .alternatePhoto } ?? resources.first
        guard let fileResource = resource else {
            // Fall back to sharing the UIImage if no resource found
            if let image = currentImage {
                presentShareSheet(items: [image])
            }
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = fileResource.originalFilename
        let tempURL = tempDir.appendingPathComponent(fileName)

        // Clean up any existing temp file
        try? FileManager.default.removeItem(at: tempURL)

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().writeData(for: fileResource, toFile: tempURL, options: options) { error in
            DispatchQueue.main.async {
                if let error = error {
                    Logger.error("Failed to export photo for sharing: \(error.localizedDescription)")
                    // Fall back to UIImage sharing
                    if let image = self.currentImage {
                        self.presentShareSheet(items: [image])
                    }
                } else {
                    self.presentShareSheet(items: [tempURL])
                }
            }
        }
    }

    private func presentShareSheet(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // iPad popover anchor
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.maxY - 100, width: 0, height: 0)
            window.rootViewController?.present(activityVC, animated: true)
        }
    }

    private func deleteCurrentImage() {
        guard currentIndex >= 0 && currentIndex < bracketAssets.count else { return }

        let asset = bracketAssets[currentIndex]

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    Logger.photo("Deleted bracket photo at index \(self.currentIndex)")
                    HapticManager.shared.gridTypeChanged()
                    self.bracketAssets.remove(at: self.currentIndex)
                    self.currentMetadata = nil
                    self.currentImage = nil
                    self.showMetadata = false

                    if self.bracketAssets.isEmpty {
                        self.onDismiss()
                    } else if self.currentIndex >= self.bracketAssets.count {
                        self.currentIndex = max(0, self.currentIndex - 1)
                        self.loadImage(at: self.currentIndex)
                    } else {
                        self.loadImage(at: self.currentIndex)
                    }
                }
            } else if let error = error {
                Logger.error("Failed to delete asset: \(error.localizedDescription)")
            }
        }
    }
    
    private func evLabelForCurrentIndex() -> String {
        guard currentIndex >= 0 && currentIndex < bracketAssets.count else { return "" }
        // Try to infer from filename pattern in localIdentifier or metadata loaded earlier
        // Since Photos API doesn't expose filename directly here, fall back to index mapping
        // Map index to planned order [0EV, +EV, -EV] for 3 shots or [0, +, -, +2, -2]
        switch bracketAssets.count {
        case 3:
            switch currentIndex { case 0: return "0 EV"; case 1: return "+ EV"; case 2: return "− EV"; default: return "" }
        case 5:
            switch currentIndex { case 0: return "0 EV"; case 1: return "+ EV"; case 2: return "− EV"; case 3: return "+2 EV"; case 4: return "−2 EV"; default: return "" }
        default:
            return ""
        }
    }
}

struct ImageViewerContent: View {
    let image: UIImage
    let bracketAssets: [PHAsset]
    let currentIndex: Int
    let showProcessed: Bool
    let onIndexChange: (Int) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                scale = min(max(scale, 1.0), 4.0)
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = value.translation
                            }
                        }
                        .onEnded { _ in
                            if scale > 1.0 {
                                withAnimation(.spring()) {
                                    offset = .zero
                                }
                            }
                        }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Photo \(currentIndex + 1) of \(bracketAssets.count)")
        }
    }
}


// Preview provider for testing
struct ImageViewer_Previews: PreviewProvider {
    static var previews: some View {
        // This would need actual PHAsset objects for proper preview
        Text("Image Viewer Preview")
    }
}

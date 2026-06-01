import SwiftUI
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import MapKit
import QuartzCore

/// High-performance image viewer for bracketed photo sequences
/// Provides RAW/processed toggle, navigation, and professional review tools
struct ImageViewer: View {
    let onDismiss: () -> Void
    let bracketManifest: BracketManifest?
    let intelligenceAvailability: IntelligenceFeatureAvailability
    let onResourceInspectionUpdate: (BracketProjectResourceInspection.ShotResources) -> Void
    let onThumbnailInspectionUpdate: (BracketProjectThumbnailInspection.ShotThumbnail) -> Void
    @State private var bracketAssets: [PHAsset]
    @State private var reviewSequence: BracketReviewSequence?
    @State private var currentIndex = 0
    @State private var showProcessed = true
    @State private var showMetadata = false
    @State private var isLoading = false
    @State private var currentImage: UIImage?
    @State private var currentMetadata: [String: Any]?
    @State private var showDeleteConfirmation = false
    @State private var reviewDiagnostics = CameraRuntimeDiagnostics()
    @State private var refreshedNarrativeRun: BracketReviewNarrativeRun?
    @State private var isGeneratingNarrative = false
    @State private var isNarrativeDismissed = false

    private let imageManager = PHCachingImageManager()

    init(
        bracketAssets: [PHAsset],
        reviewSequence: BracketReviewSequence? = nil,
        bracketManifest: BracketManifest? = nil,
        intelligenceAvailability: IntelligenceFeatureAvailability = .simulatorUnsupported,
        onResourceInspectionUpdate: @escaping (BracketProjectResourceInspection.ShotResources) -> Void = { _ in },
        onThumbnailInspectionUpdate: @escaping (BracketProjectThumbnailInspection.ShotThumbnail) -> Void = { _ in },
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        self.bracketManifest = bracketManifest
        self.intelligenceAvailability = intelligenceAvailability
        self.onResourceInspectionUpdate = onResourceInspectionUpdate
        self.onThumbnailInspectionUpdate = onThumbnailInspectionUpdate
        _bracketAssets = State(initialValue: bracketAssets)
        _reviewSequence = State(initialValue: reviewSequence)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = currentImage {
                // Main image display
                ImageViewerContent(
                    image: image,
                    assetCount: bracketAssets.count,
                    currentIndex: currentIndex,
                    showProcessed: showProcessed,
                    onIndexChange: { newIndex in
                        selectImage(at: newIndex)
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
                                    selectImage(at: currentIndex - 1)
                                    HapticManager.shared.gridTypeChanged()
                                } else if horizontalAmount < 0 && currentIndex < bracketAssets.count - 1 {
                                    selectImage(at: currentIndex + 1)
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

            BracketLiveReviewChrome(
                itemCount: bracketAssets.count,
                currentIndex: currentIndex,
                selectedEVLabel: evLabelForCurrentIndex(),
                selectedShot: currentReviewShot,
                showMetadata: showMetadata,
                representationTitle: showProcessed ? "JPG" : "RAW",
                representationIcon: showProcessed ? "photo" : "r.square",
                representationAccessibilityValue: reviewRepresentationAccessibilityValue,
                manifestJSON: manifestJSONString,
                onDismiss: onDismiss,
                onPrevious: { selectImage(at: currentIndex - 1) },
                onNext: { selectImage(at: currentIndex + 1) },
                onToggleMetadata: {
                    showMetadata.toggle()
                    HapticManager.shared.gridTypeChanged()
                },
                onToggleRepresentation: {
                    toggleRepresentation()
                    loadImage(at: currentIndex, forceReload: true)
                    HapticManager.shared.gridTypeChanged()
                },
                onShare: shareCurrentImage,
                onDelete: { showDeleteConfirmation = true }
            )
            ReviewFixtureProbe(
                identifier: "review.diagnostics.summary",
                label: "Review Diagnostics Summary",
                value: reviewDiagnostics.summaryAccessibilityValue
            )
            ReviewFixtureProbe(
                identifier: "review.diagnostics.latest",
                label: "Review Latest Diagnostic",
                value: reviewDiagnostics.latestAccessibilityValue
            )
            ReviewFixtureProbe(
                identifier: "review.live.manifestRecipe",
                label: "Live Manifest Recipe",
                value: manifestRecipeAccessibilityValue
            )

            if let currentNarrativeRun, !isNarrativeDismissed {
                BracketReviewNarrativeCard(
                    run: currentNarrativeRun,
                    isLoading: isGeneratingNarrative,
                    onRegenerate: regenerateNarrative,
                    onDismiss: { isNarrativeDismissed = true }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 116)
                .frame(maxHeight: .infinity, alignment: .bottom)
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

    private var currentReviewShot: BracketReviewShotSummary? {
        reviewSequence?.selecting(index: currentIndex).selectedShot
    }

    private var manifestJSONString: String? {
        try? bracketManifest?.jsonString()
    }

    private var manifestRecipeAccessibilityValue: String {
        bracketManifest?.recipe?.accessibilityValue ?? "No applied bracket recipe"
    }

    private var reviewRepresentationAccessibilityValue: String {
        reviewSequence?.selectedRepresentationAvailabilityLabel ?? (showProcessed ? "Processed" : "RAW")
    }

    private var narrativeRequest: BracketReviewNarrativeRequest? {
        guard let bracketManifest else { return nil }
        return BracketReviewNarrativeRequest.make(
            context: BracketNarrativeContext.make(
                manifest: bracketManifest,
                sequence: reviewSequence,
                intelligenceAvailability: intelligenceAvailability
            )
        )
    }

    private var currentNarrativeRun: BracketReviewNarrativeRun? {
        if let refreshedNarrativeRun {
            return refreshedNarrativeRun
        }
        guard let narrativeRequest else { return nil }
        return DeterministicBracketReviewNarrative.run(
            for: narrativeRequest,
            fallbackReason: "Not refreshed in this session."
        )
    }

    private func selectImage(at index: Int) {
        guard bracketAssets.indices.contains(index) else { return }

        currentIndex = index
        updateReviewSequence(reviewSequence?.selecting(index: index))
        loadImage(at: index)
    }

    private func toggleRepresentation() {
        showProcessed.toggle()
        updateReviewSequence(reviewSequence?.togglingRepresentation())
    }

    private func loadImage(at index: Int, forceReload: Bool = false) {
        guard index >= 0 && index < bracketAssets.count else { return }

        let loadStart = CACurrentMediaTime()
        isLoading = true
        let asset = bracketAssets[index]
        refreshResourceSummary(for: asset, at: index)

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
                let durationMilliseconds = Self.elapsedMilliseconds(since: loadStart)
                self.onThumbnailInspectionUpdate(
                    Self.thumbnailInspection(
                        from: image,
                        info: info,
                        asset: asset,
                        at: index,
                        targetSize: targetSize,
                        deliveryMode: "highQualityFormat",
                        contentMode: "aspectFit"
                    )
                )
                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    Logger.error("Failed to load image: \(error.localizedDescription)")
                    self.recordReviewDiagnostic(
                        severity: .error,
                        title: "Review Image Load Failed",
                        detail: "Image \(index + 1) of \(self.bracketAssets.count): \(error.localizedDescription)",
                        durationMilliseconds: durationMilliseconds
                    )
                } else if image != nil {
                    self.recordReviewDiagnostic(
                        severity: CameraRuntimePerformanceThresholds.severity(
                            durationMilliseconds: durationMilliseconds,
                            warningThresholdMilliseconds: CameraRuntimePerformanceThresholds.reviewImageLoadWarningMilliseconds
                        ),
                        title: "Review Image Loaded",
                        detail: "Image \(index + 1) of \(self.bracketAssets.count) loaded for review.",
                        durationMilliseconds: durationMilliseconds
                    )
                } else {
                    self.recordReviewDiagnostic(
                        severity: .warning,
                        title: "Review Image Missing",
                        detail: "Photos returned no image for item \(index + 1) of \(self.bracketAssets.count).",
                        durationMilliseconds: durationMilliseconds
                    )
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
        let metadataStart = CACurrentMediaTime()
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        asset.requestContentEditingInput(with: options) { input, info in
            guard let input, let fullSizeImageURL = input.fullSizeImageURL else {
                DispatchQueue.main.async {
                    let durationMilliseconds = Self.elapsedMilliseconds(since: metadataStart)
                    self.currentMetadata = nil
                    self.updateMetadataAvailability(
                        for: asset,
                        availability: .unavailable(reason: "Full-size image metadata unavailable")
                    )
                    self.recordReviewDiagnostic(
                        severity: .warning,
                        title: "Review Metadata Unavailable",
                        detail: "Full-size metadata input was unavailable.",
                        durationMilliseconds: durationMilliseconds
                    )
                }
                return
            }

            let fullImage = CIImage(contentsOf: fullSizeImageURL)
            DispatchQueue.main.async {
                let durationMilliseconds = Self.elapsedMilliseconds(since: metadataStart)
                let properties = fullImage?.properties
                self.currentMetadata = properties
                if let properties {
                    let summary = Self.metadataSummary(from: properties)
                    self.updateMetadataAvailability(
                        for: asset,
                        availability: .available(summary: summary.displaySummary)
                    )
                    self.recordReviewDiagnostic(
                        severity: CameraRuntimePerformanceThresholds.severity(
                            durationMilliseconds: durationMilliseconds,
                            warningThresholdMilliseconds: CameraRuntimePerformanceThresholds.reviewMetadataLoadWarningMilliseconds
                        ),
                        title: "Review Metadata Loaded",
                        detail: "\(summary.availableKeyCount) metadata key(s) loaded.",
                        durationMilliseconds: durationMilliseconds
                    )
                } else {
                    self.updateMetadataAvailability(
                        for: asset,
                        availability: .unavailable(reason: "Image metadata could not be decoded")
                    )
                    self.recordReviewDiagnostic(
                        severity: .warning,
                        title: "Review Metadata Decode Failed",
                        detail: "Image metadata could not be decoded.",
                        durationMilliseconds: durationMilliseconds
                    )
                }
            }
        }
    }

    private func refreshResourceSummary(for asset: PHAsset, at index: Int) {
        let resources = PHAssetResource.assetResources(for: asset)
        updateReviewSequence(reviewSequence?.updatingShot(
            at: index,
            resourceSummary: Self.resourceSummary(from: resources)
        ))
        onResourceInspectionUpdate(
            BracketProjectResourceInspection.ShotResources(
                index: index,
                assetIdentifier: asset.localIdentifier,
                resources: resources.map(Self.inspectionResource)
            )
        )
    }

    private func updateMetadataAvailability(
        for asset: PHAsset,
        availability: BracketReviewMetadataAvailability
    ) {
        guard bracketAssets.indices.contains(currentIndex),
              bracketAssets[currentIndex].localIdentifier == asset.localIdentifier else {
            return
        }

        updateReviewSequence(reviewSequence?.updatingShot(
            at: currentIndex,
            metadataAvailability: availability
        ))
    }

    private func updateReviewSequence(_ updatedSequence: BracketReviewSequence?) {
        reviewSequence = updatedSequence
        refreshedNarrativeRun = nil
    }

    private func regenerateNarrative() {
        guard let narrativeRequest else { return }
        isNarrativeDismissed = false
        isGeneratingNarrative = true
        Task {
            let run = await BracketReviewNarrativeEngine.live.response(for: narrativeRequest)
            await MainActor.run {
                refreshedNarrativeRun = run
                isGeneratingNarrative = false
            }
        }
    }

    private static func resourceSummary(from resources: [PHAssetResource]) -> BracketReviewResourceSummary {
        guard !resources.isEmpty else { return .unavailable }

        let hasRaw = resources.contains { resource in
            resource.type == .alternatePhoto || fileExtension(for: resource.originalFilename) == "dng"
        }
        let hasProcessed = resources.contains { resource in
            switch resource.type {
            case .photo, .fullSizePhoto:
                return true
            default:
                return ["heic", "heif", "jpg", "jpeg"].contains(fileExtension(for: resource.originalFilename))
            }
        }

        let fileType: String
        if hasRaw && hasProcessed {
            fileType = "RAW + Processed"
        } else if hasRaw {
            fileType = "RAW"
        } else if hasProcessed {
            fileType = "HEIF/JPEG"
        } else {
            fileType = "Unknown"
        }

        var representations: [BracketReviewRepresentation] = []
        if hasProcessed { representations.append(.processed) }
        if hasRaw { representations.append(.raw) }

        let filenames = resources.map(\.originalFilename).joined(separator: ", ")
        return BracketReviewResourceSummary(
            fileType: fileType,
            availableRepresentations: representations,
            detail: filenames.isEmpty ? "Asset resources available" : filenames
        )
    }

    private static func metadataSummary(from properties: [String: Any]) -> BracketReviewMetadataSummary {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let width = intValue(properties[kCGImagePropertyPixelWidth as String])
        let height = intValue(properties[kCGImagePropertyPixelHeight as String])
        let isoValues = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber]
        let lensModel = exif[kCGImagePropertyExifLensModel as String] as? String
        let cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String

        let pixelSize: String?
        if let width, let height {
            pixelSize = "\(width) x \(height)"
        } else {
            pixelSize = nil
        }

        let isoDescription = isoValues?.map { "ISO \($0.intValue)" }.joined(separator: ", ")
        let lensDescription = lensModel ?? cameraModel

        return BracketReviewMetadataSummary(
            availableKeyCount: properties.count + exif.count + tiff.count,
            pixelSize: pixelSize,
            isoDescription: isoDescription,
            lensDescription: lensDescription
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func fileExtension(for filename: String) -> String {
        URL(fileURLWithPath: filename).pathExtension.lowercased()
    }

    private static func thumbnailInspection(
        from image: UIImage?,
        info: [AnyHashable: Any]?,
        asset: PHAsset,
        at index: Int,
        targetSize: CGSize,
        deliveryMode: String,
        contentMode: String
    ) -> BracketProjectThumbnailInspection.ShotThumbnail {
        let deliveredPixelWidth = image.map { Int(($0.size.width * $0.scale).rounded()) }
        let deliveredPixelHeight = image.map { Int(($0.size.height * $0.scale).rounded()) }
        let error = info?[PHImageErrorKey] as? Error
        return BracketProjectThumbnailInspection.ShotThumbnail(
            index: index,
            assetIdentifier: asset.localIdentifier,
            targetPixelWidth: Int(targetSize.width.rounded()),
            targetPixelHeight: Int(targetSize.height.rounded()),
            deliveredPixelWidth: deliveredPixelWidth,
            deliveredPixelHeight: deliveredPixelHeight,
            deliveryMode: deliveryMode,
            contentMode: contentMode,
            isDegraded: boolInfo(PHImageResultIsDegradedKey, in: info),
            isCloudBacked: boolInfo(PHImageResultIsInCloudKey, in: info),
            wasCancelled: boolInfo(PHImageCancelledKey, in: info),
            errorDescription: error?.localizedDescription
        )
    }

    private static func boolInfo(
        _ key: String,
        in info: [AnyHashable: Any]?
    ) -> Bool {
        if let value = info?[key] as? Bool {
            return value
        }
        if let value = info?[key] as? NSNumber {
            return value.boolValue
        }
        return false
    }

    private static func inspectionResource(from resource: PHAssetResource) -> BracketProjectResourceInspection.Resource {
        BracketProjectResourceInspection.Resource(
            resourceType: resourceTypeLabel(for: resource.type),
            originalFilename: resource.originalFilename,
            uniformTypeIdentifier: resource.uniformTypeIdentifier
        )
    }

    private static func resourceTypeLabel(for type: PHAssetResourceType) -> String {
        switch type {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "audio"
        case .alternatePhoto:
            return "alternatePhoto"
        case .fullSizePhoto:
            return "fullSizePhoto"
        case .fullSizeVideo:
            return "fullSizeVideo"
        case .adjustmentData:
            return "adjustmentData"
        case .adjustmentBasePhoto:
            return "adjustmentBasePhoto"
        case .pairedVideo:
            return "pairedVideo"
        case .fullSizePairedVideo:
            return "fullSizePairedVideo"
        case .adjustmentBasePairedVideo:
            return "adjustmentBasePairedVideo"
        case .adjustmentBaseVideo:
            return "adjustmentBaseVideo"
        case .photoProxy:
            return "photoProxy"
        @unknown default:
            return "unknown-\(type.rawValue)"
        }
    }

    private func recordReviewDiagnostic(
        severity: CameraRuntimeDiagnosticEvent.Severity,
        title: String,
        detail: String,
        durationMilliseconds: Int
    ) {
        Logger.photo("[Review] \(title): \(detail) (\(durationMilliseconds) ms)", level: severity.loggerLevel)
        reviewDiagnostics = reviewDiagnostics.recording(
            category: .review,
            severity: severity,
            title: title,
            detail: detail,
            durationMilliseconds: durationMilliseconds
        )
    }

    private static func elapsedMilliseconds(since startTime: TimeInterval) -> Int {
        max(0, Int(((CACurrentMediaTime() - startTime) * 1_000).rounded()))
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
                    let updatedSequence = self.reviewSequence?.deletingSelected()
                    self.currentMetadata = nil
                    self.currentImage = nil
                    self.showMetadata = false

                    if self.bracketAssets.isEmpty {
                        self.updateReviewSequence(updatedSequence)
                        self.onDismiss()
                    } else if self.currentIndex >= self.bracketAssets.count {
                        self.currentIndex = max(0, self.currentIndex - 1)
                        self.updateReviewSequence(updatedSequence?.selecting(index: self.currentIndex))
                        self.loadImage(at: self.currentIndex)
                    } else {
                        self.updateReviewSequence(updatedSequence?.selecting(index: self.currentIndex))
                        self.loadImage(at: self.currentIndex)
                    }
                }
            } else if let error = error {
                Logger.error("Failed to delete asset: \(error.localizedDescription)")
            }
        }
    }
    
    private func evLabelForCurrentIndex() -> String {
        if let reviewLabel = currentReviewShot?.displayLabel {
            return reviewLabel
        }

        guard currentIndex >= 0 && currentIndex < bracketAssets.count else { return "" }
        // Fallback for a standalone recent asset opened without a bracket review sequence.
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
    let assetCount: Int
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
                .accessibilityLabel("Photo \(currentIndex + 1) of \(assetCount)")
        }
    }
}

private struct BracketLiveReviewChrome: View {
    let itemCount: Int
    let currentIndex: Int
    let selectedEVLabel: String
    let selectedShot: BracketReviewShotSummary?
    let showMetadata: Bool
    let representationTitle: String
    let representationIcon: String
    let representationAccessibilityValue: String
    let manifestJSON: String?
    let onDismiss: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleMetadata: () -> Void
    let onToggleRepresentation: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
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
                .accessibilityIdentifier("review.live.closeButton")

                Spacer()

                if itemCount > 1 {
                    HStack(spacing: 6) {
                        Button(action: onPrevious) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(currentIndex == 0 ? .white.opacity(0.28) : .white)
                        .disabled(currentIndex == 0)
                        .accessibilityLabel("Previous review image")
                        .accessibilityIdentifier("review.live.previousButton")

                        HStack(spacing: 4) {
                            ForEach(0..<itemCount, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.yellow : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Button(action: onNext) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(currentIndex >= itemCount - 1 ? .white.opacity(0.28) : .white)
                        .disabled(currentIndex >= itemCount - 1)
                        .accessibilityLabel("Next review image")
                        .accessibilityIdentifier("review.live.nextButton")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.6), in: Capsule())
                }

                if !selectedEVLabel.isEmpty {
                    Text(selectedEVLabel)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .accessibilityIdentifier("review.live.selectedEV")
                }

                Spacer()

                Button(action: onToggleMetadata) {
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
                .accessibilityIdentifier("review.live.metadataToggle")
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            if let selectedShot {
                BracketLiveReviewStatusStrip(
                    positionLabel: "\(currentIndex + 1) of \(itemCount)",
                    shot: selectedShot
                )
            }

            Spacer()

            HStack {
                Button(action: onToggleRepresentation) {
                    HStack(spacing: 8) {
                        Text(representationTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Image(systemName: representationIcon)
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
                .accessibilityLabel("Review representation")
                .accessibilityValue(representationAccessibilityValue)
                .accessibilityIdentifier("review.live.representationToggle")

                Spacer()

                HStack(spacing: 16) {
                    if let manifestJSON {
                        ShareLink(item: manifestJSON) {
                            Image(systemName: "doc.plaintext")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .liquidGlass(intensity: .regular, tint: .white.opacity(0.12), interactive: true)
                                )
                        }
                        .accessibilityLabel("Share Bracket Manifest")
                        .accessibilityValue(manifestJSON)
                        .accessibilityIdentifier("review.live.manifestShareButton")
                    }

                    Button(action: onShare) {
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
                    .accessibilityIdentifier("review.live.shareButton")

                    Button(action: onDelete) {
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
                    .accessibilityIdentifier("review.live.deleteButton")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

private struct BracketLiveReviewStatusStrip: View {
    let positionLabel: String
    let shot: BracketReviewShotSummary

    var body: some View {
        HStack(spacing: 8) {
            Text(positionLabel)
                .accessibilityIdentifier("review.live.position")

            Text(shot.fileType)
                .accessibilityIdentifier("review.live.fileType")

            Text(shot.metadataAvailability.displayName)
                .accessibilityIdentifier("review.live.metadataStatus")
                .accessibilityValue(shot.metadataAvailability.detail)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundColor(.white.opacity(0.76))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct DeterministicImageReviewFixtureView: View {
    let onDismiss: () -> Void

    @State private var sequence = Self.makeSequence()
    @State private var showMetadata = false
    @State private var showDeleteConfirmation = false
    @State private var shareNoticeVisible = false
    @State private var dismissed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if dismissed {
                VStack(spacing: 12) {
                    Text("Review Fixture Dismissed")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .accessibilityIdentifier("review.fixture.dismissedTitle")

                    Button("Reopen") {
                        dismissed = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if sequence.isEmpty {
                VStack(spacing: 12) {
                    Text("No Fixture Shots")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .accessibilityIdentifier("review.fixture.emptyTitle")

                    Button("Reset Fixture") {
                        sequence = Self.makeSequence()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                fixtureImage

                BracketLiveReviewChrome(
                    itemCount: sequence.shots.count,
                    currentIndex: sequence.selectedIndex,
                    selectedEVLabel: sequence.selectedShot?.displayLabel ?? "",
                    selectedShot: sequence.selectedShot,
                    showMetadata: showMetadata,
                    representationTitle: sequence.selectedRepresentation == .processed ? "JPG" : "RAW",
                    representationIcon: sequence.selectedRepresentation == .processed ? "photo" : "r.square",
                    representationAccessibilityValue: sequence.selectedRepresentationAvailabilityLabel,
                    manifestJSON: fixtureManifestJSON,
                    onDismiss: {
                        dismissed = true
                        onDismiss()
                    },
                    onPrevious: { sequence = sequence.selectingPrevious() },
                    onNext: { sequence = sequence.selectingNext() },
                    onToggleMetadata: { showMetadata.toggle() },
                    onToggleRepresentation: { sequence = sequence.togglingRepresentation() },
                    onShare: {
                        shareNoticeVisible = true
                    },
                    onDelete: {
                        showDeleteConfirmation = true
                    }
                )

                if showMetadata, let selectedShot = sequence.selectedShot {
                    ReviewFixtureProbe(identifier: "review.live.metadataPanel", label: "Live Review Metadata Panel")
                    fixtureMetadataPanel(for: selectedShot)
                }

                if shareNoticeVisible {
                    Text("Fixture export suppressed")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .padding(.bottom, 96)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .accessibilityIdentifier("review.fixture.shareNotice")
                }
            }
        }
        .confirmationDialog("Remove Fixture Shot?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Fixture Shot", role: .destructive) {
                sequence = sequence.deletingSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes only the in-memory fixture item. No Photos library asset is touched.")
        }
    }

    private var fixtureImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.08),
                    Color(red: 0.12, green: 0.18, blue: 0.24),
                    Color(red: 0.02, green: 0.03, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 14) {
                Text("Deterministic Review Fixture")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("review.fixture.title")

                if let selectedShot = sequence.selectedShot {
                    Text(selectedShot.selectedTitle)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .accessibilityIdentifier("review.fixture.selectedTitle")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.fixture.image")
    }

    private func fixtureMetadataPanel(for shot: BracketReviewShotSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fixture Metadata", systemImage: "info.circle.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)

            Text(shot.metadataAvailability.detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.74))
                .accessibilityIdentifier("review.live.metadataDetail")

            Text(shot.clippingSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(shot.clippingWarnings.isEmpty ? .white.opacity(0.62) : .orange)
                .accessibilityIdentifier("review.live.clippingSummary")
        }
        .padding(14)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 132)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var fixtureManifestJSON: String? {
        try? sequence.manifest(
            groupIdentifier: "review-fixture",
            source: .photos,
            plan: Self.fixturePlan
        ).jsonString()
    }

    private static let fixturePlan = BracketPlan(evStep: 2.0, requestedShotCount: 5)

    private static func makeSequence() -> BracketReviewSequence {
        BracketReviewSequence.make(
            plan: fixturePlan,
            assetIdentifiers: [
                "fixture--4.0EV",
                "fixture--2.0EV",
                "fixture-0EV",
                "fixture-+2.0EV",
                "fixture-+4.0EV",
            ],
            capturedAt: Date(timeIntervalSince1970: 0),
            fileType: "RAW + Processed",
            metadataAvailability: .available(summary: "18 metadata keys / 4032 x 3024 / ISO 125 / Wide Camera"),
            availableRepresentations: [.processed, .raw]
        )
    }
}

private struct ReviewFixtureProbe: View {
    let identifier: String
    let label: String
    var value: String?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityIdentifier(identifier)
    }
}

private extension CameraRuntimeDiagnosticEvent.Severity {
    var loggerLevel: Logger.Level {
        switch self {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
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

import UIKit
import SwiftUI
import AVFoundation

/// Capability level determines which features are available
enum DeviceCapabilityLevel {
    case full       // All lenses + ProRAW (iPhone 15/16/17 Pro)
    case standard   // Multiple lenses, no ProRAW
    case basic      // Wide lens only
    case unsupported // No camera or too-old OS
}

/// Device compatibility gating system using capability-based detection
/// Supports any iPhone with adequate camera hardware instead of hardcoded model
final class DeviceGating: ObservableObject {
    static let shared = DeviceGating()

    @Published var isCompatibleDevice = false
    @Published var capabilityLevel: DeviceCapabilityLevel = .unsupported
    @Published var deviceModel: String = ""
    @Published var iosVersion: String = ""
    @Published var compatibilityMessage: String = ""

    private init() {
        checkDeviceCompatibility()
    }

    private func checkDeviceCompatibility() {
        deviceModel = getDeviceModelIdentifier()
        iosVersion = UIDevice.current.systemVersion

        #if targetEnvironment(simulator)
        isCompatibleDevice = true
        capabilityLevel = .full
        #else
        let isCorrectOS = compareVersion(iosVersion, "26.0") >= 0

        if !isCorrectOS {
            isCompatibleDevice = false
            capabilityLevel = .unsupported
            generateCompatibilityMessage(deviceOK: true, osOK: false)
            return
        }

        capabilityLevel = detectCameraCapabilities()

        switch capabilityLevel {
        case .full, .standard:
            isCompatibleDevice = true
        case .basic:
            // Allow basic devices but with reduced features
            isCompatibleDevice = true
            compatibilityMessage = "Some features may be limited on this device. For the best experience, use an iPhone with multiple camera lenses."
        case .unsupported:
            isCompatibleDevice = false
            generateCompatibilityMessage(deviceOK: false, osOK: isCorrectOS)
        }
        #endif
    }

    private func detectCameraCapabilities() -> DeviceCapabilityLevel {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        let deviceTypes = Set(discovery.devices.map { $0.deviceType })

        let hasWide = deviceTypes.contains(.builtInWideAngleCamera)
        let hasUltraWide = deviceTypes.contains(.builtInUltraWideCamera)
        let hasTelephoto = deviceTypes.contains(.builtInTelephotoCamera)

        guard hasWide else { return .unsupported }

        // Check ProRAW support
        let hasProRAW: Bool = {
            guard let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return false }
            let output = AVCapturePhotoOutput()
            let session = AVCaptureSession()
            session.beginConfiguration()
            if let input = try? AVCaptureDeviceInput(device: wideDevice), session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            return output.isAppleProRAWSupported
        }()

        if (hasUltraWide || hasTelephoto) && hasProRAW {
            return .full
        } else if hasUltraWide || hasTelephoto {
            return .standard
        } else {
            return .basic
        }
    }
    
    private func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    private func compareVersion(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value < v2Value {
                return -1
            } else if v1Value > v2Value {
                return 1
            }
        }
        
        return 0
    }
    
    private func generateCompatibilityMessage(deviceOK: Bool, osOK: Bool) {
        switch (deviceOK, osOK) {
        case (false, false):
            compatibilityMessage = """
            This app requires an iPhone with a camera and iOS 26 or later.

            Current device: \(getDeviceDisplayName())
            Current iOS version: \(iosVersion)
            """
        case (false, true):
            compatibilityMessage = """
            This app requires an iPhone with a supported camera system.

            Current device: \(getDeviceDisplayName())
            iOS version: \(iosVersion)
            """
        case (true, false):
            compatibilityMessage = """
            This app requires iOS 26 or later.

            Device: \(getDeviceDisplayName())
            Current iOS version: \(iosVersion)

            Please update to iOS 26.0 or later to access the latest camera APIs.
            """
        case (true, true):
            compatibilityMessage = ""
        }
    }
    
    private func getDeviceDisplayName() -> String {
        // Map device identifiers to display names
        switch deviceModel {
        case "iPhone14,1": return "iPhone 13 mini"
        case "iPhone14,2": return "iPhone 13"
        case "iPhone14,3": return "iPhone 13 Pro"
        case "iPhone14,4": return "iPhone 13 Pro Max"
        case "iPhone15,1": return "iPhone 14"
        case "iPhone15,2": return "iPhone 14 Plus"
        case "iPhone15,3": return "iPhone 14 Pro"
        case "iPhone15,4": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 17 Pro Max"
        default: return "Unknown iPhone (\(deviceModel))"
        }
    }
}

/// Compatibility check view that blocks app usage on unsupported devices
struct DeviceCompatibilityView: View {
    @StateObject private var deviceGating = DeviceGating.shared
    
    var body: some View {
        if deviceGating.isCompatibleDevice {
            ModernContentView()
        } else {
            IncompatibleDeviceView()
        }
    }
}

/// Full-screen incompatibility warning with no bypass mechanism
struct IncompatibleDeviceView: View {
    @StateObject private var deviceGating = DeviceGating.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Liquid Glass background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Glassmorphism overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // App icon or camera symbol
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .white.opacity(0.3), radius: 20)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        Text("Professional Camera")
                            .font(ModernDesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Compatible Device Required")
                            .font(ModernDesignSystem.Typography.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Compatibility details card
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                        Text(deviceGating.compatibilityMessage)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .padding(ModernDesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                            .fill(.ultraThinMaterial)
                            .opacity(0.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .applyModernShadow(ModernDesignSystem.Shadows.large)
                    
                    // App Store redirect button
                    Button {
                        openAppStore()
                    } label: {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 18, weight: .semibold))
                            Text("View in App Store")
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, ModernDesignSystem.Spacing.xl)
                        .padding(.vertical, ModernDesignSystem.Spacing.md)
                        .background(
                            Capsule()
                                .liquidGlass(intensity: .prominent, tint: .white.opacity(0.2), interactive: true)
                        )
                    }
                    .buttonStyle(.plain)
                    .applyModernShadow(ModernDesignSystem.Shadows.medium)
                    
                    Spacer()
                    
                    // System requirements
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text("System Requirements")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("iPhone with camera • iOS 26.0+")
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(ModernDesignSystem.Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func openAppStore() {
        // In a real app, this would open the App Store page
        if let url = URL(string: "https://apps.apple.com/app/id0000000000") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("Compatible Device") {
    DeviceCompatibilityView()
        .onAppear {
            // Override for preview
            DeviceGating.shared.isCompatibleDevice = true
        }
}

#Preview("Incompatible Device") {
    IncompatibleDeviceView()
}

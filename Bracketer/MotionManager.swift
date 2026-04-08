import CoreMotion
import SwiftUI
import UIKit

/// Advanced motion detection and level calculation for camera orientation
/// Provides real-time device attitude and level measurements for professional camera features
final class MotionLevelManager: NSObject, ObservableObject {
    @Published var currentAttitude: CMAttitude?
    @Published var isLevelingActive = true
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    // Level calculation properties
    private var referenceAttitude: CMAttitude?
    private let levelThreshold: Double = 1.0 // degrees
    private var isRunning = false
    
    override init() {
        super.init()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }
    
    /// Start motion updates for camera orientation and leveling
    func start() {
        guard !isRunning else { return }
        guard motionManager.isDeviceMotionAvailable else {
            Logger.motion("Device motion not available", level: .warning)
            return
        }
        
        // Configure motion updates for camera use
        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0 // 10 FPS sufficient for level indicator
        motionManager.showsDeviceMovementDisplay = true
        
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: queue
        ) { [weak self] motion, error in
            guard let motion = motion, error == nil else {
                if let error = error {
                    Logger.motion("Motion update error: \(error.localizedDescription)", level: .error)
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.currentAttitude = motion.attitude
            }
        }

        isRunning = true
        Logger.motion("Motion updates started")
    }
    
    /// Stop motion updates
    func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        Logger.motion("Motion updates stopped")
    }
    
    /// Calculate level angle in degrees for current device orientation
    func levelAngleDegrees(for orientation: UIInterfaceOrientation) -> Double {
        guard let attitude = currentAttitude else { return 0.0 }
        
        // Calculate roll angle based on device orientation
        switch orientation {
        case .portrait:
            return attitude.roll * 180.0 / .pi
        case .portraitUpsideDown:
            return -attitude.roll * 180.0 / .pi
        case .landscapeLeft:
            return -attitude.pitch * 180.0 / .pi
        case .landscapeRight:
            return attitude.pitch * 180.0 / .pi
        default:
            return attitude.roll * 180.0 / .pi
        }
    }
    
    /// Check if device is currently level within threshold
    func isDeviceLevel(for orientation: UIInterfaceOrientation, threshold: Double = 1.0) -> Bool {
        let angle = levelAngleDegrees(for: orientation)
        return abs(angle) <= threshold
    }
    
    /// Get level status for UI indication
    func getLevelStatus(for orientation: UIInterfaceOrientation) -> LevelStatus {
        let angle = levelAngleDegrees(for: orientation)
        
        if abs(angle) <= 0.5 {
            return .perfect
        } else if abs(angle) <= 1.0 {
            return .good
        } else if abs(angle) <= 2.0 {
            return .close
        } else {
            return .off
        }
    }
    
    /// Set reference attitude for relative measurements
    func setReferenceAttitude() {
        referenceAttitude = currentAttitude?.copy() as? CMAttitude
    }
    
    /// Get attitude relative to reference
    func getRelativeAttitude() -> CMAttitude? {
        guard let current = currentAttitude?.copy() as? CMAttitude,
              let reference = referenceAttitude else { return nil }

        current.multiply(byInverseOf: reference)
        return current
    }
    
    /// Calculate camera shake amount for stabilization feedback
    func getCameraShakeAmount() -> Double {
        guard let attitude = currentAttitude else { return 0.0 }
        
        // Simple shake detection based on attitude changes
        // In a real implementation, this would use accelerometer data and temporal analysis
        let rollChange = abs(attitude.roll)
        let pitchChange = abs(attitude.pitch)
        let yawChange = abs(attitude.yaw)
        
        return (rollChange + pitchChange + yawChange) / 3.0
    }
    
    /// Check if device is stable enough for long exposure
    func isStableForLongExposure(threshold: Double = 0.01) -> Bool {
        return getCameraShakeAmount() < threshold
    }
    
    deinit {
        stop()
    }
}

/// Level status enumeration for UI feedback
enum LevelStatus: Equatable {
    case perfect    // Within 0.5 degrees
    case good      // Within 1 degree
    case close     // Within 2 degrees
    case off       // Beyond 2 degrees
    
    var color: Color {
        switch self {
        case .perfect: return .green
        case .good: return .yellow
        case .close: return .orange
        case .off: return .red
        }
    }
    
    var description: String {
        switch self {
        case .perfect: return "Perfect"
        case .good: return "Level"
        case .close: return "Close"
        case .off: return "Not Level"
        }
    }
}

/// Real-time level indicator overlay for camera preview
struct MotionLevelOverlay: View {
    let angleDegrees: Double
    @State private var isVisible = true
    @State private var hideTask: DispatchWorkItem?

    private var levelStatus: LevelStatus {
        if abs(angleDegrees) <= 0.5 {
            return .perfect
        } else if abs(angleDegrees) <= 1.0 {
            return .good
        } else if abs(angleDegrees) <= 2.0 {
            return .close
        } else {
            return .off
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal reference line
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(height: 2)
                    .frame(width: geometry.size.width * 0.6)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Actual level line that rotates with device
                Rectangle()
                    .fill(levelStatus.color)
                    .frame(height: 3)
                    .frame(width: geometry.size.width * 0.6)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .rotationEffect(.degrees(-angleDegrees))
                    .animation(.easeOut(duration: 0.1), value: angleDegrees)
                
                // Center point indicator
                Circle()
                    .fill(levelStatus.color)
                    .frame(width: 8, height: 8)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .scaleEffect(levelStatus == .perfect ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: levelStatus)
                
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            // Auto-hide after showing for a few seconds if level is good
            if levelStatus == .perfect || levelStatus == .good {
                scheduleHide(after: 3.0)
            }
        }
        .onDisappear {
            // Cancel any pending hide tasks to prevent state changes after view is gone
            hideTask?.cancel()
            hideTask = nil
        }
        .onChange(of: levelStatus) { oldStatus, newStatus in
            // Show overlay when device moves away from level
            if newStatus == .close || newStatus == .off {
                // Cancel any pending hide task
                hideTask?.cancel()
                hideTask = nil

                withAnimation {
                    isVisible = true
                }
            } else if newStatus == .perfect {
                // Briefly show perfect level, then fade
                withAnimation {
                    isVisible = true
                }
                scheduleHide(after: 1.0)
            }
        }
    }

    // Helper function to schedule auto-hide with cancellable task
    private func scheduleHide(after delay: TimeInterval) {
        // Cancel any existing hide task to prevent overlapping animations
        hideTask?.cancel()

        // Create a new cancellable hide task
        let task = DispatchWorkItem {
            withAnimation {
                isVisible = false
            }
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MotionLevelOverlay(angleDegrees: 2.5)
    }
}

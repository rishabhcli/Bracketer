import CoreMotion
import Foundation

struct CaptureMotionAccumulator: Equatable, Sendable {
    private(set) var sampleCount: Int = 0
    private(set) var maxAngularVelocityRadiansPerSecond: Double = 0
    private(set) var maxAccelerationG: Double = 0

    mutating func record(
        rotationRateX: Double,
        rotationRateY: Double,
        rotationRateZ: Double,
        accelerationX: Double,
        accelerationY: Double,
        accelerationZ: Double
    ) {
        sampleCount += 1
        maxAngularVelocityRadiansPerSecond = max(
            maxAngularVelocityRadiansPerSecond,
            vectorMagnitude(x: rotationRateX, y: rotationRateY, z: rotationRateZ)
        )
        maxAccelerationG = max(
            maxAccelerationG,
            vectorMagnitude(x: accelerationX, y: accelerationY, z: accelerationZ)
        )
    }

    mutating func record(deviceMotion: CMDeviceMotion) {
        record(
            rotationRateX: deviceMotion.rotationRate.x,
            rotationRateY: deviceMotion.rotationRate.y,
            rotationRateZ: deviceMotion.rotationRate.z,
            accelerationX: deviceMotion.userAcceleration.x,
            accelerationY: deviceMotion.userAcceleration.y,
            accelerationZ: deviceMotion.userAcceleration.z
        )
    }

    func snapshot(
        source: String,
        durationMilliseconds: Int?
    ) -> BracketManifest.CaptureMotionSnapshot {
        guard sampleCount > 0 else {
            return .unavailable(
                source: source,
                captureDurationMilliseconds: durationMilliseconds ?? 0
            )
        }

        let maxAngularVelocityDegreesPerSecond = Int(
            (maxAngularVelocityRadiansPerSecond * 180.0 / Double.pi).rounded()
        )
        let maxAccelerationMilliG = Int((maxAccelerationG * 1_000).rounded())
        return .available(
            source: source,
            sampleCount: sampleCount,
            captureDurationMilliseconds: durationMilliseconds ?? 0,
            maxAngularVelocityDegreesPerSecond: maxAngularVelocityDegreesPerSecond,
            maxAccelerationMilliG: maxAccelerationMilliG,
            qualityLabel: qualityLabel(
                maxAngularVelocityDegreesPerSecond: maxAngularVelocityDegreesPerSecond,
                maxAccelerationMilliG: maxAccelerationMilliG
            )
        )
    }

    private func vectorMagnitude(x: Double, y: Double, z: Double) -> Double {
        sqrt((x * x) + (y * y) + (z * z))
    }

    private func qualityLabel(
        maxAngularVelocityDegreesPerSecond: Int,
        maxAccelerationMilliG: Int
    ) -> String {
        if maxAngularVelocityDegreesPerSecond >= 45 || maxAccelerationMilliG >= 900 {
            return "High motion scalar summary"
        }
        if maxAngularVelocityDegreesPerSecond >= 12 || maxAccelerationMilliG >= 250 {
            return "Moderate handheld scalar summary"
        }
        return "Stable handheld scalar summary"
    }
}

final class CaptureMotionRecorder {
    private let motionManager: CMMotionManager
    private let queue: OperationQueue
    private let lock = NSLock()
    private var accumulator = CaptureMotionAccumulator()
    private var unavailableSource = "CMMotionManager capture motion not started"

    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    func start() {
        lock.lock()
        accumulator = CaptureMotionAccumulator()
        unavailableSource = "CMMotionManager produced no capture motion samples"
        lock.unlock()

        guard motionManager.isDeviceMotionAvailable else {
            lock.lock()
            unavailableSource = "CMMotionManager device motion unavailable"
            lock.unlock()
            Logger.motion("Capture motion metadata unavailable", level: .warning)
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                self.lock.lock()
                self.unavailableSource = "CMMotionManager capture motion error: \(error.localizedDescription)"
                self.lock.unlock()
                Logger.motion("Capture motion metadata error: \(error.localizedDescription)", level: .error)
                return
            }
            guard let motion else { return }

            self.lock.lock()
            self.accumulator.record(deviceMotion: motion)
            self.lock.unlock()
        }
        Logger.motion("Capture motion metadata sampling started")
    }

    func finishSnapshot(
        durationMilliseconds: Int?
    ) -> BracketManifest.CaptureMotionSnapshot {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }

        lock.lock()
        let capturedAccumulator = accumulator
        let capturedUnavailableSource = unavailableSource
        accumulator = CaptureMotionAccumulator()
        unavailableSource = "CMMotionManager capture motion not started"
        lock.unlock()

        let source = capturedAccumulator.sampleCount > 0
            ? "CMMotionManager deviceMotion scalar summary"
            : capturedUnavailableSource
        let snapshot = capturedAccumulator.snapshot(
            source: source,
            durationMilliseconds: durationMilliseconds
        )
        Logger.motion("Capture motion metadata summary: \(snapshot.summaryLabel)")
        return snapshot
    }
}

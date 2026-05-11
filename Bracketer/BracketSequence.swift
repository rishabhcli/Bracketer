import Foundation

enum BracketSequencePlanner {
    static func evOffsets(evStep: Float, shotCount: Int, centerBias: Float = 0) -> [Float] {
        BracketPlan(evStep: evStep, requestedShotCount: shotCount, centerBias: centerBias).evOffsets
    }
}

struct BracketShot: Equatable, Identifiable, Sendable {
    let index: Int
    let evOffset: Float

    var id: Int { index }

    var displayLabel: String {
        BracketEVFormatter.displayLabel(for: evOffset)
    }

    var filenameLabel: String {
        BracketEVFormatter.filenameLabel(for: evOffset)
    }

    var isCenterExposure: Bool {
        BracketEVFormatter.isEffectivelyZero(evOffset)
    }
}

struct BracketPlan: Equatable, Sendable {
    static let supportedShotCounts: [Int] = [3, 5, 7]
    static let defaultShotCount = 3
    static let defaultEVStep: Float = 1.0

    let requestedShotCount: Int
    let shotCount: Int
    let evStep: Float
    let centerBias: Float
    let shots: [BracketShot]
    let normalizationReason: String?

    init(evStep: Float, requestedShotCount: Int, centerBias: Float = 0) {
        self.requestedShotCount = requestedShotCount
        self.centerBias = centerBias

        let resolvedEVStep: Float
        var reasons: [String] = []
        if evStep.isFinite, evStep > 0 {
            resolvedEVStep = evStep
        } else {
            resolvedEVStep = Self.defaultEVStep
            reasons.append("Invalid EV step \(evStep); using +/-\(Self.defaultEVStep) EV.")
        }

        if Self.supportedShotCounts.contains(requestedShotCount) {
            self.shotCount = requestedShotCount
        } else {
            self.shotCount = Self.defaultShotCount
            reasons.append("Unsupported \(requestedShotCount)-shot bracket; using \(Self.defaultShotCount) shots.")
        }

        self.evStep = resolvedEVStep
        self.normalizationReason = reasons.isEmpty ? nil : reasons.joined(separator: " ")

        let radius = self.shotCount / 2
        self.shots = (-radius...radius).enumerated().map { offsetIndex, multiplier in
            BracketShot(
                index: offsetIndex,
                evOffset: Float(multiplier) * resolvedEVStep + centerBias
            )
        }
    }

    var evOffsets: [Float] {
        shots.map(\.evOffset)
    }

    var centerShot: BracketShot? {
        shots.first(where: \.isCenterExposure)
    }
}

enum BracketSequenceState: Equatable, Sendable {
    case idle
    case preparing(plan: BracketPlan)
    case capturing(plan: BracketPlan, currentIndex: Int, completedShots: Int)
    case saving(plan: BracketPlan, savedCount: Int)
    case completed(plan: BracketPlan, assetIdentifiers: [String])
    case cancelled(plan: BracketPlan?, reason: String)
    case timedOut(plan: BracketPlan)
    case failed(plan: BracketPlan?, message: String)

    var plan: BracketPlan? {
        switch self {
        case .idle:
            return nil
        case .preparing(let plan),
             .capturing(let plan, _, _),
             .saving(let plan, _),
             .completed(let plan, _),
             .timedOut(let plan):
            return plan
        case .cancelled(let plan, _),
             .failed(let plan, _):
            return plan
        }
    }

    var isActive: Bool {
        switch self {
        case .preparing, .capturing, .saving:
            return true
        case .idle, .completed, .cancelled, .timedOut, .failed:
            return false
        }
    }

    var progress: BracketCaptureProgress {
        switch self {
        case .idle:
            return .idle
        case .preparing(let plan):
            return BracketCaptureProgress(
                phase: .preparing,
                completedShots: 0,
                totalShots: plan.shotCount,
                currentShot: plan.shots.first,
                title: "Preparing bracket",
                subtitle: "Setting up \(plan.shotCount) exposure sequence"
            )
        case .capturing(let plan, let currentIndex, let completedShots):
            let boundedIndex = min(max(currentIndex, 0), max(plan.shots.count - 1, 0))
            let currentShot = plan.shots.indices.contains(boundedIndex) ? plan.shots[boundedIndex] : nil
            return BracketCaptureProgress(
                phase: .capturing,
                completedShots: min(max(completedShots, 0), plan.shotCount),
                totalShots: plan.shotCount,
                currentShot: currentShot,
                title: currentShot.map { "Capturing \($0.displayLabel)" } ?? "Capturing bracket",
                subtitle: "Shot \(min(boundedIndex + 1, plan.shotCount)) of \(plan.shotCount)"
            )
        case .saving(let plan, let savedCount):
            return BracketCaptureProgress(
                phase: .saving,
                completedShots: plan.shotCount,
                totalShots: plan.shotCount,
                currentShot: nil,
                title: "Saving bracket",
                subtitle: "Saved \(min(max(savedCount, 0), plan.shotCount)) of \(plan.shotCount)"
            )
        case .completed(let plan, let assetIdentifiers):
            return BracketCaptureProgress(
                phase: .completed,
                completedShots: plan.shotCount,
                totalShots: plan.shotCount,
                currentShot: nil,
                title: "Bracket complete",
                subtitle: "\(assetIdentifiers.count) assets saved"
            )
        case .cancelled(let plan, let reason):
            return BracketCaptureProgress(
                phase: .cancelled,
                completedShots: 0,
                totalShots: plan?.shotCount ?? 0,
                currentShot: nil,
                title: "Bracket cancelled",
                subtitle: reason
            )
        case .timedOut(let plan):
            return BracketCaptureProgress(
                phase: .timedOut,
                completedShots: 0,
                totalShots: plan.shotCount,
                currentShot: nil,
                title: "Bracket timed out",
                subtitle: "Capture did not finish in time"
            )
        case .failed(let plan, let message):
            return BracketCaptureProgress(
                phase: .failed,
                completedShots: 0,
                totalShots: plan?.shotCount ?? 0,
                currentShot: nil,
                title: "Bracket failed",
                subtitle: message
            )
        }
    }
}

struct BracketCaptureProgress: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case idle
        case preparing
        case capturing
        case saving
        case completed
        case cancelled
        case timedOut
        case failed
    }

    static let idle = BracketCaptureProgress(
        phase: .idle,
        completedShots: 0,
        totalShots: 0,
        currentShot: nil,
        title: "",
        subtitle: ""
    )

    let phase: Phase
    let completedShots: Int
    let totalShots: Int
    let currentShot: BracketShot?
    let title: String
    let subtitle: String

    var fraction: Double {
        guard totalShots > 0 else { return 0 }
        return min(max(Double(completedShots) / Double(totalShots), 0), 1)
    }

    var shouldShowOverlay: Bool {
        switch phase {
        case .preparing, .capturing, .saving:
            return true
        case .idle, .completed, .cancelled, .timedOut, .failed:
            return false
        }
    }
}

enum BracketEVFormatter {
    static func displayLabel(for evOffset: Float) -> String {
        if isEffectivelyZero(evOffset) {
            return "0 EV"
        }

        return "\(signedEV(evOffset)) EV"
    }

    static func filenameLabel(for evOffset: Float) -> String {
        if isEffectivelyZero(evOffset) {
            return "0EV"
        }

        return "\(signedEV(evOffset))EV"
    }

    static func isEffectivelyZero(_ value: Float) -> Bool {
        abs(value) < 0.0001
    }

    private static func signedEV(_ value: Float) -> String {
        String(format: "%+.1f", value)
    }
}

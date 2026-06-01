import CoreSpotlight
import SwiftUI

@available(iOS 26.2, *)
@main
struct BracketerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let shouldSkipOnboardingForUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing-skip-onboarding")
    private let shouldForceAccessibilityDynamicTypeForUITests =
        ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-environment")
        || ProcessInfo.processInfo.arguments.contains("-ui-testing-force-accessibility-dynamic-type")
    private let forcedDynamicTypeSizeForUITests = BracketerApp.dynamicTypeSizeOverrideForUITests()

    init() {
        // Support all orientations - camera preview will auto-rotate
        AppDelegate.orientationLock = .all
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding || shouldSkipOnboardingForUITests {
                    DeviceCompatibilityView()
                        .onAppear {
                            // Support all orientations for camera
                            AppDelegate.orientationLock = .all
                        }
                } else {
                    OnboardingView()
                }
            }
            .modifier(
                UITestAccessibilityEnvironmentModifier(
                    isEnabled: shouldForceAccessibilityDynamicTypeForUITests
                )
            )
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                Task { @MainActor in
                    guard let handoff = try? BracketerSpotlightHandoff.handoff(from: activity) else { return }
                    BracketerAppIntentRouter.shared.handle(handoff)
                }
            }
            .bracketerDynamicTypeOverride(forcedDynamicTypeSizeForUITests)
        }
    }

    private static func dynamicTypeSizeOverrideForUITests() -> DynamicTypeSize? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-force-accessibility-environment") {
            return .accessibility3
        }

        guard let optionIndex = arguments.firstIndex(of: "-ui-testing-dynamic-type-size"),
              arguments.indices.contains(optionIndex + 1) else {
            return nil
        }

        switch arguments[optionIndex + 1].lowercased() {
        case "accessibility1":
            return .accessibility1
        case "accessibility2":
            return .accessibility2
        case "accessibility3":
            return .accessibility3
        case "accessibility4":
            return .accessibility4
        case "accessibility5":
            return .accessibility5
        case "xxxl", "xxxlarge":
            return .xxxLarge
        case "xxl", "xxlarge":
            return .xxLarge
        case "xl", "xlarge":
            return .xLarge
        case "small":
            return .small
        case "medium":
            return .medium
        default:
            return nil
        }
    }
}

private struct UITestAccessibilityEnvironmentModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .dynamicTypeSize(.accessibility3)
        } else {
            content
        }
    }
}

// MARK: - App Delegate for Orientation Support

private extension View {
    @ViewBuilder
    func bracketerDynamicTypeOverride(_ size: DynamicTypeSize?) -> some View {
        if let size {
            environment(\.dynamicTypeSize, size)
        } else {
            self
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

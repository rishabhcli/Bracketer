// BracketerApp.swift
// Main entry point for the Bracketer app.

import SwiftUI

@available(iOS 26.2, *)
@main
struct BracketerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let shouldSkipOnboardingForUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing-skip-onboarding")

    init() {
        // Support all orientations - camera preview will auto-rotate
        AppDelegate.orientationLock = .all
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
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
    }
}

// MARK: - App Delegate for Orientation Support

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

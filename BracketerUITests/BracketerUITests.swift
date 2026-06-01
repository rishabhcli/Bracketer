//
//  BracketerUITests.swift
//  BracketerUITests
//
//  Created by Rishabh Bansal on 8/25/25.
//

import XCTest

final class BracketerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCameraScreenLaunchesWithStableControls() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["camera.photoLibraryButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["camera.shutterButton"].exists)
        XCTAssertTrue(app.buttons["camera.settingsButton"].exists)

        let diagnosticsSummary = anyElement(in: app, identifier: "camera.diagnostics.summary")
        XCTAssertTrue(diagnosticsSummary.waitForExistence(timeout: 5))
        XCTAssertEqual(diagnosticsSummary.value as? String, "0 events | No diagnostics")
        XCTAssertEqual(
            anyElement(in: app, identifier: "camera.diagnostics.latest").value as? String,
            "No diagnostics"
        )
        XCTAssertEqual(
            anyElement(in: app, identifier: "camera.diagnostics.export").value as? String,
            """
            Bracketer Diagnostics
            Events: 0
            Max Events: 30
            No diagnostics recorded.
            """
        )

        let shortcutInventory = anyElement(in: app, identifier: "camera.appIntent.shortcutInventory")
        XCTAssertTrue(shortcutInventory.waitForExistence(timeout: 5))
        let shortcutInventoryValue = shortcutInventory.value as? String
        XCTAssertTrue(shortcutInventoryValue?.contains("Shortcut tiles: 10 of 10") ?? false)
        XCTAssertTrue(shortcutInventoryValue?.contains("No shortcut tile headroom") ?? false)
        XCTAssertTrue(shortcutInventoryValue?.contains("Prepare Timed Bracketer Capture") ?? false)
        XCTAssertTrue(shortcutInventoryValue?.contains("Open Latest Bracketer Review") ?? false)
        XCTAssertTrue(shortcutInventoryValue?.contains("Export Latest Bracketer Manifest") ?? false)
    }

    @MainActor
    func testTimedCaptureAppIntentHandoffAppliesPresetAndTimer() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-open-timed-capture-handoff",
        ]
        app.launch()

        let handoffProbe = anyElement(in: app, identifier: "camera.appIntent.lastHandoff")
        XCTAssertTrue(handoffProbe.waitForExistence(timeout: 5))
        let handoffValue = handoffProbe.value as? String
        XCTAssertTrue(handoffValue?.contains("Destination: Camera") ?? false)
        XCTAssertTrue(handoffValue?.contains("Bracket: 5 shots at +/-2 EV") ?? false)
        XCTAssertTrue(handoffValue?.contains("Timer: 3s") ?? false)
        XCTAssertTrue(handoffValue?.contains("capture still requires the photographer") ?? false)

        let planProbe = anyElement(in: app, identifier: "camera.bracketPlan.current")
        XCTAssertTrue(planProbe.waitForExistence(timeout: 5))
        XCTAssertEqual(
            planProbe.value as? String,
            "5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV"
        )

        let bracketStrip = anyElement(in: app, identifier: "camera.bracketPlan.strip")
        XCTAssertTrue(bracketStrip.waitForExistence(timeout: 5))
        XCTAssertEqual(
            bracketStrip.value as? String,
            "5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV"
        )
        XCTAssertEqual(anyElement(in: app, identifier: "camera.bracketingIndicator").value as? String, "+/-2.0 EV")

        let timerButton = app.buttons["camera.timerModeButton"].firstMatch
        XCTAssertTrue(timerButton.waitForExistence(timeout: 5))
        XCTAssertEqual(timerButton.value as? String, "3s")
        XCTAssertEqual(app.buttons["camera.shutterButton"].value as? String, "Ready")
    }

    @MainActor
    func testPhysicalProofIngestorReadinessExposesSummaryCountContract() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = app.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let accessibilityAudit = anyElement(in: app, identifier: "settings.accessibility.audit")
        reveal(accessibilityAudit, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(accessibilityAudit.waitForExistence(timeout: 5))
        let accessibilityAuditValue = accessibilityAudit.value as? String
        XCTAssertTrue(accessibilityAuditValue?.contains("Inclusive Design Audit") ?? false)
        XCTAssertTrue(accessibilityAuditValue?.contains("Minimum tap target 44 pt") ?? false)
        XCTAssertTrue(accessibilityAuditValue?.contains("Dynamic Type") ?? false)
        XCTAssertTrue(accessibilityAuditValue?.contains("Reduced Motion") ?? false)
        XCTAssertTrue(accessibilityAuditValue?.contains("High Contrast") ?? false)
        XCTAssertTrue(accessibilityAuditValue?.contains("does not prove physical-device accessibility") ?? false)
        XCTAssertFalse(accessibilityAuditValue?.contains("Physical proof captured") ?? true)

        let tapTargetAudit = anyElement(in: app, identifier: "settings.accessibility.audit.row.tapTargets")
        reveal(tapTargetAudit, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(tapTargetAudit.waitForExistence(timeout: 5))
        let tapTargetAuditValue = tapTargetAudit.value as? String
        XCTAssertTrue(tapTargetAuditValue?.contains("Verified") ?? false)

        let reducedMotionAudit = anyElement(in: app, identifier: "settings.accessibility.audit.row.reducedMotion")
        reveal(reducedMotionAudit, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(reducedMotionAudit.waitForExistence(timeout: 5))
        let reducedMotionAuditValue = reducedMotionAudit.value as? String
        XCTAssertTrue(reducedMotionAuditValue?.contains("Verified") ?? false)
        XCTAssertTrue(reducedMotionAuditValue?.contains("Settings sheet presentation/dismissal") ?? false)

        let highContrastAudit = anyElement(in: app, identifier: "settings.accessibility.audit.row.highContrast")
        reveal(highContrastAudit, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(highContrastAudit.waitForExistence(timeout: 5))
        let highContrastAuditValue = highContrastAudit.value as? String
        XCTAssertTrue(highContrastAuditValue?.contains("Verified") ?? false)
        XCTAssertTrue(highContrastAuditValue?.contains("strengthens row borders") ?? false)

        let labPreflight = anyElement(in: app, identifier: "settings.deviceProof.deviceLabPreflight")
        reveal(labPreflight, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(labPreflight.waitForExistence(timeout: 5))
        let labPreflightValue = labPreflight.value as? String
        XCTAssertTrue(labPreflightValue?.contains("Physical Device Lab Preflight") ?? false)
        XCTAssertTrue(labPreflightValue?.contains("Connected unlocked iPhone required") ?? false)
        XCTAssertTrue(labPreflightValue?.contains("No physical proof count changed") ?? false)
        XCTAssertTrue(labPreflightValue?.contains("platform=iOS,id=<DEVICE-UDID>") ?? false)
        XCTAssertTrue(labPreflightValue?.contains("does not execute commands") ?? false)
        XCTAssertFalse(labPreflightValue?.contains("Physical proof captured") ?? true)

        let deviceAvailabilityReport = anyElement(in: app, identifier: "settings.deviceProof.deviceAvailabilityReportImportPreview")
        reveal(deviceAvailabilityReport, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(deviceAvailabilityReport.waitForExistence(timeout: 5))
        let deviceAvailabilityReportValue = deviceAvailabilityReport.value as? String
        XCTAssertTrue(deviceAvailabilityReportValue?.contains("No host device availability report previewed") ?? false)
        XCTAssertTrue(deviceAvailabilityReportValue?.contains("host-device-availability preview only") ?? false)
        XCTAssertTrue(deviceAvailabilityReportValue?.contains("Connected unlocked iPhone still required") ?? false)
        XCTAssertTrue(deviceAvailabilityReportValue?.contains("No physical proof count changed") ?? false)
        XCTAssertFalse(deviceAvailabilityReportValue?.contains("Physical proof captured") ?? true)

        let proofIngestor = app.staticTexts["settings.deviceProof.proofIngestor"]
        reveal(proofIngestor, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(proofIngestor.waitForExistence(timeout: 5))

        let proofIngestorValue = proofIngestor.value as? String
        XCTAssertTrue(proofIngestorValue?.contains("schema v26") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("typed result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary total test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary passed test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary failed test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary counts match metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool compact test-results summary JSON") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("parsed result-bundle proof input") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool command plan") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle digest command plan") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario-bound result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("top-level xcresult summary counts") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle device/platform metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("physical xcresult platform") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle iOS build matches submission") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle device metadata in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary counts disagree with metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid xcresulttool compact summary JSON") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool summary timing window invalid") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("non-.xcresult result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("unsafe result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario bundle name mismatch") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("missing result-bundle device metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid result-bundle device metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("simulator result-bundle platform") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle device metadata disagrees with submission") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle device metadata") ?? false)
        XCTAssertFalse(proofIngestorValue?.contains("Physical proof captured") ?? true)

        let commandPlan = anyElement(in: app, identifier: "settings.deviceProof.proofIngestor.commandPlan")
        reveal(commandPlan, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(commandPlan.waitForExistence(timeout: 5))
        let commandPlanValue = commandPlan.value as? String
        XCTAssertTrue(commandPlanValue?.contains("Physical Result Bundle Command Plan") ?? false)
        XCTAssertTrue(commandPlanValue?.contains("shasum") ?? false)
        XCTAssertTrue(commandPlanValue?.contains("xcresulttool") ?? false)
        XCTAssertTrue(commandPlanValue?.contains("Copy/share only") ?? false)
        XCTAssertTrue(commandPlanValue?.contains("Does not execute commands or count physical proof") ?? false)
        XCTAssertFalse(commandPlanValue?.contains("Physical proof captured") ?? true)

        let labWorkspace = anyElement(in: app, identifier: "settings.deviceProof.proofIngestor.labWorkspace")
        reveal(labWorkspace, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(labWorkspace.waitForExistence(timeout: 5))
        let labWorkspaceValue = labWorkspace.value as? String
        XCTAssertTrue(labWorkspaceValue?.contains("Bracketer Physical Lab Workspace") ?? false)
        XCTAssertTrue(labWorkspaceValue?.contains("no physical proof captured") ?? false)
        XCTAssertTrue(labWorkspaceValue?.contains("Command Plan") ?? false)
        XCTAssertTrue(labWorkspaceValue?.contains("Seeded Physical Proof Template") ?? false)
        XCTAssertTrue(labWorkspaceValue?.contains("Copy/share only") ?? false)
        XCTAssertFalse(labWorkspaceValue?.contains("Physical proof captured") ?? true)

        let labReviewHandoffPackage = anyElement(in: app, identifier: "settings.deviceProof.proofIngestor.labReviewHandoffPackage")
        reveal(labReviewHandoffPackage, byScrolling: settingsScrollView, attempts: 6)
        XCTAssertTrue(labReviewHandoffPackage.waitForExistence(timeout: 5))
        let labReviewHandoffPackageValue = labReviewHandoffPackage.value as? String
        XCTAssertTrue(labReviewHandoffPackageValue?.contains("Bracketer Physical Lab Review Handoff Package") ?? false)
        XCTAssertTrue(labReviewHandoffPackageValue?.contains("physical-package-manifest.json") ?? false)
        XCTAssertTrue(labReviewHandoffPackageValue?.contains("reviewer-checklist") ?? false)
        XCTAssertTrue(labReviewHandoffPackageValue?.contains("Copy/share only") ?? false)
        XCTAssertTrue(labReviewHandoffPackageValue?.contains("no physical proof captured") ?? false)
        XCTAssertFalse(labReviewHandoffPackageValue?.contains("Physical proof captured") ?? true)

        let labWorkspaceImportPreview = anyElement(in: app, identifier: "settings.deviceProof.proofIngestor.labWorkspaceImportPreview")
        reveal(labWorkspaceImportPreview, byScrolling: settingsScrollView, attempts: 6)
        XCTAssertTrue(labWorkspaceImportPreview.waitForExistence(timeout: 5))
        let labWorkspaceImportPreviewValue = labWorkspaceImportPreview.value as? String
        XCTAssertTrue(labWorkspaceImportPreviewValue?.contains("No physical lab workspace previewed") ?? false)
        XCTAssertTrue(labWorkspaceImportPreviewValue?.contains("physical-lab-workspace preview only") ?? false)
        XCTAssertTrue(labWorkspaceImportPreviewValue?.contains("Import preview does not mutate runbooks or result-bundle indexes") ?? false)
        XCTAssertTrue(labWorkspaceImportPreviewValue?.contains("No physical proof count changed") ?? false)
        XCTAssertFalse(labWorkspaceImportPreviewValue?.contains("Physical proof captured") ?? true)

        let labReviewHandoffPackageImportPreview = anyElement(in: app, identifier: "settings.deviceProof.proofIngestor.labReviewHandoffPackageImportPreview")
        reveal(labReviewHandoffPackageImportPreview, byScrolling: settingsScrollView, attempts: 7)
        XCTAssertTrue(labReviewHandoffPackageImportPreview.waitForExistence(timeout: 5))
        let labReviewHandoffPackageImportPreviewValue = labReviewHandoffPackageImportPreview.value as? String
        XCTAssertTrue(labReviewHandoffPackageImportPreviewValue?.contains("No physical lab handoff package previewed") ?? false)
        XCTAssertTrue(labReviewHandoffPackageImportPreviewValue?.contains("physical-lab-review-handoff preview only") ?? false)
        XCTAssertTrue(labReviewHandoffPackageImportPreviewValue?.contains("Import preview does not mutate runbooks or result-bundle indexes") ?? false)
        XCTAssertTrue(labReviewHandoffPackageImportPreviewValue?.contains("No physical proof count changed") ?? false)
        XCTAssertFalse(labReviewHandoffPackageImportPreviewValue?.contains("Physical proof captured") ?? true)
    }

    @MainActor
    func testDeviceAvailabilityReportPreviewShowsLockedXcodebuildVerdictFromLaunchFixture() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-preview-locked-device-availability-report",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = app.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let deviceAvailabilityReport = anyElement(in: app, identifier: "settings.deviceProof.deviceAvailabilityReportImportPreview")
        reveal(deviceAvailabilityReport, byScrolling: settingsScrollView, attempts: 6)
        XCTAssertTrue(deviceAvailabilityReport.waitForExistence(timeout: 5))
        let value = deviceAvailabilityReport.value as? String

        XCTAssertTrue(value?.contains("Previewed ui-testing-locked-xcodebuild-preflight.txt") ?? false)
        XCTAssertTrue(value?.contains("Host Device Availability Report") ?? false)
        XCTAssertTrue(value?.contains("xcodebuild destinations/preflight") ?? false)
        XCTAssertTrue(value?.contains("1 physical iPhone row(s)") ?? false)
        XCTAssertTrue(value?.contains("1 locked") ?? false)
        XCTAssertTrue(value?.contains("Blocked: physical iPhone is locked") ?? false)
        XCTAssertTrue(value?.contains("Unlock the iPhone before running the physical lab") ?? false)
        XCTAssertTrue(value?.contains("Import preview does not mutate runbooks or result-bundle indexes") ?? false)
        XCTAssertTrue(value?.contains("No physical proof count changed") ?? false)
        XCTAssertFalse(value?.contains("00008150-00027C3E0108401C") ?? true)
        XCTAssertFalse(value?.contains("Physical proof captured") ?? true)
    }

    @MainActor
    func testAccessibilityAuditTapTargetContractListsCameraChromeControls() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = app.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let tapTargetAudit = anyElement(in: app, identifier: "settings.accessibility.audit.row.tapTargets")
        reveal(tapTargetAudit, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(tapTargetAudit.waitForExistence(timeout: 5))

        let value = tapTargetAudit.value as? String
        XCTAssertTrue(value?.contains("Verified") ?? false)
        XCTAssertTrue(value?.contains("Apple Intelligence refresh/recipe controls") ?? false)
        XCTAssertTrue(value?.contains("camera chrome buttons") ?? false)
        XCTAssertTrue(value?.contains("Compact PRO top-bar button") ?? false)
        XCTAssertTrue(value?.contains("Settings close button") ?? false)
    }

    @MainActor
    func testAccessibilityAuditReflectsForcedAccessibilityEnvironment() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-force-accessibility-environment",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = app.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let environment = anyElement(in: app, identifier: "settings.accessibility.environment")
        reveal(environment, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(environment.waitForExistence(timeout: 5))
        let environmentValue = environment.value as? String
        XCTAssertTrue(environmentValue?.contains("UI-test forced accessibility environment") ?? false)
        XCTAssertTrue(environmentValue?.contains("Dynamic Type: Accessibility 3") ?? false)
        XCTAssertTrue(environmentValue?.contains("Accessibility dynamic type: Yes") ?? false)
        XCTAssertTrue(environmentValue?.contains("Reduce Motion: On") ?? false)
        XCTAssertTrue(environmentValue?.contains("High Contrast: Increased") ?? false)

        let dynamicTypeRow = anyElement(in: app, identifier: "settings.accessibility.audit.row.dynamicType")
        reveal(dynamicTypeRow, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(dynamicTypeRow.waitForExistence(timeout: 5))
        let dynamicTypeValue = dynamicTypeRow.value as? String
        XCTAssertTrue(dynamicTypeValue?.contains("Verified") ?? false)
        XCTAssertTrue(dynamicTypeValue?.contains("Observed Dynamic Type: Accessibility 3") ?? false)
        XCTAssertTrue(dynamicTypeValue?.contains("semantic text styles") ?? false)
        XCTAssertTrue(dynamicTypeValue?.contains("Dynamic Type layout: Stacked") ?? false)

        let reducedMotionRow = anyElement(in: app, identifier: "settings.accessibility.audit.row.reducedMotion")
        reveal(reducedMotionRow, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(reducedMotionRow.waitForExistence(timeout: 5))
        XCTAssertTrue((reducedMotionRow.value as? String)?.contains("Verified") ?? false)

        let highContrastRow = anyElement(in: app, identifier: "settings.accessibility.audit.row.highContrast")
        reveal(highContrastRow, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(highContrastRow.waitForExistence(timeout: 5))
        XCTAssertTrue((highContrastRow.value as? String)?.contains("Verified") ?? false)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Settings About Accessibility Audit - Accessibility 3"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testAccessibilityScreenshotMatrixCapturesCameraAndSettingsSurfaces() throws {
        let cameraApp = XCUIApplication()
        cameraApp.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-force-portrait-layout",
            "-ui-testing-force-accessibility-environment",
        ]
        cameraApp.launch()

        let cameraChrome = anyElement(in: cameraApp, identifier: "camera.chromeLayout")
        XCTAssertTrue(cameraChrome.waitForExistence(timeout: 5))
        XCTAssertEqual(cameraChrome.value as? String, "Portrait")
        XCTAssertTrue(cameraApp.buttons["camera.captureCoach.card"].waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement(in: cameraApp, identifier: "camera.bracketPlan.strip").waitForExistence(timeout: 5))
        XCTAssertTrue(cameraApp.buttons["camera.shutterButton"].waitForExistence(timeout: 5))
        keepScreenshot(from: cameraApp, named: "Accessibility Matrix - Camera Cockpit - Accessibility 3")

        let settingsButton = cameraApp.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = cameraApp.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = cameraApp.scrollViews["settings.scrollView"].firstMatch
        let environment = anyElement(in: cameraApp, identifier: "settings.accessibility.environment")
        reveal(environment, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(environment.waitForExistence(timeout: 5))
        XCTAssertTrue((environment.value as? String)?.contains("Dynamic Type: Accessibility 3") ?? false)
        XCTAssertTrue((environment.value as? String)?.contains("Reduce Motion: On") ?? false)
        XCTAssertTrue((environment.value as? String)?.contains("High Contrast: Increased") ?? false)

        let screenshotMatrix = anyElement(in: cameraApp, identifier: "settings.accessibility.screenshotMatrix")
        reveal(screenshotMatrix, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(screenshotMatrix.waitForExistence(timeout: 5))
        let screenshotMatrixValue = screenshotMatrix.value as? String
        XCTAssertTrue(screenshotMatrixValue?.contains("Accessibility Screenshot Matrix") ?? false)
        XCTAssertTrue(screenshotMatrixValue?.contains("Camera Cockpit") ?? false)
        XCTAssertTrue(screenshotMatrixValue?.contains("Project Review Handoff") ?? false)
        XCTAssertTrue(screenshotMatrixValue?.contains("Accessibility Matrix - Project Review - Accessibility 3") ?? false)
        keepScreenshot(from: cameraApp, named: "Accessibility Matrix - Settings About - Accessibility 3")
    }

    @MainActor
    func testAccessibilityScreenshotMatrixCapturesProjectReviewSurface() throws {
        let reviewApp = XCUIApplication()
        reviewApp.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-force-accessibility-environment",
            "-ui-testing-open-review-accessibility-fixture",
        ]
        reviewApp.launch()

        let reviewAccessibility = anyElement(in: reviewApp, identifier: "review.project.accessibility")
        XCTAssertTrue(reviewAccessibility.waitForExistence(timeout: 5))
        let reviewAccessibilityValue = reviewAccessibility.value as? String
        XCTAssertTrue(reviewAccessibilityValue?.contains("Review Workspace Accessibility Contract") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("Minimum tap target 44 pt") ?? false)
        XCTAssertTrue(reviewApp.buttons["review.project.previousShotButton"].exists)
        XCTAssertTrue(reviewApp.buttons["review.project.nextShotButton"].exists)
        XCTAssertTrue(reviewApp.buttons["review.project.representationToggle"].exists)
        XCTAssertTrue(reviewApp.buttons["review.project.closeButton"].exists)
        keepScreenshot(from: reviewApp, named: "Accessibility Matrix - Project Review - Accessibility 3")
    }

    @MainActor
    func testAppleIntelligenceAvailabilityCanBeForcedForUITests() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-intelligence-model-not-ready",
            "-ui-testing-bracket-recipe-prompt-high-contrast",
        ]
        app.launch()

        let expectedAvailability = "Apple Intelligence | Model not ready | The on-device model is still downloading or preparing. | Action: Keep the device online and plugged in until the model is ready."
        let expectedCoachSuggestion = "Apple Intelligence unavailable | The on-device model is still downloading or preparing. | Action: Keep the device online and plugged in until the model is ready."

        let coachCard = app.buttons["camera.captureCoach.card"]
        XCTAssertTrue(coachCard.waitForExistence(timeout: 5))
        XCTAssertEqual(
            coachCard.value as? String,
            "\(expectedCoachSuggestion) | Source: deterministicFallback | Not refreshed in this session."
        )
        let bracketStrip = anyElement(in: app, identifier: "camera.bracketPlan.strip")
        XCTAssertTrue(bracketStrip.waitForExistence(timeout: 5))
        XCTAssertEqual(bracketStrip.value as? String, "3 shots | -1.0 EV, 0 EV, +1.0 EV | Center 0 EV")
        coachCard.tap()

        let settingsAvailability = anyElement(in: app, identifier: "settings.intelligence.availability")
        XCTAssertTrue(settingsAvailability.waitForExistence(timeout: 5))
        XCTAssertEqual(settingsAvailability.value as? String, expectedAvailability)
        XCTAssertTrue(app.staticTexts["settings.intelligence.recoveryAction"].waitForExistence(timeout: 5))

        let runtimeDiagnostic = anyElement(in: app, identifier: "settings.intelligence.runtimeDiagnostic")
        XCTAssertTrue(runtimeDiagnostic.waitForExistence(timeout: 5))
        XCTAssertEqual(
            runtimeDiagnostic.value as? String,
            "Deterministic fallback active | Availability: Model not ready. Coach: deterministicFallback without Apple Intelligence. Recipe: deterministicFallback without Apple Intelligence. | Action: Keep the device online and plugged in until the model is ready."
        )

        let coachSource = anyElement(in: app, identifier: "settings.intelligence.coach.source")
        XCTAssertTrue(coachSource.waitForExistence(timeout: 5))
        XCTAssertEqual(coachSource.value as? String, "deterministicFallback | Not refreshed in this session.")

        let coachSuggestion = anyElement(in: app, identifier: "settings.intelligence.coach.suggestion.0")
        XCTAssertTrue(coachSuggestion.waitForExistence(timeout: 5))
        XCTAssertEqual(coachSuggestion.value as? String, expectedCoachSuggestion)

        let refreshCoach = app.buttons["settings.intelligence.coach.refresh"]
        XCTAssertTrue(refreshCoach.waitForExistence(timeout: 5))
        refreshCoach.tap()
        XCTAssertTrue(
            waitForValue(
                coachSource,
                "deterministicFallback | Apple Intelligence unavailable: Model not ready",
                timeout: 5
            )
        )

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let recipeSource = anyElement(in: app, identifier: "settings.intelligence.recipe.source")
        reveal(recipeSource, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(recipeSource.waitForExistence(timeout: 5))
        XCTAssertEqual(recipeSource.value as? String, "deterministicFallback | Not planned in this session.")

        let recipePlan = app.buttons["settings.intelligence.recipe.plan"]
        revealForTap(recipePlan, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(recipePlan.waitForExistence(timeout: 5))
        recipePlan.tap()
        XCTAssertTrue(
            waitForValue(
                recipeSource,
                "deterministicFallback | Apple Intelligence unavailable: Model not ready",
                timeout: 5
            )
        )

        let recipeRecommendation = anyElement(in: app, identifier: "settings.intelligence.recipe.recommendation.0")
        XCTAssertTrue(recipeRecommendation.waitForExistence(timeout: 5))

        let recipeEvidence = anyElement(in: app, identifier: "settings.intelligence.recipe.evidence.0")
        XCTAssertTrue(recipeEvidence.waitForExistence(timeout: 5))
        let recipeEvidenceValue = (recipeEvidence.value as? String) ?? recipeEvidence.label
        XCTAssertTrue(recipeEvidenceValue.contains("Confidence"))
        XCTAssertTrue(recipeEvidenceValue.contains("Sources:"))
        XCTAssertFalse(recipeEvidenceValue.contains("No source signals recorded"))

        let applyRecipe = app.buttons["settings.intelligence.recipe.apply.0"]
        revealForTap(applyRecipe, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(applyRecipe.waitForExistence(timeout: 5))
        applyRecipe.tap()

        let appliedRecipe = anyElement(in: app, identifier: "settings.intelligence.recipe.applied")
        XCTAssertTrue(appliedRecipe.waitForExistence(timeout: 5))
        XCTAssertEqual(
            appliedRecipe.value as? String,
            "High contrast scene | 5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV | Source: deterministicFallback"
        )
        XCTAssertEqual(
            anyElement(in: app, identifier: "camera.bracketPlan.current").value as? String,
            "5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV"
        )

        let recentRecipe = anyElement(in: app, identifier: "settings.intelligence.recipe.recent.0")
        reveal(recentRecipe, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(recentRecipe.waitForExistence(timeout: 5))
        XCTAssertEqual(
            recentRecipe.value as? String,
            "High contrast scene | 5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV | Source: deterministicFallback"
        )

        let closeSettings = app.buttons["settings.closeButton"]
        XCTAssertTrue(closeSettings.waitForExistence(timeout: 5))
        closeSettings.tap()

        let activeBracketStrip = anyElement(in: app, identifier: "camera.bracketPlan.strip")
        XCTAssertTrue(activeBracketStrip.waitForExistence(timeout: 5))
        XCTAssertEqual(
            activeBracketStrip.value as? String,
            "5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV | Recipe: High contrast scene | Source: deterministicFallback"
        )
        activeBracketStrip.tap()
        XCTAssertTrue(settingsAvailability.waitForExistence(timeout: 5))
        XCTAssertTrue(closeSettings.waitForExistence(timeout: 5))
        closeSettings.tap()

        let shutterButton = app.buttons["camera.shutterButton"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 5))
        shutterButton.tap()

        let reviewRecipe = anyElement(in: app, identifier: "review.sequence.manifestRecipe")
        XCTAssertTrue(reviewRecipe.waitForExistence(timeout: 10))
        XCTAssertEqual(
            reviewRecipe.value as? String,
            "High contrast scene | 5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV | Source: deterministicFallback"
        )

        let simulatedManifestShare = app.buttons["review.sequence.manifestShareButton"]
        XCTAssertTrue(simulatedManifestShare.waitForExistence(timeout: 5))
        let simulatedManifest = simulatedManifestShare.value as? String
        XCTAssertTrue(simulatedManifest?.contains("\"recipe\" : {") ?? false)
        XCTAssertTrue(simulatedManifest?.contains("\"title\" : \"High contrast scene\"") ?? false)

        let narrativeCard = anyElement(in: app, identifier: "review.narrative.card")
        XCTAssertTrue(narrativeCard.waitForExistence(timeout: 5))
        let narrativeValue = narrativeCard.value as? String
        XCTAssertTrue(narrativeValue?.contains("Deterministic review") ?? false)
        XCTAssertTrue(narrativeValue?.contains("5-shot simulated bracket") ?? false)
        XCTAssertTrue(narrativeValue?.contains("Recipe: High contrast scene") ?? false)
        XCTAssertTrue(narrativeValue?.contains("Use the center shot as merge anchor") ?? false)
    }

    @MainActor
    func testBracketRecipeEvidenceSummaryAppearsAfterPlanning() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-intelligence-model-not-ready",
            "-ui-testing-bracket-recipe-prompt-high-contrast",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aiTab = app.segmentedControls.buttons["AI"]
        XCTAssertTrue(aiTab.waitForExistence(timeout: 5))
        aiTab.tap()

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let recipePlan = app.buttons["settings.intelligence.recipe.plan"]
        revealForTap(recipePlan, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(recipePlan.waitForExistence(timeout: 5))
        recipePlan.tap()

        let recipeSource = anyElement(in: app, identifier: "settings.intelligence.recipe.source")
        XCTAssertTrue(
            waitForValue(
                recipeSource,
                "deterministicFallback | Apple Intelligence unavailable: Model not ready",
                timeout: 5
            )
        )

        let recipeEvidence = anyElement(in: app, identifier: "settings.intelligence.recipe.evidence.0")
        reveal(recipeEvidence, byScrolling: settingsScrollView, attempts: 3)
        XCTAssertTrue(recipeEvidence.waitForExistence(timeout: 5))
        let recipeEvidenceValue = (recipeEvidence.value as? String) ?? recipeEvidence.label
        XCTAssertTrue(recipeEvidenceValue.contains("Confidence"))
        XCTAssertTrue(recipeEvidenceValue.contains("Sources:"))
        XCTAssertFalse(recipeEvidenceValue.contains("No source signals recorded"))
    }

    @MainActor
    func testDeviceCapabilitiesPhotosDeniedShowsExactRecoveryPath() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-device-capabilities-photos-denied",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["deviceCompatibility.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["deviceCompatibility.status"].label, "Compatible Device Required")

        let photosAction = app.staticTexts["deviceCompatibility.issue.photos.denied.action"]
        XCTAssertTrue(photosAction.waitForExistence(timeout: 5))
        XCTAssertEqual(
            photosAction.label,
            "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only"
        )
        XCTAssertFalse(app.buttons["camera.shutterButton"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testHistogramOverlayLaunchArgumentAndProToggleExposeState() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-show-histogram",
        ]
        app.launch()

        let histogramOverlay = anyElement(in: app, identifier: "camera.histogramOverlay")
        XCTAssertTrue(histogramOverlay.waitForExistence(timeout: 5))
        XCTAssertEqual(histogramOverlay.value as? String, "RGB Histogram")

        let histogramDiagnosticsSummary = anyElement(in: app, identifier: "camera.histogramDiagnostics.summary")
        XCTAssertTrue(histogramDiagnosticsSummary.waitForExistence(timeout: 5))
        XCTAssertEqual(histogramDiagnosticsSummary.value as? String, "0 events | No diagnostics")
        XCTAssertEqual(
            anyElement(in: app, identifier: "camera.histogramDiagnostics.latest").value as? String,
            "No diagnostics"
        )

        let proButton = app.buttons["camera.proControlsButton"]
        XCTAssertTrue(proButton.waitForExistence(timeout: 5))
        proButton.tap()
        XCTAssertTrue(app.staticTexts["Pro Controls"].waitForExistence(timeout: 5))

        let exposureHeader = app.buttons["Exposure"]
        XCTAssertTrue(exposureHeader.waitForExistence(timeout: 5))
        exposureHeader.tap()

        let histogramToggle = app.switches["pro.histogramToggle"]
        XCTAssertTrue(histogramToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForAnyValue(histogramToggle, ["On", "1"]))
        histogramToggle.tap()
        XCTAssertTrue(waitForAnyValue(histogramToggle, ["Off", "0"]))
        XCTAssertFalse(anyElement(in: app, identifier: "camera.histogramOverlay").waitForExistence(timeout: 1))
    }

    @MainActor
    func testZebraOverlayLaunchArgumentAndProToggleExposeAnalysisState() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-show-zebras",
        ]
        app.launch()

        let zebraOverlay = anyElement(in: app, identifier: "camera.zebraOverlay")
        XCTAssertTrue(zebraOverlay.waitForExistence(timeout: 5))
        XCTAssertEqual(zebraOverlay.value as? String, "Highlights 25%, Shadows 25%, Regions 8")

        let proButton = app.buttons["camera.proControlsButton"]
        XCTAssertTrue(proButton.waitForExistence(timeout: 5))
        proButton.tap()
        XCTAssertTrue(app.staticTexts["Pro Controls"].waitForExistence(timeout: 5))

        let exposureHeader = app.buttons["Exposure"]
        XCTAssertTrue(exposureHeader.waitForExistence(timeout: 5))
        exposureHeader.tap()

        let zebraToggle = app.switches["pro.zebraToggle"]
        XCTAssertTrue(zebraToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForAnyValue(zebraToggle, ["On", "1"]))
        zebraToggle.tap()
        XCTAssertTrue(waitForAnyValue(zebraToggle, ["Off", "0"]))
        XCTAssertFalse(anyElement(in: app, identifier: "camera.zebraOverlay").waitForExistence(timeout: 1))
    }

    @MainActor
    func testFocusPeakingLaunchArgumentAndProToggleExposeAnalysisState() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-show-focus-peaking",
        ]
        app.launch()

        let focusOverlay = anyElement(in: app, identifier: "camera.focusPeakingOverlay")
        XCTAssertTrue(focusOverlay.waitForExistence(timeout: 5))
        XCTAssertEqual(focusOverlay.value as? String, "Analysis regions 15")

        let proButton = app.buttons["camera.proControlsButton"]
        XCTAssertTrue(proButton.waitForExistence(timeout: 5))
        proButton.tap()
        XCTAssertTrue(app.staticTexts["Pro Controls"].waitForExistence(timeout: 5))

        let focusHeader = app.buttons["Focus"]
        XCTAssertTrue(focusHeader.waitForExistence(timeout: 5))
        focusHeader.tap()

        let focusToggle = app.switches["pro.focusPeakingToggle"]
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForAnyValue(focusToggle, ["On", "1"]))
        focusToggle.tap()
        XCTAssertTrue(waitForAnyValue(focusToggle, ["Off", "0"]))
        XCTAssertFalse(anyElement(in: app, identifier: "camera.focusPeakingOverlay").waitForExistence(timeout: 1))
    }

    @MainActor
    func testCaptureSettingsShowEffectiveConfigurationWhenCameraStartupIsDisabled() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        let captureSettingsTab = app.segmentedControls.buttons["Capture"]
        XCTAssertTrue(captureSettingsTab.waitForExistence(timeout: 5))
        captureSettingsTab.tap()

        let settingsScrollView = app.scrollViews.firstMatch
        if settingsScrollView.waitForExistence(timeout: 2) {
            settingsScrollView.swipeUp()
        }

        let photoFormatValue = app.staticTexts["settings.badge.photoFormat.value"]
        XCTAssertTrue(photoFormatValue.waitForExistence(timeout: 5))
        XCTAssertTrue(["HEIF/JPEG", "ProRAW"].contains(photoFormatValue.label))
        XCTAssertEqual(app.staticTexts["settings.badge.flash.value"].label, "Unavailable")
        XCTAssertEqual(app.staticTexts["settings.badge.location.value"].label, "Pending")
    }

    @MainActor
    func testSettingsPresetsAndCaptureControlsExposeStableState() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
        ]
        app.launch()

        let timerButton = app.buttons["camera.timerModeButton"].firstMatch
        XCTAssertTrue(timerButton.waitForExistence(timeout: 5))
        XCTAssertEqual(timerButton.value as? String, "Off")
        timerButton.tap()

        let threeSecondTimer = app.buttons["3s"].firstMatch
        XCTAssertTrue(threeSecondTimer.waitForExistence(timeout: 5))
        threeSecondTimer.tap()
        XCTAssertTrue(waitForValue(timerButton, "3s"))

        let flashButton = app.buttons["camera.flashModeButton"].firstMatch
        XCTAssertTrue(flashButton.waitForExistence(timeout: 5))
        XCTAssertEqual(flashButton.value as? String, "Unavailable")

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["settings.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["settings.categoryPicker"].waitForExistence(timeout: 5))

        let settingsScrollView = app.scrollViews["settings.scrollView"].firstMatch
        let landscapePreset = app.buttons["settings.preset.landscape"]
        revealForTap(landscapePreset, byScrolling: settingsScrollView)
        XCTAssertTrue(landscapePreset.waitForExistence(timeout: 5))
        landscapePreset.tap()

        XCTAssertTrue(app.switches["settings.toggle.grid"].waitForExistence(timeout: 5))
        XCTAssertSwitch(app.switches["settings.toggle.grid"], isOn: true)
        XCTAssertSwitch(app.switches["settings.toggle.level"], isOn: true)
        XCTAssertEqual(app.buttons["settings.picker.gridStyle"].value as? String, "Golden Ratio")

        let focusTab = app.segmentedControls.buttons["Focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 5))
        focusTab.tap()

        let portraitPreset = app.buttons["settings.preset.portrait"]
        revealForTap(portraitPreset, byScrolling: settingsScrollView)
        XCTAssertTrue(portraitPreset.waitForExistence(timeout: 5))
        portraitPreset.tap()

        let focusToggle = app.switches["settings.toggle.focusPeaking"]
        revealForTap(focusToggle, byScrolling: settingsScrollView)
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 5))
        XCTAssertSwitch(focusToggle, isOn: true)
        XCTAssertEqual(app.staticTexts["settings.focusPeakingIntensity.value"].label, "65%")
        let selectedPeakingColor = app.staticTexts["settings.focusPeakingColor.title"]
        reveal(selectedPeakingColor, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(selectedPeakingColor.waitForExistence(timeout: 5))
        XCTAssertEqual(selectedPeakingColor.value as? String, "orange")

        let captureTab = app.segmentedControls.buttons["Capture"]
        XCTAssertTrue(captureTab.waitForExistence(timeout: 5))
        captureTab.tap()

        let timerBadge = app.staticTexts["settings.badge.timer.value"]
        reveal(timerBadge, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(timerBadge.waitForExistence(timeout: 5))
        XCTAssertEqual(timerBadge.label, "3s")
        XCTAssertEqual(app.staticTexts["settings.badge.flash.value"].label, "Unavailable")
        XCTAssertTrue(["HEIF/JPEG", "ProRAW"].contains(app.staticTexts["settings.badge.photoFormat.value"].label))
    }

    @MainActor
    func testCameraChromeExposesPortraitAndLandscapeContracts() throws {
        let portraitApp = launchCameraChromeApp(forceLandscape: false)
        assertCameraChrome(in: portraitApp, expectedLayout: "Portrait")

        let gridToggle = portraitApp.buttons["camera.gridToggleButton"].firstMatch
        XCTAssertTrue(gridToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(gridToggle.value as? String, "On")
        gridToggle.tap()
        XCTAssertTrue(waitForValue(gridToggle, "Off"))
        gridToggle.tap()
        XCTAssertTrue(waitForValue(gridToggle, "On"))

        let modeButton = portraitApp.buttons["camera.shootingModeButton"].firstMatch
        XCTAssertTrue(modeButton.waitForExistence(timeout: 5))
        XCTAssertEqual(modeButton.value as? String, "AUTO")
        modeButton.tap()

        let nightMode = portraitApp.buttons["NIGHT"].firstMatch
        XCTAssertTrue(nightMode.waitForExistence(timeout: 5))
        nightMode.tap()
        XCTAssertTrue(waitForValue(modeButton, "NIGHT"))
        XCTAssertTrue(waitForValue(anyElement(in: portraitApp, identifier: "camera.secondaryControls"), "Night"))

        portraitApp.terminate()

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeApp = launchCameraChromeApp(forceLandscape: true)
        assertCameraChrome(in: landscapeApp, expectedLayout: "Landscape")
    }

    @MainActor
    func testSimulatedBracketCaptureCompletesAndOpensReview() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-reset-projects",
            "-ui-testing-simulated-camera",
        ]
        app.launch()

        let proButton = app.buttons["camera.proControlsButton"]
        XCTAssertTrue(proButton.waitForExistence(timeout: 5))
        proButton.tap()
        XCTAssertTrue(app.staticTexts["Pro Controls"].waitForExistence(timeout: 5))

        let proScrollView = app.scrollViews.firstMatch
        let evStepButton = app.buttons["pro.evStep.2"]
        reveal(evStepButton, byScrolling: proScrollView)
        XCTAssertTrue(evStepButton.waitForExistence(timeout: 5))
        evStepButton.tap()

        let fiveShotButton = app.buttons["pro.shotCount.5"]
        reveal(fiveShotButton, byScrolling: proScrollView)
        XCTAssertTrue(fiveShotButton.waitForExistence(timeout: 5))
        fiveShotButton.tap()

        let closeButton = app.buttons["pro.closeButton"]
        if closeButton.waitForExistence(timeout: 5) {
            closeButton.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }

        let shutterButton = app.buttons["camera.shutterButton"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 5))
        shutterButton.tap()

        XCTAssertTrue(app.staticTexts["review.simulated.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["review.simulated.summary"].label, "5 shots · +/-2.0 EV")
        XCTAssertEqual(app.staticTexts["review.sequence.count"].label, "5 shots")
        XCTAssertEqual(app.staticTexts["review.sequence.timestamp"].label, "1970-01-01T00:00:00Z")
        XCTAssertEqual(app.staticTexts["review.sequence.selectedIndex"].label, "1 of 5")
        XCTAssertEqual(app.staticTexts["review.sequence.selectedEV"].label, "-4.0 EV")
        XCTAssertEqual(app.staticTexts["review.sequence.selectedFileType"].label, "HEIF/JPEG")
        XCTAssertEqual(app.staticTexts["review.sequence.selectedCaptureState"].label, "Available")
        XCTAssertEqual(app.staticTexts["review.sequence.metadataStatus"].label, "Metadata unavailable")
        let simulatedManifestShare = app.buttons["review.sequence.manifestShareButton"]
        XCTAssertTrue(simulatedManifestShare.waitForExistence(timeout: 5))
        XCTAssertTrue((simulatedManifestShare.value as? String)?.contains("\"source\" : \"simulated\"") ?? false)

        let nextButton = app.buttons["review.sequence.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.sequence.selectedEV"], "-2.0 EV"))
        nextButton.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.sequence.selectedEV"], "0 EV"))
        XCTAssertTrue(anyElement(in: app, identifier: "review.sequence.bestExposureBadge").waitForExistence(timeout: 5))

        nextButton.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.sequence.selectedEV"], "+2.0 EV"))
        XCTAssertTrue(anyElement(in: app, identifier: "review.sequence.clippingWarning").waitForExistence(timeout: 5))

        let representationToggle = app.buttons["review.sequence.representationToggle"]
        XCTAssertTrue(representationToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(representationToggle.value as? String, "Processed")
        representationToggle.tap()
        XCTAssertTrue(waitForValue(representationToggle, "RAW unavailable"))

        let metadataToggle = app.buttons["review.sequence.metadataToggle"]
        XCTAssertTrue(metadataToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(metadataToggle.value as? String, "Hidden")
        metadataToggle.tap()
        XCTAssertTrue(waitForValue(metadataToggle, "Shown"))
        XCTAssertTrue(anyElement(in: app, identifier: "review.sequence.metadataPanel").waitForExistence(timeout: 5))

        let deleteButton = app.buttons["review.sequence.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        let removeShotButton = app.buttons["Remove Shot"]
        XCTAssertTrue(removeShotButton.waitForExistence(timeout: 5))
        removeShotButton.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.sequence.count"], "4 shots"))

        let reviewScrollView = app.scrollViews.firstMatch
        let lastRemainingRow = app.buttons["review.sequence.shot.4"]
        revealForTap(lastRemainingRow, byScrolling: reviewScrollView, attempts: 5)
        XCTAssertTrue(lastRemainingRow.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.simulated.shot.4.label"].label, "+4.0 EV")
        XCTAssertTrue(app.staticTexts["review.simulated.disclaimer"].exists)

        let closeReview = app.buttons["review.simulated.closeButton"]
        XCTAssertTrue(closeReview.waitForExistence(timeout: 5))
        closeReview.tap()

        let latestProjectProbe = anyElement(in: app, identifier: "camera.project.latest")
        XCTAssertTrue(latestProjectProbe.waitForExistence(timeout: 5))
        XCTAssertTrue((latestProjectProbe.value as? String)?.contains("project-simulated") ?? false)
        XCTAssertTrue((latestProjectProbe.value as? String)?.contains("5 shots") ?? false)
        XCTAssertTrue((latestProjectProbe.value as? String)?.contains("No raw photo bytes") ?? false)

        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-preview-final-output-readiness-audit-import-failure",
        ]
        relaunchedApp.launch()

        let relaunchedProjectProbe = anyElement(in: relaunchedApp, identifier: "camera.project.latest")
        XCTAssertTrue(relaunchedProjectProbe.waitForExistence(timeout: 5))
        XCTAssertTrue((relaunchedProjectProbe.value as? String)?.contains("project-simulated") ?? false)
        XCTAssertTrue((relaunchedProjectProbe.value as? String)?.contains("5 shots") ?? false)

        let settingsButton = relaunchedApp.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutTab = relaunchedApp.segmentedControls.buttons["About"]
        XCTAssertTrue(aboutTab.waitForExistence(timeout: 5))
        aboutTab.tap()

        let settingsScrollView = relaunchedApp.scrollViews["settings.scrollView"].firstMatch
        let privacyTrust = anyElement(in: relaunchedApp, identifier: "settings.privacyTrust.summary")
        reveal(privacyTrust, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(privacyTrust.waitForExistence(timeout: 5))
        let privacyTrustValue = privacyTrust.value as? String
        XCTAssertTrue(privacyTrustValue?.contains("Privacy Trust Center") ?? false)
        XCTAssertTrue(privacyTrustValue?.contains("Local Computation") ?? false)
        XCTAssertTrue(privacyTrustValue?.contains("Location Policy") ?? false)
        XCTAssertTrue(privacyTrustValue?.contains("Generated project-note storage is Off") ?? false)
        XCTAssertTrue(privacyTrustValue?.contains("No precise coordinates") ?? false)

        let privacyTrustLocation = anyElement(in: relaunchedApp, identifier: "settings.privacyTrust.row.locationPolicy")
        reveal(privacyTrustLocation, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(privacyTrustLocation.waitForExistence(timeout: 5))
        let privacyTrustLocationValue = privacyTrustLocation.value as? String
        XCTAssertTrue(privacyTrustLocationValue?.contains("Simulated Location Not Requested") ?? false)
        XCTAssertTrue(privacyTrustLocationValue?.contains("No precise coordinates") ?? false)

        let privacyTrustGeneratedContent = anyElement(in: relaunchedApp, identifier: "settings.privacyTrust.row.generatedContent")
        reveal(privacyTrustGeneratedContent, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(privacyTrustGeneratedContent.waitForExistence(timeout: 5))
        let privacyTrustGeneratedContentValue = privacyTrustGeneratedContent.value as? String
        XCTAssertTrue(privacyTrustGeneratedContentValue?.contains("Generated project-note storage is Off") ?? false)
        XCTAssertTrue(privacyTrustGeneratedContentValue?.contains("sidecar omits generated notes") ?? false)

        let generatedNotesStorage = anyElement(in: relaunchedApp, identifier: "settings.privacyTrust.generatedNotesStorage")
        reveal(generatedNotesStorage, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertSwitch(generatedNotesStorage, isOn: false)

        let deviceProof = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.summary")
        reveal(deviceProof, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(deviceProof.waitForExistence(timeout: 5))
        let deviceProofValue = deviceProof.value as? String
        XCTAssertTrue(deviceProofValue?.contains("Physical Device Proof Checklist") ?? false)
        XCTAssertTrue(deviceProofValue?.contains("0 physical proofs captured") ?? false)
        XCTAssertTrue(deviceProofValue?.contains("Simulator evidence is not physical iPhone proof") ?? false)

        let liveFoundationModelsProof = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.item.liveFoundationModelsOutput")
        reveal(liveFoundationModelsProof, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(liveFoundationModelsProof.waitForExistence(timeout: 5))
        let liveFoundationModelsProofValue = liveFoundationModelsProof.value as? String
        XCTAssertTrue(liveFoundationModelsProofValue?.contains("Requires real iPhone") ?? false)
        XCTAssertTrue(liveFoundationModelsProofValue?.contains("LanguageModelSession") ?? false)

        let deviceProofMatrix = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.matrix")
        reveal(deviceProofMatrix, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(deviceProofMatrix.waitForExistence(timeout: 5))
        XCTAssertTrue((deviceProofMatrix.value as? String)?.contains("Required Device Matrix") ?? false)

        let physicalCaptureMatrix = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.captureMatrix")
        reveal(physicalCaptureMatrix, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(physicalCaptureMatrix.waitForExistence(timeout: 5))
        let physicalCaptureMatrixValue = physicalCaptureMatrix.value as? String
        XCTAssertTrue(physicalCaptureMatrixValue?.contains("Physical Capture Matrix") ?? false)
        XCTAssertTrue(physicalCaptureMatrixValue?.contains("0 of 8 scenario proofs captured") ?? false)
        XCTAssertTrue(physicalCaptureMatrixValue?.contains("Real iPhone required") ?? false)
        XCTAssertTrue(physicalCaptureMatrixValue?.contains("Simulator coverage does not satisfy capture matrix") ?? false)
        XCTAssertTrue(physicalCaptureMatrixValue?.contains("Interior Window Dynamic Range") ?? false)
        XCTAssertFalse(physicalCaptureMatrixValue?.contains("Physical proof captured") ?? true)

        let deviceLabPreflight = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.deviceLabPreflight")
        reveal(deviceLabPreflight, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(deviceLabPreflight.waitForExistence(timeout: 5))
        let deviceLabPreflightValue = deviceLabPreflight.value as? String
        XCTAssertTrue(deviceLabPreflightValue?.contains("Physical Device Lab Preflight") ?? false)
        XCTAssertTrue(deviceLabPreflightValue?.contains("Connected unlocked iPhone required") ?? false)
        XCTAssertTrue(deviceLabPreflightValue?.contains("platform=iOS,id=<DEVICE-UDID>") ?? false)
        XCTAssertTrue(deviceLabPreflightValue?.contains("Xcode/devicectl") ?? false)
        XCTAssertTrue(deviceLabPreflightValue?.contains("No physical proof count changed") ?? false)
        XCTAssertTrue(deviceLabPreflightValue?.contains("does not count physical proof") ?? false)
        XCTAssertFalse(deviceLabPreflightValue?.contains("Physical proof captured") ?? true)

        let verificationRunbook = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.verificationRunbook")
        reveal(verificationRunbook, byScrolling: settingsScrollView, attempts: 8)
        XCTAssertTrue(verificationRunbook.waitForExistence(timeout: 5))
        let verificationRunbookValue = verificationRunbook.value as? String
        XCTAssertTrue(verificationRunbookValue?.contains("Verification Runbook") ?? false)
        XCTAssertTrue(verificationRunbookValue?.contains("Bracketer-simulator-full.xcresult") ?? false)
        XCTAssertTrue(verificationRunbookValue?.contains("xcresulttool get test-results metrics") ?? false)
        XCTAssertTrue(verificationRunbookValue?.contains("platform=iOS,id=<DEVICE-UDID>") ?? false)
        XCTAssertTrue(verificationRunbookValue?.contains("do not prove physical iPhone capture") ?? false)
        XCTAssertFalse(verificationRunbookValue?.contains("Physical proof captured") ?? true)

        let benchmarkCommands = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.benchmarkCommands")
        reveal(benchmarkCommands, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(benchmarkCommands.waitForExistence(timeout: 5))
        let benchmarkCommandsValue = benchmarkCommands.value as? String
        XCTAssertTrue(benchmarkCommandsValue?.contains("Benchmark Commands") ?? false)
        XCTAssertTrue(benchmarkCommandsValue?.contains("Duration (AppLaunch)") ?? false)
        XCTAssertTrue(benchmarkCommandsValue?.contains("Dropped frame diagnostics") ?? false)
        XCTAssertTrue(benchmarkCommandsValue?.contains("No physical dropped-frame proof yet") ?? false)

        let captureRunbooks = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.captureRunbooks")
        reveal(captureRunbooks, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(captureRunbooks.waitForExistence(timeout: 5))
        let captureRunbooksValue = captureRunbooks.value as? String
        XCTAssertTrue(captureRunbooksValue?.contains("Physical Capture Runbooks") ?? false)
        XCTAssertTrue(captureRunbooksValue?.contains("0 of 8 runbooks captured") ?? false)
        XCTAssertTrue(captureRunbooksValue?.contains("Interior Window Dynamic Range") ?? false)
        XCTAssertTrue(captureRunbooksValue?.contains("Reserve result bundle path") ?? false)
        XCTAssertTrue(captureRunbooksValue?.contains("stores no Photos identifiers") ?? false)

        let resultBundleIndex = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.resultBundleIndex")
        reveal(resultBundleIndex, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(resultBundleIndex.waitForExistence(timeout: 5))
        let resultBundleIndexValue = resultBundleIndex.value as? String
        XCTAssertTrue(resultBundleIndexValue?.contains("Physical Result Bundle Index") ?? false)
        XCTAssertTrue(resultBundleIndexValue?.contains("0 of 8 scenario result bundles indexed") ?? false)
        XCTAssertTrue(resultBundleIndexValue?.contains("does not store raw image bytes") ?? false)

        let proofIngestor = relaunchedApp.staticTexts["settings.deviceProof.proofIngestor"]
        reveal(proofIngestor, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(proofIngestor.waitForExistence(timeout: 5))
        let proofIngestorValue = proofIngestor.value as? String
        XCTAssertTrue(proofIngestorValue?.contains("Physical Proof Ingestor") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("0 of 8 physical submissions accepted") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("Real iPhone artifacts required") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("valid attachment signature") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid attachment signature") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario-bound result-bundle filename") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle filename for a different scenario") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("iPhone model identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("non-iPhone model identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("iOS version or build label") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid iOS build label") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario-bound reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing scenario descriptors") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("physical capturedAt timestamp") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("capturedAt timestamp in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing capturedAt timestamp") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle filename in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle SHA-256 in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary SHA-256 in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("typed result-bundle summary in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle metrics in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle test contract in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle timing metadata in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest result-bundle context in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest hashes in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest byte counts in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario-bound test identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("capturedAt inside result-bundle test window") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("passing result-bundle summary in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle filename") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle SHA-256") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle summary SHA-256") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing typed result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle test contract") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle timing metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing attachment manifest context") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing attachment manifest hashes") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing passing result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("hashed device identifier in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing hashed device identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("device model identifier in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("iOS build label in reviewer evidence") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing device model identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing iOS build label") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("stale capturedAt timestamp") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("future capturedAt timestamp") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle SHA-256") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("typed result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary status") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary title") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary total test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary passed test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary failed test count") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary counts match metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool compact test-results summary JSON") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("parsed result-bundle proof input") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool command plan") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle digest command plan") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario-bound result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("top-level xcresult summary counts") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle device/platform metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("physical xcresult platform") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle iOS build matches submission") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("missing typed result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid typed result-bundle summary") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle summary counts disagree with metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid xcresulttool compact summary JSON") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("xcresulttool summary timing window invalid") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("non-.xcresult result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("unsafe result-bundle path") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("scenario bundle name mismatch") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("missing result-bundle device metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid result-bundle device metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("simulator result-bundle platform") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle device metadata disagrees with submission") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing result-bundle device metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle timing metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid result-bundle timing metadata") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("result-bundle duration disagrees with test window") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("per-artifact attachment manifest SHA-256 values") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("per-artifact attachment manifest byte counts") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest result-bundle filename") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest scenario test identifier") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest test start and finish time") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid attachment manifest context") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid attachment manifest hashes") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("invalid attachment manifest byte counts") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("attachment manifest byte count disagrees with result-bundle metrics") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("reviewer evidence missing attachment manifest byte counts") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("manifest snapshot SHA-256") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("missing manifest snapshot SHA-256") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("simulator destination") ?? false)
        XCTAssertTrue(proofIngestorValue?.contains("unreplaced template placeholder") ?? false)
        XCTAssertFalse(proofIngestorValue?.contains("Physical proof captured") ?? true)

        let proofTemplate = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.proofIngestor.exportTemplate")
        reveal(proofTemplate, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(proofTemplate.waitForExistence(timeout: 5))
        let proofTemplateValue = proofTemplate.value as? String
        XCTAssertTrue(proofTemplateValue?.contains("Physical Proof Submission Template") ?? false)
        XCTAssertTrue(proofTemplateValue?.contains("platform=iOS,id=<DEVICE-UDID>") ?? false)
        XCTAssertTrue(proofTemplateValue?.contains("preview only") ?? false)
        XCTAssertFalse(proofTemplateValue?.contains("Physical proof captured") ?? true)

        let proofImportPreview = anyElement(in: relaunchedApp, identifier: "settings.deviceProof.proofIngestor.importPreview")
        reveal(proofImportPreview, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(proofImportPreview.waitForExistence(timeout: 5))
        let proofImportPreviewValue = proofImportPreview.value as? String
        XCTAssertTrue(proofImportPreviewValue?.contains("physical-device-proof preview only") ?? false)
        XCTAssertTrue(proofImportPreviewValue?.contains("0 of 8 physical submissions accepted remains unchanged") ?? false)
        XCTAssertFalse(proofImportPreviewValue?.contains("Physical proof captured") ?? true)

        let projectSummary = anyElement(in: relaunchedApp, identifier: "settings.projects.summary")
        reveal(projectSummary, byScrolling: settingsScrollView, attempts: 10)
        XCTAssertTrue(projectSummary.waitForExistence(timeout: 5))
        XCTAssertTrue((projectSummary.value as? String)?.contains("Project Library") ?? false)
        XCTAssertTrue((projectSummary.value as? String)?.contains("Latest: 5-shot simulated bracket") ?? false)

        let smartCollections = anyElement(in: relaunchedApp, identifier: "settings.projects.smartCollections")
        reveal(smartCollections, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(smartCollections.waitForExistence(timeout: 5))
        XCTAssertTrue((smartCollections.value as? String)?.contains("Smart Collections") ?? false)

        let reviewableCollection = relaunchedApp.buttons["settings.projects.smartCollections.reviewable"]
        revealForTap(reviewableCollection, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(reviewableCollection.waitForExistence(timeout: 5))
        XCTAssertTrue((reviewableCollection.value as? String)?.contains("Reviewable") ?? false)

        let facetFilters = anyElement(in: relaunchedApp, identifier: "settings.projects.facetFilters")
        reveal(facetFilters, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(facetFilters.waitForExistence(timeout: 5))
        let facetFiltersValue = facetFilters.value as? String
        XCTAssertTrue(facetFiltersValue?.contains("Selectable Facets") ?? false)
        XCTAssertTrue(facetFiltersValue?.contains("Dynamic Range") ?? false)
        XCTAssertTrue(facetFiltersValue?.contains("Output Blocked") ?? false)

        let dateFacets = anyElement(in: relaunchedApp, identifier: "settings.projects.dateFacets")
        reveal(dateFacets, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(dateFacets.waitForExistence(timeout: 5))
        let dateFacetsValue = dateFacets.value as? String
        XCTAssertTrue(dateFacetsValue?.contains("Captured Date Facets") ?? false)
        XCTAssertTrue(dateFacetsValue?.contains("1970-01-01") ?? false)

        let lensFacets = anyElement(in: relaunchedApp, identifier: "settings.projects.lensFacets")
        reveal(lensFacets, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(lensFacets.waitForExistence(timeout: 5))
        let lensFacetsValue = lensFacets.value as? String
        XCTAssertTrue(lensFacetsValue?.contains("Lens Facets") ?? false)
        XCTAssertTrue(lensFacetsValue?.contains("Simulated Wide Camera") ?? false)

        let locationFacets = anyElement(in: relaunchedApp, identifier: "settings.projects.locationFacets")
        reveal(locationFacets, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(locationFacets.waitForExistence(timeout: 5))
        let locationFacetsValue = locationFacets.value as? String
        XCTAssertTrue(locationFacetsValue?.contains("Location Policy Facets") ?? false)
        XCTAssertTrue(locationFacetsValue?.contains("Simulated Location Not Requested") ?? false)

        let searchRoute = anyElement(in: relaunchedApp, identifier: "settings.projects.library.searchRoute")
        reveal(searchRoute, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(searchRoute.waitForExistence(timeout: 5))
        let searchRouteValue = searchRoute.value as? String
        XCTAssertTrue(searchRouteValue?.contains("Project Search Route") ?? false)
        XCTAssertTrue(searchRouteValue?.contains("5-shot simulated bracket") ?? false)
        XCTAssertTrue(searchRouteValue?.contains("no Photos local identifiers") ?? false)

        let archiveWorkspaceButton = relaunchedApp.buttons["settings.projects.library.workspaceButton"]
        revealForTap(archiveWorkspaceButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(archiveWorkspaceButton.waitForExistence(timeout: 5))
        let archiveWorkspaceButtonValue = archiveWorkspaceButton.value as? String
        XCTAssertTrue(archiveWorkspaceButtonValue?.contains("Project Archive Workspace") ?? false)
        XCTAssertTrue(archiveWorkspaceButtonValue?.contains("5-shot simulated bracket") ?? false)
        archiveWorkspaceButton.tap()

        let archiveWorkspace = anyElement(in: relaunchedApp, identifier: "settings.projects.library.workspace")
        XCTAssertTrue(archiveWorkspace.waitForExistence(timeout: 5))
        let archiveWorkspaceValue = archiveWorkspace.value as? String
        XCTAssertTrue(archiveWorkspaceValue?.contains("Project Archive Workspace") ?? false)
        XCTAssertTrue(archiveWorkspaceValue?.contains("Metadata-only archive workspace") ?? false)
        XCTAssertTrue(archiveWorkspaceValue?.contains("Final output action plan: 2 action item(s)") ?? false)
        XCTAssertTrue(archiveWorkspaceValue?.contains("not final rendered image proof") ?? false)
        XCTAssertTrue(archiveWorkspaceValue?.contains("no Photos local identifiers") ?? false)

        let archiveWorkspaceResult = anyElement(in: relaunchedApp, identifier: "settings.projects.library.workspace.result.0")
        XCTAssertTrue(archiveWorkspaceResult.waitForExistence(timeout: 5))
        let archiveWorkspaceResultValue = archiveWorkspaceResult.value as? String
        XCTAssertTrue(archiveWorkspaceResultValue?.contains("project-simulated") ?? false)
        XCTAssertTrue(archiveWorkspaceResultValue?.contains("Final output action plan: 2 action item(s)") ?? false)
        XCTAssertTrue(archiveWorkspaceResultValue?.contains("Resolve blockers before export") ?? false)

        let archiveWorkspaceExport = relaunchedApp.buttons["settings.projects.library.workspace.result.0.exportBundle.shareButton"]
        XCTAssertTrue(archiveWorkspaceExport.waitForExistence(timeout: 5))
        let archiveWorkspaceExportValue = archiveWorkspaceExport.value as? String
        XCTAssertTrue(archiveWorkspaceExportValue?.contains("Project Export Bundle") ?? false)
        XCTAssertTrue(archiveWorkspaceExportValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(archiveWorkspaceExportValue?.contains("Omit generated") ?? false)
        XCTAssertTrue(archiveWorkspaceExportValue?.contains("Final output action plan: 2 action item(s)") ?? false)
        XCTAssertTrue(archiveWorkspaceExportValue?.contains("not final rendered image proof") ?? false)

        let archiveWorkspaceClose = relaunchedApp.buttons["settings.projects.library.workspace.close"]
        XCTAssertTrue(archiveWorkspaceClose.waitForExistence(timeout: 5))
        archiveWorkspaceClose.tap()
        XCTAssertTrue(projectSummary.waitForExistence(timeout: 5))

        let exportPreset = anyElement(in: relaunchedApp, identifier: "settings.projects.exportPreset")
        reveal(exportPreset, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(exportPreset.waitForExistence(timeout: 5))
        let exportPresetValue = exportPreset.value as? String
        XCTAssertTrue(exportPresetValue?.contains("Client Handoff") ?? false)
        XCTAssertTrue(exportPresetValue?.contains("Dated summary") ?? false)
        XCTAssertTrue(exportPresetValue?.contains("Metadata only") ?? false)

        let exportPrivacyLevel = anyElement(in: relaunchedApp, identifier: "settings.projects.exportPrivacyLevel")
        reveal(exportPrivacyLevel, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(exportPrivacyLevel.waitForExistence(timeout: 5))
        let exportPrivacyValue = exportPrivacyLevel.value as? String
        XCTAssertTrue(exportPrivacyValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(exportPrivacyValue?.contains("Photos local identifiers are redacted") ?? false)

        let exportFilenameTemplate = anyElement(in: relaunchedApp, identifier: "settings.projects.exportFilenameTemplate")
        reveal(exportFilenameTemplate, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(exportFilenameTemplate.waitForExistence(timeout: 5))
        let exportFilenameValue = exportFilenameTemplate.value as? String
        XCTAssertTrue(exportFilenameValue?.contains("Dated summary") ?? false)
        XCTAssertTrue(exportFilenameValue?.contains("without Photos identifiers") ?? false)

        let exportGeneratedContent = anyElement(in: relaunchedApp, identifier: "settings.projects.exportGeneratedContent")
        reveal(exportGeneratedContent, byScrolling: settingsScrollView, attempts: 10)
        XCTAssertTrue(exportGeneratedContent.waitForExistence(timeout: 5))
        let exportGeneratedContentValue = exportGeneratedContent.value as? String
        XCTAssertTrue(exportGeneratedContentValue?.contains("Omit generated") ?? false)
        XCTAssertTrue(exportGeneratedContentValue?.contains("User-curated") ?? false)

        let projectRow = anyElement(in: relaunchedApp, identifier: "settings.projects.result.0")
        reveal(projectRow, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(projectRow.waitForExistence(timeout: 5))
        XCTAssertTrue((projectRow.value as? String)?.contains("project-simulated") ?? false)
        XCTAssertTrue((projectRow.value as? String)?.contains("No raw photo bytes") ?? false)

        let previewStrip = anyElement(in: relaunchedApp, identifier: "settings.projects.result.0.previewStrip")
        reveal(previewStrip, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(previewStrip.waitForExistence(timeout: 5))
        let previewStripValue = previewStrip.value as? String
        XCTAssertTrue(previewStripValue?.contains("Preview placeholders") ?? false)
        XCTAssertTrue(previewStripValue?.contains("0 EV") ?? false)
        XCTAssertTrue(previewStripValue?.contains("Best exposure candidate") ?? false)
        XCTAssertFalse(previewStripValue?.contains("simulated-minus") ?? false)
        XCTAssertFalse(previewStripValue?.contains("simulated-plus") ?? false)

        let favoriteButton = relaunchedApp.buttons["settings.projects.favorite.0"]
        revealForTap(favoriteButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        XCTAssertTrue((favoriteButton.value as? String)?.contains("Not favorite") ?? false)

        let selectedProjectExportButton = relaunchedApp.buttons["settings.projects.result.0.exportBundle.shareButton"]
        revealForTap(selectedProjectExportButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(selectedProjectExportButton.waitForExistence(timeout: 5))
        let selectedProjectExportValue = selectedProjectExportButton.value as? String
        XCTAssertTrue(selectedProjectExportValue?.contains("Project Export Bundle") ?? false)
        XCTAssertTrue(selectedProjectExportValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(selectedProjectExportValue?.contains("Dated summary") ?? false)
        XCTAssertTrue(selectedProjectExportValue?.contains("Filename: bracketer-19700101-0000-5shot-simulated-metadata-only.txt") ?? false)
        XCTAssertFalse(selectedProjectExportValue?.contains("simulated-minus") ?? false)
        XCTAssertFalse(selectedProjectExportValue?.contains("simulated-plus") ?? false)

        let importConflictPolicy = anyElement(in: relaunchedApp, identifier: "settings.projects.importConflictPolicy")
        reveal(importConflictPolicy, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(importConflictPolicy.waitForExistence(timeout: 5))
        XCTAssertTrue((importConflictPolicy.value as? String)?.contains("Keep both") ?? false)

        let exportBundleButton = relaunchedApp.buttons["settings.projects.exportBundle.shareButton"]
        revealForTap(exportBundleButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(exportBundleButton.waitForExistence(timeout: 5))
        let exportBundleValue = exportBundleButton.value as? String
        XCTAssertTrue(exportBundleValue?.contains("Project Export Bundle") ?? false)
        XCTAssertTrue(exportBundleValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(exportBundleValue?.contains("Dated summary") ?? false)
        XCTAssertTrue(exportBundleValue?.contains("Filename: bracketer-19700101-0000-5shot-simulated-metadata-only.txt") ?? false)
        XCTAssertTrue(exportBundleValue?.contains("Photos asset identifiers: redacted") ?? false)
        XCTAssertTrue(exportBundleValue?.contains("Bracketer Project Privacy Report") ?? false)
        XCTAssertFalse(exportBundleValue?.contains("simulated-minus") ?? false)
        XCTAssertFalse(exportBundleValue?.contains("simulated-plus") ?? false)

        let exportBundleFileButton = relaunchedApp.buttons["settings.projects.exportBundle.fileButton"]
        revealForTap(exportBundleFileButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(exportBundleFileButton.waitForExistence(timeout: 5))
        let exportBundleFileValue = exportBundleFileButton.value as? String
        XCTAssertTrue(exportBundleFileValue?.contains("No Files export attempted") ?? false)
        XCTAssertTrue(exportBundleFileValue?.contains("Project Export Bundle") ?? false)
        XCTAssertTrue(exportBundleFileValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(exportBundleFileValue?.contains("bracketer-19700101-0000-5shot-simulated-metadata-only.txt") ?? false)

        let importBundleButton = relaunchedApp.buttons["settings.projects.importBundle.button"]
        revealForTap(importBundleButton, byScrolling: settingsScrollView, attempts: 5)
        XCTAssertTrue(importBundleButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValueContaining(importBundleButton, "Previewed ui-testing-final-output-readiness-audit-mismatch.txt", timeout: 5))
        let importBundleValue = importBundleButton.value as? String
        XCTAssertTrue(importBundleValue?.contains("Previewed ui-testing-final-output-readiness-audit-mismatch.txt") ?? false)
        XCTAssertTrue(importBundleValue?.contains("final-output-readiness-audit-mismatch") ?? false)
        XCTAssertTrue(importBundleValue?.contains("Recovery: Re-export final-output readiness audit") ?? false)
        XCTAssertTrue(importBundleValue?.contains("No import was saved") ?? false)
        XCTAssertTrue(importBundleValue?.contains("Duplicate policy: Keep both") ?? false)

        relaunchedApp.terminate()

        let handoffApp = XCUIApplication()
        handoffApp.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-open-latest-review-handoff",
        ]
        handoffApp.launch()

        let latestReviewHandoff = anyElement(in: handoffApp, identifier: "camera.appIntent.lastHandoff")
        XCTAssertTrue(latestReviewHandoff.waitForExistence(timeout: 5))
        XCTAssertTrue((latestReviewHandoff.value as? String)?.contains("Destination: Last Review") ?? false)
        XCTAssertTrue((latestReviewHandoff.value as? String)?.contains("Project: Latest Review") ?? false)

        let projectReviewSummary = anyElement(in: handoffApp, identifier: "review.project.handoff.summary")
        XCTAssertTrue(projectReviewSummary.waitForExistence(timeout: 5))
        XCTAssertTrue((projectReviewSummary.value as? String)?.contains("Project Handoff: Latest Review") ?? false)
        XCTAssertTrue((projectReviewSummary.value as? String)?.contains("5-shot simulated bracket") ?? false)
        let reviewAccessibility = anyElement(in: handoffApp, identifier: "review.project.accessibility")
        XCTAssertTrue(reviewAccessibility.waitForExistence(timeout: 5))
        let reviewAccessibilityValue = reviewAccessibility.value as? String
        XCTAssertTrue(reviewAccessibilityValue?.contains("Review Workspace Accessibility Contract") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("Minimum tap target 44 pt") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.previousShotButton") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.representationToggle") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("does not prove physical-device accessibility") ?? false)
        XCTAssertTrue(anyElement(in: handoffApp, identifier: "review.project.selectedShot").waitForExistence(timeout: 5))
        XCTAssertTrue(handoffApp.buttons["review.project.previousShotButton"].exists)
        XCTAssertTrue(handoffApp.buttons["review.project.nextShotButton"].exists)
        XCTAssertTrue(handoffApp.buttons["review.project.representationToggle"].exists)
        let handoffScrollView = handoffApp.scrollViews.firstMatch
        let qualityReport = anyElement(in: handoffApp, identifier: "review.project.qualityReport")
        reveal(qualityReport, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(qualityReport.waitForExistence(timeout: 5))
        let qualityReportValue = qualityReport.value as? String
        XCTAssertTrue(qualityReportValue?.contains("Capture Quality") ?? false)
        XCTAssertTrue(qualityReportValue?.contains("5 of 5 available") ?? false)
        XCTAssertTrue(qualityReportValue?.contains("Score 100") ?? false)

        let assetResources = anyElement(in: handoffApp, identifier: "review.project.assetResources.card")
        reveal(assetResources, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(assetResources.waitForExistence(timeout: 5))

        let imageBundle = anyElement(in: handoffApp, identifier: "review.project.imageBundle.card")
        reveal(imageBundle, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(imageBundle.waitForExistence(timeout: 5))
        let imageBundleValue = imageBundle.value as? String
        XCTAssertTrue(imageBundleValue?.contains("Image Bundle Manifest") ?? false)
        XCTAssertTrue(imageBundleValue?.contains("5 of 5 exportable") ?? false)
        XCTAssertTrue(imageBundleValue?.contains("Draft package 5 synthetic entries") ?? false)
        XCTAssertTrue(imageBundleValue?.contains("not private Photos bytes") ?? false)

        let exposureComparison = anyElement(in: handoffApp, identifier: "review.project.exposureComparison")
        reveal(exposureComparison, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(exposureComparison.waitForExistence(timeout: 5))
        let exposureComparisonValue = exposureComparison.value as? String
        XCTAssertTrue(exposureComparisonValue?.contains("Exposure Comparison") ?? false)
        XCTAssertTrue(exposureComparisonValue?.contains("Baseline 0 EV") ?? false)
        XCTAssertTrue(exposureComparisonValue?.contains("5 comparisons") ?? false)

        let pixelComparison = anyElement(in: handoffApp, identifier: "review.project.pixelComparison")
        reveal(pixelComparison, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(pixelComparison.waitForExistence(timeout: 5))
        let pixelComparisonValue = pixelComparison.value as? String
        XCTAssertTrue(pixelComparisonValue?.contains("Side-by-side Pixel Compare") ?? false)
        XCTAssertTrue(pixelComparisonValue?.contains("Baseline 0 EV") ?? false)
        XCTAssertTrue(pixelComparisonValue?.contains("4 comparisons") ?? false)

        let restoredCenterComparison = handoffApp.buttons["review.project.exposureComparison.item.2"]
        revealForTap(restoredCenterComparison, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(restoredCenterComparison.waitForExistence(timeout: 5))
        XCTAssertTrue((restoredCenterComparison.value as? String)?.contains("Baseline exposure") ?? false)

        let brighterShadowComparison = handoffApp.buttons["review.project.exposureComparison.item.4"]
        revealForTap(brighterShadowComparison, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(brighterShadowComparison.waitForExistence(timeout: 5))
        brighterShadowComparison.tap()
        XCTAssertTrue(
            waitForValue(
                anyElement(in: handoffApp, identifier: "review.project.selectedShot"),
                "Shot 5 / +4.0 EV | Available | HEIF/JPEG",
                timeout: 5
            )
        )

        let brightPixelComparison = handoffApp.buttons["review.project.pixelComparison.item.4"]
        revealForTap(brightPixelComparison, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(brightPixelComparison.waitForExistence(timeout: 5))
        XCTAssertTrue((brightPixelComparison.value as? String)?.contains("Compare +4.0 EV") ?? false)

        let restoredCenterShot = handoffApp.buttons["review.project.shot.2"]
        revealForTap(restoredCenterShot, byScrolling: handoffScrollView, attempts: 5)
        XCTAssertTrue(restoredCenterShot.waitForExistence(timeout: 5))

        XCTAssertTrue(handoffApp.buttons["review.project.closeButton"].exists)
    }

    @MainActor
    func testProjectReviewAccessibilityFixtureExposesReviewWorkspaceContract() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            "-ui-testing-open-review-accessibility-fixture",
        ]
        app.launch()

        let reviewAccessibility = reviewProjectElement(in: app, identifier: "review.project.accessibility")
        XCTAssertTrue(reviewAccessibility.waitForExistence(timeout: 5))
        let reviewAccessibilityValue = reviewAccessibility.value as? String
        XCTAssertTrue(reviewAccessibilityValue?.contains("Review Workspace Accessibility Contract") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("Verified") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("Minimum tap target 44 pt") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.voiceOverTraversal") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.finalWorkspace.fixture") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.tapTargetAudit") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.bestBaseFrame") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.bestBaseFrame.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.beforeAfterScrub") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.beforeAfterScrub.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.perShotExposure") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.perShotExposure.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.focusEdge") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.focusEdge.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionAlignment") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionAlignment.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionMetadata") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionMetadata.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.featureMatch") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.featureMatch.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentTransform") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentTransform.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionBlur") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.motionBlur.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.ghostingRisk") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.ghostingRisk.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.movingRegionMask") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.movingRegionMask.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentPerformance") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentPerformance.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentExplanation") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.alignmentExplanation.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.qualityReport") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.qualityReport.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.finalOutputs") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.mergeReadiness") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.mergeReadiness.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.finalOutputs.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.finalOutputReadinessAudit") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.assetResources") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.assetResources.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.imageBundle") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.imageBundle.card") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.previousShotButton") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.nextShotButton") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("review.project.representationToggle") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("No raw photo bytes exposed") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("Photos asset identifiers redacted") ?? false)
        XCTAssertTrue(reviewAccessibilityValue?.contains("does not prove physical-device accessibility") ?? false)
        XCTAssertFalse(reviewAccessibilityValue?.contains("review-accessibility-0EV") ?? true)

        let selectedShot = reviewProjectElement(in: app, identifier: "review.project.selectedShot")
        XCTAssertTrue(selectedShot.waitForExistence(timeout: 5))

        let voiceOverTraversal = reviewProjectElement(in: app, identifier: "review.project.voiceOverTraversal")
        XCTAssertTrue(voiceOverTraversal.waitForExistence(timeout: 5))
        let voiceOverTraversalValue = voiceOverTraversal.value as? String
        XCTAssertTrue(voiceOverTraversalValue?.contains("Review VoiceOver Traversal") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("Complete") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.finalWorkspace.fixture") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.tapTargetAudit") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.bestBaseFrame") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.bestBaseFrame.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.beforeAfterScrub") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.beforeAfterScrub.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.perShotExposure") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.perShotExposure.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.focusEdge") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.focusEdge.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionAlignment") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionAlignment.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionMetadata") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionMetadata.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.featureMatch") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.featureMatch.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentTransform") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentTransform.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionBlur") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.motionBlur.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.ghostingRisk") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.ghostingRisk.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.movingRegionMask") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.movingRegionMask.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentPerformance") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentPerformance.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentExplanation") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.alignmentExplanation.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.qualityReport") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.qualityReport.card") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.mergeReadiness") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.finalOutputs") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.finalOutputReadinessAudit") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.assetResources") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.imageBundle") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("review.project.shot.2") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("Traits: button") ?? false)
        XCTAssertTrue(voiceOverTraversalValue?.contains("does not run VoiceOver") ?? false)
        XCTAssertFalse(voiceOverTraversalValue?.contains("review-accessibility-0EV") ?? true)

        let finalWorkspace = reviewProjectElement(in: app, identifier: "review.project.finalWorkspace.fixture")
        XCTAssertTrue(finalWorkspace.waitForExistence(timeout: 5))
        let finalWorkspaceValue = finalWorkspace.value as? String
        XCTAssertTrue(finalWorkspaceValue?.contains("Final Review Workspace Fixture") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final review workspace fixture complete") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("18 split handoff/card pairs") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("35 alignment diagnostic guides across 7 families") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Feature Match 5/5") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Alignment Explanation 5/5") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("26 tap-target rows") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("5 selected-shot control tap targets") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("15 review guidance tap targets") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("3 export tap targets") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("2 comparison tap targets") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("1 shot-row tap target scopes") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 selected-shot control tap target follow-ups") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 review guidance tap target follow-ups") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 export tap target follow-ups") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 comparison tap target follow-ups") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 shot-row tap target follow-ups") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("tap-target rows") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("3 export surfaces") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("2 comparison surfaces") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("0 ready final outputs") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("3 blocked final outputs") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Ready final outputs: none") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("5 final-output source exposures") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("5 complete final-output resource pairs") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final-output preview artifact available: true") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final-output readiness") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final-output readiness says 0 ready, 3 blocked") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("3 final-output recommendations") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final-output recommendations: Tone-mapped review JPEG") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Use the fusion preview as review context only") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("Final-output recommendations cover 3 planned output") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("No final rendered bytes are included") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("simulator-ready model/UI coverage only") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("does not run VoiceOver") ?? false)
        XCTAssertTrue(finalWorkspaceValue?.contains("proving physical-device accessibility") ?? false)
        XCTAssertFalse(finalWorkspaceValue?.contains("review-accessibility-0EV") ?? true)

        let finalOutputReadinessAudit = reviewProjectElement(in: app, identifier: "review.project.finalOutputReadinessAudit")
        XCTAssertTrue(finalOutputReadinessAudit.waitForExistence(timeout: 5))
        let finalOutputReadinessAuditValue = finalOutputReadinessAudit.value as? String
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Final Output Readiness Audit") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Follow-up before final export") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("0/3 outputs ready") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("2 blocker reason") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("3 recommendation") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Preview artifact available") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("No final rendered bytes") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Recommendations: Tone-mapped review JPEG") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("without including final rendered image bytes") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Action plan: 2 action item(s)") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("Resolve blockers before export for 3 blocked output(s)") ?? false)
        XCTAssertTrue(finalOutputReadinessAuditValue?.contains("not final rendered image proof") ?? false)
        XCTAssertFalse(finalOutputReadinessAuditValue?.contains("review-accessibility-0EV") ?? true)

        let tapTargetAudit = reviewProjectElement(in: app, identifier: "review.project.tapTargetAudit")
        XCTAssertTrue(tapTargetAudit.waitForExistence(timeout: 5))
        let tapTargetAuditValue = tapTargetAudit.value as? String
        XCTAssertTrue(tapTargetAuditValue?.contains("Review Export Tap Target Audit") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("26/26 tap targets verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("5/5 selected-shot control tap targets verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("15/15 review guidance tap targets verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("3/3 export tap targets verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("2/2 comparison tap targets verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("1/1 shot-row tap target scopes verified") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("Minimum tap target 44 pt") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("review.project.previousShotButton") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("review.project.bestBaseFrame.card") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("review.project.alignmentExplanation.card") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("review.project.finalOutputs.card") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("review.project.imageBundle.card") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("model contract for expected SwiftUI control frames only") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("does not measure physical touch ergonomics") ?? false)
        XCTAssertTrue(tapTargetAuditValue?.contains("prove physical-device accessibility") ?? false)
        XCTAssertFalse(tapTargetAuditValue?.contains("review-accessibility-0EV") ?? true)

        let qualityReportHandoff = reviewProjectElement(in: app, identifier: "review.project.qualityReport")
        XCTAssertTrue(qualityReportHandoff.waitForExistence(timeout: 5))
        let qualityReportHandoffValue = qualityReportHandoff.value as? String
        XCTAssertTrue(qualityReportHandoffValue?.contains("Capture Quality") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("5 of 5 available") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("Score 100") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("Ready for careful review") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("Highlight guards 2") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("Shadow guards 2") ?? false)
        XCTAssertTrue(qualityReportHandoffValue?.contains("does not inspect private Photos bytes") ?? false)
        XCTAssertFalse(qualityReportHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let mergeReadinessHandoff = reviewProjectElement(in: app, identifier: "review.project.mergeReadiness")
        XCTAssertTrue(mergeReadinessHandoff.waitForExistence(timeout: 5))
        let mergeReadinessHandoffValue = mergeReadinessHandoff.value as? String
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("Merge Readiness") ?? false)
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("Score 95") ?? false)
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("Ready for cautious merge preview") ?? false)
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("0 blockers") ?? false)
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("0 cautions") ?? false)
        XCTAssertTrue(mergeReadinessHandoffValue?.contains("does not inspect private Photos bytes") ?? false)
        XCTAssertFalse(mergeReadinessHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let finalOutputHandoff = reviewProjectElement(in: app, identifier: "review.project.finalOutputs")
        XCTAssertTrue(finalOutputHandoff.waitForExistence(timeout: 5))
        let finalOutputHandoffValue = finalOutputHandoff.value as? String
        XCTAssertTrue(finalOutputHandoffValue?.contains("Final Output Manifest") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("0 ready") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("3 blocked") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("5 source exposures") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("5 complete resource pairs") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Preview artifact available") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("No final rendered bytes") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Ready outputs: none") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Blocked outputs: Tone-mapped review JPEG, HDR HEIF master, Lightroom reference TIFF") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("3 recommendations") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Recommendations: Tone-mapped review JPEG") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Use the fusion preview as review context only") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("No final rendered outputs are available yet") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("Final-output export plan only") ?? false)
        XCTAssertTrue(finalOutputHandoffValue?.contains("without including final rendered image bytes") ?? false)
        XCTAssertFalse(finalOutputHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let finalOutputsCard = reviewProjectElement(in: app, identifier: "review.project.finalOutputs.card")
        XCTAssertTrue(finalOutputsCard.waitForExistence(timeout: 5))
        let finalOutputsCardValue = finalOutputsCard.value as? String
        XCTAssertTrue(finalOutputsCardValue?.contains("Final Output Manifest") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("Action plan: 2 action item(s)") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("Resolve blockers before export for 3 blocked output(s)") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("No final rendered bytes") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("without including final rendered image bytes") ?? false)
        XCTAssertTrue(finalOutputsCardValue?.contains("not final rendered image proof") ?? false)
        XCTAssertFalse(finalOutputsCardValue?.contains("review-accessibility-0EV") ?? true)

        let assetResourceHandoff = reviewProjectElement(in: app, identifier: "review.project.assetResources")
        XCTAssertTrue(assetResourceHandoff.waitForExistence(timeout: 5))
        let assetResourceHandoffValue = assetResourceHandoff.value as? String
        XCTAssertTrue(assetResourceHandoffValue?.contains("Asset Resources") ?? false)
        XCTAssertTrue(assetResourceHandoffValue?.contains("5 complete pairs") ?? false)
        XCTAssertTrue(assetResourceHandoffValue?.contains("RAW 5") ?? false)
        XCTAssertTrue(assetResourceHandoffValue?.contains("Processed 5") ?? false)
        XCTAssertTrue(assetResourceHandoffValue?.contains("Recovery IDs 5") ?? false)
        XCTAssertTrue(assetResourceHandoffValue?.contains("does not fetch Photos resources") ?? false)
        XCTAssertFalse(assetResourceHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let imageBundleHandoff = reviewProjectElement(in: app, identifier: "review.project.imageBundle")
        XCTAssertTrue(imageBundleHandoff.waitForExistence(timeout: 5))
        let imageBundleHandoffValue = imageBundleHandoff.value as? String
        XCTAssertTrue(imageBundleHandoffValue?.contains("Image Bundle Manifest") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("Metadata only") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("5 of 5 exportable") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("RAW 5") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("Processed 5") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("5 complete RAW/processed pairs") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("Recovery IDs 5") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("Draft package 10 synthetic entries") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("not private Photos bytes") ?? false)
        XCTAssertTrue(imageBundleHandoffValue?.contains("does not export, read, fetch, decode, or prove photo bytes") ?? false)
        XCTAssertFalse(imageBundleHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let bestBaseFrameHandoff = reviewProjectElement(in: app, identifier: "review.project.bestBaseFrame")
        XCTAssertTrue(bestBaseFrameHandoff.waitForExistence(timeout: 5))
        let bestBaseFrameHandoffValue = bestBaseFrameHandoff.value as? String
        XCTAssertTrue(bestBaseFrameHandoffValue?.contains("Best Base Frame Suggestion") ?? false)
        XCTAssertTrue(bestBaseFrameHandoffValue?.contains("Shot 3 / 0 EV") ?? false)
        XCTAssertTrue(bestBaseFrameHandoffValue?.contains("Confidence ") ?? false)
        XCTAssertTrue(bestBaseFrameHandoffValue?.contains("2 darker highlight guards") ?? false)
        XCTAssertTrue(bestBaseFrameHandoffValue?.contains("not a final HDR merge decision") ?? false)
        XCTAssertFalse(bestBaseFrameHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let bestBaseFrame = reviewProjectElement(in: app, identifier: "review.project.bestBaseFrame.card")
        XCTAssertTrue(bestBaseFrame.waitForExistence(timeout: 5))
        let bestBaseFrameValue = bestBaseFrame.value as? String
        XCTAssertTrue(bestBaseFrameValue?.contains("Best Base Frame Suggestion") ?? false)
        XCTAssertTrue(bestBaseFrameValue?.contains("Shot 3 / 0 EV") ?? false)
        XCTAssertTrue(bestBaseFrameValue?.contains("2 darker highlight guards") ?? false)
        XCTAssertTrue(bestBaseFrameValue?.contains("not a final HDR merge decision") ?? false)
        XCTAssertFalse(bestBaseFrameValue?.contains("review-accessibility-0EV") ?? true)

        let beforeAfterScrubHandoff = reviewProjectElement(in: app, identifier: "review.project.beforeAfterScrub")
        XCTAssertTrue(beforeAfterScrubHandoff.waitForExistence(timeout: 5))
        let beforeAfterScrubHandoffValue = beforeAfterScrubHandoff.value as? String
        XCTAssertTrue(beforeAfterScrubHandoffValue?.contains("Before/After Scrub Plan") ?? false)
        XCTAssertTrue(beforeAfterScrubHandoffValue?.contains("Baseline 0 EV") ?? false)
        XCTAssertTrue(beforeAfterScrubHandoffValue?.contains("Compare -4.0 EV") ?? false)
        XCTAssertTrue(beforeAfterScrubHandoffValue?.contains("5 scrub stops") ?? false)
        XCTAssertTrue(beforeAfterScrubHandoffValue?.contains("not derived from private Photos bytes") ?? false)
        XCTAssertFalse(beforeAfterScrubHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let beforeAfterScrub = reviewProjectElement(in: app, identifier: "review.project.beforeAfterScrub.card")
        XCTAssertTrue(beforeAfterScrub.waitForExistence(timeout: 5))
        let beforeAfterScrubValue = beforeAfterScrub.value as? String
        XCTAssertTrue(beforeAfterScrubValue?.contains("Before/After Scrub Plan") ?? false)
        XCTAssertTrue(beforeAfterScrubValue?.contains("Baseline 0 EV") ?? false)
        XCTAssertTrue(beforeAfterScrubValue?.contains("Compare -4.0 EV") ?? false)
        XCTAssertTrue(beforeAfterScrubValue?.contains("5 scrub stops") ?? false)
        XCTAssertTrue(beforeAfterScrubValue?.contains("not derived from private Photos bytes") ?? false)
        XCTAssertFalse(beforeAfterScrubValue?.contains("review-accessibility-0EV") ?? true)

        let perShotExposureHandoff = reviewProjectElement(in: app, identifier: "review.project.perShotExposure")
        XCTAssertTrue(perShotExposureHandoff.waitForExistence(timeout: 5))
        let perShotExposureHandoffValue = perShotExposureHandoff.value as? String
        XCTAssertTrue(perShotExposureHandoffValue?.contains("Per-shot Exposure Distribution") ?? false)
        XCTAssertTrue(perShotExposureHandoffValue?.contains("5 shots") ?? false)
        XCTAssertTrue(perShotExposureHandoffValue?.contains("EV spread +8.0 EV") ?? false)
        XCTAssertTrue(perShotExposureHandoffValue?.contains("2 darker highlight guards") ?? false)
        XCTAssertTrue(perShotExposureHandoffValue?.contains("4 manifest clipping warnings") ?? false)
        XCTAssertTrue(perShotExposureHandoffValue?.contains("pixel histograms") ?? false)
        XCTAssertFalse(perShotExposureHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let perShotExposure = reviewProjectElement(in: app, identifier: "review.project.perShotExposure.card")
        XCTAssertTrue(perShotExposure.waitForExistence(timeout: 5))
        let perShotExposureValue = perShotExposure.value as? String
        XCTAssertTrue(perShotExposureValue?.contains("Per-shot Exposure Distribution") ?? false)
        XCTAssertTrue(perShotExposureValue?.contains("5 shots") ?? false)
        XCTAssertTrue(perShotExposureValue?.contains("EV spread +8.0 EV") ?? false)
        XCTAssertTrue(perShotExposureValue?.contains("2 darker highlight guards") ?? false)
        XCTAssertTrue(perShotExposureValue?.contains("4 manifest clipping warnings") ?? false)
        XCTAssertTrue(perShotExposureValue?.contains("pixel histograms") ?? false)
        XCTAssertFalse(perShotExposureValue?.contains("review-accessibility-0EV") ?? true)

        let focusEdgeHandoff = reviewProjectElement(in: app, identifier: "review.project.focusEdge")
        XCTAssertTrue(focusEdgeHandoff.waitForExistence(timeout: 5))
        let focusEdgeHandoffValue = focusEdgeHandoff.value as? String
        XCTAssertTrue(focusEdgeHandoffValue?.contains("Focus/Edge Inspection") ?? false)
        XCTAssertTrue(focusEdgeHandoffValue?.contains("5/5 inspected") ?? false)
        XCTAssertTrue(focusEdgeHandoffValue?.contains("Synthetic fixture pixels, not private Photos bytes") ?? false)
        XCTAssertTrue(focusEdgeHandoffValue?.contains("deterministic fixture-pixel/metadata review guidance only") ?? false)
        XCTAssertTrue(focusEdgeHandoffValue?.contains("does not inspect private Photos bytes") ?? false)
        XCTAssertFalse(focusEdgeHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let focusEdge = reviewProjectElement(in: app, identifier: "review.project.focusEdge.card")
        XCTAssertTrue(focusEdge.waitForExistence(timeout: 5))
        let focusEdgeValue = focusEdge.value as? String
        XCTAssertTrue(focusEdgeValue?.contains("Focus/Edge Inspection") ?? false)
        XCTAssertTrue(focusEdgeValue?.contains("5/5 inspected") ?? false)
        XCTAssertTrue(focusEdgeValue?.contains("Synthetic fixture pixels, not private Photos bytes") ?? false)
        XCTAssertTrue(focusEdgeValue?.contains("deterministic fixture-pixel/metadata review guidance only") ?? false)
        XCTAssertTrue(focusEdgeValue?.contains("does not inspect private Photos bytes") ?? false)
        XCTAssertFalse(focusEdgeValue?.contains("review-accessibility-0EV") ?? true)

        let motionAlignmentHandoff = reviewProjectElement(in: app, identifier: "review.project.motionAlignment")
        XCTAssertTrue(motionAlignmentHandoff.waitForExistence(timeout: 5))
        let motionAlignmentHandoffValue = motionAlignmentHandoff.value as? String
        XCTAssertTrue(motionAlignmentHandoffValue?.contains("Motion/Alignment Overlay") ?? false)
        XCTAssertTrue(motionAlignmentHandoffValue?.contains("5 overlay guides") ?? false)
        XCTAssertTrue(motionAlignmentHandoffValue?.contains("Synthetic motion/alignment overlay, not real IMU samples") ?? false)
        XCTAssertTrue(motionAlignmentHandoffValue?.contains("deterministic fixture-pixel/manifest scaffolding only") ?? false)
        XCTAssertTrue(motionAlignmentHandoffValue?.contains("does not read real CMMotion or IMU samples") ?? false)
        XCTAssertFalse(motionAlignmentHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let motionAlignment = reviewProjectElement(in: app, identifier: "review.project.motionAlignment.card")
        XCTAssertTrue(motionAlignment.waitForExistence(timeout: 5))
        let motionAlignmentValue = motionAlignment.value as? String
        XCTAssertTrue(motionAlignmentValue?.contains("Motion/Alignment Overlay") ?? false)
        XCTAssertTrue(motionAlignmentValue?.contains("5 overlay guides") ?? false)
        XCTAssertTrue(motionAlignmentValue?.contains("Synthetic motion/alignment overlay, not real IMU samples") ?? false)
        XCTAssertTrue(motionAlignmentValue?.contains("deterministic fixture-pixel/manifest scaffolding only") ?? false)
        XCTAssertTrue(motionAlignmentValue?.contains("does not read real CMMotion or IMU samples") ?? false)
        XCTAssertFalse(motionAlignmentValue?.contains("review-accessibility-0EV") ?? true)

        let motionMetadataHandoff = reviewProjectElement(in: app, identifier: "review.project.motionMetadata")
        XCTAssertTrue(motionMetadataHandoff.waitForExistence(timeout: 5))
        let motionMetadataHandoffValue = motionMetadataHandoff.value as? String
        XCTAssertTrue(motionMetadataHandoffValue?.contains("Motion Metadata Capture") ?? false)
        XCTAssertTrue(motionMetadataHandoffValue?.contains("0 motion samples captured") ?? false)
        XCTAssertTrue(motionMetadataHandoffValue?.contains("Unavailable motion metadata") ?? false)
        XCTAssertTrue(motionMetadataHandoffValue?.contains("Motion metadata capture contract, not live IMU proof") ?? false)
        XCTAssertTrue(motionMetadataHandoffValue?.contains("does not include raw CMMotion samples") ?? false)
        XCTAssertTrue(motionMetadataHandoffValue?.contains("does not prove physical-device motion capture") ?? false)
        XCTAssertFalse(motionMetadataHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let motionMetadata = reviewProjectElement(in: app, identifier: "review.project.motionMetadata.card")
        XCTAssertTrue(motionMetadata.waitForExistence(timeout: 5))
        let motionMetadataValue = motionMetadata.value as? String
        XCTAssertTrue(motionMetadataValue?.contains("Motion Metadata Capture") ?? false)
        XCTAssertTrue(motionMetadataValue?.contains("0 motion samples captured") ?? false)
        XCTAssertTrue(motionMetadataValue?.contains("Unavailable motion metadata") ?? false)
        XCTAssertTrue(motionMetadataValue?.contains("Motion metadata capture contract, not live IMU proof") ?? false)
        XCTAssertTrue(motionMetadataValue?.contains("does not include raw CMMotion samples") ?? false)
        XCTAssertTrue(motionMetadataValue?.contains("does not prove physical-device motion capture") ?? false)
        XCTAssertFalse(motionMetadataValue?.contains("review-accessibility-0EV") ?? true)

        let featureMatchHandoff = reviewProjectElement(in: app, identifier: "review.project.featureMatch")
        XCTAssertTrue(featureMatchHandoff.waitForExistence(timeout: 5))
        let featureMatchHandoffValue = featureMatchHandoff.value as? String
        XCTAssertTrue(featureMatchHandoffValue?.contains("Feature Match Fixture") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("5 feature-match guides") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("synthetic matched pairs") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("Synthetic feature-match fixture, not real pixel matching") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("deterministic manifest and fixture-pixel scaffolding only") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("does not inspect real image features") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("descriptor matching") ?? false)
        XCTAssertTrue(featureMatchHandoffValue?.contains("homography solving") ?? false)
        XCTAssertFalse(featureMatchHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let featureMatch = reviewProjectElement(in: app, identifier: "review.project.featureMatch.card")
        XCTAssertTrue(featureMatch.waitForExistence(timeout: 5))
        let featureMatchValue = featureMatch.value as? String
        XCTAssertTrue(featureMatchValue?.contains("Feature Match Fixture") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("5 feature-match guides") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("synthetic matched pairs") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("Synthetic feature-match fixture, not real pixel matching") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("deterministic manifest and fixture-pixel scaffolding only") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("does not inspect real image features") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("descriptor matching") ?? false)
        XCTAssertTrue(featureMatchValue?.contains("homography solving") ?? false)
        XCTAssertFalse(featureMatchValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentTransformHandoff = reviewProjectElement(in: app, identifier: "review.project.alignmentTransform")
        XCTAssertTrue(alignmentTransformHandoff.waitForExistence(timeout: 5))
        let alignmentTransformHandoffValue = alignmentTransformHandoff.value as? String
        XCTAssertTrue(alignmentTransformHandoffValue?.contains("Alignment Transform") ?? false)
        XCTAssertTrue(alignmentTransformHandoffValue?.contains("5 transform guides") ?? false)
        XCTAssertTrue(alignmentTransformHandoffValue?.contains("Synthetic alignment transform, not real feature matching") ?? false)
        XCTAssertTrue(alignmentTransformHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentTransformHandoffValue?.contains("does not detect real image features") ?? false)
        XCTAssertFalse(alignmentTransformHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentTransform = reviewProjectElement(in: app, identifier: "review.project.alignmentTransform.card")
        XCTAssertTrue(alignmentTransform.waitForExistence(timeout: 5))
        let alignmentTransformValue = alignmentTransform.value as? String
        XCTAssertTrue(alignmentTransformValue?.contains("Alignment Transform") ?? false)
        XCTAssertTrue(alignmentTransformValue?.contains("5 transform guides") ?? false)
        XCTAssertTrue(alignmentTransformValue?.contains("Synthetic alignment transform, not real feature matching") ?? false)
        XCTAssertTrue(alignmentTransformValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentTransformValue?.contains("does not detect real image features") ?? false)
        XCTAssertFalse(alignmentTransformValue?.contains("review-accessibility-0EV") ?? true)

        let motionBlurHandoff = reviewProjectElement(in: app, identifier: "review.project.motionBlur")
        XCTAssertTrue(motionBlurHandoff.waitForExistence(timeout: 5))
        let motionBlurHandoffValue = motionBlurHandoff.value as? String
        XCTAssertTrue(motionBlurHandoffValue?.contains("Motion/Blur Risk") ?? false)
        XCTAssertTrue(motionBlurHandoffValue?.contains("5 blur-risk guides") ?? false)
        XCTAssertTrue(motionBlurHandoffValue?.contains("Synthetic motion/blur risk, not real shutter or sensor evidence") ?? false)
        XCTAssertTrue(motionBlurHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(motionBlurHandoffValue?.contains("does not read real shutter speed") ?? false)
        XCTAssertFalse(motionBlurHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let motionBlur = reviewProjectElement(in: app, identifier: "review.project.motionBlur.card")
        XCTAssertTrue(motionBlur.waitForExistence(timeout: 5))
        let motionBlurValue = motionBlur.value as? String
        XCTAssertTrue(motionBlurValue?.contains("Motion/Blur Risk") ?? false)
        XCTAssertTrue(motionBlurValue?.contains("5 blur-risk guides") ?? false)
        XCTAssertTrue(motionBlurValue?.contains("Synthetic motion/blur risk, not real shutter or sensor evidence") ?? false)
        XCTAssertTrue(motionBlurValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(motionBlurValue?.contains("does not read real shutter speed") ?? false)
        XCTAssertFalse(motionBlurValue?.contains("review-accessibility-0EV") ?? true)

        let ghostingRiskHandoff = reviewProjectElement(in: app, identifier: "review.project.ghostingRisk")
        XCTAssertTrue(ghostingRiskHandoff.waitForExistence(timeout: 5))
        let ghostingRiskHandoffValue = ghostingRiskHandoff.value as? String
        XCTAssertTrue(ghostingRiskHandoffValue?.contains("Ghosting Risk") ?? false)
        XCTAssertTrue(ghostingRiskHandoffValue?.contains("5 ghosting-risk guides") ?? false)
        XCTAssertTrue(ghostingRiskHandoffValue?.contains("Synthetic ghosting risk, not moving-subject detection") ?? false)
        XCTAssertTrue(ghostingRiskHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(ghostingRiskHandoffValue?.contains("does not run optical flow") ?? false)
        XCTAssertFalse(ghostingRiskHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let ghostingRisk = reviewProjectElement(in: app, identifier: "review.project.ghostingRisk.card")
        XCTAssertTrue(ghostingRisk.waitForExistence(timeout: 5))
        let ghostingRiskValue = ghostingRisk.value as? String
        XCTAssertTrue(ghostingRiskValue?.contains("Ghosting Risk") ?? false)
        XCTAssertTrue(ghostingRiskValue?.contains("5 ghosting-risk guides") ?? false)
        XCTAssertTrue(ghostingRiskValue?.contains("Synthetic ghosting risk, not moving-subject detection") ?? false)
        XCTAssertTrue(ghostingRiskValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(ghostingRiskValue?.contains("does not run optical flow") ?? false)
        XCTAssertFalse(ghostingRiskValue?.contains("review-accessibility-0EV") ?? true)

        let movingRegionMaskHandoff = reviewProjectElement(in: app, identifier: "review.project.movingRegionMask")
        XCTAssertTrue(movingRegionMaskHandoff.waitForExistence(timeout: 5))
        let movingRegionMaskHandoffValue = movingRegionMaskHandoff.value as? String
        XCTAssertTrue(movingRegionMaskHandoffValue?.contains("Moving-Region Mask") ?? false)
        XCTAssertTrue(movingRegionMaskHandoffValue?.contains("5 mask guides") ?? false)
        XCTAssertTrue(movingRegionMaskHandoffValue?.contains("Synthetic moving-region masks, not real subject segmentation") ?? false)
        XCTAssertTrue(movingRegionMaskHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(movingRegionMaskHandoffValue?.contains("does not segment moving subjects") ?? false)
        XCTAssertFalse(movingRegionMaskHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let movingRegionMask = reviewProjectElement(in: app, identifier: "review.project.movingRegionMask.card")
        XCTAssertTrue(movingRegionMask.waitForExistence(timeout: 5))
        let movingRegionMaskValue = movingRegionMask.value as? String
        XCTAssertTrue(movingRegionMaskValue?.contains("Moving-Region Mask") ?? false)
        XCTAssertTrue(movingRegionMaskValue?.contains("5 mask guides") ?? false)
        XCTAssertTrue(movingRegionMaskValue?.contains("Synthetic moving-region masks, not real subject segmentation") ?? false)
        XCTAssertTrue(movingRegionMaskValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(movingRegionMaskValue?.contains("does not segment moving subjects") ?? false)
        XCTAssertFalse(movingRegionMaskValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentPerformanceHandoff = reviewProjectElement(in: app, identifier: "review.project.alignmentPerformance")
        XCTAssertTrue(alignmentPerformanceHandoff.waitForExistence(timeout: 5))
        let alignmentPerformanceHandoffValue = alignmentPerformanceHandoff.value as? String
        XCTAssertTrue(alignmentPerformanceHandoffValue?.contains("Alignment Performance Notes") ?? false)
        XCTAssertTrue(alignmentPerformanceHandoffValue?.contains("5 performance notes") ?? false)
        XCTAssertTrue(alignmentPerformanceHandoffValue?.contains("Synthetic alignment performance notes, not measured Instruments timing") ?? false)
        XCTAssertTrue(alignmentPerformanceHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentPerformanceHandoffValue?.contains("does not run Instruments") ?? false)
        XCTAssertFalse(alignmentPerformanceHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentPerformance = reviewProjectElement(in: app, identifier: "review.project.alignmentPerformance.card")
        XCTAssertTrue(alignmentPerformance.waitForExistence(timeout: 5))
        let alignmentPerformanceValue = alignmentPerformance.value as? String
        XCTAssertTrue(alignmentPerformanceValue?.contains("Alignment Performance Notes") ?? false)
        XCTAssertTrue(alignmentPerformanceValue?.contains("5 performance notes") ?? false)
        XCTAssertTrue(alignmentPerformanceValue?.contains("Synthetic alignment performance notes, not measured Instruments timing") ?? false)
        XCTAssertTrue(alignmentPerformanceValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentPerformanceValue?.contains("does not run Instruments") ?? false)
        XCTAssertFalse(alignmentPerformanceValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentExplanationHandoff = reviewProjectElement(in: app, identifier: "review.project.alignmentExplanation")
        XCTAssertTrue(alignmentExplanationHandoff.waitForExistence(timeout: 5))
        let alignmentExplanationHandoffValue = alignmentExplanationHandoff.value as? String
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("Alignment Explanation") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("5 explanations") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("Synthetic alignment explanation, not real pixel analysis") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("does not inspect real image features") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("compute deghosting masks") ?? false)
        XCTAssertTrue(alignmentExplanationHandoffValue?.contains("run Instruments") ?? false)
        XCTAssertFalse(alignmentExplanationHandoffValue?.contains("review-accessibility-0EV") ?? true)

        let alignmentExplanation = reviewProjectElement(in: app, identifier: "review.project.alignmentExplanation.card")
        XCTAssertTrue(alignmentExplanation.waitForExistence(timeout: 5))
        let alignmentExplanationValue = alignmentExplanation.value as? String
        XCTAssertTrue(alignmentExplanationValue?.contains("Alignment Explanation") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("5 explanations") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("Synthetic alignment explanation, not real pixel analysis") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("deterministic manifest scaffolding only") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("does not inspect real image features") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("compute deghosting masks") ?? false)
        XCTAssertTrue(alignmentExplanationValue?.contains("run Instruments") ?? false)
        XCTAssertFalse(alignmentExplanationValue?.contains("review-accessibility-0EV") ?? true)

        let previousButton = app.buttons["review.project.previousShotButton"]
        let nextButton = app.buttons["review.project.nextShotButton"]
        let representationToggle = app.buttons["review.project.representationToggle"]
        let closeButton = app.buttons["review.project.closeButton"]
        XCTAssertTrue(previousButton.exists)
        XCTAssertTrue(nextButton.exists)
        XCTAssertTrue(representationToggle.exists)
        XCTAssertTrue(closeButton.exists)
    }

    @MainActor
    func testDeterministicImageReviewFixtureExposesLiveChromeContract() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-review-fixture",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["review.fixture.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.live.position"].label, "1 of 5")
        XCTAssertEqual(app.staticTexts["review.live.selectedEV"].label, "-4.0 EV")
        XCTAssertEqual(app.staticTexts["review.live.fileType"].label, "RAW + Processed")
        XCTAssertEqual(app.staticTexts["review.live.metadataStatus"].label, "Metadata available")
        let fixtureManifestShare = app.buttons["review.live.manifestShareButton"]
        XCTAssertTrue(fixtureManifestShare.waitForExistence(timeout: 5))
        XCTAssertTrue((fixtureManifestShare.value as? String)?.contains("\"groupIdentifier\" : \"review-fixture\"") ?? false)

        let nextButton = app.buttons["review.live.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.live.position"], "2 of 5"))
        XCTAssertTrue(waitForLabel(app.staticTexts["review.live.selectedEV"], "-2.0 EV"))

        let representationToggle = app.buttons["review.live.representationToggle"]
        XCTAssertTrue(representationToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(representationToggle.value as? String, "Processed")
        representationToggle.tap()
        XCTAssertTrue(waitForValue(representationToggle, "RAW"))

        let metadataToggle = app.buttons["review.live.metadataToggle"]
        XCTAssertTrue(metadataToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(metadataToggle.value as? String, "Hidden")
        metadataToggle.tap()
        XCTAssertTrue(waitForValue(metadataToggle, "Showing"))
        XCTAssertTrue(anyElement(in: app, identifier: "review.live.metadataPanel").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.live.metadataDetail"].label, "18 metadata keys / 4032 x 3024 / ISO 125 / Wide Camera")
        XCTAssertEqual(app.staticTexts["review.live.clippingSummary"].label, "Simulated shadow clipping risk")

        let deleteButton = app.buttons["review.live.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        let removeFixtureShot = app.buttons["Remove Fixture Shot"]
        XCTAssertTrue(removeFixtureShot.waitForExistence(timeout: 5))
        removeFixtureShot.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["review.live.position"], "2 of 4"))
        XCTAssertTrue(waitForLabel(app.staticTexts["review.live.selectedEV"], "0 EV"))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments += [
                "-ui-testing-skip-onboarding",
                "-ui-testing-disable-camera-startup",
                "-ui-testing-reset-settings",
            ]
            app.launch()
        }
    }

    private func reveal(_ element: XCUIElement, byScrolling scrollView: XCUIElement, attempts: Int = 3) {
        guard scrollView.waitForExistence(timeout: 2) else { return }

        for _ in 0..<attempts where !element.exists {
            scrollView.swipeUp()
        }
    }

    private func revealForTap(_ element: XCUIElement, byScrolling scrollView: XCUIElement, attempts: Int = 4) {
        guard scrollView.waitForExistence(timeout: 2) else { return }

        for _ in 0..<attempts where !element.isHittable {
            scrollView.swipeUp()
        }
    }

    private func keepScreenshot(from app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func launchCameraChromeApp(forceLandscape: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
            "-ui-testing-reset-settings",
            "-ui-testing-simulated-camera",
            forceLandscape ? "-ui-testing-force-landscape-layout" : "-ui-testing-force-portrait-layout",
        ]
        app.launch()
        return app
    }

    private func assertCameraChrome(
        in app: XCUIApplication,
        expectedLayout: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let layout = anyElement(in: app, identifier: "camera.chromeLayout")
        XCTAssertTrue(layout.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(layout.value as? String, expectedLayout, file: file, line: line)

        XCTAssertTrue(anyElement(in: app, identifier: "camera.topBar").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(anyElement(in: app, identifier: "camera.bottomControls").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(anyElement(in: app, identifier: "camera.primaryControls").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(anyElement(in: app, identifier: "camera.secondaryControls").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(anyElement(in: app, identifier: "camera.secondaryControls").value as? String, "Auto", file: file, line: line)

        XCTAssertTrue(app.buttons["camera.photoLibraryButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.buttons["camera.shutterButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.shutterButton"].value as? String, "Ready", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.settingsButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.buttons["camera.proControlsButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.proControlsButton"].value as? String, "Closed", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.proControlsTopButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.proControlsTopButton"].value as? String, "Closed", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.captureCoach.card"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue((app.buttons["camera.captureCoach.card"].value as? String)?.contains("Source: deterministicFallback") ?? false, file: file, line: line)
        XCTAssertTrue(anyElement(in: app, identifier: "camera.bracketPlan.strip").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(anyElement(in: app, identifier: "camera.bracketPlan.strip").value as? String, "3 shots | -1.0 EV, 0 EV, +1.0 EV | Center 0 EV", file: file, line: line)

        XCTAssertTrue(app.buttons["camera.flashModeButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.flashModeButton"].value as? String, "Unavailable", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.timerModeButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.timerModeButton"].value as? String, "Off", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.gridToggleButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.gridToggleButton"].value as? String, "On", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.levelToggleButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.levelToggleButton"].value as? String, "On", file: file, line: line)
        XCTAssertTrue(app.buttons["camera.shootingModeButton"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons["camera.shootingModeButton"].value as? String, "AUTO", file: file, line: line)
        XCTAssertEqual(anyElement(in: app, identifier: "camera.bracketingIndicator").value as? String, "+/-1.0 EV", file: file, line: line)
        XCTAssertEqual(app.buttons["camera.zoom.wide"].value as? String, "Selected", file: file, line: line)

        assertCameraChromeFrames(in: app, file: file, line: line)
    }

    private func assertCameraChromeFrames(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), file: file, line: line)
        let screenFrame = window.frame
        XCTAssertGreaterThan(screenFrame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(screenFrame.height, 0, file: file, line: line)

        let modeButton = app.buttons["camera.shootingModeButton"]
        let topProButton = app.buttons["camera.proControlsTopButton"]
        let flashButton = app.buttons["camera.flashModeButton"]
        let timerButton = app.buttons["camera.timerModeButton"]
        let gridButton = app.buttons["camera.gridToggleButton"]
        let levelButton = app.buttons["camera.levelToggleButton"]
        let bottomProButton = app.buttons["camera.proControlsButton"]
        let libraryButton = app.buttons["camera.photoLibraryButton"]
        let shutterButton = app.buttons["camera.shutterButton"]
        let settingsButton = app.buttons["camera.settingsButton"]
        let zoomButton = app.buttons["camera.zoom.wide"]
        let bracketingIndicator = anyElement(in: app, identifier: "camera.bracketingIndicator")
        let zoomControl = anyElement(in: app, identifier: "camera.zoomControl")
        let coachCard = app.buttons["camera.captureCoach.card"]
        let bracketStrip = anyElement(in: app, identifier: "camera.bracketPlan.strip")

        let requiredElements: [(String, XCUIElement)] = [
            ("shooting mode", modeButton),
            ("top pro controls", topProButton),
            ("capture coach", coachCard),
            ("bracket plan strip", bracketStrip),
            ("flash", flashButton),
            ("timer", timerButton),
            ("grid", gridButton),
            ("level", levelButton),
            ("bottom pro controls", bottomProButton),
            ("photo library", libraryButton),
            ("shutter", shutterButton),
            ("settings", settingsButton),
            ("zoom button", zoomButton),
            ("bracketing indicator", bracketingIndicator),
            ("zoom control", zoomControl),
        ]

        for (name, element) in requiredElements {
            assertUsableFrame(element.frame, named: name, inside: screenFrame, file: file, line: line)
        }

        assertNoFrameOverlap(
            [
                ("flash", flashButton),
                ("timer", timerButton),
                ("grid", gridButton),
                ("level", levelButton),
                ("bottom pro controls", bottomProButton),
            ],
            file: file,
            line: line
        )
        assertNoFrameOverlap(
            [
                ("photo library", libraryButton),
                ("shutter", shutterButton),
                ("settings", settingsButton),
            ],
            file: file,
            line: line
        )
        assertNoFrameOverlap(
            [
                ("shooting mode", modeButton),
                ("top pro controls", topProButton),
            ],
            file: file,
            line: line
        )

        assertFrames(
            [modeButton, topProButton],
            areAbove: [coachCard],
            file: file,
            line: line
        )
        assertFrames(
            [coachCard],
            areAbove: [bracketStrip],
            file: file,
            line: line
        )
        assertFrames(
            [bracketStrip],
            areAbove: [flashButton, timerButton, gridButton, levelButton, bottomProButton],
            file: file,
            line: line
        )
        assertFrames(
            [flashButton, timerButton, gridButton, levelButton, bottomProButton],
            areAbove: [libraryButton, shutterButton, settingsButton],
            file: file,
            line: line
        )
        assertFrames(
            [libraryButton, shutterButton, settingsButton],
            areAbove: [zoomButton],
            file: file,
            line: line
        )
    }

    private func assertUsableFrame(
        _ frame: CGRect,
        named name: String,
        inside screenFrame: CGRect,
        file: StaticString,
        line: UInt
    ) {
        XCTAssertGreaterThan(frame.width, 0, "\(name) width should be positive", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, "\(name) height should be positive", file: file, line: line)
        XCTAssertTrue(
            screenFrame.insetBy(dx: -1, dy: -1).contains(frame),
            "\(name) frame \(frame) should stay inside screen \(screenFrame)",
            file: file,
            line: line
        )
    }

    private func assertNoFrameOverlap(
        _ elements: [(String, XCUIElement)],
        file: StaticString,
        line: UInt
    ) {
        for leftIndex in elements.indices {
            for rightIndex in elements.indices where rightIndex > leftIndex {
                let left = elements[leftIndex]
                let right = elements[rightIndex]
                XCTAssertFalse(
                    left.1.frame.insetBy(dx: 1, dy: 1).intersects(right.1.frame.insetBy(dx: 1, dy: 1)),
                    "\(left.0) frame \(left.1.frame) should not overlap \(right.0) frame \(right.1.frame)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func assertFrames(
        _ upperElements: [XCUIElement],
        areAbove lowerElements: [XCUIElement],
        file: StaticString,
        line: UInt
    ) {
        let upperMaxY = upperElements.map(\.frame.maxY).max() ?? 0
        let lowerMinY = lowerElements.map(\.frame.minY).min() ?? 0
        XCTAssertLessThanOrEqual(
            upperMaxY,
            lowerMinY + 2,
            "Expected upper controls ending at \(upperMaxY) to stay above lower controls starting at \(lowerMinY)",
            file: file,
            line: line
        )
    }

    private func anyElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func reviewProjectElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.otherElements[identifier].firstMatch
    }

    private func XCTAssertSwitch(
        _ element: XCUIElement,
        isOn expectedValue: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        let value = element.value as? String
        XCTAssertEqual(value, expectedValue ? "1" : "0", file: file, line: line)
    }

    private func waitForValue(_ element: XCUIElement, _ expectedValue: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if element.value as? String == expectedValue {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return element.value as? String == expectedValue
    }

    private func waitForValueContaining(_ element: XCUIElement, _ expectedFragment: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if (element.value as? String)?.contains(expectedFragment) == true {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return (element.value as? String)?.contains(expectedFragment) == true
    }

    private func waitForAnyValue(_ element: XCUIElement, _ expectedValues: Set<String>, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let value = element.value as? String, expectedValues.contains(value) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        guard let value = element.value as? String else { return false }
        return expectedValues.contains(value)
    }

    private func waitForLabel(_ element: XCUIElement, _ expectedLabel: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if element.label == expectedLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return element.label == expectedLabel
    }
}

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
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

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

        let requiredElements: [(String, XCUIElement)] = [
            ("shooting mode", modeButton),
            ("top pro controls", topProButton),
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

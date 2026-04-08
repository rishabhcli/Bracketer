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
        ]
        app.launch()

        XCTAssertTrue(app.buttons["camera.photoLibraryButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["camera.shutterButton"].exists)
        XCTAssertTrue(app.buttons["camera.settingsButton"].exists)
    }

    @MainActor
    func testCaptureSettingsShowEffectiveConfigurationWhenCameraStartupIsDisabled() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-skip-onboarding",
            "-ui-testing-disable-camera-startup",
        ]
        app.launch()

        let settingsButton = app.buttons["camera.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.staticTexts["HEIF/JPEG"].exists)
        XCTAssertTrue(app.staticTexts["Unavailable"].exists)
        XCTAssertTrue(app.staticTexts["Pending"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments += [
                "-ui-testing-skip-onboarding",
                "-ui-testing-disable-camera-startup",
            ]
            app.launch()
        }
    }
}

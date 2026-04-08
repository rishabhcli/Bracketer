//
//  BracketerTests.swift
//  BracketerTests
//
//  Created by Rishabh Bansal on 8/25/25.
//

import Testing
import CoreLocation
@testable import Bracketer

struct BracketerTests {

    @Test func bracketPlannerReturnsExpectedThreeShotOffsets() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 1.0, shotCount: 3) == [-1.0, 0.0, 1.0])
    }

    @Test func bracketPlannerReturnsExpectedFiveShotOffsets() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 2.0, shotCount: 5) == [-4.0, -2.0, 0.0, 2.0, 4.0])
    }

    @Test func bracketPlannerFallsBackToThreeShotsForUnsupportedCounts() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 1.5, shotCount: 9) == [-1.5, 0.0, 1.5])
    }

    @Test func processedPhotoExtensionPreservesJpegInput() {
        #expect(PhotoSaver.processedFileExtension(for: "Bracket-123.jpg") == "jpg")
        #expect(PhotoSaver.processedFileExtension(for: "Bracket-123.jpeg") == "jpg")
    }

    @Test func processedPhotoExtensionNormalizesHeifAndFallbacks() {
        #expect(PhotoSaver.processedFileExtension(for: "Bracket-123.heif") == "heic")
        #expect(PhotoSaver.processedFileExtension(for: "Bracket-123.unknown") == "heic")
    }

    @Test func bracketPlannerCentersOffsetsAroundExposureCompensation() {
        #expect(
            BracketSequencePlanner.evOffsets(evStep: 1.0, shotCount: 3, centerBias: 0.5)
            == [-0.5, 0.5, 1.5]
        )
        #expect(
            BracketSequencePlanner.evOffsets(evStep: 2.0, shotCount: 5, centerBias: -1.0)
            == [-5.0, -3.0, -1.0, 1.0, 3.0]
        )
    }

    @Test func effectiveCaptureConfigurationShowsUnavailableFlashWhenHardwareDoesNotSupportIt() {
        let config = EffectiveCaptureConfiguration.resolve(
            isRawEnabled: false,
            flashMode: .on,
            isFlashAvailable: false,
            timerMode: .threeSeconds,
            locationAuthorizationStatus: .notDetermined
        )

        #expect(config.formatDisplayName == "HEIF/JPEG")
        #expect(config.flashDisplayName == "Unavailable")
        #expect(config.flashBadgeLabel == "N/A")
        #expect(config.timerDisplayName == "3s")
        #expect(config.locationDisplayName == "Pending")
    }

    @Test func effectiveCaptureConfigurationPreservesEnabledCaptureModes() {
        let config = EffectiveCaptureConfiguration.resolve(
            isRawEnabled: true,
            flashMode: .auto,
            isFlashAvailable: true,
            timerMode: .tenSeconds,
            locationAuthorizationStatus: .authorizedWhenInUse
        )

        #expect(config.formatBadgeLabel == "RAW")
        #expect(config.flashDisplayName == "Auto")
        #expect(config.flashBadgeLabel == "Auto")
        #expect(config.timerBadgeLabel == "10s")
        #expect(config.locationState == .on)
    }
}

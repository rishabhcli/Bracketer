//
//  BracketerTests.swift
//  BracketerTests
//
//  Created by Rishabh Bansal on 8/25/25.
//

import Testing
import Foundation
import CoreLocation
import SwiftUI
@testable import Bracketer

struct BracketerTests {

    @Test func bracketPlannerReturnsExpectedThreeShotOffsets() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 1.0, shotCount: 3) == [-1.0, 0.0, 1.0])
    }

    @Test func bracketPlannerReturnsExpectedFiveShotOffsets() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 2.0, shotCount: 5) == [-4.0, -2.0, 0.0, 2.0, 4.0])
    }

    @Test func bracketPlannerReturnsExpectedSevenShotOffsets() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 1.0, shotCount: 7) == [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0])
    }

    @Test func bracketPlannerFallsBackToThreeShotsForUnsupportedCounts() {
        #expect(BracketSequencePlanner.evOffsets(evStep: 1.5, shotCount: 9) == [-1.5, 0.0, 1.5])
    }

    @Test func bracketPlanNormalizesUnsupportedShotCountsWithReason() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 9)

        #expect(plan.requestedShotCount == 9)
        #expect(plan.shotCount == 3)
        #expect(plan.evOffsets == [-1.0, 0.0, 1.0])
        #expect(plan.normalizationReason == "Unsupported 9-shot bracket; using 3 shots.")
    }

    @Test func bracketPlanNormalizesInvalidEVStepWithReason() {
        let plan = BracketPlan(evStep: -2.0, requestedShotCount: 5)

        #expect(plan.evStep == 1.0)
        #expect(plan.shotCount == 5)
        #expect(plan.evOffsets == [-2.0, -1.0, 0.0, 1.0, 2.0])
        #expect(plan.normalizationReason == "Invalid EV step -2.0; using +/-1.0 EV.")
    }

    @Test func bracketPlanBuildsShotLabelsAndCenterExposure() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)

        #expect(plan.shots.map(\.displayLabel) == ["-1.0 EV", "0 EV", "+1.0 EV"])
        #expect(plan.shots.map(\.filenameLabel) == ["-1.0EV", "0EV", "+1.0EV"])
        #expect(plan.centerShot?.index == 1)
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

    @Test func bracketSequenceStateReportsPreparingProgress() {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let state = BracketSequenceState.preparing(plan: plan)

        #expect(state.isActive)
        #expect(state.progress.phase == .preparing)
        #expect(state.progress.totalShots == 5)
        #expect(state.progress.completedShots == 0)
        #expect(state.progress.title == "Preparing bracket")
        #expect(state.progress.shouldShowOverlay)
    }

    @Test func bracketSequenceStateReportsCapturingProgress() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let state = BracketSequenceState.capturing(plan: plan, currentIndex: 2, completedShots: 2)

        #expect(state.isActive)
        #expect(state.progress.phase == .capturing)
        #expect(state.progress.completedShots == 2)
        #expect(state.progress.currentShot?.displayLabel == "+1.0 EV")
        #expect(state.progress.title == "Capturing +1.0 EV")
        #expect(state.progress.subtitle == "Shot 3 of 3")
        #expect(state.progress.fraction == 2.0 / 3.0)
    }

    @Test func bracketSequenceStateReportsSavingAndCompletion() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let saving = BracketSequenceState.saving(plan: plan, savedCount: 2)
        let completed = BracketSequenceState.completed(plan: plan, assetIdentifiers: ["a", "b", "c"])

        #expect(saving.isActive)
        #expect(saving.progress.title == "Saving bracket")
        #expect(saving.progress.subtitle == "Saved 2 of 3")
        #expect(saving.progress.fraction == 1.0)
        #expect(!completed.isActive)
        #expect(completed.progress.title == "Bracket complete")
        #expect(completed.progress.subtitle == "3 assets saved")
        #expect(!completed.progress.shouldShowOverlay)
    }

    @Test func bracketSequenceStateReportsCancellationTimeoutAndFailureAsTerminal() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let cancelled = BracketSequenceState.cancelled(plan: plan, reason: "Runtime stopped")
        let timedOut = BracketSequenceState.timedOut(plan: plan)
        let failed = BracketSequenceState.failed(plan: plan, message: "Camera unavailable")

        #expect(!cancelled.isActive)
        #expect(cancelled.progress.title == "Bracket cancelled")
        #expect(cancelled.progress.subtitle == "Runtime stopped")
        #expect(!timedOut.isActive)
        #expect(timedOut.progress.title == "Bracket timed out")
        #expect(!failed.isActive)
        #expect(failed.progress.subtitle == "Camera unavailable")
    }

    @Test func simulatedBracketReviewUsesDeterministicAssetSummaries() {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let review = SimulatedBracketReview.make(plan: plan)

        #expect(review.capturedAt == Date(timeIntervalSince1970: 0))
        #expect(review.assetIdentifiers == [
            "simulated--4.0EV",
            "simulated--2.0EV",
            "simulated-0EV",
            "simulated-+2.0EV",
            "simulated-+4.0EV",
        ])
        #expect(review.sequence.countLabel == "5 shots")
        #expect(review.sequence.captureTimestampLabel == "1970-01-01T00:00:00Z")
    }

    @Test func simulatedBracketReviewBuildsManifestForExport() throws {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let review = SimulatedBracketReview.make(plan: plan)
        let manifest = review.manifest

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.groupIdentifier == review.id)
        #expect(manifest.source == .simulated)
        #expect(manifest.capturedAt == Date(timeIntervalSince1970: 0))
        #expect(manifest.plan.resolvedShotCount == 5)
        #expect(manifest.plan.evStep == 2.0)
        #expect(manifest.shots.map(\.displayLabel) == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(manifest.shots[0].clippingWarnings == ["Simulated shadow clipping risk"])
        #expect(manifest.shots[2].isBestExposureCandidate)
        #expect(manifest.shots[2].availableRepresentations == ["Processed"])

        let json = try manifest.jsonString()
        #expect(json.contains("\"schemaVersion\" : 1"))
        #expect(json.contains("\"source\" : \"simulated\""))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BracketManifest.self, from: Data(json.utf8))
        #expect(decoded == manifest)
    }

    @Test func bracketManifestPreservesMissingShotsForPartialPhotoSequences() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["asset-under"],
            capturedAt: Date(timeIntervalSince1970: 100),
            fileType: "RAW + Processed",
            availableRepresentations: [.processed, .raw]
        )
        let manifest = sequence.manifest(
            groupIdentifier: "photos-group",
            source: .photos,
            plan: plan
        )

        #expect(manifest.groupIdentifier == "photos-group")
        #expect(manifest.source == .photos)
        #expect(manifest.shots.map(\.captureState) == ["Available", "Missing", "Missing"])
        #expect(manifest.shots[0].assetIdentifier == "asset-under")
        #expect(manifest.shots[1].assetIdentifier == nil)
        #expect(manifest.shots[0].availableRepresentations == ["Processed", "RAW"])
    }

    @Test func bracketReviewSequenceBuildsShotSummariesAndBestExposure() {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c", "d", "e"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(sequence.shots.count == 5)
        #expect(sequence.selectedShot?.displayLabel == "-4.0 EV")
        #expect(sequence.selectedPositionLabel == "1 of 5")
        #expect(sequence.selectedRepresentationAvailabilityLabel == "Processed")
        #expect(sequence.shots.map(\.captureState) == [.available, .available, .available, .available, .available])
        #expect(sequence.shots[2].isBestExposureCandidate)
        #expect(sequence.shots[0].clippingWarnings == [.simulatedShadowRisk])
        #expect(sequence.shots[4].clippingWarnings == [.simulatedHighlightRisk])
        #expect(sequence.shots[2].clippingWarnings.isEmpty)
    }

    @Test func bracketReviewSequenceMarksPartialSequenceMissingAssets() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 5)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b"],
            capturedAt: Date(timeIntervalSince1970: 12)
        )

        #expect(sequence.countLabel == "5 shots")
        #expect(sequence.shots[0].captureState == .available)
        #expect(sequence.shots[1].captureState == .available)
        #expect(sequence.shots[2].captureState == .missing)
        #expect(sequence.shots[2].captureState.detail == "Expected shot has no saved asset")
        #expect(sequence.shots[4].assetIdentifier == nil)
    }

    @Test func bracketReviewSequenceClampsSelectionAndNavigates() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(sequence.selecting(index: 99).selectedIndex == 2)
        #expect(sequence.selecting(index: -12).selectedIndex == 0)
        #expect(sequence.selectingNext().selectedIndex == 1)
        #expect(sequence.selectingPrevious().selectedIndex == 0)
        #expect(sequence.selecting(index: 2).selectingNext().selectedIndex == 2)
    }

    @Test func bracketReviewSequenceDeletesSelectedAndClamps() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        let deletedMiddle = sequence.selecting(index: 1).deletingSelected()
        #expect(deletedMiddle.countLabel == "2 shots")
        #expect(deletedMiddle.selectedIndex == 1)
        #expect(deletedMiddle.selectedShot?.displayLabel == "+1.0 EV")

        let deletedLast = sequence.selecting(index: 2).deletingSelected()
        #expect(deletedLast.selectedIndex == 1)
        #expect(deletedLast.selectedShot?.displayLabel == "0 EV")

        let empty = BracketReviewSequence(shots: []).deletingSelected()
        #expect(empty.isEmpty)
        #expect(empty.selectedIndex == 0)
        #expect(empty.selectedPositionLabel == "0 of 0")
    }

    @Test func bracketReviewSequenceTracksRepresentationToggleTruthfully() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let processedOnly = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        let rawRequested = processedOnly.togglingRepresentation()
        #expect(rawRequested.selectedRepresentation == .raw)
        #expect(rawRequested.selectedRepresentationAvailabilityLabel == "RAW unavailable")

        let rawAvailable = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0),
            availableRepresentations: [.processed, .raw]
        ).togglingRepresentation()
        #expect(rawAvailable.selectedRepresentationAvailabilityLabel == "RAW")
    }

    @Test func bracketReviewSequenceUpdatesLoadedResourceSummary() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )

        let resourceSummary = BracketReviewResourceSummary(
            fileType: "RAW + Processed",
            availableRepresentations: [.processed, .raw],
            detail: "Bracket-0EV-0.dng, Bracket-0EV-0.heic"
        )
        let updated = sequence
            .updatingShot(at: 1, resourceSummary: resourceSummary)
            .selecting(index: 1)

        #expect(updated.selectedShot?.fileType == "RAW + Processed")
        #expect(updated.selectedRepresentationAvailabilityLabel == "Processed")
        #expect(updated.togglingRepresentation().selectedRepresentationAvailabilityLabel == "RAW")
        #expect(updated.updatingShot(at: 99, resourceSummary: .unavailable) == updated)
    }

    @Test func bracketReviewSequenceUpdatesLoadedMetadataSummary() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 0)
        )
        let metadataSummary = BracketReviewMetadataSummary(
            availableKeyCount: 12,
            pixelSize: "4032 x 3024",
            isoDescription: "ISO 125",
            lensDescription: "Wide Camera"
        )

        let updated = sequence.updatingShot(
            at: 0,
            metadataAvailability: .available(summary: metadataSummary.displaySummary)
        )

        #expect(updated.selectedShot?.metadataAvailability.displayName == "Metadata available")
        #expect(updated.selectedShot?.metadataAvailability.detail == "12 metadata keys / 4032 x 3024 / ISO 125 / Wide Camera")
        #expect(updated.updatingShot(at: -1, metadataAvailability: .unavailable(reason: "No-op")) == updated)
    }

    @Test func histogramFrameAnalyzerBuildsDeterministicBinsAndClippingMetrics() {
        let pixels: [UInt8] = [
            0, 0, 0, 255,
            0, 0, 0, 255,
            128, 128, 128, 255,
            255, 255, 255, 255,
        ]

        let analysis = HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 2,
            height: 2,
            stepX: 1,
            stepY: 1
        )

        #expect(analysis?.sampleCount == 4)
        #expect(analysis?.histogram.red[0] == 1.0)
        #expect(analysis?.histogram.red[128] == 0.5)
        #expect(analysis?.histogram.red[255] == 0.5)
        #expect(analysis?.clipping.shadowClippedPixels == 2)
        #expect(analysis?.clipping.highlightClippedPixels == 1)
        #expect(abs((analysis?.clipping.shadowClippedFraction ?? 0) - 0.5) < 0.001)
        #expect(abs((analysis?.clipping.highlightClippedFraction ?? 0) - 0.25) < 0.001)
        #expect(analysis?.clipping.hasShadowWarning == true)
        #expect(analysis?.clipping.hasHighlightWarning == true)
        #expect(abs((analysis?.histogram.underexposedPixels ?? 0) - 0.5) < 0.001)
        #expect(abs((analysis?.histogram.overexposedPixels ?? 0) - 0.25) < 0.001)
    }

    @Test func histogramFrameAnalyzerReadsBGRAPixelBuffersAndRowStride() {
        let pixels: [UInt8] = [
            20, 40, 200, 255,
            240, 20, 10, 255,
            99, 99, 99, 99,
            99, 99, 99, 99,
        ]

        let analysis = HistogramFrameAnalyzer.analyzeBGRABytes(
            pixels,
            width: 2,
            height: 1,
            bytesPerRow: 16,
            stepX: 1,
            stepY: 1
        )

        #expect(analysis?.sampleCount == 2)
        #expect(analysis?.histogram.red[200] == 1.0)
        #expect(analysis?.histogram.green[40] == 1.0)
        #expect(analysis?.histogram.blue[20] == 1.0)
        #expect(analysis?.histogram.red[10] == 1.0)
        #expect(analysis?.histogram.green[20] == 1.0)
        #expect(analysis?.histogram.blue[240] == 1.0)
    }

    @Test func zebraThresholdsClassifyShadowHighlightAndNormalPixels() {
        let thresholds = ExposureZebraThresholds(shadowLevel: 10, highlightLevel: 245)

        #expect(thresholds.classification(red: 0, green: 0, blue: 0) == .shadowClipped)
        #expect(thresholds.classification(red: 255, green: 255, blue: 255) == .highlightClipped)
        #expect(thresholds.classification(red: 120, green: 120, blue: 120) == .normal)
    }

    @Test func histogramFrameAnalyzerBuildsZebraRegionsFromClippingTiles() {
        let pixels: [UInt8] = [
            255, 255, 255, 255,
            128, 128, 128, 255,
            0, 0, 0, 255,
            128, 128, 128, 255,
        ]

        let analysis = HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 2,
            height: 2,
            stepX: 1,
            stepY: 1,
            zebraColumns: 2,
            zebraRows: 2,
            zebraRegionWarningFraction: 0.5
        )

        #expect(analysis?.sampleCount == 4)
        #expect(analysis?.zebraMap.highlightRegionCount == 1)
        #expect(analysis?.zebraMap.shadowRegionCount == 1)
        #expect(analysis?.zebraMap.regions.count == 2)
        #expect(analysis?.zebraMap.regions.contains { region in
            region.tileIndex == 0
            && region.classification == .highlightClipped
            && region.strength == 1
        } == true)
        #expect(analysis?.zebraMap.regions.contains { region in
            region.tileIndex == 2
            && region.classification == .shadowClipped
            && region.strength == 1
        } == true)
    }

    @Test func histogramFrameAnalyzerBuildsFocusPeakingRegionsFromEdges() {
        let luminanceValues: [UInt8] = [
            0, 255, 0, 255,
            255, 0, 255, 0,
            0, 255, 0, 255,
            255, 0, 255, 0,
        ]
        let pixels = luminanceValues.reduce(into: [UInt8]()) { bytes, value in
            bytes.append(value)
            bytes.append(value)
            bytes.append(value)
            bytes.append(255)
        }

        let analysis = HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 4,
            height: 4,
            stepX: 1,
            stepY: 1,
            zebraColumns: 4,
            zebraRows: 4,
            focusThresholds: FocusPeakingThresholds(edgeThreshold: 20, regionWarningFraction: 0.5)
        )
        let regions = analysis?.focusPeakingMap.regions ?? []

        #expect(regions.count == 15)
        #expect(!regions.contains { $0.tileIndex == 0 })
        #expect(regions.contains { region in
            region.tileIndex == 1 && region.strength == 1
        })
    }

    @Test func histogramFrameAnalyzerDoesNotPeakFlatFrames() {
        let luminanceValues = [UInt8](repeating: 128, count: 16)
        let pixels = luminanceValues.reduce(into: [UInt8]()) { bytes, value in
            bytes.append(value)
            bytes.append(value)
            bytes.append(value)
            bytes.append(255)
        }

        let analysis = HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 4,
            height: 4,
            stepX: 1,
            stepY: 1,
            zebraColumns: 4,
            zebraRows: 4,
            focusThresholds: FocusPeakingThresholds(edgeThreshold: 20, regionWarningFraction: 0.5)
        )

        #expect(analysis?.focusPeakingMap.regions.isEmpty == true)
    }

    @Test func settingsStorePersistsValuesToInjectedDefaults() {
        let defaults = makeIsolatedDefaults()

        let store = SettingsStore(defaults: defaults)
        store.showGrid = false
        store.gridType = .goldenSpiral
        store.showLevel = false
        store.focusPeakingEnabled = true
        store.focusPeakingColor = .green
        store.focusPeakingIntensity = 0.65
        store.selectedEVStep = 2.0
        store.bracketShotCount = 5
        store.currentShootingMode = .manual
        store.flashMode = .on
        store.timerMode = .tenSeconds
        store.teleUses12MP = true

        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.showGrid)
        #expect(reloaded.gridType == .goldenSpiral)
        #expect(!reloaded.showLevel)
        #expect(reloaded.focusPeakingEnabled)
        #expect(reloaded.focusPeakingColor == .green)
        #expect(reloaded.focusPeakingIntensity == 0.65)
        #expect(reloaded.selectedEVStep == 2.0)
        #expect(reloaded.bracketShotCount == 5)
        #expect(reloaded.currentShootingMode == .manual)
        #expect(reloaded.flashMode == .on)
        #expect(reloaded.timerMode == .tenSeconds)
        #expect(reloaded.teleUses12MP)
    }

    @Test func settingsStoreNormalizesCorruptPersistedValuesAndWritesThemBack() {
        let defaults = makeIsolatedDefaults()
        defaults.set(Float(5.0), forKey: SettingsStore.Keys.focusPeakingIntensity)
        defaults.set(Float(9.0), forKey: SettingsStore.Keys.selectedEVStep)
        defaults.set(99, forKey: SettingsStore.Keys.bracketShotCount)
        defaults.set("not-a-grid", forKey: SettingsStore.Keys.gridType)
        defaults.set("not-a-mode", forKey: SettingsStore.Keys.shootingMode)
        defaults.set("not-flash", forKey: SettingsStore.Keys.flashMode)
        defaults.set("not-timer", forKey: SettingsStore.Keys.timerMode)

        let store = SettingsStore(defaults: defaults)

        #expect(store.focusPeakingIntensity == 1.0)
        #expect(store.selectedEVStep == 3.0)
        #expect(store.bracketShotCount == 7)
        #expect(store.gridType == .ruleOfThirds)
        #expect(store.currentShootingMode == .auto)
        #expect(store.flashMode == .off)
        #expect(store.timerMode == .off)
        #expect(defaults.float(forKey: SettingsStore.Keys.focusPeakingIntensity) == 1.0)
        #expect(defaults.float(forKey: SettingsStore.Keys.selectedEVStep) == 3.0)
        #expect(defaults.integer(forKey: SettingsStore.Keys.bracketShotCount) == 7)
        #expect(defaults.string(forKey: SettingsStore.Keys.gridType) == GridType.ruleOfThirds.rawValue)
    }

    @Test func settingsStoreClampsAssignedValuesAndCanResetToDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        store.focusPeakingIntensity = -4.0
        store.selectedEVStep = 2.8
        store.bracketShotCount = 6

        #expect(store.focusPeakingIntensity == 0.1)
        #expect(store.selectedEVStep == 3.0)
        #expect(store.bracketShotCount == 5)
        #expect(defaults.float(forKey: SettingsStore.Keys.focusPeakingIntensity) == 0.1)
        #expect(defaults.float(forKey: SettingsStore.Keys.selectedEVStep) == 3.0)
        #expect(defaults.integer(forKey: SettingsStore.Keys.bracketShotCount) == 5)

        store.resetToDefaults()

        #expect(store.showGrid)
        #expect(store.gridType == .ruleOfThirds)
        #expect(store.showLevel)
        #expect(!store.focusPeakingEnabled)
        #expect(store.focusPeakingColor == .red)
        #expect(store.focusPeakingIntensity == 0.5)
        #expect(store.selectedEVStep == 1.0)
        #expect(store.bracketShotCount == 3)
        #expect(store.currentShootingMode == .auto)
        #expect(store.flashMode == .off)
        #expect(store.timerMode == .off)
        #expect(!store.teleUses12MP)
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

    @Test func deviceCapabilitySnapshotResolvesFullHardwareWithoutBlockers() {
        let snapshot = DeviceCapabilitySnapshot.resolve(inputs: DeviceCapabilityInputs(
            modelIdentifier: "TestPhone",
            systemVersion: "26.4",
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: true,
            hasTelephotoLens: true,
            hasFlash: true,
            supportsProRAW: true,
            photosAuthorization: .authorized,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: 4_096,
            isLowPowerModeEnabled: false
        ))

        #expect(snapshot.capabilityLevel == .full)
        #expect(snapshot.isCompatibleDevice)
        #expect(snapshot.blockingIssues.isEmpty)
        #expect(snapshot.statusSummary == "Ready")
    }

    @Test func deviceCapabilitySnapshotBlocksDeniedPhotosAndLowStorageWithActionPaths() {
        let snapshot = DeviceCapabilitySnapshot.resolve(inputs: DeviceCapabilityInputs(
            modelIdentifier: "TestPhone",
            systemVersion: "26.4",
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: true,
            hasTelephotoLens: false,
            hasFlash: true,
            supportsProRAW: true,
            photosAuthorization: .denied,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: 120,
            minimumStorageMB: 500,
            isLowPowerModeEnabled: false
        ))

        #expect(!snapshot.isCompatibleDevice)
        #expect(snapshot.blockingIssues.map(\.id).contains("photos.denied"))
        #expect(snapshot.blockingIssues.map(\.id).contains("storage.low"))
        #expect(snapshot.blockingIssues.contains { issue in
            issue.actionPath == "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only"
        })
        #expect(snapshot.blockingIssues.contains { issue in
            issue.actionPath == "Settings > General > iPhone Storage"
        })
    }

    @Test func cameraRuntimeFailuresShareDeviceCapabilityActionPaths() {
        let cameraDenied = CameraRuntimeFailure.cameraPermissionDenied.capabilityIssue
        let photosDenied = CameraRuntimeFailure.photosAddPermissionDenied.capabilityIssue
        let lowStorage = CameraRuntimeFailure.lowStorage(freeMB: 128, minimumStorageMB: 500).capabilityIssue
        let sessionFailed = CameraRuntimeFailure.cameraSessionFailed(reason: "Input unavailable").capabilityIssue

        #expect(cameraDenied.id == "camera.denied")
        #expect(cameraDenied.actionPath == "Settings > Privacy & Security > Camera > Bracketer")
        #expect(photosDenied == DeviceCapabilityIssue.photosAddAccessDenied())
        #expect(photosDenied.actionPath == "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only")
        #expect(lowStorage == DeviceCapabilityIssue.lowStorage(freeMB: 128, minimumStorageMB: 500))
        #expect(lowStorage.actionPath == "Settings > General > iPhone Storage")
        #expect(sessionFailed.actionPath == "Settings > Privacy & Security > Camera > Bracketer")
    }

    @Test func cameraRuntimeErrorsRenderActionPathInAlertCopy() {
        let error = CameraRuntimeFailure.photosAddPermissionDenied.camError

        #expect(error.title == "Photos Add Access")
        #expect(error.message == "Bracketer needs permission to save bracketed captures to Photos.")
        #expect(error.actionPath == "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only")
        #expect(error.alertMessage.contains("Action: Settings > Privacy & Security > Photos > Bracketer > Add Photos Only"))
        #expect(error.capabilityIssue == DeviceCapabilityIssue.photosAddAccessDenied())
        #expect(!error.isRecoverable)
    }

    @Test func cameraRuntimeDiagnosticsSummarizeLatestEventAndTrimOldEntries() {
        let baseDate = Date(timeIntervalSince1970: 10)
        let diagnostics = CameraRuntimeDiagnostics(maxEvents: 2)
            .recording(
                category: .startup,
                severity: .info,
                title: "Camera Startup",
                detail: "Starting camera runtime services.",
                recordedAt: baseDate
            )
            .recording(
                category: .session,
                severity: .info,
                title: "Session Configured",
                detail: "Configured wide camera session.",
                recordedAt: baseDate.addingTimeInterval(1)
            )
            .recording(
                category: .capture,
                severity: .warning,
                title: "Bracket cancelled",
                detail: "Runtime stopped",
                recordedAt: baseDate.addingTimeInterval(2)
            )

        #expect(diagnostics.events.map(\.id) == [2, 3])
        #expect(diagnostics.events.map(\.title) == ["Session Configured", "Bracket cancelled"])
        #expect(diagnostics.summaryAccessibilityValue == "2 events | Latest: Warning Capture | Bracket cancelled")
        #expect(diagnostics.latestAccessibilityValue == "Warning | Capture | Bracket cancelled | Runtime stopped")
    }

    @Test func cameraRuntimeDiagnosticsRecordCapabilityIssueActionPath() {
        let diagnostics = CameraRuntimeDiagnostics()
            .recording(
                issue: DeviceCapabilityIssue.photosAddAccessDenied(),
                category: .permissions,
                recordedAt: Date(timeIntervalSince1970: 0)
            )

        #expect(diagnostics.latest?.severity == .error)
        #expect(diagnostics.latest?.category == .permissions)
        #expect(diagnostics.latest?.actionPath == "Settings > Privacy & Security > Photos > Bracketer > Add Photos Only")
        #expect(diagnostics.latestAccessibilityValue.contains("Action: Settings > Privacy & Security > Photos > Bracketer > Add Photos Only"))
    }

    @Test func cameraRuntimeDiagnosticsIncludeTimingInAccessibilityCopy() {
        let diagnostics = CameraRuntimeDiagnostics()
            .recording(
                category: .session,
                severity: .info,
                title: "Session Configured",
                detail: "Configured wide camera session.",
                durationMilliseconds: 142,
                recordedAt: Date(timeIntervalSince1970: 0)
            )

        #expect(diagnostics.latest?.durationMilliseconds == 142)
        #expect(diagnostics.latestAccessibilityValue == "Info | Session | Session Configured | Configured wide camera session. | Duration: 142 ms")
        #expect(diagnostics.summaryAccessibilityValue == "1 events | Latest: Info Session | Session Configured")
    }

    @Test func cameraRuntimeDiagnosticsExportReportIncludesTimingAndActionPath() {
        let diagnostics = CameraRuntimeDiagnostics()
            .recording(
                category: .photos,
                severity: .warning,
                title: "Photo Save Failed",
                detail: "Failed to save Bracket-0EV-123.heic.",
                actionPath: "Free device storage, then retry capture.",
                durationMilliseconds: 1_501,
                recordedAt: Date(timeIntervalSince1970: 0)
            )

        #expect(diagnostics.exportText == """
        Bracketer Diagnostics
        Events: 1
        Max Events: 30
        Event 1 | 1970-01-01T00:00:00Z | Warning | Photos | Photo Save Failed | Failed to save Bracket-0EV-123.heic. | Action: Free device storage, then retry capture. | Duration: 1501 ms
        """)
    }

    @Test func cameraRuntimePerformanceThresholdsPromoteSlowPhasesToWarnings() {
        #expect(CameraRuntimePerformanceThresholds.severity(
            durationMilliseconds: 999,
            warningThresholdMilliseconds: 1_000
        ) == .info)
        #expect(CameraRuntimePerformanceThresholds.severity(
            durationMilliseconds: 1_000,
            warningThresholdMilliseconds: 1_000
        ) == .warning)
        #expect(CameraRuntimePerformanceThresholds.histogramProcessingWarningMilliseconds == 50)
    }

    @Test func photoSaveResultReportsSuccessAndDurationForDiagnostics() {
        let saved = PhotoSaveResult(
            assetIdentifier: "asset-1",
            filename: "Bracket-0EV-123.heic",
            durationMilliseconds: 64
        )
        let failed = PhotoSaveResult(
            assetIdentifier: nil,
            filename: "Bracket-0EV-123.heic",
            durationMilliseconds: 64
        )

        #expect(saved.didSave)
        #expect(!failed.didSave)
        #expect(saved.durationMilliseconds == 64)
        #expect(saved.filename == "Bracket-0EV-123.heic")
    }

    @Test func cameraRuntimeDiagnosticsAcceptReviewPhotosAndHistogramTimingCategories() {
        let diagnostics = CameraRuntimeDiagnostics()
            .recording(
                category: .photos,
                severity: .info,
                title: "Photo Saved",
                detail: "Saved shot 1 of 3.",
                durationMilliseconds: 80
            )
            .recording(
                category: .review,
                severity: .warning,
                title: "Review Image Loaded",
                detail: "Image 1 of 3 loaded for review.",
                durationMilliseconds: 1_250
            )
            .recording(
                category: .histogram,
                severity: .info,
                title: "Histogram Frame Processed",
                detail: "1200 sampled pixel(s).",
                durationMilliseconds: 12
            )

        #expect(diagnostics.events.map(\.category) == [.photos, .review, .histogram])
        #expect(diagnostics.latestAccessibilityValue == "Info | Histogram | Histogram Frame Processed | 1200 sampled pixel(s). | Duration: 12 ms")
    }

    @Test func deviceCapabilitySnapshotKeepsRecoverableWarningsOutOfBlockers() {
        let snapshot = DeviceCapabilitySnapshot.resolve(inputs: DeviceCapabilityInputs(
            modelIdentifier: "TestPhone",
            systemVersion: "26.4",
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: false,
            hasTelephotoLens: false,
            hasFlash: false,
            supportsProRAW: false,
            photosAuthorization: .notDetermined,
            locationAuthorization: .denied,
            notificationAuthorization: .denied,
            freeStorageMB: 1_024,
            isLowPowerModeEnabled: true
        ))

        #expect(snapshot.isCompatibleDevice)
        #expect(snapshot.capabilityLevel == .basic)
        #expect(snapshot.warningIssues.map(\.id).contains("photos.pending"))
        #expect(snapshot.warningIssues.map(\.id).contains("location.denied"))
        #expect(snapshot.warningIssues.map(\.id).contains("notifications.denied"))
        #expect(snapshot.warningIssues.map(\.id).contains("power.lowPower"))
        #expect(snapshot.statusSummary == "Ready with warnings")
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "BracketerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

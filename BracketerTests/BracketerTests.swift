//
//  BracketerTests.swift
//  BracketerTests
//
//  Created by Rishabh Bansal on 8/25/25.
//

import Testing
import AppIntents
import Foundation
import CoreGraphics
import CoreLocation
import CoreSpotlight
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
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
        #expect(manifest.captureDevice?.libraryLensTitle == "1x Simulated Wide Camera")
        #expect(manifest.captureDevice?.source == "simulated camera harness")
        #expect(manifest.captureLocation?.libraryLocationTitle == "Simulated Location Not Requested")
        #expect(manifest.captureLocation?.preciseCoordinatesStored == false)
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

    @Test func bracketManifestCanIncludeAppliedRecipeSnapshot() throws {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["a", "b", "c", "d", "e"],
            capturedAt: Date(timeIntervalSince1970: 50)
        )
        let recipe = AppliedBracketRecipeRecord(
            id: "recipe-1",
            title: "High contrast scene",
            source: .deterministicFallback,
            plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 5, centerBias: -0.3),
            appliedAt: Date(timeIntervalSince1970: 40)
        )

        let manifest = sequence.manifest(
            groupIdentifier: "recipe-group",
            source: .simulated,
            plan: plan,
            recipe: recipe
        )

        #expect(manifest.recipe?.title == "High contrast scene")
        #expect(manifest.recipe?.source == "deterministicFallback")
        #expect(manifest.recipe?.plan.resolvedShotCount == 5)
        #expect(manifest.recipe?.plan.centerBias == -0.3)
        #expect(
            manifest.recipe?.accessibilityValue
            == "High contrast scene | 5 shots | -4.3 EV, -2.3 EV, -0.3 EV, +1.7 EV, +3.7 EV | Center -0.3 EV | Source: deterministicFallback"
        )

        let json = try manifest.jsonString()
        #expect(json.contains("\"recipe\" : {"))
        #expect(json.contains("\"title\" : \"High contrast scene\""))
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
        store.storesGeneratedProjectNotes = true

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
        #expect(reloaded.storesGeneratedProjectNotes)
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
        #expect(!store.storesGeneratedProjectNotes)
    }

    @Test func settingsStoreAppliesBracketRecipePlanThroughSupportedBracketSettings() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        let recipePlan = BracketRecipePlan(evStep: 2.0, requestedShotCount: 7, centerBias: -0.3)

        let appliedPlan = store.applyBracketRecipePlan(recipePlan)

        #expect(store.selectedEVStep == 2.0)
        #expect(store.bracketShotCount == 7)
        #expect(appliedPlan.evStep == 2.0)
        #expect(appliedPlan.shotCount == 7)
        #expect(appliedPlan.centerBias == -0.3)
        #expect(appliedPlan.shots.map(\.displayLabel) == ["-6.3 EV", "-4.3 EV", "-2.3 EV", "-0.3 EV", "+1.7 EV", "+3.7 EV", "+5.7 EV"])
        #expect(defaults.float(forKey: SettingsStore.Keys.selectedEVStep) == 2.0)
        #expect(defaults.integer(forKey: SettingsStore.Keys.bracketShotCount) == 7)
    }

    @Test func settingsStorePersistsRecentBracketRecipesNewestFirst() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        let first = AppliedBracketRecipeRecord(
            id: "first",
            title: "High contrast scene",
            source: .deterministicFallback,
            plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 5),
            appliedAt: Date(timeIntervalSince1970: 1)
        )
        let second = AppliedBracketRecipeRecord(
            id: "second",
            title: "Fast handheld capture",
            source: .deterministicFallback,
            plan: BracketRecipePlan(evStep: 1.0, requestedShotCount: 3),
            appliedAt: Date(timeIntervalSince1970: 2)
        )

        store.recordAppliedBracketRecipe(first)
        store.recordAppliedBracketRecipe(second)
        store.recordAppliedBracketRecipe(first)

        #expect(store.recentBracketRecipes.map(\.id) == ["first", "second"])
        #expect(store.recentBracketRecipes.first?.accessibilityValue == "High contrast scene | 5 shots | -4.0 EV, -2.0 EV, 0 EV, +2.0 EV, +4.0 EV | Center 0 EV | Source: deterministicFallback")

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.recentBracketRecipes.map(\.id) == ["first", "second"])

        reloadedStore.resetToDefaults()
        #expect(reloadedStore.recentBracketRecipes.isEmpty)
    }

    @Test func settingsStoreLimitsRecentBracketRecipes() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        for index in 0..<7 {
            store.recordAppliedBracketRecipe(
                AppliedBracketRecipeRecord(
                    id: "recipe-\(index)",
                    title: "Recipe \(index)",
                    source: .deterministicFallback,
                    plan: BracketRecipePlan(evStep: 1.0, requestedShotCount: 3),
                    appliedAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        }

        #expect(store.recentBracketRecipes.map(\.id) == ["recipe-6", "recipe-5", "recipe-4", "recipe-3", "recipe-2"])
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

    @Test func captureContextSummaryBuildsPrivacySafePromptFacts() throws {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let review = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: [
                "asset-under",
                "asset-under-mid",
                "asset-center",
                "asset-over-mid",
                "asset-over",
            ],
            capturedAt: Date(timeIntervalSince1970: 0),
            fileType: "RAW + Processed",
            availableRepresentations: [.processed, .raw]
        )
        let manifest = review.manifest(
            groupIdentifier: "private-photos-group",
            source: .photos,
            plan: plan
        )
        let frameAnalysis = makeBalancedClippingFrameAnalysis()
        let device = DeviceCapabilitySnapshot.resolve(inputs: DeviceCapabilityInputs(
            modelIdentifier: "iPhone17,1",
            systemVersion: "26.5",
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: true,
            hasTelephotoLens: true,
            hasFlash: true,
            supportsProRAW: true,
            photosAuthorization: .authorized,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: 8_192,
            isLowPowerModeEnabled: false
        ))
        let capture = EffectiveCaptureConfiguration.resolve(
            isRawEnabled: true,
            flashMode: .on,
            isFlashAvailable: true,
            timerMode: .threeSeconds,
            locationAuthorizationStatus: .authorizedWhenInUse
        )
        let settings = CaptureContextSettings(
            shootingMode: "MANUAL",
            showGrid: true,
            gridType: "Golden Ratio",
            showLevel: true,
            focusPeakingEnabled: true,
            focusPeakingColorName: "orange",
            focusPeakingIntensity: 0.65,
            showHistogram: true,
            showZebras: true
        )

        let summary = CaptureContextSummary.make(
            plan: plan,
            deviceSnapshot: device,
            captureConfiguration: capture,
            settings: settings,
            frameAnalysis: frameAnalysis,
            reviewSequence: review,
            manifest: manifest,
            intelligenceAvailability: .modelNotReady
        )

        #expect(summary.schemaVersion == CaptureContextSummary.currentSchemaVersion)
        #expect(summary.bracket.evLabels == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(summary.frameAnalysis.shadowClippingPercent == 25)
        #expect(summary.frameAnalysis.highlightClippingPercent == 25)
        #expect(summary.frameAnalysis.zebraShadowRegions == 4)
        #expect(summary.frameAnalysis.zebraHighlightRegions == 4)
        #expect(summary.review?.rawAvailableCount == 5)
        #expect(summary.review?.manifestSource == "photos")
        #expect(summary.intelligence.status == "Model not ready")
        #expect(!summary.privacy.rawPhotoBytesIncluded)
        #expect(!summary.privacy.assetIdentifiersIncluded)
        #expect(!summary.privacy.locationCoordinatesIncluded)

        let prompt = summary.compactPromptContext
        #expect(prompt.contains("Apple Intelligence: Model not ready"))
        #expect(prompt.contains("RAW available 5"))
        #expect(!prompt.contains("asset-under"))
        #expect(!prompt.contains("private-photos-group"))

        let encoded = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(CaptureContextSummary.self, from: encoded)
        #expect(decoded == summary)
    }

    @Test func captureContextSummaryHandlesMissingOptionalRuntimeSignals() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let capture = EffectiveCaptureConfiguration.resolve(
            isRawEnabled: false,
            flashMode: .auto,
            isFlashAvailable: false,
            timerMode: .off,
            locationAuthorizationStatus: .denied
        )
        let settings = CaptureContextSettings(
            shootingMode: "AUTO",
            showGrid: false,
            gridType: "Rule of Thirds",
            showLevel: false,
            focusPeakingEnabled: false,
            focusPeakingColorName: "red",
            focusPeakingIntensity: 0.5,
            showHistogram: false,
            showZebras: false
        )

        let summary = CaptureContextSummary.make(
            plan: plan,
            deviceSnapshot: nil,
            captureConfiguration: capture,
            settings: settings,
            frameAnalysis: nil,
            reviewSequence: nil,
            manifest: nil,
            intelligenceAvailability: .simulatorUnsupported
        )

        #expect(summary.device == nil)
        #expect(!summary.frameAnalysis.isAvailable)
        #expect(summary.frameAnalysis.guidanceSignals == ["Frame analysis unavailable"])
        #expect(summary.review == nil)
        #expect(summary.capture.flash == "Unavailable")
        #expect(summary.capture.location == "Off")
        #expect(summary.compactPromptContext.contains("Device: compatibility snapshot unavailable."))
        #expect(summary.compactPromptContext.contains("Review: no bracket review loaded."))
    }

    @Test func captureCoachRequestBuildsPrivacyBoundedPrompt() {
        let context = makeCaptureCoachContext()
        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: context,
            maxSuggestions: 9
        )

        #expect(request.schemaVersion == CaptureCoachRequest.currentSchemaVersion)
        #expect(request.maxSuggestions == 5)
        #expect(request.systemInstruction.contains("Use only the structured context"))
        #expect(request.userPrompt.contains("Task: preCaptureGuidance"))
        #expect(request.userPrompt.contains("Apple Intelligence: Model not ready"))
        #expect(!request.userPrompt.contains("asset-under"))
        #expect(!request.userPrompt.contains("private-photos-group"))
    }

    @Test func deterministicCaptureCoachRespondsFromStructuredSignals() {
        let context = makeCaptureCoachContext()
        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: context,
            maxSuggestions: 3
        )

        let response = DeterministicCaptureCoach.response(for: request)

        #expect(response.schemaVersion == CaptureCoachResponse.currentSchemaVersion)
        #expect(response.task == .preCaptureGuidance)
        #expect(!response.usedAppleIntelligence)
        #expect(response.availabilityStatus == "Model not ready")
        #expect(response.suggestions.map(\.title) == [
            "Protect highlights",
            "Lift shadow detail",
            "Apple Intelligence unavailable",
        ])
        #expect(response.disclosure.contains("structured camera state only"))
    }

    @Test func captureCoachValidatorFiltersAndTrimsModelOutput() {
        let context = makeCaptureCoachContext(intelligenceAvailability: .simulatorUnsupported)
        let request = CaptureCoachRequest.make(
            task: .reviewNarrative,
            context: context,
            maxSuggestions: 1
        )
        let noisyResponse = CaptureCoachResponse(
            schemaVersion: 99,
            task: .preCaptureGuidance,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            suggestions: [
                CaptureCoachSuggestion(
                    priority: .info,
                    title: "",
                    rationale: "Should be removed",
                    action: "Do something",
                    sourceSignals: []
                ),
                CaptureCoachSuggestion(
                    priority: .warning,
                    title: "Keep the center exposure",
                    rationale: "A plausible suggestion",
                    action: "Capture the current bracket.",
                    sourceSignals: ["test"]
                ),
                CaptureCoachSuggestion(
                    priority: .warning,
                    title: "Second valid suggestion",
                    rationale: "Should be trimmed",
                    action: "Trim me.",
                    sourceSignals: ["test"]
                ),
            ],
            disclosure: "stale"
        )

        let validated = CaptureCoachResponseValidator.validated(noisyResponse, for: request)

        #expect(validated.schemaVersion == CaptureCoachResponse.currentSchemaVersion)
        #expect(validated.task == .reviewNarrative)
        #expect(!validated.usedAppleIntelligence)
        #expect(validated.availabilityStatus == "Simulator unsupported")
        #expect(validated.suggestions.count == 1)
        #expect(validated.suggestions.first?.title == "Keep the center exposure")
        #expect(validated.disclosure.contains("no raw photo bytes"))
    }

    @Test func captureCoachEngineFallsBackBeforeModelWhenIntelligenceIsUnavailable() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .modelNotReady)
        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: context,
            maxSuggestions: 3
        )
        let engine = CaptureCoachEngine(
            makeModelGenerator: { ThrowingCaptureCoachModelGenerator() }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .deterministicFallback)
        #expect(run.fallbackReason == "Apple Intelligence unavailable: Model not ready")
        #expect(!run.response.usedAppleIntelligence)
        #expect(run.response.availabilityStatus == "Model not ready")
        #expect(run.response.suggestions.contains { $0.title == "Apple Intelligence unavailable" })
    }

    @Test func captureCoachEngineValidatesFoundationModelsOutput() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .available)
        let request = CaptureCoachRequest.make(
            task: .reviewNarrative,
            context: context,
            maxSuggestions: 1
        )
        let modelResponse = CaptureCoachResponse(
            schemaVersion: 42,
            task: .preCaptureGuidance,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            suggestions: [
                CaptureCoachSuggestion(
                    priority: .info,
                    title: "   ",
                    rationale: "Filtered",
                    action: "Ignore me.",
                    sourceSignals: ["noise"]
                ),
                CaptureCoachSuggestion(
                    priority: .warning,
                    title: "Hold highlights",
                    rationale: "The structured context reports highlight clipping.",
                    action: "Bias the next bracket slightly darker.",
                    sourceSignals: ["highlight clipping"]
                ),
                CaptureCoachSuggestion(
                    priority: .critical,
                    title: "Extra",
                    rationale: "Should be trimmed.",
                    action: "Trim me.",
                    sourceSignals: ["trim"]
                ),
            ],
            disclosure: "stale"
        )
        let engine = CaptureCoachEngine(
            makeModelGenerator: { FixedCaptureCoachModelGenerator(modelResponse: modelResponse) }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .foundationModels)
        #expect(run.fallbackReason == nil)
        #expect(run.response.usedAppleIntelligence)
        #expect(run.response.availabilityStatus == "Available")
        #expect(run.response.task == .reviewNarrative)
        #expect(run.response.suggestions.count == 1)
        #expect(run.response.suggestions.first?.title == "Hold highlights")
        #expect(run.response.disclosure.contains("structured camera state only"))
    }

    @Test func captureCoachEngineFallsBackWhenFoundationModelsFails() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .available)
        let request = CaptureCoachRequest.make(
            task: .preCaptureGuidance,
            context: context,
            maxSuggestions: 3
        )
        let engine = CaptureCoachEngine(
            makeModelGenerator: { ThrowingCaptureCoachModelGenerator() }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .deterministicFallback)
        #expect(run.fallbackReason?.contains("offline model failure") == true)
        #expect(!run.response.usedAppleIntelligence)
        #expect(run.response.availabilityStatus == "Available")
        #expect(run.response.suggestions.first?.title == "Protect highlights")
    }

    @Test func bracketRecipeRequestBuildsPrivacyBoundedPrompt() {
        let context = makeCaptureCoachContext()
        let request = BracketRecipeRequest.make(
            prompt: "Interior window with bright sky and dark furniture",
            context: context,
            maxRecommendations: 9
        )

        #expect(request.schemaVersion == BracketRecipeRequest.currentSchemaVersion)
        #expect(request.maxRecommendations == 5)
        #expect(request.systemInstruction.contains("Use only 3, 5, or 7 shots"))
        #expect(request.userPrompt.contains("Interior window"))
        #expect(request.userPrompt.contains("Structured camera context"))
        #expect(!request.userPrompt.contains("asset-under"))
        #expect(!request.userPrompt.contains("private-photos-group"))
    }

    @Test func adaptiveCapturePlanningProfileSummarizesPromptFrameLensAndPrivacyBoundary() {
        let context = makeCaptureCoachContext()

        let profile = AdaptiveCapturePlanningProfile.make(
            prompt: "Interior window with bright sky and dark furniture",
            context: context
        )

        #expect(profile.schemaVersion == AdaptiveCapturePlanningProfile.currentSchemaVersion)
        #expect(profile.intent.kind == .highDynamicRange)
        #expect(profile.sceneCondition.kind == .interiorWindow)
        #expect(profile.dynamicRange.level == .wide)
        #expect(profile.dynamicRange.rationale.contains("simultaneous highlight and shadow clipping risk"))
        #expect(profile.highlightShadowRisk.highlight == .high)
        #expect(profile.highlightShadowRisk.shadow == .high)
        #expect(profile.highlightShadowRisk.combined == .high)
        #expect(profile.lensCapability.supportsProRAW == nil)
        #expect(profile.lensCapability.status == "Device capability snapshot unavailable")
        #expect(profile.recommendedPlan.resolvedShotCount == 5)
        #expect(profile.captureStrategy.timer.title == "Keep 3s timer")
        #expect(profile.captureStrategy.format.title == "Keep ProRAW")
        #expect(profile.captureStrategy.lens.title == "Keep current lens")
        #expect(profile.captureStrategy.stabilization.title == "Stabilize bracket")
        #expect(profile.captureStrategy.accessibilityValue.contains("Timer: Keep 3s timer"))
        #expect(profile.sourceSignals.contains("scene prompt"))
        #expect(profile.sourceSignals.contains("device capability snapshot unavailable"))
        #expect(profile.privacyBoundary.contains("physical-device proof"))
        #expect(profile.accessibilityValue.contains("Adaptive Capture Planning Profile"))
    }

    @Test func adaptiveCapturePlanningProfileKeepsMotionShortWhenFrameAlsoHasWideRange() {
        let context = makeCaptureCoachContext()

        let profile = AdaptiveCapturePlanningProfile.make(
            prompt: "Handheld street portrait with people moving fast",
            context: context
        )

        #expect(profile.intent.kind == .motionSensitive)
        #expect(profile.sceneCondition.kind == .fastSubject)
        #expect(profile.motionStability.level == .motionSensitive)
        #expect(profile.dynamicRange.level == .wide)
        #expect(profile.recommendedPlan.resolvedShotCount == 3)
        #expect(profile.recommendedPlan.evLabels == ["-1.0 EV", "0 EV", "+1.0 EV"])
        #expect(profile.captureStrategy.timer.title == "Turn timer off")
        #expect(profile.captureStrategy.stabilization.title == "Brace handheld")
    }

    @Test func adaptiveCapturePlanningProfileUsesDeviceCapabilityForFormatAndLensStrategy() {
        let device = DeviceCapabilitySnapshot.resolve(inputs: DeviceCapabilityInputs(
            modelIdentifier: "iPhone17,1",
            systemVersion: "26.5",
            hasBackCamera: true,
            hasWideLens: true,
            hasUltraWideLens: true,
            hasTelephotoLens: true,
            hasFlash: true,
            supportsProRAW: true,
            photosAuthorization: .authorized,
            locationAuthorization: .authorized,
            notificationAuthorization: .authorized,
            freeStorageMB: 8_192,
            isLowPowerModeEnabled: false
        ))
        let context = makeCaptureCoachContext(deviceSnapshot: device)

        let profile = AdaptiveCapturePlanningProfile.make(
            prompt: "Tripod real estate architecture with bright windows",
            context: context
        )

        #expect(profile.lensCapability.status == "Wide, Ultra Wide, Telephoto; ProRAW supported")
        #expect(profile.captureStrategy.format.title == "Keep ProRAW")
        #expect(profile.captureStrategy.format.detail.contains("ProRAW is available"))
        #expect(profile.captureStrategy.lens.title == "Prefer Ultra Wide")
        #expect(profile.captureStrategy.lens.detail.contains("Ultra Wide"))
        #expect(profile.captureStrategy.timer.title == "Keep 3s timer")
        #expect(profile.sourceSignals.contains("device capability snapshot"))
    }

    @Test func adaptiveCapturePlanningProfileTreatsHighContrastLanguageAsWideSignal() {
        let context = makeCaptureCoachContext()

        let profile = AdaptiveCapturePlanningProfile.make(
            prompt: "High contrast sunset through a bright window",
            context: context
        )

        #expect(profile.intent.kind == .highDynamicRange)
        #expect(profile.dynamicRange.level == .wide)
        #expect(profile.recommendedPlan.resolvedShotCount == 5)
        #expect(profile.sourceSignals.contains("high contrast prompt"))
    }

    @Test func deterministicBracketRecipePlannerRespondsToSceneLanguageAndFrameSignals() {
        let context = makeCaptureCoachContext()
        let request = BracketRecipeRequest.make(
            prompt: "Interior window with bright sky and dark furniture",
            context: context,
            maxRecommendations: 2
        )

        let response = DeterministicBracketRecipePlanner.response(for: request)

        #expect(response.schemaVersion == BracketRecipeResponse.currentSchemaVersion)
        #expect(!response.usedAppleIntelligence)
        #expect(response.availabilityStatus == "Model not ready")
        #expect(response.recommendations.count == 2)
        #expect(response.recommendations.first?.title == "High contrast scene")
        #expect(response.recommendations.first?.plan.resolvedShotCount == 5)
        #expect(response.recommendations.first?.plan.evStep == 2.0)
        #expect(response.recommendations.first?.action.contains("Recipe: 5 shots") == true)
        #expect(response.recommendations.first?.action.contains("Stabilize bracket") == true)
        #expect(response.recommendations.first?.action.contains("Keep ProRAW") == true)
        #expect(response.recommendations.first?.sourceSignals.contains("adaptive dynamic range profile") == true)
        #expect(response.recommendations.first?.sourceSignals.contains("scene prompt") == true)
        #expect(response.disclosure.contains("typed scene description only"))
    }

    @Test func deterministicBracketRecipePlannerKeepsFastSubjectsShort() {
        let context = makeCaptureCoachContext()
        let request = BracketRecipeRequest.make(
            prompt: "Handheld street portrait with people moving fast",
            context: context,
            maxRecommendations: 1
        )

        let response = DeterministicBracketRecipePlanner.response(for: request)

        #expect(response.recommendations.first?.title == "Fast handheld capture")
        #expect(response.recommendations.first?.plan.resolvedShotCount == 3)
        #expect(response.recommendations.first?.plan.evLabels == ["-1.0 EV", "0 EV", "+1.0 EV"])
        #expect(response.recommendations.first?.action.contains("Turn timer off") == true)
        #expect(response.recommendations.first?.action.contains("Brace handheld") == true)
        #expect(response.recommendations.first?.sourceSignals.contains("adaptive motion profile") == true)
        #expect(response.recommendations.first?.confidence == 0.78)
    }

    @Test func bracketRecipeRecommendationCompactsConfidenceAndSourceEvidence() {
        let recommendation = BracketRecipeRecommendation(
            title: "Evidence",
            plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 5),
            rationale: "Reason",
            action: "Act",
            sourceSignals: [" scene prompt ", "highlight clipping", "shadow clipping", "capture timer", "device snapshot"],
            confidence: 0.823
        )

        #expect(
            recommendation.compactEvidenceSummary
            == "Confidence 0.82 | Sources: scene prompt, highlight clipping, shadow clipping, capture timer + 1 more"
        )
    }

    @Test func bracketRecipeRecommendationEvidenceHandlesEmptySignalsAndClampedConfidence() {
        let recommendation = BracketRecipeRecommendation(
            title: "Evidence",
            plan: BracketRecipePlan(evStep: 1.0, requestedShotCount: 3),
            rationale: "Reason",
            action: "Act",
            sourceSignals: [" ", ""],
            confidence: 4.2
        )

        #expect(recommendation.compactEvidenceSummary == "Confidence 1.00 | Sources: No source signals recorded")
    }

    @Test func bracketRecipeValidatorNormalizesModelOutput() {
        let context = makeCaptureCoachContext(intelligenceAvailability: .simulatorUnsupported)
        let request = BracketRecipeRequest.make(
            prompt: "Extreme HDR stage spotlight",
            context: context,
            maxRecommendations: 1
        )
        let noisyResponse = BracketRecipeResponse(
            schemaVersion: 99,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            recommendations: [
                BracketRecipeRecommendation(
                    title: " ",
                    plan: BracketRecipePlan(evStep: 4.0, requestedShotCount: 7),
                    rationale: "Filtered",
                    action: "",
                    sourceSignals: ["noise"],
                    confidence: 0.4
                ),
                BracketRecipeRecommendation(
                    title: "  Normalize this recipe  ",
                    plan: BracketRecipePlan(evStep: -2.0, requestedShotCount: 9),
                    rationale: "  Plausible after cleanup  ",
                    action: "  Use the normalized recipe.  ",
                    sourceSignals: ["one", "two", "three", "four", "five", "six", "seven"],
                    confidence: 4.2
                ),
            ],
            disclosure: "stale"
        )

        let validated = BracketRecipeResponseValidator.validated(noisyResponse, for: request)

        #expect(validated.schemaVersion == BracketRecipeResponse.currentSchemaVersion)
        #expect(!validated.usedAppleIntelligence)
        #expect(validated.availabilityStatus == "Simulator unsupported")
        #expect(validated.recommendations.count == 1)
        #expect(validated.recommendations.first?.title == "Normalize this recipe")
        #expect(validated.recommendations.first?.plan.resolvedShotCount == 3)
        #expect(validated.recommendations.first?.plan.evStep == 1.0)
        #expect(validated.recommendations.first?.sourceSignals.count == 6)
        #expect(validated.recommendations.first?.confidence == 1.0)
    }

    @Test func bracketRecipeEngineFallsBackBeforeModelWhenIntelligenceIsUnavailable() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .modelNotReady)
        let request = BracketRecipeRequest.make(
            prompt: "High contrast sunset",
            context: context,
            maxRecommendations: 2
        )
        let engine = BracketRecipeEngine(
            makeModelGenerator: { ThrowingBracketRecipeModelGenerator() }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .deterministicFallback)
        #expect(run.fallbackReason == "Apple Intelligence unavailable: Model not ready")
        #expect(!run.response.usedAppleIntelligence)
        #expect(run.response.recommendations.first?.title == "High contrast scene")
    }

    @Test func bracketRecipeEngineValidatesFoundationModelsOutput() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .available)
        let request = BracketRecipeRequest.make(
            prompt: "Extreme HDR stage spotlight",
            context: context,
            maxRecommendations: 1
        )
        let modelResponse = BracketRecipeResponse(
            schemaVersion: 42,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            recommendations: [
                BracketRecipeRecommendation(
                    title: "Model HDR recipe",
                    plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 7, centerBias: -0.3),
                    rationale: "The structured context and prompt indicate a very high contrast stage scene.",
                    action: "Use seven shots and stabilize the phone.",
                    sourceSignals: ["scene prompt", "highlight clipping"],
                    confidence: 0.91
                ),
                BracketRecipeRecommendation(
                    title: "Trimmed",
                    plan: BracketRecipePlan(evStep: 1.0, requestedShotCount: 3),
                    rationale: "Should be trimmed.",
                    action: "Trim me.",
                    sourceSignals: ["trim"],
                    confidence: 0.1
                ),
            ],
            disclosure: "stale"
        )
        let engine = BracketRecipeEngine(
            makeModelGenerator: { FixedBracketRecipeModelGenerator(modelResponse: modelResponse) }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .foundationModels)
        #expect(run.fallbackReason == nil)
        #expect(run.response.usedAppleIntelligence)
        #expect(run.response.availabilityStatus == "Available")
        #expect(run.response.recommendations.count == 1)
        #expect(run.response.recommendations.first?.title == "Model HDR recipe")
        #expect(run.response.recommendations.first?.plan.accessibilitySummary == "7 shots | -6.3 EV, -4.3 EV, -2.3 EV, -0.3 EV, +1.7 EV, +3.7 EV, +5.7 EV | Center -0.3 EV")
    }

    @Test func bracketRecipeEngineFallsBackWhenFoundationModelsFails() async {
        let context = makeCaptureCoachContext(intelligenceAvailability: .available)
        let request = BracketRecipeRequest.make(
            prompt: "Extreme HDR stage spotlight",
            context: context,
            maxRecommendations: 1
        )
        let engine = BracketRecipeEngine(
            makeModelGenerator: { ThrowingBracketRecipeModelGenerator() }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .deterministicFallback)
        #expect(run.fallbackReason?.contains("offline model failure") == true)
        #expect(!run.response.usedAppleIntelligence)
        #expect(run.response.recommendations.first?.title == "Extreme dynamic range")
        #expect(run.response.recommendations.first?.plan.resolvedShotCount == 7)
    }

    @Test func bracketNarrativeContextBuildsPrivacyBoundedPrompt() {
        let request = makeBracketNarrativeRequest()

        #expect(request.schemaVersion == BracketReviewNarrativeRequest.currentSchemaVersion)
        #expect(request.context.schemaVersion == BracketNarrativeContext.currentSchemaVersion)
        #expect(request.context.exposureSpreadLabel == "-4.0 EV to +4.0 EV")
        #expect(request.context.recipeTitle == "High contrast scene")
        #expect(request.context.recipeSource == "deterministicFallback")
        #expect(request.context.rawAvailableCount == 5)
        #expect(request.userPrompt.contains("Applied recipe: High contrast scene from deterministicFallback."))
        #expect(!request.userPrompt.contains("asset-under"))
        #expect(!request.userPrompt.contains("private-photos-group"))
        #expect(request.userPrompt.contains("no raw photo bytes"))
    }

    @Test func deterministicBracketReviewNarrativeSummarizesManifestTruthfully() {
        let request = makeBracketNarrativeRequest()

        let response = DeterministicBracketReviewNarrative.response(for: request)

        #expect(response.schemaVersion == BracketReviewNarrativeResponse.currentSchemaVersion)
        #expect(!response.usedAppleIntelligence)
        #expect(response.availabilityStatus == "Model not ready")
        #expect(response.title == "5-shot photos bracket")
        #expect(response.summary.contains("Reviewed 5 planned exposures from -4.0 EV to +4.0 EV"))
        #expect(response.summary.contains("best exposure candidate is 0 EV"))
        #expect(response.summary.contains("Recipe: High contrast scene from deterministicFallback."))
        #expect(response.mergeAdvice == "Use the center shot as merge anchor and inspect clipped edge exposures before export.")
        #expect(response.warnings == ["Simulated shadow clipping risk", "Simulated highlight clipping risk"])
        #expect(response.tags.contains("recipe: High contrast scene"))
        #expect(response.disclosure.contains("no raw photo bytes"))
    }

    @Test func bracketReviewNarrativeValidatorNormalizesModelOutput() {
        let request = makeBracketNarrativeRequest(intelligenceAvailability: .simulatorUnsupported)
        let response = BracketReviewNarrativeResponse(
            schemaVersion: 99,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            title: "   ",
            summary: "  Model summary  ",
            mergeAdvice: "  Keep the manifest nearby.  ",
            warnings: [" one ", "", "two", "three", "four", "five"],
            tags: [" a ", "", "b", "c", "d", "e", "f", "g"],
            disclosure: "stale"
        )

        let validated = BracketReviewNarrativeResponseValidator.validated(response, for: request)

        #expect(validated.schemaVersion == BracketReviewNarrativeResponse.currentSchemaVersion)
        #expect(!validated.usedAppleIntelligence)
        #expect(validated.availabilityStatus == "Simulator unsupported")
        #expect(validated.title == "Bracket review")
        #expect(validated.summary == "Model summary")
        #expect(validated.mergeAdvice == "Keep the manifest nearby.")
        #expect(validated.warnings == ["one", "two", "three", "four"])
        #expect(validated.tags == ["a", "b", "c", "d", "e", "f"])
        #expect(validated.disclosure.contains("manifest and review state only"))
    }

    @Test func bracketReviewNarrativeEngineFallsBackBeforeModelWhenUnavailable() async {
        let request = makeBracketNarrativeRequest(intelligenceAvailability: .modelNotReady)
        let engine = BracketReviewNarrativeEngine(
            makeModelGenerator: { ThrowingBracketReviewNarrativeModelGenerator() }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .deterministicFallback)
        #expect(run.fallbackReason == "Apple Intelligence unavailable: Model not ready")
        #expect(!run.response.usedAppleIntelligence)
        #expect(run.response.summary.contains("High contrast scene"))
    }

    @Test func bracketReviewNarrativeEngineValidatesFoundationModelsOutput() async {
        let request = makeBracketNarrativeRequest(intelligenceAvailability: .available)
        let modelResponse = BracketReviewNarrativeResponse(
            schemaVersion: 42,
            usedAppleIntelligence: true,
            availabilityStatus: "stale",
            title: "Model review",
            summary: "This bracket has enough edge coverage for a careful merge.",
            mergeAdvice: "Use the center exposure as the tonal anchor.",
            warnings: ["highlight edge"],
            tags: ["model", "merge"],
            disclosure: "stale"
        )
        let engine = BracketReviewNarrativeEngine(
            makeModelGenerator: { FixedBracketReviewNarrativeModelGenerator(modelResponse: modelResponse) }
        )

        let run = await engine.response(for: request)

        #expect(run.source == .foundationModels)
        #expect(run.fallbackReason == nil)
        #expect(run.response.usedAppleIntelligence)
        #expect(run.response.availabilityStatus == "Available")
        #expect(run.response.title == "Model review")
        #expect(run.sourceLabel == "Generated with Apple Intelligence")
    }

    @Test func bracketManifestSidecarExportsNarrativeWithoutAssetIdentifiers() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRequest = makeBracketNarrativeRequest()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: narrativeRequest,
            fallbackReason: "Not refreshed in this session."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["portfolio candidate", "High contrast scene"],
            createdAt: Date(timeIntervalSince1970: 10)
        )

        #expect(sidecar.schemaVersion == 2)
        #expect(sidecar.manifestSchemaVersion == 1)
        #expect(sidecar.groupReference == "photos-schema1-5shots-0")
        #expect(sidecar.generatedNote?.title == "5-shot photos bracket")
        #expect(sidecar.generatedNote?.source == "deterministicFallback")
        #expect(sidecar.generatedNote?.usedAppleIntelligence == false)
        #expect(sidecar.acceptedTags.contains("portfolio candidate"))
        #expect(sidecar.acceptedTags.contains("recipe: High contrast scene"))
        #expect(sidecar.clippingSummary.warnings == ["Simulated shadow clipping risk", "Simulated highlight clipping risk"])
        #expect(!sidecar.provenance.containsRawPhotoBytes)
        #expect(!sidecar.provenance.containsAssetIdentifiers)

        let json = try sidecar.jsonString()
        #expect(json.contains("\"schemaVersion\" : 2"))
        #expect(json.contains("\"generatedNote\" : {"))
        #expect(!json.contains("asset-under"))
        #expect(!json.contains("private-photos-group"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BracketManifestSidecar.self, from: Data(json.utf8))
        #expect(decoded == sidecar)
    }

    @Test func bracketManifestSidecarCanOmitGeneratedNarrativeByStoragePolicy() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Not refreshed in this session."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            acceptedTags: ["portfolio candidate"],
            storesGeneratedNote: false,
            createdAt: Date(timeIntervalSince1970: 10)
        )

        #expect(sidecar.generatedNote == nil)
        #expect(sidecar.acceptedTags == ["portfolio candidate"])
        #expect(sidecar.provenance.noteSource == nil)

        let json = try sidecar.jsonString()
        #expect(!json.contains("\"generatedNote\""))
        #expect(!json.contains("\"5-shot photos bracket\""))
        #expect(!json.contains("\"noteSource\""))
        #expect(!json.contains("recipe: High contrast scene"))
    }

    @Test func bracketManifestSidecarReadsMinimalVersionTwoWithoutGeneratedNote() throws {
        let json = """
        {
          "acceptedTags" : [],
          "captureContextFacts" : [],
          "capturedAt" : "1970-01-01T00:00:00Z",
          "clippingSummary" : {
            "warningCount" : 0,
            "warnings" : []
          },
          "groupReference" : "photos-schema1-3shots-0",
          "manifestSchemaVersion" : 1,
          "plan" : {
            "centerBias" : 0,
            "evStep" : 1,
            "normalizationReason" : null,
            "requestedShotCount" : 3,
            "resolvedShotCount" : 3
          },
          "provenance" : {
            "appName" : "Bracketer",
            "containsAssetIdentifiers" : false,
            "containsLocationCoordinates" : false,
            "containsRawPhotoBytes" : false,
            "createdAt" : "1970-01-01T00:00:10Z",
            "noteSource" : null
          },
          "schemaVersion" : 2,
          "source" : "photos"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BracketManifestSidecar.self, from: Data(json.utf8))

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.manifestSchemaVersion == 1)
        #expect(decoded.generatedNote == nil)
        #expect(decoded.recipe == nil)
        #expect(decoded.source == .photos)
    }

    @Test @MainActor func cameraControllerRespectsGeneratedProjectNoteStoragePolicy() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let camera = CameraController(projectStore: store)
        let fixture = makeBracketNarrativeManifestFixture()

        camera.storesGeneratedProjectNotes = false
        camera.recordLatestBracketProject(
            manifest: fixture.manifest,
            reviewSequence: fixture.review
        )

        #expect(camera.lastBracketProject?.sidecar?.generatedNote == nil)
        #expect(try store.current()?.sidecar?.generatedNote == nil)

        camera.storesGeneratedProjectNotes = true
        camera.intelligenceAvailabilityForProjectNotes = .simulatorUnsupported
        camera.recordLatestBracketProject(
            manifest: fixture.manifest,
            reviewSequence: fixture.review
        )

        let generatedNote = try #require(camera.lastBracketProject?.sidecar?.generatedNote)
        #expect(generatedNote.title == "5-shot photos bracket")
        #expect(generatedNote.source == "deterministicFallback")
        #expect(generatedNote.disclosure.contains("manifest and review state only"))
        #expect(generatedNote.fallbackReason == "Stored project note generated locally from manifest and review metadata.")
        #expect(try store.current()?.sidecar?.generatedNote == generatedNote)
    }

    @Test func bracketProjectBuildsDurableReviewPrivacyAndSearchContract() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Not refreshed in this session."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )

        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            acceptedTags: ["Portfolio Candidate", "High contrast scene"],
            userNote: "Window test bracket",
            diagnosticsSummary: "5 events | Latest: Info Capture | Bracket complete",
            createdAt: Date(timeIntervalSince1970: 12)
        )

        #expect(project.schemaVersion == 1)
        #expect(project.id == "project-photos-private-photos-group-schema1")
        #expect(project.captureSessionIdentifier == "private-photos-group")
        #expect(project.lifecycle == .reviewable)
        #expect(project.reviewSnapshot.shotCount == 5)
        #expect(project.reviewSnapshot.rawAvailableCount == 5)
        #expect(project.reviewSnapshot.bestExposureLabel == "0 EV")
        #expect(project.assets.map(\.displayLabel) == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(project.previewPlaceholders.map(\.displayLabel) == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(project.previewPlaceholders[2].symbolName == "target")
        #expect(project.previewStripAccessibilityValue.contains("Preview placeholders"))
        #expect(project.previewStripAccessibilityValue.contains("Best exposure candidate"))
        #expect(!project.previewStripAccessibilityValue.contains("asset-under"))
        #expect(project.privacy.storesRawPhotoBytes == false)
        #expect(project.privacy.storesAssetIdentifiers)
        #expect(project.privacy.storesPreciseLocationCoordinates == false)
        #expect(project.privacy.containsGeneratedText)
        #expect(project.privacy.containsCaptureContextFacts)
        #expect(project.privacy.assetIdentifierPolicy.contains("omitted from generated sidecars"))
        #expect(project.searchTokens.contains("portfolio"))
        #expect(project.searchTokens.contains("window"))
        #expect(project.searchTokens.contains("reviewable"))
        #expect(project.searchTokens.contains("raw"))
        #expect(project.diagnosticsReference?.summary.contains("Bracket complete") == true)
        #expect(project.accessibilityValue.contains("Photos identifiers scoped for recovery"))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BracketProject.self, from: data)
        #expect(decoded == project)
    }

    @Test func privacyTrustCenterSnapshotSummarizesLocalBoundaries() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Not refreshed in this session."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            diagnosticsSummary: "5 events | Latest: Info Capture | Bracket complete",
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let library = BracketProjectLibrarySnapshot.make(
            projects: [project],
            currentProjectID: project.id
        )

        let snapshot = BracketerPrivacyTrustSnapshot.make(
            projectLibrary: library,
            intelligenceAvailability: .simulatorUnsupported,
            captureCoachRun: makeCaptureCoachRun(fallbackReason: "Not refreshed in this session."),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session."),
            storesGeneratedProjectNotes: true,
            diagnosticsReport: """
            Bracketer Diagnostics
            Events: 1
            Latest: Info Capture | Bracket complete
            """
        )

        #expect(snapshot.schemaVersion == 2)
        #expect(snapshot.projectCount == 1)
        #expect(snapshot.latestProjectID == project.id)
        #expect(snapshot.latestProjectTitle == "5-shot photos bracket")
        #expect(snapshot.storesGeneratedProjectNotes)
        #expect(snapshot.rows.map(\.id) == [
            "localComputation",
            "photosAccess",
            "locationPolicy",
            "appleIntelligence",
            "generatedContent",
            "diagnostics",
            "exportBoundary",
        ])
        #expect(snapshot.localComputationPolicy.contains("computed locally"))
        #expect(snapshot.photosAccessPolicy.contains("Photos local identifiers are scoped for recovery"))
        #expect(snapshot.photosAccessPolicy.contains("metadata-only exports redact"))
        #expect(snapshot.locationPolicy.contains("Photo Location Requested, Project Redacted"))
        #expect(snapshot.locationPolicy.contains("No precise coordinates"))
        #expect(snapshot.appleIntelligencePolicy.contains("Simulator unsupported"))
        #expect(snapshot.appleIntelligencePolicy.contains("Coach fallback: Not refreshed in this session."))
        #expect(snapshot.appleIntelligencePolicy.contains("Recipe fallback: Not planned in this session."))
        #expect(snapshot.generatedContentPolicy.contains("5-shot photos bracket"))
        #expect(snapshot.generatedContentPolicy.contains("deterministicFallback"))
        #expect(snapshot.generatedContentPolicy.contains("Generated project-note storage is On"))
        #expect(snapshot.diagnosticsPolicy.contains("3 report lines"))
        #expect(snapshot.exportPolicy.contains("Default metadata-only exports redact"))
        #expect(snapshot.privacyBoundary.contains("does not inspect raw pixels"))
        #expect(snapshot.accessibilityValue.contains("Privacy Trust Center"))
        #expect(snapshot.accessibilityValue.contains("Location Policy"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        let decoded = try JSONDecoder().decode(BracketerPrivacyTrustSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func accessibilityAuditSurfacesInclusiveDesignGapsAndTapTargets() throws {
        let audit = BracketerAccessibilityAudit.make()
        let dynamicTypeContract = BracketerDynamicTypeContract.implemented
        let reducedMotionContract = BracketerReducedMotionContract.implemented
        let highContrastContract = BracketerHighContrastContract.implemented
        let tapTargetContract = BracketerTapTargetContract.implemented()

        #expect(audit.schemaVersion == 1)
        #expect(audit.minimumTapTargetPoints == 44)
        #expect(audit.rows.map(\.id) == [
            "dynamicType",
            "reducedMotion",
            "highContrast",
            "tapTargets",
        ])
        #expect(audit.verifiedCount == 3)
        #expect(audit.observedCount == 0)
        #expect(audit.followUpCount == 1)
        #expect(dynamicTypeContract.isVerified)
        #expect(dynamicTypeContract.accessibilityValue.contains("honors SwiftUI Dynamic Type"))
        #expect(dynamicTypeContract.accessibilityValue.contains("audit rows stack at accessibility sizes"))
        #expect(dynamicTypeContract.accessibilityValue.contains("UI tests force Accessibility 3 at app root"))
        #expect(dynamicTypeContract.auditDetail(observedLabel: "Accessibility 3").contains("Observed Dynamic Type: Accessibility 3"))
        #expect(dynamicTypeContract.auditDetail(observedLabel: nil).contains("App-wide screenshot layout proof remains"))
        #expect(reducedMotionContract.isVerified)
        #expect(reducedMotionContract.accessibilityValue.contains("honors system Reduce Motion"))
        #expect(reducedMotionContract.auditDetail.contains("Settings sheet presentation/dismissal"))
        #expect(highContrastContract.isVerified)
        #expect(highContrastContract.accessibilityValue.contains("honors system Increased Contrast"))
        #expect(highContrastContract.auditDetail.contains("strengthens row borders"))
        #expect(tapTargetContract.isVerified)
        #expect(tapTargetContract.accessibilityValue.contains("Compact PRO top-bar button 44 pt"))
        #expect(tapTargetContract.auditDetail.contains("Settings close button"))
        #expect(audit.rows.first { $0.id == "dynamicType" }?.status == .followUpRequired)
        #expect(audit.rows.first { $0.id == "dynamicType" }?.accessibilityValue.contains("semantic text styles") == true)
        #expect(audit.rows.first { $0.id == "reducedMotion" }?.status == .verified)
        #expect(audit.rows.first { $0.id == "highContrast" }?.status == .verified)
        #expect(audit.rows.first { $0.id == "tapTargets" }?.status == .verified)
        #expect(audit.accessibilityValue.contains("Inclusive Design Audit"))
        #expect(audit.accessibilityValue.contains("Minimum tap target 44 pt"))
        #expect(audit.accessibilityValue.contains("0 observed"))
        #expect(audit.accessibilityValue.contains("Dynamic Type"))
        #expect(audit.accessibilityValue.contains("Reduced Motion"))
        #expect(audit.accessibilityValue.contains("High Contrast"))
        #expect(audit.accessibilityValue.contains("does not prove physical-device accessibility"))
        #expect(!audit.accessibilityValue.contains("Physical proof captured"))

        let failingAudit = BracketerAccessibilityAudit.make(intelligenceIconButtonPoints: 34)
        #expect(failingAudit.rows.first { $0.id == "tapTargets" }?.status == .followUpRequired)
        #expect(failingAudit.followUpCount == 2)
        #expect(
            BracketerTapTargetContract
                .implemented(compactAppleIntelligenceButtonPoints: 34)
                .isVerified == false
        )

        let incompleteDynamicTypeContract = BracketerDynamicTypeContract(
            honorsSystemDynamicType: false,
            usesSemanticAuditTypography: true,
            allowsAuditRowsToWrapVertically: true,
            stacksAuditRowsAtAccessibilitySizes: true,
            preservesStableAuditIdentifiersAndValues: true,
            uiTestForcesAccessibilitySizeAtAppRoot: true
        )
        let incompleteDynamicTypeAudit = BracketerAccessibilityAudit.make(
            dynamicTypeContract: incompleteDynamicTypeContract
        )
        #expect(incompleteDynamicTypeAudit.rows.first { $0.id == "dynamicType" }?.status == .followUpRequired)

        let incompleteMotionContract = BracketerReducedMotionContract(
            honorsSystemReduceMotion: false,
            disablesCameraChromeSprings: true,
            disablesSettingsSheetSprings: true,
            disablesSettingsPreviewSprings: true,
            preservesCaptureTimingAndHaptics: true
        )
        let incompleteMotionAudit = BracketerAccessibilityAudit.make(
            reducedMotionContract: incompleteMotionContract
        )
        #expect(incompleteMotionAudit.rows.first { $0.id == "reducedMotion" }?.status == .followUpRequired)

        let incompleteHighContrastContract = BracketerHighContrastContract(
            honorsSystemIncreasedContrast: false,
            pairsStatusColorWithIconAndText: true,
            strengthensAuditRowBorders: true,
            preservesStableAccessibilityValues: true
        )
        let incompleteContrastAudit = BracketerAccessibilityAudit.make(
            highContrastContract: incompleteHighContrastContract
        )
        #expect(incompleteContrastAudit.rows.first { $0.id == "highContrast" }?.status == .followUpRequired)

        let data = try JSONEncoder().encode(audit)
        let decoded = try JSONDecoder().decode(BracketerAccessibilityAudit.self, from: data)
        #expect(decoded == audit)

        let contractData = try JSONEncoder().encode(reducedMotionContract)
        let decodedContract = try JSONDecoder().decode(BracketerReducedMotionContract.self, from: contractData)
        #expect(decodedContract == reducedMotionContract)

        let contrastContractData = try JSONEncoder().encode(highContrastContract)
        let decodedContrastContract = try JSONDecoder().decode(BracketerHighContrastContract.self, from: contrastContractData)
        #expect(decodedContrastContract == highContrastContract)

        let dynamicTypeContractData = try JSONEncoder().encode(dynamicTypeContract)
        let decodedDynamicTypeContract = try JSONDecoder().decode(BracketerDynamicTypeContract.self, from: dynamicTypeContractData)
        #expect(decodedDynamicTypeContract == dynamicTypeContract)

        let tapTargetContractData = try JSONEncoder().encode(tapTargetContract)
        let decodedTapTargetContract = try JSONDecoder().decode(BracketerTapTargetContract.self, from: tapTargetContractData)
        #expect(decodedTapTargetContract == tapTargetContract)
    }

    @Test func accessibilityAuditReflectsObservedAccessibilityEnvironment() throws {
        let environment = BracketerAccessibilityAudit.EnvironmentEvidence(
            source: "UI-test forced accessibility environment",
            dynamicTypeLabel: "Accessibility 3",
            dynamicTypeIsAccessibilitySize: true,
            reduceMotionEnabled: true,
            highContrastEnabled: true
        )
        let audit = BracketerAccessibilityAudit.make(environmentEvidence: environment)

        #expect(audit.environmentEvidence == environment)
        #expect(audit.verifiedCount == 4)
        #expect(audit.observedCount == 0)
        #expect(audit.followUpCount == 0)
        #expect(audit.rows.first { $0.id == "dynamicType" }?.status == .verified)
        #expect(audit.rows.first { $0.id == "dynamicType" }?.accessibilityValue.contains("Observed Dynamic Type: Accessibility 3") == true)
        #expect(audit.rows.first { $0.id == "reducedMotion" }?.status == .verified)
        #expect(audit.rows.first { $0.id == "highContrast" }?.status == .verified)
        #expect(audit.accessibilityValue.contains("Accessibility Environment"))
        #expect(audit.accessibilityValue.contains("Source: UI-test forced accessibility environment"))
        #expect(audit.accessibilityValue.contains("Dynamic Type: Accessibility 3"))
        #expect(audit.accessibilityValue.contains("Accessibility dynamic type: Yes"))
        #expect(audit.accessibilityValue.contains("Reduce Motion: On"))
        #expect(audit.accessibilityValue.contains("High Contrast: Increased"))

        let incompleteMotionContract = BracketerReducedMotionContract(
            honorsSystemReduceMotion: false,
            disablesCameraChromeSprings: true,
            disablesSettingsSheetSprings: true,
            disablesSettingsPreviewSprings: true,
            preservesCaptureTimingAndHaptics: true
        )
        let observedOnlyAudit = BracketerAccessibilityAudit.make(
            environmentEvidence: environment,
            reducedMotionContract: incompleteMotionContract
        )
        #expect(observedOnlyAudit.rows.first { $0.id == "reducedMotion" }?.status == .observed)

        let incompleteDynamicTypeContract = BracketerDynamicTypeContract(
            honorsSystemDynamicType: false,
            usesSemanticAuditTypography: true,
            allowsAuditRowsToWrapVertically: true,
            stacksAuditRowsAtAccessibilitySizes: true,
            preservesStableAuditIdentifiersAndValues: true,
            uiTestForcesAccessibilitySizeAtAppRoot: true
        )
        let observedDynamicTypeAudit = BracketerAccessibilityAudit.make(
            environmentEvidence: environment,
            dynamicTypeContract: incompleteDynamicTypeContract
        )
        #expect(observedDynamicTypeAudit.rows.first { $0.id == "dynamicType" }?.status == .observed)

        let incompleteHighContrastContract = BracketerHighContrastContract(
            honorsSystemIncreasedContrast: false,
            pairsStatusColorWithIconAndText: true,
            strengthensAuditRowBorders: true,
            preservesStableAccessibilityValues: true
        )
        let observedContrastAudit = BracketerAccessibilityAudit.make(
            environmentEvidence: environment,
            highContrastContract: incompleteHighContrastContract
        )
        #expect(observedContrastAudit.rows.first { $0.id == "highContrast" }?.status == .observed)

        let data = try JSONEncoder().encode(audit)
        let decoded = try JSONDecoder().decode(BracketerAccessibilityAudit.self, from: data)
        #expect(decoded == audit)
    }

    @Test func accessibilityScreenshotMatrixDefinesAppWideForcedEnvironmentProof() throws {
        let environment = BracketerAccessibilityAudit.EnvironmentEvidence(
            source: "UI-test forced accessibility environment",
            dynamicTypeLabel: "Accessibility 3",
            dynamicTypeIsAccessibilitySize: true,
            reduceMotionEnabled: true,
            highContrastEnabled: true
        )
        let matrix = BracketerAccessibilityScreenshotMatrix.accessibilityHeavy(
            environmentEvidence: environment
        )

        #expect(matrix.schemaVersion == 1)
        #expect(matrix.isComplete)
        #expect(matrix.surfaces.map(\.id) == [
            "cameraCockpit",
            "settingsAbout",
            "projectReview",
        ])
        #expect(matrix.screenshotAttachmentNames == [
            "Accessibility Matrix - Camera Cockpit - Accessibility 3",
            "Accessibility Matrix - Settings About - Accessibility 3",
            "Accessibility Matrix - Project Review - Accessibility 3",
        ])
        #expect(matrix.surfaces[0].requiredAccessibilityIdentifiers.contains("camera.captureCoach.card"))
        #expect(matrix.surfaces[1].requiredAccessibilityIdentifiers.contains("settings.accessibility.screenshotMatrix"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.voiceOverTraversal"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.finalWorkspace.fixture"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.tapTargetAudit"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.beforeAfterScrub"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.beforeAfterScrub.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.bestBaseFrame"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.bestBaseFrame.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.perShotExposure"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.perShotExposure.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.focusEdge"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.focusEdge.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionAlignment"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionAlignment.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionMetadata"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionMetadata.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.featureMatch"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.featureMatch.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentTransform"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentTransform.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionBlur"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.motionBlur.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.ghostingRisk"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.ghostingRisk.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.movingRegionMask"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.movingRegionMask.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentPerformance"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentPerformance.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentExplanation"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.alignmentExplanation.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.qualityReport"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.qualityReport.card"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.mergeReadiness"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.finalOutputs"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.finalOutputReadinessAudit"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.assetResources"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.imageBundle"))
        #expect(matrix.surfaces[2].requiredAccessibilityIdentifiers.contains("review.project.representationToggle"))
        #expect(matrix.accessibilityValue.contains("Accessibility Screenshot Matrix"))
        #expect(matrix.accessibilityValue.contains("Dynamic Type: Accessibility 3"))
        #expect(matrix.accessibilityValue.contains("Reduce Motion: On"))
        #expect(matrix.accessibilityValue.contains("High Contrast: Increased"))
        #expect(matrix.accessibilityValue.contains("does not prove physical-device accessibility"))
        #expect(!matrix.accessibilityValue.contains("Physical proof captured"))

        let incompleteEnvironment = BracketerAccessibilityAudit.EnvironmentEvidence(
            source: "standard simulator",
            dynamicTypeLabel: "Large",
            dynamicTypeIsAccessibilitySize: false,
            reduceMotionEnabled: false,
            highContrastEnabled: false
        )
        #expect(!BracketerAccessibilityScreenshotMatrix.accessibilityHeavy(
            environmentEvidence: incompleteEnvironment
        ).isComplete)

        let data = try JSONEncoder().encode(matrix)
        let decoded = try JSONDecoder().decode(BracketerAccessibilityScreenshotMatrix.self, from: data)
        #expect(decoded == matrix)
    }

    @Test func physicalDeviceProofChecklistSeparatesSimulatorEvidenceFromPhysicalProof() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let library = BracketProjectLibrarySnapshot.make(
            projects: [project],
            currentProjectID: project.id
        )
        let runtimeDiagnostic = IntelligenceRuntimeDiagnostic(
            availability: .simulatorUnsupported,
            captureCoachRun: makeCaptureCoachRun(fallbackReason: "Not refreshed in this session."),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session.")
        )
        let privacyTrust = BracketerPrivacyTrustSnapshot.make(
            projectLibrary: library,
            intelligenceAvailability: .simulatorUnsupported,
            captureCoachRun: makeCaptureCoachRun(fallbackReason: "Not refreshed in this session."),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session."),
            storesGeneratedProjectNotes: false,
            diagnosticsReport: ""
        )

        let checklist = BracketerPhysicalDeviceProofChecklist.make(
            projectLibrary: library,
            runtimeDiagnostic: runtimeDiagnostic,
            privacyTrust: privacyTrust
        )

        #expect(checklist.schemaVersion == 1)
        #expect(checklist.projectCount == 1)
        #expect(checklist.latestProjectID == project.id)
        #expect(checklist.latestProjectTitle == "5-shot photos bracket")
        #expect(checklist.physicalProofCount == 0)
        #expect(checklist.requiredPhysicalProofCount == 10)
        #expect(checklist.items.map(\.id) == [
            "liveFoundationModelsOutput",
            "photosResourceFetch",
            "photosBackedThumbnails",
            "finalRenderedOutputBytes",
            "photosSideBySidePixels",
            "imageBundleByteExport",
            "lensExifProRAW",
            "locationPermissionPolicy",
            "filesShortcutsRoundTrip",
            "spotlightHandoffContinuation",
        ])
        #expect(checklist.items.allSatisfy { $0.status == .requiresPhysicalDevice })
        #expect(checklist.simulatorCoverageSummary.contains("Simulator evidence is not physical iPhone proof"))
        #expect(checklist.physicalProofSummary.contains("0 physical proofs captured"))
        #expect(checklist.deviceMatrixAccessibilityValue.contains("Real iPhone model"))
        #expect(checklist.privacyBoundary.contains("does not store raw photo bytes"))
        #expect(checklist.accessibilityValue.contains("Physical Device Proof Checklist"))
        #expect(checklist.accessibilityValue.contains("Required Device Matrix"))

        let liveFoundationModelsItem = try #require(
            checklist.items.first { $0.id == "liveFoundationModelsOutput" }
        )
        #expect(liveFoundationModelsItem.simulatorEvidence.contains("Deterministic fallback active"))
        #expect(liveFoundationModelsItem.requiredPhysicalEvidence.contains("Requires real iPhone"))

        let photosResourceItem = try #require(
            checklist.items.first { $0.id == "photosResourceFetch" }
        )
        #expect(photosResourceItem.requiredPhysicalEvidence.contains("PHAssetResource"))
        #expect(photosResourceItem.accessibilityValue.contains("Simulator evidence"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(checklist)
        let decoded = try JSONDecoder().decode(BracketerPhysicalDeviceProofChecklist.self, from: data)
        #expect(decoded == checklist)
    }

    @Test func physicalCaptureMatrixDefinesRealDeviceLabScenariosWithoutClaimingProof() throws {
        let matrix = BracketerPhysicalCaptureMatrix.make()

        #expect(matrix.schemaVersion == 1)
        #expect(matrix.scenarioCount == 8)
        #expect(matrix.provenScenarioCount == 0)
        #expect(matrix.scenarios.map(\.id) == [
            "dynamicRangeInteriorWindow",
            "lensProRAWResourceSweep",
            "handheldMotionRecovery",
            "photosPermissionLocationSweep",
            "storagePressurePartialSave",
            "liveFoundationModelsCoach",
            "filesShortcutsSpotlightRoundTrip",
            "multiDeviceOSRegression",
        ])
        #expect(matrix.scenarios.allSatisfy { $0.status == .requiresPhysicalDevice })
        #expect(matrix.summaryValue.contains("Physical Capture Matrix"))
        #expect(matrix.summaryValue.contains("0 of 8 scenario proofs captured"))
        #expect(matrix.summaryValue.contains("Real iPhone required"))
        #expect(matrix.summaryValue.contains("Simulator coverage does not satisfy capture matrix"))
        #expect(matrix.privacyBoundary.contains("stores no Photos identifiers"))
        #expect(matrix.privacyBoundary.contains("image bytes"))
        #expect(matrix.privacyBoundary.contains("thumbnails"))
        #expect(matrix.privacyBoundary.contains("precise coordinates"))
        #expect(matrix.accessibilityValue.contains("Interior Window Dynamic Range"))
        #expect(matrix.accessibilityValue.contains("PHAssetResource metadata"))
        #expect(matrix.accessibilityValue.contains("Non-fallback LanguageModelSession result"))
        #expect(matrix.accessibilityValue.contains("Per-device result bundles"))
        #expect(!matrix.accessibilityValue.localizedCaseInsensitiveContains("captured on iPhone"))
        #expect(!matrix.accessibilityValue.localizedCaseInsensitiveContains("verified on"))
        #expect(!matrix.accessibilityValue.contains("Physical proof captured"))

        let checklistProofIDs: Set<String> = [
            "liveFoundationModelsOutput",
            "photosResourceFetch",
            "photosBackedThumbnails",
            "finalRenderedOutputBytes",
            "photosSideBySidePixels",
            "imageBundleByteExport",
            "lensExifProRAW",
            "locationPermissionPolicy",
            "filesShortcutsRoundTrip",
            "spotlightHandoffContinuation",
        ]
        for scenario in matrix.scenarios {
            #expect(!scenario.linkedProofIDs.isEmpty)
            #expect(Set(scenario.linkedProofIDs).isSubset(of: checklistProofIDs))
        }

        let lensSweep = try #require(
            matrix.scenarios.first { $0.id == "lensProRAWResourceSweep" }
        )
        #expect(lensSweep.linkedProofIDs.contains("lensExifProRAW"))
        #expect(lensSweep.linkedProofIDs.contains("imageBundleByteExport"))
        #expect(lensSweep.accessibilityValue.contains("Ultra-wide, wide, and telephoto"))

        let systemRoundTrip = try #require(
            matrix.scenarios.first { $0.id == "filesShortcutsSpotlightRoundTrip" }
        )
        #expect(systemRoundTrip.linkedProofIDs == [
            "filesShortcutsRoundTrip",
            "spotlightHandoffContinuation",
        ])

        let encoder = JSONEncoder()
        let firstDefaultMatrix = BracketerPhysicalCaptureMatrix.make()
        let secondDefaultMatrix = BracketerPhysicalCaptureMatrix.make()
        #expect(firstDefaultMatrix == secondDefaultMatrix)
        #expect(try JSONDecoder().decode(BracketerPhysicalCaptureMatrix.self, from: encoder.encode(firstDefaultMatrix)) == firstDefaultMatrix)
        #expect(try JSONDecoder().decode(BracketerPhysicalCaptureMatrix.self, from: encoder.encode(secondDefaultMatrix)) == secondDefaultMatrix)

        let firstScenario = try #require(matrix.scenarios.first)
        var partiallyProvenScenarios = matrix.scenarios
        partiallyProvenScenarios[0] = BracketerPhysicalCaptureMatrix.Scenario(
            id: firstScenario.id,
            title: firstScenario.title,
            deviceAxis: firstScenario.deviceAxis,
            captureAxis: firstScenario.captureAxis,
            permissionAxis: firstScenario.permissionAxis,
            environmentAxis: firstScenario.environmentAxis,
            requiredEvidence: firstScenario.requiredEvidence,
            linkedProofIDs: firstScenario.linkedProofIDs,
            status: .physicalProofCaptured
        )
        let partiallyProvenMatrix = BracketerPhysicalCaptureMatrix(scenarios: partiallyProvenScenarios)
        #expect(partiallyProvenMatrix.provenScenarioCount == 1)
        #expect(partiallyProvenMatrix.summaryValue.contains("1 of 8 scenario proofs captured"))

        let data = try encoder.encode(matrix)
        let decoded = try JSONDecoder().decode(BracketerPhysicalCaptureMatrix.self, from: data)
        #expect(decoded == matrix)
    }

    @Test func physicalDeviceLabPreflightListsExternalReadinessWithoutCountingProof() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let preflight = BracketerPhysicalDeviceLabPreflight.make(catalog: catalog)

        #expect(preflight.schemaVersion == 1)
        #expect(preflight.scenarioID == "dynamicRangeInteriorWindow")
        #expect(preflight.scenarioTitle == "Interior Window Dynamic Range")
        #expect(preflight.verifiedCheckCount == 0)
        #expect(preflight.checkIDs == [
            "connectedUnlockedIPhone",
            "physicalDestinationSelected",
            "scenarioResultBundleReserved",
            "compactSummaryAndDigestsReady",
            "attachmentManifestReady",
            "signedProofPreviewBeforeIngest",
        ])
        #expect(preflight.checks.allSatisfy { $0.status == .requiresReviewerAction })
        #expect(preflight.summaryValue.contains("Physical Device Lab Preflight"))
        #expect(preflight.summaryValue.contains("Connected unlocked iPhone required"))
        #expect(preflight.summaryValue.contains("No physical proof count changed"))
        #expect(preflight.accessibilityValue.contains("Xcode/devicectl lists an available unlocked iPhone"))
        #expect(preflight.accessibilityValue.contains("platform=iOS,id=<DEVICE-UDID>"))
        #expect(preflight.accessibilityValue.contains("result-bundle SHA-256"))
        #expect(preflight.accessibilityValue.contains("attachment hashes or byte counts"))
        #expect(preflight.accessibilityValue.contains("does not execute commands"))
        #expect(preflight.accessibilityValue.contains("does not count physical proof"))
        #expect(!preflight.accessibilityValue.contains("Physical proof captured"))

        let decoded = try JSONDecoder().decode(
            BracketerPhysicalDeviceLabPreflight.self,
            from: try JSONEncoder().encode(preflight)
        )
        #expect(decoded == preflight)
    }

    @Test func hostDeviceAvailabilityReportParsesDevicectlUnavailablePhysicalIPhoneWithoutLeakingIdentifiers() throws {
        let rawUDID = "00008101-001A442C26AA801E"
        let devicectlText = """
        Devices:
        Name              Identifier                            State        Model
        ----------------- ------------------------------------- ------------ ----------
        Physical iPhone   \(rawUDID)             unavailable  iPhone18,2 (iPhone 17 Pro Max) (26.5)
        Apple Watch       11112222-3333-4444-5555-666677778888  connected    Watch6,8 (44mm) (10.4)
        iPhone 17 Simulator  22223333-4444-5555-6666-777788889999  available    iPhone17,1 Simulator (26.4)
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(devicectlText)

        #expect(report.schemaVersion == 1)
        #expect(report.source == .devicectl)
        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 0)
        #expect(report.unavailablePhysicalIPhoneCount == 1)
        #expect(report.offlinePhysicalIPhoneCount == 0)
        #expect(report.devices.count == 1)
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone unavailable or offline"))
        #expect(report.labReadinessValue.contains("No physical proof count changed"))

        let device = try #require(report.devices.first)
        #expect(device.isPhysicalIPhone == true)
        #expect(device.availability == .unavailable)
        #expect(device.modelLabel == "iPhone18,2")
        #expect(device.osLabel == "26.5")
        #expect(device.id.hasPrefix("device-"))
        #expect(!device.id.contains(rawUDID))
        #expect(device.id != rawUDID)

        #expect(report.summaryValue.contains("Host Device Availability Report"))
        #expect(report.summaryValue.contains("devicectl list devices"))
        #expect(report.summaryValue.contains("1 physical iPhone row(s)"))
        #expect(report.summaryValue.contains("0 available"))
        #expect(report.summaryValue.contains("1 unavailable"))
        #expect(report.summaryValue.contains("preview only"))
        #expect(report.summaryValue.contains("no physical proof count changed"))
        #expect(report.summaryValue.contains("Connected unlocked iPhone still required"))
        #expect(!report.summaryValue.contains(rawUDID))
        #expect(!report.summaryValue.contains("Physical proof captured"))

        #expect(report.accessibilityValue.contains("does not execute commands"))
        #expect(report.accessibilityValue.contains("does not count physical proof"))
        #expect(!report.accessibilityValue.contains(rawUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let data = try JSONEncoder().encode(report)
        let serialized = try #require(String(data: data, encoding: .utf8))
        #expect(!serialized.contains(rawUDID))
        let decoded = try JSONDecoder().decode(BracketerHostDeviceAvailabilityReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func hostDeviceAvailabilityReportParsesXctraceOfflinePhysicalIPhoneWithoutLeakingIdentifiers() throws {
        let rawUDID = "00008101-001A442C26AA801E"
        let xctraceText = """
        == Devices ==
        M3 Max (Apple Silicon)
        == Devices Offline ==
        Physical iPhone (26.5) (\(rawUDID))
        == Simulators ==
        iPhone 17 Pro (26.4) (12345678-1234-5678-9ABC-DEF012345678)
        iPhone 17 (26.4) (87654321-4321-8765-CBA9-876543210FED)
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(xctraceText)

        #expect(report.source == .xctrace)
        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 0)
        #expect(report.unavailablePhysicalIPhoneCount == 0)
        #expect(report.offlinePhysicalIPhoneCount == 1)
        #expect(report.devices.count == 1)
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone unavailable or offline"))
        #expect(report.labReadinessValue.contains("Connected unlocked iPhone still required"))

        let device = try #require(report.devices.first)
        #expect(device.isPhysicalIPhone == true)
        #expect(device.availability == .offline)
        #expect(device.osLabel == "26.5")
        #expect(device.id.hasPrefix("device-"))
        #expect(!device.id.contains(rawUDID))

        #expect(report.summaryValue.contains("xctrace list devices"))
        #expect(report.summaryValue.contains("1 physical iPhone row(s)"))
        #expect(report.summaryValue.contains("1 offline"))
        #expect(report.summaryValue.contains("preview only"))
        #expect(report.summaryValue.contains("no physical proof count changed"))
        #expect(report.summaryValue.contains("Connected unlocked iPhone still required"))
        #expect(!report.summaryValue.contains(rawUDID))
        #expect(!report.summaryValue.contains("12345678-1234-5678-9ABC-DEF012345678"))
        #expect(!report.summaryValue.contains("Physical proof captured"))

        #expect(!report.accessibilityValue.contains(rawUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let data = try JSONEncoder().encode(report)
        let serialized = try #require(String(data: data, encoding: .utf8))
        #expect(!serialized.contains(rawUDID))
        #expect(!serialized.contains("12345678-1234-5678-9ABC-DEF012345678"))
        let decoded = try JSONDecoder().decode(BracketerHostDeviceAvailabilityReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func hostDeviceAvailabilityReportParsesDevicectlHostnameTableShapeWithoutLeakingIdentifiers() throws {
        let rawIPhoneIdentifier = "75C96B6E-24BD-555F-A9B9-5852131BB23D"
        let rawIPadIdentifier = "BEA80DBE-76AB-5457-BFBB-366706BAF25C"
        let rawWatchIdentifier = "61598C02-89EE-50B5-AAD3-B8A16C623AE9"
        let devicectlText = """
        Name                    Hostname                               Identifier                             State         Model
        ---------------------   ------------------------------------   ------------------------------------   -----------   --------------------------------
        M5                      M5.coredevice.local                    \(rawIPadIdentifier)   unavailable   iPad Pro 13-inch (M5) (iPad17,3)
        Physical iPhone         Physical-iPhone.coredevice.local       \(rawIPhoneIdentifier)   unavailable   iPhone 17 Pro Max (iPhone18,2)
        Rishabh's Apple Watch   Rishabhs-AppleWatch.coredevice.local   \(rawWatchIdentifier)   unavailable   Apple Watch Series 8 (Watch6,14)
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(devicectlText)

        #expect(report.source == .devicectl)
        #expect(report.devices.count == 1)
        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 0)
        #expect(report.unavailablePhysicalIPhoneCount == 1)
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone unavailable or offline"))
        let device = try #require(report.devices.first)
        #expect(device.availability == .unavailable)
        #expect(device.modelLabel == "iPhone18,2")
        #expect(device.id.hasPrefix("device-"))
        #expect(!report.accessibilityValue.contains(rawIPhoneIdentifier))
        #expect(!report.accessibilityValue.contains(rawIPadIdentifier))
        #expect(!report.accessibilityValue.contains(rawWatchIdentifier))
        let serialized = try #require(String(data: try JSONEncoder().encode(report), encoding: .utf8))
        #expect(!serialized.contains(rawIPhoneIdentifier))
        #expect(!serialized.contains(rawIPadIdentifier))
        #expect(!serialized.contains(rawWatchIdentifier))
    }

    @Test func hostDeviceAvailabilityReportAvailableIPhoneStillDoesNotCountProof() {
        let report = BracketerHostDeviceAvailabilityReport.parse(
            """
            Name              Identifier                            State      Model
            Physical iPhone   00008101-001A442C26AA801E             available  iPhone18,2 (iPhone 17 Pro Max) (26.5)
            """
        )

        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 1)
        #expect(report.labReadinessValue.contains("Host report sees an available physical iPhone"))
        #expect(report.labReadinessValue.contains("Still requires signed physical lab artifacts"))
        #expect(report.labReadinessValue.contains("No physical proof count changed"))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))
    }

    @Test func hostDeviceAvailabilityReportParsesXcodebuildDestinationsWithoutLeakingIdentifiers() throws {
        let rawUDID = "00008150-00027C3E0108401C"
        let xcodebuildDestinations = """
        Available destinations for the "Bracketer" scheme:
            { platform:iOS, arch:arm64, id:\(rawUDID), name:Physical iPhone }
            { platform:iOS Simulator, arch:arm64, id:BB433905-C31E-4E1A-8F4D-C9D53FFC9D06, OS:26.5, name:iPhone 17 Pro }
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(xcodebuildDestinations)

        #expect(report.source == .xcodebuild)
        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 1)
        #expect(report.lockedPhysicalIPhoneCount == 0)
        #expect(report.labReadinessValue.contains("Host report sees an available physical iPhone"))
        #expect(report.summaryValue.contains("xcodebuild destinations/preflight"))
        #expect(report.summaryValue.contains("0 locked"))
        #expect(report.summaryValue.contains("Still requires signed physical lab artifacts"))
        let device = try #require(report.devices.first)
        #expect(device.availability == .available)
        #expect(device.id.hasPrefix("device-"))
        #expect(!device.id.contains(rawUDID))
        #expect(!report.accessibilityValue.contains(rawUDID))
        #expect(!report.accessibilityValue.contains("BB433905-C31E-4E1A-8F4D-C9D53FFC9D06"))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let serialized = try #require(String(data: try JSONEncoder().encode(report), encoding: .utf8))
        #expect(!serialized.contains(rawUDID))
    }

    @Test func hostDeviceAvailabilityReportParsesXcodebuildLockedPreflightWithoutCountingProof() throws {
        let rawUDID = "00008150-00027C3E0108401C"
        let preflightLog = """
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(rawUDID)
        Run Destination Preflight: The destination is not ready.
        Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock Physical iPhone to Continue"
        NSLocalizedRecoverySuggestion=Xcode cannot launch BracketerTests on Physical iPhone because the device is locked.
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(preflightLog)

        #expect(report.source == .xcodebuild)
        #expect(report.physicalIPhoneCount == 1)
        #expect(report.availablePhysicalIPhoneCount == 0)
        #expect(report.lockedPhysicalIPhoneCount == 1)
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone is locked"))
        #expect(report.labReadinessValue.contains("Unlock the iPhone before running the physical lab"))
        #expect(report.summaryValue.contains("1 locked"))
        #expect(report.summaryValue.contains("No physical proof count changed"))
        let device = try #require(report.devices.first)
        #expect(device.availability == .locked)
        #expect(device.id.hasPrefix("device-"))
        #expect(!device.id.contains(rawUDID))
        #expect(report.accessibilityValue.contains("Availability: locked"))
        #expect(!report.accessibilityValue.contains(rawUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let data = try JSONEncoder().encode(report)
        let serialized = try #require(String(data: data, encoding: .utf8))
        #expect(!serialized.contains(rawUDID))
        let decoded = try JSONDecoder().decode(BracketerHostDeviceAvailabilityReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func hostDeviceAvailabilityReportDoesNotTreatLockedIPadPreflightAsIPhoneProof() throws {
        let rawIPadUDID = "00008160-000A1B2C3D4E501F"
        let preflightLog = """
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(rawIPadUDID)
        Run Destination Preflight: The destination is not ready.
        Error Domain=com.apple.dt.deviceprep Code=-3 "The device is locked"
        NSLocalizedRecoverySuggestion=Xcode cannot launch BracketerTests on Physical iPad because the device is locked.
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(preflightLog)

        #expect(report.source == .xcodebuild)
        #expect(report.devices.isEmpty)
        #expect(report.physicalIPhoneCount == 0)
        #expect(report.lockedPhysicalIPhoneCount == 0)
        #expect(report.labReadinessValue.contains("Blocked: no physical iPhone found"))
        #expect(report.labReadinessValue.contains("No physical proof count changed"))
        #expect(!report.accessibilityValue.contains(rawIPadUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))
    }

    @Test func hostDeviceAvailabilityReportLockedXcodebuildPreflightTakesReadinessPriorityOverAvailableRows() throws {
        let lockedUDID = "00008150-00027C3E0108401C"
        let availableUDID = "00008151-00027C3E0108402D"
        let mixedLog = """
        Available destinations for the "Bracketer" scheme:
            { platform:iOS, arch:arm64, id:\(availableUDID), name:Physical iPhone }
            { platform:iOS Simulator, arch:arm64, id:BB433905-C31E-4E1A-8F4D-C9D53FFC9D06, OS:26.5, name:iPhone 17 Pro }
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(lockedUDID)
        Run Destination Preflight: The destination is not ready.
        NSLocalizedRecoverySuggestion=Xcode cannot launch BracketerTests on Physical iPhone because the device is locked.
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(mixedLog)

        #expect(report.source == .xcodebuild)
        #expect(report.physicalIPhoneCount == 2)
        #expect(report.availablePhysicalIPhoneCount == 1)
        #expect(report.lockedPhysicalIPhoneCount == 1)
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone is locked"))
        #expect(report.summaryValue.contains("1 available"))
        #expect(report.summaryValue.contains("1 locked"))
        #expect(!report.accessibilityValue.contains(lockedUDID))
        #expect(!report.accessibilityValue.contains(availableUDID))
        #expect(!report.accessibilityValue.contains("BB433905-C31E-4E1A-8F4D-C9D53FFC9D06"))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let data = try JSONEncoder().encode(report)
        let serialized = try #require(String(data: data, encoding: .utf8))
        #expect(!serialized.contains(lockedUDID))
        #expect(!serialized.contains(availableUDID))
        let decoded = try JSONDecoder().decode(BracketerHostDeviceAvailabilityReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func hostDeviceAvailabilityReportEnumeratesMultipleLockedXcodebuildIPhoneDestinations() throws {
        let firstLockedUDID = "00008150-00027C3E0108401C"
        let secondLockedUDID = "00008151-00027C3E0108402D"
        let preflightLog = """
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(firstLockedUDID)
        Run Destination Preflight: The destination is not ready.
        Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock Physical iPhone to Continue"
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(secondLockedUDID)
        Run Destination Preflight: The destination is not ready.
        NSLocalizedRecoverySuggestion=Xcode cannot launch BracketerTests on Physical iPhone because the device is locked.
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(preflightLog)

        #expect(report.source == .xcodebuild)
        #expect(report.physicalIPhoneCount == 2)
        #expect(report.availablePhysicalIPhoneCount == 0)
        #expect(report.lockedPhysicalIPhoneCount == 2)
        #expect(Set(report.devices.map(\.id)).count == 2)
        #expect(report.summaryValue.contains("2 physical iPhone row(s)"))
        #expect(report.summaryValue.contains("2 locked"))
        #expect(report.labReadinessValue.contains("Blocked: physical iPhone is locked"))
        #expect(!report.accessibilityValue.contains(firstLockedUDID))
        #expect(!report.accessibilityValue.contains(secondLockedUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))

        let data = try JSONEncoder().encode(report)
        let serialized = try #require(String(data: data, encoding: .utf8))
        #expect(!serialized.contains(firstLockedUDID))
        #expect(!serialized.contains(secondLockedUDID))
        let decoded = try JSONDecoder().decode(BracketerHostDeviceAvailabilityReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func hostDeviceAvailabilityReportDoesNotCountIPadLineWithUnlockIPhonePhrase() {
        let rawIPadUDID = "00008160-000A1B2C3D4E501F"
        let preflightLog = """
        xcodebuild -quiet test -project Bracketer.xcodeproj -destination platform=iOS,id=\(rawIPadUDID)
        Run Destination Preflight: The destination is not ready.
        Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock Physical iPhone to Continue for Physical iPad"
        """

        let report = BracketerHostDeviceAvailabilityReport.parse(preflightLog)

        #expect(report.source == .xcodebuild)
        #expect(report.devices.isEmpty)
        #expect(report.physicalIPhoneCount == 0)
        #expect(report.lockedPhysicalIPhoneCount == 0)
        #expect(report.labReadinessValue.contains("Blocked: no physical iPhone found"))
        #expect(!report.accessibilityValue.contains(rawIPadUDID))
        #expect(!report.accessibilityValue.contains("Physical proof captured"))
    }

    @Test func verificationRunbookDefinesResultBundlesAndBenchmarkCommandsWithoutPhysicalClaims() throws {
        let runbook = BracketerVerificationRunbook.make(
            simulatorUDID: "SIM-123",
            physicalDeviceUDID: "IPHONE-123",
            developmentTeam: "TEAM123",
            resultBundleRoot: "build/verification"
        )

        #expect(runbook.schemaVersion == 1)
        #expect(runbook.resultBundleRoot == "build/verification")
        #expect(runbook.simulatorUDIDPlaceholder == "SIM-123")
        #expect(runbook.physicalDeviceUDIDPlaceholder == "IPHONE-123")
        #expect(runbook.commandCount == 7)
        #expect(runbook.commandIDs == [
            "resolveSimulatorDestination",
            "fullSimulatorGate",
            "unitBundleGate",
            "simulatedCaptureReviewUIGate",
            "extractResultBundleSummary",
            "extractBenchmarkMetrics",
            "physicalDeviceLabGate",
        ])
        #expect(runbook.benchmarkCommandCount == 2)
        #expect(runbook.resultBundles.map(\.path) == [
            "build/verification/Bracketer-simulator-full.xcresult",
            "build/verification/Bracketer-unit.xcresult",
            "build/verification/Bracketer-simulated-capture-ui.xcresult",
            "build/verification/Bracketer-physical-device-lab.xcresult",
        ])
        #expect(runbook.commands.allSatisfy {
            $0.invocation.contains("DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer")
        })
        #expect(runbook.summaryValue.contains("Verification Runbook"))
        #expect(runbook.summaryValue.contains("7 commands"))
        #expect(runbook.summaryValue.contains("platform=iOS,id=IPHONE-123"))
        #expect(runbook.resultBundleDocumentationValue.contains("Result Bundle Documentation"))
        #expect(runbook.resultBundleDocumentationValue.contains("Bracketer-simulator-full.xcresult"))
        #expect(runbook.resultBundleDocumentationValue.contains("xcresulttool get test-results summary"))
        #expect(runbook.benchmarkSummaryValue.contains("Benchmark Commands"))
        #expect(runbook.benchmarkAccessibilityValue.contains("xcresulttool get test-results metrics"))
        #expect(runbook.benchmarkAccessibilityValue.contains("Duration (AppLaunch)"))
        #expect(runbook.benchmarkAccessibilityValue.contains("Dropped frame diagnostics"))
        #expect(runbook.privacyBoundary.contains("stores command text"))
        #expect(runbook.physicalProofBoundary.contains("do not prove physical iPhone capture"))
        #expect(runbook.physicalProofBoundary.contains("real camera, Photos, Files, Shortcuts, Spotlight, and Foundation Models evidence"))
        #expect(runbook.accessibilityValue.contains("Settings Device Proof probes"))
        #expect(!runbook.accessibilityValue.localizedCaseInsensitiveContains("physical proof captured"))

        let fullSimulatorGate = try #require(
            runbook.commands.first { $0.id == "fullSimulatorGate" }
        )
        #expect(fullSimulatorGate.invocation.contains("-destination 'platform=iOS Simulator,id=SIM-123'"))
        #expect(fullSimulatorGate.invocation.contains("-resultBundlePath build/verification/Bracketer-simulator-full.xcresult"))
        #expect(fullSimulatorGate.invocation.contains("CODE_SIGNING_ALLOWED=NO"))
        #expect(fullSimulatorGate.expectedResultBundle == "build/verification/Bracketer-simulator-full.xcresult")

        let simulatedCaptureGate = try #require(
            runbook.commands.first { $0.id == "simulatedCaptureReviewUIGate" }
        )
        #expect(simulatedCaptureGate.invocation.contains("-only-testing:BracketerUITests/BracketerUITests/testSimulatedBracketCaptureCompletesAndOpensReview"))
        #expect(simulatedCaptureGate.proofBoundary.contains("no real camera"))

        let physicalGate = try #require(
            runbook.commands.first { $0.id == "physicalDeviceLabGate" }
        )
        #expect(physicalGate.invocation.contains("-destination 'platform=iOS,id=IPHONE-123'"))
        #expect(physicalGate.invocation.contains("DEVELOPMENT_TEAM=TEAM123"))
        #expect(!physicalGate.invocation.contains("CODE_SIGNING_ALLOWED=NO"))
        #expect(physicalGate.proofBoundary.contains("manual camera"))

        let physicalBundle = try #require(
            runbook.resultBundles.first { $0.id == "physicalDeviceLab" }
        )
        #expect(physicalBundle.requiredContents.contains("real iPhone model and iOS build"))
        #expect(physicalBundle.requiredContents.contains("manual attachments for physical capture matrix scenarios before any proof count can increase"))
        #expect(physicalBundle.proofBoundary.contains("not proof until a connected iPhone run"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(runbook)
        let decoded = try JSONDecoder().decode(BracketerVerificationRunbook.self, from: data)
        #expect(decoded == runbook)
    }

    @Test func physicalCaptureRunbooksCoverEveryMatrixScenarioWithoutDefaultProofs() throws {
        let matrix = BracketerPhysicalCaptureMatrix.make()
        let productionCatalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbooks = BracketerPhysicalCaptureRunbook.defaultRunbooks(resultBundleRoot: "build/lab")
        let catalog = BracketerPhysicalCaptureRunbookCatalog(runbooks: runbooks)
        let index = BracketerPhysicalResultBundleIndex.make(runbooks: runbooks)

        #expect(productionCatalog.schemaVersion == BracketerPhysicalCaptureRunbookCatalog.schemaVersion)
        #expect(productionCatalog.runbooks.count == matrix.scenarioCount)
        #expect(productionCatalog.runbooks.allSatisfy { $0.resultBundlePath.hasPrefix("build/physical-lab/Bracketer-") })
        #expect(catalog.schemaVersion == BracketerPhysicalCaptureRunbookCatalog.schemaVersion)
        #expect(index.schemaVersion == BracketerPhysicalResultBundleIndex.schemaVersion)
        #expect(runbooks.count == matrix.scenarioCount)
        #expect(Set(runbooks.map(\.id)) == Set(matrix.scenarios.map(\.id)))
        #expect(runbooks.allSatisfy { $0.schemaVersion == BracketerPhysicalCaptureRunbook.schemaVersion })
        #expect(runbooks.allSatisfy { !$0.physicalProofCaptured })
        #expect(runbooks.allSatisfy { $0.recordedProofs.isEmpty })
        #expect(runbooks.allSatisfy { $0.resultBundlePath.hasPrefix("build/lab/Bracketer-") })
        #expect(index.expectedScenarioIDs == runbooks.map(\.id))
        #expect(catalog.summaryValue.contains("Physical Capture Runbooks"))
        #expect(catalog.summaryValue.contains("0 of 8 runbooks captured"))
        #expect(catalog.accessibilityValue.contains("Interior Window Dynamic Range"))
        #expect(catalog.accessibilityValue.contains("Reserve result bundle path"))
        #expect(catalog.accessibilityValue.contains("Extract xcresult summary and benchmark metrics"))
        #expect(catalog.accessibilityValue.contains("stores no Photos identifiers"))
        #expect(index.summaryValue == "0 of 8 scenario result bundles indexed")
        #expect(index.accessibilityValue.contains("Physical Result Bundle Index"))
        #expect(index.accessibilityValue.contains("does not store raw image bytes"))

        let checklistProofIDs: Set<String> = [
            "liveFoundationModelsOutput",
            "photosResourceFetch",
            "photosBackedThumbnails",
            "finalRenderedOutputBytes",
            "photosSideBySidePixels",
            "imageBundleByteExport",
            "lensExifProRAW",
            "locationPermissionPolicy",
            "filesShortcutsRoundTrip",
            "spotlightHandoffContinuation",
        ]
        for runbook in runbooks {
            #expect(!runbook.linkedProofIDs.isEmpty)
            #expect(Set(runbook.linkedProofIDs).isSubset(of: checklistProofIDs))
            #expect(!runbook.expectedArtifacts.isEmpty)
        }

        let defaultAppliedMatrix = BracketerPhysicalCaptureMatrix.applying(runbooks: runbooks)
        #expect(defaultAppliedMatrix.provenScenarioCount == 0)
        #expect(defaultAppliedMatrix.summaryValue.contains("0 of 8 scenario proofs captured"))
        #expect(!defaultAppliedMatrix.accessibilityValue.contains("Physical proof captured"))

        let encoder = JSONEncoder()
        #expect(try JSONDecoder().decode(BracketerPhysicalCaptureRunbookCatalog.self, from: encoder.encode(catalog)) == catalog)
        #expect(try JSONDecoder().decode(BracketerPhysicalResultBundleIndex.self, from: encoder.encode(index)) == index)
    }

    @Test func physicalCaptureRunbookRecordedProofFlipsMatrixAndIndexesBundleWithoutRawFields() throws {
        let proof = BracketerPhysicalCaptureRunbook.RecordedProof(
            deviceModel: "iPhone 17 Pro",
            iosBuild: "26.4.1",
            capturedAt: Date(timeIntervalSince1970: 30),
            resultBundleFilename: "Bracketer-dynamicRangeInteriorWindow-physical.xcresult",
            resultBundleSHA256: String(repeating: "a", count: 64),
            resultBundleSummarySHA256: String(repeating: "d", count: 64),
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 164,
                passedTests: 164,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTestContract: BracketerPhysicalResultBundleTestContract(
                xcodebuildVersion: "Xcode 26.5 Build version 17F42",
                xcresulttoolVersion: "xcresulttool version 24757, schema version: 0.1.0",
                testPlanConfigurationName: "Test Scheme Action",
                testIdentifier: "BracketerPhysicalCaptureTests/testdynamicRangeInteriorWindowPhysicalCapture",
                testName: "testdynamicRangeInteriorWindowPhysicalCapture"
            ),
            resultBundleTiming: BracketerPhysicalResultBundleTiming.window(
                around: Date(timeIntervalSince1970: 30)
            ),
            attachmentManifest: BracketerPhysicalAttachmentManifest(
                resultBundleFilename: "Bracketer-dynamicRangeInteriorWindow-physical.xcresult",
                resultBundleTestIdentifier: "BracketerPhysicalCaptureTests/testdynamicRangeInteriorWindowPhysicalCapture",
                testStartTime: BracketerPhysicalResultBundleTiming.window(
                    around: Date(timeIntervalSince1970: 30)
                ).testStartTime,
                testFinishTime: BracketerPhysicalResultBundleTiming.window(
                    around: Date(timeIntervalSince1970: 30)
                ).testFinishTime,
                artifactSHA256ByID: [
                    "project-json": String(repeating: "1", count: 64),
                    "histogram-diagnostics": String(repeating: "2", count: 64)
                ],
                artifactByteCountByID: [
                    "project-json": 2048,
                    "histogram-diagnostics": 2048
                ]
            ),
            manifestSHA256: "abc123",
            notes: "Window scene captured with Photos and Files evidence attached."
        )
        var runbooks = BracketerPhysicalCaptureRunbook.defaultRunbooks()
        let first = try #require(runbooks.first)
        runbooks[0] = first.withRecordedProof(proof)

        #expect(proof.accessibilityValue.contains("Device: iPhone 17 Pro"))
        #expect(proof.accessibilityValue.contains("iOS build: 26.4.1"))
        #expect(proof.accessibilityValue.contains("Result bundle: Bracketer-dynamicRangeInteriorWindow-physical.xcresult"))
        #expect(proof.accessibilityValue.contains("Result bundle SHA-256"))
        #expect(proof.accessibilityValue.contains("Result bundle summary SHA-256"))
        #expect(proof.accessibilityValue.contains("Result bundle metrics"))
        #expect(proof.accessibilityValue.contains("Result bundle test contract"))
        #expect(proof.accessibilityValue.contains("Result bundle timing"))
        #expect(proof.accessibilityValue.contains("Attachment manifest hashes"))
        #expect(proof.accessibilityValue.contains("Manifest SHA-256: abc123"))
        #expect(proof.accessibilityValue.contains("Window scene captured"))
        #expect(!proof.accessibilityValue.contains("Photos identifier"))
        #expect(!proof.accessibilityValue.contains("image bytes"))

        let updatedMatrix = BracketerPhysicalCaptureMatrix.applying(runbooks: runbooks)
        #expect(updatedMatrix.provenScenarioCount == 1)
        #expect(updatedMatrix.summaryValue.contains("1 of 8 scenario proofs captured"))
        #expect(updatedMatrix.scenarios.first?.status == .physicalProofCaptured)

        let encodedProof = try JSONEncoder().encode(proof)
        let object = try #require(JSONSerialization.jsonObject(with: encodedProof) as? [String: Any])
        #expect(Set(object.keys) == [
            "deviceModel",
            "iosBuild",
            "capturedAt",
            "resultBundleFilename",
            "resultBundleSHA256",
            "resultBundleSummarySHA256",
            "resultBundleMetrics",
            "resultBundleTestContract",
            "resultBundleTiming",
            "attachmentManifest",
            "manifestSHA256",
            "notes",
        ])
        #expect(!object.keys.contains("assetIdentifier"))
        #expect(!object.keys.contains("imageBytes"))
        #expect(!object.keys.contains("coordinates"))

        let indexEntry = BracketerPhysicalResultBundleIndex.Entry(
            scenarioID: first.id,
            runbookID: first.id,
            resultBundleFilename: proof.resultBundleFilename,
            recordedAt: proof.capturedAt,
            deviceModel: proof.deviceModel,
            iosBuild: proof.iosBuild
        )
        let index = BracketerPhysicalResultBundleIndex.make(runbooks: runbooks).adding(indexEntry)
        #expect(index.indexedCount == 1)
        #expect(index.indexedScenarioIDs == [first.id])
        #expect(index.summaryValue == "1 of 8 scenario result bundles indexed")
        #expect(index.accessibilityValue.contains("Bracketer-dynamicRangeInteriorWindow-physical.xcresult"))

        let duplicateScenarioEntry = BracketerPhysicalResultBundleIndex.Entry(
            scenarioID: first.id,
            runbookID: first.id,
            resultBundleFilename: "Bracketer-dynamicRangeInteriorWindow-physical-rerun.xcresult",
            recordedAt: Date(timeIntervalSince1970: 31),
            deviceModel: "iPhone 17 Pro",
            iosBuild: "26.4.1"
        )
        let duplicateIndexed = index.adding(duplicateScenarioEntry)
        #expect(duplicateIndexed.entries.count == 2)
        #expect(duplicateIndexed.indexedCount == 1)
        #expect(duplicateIndexed.indexedScenarioIDs == [first.id])
        #expect(duplicateIndexed.summaryValue == "1 of 8 scenario result bundles indexed")
        #expect(duplicateIndexed.accessibilityValue.contains("Bracketer-dynamicRangeInteriorWindow-physical-rerun.xcresult"))
    }

    @Test func physicalProofIngestorValidatesSubmissionAndFlipsOneScenario() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let submission = try validPhysicalProofSubmission(for: runbook).signed()

        let result = try BracketerPhysicalProofIngestor.ingest(submission, catalog: catalog)

        #expect(result.proofCategory == "physical-device-proof")
        #expect(result.catalog.capturedRunbookCount == 1)
        #expect(result.resultBundleIndex.indexedCount == 1)
        #expect(result.resultBundleIndex.indexedScenarioIDs == [runbook.id])
        #expect(result.recordedProof.deviceModel == "iPhone17,1")
        #expect(result.recordedProof.resultBundleSHA256 == String(repeating: "a", count: 64))
        #expect(result.recordedProof.resultBundleSummarySHA256 == String(repeating: "d", count: 64))
        #expect(result.recordedProof.resultBundleSummary?.status == .passed)
        #expect(result.recordedProof.resultBundleSummary?.title == "Test - Bracketer")
        #expect(result.recordedProof.resultBundleMetrics?.totalTestCount == 164)
        #expect(result.recordedProof.resultBundleTestContract?.testIdentifier.contains(runbook.id) == true)
        #expect(result.recordedProof.resultBundleTiming?.testStartTime == submission.capturedAt.addingTimeInterval(-30))
        #expect(result.recordedProof.resultBundleDevice == physicalProofResultBundleDevice())
        #expect(result.recordedProof.attachmentManifest?.artifactSHA256ByID.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(result.recordedProof.attachmentManifest?.totalArtifactByteCount == result.recordedProof.resultBundleMetrics?.attachmentByteCount)
        #expect(result.recordedProof.manifestSHA256 == String(repeating: "b", count: 64))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle SHA-256"))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle summary SHA-256"))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle metrics"))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle test contract"))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle timing"))
        #expect(result.recordedProof.accessibilityValue.contains("Result bundle device"))
        #expect(result.recordedProof.accessibilityValue.contains("Attachment manifest hashes"))
        #expect(result.recordedProof.accessibilityValue.contains("Lens: wide-camera"))
        #expect(result.summaryValue.contains("1 of 8 runbooks captured"))

        let updatedMatrix = BracketerPhysicalCaptureMatrix.applying(runbooks: result.catalog.runbooks)
        #expect(updatedMatrix.provenScenarioCount == 1)
        #expect(updatedMatrix.scenarios.first?.status == .physicalProofCaptured)

        let encodedProof = try JSONEncoder().encode(result.recordedProof)
        let object = try #require(JSONSerialization.jsonObject(with: encodedProof) as? [String: Any])
        #expect(object.keys.contains("resultBundleSHA256"))
        #expect(object.keys.contains("resultBundleDevice"))
        #expect(!object.keys.contains("hashedDeviceIdentifier"))
        #expect(!object.keys.contains("photosLocalIdentifier"))
        #expect(!object.keys.contains("imageBytes"))
        #expect(!object.keys.contains("coordinates"))
    }

    @Test func physicalProofIngestorRejectsUnsignedAndTamperedSubmissions() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let unsignedSubmission = validPhysicalProofSubmission(for: runbook)

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(unsignedSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let signedSubmission = try unsignedSubmission.signed()
        let tamperedSubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: String(repeating: "d", count: 64),
            resultBundleSummarySHA256: signedSubmission.resultBundleSummarySHA256,
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: signedSubmission.resultBundleMetrics,
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let accepted = try BracketerPhysicalProofIngestor.ingest(signedSubmission, catalog: catalog)
        #expect(accepted.catalog.capturedRunbookCount == 1)
    }

    @Test func physicalProofIngestorRejectsSimulatorMissingArtifactsAndPrivateMarkers() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    xcodeDestination: "platform=iOS Simulator,id=SIM-123"
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .simulatorDestination("platform=iOS Simulator,id=SIM-123"))
        }

        let missingArtifact = try #require(runbook.expectedArtifacts.last)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    providedArtifactIDs: Array(runbook.expectedArtifacts.dropLast())
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingExpectedArtifacts([missingArtifact]))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    reviewerEvidence: ["PHAsset.localIdentifier=secret-local-id"]
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .privacyBoundaryViolation("phasset.localidentifier"))
        }
    }

    @Test func physicalProofIngestorRejectsMissingDeviceLabelsAndInvalidDigests() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, deviceModelIdentifier: " ").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingDeviceModelIdentifier)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, hashedDeviceIdentifier: "").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingHashedDeviceIdentifier)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, iosBuild: " ").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingIOSBuild)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, hashedDeviceIdentifier: "not-a-hash").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidSHA256(field: "hashedDeviceIdentifier"))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, resultBundleSHA256: "not-a-digest").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidSHA256(field: "resultBundleSHA256"))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, manifestSnapshotSHA256: nil).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingManifestSnapshotSHA256)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, manifestSnapshotSHA256: "not-a-digest").signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidSHA256(field: "manifestSnapshotSHA256"))
        }
    }

    @Test func physicalProofIngestorRejectsNonIPhoneDeviceModelIdentifiers() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let invalidIdentifiers = [
            "Simulator",
            "Mac14,7",
            "iPad13,1",
            "iphone17,1",
            "IPHONE17,1",
            "iPhone",
            "iPhone17",
            "iPhone17,",
            "iPhone17,1,5",
            "iPhone17,1-extra",
            " iPhone17,1 "
        ]

        for identifier in invalidIdentifiers {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        deviceModelIdentifier: identifier
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .deviceModelIdentifierNotIPhone(identifier))
            }
        }

        let previewSubmission = try validPhysicalProofSubmission(
            for: runbook,
            deviceModelIdentifier: "iPad13,1"
        ).signed()
        let preview = BracketerPhysicalProofIngestor.preview(previewSubmission, catalog: catalog)

        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof device model identifier must be an iPhone hardware identifier like iPhone17,1: iPad13,1."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorAcceptsCanonicalIPhoneModelIdentifiers() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let firstRunbook = try #require(catalog.runbooks.first)
        let secondRunbook = try #require(catalog.runbooks.dropFirst().first)

        let firstResult = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: firstRunbook,
                deviceModelIdentifier: "iPhone17,1"
            ).signed(),
            catalog: catalog
        )
        let secondResult = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: secondRunbook,
                deviceModelIdentifier: "iPhone16,2"
            ).signed(),
            catalog: firstResult.catalog,
            resultBundleIndex: firstResult.resultBundleIndex
        )

        #expect(firstResult.recordedProof.deviceModel == "iPhone17,1")
        #expect(secondResult.recordedProof.deviceModel == "iPhone16,2")
        #expect(secondResult.resultBundleIndex.entries.map(\.deviceModel).sorted() == ["iPhone16,2", "iPhone17,1"])
        #expect(secondResult.catalog.capturedRunbookCount == 2)
        #expect(secondResult.resultBundleIndex.indexedCount == 2)
    }

    @Test func physicalProofIngestorRejectsInvalidIOSBuildLabels() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let invalidLabels = [
            "latest",
            "iOS 26",
            "26",
            "26.4.1 beta",
            " 26.4.1 ",
            "26.4.",
            "26.4.1.2",
            "23e254a",
            "23E254!",
            "23E254A",
            "23EA",
            "A23E254",
            "1A23"
        ]

        for label in invalidLabels {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        iosBuild: label
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidIOSBuildLabel(label))
            }
        }

        let previewSubmission = try validPhysicalProofSubmission(
            for: runbook,
            iosBuild: "latest"
        ).signed()
        let preview = BracketerPhysicalProofIngestor.preview(previewSubmission, catalog: catalog)

        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof iOS build label must be a dotted iOS version or Apple build number: latest."))
    }

    @Test func physicalProofIngestorAcceptsDottedAndAppleIOSBuildLabels() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let labels = ["26.4", "26.4.1", "23A1", "23E254", "23E254a"]
        let runbooks = Array(catalog.runbooks.prefix(labels.count))
        #expect(runbooks.count == labels.count)

        var workingCatalog = catalog
        var workingIndex: BracketerPhysicalResultBundleIndex?
        var recordedLabels: [String] = []

        for (runbook, label) in zip(runbooks, labels) {
            let resultBundleDevice = label.contains(".")
                ? physicalProofResultBundleDevice(osVersion: label, osBuildNumber: nil)
                : physicalProofResultBundleDevice(osVersion: nil, osBuildNumber: label)
            let result = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleDevice: resultBundleDevice,
                    iosBuild: label
                ).signed(),
                catalog: workingCatalog,
                resultBundleIndex: workingIndex
            )
            recordedLabels.append(result.recordedProof.iosBuild)
            workingCatalog = result.catalog
            workingIndex = result.resultBundleIndex
        }

        #expect(recordedLabels == labels)
        #expect(workingIndex?.entries.map(\.iosBuild).sorted() == labels.sorted())
        #expect(workingCatalog.capturedRunbookCount == labels.count)
    }

    @Test func physicalProofIngestorRejectsGenericReviewerEvidence() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let genericEvidence = [
            "Attached real camera screenshot",
            "xcresult summary shows physical destination"
        ]

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    reviewerEvidence: genericEvidence
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingScenarioDescriptors(runbook.evidenceSteps))
        }

        let previewSubmission = try validPhysicalProofSubmission(
            for: runbook,
            reviewerEvidence: genericEvidence
        ).signed()
        let preview = BracketerPhysicalProofIngestor.preview(previewSubmission, catalog: catalog)

        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must include scenario runbook descriptors: \(runbook.evidenceSteps.joined(separator: ", "))."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorAcceptsCaseAndWhitespaceVariedReviewerEvidence() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_120)
        let resultBundleFilename = "Bracketer-\(runbook.id)-physical.xcresult"
        let resultBundleSHA256 = String(repeating: "a", count: 64)
        let resultBundleSummarySHA256 = String(repeating: "d", count: 64)
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let resultBundleMetrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        )
        let resultBundleTestContract = physicalProofResultBundleTestContract(for: runbook)
        let resultBundleTiming = physicalProofResultBundleTiming(around: capturedAt)
        let resultBundleDevice = physicalProofResultBundleDevice()
        let attachmentManifest = physicalProofAttachmentManifest(
            for: runbook,
            resultBundleFilename: resultBundleFilename,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: resultBundleTiming
        )
        let hashedDeviceIdentifier = String(repeating: "c", count: 64)
        let deviceModelIdentifier = "iPhone17,1"
        let iosBuild = "26.4.1"
        let variedEvidence = ["CAPTURED AT: \(physicalProofTimestamp(capturedAt).lowercased())"]
            + ["Result bundle: \(resultBundleFilename.uppercased())"]
            + ["Result bundle SHA-256: \(resultBundleSHA256.uppercased())"]
            + ["Result bundle summary SHA-256: \(resultBundleSummarySHA256.uppercased())"]
            + ["RESULT BUNDLE SUMMARY: \(resultBundleSummary.summaryValue.uppercased())"]
            + ["RESULT BUNDLE METRICS: metrics.totalTestCount = \(resultBundleMetrics.totalTestCount), metrics.passedTests = \(resultBundleMetrics.passedTests), metrics.failedTests = \(resultBundleMetrics.failedTests), metrics.durationMilliseconds = \(resultBundleMetrics.durationMilliseconds), metrics.attachmentByteCount = \(resultBundleMetrics.attachmentByteCount)"]
            + ["RESULT BUNDLE TEST CONTRACT: test.xcodebuildVersion = \(resultBundleTestContract.xcodebuildVersion.uppercased()), test.xcresulttoolVersion = \(resultBundleTestContract.xcresulttoolVersion.uppercased()), test.plan = \(resultBundleTestContract.testPlanConfigurationName.uppercased()), test.identifier = \(resultBundleTestContract.testIdentifier.uppercased()), test.name = \(resultBundleTestContract.testName.uppercased())"]
            + ["RESULT BUNDLE TIMING: \(resultBundleTiming.summaryValue.uppercased())"]
            + ["RESULT BUNDLE DEVICE: \(resultBundleDevice.summaryValue.uppercased())"]
            + ["ATTACHMENT MANIFEST HASHES: \(attachmentManifest.summaryValue.uppercased())"]
            + ["Hashed device identifier: \(hashedDeviceIdentifier.uppercased())"]
            + ["Device model: \(deviceModelIdentifier.uppercased())"]
            + ["iOS build: \(iosBuild.uppercased())"]
            + runbook.evidenceSteps.map { evidenceStep in
                "  \(evidenceStep.uppercased().components(separatedBy: " ").joined(separator: " \n "))  "
            }

        let result = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: resultBundleFilename,
                resultBundleSHA256: resultBundleSHA256,
                resultBundleSummarySHA256: resultBundleSummarySHA256,
                resultBundleSummary: resultBundleSummary,
                resultBundleMetrics: resultBundleMetrics,
                resultBundleTestContract: resultBundleTestContract,
                resultBundleTiming: resultBundleTiming,
                resultBundleDevice: resultBundleDevice,
                attachmentManifest: attachmentManifest,
                deviceModelIdentifier: deviceModelIdentifier,
                hashedDeviceIdentifier: hashedDeviceIdentifier,
                iosBuild: iosBuild,
                reviewerEvidence: variedEvidence,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )

        #expect(result.catalog.capturedRunbookCount == 1)
        #expect(result.resultBundleIndex.indexedCount == 1)
        #expect(result.recordedProof.notes?.contains("Evidence:") == true)
    }

    @Test func physicalProofIngestorRejectsStaleFutureAndTimestampUnboundEvidence() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let staleDate = Date(timeIntervalSince1970: 40)

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, capturedAt: staleDate).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .capturedAtBeforePhysicalLabWindow(staleDate))
        }

        let futureDate = Date().addingTimeInterval(3_600)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(for: runbook, capturedAt: futureDate).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .capturedAtInFuture(futureDate))
        }

        let freshDate = Date(timeIntervalSince1970: 1_779_960_180)
        let unboundEvidence = runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    reviewerEvidence: unboundEvidence,
                    capturedAt: freshDate
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingCapturedAtTimestamp(physicalProofTimestamp(freshDate)))
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                reviewerEvidence: unboundEvidence,
                capturedAt: freshDate
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo capturedAt timestamp \(physicalProofTimestamp(freshDate))."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorRejectsReviewerEvidenceWithoutResultBundleBinding() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_420)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let digest = String(repeating: "a", count: 64)
        let scenarioAndTimeEvidence = ["Captured at: \(physicalProofTimestamp(capturedAt))"]
            + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    reviewerEvidence: scenarioAndTimeEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleFilename(filename))
        }

        let filenameOnlyEvidence = scenarioAndTimeEvidence + ["Result bundle: \(filename)"]
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    reviewerEvidence: filenameOnlyEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleSHA256(digest))
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: digest,
                reviewerEvidence: filenameOnlyEvidence,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle SHA-256 \(digest)."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)

        let rerunFilename = "Bracketer-\(runbook.id)-physical-rerun-02.xcresult"
        let baseFilenameEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: digest
        )
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: rerunFilename,
                    resultBundleSHA256: digest,
                    reviewerEvidence: baseFilenameEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleFilename(rerunFilename))
        }
    }

    @Test func physicalProofIngestorRejectsReviewerEvidenceWithoutDeviceIdentityBinding() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_540)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let digest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let hashedDeviceIdentifier = String(repeating: "e", count: 64)
        let deviceModelIdentifier = "iPhone17,2"
        let iosBuild = "23E254a"
        let evidenceWithoutDeviceIdentity = [
            "Captured at: \(physicalProofTimestamp(capturedAt))",
            "Result bundle: \(filename)",
            "Result bundle SHA-256: \(digest)",
            "Result bundle summary SHA-256: \(summaryDigest)",
            "Result bundle summary: \(resultBundleSummary.summaryValue)"
        ] + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: resultBundleSummary,
                    deviceModelIdentifier: deviceModelIdentifier,
                    hashedDeviceIdentifier: hashedDeviceIdentifier,
                    iosBuild: iosBuild,
                    reviewerEvidence: evidenceWithoutDeviceIdentity,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingHashedDeviceIdentifier(hashedDeviceIdentifier))
        }

        let evidenceWithoutDeviceModel = evidenceWithoutDeviceIdentity + ["Hashed device identifier: \(hashedDeviceIdentifier.uppercased())"]
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: resultBundleSummary,
                    deviceModelIdentifier: deviceModelIdentifier,
                    hashedDeviceIdentifier: hashedDeviceIdentifier,
                    iosBuild: iosBuild,
                    reviewerEvidence: evidenceWithoutDeviceModel,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingDeviceModelIdentifier(deviceModelIdentifier))
        }

        let evidenceWithoutIOSBuild = evidenceWithoutDeviceModel + ["Device model: \(deviceModelIdentifier)"]
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: resultBundleSummary,
                    deviceModelIdentifier: deviceModelIdentifier,
                    hashedDeviceIdentifier: hashedDeviceIdentifier,
                    iosBuild: iosBuild,
                    reviewerEvidence: evidenceWithoutIOSBuild,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingIOSBuild(iosBuild))
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: digest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleSummary: resultBundleSummary,
                deviceModelIdentifier: deviceModelIdentifier,
                hashedDeviceIdentifier: hashedDeviceIdentifier,
                iosBuild: iosBuild,
                reviewerEvidence: evidenceWithoutIOSBuild,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo iOS build label \(iosBuild)."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalResultBundleProofInputParsesXCResultToolCompactSummaryJSON() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_690)
        let resultBundleFilename = "Bracketer-\(runbook.id)-physical.xcresult"
        let resultBundleSHA256 = String(repeating: "a", count: 64)
        let resultBundleSummarySHA256 = String(repeating: "d", count: 64)
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "architecture" : "arm64",
                "deviceId" : "3D6A76E2-86BE-4F15-A384-A920B56478EB",
                "deviceName" : "BracketerUITest-230901",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "expectedFailures" : 0,
              "failedTests" : 0,
              "passedTests" : 336,
              "skippedTests" : 0,
              "testPlanConfiguration" : {
                "configurationId" : "1",
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer · Built with macOS 26.5",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "testFailures" : [],
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let proofInput = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
            try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )

        #expect(proofInput.resultBundleSummary.status == .passed)
        #expect(proofInput.resultBundleSummary.title == "Test - Bracketer")
        #expect(proofInput.resultBundleSummary.totalTestCount == 168)
        #expect(proofInput.resultBundleSummary.passedTestCount == 168)
        #expect(proofInput.resultBundleSummary.failedTestCount == 0)
        #expect(proofInput.resultBundleMetrics.totalTestCount == 168)
        #expect(proofInput.resultBundleMetrics.passedTests == 168)
        #expect(proofInput.resultBundleMetrics.failedTests == 0)
        #expect(proofInput.resultBundleMetrics.durationMilliseconds == 60_000)
        #expect(proofInput.resultBundleMetrics.attachmentByteCount == 4096)
        #expect(proofInput.resultBundleTiming.testStartTime == Date(timeIntervalSince1970: 1_779_960_660))
        #expect(proofInput.resultBundleTiming.testFinishTime == Date(timeIntervalSince1970: 1_779_960_720))
        #expect(proofInput.testPlanConfigurationName == "Test Scheme Action")
        #expect(proofInput.deviceSummaryValue.contains("iPhone 17"))
        #expect(proofInput.deviceSummaryValue.contains("xcresult.osVersion=26.4.1"))
        #expect(proofInput.deviceSummaryValue.contains("23E254a"))
        let resultBundleDevice = try #require(proofInput.resultBundleDevice)
        #expect(resultBundleDevice == BracketerPhysicalResultBundleDevice(
            modelName: "iPhone 17",
            osVersion: "26.4.1",
            osBuildNumber: "23E254a",
            platform: "iOS"
        ))
        #expect(proofInput.reviewerEvidenceLines.contains("Result bundle summary: \(proofInput.resultBundleSummary.summaryValue)"))
        #expect(proofInput.reviewerEvidenceLines.contains("Result bundle metrics: \(proofInput.resultBundleMetrics.summaryValue)"))
        #expect(proofInput.reviewerEvidenceLines.contains("Result bundle timing: \(proofInput.resultBundleTiming.summaryValue)"))
        #expect(proofInput.reviewerEvidenceLines.contains("Result bundle device: \(resultBundleDevice.summaryValue)"))

        let seededDocument = try BracketerPhysicalProofSubmissionDocument(
            prefillingTemplateFor: runbook,
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )
        #expect(seededDocument.submission.resultBundleSummary == proofInput.resultBundleSummary)
        #expect(seededDocument.submission.resultBundleMetrics == proofInput.resultBundleMetrics)
        #expect(seededDocument.submission.resultBundleTiming == proofInput.resultBundleTiming)
        #expect(seededDocument.submission.resultBundleDevice == proofInput.resultBundleDevice)
        let seededArtifactByteCounts = try #require(seededDocument.submission.attachmentManifest?.artifactByteCountByID)
        #expect(seededArtifactByteCounts.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(seededArtifactByteCounts.values.allSatisfy { $0 == 0 })
        #expect(seededDocument.documentText.contains("physical-device-proof preview only seeded from parsed result-bundle proof input"))

        let resultBundleTestContract = proofInput.testContract(
            xcodebuildVersion: "Xcode 26.5 Build version 17F42",
            xcresulttoolVersion: "xcresulttool version 24757, schema version: 0.1.0",
            testIdentifier: "BracketerPhysicalCaptureTests/test\(runbook.id)PhysicalCapture",
            testName: "test\(runbook.id)PhysicalCapture"
        )
        let attachmentManifest = physicalProofAttachmentManifest(
            for: runbook,
            resultBundleFilename: resultBundleFilename,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: proofInput.resultBundleTiming,
            totalAttachmentByteCount: proofInput.resultBundleMetrics.attachmentByteCount
        )
        let hashedDeviceIdentifier = String(repeating: "c", count: 64)
        let deviceModelIdentifier = "iPhone17,1"
        let iosBuild = "26.4.1"
        let reviewerEvidence = [
            "Captured at: \(physicalProofTimestamp(capturedAt))",
            "Result bundle: \(resultBundleFilename)",
            "Result bundle SHA-256: \(resultBundleSHA256)",
            "Result bundle summary SHA-256: \(resultBundleSummarySHA256)"
        ] + proofInput.reviewerEvidenceLines + [
            "Result bundle test contract: \(resultBundleTestContract.summaryValue)",
            "Attachment manifest hashes: \(attachmentManifest.summaryValue)",
            "Hashed device identifier: \(hashedDeviceIdentifier)",
            "Device model: \(deviceModelIdentifier)",
            "iOS build: \(iosBuild)"
        ] + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }

        let result = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: resultBundleFilename,
                resultBundleSHA256: resultBundleSHA256,
                resultBundleSummarySHA256: resultBundleSummarySHA256,
                resultBundleSummary: proofInput.resultBundleSummary,
                resultBundleMetrics: proofInput.resultBundleMetrics,
                resultBundleTestContract: resultBundleTestContract,
                resultBundleTiming: proofInput.resultBundleTiming,
                resultBundleDevice: proofInput.resultBundleDevice,
                attachmentManifest: attachmentManifest,
                deviceModelIdentifier: deviceModelIdentifier,
                hashedDeviceIdentifier: hashedDeviceIdentifier,
                iosBuild: iosBuild,
                reviewerEvidence: reviewerEvidence,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )

        #expect(result.recordedProof.resultBundleSummary == proofInput.resultBundleSummary)
        #expect(result.recordedProof.resultBundleMetrics == proofInput.resultBundleMetrics)
        #expect(result.recordedProof.resultBundleTiming == proofInput.resultBundleTiming)
        #expect(result.recordedProof.resultBundleDevice == proofInput.resultBundleDevice)
        #expect(result.recordedProof.resultBundleTestContract == resultBundleTestContract)
        #expect(result.catalog.capturedRunbookCount == 1)
    }

    @Test func physicalResultBundleProofInputRejectsInvalidXCResultSummaryInputs() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "BracketerUITest-230901",
                "modelName" : "iPhone 17"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960660.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960720.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let data = try #require(compactSummaryJSON.data(using: .utf8))

        do {
            _ = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
                data,
                attachmentByteCount: 4096
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleProofInputError {
            #expect(
                error == .invalidXCResultTimeRange(
                    startTime: 1_779_960_720,
                    finishTime: 1_779_960_660
                )
            )
        }

        do {
            _ = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
                data,
                attachmentByteCount: 0
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleProofInputError {
            #expect(error == .invalidAttachmentByteCount(0))
        }

        let missingTestPlanJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "BracketerUITest-230901",
                "modelName" : "iPhone 17"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        do {
            _ = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
                try #require(missingTestPlanJSON.data(using: .utf8)),
                attachmentByteCount: 4096
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleProofInputError {
            #expect(error == .missingTestPlanConfiguration)
        }

        do {
            _ = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
                Data("{".utf8),
                attachmentByteCount: 4096
            )
            #expect(Bool(false))
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test func physicalResultBundleCommandPlanEmitsScenarioBoundDigestAndXCResultToolCommands() throws {
        let runbook = try #require(BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first)
        let plan = try BracketerPhysicalResultBundleCommandPlan.make(for: runbook)
        let expectedBundlePath = "build/physical-lab/Bracketer-\(runbook.id)-physical.xcresult"

        #expect(plan.schemaVersion == BracketerPhysicalResultBundleCommandPlan.schemaVersion)
        #expect(plan.scenarioID == runbook.id)
        #expect(plan.resultBundlePath == expectedBundlePath)
        #expect(plan.resultBundleDigestPath == "\(expectedBundlePath).sha256")
        #expect(plan.compactSummaryJSONPath == "build/physical-lab/Bracketer-\(runbook.id)-physical-summary.json")
        #expect(plan.compactSummaryDigestPath == "build/physical-lab/Bracketer-\(runbook.id)-physical-summary.json.sha256")
        #expect(plan.compactMetricsJSONPath == "build/physical-lab/Bracketer-\(runbook.id)-physical-metrics.json")
        #expect(plan.xcodebuildVersionPath == "build/physical-lab/Bracketer-\(runbook.id)-physical-xcodebuild-version.txt")
        #expect(plan.xcresulttoolVersionPath == "build/physical-lab/Bracketer-\(runbook.id)-physical-xcresulttool-version.txt")
        #expect(plan.commands.map(\.step) == [
            .digestResultBundle,
            .extractCompactSummaryJSON,
            .digestCompactSummaryJSON,
            .extractCompactMetricsJSON,
            .captureXcodebuildVersion,
            .captureXCResultToolVersion
        ])
        #expect(plan.summaryValue.contains("No physical proof count changed"))
        #expect(plan.accessibilityValue.contains("Command plans do not prove physical iPhone capture"))
        #expect(plan.reviewerEvidenceLines.contains("Command plan compact summary JSON path: \(plan.compactSummaryJSONPath)"))
        #expect(!plan.accessibilityValue.lowercased().contains("phasset.localidentifier"))
        #expect(!plan.accessibilityValue.lowercased().contains("raw image bytes stored"))
    }

    @Test func physicalResultBundleCommandPlanDocumentBuildsShareableTextWithoutExecuting() throws {
        let runbook = try #require(BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first)
        let document = try BracketerPhysicalResultBundleCommandPlanDocument(runbook: runbook)
        let plan = document.plan

        #expect(document.filename == "Bracketer-\(runbook.id)-physical-command-plan.txt")
        #expect(document.documentText.contains("# Bracketer Physical Result Bundle Command Plan"))
        #expect(document.documentText.contains("schemaVersion: \(BracketerPhysicalResultBundleCommandPlan.schemaVersion)"))
        #expect(document.documentText.contains("scenarioID: \(runbook.id)"))
        #expect(document.documentText.contains(plan.resultBundleDigestPath))
        #expect(document.documentText.contains(plan.compactSummaryJSONPath))
        #expect(document.documentText.contains("'/usr/bin/shasum' '-a' '256' '\(plan.resultBundlePath)'"))
        #expect(document.documentText.contains("DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer '/usr/bin/xcrun' 'xcresulttool'"))
        #expect(document.documentText.contains("Copy/share only. Does not execute commands or count physical proof."))
        #expect(document.accessibilityValue.contains("Copy/share only"))
        #expect(!document.documentText.contains("Physical proof captured"))
        #expect(!document.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!document.documentText.lowercased().contains("rawimagebytes"))
        #expect(!document.documentText.lowercased().contains("precisecoordinates"))
    }

    @Test func physicalResultBundleCommandPlanFileProviderBuildsShortcutsIntentFile() throws {
        let export = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
            scenario: .dynamicRangeInteriorWindow
        )
        let file = export.intentFile

        #expect(export.scenarioID == BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow.runbookID)
        #expect(export.filename == "Bracketer-dynamicRangeInteriorWindow-physical-command-plan.txt")
        #expect(export.dialogText.contains("copy/share-only physical result-bundle command plan"))
        #expect(export.dialogText.contains("No physical proof count changed"))
        #expect(export.accessibilityValue.contains("Physical Result Bundle Command Plan Document"))
        #expect(export.documentText.contains("Bracketer-dynamicRangeInteriorWindow-physical.xcresult"))
        #expect(export.documentText.contains("xcresult-summary.compact.json"))
        #expect(export.documentText.contains("xcresult-metrics.compact.json"))
        #expect(export.documentText.contains("Copy/share only. Does not execute commands or count physical proof."))
        #expect(!export.documentText.contains("Physical proof captured"))
        #expect(!export.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(file.filename == export.filename)
        #expect(file.type == .plainText)
        #expect(String(decoding: file.data, as: UTF8.self) == export.documentText)
    }

    @Test func physicalResultBundleCommandPlanFileProviderUsesCallerResultBundlePath() throws {
        let customResultBundlePath = "/tmp/Bracketer-handheldMotionRecovery-physical rerun.xcresult"
        let export = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
            scenario: .handheldMotionRecovery,
            resultBundlePath: "  \(customResultBundlePath)  "
        )

        #expect(export.scenarioID == "handheldMotionRecovery")
        #expect(export.documentText.contains("resultBundlePath: \(customResultBundlePath)"))
        #expect(export.documentText.contains("'/usr/bin/shasum' '-a' '256' '\(customResultBundlePath)'"))
        #expect(export.documentText.contains("'\(customResultBundlePath).sha256'"))
        #expect(export.documentText.contains("/tmp/Bracketer-handheldMotionRecovery-physical rerun-summary.json"))
        #expect(!export.documentText.contains("build/physical-lab/Bracketer-handheldMotionRecovery-physical.xcresult"))
        #expect(!export.documentText.contains("Physical proof captured"))
    }

    @Test func physicalResultBundleCommandPlanFileProviderUsesRunbookPathForBlankCallerPath() throws {
        let export = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
            scenario: .dynamicRangeInteriorWindow,
            resultBundlePath: " \n\t "
        )

        #expect(export.documentText.contains("resultBundlePath: build/physical-lab/Bracketer-dynamicRangeInteriorWindow-physical.xcresult"))
        #expect(export.documentText.contains("xcresult-summary.compact.json"))
        #expect(!export.documentText.contains("Physical proof captured"))
    }

    @Test func physicalResultBundleCommandPlanFileProviderCanOmitMetricsCommand() throws {
        let export = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
            scenario: .handheldMotionRecovery,
            includeMetricsExtraction: false
        )

        #expect(export.scenarioID == "handheldMotionRecovery")
        #expect(export.documentText.contains("Bracketer-handheldMotionRecovery-physical.xcresult"))
        #expect(export.documentText.contains("xcresult-summary.compact.json"))
        #expect(!export.documentText.contains("'metrics'"))
    }

    @Test func physicalResultBundleCommandPlanFileProviderThrowsForMissingRunbook() throws {
        let provider = BracketerPhysicalResultBundleCommandPlanFileProvider(
            catalog: BracketerPhysicalCaptureRunbookCatalog(runbooks: [])
        )

        var didThrowMissingRunbook = false
        do {
            _ = try provider.exportFile(scenario: .dynamicRangeInteriorWindow)
        } catch BracketerPhysicalResultBundleCommandPlanFileProviderError.runbookNotFound(let scenarioID) {
            didThrowMissingRunbook = scenarioID == "dynamicRangeInteriorWindow"
        }

        #expect(didThrowMissingRunbook)
    }

    @Test func physicalResultBundleCommandPlanFileProviderRejectsMismatchedCallerResultBundlePath() throws {
        let mismatchedResultBundlePath = "/tmp/Bracketer-dynamicRangeInteriorWindow-physical-rerun.xcresult"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
                scenario: .handheldMotionRecovery,
                resultBundlePath: mismatchedResultBundlePath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .scenarioBundleNameMismatch(
                expectedPrefix: "Bracketer-handheldMotionRecovery-physical",
                actual: "Bracketer-dynamicRangeInteriorWindow-physical-rerun.xcresult"
            ))
        }
    }

    @Test func physicalResultBundleCommandPlanFileProviderRejectsUnsafeCallerResultBundlePath() throws {
        let unsafeResultBundlePath = "build/physical-lab/Bracketer-handheldMotionRecovery-physical;rm.xcresult"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlanFileProvider().exportFile(
                scenario: .handheldMotionRecovery,
                resultBundlePath: unsafeResultBundlePath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .unsafeResultBundlePath(unsafeResultBundlePath))
        }
    }

    @Test func physicalProofTemplateFileProviderBuildsShortcutsIntentFileFromCompactSummary() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab seeded template",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let export = try BracketerPhysicalProofTemplateFileProvider().exportFile(
            scenario: .dynamicRangeInteriorWindow,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )
        let file = export.intentFile
        let decodedDocument = try BracketerPhysicalProofSubmissionDocument(data: export.data)
        let artifactByteCounts = try #require(decodedDocument.submission.attachmentManifest?.artifactByteCountByID)

        #expect(export.scenarioID == BracketerPhysicalRunbookIntentScenario.dynamicRangeInteriorWindow.runbookID)
        #expect(export.filename == "Bracketer-dynamicRangeInteriorWindow-physical-proof-seeded-template.json")
        #expect(export.dialogText.contains("preview-only physical proof template"))
        #expect(export.dialogText.contains("No physical proof count changed"))
        #expect(export.accessibilityValue.contains("physical-device-proof preview only"))
        #expect(export.documentText.contains("metrics.attachmentByteCount=4096"))
        #expect(export.documentText.contains("attachment.totalBytes=0"))
        #expect(export.documentText.contains("REPLACE_WITH_HASHED_DEVICE_IDENTIFIER"))
        #expect(!export.documentText.contains("Physical proof captured"))
        #expect(!export.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!export.documentText.lowercased().contains("rawimagebytes"))
        #expect(!export.documentText.lowercased().contains("precisecoordinates"))
        #expect(file.filename == export.filename)
        #expect(file.type == .json)
        #expect(String(decoding: file.data, as: UTF8.self) == export.documentText)
        #expect(decodedDocument.submission.scenarioID == "dynamicRangeInteriorWindow")
        #expect(artifactByteCounts.values.allSatisfy { $0 == 0 })
    }

    @Test func physicalProofTemplateFileProviderThrowsForMissingRunbook() throws {
        let provider = BracketerPhysicalProofTemplateFileProvider(
            catalog: BracketerPhysicalCaptureRunbookCatalog(runbooks: [])
        )

        var didThrowMissingRunbook = false
        do {
            _ = try provider.exportFile(
                scenario: .dynamicRangeInteriorWindow,
                compactSummaryData: Data("{}".utf8),
                attachmentByteCount: 4096
            )
        } catch BracketerPhysicalProofTemplateFileProviderError.runbookNotFound(let scenarioID) {
            didThrowMissingRunbook = scenarioID == "dynamicRangeInteriorWindow"
        }

        #expect(didThrowMissingRunbook)
    }

    @Test func physicalLabWorkspaceFileProviderBuildsShortcutsWorkspaceFile() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab workspace",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let customResultBundlePath = "/tmp/Bracketer-handheldMotionRecovery-physical lab.xcresult"
        let runbook = try #require(
            BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first(where: { $0.id == "handheldMotionRecovery" })
        )
        let workspaceDocument = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            resultBundlePath: "  \(customResultBundlePath)  ",
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 8192
        )
        let workspaceArtifactByteCounts = try #require(
            workspaceDocument.proofTemplateDocument.submission.attachmentManifest?.artifactByteCountByID
        )
        let export = try BracketerPhysicalLabWorkspaceFileProvider().exportFile(
            scenario: .handheldMotionRecovery,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 8192,
            resultBundlePath: "  \(customResultBundlePath)  "
        )
        let file = export.intentFile
        let manifest = try BracketerPhysicalLabWorkspaceDocument.decodeManifest(from: export.documentText)

        #expect(export.scenarioID == "handheldMotionRecovery")
        #expect(export.filename == "Bracketer-handheldMotionRecovery-physical-lab-workspace.md")
        #expect(export.dialogText.contains("copy/share-only physical lab workspace"))
        #expect(export.dialogText.contains("No physical proof count changed"))
        #expect(export.accessibilityValue.contains("Bracketer Physical Lab Workspace"))
        #expect(export.accessibilityValue.contains("Copy/share only"))
        #expect(export.documentText.contains("# Bracketer Physical Lab Workspace"))
        #expect(export.documentText.contains("scenarioID: handheldMotionRecovery"))
        #expect(export.documentText.contains("physicalProofStatus: no physical proof captured"))
        #expect(export.documentText.contains("0 of 8"))
        #expect(export.documentText.contains("## Workspace Manifest"))
        #expect(export.documentText.contains("```json bracketer-physical-lab-workspace-manifest"))
        #expect(!export.documentText.contains("recorded proof(s)"))
        #expect(export.documentText.contains("resultBundlePath: \(customResultBundlePath)"))
        #expect(export.documentText.contains("## Expected Artifacts"))
        #expect(export.documentText.contains("- side-by-side-pixel-comparison"))
        #expect(runbook.expectedArtifacts.allSatisfy { export.documentText.contains("- \($0)") })
        #expect(export.documentText.contains("## Output Paths"))
        #expect(export.documentText.contains("/tmp/Bracketer-handheldMotionRecovery-physical lab-summary.json"))
        #expect(export.documentText.contains("## Command Plan"))
        #expect(export.documentText.contains("## Seeded Physical Proof Template"))
        #expect(export.documentText.contains("Bracketer-handheldMotionRecovery-physical-proof-seeded-template.json"))
        #expect(export.documentText.contains("\"scenarioID\" : \"handheldMotionRecovery\""))
        #expect(export.documentText.contains("metrics.attachmentByteCount=8192"))
        #expect(export.documentText.contains("attachment.totalBytes=0"))
        #expect(workspaceArtifactByteCounts.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(workspaceArtifactByteCounts.values.allSatisfy { $0 == 0 })
        #expect(export.documentText.contains("per-artifact byte counts at zero"))
        #expect(export.accessibilityValue.contains("no physical proof captured"))
        #expect(!export.documentText.contains("Physical proof captured"))
        #expect(!export.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!export.documentText.lowercased().contains("rawimagebytes"))
        #expect(!export.documentText.lowercased().contains("precisecoordinates"))
        #expect(file.filename == export.filename)
        #expect(file.type == .plainText)
        #expect(String(decoding: file.data, as: UTF8.self) == export.documentText)
        #expect(manifest.scenarioID == "handheldMotionRecovery")
        #expect(manifest.scenarioTitle == runbook.scenarioTitle)
        #expect(manifest.resultBundlePath == customResultBundlePath)
        #expect(manifest.commandPlanFilename == "Bracketer-handheldMotionRecovery-physical-command-plan.txt")
        #expect(manifest.seededTemplateFilename == "Bracketer-handheldMotionRecovery-physical-proof-seeded-template.json")
        #expect(manifest.expectedArtifacts == runbook.expectedArtifacts)
        #expect(manifest.commandCount == 6)
        #expect(manifest.includesMetricsExtractionCommand)
        #expect(manifest.requiredPhysicalScenarioCount == 8)
        #expect(manifest.noPhysicalProofBoundary.contains("does not execute commands"))
        #expect(manifest.outputArtifactPaths["xcresult-metrics.compact.json"]?.hasSuffix("-metrics.json") ?? false)
    }

    @Test func physicalLabWorkspacePreviewProviderBuildsChecklistFromEmbeddedManifest() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let export = try BracketerPhysicalLabWorkspaceFileProvider().exportFile(
            scenario: .filesShortcutsSpotlightRoundTrip,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096,
            includeMetricsExtraction: false
        )
        let manifest = try BracketerPhysicalLabWorkspaceDocument.decodeManifest(from: export.documentText)
        let preview = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
            export.data,
            filename: export.filename
        )
        let shortcutsPreview = try BracketerPhysicalLabWorkspacePreviewFileProvider().previewFile(export.intentFile)

        #expect(export.documentText.contains("```json bracketer-physical-lab-workspace-manifest"))
        #expect(manifest.scenarioID == "filesShortcutsSpotlightRoundTrip")
        #expect(manifest.physicalProofStatus.contains("no physical proof captured"))
        #expect(manifest.outputArtifactPaths["seeded-template.json"] == "Bracketer-filesShortcutsSpotlightRoundTrip-physical-proof-seeded-template.json")
        #expect(manifest.outputArtifactPaths["result-bundle.sha256"]?.hasSuffix(".xcresult.sha256") ?? false)
        #expect(!manifest.includesMetricsExtractionCommand)
        #expect(preview.dialogText.contains("physical-lab-workspace preview only"))
        #expect(preview.dialogText.contains("No physical proof count changed"))
        #expect(preview.checklist.summaryValue.contains("Physical Lab Workspace Preview"))
        #expect(preview.checklist.checklistItems.contains("Expected artifact ids match current runbook"))
        #expect(preview.accessibilityValue.contains("Import preview does not mutate runbooks or result-bundle indexes"))
        #expect(shortcutsPreview.dialogText == preview.dialogText)
        #expect(shortcutsPreview.accessibilityValue.contains("Proof category: pure-model-proof"))
    }

    @Test func physicalLabReviewHandoffPackageFileProviderBuildsManifestedIntentFile() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab handoff package",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let customResultBundlePath = "/tmp/Bracketer-handheldMotionRecovery-physical handoff.xcresult"
        let runbook = try #require(
            BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first(where: { $0.id == "handheldMotionRecovery" })
        )
        let workspaceDocument = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            resultBundlePath: "  \(customResultBundlePath)  ",
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 8192
        )
        let package = BracketerPhysicalLabReviewHandoffPackage(workspaceDocument: workspaceDocument)
        let export = try BracketerPhysicalLabReviewHandoffPackageFileProvider().exportFile(
            scenario: .handheldMotionRecovery,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 8192,
            resultBundlePath: "  \(customResultBundlePath)  "
        )
        let file = export.intentFile

        #expect(package.filename == "Bracketer-handheldMotionRecovery-physical-lab-review-handoff.txt")
        #expect(package.payloadFiles.map(\.kind) == ["lab-workspace", "command-plan", "seeded-proof-template", "output-paths", "reviewer-checklist"])
        #expect(package.files.map(\.kind) == ["package-manifest", "lab-workspace", "command-plan", "seeded-proof-template", "output-paths", "reviewer-checklist"])
        #expect(package.files.allSatisfy { $0.sha256Hex.count == 64 })
        #expect(package.documentText.contains("# Bracketer Physical Lab Review Handoff Package"))
        #expect(package.documentText.contains("\"payloadCount\":5"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-package-manifest.json"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-lab-workspace.md"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-command-plan.txt"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-proof-seeded-template.json"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-output-paths.md"))
        #expect(package.documentText.contains("Bracketer-handheldMotionRecovery-physical-reviewer-checklist.md"))
        #expect(package.documentText.contains("SHA-256:"))
        #expect(package.documentText.contains("no physical proof captured"))
        #expect(package.documentText.contains("0 of 8"))
        #expect(package.documentText.contains("Copy/share only. Does not execute commands or count physical proof."))
        #expect(package.documentText.contains("resultBundlePath: \(customResultBundlePath)"))
        #expect(package.accessibilityValue.contains("Payload files: 5"))
        #expect(!package.documentText.contains("Physical proof captured"))
        #expect(!package.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!package.documentText.lowercased().contains("rawimagebytes"))
        #expect(!package.documentText.lowercased().contains("precisecoordinates"))
        #expect(export.scenarioID == "handheldMotionRecovery")
        #expect(export.filename == package.filename)
        #expect(export.documentText == package.documentText)
        #expect(export.dialogText.contains("copy/share-only physical lab review handoff package"))
        #expect(export.dialogText.contains("No physical proof count changed"))
        #expect(export.accessibilityValue.contains("Bracketer Physical Lab Review Handoff Package"))
        #expect(file.filename == package.filename)
        #expect(file.type == .plainText)
        #expect(String(decoding: file.data, as: UTF8.self) == package.documentText)
    }

    @Test func physicalLabReviewHandoffPackagePreviewProviderBuildsChecklistAndShortcutsPreview() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab handoff package preview",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let export = try BracketerPhysicalLabReviewHandoffPackageFileProvider().exportFile(
            scenario: .filesShortcutsSpotlightRoundTrip,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096,
            includeMetricsExtraction: false
        )
        let preview = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
            export.data,
            filename: export.filename
        )
        let shortcutsPreview = try BracketerPhysicalLabReviewHandoffPackagePreviewFileProvider().previewFile(export.intentFile)

        #expect(preview.manifest.scenarioID == "filesShortcutsSpotlightRoundTrip")
        #expect(preview.manifest.payloadCount == 5)
        #expect(preview.dialogText.contains("physical-lab-review-handoff preview only"))
        #expect(preview.dialogText.contains("No physical proof count changed"))
        #expect(preview.checklist.summaryValue.contains("Physical Lab Review Handoff Package Preview"))
        #expect(preview.checklist.checklistItems.contains("Payload SHA-256 digests match archive blocks"))
        #expect(preview.workspacePreview.checklist.summaryValue.contains("Physical Lab Workspace Preview"))
        #expect(preview.accessibilityValue.contains("Import preview does not mutate runbooks or result-bundle indexes"))
        #expect(preview.accessibilityValue.contains("Embedded workspace:"))
        #expect(shortcutsPreview.dialogText == preview.dialogText)
        #expect(shortcutsPreview.accessibilityValue.contains("Proof category: pure-model-proof"))
    }

    @Test func physicalLabReviewHandoffPackagePreviewProviderRejectsTamperedSHAHeader() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab handoff package tamper test",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let runbook = try #require(
            BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first(where: { $0.id == "dynamicRangeInteriorWindow" })
        )
        let workspaceDocument = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )
        let package = BracketerPhysicalLabReviewHandoffPackage(workspaceDocument: workspaceDocument)
        let payload = try #require(package.payloadFiles.first)
        let tamperedDocument = package.documentText.replacingOccurrences(
            of: "SHA-256: \(payload.sha256Hex)",
            with: "SHA-256: \(String(repeating: "0", count: 64))"
        )

        var didThrowSHA = false
        do {
            _ = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
                Data(tamperedDocument.utf8),
                filename: package.filename
            )
            #expect(Bool(false))
        } catch BracketerPhysicalLabReviewHandoffPackageReviewError.sha256Mismatch(let filename) {
            didThrowSHA = filename == payload.filename
        }
        #expect(didThrowSHA)
    }

    @Test func physicalLabReviewHandoffPackagePreviewProviderRejectsMissingPayloadAndBadManifest() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab handoff package manifest rejection test",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let runbook = try #require(
            BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first(where: { $0.id == "dynamicRangeInteriorWindow" })
        )
        let workspaceDocument = try BracketerPhysicalLabWorkspaceDocument(
            runbook: runbook,
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )
        let package = BracketerPhysicalLabReviewHandoffPackage(workspaceDocument: workspaceDocument)
        let seededTemplateFile = try #require(package.payloadFiles.first { $0.kind == "seeded-proof-template" })
        let missingPayloadDocument = package.documentText.replacingOccurrences(
            of: seededTemplateFile.archiveBlock,
            with: ""
        )

        do {
            _ = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
                Data(missingPayloadDocument.utf8),
                filename: package.filename
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalLabReviewHandoffPackageReviewError {
            if case .payloadInventoryMismatch(expected: let expected, actual: let actual) = error {
                #expect(expected.contains(seededTemplateFile.filename))
                #expect(!actual.contains(seededTemplateFile.filename))
            } else {
                #expect(Bool(false))
            }
        }

        let manifestFile = try #require(package.files.first { $0.kind == "package-manifest" })
        let malformedManifestFile = BracketerPhysicalLabReviewHandoffPackageFile(
            kind: manifestFile.kind,
            filename: manifestFile.filename,
            contents: "{not-json"
        )
        let malformedManifestDocument = package.documentText.replacingOccurrences(
            of: manifestFile.archiveBlock,
            with: malformedManifestFile.archiveBlock
        )

        do {
            _ = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
                Data(malformedManifestDocument.utf8),
                filename: package.filename
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalLabReviewHandoffPackageReviewError {
            #expect(error == .unreadableManifest)
        }

        let manifest = try JSONDecoder().decode(
            BracketerPhysicalLabReviewHandoffPackageManifest.self,
            from: Data(manifestFile.contents.utf8)
        )
        let unsupportedManifest = BracketerPhysicalLabReviewHandoffPackageManifest(
            schemaVersion: 2,
            scenarioID: manifest.scenarioID,
            scenarioTitle: manifest.scenarioTitle,
            physicalProofStatus: manifest.physicalProofStatus,
            payloadCount: manifest.payloadCount,
            privacyBoundary: manifest.privacyBoundary,
            proofBoundary: manifest.proofBoundary,
            packageBoundary: manifest.packageBoundary,
            payloads: manifest.payloads
        )
        let unsupportedManifestFile = BracketerPhysicalLabReviewHandoffPackageFile(
            kind: manifestFile.kind,
            filename: manifestFile.filename,
            contents: String(
                decoding: try JSONEncoder.bracketerPhysicalProofCanonical.encode(unsupportedManifest),
                as: UTF8.self
            )
        )
        let unsupportedManifestDocument = package.documentText.replacingOccurrences(
            of: manifestFile.archiveBlock,
            with: unsupportedManifestFile.archiveBlock
        )

        do {
            _ = try BracketerPhysicalLabReviewHandoffPackageReviewPreviewProvider().previewData(
                Data(unsupportedManifestDocument.utf8),
                filename: package.filename
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalLabReviewHandoffPackageReviewError {
            #expect(error == .unsupportedSchemaVersion(2))
        }
    }

    @Test func physicalLabReviewHandoffPackageFileProviderRejectsMissingRunbookAndUnsafePath() throws {
        let provider = BracketerPhysicalLabReviewHandoffPackageFileProvider(
            catalog: BracketerPhysicalCaptureRunbookCatalog(runbooks: [])
        )

        var didThrowMissingRunbook = false
        do {
            _ = try provider.exportFile(
                scenario: .dynamicRangeInteriorWindow,
                compactSummaryData: Data("{}".utf8),
                attachmentByteCount: 4096
            )
        } catch BracketerPhysicalLabReviewHandoffPackageFileProviderError.runbookNotFound(let scenarioID) {
            didThrowMissingRunbook = scenarioID == "dynamicRangeInteriorWindow"
        }
        #expect(didThrowMissingRunbook)

        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let unsafeResultBundlePath = "/tmp/Bracketer-handheldMotionRecovery-physical;rm.xcresult"
        do {
            _ = try BracketerPhysicalLabReviewHandoffPackageFileProvider().exportFile(
                scenario: .handheldMotionRecovery,
                compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
                attachmentByteCount: 4096,
                resultBundlePath: unsafeResultBundlePath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .unsafeResultBundlePath(unsafeResultBundlePath))
        }
    }

    @Test func physicalLabWorkspacePreviewProviderRejectsMissingManifestAndMissingRunbook() throws {
        var didThrowMissingManifest = false
        do {
            _ = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
                Data("# Bracketer Physical Lab Workspace\n\nNo manifest".utf8)
            )
        } catch BracketerPhysicalLabWorkspaceReviewError.missingManifest {
            didThrowMissingManifest = true
        }
        #expect(didThrowMissingManifest)

        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let export = try BracketerPhysicalLabWorkspaceFileProvider().exportFile(
            scenario: .dynamicRangeInteriorWindow,
            compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )

        var didThrowMissingRunbook = false
        do {
            _ = try BracketerPhysicalLabWorkspaceReviewPreviewProvider().previewData(
                export.data,
                filename: export.filename,
                catalog: BracketerPhysicalCaptureRunbookCatalog(runbooks: [])
            )
        } catch BracketerPhysicalLabWorkspaceReviewError.runbookNotFound(let scenarioID) {
            didThrowMissingRunbook = scenarioID == "dynamicRangeInteriorWindow"
        }
        #expect(didThrowMissingRunbook)
    }

    @Test func physicalLabWorkspaceFileProviderThrowsForMissingRunbook() throws {
        let provider = BracketerPhysicalLabWorkspaceFileProvider(
            catalog: BracketerPhysicalCaptureRunbookCatalog(runbooks: [])
        )

        var didThrowMissingRunbook = false
        do {
            _ = try provider.exportFile(
                scenario: .dynamicRangeInteriorWindow,
                compactSummaryData: Data("{}".utf8),
                attachmentByteCount: 4096
            )
        } catch BracketerPhysicalLabWorkspaceFileProviderError.runbookNotFound(let scenarioID) {
            didThrowMissingRunbook = scenarioID == "dynamicRangeInteriorWindow"
        }

        #expect(didThrowMissingRunbook)
    }

    @Test func physicalLabWorkspaceFileProviderRejectsUnsafeResultBundlePath() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let unsafeResultBundlePath = "/tmp/Bracketer-handheldMotionRecovery-physical;rm.xcresult"
        do {
            _ = try BracketerPhysicalLabWorkspaceFileProvider().exportFile(
                scenario: .handheldMotionRecovery,
                compactSummaryData: try #require(compactSummaryJSON.data(using: .utf8)),
                attachmentByteCount: 4096,
                resultBundlePath: unsafeResultBundlePath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .unsafeResultBundlePath(unsafeResultBundlePath))
        }
    }

    @Test func physicalResultBundleCommandPlanCanOmitMetricsExtraction() throws {
        let runbook = try #require(BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first)
        let plan = try BracketerPhysicalResultBundleCommandPlan.make(
            for: runbook,
            includeMetricsExtraction: false
        )

        #expect(plan.commands.map(\.step) == [
            .digestResultBundle,
            .extractCompactSummaryJSON,
            .digestCompactSummaryJSON,
            .captureXcodebuildVersion,
            .captureXCResultToolVersion
        ])
        #expect(!plan.commands.contains { $0.step == .extractCompactMetricsJSON })
    }

    @Test func physicalResultBundleCommandPlanShellLinesAreStableAndQuoted() throws {
        let runbook = try #require(BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first)
        let resultBundlePath = "/tmp/Bracketer-\(runbook.id)-physical rerun.xcresult"
        let plan = try BracketerPhysicalResultBundleCommandPlan.make(
            for: runbook,
            resultBundlePath: "  \(resultBundlePath)  "
        )

        #expect(plan.resultBundlePath == resultBundlePath)
        #expect(plan.commands.first?.invocation == "'/usr/bin/shasum' '-a' '256' '\(resultBundlePath)' > '\(resultBundlePath).sha256'")
        #expect(plan.commands[1].invocation == "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer '/usr/bin/xcrun' 'xcresulttool' 'get' 'test-results' 'summary' '--path' '\(resultBundlePath)' '--compact' > '/tmp/Bracketer-\(runbook.id)-physical rerun-summary.json'")
        #expect(plan.commands[2].invocation == "'/usr/bin/shasum' '-a' '256' '/tmp/Bracketer-\(runbook.id)-physical rerun-summary.json' > '/tmp/Bracketer-\(runbook.id)-physical rerun-summary.json.sha256'")
        #expect(plan.commands[3].invocation.contains("'metrics'"))
        #expect(plan.commands[4].invocation == "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer '/usr/bin/xcodebuild' '-version' > '/tmp/Bracketer-\(runbook.id)-physical rerun-xcodebuild-version.txt'")
        #expect(plan.commands[5].invocation == "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer '/usr/bin/xcrun' 'xcresulttool' 'version' > '/tmp/Bracketer-\(runbook.id)-physical rerun-xcresulttool-version.txt'")
    }

    @Test func physicalResultBundleCommandPlanRejectsUnsafeAndMismatchedPaths() throws {
        let runbook = try #require(BracketerPhysicalCaptureRunbookCatalog.make().runbooks.first)
        let unsafePath = "build/physical-lab/Bracketer-\(runbook.id)-physical.xcresult;rm"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlan.make(
                for: runbook,
                resultBundlePath: unsafePath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .resultBundlePathNotXCResult(unsafePath))
        }

        let unsafeXCResultPath = "build/physical-lab/Bracketer-\(runbook.id)-physical;rm.xcresult"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlan.make(
                for: runbook,
                resultBundlePath: unsafeXCResultPath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .unsafeResultBundlePath(unsafeXCResultPath))
        }

        let nonXCResultPath = "build/physical-lab/Bracketer-\(runbook.id)-physical.json"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlan.make(
                for: runbook,
                resultBundlePath: nonXCResultPath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .resultBundlePathNotXCResult(nonXCResultPath))
        }

        let mismatchedPath = "build/physical-lab/Bracketer-otherScenario-physical.xcresult"
        do {
            _ = try BracketerPhysicalResultBundleCommandPlan.make(
                for: runbook,
                resultBundlePath: mismatchedPath
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalResultBundleCommandPlanError {
            #expect(error == .scenarioBundleNameMismatch(
                expectedPrefix: "Bracketer-\(runbook.id)-physical",
                actual: "Bracketer-otherScenario-physical.xcresult"
            ))
        }
    }

    @Test func physicalResultBundleCommandPlanDecodesProofInputThroughExistingParser() throws {
        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab command plan",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let data = try #require(compactSummaryJSON.data(using: .utf8))
        let proofInput = try BracketerPhysicalResultBundleCommandPlan.decodeProofInput(
            compactSummaryJSON: data,
            attachmentByteCount: 4096
        )
        let directProofInput = try BracketerPhysicalResultBundleProofInput.decodeCompactXCResultSummaryJSON(
            data,
            attachmentByteCount: 4096
        )

        #expect(proofInput == directProofInput)
        #expect(proofInput.resultBundleSummary.status == .passed)
        #expect(proofInput.resultBundleDevice?.platform == "iOS")
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundResultBundleDeviceMetadata() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_720)
        let resultBundleDevice = physicalProofResultBundleDevice()
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let evidenceWithoutDevice = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleDevice: resultBundleDevice
        )
            .filter { !$0.contains("Result bundle device") }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    omitResultBundleDevice: true,
                    reviewerEvidence: evidenceWithoutDevice,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleDeviceMetadata)
        }

        for (invalidDevice, expectedError) in [
            (
                physicalProofResultBundleDevice(platform: "iOS Simulator"),
                BracketerPhysicalProofIngestor.ValidationFailure.invalidResultBundleDeviceMetadata("platform must describe physical iOS, not iOS Simulator")
            ),
            (
                physicalProofResultBundleDevice(modelName: "iPad Pro"),
                .invalidResultBundleDeviceMetadata("modelName must describe an iPhone device")
            ),
            (
                physicalProofResultBundleDevice(osVersion: "26.4.0", osBuildNumber: "23E253"),
                .invalidResultBundleDeviceMetadata("osVersion or osBuildNumber must match submission iOS build")
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleDevice: invalidDevice,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleDevice: invalidDevice
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == expectedError)
            }
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleDevice: resultBundleDevice,
                    reviewerEvidence: evidenceWithoutDevice,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleDeviceMetadata(resultBundleDevice.reviewerEvidenceTokens))
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleDevice: resultBundleDevice,
                reviewerEvidence: evidenceWithoutDevice,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )

        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle device metadata: \(resultBundleDevice.reviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundResultBundleSummary() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_660)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let digest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let evidenceWithoutSummary = [
            "Captured at: \(physicalProofTimestamp(capturedAt))",
            "Result bundle: \(filename)",
            "Result bundle SHA-256: \(digest)",
            "Result bundle summary SHA-256: \(summaryDigest)"
        ] + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: nil,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleSummary)
        }

        for (invalidSummary, expectedError) in [
            (
                BracketerPhysicalResultBundleSummary(
                    status: .failed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                BracketerPhysicalProofIngestor.ValidationFailure.invalidResultBundleSummary("status must equal Passed")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 0,
                    passedTestCount: 0,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("totalTestCount must be greater than 0")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: -1,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("passedTestCount must not be negative")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: -1,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("failedTestCount must not be negative")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 163,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("passedTestCount must equal totalTestCount")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: 1,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("failedTestCount must equal 0")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "   ",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("title is required")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: 0,
                    expectedFailureCount: 1,
                    skippedTestCount: 0
                ),
                .invalidResultBundleSummary("expectedFailureCount must equal 0")
            ),
            (
                BracketerPhysicalResultBundleSummary(
                    status: .passed,
                    title: "Test - Bracketer",
                    totalTestCount: 164,
                    passedTestCount: 164,
                    failedTestCount: 0,
                    expectedFailureCount: 0,
                    skippedTestCount: 1
                ),
                .invalidResultBundleSummary("skippedTestCount must equal 0")
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: digest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleSummary: invalidSummary,
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == expectedError)
            }
        }

        let mismatchedMetricsSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 165,
            passedTestCount: 165,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: mismatchedMetricsSummary,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(
                error == .resultBundleSummaryMetricsMismatch(
                    field: "totalTestCount",
                    summaryCount: 165,
                    metricsCount: 164
                )
            )
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: resultBundleSummary,
                    reviewerEvidence: evidenceWithoutSummary,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleSummary(resultBundleSummary.reviewerEvidenceTokens))
        }

        let suffixCollisionSummaryEvidence = evidenceWithoutSummary + [
            "Result bundle summary: summary.status=passed0, summary.title=testbracketer0, summary.totalTestCount=1640, summary.passedTests=1640, summary.failedTests=00, summary.expectedFailures=00, summary.skippedTests=00"
        ]
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: digest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleSummary: resultBundleSummary,
                    reviewerEvidence: suffixCollisionSummaryEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleSummary(resultBundleSummary.reviewerEvidenceTokens))
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: digest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleSummary: resultBundleSummary,
                reviewerEvidence: suffixCollisionSummaryEvidence,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo typed result-bundle summary: \(resultBundleSummary.reviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorRejectsUnboundResultBundleSummaryDigest() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_720)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let evidenceWithoutSummaryDigest = [
            "Captured at: \(physicalProofTimestamp(capturedAt))",
            "Result bundle: \(filename)",
            "Result bundle SHA-256: \(bundleDigest)",
            "Result bundle summary: \(resultBundleSummary.summaryValue)",
            "Hashed device identifier: \(String(repeating: "c", count: 64))",
            "Device model: iPhone17,1",
            "iOS build: 26.4.1"
        ] + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: nil,
                    reviewerEvidence: evidenceWithoutSummaryDigest,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleSummarySHA256)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: "not-a-digest",
                    reviewerEvidence: evidenceWithoutSummaryDigest + ["Result bundle summary SHA-256: not-a-digest"],
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidSHA256(field: "resultBundleSummarySHA256"))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: bundleDigest,
                    reviewerEvidence: evidenceWithoutSummaryDigest + ["Result bundle summary SHA-256: \(bundleDigest)"],
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .resultBundleSummarySHA256MatchesBundleSHA256)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    reviewerEvidence: evidenceWithoutSummaryDigest,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleSummarySHA256(summaryDigest))
        }

        let signedSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            capturedAt: capturedAt
        ).signed()
        let tamperedSummarySubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: signedSubmission.resultBundleSHA256,
            resultBundleSummarySHA256: String(repeating: "e", count: 64),
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: signedSubmission.resultBundleMetrics,
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedSummarySubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                reviewerEvidence: evidenceWithoutSummaryDigest,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle summary SHA-256 \(summaryDigest)."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundResultBundleMetrics() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_840)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let metrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        )
        let invalidMetrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 1,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        )
        let evidenceWithoutMetrics = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleMetrics: metrics
        )
            .filter { !$0.contains("Result bundle metrics") }
        let suffixCollisionMetricsEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleMetrics: metrics
        )
            .map { line in
                if line.contains("Result bundle metrics") {
                    return "Result bundle metrics: metrics.totalTestCount=1640, metrics.passedTests=1640, metrics.failedTests=00, metrics.durationMilliseconds=600000, metrics.attachmentByteCount=40960"
                }
                return line
            }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleMetrics: nil,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleMetrics)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleMetrics: invalidMetrics,
                    reviewerEvidence: physicalProofReviewerEvidence(
                        for: runbook,
                        capturedAt: capturedAt,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleMetrics: invalidMetrics
                    ),
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidResultBundleMetrics("failedTests must equal 0"))
        }

        for (invalidMetrics, expectedReason) in [
            (
                BracketerPhysicalResultBundleMetrics(
                    totalTestCount: 0,
                    passedTests: 0,
                    failedTests: 0,
                    durationMilliseconds: 60_000,
                    attachmentByteCount: 4096
                ),
                "totalTestCount must be greater than 0"
            ),
            (
                BracketerPhysicalResultBundleMetrics(
                    totalTestCount: 164,
                    passedTests: 163,
                    failedTests: 0,
                    durationMilliseconds: 60_000,
                    attachmentByteCount: 4096
                ),
                "passedTests must equal totalTestCount"
            ),
            (
                BracketerPhysicalResultBundleMetrics(
                    totalTestCount: 164,
                    passedTests: 164,
                    failedTests: 0,
                    durationMilliseconds: 0,
                    attachmentByteCount: 4096
                ),
                "durationMilliseconds must be greater than 0"
            ),
            (
                BracketerPhysicalResultBundleMetrics(
                    totalTestCount: 164,
                    passedTests: 164,
                    failedTests: 0,
                    durationMilliseconds: 60_000,
                    attachmentByteCount: 0
                ),
                "attachmentByteCount must be greater than 0"
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleMetrics: invalidMetrics,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleMetrics: invalidMetrics
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidResultBundleMetrics(expectedReason))
            }
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleMetrics: metrics,
                    reviewerEvidence: evidenceWithoutMetrics,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleMetrics(metrics.reviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleMetrics: metrics,
                    reviewerEvidence: suffixCollisionMetricsEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleMetrics(metrics.reviewerEvidenceTokens))
        }

        let signedSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleMetrics: metrics,
            capturedAt: capturedAt
        ).signed()
        let tamperedMetricsSubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: signedSubmission.resultBundleSHA256,
            resultBundleSummarySHA256: signedSubmission.resultBundleSummarySHA256,
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 165,
                passedTests: 165,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )
        #expect(!tamperedMetricsSubmission.hasValidAttachmentSignature)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedMetricsSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleMetrics: metrics,
                reviewerEvidence: evidenceWithoutMetrics,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle metrics: \(metrics.reviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(preview.recordedProofPreview == nil)
        #expect(preview.indexEntryPreview == nil)
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundResultBundleTestContract() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_900)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let contract = physicalProofResultBundleTestContract(for: runbook)
        let invalidContract = BracketerPhysicalResultBundleTestContract(
            xcodebuildVersion: "xcodebuild output unavailable",
            xcresulttoolVersion: contract.xcresulttoolVersion,
            testPlanConfigurationName: contract.testPlanConfigurationName,
            testIdentifier: contract.testIdentifier,
            testName: contract.testName
        )
        let evidenceWithoutContract = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTestContract: contract
        )
            .filter { !$0.contains("Result bundle test contract") }
        let suffixCollisionContractEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTestContract: contract
        )
            .map { line in
                if line.contains("Result bundle test contract") {
                    return "Result bundle test contract: test.xcodebuildVersion=Xcode 26.50 Build version 17F421, test.xcresulttoolVersion=xcresulttool version 247570, schema version: 0.1.01, test.plan=Test Scheme Actions, test.identifier=BracketerPhysicalCaptureTests/test\(runbook.id)PhysicalCaptureExtra, test.name=test\(runbook.id)PhysicalCaptureExtra"
                }
                return line
            }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    omitResultBundleTestContract: true,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleTestContract)
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: invalidContract,
                    reviewerEvidence: physicalProofReviewerEvidence(
                        for: runbook,
                        capturedAt: capturedAt,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleTestContract: invalidContract
                    ),
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidResultBundleTestContract("xcodebuildVersion must come from xcodebuild -version"))
        }

        for (invalidContract, expectedReason) in [
            (
                BracketerPhysicalResultBundleTestContract(
                    xcodebuildVersion: contract.xcodebuildVersion,
                    xcresulttoolVersion: "result bundle tool",
                    testPlanConfigurationName: contract.testPlanConfigurationName,
                    testIdentifier: contract.testIdentifier,
                    testName: contract.testName
                ),
                "xcresulttoolVersion must come from xcresulttool --version"
            ),
            (
                BracketerPhysicalResultBundleTestContract(
                    xcodebuildVersion: contract.xcodebuildVersion,
                    xcresulttoolVersion: contract.xcresulttoolVersion,
                    testPlanConfigurationName: "",
                    testIdentifier: contract.testIdentifier,
                    testName: contract.testName
                ),
                "testPlanConfigurationName is required"
            ),
            (
                BracketerPhysicalResultBundleTestContract(
                    xcodebuildVersion: contract.xcodebuildVersion,
                    xcresulttoolVersion: contract.xcresulttoolVersion,
                    testPlanConfigurationName: contract.testPlanConfigurationName,
                    testIdentifier: "BracketerPhysicalCaptureTests/testOtherScenarioPhysicalCapture",
                    testName: "testOtherScenarioPhysicalCapture"
                ),
                "testIdentifier must include scenario id \(runbook.id)"
            ),
            (
                BracketerPhysicalResultBundleTestContract(
                    xcodebuildVersion: contract.xcodebuildVersion,
                    xcresulttoolVersion: contract.xcresulttoolVersion,
                    testPlanConfigurationName: contract.testPlanConfigurationName,
                    testIdentifier: contract.testIdentifier,
                    testName: ""
                ),
                "testName is required"
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleTestContract: invalidContract,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleTestContract: invalidContract
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidResultBundleTestContract(expectedReason))
            }
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    reviewerEvidence: evidenceWithoutContract,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleTestContract(contract.reviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    reviewerEvidence: suffixCollisionContractEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleTestContract(contract.reviewerEvidenceTokens))
        }

        let signedSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTestContract: contract,
            capturedAt: capturedAt
        ).signed()
        let tamperedContractSubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: signedSubmission.resultBundleSHA256,
            resultBundleSummarySHA256: signedSubmission.resultBundleSummarySHA256,
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: signedSubmission.resultBundleMetrics,
            resultBundleTestContract: BracketerPhysicalResultBundleTestContract(
                xcodebuildVersion: "Xcode 26.5 Build version 17F42",
                xcresulttoolVersion: "xcresulttool version 24758, schema version: 0.1.0",
                testPlanConfigurationName: contract.testPlanConfigurationName,
                testIdentifier: contract.testIdentifier,
                testName: contract.testName
            ),
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )
        #expect(!tamperedContractSubmission.hasValidAttachmentSignature)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedContractSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleTestContract: contract,
                reviewerEvidence: evidenceWithoutContract,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle test contract: \(contract.reviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(preview.recordedProofPreview == nil)
        #expect(preview.indexEntryPreview == nil)
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundResultBundleTiming() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_960)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let timing = physicalProofResultBundleTiming(around: capturedAt)
        let metrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        )
        let evidenceWithoutTiming = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTiming: timing
        )
            .filter { !$0.contains("Result bundle timing") }
        let suffixCollisionTimingEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTiming: timing
        )
            .map { line in
                if line.contains("Result bundle timing") {
                    return "Result bundle timing: timing.summaryStart=\(physicalProofTimestamp(timing.summaryStartTime))0, timing.summaryFinish=\(physicalProofTimestamp(timing.summaryFinishTime))0, timing.testStart=\(physicalProofTimestamp(timing.testStartTime))0, timing.testFinish=\(physicalProofTimestamp(timing.testFinishTime))0"
                }
                return line
            }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    omitResultBundleTiming: true,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingResultBundleTiming)
        }

        for (invalidTiming, expectedReason) in [
            (
                BracketerPhysicalResultBundleTiming(
                    summaryStartTime: capturedAt,
                    summaryFinishTime: capturedAt,
                    testStartTime: capturedAt,
                    testFinishTime: capturedAt.addingTimeInterval(1)
                ),
                "summaryFinishTime must be after summaryStartTime"
            ),
            (
                BracketerPhysicalResultBundleTiming(
                    summaryStartTime: capturedAt.addingTimeInterval(-60),
                    summaryFinishTime: capturedAt.addingTimeInterval(60),
                    testStartTime: capturedAt.addingTimeInterval(-30),
                    testFinishTime: capturedAt.addingTimeInterval(90)
                ),
                "testFinishTime must be on or before summaryFinishTime"
            ),
            (
                BracketerPhysicalResultBundleTiming(
                    summaryStartTime: capturedAt.addingTimeInterval(60),
                    summaryFinishTime: capturedAt.addingTimeInterval(180),
                    testStartTime: capturedAt.addingTimeInterval(90),
                    testFinishTime: capturedAt.addingTimeInterval(120)
                ),
                "capturedAt must fall inside result-bundle test window"
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleTiming: invalidTiming,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleTiming: invalidTiming
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidResultBundleTiming(expectedReason))
            }
        }

        for (durationMilliseconds, expectedDurationMilliseconds) in [
            (59_999, 60_000),
            (60_001, 60_000)
        ] {
            let mismatchedMetrics = BracketerPhysicalResultBundleMetrics(
                totalTestCount: metrics.totalTestCount,
                passedTests: metrics.passedTests,
                failedTests: metrics.failedTests,
                durationMilliseconds: durationMilliseconds,
                attachmentByteCount: metrics.attachmentByteCount
            )
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleMetrics: mismatchedMetrics,
                        resultBundleTiming: timing,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleMetrics: mismatchedMetrics,
                            resultBundleTiming: timing
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .resultBundleTimingDurationMismatch(
                    expectedMilliseconds: expectedDurationMilliseconds,
                    metricsMilliseconds: durationMilliseconds
                ))
            }
        }

        let exactDurationResult = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleMetrics: metrics,
                resultBundleTiming: timing,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(exactDurationResult.resultBundleIndex.indexedCount == 1)

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTiming: timing,
                    reviewerEvidence: evidenceWithoutTiming,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleTiming(timing.reviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTiming: timing,
                    reviewerEvidence: suffixCollisionTimingEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingResultBundleTiming(timing.reviewerEvidenceTokens))
        }

        let signedSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTiming: timing,
            capturedAt: capturedAt
        ).signed()
        let tamperedTimingSubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: signedSubmission.resultBundleSHA256,
            resultBundleSummarySHA256: signedSubmission.resultBundleSummarySHA256,
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: signedSubmission.resultBundleMetrics,
            resultBundleTestContract: signedSubmission.resultBundleTestContract,
            resultBundleTiming: BracketerPhysicalResultBundleTiming(
                summaryStartTime: timing.summaryStartTime,
                summaryFinishTime: timing.summaryFinishTime,
                testStartTime: timing.testStartTime.addingTimeInterval(-1),
                testFinishTime: timing.testFinishTime
            ),
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )
        #expect(!tamperedTimingSubmission.hasValidAttachmentSignature)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedTimingSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleTiming: timing,
                reviewerEvidence: evidenceWithoutTiming,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo result-bundle timing metadata: \(timing.reviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(preview.recordedProofPreview == nil)
        #expect(preview.indexEntryPreview == nil)
    }

    @Test func physicalProofIngestorRejectsMissingInvalidAndUnboundAttachmentManifest() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_961_020)
        let filename = "Bracketer-\(runbook.id)-physical.xcresult"
        let bundleDigest = String(repeating: "a", count: 64)
        let summaryDigest = String(repeating: "d", count: 64)
        let contract = physicalProofResultBundleTestContract(for: runbook)
        let timing = physicalProofResultBundleTiming(around: capturedAt)
        let manifest = physicalProofAttachmentManifest(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleTestContract: contract,
            resultBundleTiming: timing
        )
        let firstArtifact = try #require(runbook.expectedArtifacts.first)
        func manifestWith(
            resultBundleFilename: String? = nil,
            resultBundleTestIdentifier: String? = nil,
            testStartTime: Date? = nil,
            testFinishTime: Date? = nil,
            artifactSHA256ByID: [String: String]? = nil,
            artifactByteCountByID: [String: Int]? = nil
        ) -> BracketerPhysicalAttachmentManifest {
            BracketerPhysicalAttachmentManifest(
                resultBundleFilename: resultBundleFilename ?? manifest.resultBundleFilename,
                resultBundleTestIdentifier: resultBundleTestIdentifier ?? manifest.resultBundleTestIdentifier,
                testStartTime: testStartTime ?? manifest.testStartTime,
                testFinishTime: testFinishTime ?? manifest.testFinishTime,
                artifactSHA256ByID: artifactSHA256ByID ?? manifest.artifactSHA256ByID,
                artifactByteCountByID: artifactByteCountByID ?? manifest.artifactByteCountByID
            )
        }
        let hashEvidenceValue = manifest.artifactSHA256ByID
            .sorted { $0.key < $1.key }
            .map { artifactID, digest in "artifact.\(artifactID).sha256=\(digest)" }
            .joined(separator: ", ")
        let evidenceWithoutManifest = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            attachmentManifest: manifest
        )
            .filter { !$0.contains("Attachment manifest hashes") }
        let evidenceWithoutArtifactHashes = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            attachmentManifest: manifest
        )
            .map { line in
                if line.contains("Attachment manifest hashes") {
                    return "Attachment manifest hashes: \(manifest.contextValue)"
                }
                return line
            }
        let evidenceWithoutByteCounts = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            attachmentManifest: manifest
        )
            .map { line in
                if line.contains("Attachment manifest hashes") {
                    return "Attachment manifest hashes: \(manifest.contextValue), \(hashEvidenceValue)"
                }
                return line
            }
        let suffixCollisionManifestEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            attachmentManifest: manifest
        )
            .map { line in
                if line.contains("Attachment manifest hashes") {
                    return "Attachment manifest hashes: \(manifest.contextValue), "
                        + manifest.artifactSHA256ByID
                            .sorted { $0.key < $1.key }
                            .map { artifactID, digest in "artifact.\(artifactID).sha256=\(digest)0" }
                            .joined(separator: ", ")
                }
                return line
            }
        let suffixCollisionByteCountEvidence = physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            attachmentManifest: manifest
        )
            .map { line in
                if line.contains("Attachment manifest hashes") {
                    return "Attachment manifest hashes: \(manifest.contextValue), \(hashEvidenceValue), "
                        + manifest.artifactByteCountByID
                            .sorted { $0.key < $1.key }
                            .map { artifactID, byteCount in "artifact.\(artifactID).bytes=\(byteCount)0" }
                            .joined(separator: ", ")
                }
                return line
            }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    omitAttachmentManifest: true,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .missingAttachmentManifest)
        }

        for (invalidContextManifest, expectedReason) in [
            (
                manifestWith(resultBundleFilename: "Bracketer-\(runbook.id)-physical-other.xcresult"),
                "resultBundleFilename must match the submitted result-bundle filename"
            ),
            (
                manifestWith(resultBundleTestIdentifier: "BracketerPhysicalCaptureTests/testOtherScenarioPhysicalCapture"),
                "resultBundleTestIdentifier must match the signed result-bundle test identifier"
            ),
            (
                manifestWith(testStartTime: timing.testStartTime.addingTimeInterval(-1)),
                "testStartTime must match result-bundle timing metadata"
            ),
            (
                manifestWith(testFinishTime: timing.testFinishTime.addingTimeInterval(1)),
                "testFinishTime must match result-bundle timing metadata"
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        resultBundleTestContract: contract,
                        resultBundleTiming: timing,
                        attachmentManifest: invalidContextManifest,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            resultBundleTestContract: contract,
                            resultBundleTiming: timing,
                            attachmentManifest: invalidContextManifest
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidAttachmentManifestContext(expectedReason))
            }
        }

        for (invalidManifest, expectedReason) in [
            (
                manifestWith(artifactSHA256ByID: [:]),
                "artifactSHA256ByID must not be empty"
            ),
            (
                manifestWith(
                    artifactSHA256ByID: Dictionary(
                        uniqueKeysWithValues: manifest.artifactSHA256ByID.filter { $0.key != firstArtifact }
                    )
                ),
                "missing expected artifact hashes: \(firstArtifact)"
            ),
            (
                manifestWith(
                    artifactSHA256ByID: manifest.artifactSHA256ByID.merging([
                        "unexpected-artifact": String(repeating: "f", count: 64)
                    ]) { current, _ in current }
                ),
                "unexpected artifact ids: unexpected-artifact"
            ),
            (
                manifestWith(
                    artifactSHA256ByID: manifest.artifactSHA256ByID.merging([
                        firstArtifact: "not-a-digest"
                    ]) { _, new in new }
                ),
                "artifact \(firstArtifact) must have a SHA-256 hex digest"
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        attachmentManifest: invalidManifest,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            attachmentManifest: invalidManifest
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == .invalidAttachmentManifest(expectedReason))
            }
        }

        for (invalidManifest, expectedError) in [
            (
                manifestWith(artifactByteCountByID: [:]),
                BracketerPhysicalProofIngestor.ValidationFailure.invalidAttachmentManifestByteCounts("artifactByteCountByID must not be empty")
            ),
            (
                manifestWith(
                    artifactByteCountByID: Dictionary(
                        uniqueKeysWithValues: manifest.artifactByteCountByID.filter { $0.key != firstArtifact }
                    )
                ),
                .invalidAttachmentManifestByteCounts("missing expected artifact byte counts: \(firstArtifact)")
            ),
            (
                manifestWith(
                    artifactByteCountByID: manifest.artifactByteCountByID.merging([
                        "unexpected-artifact": 1
                    ]) { current, _ in current }
                ),
                .invalidAttachmentManifestByteCounts("unexpected artifact byte-count ids: unexpected-artifact")
            ),
            (
                manifestWith(
                    artifactByteCountByID: manifest.artifactByteCountByID.merging([
                        firstArtifact: 0
                    ]) { _, new in new }
                ),
                .invalidAttachmentManifestByteCounts("artifact \(firstArtifact) must have a positive byte count")
            ),
            (
                manifestWith(
                    artifactByteCountByID: manifest.artifactByteCountByID.merging([
                        firstArtifact: (manifest.artifactByteCountByID[firstArtifact] ?? 0) + 1
                    ]) { _, new in new }
                ),
                .attachmentManifestByteCountMismatch(
                    expectedBytes: 4096,
                    manifestBytes: manifest.totalArtifactByteCount + 1
                )
            )
        ] {
            do {
                _ = try BracketerPhysicalProofIngestor.ingest(
                    try validPhysicalProofSubmission(
                        for: runbook,
                        resultBundleFilename: filename,
                        resultBundleSHA256: bundleDigest,
                        resultBundleSummarySHA256: summaryDigest,
                        attachmentManifest: invalidManifest,
                        reviewerEvidence: physicalProofReviewerEvidence(
                            for: runbook,
                            capturedAt: capturedAt,
                            resultBundleFilename: filename,
                            resultBundleSHA256: bundleDigest,
                            resultBundleSummarySHA256: summaryDigest,
                            attachmentManifest: invalidManifest
                        ),
                        capturedAt: capturedAt
                    ).signed(),
                    catalog: catalog
                )
                #expect(Bool(false))
            } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
                #expect(error == expectedError)
            }
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    attachmentManifest: manifest,
                    reviewerEvidence: evidenceWithoutManifest,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingAttachmentManifestContext(manifest.contextReviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    resultBundleTiming: timing,
                    attachmentManifest: manifest,
                    reviewerEvidence: evidenceWithoutArtifactHashes,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingAttachmentManifest(manifest.artifactReviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    resultBundleTiming: timing,
                    attachmentManifest: manifest,
                    reviewerEvidence: evidenceWithoutByteCounts,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingAttachmentManifestByteCounts(manifest.artifactByteCountReviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    resultBundleTiming: timing,
                    attachmentManifest: manifest,
                    reviewerEvidence: suffixCollisionByteCountEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingAttachmentManifestByteCounts(manifest.artifactByteCountReviewerEvidenceTokens))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: filename,
                    resultBundleSHA256: bundleDigest,
                    resultBundleSummarySHA256: summaryDigest,
                    resultBundleTestContract: contract,
                    resultBundleTiming: timing,
                    attachmentManifest: manifest,
                    reviewerEvidence: suffixCollisionManifestEvidence,
                    capturedAt: capturedAt
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .reviewerEvidenceMissingAttachmentManifest(manifest.artifactReviewerEvidenceTokens))
        }

        let signedSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: filename,
            resultBundleSHA256: bundleDigest,
            resultBundleSummarySHA256: summaryDigest,
            resultBundleTestContract: contract,
            resultBundleTiming: timing,
            attachmentManifest: manifest,
            capturedAt: capturedAt
        ).signed()
        let tamperedManifestSubmission = BracketerPhysicalProofSubmission(
            scenarioID: signedSubmission.scenarioID,
            resultBundleFilename: signedSubmission.resultBundleFilename,
            resultBundleSHA256: signedSubmission.resultBundleSHA256,
            resultBundleSummarySHA256: signedSubmission.resultBundleSummarySHA256,
            resultBundleSummary: signedSubmission.resultBundleSummary,
            resultBundleMetrics: signedSubmission.resultBundleMetrics,
            resultBundleTestContract: signedSubmission.resultBundleTestContract,
            resultBundleTiming: signedSubmission.resultBundleTiming,
            attachmentManifest: manifestWith(
                artifactSHA256ByID: manifest.artifactSHA256ByID.merging([
                    firstArtifact: String(repeating: "e", count: 64)
                ]) { _, new in new }
            ),
            xcodeDestination: signedSubmission.xcodeDestination,
            deviceModelIdentifier: signedSubmission.deviceModelIdentifier,
            hashedDeviceIdentifier: signedSubmission.hashedDeviceIdentifier,
            iosBuild: signedSubmission.iosBuild,
            capturedAt: signedSubmission.capturedAt,
            lensID: signedSubmission.lensID,
            manifestSnapshotSHA256: signedSubmission.manifestSnapshotSHA256,
            providedArtifactIDs: signedSubmission.providedArtifactIDs,
            reviewerEvidence: signedSubmission.reviewerEvidence,
            notes: signedSubmission.notes,
            attachmentSignature: signedSubmission.attachmentSignature
        )
        #expect(!tamperedManifestSubmission.hasValidAttachmentSignature)
        do {
            _ = try BracketerPhysicalProofIngestor.ingest(tamperedManifestSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidAttachmentSignature)
        }

        let preview = BracketerPhysicalProofIngestor.preview(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: filename,
                resultBundleSHA256: bundleDigest,
                resultBundleSummarySHA256: summaryDigest,
                resultBundleTestContract: contract,
                resultBundleTiming: timing,
                attachmentManifest: manifest,
                reviewerEvidence: evidenceWithoutManifest,
                capturedAt: capturedAt
            ).signed(),
            catalog: catalog
        )
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof reviewer evidence must echo attachment manifest result-bundle context: \(manifest.contextReviewerEvidenceTokens.joined(separator: ", "))."))
        #expect(preview.recordedProofPreview == nil)
        #expect(preview.indexEntryPreview == nil)
    }

    @Test func physicalProofIngestorRejectsScenarioMismatchedResultBundleFilenames() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let otherRunbook = try #require(catalog.runbooks.dropFirst().first)

        let acceptedRerun = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(
                for: runbook,
                resultBundleFilename: "Bracketer-\(runbook.id)-physical-rerun-02.xcresult"
            ).signed(),
            catalog: catalog
        )
        #expect(acceptedRerun.recordedProof.resultBundleFilename == "Bracketer-\(runbook.id)-physical-rerun-02.xcresult")

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: "Bracketer-physical.xcresult"
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .resultBundleFilenameScenarioMismatch(
                filename: "Bracketer-physical.xcresult",
                expectedPrefix: "Bracketer-\(runbook.id)-physical"
            ))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: "Bracketer-\(otherRunbook.id)-physical.xcresult"
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .resultBundleFilenameScenarioMismatch(
                filename: "Bracketer-\(otherRunbook.id)-physical.xcresult",
                expectedPrefix: "Bracketer-\(runbook.id)-physical"
            ))
        }

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(
                try validPhysicalProofSubmission(
                    for: runbook,
                    resultBundleFilename: "nested/Bracketer-\(runbook.id)-physical.xcresult"
                ).signed(),
                catalog: catalog
            )
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .invalidResultBundleFilename("nested/Bracketer-\(runbook.id)-physical.xcresult"))
        }
    }

    @Test func physicalProofIngestorRejectsUnreplacedTemplatePlaceholders() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let template = BracketerPhysicalProofSubmission.template(for: runbook)
        let resultBundleTestContract = physicalProofResultBundleTestContract(for: runbook)
        let resultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let retainedPlaceholderSubmission = try BracketerPhysicalProofSubmission(
            scenarioID: template.scenarioID,
            resultBundleFilename: template.resultBundleFilename,
            resultBundleSHA256: String(repeating: "a", count: 64),
            resultBundleSummarySHA256: String(repeating: "d", count: 64),
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 164,
                passedTests: 164,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: physicalProofResultBundleTiming(around: Date(timeIntervalSince1970: 50)),
            xcodeDestination: "platform=iOS,id=IPHONE-123",
            deviceModelIdentifier: "iPhone17,1",
            hashedDeviceIdentifier: String(repeating: "c", count: 64),
            iosBuild: "26.4.1",
            capturedAt: Date(timeIntervalSince1970: 50),
            lensID: nil,
            manifestSnapshotSHA256: String(repeating: "b", count: 64),
            providedArtifactIDs: template.providedArtifactIDs,
            reviewerEvidence: template.reviewerEvidence,
            notes: "Lab reviewer replaced device labels and digests."
        ).signed()

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(retainedPlaceholderSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .templatePlaceholderRetained(
                field: "reviewerEvidence[0]",
                marker: "REPLACE_AFTER_PHYSICAL_RUN"
            ))
        }

        let retainedDeviceModelSubmission = try BracketerPhysicalProofSubmission(
            scenarioID: template.scenarioID,
            resultBundleFilename: template.resultBundleFilename,
            resultBundleSHA256: String(repeating: "a", count: 64),
            resultBundleSummarySHA256: String(repeating: "d", count: 64),
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 164,
                passedTests: 164,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: physicalProofResultBundleTiming(around: Date(timeIntervalSince1970: 50)),
            xcodeDestination: "platform=iOS,id=IPHONE-123",
            deviceModelIdentifier: template.deviceModelIdentifier,
            hashedDeviceIdentifier: String(repeating: "c", count: 64),
            iosBuild: "26.4.1",
            capturedAt: Date(timeIntervalSince1970: 50),
            lensID: nil,
            manifestSnapshotSHA256: String(repeating: "b", count: 64),
            providedArtifactIDs: template.providedArtifactIDs,
            reviewerEvidence: runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" },
            notes: "Lab reviewer replaced every template field except the iPhone model identifier."
        ).signed()

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(retainedDeviceModelSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .templatePlaceholderRetained(
                field: "deviceModelIdentifier",
                marker: "REPLACE_WITH_"
            ))
        }

        let preview = BracketerPhysicalProofIngestor.preview(retainedPlaceholderSubmission, catalog: catalog)
        #expect(!preview.accepted)
        #expect(preview.rejectionReasons.contains("Physical proof submission retains unreplaced template placeholder in reviewerEvidence[0]: REPLACE_AFTER_PHYSICAL_RUN."))

        let cleanedCapturedAt = Date(timeIntervalSince1970: 1_779_960_240)
        let retainedDestinationSubmission = try BracketerPhysicalProofSubmission(
            scenarioID: template.scenarioID,
            resultBundleFilename: template.resultBundleFilename,
            resultBundleSHA256: String(repeating: "a", count: 64),
            resultBundleSummarySHA256: String(repeating: "d", count: 64),
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 164,
                passedTests: 164,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTestContract: resultBundleTestContract,
            xcodeDestination: template.xcodeDestination,
            deviceModelIdentifier: "iPhone17,1",
            hashedDeviceIdentifier: String(repeating: "c", count: 64),
            iosBuild: "26.4.1",
            capturedAt: Date(timeIntervalSince1970: 50),
            lensID: "wide-camera",
            manifestSnapshotSHA256: String(repeating: "b", count: 64),
            providedArtifactIDs: template.providedArtifactIDs,
            reviewerEvidence: runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" },
            notes: "Lab reviewer replaced evidence and digest fields."
        ).signed()

        do {
            _ = try BracketerPhysicalProofIngestor.ingest(retainedDestinationSubmission, catalog: catalog)
            #expect(Bool(false))
        } catch let error as BracketerPhysicalProofIngestor.ValidationFailure {
            #expect(error == .templatePlaceholderRetained(
                field: "xcodeDestination",
                marker: "<DEVICE-UDID>"
            ))
        }

        let cleanedResultBundleTiming = physicalProofResultBundleTiming(around: cleanedCapturedAt)
        let cleanedAttachmentManifest = physicalProofAttachmentManifest(
            for: runbook,
            resultBundleFilename: template.resultBundleFilename,
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: cleanedResultBundleTiming
        )
        let cleanedSubmission = try BracketerPhysicalProofSubmission(
            scenarioID: template.scenarioID,
            resultBundleFilename: template.resultBundleFilename,
            resultBundleSHA256: String(repeating: "a", count: 64),
            resultBundleSummarySHA256: String(repeating: "d", count: 64),
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 164,
                passedTests: 164,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTestContract: resultBundleTestContract,
            resultBundleTiming: cleanedResultBundleTiming,
            resultBundleDevice: physicalProofResultBundleDevice(),
            attachmentManifest: cleanedAttachmentManifest,
            xcodeDestination: "platform=iOS,id=IPHONE-123",
            deviceModelIdentifier: "iPhone17,1",
            hashedDeviceIdentifier: String(repeating: "c", count: 64),
            iosBuild: "26.4.1",
            capturedAt: cleanedCapturedAt,
            lensID: "wide-camera",
            manifestSnapshotSHA256: String(repeating: "b", count: 64),
            providedArtifactIDs: template.providedArtifactIDs,
            reviewerEvidence: physicalProofReviewerEvidence(
                for: runbook,
                capturedAt: cleanedCapturedAt,
                resultBundleFilename: template.resultBundleFilename,
                resultBundleSHA256: String(repeating: "a", count: 64),
                resultBundleTestContract: resultBundleTestContract,
                resultBundleTiming: cleanedResultBundleTiming,
                attachmentManifest: cleanedAttachmentManifest
            ),
            notes: "Lab reviewer replaced all template fields."
        ).signed()
        let result = try BracketerPhysicalProofIngestor.ingest(cleanedSubmission, catalog: catalog)

        #expect(result.catalog.capturedRunbookCount == 1)
        #expect(result.resultBundleIndex.indexedCount == 1)
    }

    @Test func physicalProofSubmissionCodablePreservesScenarioSchemaAndDigest() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let submission = validPhysicalProofSubmission(for: runbook)

        let data = try JSONEncoder().encode(submission)
        let decoded = try JSONDecoder().decode(BracketerPhysicalProofSubmission.self, from: data)

        #expect(decoded.schemaVersion == BracketerPhysicalProofSubmission.schemaVersion)
        #expect(decoded.scenarioID == runbook.id)
        #expect(decoded.resultBundleSHA256 == String(repeating: "a", count: 64))
        #expect(decoded.resultBundleSummarySHA256 == String(repeating: "d", count: 64))
        #expect(decoded.resultBundleSummary?.status == .passed)
        #expect(decoded.resultBundleSummary?.title == "Test - Bracketer")
        #expect(decoded.resultBundleSummary?.totalTestCount == 164)
        #expect(decoded.resultBundleSummary?.passedTestCount == 164)
        #expect(decoded.resultBundleSummary?.failedTestCount == 0)
        #expect(decoded.resultBundleSummary?.expectedFailureCount == 0)
        #expect(decoded.resultBundleSummary?.skippedTestCount == 0)
        #expect(decoded.resultBundleMetrics?.totalTestCount == 164)
        #expect(decoded.resultBundleMetrics?.durationMilliseconds == 60_000)
        #expect(decoded.resultBundleTestContract?.xcodebuildVersion == "Xcode 26.5 Build version 17F42")
        #expect(decoded.resultBundleTestContract?.testIdentifier.contains(runbook.id) == true)
        #expect(decoded.resultBundleTiming?.testStartTime == submission.capturedAt.addingTimeInterval(-30))
        #expect(decoded.resultBundleDevice == physicalProofResultBundleDevice())
        #expect(decoded.attachmentManifest?.artifactSHA256ByID.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(decoded.attachmentManifest?.artifactByteCountByID.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(decoded.attachmentManifest?.totalArtifactByteCount == 4096)
        #expect(decoded.hashedDeviceIdentifier == String(repeating: "c", count: 64))
        #expect(decoded == submission)
    }

    @Test func physicalProofIngestReadinessExposesVisibleContractWithoutClaimingProof() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let defaultReadiness = BracketerPhysicalProofIngestReadiness.make(catalog: catalog)

        #expect(defaultReadiness.schemaVersion == BracketerPhysicalProofIngestReadiness.schemaVersion)
        #expect(defaultReadiness.schemaVersion == 26)
        #expect(defaultReadiness.acceptedScenarioCount == 0)
        #expect(defaultReadiness.requiredScenarioCount == 8)
        #expect(defaultReadiness.summaryValue.contains("Physical Proof Ingestor"))
        #expect(defaultReadiness.summaryValue.contains("0 of 8 physical submissions accepted"))
        #expect(defaultReadiness.summaryValue.contains("Real iPhone artifacts required"))
        #expect(defaultReadiness.accessibilityValue.contains("valid attachment signature"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid attachment signature"))
        #expect(defaultReadiness.accessibilityValue.contains("physical platform=iOS destination id"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario-bound result-bundle filename"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("typed result-bundle summary"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary status"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary title"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary total test count"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary passed test count"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary failed test count"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary counts match metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("xcresulttool compact test-results summary JSON"))
        #expect(defaultReadiness.accessibilityValue.contains("parsed result-bundle proof input"))
        #expect(defaultReadiness.accessibilityValue.contains("xcresulttool command plan"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle digest command plan"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario-bound result-bundle path"))
        #expect(defaultReadiness.accessibilityValue.contains("top-level xcresult summary counts"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle test contract"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle timing metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle device/platform metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("physical xcresult platform"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle iOS build matches submission"))
        #expect(defaultReadiness.accessibilityValue.contains("per-artifact attachment manifest SHA-256 values"))
        #expect(defaultReadiness.accessibilityValue.contains("per-artifact attachment manifest byte counts"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest result-bundle filename"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest scenario test identifier"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest test start and finish time"))
        #expect(defaultReadiness.accessibilityValue.contains("xcodebuild version"))
        #expect(defaultReadiness.accessibilityValue.contains("xcresulttool version"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario-bound test identifier"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary start and finish time"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario test start and finish time"))
        #expect(defaultReadiness.accessibilityValue.contains("capturedAt inside result-bundle test window"))
        #expect(defaultReadiness.accessibilityValue.contains("manifest snapshot SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("physical capturedAt timestamp"))
        #expect(defaultReadiness.accessibilityValue.contains("capturedAt timestamp in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle filename in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle SHA-256 in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary SHA-256 in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("typed result-bundle summary in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle metrics in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle test contract in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle timing metadata in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle device metadata in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest result-bundle context in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest hashes in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest byte counts in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("passing result-bundle summary in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("hashed device identifier in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("device model identifier in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("iOS build label in reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle filename for a different scenario"))
        #expect(defaultReadiness.accessibilityValue.contains("iPhone model identifier (iPhoneN,M)"))
        #expect(defaultReadiness.accessibilityValue.contains("non-iPhone model identifier"))
        #expect(defaultReadiness.accessibilityValue.contains("iOS version or build label"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid iOS build label"))
        #expect(defaultReadiness.accessibilityValue.contains("missing expected artifacts"))
        #expect(defaultReadiness.accessibilityValue.contains("missing result-bundle summary SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("missing typed result-bundle summary"))
        #expect(defaultReadiness.accessibilityValue.contains("missing result-bundle metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("missing result-bundle test contract"))
        #expect(defaultReadiness.accessibilityValue.contains("missing result-bundle timing metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("missing result-bundle device metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("missing attachment manifest hashes"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary SHA-256 equals bundle SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid typed result-bundle summary"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle summary counts disagree with metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid xcresulttool compact summary JSON"))
        #expect(defaultReadiness.accessibilityValue.contains("xcresulttool summary timing window invalid"))
        #expect(defaultReadiness.accessibilityValue.contains("non-.xcresult result-bundle path"))
        #expect(defaultReadiness.accessibilityValue.contains("unsafe result-bundle path"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario bundle name mismatch"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid result-bundle metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid result-bundle test contract"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid result-bundle timing metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid result-bundle device metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("simulator result-bundle platform"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle device metadata disagrees with submission"))
        #expect(defaultReadiness.accessibilityValue.contains("result-bundle duration disagrees with test window"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid attachment manifest context"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid attachment manifest hashes"))
        #expect(defaultReadiness.accessibilityValue.contains("invalid attachment manifest byte counts"))
        #expect(defaultReadiness.accessibilityValue.contains("attachment manifest byte count disagrees with result-bundle metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("capturedAt outside result-bundle test window"))
        #expect(defaultReadiness.accessibilityValue.contains("scenario-bound reviewer evidence"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing scenario descriptors"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing capturedAt timestamp"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle filename"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle summary SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing typed result-bundle summary"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle metrics"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle test contract"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle timing metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing result-bundle device metadata"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing attachment manifest context"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing attachment manifest hashes"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing attachment manifest byte counts"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing passing result-bundle summary"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing hashed device identifier"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing device model identifier"))
        #expect(defaultReadiness.accessibilityValue.contains("reviewer evidence missing iOS build label"))
        #expect(defaultReadiness.accessibilityValue.contains("stale capturedAt timestamp"))
        #expect(defaultReadiness.accessibilityValue.contains("future capturedAt timestamp"))
        #expect(defaultReadiness.accessibilityValue.contains("missing manifest snapshot SHA-256"))
        #expect(defaultReadiness.accessibilityValue.contains("simulator destination"))
        #expect(defaultReadiness.accessibilityValue.contains("unreplaced template placeholder"))
        #expect(defaultReadiness.accessibilityValue.contains("Photos local identifiers"))
        #expect(defaultReadiness.privacyBoundary.contains("contract text only"))
        #expect(!defaultReadiness.accessibilityValue.contains("Physical proof captured"))

        let runbook = try #require(catalog.runbooks.first)
        let ingestResult = try BracketerPhysicalProofIngestor.ingest(
            try validPhysicalProofSubmission(for: runbook).signed(),
            catalog: catalog
        )
        let acceptedReadiness = BracketerPhysicalProofIngestReadiness.make(
            catalog: ingestResult.catalog,
            resultBundleIndex: ingestResult.resultBundleIndex
        )

        #expect(acceptedReadiness.acceptedScenarioCount == 1)
        #expect(acceptedReadiness.summaryValue.contains("1 of 8 physical submissions accepted"))

        let encoder = JSONEncoder()
        #expect(try JSONDecoder().decode(BracketerPhysicalProofIngestReadiness.self, from: encoder.encode(defaultReadiness)) == defaultReadiness)
    }

    @Test func physicalProofSubmissionTemplateDocumentAndPreviewRejectPlaceholders() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let template = BracketerPhysicalProofSubmission.template(for: runbook)
        let signedTemplate = try template.signed()
        let document = try BracketerPhysicalProofSubmissionDocument(
            submission: signedTemplate,
            filename: "template.json"
        )
        let roundTrip = try BracketerPhysicalProofSubmissionDocument(
            data: document.data,
            filename: document.filename
        )

        #expect(roundTrip.submission == signedTemplate)
        #expect(document.documentText.contains("platform=iOS,id=<DEVICE-UDID>"))
        #expect(document.documentText.contains("REPLACE_WITH_IPHONE_MODEL_IDENTIFIER_LIKE_iPhone17,1"))
        #expect(document.documentText.contains(runbook.expectedArtifacts.first ?? "missing-artifact"))
        #expect(document.accessibilityValue.contains("physical-device-proof preview only"))
        #expect(!document.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!document.documentText.lowercased().contains("rawimagebytes"))
        #expect(!document.documentText.lowercased().contains("precisecoordinates"))

        let preview = BracketerPhysicalProofIngestor.preview(signedTemplate, catalog: catalog)

        #expect(!preview.accepted)
        #expect(preview.summaryValue.contains("physical-device-proof preview only"))
        #expect(preview.rejectionReasons.contains("Physical proof field resultBundleSHA256 must be a SHA-256 hex digest."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestPreviewAcceptsSignedSubmissionWithoutMutatingInputs() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let index = BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks)
        let runbook = try #require(catalog.runbooks.first)
        let submission = try validPhysicalProofSubmission(for: runbook).signed()

        let preview = BracketerPhysicalProofIngestor.preview(
            submission,
            catalog: catalog,
            resultBundleIndex: index
        )

        #expect(preview.accepted)
        #expect(preview.proofCategory == "physical-device-proof preview only")
        #expect(preview.recordedProofPreview?.resultBundleSHA256 == String(repeating: "a", count: 64))
        #expect(preview.indexEntryPreview?.scenarioID == runbook.id)
        #expect(preview.accessibilityValue.contains("Preview does not mutate"))
        #expect(!preview.accessibilityValue.contains("Physical proof captured"))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(index.indexedCount == 0)

        let readiness = BracketerPhysicalProofIngestReadiness.make(
            catalog: catalog,
            resultBundleIndex: index
        )
        #expect(readiness.summaryValue.contains("0 of 8 physical submissions accepted"))
    }

    @Test func physicalProofIngestPreviewRejectsUnsignedSimulatorAndPrivateSubmissions() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)

        let unsignedPreview = BracketerPhysicalProofIngestor.preview(
            validPhysicalProofSubmission(for: runbook),
            catalog: catalog
        )
        #expect(!unsignedPreview.accepted)
        #expect(unsignedPreview.rejectionReasons == ["Physical proof submission preview requires a valid attachment signature."])

        let simulatorSubmission = try validPhysicalProofSubmission(
            for: runbook,
            xcodeDestination: "platform=iOS Simulator,id=SIM-123"
        ).signed()
        let simulatorPreview = BracketerPhysicalProofIngestor.preview(simulatorSubmission, catalog: catalog)
        #expect(!simulatorPreview.accepted)
        #expect(simulatorPreview.rejectionReasons.contains("Simulator destination cannot be ingested as physical proof: platform=iOS Simulator,id=SIM-123."))

        let privateSubmission = try validPhysicalProofSubmission(
            for: runbook,
            reviewerEvidence: ["PreciseCoordinates latitude: 37.7 longitude: -122.4"]
        ).signed()
        let privatePreview = BracketerPhysicalProofIngestor.preview(privateSubmission, catalog: catalog)
        #expect(!privatePreview.accepted)
        #expect(privatePreview.rejectionReasons.contains("Physical proof submission contains forbidden private data marker: precisecoordinates."))
    }

    @Test func physicalProofSubmissionDocumentRejectsUnreadableAndUnsupportedFiles() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let signedSubmission = try validPhysicalProofSubmission(for: runbook).signed()
        let document = try BracketerPhysicalProofSubmissionDocument(submission: signedSubmission)

        #expect(BracketerPhysicalProofSubmissionDocument.readableContentTypes == [.plainText, .json])
        #expect(BracketerPhysicalProofSubmissionDocument.writableContentTypes == [.json])
        #expect(try BracketerPhysicalProofSubmissionDocument(data: document.data).submission == signedSubmission)

        do {
            _ = try BracketerPhysicalProofSubmissionDocument(
                data: Data([0xff, 0xfe, 0xfd]),
                filename: "bad-proof.json"
            )
            #expect(Bool(false))
        } catch BracketerPhysicalProofSubmissionDocumentError.unreadableUTF8(let filename) {
            #expect(filename == "bad-proof.json")
        }

        do {
            _ = try BracketerPhysicalProofSubmissionDocument(
                submission: validPhysicalProofSubmission(for: runbook, schemaVersion: 99)
            )
            #expect(Bool(false))
        } catch BracketerPhysicalProofSubmissionDocumentError.unsupportedSchemaVersion(let version) {
            #expect(version == 99)
        }
    }

    @Test func physicalProofPreviewFileProviderReturnsPreviewOnlyDialog() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let signedSubmission = try validPhysicalProofSubmission(for: runbook).signed()
        let document = try BracketerPhysicalProofSubmissionDocument(submission: signedSubmission)
        let intentFile = IntentFile(data: document.data, filename: document.filename, type: .json)

        let result = try BracketerPhysicalProofPreviewFileProvider().previewFile(
            intentFile,
            catalog: catalog
        )

        #expect(result.preview.accepted)
        #expect(result.dialogText.contains("physical-device-proof preview only"))
        #expect(result.dialogText.contains("No physical proof count changed"))
        #expect(result.accessibilityValue.contains(document.filename))
    }

    @Test func physicalProofPreviewFileProviderSeedsTemplateFromParsedProofInput() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let capturedAt = Date(timeIntervalSince1970: 1_779_960_690)
        let proofInput = BracketerPhysicalResultBundleProofInput(
            resultBundleSummary: BracketerPhysicalResultBundleSummary(
                status: .passed,
                title: "Test - Bracketer",
                totalTestCount: 168,
                passedTestCount: 168,
                failedTestCount: 0,
                expectedFailureCount: 0,
                skippedTestCount: 0
            ),
            resultBundleMetrics: BracketerPhysicalResultBundleMetrics(
                totalTestCount: 168,
                passedTests: 168,
                failedTests: 0,
                durationMilliseconds: 60_000,
                attachmentByteCount: 4096
            ),
            resultBundleTiming: BracketerPhysicalResultBundleTiming.window(around: capturedAt),
            testPlanConfigurationName: "Test Scheme Action",
            environmentDescription: "Bracketer physical lab seed",
            deviceName: "Physical iPhone",
            deviceModelName: "iPhone 17",
            osVersion: "26.4.1",
            osBuildNumber: "23E254a",
            platform: "iOS"
        )
        let seededDocument = try BracketerPhysicalProofSubmissionDocument(
            templateFor: runbook,
            proofInput: proofInput
        )

        #expect(seededDocument.filename == "Bracketer-\(runbook.id)-physical-proof-seeded-template.json")
        #expect(seededDocument.documentText.contains("Test - Bracketer"))
        #expect(seededDocument.documentText.contains("metrics.totalTestCount=168"))
        #expect(seededDocument.documentText.contains("xcresult.model=iPhone 17"))
        #expect(seededDocument.documentText.contains("xcresult.osVersion=26.4.1"))
        #expect(seededDocument.documentText.contains("Attachment manifest hashes"))
        #expect(seededDocument.documentText.contains("metrics.attachmentByteCount=4096"))
        #expect(seededDocument.documentText.contains("attachment.totalBytes=0"))
        #expect(seededDocument.documentText.contains("REPLACE_WITH_HASHED_DEVICE_IDENTIFIER"))
        let seededArtifactByteCounts = try #require(seededDocument.submission.attachmentManifest?.artifactByteCountByID)
        #expect(seededArtifactByteCounts.keys.sorted() == runbook.expectedArtifacts.sorted())
        #expect(seededArtifactByteCounts.values.allSatisfy { $0 == 0 })
        #expect(!seededDocument.documentText.lowercased().contains("phasset.localidentifier"))
        #expect(!seededDocument.documentText.lowercased().contains("rawimagebytes"))
        #expect(!seededDocument.documentText.lowercased().contains("precisecoordinates"))

        let compactSummaryJSON = """
        {
          "devicesAndConfigurations" : [
            {
              "device" : {
                "deviceName" : "Physical iPhone",
                "modelName" : "iPhone 17",
                "osBuildNumber" : "23E254a",
                "osVersion" : "26.4.1",
                "platform" : "iOS"
              },
              "testPlanConfiguration" : {
                "configurationName" : "Test Scheme Action"
              }
            }
          ],
          "environmentDescription" : "Bracketer physical lab seed",
          "expectedFailures" : 0,
          "failedTests" : 0,
          "finishTime" : 1779960720.0,
          "passedTests" : 168,
          "result" : "Passed",
          "skippedTests" : 0,
          "startTime" : 1779960660.0,
          "title" : "Test - Bracketer",
          "totalTestCount" : 168
        }
        """
        let compactSeededDocument = try BracketerPhysicalProofSubmissionDocument(
            prefillingTemplateFor: runbook,
            compactXCResultSummaryJSON: try #require(compactSummaryJSON.data(using: .utf8)),
            attachmentByteCount: 4096
        )
        #expect(compactSeededDocument.documentText.contains("metrics.attachmentByteCount=4096"))
        #expect(compactSeededDocument.documentText.contains("xcresult.platform=iOS"))

        let proofInputData = try JSONEncoder.bracketerPhysicalProofCanonical.encode(proofInput)
        let previewFile = try BracketerPhysicalProofPreviewFileProvider().previewData(
            proofInputData,
            filename: "Bracketer-\(runbook.id)-parsed-result-bundle-proof-input.json",
            catalog: catalog
        )

        #expect(previewFile.filename == seededDocument.filename)
        #expect(previewFile.dialogText.contains("parsed result-bundle proof input seeded physical proof submission template"))
        #expect(previewFile.accessibilityValue.contains("parsed result-bundle proof input seeded physical proof submission template"))
        #expect(!previewFile.preview.accepted)
        #expect(previewFile.preview.rejectionReasons.contains("Physical proof field resultBundleSHA256 must be a SHA-256 hex digest."))
        #expect(catalog.capturedRunbookCount == 0)
        #expect(BracketerPhysicalResultBundleIndex.make(runbooks: catalog.runbooks).indexedCount == 0)
    }

    @Test func physicalProofIngestorReplacesDuplicateScenarioIndexEntries() throws {
        let catalog = BracketerPhysicalCaptureRunbookCatalog.make()
        let runbook = try #require(catalog.runbooks.first)
        let firstSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: "Bracketer-\(runbook.id)-physical-first.xcresult",
            capturedAt: Date(timeIntervalSince1970: 1_779_960_300)
        ).signed()
        let firstResult = try BracketerPhysicalProofIngestor.ingest(firstSubmission, catalog: catalog)
        let secondSubmission = try validPhysicalProofSubmission(
            for: runbook,
            resultBundleFilename: "Bracketer-\(runbook.id)-physical-rerun.xcresult",
            capturedAt: Date(timeIntervalSince1970: 1_779_960_360)
        ).signed()

        let secondResult = try BracketerPhysicalProofIngestor.ingest(
            secondSubmission,
            catalog: firstResult.catalog,
            resultBundleIndex: firstResult.resultBundleIndex
        )

        #expect(secondResult.catalog.capturedRunbookCount == 1)
        #expect(secondResult.resultBundleIndex.indexedCount == 1)
        #expect(secondResult.resultBundleIndex.entries.count == 1)
        #expect(secondResult.resultBundleIndex.entries.first?.resultBundleFilename == "Bracketer-\(runbook.id)-physical-rerun.xcresult")
        #expect(secondResult.catalog.runbooks.first?.recordedProofs.count == 1)
        #expect(secondResult.catalog.runbooks.first?.recordedProofs.first?.resultBundleFilename == "Bracketer-\(runbook.id)-physical-rerun.xcresult")
    }

    private func validPhysicalProofSubmission(
        for runbook: BracketerPhysicalCaptureRunbook,
        schemaVersion: Int = BracketerPhysicalProofSubmission.schemaVersion,
        resultBundleFilename: String? = nil,
        resultBundleSHA256: String = String(repeating: "a", count: 64),
        resultBundleSummarySHA256: String? = String(repeating: "d", count: 64),
        resultBundleSummary: BracketerPhysicalResultBundleSummary? = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        ),
        resultBundleMetrics: BracketerPhysicalResultBundleMetrics? = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        ),
        resultBundleTestContract: BracketerPhysicalResultBundleTestContract? = nil,
        omitResultBundleTestContract: Bool = false,
        resultBundleTiming: BracketerPhysicalResultBundleTiming? = nil,
        omitResultBundleTiming: Bool = false,
        resultBundleDevice: BracketerPhysicalResultBundleDevice? = nil,
        omitResultBundleDevice: Bool = false,
        attachmentManifest: BracketerPhysicalAttachmentManifest? = nil,
        omitAttachmentManifest: Bool = false,
        xcodeDestination: String = "platform=iOS,id=IPHONE-123",
        deviceModelIdentifier: String = "iPhone17,1",
        hashedDeviceIdentifier: String = String(repeating: "c", count: 64),
        iosBuild: String = "26.4.1",
        manifestSnapshotSHA256: String? = String(repeating: "b", count: 64),
        providedArtifactIDs: [String]? = nil,
        reviewerEvidence: [String]? = nil,
        capturedAt: Date = Date(timeIntervalSince1970: 1_779_960_000)
    ) -> BracketerPhysicalProofSubmission {
        let resolvedResultBundleFilename = resultBundleFilename ?? "Bracketer-\(runbook.id)-physical.xcresult"
        let defaultResultBundleMetrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        )
        let resolvedResultBundleMetrics = resultBundleMetrics ?? defaultResultBundleMetrics
        let defaultResultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: resolvedResultBundleMetrics.totalTestCount,
            passedTestCount: resolvedResultBundleMetrics.passedTests,
            failedTestCount: resolvedResultBundleMetrics.failedTests,
            expectedFailureCount: 0,
            skippedTestCount: 0
        )
        let resolvedResultBundleSummary = resultBundleSummary ?? defaultResultBundleSummary
        let defaultResultBundleTestContract = physicalProofResultBundleTestContract(for: runbook)
        let resolvedResultBundleTestContract = omitResultBundleTestContract
            ? nil
            : (resultBundleTestContract ?? defaultResultBundleTestContract)
        let resolvedResultBundleTiming = omitResultBundleTiming
            ? nil
            : (resultBundleTiming ?? physicalProofResultBundleTiming(around: capturedAt))
        let resolvedResultBundleDevice = omitResultBundleDevice
            ? nil
            : (resultBundleDevice ?? physicalProofResultBundleDevice(forIOSBuild: iosBuild))
        let defaultAttachmentManifest = physicalProofAttachmentManifest(
            for: runbook,
            resultBundleFilename: resolvedResultBundleFilename,
            resultBundleTestContract: resolvedResultBundleTestContract ?? defaultResultBundleTestContract,
            resultBundleTiming: resolvedResultBundleTiming ?? physicalProofResultBundleTiming(around: capturedAt),
            totalAttachmentByteCount: resolvedResultBundleMetrics.attachmentByteCount
        )
        let resolvedAttachmentManifest = omitAttachmentManifest
            ? nil
            : (attachmentManifest ?? defaultAttachmentManifest)
        let resolvedReviewerEvidence = reviewerEvidence ?? physicalProofReviewerEvidence(
            for: runbook,
            capturedAt: capturedAt,
            resultBundleFilename: resolvedResultBundleFilename,
            resultBundleSHA256: resultBundleSHA256,
            resultBundleSummarySHA256: resultBundleSummarySHA256 ?? String(repeating: "d", count: 64),
            resultBundleSummary: resolvedResultBundleSummary,
            resultBundleMetrics: resolvedResultBundleMetrics,
            resultBundleTestContract: resolvedResultBundleTestContract ?? defaultResultBundleTestContract,
            resultBundleTiming: resolvedResultBundleTiming ?? physicalProofResultBundleTiming(around: capturedAt),
            resultBundleDevice: resolvedResultBundleDevice ?? physicalProofResultBundleDevice(),
            attachmentManifest: resolvedAttachmentManifest ?? defaultAttachmentManifest,
            hashedDeviceIdentifier: hashedDeviceIdentifier,
            deviceModelIdentifier: deviceModelIdentifier,
            iosBuild: iosBuild
        )
        return BracketerPhysicalProofSubmission(
            schemaVersion: schemaVersion,
            scenarioID: runbook.id,
            resultBundleFilename: resolvedResultBundleFilename,
            resultBundleSHA256: resultBundleSHA256,
            resultBundleSummarySHA256: resultBundleSummarySHA256,
            resultBundleSummary: resultBundleSummary,
            resultBundleMetrics: resultBundleMetrics,
            resultBundleTestContract: resolvedResultBundleTestContract,
            resultBundleTiming: resolvedResultBundleTiming,
            resultBundleDevice: resolvedResultBundleDevice,
            attachmentManifest: resolvedAttachmentManifest,
            xcodeDestination: xcodeDestination,
            deviceModelIdentifier: deviceModelIdentifier,
            hashedDeviceIdentifier: hashedDeviceIdentifier,
            iosBuild: iosBuild,
            capturedAt: capturedAt,
            lensID: "wide-camera",
            manifestSnapshotSHA256: manifestSnapshotSHA256,
            providedArtifactIDs: providedArtifactIDs ?? runbook.expectedArtifacts,
            reviewerEvidence: resolvedReviewerEvidence,
            notes: "Lab reviewer accepted all required artifacts."
        )
    }

    private func physicalProofReviewerEvidence(
        for runbook: BracketerPhysicalCaptureRunbook,
        capturedAt: Date,
        resultBundleFilename: String,
        resultBundleSHA256: String,
        resultBundleSummarySHA256: String = String(repeating: "d", count: 64),
        resultBundleSummary: BracketerPhysicalResultBundleSummary = BracketerPhysicalResultBundleSummary(
            status: .passed,
            title: "Test - Bracketer",
            totalTestCount: 164,
            passedTestCount: 164,
            failedTestCount: 0,
            expectedFailureCount: 0,
            skippedTestCount: 0
        ),
        resultBundleMetrics: BracketerPhysicalResultBundleMetrics = BracketerPhysicalResultBundleMetrics(
            totalTestCount: 164,
            passedTests: 164,
            failedTests: 0,
            durationMilliseconds: 60_000,
            attachmentByteCount: 4096
        ),
        resultBundleTestContract: BracketerPhysicalResultBundleTestContract? = nil,
        resultBundleTiming: BracketerPhysicalResultBundleTiming? = nil,
        resultBundleDevice: BracketerPhysicalResultBundleDevice? = nil,
        attachmentManifest: BracketerPhysicalAttachmentManifest? = nil,
        hashedDeviceIdentifier: String = String(repeating: "c", count: 64),
        deviceModelIdentifier: String = "iPhone17,1",
        iosBuild: String = "26.4.1"
    ) -> [String] {
        let resolvedResultBundleTestContract = resultBundleTestContract
            ?? physicalProofResultBundleTestContract(for: runbook)
        let resolvedResultBundleTiming = resultBundleTiming
            ?? physicalProofResultBundleTiming(around: capturedAt)
        let resolvedResultBundleDevice = resultBundleDevice ?? physicalProofResultBundleDevice()
        let resolvedAttachmentManifest = attachmentManifest
            ?? physicalProofAttachmentManifest(
                for: runbook,
                resultBundleFilename: resultBundleFilename,
                resultBundleTestContract: resolvedResultBundleTestContract,
                resultBundleTiming: resolvedResultBundleTiming,
                totalAttachmentByteCount: resultBundleMetrics.attachmentByteCount
            )
        return [
            "Captured at: \(physicalProofTimestamp(capturedAt))",
            "Result bundle: \(resultBundleFilename)",
            "Result bundle SHA-256: \(resultBundleSHA256)",
            "Result bundle summary SHA-256: \(resultBundleSummarySHA256)",
            "Result bundle summary: \(resultBundleSummary.summaryValue)",
            "Result bundle metrics: \(resultBundleMetrics.summaryValue)",
            "Result bundle test contract: \(resolvedResultBundleTestContract.summaryValue)",
            "Result bundle timing: \(resolvedResultBundleTiming.summaryValue)",
            "Result bundle device: \(resolvedResultBundleDevice.summaryValue)",
            "Attachment manifest hashes: \(resolvedAttachmentManifest.summaryValue)",
            "Hashed device identifier: \(hashedDeviceIdentifier)",
            "Device model: \(deviceModelIdentifier)",
            "iOS build: \(iosBuild)"
        ]
            + runbook.evidenceSteps.map { "Verified on physical iPhone: \($0)" }
    }

    private func physicalProofResultBundleTestContract(
        for runbook: BracketerPhysicalCaptureRunbook
    ) -> BracketerPhysicalResultBundleTestContract {
        BracketerPhysicalResultBundleTestContract(
            xcodebuildVersion: "Xcode 26.5 Build version 17F42",
            xcresulttoolVersion: "xcresulttool version 24757, schema version: 0.1.0",
            testPlanConfigurationName: "Test Scheme Action",
            testIdentifier: "BracketerPhysicalCaptureTests/test\(runbook.id)PhysicalCapture",
            testName: "test\(runbook.id)PhysicalCapture"
        )
    }

    private func physicalProofResultBundleTiming(
        around capturedAt: Date
    ) -> BracketerPhysicalResultBundleTiming {
        BracketerPhysicalResultBundleTiming.window(around: capturedAt)
    }

    private func physicalProofResultBundleDevice(
        modelName: String = "iPhone 17",
        osVersion: String? = "26.4.1",
        osBuildNumber: String? = "23E254a",
        platform: String = "iOS"
    ) -> BracketerPhysicalResultBundleDevice {
        BracketerPhysicalResultBundleDevice(
            modelName: modelName,
            osVersion: osVersion,
            osBuildNumber: osBuildNumber,
            platform: platform
        )
    }

    private func physicalProofResultBundleDevice(
        forIOSBuild iosBuild: String
    ) -> BracketerPhysicalResultBundleDevice {
        if iosBuild.contains(".") {
            return physicalProofResultBundleDevice(
                osVersion: iosBuild,
                osBuildNumber: "23E254a"
            )
        }
        return physicalProofResultBundleDevice(
            osVersion: nil,
            osBuildNumber: iosBuild
        )
    }

    private func physicalProofAttachmentManifest(
        for runbook: BracketerPhysicalCaptureRunbook,
        resultBundleFilename: String? = nil,
        resultBundleTestContract: BracketerPhysicalResultBundleTestContract? = nil,
        resultBundleTiming: BracketerPhysicalResultBundleTiming? = nil,
        totalAttachmentByteCount: Int = 4096
    ) -> BracketerPhysicalAttachmentManifest {
        let resolvedResultBundleFilename = resultBundleFilename ?? "Bracketer-\(runbook.id)-physical.xcresult"
        let resolvedTestContract = resultBundleTestContract ?? physicalProofResultBundleTestContract(for: runbook)
        let resolvedTiming = resultBundleTiming
            ?? physicalProofResultBundleTiming(around: Date(timeIntervalSince1970: 1_779_960_000))
        let artifactByteCounts = physicalProofArtifactByteCounts(
            for: runbook,
            totalAttachmentByteCount: totalAttachmentByteCount
        )
        return BracketerPhysicalAttachmentManifest(
            resultBundleFilename: resolvedResultBundleFilename,
            resultBundleTestIdentifier: resolvedTestContract.testIdentifier,
            testStartTime: resolvedTiming.testStartTime,
            testFinishTime: resolvedTiming.testFinishTime,
            artifactSHA256ByID: Dictionary(
                uniqueKeysWithValues: runbook.expectedArtifacts.enumerated().map { index, artifactID in
                    let digit = String(index + 1, radix: 16)
                    return (artifactID, String(repeating: digit, count: 64))
                }
            ),
            artifactByteCountByID: artifactByteCounts
        )
    }

    private func physicalProofArtifactByteCounts(
        for runbook: BracketerPhysicalCaptureRunbook,
        totalAttachmentByteCount: Int
    ) -> [String: Int] {
        guard !runbook.expectedArtifacts.isEmpty else { return [:] }
        let baseByteCount = max(1, totalAttachmentByteCount / runbook.expectedArtifacts.count)
        return Dictionary(
            uniqueKeysWithValues: runbook.expectedArtifacts.enumerated().map { index, artifactID in
                let remainingArtifacts = runbook.expectedArtifacts.count - 1
                let byteCount = index == remainingArtifacts
                    ? totalAttachmentByteCount - (baseByteCount * remainingArtifacts)
                    : baseByteCount
                return (artifactID, byteCount)
            }
        )
    }

    private func physicalProofTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    @Test func bracketProjectMarksPartialManifestIncompleteWithoutRawBytes() {
        let plan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let sequence = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: ["asset-under"],
            capturedAt: Date(timeIntervalSince1970: 20)
        )
        let manifest = sequence.manifest(
            groupIdentifier: "partial-group",
            source: .photos,
            plan: plan
        )

        let project = BracketProject.make(manifest: manifest, reviewSequence: sequence)

        #expect(project.lifecycle == .incomplete)
        #expect(project.reviewSnapshot.availableShotCount == 1)
        #expect(project.reviewSnapshot.missingShotCount == 2)
        #expect(project.privacy.storesRawPhotoBytes == false)
        #expect(project.privacy.storesAssetIdentifiers)
        #expect(project.searchTokens.contains("incomplete"))
        #expect(project.searchTokens.contains("missing"))
    }

    @Test func fileBracketProjectStorePersistsCurrentLatestAndDeletionAcrossInstances() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let firstStore = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let firstProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let secondPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let secondReview = BracketReviewSequence.make(
            plan: secondPlan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 30)
        )
        let secondManifest = secondReview.manifest(
            groupIdentifier: "second-group",
            source: .simulated,
            plan: secondPlan
        )
        let secondProject = BracketProject.make(
            manifest: secondManifest,
            reviewSequence: secondReview,
            createdAt: Date(timeIntervalSince1970: 30)
        )

        try firstStore.save(firstProject)
        try firstStore.save(secondProject)

        let reloadedStore = FileBracketProjectStore(rootURL: rootURL)
        let loadedFirst = try #require(try reloadedStore.load(id: firstProject.id))
        let current = try #require(try reloadedStore.current())
        let latest = try #require(try reloadedStore.latest())

        #expect(loadedFirst == firstProject)
        #expect(current.id == secondProject.id)
        #expect(latest.id == secondProject.id)
        #expect(try reloadedStore.loadAll().map(\.id) == [secondProject.id, firstProject.id])

        try reloadedStore.setCurrentProjectID(firstProject.id)
        #expect(try reloadedStore.current()?.id == firstProject.id)

        try reloadedStore.delete(id: firstProject.id)
        #expect(try reloadedStore.load(id: firstProject.id) == nil)
        #expect(try reloadedStore.current()?.id == secondProject.id)
    }

    @Test func fileBracketProjectStoreSurfacesCorruptProjectData() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review
        )
        try store.save(project)
        try Data("{ invalid json".utf8).write(
            to: rootURL.appendingPathComponent(project.id).appendingPathExtension("json"),
            options: [.atomic]
        )

        var didThrow = false
        do {
            _ = try store.load(id: project.id)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    @Test func bracketProjectLibrarySnapshotFiltersBySearchableFacts() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let photosProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Portfolio Window"],
            userNote: "Interior window bracket with RAW pairs",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let simulatedPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let simulatedReview = BracketReviewSequence.make(
            plan: simulatedPlan,
            assetIdentifiers: ["sim-under", "sim-center", "sim-over"],
            capturedAt: Date(timeIntervalSince1970: 20)
        )
        let simulatedProject = BracketProject.make(
            manifest: simulatedReview.manifest(
                groupIdentifier: "sim-tripod-group",
                source: .simulated,
                plan: simulatedPlan,
                captureDevice: .simulatedWide,
                captureLocation: .simulatedNotRequested
            ),
            reviewSequence: simulatedReview,
            acceptedTags: ["Tripod"],
            userNote: "Night archive dry run",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        .withUserCuration(
            isFavorite: true,
            acceptedTags: ["Tripod"],
            userNote: "Night archive dry run",
            updatedAt: Date(timeIntervalSince1970: 22)
        )
        let nextDayPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let nextDayReview = BracketReviewSequence.make(
            plan: nextDayPlan,
            assetIdentifiers: ["next-under", "next-center", "next-over"],
            capturedAt: Date(timeIntervalSince1970: 86_420)
        )
        let nextDayProject = BracketProject.make(
            manifest: nextDayReview.manifest(
                groupIdentifier: "sim-next-day-group",
                source: .simulated,
                plan: nextDayPlan,
                captureDevice: .simulatedWide,
                captureLocation: .simulatedNotRequested
            ),
            reviewSequence: nextDayReview,
            acceptedTags: ["Next Day"],
            userNote: "Next day archive dry run",
            createdAt: Date(timeIntervalSince1970: 86_420)
        )

        let all = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id
        )
        let window = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            query: "window raw"
        )
        let tripod = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            query: "simulated tripod"
        )
        let none = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            query: "client panorama"
        )
        let favoriteCollection = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            smartCollectionKind: .favorites
        )
        let rawCollection = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            smartCollectionKind: .rawAvailable
        )
        let rawSearchRoute = BracketProjectLibrarySearchRoute.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            query: "window raw",
            smartCollectionKind: .rawAvailable,
            facetFilter: .highDynamicRange
        )
        let dynamicRangeFacet = BracketProjectLibrarySnapshot.make(
            projects: [simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            facetFilter: .highDynamicRange
        )
        let twoDayLibrary = BracketProjectLibrarySnapshot.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id
        )
        let nextDaySnapshot = BracketProjectLibrarySnapshot.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            capturedDay: "1970-01-02"
        )
        let nextDayRoute = BracketProjectLibrarySearchRoute.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            capturedDay: "1970-01-02T12:34:56Z"
        )
        let wideLensID = try #require(BracketProjectLibraryLensFacet.normalizedLensID("1x Wide Camera"))
        let photosLocationPolicyID = try #require(BracketProjectLibraryLocationFacet.normalizedLocationPolicyID("Photo Location Requested, Project Redacted"))
        let wideLensSnapshot = BracketProjectLibrarySnapshot.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            lensID: "1x Wide Camera"
        )
        let wideLensRoute = BracketProjectLibrarySearchRoute.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            lensID: wideLensID
        )
        let photosLocationSnapshot = BracketProjectLibrarySnapshot.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            locationPolicyID: "Photo Location Requested, Project Redacted"
        )
        let photosLocationRoute = BracketProjectLibrarySearchRoute.make(
            projects: [nextDayProject, simulatedProject, photosProject],
            currentProjectID: photosProject.id,
            locationPolicyID: photosLocationPolicyID
        )
        let archiveWorkspace = BracketProjectLibraryWorkspace(snapshot: all)
        let limitedArchiveWorkspace = BracketProjectLibraryWorkspace(
            snapshot: twoDayLibrary,
            resultLimit: 2
        )

        #expect(all.resultCount == 2)
        #expect(all.latestProjectID == simulatedProject.id)
        #expect(all.accessibilityValue.contains("Project Library | 2 projects"))
        #expect(all.smartCollections.map(\.kind).contains(.reviewable))
        #expect(all.smartCollections.first(where: { $0.kind == .favorites })?.count == 1)
        #expect(all.smartCollections.first(where: { $0.kind == .rawAvailable })?.count == 1)
        #expect(all.smartCollectionsAccessibilityValue.contains("Smart Collections"))
        #expect(all.smartCollectionsAccessibilityValue.contains("Favorites"))
        #expect(all.facetSummary.projectCount == 2)
        #expect(all.facetSummary.capturedDateRange == "Captured 1970-01-01")
        #expect(all.facetSummary.shotCountRange == "3-5 shots")
        #expect(all.facetSummary.evSpreadRange == "EV spread 2-8 EV")
        #expect(all.facetSummary.rawProjectCount == 1)
        #expect(all.facetSummary.highDynamicRangeProjectCount == 1)
        #expect(all.facetSummary.qualityReadyProjectCount == 2)
        #expect(all.facetSummary.finalOutputBlockedProjectCount == 2)
        #expect(all.facetSummary.accessibilityValue.contains("Lenses"))
        #expect(all.facetSummary.accessibilityValue.contains("1x Wide Camera"))
        #expect(all.facetSummary.accessibilityValue.contains("Location policies"))
        #expect(all.facetSummary.accessibilityValue.contains("Photo Location Requested"))
        #expect(all.facetSummary.accessibilityValue.contains("Metadata-only library facets"))
        #expect(all.facetFilters.first(where: { $0.filter == .rawAvailable })?.count == 1)
        #expect(all.facetFilters.first(where: { $0.filter == .highDynamicRange })?.count == 1)
        #expect(all.facetFilters.first(where: { $0.filter == .qualityReady })?.count == 2)
        #expect(all.facetFilters.first(where: { $0.filter == .finalOutputBlocked })?.count == 2)
        #expect(all.facetFilters.first(where: { $0.filter == .exported }) == nil)
        #expect(all.facetFiltersAccessibilityValue.contains("Selectable Facets"))
        #expect(twoDayLibrary.dateFacets.map(\.day) == ["1970-01-02", "1970-01-01"])
        #expect(twoDayLibrary.dateFacets.first(where: { $0.day == "1970-01-01" })?.count == 2)
        #expect(twoDayLibrary.dateFacetsAccessibilityValue.contains("Captured Date Facets"))
        #expect(twoDayLibrary.lensFacets.first(where: { $0.id == wideLensID })?.count == 1)
        #expect(twoDayLibrary.lensFacetsAccessibilityValue.contains("Lens Facets"))
        #expect(twoDayLibrary.lensFacetsAccessibilityValue.contains("Simulated Wide Camera"))
        #expect(twoDayLibrary.locationFacets.first(where: { $0.id == photosLocationPolicyID })?.count == 1)
        #expect(twoDayLibrary.locationFacetsAccessibilityValue.contains("Location Policy Facets"))
        #expect(twoDayLibrary.locationFacetsAccessibilityValue.contains("Simulated Location Not Requested"))
        #expect(window.projects.map(\.id) == [photosProject.id])
        #expect(window.accessibilityValue.contains("Query window raw"))
        #expect(tripod.projects.map(\.id) == [simulatedProject.id])
        #expect(none.projects.isEmpty)
        #expect(favoriteCollection.projects.map(\.id) == [simulatedProject.id])
        #expect(favoriteCollection.accessibilityValue.contains("Collection Favorites"))
        #expect(rawCollection.projects.map(\.id) == [photosProject.id])
        #expect(dynamicRangeFacet.projects.map(\.id) == [photosProject.id])
        #expect(dynamicRangeFacet.accessibilityValue.contains("Facet Dynamic Range"))
        #expect(nextDaySnapshot.projects.map(\.id) == [nextDayProject.id])
        #expect(nextDaySnapshot.accessibilityValue.contains("Captured Day 1970-01-02"))
        #expect(nextDayRoute.resultProjectIDs == [nextDayProject.id])
        #expect(nextDayRoute.accessibilityValue.contains("Captured Day 1970-01-02"))
        #expect(nextDayRoute.dialogText.contains("captured 1970-01-02"))
        #expect(wideLensSnapshot.projects.map(\.id) == [photosProject.id])
        #expect(wideLensSnapshot.accessibilityValue.contains("Lens \(wideLensID)"))
        #expect(wideLensRoute.resultProjectIDs == [photosProject.id])
        #expect(wideLensRoute.accessibilityValue.contains("Lens \(wideLensID)"))
        #expect(wideLensRoute.dialogText.contains("lens \(wideLensID)"))
        #expect(photosLocationSnapshot.projects.map(\.id) == [photosProject.id])
        #expect(photosLocationSnapshot.accessibilityValue.contains("Location Policy \(photosLocationPolicyID)"))
        #expect(photosLocationRoute.resultProjectIDs == [photosProject.id])
        #expect(photosLocationRoute.accessibilityValue.contains("Location Policy \(photosLocationPolicyID)"))
        #expect(photosLocationRoute.dialogText.contains("location policy \(photosLocationPolicyID)"))
        #expect(rawSearchRoute.resultProjectIDs == [photosProject.id])
        #expect(rawSearchRoute.firstResultID == photosProject.id)
        #expect(rawSearchRoute.accessibilityValue.contains("Project Search Route"))
        #expect(rawSearchRoute.accessibilityValue.contains("Query window raw"))
        #expect(rawSearchRoute.accessibilityValue.contains("Collection RAW Available"))
        #expect(rawSearchRoute.accessibilityValue.contains("Facet Dynamic Range"))
        #expect(rawSearchRoute.dialogText.contains("facet Dynamic Range"))
        #expect(rawSearchRoute.accessibilityValue.contains("no Photos local identifiers"))
        #expect(rawSearchRoute.accessibilityValue.contains("Facets Captured 1970-01-01"))
        #expect(rawSearchRoute.facetSummary.projectCount == 1)
        #expect(rawSearchRoute.facetSummary.highDynamicRangeProjectCount == 1)
        #expect(rawSearchRoute.facetSummary.finalOutputBlockedProjectCount == 1)
        #expect(archiveWorkspace.resultCount == 2)
        #expect(archiveWorkspace.visibleCount == 2)
        #expect(!archiveWorkspace.hasTruncatedResults)
        #expect(archiveWorkspace.projectSummaries.map(\.id) == [simulatedProject.id, photosProject.id])
        #expect(archiveWorkspace.projectSummaries[0].isLatest)
        #expect(archiveWorkspace.projectSummaries[1].isCurrent)
        #expect(archiveWorkspace.projectSummaries[0].finalOutputActionPlanSummary.contains("Resolve blockers before export"))
        #expect(archiveWorkspace.projectSummaries[0].accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(archiveWorkspace.accessibilityValue.contains("Project Archive Workspace"))
        #expect(archiveWorkspace.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(archiveWorkspace.accessibilityValue.contains("not final rendered image proof"))
        #expect(archiveWorkspace.accessibilityValue.contains("Metadata-only archive workspace"))
        #expect(archiveWorkspace.accessibilityValue.contains("No raw photo bytes"))
        #expect(limitedArchiveWorkspace.resultCount == 3)
        #expect(limitedArchiveWorkspace.visibleCount == 2)
        #expect(limitedArchiveWorkspace.hasTruncatedResults)
        #expect(limitedArchiveWorkspace.accessibilityValue.contains("Showing 2 of 3"))
        #expect(photosProject.projectLibraryAccessibilityValue.contains("No raw photo bytes"))
    }

    @Test func bracketReviewSequenceRestoresManifestFactsForProjectReview() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let sequence = BracketReviewSequence.make(manifest: fixture.manifest)
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 30),
            source: "Unit Test"
        )

        #expect(sequence.countLabel == "5 shots")
        #expect(sequence.shots[0].assetIdentifier == "asset-under")
        #expect(sequence.shots[0].fileType == "RAW + Processed")
        #expect(sequence.shots[0].captureState == .available)
        #expect(sequence.shots[0].availableRepresentations == [.processed, .raw])
        #expect(sequence.shots[0].clippingWarnings == [.simulatedShadowRisk])
        #expect(sequence.shots[2].isBestExposureCandidate)
        #expect(sequence.captureTimestampLabel == "1970-01-01T00:00:00Z")
        #expect(snapshot.sequence == sequence)
        #expect(snapshot.accessibilityValue.contains("Project Review"))
        #expect(snapshot.accessibilityValue.contains("Source Unit Test"))
    }

    @Test func bracketProjectReviewAccessibilityContractSurfacesStableWorkspaceProof() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 30),
            source: "Accessibility Unit Test"
        )
        let contract = BracketProjectReviewAccessibilityContract.make(snapshot: snapshot)

        #expect(contract.schemaVersion == 1)
        #expect(contract.isVerified)
        #expect(contract.hasRequiredProbes)
        #expect(contract.hasNavigationControls)
        #expect(contract.tapTargetsVerified)
        #expect(contract.minimumTapTargetPoints == 44)
        #expect(contract.requiredProbeIdentifiers == [
            "review.project.handoff.summary",
            "review.project.selectedShot",
            "review.project.voiceOverTraversal",
            "review.project.finalWorkspace.fixture",
            "review.project.tapTargetAudit",
            "review.project.bestBaseFrame",
            "review.project.bestBaseFrame.card",
            "review.project.beforeAfterScrub",
            "review.project.beforeAfterScrub.card",
            "review.project.perShotExposure",
            "review.project.perShotExposure.card",
            "review.project.focusEdge",
            "review.project.focusEdge.card",
            "review.project.motionAlignment",
            "review.project.motionAlignment.card",
            "review.project.motionMetadata",
            "review.project.motionMetadata.card",
            "review.project.featureMatch",
            "review.project.featureMatch.card",
            "review.project.alignmentTransform",
            "review.project.alignmentTransform.card",
            "review.project.motionBlur",
            "review.project.motionBlur.card",
            "review.project.ghostingRisk",
            "review.project.ghostingRisk.card",
            "review.project.movingRegionMask",
            "review.project.movingRegionMask.card",
            "review.project.alignmentPerformance",
            "review.project.alignmentPerformance.card",
            "review.project.alignmentExplanation",
            "review.project.alignmentExplanation.card",
            "review.project.qualityReport",
            "review.project.qualityReport.card",
            "review.project.mergeReadiness",
            "review.project.mergeReadiness.card",
            "review.project.finalOutputs",
            "review.project.finalOutputs.card",
            "review.project.finalOutputReadinessAudit",
            "review.project.assetResources",
            "review.project.assetResources.card",
            "review.project.imageBundle",
            "review.project.imageBundle.card",
            "review.project.exposureComparison",
            "review.project.pixelComparison",
            "review.project.facts",
        ])
        #expect(contract.navigationControlIdentifiers == [
            "review.project.previousShotButton",
            "review.project.nextShotButton",
            "review.project.representationToggle",
            "review.project.closeButton",
        ])
        #expect(contract.shotRowIdentifierPrefix == "review.project.shot")
        #expect(contract.shotRowCount == 5)
        #expect(contract.exposureComparisonCount == 5)
        #expect(contract.pixelComparisonCount == 4)
        #expect(contract.accessibilityValue.contains("Review Workspace Accessibility Contract"))
        #expect(contract.accessibilityValue.contains("Minimum tap target 44 pt"))
        #expect(contract.accessibilityValue.contains("review.project.voiceOverTraversal"))
        #expect(contract.accessibilityValue.contains("review.project.finalWorkspace.fixture"))
        #expect(contract.accessibilityValue.contains("review.project.tapTargetAudit"))
        #expect(contract.accessibilityValue.contains("review.project.bestBaseFrame"))
        #expect(contract.accessibilityValue.contains("review.project.bestBaseFrame.card"))
        #expect(contract.accessibilityValue.contains("review.project.beforeAfterScrub"))
        #expect(contract.accessibilityValue.contains("review.project.beforeAfterScrub.card"))
        #expect(contract.accessibilityValue.contains("review.project.perShotExposure"))
        #expect(contract.accessibilityValue.contains("review.project.perShotExposure.card"))
        #expect(contract.accessibilityValue.contains("review.project.focusEdge"))
        #expect(contract.accessibilityValue.contains("review.project.focusEdge.card"))
        #expect(contract.accessibilityValue.contains("review.project.motionAlignment"))
        #expect(contract.accessibilityValue.contains("review.project.motionAlignment.card"))
        #expect(contract.accessibilityValue.contains("review.project.motionMetadata"))
        #expect(contract.accessibilityValue.contains("review.project.motionMetadata.card"))
        #expect(contract.accessibilityValue.contains("review.project.featureMatch"))
        #expect(contract.accessibilityValue.contains("review.project.featureMatch.card"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentTransform"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentTransform.card"))
        #expect(contract.accessibilityValue.contains("review.project.motionBlur"))
        #expect(contract.accessibilityValue.contains("review.project.motionBlur.card"))
        #expect(contract.accessibilityValue.contains("review.project.ghostingRisk"))
        #expect(contract.accessibilityValue.contains("review.project.ghostingRisk.card"))
        #expect(contract.accessibilityValue.contains("review.project.movingRegionMask"))
        #expect(contract.accessibilityValue.contains("review.project.movingRegionMask.card"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentPerformance"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentPerformance.card"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentExplanation"))
        #expect(contract.accessibilityValue.contains("review.project.alignmentExplanation.card"))
        #expect(contract.accessibilityValue.contains("review.project.qualityReport"))
        #expect(contract.accessibilityValue.contains("review.project.qualityReport.card"))
        #expect(contract.accessibilityValue.contains("review.project.mergeReadiness"))
        #expect(contract.accessibilityValue.contains("review.project.finalOutputs"))
        #expect(contract.accessibilityValue.contains("review.project.assetResources"))
        #expect(contract.accessibilityValue.contains("review.project.imageBundle"))
        #expect(contract.accessibilityValue.contains("review.project.imageBundle.card"))
        #expect(contract.accessibilityValue.contains("review.project.finalOutputs.card"))
        #expect(contract.accessibilityValue.contains("review.project.finalOutputReadinessAudit"))
        #expect(contract.accessibilityValue.contains("review.project.previousShotButton"))
        #expect(contract.accessibilityValue.contains("review.project.representationToggle"))
        #expect(contract.accessibilityValue.contains("No raw photo bytes exposed"))
        #expect(contract.accessibilityValue.contains("Photos asset identifiers redacted"))
        #expect(contract.accessibilityValue.contains("does not prove physical-device accessibility"))
        #expect(!contract.accessibilityValue.contains("asset-under"))
        #expect(!contract.accessibilityValue.contains("asset-center"))
        #expect(!contract.accessibilityValue.contains("private-photos-group"))

        let failingTapTargetContract = BracketProjectReviewAccessibilityContract.make(
            snapshot: snapshot,
            reviewCloseButtonPoints: 43
        )
        #expect(!failingTapTargetContract.isVerified)
        #expect(!failingTapTargetContract.tapTargetsVerified)
        #expect(failingTapTargetContract.accessibilityValue.contains("Follow-up required"))

        let missingProbeContract = BracketProjectReviewAccessibilityContract(
            requiredProbeIdentifiers: [
                "review.project.handoff.summary",
                "review.project.selectedShot",
            ],
            navigationControlIdentifiers: [
                "review.project.previousShotButton",
                "review.project.nextShotButton",
                "review.project.representationToggle",
                "review.project.closeButton",
            ],
            shotRowCount: 0,
            exposureComparisonCount: 0,
            pixelComparisonCount: 0,
            reviewCloseButtonPoints: 44,
            selectedShotNavigationButtonPoints: 44,
            representationTogglePoints: 44
        )
        #expect(!missingProbeContract.isVerified)
        #expect(!missingProbeContract.hasRequiredProbes)

        let data = try JSONEncoder().encode(contract)
        let decoded = try JSONDecoder().decode(BracketProjectReviewAccessibilityContract.self, from: data)
        #expect(decoded == contract)
    }

    @Test func bracketProjectReviewTapTargetAuditCoversReviewAndExportControls() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 30),
            source: "Tap Target Unit Test"
        )

        let audit = BracketProjectReviewTapTargetAudit.make(snapshot: snapshot)

        #expect(audit.schemaVersion == 1)
        #expect(audit.isVerified)
        #expect(audit.minimumTapTargetPoints == 44)
        #expect(audit.rows.count == 26)
        #expect(audit.verifiedRowCount == 26)
        #expect(audit.followUpRowCount == 0)
        #expect(audit.selectedControlRowCount == 5)
        #expect(audit.selectedControlVerifiedRowCount == 5)
        #expect(audit.selectedControlFollowUpRowCount == 0)
        #expect(audit.reviewGuidanceRowCount == 15)
        #expect(audit.reviewGuidanceVerifiedRowCount == 15)
        #expect(audit.reviewGuidanceFollowUpRowCount == 0)
        #expect(audit.exportRowCount == 3)
        #expect(audit.exportVerifiedRowCount == 3)
        #expect(audit.exportFollowUpRowCount == 0)
        #expect(audit.comparisonRowCount == 2)
        #expect(audit.comparisonVerifiedRowCount == 2)
        #expect(audit.comparisonFollowUpRowCount == 0)
        #expect(audit.shotRowAuditCount == 1)
        #expect(audit.shotRowVerifiedCount == 1)
        #expect(audit.shotRowFollowUpCount == 0)
        #expect(audit.summaryLabel == "26/26 tap targets verified")
        #expect(audit.selectedControlSummaryLabel == "5/5 selected-shot control tap targets verified")
        #expect(audit.reviewGuidanceSummaryLabel == "15/15 review guidance tap targets verified")
        #expect(audit.exportSummaryLabel == "3/3 export tap targets verified")
        #expect(audit.comparisonSummaryLabel == "2/2 comparison tap targets verified")
        #expect(audit.shotRowSummaryLabel == "1/1 shot-row tap target scopes verified")
        #expect(audit.selectedControlRows.map(\.id) == BracketProjectReviewTapTargetAudit.selectedControlRowIDs)
        #expect(audit.reviewGuidanceRows.map(\.id) == BracketProjectReviewTapTargetAudit.reviewGuidanceRowIDs)
        #expect(audit.exportRows.map(\.id) == BracketProjectReviewTapTargetAudit.exportRowIDs)
        #expect(audit.comparisonRows.map(\.id) == BracketProjectReviewTapTargetAudit.comparisonRowIDs)
        #expect(audit.shotRows.map(\.id) == BracketProjectReviewTapTargetAudit.shotRowIDs)
        #expect(audit.rows.contains { $0.id == "previousShot" && $0.accessibilityIdentifier == "review.project.previousShotButton" })
        #expect(audit.rows.contains { $0.id == "nextShot" && $0.accessibilityIdentifier == "review.project.nextShotButton" })
        #expect(audit.rows.contains { $0.id == "representationToggle" && $0.accessibilityIdentifier == "review.project.representationToggle" })
        #expect(audit.rows.contains { $0.id == "close" && $0.accessibilityIdentifier == "review.project.closeButton" })
        #expect(audit.rows.contains { $0.id == "bestBaseFrame" && $0.scope == "Review guidance" })
        #expect(audit.rows.contains { $0.id == "alignmentExplanation" && $0.accessibilityIdentifier == "review.project.alignmentExplanation.card" })
        #expect(audit.rows.contains { $0.id == "qualityReport" && $0.scope == "Review guidance" })
        #expect(audit.rows.contains { $0.id == "finalOutputs" && $0.scope == "Export review" })
        #expect(audit.rows.contains { $0.id == "assetResources" && $0.scope == "Export resources" })
        #expect(audit.rows.contains { $0.id == "imageBundle" && $0.scope == "Export bundle" })
        #expect(audit.rows.contains { $0.id == "shotRows" && $0.scope == "5 selectable review rows" })
        #expect(audit.accessibilityValue.contains("Review Export Tap Target Audit"))
        #expect(audit.accessibilityValue.contains("5/5 selected-shot control tap targets verified"))
        #expect(audit.accessibilityValue.contains("15/15 review guidance tap targets verified"))
        #expect(audit.accessibilityValue.contains("3/3 export tap targets verified"))
        #expect(audit.accessibilityValue.contains("2/2 comparison tap targets verified"))
        #expect(audit.accessibilityValue.contains("1/1 shot-row tap target scopes verified"))
        #expect(audit.accessibilityValue.contains("Minimum tap target 44 pt"))
        #expect(audit.accessibilityValue.contains("review.project.bestBaseFrame.card"))
        #expect(audit.accessibilityValue.contains("review.project.alignmentExplanation.card"))
        #expect(audit.accessibilityValue.contains("review.project.finalOutputs.card"))
        #expect(audit.accessibilityValue.contains("review.project.imageBundle.card"))
        #expect(audit.accessibilityValue.contains("model contract for expected SwiftUI control frames only"))
        #expect(audit.accessibilityValue.contains("does not measure physical touch ergonomics"))
        #expect(!audit.accessibilityValue.contains("asset-under"))
        #expect(!audit.accessibilityValue.contains("asset-center"))
        #expect(!audit.accessibilityValue.contains("private-photos-group"))

        let followUpAudit = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            closeButtonPoints: 43,
            exportCardPoints: 40
        )
        #expect(!followUpAudit.isVerified)
        #expect(followUpAudit.followUpRowCount == 4)
        #expect(followUpAudit.rows.first { $0.id == "close" }?.status == "Follow-up required")
        #expect(followUpAudit.rows.first { $0.id == "finalOutputs" }?.status == "Follow-up required")
        #expect(followUpAudit.summaryLabel == "4 tap target follow-ups")
        #expect(followUpAudit.selectedControlFollowUpRowCount == 1)
        #expect(followUpAudit.reviewGuidanceFollowUpRowCount == 0)
        #expect(followUpAudit.exportFollowUpRowCount == 3)
        #expect(followUpAudit.exportSummaryLabel == "3 export tap target follow-ups")

        let guidanceFollowUpAudit = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            reviewCardPoints: 40
        )
        #expect(!guidanceFollowUpAudit.isVerified)
        #expect(guidanceFollowUpAudit.followUpRowCount == 15)
        #expect(guidanceFollowUpAudit.reviewGuidanceRowCount == 15)
        #expect(guidanceFollowUpAudit.reviewGuidanceVerifiedRowCount == 0)
        #expect(guidanceFollowUpAudit.reviewGuidanceFollowUpRowCount == 15)
        #expect(guidanceFollowUpAudit.summaryLabel == "15 tap target follow-ups")
        #expect(guidanceFollowUpAudit.reviewGuidanceSummaryLabel == "15 review guidance tap target follow-ups")
        #expect(guidanceFollowUpAudit.rows.first { $0.id == "bestBaseFrame" }?.status == "Follow-up required")
        #expect(guidanceFollowUpAudit.rows.first { $0.id == "alignmentExplanation" }?.status == "Follow-up required")
        #expect(guidanceFollowUpAudit.rows.first { $0.id == "finalOutputs" }?.status == "Verified")
        #expect(guidanceFollowUpAudit.accessibilityValue.contains("15 review guidance tap target follow-ups"))

        let comparisonFollowUpAudit = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            comparisonCardPoints: 40
        )
        #expect(!comparisonFollowUpAudit.isVerified)
        #expect(comparisonFollowUpAudit.followUpRowCount == 2)
        #expect(comparisonFollowUpAudit.comparisonRowCount == 2)
        #expect(comparisonFollowUpAudit.comparisonVerifiedRowCount == 0)
        #expect(comparisonFollowUpAudit.comparisonFollowUpRowCount == 2)
        #expect(comparisonFollowUpAudit.summaryLabel == "2 tap target follow-ups")
        #expect(comparisonFollowUpAudit.comparisonSummaryLabel == "2 comparison tap target follow-ups")
        #expect(comparisonFollowUpAudit.rows.first { $0.id == "exposureComparison" }?.status == "Follow-up required")
        #expect(comparisonFollowUpAudit.rows.first { $0.id == "pixelComparison" }?.status == "Follow-up required")
        #expect(comparisonFollowUpAudit.rows.first { $0.id == "finalOutputs" }?.status == "Verified")

        let selectedControlFollowUpAudit = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            selectedShotNavigationButtonPoints: 40,
            representationTogglePoints: 40,
            closeButtonPoints: 40,
            selectedShotCardPoints: 40
        )
        #expect(!selectedControlFollowUpAudit.isVerified)
        #expect(selectedControlFollowUpAudit.followUpRowCount == 5)
        #expect(selectedControlFollowUpAudit.selectedControlRowCount == 5)
        #expect(selectedControlFollowUpAudit.selectedControlVerifiedRowCount == 0)
        #expect(selectedControlFollowUpAudit.selectedControlFollowUpRowCount == 5)
        #expect(selectedControlFollowUpAudit.summaryLabel == "5 tap target follow-ups")
        #expect(selectedControlFollowUpAudit.selectedControlSummaryLabel == "5 selected-shot control tap target follow-ups")
        #expect(selectedControlFollowUpAudit.rows.first { $0.id == "previousShot" }?.status == "Follow-up required")
        #expect(selectedControlFollowUpAudit.rows.first { $0.id == "selectedShot" }?.status == "Follow-up required")
        #expect(selectedControlFollowUpAudit.rows.first { $0.id == "bestBaseFrame" }?.status == "Verified")

        let shotRowFollowUpAudit = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            shotRowPoints: 40
        )
        #expect(!shotRowFollowUpAudit.isVerified)
        #expect(shotRowFollowUpAudit.followUpRowCount == 1)
        #expect(shotRowFollowUpAudit.shotRowAuditCount == 1)
        #expect(shotRowFollowUpAudit.shotRowVerifiedCount == 0)
        #expect(shotRowFollowUpAudit.shotRowFollowUpCount == 1)
        #expect(shotRowFollowUpAudit.summaryLabel == "1 tap target follow-ups")
        #expect(shotRowFollowUpAudit.shotRowSummaryLabel == "1 shot-row tap target follow-ups")
        #expect(shotRowFollowUpAudit.rows.first { $0.id == "shotRows" }?.status == "Follow-up required")
        #expect(shotRowFollowUpAudit.rows.first { $0.id == "finalOutputs" }?.status == "Verified")

        let data = try JSONEncoder().encode(audit)
        let decoded = try JSONDecoder().decode(BracketProjectReviewTapTargetAudit.self, from: data)
        #expect(decoded == audit)
    }

    @Test func bracketProjectFinalReviewWorkspaceFixtureReportCoversReviewExportWorkspace() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 30),
            source: "Final Workspace Unit Test"
        )

        let report = BracketProjectFinalReviewWorkspaceFixtureReport.make(snapshot: snapshot)
        let defaultMergeReadiness = BracketProjectMergeReadinessReport.make(project: snapshot.project)
        let defaultGhostingRisk = BracketProjectGhostingRiskReport.make(project: snapshot.project)
        let defaultMovingRegionMask = BracketProjectMovingRegionMaskReport.make(project: snapshot.project)
        let defaultArchiveBundle = try BracketProjectExportBundle.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let defaultArchiveIntegrityFile = try #require(
            defaultArchiveBundle.file(kind: BracketProjectArchiveIntegrityManifest.kind)
        )
        let archiveDecoder = JSONDecoder()
        archiveDecoder.dateDecodingStrategy = .iso8601
        let defaultArchiveIntegrity = try archiveDecoder.decode(
            BracketProjectArchiveIntegrityManifest.self,
            from: Data(defaultArchiveIntegrityFile.contents.utf8)
        )

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectFinalReviewWorkspaceFixtureReport.kind == "final-review-workspace-fixture")
        #expect(report.source == "directReviewAccessibilityFixture")
        #expect(report.isFixtureComplete)
        #expect(report.requiredProbeCount == 45)
        #expect(report.splitHandoffProbeCount == 18)
        #expect(report.traversalEntryCount >= 53)
        #expect(report.shotRowCount == 5)
        #expect(report.featureMatchGuideCount == 5)
        #expect(report.ghostingRiskGuideCount == defaultGhostingRisk.riskGuideCount)
        #expect(report.ghostingHighRiskShotCount == defaultGhostingRisk.highRiskShotCount)
        #expect(report.maxSyntheticGhostingRiskScore == defaultGhostingRisk.maxSyntheticGhostingRiskScore)
        #expect(report.movingRegionMaskGuideCount == defaultMovingRegionMask.maskGuideCount)
        #expect(report.highPriorityMovingRegionMaskCount == defaultMovingRegionMask.highPriorityMaskCount)
        #expect(report.maxSyntheticMaskCoveragePercent == defaultMovingRegionMask.maxSyntheticMaskCoveragePercent)
        #expect(report.alignmentDiagnosticGuideCount == 35)
        #expect(report.alignmentDiagnosticBreakdowns.count == 7)
        let allAlignmentDiagnosticBreakdownsComplete = report.alignmentDiagnosticBreakdowns.allSatisfy { $0.isComplete }
        #expect(allAlignmentDiagnosticBreakdownsComplete)
        #expect(report.alignmentDiagnosticBreakdowns.map(\.id) == [
            "featureMatch",
            "alignmentTransform",
            "motionBlur",
            "ghostingRisk",
            "movingRegionMask",
            "alignmentPerformance",
            "alignmentExplanation",
        ])
        #expect(report.alignmentDiagnosticBreakdowns.map(\.id) == BracketProjectFinalReviewWorkspaceFixtureReport.requiredAlignmentDiagnosticFamilyIDs)
        #expect(BracketProjectFinalReviewWorkspaceFixtureReport.hasCompleteAlignmentDiagnosticBreakdown(report.alignmentDiagnosticBreakdowns))
        let missingMaskBreakdowns = report.alignmentDiagnosticBreakdowns.filter { $0.id != "movingRegionMask" }
        #expect(!BracketProjectFinalReviewWorkspaceFixtureReport.hasCompleteAlignmentDiagnosticBreakdown(missingMaskBreakdowns))
        #expect(BracketProjectFinalReviewWorkspaceFixtureReport.alignmentDiagnosticMissingFamilyIDs(in: missingMaskBreakdowns) == ["movingRegionMask"])
        let featureMatchBreakdown = try #require(report.alignmentDiagnosticBreakdowns.first { $0.id == "featureMatch" })
        let duplicateFeatureBreakdowns = missingMaskBreakdowns + [featureMatchBreakdown]
        #expect(duplicateFeatureBreakdowns.count == 7)
        #expect(!BracketProjectFinalReviewWorkspaceFixtureReport.hasCompleteAlignmentDiagnosticBreakdown(duplicateFeatureBreakdowns))
        #expect(BracketProjectFinalReviewWorkspaceFixtureReport.alignmentDiagnosticDuplicateFamilyIDs(in: duplicateFeatureBreakdowns) == ["featureMatch"])
        let unexpectedFamilyBreakdown = BracketProjectFinalReviewWorkspaceFixtureReport.AlignmentDiagnosticBreakdown(
            id: "unexpectedAlignment",
            label: "Unexpected Alignment",
            count: 5,
            requiredCount: 5
        )
        let unexpectedFamilyBreakdowns = missingMaskBreakdowns + [unexpectedFamilyBreakdown]
        #expect(unexpectedFamilyBreakdowns.count == 7)
        #expect(!BracketProjectFinalReviewWorkspaceFixtureReport.hasCompleteAlignmentDiagnosticBreakdown(unexpectedFamilyBreakdowns))
        #expect(BracketProjectFinalReviewWorkspaceFixtureReport.alignmentDiagnosticUnexpectedFamilyIDs(in: unexpectedFamilyBreakdowns) == ["unexpectedAlignment"])
        let incompleteFamilyBreakdowns = report.alignmentDiagnosticBreakdowns.map { breakdown in
            breakdown.id == "ghostingRisk"
                ? BracketProjectFinalReviewWorkspaceFixtureReport.AlignmentDiagnosticBreakdown(
                    id: breakdown.id,
                    label: breakdown.label,
                    count: 4,
                    requiredCount: breakdown.requiredCount
                )
                : breakdown
        }
        #expect(!BracketProjectFinalReviewWorkspaceFixtureReport.hasCompleteAlignmentDiagnosticBreakdown(incompleteFamilyBreakdowns))
        #expect(report.tapTargetRowCount == 26)
        #expect(report.selectedControlTapTargetRowCount == 5)
        #expect(report.selectedControlTapTargetFollowUpRowCount == 0)
        #expect(report.reviewGuidanceTapTargetRowCount == 15)
        #expect(report.reviewGuidanceTapTargetFollowUpRowCount == 0)
        #expect(report.exportTapTargetRowCount == 3)
        #expect(report.exportTapTargetFollowUpRowCount == 0)
        #expect(report.comparisonTapTargetRowCount == 2)
        #expect(report.comparisonTapTargetFollowUpRowCount == 0)
        #expect(report.shotRowTapTargetScopeCount == 1)
        #expect(report.shotRowTapTargetFollowUpCount == 0)
        #expect(report.exportSurfaceCount == 3)
        #expect(report.comparisonSurfaceCount == 2)
        #expect(report.finalOutputPlanCount == 3)
        #expect(report.readyFinalOutputCount == 0)
        #expect(report.readyFinalOutputNames.isEmpty)
        #expect(report.blockedFinalOutputCount == 3)
        #expect(report.mergeReadinessScore == 95)
        #expect(report.mergeReadinessLabel == "Ready for cautious merge preview")
        #expect(report.mergeReadinessBlockerCount == 0)
        #expect(report.mergeReadinessCautionCount == 0)
        #expect(report.mergeReadinessEvidenceCount == defaultMergeReadiness.evidence.count)
        #expect(report.mergeReadinessBlockerEvidenceTitles.isEmpty)
        #expect(report.mergeReadinessCautionEvidenceTitles.isEmpty)
        #expect(report.mergeReadinessRecommendationCount == defaultMergeReadiness.recommendations.count)
        #expect(report.archiveIntegrityPayloadCount == 0)
        #expect(report.archiveIntegrityItemCount == 0)
        #expect(report.archiveIntegrityDigestCount == 0)
        #expect(report.archiveIntegrityInvalidDigestCount == 0)
        #expect(report.archiveIntegrityTotalByteCount == 0)
        #expect(report.isArchiveIntegrityVerified)
        #expect(report.summaryLabel == "Final review workspace fixture complete")
        #expect(report.coverageSummary.contains("probes"))
        #expect(report.coverageSummary.contains("18 split handoff/card pairs"))
        #expect(report.coverageSummary.contains("35 alignment diagnostic guides across 7 families"))
        #expect(report.coverageSummary.contains("5 selected-shot control tap targets"))
        #expect(report.coverageSummary.contains("15 review guidance tap targets"))
        #expect(report.coverageSummary.contains("3 export tap targets"))
        #expect(report.coverageSummary.contains("2 comparison tap targets"))
        #expect(report.coverageSummary.contains("1 shot-row tap target scopes"))
        #expect(report.alignmentDiagnosticBreakdownSummary.contains("Feature Match 5/5"))
        #expect(report.alignmentDiagnosticBreakdownSummary.contains("Alignment Explanation 5/5"))
        #expect(report.exportSummary.contains("3 export surfaces"))
        #expect(report.exportSummary.contains("0 ready final outputs"))
        #expect(report.exportSummary.contains("3 blocked final outputs"))
        #expect(report.accessibilityValue.contains("Final Review Workspace Fixture"))
        #expect(report.accessibilityValue.contains("18 split handoff/card pairs are present"))
        #expect(report.accessibilityValue.contains("Review/export tap targets meet the model contract"))
        #expect(report.accessibilityValue.contains("5 selected-shot control tap targets meet the model contract"))
        #expect(report.accessibilityValue.contains("15 review guidance tap targets meet the model contract"))
        #expect(report.accessibilityValue.contains("3 export tap targets meet the model contract"))
        #expect(report.accessibilityValue.contains("2 comparison tap targets meet the model contract"))
        #expect(report.accessibilityValue.contains("1 shot-row tap target scopes meet the model contract"))
        #expect(report.accessibilityValue.contains("5 feature-match guides are present"))
        #expect(report.accessibilityValue.contains("5 ghosting-risk guides are present"))
        #expect(report.accessibilityValue.contains("5 moving-region mask guides are present"))
        #expect(report.accessibilityValue.contains("max ghosting risk \(defaultGhostingRisk.maxSyntheticGhostingRiskScore)"))
        #expect(report.accessibilityValue.contains("max mask coverage \(defaultMovingRegionMask.maxSyntheticMaskCoveragePercent)%"))
        #expect(report.accessibilityValue.contains("7 required alignment diagnostic families are complete"))
        #expect(report.accessibilityValue.contains("35 alignment diagnostic guides are present"))
        #expect(report.accessibilityValue.contains("Alignment Performance 5/5"))
        #expect(report.accessibilityValue.contains("3 final-output plans are present"))
        #expect(report.accessibilityValue.contains("0 ready final outputs"))
        #expect(report.accessibilityValue.contains("Ready final outputs: none"))
        #expect(report.accessibilityValue.contains("5 asset-resource rows are present"))
        #expect(report.accessibilityValue.contains("4 pixel comparison pairs are present"))
        #expect(report.accessibilityValue.contains("No final rendered bytes are included"))
        #expect(report.accessibilityValue.contains("Merge readiness is ready for cautious merge preview."))
        #expect(report.accessibilityValue.contains("\(defaultMergeReadiness.evidence.count) merge-readiness evidence rows"))
        #expect(report.accessibilityValue.contains("Merge-readiness blockers: none"))
        #expect(report.accessibilityValue.contains("Merge-readiness cautions: none"))
        #expect(report.accessibilityValue.contains("Archive integrity 0 payloads"))
        #expect(report.accessibilityValue.contains("Archive integrity manifest not attached to this fixture."))
        #expect(report.accessibilityValue.contains("simulator-ready model/UI coverage only"))
        #expect(report.accessibilityValue.contains("does not run VoiceOver"))
        #expect(report.accessibilityValue.contains("proving physical-device accessibility"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let explicitDefaultTapTargetsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: .make(snapshot: snapshot)
        )
        #expect(explicitDefaultTapTargetsReport == report)

        let defaultContract = BracketProjectReviewAccessibilityContract.make(snapshot: snapshot)
        let explicitDefaultContractReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            accessibilityContract: defaultContract
        )
        #expect(explicitDefaultContractReport == report)

        let defaultTraversal = BracketProjectReviewVoiceOverTraversalSnapshot.make(snapshot: snapshot)
        let explicitDefaultTraversalReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            traversalSnapshot: defaultTraversal
        )
        #expect(explicitDefaultTraversalReport == report)

        let undersizedContract = BracketProjectReviewAccessibilityContract.make(
            snapshot: snapshot,
            reviewCloseButtonPoints: 43
        )
        let undersizedContractReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            accessibilityContract: undersizedContract
        )
        #expect(!undersizedContractReport.isFixtureComplete)
        #expect(undersizedContractReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(undersizedContractReport.requiredProbeCount == report.requiredProbeCount)
        #expect(undersizedContractReport.splitHandoffProbeCount == report.splitHandoffProbeCount)
        #expect(undersizedContractReport.traversalEntryCount == report.traversalEntryCount)
        #expect(undersizedContractReport.accessibilityValue.contains("Workspace accessibility contract needs follow-up."))
        #expect(undersizedContractReport.accessibilityValue.contains("18 split handoff/card pairs are present."))
        #expect(undersizedContractReport.accessibilityValue.contains("Traversal fixture is complete."))

        let reducedProbeContract = BracketProjectReviewAccessibilityContract(
            requiredProbeIdentifiers: [
                BracketProjectReviewAccessibilityContract.handoffSummaryProbeIdentifier,
                BracketProjectReviewAccessibilityContract.selectedShotProbeIdentifier,
            ],
            navigationControlIdentifiers: defaultContract.navigationControlIdentifiers,
            shotRowCount: defaultContract.shotRowCount,
            exposureComparisonCount: defaultContract.exposureComparisonCount,
            pixelComparisonCount: defaultContract.pixelComparisonCount,
            reviewCloseButtonPoints: defaultContract.reviewCloseButtonPoints,
            selectedShotNavigationButtonPoints: defaultContract.selectedShotNavigationButtonPoints,
            representationTogglePoints: defaultContract.representationTogglePoints
        )
        let reducedProbeContractReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            accessibilityContract: reducedProbeContract
        )
        #expect(!reducedProbeContractReport.isFixtureComplete)
        #expect(reducedProbeContractReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(reducedProbeContractReport.requiredProbeCount == 2)
        #expect(reducedProbeContractReport.splitHandoffProbeCount == 0)
        #expect(reducedProbeContractReport.accessibilityValue.contains("Workspace accessibility contract needs follow-up."))
        #expect(reducedProbeContractReport.accessibilityValue.contains("0 split handoff/card pairs are present."))
        #expect(reducedProbeContractReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        func privacyContract(
            redactsRawPhotoBytes: Bool,
            redactsPhotosAssetIdentifiers: Bool
        ) -> BracketProjectReviewAccessibilityContract {
            BracketProjectReviewAccessibilityContract(
                schemaVersion: defaultContract.schemaVersion,
                minimumTapTargetPoints: defaultContract.minimumTapTargetPoints,
                requiredProbeIdentifiers: defaultContract.requiredProbeIdentifiers,
                navigationControlIdentifiers: defaultContract.navigationControlIdentifiers,
                shotRowIdentifierPrefix: defaultContract.shotRowIdentifierPrefix,
                shotRowCount: defaultContract.shotRowCount,
                exposureComparisonCount: defaultContract.exposureComparisonCount,
                pixelComparisonCount: defaultContract.pixelComparisonCount,
                reviewCloseButtonPoints: defaultContract.reviewCloseButtonPoints,
                selectedShotNavigationButtonPoints: defaultContract.selectedShotNavigationButtonPoints,
                representationTogglePoints: defaultContract.representationTogglePoints,
                redactsRawPhotoBytes: redactsRawPhotoBytes,
                redactsPhotosAssetIdentifiers: redactsPhotosAssetIdentifiers,
                proofBoundary: defaultContract.proofBoundary
            )
        }
        let rawByteExposureContract = privacyContract(
            redactsRawPhotoBytes: false,
            redactsPhotosAssetIdentifiers: true
        )
        let rawByteExposureReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            accessibilityContract: rawByteExposureContract
        )
        #expect(!rawByteExposureReport.isFixtureComplete)
        #expect(rawByteExposureReport.requiredProbeCount == report.requiredProbeCount)
        #expect(rawByteExposureReport.accessibilityValue.contains("Workspace accessibility contract needs follow-up."))
        #expect(rawByteExposureReport.accessibilityValue.contains("raw photo byte redaction needs follow-up"))
        #expect(!rawByteExposureReport.accessibilityValue.contains("Photos asset identifier redaction needs follow-up"))
        #expect(rawByteExposureReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let photosIdentifierExposureContract = privacyContract(
            redactsRawPhotoBytes: true,
            redactsPhotosAssetIdentifiers: false
        )
        let photosIdentifierExposureReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            accessibilityContract: photosIdentifierExposureContract
        )
        #expect(!photosIdentifierExposureReport.isFixtureComplete)
        #expect(photosIdentifierExposureReport.requiredProbeCount == report.requiredProbeCount)
        #expect(photosIdentifierExposureReport.accessibilityValue.contains("Workspace accessibility contract needs follow-up."))
        #expect(photosIdentifierExposureReport.accessibilityValue.contains("Photos asset identifier redaction needs follow-up"))
        #expect(!photosIdentifierExposureReport.accessibilityValue.contains("raw photo byte redaction needs follow-up"))
        #expect(photosIdentifierExposureReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let incompleteTraversal = BracketProjectReviewVoiceOverTraversalSnapshot(
            schemaVersion: BracketProjectReviewVoiceOverTraversalSnapshot.schemaVersion,
            projectID: defaultTraversal.projectID,
            title: defaultTraversal.title,
            source: "unit-test-stub",
            entries: [
                BracketProjectReviewVoiceOverTraversalSnapshot.Entry(
                    order: 0,
                    identifier: "review.project.UNKNOWN",
                    label: "Stub traversal entry",
                    role: "Stub probe",
                    traits: ["staticText"],
                    expectedValueFragments: ["Stub"]
                ),
            ],
            boundary: defaultTraversal.boundary
        )
        #expect(!incompleteTraversal.isComplete)
        let incompleteTraversalReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            traversalSnapshot: incompleteTraversal
        )
        #expect(!incompleteTraversalReport.isFixtureComplete)
        #expect(incompleteTraversalReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(incompleteTraversalReport.requiredProbeCount == report.requiredProbeCount)
        #expect(incompleteTraversalReport.splitHandoffProbeCount == report.splitHandoffProbeCount)
        #expect(incompleteTraversalReport.traversalEntryCount == 1)
        #expect(incompleteTraversalReport.accessibilityValue.contains("Workspace accessibility contract verified."))
        #expect(incompleteTraversalReport.accessibilityValue.contains("Traversal fixture needs follow-up."))
        #expect(incompleteTraversalReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let explicitDefaultAlignmentDiagnosticsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            alignmentDiagnosticBreakdowns: report.alignmentDiagnosticBreakdowns
        )
        #expect(explicitDefaultAlignmentDiagnosticsReport == report)

        let defaultFinalOutputs = BracketProjectFinalOutputManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let explicitDefaultFinalOutputsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            finalOutputs: defaultFinalOutputs
        )
        #expect(explicitDefaultFinalOutputsReport == report)

        let expectedBlockedFinalOutputNames = defaultFinalOutputs.outputs
            .filter { !$0.blockers.isEmpty }
            .map(\.displayName)
        let expectedReadyFinalOutputNames = defaultFinalOutputs.outputs
            .filter { $0.blockers.isEmpty }
            .map(\.displayName)
        let expectedFinalOutputBlockerReasons = defaultFinalOutputs.outputs
            .flatMap(\.blockers)
            .reduce(into: [String]()) { unique, blocker in
                if !unique.contains(blocker) {
                    unique.append(blocker)
                }
            }
        let expectedFinalOutputBlockerReasonCount = defaultFinalOutputs.outputs.reduce(0) { total, output in
            total + output.blockers.count
        }
        let expectedFinalOutputBlockerSummaries = defaultFinalOutputs.outputs.compactMap { output -> String? in
            guard !output.blockers.isEmpty else { return nil }
            return "\(output.displayName): \(output.blockers.joined(separator: "; "))"
        }
        let expectedFinalOutputRecommendations = defaultFinalOutputs.outputs.map {
            "\($0.displayName): \($0.recommendation)"
        }
        #expect(report.blockedFinalOutputNames == expectedBlockedFinalOutputNames)
        #expect(report.readyFinalOutputCount == defaultFinalOutputs.readyOutputCount)
        #expect(report.readyFinalOutputNames == expectedReadyFinalOutputNames)
        #expect(report.blockedFinalOutputNames.count == report.blockedFinalOutputCount)
        #expect(report.finalOutputSourceExposureCount == defaultFinalOutputs.sourceExposureCount)
        #expect(report.finalOutputCompleteResourcePairCount == defaultFinalOutputs.completeResourcePairCount)
        #expect(report.finalOutputPreviewArtifactAvailable == defaultFinalOutputs.previewArtifactAvailable)
        #expect(report.finalOutputReadinessSummary == defaultFinalOutputs.readinessSummary)
        #expect(report.finalOutputBlockerReasonCount == expectedFinalOutputBlockerReasonCount)
        #expect(report.finalOutputBlockerReasons == expectedFinalOutputBlockerReasons)
        #expect(report.finalOutputBlockerReasons.count == Set(report.finalOutputBlockerReasons).count)
        #expect(report.finalOutputBlockerSummaries == expectedFinalOutputBlockerSummaries)
        #expect(report.finalOutputRecommendations == expectedFinalOutputRecommendations)
        #expect(report.finalOutputRecommendations.count == defaultFinalOutputs.outputCount)
        #expect(report.blockedFinalOutputNames.contains("HDR HEIF master"))
        #expect(report.finalOutputBlockerReasons.contains("Final HDR/tone-map renderer is not implemented in this build."))
        #expect(report.finalOutputBlockerSummaries.contains { summary in
            summary.contains("HDR HEIF master")
                && summary.contains("Physical Photos resource bytes and Files export artifact have not been inspected.")
        })
        #expect(report.accessibilityValue.contains("Blocked final outputs: \(expectedBlockedFinalOutputNames.joined(separator: ", "))"))
        #expect(report.accessibilityValue.contains("\(defaultFinalOutputs.sourceExposureCount) final-output source exposures"))
        #expect(report.accessibilityValue.contains("\(defaultFinalOutputs.completeResourcePairCount) complete final-output resource pairs"))
        #expect(report.accessibilityValue.contains("Final-output preview artifact available: \(defaultFinalOutputs.previewArtifactAvailable)"))
        #expect(report.accessibilityValue.contains("Final-output readiness: \(defaultFinalOutputs.readinessSummary)"))
        #expect(report.accessibilityValue.contains("Final-output readiness says \(defaultFinalOutputs.readyOutputCount) ready, \(defaultFinalOutputs.blockedOutputCount) blocked"))
        #expect(report.accessibilityValue.contains("\(expectedFinalOutputRecommendations.count) final-output recommendations"))
        #expect(report.accessibilityValue.contains("Final-output recommendations: \(expectedFinalOutputRecommendations.joined(separator: " | "))"))
        #expect(report.accessibilityValue.contains("Final-output recommendations cover \(expectedFinalOutputRecommendations.count) planned output(s): \(expectedFinalOutputRecommendations.joined(separator: " | "))."))
        #expect(report.accessibilityValue.contains("\(expectedFinalOutputBlockerReasonCount) final-output blocker reasons"))
        #expect(report.accessibilityValue.contains("Final-output blockers: \(expectedFinalOutputBlockerReasons.joined(separator: ", "))"))
        #expect(report.accessibilityValue.contains("Final-output blocker detail: \(expectedFinalOutputBlockerSummaries.joined(separator: " | "))"))
        #expect(report.accessibilityValue.contains("Final-output blocker detail covers \(expectedBlockedFinalOutputNames.count) blocked plan(s) and \(expectedFinalOutputBlockerReasonCount) blocker reason(s): \(expectedBlockedFinalOutputNames.joined(separator: ", "))."))

        let injectedBlockedFinalOutputs = BracketProjectFinalOutputManifest(
            schemaVersion: defaultFinalOutputs.schemaVersion,
            projectID: defaultFinalOutputs.projectID,
            title: defaultFinalOutputs.title,
            privacyLevel: defaultFinalOutputs.privacyLevel,
            createdAt: defaultFinalOutputs.createdAt,
            boundary: defaultFinalOutputs.boundary,
            sourceExposureCount: defaultFinalOutputs.sourceExposureCount,
            completeResourcePairCount: defaultFinalOutputs.completeResourcePairCount,
            previewArtifactAvailable: defaultFinalOutputs.previewArtifactAvailable,
            finalRenderedBytesIncluded: false,
            outputCount: 1,
            readyOutputCount: 0,
            blockedOutputCount: 1,
            readinessSummary: "Injected final-output blocker detail for regression proof.",
            outputs: [
                BracketProjectFinalOutputManifest.Output(
                    id: "unit-test-final-render",
                    displayName: "Unit test final render",
                    filename: "unit-test-final-render.tiff",
                    mimeType: "image/tiff",
                    codec: "TIFF",
                    colorPipeline: "Unit-test final-render pipeline",
                    sourcePolicy: "Unit-test metadata only; no Photos bytes are read.",
                    readiness: "blocked-unit-test-proof",
                    blockers: [
                        "Injected renderer blocker.",
                        "Injected physical export blocker.",
                    ],
                    provenanceInputs: [
                        "unit-test",
                        BracketProjectFinalOutputManifest.kind,
                    ],
                    recommendation: "Resolve injected blockers before claiming final output."
                ),
            ]
        )
        let injectedBlockedFinalOutputsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            finalOutputs: injectedBlockedFinalOutputs
        )
        #expect(injectedBlockedFinalOutputsReport.isFixtureComplete)
        #expect(injectedBlockedFinalOutputsReport.finalOutputPlanCount == 1)
        #expect(injectedBlockedFinalOutputsReport.readyFinalOutputCount == 0)
        #expect(injectedBlockedFinalOutputsReport.readyFinalOutputNames.isEmpty)
        #expect(injectedBlockedFinalOutputsReport.blockedFinalOutputCount == 1)
        #expect(injectedBlockedFinalOutputsReport.blockedFinalOutputNames == ["Unit test final render"])
        #expect(injectedBlockedFinalOutputsReport.finalOutputSourceExposureCount == injectedBlockedFinalOutputs.sourceExposureCount)
        #expect(injectedBlockedFinalOutputsReport.finalOutputCompleteResourcePairCount == injectedBlockedFinalOutputs.completeResourcePairCount)
        #expect(injectedBlockedFinalOutputsReport.finalOutputPreviewArtifactAvailable == injectedBlockedFinalOutputs.previewArtifactAvailable)
        #expect(injectedBlockedFinalOutputsReport.finalOutputReadinessSummary == "Injected final-output blocker detail for regression proof.")
        #expect(injectedBlockedFinalOutputsReport.finalOutputBlockerReasonCount == 2)
        #expect(injectedBlockedFinalOutputsReport.finalOutputBlockerReasons == [
            "Injected renderer blocker.",
            "Injected physical export blocker.",
        ])
        #expect(injectedBlockedFinalOutputsReport.finalOutputBlockerSummaries == [
            "Unit test final render: Injected renderer blocker.; Injected physical export blocker.",
        ])
        #expect(injectedBlockedFinalOutputsReport.finalOutputRecommendations == [
            "Unit test final render: Resolve injected blockers before claiming final output.",
        ])
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Final-output blocker detail: Unit test final render: Injected renderer blocker.; Injected physical export blocker."))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Final-output recommendations: Unit test final render: Resolve injected blockers before claiming final output."))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Final-output recommendations cover 1 planned output(s): Unit test final render: Resolve injected blockers before claiming final output."))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Final-output readiness: Injected final-output blocker detail for regression proof."))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Ready final outputs: none"))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Final-output blocker detail covers 1 blocked plan(s) and 2 blocker reason(s): Unit test final render."))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))
        #expect(injectedBlockedFinalOutputsReport.accessibilityValue.contains("No final rendered bytes are included"))

        let mixedFinalOutputs = BracketProjectFinalOutputManifest(
            schemaVersion: defaultFinalOutputs.schemaVersion,
            projectID: defaultFinalOutputs.projectID,
            title: defaultFinalOutputs.title,
            privacyLevel: defaultFinalOutputs.privacyLevel,
            createdAt: defaultFinalOutputs.createdAt,
            boundary: defaultFinalOutputs.boundary,
            sourceExposureCount: defaultFinalOutputs.sourceExposureCount,
            completeResourcePairCount: defaultFinalOutputs.completeResourcePairCount,
            previewArtifactAvailable: true,
            finalRenderedBytesIncluded: false,
            outputCount: 2,
            readyOutputCount: 1,
            blockedOutputCount: 1,
            readinessSummary: "1 of 2 injected final outputs are ready.",
            outputs: [
                BracketProjectFinalOutputManifest.Output(
                    id: "unit-test-ready-preview",
                    displayName: "Unit test ready preview",
                    filename: "unit-test-ready-preview.jpg",
                    mimeType: "image/jpeg",
                    codec: "JPEG",
                    colorPipeline: "Unit-test ready preview pipeline",
                    sourcePolicy: "Unit-test metadata only; no Photos bytes are read.",
                    readiness: "ready-unit-test-proof",
                    blockers: [],
                    provenanceInputs: ["unit-test-ready"],
                    recommendation: "Keep ready output separate from final rendered bytes."
                ),
                BracketProjectFinalOutputManifest.Output(
                    id: "unit-test-blocked-master",
                    displayName: "Unit test blocked master",
                    filename: "unit-test-blocked-master.heic",
                    mimeType: "image/heic",
                    codec: "HEIF",
                    colorPipeline: "Unit-test blocked master pipeline",
                    sourcePolicy: "Unit-test metadata only; no Photos bytes are read.",
                    readiness: "blocked-unit-test-proof",
                    blockers: ["Injected final master blocker."],
                    provenanceInputs: ["unit-test-blocked"],
                    recommendation: "Resolve injected blocker before final export."
                ),
            ]
        )
        let mixedFinalOutputsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            finalOutputs: mixedFinalOutputs
        )
        #expect(mixedFinalOutputsReport.isFixtureComplete)
        #expect(mixedFinalOutputsReport.finalOutputPlanCount == 2)
        #expect(mixedFinalOutputsReport.readyFinalOutputCount == 1)
        #expect(mixedFinalOutputsReport.readyFinalOutputNames == ["Unit test ready preview"])
        #expect(mixedFinalOutputsReport.blockedFinalOutputCount == 1)
        #expect(mixedFinalOutputsReport.blockedFinalOutputNames == ["Unit test blocked master"])
        #expect(mixedFinalOutputsReport.finalOutputReadinessSummary == "1 of 2 injected final outputs are ready.")
        #expect(mixedFinalOutputsReport.finalOutputRecommendations == [
            "Unit test ready preview: Keep ready output separate from final rendered bytes.",
            "Unit test blocked master: Resolve injected blocker before final export.",
        ])
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("1 ready final outputs"))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Ready final outputs: Unit test ready preview"))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Blocked final outputs: Unit test blocked master"))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Final-output readiness says 1 ready, 1 blocked"))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Ready outputs: Unit test ready preview."))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Final-output recommendations cover 2 planned output(s): Unit test ready preview: Keep ready output separate from final rendered bytes. | Unit test blocked master: Resolve injected blocker before final export."))
        #expect(mixedFinalOutputsReport.accessibilityValue.contains("Final-output blocker detail covers 1 blocked plan(s) and 1 blocker reason(s): Unit test blocked master."))

        let explicitDefaultGhostingRiskReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            ghostingRisk: defaultGhostingRisk
        )
        #expect(explicitDefaultGhostingRiskReport == report)

        let explicitDefaultMovingRegionMaskReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            movingRegionMask: defaultMovingRegionMask
        )
        #expect(explicitDefaultMovingRegionMaskReport == report)

        let explicitDefaultMergeReadinessReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            mergeReadiness: defaultMergeReadiness
        )
        #expect(explicitDefaultMergeReadinessReport == report)

        let explicitDefaultArchiveIntegrityReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            archiveIntegrity: defaultArchiveIntegrity
        )
        #expect(explicitDefaultArchiveIntegrityReport.isFixtureComplete)
        #expect(explicitDefaultArchiveIntegrityReport.summaryLabel == "Final review workspace fixture complete")
        #expect(explicitDefaultArchiveIntegrityReport.archiveIntegrityPayloadCount == defaultArchiveIntegrity.payloadCount)
        #expect(explicitDefaultArchiveIntegrityReport.archiveIntegrityItemCount == defaultArchiveIntegrity.items.count)
        #expect(explicitDefaultArchiveIntegrityReport.archiveIntegrityDigestCount == defaultArchiveIntegrity.payloadCount)
        #expect(explicitDefaultArchiveIntegrityReport.archiveIntegrityInvalidDigestCount == 0)
        #expect(explicitDefaultArchiveIntegrityReport.archiveIntegrityTotalByteCount == defaultArchiveIntegrity.totalByteCount)
        #expect(explicitDefaultArchiveIntegrityReport.isArchiveIntegrityVerified)
        #expect(explicitDefaultArchiveIntegrityReport.accessibilityValue.contains("Archive integrity \(defaultArchiveIntegrity.payloadCount) payloads"))
        #expect(explicitDefaultArchiveIntegrityReport.accessibilityValue.contains("Archive integrity manifest covers \(defaultArchiveIntegrity.payloadCount) payloads with valid SHA-256 digests."))

        let blockedMergeReadiness = BracketProjectMergeReadinessReport(
            schemaVersion: defaultMergeReadiness.schemaVersion,
            projectID: defaultMergeReadiness.projectID,
            title: defaultMergeReadiness.title,
            boundary: defaultMergeReadiness.boundary,
            score: 40,
            label: "Recovery before merge",
            blockerCount: 1,
            cautionCount: 2,
            evidence: [
                BracketProjectMergeReadinessReport.Evidence(
                    id: "unit-test-blocker",
                    severity: "Blocker",
                    title: "Injected merge blocker",
                    detail: "Unit fixture forces merge-readiness follow-up.",
                    recommendation: "Resolve merge blockers before preview."
                ),
                BracketProjectMergeReadinessReport.Evidence(
                    id: "unit-test-caution",
                    severity: "Caution",
                    title: "Injected merge caution",
                    detail: "Unit fixture forces cautious merge-readiness follow-up.",
                    recommendation: "Review caution evidence before preview."
                ),
                BracketProjectMergeReadinessReport.Evidence(
                    id: "unit-test-thumbnail-caution",
                    severity: "Caution",
                    title: "Injected thumbnail caution",
                    detail: "Unit fixture forces thumbnail-readiness follow-up.",
                    recommendation: "Regenerate thumbnail evidence before preview."
                ),
            ],
            recommendations: [
                "Resolve merge blockers before preview.",
                "Review caution evidence before preview.",
                "Regenerate thumbnail evidence before preview.",
            ]
        )
        let blockedMergeReadinessReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            mergeReadiness: blockedMergeReadiness
        )
        #expect(!blockedMergeReadinessReport.isFixtureComplete)
        #expect(blockedMergeReadinessReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(blockedMergeReadinessReport.mergeReadinessScore == 40)
        #expect(blockedMergeReadinessReport.mergeReadinessLabel == "Recovery before merge")
        #expect(blockedMergeReadinessReport.mergeReadinessBlockerCount == 1)
        #expect(blockedMergeReadinessReport.mergeReadinessCautionCount == 2)
        #expect(blockedMergeReadinessReport.mergeReadinessEvidenceCount == 3)
        #expect(blockedMergeReadinessReport.mergeReadinessBlockerEvidenceTitles == ["Injected merge blocker"])
        #expect(blockedMergeReadinessReport.mergeReadinessCautionEvidenceTitles == [
            "Injected merge caution",
            "Injected thumbnail caution",
        ])
        #expect(blockedMergeReadinessReport.mergeReadinessRecommendationCount == 3)
        #expect(blockedMergeReadinessReport.exportSurfaceCount == 3)
        #expect(blockedMergeReadinessReport.comparisonSurfaceCount == 2)
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Merge Recovery before merge, score 40, 1 blockers, 2 cautions"))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Merge readiness needs follow-up: score 40, 1 blocker(s), 2 caution(s), Recovery before merge."))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Merge-readiness blockers: Injected merge blocker"))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Merge-readiness cautions: Injected merge caution, Injected thumbnail caution"))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Blockers: Injected merge blocker."))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Cautions: Injected merge caution, Injected thumbnail caution."))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Resolve merge blockers before preview."))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Review caution evidence before preview."))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))
        #expect(blockedMergeReadinessReport.accessibilityValue.contains("No final rendered bytes are included"))

        let brokenArchiveIntegrity = BracketProjectArchiveIntegrityManifest(
            schemaVersion: defaultArchiveIntegrity.schemaVersion,
            projectID: defaultArchiveIntegrity.projectID,
            privacyLevel: defaultArchiveIntegrity.privacyLevel,
            createdAt: defaultArchiveIntegrity.createdAt,
            boundary: defaultArchiveIntegrity.boundary,
            payloadCount: 2,
            totalByteCount: 42,
            items: [
                BracketProjectArchiveIntegrityManifest.Item(
                    index: 0,
                    filename: "unit-test-project.json",
                    kind: "project",
                    mimeType: "application/json",
                    byteCount: 42,
                    sha256Hex: "not-a-sha"
                ),
            ]
        )
        let brokenArchiveIntegrityReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            archiveIntegrity: brokenArchiveIntegrity
        )
        #expect(!brokenArchiveIntegrityReport.isFixtureComplete)
        #expect(brokenArchiveIntegrityReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(brokenArchiveIntegrityReport.archiveIntegrityPayloadCount == 2)
        #expect(brokenArchiveIntegrityReport.archiveIntegrityItemCount == 1)
        #expect(brokenArchiveIntegrityReport.archiveIntegrityDigestCount == 0)
        #expect(brokenArchiveIntegrityReport.archiveIntegrityInvalidDigestCount == 1)
        #expect(brokenArchiveIntegrityReport.archiveIntegrityTotalByteCount == 42)
        #expect(!brokenArchiveIntegrityReport.isArchiveIntegrityVerified)
        #expect(brokenArchiveIntegrityReport.mergeReadinessScore == report.mergeReadinessScore)
        #expect(brokenArchiveIntegrityReport.exportSurfaceCount == 3)
        #expect(brokenArchiveIntegrityReport.comparisonSurfaceCount == 2)
        #expect(brokenArchiveIntegrityReport.accessibilityValue.contains("Archive integrity 2 payloads, 1 items, 0 valid digests, 1 invalid digests, 42 bytes"))
        #expect(brokenArchiveIntegrityReport.accessibilityValue.contains("Archive integrity needs follow-up: payloads 2, items 1, valid digests 0, invalid digests 1."))
        #expect(brokenArchiveIntegrityReport.accessibilityValue.contains("Merge readiness is ready for cautious merge preview."))

        let missingGhostingRisk = BracketProjectGhostingRiskReport(
            schemaVersion: defaultGhostingRisk.schemaVersion,
            projectID: defaultGhostingRisk.projectID,
            title: defaultGhostingRisk.title,
            source: defaultGhostingRisk.source,
            baselineIndex: defaultGhostingRisk.baselineIndex,
            baselineLabel: defaultGhostingRisk.baselineLabel,
            shotCount: defaultGhostingRisk.shotCount,
            riskGuideCount: 0,
            highRiskShotCount: 0,
            maxSyntheticGhostingRiskScore: 0,
            items: [],
            guidance: ["Unit fixture removed ghosting-risk guidance."],
            syntheticFixtureNote: defaultGhostingRisk.syntheticFixtureNote,
            boundary: defaultGhostingRisk.boundary
        )
        let missingGhostingRiskReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            ghostingRisk: missingGhostingRisk
        )
        #expect(!missingGhostingRiskReport.isFixtureComplete)
        #expect(missingGhostingRiskReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingGhostingRiskReport.ghostingRiskGuideCount == 0)
        #expect(missingGhostingRiskReport.ghostingHighRiskShotCount == 0)
        #expect(missingGhostingRiskReport.maxSyntheticGhostingRiskScore == 0)
        #expect(missingGhostingRiskReport.movingRegionMaskGuideCount == report.movingRegionMaskGuideCount)
        #expect(missingGhostingRiskReport.accessibilityValue.contains("Ghosting-risk guidance needs follow-up: 0 risk guides are present."))
        #expect(missingGhostingRiskReport.accessibilityValue.contains("Required alignment diagnostic family coverage is incomplete."))
        #expect(missingGhostingRiskReport.accessibilityValue.contains("Archive integrity manifest not attached to this fixture."))

        let missingMovingRegionMask = BracketProjectMovingRegionMaskReport(
            schemaVersion: defaultMovingRegionMask.schemaVersion,
            projectID: defaultMovingRegionMask.projectID,
            title: defaultMovingRegionMask.title,
            source: defaultMovingRegionMask.source,
            baselineIndex: defaultMovingRegionMask.baselineIndex,
            baselineLabel: defaultMovingRegionMask.baselineLabel,
            shotCount: defaultMovingRegionMask.shotCount,
            maskGuideCount: 0,
            highPriorityMaskCount: 0,
            maxSyntheticMaskCoveragePercent: 0,
            items: [],
            guidance: ["Unit fixture removed moving-region mask guidance."],
            syntheticFixtureNote: defaultMovingRegionMask.syntheticFixtureNote,
            boundary: defaultMovingRegionMask.boundary
        )
        let missingMovingRegionMaskReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            movingRegionMask: missingMovingRegionMask
        )
        #expect(!missingMovingRegionMaskReport.isFixtureComplete)
        #expect(missingMovingRegionMaskReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingMovingRegionMaskReport.ghostingRiskGuideCount == report.ghostingRiskGuideCount)
        #expect(missingMovingRegionMaskReport.movingRegionMaskGuideCount == 0)
        #expect(missingMovingRegionMaskReport.highPriorityMovingRegionMaskCount == 0)
        #expect(missingMovingRegionMaskReport.maxSyntheticMaskCoveragePercent == 0)
        #expect(missingMovingRegionMaskReport.accessibilityValue.contains("Moving-region mask guidance needs follow-up: 0 mask guides are present."))
        #expect(missingMovingRegionMaskReport.accessibilityValue.contains("Required alignment diagnostic family coverage is incomplete."))
        #expect(missingMovingRegionMaskReport.accessibilityValue.contains("Merge readiness is ready for cautious merge preview."))

        let defaultAssetResources = BracketProjectAssetResourceReport.make(project: snapshot.project)
        let defaultImageBundle = BracketProjectImageBundleManifest.make(
            project: snapshot.project,
            privacyLevel: .metadataOnly,
            createdAt: snapshot.project.updatedAt
        )
        let defaultExposureComparison = BracketProjectExposureComparison.make(project: snapshot.project)
        let defaultPixelComparison = try #require(BracketProjectSideBySidePixelComparison.make(project: snapshot.project))
        let explicitDefaultExportComparisonReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            assetResources: defaultAssetResources,
            imageBundle: defaultImageBundle,
            exposureComparison: defaultExposureComparison,
            pixelComparison: .some(defaultPixelComparison)
        )
        #expect(explicitDefaultExportComparisonReport == report)

        let missingAssetResources = BracketProjectAssetResourceReport(
            schemaVersion: defaultAssetResources.schemaVersion,
            projectID: defaultAssetResources.projectID,
            title: defaultAssetResources.title,
            boundary: defaultAssetResources.boundary,
            shotCount: 0,
            assetReferenceCount: 0,
            rawAvailableCount: 0,
            processedAvailableCount: 0,
            completePairCount: 0,
            missingAssetCount: 0,
            recoveryIdentifierCount: 0,
            identifierPolicy: defaultAssetResources.identifierPolicy,
            items: []
        )
        let missingAssetResourcesReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            assetResources: missingAssetResources
        )
        #expect(!missingAssetResourcesReport.isFixtureComplete)
        #expect(missingAssetResourcesReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingAssetResourcesReport.exportSurfaceCount == 2)
        #expect(missingAssetResourcesReport.comparisonSurfaceCount == 2)
        #expect(missingAssetResourcesReport.accessibilityValue.contains("Asset-resource rows are missing."))
        #expect(missingAssetResourcesReport.accessibilityValue.contains("5 image-bundle rows are present."))
        #expect(missingAssetResourcesReport.accessibilityValue.contains("3 final-output plans are present."))
        #expect(missingAssetResourcesReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let missingImageBundle = BracketProjectImageBundleManifest(
            schemaVersion: defaultImageBundle.schemaVersion,
            projectID: defaultImageBundle.projectID,
            title: defaultImageBundle.title,
            privacyLevel: defaultImageBundle.privacyLevel,
            createdAt: defaultImageBundle.createdAt,
            boundary: defaultImageBundle.boundary,
            shotCount: 0,
            exportableShotCount: 0,
            rawRequestedCount: 0,
            processedRequestedCount: 0,
            completeRawProcessedPairCount: 0,
            missingRepresentationCount: 0,
            recoveryIdentifierCount: 0,
            assetIdentifierPolicy: defaultImageBundle.assetIdentifierPolicy,
            items: []
        )
        let missingImageBundleReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            imageBundle: missingImageBundle
        )
        #expect(!missingImageBundleReport.isFixtureComplete)
        #expect(missingImageBundleReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingImageBundleReport.exportSurfaceCount == 2)
        #expect(missingImageBundleReport.comparisonSurfaceCount == 2)
        #expect(missingImageBundleReport.accessibilityValue.contains("Image-bundle rows are missing."))
        #expect(missingImageBundleReport.accessibilityValue.contains("5 asset-resource rows are present."))
        #expect(missingImageBundleReport.accessibilityValue.contains("3 final-output plans are present."))
        #expect(missingImageBundleReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let missingExposureComparison = BracketProjectExposureComparison(
            schemaVersion: defaultExposureComparison.schemaVersion,
            projectID: defaultExposureComparison.projectID,
            title: defaultExposureComparison.title,
            baselineIndex: nil,
            baselineDisplayLabel: nil,
            baselineEVOffset: nil,
            shotCount: 0,
            items: []
        )
        let missingExposureComparisonReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            exposureComparison: missingExposureComparison
        )
        #expect(!missingExposureComparisonReport.isFixtureComplete)
        #expect(missingExposureComparisonReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingExposureComparisonReport.exportSurfaceCount == 3)
        #expect(missingExposureComparisonReport.comparisonSurfaceCount == 1)
        #expect(missingExposureComparisonReport.accessibilityValue.contains("Exposure comparison is missing."))
        #expect(missingExposureComparisonReport.accessibilityValue.contains("4 pixel comparison pairs are present."))
        #expect(missingExposureComparisonReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let missingPixelComparisonReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            pixelComparison: .some(nil)
        )
        #expect(!missingPixelComparisonReport.isFixtureComplete)
        #expect(missingPixelComparisonReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingPixelComparisonReport.exportSurfaceCount == 3)
        #expect(missingPixelComparisonReport.comparisonSurfaceCount == 1)
        #expect(missingPixelComparisonReport.accessibilityValue.contains("5 exposure comparison rows are present."))
        #expect(missingPixelComparisonReport.accessibilityValue.contains("Pixel comparison pairs are missing."))
        #expect(missingPixelComparisonReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let missingComparisonSurfacesReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            exposureComparison: missingExposureComparison,
            pixelComparison: .some(nil)
        )
        #expect(!missingComparisonSurfacesReport.isFixtureComplete)
        #expect(missingComparisonSurfacesReport.exportSurfaceCount == 3)
        #expect(missingComparisonSurfacesReport.comparisonSurfaceCount == 0)
        #expect(missingComparisonSurfacesReport.accessibilityValue.contains("Exposure comparison is missing."))
        #expect(missingComparisonSurfacesReport.accessibilityValue.contains("Pixel comparison pairs are missing."))

        let missingFinalOutputs = BracketProjectFinalOutputManifest(
            schemaVersion: defaultFinalOutputs.schemaVersion,
            projectID: defaultFinalOutputs.projectID,
            title: defaultFinalOutputs.title,
            privacyLevel: defaultFinalOutputs.privacyLevel,
            createdAt: defaultFinalOutputs.createdAt,
            boundary: defaultFinalOutputs.boundary,
            sourceExposureCount: defaultFinalOutputs.sourceExposureCount,
            completeResourcePairCount: defaultFinalOutputs.completeResourcePairCount,
            previewArtifactAvailable: defaultFinalOutputs.previewArtifactAvailable,
            finalRenderedBytesIncluded: false,
            outputCount: 0,
            readyOutputCount: 0,
            blockedOutputCount: 0,
            readinessSummary: "No final-output plans were injected for regression proof.",
            outputs: []
        )
        let missingFinalOutputsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            finalOutputs: missingFinalOutputs
        )
        #expect(!missingFinalOutputsReport.isFixtureComplete)
        #expect(missingFinalOutputsReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingFinalOutputsReport.exportSurfaceCount == 2)
        #expect(missingFinalOutputsReport.finalOutputPlanCount == 0)
        #expect(missingFinalOutputsReport.blockedFinalOutputCount == 0)
        #expect(missingFinalOutputsReport.blockedFinalOutputNames.isEmpty)
        #expect(missingFinalOutputsReport.finalOutputBlockerReasonCount == 0)
        #expect(missingFinalOutputsReport.finalOutputBlockerReasons.isEmpty)
        #expect(missingFinalOutputsReport.finalOutputBlockerSummaries.isEmpty)
        #expect(missingFinalOutputsReport.finalOutputRecommendations.isEmpty)
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Blocked final outputs: none"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("0 final-output recommendations"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output recommendations: none"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output recommendations cannot be evaluated because final-output plans are missing."))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("0 final-output blocker reasons"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output blockers: none"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output blocker detail: none"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output blocker detail cannot be evaluated because final-output plans are missing."))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Final-output plan is missing."))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("2 export surfaces"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("No final rendered bytes are included"))
        #expect(missingFinalOutputsReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let renderedBytesFinalOutputs = BracketProjectFinalOutputManifest(
            schemaVersion: defaultFinalOutputs.schemaVersion,
            projectID: defaultFinalOutputs.projectID,
            title: defaultFinalOutputs.title,
            privacyLevel: defaultFinalOutputs.privacyLevel,
            createdAt: defaultFinalOutputs.createdAt,
            boundary: defaultFinalOutputs.boundary,
            sourceExposureCount: defaultFinalOutputs.sourceExposureCount,
            completeResourcePairCount: defaultFinalOutputs.completeResourcePairCount,
            previewArtifactAvailable: defaultFinalOutputs.previewArtifactAvailable,
            finalRenderedBytesIncluded: true,
            outputCount: defaultFinalOutputs.outputCount,
            readyOutputCount: defaultFinalOutputs.readyOutputCount,
            blockedOutputCount: defaultFinalOutputs.blockedOutputCount,
            readinessSummary: defaultFinalOutputs.readinessSummary,
            outputs: defaultFinalOutputs.outputs
        )
        let renderedBytesFinalOutputsReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            finalOutputs: renderedBytesFinalOutputs
        )
        #expect(!renderedBytesFinalOutputsReport.isFixtureComplete)
        #expect(renderedBytesFinalOutputsReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(renderedBytesFinalOutputsReport.exportSurfaceCount == 3)
        #expect(renderedBytesFinalOutputsReport.finalOutputPlanCount == 3)
        #expect(renderedBytesFinalOutputsReport.blockedFinalOutputCount == 3)
        #expect(renderedBytesFinalOutputsReport.finalOutputBlockerSummaries == report.finalOutputBlockerSummaries)
        #expect(renderedBytesFinalOutputsReport.accessibilityValue.contains("Unexpected final rendered bytes are included."))
        #expect(renderedBytesFinalOutputsReport.accessibilityValue.contains("3 final-output plans are present."))
        #expect(renderedBytesFinalOutputsReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let missingAlignmentFamilyReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            alignmentDiagnosticBreakdowns: missingMaskBreakdowns
        )
        #expect(!missingAlignmentFamilyReport.isFixtureComplete)
        #expect(missingAlignmentFamilyReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(missingAlignmentFamilyReport.alignmentDiagnosticBreakdowns.count == 6)
        #expect(missingAlignmentFamilyReport.alignmentDiagnosticGuideCount == 30)
        #expect(missingAlignmentFamilyReport.accessibilityValue.contains("Required alignment diagnostic family coverage is incomplete"))
        #expect(missingAlignmentFamilyReport.accessibilityValue.contains("Alignment diagnostic guides are incomplete"))
        #expect(missingAlignmentFamilyReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))
        #expect(!missingAlignmentFamilyReport.alignmentDiagnosticBreakdownSummary.contains("Moving Region Mask 5/5"))

        let incompleteAlignmentFamilyReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            alignmentDiagnosticBreakdowns: incompleteFamilyBreakdowns
        )
        #expect(!incompleteAlignmentFamilyReport.isFixtureComplete)
        #expect(incompleteAlignmentFamilyReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(incompleteAlignmentFamilyReport.alignmentDiagnosticBreakdowns.count == 7)
        #expect(incompleteAlignmentFamilyReport.alignmentDiagnosticGuideCount == 34)
        #expect(incompleteAlignmentFamilyReport.alignmentDiagnosticBreakdownSummary.contains("Ghosting Risk 4/5"))
        #expect(incompleteAlignmentFamilyReport.accessibilityValue.contains("Required alignment diagnostic family coverage is incomplete"))
        #expect(incompleteAlignmentFamilyReport.accessibilityValue.contains("Alignment diagnostic guides are incomplete"))
        #expect(incompleteAlignmentFamilyReport.accessibilityValue.contains("Review/export tap targets meet the model contract"))

        let selectedControlFollowUpTapTargets = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            selectedShotNavigationButtonPoints: 40,
            representationTogglePoints: 40,
            closeButtonPoints: 40,
            selectedShotCardPoints: 40
        )
        let selectedControlFollowUpReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: selectedControlFollowUpTapTargets
        )
        #expect(!selectedControlFollowUpReport.isFixtureComplete)
        #expect(selectedControlFollowUpReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(selectedControlFollowUpReport.selectedControlTapTargetRowCount == 5)
        #expect(selectedControlFollowUpReport.selectedControlTapTargetFollowUpRowCount == 5)
        #expect(selectedControlFollowUpReport.shotRowTapTargetFollowUpCount == 0)
        #expect(selectedControlFollowUpReport.accessibilityValue.contains("Review/export tap targets need follow-up"))
        #expect(selectedControlFollowUpReport.accessibilityValue.contains("5 selected-shot control tap target follow-ups"))
        #expect(selectedControlFollowUpReport.accessibilityValue.contains("5 selected-shot control tap targets need follow-up"))
        #expect(selectedControlFollowUpReport.accessibilityValue.contains("1 shot-row tap target scopes meet the model contract"))

        let shotRowFollowUpTapTargets = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            shotRowPoints: 40
        )
        let shotRowFollowUpReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: shotRowFollowUpTapTargets
        )
        #expect(!shotRowFollowUpReport.isFixtureComplete)
        #expect(shotRowFollowUpReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(shotRowFollowUpReport.selectedControlTapTargetFollowUpRowCount == 0)
        #expect(shotRowFollowUpReport.shotRowTapTargetScopeCount == 1)
        #expect(shotRowFollowUpReport.shotRowTapTargetFollowUpCount == 1)
        #expect(shotRowFollowUpReport.accessibilityValue.contains("Review/export tap targets need follow-up"))
        #expect(shotRowFollowUpReport.accessibilityValue.contains("1 shot-row tap target follow-ups"))
        #expect(shotRowFollowUpReport.accessibilityValue.contains("1 shot-row tap target scopes need follow-up"))
        #expect(shotRowFollowUpReport.accessibilityValue.contains("5 selected-shot control tap targets meet the model contract"))

        let reviewGuidanceFollowUpTapTargets = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            reviewCardPoints: 40
        )
        let reviewGuidanceFollowUpReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: reviewGuidanceFollowUpTapTargets
        )
        #expect(!reviewGuidanceFollowUpReport.isFixtureComplete)
        #expect(reviewGuidanceFollowUpReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(reviewGuidanceFollowUpReport.selectedControlTapTargetFollowUpRowCount == 0)
        #expect(reviewGuidanceFollowUpReport.reviewGuidanceTapTargetRowCount == 15)
        #expect(reviewGuidanceFollowUpReport.reviewGuidanceTapTargetFollowUpRowCount == 15)
        #expect(reviewGuidanceFollowUpReport.exportTapTargetFollowUpRowCount == 0)
        #expect(reviewGuidanceFollowUpReport.accessibilityValue.contains("Review/export tap targets need follow-up"))
        #expect(reviewGuidanceFollowUpReport.accessibilityValue.contains("15 review guidance tap target follow-ups"))
        #expect(reviewGuidanceFollowUpReport.accessibilityValue.contains("15 review guidance tap targets need follow-up"))
        #expect(reviewGuidanceFollowUpReport.accessibilityValue.contains("3 export tap targets meet the model contract"))

        let exportFollowUpTapTargets = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            exportCardPoints: 40
        )
        let exportFollowUpReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: exportFollowUpTapTargets
        )
        #expect(!exportFollowUpReport.isFixtureComplete)
        #expect(exportFollowUpReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(exportFollowUpReport.reviewGuidanceTapTargetFollowUpRowCount == 0)
        #expect(exportFollowUpReport.exportTapTargetRowCount == 3)
        #expect(exportFollowUpReport.exportTapTargetFollowUpRowCount == 3)
        #expect(exportFollowUpReport.comparisonTapTargetFollowUpRowCount == 0)
        #expect(exportFollowUpReport.accessibilityValue.contains("Review/export tap targets need follow-up"))
        #expect(exportFollowUpReport.accessibilityValue.contains("3 export tap target follow-ups"))
        #expect(exportFollowUpReport.accessibilityValue.contains("3 export tap targets need follow-up"))
        #expect(exportFollowUpReport.accessibilityValue.contains("2 comparison tap targets meet the model contract"))

        let comparisonFollowUpTapTargets = BracketProjectReviewTapTargetAudit.make(
            snapshot: snapshot,
            comparisonCardPoints: 40
        )
        let comparisonFollowUpReport = BracketProjectFinalReviewWorkspaceFixtureReport.make(
            snapshot: snapshot,
            tapTargetAudit: comparisonFollowUpTapTargets
        )
        #expect(!comparisonFollowUpReport.isFixtureComplete)
        #expect(comparisonFollowUpReport.summaryLabel == "Final review workspace fixture follow-up required")
        #expect(comparisonFollowUpReport.exportTapTargetFollowUpRowCount == 0)
        #expect(comparisonFollowUpReport.comparisonTapTargetRowCount == 2)
        #expect(comparisonFollowUpReport.comparisonTapTargetFollowUpRowCount == 2)
        #expect(comparisonFollowUpReport.shotRowTapTargetFollowUpCount == 0)
        #expect(comparisonFollowUpReport.accessibilityValue.contains("Review/export tap targets need follow-up"))
        #expect(comparisonFollowUpReport.accessibilityValue.contains("2 comparison tap target follow-ups"))
        #expect(comparisonFollowUpReport.accessibilityValue.contains("2 comparison tap targets need follow-up"))
        #expect(comparisonFollowUpReport.accessibilityValue.contains("1 shot-row tap target scopes meet the model contract"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectFinalReviewWorkspaceFixtureReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectReviewVoiceOverTraversalSnapshotOrdersReviewSurface() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 30),
            source: "VoiceOver Unit Test"
        )

        let traversal = BracketProjectReviewVoiceOverTraversalSnapshot.make(snapshot: snapshot)

        #expect(traversal.schemaVersion == 1)
        #expect(traversal.isComplete)
        #expect(traversal.entries.first?.identifier == "review.project.handoff.summary")
        #expect(traversal.entries.map(\.order) == traversal.entries.map(\.order).sorted())
        #expect(traversal.entries.contains { $0.identifier == "review.project.voiceOverTraversal" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.finalWorkspace.fixture" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.tapTargetAudit" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.bestBaseFrame" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.bestBaseFrame.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.beforeAfterScrub" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.beforeAfterScrub.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.perShotExposure" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.perShotExposure.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.focusEdge" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.focusEdge.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionAlignment" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionAlignment.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionMetadata" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionMetadata.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.featureMatch" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.featureMatch.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentTransform" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentTransform.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionBlur" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.motionBlur.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.ghostingRisk" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.ghostingRisk.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.movingRegionMask" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.movingRegionMask.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentPerformance" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentPerformance.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentExplanation" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.alignmentExplanation.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.qualityReport" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.qualityReport.card" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.mergeReadiness" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.finalOutputs" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.finalOutputReadinessAudit" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.assetResources" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.imageBundle" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.shot.2" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.previousShotButton" })
        #expect(traversal.entries.contains { $0.identifier == "review.project.closeButton" })
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.previousShotButton" }?.traits.contains("button") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.shot.2" }?.expectedValueFragments.contains("0 EV") == true)
        #expect(traversal.accessibilityValue.contains("Review VoiceOver Traversal"))
        #expect(traversal.accessibilityValue.contains("Complete"))
        #expect(traversal.accessibilityValue.contains("review.project.perShotExposure"))
        #expect(traversal.accessibilityValue.contains("review.project.perShotExposure.card"))
        #expect(traversal.accessibilityValue.contains("review.project.finalWorkspace.fixture"))
        #expect(traversal.accessibilityValue.contains("review.project.tapTargetAudit"))
        #expect(traversal.accessibilityValue.contains("review.project.bestBaseFrame"))
        #expect(traversal.accessibilityValue.contains("review.project.bestBaseFrame.card"))
        #expect(traversal.accessibilityValue.contains("review.project.beforeAfterScrub"))
        #expect(traversal.accessibilityValue.contains("review.project.beforeAfterScrub.card"))
        #expect(traversal.accessibilityValue.contains("review.project.focusEdge"))
        #expect(traversal.accessibilityValue.contains("review.project.focusEdge.card"))
        #expect(traversal.accessibilityValue.contains("review.project.motionAlignment"))
        #expect(traversal.accessibilityValue.contains("review.project.motionAlignment.card"))
        #expect(traversal.accessibilityValue.contains("review.project.motionMetadata"))
        #expect(traversal.accessibilityValue.contains("review.project.motionMetadata.card"))
        #expect(traversal.accessibilityValue.contains("review.project.featureMatch"))
        #expect(traversal.accessibilityValue.contains("review.project.featureMatch.card"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentTransform"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentTransform.card"))
        #expect(traversal.accessibilityValue.contains("review.project.motionBlur"))
        #expect(traversal.accessibilityValue.contains("review.project.motionBlur.card"))
        #expect(traversal.accessibilityValue.contains("review.project.ghostingRisk"))
        #expect(traversal.accessibilityValue.contains("review.project.ghostingRisk.card"))
        #expect(traversal.accessibilityValue.contains("review.project.movingRegionMask"))
        #expect(traversal.accessibilityValue.contains("review.project.movingRegionMask.card"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentPerformance"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentPerformance.card"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentExplanation"))
        #expect(traversal.accessibilityValue.contains("review.project.alignmentExplanation.card"))
        #expect(traversal.accessibilityValue.contains("review.project.qualityReport"))
        #expect(traversal.accessibilityValue.contains("review.project.qualityReport.card"))
        #expect(traversal.accessibilityValue.contains("review.project.mergeReadiness"))
        #expect(traversal.accessibilityValue.contains("review.project.finalOutputs"))
        #expect(traversal.accessibilityValue.contains("review.project.finalOutputReadinessAudit"))
        #expect(traversal.accessibilityValue.contains("review.project.assetResources"))
        #expect(traversal.accessibilityValue.contains("review.project.imageBundle"))
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure" }?.accessibilityValue.contains("Traits: staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure.card" }?.accessibilityValue.contains("Traits: staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.focusEdge" }?.accessibilityValue.contains("Traits: staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionAlignment" }?.accessibilityValue.contains("Traits: staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionMetadata" }?.accessibilityValue.contains("Traits: staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalWorkspace.fixture" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalWorkspace.fixture" }?.expectedValueFragments.contains("Final Review Workspace Fixture") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.tapTargetAudit" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.tapTargetAudit" }?.expectedValueFragments.contains("Review Export Tap Target Audit") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.bestBaseFrame" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.bestBaseFrame" }?.expectedValueFragments.contains("Best Base Frame Suggestion") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.bestBaseFrame.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.bestBaseFrame.card" }?.expectedValueFragments.contains("Best Base Frame Suggestion") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.beforeAfterScrub" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.beforeAfterScrub" }?.expectedValueFragments.contains("Before/After Scrub Plan") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.beforeAfterScrub.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.beforeAfterScrub.card" }?.expectedValueFragments.contains("Before/After Scrub Plan") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure" }?.expectedValueFragments.contains("Per-shot Exposure Distribution") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.perShotExposure.card" }?.expectedValueFragments.contains("Per-shot Exposure Distribution") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.focusEdge" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.focusEdge" }?.expectedValueFragments.contains("Focus/Edge Inspection") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.focusEdge.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.focusEdge.card" }?.expectedValueFragments.contains("Focus/Edge Inspection") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionAlignment" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionAlignment" }?.expectedValueFragments.contains("Motion/Alignment Overlay") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionAlignment.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionAlignment.card" }?.expectedValueFragments.contains("Motion/Alignment Overlay") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionMetadata" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionMetadata" }?.expectedValueFragments.contains("Motion Metadata Capture") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionMetadata.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionMetadata.card" }?.expectedValueFragments.contains("Motion Metadata Capture") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.featureMatch" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.featureMatch" }?.expectedValueFragments.contains("Feature Match Fixture") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.featureMatch.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.featureMatch.card" }?.expectedValueFragments.contains("Feature Match Fixture") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentTransform" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentTransform" }?.expectedValueFragments.contains("Alignment Transform") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentTransform.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentTransform.card" }?.expectedValueFragments.contains("Alignment Transform") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionBlur" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionBlur" }?.expectedValueFragments.contains("Motion/Blur Risk") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionBlur.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.motionBlur.card" }?.expectedValueFragments.contains("Motion/Blur Risk") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.ghostingRisk" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.ghostingRisk" }?.expectedValueFragments.contains("Ghosting Risk") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.ghostingRisk.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.ghostingRisk.card" }?.expectedValueFragments.contains("Ghosting Risk") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.movingRegionMask" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.movingRegionMask" }?.expectedValueFragments.contains("Moving-Region Mask") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.movingRegionMask.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.movingRegionMask.card" }?.expectedValueFragments.contains("Moving-Region Mask") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentPerformance" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentPerformance" }?.expectedValueFragments.contains("Alignment Performance Notes") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentPerformance.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentPerformance.card" }?.expectedValueFragments.contains("Alignment Performance Notes") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentExplanation" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentExplanation" }?.expectedValueFragments.contains("Alignment Explanation") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentExplanation.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.alignmentExplanation.card" }?.expectedValueFragments.contains("Alignment Explanation") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.qualityReport" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.qualityReport" }?.expectedValueFragments.contains("Capture Quality") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.qualityReport.card" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.qualityReport.card" }?.expectedValueFragments.contains("Capture Quality") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.mergeReadiness" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.mergeReadiness" }?.expectedValueFragments.contains("Merge Readiness") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs" }?.expectedValueFragments.contains("Final Output Manifest") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputReadinessAudit" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputReadinessAudit" }?.expectedValueFragments.contains("Final Output Readiness Audit") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputReadinessAudit" }?.expectedValueFragments.contains("Action plan") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputReadinessAudit" }?.expectedValueFragments.contains("not final rendered image proof") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs.card" }?.expectedValueFragments.contains("Final Outputs") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs.card" }?.expectedValueFragments.contains("Action plan") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs.card" }?.expectedValueFragments.contains("not final rendered image proof") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs.card" }?.accessibilityValue.contains("Action plan") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.finalOutputs.card" }?.accessibilityValue.contains("not final rendered image proof") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.assetResources" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.assetResources" }?.expectedValueFragments.contains("Asset Resources") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.imageBundle" }?.traits.contains("staticText") == true)
        #expect(traversal.entries.first { $0.identifier == "review.project.imageBundle" }?.expectedValueFragments.contains("Image Bundle Manifest") == true)
        #expect(traversal.accessibilityValue.contains("does not run VoiceOver"))
        #expect(traversal.accessibilityValue.contains(BracketProjectReviewVoiceOverTraversalSnapshot.boundary))
        #expect(!traversal.accessibilityValue.contains("asset-under"))
        #expect(!traversal.accessibilityValue.contains("asset-center"))
        #expect(!traversal.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(traversal)
        let decoded = try JSONDecoder().decode(BracketProjectReviewVoiceOverTraversalSnapshot.self, from: data)
        #expect(decoded == traversal)
    }

    @Test func bracketProjectFocusEdgeInspectionSummarizesSyntheticFixtureGuidance() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let inspection = BracketProjectFocusEdgeInspection.make(project: project)

        #expect(inspection.schemaVersion == 1)
        #expect(BracketProjectFocusEdgeInspection.kind == "focus-edge-inspection")
        #expect(inspection.source == "deterministicFixture")
        #expect(inspection.hasFocusGuidance)
        #expect(inspection.shotCount == 5)
        #expect(inspection.inspectedShotCount == 5)
        #expect(inspection.baselineIndex == 2)
        #expect(inspection.baselineLabel == "0 EV")
        #expect(inspection.items.count == 5)
        #expect(inspection.items.contains { $0.role == "Focus anchor" })
        #expect(inspection.items.allSatisfy { $0.syntheticEdgeCandidateCount == 15 })
        #expect(inspection.totalEdgeRegionCount >= inspection.peakEdgeRegionCount)
        #expect(inspection.summaryLabel == "5/5 inspected")
        #expect(inspection.accessibilityValue.contains("Focus/Edge Inspection"))
        #expect(inspection.accessibilityValue.contains("Synthetic fixture pixels, not private Photos bytes"))
        #expect(inspection.accessibilityValue.contains("deterministic fixture-pixel/metadata review guidance only"))
        #expect(inspection.accessibilityValue.contains("does not inspect private Photos bytes"))
        #expect(inspection.accessibilityValue.contains("final rendered output"))
        #expect(!inspection.accessibilityValue.contains("asset-under"))
        #expect(!inspection.accessibilityValue.contains("asset-center"))
        #expect(!inspection.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(inspection)
        let decoded = try JSONDecoder().decode(BracketProjectFocusEdgeInspection.self, from: data)
        #expect(decoded == inspection)
    }

    @Test func bracketManifestCaptureMotionSnapshotStoresBoundedScalarMetadata() throws {
        let unavailable = BracketManifest.CaptureMotionSnapshot.unavailable(
            source: "unit-test motion manager unavailable",
            captureDurationMilliseconds: 420
        )
        #expect(!unavailable.hasMotionSamples)
        #expect(unavailable.sampleAvailability == "Unavailable")
        #expect(unavailable.summaryLabel == "0 motion samples captured")
        #expect(unavailable.accessibilityValue.contains("Capture Motion Metadata"))
        #expect(unavailable.accessibilityValue.contains("No raw CMMotion samples"))
        #expect(unavailable.accessibilityValue.contains("No motion samples captured"))

        let available = BracketManifest.CaptureMotionSnapshot.available(
            source: "unit-test scalar CMMotion summary",
            sampleCount: 144,
            captureDurationMilliseconds: 1_600,
            maxAngularVelocityDegreesPerSecond: 28,
            maxAccelerationMilliG: 1_040,
            qualityLabel: "Stable handheld scalar summary"
        )
        #expect(available.hasMotionSamples)
        #expect(available.sampleAvailability == "Available")
        #expect(available.summaryLabel == "144 motion samples captured")
        #expect(available.accessibilityValue.contains("Only bounded scalar motion metadata is stored"))
        #expect(available.accessibilityValue.contains("gyroscope streams"))
        #expect(available.accessibilityValue.contains("Stable handheld scalar summary"))

        let data = try JSONEncoder().encode(available)
        let decoded = try JSONDecoder().decode(BracketManifest.CaptureMotionSnapshot.self, from: data)
        #expect(decoded == available)
    }

    @Test func captureMotionAccumulatorBuildsScalarSnapshotsWithoutRawSamples() throws {
        let emptyAccumulator = CaptureMotionAccumulator()
        let unavailable = emptyAccumulator.snapshot(
            source: "unit-test recorder produced no samples",
            durationMilliseconds: 320
        )
        #expect(!unavailable.hasMotionSamples)
        #expect(unavailable.sampleCount == 0)
        #expect(unavailable.captureDurationMilliseconds == 320)
        #expect(unavailable.source == "unit-test recorder produced no samples")
        #expect(unavailable.privacyBoundary.contains("No raw CMMotion samples"))

        var accumulator = CaptureMotionAccumulator()
        accumulator.record(
            rotationRateX: 0,
            rotationRateY: .pi / 6.0,
            rotationRateZ: 0,
            accelerationX: 0,
            accelerationY: 0,
            accelerationZ: 0.2
        )
        accumulator.record(
            rotationRateX: 0,
            rotationRateY: .pi / 2.0,
            rotationRateZ: 0,
            accelerationX: 0,
            accelerationY: 0,
            accelerationZ: 1.2
        )

        let available = accumulator.snapshot(
            source: "unit-test CMMotion scalar accumulator",
            durationMilliseconds: 980
        )
        #expect(available.hasMotionSamples)
        #expect(available.sampleCount == 2)
        #expect(available.captureDurationMilliseconds == 980)
        #expect(available.maxAngularVelocityDegreesPerSecond == 90)
        #expect(available.maxAccelerationMilliG == 1_200)
        #expect(available.qualityLabel == "High motion scalar summary")
        #expect(available.privacyBoundary.contains("Only bounded scalar motion metadata is stored"))
        #expect(available.privacyBoundary.contains("gyroscope streams"))

        let data = try JSONEncoder().encode(available)
        let decoded = try JSONDecoder().decode(BracketManifest.CaptureMotionSnapshot.self, from: data)
        #expect(decoded == available)
    }

    @Test func bracketProjectMotionMetadataReportSummarizesManifestCaptureContract() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectMotionMetadataReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectMotionMetadataReport.kind == "motion-metadata-capture")
        #expect(report.source == "manifestCaptureMotionMetadata")
        #expect(report.hasManifestMotionSnapshot)
        #expect(!report.hasMotionSamples)
        #expect(report.sampleAvailability == "Unavailable")
        #expect(report.sampleCount == 0)
        #expect(report.captureDurationMilliseconds == 420)
        #expect(report.summaryLabel == "0 motion samples captured")
        #expect(report.availabilitySummary == "Unavailable motion metadata")
        #expect(report.accessibilityValue.contains("Motion Metadata Capture"))
        #expect(report.accessibilityValue.contains("Motion metadata capture contract, not live IMU proof"))
        #expect(report.accessibilityValue.contains("The manifest records that motion metadata was unavailable"))
        #expect(report.accessibilityValue.contains("does not include raw CMMotion samples"))
        #expect(report.accessibilityValue.contains("does not prove physical-device motion capture"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectMotionMetadataReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectMotionAlignmentOverlaySummarizesSyntheticScaffolding() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let overlay = BracketProjectMotionAlignmentOverlay.make(project: project)

        #expect(overlay.schemaVersion == 1)
        #expect(BracketProjectMotionAlignmentOverlay.kind == "motion-alignment-overlay")
        #expect(overlay.source == "deterministicManifestFixture")
        #expect(overlay.hasOverlayGuidance)
        #expect(overlay.shotCount == 5)
        #expect(overlay.overlayGuideCount == 5)
        #expect(overlay.baselineIndex == 2)
        #expect(overlay.baselineLabel == "0 EV")
        #expect(overlay.items.count == 5)
        #expect(overlay.items.contains { $0.role == "Alignment anchor" })
        #expect(overlay.items.contains { $0.role == "Darker guard overlay" })
        #expect(overlay.items.contains { $0.role == "Brighter guard overlay" })
        #expect(overlay.maxSyntheticMotionScore > 0)
        #expect(overlay.maxSyntheticAlignmentOffsetPoints > 0)
        #expect(overlay.summaryLabel == "5 overlay guides")
        #expect(overlay.accessibilityValue.contains("Motion/Alignment Overlay"))
        #expect(overlay.accessibilityValue.contains("Synthetic motion/alignment overlay, not real IMU samples"))
        #expect(overlay.accessibilityValue.contains("deterministic fixture-pixel/manifest scaffolding only"))
        #expect(overlay.accessibilityValue.contains("does not read real CMMotion or IMU samples"))
        #expect(overlay.accessibilityValue.contains("does not inspect private Photos bytes"))
        #expect(!overlay.accessibilityValue.contains("asset-under"))
        #expect(!overlay.accessibilityValue.contains("asset-center"))
        #expect(!overlay.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(overlay)
        let decoded = try JSONDecoder().decode(BracketProjectMotionAlignmentOverlay.self, from: data)
        #expect(decoded == overlay)
    }

    @Test func bracketProjectFeatureMatchFixtureReportSummarizesSyntheticMatchingSeam() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectFeatureMatchFixtureReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectFeatureMatchFixtureReport.kind == "feature-match-fixture")
        #expect(report.source == "deterministicFeatureMatchFixture")
        #expect(report.hasFeatureMatchGuidance)
        #expect(report.shotCount == 5)
        #expect(report.featureMatchGuideCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Baseline feature anchor" })
        #expect(report.totalSyntheticFeatureCandidates > 0)
        #expect(report.totalSyntheticMatchedFeaturePairs > 0)
        #expect(report.totalSyntheticFeatureCandidates >= report.totalSyntheticMatchedFeaturePairs)
        #expect(report.totalSyntheticOutlierPairs >= 0)
        #expect(report.averageSyntheticMatchConfidencePercent > 0)
        #expect(report.summaryLabel == "5 feature-match guides")
        #expect(report.accessibilityValue.contains("Feature Match Fixture"))
        #expect(report.accessibilityValue.contains("Synthetic feature-match fixture, not real pixel matching"))
        #expect(report.accessibilityValue.contains("deterministic manifest and fixture-pixel scaffolding only"))
        #expect(report.accessibilityValue.contains("does not inspect real image features"))
        #expect(report.accessibilityValue.contains("descriptor matching"))
        #expect(report.accessibilityValue.contains("homography solving"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectFeatureMatchFixtureReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectAlignmentTransformReportSummarizesSyntheticTransforms() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectAlignmentTransformReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectAlignmentTransformReport.kind == "alignment-transform")
        #expect(report.source == "deterministicManifestAlignment")
        #expect(report.hasTransformGuidance)
        #expect(report.shotCount == 5)
        #expect(report.transformGuideCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Identity transform anchor" })
        #expect(report.items.contains { $0.role == "Dark guard translation" })
        #expect(report.items.contains { $0.role == "Bright guard translation" })
        #expect(report.totalSyntheticFeaturePairs > 0)
        #expect(report.maxSyntheticTranslationPoints > 0)
        #expect(report.averageSyntheticConfidencePercent > 0)
        #expect(report.summaryLabel == "5 transform guides")
        #expect(report.accessibilityValue.contains("Alignment Transform"))
        #expect(report.accessibilityValue.contains("Synthetic alignment transform, not real feature matching"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not detect real image features"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectAlignmentTransformReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectMotionBlurRiskReportSummarizesSyntheticManifestRisk() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectMotionBlurRiskReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectMotionBlurRiskReport.kind == "motion-blur-risk")
        #expect(report.source == "deterministicManifestRisk")
        #expect(report.hasRiskGuidance)
        #expect(report.shotCount == 5)
        #expect(report.riskGuideCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Blur anchor" })
        #expect(report.items.contains { $0.role == "Longer-exposure blur watch" })
        #expect(report.items.contains { $0.role == "Shorter-exposure motion reference" })
        #expect(report.highRiskShotCount > 0)
        #expect(report.maxSyntheticBlurRiskScore > 0)
        #expect(report.summaryLabel == "5 blur-risk guides")
        #expect(report.accessibilityValue.contains("Motion/Blur Risk"))
        #expect(report.accessibilityValue.contains("Synthetic motion/blur risk, not real shutter or sensor evidence"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not read real shutter speed"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectMotionBlurRiskReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectGhostingRiskReportSummarizesSyntheticManifestRisk() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectGhostingRiskReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectGhostingRiskReport.kind == "ghosting-risk")
        #expect(report.source == "deterministicManifestGhostingRisk")
        #expect(report.hasRiskGuidance)
        #expect(report.shotCount == 5)
        #expect(report.riskGuideCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Deghosting anchor" })
        #expect(report.items.contains { $0.role == "Bright ghosting watch" })
        #expect(report.items.contains { $0.role == "Dark ghosting reference" })
        #expect(report.highRiskShotCount > 0)
        #expect(report.maxSyntheticGhostingRiskScore > 0)
        #expect(report.summaryLabel == "5 ghosting-risk guides")
        #expect(report.accessibilityValue.contains("Ghosting Risk"))
        #expect(report.accessibilityValue.contains("Synthetic ghosting risk, not moving-subject detection"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not run optical flow"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectGhostingRiskReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectMovingRegionMaskReportSummarizesSyntheticMaskGuidance() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectMovingRegionMaskReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectMovingRegionMaskReport.kind == "moving-region-mask")
        #expect(report.source == "deterministicManifestMovingRegionMask")
        #expect(report.hasMaskGuidance)
        #expect(report.shotCount == 5)
        #expect(report.maskGuideCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Mask anchor" })
        #expect(report.items.contains { $0.role == "Bright moving-region watch" })
        #expect(report.items.contains { $0.role == "Dark moving-region reference" })
        #expect(report.items.contains { $0.syntheticMaskTileCount > 0 })
        #expect(report.highPriorityMaskCount > 0)
        #expect(report.maxSyntheticMaskCoveragePercent > 0)
        #expect(report.summaryLabel == "5 mask guides")
        #expect(report.accessibilityValue.contains("Moving-Region Mask"))
        #expect(report.accessibilityValue.contains("Synthetic moving-region masks, not real subject segmentation"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not segment moving subjects"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectMovingRegionMaskReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectAlignmentPerformanceReportSummarizesSyntheticWorkBudget() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectAlignmentPerformanceReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectAlignmentPerformanceReport.kind == "alignment-performance")
        #expect(report.source == "deterministicManifestAlignmentPerformance")
        #expect(report.hasPerformanceNotes)
        #expect(report.shotCount == 5)
        #expect(report.performanceNoteCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Performance anchor" })
        #expect(report.items.contains { $0.role == "Bright-frame budget watch" })
        #expect(report.items.contains { $0.role == "Dark-frame budget reference" })
        #expect(report.items.contains { $0.estimatedAlignmentWorkUnits > 0 })
        #expect(report.items.contains { $0.estimatedMaskWorkUnits > 0 })
        #expect(report.totalEstimatedWorkUnits > 0)
        #expect(report.peakEstimatedWorkUnits > 0)
        #expect(report.summaryLabel == "5 performance notes")
        #expect(report.accessibilityValue.contains("Alignment Performance Notes"))
        #expect(report.accessibilityValue.contains("Synthetic alignment performance notes, not measured Instruments timing"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not run Instruments"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectAlignmentPerformanceReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectAlignmentExplanationReportSummarizesUserFacingWatchPoints() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let report = BracketProjectAlignmentExplanationReport.make(project: project)

        #expect(report.schemaVersion == 1)
        #expect(BracketProjectAlignmentExplanationReport.kind == "alignment-explanation")
        #expect(report.source == "deterministicManifestAlignmentExplanation")
        #expect(report.hasUserFacingExplanations)
        #expect(report.shotCount == 5)
        #expect(report.explanationCount == 5)
        #expect(report.baselineIndex == 2)
        #expect(report.baselineLabel == "0 EV")
        #expect(report.items.count == 5)
        #expect(report.items.contains { $0.role == "Base-frame explanation" })
        #expect(report.items.contains { $0.role == "Moving-subject explanation" })
        #expect(report.items.contains { $0.attentionScore > 0 })
        #expect(report.items.contains { $0.photographerGuidance.contains("Inspect") })
        #expect(report.highAttentionShotCount > 0)
        #expect(report.topConcernScore > 0)
        #expect(report.summaryLabel == "5 explanations")
        #expect(report.accessibilityValue.contains("Alignment Explanation"))
        #expect(report.accessibilityValue.contains("Synthetic alignment explanation, not real pixel analysis"))
        #expect(report.accessibilityValue.contains("photographer"))
        #expect(report.accessibilityValue.contains("deterministic manifest scaffolding only"))
        #expect(report.accessibilityValue.contains("does not inspect real image features"))
        #expect(report.accessibilityValue.contains("compute deghosting masks"))
        #expect(report.accessibilityValue.contains("run Instruments"))
        #expect(report.accessibilityValue.contains("private Photos bytes"))
        #expect(!report.accessibilityValue.contains("asset-under"))
        #expect(!report.accessibilityValue.contains("asset-center"))
        #expect(!report.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BracketProjectAlignmentExplanationReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func bracketProjectBestBaseFrameSuggestionChoosesNeutralBestExposure() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let suggestion = BracketProjectBestBaseFrameSuggestion.make(project: project)

        #expect(suggestion.schemaVersion == 1)
        #expect(suggestion.hasSuggestion)
        #expect(suggestion.selectedIndex == 2)
        #expect(suggestion.selectedShotLabel == "Shot 3 / 0 EV")
        #expect(suggestion.selectedDisplayLabel == "0 EV")
        #expect(suggestion.confidenceLabel == "High")
        #expect(suggestion.confidenceScore == 100)
        #expect(suggestion.guardExposureSummary == "2 darker highlight guards and 2 brighter shadow guards")
        #expect(suggestion.rationale.contains("Use Shot 3 / 0 EV as the neutral base frame."))
        #expect(suggestion.accessibilityValue.contains("Best Base Frame Suggestion"))
        #expect(suggestion.accessibilityValue.contains("not a final HDR merge decision"))
        #expect(suggestion.accessibilityValue.contains("does not inspect private Photos bytes"))
        #expect(!suggestion.accessibilityValue.contains("asset-under"))
        #expect(!suggestion.accessibilityValue.contains("asset-center"))
        #expect(!suggestion.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(suggestion)
        let decoded = try JSONDecoder().decode(BracketProjectBestBaseFrameSuggestion.self, from: data)
        #expect(decoded == suggestion)
    }

    @Test func bracketProjectPerShotExposureDistributionSummarizesManifestShots() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let distribution = BracketProjectPerShotExposureDistribution.make(project: project)

        #expect(distribution.schemaVersion == 1)
        #expect(distribution.projectID == project.id)
        #expect(distribution.shotCount == 5)
        #expect(distribution.items.count == 5)
        #expect(distribution.baselineIndex == 2)
        #expect(distribution.baselineDisplayLabel == "0 EV")
        #expect(distribution.evSpread == 8)
        #expect(distribution.evSpreadLabel == "+8.0 EV")
        #expect(distribution.highlightGuardCount == 2)
        #expect(distribution.shadowGuardCount == 2)
        #expect(distribution.guardSummary == "2 darker highlight guards and 2 brighter shadow guards")
        #expect(distribution.clippingWarningCount == 4)
        #expect(distribution.clippingSummary == "4 manifest clipping warnings")
        #expect(distribution.items[0].role == "Darker highlight guard")
        #expect(distribution.items[0].clippingSummary == "Simulated shadow clipping risk")
        #expect(distribution.items[2].role == "Baseline exposure")
        #expect(distribution.items[2].clippingSummary == "No manifest clipping warning")
        #expect(distribution.items[4].role == "Brighter shadow guard")
        #expect(distribution.items[4].clippingSummary == "Simulated highlight clipping risk")
        #expect(distribution.accessibilityValue.contains("Per-shot Exposure Distribution"))
        #expect(distribution.accessibilityValue.contains("EV spread +8.0 EV"))
        #expect(distribution.accessibilityValue.contains("Baseline 0 EV"))
        #expect(distribution.accessibilityValue.contains("not inspect private Photos bytes"))
        #expect(distribution.accessibilityValue.contains("pixel histograms"))
        #expect(!distribution.accessibilityValue.contains("asset-under"))
        #expect(!distribution.accessibilityValue.contains("asset-center"))
        #expect(!distribution.accessibilityValue.contains("private-photos-group"))

        let data = try JSONEncoder().encode(distribution)
        let decoded = try JSONDecoder().decode(BracketProjectPerShotExposureDistribution.self, from: data)
        #expect(decoded == distribution)
    }

    @Test func bracketProjectBeforeAfterScrubPlanChoosesNearestGuardExposure() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let baselinePlan = BracketProjectBeforeAfterScrubPlan.make(project: project, selectedIndex: 2)

        #expect(baselinePlan.schemaVersion == 1)
        #expect(baselinePlan.hasScrubStops)
        #expect(baselinePlan.baselineIndex == 2)
        #expect(baselinePlan.baselineLabel == "0 EV")
        #expect(baselinePlan.comparisonIndex == 1)
        #expect(baselinePlan.comparisonLabel == "-2.0 EV")
        #expect(baselinePlan.comparisonRole == "Darker highlight guard")
        #expect(baselinePlan.comparisonEVDeltaFromBaseline == -2)
        #expect(baselinePlan.stopCount == 5)
        #expect(baselinePlan.scrubStops.map(\.positionPercent) == [0, 25, 50, 75, 100])
        #expect(baselinePlan.scrubStops.first?.label == "Before base frame")
        #expect(baselinePlan.scrubStops.last?.label == "After comparison frame")
        #expect(baselinePlan.scrubStops.first?.previewRGBABytes.count == 12)
        #expect(baselinePlan.accessibilityValue.contains("Before/After Scrub Plan"))
        #expect(baselinePlan.accessibilityValue.contains("Baseline 0 EV"))
        #expect(baselinePlan.accessibilityValue.contains("Compare -2.0 EV"))
        #expect(baselinePlan.accessibilityValue.contains("5 scrub stops"))
        #expect(baselinePlan.accessibilityValue.contains("not derived from private Photos bytes"))
        #expect(baselinePlan.accessibilityValue.contains("not a final HDR merge decision"))
        #expect(!baselinePlan.accessibilityValue.contains("asset-under"))
        #expect(!baselinePlan.accessibilityValue.contains("asset-center"))
        #expect(!baselinePlan.accessibilityValue.contains("private-photos-group"))

        let selectedShadowPlan = BracketProjectBeforeAfterScrubPlan.make(project: project, selectedIndex: 4)
        #expect(selectedShadowPlan.comparisonIndex == 4)
        #expect(selectedShadowPlan.comparisonLabel == "+4.0 EV")
        #expect(selectedShadowPlan.comparisonRole == "Brighter shadow guard")

        let data = try JSONEncoder().encode(baselinePlan)
        let decoded = try JSONDecoder().decode(BracketProjectBeforeAfterScrubPlan.self, from: data)
        #expect(decoded == baselinePlan)
    }

    @Test func bracketProjectReviewSnapshotIncludesResourceInspectionSummary() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let baseProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let inspection = BracketProjectResourceInspection.make(
            project: baseProject,
            source: .photosAssetResource,
            inspectedAt: Date(timeIntervalSince1970: 40),
            shotResources: [
                BracketProjectResourceInspection.ShotResources(
                    index: 0,
                    assetIdentifier: "asset-under",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "photo",
                            originalFilename: "IMG_0001.HEIC",
                            uniformTypeIdentifier: "public.heic"
                        ),
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0001.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        )
                    ]
                )
            ]
        )
        let project = baseProject.withResourceInspection(
            inspection,
            updatedAt: Date(timeIntervalSince1970: 41)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 50),
            source: "Inspection Unit Test"
        )

        #expect(snapshot.accessibilityValue.contains("Resource Inspection"))
        #expect(snapshot.accessibilityValue.contains("Photos asset resources"))
        #expect(snapshot.accessibilityValue.contains("1 inspected shots"))
        #expect(snapshot.accessibilityValue.contains("1 complete pairs"))
        #expect(snapshot.accessibilityValue.contains("0 mismatches"))
    }

    @Test func bracketProjectReviewSnapshotIncludesThumbnailInspectionSummary() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let baseProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let inspection = BracketProjectThumbnailInspection.make(
            project: baseProject,
            source: .photosImageManager,
            inspectedAt: Date(timeIntervalSince1970: 70),
            shotThumbnails: [
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 0,
                    assetIdentifier: "asset-under",
                    targetPixelWidth: 1170,
                    targetPixelHeight: 2532,
                    deliveredPixelWidth: 1024,
                    deliveredPixelHeight: 768,
                    deliveryMode: "highQualityFormat",
                    contentMode: "aspectFit"
                ),
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 1,
                    assetIdentifier: "asset-under-mid",
                    targetPixelWidth: 1170,
                    targetPixelHeight: 2532,
                    deliveredPixelWidth: 640,
                    deliveredPixelHeight: 480,
                    deliveryMode: "highQualityFormat",
                    contentMode: "aspectFit",
                    isDegraded: true
                )
            ]
        )
        let project = baseProject.withThumbnailInspection(
            inspection,
            updatedAt: Date(timeIntervalSince1970: 71)
        )
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 80),
            source: "Thumbnail Unit Test"
        )

        #expect(snapshot.accessibilityValue.contains("Thumbnail Inspection"))
        #expect(snapshot.accessibilityValue.contains("Photos image manager thumbnails"))
        #expect(snapshot.accessibilityValue.contains("2 requested shots"))
        #expect(snapshot.accessibilityValue.contains("2 delivered thumbnails"))
        #expect(snapshot.accessibilityValue.contains("1 degraded callbacks"))
        #expect(snapshot.accessibilityValue.contains("0 errors"))
    }

    @Test func bracketProjectReviewSnapshotIncludesMergeReadinessSummary() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let report = BracketProjectMergeReadinessReport.make(project: project)
        let snapshot = BracketProjectReviewSnapshot(
            project: project,
            openedAt: Date(timeIntervalSince1970: 90),
            source: "Merge Unit Test"
        )

        #expect(report.score == 95)
        #expect(report.label == "Ready for cautious merge preview")
        #expect(report.blockerCount == 0)
        #expect(report.cautionCount == 0)
        #expect(report.evidence.map(\.id).contains("resource-inspection-missing"))
        #expect(snapshot.accessibilityValue.contains("Merge Readiness"))
        #expect(snapshot.accessibilityValue.contains("Score 95"))
        #expect(snapshot.accessibilityValue.contains("Ready for cautious merge preview"))
        #expect(snapshot.accessibilityValue.contains("0 blockers"))
        #expect(snapshot.accessibilityValue.contains("0 cautions"))
    }

    @Test @MainActor func cameraControllerRestoresSelectedProjectReviewFromStore() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let photosProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Window"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let simulatedPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let simulatedReview = BracketReviewSequence.make(
            plan: simulatedPlan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 30)
        )
        let simulatedProject = BracketProject.make(
            manifest: simulatedReview.manifest(
                groupIdentifier: "restore-simulated-group",
                source: .simulated,
                plan: simulatedPlan
            ),
            reviewSequence: simulatedReview,
            createdAt: Date(timeIntervalSince1970: 30)
        )
        try store.save(photosProject)
        try store.save(simulatedProject)
        let camera = CameraController(projectStore: store)

        let snapshot = try #require(camera.restoreProjectReview(
            projectID: photosProject.id,
            source: "Unit Test Handoff",
            openedAt: Date(timeIntervalSince1970: 40)
        ))

        #expect(snapshot.project.id == photosProject.id)
        #expect(snapshot.sequence == BracketReviewSequence.make(manifest: photosProject.manifest))
        #expect(camera.restoredProjectReviewSnapshot == snapshot)
        #expect(camera.lastBracketProject?.id == photosProject.id)
        #expect(camera.lastBracketManifest == photosProject.manifest)
        #expect(camera.lastBracketReviewSequence == snapshot.sequence)
        #expect(try store.current()?.id == photosProject.id)
        #expect(camera.bracketProjectLibrarySnapshot.currentProjectID == photosProject.id)
        #expect(camera.bracketProjectLibrarySnapshot.projects.map(\.id).contains(photosProject.id))
    }

    @Test func fileBracketProjectStoreSearchesProjectsAndDeletesAll() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let photosProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Archive"],
            userNote: "Window recovery candidate",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let simulatedPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let simulatedReview = BracketReviewSequence.make(
            plan: simulatedPlan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 30)
        )
        let simulatedProject = BracketProject.make(
            manifest: simulatedReview.manifest(
                groupIdentifier: "second-search-group",
                source: .simulated,
                plan: simulatedPlan
            ),
            reviewSequence: simulatedReview,
            acceptedTags: ["Tripod"],
            createdAt: Date(timeIntervalSince1970: 30)
        )

        try store.save(photosProject)
        try store.save(simulatedProject)

        #expect(try store.search("window archive").map(\.id) == [photosProject.id])
        #expect(try store.search("tripod simulated 3 shot").map(\.id) == [simulatedProject.id])
        #expect(try store.librarySnapshot().accessibilityValue.contains("2 projects"))

        try store.deleteAll()

        #expect(try store.loadAll().isEmpty)
        #expect(try store.current() == nil)
        #expect(try store.latest() == nil)
        #expect(try store.librarySnapshot().accessibilityValue.contains("No saved projects"))
    }

    @Test func bracketProjectExportBundleRedactsIdentifiersByDefault() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Export test fallback."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            acceptedTags: ["Portfolio Candidate"],
            diagnosticsSummary: "5 events | Latest: Info Capture | Bracket complete",
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let projectFile = try #require(bundle.file(kind: "project"))
        let manifestFile = try #require(bundle.file(kind: "manifest"))
        let sidecarFile = try #require(bundle.file(kind: "sidecar"))
        let contactSheetFile = try #require(bundle.file(kind: "contact-sheet"))
        let contactSheetHTMLFile = try #require(bundle.file(kind: "contact-sheet-html"))
        let contactSheetPreviewFile = try #require(bundle.file(kind: "contact-sheet-preview"))
        let contactSheetImageFile = try #require(bundle.file(kind: "contact-sheet-image"))
        let contactSheetPDFFile = try #require(bundle.file(kind: "contact-sheet-pdf"))
        let captureQualityReportFile = try #require(bundle.file(kind: "capture-quality-report"))
        let assetResourceReportFile = try #require(bundle.file(kind: "asset-resource-report"))
        let mergeReadinessReportFile = try #require(bundle.file(kind: "merge-readiness-report"))
        let imageBundleManifestFile = try #require(bundle.file(kind: "image-bundle-manifest"))
        let imageBundleDraftPackageFile = try #require(bundle.file(kind: "image-bundle-draft-package"))
        let finalOutputManifestFile = try #require(bundle.file(kind: "final-output-manifest"))
        let finalOutputReadinessAuditFile = try #require(bundle.file(kind: "final-output-readiness-audit"))
        let finalOutputPreviewImageFile = try #require(bundle.file(kind: "final-output-preview-image"))
        let finalOutputDraftJPEGFile = try #require(bundle.file(kind: "final-output-draft-review-jpeg"))
        let exposureComparisonFile = try #require(bundle.file(kind: "exposure-comparison"))
        let sideBySidePixelComparisonFile = try #require(bundle.file(kind: "side-by-side-pixel-comparison"))
        let fusionPreviewFile = try #require(bundle.file(kind: "fusion-preview"))
        let exportNoteFile = try #require(bundle.file(kind: "export-note"))
        let privacyFile = try #require(bundle.file(kind: "privacy-report"))
        let diagnosticsFile = try #require(bundle.file(kind: "diagnostics-report"))
        let archiveIntegrityFile = try #require(bundle.file(kind: BracketProjectArchiveIntegrityManifest.kind))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let contactSheet = try decoder.decode(
            BracketProjectContactSheet.self,
            from: Data(contactSheetFile.contents.utf8)
        )
        let exposureComparison = try decoder.decode(
            BracketProjectExposureComparison.self,
            from: Data(exposureComparisonFile.contents.utf8)
        )
        let contactSheetPreview = try decoder.decode(
            BracketProjectContactSheetPreview.self,
            from: Data(contactSheetPreviewFile.contents.utf8)
        )
        let sideBySidePixelComparison = try decoder.decode(
            BracketProjectSideBySidePixelComparison.self,
            from: Data(sideBySidePixelComparisonFile.contents.utf8)
        )
        let captureQualityReport = try decoder.decode(
            BracketProjectCaptureQualityReport.self,
            from: Data(captureQualityReportFile.contents.utf8)
        )
        let assetResourceReport = try decoder.decode(
            BracketProjectAssetResourceReport.self,
            from: Data(assetResourceReportFile.contents.utf8)
        )
        let mergeReadinessReport = try decoder.decode(
            BracketProjectMergeReadinessReport.self,
            from: Data(mergeReadinessReportFile.contents.utf8)
        )
        let imageBundleManifest = try decoder.decode(
            BracketProjectImageBundleManifest.self,
            from: Data(imageBundleManifestFile.contents.utf8)
        )
        let imageBundleDraftPackageData = try #require(Data(base64Encoded: imageBundleDraftPackageFile.contents))
        let imageBundleDraftPackage = try decoder.decode(
            BracketProjectImageBundleDraftPackageDocument.Package.self,
            from: imageBundleDraftPackageData
        )
        let finalOutputManifest = try decoder.decode(
            BracketProjectFinalOutputManifest.self,
            from: Data(finalOutputManifestFile.contents.utf8)
        )
        let finalOutputReadinessAudit = try decoder.decode(
            BracketProjectFinalOutputReadinessAudit.self,
            from: Data(finalOutputReadinessAuditFile.contents.utf8)
        )
        let fusionPreview = try decoder.decode(
            BracketProjectFusionPreviewReport.self,
            from: Data(fusionPreviewFile.contents.utf8)
        )
        let exportNote = try decoder.decode(
            BracketProjectExportNote.self,
            from: Data(exportNoteFile.contents.utf8)
        )
        let archiveIntegrityManifest = try decoder.decode(
            BracketProjectArchiveIntegrityManifest.self,
            from: Data(archiveIntegrityFile.contents.utf8)
        )
        let exportedProject = try decoder.decode(
            BracketProject.self,
            from: Data(projectFile.contents.utf8)
        )

        #expect(bundle.schemaVersion == 1)
        #expect(bundle.projectID == "project-photos-metadata-5shots-schema1-12")
        #expect(bundle.privacyLevel == .metadataOnly)
        #expect(BracketProjectExportPrivacyLevel.metadataOnly.accessibilityValue.contains("Photos local identifiers are redacted"))
        #expect(bundle.files.map(\.kind) == ["project", "manifest", "sidecar", "contact-sheet", "contact-sheet-html", "contact-sheet-preview", "contact-sheet-image", "contact-sheet-pdf", "capture-quality-report", "asset-resource-report", "merge-readiness-report", "image-bundle-manifest", "image-bundle-draft-package", "final-output-manifest", "final-output-readiness-audit", "final-output-preview-image", "final-output-draft-review-jpeg", "exposure-comparison", "side-by-side-pixel-comparison", "fusion-preview", "export-note", "privacy-report", "diagnostics-report", "archive-integrity-manifest"])
        let exportNoteArchiveRange = try #require(
            bundle.archiveText.range(of: "----- BEGIN \(exportNoteFile.filename) -----")
        )
        let privacyArchiveRange = try #require(
            bundle.archiveText.range(of: "----- BEGIN \(privacyFile.filename) -----")
        )
        #expect(exportNoteArchiveRange.lowerBound < privacyArchiveRange.lowerBound)
        #expect(bundle.accessibilityValue.contains("Metadata only"))
        #expect(archiveIntegrityManifest.projectID == bundle.projectID)
        #expect(archiveIntegrityManifest.payloadCount == bundle.files.count - 1)
        #expect(archiveIntegrityManifest.items.map(\.kind) == bundle.files.dropLast().map(\.kind))
        #expect(archiveIntegrityManifest.items.first?.byteCount == projectFile.byteCount)
        #expect(archiveIntegrityManifest.items.allSatisfy { $0.sha256Hex.count == 64 })
        #expect(archiveIntegrityManifest.matches(files: bundle.files, projectID: bundle.projectID))
        #expect(!projectFile.contents.contains("asset-under"))
        #expect(!manifestFile.contents.contains("asset-under"))
        #expect(!contactSheetFile.contents.contains("asset-under"))
        #expect(!contactSheetHTMLFile.contents.contains("asset-under"))
        #expect(!contactSheetPreviewFile.contents.contains("asset-under"))
        #expect(!contactSheetImageFile.contents.contains("asset-under"))
        #expect(!contactSheetPDFFile.contents.contains("asset-under"))
        #expect(!captureQualityReportFile.contents.contains("asset-under"))
        #expect(!assetResourceReportFile.contents.contains("asset-under"))
        #expect(!mergeReadinessReportFile.contents.contains("asset-under"))
        #expect(!imageBundleManifestFile.contents.contains("asset-under"))
        #expect(!imageBundleDraftPackageFile.contents.contains("asset-under"))
        #expect(!finalOutputManifestFile.contents.contains("asset-under"))
        #expect(!finalOutputReadinessAuditFile.contents.contains("asset-under"))
        #expect(!finalOutputPreviewImageFile.contents.contains("asset-under"))
        #expect(!finalOutputDraftJPEGFile.contents.contains("asset-under"))
        #expect(!exposureComparisonFile.contents.contains("asset-under"))
        #expect(!sideBySidePixelComparisonFile.contents.contains("asset-under"))
        #expect(!fusionPreviewFile.contents.contains("asset-under"))
        #expect(!exportNoteFile.contents.contains("asset-under"))
        #expect(!archiveIntegrityFile.contents.contains("asset-under"))
        #expect(!projectFile.contents.contains("private-photos-group"))
        #expect(!manifestFile.contents.contains("private-photos-group"))
        #expect(!contactSheetFile.contents.contains("private-photos-group"))
        #expect(!contactSheetHTMLFile.contents.contains("private-photos-group"))
        #expect(!contactSheetPreviewFile.contents.contains("private-photos-group"))
        #expect(!contactSheetImageFile.contents.contains("private-photos-group"))
        #expect(!contactSheetPDFFile.contents.contains("private-photos-group"))
        #expect(!captureQualityReportFile.contents.contains("private-photos-group"))
        #expect(!assetResourceReportFile.contents.contains("private-photos-group"))
        #expect(!mergeReadinessReportFile.contents.contains("private-photos-group"))
        #expect(!imageBundleManifestFile.contents.contains("private-photos-group"))
        #expect(!imageBundleDraftPackageFile.contents.contains("private-photos-group"))
        #expect(!finalOutputManifestFile.contents.contains("private-photos-group"))
        #expect(!finalOutputReadinessAuditFile.contents.contains("private-photos-group"))
        #expect(!finalOutputPreviewImageFile.contents.contains("private-photos-group"))
        #expect(!finalOutputDraftJPEGFile.contents.contains("private-photos-group"))
        #expect(!exposureComparisonFile.contents.contains("private-photos-group"))
        #expect(!sideBySidePixelComparisonFile.contents.contains("private-photos-group"))
        #expect(!fusionPreviewFile.contents.contains("private-photos-group"))
        #expect(!exportNoteFile.contents.contains("private-photos-group"))
        #expect(!archiveIntegrityFile.contents.contains("private-photos-group"))
        #expect(projectFile.contents.contains("photos-metadata-5shots-schema1-0"))
        #expect(manifestFile.contents.contains("photos-metadata-5shots-schema1-0"))
        #expect(sidecarFile.contents.contains("\"source\" : \"deterministicFallback\""))
        #expect(sidecarFile.contents.contains("Generated from manifest and review state only"))
        #expect(contactSheet.projectID == bundle.projectID)
        #expect(contactSheet.shotCount == 5)
        #expect(contactSheet.items.map(\.displayLabel) == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(contactSheet.items.filter(\.isBestExposureCandidate).map(\.displayLabel) == ["0 EV"])
        #expect(contactSheet.items.allSatisfy { $0.fileType == "RAW + Processed" })
        #expect(contactSheet.accessibilityValue.contains("Contact Sheet"))
        #expect(contactSheetHTMLFile.mimeType == "text/html")
        #expect(contactSheetHTMLFile.contents.contains("<!doctype html>"))
        #expect(contactSheetHTMLFile.contents.contains("Rendered Contact Sheet"))
        #expect(contactSheetHTMLFile.contents.contains("data-shot-index=\"2\""))
        #expect(contactSheetHTMLFile.contents.contains("Best exposure candidate"))
        #expect(contactSheetHTMLFile.contents.contains("Metadata placeholders only"))
        #expect(contactSheetPreview.projectID == bundle.projectID)
        #expect(contactSheetPreview.source == "deterministicFixture")
        #expect(contactSheetPreview.tileWidth == 3)
        #expect(contactSheetPreview.tileHeight == 2)
        #expect(contactSheetPreview.tileCount == 5)
        #expect(contactSheetPreview.shotCount == 5)
        #expect(contactSheetPreview.tiles.map(\.displayLabel) == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(contactSheetPreview.tiles.allSatisfy { tile in
            tile.byteCount == 24
                && tile.rgbaBytes.count == 24
                && tile.rgbaBytes[3] == 255
                && tile.rgbaBytes[7] == 255
                && tile.rgbaBytes[23] == 255
        })
        #expect(contactSheetPreview.tiles.filter(\.isBestExposureCandidate).map(\.displayLabel) == ["0 EV"])
        #expect(contactSheetPreview.boundary.contains("not derived from private Photos bytes"))
        #expect(contactSheetPreview.accessibilityValue.contains("Contact Sheet Preview"))
        let contactSheetRenderedImage = try #require(
            BracketProjectContactSheetImageDocument.renderedImage(preview: contactSheetPreview)
        )
        let contactSheetImageData = try #require(Data(base64Encoded: contactSheetImageFile.contents))
        let contactSheetImageSource = try #require(CGImageSourceCreateWithData(contactSheetImageData as CFData, nil))
        let contactSheetImageProperties = try #require(
            CGImageSourceCopyPropertiesAtIndex(contactSheetImageSource, 0, nil) as? [CFString: Any]
        )
        #expect(contactSheetImageFile.mimeType == "image/png")
        #expect(contactSheetImageFile.filename.hasSuffix("-contact-sheet-image.png.base64"))
        #expect(Array(contactSheetImageData.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        #expect(contactSheetRenderedImage.width == 164)
        #expect(contactSheetRenderedImage.height == 76)
        #expect(contactSheetRenderedImage.byteCount == 164 * 76 * 4)
        #expect(contactSheetImageProperties[kCGImagePropertyPixelWidth] as? Int == contactSheetRenderedImage.width)
        #expect(contactSheetImageProperties[kCGImagePropertyPixelHeight] as? Int == contactSheetRenderedImage.height)
        #expect(contactSheetImageFile.contents == BracketProjectContactSheetImageDocument.base64PNG(preview: contactSheetPreview))
        let contactSheetPDFData = try #require(Data(base64Encoded: contactSheetPDFFile.contents))
        let contactSheetPDFProvider = try #require(CGDataProvider(data: contactSheetPDFData as CFData))
        let contactSheetPDFDocument = try #require(CGPDFDocument(contactSheetPDFProvider))
        let contactSheetPDFPage = try #require(contactSheetPDFDocument.page(at: 1))
        #expect(contactSheetPDFFile.mimeType == "application/pdf")
        #expect(contactSheetPDFFile.filename.hasSuffix("-contact-sheet.pdf.base64"))
        #expect(String(decoding: contactSheetPDFData.prefix(8), as: UTF8.self) == "%PDF-1.4")
        #expect(contactSheetPDFData.range(of: Data("startxref".utf8)) != nil)
        #expect(Int(contactSheetPDFPage.getBoxRect(.mediaBox).width) == contactSheetRenderedImage.width)
        #expect(Int(contactSheetPDFPage.getBoxRect(.mediaBox).height) == contactSheetRenderedImage.height)
        #expect(contactSheetPDFFile.contents == BracketProjectContactSheetPDFDocument.base64PDF(preview: contactSheetPreview))
        #expect(captureQualityReport.projectID == bundle.projectID)
        #expect(captureQualityReport.shotCount == 5)
        #expect(captureQualityReport.availableShotCount == 5)
        #expect(captureQualityReport.missingShotCount == 0)
        #expect(captureQualityReport.failedShotCount == 0)
        #expect(captureQualityReport.evSpread == 8)
        #expect(captureQualityReport.highlightGuardCount == 2)
        #expect(captureQualityReport.shadowGuardCount == 2)
        #expect(captureQualityReport.rawAvailableCount == 5)
        #expect(captureQualityReport.processedAvailableCount == 5)
        #expect(captureQualityReport.readinessScore == 100)
        #expect(captureQualityReport.readinessLabel == "Ready for careful review")
        #expect(captureQualityReport.findings.map(\.id).contains("sequence-complete"))
        #expect(captureQualityReport.boundary.contains("does not inspect private Photos bytes"))
        #expect(captureQualityReport.accessibilityValue.contains("Capture Quality"))
        #expect(assetResourceReport.projectID == bundle.projectID)
        #expect(assetResourceReport.shotCount == 5)
        #expect(assetResourceReport.assetReferenceCount == 5)
        #expect(assetResourceReport.rawAvailableCount == 5)
        #expect(assetResourceReport.processedAvailableCount == 5)
        #expect(assetResourceReport.completePairCount == 5)
        #expect(assetResourceReport.missingAssetCount == 0)
        #expect(assetResourceReport.recoveryIdentifierCount == 0)
        #expect(assetResourceReport.identifierPolicy.contains("redacted"))
        #expect(assetResourceReport.items.map(\.resourceState) == [
            "raw-and-processed-ready",
            "raw-and-processed-ready",
            "raw-and-processed-ready",
            "raw-and-processed-ready",
            "raw-and-processed-ready",
        ])
        #expect(assetResourceReport.items.allSatisfy { !$0.hasRecoveryIdentifier })
        #expect(assetResourceReport.items.allSatisfy { $0.missingRepresentationLabels.isEmpty })
        #expect(assetResourceReport.boundary.contains("does not fetch Photos resources"))
        #expect(assetResourceReport.accessibilityValue.contains("Asset Resources"))
        #expect(mergeReadinessReport.projectID == bundle.projectID)
        #expect(mergeReadinessReport.score == 95)
        #expect(mergeReadinessReport.label == "Ready for cautious merge preview")
        #expect(mergeReadinessReport.blockerCount == 0)
        #expect(mergeReadinessReport.cautionCount == 0)
        #expect(mergeReadinessReport.evidence.map(\.id).contains("resource-inspection-missing"))
        #expect(mergeReadinessReport.boundary.contains("does not inspect private Photos bytes"))
        #expect(mergeReadinessReport.accessibilityValue.contains("Merge Readiness"))
        #expect(imageBundleManifest.projectID == bundle.projectID)
        #expect(imageBundleManifest.privacyLevel == .metadataOnly)
        #expect(imageBundleManifest.createdAt == Date(timeIntervalSince1970: 20))
        #expect(imageBundleManifest.shotCount == 5)
        #expect(imageBundleManifest.exportableShotCount == 5)
        #expect(imageBundleManifest.rawRequestedCount == 5)
        #expect(imageBundleManifest.processedRequestedCount == 5)
        #expect(imageBundleManifest.completeRawProcessedPairCount == 5)
        #expect(imageBundleManifest.missingRepresentationCount == 0)
        #expect(imageBundleManifest.recoveryIdentifierCount == 0)
        #expect(imageBundleManifest.items.map(\.bundleReadiness) == [
            "ready-raw-processed-pair",
            "ready-raw-processed-pair",
            "ready-raw-processed-pair",
            "ready-raw-processed-pair",
            "ready-raw-processed-pair",
        ])
        #expect(imageBundleManifest.items.allSatisfy { !$0.assetIdentifierIncluded })
        #expect(imageBundleManifest.items.allSatisfy { $0.requestedRepresentations == ["Processed", "RAW"] })
        #expect(imageBundleManifest.items.allSatisfy { $0.plannedFilenames.count == 2 })
        #expect(imageBundleManifest.items.first?.plannedFilenames.first?.hasSuffix("-shot-001--4.0EV-processed.heic") == true)
        #expect(imageBundleManifest.items.first?.plannedFilenames.last?.hasSuffix("-shot-001--4.0EV-raw.dng") == true)
        #expect(imageBundleManifest.boundary.contains("Metadata-only selected image/RAW bundle manifest"))
        #expect(imageBundleManifest.accessibilityValue.contains("Image Bundle Manifest"))
        #expect(imageBundleDraftPackageFile.mimeType == "application/vnd.bracketer.image-bundle-draft+json")
        #expect(imageBundleDraftPackageFile.filename.hasSuffix("-image-bundle-draft-package.json.base64"))
        #expect(imageBundleDraftPackageFile.contents == BracketProjectImageBundleDraftPackageDocument.base64Package(
            manifest: imageBundleManifest
        ))
        #expect(imageBundleDraftPackage.kind == "image-bundle-draft-package")
        #expect(imageBundleDraftPackage.projectID == bundle.projectID)
        #expect(imageBundleDraftPackage.privacyLevel == .metadataOnly)
        #expect(imageBundleDraftPackage.sourceManifestKind == "image-bundle-manifest")
        #expect(imageBundleDraftPackage.entryCount == 10)
        #expect(imageBundleDraftPackage.totalByteCount == imageBundleDraftPackage.entries.reduce(0) { $0 + $1.byteCount })
        #expect(imageBundleDraftPackage.entries.first?.representation == "Processed")
        #expect(imageBundleDraftPackage.entries.first?.plannedFilename.hasSuffix("-shot-001--4.0EV-processed.heic") == true)
        #expect(imageBundleDraftPackage.entries.last?.representation == "RAW")
        #expect(imageBundleDraftPackage.entries.allSatisfy { $0.sha256Hex.count == 64 })
        let firstDraftPackagePayloadBase64 = try #require(
            imageBundleDraftPackage.entries.first?.syntheticPayloadBase64
        )
        let firstDraftPackagePayload = try #require(
            Data(base64Encoded: firstDraftPackagePayloadBase64)
        )
        let firstDraftPackagePayloadText = String(decoding: firstDraftPackagePayload, as: UTF8.self)
        #expect(firstDraftPackagePayloadText.contains("Bracketer synthetic image bundle draft"))
        #expect(firstDraftPackagePayloadText.contains("Representation: Processed"))
        #expect(imageBundleDraftPackage.boundary.contains("not private Photos bytes"))
        #expect(finalOutputManifest.projectID == bundle.projectID)
        #expect(finalOutputManifest.privacyLevel == .metadataOnly)
        #expect(finalOutputManifest.createdAt == Date(timeIntervalSince1970: 20))
        #expect(finalOutputManifest.sourceExposureCount == 5)
        #expect(finalOutputManifest.completeResourcePairCount == 5)
        #expect(finalOutputManifest.previewArtifactAvailable)
        #expect(!finalOutputManifest.finalRenderedBytesIncluded)
        #expect(finalOutputManifest.outputCount == 3)
        #expect(finalOutputManifest.readyOutputCount == 0)
        #expect(finalOutputManifest.blockedOutputCount == 3)
        #expect(finalOutputManifest.outputs.map(\.id) == [
            "tone-mapped-review-jpeg",
            "hdr-heif-master",
            "lightroom-reference-tiff",
        ])
        #expect(finalOutputManifest.outputs.first?.filename.hasSuffix("-tone-mapped-review.jpg") == true)
        #expect(finalOutputManifest.outputs.first?.readiness == "planned-preview-only")
        #expect(finalOutputManifest.outputs.first?.provenanceInputs.contains("fusion-preview") == true)
        #expect(finalOutputManifest.outputs.allSatisfy { !$0.blockers.isEmpty })
        #expect(finalOutputManifest.boundary.contains("Final-output export plan only"))
        #expect(finalOutputManifest.accessibilityValue.contains("Final Output Manifest"))
        #expect(finalOutputManifest.accessibilityValue.contains("0 ready"))
        #expect(finalOutputManifest.accessibilityValue.contains("3 blocked"))
        #expect(finalOutputManifest.accessibilityValue.contains("5 source exposures"))
        #expect(finalOutputManifest.accessibilityValue.contains("5 complete resource pairs"))
        #expect(finalOutputManifest.accessibilityValue.contains("Preview artifact available"))
        #expect(finalOutputManifest.accessibilityValue.contains("No final rendered bytes"))
        #expect(finalOutputManifest.accessibilityValue.contains("Ready outputs: none"))
        #expect(finalOutputManifest.accessibilityValue.contains("Blocked outputs: Tone-mapped review JPEG, HDR HEIF master, Lightroom reference TIFF"))
        #expect(finalOutputManifest.accessibilityValue.contains("3 recommendations"))
        #expect(finalOutputManifest.accessibilityValue.contains("Recommendations: Tone-mapped review JPEG: Use the fusion preview as review context only"))
        #expect(finalOutputManifest.accessibilityValue.contains("HDR HEIF master: Keep this as a planned professional output until RAW/processed bytes"))
        #expect(finalOutputManifest.accessibilityValue.contains("No final rendered outputs are available yet"))
        #expect(finalOutputManifest.accessibilityValue.contains("without including final rendered image bytes"))
        #expect(finalOutputReadinessAuditFile.filename.hasSuffix("-final-output-readiness-audit.json"))
        #expect(finalOutputReadinessAudit.projectID == bundle.projectID)
        #expect(finalOutputReadinessAudit.outputCount == finalOutputManifest.outputCount)
        #expect(finalOutputReadinessAudit.readyOutputCount == finalOutputManifest.readyOutputCount)
        #expect(finalOutputReadinessAudit.blockedOutputCount == finalOutputManifest.blockedOutputCount)
        #expect(finalOutputReadinessAudit.blockerReasonCount == 2)
        #expect(finalOutputReadinessAudit.recommendationCount == 3)
        #expect(finalOutputReadinessAudit.statusLabel == "Follow-up before final export")
        #expect(finalOutputReadinessAudit.summaryLine == "0/3 outputs ready; 3 blocked; 2 blocker reason(s); 3 recommendation(s).")
        #expect(finalOutputReadinessAudit.matches(manifest: finalOutputManifest))
        #expect(finalOutputReadinessAudit.accessibilityValue.contains("Final Output Readiness Audit"))
        #expect(finalOutputReadinessAudit.accessibilityValue.contains("No final rendered bytes"))
        #expect(finalOutputReadinessAudit.accessibilityValue.contains("metadata-only review/export guidance"))
        #expect(exposureComparison.projectID == bundle.projectID)
        #expect(exposureComparison.baselineDisplayLabel == "0 EV")
        #expect(exposureComparison.items.map(\.role) == [
            "Darker highlight guard",
            "Darker highlight guard",
            "Baseline exposure",
            "Brighter shadow guard",
            "Brighter shadow guard",
        ])
        #expect(exposureComparison.items.map(\.evDeltaFromBaseline) == [-4.0, -2.0, 0.0, 2.0, 4.0])
        #expect(exposureComparison.accessibilityValue.contains("Exposure Comparison"))
        #expect(sideBySidePixelComparison.projectID == bundle.projectID)
        #expect(sideBySidePixelComparison.source == "deterministicFixture")
        #expect(sideBySidePixelComparison.baselineLabel == "0 EV")
        #expect(sideBySidePixelComparison.baselineEVOffset == 0)
        #expect(sideBySidePixelComparison.comparisonCount == 4)
        #expect(sideBySidePixelComparison.pairs.map(\.comparisonLabel) == ["-4.0 EV", "-2.0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(sideBySidePixelComparison.pairs.allSatisfy { pair in
            pair.byteCount == 12
                && pair.baselineRGBABytes.count == 12
                && pair.comparisonRGBABytes.count == 12
                && pair.differenceRGBABytes.count == 12
                && pair.differenceRGBABytes[3] == 255
                && pair.differenceRGBABytes[7] == 255
                && pair.differenceRGBABytes[11] == 255
        })
        let brightestPixelPair = try #require(sideBySidePixelComparison.pairs.last)
        #expect(brightestPixelPair.comparisonLabel == "+4.0 EV")
        #expect(brightestPixelPair.maxChannelDelta > 0)
        #expect(brightestPixelPair.accessibilityValue.contains("Side-by-side Pixel Compare"))
        #expect(sideBySidePixelComparison.boundary.contains("not derived from private Photos bytes"))
        #expect(sideBySidePixelComparison.accessibilityValue.contains("4 comparisons"))
        #expect(fusionPreview.projectID == bundle.projectID)
        #expect(fusionPreview.source == "deterministicFixture")
        #expect(fusionPreview.width == 3)
        #expect(fusionPreview.height == 1)
        #expect(fusionPreview.sourceCount == 5)
        #expect(fusionPreview.evLabels == ["-4.0 EV", "-2.0 EV", "0 EV", "+2.0 EV", "+4.0 EV"])
        #expect(fusionPreview.byteCount == 12)
        #expect(fusionPreview.rgbaBytes.count == 12)
        #expect(fusionPreview.rgbaBytes[3] == 255)
        #expect(fusionPreview.rgbaBytes[7] == 255)
        #expect(fusionPreview.rgbaBytes[11] == 255)
        #expect(fusionPreview.boundary.contains("not a final HDR render"))
        #expect(fusionPreview.accessibilityValue.contains("Fusion Preview"))
        #expect(exportNoteFile.filename.hasSuffix("-export-note.json"))
        #expect(exportNote.projectID == bundle.projectID)
        #expect(exportNote.title == "Export note for 5-shot photos bracket")
        #expect(exportNote.summary.contains("5-shot photos bracket"))
        #expect(exportNote.summary.contains("20 metadata payloads"))
        #expect(exportNote.privacyLevel == .metadataOnly)
        #expect(exportNote.filenameTemplate == .projectIdentifier)
        #expect(exportNote.generatedContentPolicy == .include)
        #expect(exportNote.source == "deterministicFallback")
        #expect(!exportNote.usedAppleIntelligence)
        #expect(exportNote.fallbackReason.contains("deterministically"))
        #expect(exportNote.payloadKinds == bundle.files.prefix(while: { $0.kind != "export-note" }).map(\.kind))
        #expect(exportNote.payloadKinds.last == "fusion-preview")
        #expect(exportNote.recommendedNextActions.first?.contains("Resolve blockers before export") == true)
        #expect(exportNote.recommendedNextActions.last == "Review archive-integrity-manifest before handoff.")
        #expect(exportNote.dataBoundary.contains("no raw photo bytes"))
        #expect(exportNote.dataBoundary.contains("physical-device proof"))
        #expect(exportNote.accessibilityValue.contains("Project Export Note"))
        #expect(exportNote.accessibilityValue.contains("Deterministic fallback"))
        #expect(exportNote.matches(
            project: exportedProject,
            payloadKinds: bundle.files.prefix(while: { $0.kind != "export-note" }).map(\.kind),
            finalOutputActionPlanSummary: finalOutputReadinessAudit.actionPlanSummary
        ))
        let finalOutputPreviewImage = try #require(
            BracketProjectFinalOutputPreviewImageDocument.renderedImage(fusionPreview: fusionPreview)
        )
        let finalOutputPreviewImageData = try #require(Data(base64Encoded: finalOutputPreviewImageFile.contents))
        let finalOutputPreviewImageSource = try #require(
            CGImageSourceCreateWithData(finalOutputPreviewImageData as CFData, nil)
        )
        let finalOutputPreviewImageProperties = try #require(
            CGImageSourceCopyPropertiesAtIndex(finalOutputPreviewImageSource, 0, nil) as? [CFString: Any]
        )
        #expect(finalOutputPreviewImageFile.mimeType == "image/png")
        #expect(finalOutputPreviewImageFile.filename.hasSuffix("-final-output-preview.png.base64"))
        #expect(Array(finalOutputPreviewImageData.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        #expect(finalOutputPreviewImage.width == 96)
        #expect(finalOutputPreviewImage.height == 32)
        #expect(finalOutputPreviewImage.byteCount == 96 * 32 * 4)
        #expect(finalOutputPreviewImageProperties[kCGImagePropertyPixelWidth] as? Int == finalOutputPreviewImage.width)
        #expect(finalOutputPreviewImageProperties[kCGImagePropertyPixelHeight] as? Int == finalOutputPreviewImage.height)
        #expect(finalOutputPreviewImageFile.contents == BracketProjectFinalOutputPreviewImageDocument.base64PNG(
            fusionPreview: fusionPreview
        ))
        #expect(BracketProjectFinalOutputPreviewImageDocument.boundary.contains("not final HDR output"))
        let finalOutputDraftJPEGData = try #require(Data(base64Encoded: finalOutputDraftJPEGFile.contents))
        let finalOutputDraftJPEGSource = try #require(
            CGImageSourceCreateWithData(finalOutputDraftJPEGData as CFData, nil)
        )
        let finalOutputDraftJPEGProperties = try #require(
            CGImageSourceCopyPropertiesAtIndex(finalOutputDraftJPEGSource, 0, nil) as? [CFString: Any]
        )
        #expect(finalOutputDraftJPEGFile.mimeType == "image/jpeg")
        #expect(finalOutputDraftJPEGFile.filename.hasSuffix("-final-output-draft-review.jpg.base64"))
        #expect(Array(finalOutputDraftJPEGData.prefix(3)) == [255, 216, 255])
        #expect(finalOutputDraftJPEGProperties[kCGImagePropertyPixelWidth] as? Int == finalOutputPreviewImage.width)
        #expect(finalOutputDraftJPEGProperties[kCGImagePropertyPixelHeight] as? Int == finalOutputPreviewImage.height)
        #expect(finalOutputDraftJPEGFile.contents == BracketProjectFinalOutputDraftJPEGDocument.base64JPEG(
            fusionPreview: fusionPreview
        ))
        #expect(BracketProjectFinalOutputDraftJPEGDocument.boundary.contains("not final HDR output"))
        #expect(privacyFile.contents.contains("Photos asset identifiers: redacted"))
        #expect(privacyFile.contents.contains("Contact sheet: metadata placeholders only"))
        #expect(privacyFile.contents.contains("Rendered contact sheet: HTML document"))
        #expect(privacyFile.contents.contains("Contact sheet preview: deterministic fixture pixels only"))
        #expect(privacyFile.contents.contains("Contact sheet image: base64 PNG rendered from deterministic fixture pixels only"))
        #expect(privacyFile.contents.contains("Contact sheet PDF: base64 PDF rendered from deterministic fixture pixels only"))
        #expect(privacyFile.contents.contains("Capture quality report: manifest facts only"))
        #expect(privacyFile.contents.contains("Asset resource report: manifest/project asset facts only"))
        #expect(privacyFile.contents.contains("Merge readiness report: manifest/project heuristic only"))
        #expect(privacyFile.contents.contains("Image bundle manifest: metadata-only selected image/RAW bundle plan"))
        #expect(privacyFile.contents.contains("Image bundle draft package: base64 JSON"))
        #expect(privacyFile.contents.contains("Final output manifest: planned render formats"))
        #expect(privacyFile.contents.contains("Final output readiness audit: metadata-only readiness"))
        #expect(privacyFile.contents.contains("Final output preview image: base64 PNG"))
        #expect(privacyFile.contents.contains("Final output draft JPEG: base64 JPEG"))
        #expect(privacyFile.contents.contains("Exposure comparison: manifest EV facts only"))
        #expect(privacyFile.contents.contains("Side-by-side pixel comparison: deterministic synthetic pixel strips only"))
        #expect(privacyFile.contents.contains("Fusion preview: deterministic synthetic pixel preview only"))
        #expect(privacyFile.contents.contains("Export note: deterministic source-disclosed metadata note only"))
        #expect(privacyFile.contents.contains("Raw photo bytes: not included"))
        #expect(diagnosticsFile.contents.contains("Bracket complete"))
        #expect(bundle.archiveText.contains("Bracketer Project Export Bundle"))
        #expect(bundle.archiveFilename == "\(bundle.projectID)-bracketer-project-bundle.txt")
        #expect(bundle.archiveText.contains("Filename: \(bundle.archiveFilename)"))
        #expect(bundle.archiveText.contains("----- BEGIN \(projectFile.filename) -----"))
        #expect(bundle.archiveText.contains("Kind: contact-sheet"))
        #expect(bundle.archiveText.contains("Kind: contact-sheet-html"))
        #expect(bundle.archiveText.contains("Kind: contact-sheet-preview"))
        #expect(bundle.archiveText.contains("Kind: contact-sheet-image"))
        #expect(bundle.archiveText.contains("Kind: contact-sheet-pdf"))
        #expect(bundle.archiveText.contains("Kind: capture-quality-report"))
        #expect(bundle.archiveText.contains("Kind: asset-resource-report"))
        #expect(bundle.archiveText.contains("Kind: merge-readiness-report"))
        #expect(bundle.archiveText.contains("Kind: image-bundle-manifest"))
        #expect(bundle.archiveText.contains("Kind: image-bundle-draft-package"))
        #expect(bundle.archiveText.contains("Kind: final-output-manifest"))
        #expect(bundle.archiveText.contains("Kind: final-output-readiness-audit"))
        #expect(bundle.archiveText.contains("Kind: final-output-preview-image"))
        #expect(bundle.archiveText.contains("Kind: final-output-draft-review-jpeg"))
        #expect(bundle.archiveText.contains("Kind: exposure-comparison"))
        #expect(bundle.archiveText.contains("Kind: side-by-side-pixel-comparison"))
        #expect(bundle.archiveText.contains("Kind: fusion-preview"))
        #expect(bundle.archiveText.contains("Kind: export-note"))
        #expect(bundle.archiveText.contains("Photos asset identifiers: redacted"))
        #expect(!bundle.archiveText.contains("asset-under"))
        #expect(!bundle.archiveText.contains("private-photos-group"))
    }

    @Test func bracketProjectExportPresetsAndFilenameTemplatesProduceDeterministicNames() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let datedBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            filenameTemplate: .datedSummary,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let auditBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            filenameTemplate: .privacyAudit,
            createdAt: Date(timeIntervalSince1970: 24)
        )

        #expect(datedBundle.filenameTemplate == .datedSummary)
        #expect(datedBundle.archiveFilename == "bracketer-19700101-0000-5shot-photos-metadata-only.txt")
        #expect(datedBundle.files.map(\.filename).contains("bracketer-19700101-0000-5shot-photos-metadata-only-project.json"))
        #expect(datedBundle.accessibilityValue.contains("Dated summary"))
        #expect(datedBundle.archiveText.contains("Filename: bracketer-19700101-0000-5shot-photos-metadata-only.txt"))
        #expect(datedBundle.archiveText.contains("Naming: Dated summary"))
        #expect(!datedBundle.archiveText.contains("asset-under"))
        #expect(!datedBundle.archiveText.contains("private-photos-group"))
        #expect(auditBundle.archiveFilename == "bracketer-privacy-19700101-metadata-only-schema1.txt")
        #expect(auditBundle.accessibilityValue.contains("Privacy audit"))
        #expect(BracketProjectExportPreset.clientHandoff.privacyLevel == .metadataOnly)
        #expect(BracketProjectExportPreset.clientHandoff.filenameTemplate == .datedSummary)
        #expect(BracketProjectExportPreset.recoveryArchive.privacyLevel == .recoveryIdentifiers)
        #expect(BracketProjectExportPreset.recoveryArchive.filenameTemplate == .projectIdentifier)
        #expect(BracketProjectExportPreset.privacyAudit.accessibilityValue.contains("Privacy audit"))
    }

    @Test func bracketProjectExportBundleOmitsGeneratedContentWhenRequested() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Generated content omit test."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let includeBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let omitBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            generatedContentPolicy: .omit,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let includeSidecarFile = try #require(includeBundle.file(kind: "sidecar"))
        let omitSidecarFile = try #require(omitBundle.file(kind: "sidecar"))
        let omitProjectFile = try #require(omitBundle.file(kind: "project"))
        let omitPrivacyFile = try #require(omitBundle.file(kind: "privacy-report"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let includeSidecar = try decoder.decode(
            BracketManifestSidecar.self,
            from: Data(includeSidecarFile.contents.utf8)
        )
        let omitSidecar = try decoder.decode(
            BracketManifestSidecar.self,
            from: Data(omitSidecarFile.contents.utf8)
        )
        let omitProject = try decoder.decode(
            BracketProject.self,
            from: Data(omitProjectFile.contents.utf8)
        )

        #expect(includeBundle.generatedContentPolicy == .include)
        #expect(includeSidecar.generatedNote != nil)
        #expect(includeSidecar.provenance.noteSource != nil)
        #expect(includeBundle.archiveText.contains("Generated text: included"))

        #expect(omitBundle.generatedContentPolicy == .omit)
        #expect(omitSidecar.generatedNote == nil)
        #expect(omitSidecar.provenance.noteSource == nil)
        #expect(omitSidecar.acceptedTags == ["Portfolio Candidate"])
        #expect(omitProject.acceptedTags == ["Portfolio Candidate"])
        #expect(omitProject.privacy.containsGeneratedText == false)
        #expect(!omitSidecarFile.contents.contains("\"generatedNote\""))
        #expect(!omitSidecarFile.contents.contains("\"noteSource\" : \"deterministicFallback\""))
        #expect(!omitProjectFile.contents.contains("\"generatedNote\""))
        #expect(omitPrivacyFile.contents.contains("Generated content export: Omit generated"))
        #expect(omitPrivacyFile.contents.contains("User-curated accepted tags are preserved"))
        #expect(omitPrivacyFile.contents.contains("Generated text: not included"))
        #expect(omitBundle.archiveText.contains("Generated Content: Omit generated"))
        #expect(omitBundle.accessibilityValue.contains("Omit generated"))
        #expect(omitBundle.summary.contains("Omit generated"))
    }

    @Test func bracketProjectExportPresetsExposeGeneratedContentPolicy() {
        #expect(BracketProjectExportPreset.clientHandoff.generatedContentPolicy == .omit)
        #expect(BracketProjectExportPreset.privacyAudit.generatedContentPolicy == .omit)
        #expect(BracketProjectExportPreset.reviewArchive.generatedContentPolicy == .include)
        #expect(BracketProjectExportPreset.recoveryArchive.generatedContentPolicy == .include)
        #expect(BracketProjectExportPreset.clientHandoff.accessibilityValue.contains("Omit generated"))
        #expect(BracketProjectExportGeneratedContentPolicy.omit.policyDescription.contains("User-curated"))
    }

    @Test func bracketProjectExportLatestIntentDefaultsToOmittingGeneratedContent() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Intent generated content default test."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let intent = ExportLatestBracketProjectBundleIntent()
        #expect(intent.generatedContent == .omit)

        let export = try LatestBracketProjectExportFileProvider(store: store).exportFile(
            createdAt: Date(timeIntervalSince1970: 20)
        )
        #expect(export.archiveText.contains("Generated Content: Omit generated"))
        #expect(export.archiveText.contains("Generated text: not included"))
        #expect(!export.archiveText.contains("\"generatedNote\""))
    }

    @Test func bracketProjectExportBundleCanIncludeRecoveryIdentifiersWhenRequested() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let bundle = try #require(try store.exportBundle(id: project.id, privacyLevel: .recoveryIdentifiers))
        let projectFile = try #require(bundle.file(kind: "project"))
        let manifestFile = try #require(bundle.file(kind: "manifest"))
        let assetResourceReportFile = try #require(bundle.file(kind: "asset-resource-report"))
        let imageBundleManifestFile = try #require(bundle.file(kind: BracketProjectImageBundleManifest.kind))
        let privacyFile = try #require(bundle.file(kind: "privacy-report"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let assetResourceReport = try decoder.decode(
            BracketProjectAssetResourceReport.self,
            from: Data(assetResourceReportFile.contents.utf8)
        )
        let imageBundleManifest = try decoder.decode(
            BracketProjectImageBundleManifest.self,
            from: Data(imageBundleManifestFile.contents.utf8)
        )

        #expect(bundle.privacyLevel == .recoveryIdentifiers)
        #expect(bundle.projectID == project.id)
        #expect(projectFile.contents.contains("asset-under"))
        #expect(manifestFile.contents.contains("asset-under"))
        #expect(assetResourceReport.recoveryIdentifierCount == 5)
        #expect(assetResourceReport.identifierPolicy.contains("present"))
        #expect(assetResourceReport.items.allSatisfy { $0.hasRecoveryIdentifier })
        #expect(imageBundleManifest.privacyLevel == .recoveryIdentifiers)
        #expect(imageBundleManifest.recoveryIdentifierCount == 5)
        #expect(imageBundleManifest.items.allSatisfy { $0.assetIdentifierIncluded })
        #expect(imageBundleManifest.completeRawProcessedPairCount == 5)
        #expect(privacyFile.contents.contains("Photos asset identifiers: included for recovery"))
        #expect(!projectFile.contents.contains("Raw photo bytes stored"))
    }

    @Test func bracketProjectResourceInspectionReportRoundTripsInspectedMetadata() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let baseProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let inspection = BracketProjectResourceInspection.make(
            project: baseProject,
            source: .syntheticFixture,
            inspectedAt: Date(timeIntervalSince1970: 18),
            shotResources: [
                BracketProjectResourceInspection.ShotResources(
                    index: 0,
                    assetIdentifier: "asset-under",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "photo",
                            originalFilename: "IMG_0001.HEIC",
                            uniformTypeIdentifier: "public.heic"
                        ),
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0001.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        ),
                    ]
                ),
                BracketProjectResourceInspection.ShotResources(
                    index: 1,
                    assetIdentifier: "asset-under-mid",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "photo",
                            originalFilename: "IMG_0002.HEIC",
                            uniformTypeIdentifier: "public.heic"
                        ),
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0002.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        ),
                    ]
                ),
                BracketProjectResourceInspection.ShotResources(
                    index: 2,
                    assetIdentifier: "asset-center",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "photo",
                            originalFilename: "IMG_0003.HEIC",
                            uniformTypeIdentifier: "public.heic"
                        ),
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0003.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        ),
                    ]
                ),
                BracketProjectResourceInspection.ShotResources(
                    index: 3,
                    assetIdentifier: "asset-over-mid",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "photo",
                            originalFilename: "IMG_0004.HEIC",
                            uniformTypeIdentifier: "public.heic"
                        ),
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0004.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        ),
                    ]
                ),
                BracketProjectResourceInspection.ShotResources(
                    index: 4,
                    assetIdentifier: "asset-over",
                    resources: [
                        BracketProjectResourceInspection.Resource(
                            resourceType: "alternatePhoto",
                            originalFilename: "IMG_0005.DNG",
                            uniformTypeIdentifier: "com.adobe.raw-image"
                        ),
                    ]
                ),
            ]
        )
        let project = baseProject.withResourceInspection(
            inspection,
            updatedAt: Date(timeIntervalSince1970: 19)
        )
        let metadataBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let recoveryBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .recoveryIdentifiers,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let resourceInspectionFile = try #require(
            metadataBundle.file(kind: BracketProjectResourceInspectionReport.kind)
        )
        let recoveryInspectionFile = try #require(
            recoveryBundle.file(kind: BracketProjectResourceInspectionReport.kind)
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(
            BracketProjectResourceInspectionReport.self,
            from: Data(resourceInspectionFile.contents.utf8)
        )
        let resourceInspectionIndex = try #require(
            metadataBundle.files.map(\.kind).firstIndex(of: BracketProjectResourceInspectionReport.kind)
        )
        let assetResourceIndex = try #require(
            metadataBundle.files.map(\.kind).firstIndex(of: BracketProjectAssetResourceReport.kind)
        )

        #expect(resourceInspectionIndex == assetResourceIndex + 1)
        #expect(resourceInspectionFile.filename.hasSuffix("-resource-inspection-report.json"))
        #expect(report.projectID == metadataBundle.projectID)
        #expect(report.source == "Synthetic resource fixture")
        #expect(report.shotCount == 5)
        #expect(report.inspectedShotCount == 5)
        #expect(report.rawResourceCount == 5)
        #expect(report.processedResourceCount == 4)
        #expect(report.completePairCount == 4)
        #expect(report.mismatchCount == 1)
        #expect(report.items.last?.resourceState == "inspection-mismatch")
        #expect(report.items.last?.mismatchLabels == ["Expected Processed resource missing"])
        #expect(report.items.last?.recommendation.contains("Resource metadata disagrees") == true)
        #expect(report.boundary.contains("Synthetic resource metadata fixture"))
        #expect(report.accessibilityValue.contains("Resource Inspection"))
        #expect(!resourceInspectionFile.contents.contains("asset-under"))
        #expect(recoveryInspectionFile.contents.contains("asset-under"))
        #expect(metadataBundle.archiveText.contains("Kind: resource-inspection-report"))
        #expect(metadataBundle.archiveText.contains("Resource inspection report: optional Photos resource metadata summary only"))

        let imported = try store.importArchiveText(metadataBundle.archiveText)

        #expect(imported.resourceInspectionReport?.projectID == imported.project.id)
        #expect(imported.resourceInspectionReport?.mismatchCount == 1)
        #expect(imported.project.resourceInspection?.items.last?.resourceState == "inspection-mismatch")
        #expect(!imported.project.privacy.storesAssetIdentifiers)
        #expect(try store.search("inspection mismatch").map(\.id) == [imported.project.id])

        var didRejectResourceInspectionReportMismatch = false
        let mismatchedInspectionArchive = metadataBundle.archiveText
            .replacingOccurrences(
                of: "\"mismatchCount\" : 1",
                with: "\"mismatchCount\" : 0"
            )
        do {
            _ = try BracketProjectImportBundle.parse(archiveText: mismatchedInspectionArchive)
        } catch let error as BracketProjectImportError {
            didRejectResourceInspectionReportMismatch = error == .resourceInspectionReportMismatch
        }
        #expect(didRejectResourceInspectionReportMismatch)
    }

    @Test func bracketProjectThumbnailInspectionReportRoundTripsDeliveryMetadata() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let baseProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let inspection = BracketProjectThumbnailInspection.make(
            project: baseProject,
            source: .syntheticFixture,
            inspectedAt: Date(timeIntervalSince1970: 18),
            shotThumbnails: [
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 0,
                    assetIdentifier: "asset-under",
                    targetPixelWidth: 512,
                    targetPixelHeight: 512,
                    deliveredPixelWidth: 1024,
                    deliveredPixelHeight: 768,
                    deliveryMode: "highQualityFormat",
                    contentMode: "aspectFit"
                ),
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 1,
                    assetIdentifier: "asset-under-mid",
                    targetPixelWidth: 512,
                    targetPixelHeight: 512,
                    deliveredPixelWidth: 640,
                    deliveredPixelHeight: 480,
                    deliveryMode: "opportunistic",
                    contentMode: "aspectFill",
                    isDegraded: true,
                    isCloudBacked: true
                ),
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 2,
                    assetIdentifier: "asset-center",
                    targetPixelWidth: 512,
                    targetPixelHeight: 512,
                    deliveredPixelWidth: nil,
                    deliveredPixelHeight: nil,
                    deliveryMode: "highQualityFormat",
                    contentMode: "aspectFit",
                    errorDescription: "Photos thumbnail unavailable"
                ),
                BracketProjectThumbnailInspection.ShotThumbnail(
                    index: 4,
                    assetIdentifier: "asset-over",
                    targetPixelWidth: 512,
                    targetPixelHeight: 512,
                    deliveredPixelWidth: nil,
                    deliveredPixelHeight: nil,
                    deliveryMode: "fastFormat",
                    contentMode: "aspectFit",
                    wasCancelled: true
                ),
            ]
        )
        let project = baseProject.withThumbnailInspection(
            inspection,
            updatedAt: Date(timeIntervalSince1970: 19)
        )
        let metadataBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let recoveryBundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .recoveryIdentifiers,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let thumbnailInspectionFile = try #require(
            metadataBundle.file(kind: BracketProjectThumbnailInspectionReport.kind)
        )
        let recoveryInspectionFile = try #require(
            recoveryBundle.file(kind: BracketProjectThumbnailInspectionReport.kind)
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(
            BracketProjectThumbnailInspectionReport.self,
            from: Data(thumbnailInspectionFile.contents.utf8)
        )
        let thumbnailInspectionIndex = try #require(
            metadataBundle.files.map(\.kind).firstIndex(of: BracketProjectThumbnailInspectionReport.kind)
        )
        let assetResourceIndex = try #require(
            metadataBundle.files.map(\.kind).firstIndex(of: BracketProjectAssetResourceReport.kind)
        )
        let mergeReadinessIndex = try #require(
            metadataBundle.files.map(\.kind).firstIndex(of: BracketProjectMergeReadinessReport.kind)
        )

        #expect(thumbnailInspectionIndex == assetResourceIndex + 1)
        #expect(mergeReadinessIndex == thumbnailInspectionIndex + 1)
        #expect(thumbnailInspectionFile.filename.hasSuffix("-thumbnail-inspection-report.json"))
        #expect(report.projectID == metadataBundle.projectID)
        #expect(report.source == "Synthetic thumbnail fixture")
        #expect(report.shotCount == 5)
        #expect(report.requestedShotCount == 4)
        #expect(report.deliveredShotCount == 2)
        #expect(report.degradedShotCount == 1)
        #expect(report.cloudBackedShotCount == 1)
        #expect(report.errorShotCount == 2)
        #expect(report.items[1].resultState == "degraded-thumbnail-delivered")
        #expect(report.items[2].resultState == "thumbnail-error")
        #expect(report.items[3].resultState == "not-requested")
        #expect(report.items[4].resultState == "request-cancelled")
        #expect(report.boundary.contains("Synthetic thumbnail delivery fixture"))
        #expect(report.accessibilityValue.contains("Thumbnail Inspection"))
        #expect(!thumbnailInspectionFile.contents.contains("asset-under"))
        #expect(recoveryInspectionFile.contents.contains("asset-under"))
        #expect(metadataBundle.archiveText.contains("Kind: thumbnail-inspection-report"))
        #expect(metadataBundle.archiveText.contains("Thumbnail inspection report: optional Photos thumbnail delivery metadata only"))

        let imported = try store.importArchiveText(metadataBundle.archiveText)

        #expect(imported.thumbnailInspectionReport?.projectID == imported.project.id)
        #expect(imported.thumbnailInspectionReport?.deliveredShotCount == 2)
        #expect(imported.thumbnailInspectionReport?.errorShotCount == 2)
        #expect(imported.project.thumbnailInspection?.items[1].isDegraded == true)
        #expect(imported.project.thumbnailInspection?.items[3].resultState == "not-requested")
        #expect(!imported.project.privacy.storesAssetIdentifiers)
        #expect(try store.search("degraded thumbnail").map(\.id) == [imported.project.id])

        var didRejectThumbnailInspectionReportMismatch = false
        let mismatchedInspectionArchive = metadataBundle.archiveText
            .replacingOccurrences(
                of: "\"deliveredShotCount\" : 2",
                with: "\"deliveredShotCount\" : 1"
            )
        do {
            _ = try BracketProjectImportBundle.parse(archiveText: mismatchedInspectionArchive)
        } catch let error as BracketProjectImportError {
            didRejectThumbnailInspectionReportMismatch = error == .thumbnailInspectionReportMismatch
        }
        #expect(didRejectThumbnailInspectionReportMismatch)
    }

    @Test func bracketProjectFinalOutputReadinessAuditSummarizesMetadataOnlyOutputState() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let defaultManifest = BracketProjectFinalOutputManifest.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: project.updatedAt
        )
        let audit = BracketProjectFinalOutputReadinessAudit.make(manifest: defaultManifest)

        #expect(BracketProjectFinalOutputReadinessAudit.kind == "final-output-readiness-audit")
        #expect(audit.schemaVersion == 1)
        #expect(audit.projectID == project.id)
        #expect(audit.outputCount == 3)
        #expect(audit.readyOutputCount == 0)
        #expect(audit.blockedOutputCount == 3)
        #expect(audit.sourceExposureCount == 5)
        #expect(audit.completeResourcePairCount == 5)
        #expect(audit.previewArtifactAvailable)
        #expect(!audit.finalRenderedBytesIncluded)
        #expect(audit.blockerReasonCount == 2)
        #expect(audit.recommendationCount == 3)
        #expect(audit.readyOutputNames.isEmpty)
        #expect(audit.blockedOutputNames == [
            "Tone-mapped review JPEG",
            "HDR HEIF master",
            "Lightroom reference TIFF",
        ])
        #expect(audit.blockerReasons.contains("Final HDR/tone-map renderer is not implemented in this build."))
        #expect(audit.blockerReasons.contains("Physical Photos resource bytes and Files export artifact have not been inspected."))
        #expect(audit.recommendationLines.first?.hasPrefix("Tone-mapped review JPEG: Use the fusion preview as review context only") == true)
        #expect(audit.statusLabel == "Follow-up before final export")
        #expect(audit.summaryLine == "0/3 outputs ready; 3 blocked; 2 blocker reason(s); 3 recommendation(s).")
        #expect(audit.accessibilityValue.contains("Final Output Readiness Audit"))
        #expect(audit.accessibilityValue.contains("Follow-up before final export"))
        #expect(audit.accessibilityValue.contains("0/3 outputs ready"))
        #expect(audit.accessibilityValue.contains("Preview artifact available"))
        #expect(audit.accessibilityValue.contains("No final rendered bytes"))
        #expect(audit.accessibilityValue.contains("Ready outputs: none"))
        #expect(audit.accessibilityValue.contains("Blocked outputs: Tone-mapped review JPEG, HDR HEIF master, Lightroom reference TIFF"))
        #expect(audit.accessibilityValue.contains("Recommendations: Tone-mapped review JPEG: Use the fusion preview as review context only"))
        #expect(audit.accessibilityValue.contains("metadata-only review/export guidance"))
        #expect(!audit.accessibilityValue.contains("asset-under"))

        #expect(audit.actionPlanStepCount == 2)
        #expect(audit.actionPlan.contains("Resolve blockers before export for 3 blocked output(s): Tone-mapped review JPEG, HDR HEIF master, Lightroom reference TIFF."))
        #expect(audit.actionPlan.contains("Clear 2 blocker reason(s): Final HDR/tone-map renderer is not implemented in this build.; Physical Photos resource bytes and Files export artifact have not been inspected."))
        #expect(!audit.actionPlan.contains { $0.hasSuffix("..") })
        #expect(audit.actionPlan.last == BracketProjectFinalOutputReadinessAudit.actionPlanBoundary)
        #expect(!audit.actionPlan.contains("Create a final-output plan before export."))
        #expect(audit.accessibilityValue.contains("Action plan: 2 action item(s)"))
        #expect(audit.accessibilityValue.contains("Resolve blockers before export for 3 blocked output(s)"))
        #expect(audit.accessibilityValue.contains("not final rendered image proof"))

        let readyManifest = BracketProjectFinalOutputManifest(
            schemaVersion: defaultManifest.schemaVersion,
            projectID: defaultManifest.projectID,
            title: defaultManifest.title,
            privacyLevel: defaultManifest.privacyLevel,
            createdAt: defaultManifest.createdAt,
            boundary: defaultManifest.boundary,
            sourceExposureCount: defaultManifest.sourceExposureCount,
            completeResourcePairCount: defaultManifest.completeResourcePairCount,
            previewArtifactAvailable: true,
            finalRenderedBytesIncluded: false,
            outputCount: 1,
            readyOutputCount: 1,
            blockedOutputCount: 0,
            readinessSummary: "1 injected output is metadata-ready.",
            outputs: [
                BracketProjectFinalOutputManifest.Output(
                    id: "unit-test-ready-output",
                    displayName: "Unit test ready output",
                    filename: "unit-test-ready-output.jpg",
                    mimeType: "image/jpeg",
                    codec: "JPEG",
                    colorPipeline: "Unit-test preview pipeline",
                    sourcePolicy: "Unit-test metadata only.",
                    readiness: "ready-unit-test-proof",
                    blockers: [],
                    provenanceInputs: ["unit-test"],
                    recommendation: "Keep this metadata-ready output separate from final rendered bytes."
                ),
            ]
        )
        let readyAudit = BracketProjectFinalOutputReadinessAudit.make(manifest: readyManifest)
        #expect(readyAudit.statusLabel == "Metadata ready, final render unverified")
        #expect(readyAudit.summaryLine == "1/1 outputs ready; 0 blocked; 0 blocker reason(s); 1 recommendation(s).")
        #expect(readyAudit.readyOutputNames == ["Unit test ready output"])
        #expect(readyAudit.blockedOutputNames.isEmpty)
        #expect(readyAudit.accessibilityValue.contains("Ready outputs: Unit test ready output"))
        #expect(readyAudit.accessibilityValue.contains("Blocker reasons: none"))
        #expect(readyAudit.actionPlanStepCount == 1)
        #expect(readyAudit.actionPlan.first == "Metadata looks ready; verify final rendered image bytes separately before export.")
        #expect(readyAudit.actionPlan.last == BracketProjectFinalOutputReadinessAudit.actionPlanBoundary)

        let renderedBytesAudit = BracketProjectFinalOutputReadinessAudit.make(
            manifest: BracketProjectFinalOutputManifest(
                schemaVersion: defaultManifest.schemaVersion,
                projectID: defaultManifest.projectID,
                title: defaultManifest.title,
                privacyLevel: defaultManifest.privacyLevel,
                createdAt: defaultManifest.createdAt,
                boundary: defaultManifest.boundary,
                sourceExposureCount: 5,
                completeResourcePairCount: 5,
                previewArtifactAvailable: true,
                finalRenderedBytesIncluded: true,
                outputCount: 1,
                readyOutputCount: 1,
                blockedOutputCount: 0,
                readinessSummary: "Injected rendered-bytes case.",
                outputs: readyManifest.outputs
            )
        )
        #expect(renderedBytesAudit.actionPlan.contains("Verify rendered bytes against the 5 source exposure(s) before export."))
        #expect(renderedBytesAudit.actionPlan.last == BracketProjectFinalOutputReadinessAudit.actionPlanBoundary)

        let missingAudit = BracketProjectFinalOutputReadinessAudit.make(
            manifest: BracketProjectFinalOutputManifest(
                schemaVersion: defaultManifest.schemaVersion,
                projectID: defaultManifest.projectID,
                title: defaultManifest.title,
                privacyLevel: defaultManifest.privacyLevel,
                createdAt: defaultManifest.createdAt,
                boundary: defaultManifest.boundary,
                sourceExposureCount: defaultManifest.sourceExposureCount,
                completeResourcePairCount: defaultManifest.completeResourcePairCount,
                previewArtifactAvailable: false,
                finalRenderedBytesIncluded: false,
                outputCount: 0,
                readyOutputCount: 0,
                blockedOutputCount: 0,
                readinessSummary: "Missing unit-test outputs.",
                outputs: []
            )
        )
        #expect(missingAudit.statusLabel == "Final-output plan missing")
        #expect(missingAudit.summaryLine == "0/0 outputs ready; 0 blocked; 0 blocker reason(s); 0 recommendation(s).")
        #expect(missingAudit.accessibilityValue.contains("Recommendations: none"))
        #expect(missingAudit.actionPlan.contains("Create a final-output plan before export."))
        #expect(missingAudit.actionPlan.contains("Generate or attach a preview artifact before handoff."))
        #expect(missingAudit.actionPlanStepCount == 2)
        #expect(missingAudit.actionPlan.last == BracketProjectFinalOutputReadinessAudit.actionPlanBoundary)

        let data = try JSONEncoder().encode(audit)
        let decoded = try JSONDecoder().decode(BracketProjectFinalOutputReadinessAudit.self, from: data)
        #expect(decoded == audit)
    }

    @Test func bracketProjectImportBundleRoundTripsMetadataOnlyArchiveThroughStore() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let indexer = RecordingBracketProjectSpotlightIndexer()
        let store = FileBracketProjectStore(rootURL: rootURL, spotlightIndexer: indexer)
        let fixture = makeBracketNarrativeManifestFixture()
        let narrativeRun = DeterministicBracketReviewNarrative.run(
            for: makeBracketNarrativeRequest(),
            fallbackReason: "Import test fallback."
        )
        let sidecar = BracketManifestSidecar.make(
            manifest: fixture.manifest,
            narrativeRun: narrativeRun,
            captureContext: makeCaptureCoachContext(),
            acceptedTags: ["Portfolio Candidate"],
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            sidecar: sidecar,
            acceptedTags: ["Portfolio Candidate"],
            userNote: "Window recovery candidate",
            diagnosticsSummary: "5 events | Latest: Info Capture | Bracket complete",
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let exportActionPlanSummary = try #require(bundle.finalOutputActionPlanSummary)
        #expect(exportActionPlanSummary.contains("Resolve blockers before export"))
        #expect(exportActionPlanSummary.contains("not final rendered image proof"))
        #expect(bundle.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(bundle.archiveText.contains("Final Output Action Plan: 2 action item(s)"))
        #expect(bundle.archiveText.contains("not final rendered image proof"))

        let imported = try store.importArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30)
        )
        let importedCorpus = imported.project.searchCorpus.joined(separator: " ")

        #expect(imported.project.id == "project-photos-metadata-5shots-schema1-12")
        #expect(imported.project.manifest == imported.manifest)
        #expect(imported.project.sidecar == imported.sidecar)
        #expect(imported.contactSheet?.projectID == imported.project.id)
        #expect(imported.contactSheet?.items.filter(\.isBestExposureCandidate).map(\.displayLabel) == ["0 EV"])
        #expect(imported.contactSheetHTML?.contains("Rendered Contact Sheet") == true)
        #expect(imported.contactSheetHTML?.contains("data-shot-index=\"2\"") == true)
        #expect(imported.contactSheetPreview?.projectID == imported.project.id)
        #expect(imported.contactSheetPreview?.source == "deterministicFixture")
        #expect(imported.contactSheetPreview?.tileCount == 5)
        #expect(imported.contactSheetPreview?.tiles.first?.rgbaBytes.count == 24)
        let importedContactSheetPreview = try #require(imported.contactSheetPreview)
        #expect(imported.contactSheetImageBase64 == BracketProjectContactSheetImageDocument.base64PNG(
            preview: importedContactSheetPreview
        ))
        #expect(Data(base64Encoded: try #require(imported.contactSheetImageBase64))?.starts(with: [
            137, 80, 78, 71, 13, 10, 26, 10
        ]) == true)
        #expect(imported.contactSheetPDFBase64 == BracketProjectContactSheetPDFDocument.base64PDF(
            preview: importedContactSheetPreview
        ))
        let importedContactSheetPDFBase64 = try #require(imported.contactSheetPDFBase64)
        let importedContactSheetPDFData = try #require(Data(base64Encoded: importedContactSheetPDFBase64))
        #expect(String(decoding: importedContactSheetPDFData.prefix(8), as: UTF8.self) == "%PDF-1.4")
        #expect(imported.captureQualityReport?.projectID == imported.project.id)
        #expect(imported.captureQualityReport?.availableShotCount == 5)
        #expect(imported.captureQualityReport?.readinessScore == 100)
        #expect(imported.captureQualityReport?.findings.map(\.id).contains("sequence-complete") == true)
        #expect(imported.assetResourceReport?.projectID == imported.project.id)
        #expect(imported.assetResourceReport?.completePairCount == 5)
        #expect(imported.assetResourceReport?.rawAvailableCount == 5)
        #expect(imported.assetResourceReport?.processedAvailableCount == 5)
        #expect(imported.assetResourceReport?.recoveryIdentifierCount == 0)
        #expect(imported.assetResourceReport?.identifierPolicy.contains("redacted") == true)
        #expect(imported.mergeReadinessReport?.projectID == imported.project.id)
        #expect(imported.mergeReadinessReport?.score == 95)
        #expect(imported.mergeReadinessReport?.label == "Ready for cautious merge preview")
        #expect(imported.mergeReadinessReport?.evidence.map(\.id).contains("resource-inspection-missing") == true)
        #expect(imported.imageBundleManifest?.projectID == imported.project.id)
        #expect(imported.imageBundleManifest?.privacyLevel == .metadataOnly)
        #expect(imported.imageBundleManifest?.completeRawProcessedPairCount == 5)
        #expect(imported.imageBundleManifest?.recoveryIdentifierCount == 0)
        #expect(imported.imageBundleManifest?.boundary.contains("does not export") == true)
        let importedImageBundleManifest = try #require(imported.imageBundleManifest)
        let importedImageBundleDraftPackageBase64 = try #require(imported.imageBundleDraftPackageBase64)
        let importedImageBundleDraftPackageData = try #require(
            Data(base64Encoded: importedImageBundleDraftPackageBase64)
        )
        let importedImageBundleDraftPackageDecoder = JSONDecoder()
        let importedImageBundleDraftPackage = try importedImageBundleDraftPackageDecoder.decode(
            BracketProjectImageBundleDraftPackageDocument.Package.self,
            from: importedImageBundleDraftPackageData
        )
        #expect(importedImageBundleDraftPackage.projectID == imported.project.id)
        #expect(importedImageBundleDraftPackage.entryCount == 10)
        #expect(importedImageBundleDraftPackage.entries.first?.representation == "Processed")
        #expect(importedImageBundleDraftPackage.boundary.contains("not private Photos bytes"))
        #expect(importedImageBundleDraftPackageBase64 == BracketProjectImageBundleDraftPackageDocument.base64Package(
            manifest: importedImageBundleManifest
        ))
        let importedFinalOutputManifest = try #require(imported.finalOutputManifest)
        let importedFinalOutputReadinessAudit = try #require(imported.finalOutputReadinessAudit)
        #expect(importedFinalOutputManifest.projectID == imported.project.id)
        #expect(importedFinalOutputManifest.outputCount == 3)
        #expect(importedFinalOutputManifest.readyOutputCount == 0)
        #expect(importedFinalOutputManifest.blockedOutputCount == 3)
        #expect(importedFinalOutputManifest.previewArtifactAvailable == true)
        #expect(importedFinalOutputManifest.finalRenderedBytesIncluded == false)
        #expect(importedFinalOutputManifest.outputs.map(\.id).contains("hdr-heif-master") == true)
        #expect(importedFinalOutputManifest.boundary.contains("Final-output export plan only") == true)
        #expect(importedFinalOutputReadinessAudit.projectID == imported.project.id)
        #expect(importedFinalOutputReadinessAudit.outputCount == 3)
        #expect(importedFinalOutputReadinessAudit.blockedOutputCount == 3)
        #expect(importedFinalOutputReadinessAudit.statusLabel == "Follow-up before final export")
        #expect(importedFinalOutputReadinessAudit.summaryLine == "0/3 outputs ready; 3 blocked; 2 blocker reason(s); 3 recommendation(s).")
        #expect(importedFinalOutputReadinessAudit.boundary.contains("metadata-only review/export guidance"))
        #expect(importedFinalOutputReadinessAudit.matches(manifest: importedFinalOutputManifest))
        let importedActionPlanSummary = try #require(imported.finalOutputActionPlanSummary)
        #expect(importedActionPlanSummary == importedFinalOutputReadinessAudit.actionPlanSummary)
        #expect(imported.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        let importedFinalOutputPreviewImageBase64 = try #require(imported.finalOutputPreviewImageBase64)
        let importedFinalOutputPreviewImageData = try #require(
            Data(base64Encoded: importedFinalOutputPreviewImageBase64)
        )
        #expect(Array(importedFinalOutputPreviewImageData.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        let importedFinalOutputDraftJPEGBase64 = try #require(imported.finalOutputDraftJPEGBase64)
        let importedFinalOutputDraftJPEGData = try #require(
            Data(base64Encoded: importedFinalOutputDraftJPEGBase64)
        )
        #expect(Array(importedFinalOutputDraftJPEGData.prefix(3)) == [255, 216, 255])
        #expect(imported.exposureComparison?.projectID == imported.project.id)
        #expect(imported.exposureComparison?.baselineDisplayLabel == "0 EV")
        #expect(imported.exposureComparison?.items.map(\.role).contains("Darker highlight guard") == true)
        #expect(imported.sideBySidePixelComparison?.projectID == imported.project.id)
        #expect(imported.sideBySidePixelComparison?.baselineLabel == "0 EV")
        #expect(imported.sideBySidePixelComparison?.comparisonCount == 4)
        #expect(imported.sideBySidePixelComparison?.pairs.last?.comparisonLabel == "+4.0 EV")
        #expect(imported.fusionPreview?.projectID == imported.project.id)
        #expect(imported.fusionPreview?.source == "deterministicFixture")
        #expect(imported.fusionPreview?.rgbaBytes.count == 12)
        let importedExportNote = try #require(imported.exportNote)
        #expect(importedExportNote.projectID == imported.project.id)
        #expect(importedExportNote.source == "deterministicFallback")
        #expect(!importedExportNote.usedAppleIntelligence)
        #expect(importedExportNote.payloadKinds.last == "fusion-preview")
        #expect(importedExportNote.recommendedNextActions.first == importedFinalOutputReadinessAudit.actionPlanSummary)
        #expect(importedExportNote.dataBoundary.contains("no raw photo bytes"))
        #expect(imported.accessibilityValue.contains("Export note: deterministicFallback"))
        #expect(imported.archiveIntegrityManifest?.projectID == imported.project.id)
        #expect(imported.archiveIntegrityManifest?.payloadCount == 23)
        #expect(imported.archiveIntegrityManifest?.items.last?.kind == "diagnostics-report")
        #expect(imported.payloadKinds == ["project", "manifest", "sidecar", "contact-sheet", "contact-sheet-html", "contact-sheet-preview", "contact-sheet-image", "contact-sheet-pdf", "capture-quality-report", "asset-resource-report", "merge-readiness-report", "image-bundle-manifest", "image-bundle-draft-package", "final-output-manifest", "final-output-readiness-audit", "final-output-preview-image", "final-output-draft-review-jpeg", "exposure-comparison", "side-by-side-pixel-comparison", "fusion-preview", "export-note", "privacy-report", "diagnostics-report", "archive-integrity-manifest"])
        #expect(imported.privacyReport.contains("Photos asset identifiers: redacted"))
        #expect(imported.privacyReport.contains("Contact sheet: metadata placeholders only"))
        #expect(imported.privacyReport.contains("Rendered contact sheet: HTML document"))
        #expect(imported.privacyReport.contains("Contact sheet preview: deterministic fixture pixels only"))
        #expect(imported.privacyReport.contains("Contact sheet image: base64 PNG rendered from deterministic fixture pixels only"))
        #expect(imported.privacyReport.contains("Contact sheet PDF: base64 PDF rendered from deterministic fixture pixels only"))
        #expect(imported.privacyReport.contains("Capture quality report: manifest facts only"))
        #expect(imported.privacyReport.contains("Asset resource report: manifest/project asset facts only"))
        #expect(imported.privacyReport.contains("Merge readiness report: manifest/project heuristic only"))
        #expect(imported.privacyReport.contains("Image bundle manifest: metadata-only selected image/RAW bundle plan"))
        #expect(imported.privacyReport.contains("Image bundle draft package: base64 JSON"))
        #expect(imported.privacyReport.contains("Final output manifest: planned render formats"))
        #expect(imported.privacyReport.contains("Final output readiness audit: metadata-only readiness"))
        #expect(imported.privacyReport.contains("computed action plan"))
        #expect(imported.privacyReport.contains("Final output preview image: base64 PNG"))
        #expect(imported.privacyReport.contains("Final output draft JPEG: base64 JPEG"))
        #expect(imported.privacyReport.contains("Exposure comparison: manifest EV facts only"))
        #expect(imported.privacyReport.contains("Side-by-side pixel comparison: deterministic synthetic pixel strips only"))
        #expect(imported.privacyReport.contains("Fusion preview: deterministic synthetic pixel preview only"))
        #expect(imported.privacyReport.contains("Export note: deterministic source-disclosed metadata note only"))
        #expect(imported.diagnosticsReport.contains("Bracket complete"))
        #expect(imported.accessibilityValue.contains("Project Import Bundle"))
        #expect(!imported.project.privacy.storesAssetIdentifiers)
        #expect(!imported.project.privacy.storesRawPhotoBytes)
        #expect(!importedCorpus.contains("asset-under"))
        #expect(!importedCorpus.contains("private-photos-group"))
        #expect(try store.current()?.id == imported.project.id)
        #expect(try store.latest()?.id == imported.project.id)
        #expect(try store.search("portfolio window").map(\.id) == [imported.project.id])
        #expect(indexer.indexedRecords.map(\.uniqueIdentifier) == [
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: imported.project.id)
        ])
    }

    @Test func bracketProjectImportBundleRoundTripsRecoveryIdentifierArchiveWhenExplicit() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .recoveryIdentifiers,
            createdAt: Date(timeIntervalSince1970: 24)
        )

        let imported = try store.importArchiveText(bundle.archiveText)

        #expect(imported.project.id == project.id)
        #expect(imported.project.manifest.groupIdentifier == "private-photos-group")
        #expect(imported.project.manifest.shots.first?.assetIdentifier == "asset-under")
        #expect(imported.project.assets.first?.assetIdentifier == "asset-under")
        #expect(imported.assetResourceReport?.recoveryIdentifierCount == 5)
        #expect(imported.assetResourceReport?.items.first?.hasRecoveryIdentifier == true)
        #expect(imported.imageBundleManifest?.privacyLevel == .recoveryIdentifiers)
        #expect(imported.imageBundleManifest?.recoveryIdentifierCount == 5)
        #expect(imported.imageBundleManifest?.items.first?.assetIdentifierIncluded == true)
        #expect(imported.project.privacy.storesAssetIdentifiers)
        #expect(!imported.project.privacy.storesRawPhotoBytes)
        #expect(imported.privacyReport.contains("Photos asset identifiers: included for recovery"))
        #expect(try store.load(id: project.id) == imported.project)
    }

    @Test func bracketProjectImportBundleKeepsDuplicateArchivesAsCopiesWhenRequested() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )

        let firstImport = try store.importArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30)
        )
        let duplicateImport = try store.importArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 40),
            conflictPolicy: .keepBoth
        )

        #expect(firstImport.conflictResolution == nil)
        #expect(firstImport.project.id == "project-photos-metadata-5shots-schema1-12")
        #expect(BracketProjectImportConflictPolicy.keepBoth.accessibilityValue == "Duplicate imports: Keep both")
        #expect(duplicateImport.project.id == "project-photos-metadata-5shots-schema1-12-import-40")
        #expect(duplicateImport.conflictResolution == "Conflict: kept both projects as project-photos-metadata-5shots-schema1-12-import-40")
        #expect(duplicateImport.accessibilityValue.contains("kept both"))
        #expect(duplicateImport.project.manifest == firstImport.project.manifest)
        #expect(try store.loadAll().map(\.id) == [
            duplicateImport.project.id,
            firstImport.project.id
        ])
        #expect(try store.current()?.id == duplicateImport.project.id)
        #expect(try store.search("import 40").map(\.id) == [duplicateImport.project.id])
    }

    @Test func bracketProjectImportPreviewDescribesDuplicateResolutionWithoutSaving() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let newPreview = try store.importPreview(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30),
            conflictPolicy: .keepBoth
        )

        #expect(!newPreview.isDuplicate)
        #expect(newPreview.projectID == "project-photos-metadata-5shots-schema1-12")
        #expect(newPreview.resolvedProjectID == newPreview.projectID)
        #expect(newPreview.actionSummary == "Import as new project project-photos-metadata-5shots-schema1-12.")
        #expect(newPreview.accessibilityValue.contains("Project Import Preview"))
        #expect(newPreview.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(newPreview.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(newPreview.accessibilityValue.contains("not final rendered image proof"))
        #expect(try store.loadAll().isEmpty)

        _ = try store.importArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30),
            conflictPolicy: .keepBoth
        )
        let keepBothPreview = try store.importPreview(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 40),
            conflictPolicy: .keepBoth
        )
        let rejectPreview = try store.importPreview(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 40),
            conflictPolicy: .rejectDuplicate
        )

        #expect(keepBothPreview.isDuplicate)
        #expect(keepBothPreview.duplicateProjectID == "project-photos-metadata-5shots-schema1-12")
        #expect(keepBothPreview.resolvedProjectID == "project-photos-metadata-5shots-schema1-12-import-40")
        #expect(keepBothPreview.actionSummary.contains("keep both projects"))
        #expect(keepBothPreview.accessibilityValue.contains("Will save as project-photos-metadata-5shots-schema1-12-import-40"))
        #expect(keepBothPreview.accessibilityValue.contains("Duplicate imports: Keep both"))
        #expect(rejectPreview.resolvedProjectID == rejectPreview.projectID)
        #expect(rejectPreview.actionSummary == "Duplicate found; import will be rejected.")
        #expect(try store.loadAll().map(\.id) == ["project-photos-metadata-5shots-schema1-12"])
    }

    @Test func bracketProjectImportBundleCanRejectDuplicateArchives() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let firstImport = try store.importArchiveText(bundle.archiveText)

        var rejectedDuplicateID: String?
        do {
            _ = try store.importArchiveText(
                bundle.archiveText,
                conflictPolicy: .rejectDuplicate
            )
        } catch BracketProjectImportError.duplicateProjectIdentifier(let id) {
            rejectedDuplicateID = id
        }

        #expect(rejectedDuplicateID == firstImport.project.id)
        #expect(try store.loadAll().map(\.id) == [firstImport.project.id])
    }

    @Test func bracketProjectImportBundleRejectsInvalidOrIncompleteArchivesWithoutSaving() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(project: project)
        let projectFile = try #require(bundle.file(kind: "project"))

        var didRejectHeader = false
        do {
            _ = try BracketProjectImportBundle.parse(archiveText: "not a Bracketer archive")
        } catch BracketProjectImportError.invalidArchiveHeader {
            didRejectHeader = true
        }
        #expect(didRejectHeader)
        let invalidHeaderPreviewFailure = try #require(
            store.importPreviewFailure(
                "not a Bracketer archive",
                conflictPolicy: .keepBoth
            )
        )
        #expect(invalidHeaderPreviewFailure.source == BracketProjectImportPreviewFailure.source)
        #expect(invalidHeaderPreviewFailure.failureKind == "invalid-archive-header")
        #expect(invalidHeaderPreviewFailure.recoverySuggestion == "Choose a Bracketer project export text file.")
        #expect(invalidHeaderPreviewFailure.mutationSummary == "No import was saved.")
        #expect(invalidHeaderPreviewFailure.accessibilityValue.contains("Project Import Preview Failure"))
        #expect(invalidHeaderPreviewFailure.accessibilityValue.contains("Duplicate imports: Keep both"))
        #expect(invalidHeaderPreviewFailure.accessibilityValue.contains("no-save parser diagnostics only"))
        #expect(try store.loadAll().isEmpty)

        var didRejectMissingManifest = false
        let missingManifestArchive = bundle.archiveText
            .replacingOccurrences(of: "Kind: manifest", with: "Kind: not-manifest")
        do {
            _ = try store.importArchiveText(missingManifestArchive)
        } catch let error as BracketProjectImportError {
            didRejectMissingManifest = error == .missingPayload(kind: "manifest")
        }
        #expect(didRejectMissingManifest)
        let missingManifestPreviewFailure = try #require(
            store.importPreviewFailure(missingManifestArchive)
        )
        #expect(missingManifestPreviewFailure.failureKind == "missing-payload")
        #expect(missingManifestPreviewFailure.errorDescription.contains("missing its manifest payload"))
        #expect(missingManifestPreviewFailure.recoverySuggestion == "Export the project again so the manifest payload is present.")
        #expect(missingManifestPreviewFailure.accessibilityValue.contains("No import was saved."))

        var didRejectByteMismatch = false
        let byteLineRange = try #require(bundle.archiveText.range(of: "Bytes: \(projectFile.byteCount)"))
        let byteMismatchArchive = bundle.archiveText.replacingCharacters(
            in: byteLineRange,
            with: "Bytes: \(projectFile.byteCount + 1)"
        )
        do {
            _ = try store.importArchiveText(byteMismatchArchive)
        } catch let error as BracketProjectImportError {
            didRejectByteMismatch = error == .byteCountMismatch(filename: projectFile.filename)
        }
        #expect(didRejectByteMismatch)
        let byteMismatchPreviewFailure = try #require(
            store.importPreviewFailure(byteMismatchArchive)
        )
        #expect(byteMismatchPreviewFailure.failureKind == "byte-count-mismatch")
        #expect(byteMismatchPreviewFailure.recoverySuggestion.contains(projectFile.filename))
        #expect(byteMismatchPreviewFailure.accessibilityValue.contains("does not import"))

        var didRejectContactSheetMismatch = false
        let mismatchedContactSheetArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"projectID\" : \"project-photos-metadata-5shots-schema1-12\"",
                with: "\"projectID\" : \"project-photos-metadata-5shots-schema1-99\""
            )
        do {
            _ = try store.importArchiveText(mismatchedContactSheetArchive)
        } catch let error as BracketProjectImportError {
            didRejectContactSheetMismatch = error == .contactSheetMismatch
        }
        #expect(didRejectContactSheetMismatch)

        var didRejectContactSheetHTMLMismatch = false
        let mismatchedContactSheetHTMLArchive = bundle.archiveText
            .replacingOccurrences(
                of: "Rendered Contact Sheet",
                with: "Tampered Contact Sheet"
            )
        do {
            _ = try store.importArchiveText(mismatchedContactSheetHTMLArchive)
        } catch let error as BracketProjectImportError {
            didRejectContactSheetHTMLMismatch = error == .contactSheetMismatch
        }
        #expect(didRejectContactSheetHTMLMismatch)

        var didRejectContactSheetPreviewMismatch = false
        let mismatchedContactSheetPreviewArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"tileCount\" : 5",
                with: "\"tileCount\" : 4"
            )
        do {
            _ = try store.importArchiveText(mismatchedContactSheetPreviewArchive)
        } catch let error as BracketProjectImportError {
            didRejectContactSheetPreviewMismatch = error == .contactSheetPreviewMismatch
        }
        #expect(didRejectContactSheetPreviewMismatch)

        var didRejectContactSheetImageMismatch = false
        let contactSheetImageFile = try #require(bundle.file(kind: "contact-sheet-image"))
        let mismatchedContactSheetImageArchive = bundle.archiveText
            .replacingOccurrences(
                of: contactSheetImageFile.contents,
                with: String(repeating: "A", count: contactSheetImageFile.contents.count)
            )
        do {
            _ = try store.importArchiveText(mismatchedContactSheetImageArchive)
        } catch let error as BracketProjectImportError {
            didRejectContactSheetImageMismatch = error == .contactSheetImageMismatch
        }
        #expect(didRejectContactSheetImageMismatch)

        var didRejectContactSheetPDFMismatch = false
        let contactSheetPDFFile = try #require(bundle.file(kind: "contact-sheet-pdf"))
        let mismatchedContactSheetPDFArchive = bundle.archiveText
            .replacingOccurrences(
                of: contactSheetPDFFile.contents,
                with: String(repeating: "A", count: contactSheetPDFFile.contents.count)
            )
        do {
            _ = try store.importArchiveText(mismatchedContactSheetPDFArchive)
        } catch let error as BracketProjectImportError {
            didRejectContactSheetPDFMismatch = error == .contactSheetPDFMismatch
        }
        #expect(didRejectContactSheetPDFMismatch)

        var didRejectCaptureQualityReportMismatch = false
        let mismatchedCaptureQualityReportArchive = bundle.archiveText
            .replacingOccurrences(
                of: "Ready for careful review",
                with: "Recovery recommended!!!!"
            )
        do {
            _ = try store.importArchiveText(mismatchedCaptureQualityReportArchive)
        } catch let error as BracketProjectImportError {
            didRejectCaptureQualityReportMismatch = error == .captureQualityReportMismatch
        }
        #expect(didRejectCaptureQualityReportMismatch)

        var didRejectAssetResourceReportMismatch = false
        let mismatchedAssetResourceReportArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"recoveryIdentifierCount\" : 0",
                with: "\"recoveryIdentifierCount\" : 1"
            )
        do {
            _ = try store.importArchiveText(mismatchedAssetResourceReportArchive)
        } catch let error as BracketProjectImportError {
            didRejectAssetResourceReportMismatch = error == .assetResourceReportMismatch
        }
        #expect(didRejectAssetResourceReportMismatch)

        var didRejectMergeReadinessReportMismatch = false
        let mismatchedMergeReadinessReportArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"score\" : 95",
                with: "\"score\" : 42"
            )
        do {
            _ = try store.importArchiveText(mismatchedMergeReadinessReportArchive)
        } catch let error as BracketProjectImportError {
            didRejectMergeReadinessReportMismatch = error == .mergeReadinessReportMismatch
        }
        #expect(didRejectMergeReadinessReportMismatch)

        var didRejectImageBundleManifestMismatch = false
        let mismatchedImageBundleManifestArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"completeRawProcessedPairCount\" : 5",
                with: "\"completeRawProcessedPairCount\" : 4"
            )
        do {
            _ = try store.importArchiveText(mismatchedImageBundleManifestArchive)
        } catch let error as BracketProjectImportError {
            didRejectImageBundleManifestMismatch = error == .imageBundleManifestMismatch
        }
        #expect(didRejectImageBundleManifestMismatch)

        var didRejectImageBundleDraftPackageMismatch = false
        let imageBundleDraftPackageFile = try #require(bundle.file(kind: "image-bundle-draft-package"))
        let mismatchedImageBundleDraftPackageArchive = bundle.archiveText
            .replacingOccurrences(
                of: imageBundleDraftPackageFile.contents,
                with: String(repeating: "A", count: imageBundleDraftPackageFile.contents.count)
            )
        do {
            _ = try store.importArchiveText(mismatchedImageBundleDraftPackageArchive)
        } catch let error as BracketProjectImportError {
            didRejectImageBundleDraftPackageMismatch = error == .imageBundleDraftPackageMismatch
        }
        #expect(didRejectImageBundleDraftPackageMismatch)

        var didRejectFinalOutputManifestMismatch = false
        let mismatchedFinalOutputManifestArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"outputCount\" : 3",
                with: "\"outputCount\" : 2"
            )
        do {
            _ = try store.importArchiveText(mismatchedFinalOutputManifestArchive)
        } catch let error as BracketProjectImportError {
            didRejectFinalOutputManifestMismatch = error == .finalOutputManifestMismatch
        }
        #expect(didRejectFinalOutputManifestMismatch)

        var didRejectFinalOutputReadinessAuditMismatch = false
        let mismatchedFinalOutputReadinessAuditArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"blockerReasonCount\" : 2",
                with: "\"blockerReasonCount\" : 1"
            )
        do {
            _ = try store.importArchiveText(mismatchedFinalOutputReadinessAuditArchive)
        } catch let error as BracketProjectImportError {
            didRejectFinalOutputReadinessAuditMismatch = error == .finalOutputReadinessAuditMismatch
        }
        #expect(didRejectFinalOutputReadinessAuditMismatch)
        let mismatchedFinalOutputReadinessAuditPreviewFailure = try #require(
            store.importPreviewFailure(mismatchedFinalOutputReadinessAuditArchive)
        )
        #expect(mismatchedFinalOutputReadinessAuditPreviewFailure.failureKind == "final-output-readiness-audit-mismatch")
        #expect(mismatchedFinalOutputReadinessAuditPreviewFailure.recoverySuggestion == "Export the project again so the final-output readiness audit matches the final-output manifest.")
        #expect(mismatchedFinalOutputReadinessAuditPreviewFailure.accessibilityValue.contains("No import was saved."))

        var didRejectFinalOutputActionPlanHeaderMismatch = false
        let finalOutputActionPlanHeader = "Final Output Action Plan: \(try #require(bundle.finalOutputActionPlanSummary))"
        let mismatchedFinalOutputActionPlanHeaderArchive = bundle.archiveText
            .replacingOccurrences(
                of: finalOutputActionPlanHeader,
                with: "Final Output Action Plan: Tampered action plan."
            )
        do {
            _ = try store.importArchiveText(mismatchedFinalOutputActionPlanHeaderArchive)
        } catch let error as BracketProjectImportError {
            didRejectFinalOutputActionPlanHeaderMismatch = error == .finalOutputActionPlanHeaderMismatch
        }
        #expect(didRejectFinalOutputActionPlanHeaderMismatch)
        let mismatchedFinalOutputActionPlanHeaderPreviewFailure = try #require(
            store.importPreviewFailure(mismatchedFinalOutputActionPlanHeaderArchive)
        )
        #expect(mismatchedFinalOutputActionPlanHeaderPreviewFailure.failureKind == "final-output-action-plan-header-mismatch")
        #expect(mismatchedFinalOutputActionPlanHeaderPreviewFailure.recoverySuggestion == "Export the project again so the final-output action-plan header matches the readiness audit.")
        #expect(mismatchedFinalOutputActionPlanHeaderPreviewFailure.accessibilityValue.contains("No import was saved."))

        var didRejectFinalOutputPreviewImageMismatch = false
        let finalOutputPreviewImageFile = try #require(bundle.file(kind: "final-output-preview-image"))
        let mismatchedFinalOutputPreviewImageArchive = bundle.archiveText
            .replacingOccurrences(
                of: finalOutputPreviewImageFile.contents,
                with: String(repeating: "A", count: finalOutputPreviewImageFile.contents.count)
            )
        do {
            _ = try store.importArchiveText(mismatchedFinalOutputPreviewImageArchive)
        } catch let error as BracketProjectImportError {
            didRejectFinalOutputPreviewImageMismatch = error == .finalOutputPreviewImageMismatch
        }
        #expect(didRejectFinalOutputPreviewImageMismatch)

        var didRejectFinalOutputDraftJPEGMismatch = false
        let finalOutputDraftJPEGFile = try #require(bundle.file(kind: "final-output-draft-review-jpeg"))
        let mismatchedFinalOutputDraftJPEGArchive = bundle.archiveText
            .replacingOccurrences(
                of: finalOutputDraftJPEGFile.contents,
                with: String(repeating: "A", count: finalOutputDraftJPEGFile.contents.count)
            )
        do {
            _ = try store.importArchiveText(mismatchedFinalOutputDraftJPEGArchive)
        } catch let error as BracketProjectImportError {
            didRejectFinalOutputDraftJPEGMismatch = error == .finalOutputDraftJPEGMismatch
        }
        #expect(didRejectFinalOutputDraftJPEGMismatch)

        var didRejectExposureComparisonMismatch = false
        let mismatchedExposureComparisonArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"baselineDisplayLabel\" : \"0 EV\"",
                with: "\"baselineDisplayLabel\" : \"2 EV\""
            )
        do {
            _ = try store.importArchiveText(mismatchedExposureComparisonArchive)
        } catch let error as BracketProjectImportError {
            didRejectExposureComparisonMismatch = error == .exposureComparisonMismatch
        }
        #expect(didRejectExposureComparisonMismatch)

        var didRejectSideBySidePixelComparisonMismatch = false
        let mismatchedSideBySidePixelComparisonArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"comparisonCount\" : 4",
                with: "\"comparisonCount\" : 3"
            )
        do {
            _ = try store.importArchiveText(mismatchedSideBySidePixelComparisonArchive)
        } catch let error as BracketProjectImportError {
            didRejectSideBySidePixelComparisonMismatch = error == .sideBySidePixelComparisonMismatch
        }
        #expect(didRejectSideBySidePixelComparisonMismatch)

        var didRejectFusionPreviewMismatch = false
        let mismatchedFusionPreviewArchive = bundle.archiveText
            .replacingOccurrences(
                of: "\"sourceCount\" : 5",
                with: "\"sourceCount\" : 4"
            )
        do {
            _ = try store.importArchiveText(mismatchedFusionPreviewArchive)
        } catch let error as BracketProjectImportError {
            didRejectFusionPreviewMismatch = error == .fusionPreviewMismatch
        }
        #expect(didRejectFusionPreviewMismatch)

        var didRejectExportNoteMismatch = false
        let mismatchedExportNoteArchive = bundle.archiveText
            .replacingOccurrences(
                of: "Export note for 5-shot photos bracket",
                with: "Export note for edited photos bracket"
            )
        do {
            _ = try store.importArchiveText(mismatchedExportNoteArchive)
        } catch let error as BracketProjectImportError {
            didRejectExportNoteMismatch = error == .exportNoteMismatch
        }
        #expect(didRejectExportNoteMismatch)
        let mismatchedExportNotePreviewFailure = try #require(
            store.importPreviewFailure(mismatchedExportNoteArchive)
        )
        #expect(mismatchedExportNotePreviewFailure.failureKind == "export-note-mismatch")
        #expect(mismatchedExportNotePreviewFailure.recoverySuggestion == "Export the project again so the export note matches the archive payload facts.")

        var didRejectArchiveIntegrityManifestMismatch = false
        let mismatchedPrivacyArchive = bundle.archiveText
            .replacingOccurrences(
                of: "Photos asset identifiers: redacted",
                with: "Photos asset identifiers: withheld"
            )
        do {
            _ = try store.importArchiveText(mismatchedPrivacyArchive)
        } catch let error as BracketProjectImportError {
            didRejectArchiveIntegrityManifestMismatch = error == .archiveIntegrityManifestMismatch
        }
        #expect(didRejectArchiveIntegrityManifestMismatch)
        #expect(try store.loadAll().isEmpty)
    }

    @Test @MainActor func cameraControllerImportsProjectArchiveTextIntoLibrary() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let camera = CameraController(projectStore: store)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Import"],
            userNote: "Archive restore candidate",
            diagnosticsSummary: "Import diagnostics",
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let bundle = try BracketProjectExportBundle.make(
            project: project,
            privacyLevel: .metadataOnly,
            createdAt: Date(timeIntervalSince1970: 20)
        )

        let preview = try camera.previewProjectArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30)
        )
        let imported = try camera.importProjectArchiveText(
            bundle.archiveText,
            importedAt: Date(timeIntervalSince1970: 30)
        )

        #expect(preview.actionSummary == "Import as new project project-photos-metadata-5shots-schema1-12.")
        #expect(preview.accessibilityValue.contains("Project Import Preview"))
        #expect(imported.project.id == "project-photos-metadata-5shots-schema1-12")
        #expect(camera.lastBracketProject?.id == imported.project.id)
        #expect(camera.lastBracketManifest == imported.project.manifest)
        #expect(camera.lastBracketReviewSequence == BracketReviewSequence.make(manifest: imported.project.manifest))
        #expect(camera.bracketProjectLibrarySnapshot.currentProjectID == imported.project.id)
        #expect(camera.bracketProjectLibrarySnapshot.projects.map(\.id) == [imported.project.id])
        #expect(try store.current()?.id == imported.project.id)
    }

    @Test func bracketProjectUserCurationNormalizesFavoriteTagsNotesAndSearchTokens() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["  Portfolio Candidate  ", "", "Portfolio Candidate"],
            userNote: "  Initial note  ",
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let curated = project.withUserCuration(
            isFavorite: true,
            acceptedTags: [" Gallery ", "Portfolio Candidate", "Gallery", ""],
            userNote: "  Keep for website review  ",
            updatedAt: Date(timeIntervalSince1970: 40)
        )

        #expect(project.acceptedTags == ["Portfolio Candidate"])
        #expect(project.userNote == "Initial note")
        #expect(curated.id == project.id)
        #expect(curated.isFavorite)
        #expect(curated.curation?.updatedAt == Date(timeIntervalSince1970: 40))
        #expect(curated.acceptedTags == ["Gallery", "Portfolio Candidate"])
        #expect(curated.userNote == "Keep for website review")
        #expect(curated.searchTokens.contains("favorite"))
        #expect(curated.searchTokens.contains("gallery"))
        #expect(curated.searchTokens.contains("website"))
        #expect(curated.projectLibraryAccessibilityValue.contains("Favorite project"))
        #expect(curated.projectLibraryAccessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(curated.projectLibraryAccessibilityValue.contains("not final rendered image proof"))
        #expect(curated.projectLibraryAccessibilityValue.contains("Tags Gallery, Portfolio Candidate"))
        #expect(curated.projectLibraryAccessibilityValue.contains("Note Keep for website review"))
    }

    @Test @MainActor func cameraControllerUpdatesProjectCurationInLibrarySnapshot() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let indexer = RecordingBracketProjectSpotlightIndexer()
        let store = FileBracketProjectStore(rootURL: rootURL, spotlightIndexer: indexer)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)
        let camera = CameraController(projectStore: store)

        let updated = try camera.updateProjectCuration(
            projectID: project.id,
            isFavorite: true,
            acceptedTags: ["Archive", "Gallery"],
            userNote: "Wall print candidate",
            updatedAt: Date(timeIntervalSince1970: 50)
        )

        #expect(updated.isFavorite)
        #expect(updated.acceptedTags == ["Archive", "Gallery"])
        #expect(updated.userNote == "Wall print candidate")
        #expect(camera.lastBracketProject?.id == project.id)
        #expect(camera.lastBracketProject?.isFavorite == true)
        #expect(camera.bracketProjectLibrarySnapshot.projects.first?.id == project.id)
        #expect(camera.bracketProjectLibrarySnapshot.projects.first?.isFavorite == true)
        #expect(try store.search("favorite gallery wall").map(\.id) == [project.id])
        #expect(indexer.indexedRecords.map(\.uniqueIdentifier) == [
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id),
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id)
        ])
    }

    @Test @MainActor func cameraControllerPersistsPhotosResourceInspectionForLatestProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let indexer = RecordingBracketProjectSpotlightIndexer()
        let store = FileBracketProjectStore(rootURL: rootURL, spotlightIndexer: indexer)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)
        let camera = CameraController(projectStore: store)

        let firstShot = BracketProjectResourceInspection.ShotResources(
            index: 0,
            assetIdentifier: "asset-under",
            resources: [
                BracketProjectResourceInspection.Resource(
                    resourceType: "photo",
                    originalFilename: "IMG_0001.HEIC",
                    uniformTypeIdentifier: "public.heic"
                ),
                BracketProjectResourceInspection.Resource(
                    resourceType: "alternatePhoto",
                    originalFilename: "IMG_0001.DNG",
                    uniformTypeIdentifier: "com.adobe.raw-image"
                )
            ]
        )
        let firstUpdate = try camera.updateLatestProjectResourceInspection(
            shotResources: firstShot,
            inspectedAt: Date(timeIntervalSince1970: 50)
        )
        let firstInspection = try #require(firstUpdate.resourceInspection)

        #expect(firstInspection.source == .photosAssetResource)
        #expect(firstInspection.items[0].resourceState == "inspected-raw-and-processed")
        #expect(firstInspection.items[1].resourceState == "not-inspected")

        let secondShot = BracketProjectResourceInspection.ShotResources(
            index: 1,
            assetIdentifier: "asset-under-mid",
            resources: [
                BracketProjectResourceInspection.Resource(
                    resourceType: "fullSizePhoto",
                    originalFilename: "IMG_0002.JPG",
                    uniformTypeIdentifier: "public.jpeg"
                )
            ]
        )
        let secondUpdate = try camera.updateLatestProjectResourceInspection(
            shotResources: secondShot,
            inspectedAt: Date(timeIntervalSince1970: 60)
        )
        let secondInspection = try #require(secondUpdate.resourceInspection)
        let storedInspection = try #require(store.latest()?.resourceInspection)

        #expect(secondInspection.items[0].resourceState == "inspected-raw-and-processed")
        #expect(secondInspection.items[1].resourceState == "inspection-mismatch")
        #expect(secondInspection.items[1].mismatchLabels == ["Expected RAW resource missing"])
        #expect(secondInspection.items.filter { !$0.resources.isEmpty }.count == 2)
        #expect(storedInspection == secondInspection)
        #expect(camera.lastBracketProject?.resourceInspection == secondInspection)
        #expect(camera.bracketProjectLibrarySnapshot.projects.first?.resourceInspection == secondInspection)
        #expect(try store.search("IMG 0001 DNG photos resource metadata").map(\.id) == [project.id])
        #expect(indexer.indexedRecords.map(\.uniqueIdentifier) == [
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id),
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id),
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id)
        ])
    }

    @Test @MainActor func cameraControllerPersistsPhotosThumbnailInspectionForLatestProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let indexer = RecordingBracketProjectSpotlightIndexer()
        let store = FileBracketProjectStore(rootURL: rootURL, spotlightIndexer: indexer)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)
        let camera = CameraController(projectStore: store)

        let firstShot = BracketProjectThumbnailInspection.ShotThumbnail(
            index: 0,
            assetIdentifier: "asset-under",
            targetPixelWidth: 1170,
            targetPixelHeight: 2532,
            deliveredPixelWidth: 1024,
            deliveredPixelHeight: 768,
            deliveryMode: "highQualityFormat",
            contentMode: "aspectFit"
        )
        let firstUpdate = try camera.updateLatestProjectThumbnailInspection(
            shotThumbnail: firstShot,
            inspectedAt: Date(timeIntervalSince1970: 70)
        )
        let firstInspection = try #require(firstUpdate.thumbnailInspection)

        #expect(firstInspection.source == .photosImageManager)
        #expect(firstInspection.items[0].resultState == "thumbnail-delivered")
        #expect(firstInspection.items[0].deliveredPixelWidth == 1024)
        #expect(firstInspection.items[0].deliveredPixelHeight == 768)
        #expect(firstInspection.items[1].resultState == "not-requested")

        let secondShot = BracketProjectThumbnailInspection.ShotThumbnail(
            index: 1,
            assetIdentifier: "asset-under-mid",
            targetPixelWidth: 1170,
            targetPixelHeight: 2532,
            deliveredPixelWidth: nil,
            deliveredPixelHeight: nil,
            deliveryMode: "highQualityFormat",
            contentMode: "aspectFit",
            errorDescription: "Photos returned no review thumbnail."
        )
        let secondUpdate = try camera.updateLatestProjectThumbnailInspection(
            shotThumbnail: secondShot,
            inspectedAt: Date(timeIntervalSince1970: 80)
        )
        let secondInspection = try #require(secondUpdate.thumbnailInspection)
        let storedInspection = try #require(store.latest()?.thumbnailInspection)
        let metadataCopy = secondUpdate.exportCopy(privacyLevel: .metadataOnly)

        #expect(secondInspection.items[0].resultState == "thumbnail-delivered")
        #expect(secondInspection.items[1].resultState == "thumbnail-error")
        #expect(secondInspection.items[1].errorDescription == "Photos returned no review thumbnail.")
        #expect(secondInspection.items.filter { $0.resultState != "not-requested" }.count == 2)
        #expect(storedInspection == secondInspection)
        #expect(camera.lastBracketProject?.thumbnailInspection == secondInspection)
        #expect(camera.bracketProjectLibrarySnapshot.projects.first?.thumbnailInspection == secondInspection)
        #expect(try store.search("thumbnail delivered 1024 768 photos image manager").map(\.id) == [project.id])
        #expect(metadataCopy.thumbnailInspection?.items[0].assetIdentifier == nil)
        #expect(metadataCopy.thumbnailInspection?.items[1].assetIdentifier == nil)
        #expect(indexer.indexedRecords.map(\.uniqueIdentifier) == [
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id),
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id),
            BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id)
        ])
    }

    @Test func latestBracketProjectExportFileProviderBuildsRedactedIntentFile() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let export = try LatestBracketProjectExportFileProvider(store: store).exportFile(
            privacy: .metadataOnly,
            filenameTemplate: .datedSummary,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let file = export.intentFile

        #expect(export.projectID == "project-photos-metadata-5shots-schema1-12")
        #expect(export.filename == "bracketer-19700101-0000-5shot-photos-metadata-only.txt")
        #expect(export.dialogText.contains("Metadata only"))
        #expect(export.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(export.accessibilityValue.contains("Project Export Bundle"))
        #expect(export.accessibilityValue.contains("Dated summary"))
        #expect(export.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(export.archiveText.contains("Bracketer Project Export Bundle"))
        #expect(export.archiveText.contains("Naming: Dated summary"))
        #expect(export.archiveText.contains("Final Output Action Plan: 2 action item(s)"))
        #expect(export.archiveText.contains("Photos asset identifiers: redacted"))
        #expect(!export.archiveText.contains("asset-under"))
        #expect(!export.archiveText.contains("private-photos-group"))
        #expect(file.filename == export.filename)
        #expect(file.type == .plainText)
        #expect(String(decoding: file.data, as: UTF8.self) == export.archiveText)
    }

    @Test func latestBracketManifestExportFileProviderBuildsRedactedManifestIntentFile() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let export = try LatestBracketManifestExportFileProvider(store: store).exportFile(
            privacy: .metadataOnly,
            filenameTemplate: .datedSummary
        )
        let file = export.intentFile
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedManifest = try decoder.decode(BracketManifest.self, from: export.data)

        #expect(export.projectID == project.id)
        #expect(export.filename == "bracketer-19700101-0000-5shot-photos-metadata-only-manifest.json")
        #expect(export.dialogText.contains("Metadata only"))
        #expect(export.dialogText.contains("Manifest only"))
        #expect(export.accessibilityValue.contains("Latest Bracketer Manifest"))
        #expect(export.accessibilityValue.contains("no raw photo bytes"))
        #expect(file.filename == export.filename)
        #expect(file.type == .json)
        #expect(String(decoding: file.data, as: UTF8.self) == export.manifestJSON)
        #expect(decodedManifest == project.exportCopy(privacyLevel: .metadataOnly, generatedContentPolicy: .omit).manifest)
        #expect(export.manifestJSON.contains("\"schemaVersion\" : 1"))
        #expect(!export.manifestJSON.contains("asset-under"))
        #expect(!export.manifestJSON.contains("private-photos-group"))
    }

    @Test func latestBracketManifestExportFileProviderCanIncludeRecoveryIdentifiers() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let export = try LatestBracketManifestExportFileProvider(store: store).exportFile(
            privacy: .recoveryIdentifiers,
            filenameTemplate: .privacyAudit
        )

        #expect(export.filename == "bracketer-privacy-19700101-recovery-identifiers-schema1-manifest.json")
        #expect(export.dialogText.contains("Recovery identifiers"))
        #expect(export.manifestJSON.contains("asset-under"))
        #expect(export.manifestJSON.contains("private-photos-group"))
    }

    @Test func bracketProjectExportFileProviderBuildsSelectedProjectIntentFile() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let selectedProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let latestProject = selectedProject.withImportConflictIdentifier(
            "project-latest-shortcuts-export",
            importedAt: Date(timeIntervalSince1970: 99)
        )
        try store.save(selectedProject)
        try store.save(latestProject)

        let export = try BracketProjectExportFileProvider(store: store).exportFile(
            projectID: selectedProject.id,
            privacy: .recoveryIdentifiers,
            filenameTemplate: .projectIdentifier,
            createdAt: Date(timeIntervalSince1970: 120)
        )
        let file = export.intentFile

        #expect(try store.latest()?.id == latestProject.id)
        #expect(export.projectID == selectedProject.id)
        #expect(export.filename.contains(selectedProject.id))
        #expect(!export.filename.contains(latestProject.id))
        #expect(export.dialogText.contains("Recovery identifiers"))
        #expect(export.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(export.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(export.archiveText.contains("Project: \(selectedProject.id)"))
        #expect(!export.archiveText.contains("Project: \(latestProject.id)"))
        #expect(export.archiveText.contains("asset-under"))
        #expect(file.filename == export.filename)
        #expect(file.type == .plainText)
        #expect(String(decoding: file.data, as: UTF8.self) == export.archiveText)
    }

    @Test func bracketProjectExportFileProviderThrowsForMissingSelectedProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = BracketProjectExportFileProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        var didThrowMissingProject = false
        do {
            _ = try provider.exportFile(projectID: "missing-shortcuts-project")
        } catch BracketProjectExportFileError.projectNotFound(let projectID) {
            didThrowMissingProject = projectID == "missing-shortcuts-project"
        }

        #expect(didThrowMissingProject)
    }

    @Test func latestBracketManifestExportFileProviderThrowsWithoutProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = LatestBracketManifestExportFileProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        var didThrowNoProject = false
        do {
            _ = try provider.exportFile()
        } catch LatestBracketProjectExportError.noProject {
            didThrowNoProject = true
        }

        #expect(didThrowNoProject)
    }

    @Test func bracketProjectImportFileProviderImportsIntentFileThroughStore() throws {
        let exportRootURL = try makeTemporaryProjectStoreRoot()
        let importRootURL = try makeTemporaryProjectStoreRoot()
        defer {
            try? FileManager.default.removeItem(at: exportRootURL)
            try? FileManager.default.removeItem(at: importRootURL)
        }
        let exportStore = FileBracketProjectStore(rootURL: exportRootURL)
        let importStore = FileBracketProjectStore(rootURL: importRootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try exportStore.save(project)
        let export = try LatestBracketProjectExportFileProvider(store: exportStore).exportFile(
            privacy: .metadataOnly,
            filenameTemplate: .projectIdentifier,
            createdAt: Date(timeIntervalSince1970: 24)
        )
        let intentFile = IntentFile(data: export.data, filename: export.filename, type: .plainText)

        let imported = try BracketProjectImportFileProvider(store: importStore).importFile(
            intentFile,
            conflictPolicy: .keepBoth,
            importedAt: Date(timeIntervalSince1970: 36)
        )

        #expect(imported.projectID == export.projectID)
        #expect(imported.title == "5-shot photos bracket")
        #expect(imported.filename == export.filename)
        #expect(imported.payloadKinds.contains(BracketProjectMergeReadinessReport.kind))
        #expect(imported.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(imported.dialogText.contains("Imported 5-shot photos bracket"))
        #expect(imported.accessibilityValue.contains("Imported Bracketer Project"))
        #expect(imported.accessibilityValue.contains("Duplicate policy: Keep both"))
        #expect(imported.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(imported.accessibilityValue.contains("No raw photo bytes"))
        #expect(try importStore.latest()?.id == export.projectID)
        #expect(try importStore.current()?.id == export.projectID)
    }

    @Test func bracketProjectImportFileProviderKeepsDuplicateIntentImportsSeparate() throws {
        let exportRootURL = try makeTemporaryProjectStoreRoot()
        let importRootURL = try makeTemporaryProjectStoreRoot()
        defer {
            try? FileManager.default.removeItem(at: exportRootURL)
            try? FileManager.default.removeItem(at: importRootURL)
        }
        let exportStore = FileBracketProjectStore(rootURL: exportRootURL)
        let importStore = FileBracketProjectStore(rootURL: importRootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try exportStore.save(project)
        let export = try LatestBracketProjectExportFileProvider(store: exportStore).exportFile()
        let provider = BracketProjectImportFileProvider(store: importStore)

        _ = try provider.importData(
            export.data,
            filename: export.filename,
            conflictPolicy: .keepBoth,
            importedAt: Date(timeIntervalSince1970: 36)
        )
        let duplicate = try provider.importData(
            export.data,
            filename: export.filename,
            conflictPolicy: .keepBoth,
            importedAt: Date(timeIntervalSince1970: 42)
        )

        #expect(duplicate.projectID == "\(export.projectID)-import-42")
        #expect(duplicate.conflictSummary == "Conflict: kept both projects as \(export.projectID)-import-42")
        #expect(duplicate.dialogText.contains("kept both projects"))
        #expect(try importStore.loadAll().map(\.id) == ["\(export.projectID)-import-42", export.projectID])
    }

    @Test func bracketProjectImportFileProviderRejectsUnreadableIntentData() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = BracketProjectImportFileProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        var didRejectUnreadableArchive = false
        do {
            _ = try provider.importData(
                Data([0xFF, 0xFE, 0xFD]),
                filename: "broken-bracketer-project.txt"
            )
        } catch BracketProjectImportFileError.unreadableArchive(let filename) {
            didRejectUnreadableArchive = filename == "broken-bracketer-project.txt"
        }

        #expect(didRejectUnreadableArchive)
    }

    @Test func bracketProjectArchiveDocumentWrapsExportBundleForFiles() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)
        let bundle = try #require(try store.exportBundle(
            id: project.id,
            privacyLevel: .metadataOnly,
            filenameTemplate: .datedSummary
        ))

        let document = try BracketProjectArchiveDocument(
            bundle: bundle,
            importedAt: Date(timeIntervalSince1970: 48)
        )
        let roundTripDocument = try BracketProjectArchiveDocument(
            data: document.data,
            filename: document.filename,
            importedAt: Date(timeIntervalSince1970: 54)
        )

        #expect(BracketProjectArchiveDocument.readableContentTypes == [.plainText, .json])
        #expect(BracketProjectArchiveDocument.writableContentTypes == [.plainText])
        #expect(document.filename == "bracketer-19700101-0000-5shot-photos-metadata-only.txt")
        #expect(document.archiveText == bundle.archiveText)
        #expect(document.data == Data(bundle.archiveText.utf8))
        #expect(document.importBundle.project.id == bundle.projectID)
        #expect(document.importBundle.importedAt == Date(timeIntervalSince1970: 48))
        #expect(document.importBundle.payloadKinds.contains(BracketProjectMergeReadinessReport.kind))
        #expect(document.importBundle.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(document.accessibilityValue.contains("Bracketer Project Archive Document"))
        #expect(document.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(document.accessibilityValue.contains("No raw photo bytes"))
        #expect(roundTripDocument.importBundle.project.id == bundle.projectID)
        #expect(roundTripDocument.importBundle.importedAt == Date(timeIntervalSince1970: 54))
        #expect(roundTripDocument.accessibilityValue.contains("not final rendered image proof"))
    }

    @Test func bracketProjectArchiveDocumentRejectsUnreadableAndInvalidFiles() throws {
        var didRejectUnreadableArchive = false
        do {
            _ = try BracketProjectArchiveDocument(
                data: Data([0xFF, 0xFE, 0xFD]),
                filename: "broken-bracketer-project.txt"
            )
        } catch BracketProjectArchiveDocumentError.unreadableUTF8(let filename) {
            didRejectUnreadableArchive = filename == "broken-bracketer-project.txt"
        }

        var didRejectInvalidHeader = false
        do {
            _ = try BracketProjectArchiveDocument(
                archiveText: "Not a Bracketer archive",
                filename: "wrong.txt"
            )
        } catch BracketProjectImportError.invalidArchiveHeader {
            didRejectInvalidHeader = true
        }

        #expect(didRejectUnreadableArchive)
        #expect(didRejectInvalidHeader)
    }

    @Test func latestBracketProjectExportFileProviderThrowsWithoutProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = LatestBracketProjectExportFileProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        var didThrowNoProject = false
        do {
            _ = try provider.exportFile()
        } catch LatestBracketProjectExportError.noProject {
            didThrowNoProject = true
        }

        #expect(didThrowNoProject)
    }

    @Test func bracketProjectExportIntentPrivacyMapsToProjectPrivacyLevel() {
        #expect(BracketProjectExportIntentPrivacy.metadataOnly.projectPrivacyLevel == .metadataOnly)
        #expect(BracketProjectExportIntentPrivacy.recoveryIdentifiers.projectPrivacyLevel == .recoveryIdentifiers)
        #expect(BracketProjectExportIntentFilenameTemplate.projectIdentifier.projectFilenameTemplate == .projectIdentifier)
        #expect(BracketProjectExportIntentFilenameTemplate.datedSummary.projectFilenameTemplate == .datedSummary)
        #expect(BracketProjectExportIntentFilenameTemplate.privacyAudit.projectFilenameTemplate == .privacyAudit)
        #expect(BracketProjectImportIntentConflictPolicy.keepBoth.projectConflictPolicy == .keepBoth)
        #expect(BracketProjectImportIntentConflictPolicy.replaceExisting.projectConflictPolicy == .replaceExisting)
        #expect(BracketProjectImportIntentConflictPolicy.rejectDuplicate.projectConflictPolicy == .rejectDuplicate)
    }

    @Test func latestBracketProjectSummaryProviderReturnsEmptyStateWithoutProject() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = LatestBracketProjectSummaryProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        let summary = try provider.summary()

        #expect(!summary.hasProject)
        #expect(summary.title == "No bracket project yet")
        #expect(summary.dialogText.contains("Capture a bracket"))
    }

    @Test func latestBracketProjectSummaryProviderDescribesLatestProjectTruthfully() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review
        )
        try store.save(project)

        let summary = try LatestBracketProjectSummaryProvider(store: store).summary()

        #expect(summary.hasProject)
        #expect(summary.title == "Latest 5-shot bracket")
        #expect(summary.detail.contains("reviewable photos project"))
        #expect(summary.detail.contains("selected -4.0 EV"))
        #expect(summary.detail.contains("best 0 EV"))
        #expect(summary.detail.contains("recipe High contrast scene"))
        #expect(summary.privacy.contains("No raw photo bytes"))
        #expect(summary.finalOutputActionPlanSummary?.contains("Resolve blockers before export") == true)
        #expect(summary.dialogText.contains("Final output action plan: 2 action item(s)"))
        #expect(summary.accessibilityValue.contains("not final rendered image proof"))
        #expect(summary.suggestedAction == "Open Bracketer review or export the project manifest.")
        #expect(summary.accessibilityValue.contains("Photos identifiers scoped for recovery"))
    }

    @Test func latestBracketProjectReviewHandoffProviderRoutesEmptyStateTruthfully() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let provider = LatestBracketProjectReviewHandoffProvider(
            store: FileBracketProjectStore(rootURL: rootURL)
        )

        let result = try provider.handoff(requestedAt: Date(timeIntervalSince1970: 11))

        #expect(!result.summary.hasProject)
        #expect(result.handoff.destination == .camera)
        #expect(result.handoff.projectIdentifier == nil)
        #expect(result.handoff.projectTitle == nil)
        #expect(result.handoff.routingIdentifier.contains("|latest|"))
        #expect(result.handoff.accessibilityValue == "Destination: Camera | Bracket: 3 shots at +/-1 EV")
        #expect(result.dialogText == "Opening Bracketer camera. No saved project is available yet; capture a bracket before review.")
    }

    @Test func latestBracketProjectReviewHandoffProviderRoutesLatestProjectTitle() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review
        )
        try store.save(project)

        let result = try LatestBracketProjectReviewHandoffProvider(store: store)
            .handoff(requestedAt: Date(timeIntervalSince1970: 12))

        #expect(result.summary.hasProject)
        #expect(result.summary.title == "Latest 5-shot bracket")
        #expect(result.handoff.destination == .review)
        #expect(result.handoff.projectIdentifier == nil)
        #expect(result.handoff.projectTitle == "Latest 5-shot bracket")
        #expect(result.handoff.accessibilityValue == "Destination: Last Review | Bracket: 3 shots at +/-1 EV | Project: Latest 5-shot bracket")
        #expect(result.dialogText.contains("Opening Latest 5-shot bracket in Bracketer review"))
        #expect(result.dialogText.contains("Open Bracketer review or export the project manifest."))
    }

    @Test func bracketProjectEntityQueryResolvesSuggestedIdentifierAndSearchResults() async throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let photosProject = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Window"],
            userNote: "Interior archive candidate",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let simulatedPlan = BracketPlan(evStep: 1.0, requestedShotCount: 3)
        let simulatedReview = BracketReviewSequence.make(
            plan: simulatedPlan,
            assetIdentifiers: ["a", "b", "c"],
            capturedAt: Date(timeIntervalSince1970: 30)
        )
        let simulatedProject = BracketProject.make(
            manifest: simulatedReview.manifest(
                groupIdentifier: "entity-simulated-group",
                source: .simulated,
                plan: simulatedPlan,
                captureDevice: .simulatedWide,
                captureLocation: .simulatedNotRequested
            ),
            reviewSequence: simulatedReview,
            acceptedTags: ["Tripod"],
            createdAt: Date(timeIntervalSince1970: 30)
        )
        try store.save(photosProject)
        try store.save(simulatedProject)

        let query = BracketProjectEntityQuery(store: store)
        let suggested = try await query.suggestedEntities()
        let resolved = try await query.entities(for: [photosProject.id, "missing-project"])
        let searched = try await query.entities(matching: "window raw")
        let actionPlanSearched = try await query.entities(matching: "window resolve blockers")
        let providerResult = try BracketProjectLibrarySearchProvider(store: store).search(
            text: "window raw",
            collection: .rawAvailable,
            facet: .highDynamicRange,
            capturedDay: "1970-01-01",
            lensID: "1x Wide Camera",
            locationPolicyID: "Photo Location Requested, Project Redacted"
        )

        #expect(suggested.map(\.id) == [simulatedProject.id, photosProject.id])
        #expect(resolved.map(\.id) == [photosProject.id])
        #expect(searched.map(\.id) == [photosProject.id])
        #expect(searched.first?.title == "5-shot photos bracket")
        #expect(searched.first?.finalOutputActionPlanSummary.contains("Resolve blockers before export") == true)
        #expect(searched.first?.accessibilityValue.contains("Final output action plan: 2 action item(s)") == true)
        #expect(searched.first?.accessibilityValue.contains("not final rendered image proof") == true)
        #expect(searched.first?.accessibilityValue.contains("No raw photo bytes") == true)
        #expect(actionPlanSearched.map(\.id) == [photosProject.id])
        #expect(providerResult.entities.map(\.id) == [photosProject.id])
        #expect(providerResult.route.resultProjectIDs == [photosProject.id])
        #expect(providerResult.route.accessibilityValue.contains("Collection RAW Available"))
        #expect(providerResult.route.accessibilityValue.contains("Facet Dynamic Range"))
        #expect(providerResult.route.accessibilityValue.contains("Captured Day 1970-01-01"))
        #expect(providerResult.route.accessibilityValue.contains("Lens 1x-wide-camera"))
        #expect(providerResult.route.accessibilityValue.contains("Location Policy photo-location-requested-project-redacted"))
        #expect(providerResult.dialogText.contains("Found 1 project"))
    }

    @Test func bracketProjectSpotlightRecordRedactsPrivateIdentifiers() throws {
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            acceptedTags: ["Portfolio Window"],
            userNote: "Interior window archive candidate",
            diagnosticsSummary: "5 events | Latest: Info Capture | Bracket complete",
            createdAt: Date(timeIntervalSince1970: 12),
            updatedAt: Date(timeIntervalSince1970: 18)
        )

        let record = BracketProjectSpotlightRecord(project: project)
        let item = record.searchableItem()
        let searchableText = record.searchableText

        #expect(record.schemaVersion == 2)
        #expect(record.domainIdentifier == BracketProjectSpotlightRecord.domainIdentifier)
        #expect(record.uniqueIdentifier == BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id))
        #expect(record.uniqueIdentifier.hasPrefix("bracketer.project."))
        #expect(!record.uniqueIdentifier.contains(project.id))
        #expect(!record.uniqueIdentifier.contains("private-photos-group"))
        #expect(!searchableText.contains(project.id))
        #expect(!searchableText.contains("private-photos-group"))
        #expect(!searchableText.contains("asset-under"))
        #expect(record.finalOutputActionPlanSummary.contains("Resolve blockers before export"))
        #expect(searchableText.contains("Final output action plan: 2 action item(s)"))
        #expect(searchableText.contains("not final rendered image proof"))
        #expect(searchableText.contains("portfolio"))
        #expect(searchableText.contains("window"))
        #expect(searchableText.contains("raw"))
        #expect(searchableText.contains("Spotlight index excludes Photos local identifiers"))
        #expect(record.keywords.contains("resolve"))
        #expect(record.keywords.contains("blockers"))
        #expect(record.accessibilityValue.contains("Photos identifiers redacted"))
        #expect(record.accessibilityValue.contains("Final output action plan: 2 action item(s)"))
        #expect(item.uniqueIdentifier == record.uniqueIdentifier)
        #expect(item.domainIdentifier == BracketProjectSpotlightRecord.domainIdentifier)
        #expect(item.expirationDate == .distantFuture)
        #expect(item.attributeSet.title == record.title)
        #expect(item.attributeSet.displayName == record.displayName)
        #expect(item.attributeSet.contentDescription == record.contentDescription)
        #expect(item.attributeSet.contentDescription?.contains("Final output action plan: 2 action item(s)") == true)
        #expect(item.attributeSet.keywords?.contains("portfolio") == true)
        #expect(item.attributeSet.keywords?.contains("resolve") == true)
        #expect(item.attributeSet.identifier == record.uniqueIdentifier)
    }

    @Test func fileBracketProjectStoreIndexesAndDeletesSpotlightRecords() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let indexer = RecordingBracketProjectSpotlightIndexer()
        let store = FileBracketProjectStore(rootURL: rootURL, spotlightIndexer: indexer)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        let expectedIdentifier = BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: project.id)

        try store.save(project)

        #expect(indexer.indexedRecords.map(\.uniqueIdentifier) == [expectedIdentifier])
        #expect(try store.load(spotlightIdentifier: expectedIdentifier)?.id == project.id)

        try store.delete(id: project.id)

        #expect(indexer.deletedIdentifiers == [expectedIdentifier])

        try store.save(project)
        try store.deleteAll()

        #expect(indexer.deleteAllCallCount == 1)
    }

    @Test func bracketerSpotlightHandoffResolvesIndexedProjectToReviewHandoff() throws {
        let rootURL = try makeTemporaryProjectStoreRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = FileBracketProjectStore(rootURL: rootURL)
        let fixture = makeBracketNarrativeManifestFixture()
        let project = BracketProject.make(
            manifest: fixture.manifest,
            reviewSequence: fixture.review,
            createdAt: Date(timeIntervalSince1970: 12)
        )
        try store.save(project)

        let record = BracketProjectSpotlightRecord(project: project)
        let handoff = try #require(try BracketerSpotlightHandoff.handoff(
            forSpotlightIdentifier: record.uniqueIdentifier,
            store: store,
            requestedAt: Date(timeIntervalSince1970: 20)
        ))

        #expect(handoff.destination == .review)
        #expect(handoff.projectIdentifier == project.id)
        #expect(handoff.projectTitle == project.displayTitle)
        #expect(handoff.accessibilityValue.contains("Project: 5-shot photos bracket"))

        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: record.uniqueIdentifier]
        let activityHandoff = try #require(try BracketerSpotlightHandoff.handoff(
            from: activity,
            store: store,
            requestedAt: Date(timeIntervalSince1970: 21)
        ))

        #expect(activityHandoff.projectIdentifier == project.id)
        #expect(try BracketerSpotlightHandoff.handoff(
            forSpotlightIdentifier: "missing",
            store: store
        ) == nil)
    }

    @Test func bracketerAppIntentBracketPresetMapsToCapturePlan() {
        let preset = BracketerIntentBracketPreset.fiveShotTwoEV
        let plan = BracketPlan(
            evStep: preset.evStep,
            requestedShotCount: preset.shotCount
        )

        #expect(preset.handoffTitle == "5 shots at +/-2 EV")
        #expect(plan.evOffsets == [-4.0, -2.0, 0.0, 2.0, 4.0])
    }

    @Test func bracketerAppIntentTimerModeMapsToCameraTimer() {
        #expect(BracketerIntentTimerMode(timerMode: .off) == .off)
        #expect(BracketerIntentTimerMode(timerMode: .threeSeconds) == .threeSeconds)
        #expect(BracketerIntentTimerMode(timerMode: .tenSeconds) == .tenSeconds)
        #expect(BracketerIntentTimerMode.threeSeconds.timerMode == .threeSeconds)
        #expect(BracketerIntentTimerMode.tenSeconds.handoffTitle == "10s")
    }

    @Test func bracketerShortcutsStayWithinPlatformShortcutLimit() {
        #expect(BracketerShortcuts.appShortcuts.count == 10)
    }

    @Test func bracketerShortcutTileInventoryReportsDeferredIntentsAtPlatformLimit() {
        let inventory = BracketerShortcutTileInventory.current

        #expect(inventory.registeredTileCount == 10)
        #expect(inventory.platformLimit == 10)
        #expect(!inventory.hasHeadroom)
        #expect(inventory.deferredIntentTitles.contains("Prepare Timed Bracketer Capture"))
        #expect(inventory.deferredIntentTitles.contains("Open Latest Bracketer Review"))
        #expect(inventory.deferredIntentTitles.contains("Export Latest Bracketer Manifest"))
        #expect(inventory.accessibilityValue.contains("No shortcut tile headroom"))
        #expect(inventory.accessibilityValue.contains("Deferred intents remain available as App Intents"))
    }

    @Test @MainActor func bracketerAppIntentRouterStoresLatestHandoff() {
        let handoff = BracketerAppIntentHandoff(
            destination: .intelligence,
            bracketPreset: .sevenShotTwoEV,
            requestedAt: Date(timeIntervalSince1970: 0)
        )

        BracketerAppIntentRouter.shared.handle(handoff)

        #expect(BracketerAppIntentRouter.shared.lastHandoff == handoff)
        #expect(handoff.accessibilityValue == "Destination: Apple Intelligence | Bracket: 7 shots at +/-2 EV")
    }

    @Test @MainActor func bracketerAppIntentRouterStoresProjectHandoff() {
        let handoff = BracketerAppIntentHandoff(
            destination: .review,
            bracketPreset: .threeShotOneEV,
            requestedAt: Date(timeIntervalSince1970: 0),
            projectIdentifier: "project-simulated-entity",
            projectTitle: "3-shot simulated bracket"
        )

        BracketerAppIntentRouter.shared.handle(handoff)

        #expect(BracketerAppIntentRouter.shared.lastHandoff == handoff)
        #expect(handoff.accessibilityValue == "Destination: Last Review | Bracket: 3 shots at +/-1 EV | Project: 3-shot simulated bracket | Project ID: project-simulated-entity")
    }

    @Test @MainActor func bracketerAppIntentRouterStoresLatestReviewHandoff() {
        let handoff = BracketerAppIntentHandoff(
            destination: .review,
            bracketPreset: .threeShotOneEV,
            requestedAt: Date(timeIntervalSince1970: 7),
            projectTitle: "Latest 5-shot bracket"
        )

        BracketerAppIntentRouter.shared.handle(handoff)

        #expect(BracketerAppIntentRouter.shared.lastHandoff == handoff)
        #expect(handoff.routingIdentifier.contains("|latest|"))
        #expect(handoff.accessibilityValue == "Destination: Last Review | Bracket: 3 shots at +/-1 EV | Project: Latest 5-shot bracket")
    }

    @Test @MainActor func bracketerAppIntentRouterStoresTimerPreparedCaptureHandoff() {
        let handoff = BracketerAppIntentHandoff(
            destination: .camera,
            bracketPreset: .fiveShotTwoEV,
            requestedAt: Date(timeIntervalSince1970: 42),
            timerMode: .threeSeconds
        )

        BracketerAppIntentRouter.shared.handle(handoff)

        #expect(BracketerAppIntentRouter.shared.lastHandoff == handoff)
        #expect(handoff.capturePlan.evOffsets == [-4.0, -2.0, 0.0, 2.0, 4.0])
        #expect(handoff.capturePlan.centerBias == 0)
        #expect(handoff.routingIdentifier.contains("threeSeconds"))
        #expect(handoff.accessibilityValue == "Destination: Camera | Bracket: 5 shots at +/-2 EV | Timer: 3s | Timer-prepared handoff only; capture still requires the photographer in the app.")
    }

    @Test func intelligenceRuntimeDiagnosticReportsDeterministicFallback() {
        let diagnostic = IntelligenceRuntimeDiagnostic(
            availability: .modelNotReady,
            captureCoachRun: makeCaptureCoachRun(fallbackReason: "Not refreshed in this session."),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session.")
        )

        #expect(diagnostic.state == .deterministicFallback)
        #expect(diagnostic.title == "Deterministic fallback active")
        #expect(diagnostic.detail == "Availability: Model not ready. Coach: deterministicFallback without Apple Intelligence. Recipe: deterministicFallback without Apple Intelligence.")
        #expect(diagnostic.action == "Keep the device online and plugged in until the model is ready.")
        #expect(diagnostic.accessibilityValue == "Deterministic fallback active | Availability: Model not ready. Coach: deterministicFallback without Apple Intelligence. Recipe: deterministicFallback without Apple Intelligence. | Action: Keep the device online and plugged in until the model is ready.")
    }

    @Test func intelligenceRuntimeDiagnosticReportsReadyPhysicalDeviceWithoutLiveRun() {
        let diagnostic = IntelligenceRuntimeDiagnostic(
            availability: .available,
            captureCoachRun: makeCaptureCoachRun(fallbackReason: "Not refreshed in this session."),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session.")
        )

        #expect(diagnostic.state == .readyForLiveRun)
        #expect(diagnostic.title == "Ready for live Apple Intelligence")
        #expect(diagnostic.detail == "Availability is ready, but this session has not observed Foundation Models output yet.")
        #expect(diagnostic.action == "Refresh Capture Coach or plan a Bracket Recipe on an Apple Intelligence-capable iPhone.")
    }

    @Test func intelligenceRuntimeDiagnosticReportsLiveFoundationModelsProof() {
        let diagnostic = IntelligenceRuntimeDiagnostic(
            availability: .available,
            captureCoachRun: makeCaptureCoachRun(
                source: .foundationModels,
                usedAppleIntelligence: true,
                fallbackReason: nil
            ),
            bracketRecipeRun: makeBracketRecipeRun(
                source: .foundationModels,
                usedAppleIntelligence: true,
                fallbackReason: nil
            )
        )

        #expect(diagnostic.state == .liveAppleIntelligence)
        #expect(diagnostic.title == "Live Apple Intelligence observed")
        #expect(diagnostic.detail == "Foundation Models output observed for Capture Coach and Bracket Recipe.")
        #expect(diagnostic.sourceSummary == "Coach: foundationModels with Apple Intelligence. Recipe: foundationModels with Apple Intelligence")
    }

    @Test func intelligenceRuntimeDiagnosticFlagsFoundationModelsWithoutProof() {
        let diagnostic = IntelligenceRuntimeDiagnostic(
            availability: .available,
            captureCoachRun: makeCaptureCoachRun(
                source: .foundationModels,
                usedAppleIntelligence: false,
                fallbackReason: nil
            ),
            bracketRecipeRun: makeBracketRecipeRun(fallbackReason: "Not planned in this session.")
        )

        #expect(diagnostic.state == .inconclusiveFoundationModels)
        #expect(diagnostic.title == "Foundation Models inconclusive")
        #expect(diagnostic.action == "Rerun the same coach or recipe action on device and keep the result bundle.")
    }

    @Test func intelligenceAvailabilityResolverKeepsSimulatorGenerativeFeaturesOff() {
        let resolver = IntelligenceAvailabilityResolver(
            runningInSimulator: true,
            localeIdentifier: "en_US",
            localeSupported: true
        )

        let availability = resolver.resolve(runtimeAvailability: .available)

        #expect(availability == .simulatorUnsupported)
        #expect(!availability.isUsable)
        #expect(availability.accessibilityValue.contains("Simulator builds keep generative features disabled"))
    }

    @Test func intelligenceAvailabilityResolverMapsFoundationModelStates() {
        let resolver = IntelligenceAvailabilityResolver(
            runningInSimulator: false,
            localeIdentifier: "en_US",
            localeSupported: true
        )

        #expect(resolver.resolve(runtimeAvailability: .available) == .available)
        #expect(resolver.resolve(runtimeAvailability: .frameworkUnavailable) == .frameworkUnavailable)
        #expect(resolver.resolve(runtimeAvailability: .deviceNotEligible) == .deviceNotEligible)
        #expect(resolver.resolve(runtimeAvailability: .appleIntelligenceNotEnabled) == .appleIntelligenceNotEnabled)
        #expect(resolver.resolve(runtimeAvailability: .modelNotReady) == .modelNotReady)
        #expect(resolver.resolve(runtimeAvailability: .unknownUnavailable).statusTitle == "Unknown")
    }

    @Test func intelligenceAvailabilityResolverPreservesUserAndLocaleBlockers() {
        let disabled = IntelligenceAvailabilityResolver(
            userEnabled: false,
            runningInSimulator: false,
            localeIdentifier: "en_US",
            localeSupported: true
        )
        let unsupportedLocale = IntelligenceAvailabilityResolver(
            runningInSimulator: false,
            localeIdentifier: "zz_ZZ",
            localeSupported: false
        )

        #expect(disabled.resolve(runtimeAvailability: .available) == .disabledByUser)
        #expect(unsupportedLocale.resolve(runtimeAvailability: .available) == .localeUnsupported(identifier: "zz_ZZ"))
        #expect(unsupportedLocale.resolve(runtimeAvailability: .available).recoveryAction == "Use an Apple Intelligence-supported language and region.")
    }

    @Test func intelligenceAvailabilityServiceSupportsDeterministicUITestOverrides() {
        #expect(IntelligenceAvailabilityService.forcedAvailability(
            from: ["-ui-testing-intelligence-available"]
        ) == .available)
        #expect(IntelligenceAvailabilityService.forcedAvailability(
            from: ["-ui-testing-intelligence-unavailable-device"]
        ) == .deviceNotEligible)
        #expect(IntelligenceAvailabilityService.forcedAvailability(
            from: ["-ui-testing-intelligence-unavailable-disabled"]
        ) == .appleIntelligenceNotEnabled)
        #expect(IntelligenceAvailabilityService.forcedAvailability(
            from: ["-ui-testing-intelligence-model-not-ready"]
        ) == .modelNotReady)
        #expect(IntelligenceAvailabilityService.forcedAvailability(from: []) == nil)
    }

    @Test func intelligenceAvailabilityServicePreservesLocalBlockersBeforePlatformQueries() {
        #expect(IntelligenceAvailabilityService.currentAvailability(
            arguments: [],
            userEnabled: false,
            locale: Locale(identifier: "en_US")
        ) == .disabledByUser)

        #if targetEnvironment(simulator)
        #expect(IntelligenceAvailabilityService.currentAvailability(
            arguments: [],
            userEnabled: true,
            locale: Locale(identifier: "en_US")
        ) == .simulatorUnsupported)
        #endif
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "BracketerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTemporaryProjectStoreRoot() throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BracketerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    private final class RecordingBracketProjectSpotlightIndexer: BracketProjectSpotlightIndexing {
        private(set) var indexedRecords: [BracketProjectSpotlightRecord] = []
        private(set) var deletedIdentifiers: [String] = []
        private(set) var deleteAllCallCount = 0

        func index(_ project: BracketProject) {
            indexedRecords.append(BracketProjectSpotlightRecord(project: project))
        }

        func delete(projectID: String) {
            deletedIdentifiers.append(BracketProjectSpotlightRecord.uniqueIdentifier(forProjectID: projectID))
        }

        func deleteAllProjects() {
            deleteAllCallCount += 1
        }
    }

    private func makeBalancedClippingFrameAnalysis() -> HistogramFrameAnalysis {
        let pixels = [
            (255, 255, 255), (255, 255, 255), (128, 128, 128), (128, 128, 128),
            (255, 255, 255), (255, 255, 255), (128, 128, 128), (128, 128, 128),
            (0, 0, 0), (0, 0, 0), (128, 128, 128), (128, 128, 128),
            (0, 0, 0), (0, 0, 0), (128, 128, 128), (128, 128, 128),
        ].reduce(into: [UInt8]()) { bytes, pixel in
            bytes.append(UInt8(pixel.0))
            bytes.append(UInt8(pixel.1))
            bytes.append(UInt8(pixel.2))
            bytes.append(255)
        }

        return HistogramFrameAnalyzer.analyzeRGBABytes(
            pixels,
            width: 4,
            height: 4,
            stepX: 1,
            stepY: 1,
            zebraColumns: 4,
            zebraRows: 4,
            zebraRegionWarningFraction: 0.5,
            focusThresholds: FocusPeakingThresholds(edgeThreshold: 20, regionWarningFraction: 0.5)
        )!
    }

    private func makeBracketNarrativeManifestFixture() -> (manifest: BracketManifest, review: BracketReviewSequence) {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let review = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: [
                "asset-under",
                "asset-under-mid",
                "asset-center",
                "asset-over-mid",
                "asset-over",
            ],
            capturedAt: Date(timeIntervalSince1970: 0),
            fileType: "RAW + Processed",
            availableRepresentations: [.processed, .raw]
        )
        let recipe = AppliedBracketRecipeRecord(
            id: "recipe-1",
            title: "High contrast scene",
            source: .deterministicFallback,
            plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 5),
            appliedAt: Date(timeIntervalSince1970: 0)
        )
        let manifest = review.manifest(
            groupIdentifier: "private-photos-group",
            source: .photos,
            plan: plan,
            recipe: recipe,
            captureDevice: BracketManifest.CaptureDeviceSnapshot(
                logicalLensLabel: "1x",
                cameraName: "Wide Camera",
                deviceType: "builtInWideAngleCamera",
                availableLensLabels: ["0.5x", "1x", "2x"],
                source: "unit-test capture session"
            ),
            captureLocation: .make(
                authorizationState: "On",
                locationSampleObserved: true,
                source: "unit-test CoreLocation provider"
            ),
            captureMotion: .unavailable(
                source: "unit-test motion manager not connected",
                captureDurationMilliseconds: 420
            )
        )

        return (manifest, review)
    }

    private func makeBracketNarrativeRequest(
        intelligenceAvailability: IntelligenceFeatureAvailability = .modelNotReady
    ) -> BracketReviewNarrativeRequest {
        let fixture = makeBracketNarrativeManifestFixture()

        return BracketReviewNarrativeRequest.make(
            context: BracketNarrativeContext.make(
                manifest: fixture.manifest,
                sequence: fixture.review,
                intelligenceAvailability: intelligenceAvailability
            )
        )
    }

    private func makeCaptureCoachContext(
        intelligenceAvailability: IntelligenceFeatureAvailability = .modelNotReady,
        deviceSnapshot: DeviceCapabilitySnapshot? = nil
    ) -> CaptureContextSummary {
        let plan = BracketPlan(evStep: 2.0, requestedShotCount: 5)
        let review = BracketReviewSequence.make(
            plan: plan,
            assetIdentifiers: [
                "asset-under",
                "asset-under-mid",
                "asset-center",
                "asset-over-mid",
                "asset-over",
            ],
            capturedAt: Date(timeIntervalSince1970: 0),
            fileType: "RAW + Processed",
            availableRepresentations: [.processed, .raw]
        )
        let manifest = review.manifest(
            groupIdentifier: "private-photos-group",
            source: .photos,
            plan: plan
        )
        let capture = EffectiveCaptureConfiguration.resolve(
            isRawEnabled: true,
            flashMode: .on,
            isFlashAvailable: true,
            timerMode: .threeSeconds,
            locationAuthorizationStatus: .authorizedWhenInUse
        )
        let settings = CaptureContextSettings(
            shootingMode: "MANUAL",
            showGrid: true,
            gridType: "Golden Ratio",
            showLevel: true,
            focusPeakingEnabled: true,
            focusPeakingColorName: "orange",
            focusPeakingIntensity: 0.65,
            showHistogram: true,
            showZebras: true
        )

        return CaptureContextSummary.make(
            plan: plan,
            deviceSnapshot: deviceSnapshot,
            captureConfiguration: capture,
            settings: settings,
            frameAnalysis: makeBalancedClippingFrameAnalysis(),
            reviewSequence: review,
            manifest: manifest,
            intelligenceAvailability: intelligenceAvailability
        )
    }

    private func makeCaptureCoachRun(
        source: CaptureCoachRunSource = .deterministicFallback,
        usedAppleIntelligence: Bool = false,
        fallbackReason: String? = nil
    ) -> CaptureCoachRun {
        CaptureCoachRun(
            source: source,
            response: CaptureCoachResponse(
                schemaVersion: CaptureCoachResponse.currentSchemaVersion,
                task: .preCaptureGuidance,
                usedAppleIntelligence: usedAppleIntelligence,
                availabilityStatus: usedAppleIntelligence ? "Available" : "Model not ready",
                suggestions: [
                    CaptureCoachSuggestion(
                        priority: .info,
                        title: "Hold highlights",
                        rationale: "Structured context reports highlight clipping.",
                        action: "Bias the next bracket darker.",
                        sourceSignals: ["highlight clipping"]
                    ),
                ],
                disclosure: "Test response."
            ),
            fallbackReason: fallbackReason
        )
    }

    private func makeBracketRecipeRun(
        source: BracketRecipeRunSource = .deterministicFallback,
        usedAppleIntelligence: Bool = false,
        fallbackReason: String? = nil
    ) -> BracketRecipeRun {
        BracketRecipeRun(
            source: source,
            response: BracketRecipeResponse(
                schemaVersion: BracketRecipeResponse.currentSchemaVersion,
                usedAppleIntelligence: usedAppleIntelligence,
                availabilityStatus: usedAppleIntelligence ? "Available" : "Model not ready",
                recommendations: [
                    BracketRecipeRecommendation(
                        title: "High contrast scene",
                        plan: BracketRecipePlan(evStep: 2.0, requestedShotCount: 5),
                        rationale: "The scene has bright and dark regions.",
                        action: "Use five shots.",
                        sourceSignals: ["scene prompt"],
                        confidence: 0.82
                    ),
                ],
                disclosure: "Test response."
            ),
            fallbackReason: fallbackReason
        )
    }
}

private struct FixedCaptureCoachModelGenerator: CaptureCoachModelGenerating {
    let modelResponse: CaptureCoachResponse

    func response(for request: CaptureCoachRequest) async throws -> CaptureCoachResponse {
        modelResponse
    }
}

private struct ThrowingCaptureCoachModelGenerator: CaptureCoachModelGenerating {
    func response(for request: CaptureCoachRequest) async throws -> CaptureCoachResponse {
        throw CaptureCoachTestFailure()
    }
}

private struct FixedBracketRecipeModelGenerator: BracketRecipeModelGenerating {
    let modelResponse: BracketRecipeResponse

    func response(for request: BracketRecipeRequest) async throws -> BracketRecipeResponse {
        modelResponse
    }
}

private struct ThrowingBracketRecipeModelGenerator: BracketRecipeModelGenerating {
    func response(for request: BracketRecipeRequest) async throws -> BracketRecipeResponse {
        throw CaptureCoachTestFailure()
    }
}

private struct FixedBracketReviewNarrativeModelGenerator: BracketReviewNarrativeModelGenerating {
    let modelResponse: BracketReviewNarrativeResponse

    func response(for request: BracketReviewNarrativeRequest) async throws -> BracketReviewNarrativeResponse {
        modelResponse
    }
}

private struct ThrowingBracketReviewNarrativeModelGenerator: BracketReviewNarrativeModelGenerating {
    func response(for request: BracketReviewNarrativeRequest) async throws -> BracketReviewNarrativeResponse {
        throw CaptureCoachTestFailure()
    }
}

private struct CaptureCoachTestFailure: LocalizedError, Sendable {
    var errorDescription: String? {
        "offline model failure"
    }
}

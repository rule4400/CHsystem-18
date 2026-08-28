import Foundation
import XCTest

@testable import CHShared

final class ModelCodableTests: XCTestCase {
  func testSiteSnapshotCodableRoundTrip() throws {
    let captureDate = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = SiteSnapshot(
      id: UUID(),
      name: "○○道路改良工事",
      connectionStatus: .thermalLimited,
      recordingStatus: .recording,
      desiredQuality: .high,
      appliedQuality: .standard,
      measuredQuality: VideoMetrics(
        width: 1_280,
        height: 720,
        framesPerSecond: 14.8,
        bitrateKbps: 742
      ),
      captureDate: captureDate,
      lastReceivedAt: captureDate.addingTimeInterval(0.25),
      qualityLimitReason: "端末温度が高いため"
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(SiteSnapshot.self, from: data)

    XCTAssertEqual(decoded, snapshot)
  }

  func testRecordingItemCodableRoundTripPreservesGapReason() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let recording = RecordingItem(
      id: UUID(),
      siteID: UUID(),
      siteName: "△△造成工事",
      startedAt: start,
      endedAt: start.addingTimeInterval(3_600),
      gaps: [
        RecordingGap(
          startedAt: start.addingTimeInterval(100),
          endedAt: start.addingTimeInterval(117),
          reason: "回線断"
        )
      ],
      expiresAt: start.addingTimeInterval(30 * 24 * 60 * 60)
    )

    let data = try JSONEncoder().encode(recording)
    let decoded = try JSONDecoder().decode(RecordingItem.self, from: data)

    XCTAssertEqual(decoded, recording)
    XCTAssertEqual(decoded.gaps.first?.reason, "回線断")
  }
}

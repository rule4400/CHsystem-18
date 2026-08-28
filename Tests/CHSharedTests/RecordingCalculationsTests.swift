import Foundation
import XCTest

@testable import CHShared

final class RecordingCalculationsTests: XCTestCase {
  private let origin = Date(timeIntervalSince1970: 1_800_000_000)

  func testGapDurationMergesOverlapsAndClipsToRecordingRange() {
    let gaps = [
      gap(from: -10, to: 10),
      gap(from: 5, to: 20),
      gap(from: 40, to: 55),
      gap(from: 50, to: 70),
      gap(from: 90, to: 120),
    ]

    let duration = RecordingCalculations.gapDuration(
      from: date(0),
      to: date(100),
      gaps: gaps
    )

    XCTAssertEqual(duration, 60, accuracy: 0.000_001)
  }

  func testGapDurationIgnoresReversedAndOutOfRangeGaps() {
    let gaps = [
      gap(from: 30, to: 20),
      gap(from: -30, to: -10),
      gap(from: 110, to: 120),
    ]

    XCTAssertEqual(
      RecordingCalculations.gapDuration(
        from: date(0),
        to: date(100),
        gaps: gaps
      ),
      0
    )
  }

  func testCoverageCalculatesRecordedDurationAndRatio() {
    let coverage = RecordingCalculations.coverage(
      from: date(0),
      to: date(100),
      gaps: [gap(from: 10, to: 25), gap(from: 70, to: 75)]
    )

    XCTAssertEqual(coverage.totalDuration, 100, accuracy: 0.000_001)
    XCTAssertEqual(coverage.gapDuration, 20, accuracy: 0.000_001)
    XCTAssertEqual(coverage.recordedDuration, 80, accuracy: 0.000_001)
    XCTAssertEqual(coverage.ratio, 0.8, accuracy: 0.000_001)
    XCTAssertEqual(coverage.percentage, 80, accuracy: 0.000_001)
  }

  func testCoverageForZeroOrReversedRangeIsZero() {
    for endOffset in [0.0, -1.0] {
      let coverage = RecordingCalculations.coverage(
        from: date(0),
        to: date(endOffset),
        gaps: []
      )

      XCTAssertEqual(coverage.totalDuration, 0)
      XCTAssertEqual(coverage.gapDuration, 0)
      XCTAssertEqual(coverage.recordedDuration, 0)
      XCTAssertEqual(coverage.ratio, 0)
    }
  }

  func testCompletedRecordingUsesItsOwnEndDate() {
    let recording = RecordingItem(
      id: UUID(),
      siteID: UUID(),
      siteName: "○○道路改良工事",
      startedAt: date(0),
      endedAt: date(60),
      gaps: [gap(from: 10, to: 20)]
    )

    let coverage = RecordingCalculations.coverage(
      for: recording,
      through: date(120)
    )

    XCTAssertEqual(coverage.totalDuration, 60, accuracy: 0.000_001)
    XCTAssertEqual(coverage.gapDuration, 10, accuracy: 0.000_001)
    XCTAssertEqual(coverage.ratio, 5.0 / 6.0, accuracy: 0.000_001)
  }

  func testOngoingRecordingUsesExplicitEvaluationDate() {
    let recording = RecordingItem(
      id: UUID(),
      siteID: UUID(),
      siteName: "○○道路改良工事",
      startedAt: date(0),
      gaps: [gap(from: 20, to: 30)]
    )

    let coverage = RecordingCalculations.coverage(
      for: recording,
      through: date(50)
    )

    XCTAssertEqual(coverage.totalDuration, 50, accuracy: 0.000_001)
    XCTAssertEqual(coverage.gapDuration, 10, accuracy: 0.000_001)
    XCTAssertEqual(coverage.ratio, 0.8, accuracy: 0.000_001)
  }

  private func date(_ offset: TimeInterval) -> Date {
    origin.addingTimeInterval(offset)
  }

  private func gap(
    from startOffset: TimeInterval,
    to endOffset: TimeInterval
  ) -> RecordingGap {
    RecordingGap(
      startedAt: date(startOffset),
      endedAt: date(endOffset)
    )
  }
}

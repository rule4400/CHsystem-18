import XCTest

@testable import CHShared

final class VideoQualityTests: XCTestCase {
  func testPresetOrderAndIdentityAreStable() {
    XCTAssertEqual(QualityPreset.allCases, [.low, .standard, .high])
    XCTAssertEqual(QualityPreset.standard.id, "standard")
  }

  func testPresetDisplayNamesAreJapanese() {
    XCTAssertEqual(QualityPreset.low.displayName, "低画質")
    XCTAssertEqual(QualityPreset.standard.displayName, "標準画質")
    XCTAssertEqual(QualityPreset.high.displayName, "高画質")
  }

  func testPresetMetricsMatchDesign() {
    XCTAssertEqual(
      QualityPreset.low.metrics,
      VideoMetrics(
        width: 640,
        height: 360,
        framesPerSecond: 10,
        bitrateKbps: 250
      )
    )
    XCTAssertEqual(
      QualityPreset.standard.metrics,
      VideoMetrics(
        width: 1_280,
        height: 720,
        framesPerSecond: 15,
        bitrateKbps: 800
      )
    )
    XCTAssertEqual(
      QualityPreset.high.metrics,
      VideoMetrics(
        width: 1_920,
        height: 1_080,
        framesPerSecond: 20,
        bitrateKbps: 2_000
      )
    )
  }
}

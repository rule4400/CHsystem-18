import XCTest

@testable import CHShared

final class StatusTests: XCTestCase {
  func testConnectionStatusDisplayNamesCoverEveryCase() {
    let expected = [
      "接続中",
      "ライブ",
      "再接続中",
      "オフライン",
      "カメラ利用不可",
      "温度制限中",
      "温度保護で一時停止",
    ]

    XCTAssertEqual(ConnectionStatus.allCases.map(\.displayName), expected)
  }

  func testRecordingStatusDisplayNamesCoverEveryCase() {
    let expected = [
      "未録画",
      "録画開始中",
      "録画中",
      "録画停止中",
      "録画失敗",
      "録画中断",
    ]

    XCTAssertEqual(RecordingStatus.allCases.map(\.displayName), expected)
  }
}

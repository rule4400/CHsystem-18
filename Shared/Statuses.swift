import Foundation

/// The current camera and transport state for a site.
public enum ConnectionStatus: String, Codable, CaseIterable, Sendable {
  case connecting
  case live
  case reconnecting
  case offline
  case cameraUnavailable
  case thermalLimited
  case thermalPaused

  public var displayName: String {
    switch self {
    case .connecting:
      "接続中"
    case .live:
      "ライブ"
    case .reconnecting:
      "再接続中"
    case .offline:
      "オフライン"
    case .cameraUnavailable:
      "カメラ利用不可"
    case .thermalLimited:
      "温度制限中"
    case .thermalPaused:
      "温度保護で一時停止"
    }
  }
}

/// The state confirmed by the central recording service.
public enum RecordingStatus: String, Codable, CaseIterable, Sendable {
  case idle
  case starting
  case recording
  case stopping
  case failed
  case interrupted

  public var displayName: String {
    switch self {
    case .idle:
      "未録画"
    case .starting:
      "録画開始中"
    case .recording:
      "録画中"
    case .stopping:
      "録画停止中"
    case .failed:
      "録画失敗"
    case .interrupted:
      "録画中断"
    }
  }
}

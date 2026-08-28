import CHShared
import Foundation
import SwiftUI

enum HQSection: String, CaseIterable, Identifiable, Sendable {
  case monitor
  case recordings
  case settings

  var id: Self { self }

  var title: String {
    switch self {
    case .monitor: "監視"
    case .recordings: "録画を検索"
    case .settings: "設定"
    }
  }

  var systemImage: String {
    switch self {
    case .monitor: "rectangle.grid.3x2.fill"
    case .recordings: "play.rectangle.on.rectangle"
    case .settings: "gearshape"
    }
  }
}

enum MonitorConnectionState: Equatable, Sendable {
  case live
  case delayed(seconds: Int)
  case reconnecting(since: Date)
  case offline(since: Date)
  case cameraUnavailable
  case thermalLimited
  case thermalPaused(since: Date)

  var isReceivingFrames: Bool {
    switch self {
    case .live, .delayed, .thermalLimited:
      true
    case .reconnecting, .offline, .cameraUnavailable, .thermalPaused:
      false
    }
  }

  var isOnline: Bool {
    switch self {
    case .live, .delayed, .thermalLimited:
      true
    case .reconnecting, .offline, .cameraUnavailable, .thermalPaused:
      false
    }
  }

  func label(at date: Date) -> String {
    switch self {
    case .live:
      "LIVE"
    case .delayed(let seconds):
      "遅延 \(seconds)秒"
    case .reconnecting(let since):
      "再接続中 \(Self.elapsedLabel(from: since, to: date))"
    case .offline(let since):
      "OFFLINE \(Self.elapsedLabel(from: since, to: date))"
    case .cameraUnavailable:
      "カメラ停止"
    case .thermalLimited:
      "熱保護・画質制限中"
    case .thermalPaused(let since):
      "高温停止 \(Self.elapsedLabel(from: since, to: date))"
    }
  }

  var icon: String {
    switch self {
    case .live: "circle.fill"
    case .delayed: "clock.badge.exclamationmark"
    case .reconnecting: "arrow.trianglehead.2.clockwise.rotate.90"
    case .offline: "wifi.slash"
    case .cameraUnavailable: "video.slash.fill"
    case .thermalLimited: "thermometer.high"
    case .thermalPaused: "exclamationmark.triangle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .live: .green
    case .delayed, .reconnecting, .thermalLimited: .yellow
    case .offline: .gray
    case .cameraUnavailable, .thermalPaused: .red
    }
  }

  private static func elapsedLabel(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start)))
    if seconds >= 3_600 {
      return String(format: "%d:%02d:%02d", seconds / 3_600, (seconds / 60) % 60, seconds % 60)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
}

enum MonitorRecordingState: Equatable, Sendable {
  case idle
  case starting
  case recording(startedAt: Date)
  case stopping
  case failed(reason: String)
  case interrupted

  var isRecording: Bool {
    if case .recording = self { true } else { false }
  }

  func label(at date: Date) -> String {
    switch self {
    case .idle:
      "未録画"
    case .starting:
      "録画開始中…"
    case .recording(let startedAt):
      "録画中 \(Self.elapsedLabel(from: startedAt, to: date))"
    case .stopping:
      "録画停止中…"
    case .failed(let reason):
      "録画失敗：\(reason)"
    case .interrupted:
      "録画途切れあり"
    }
  }

  var icon: String {
    switch self {
    case .idle: "record.circle"
    case .starting, .stopping: "ellipsis.circle"
    case .recording: "record.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .interrupted: "exclamationmark.circle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .recording: .red
    case .failed: .red
    case .interrupted: .orange
    case .starting, .stopping: .yellow
    case .idle: .secondary
    }
  }

  private static func elapsedLabel(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start)))
    return String(format: "%02d:%02d:%02d", seconds / 3_600, (seconds / 60) % 60, seconds % 60)
  }
}

enum QualityCommandState: Equatable, Sendable {
  case idle
  case sending(QualityPreset)
  case applied(QualityPreset, at: Date)
  case queued(QualityPreset)

  var label: String? {
    switch self {
    case .idle:
      nil
    case .sending(let quality):
      "\(quality.monitorDisplayName)を端末へ送信中…"
    case .applied(let quality, let date):
      "\(quality.monitorDisplayName)を適用済み \(date.formattedJSTTime)"
    case .queued(let quality):
      "端末はオフラインです。再接続時に\(quality.monitorDisplayName)を適用します。"
    }
  }
}

struct SitePresentation: Identifiable, Sendable {
  let id: UUID
  let snapshot: SiteSnapshot
  var connectionState: MonitorConnectionState
  var recordingState: MonitorRecordingState
  var desiredQuality: QualityPreset
  var appliedQuality: QualityPreset?
  var measuredQuality: QualityPreset?
  var qualityCommandState: QualityCommandState
  var frozenCaptureDate: Date
  var frameLatency: TimeInterval
  var framesPerSecond: Double
  var bitrateKbps: Int
  var networkLatency: TimeInterval
  var thermalDescription: String
  var backgroundSeed: Int

  var name: String { snapshot.name }

  func captureDate(at now: Date) -> Date {
    connectionState.isReceivingFrames ? now.addingTimeInterval(-frameLatency) : frozenCaptureDate
  }
}

struct GapPresentation: Identifiable, Sendable {
  let id: UUID
  let sharedGap: RecordingGap
  let startedAt: Date
  let endedAt: Date
  let reason: String

  var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
}

struct RecordingPresentation: Identifiable, Sendable {
  let id: UUID
  let item: RecordingItem
  let siteID: UUID
  let siteName: String
  let startedAt: Date
  let endedAt: Date
  let quality: QualityPreset
  let gaps: [GapPresentation]
  let expiresAt: Date
  let fileSizeBytes: Int64
  let backgroundSeed: Int

  private var calculatedCoverage: RecordingCoverage {
    RecordingCalculations.coverage(
      from: startedAt,
      to: endedAt,
      gaps: item.gaps
    )
  }

  var duration: TimeInterval { calculatedCoverage.totalDuration }
  var missingDuration: TimeInterval { calculatedCoverage.gapDuration }
  var coverage: Double { calculatedCoverage.ratio }
}

enum RecordingPolicy: String, CaseIterable, Identifiable, Sendable {
  case manual
  case continuous
  case off

  var id: Self { self }

  var label: String {
    switch self {
    case .manual: "手動録画"
    case .continuous: "常時録画"
    case .off: "録画しない"
    }
  }
}

struct RetentionImpact: Identifiable, Sendable {
  let id = UUID()
  let oldDays: Int
  let newDays: Int
  let affectedCount: Int
  let estimatedBytes: Int64
  let rangeStart: Date
  let rangeEnd: Date
  let deletionStartsAt: Date
}

extension QualityPreset {
  var monitorDisplayName: String {
    switch self {
    case .low: "低（360p）"
    case .standard: "標準（720p）"
    case .high: "高（1080p）"
    @unknown default: "不明"
    }
  }

  var compactName: String {
    switch self {
    case .low: "360p"
    case .standard: "720p"
    case .high: "1080p"
    @unknown default: "—"
    }
  }
}

extension Date {
  var formattedJST: String { Self.jstDateTimeFormatter.string(from: self) }
  var formattedJSTTime: String { Self.jstTimeFormatter.string(from: self) }

  private static let jstDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return formatter
  }()

  private static let jstTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()
}

extension Int64 {
  var formattedStorage: String {
    ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
  }
}

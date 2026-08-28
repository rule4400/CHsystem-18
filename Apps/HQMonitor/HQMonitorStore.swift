import CHShared
import Combine
import Foundation
import SwiftUI

@MainActor
final class HQMonitorStore: ObservableObject {
  @Published var selectedSection: HQSection = .monitor
  @Published var tileCount = 25
  @Published var sites: [SitePresentation]
  @Published var selectedSiteID: UUID?
  @Published var expandedSiteID: UUID?
  @Published var recordings: [RecordingPresentation]
  @Published var selectedRecordingID: UUID?
  @Published var retentionDays = 30
  @Published var draftRetentionDays = 30
  @Published var recordingPolicy: RecordingPolicy = .continuous
  @Published var draftRecordingPolicy: RecordingPolicy = .continuous
  @Published var pendingRetentionImpact: RetentionImpact?
  @Published var settingsMessage: String?

  let tileOptions = [1, 4, 9, 16, 25]
  let storageCapacityBytes: Int64 = 9_000_000_000_000
  let storageUsedBytes: Int64 = 6_200_000_000_000

  private var qualityCommandTasks: [UUID: Task<Void, Never>] = [:]
  private var recordingCommandTasks: [UUID: Task<Void, Never>] = [:]

  init(sites: [SitePresentation], recordings: [RecordingPresentation]) {
    self.sites = sites
    self.recordings = recordings
    selectedRecordingID = recordings.first?.id
  }

  var visibleSites: [SitePresentation] {
    Array(sites.prefix(tileCount))
  }

  var selectedSite: SitePresentation? {
    guard let selectedSiteID else { return nil }
    return sites.first { $0.id == selectedSiteID }
  }

  var expandedSite: SitePresentation? {
    guard let expandedSiteID else { return nil }
    return sites.first { $0.id == expandedSiteID }
  }

  var selectedRecording: RecordingPresentation? {
    guard let selectedRecordingID else { return nil }
    return recordings.first { $0.id == selectedRecordingID }
  }

  var onlineCount: Int { sites.count(where: { $0.connectionState.isOnline }) }
  var recordingCount: Int { sites.count(where: { $0.recordingState.isRecording }) }
  var attentionCount: Int {
    sites.count { site in
      !site.connectionState.isOnline
        || {
          if case .failed = site.recordingState { return true }
          return false
        }()
    }
  }

  var storageFraction: Double {
    min(1, Double(storageUsedBytes) / Double(storageCapacityBytes))
  }

  func select(_ siteID: UUID) {
    selectedSiteID = siteID
  }

  func expand(_ siteID: UUID) {
    selectedSiteID = siteID
    expandedSiteID = siteID
  }

  func closeExpandedSite() {
    expandedSiteID = nil
  }

  func moveSelection(_ direction: MoveCommandDirection, columns: Int) {
    let shown = visibleSites
    guard !shown.isEmpty else { return }
    let currentIndex =
      selectedSiteID.flatMap { id in shown.firstIndex(where: { $0.id == id }) } ?? 0
    let nextIndex: Int
    switch direction {
    case .left:
      nextIndex = max(0, currentIndex - 1)
    case .right:
      nextIndex = min(shown.count - 1, currentIndex + 1)
    case .up:
      nextIndex = max(0, currentIndex - columns)
    case .down:
      nextIndex = min(shown.count - 1, currentIndex + columns)
    @unknown default:
      nextIndex = currentIndex
    }
    selectedSiteID = shown[nextIndex].id
  }

  func requestQuality(_ quality: QualityPreset, for siteID: UUID) {
    qualityCommandTasks[siteID]?.cancel()
    updateSite(siteID) { site in
      site.desiredQuality = quality
      if site.connectionState.isOnline {
        site.qualityCommandState = .sending(quality)
      } else {
        site.qualityCommandState = .queued(quality)
      }
    }

    guard sites.first(where: { $0.id == siteID })?.connectionState.isOnline == true else { return }
    qualityCommandTasks[siteID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(900))
      guard !Task.isCancelled else { return }
      self?.updateSite(siteID) { site in
        site.appliedQuality = quality
        site.measuredQuality = quality
        site.qualityCommandState = .applied(quality, at: .now)
        switch quality {
        case .low:
          site.framesPerSecond = 10
          site.bitrateKbps = 250
        case .standard:
          site.framesPerSecond = 15
          site.bitrateKbps = 800
        case .high:
          site.framesPerSecond = 20
          site.bitrateKbps = 2_000
        @unknown default:
          break
        }
      }
    }
  }

  func startRecording(for siteID: UUID) {
    recordingCommandTasks[siteID]?.cancel()
    updateSite(siteID) { $0.recordingState = .starting }
    recordingCommandTasks[siteID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(850))
      guard !Task.isCancelled else { return }
      self?.updateSite(siteID) { $0.recordingState = .recording(startedAt: .now) }
    }
  }

  func stopRecording(for siteID: UUID) {
    recordingCommandTasks[siteID]?.cancel()
    updateSite(siteID) { $0.recordingState = .stopping }
    recordingCommandTasks[siteID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(750))
      guard !Task.isCancelled else { return }
      self?.updateSite(siteID) { $0.recordingState = .idle }
    }
  }

  func showRecordings(for siteID: UUID) {
    selectedSection = .recordings
    selectedRecordingID = recordings.first(where: { $0.siteID == siteID })?.id
  }

  func prepareRetentionSave() {
    let proposed = min(3_650, max(1, draftRetentionDays))
    draftRetentionDays = proposed
    guard proposed < retentionDays else {
      retentionDays = proposed
      recordingPolicy = draftRecordingPolicy
      settingsMessage = "保存期間を\(proposed)日に変更しました。"
      return
    }

    let now = Date.now
    let ratio = Double(retentionDays - proposed) / Double(max(retentionDays, 1))
    pendingRetentionImpact = RetentionImpact(
      oldDays: retentionDays,
      newDays: proposed,
      affectedCount: max(1, Int(3_842 * ratio)),
      estimatedBytes: Int64(Double(1_200_000_000_000) * ratio),
      rangeStart: Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) ?? now,
      rangeEnd: Calendar.current.date(byAdding: .day, value: -proposed, to: now) ?? now,
      deletionStartsAt: Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now
    )
  }

  func confirmRetentionChange() {
    guard let impact = pendingRetentionImpact else { return }
    retentionDays = impact.newDays
    draftRetentionDays = impact.newDays
    recordingPolicy = draftRecordingPolicy
    pendingRetentionImpact = nil
    settingsMessage = "保存期間を\(impact.newDays)日に変更し、削除を予約しました。"
  }

  func cancelRetentionChange() {
    draftRetentionDays = retentionDays
    pendingRetentionImpact = nil
  }

  private func updateSite(_ id: UUID, mutation: (inout SitePresentation) -> Void) {
    guard let index = sites.firstIndex(where: { $0.id == id }) else { return }
    mutation(&sites[index])
  }
}

extension HQMonitorStore {
  static func preview(now: Date = .now) -> HQMonitorStore {
    let calendar = Calendar(identifier: .gregorian)
    let names = [
      "国道18号 上田バイパス工事", "中央橋耐震補強工事", "北地区雨水幹線築造工事", "新駅東口造成工事", "港湾第3埠頭改良工事",
      "県道42号法面補修工事", "南部給水管更新工事", "市役所新庁舎建設工事", "河川護岸災害復旧工事", "東トンネル照明更新工事",
      "第一小学校校舎増築工事", "臨海物流センター新築工事", "西部処理場設備更新工事", "山間部通信塔設置工事", "駅前広場再整備工事",
      "中央自動車道床版補修工事", "海岸堤防嵩上げ工事", "北口歩道橋撤去工事", "工業団地造成二期工事", "市道105号舗装改良工事",
      "地下共同溝築造工事", "防災公園整備工事", "文化会館大規模改修工事", "農業用水路更新工事", "消防本部移転新築工事",
    ]

    let siteIDs = names.indices.map { _ in UUID() }
    let sites = names.enumerated().map { index, name -> SitePresentation in
      let connection: MonitorConnectionState
      let sharedConnection: ConnectionStatus
      switch index {
      case 3:
        connection = .delayed(seconds: 7)
        sharedConnection = .live
      case 7:
        connection = .offline(since: now.addingTimeInterval(-208))
        sharedConnection = .offline
      case 12:
        connection = .reconnecting(since: now.addingTimeInterval(-42))
        sharedConnection = .reconnecting
      case 17:
        connection = .thermalLimited
        sharedConnection = .thermalLimited
      case 21:
        connection = .cameraUnavailable
        sharedConnection = .cameraUnavailable
      case 23:
        connection = .thermalPaused(since: now.addingTimeInterval(-95))
        sharedConnection = .thermalPaused
      default:
        connection = .live
        sharedConnection = .live
      }

      let recording: MonitorRecordingState
      let sharedRecording: RecordingStatus
      if index == 9 {
        recording = .failed(reason: "保存先に接続できません")
        sharedRecording = .failed
      } else if index == 14 {
        recording = .interrupted
        sharedRecording = .interrupted
      } else if index.isMultiple(of: 6) {
        recording = .idle
        sharedRecording = .idle
      } else {
        recording = .recording(startedAt: now.addingTimeInterval(TimeInterval(-1_500 - index * 83)))
        sharedRecording = .recording
      }

      let desiredQuality: QualityPreset = index.isMultiple(of: 8) ? .high : .standard
      let appliedQuality: QualityPreset = index == 17 ? .low : desiredQuality
      let captureDate =
        connection.isReceivingFrames
        ? now.addingTimeInterval(-0.6) : now.addingTimeInterval(TimeInterval(-30 - index * 9))
      let snapshot = SiteSnapshot(
        id: siteIDs[index],
        name: name,
        connectionStatus: sharedConnection,
        recordingStatus: sharedRecording,
        desiredQuality: desiredQuality,
        appliedQuality: appliedQuality,
        measuredQuality: appliedQuality.metrics,
        captureDate: captureDate,
        lastReceivedAt: captureDate,
        disconnectedAt: connection.isOnline ? nil : captureDate,
        qualityLimitReason: index == 17 ? "端末温度が高いため" : nil
      )

      return SitePresentation(
        id: siteIDs[index],
        snapshot: snapshot,
        connectionState: connection,
        recordingState: recording,
        desiredQuality: desiredQuality,
        appliedQuality: appliedQuality,
        measuredQuality: appliedQuality,
        qualityCommandState: .idle,
        frozenCaptureDate: captureDate,
        frameLatency: index == 3 ? 7 : 0.4 + Double(index % 4) * 0.12,
        framesPerSecond: appliedQuality == .low ? 10 : 15,
        bitrateKbps: appliedQuality == .low ? 248 : 760 + index * 7,
        networkLatency: index == 3 ? 7 : 0.5 + Double(index % 5) * 0.11,
        thermalDescription: index == 17 ? "高温・画質を制限中" : "正常",
        backgroundSeed: index
      )
    }

    var recordings: [RecordingPresentation] = []
    for index in 0..<18 {
      let siteIndex = index % names.count
      let startedAt = calendar.date(byAdding: .hour, value: -(index + 1) * 3, to: now) ?? now
      let endedAt = calendar.date(byAdding: .hour, value: 1, to: startedAt) ?? startedAt
      let gapValues: [(Date, Date)]
      if index.isMultiple(of: 3) {
        let gapStart = startedAt.addingTimeInterval(TimeInterval(900 + index * 17))
        gapValues = [(gapStart, gapStart.addingTimeInterval(TimeInterval(17 + index * 3)))]
      } else {
        gapValues = []
      }
      let sharedGaps = gapValues.map { RecordingGap(startedAt: $0.0, endedAt: $0.1) }
      let gapPresentations = zip(sharedGaps, gapValues).map { sharedGap, values in
        GapPresentation(
          id: UUID(),
          sharedGap: sharedGap,
          startedAt: values.0,
          endedAt: values.1,
          reason: "通信断"
        )
      }
      let expiresAt = calendar.date(byAdding: .day, value: 30, to: endedAt) ?? endedAt
      let itemID = UUID()
      let item = RecordingItem(
        id: itemID,
        siteID: siteIDs[siteIndex],
        siteName: names[siteIndex],
        startedAt: startedAt,
        endedAt: endedAt,
        gaps: sharedGaps,
        expiresAt: expiresAt
      )
      recordings.append(
        RecordingPresentation(
          id: itemID,
          item: item,
          siteID: siteIDs[siteIndex],
          siteName: names[siteIndex],
          startedAt: startedAt,
          endedAt: endedAt,
          quality: index.isMultiple(of: 5) ? .high : .standard,
          gaps: gapPresentations,
          expiresAt: expiresAt,
          fileSizeBytes: Int64(310_000_000 + index * 12_000_000),
          backgroundSeed: siteIndex
        )
      )
    }

    return HQMonitorStore(sites: sites, recordings: recordings)
  }
}

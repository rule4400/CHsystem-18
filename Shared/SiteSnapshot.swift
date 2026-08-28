import Foundation

/// The latest immutable view of a monitored construction site.
///
/// All dates are absolute instants. Presentation code is responsible for
/// formatting them in JST or another operator-selected time zone.
public struct SiteSnapshot: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let name: String
  public let connectionStatus: ConnectionStatus
  public let recordingStatus: RecordingStatus
  public let desiredQuality: QualityPreset
  public let appliedQuality: QualityPreset?
  public let measuredQuality: VideoMetrics?
  public let captureDate: Date?
  public let lastReceivedAt: Date?
  public let disconnectedAt: Date?
  public let qualityLimitReason: String?

  public init(
    id: UUID,
    name: String,
    connectionStatus: ConnectionStatus,
    recordingStatus: RecordingStatus,
    desiredQuality: QualityPreset,
    appliedQuality: QualityPreset? = nil,
    measuredQuality: VideoMetrics? = nil,
    captureDate: Date? = nil,
    lastReceivedAt: Date? = nil,
    disconnectedAt: Date? = nil,
    qualityLimitReason: String? = nil
  ) {
    self.id = id
    self.name = name
    self.connectionStatus = connectionStatus
    self.recordingStatus = recordingStatus
    self.desiredQuality = desiredQuality
    self.appliedQuality = appliedQuality
    self.measuredQuality = measuredQuality
    self.captureDate = captureDate
    self.lastReceivedAt = lastReceivedAt
    self.disconnectedAt = disconnectedAt
    self.qualityLimitReason = qualityLimitReason
  }
}

import Foundation

/// A concrete set of video measurements.
///
/// For a ``QualityPreset`` the bitrate is the requested upper limit. For a
/// measured stream it is the latest observed bitrate.
public struct VideoMetrics: Codable, Equatable, Hashable, Sendable {
  public let width: Int
  public let height: Int
  public let framesPerSecond: Double
  public let bitrateKbps: Int

  public init(
    width: Int,
    height: Int,
    framesPerSecond: Double,
    bitrateKbps: Int
  ) {
    self.width = width
    self.height = height
    self.framesPerSecond = framesPerSecond
    self.bitrateKbps = bitrateKbps
  }

  /// A compact resolution label suitable for the monitoring UI.
  public var resolutionDescription: String {
    "\(width)×\(height)"
  }
}

/// The requested upper bound for capture and recording quality.
public enum QualityPreset: String, Identifiable, Codable, CaseIterable, Sendable {
  case low
  case standard
  case high

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .low:
      "低画質"
    case .standard:
      "標準画質"
    case .high:
      "高画質"
    }
  }

  public var metrics: VideoMetrics {
    switch self {
    case .low:
      VideoMetrics(
        width: 640,
        height: 360,
        framesPerSecond: 10,
        bitrateKbps: 250
      )
    case .standard:
      VideoMetrics(
        width: 1_280,
        height: 720,
        framesPerSecond: 15,
        bitrateKbps: 800
      )
    case .high:
      VideoMetrics(
        width: 1_920,
        height: 1_080,
        framesPerSecond: 20,
        bitrateKbps: 2_000
      )
    }
  }
}

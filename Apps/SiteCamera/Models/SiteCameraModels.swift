import CHShared
import Foundation

enum SetupPhase: Equatable {
  case constructionName
  case cameraPermission
  case monitoring
}

enum CameraAuthorizationState: Equatable, Sendable {
  case notDetermined
  case authorized
  case denied
  case restricted
}

enum CameraCaptureState: Equatable, Sendable {
  case idle
  case awaitingPermission
  case configuring
  case running
  case permissionDenied
  case unavailable(message: String)
}

enum TransportThermalConstraint: Equatable, Sendable {
  case normal
  case limited
  case paused
}

struct VideoTransportSnapshot {
  var status: ConnectionStatus
  var requestedQuality: QualityPreset
  var effectiveQuality: QualityPreset
  var lastTransmissionAt: Date?

  static let initial = VideoTransportSnapshot(
    status: .offline,
    requestedQuality: .standard,
    effectiveQuality: .standard,
    lastTransmissionAt: nil
  )
}

extension QualityPreset {
  var localizedTitle: String {
    displayName
  }

  var nominalVideoDescription: String {
    "\(metrics.resolutionDescription) / \(Int(metrics.framesPerSecond))fps"
  }

  var oneStepLower: QualityPreset {
    switch self {
    case .high:
      .standard
    case .standard, .low:
      .low
    }
  }
}

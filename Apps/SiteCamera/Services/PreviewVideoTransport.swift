import CHShared
import Foundation

/// Development transport used until the WebRTC implementation is integrated.
/// It models connection delays, reconnection, timestamps, remote quality commands,
/// and thermal throttling without pretending to upload camera frames.
@MainActor
final class PreviewVideoTransport: VideoTransport {
  private(set) var snapshot: VideoTransportSnapshot = .initial {
    didSet { onSnapshotChange?(snapshot) }
  }

  var onSnapshotChange: ((VideoTransportSnapshot) -> Void)?

  private var connectionTask: Task<Void, Never>?
  private var heartbeatTask: Task<Void, Never>?
  private var qualityTask: Task<Void, Never>?
  private var hasConnectedBefore = false
  private var wantsConnection = false
  private var isNetworkAvailable = true
  private var thermalConstraint: TransportThermalConstraint = .normal

  deinit {
    connectionTask?.cancel()
    heartbeatTask?.cancel()
    qualityTask?.cancel()
  }

  func connect() {
    wantsConnection = true
    connectionTask?.cancel()

    guard thermalConstraint != .paused else {
      stopHeartbeat()
      snapshot.status = .thermalPaused
      return
    }

    guard isNetworkAvailable else {
      stopHeartbeat()
      snapshot.status = .offline
      return
    }

    snapshot.status = hasConnectedBefore ? .reconnecting : .connecting

    connectionTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(850))
      guard !Task.isCancelled, let self, self.wantsConnection else { return }

      self.hasConnectedBefore = true
      self.snapshot.status = self.thermalConstraint == .limited ? .thermalLimited : .live
      self.snapshot.effectiveQuality = self.resolvedQuality
      self.startHeartbeat()
    }
  }

  func disconnect() {
    wantsConnection = false
    connectionTask?.cancel()
    connectionTask = nil
    stopHeartbeat()
    snapshot.status = .offline
  }

  func applyRemoteQuality(_ quality: QualityPreset) {
    snapshot.requestedQuality = quality
    qualityTask?.cancel()

    qualityTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(450))
      guard !Task.isCancelled, let self else { return }
      self.snapshot.effectiveQuality = self.resolvedQuality
    }
  }

  func setThermalConstraint(_ constraint: TransportThermalConstraint) {
    thermalConstraint = constraint

    switch constraint {
    case .normal:
      snapshot.effectiveQuality = snapshot.requestedQuality
      if wantsConnection, isNetworkAvailable {
        connect()
      }

    case .limited:
      snapshot.effectiveQuality = resolvedQuality
      if wantsConnection, isNetworkAvailable {
        snapshot.status = .thermalLimited
        startHeartbeat()
      }

    case .paused:
      connectionTask?.cancel()
      stopHeartbeat()
      snapshot.status = .thermalPaused
    }
  }

  /// Useful for UI tests and the development diagnostics screen.
  func simulateConnectionLoss() {
    guard wantsConnection else { return }
    isNetworkAvailable = false
    connectionTask?.cancel()
    stopHeartbeat()
    snapshot.status = .offline
  }

  /// Useful for UI tests and the development diagnostics screen.
  func simulateNetworkRecovery() {
    guard wantsConnection else { return }
    isNetworkAvailable = true
    connect()
  }

  private var resolvedQuality: QualityPreset {
    thermalConstraint == .limited
      ? snapshot.requestedQuality.oneStepLower
      : snapshot.requestedQuality
  }

  private func startHeartbeat() {
    heartbeatTask?.cancel()
    snapshot.lastTransmissionAt = Date()

    heartbeatTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, let self, self.wantsConnection else { return }

        switch self.snapshot.status {
        case .live, .thermalLimited:
          self.snapshot.lastTransmissionAt = Date()
        default:
          return
        }
      }
    }
  }

  private func stopHeartbeat() {
    heartbeatTask?.cancel()
    heartbeatTask = nil
  }
}

import CHShared
import Foundation

/// UI and camera lifecycle depend on this boundary rather than a WebRTC SDK.
/// A production transport can report SDK callbacks through `onSnapshotChange`.
@MainActor
protocol VideoTransport: AnyObject {
  var snapshot: VideoTransportSnapshot { get }
  var onSnapshotChange: ((VideoTransportSnapshot) -> Void)? { get set }

  func connect()
  func disconnect()
  func applyRemoteQuality(_ quality: QualityPreset)
  func setThermalConstraint(_ constraint: TransportThermalConstraint)
}

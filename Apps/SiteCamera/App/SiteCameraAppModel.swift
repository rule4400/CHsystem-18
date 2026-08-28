import AVFoundation
import CHShared
import Foundation
import SwiftUI
import UIKit

@MainActor
final class SiteCameraAppModel: ObservableObject {
  @Published private(set) var setupPhase: SetupPhase
  @Published private(set) var constructionName: String
  @Published private(set) var cameraState: CameraCaptureState
  @Published private(set) var transportSnapshot: VideoTransportSnapshot
  @Published private(set) var thermalConstraint: TransportThermalConstraint = .normal

  let camera: CameraCaptureService

  private let defaults: UserDefaults
  private let transport: any VideoTransport
  private var hasPrepared = false
  private var thermalObservationTask: Task<Void, Never>?

  private static let constructionNameDefaultsKey = "siteCamera.constructionName"

  init(
    defaults: UserDefaults = .standard,
    camera: CameraCaptureService = CameraCaptureService(),
    transport: (any VideoTransport)? = nil
  ) {
    self.defaults = defaults
    self.camera = camera

    let savedName = defaults.string(forKey: Self.constructionNameDefaultsKey) ?? ""
    let validatedName = (try? SiteNameValidator.validate(savedName)) ?? ""
    constructionName = validatedName
    setupPhase = validatedName.isEmpty ? .constructionName : .cameraPermission
    cameraState = camera.captureState

    let selectedTransport = transport ?? PreviewVideoTransport()
    self.transport = selectedTransport
    transportSnapshot = selectedTransport.snapshot

    camera.onStateChange = { [weak self] state in
      self?.handleCameraStateChange(state)
    }
    selectedTransport.onSnapshotChange = { [weak self] snapshot in
      self?.transportSnapshot = snapshot
    }

    thermalObservationTask = Task { @MainActor [weak self] in
      self?.applyThermalState(ProcessInfo.processInfo.thermalState)

      for await _ in NotificationCenter.default.notifications(
        named: ProcessInfo.thermalStateDidChangeNotification
      ) {
        guard !Task.isCancelled, let self else { return }
        self.applyThermalState(ProcessInfo.processInfo.thermalState)
      }
    }
  }

  deinit {
    thermalObservationTask?.cancel()
  }

  var effectiveConnectionStatus: ConnectionStatus {
    switch cameraState {
    case .permissionDenied, .unavailable:
      return .cameraUnavailable
    case .awaitingPermission, .configuring:
      return .connecting
    case .idle, .running:
      break
    }

    if thermalConstraint == .paused {
      return .thermalPaused
    }

    switch transportSnapshot.status {
    case .offline, .reconnecting, .connecting, .cameraUnavailable, .thermalPaused:
      return transportSnapshot.status
    case .live, .thermalLimited:
      return thermalConstraint == .limited ? .thermalLimited : transportSnapshot.status
    }
  }

  var isCameraPermissionDenied: Bool {
    switch camera.authorizationState {
    case .denied, .restricted:
      true
    case .notDetermined, .authorized:
      false
    }
  }

  var cameraIssueMessage: String? {
    switch cameraState {
    case .permissionDenied:
      return "配信を開始するには、カメラへのアクセスを許可してください。"
    case .unavailable(let message):
      return message
    case .idle, .awaitingPermission, .configuring, .running:
      return nil
    }
  }

  func prepareIfNeeded() async {
    guard !hasPrepared else { return }
    hasPrepared = true

    guard !constructionName.isEmpty else {
      setupPhase = .constructionName
      return
    }

    camera.refreshAuthorizationState()
    switch camera.authorizationState {
    case .notDetermined:
      setupPhase = .cameraPermission
    case .authorized:
      beginMonitoring()
    case .denied, .restricted:
      setupPhase = .monitoring
      setIdleTimerDisabled(true)
      camera.start()
    }
  }

  @discardableResult
  func saveInitialConstructionName(_ value: String) -> String? {
    do {
      let validatedName = try SiteNameValidator.validate(value)
      persistValidatedConstructionName(validatedName)
      setupPhase = .cameraPermission
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func requestCameraPermissionAndBegin() async {
    let granted = await camera.requestAuthorization()
    setupPhase = .monitoring
    setIdleTimerDisabled(true)

    if granted, thermalConstraint != .paused {
      camera.start()
    }
  }

  @discardableResult
  func updateConstructionName(_ value: String) -> String? {
    do {
      let validatedName = try SiteNameValidator.validate(value)
      persistValidatedConstructionName(validatedName)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func handleScenePhase(_ scenePhase: ScenePhase) {
    switch scenePhase {
    case .active:
      camera.refreshAuthorizationState()
      guard setupPhase == .monitoring else { return }
      setIdleTimerDisabled(true)

      if camera.authorizationState == .authorized,
        thermalConstraint != .paused
      {
        camera.start()
      }

    case .background:
      guard setupPhase == .monitoring else { return }
      setIdleTimerDisabled(false)
      transport.disconnect()
      camera.stop()

    case .inactive:
      break
    @unknown default:
      break
    }
  }

  func openSystemSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(settingsURL)
  }

  func simulateRemoteQualityCommand(_ quality: QualityPreset) {
    transport.applyRemoteQuality(quality)
  }

  private func beginMonitoring() {
    setupPhase = .monitoring
    setIdleTimerDisabled(true)
    if thermalConstraint != .paused {
      camera.start()
    }
  }

  private func persistValidatedConstructionName(_ validatedName: String) {
    constructionName = validatedName
    defaults.set(validatedName, forKey: Self.constructionNameDefaultsKey)
  }

  private func setIdleTimerDisabled(_ isDisabled: Bool) {
    UIApplication.shared.isIdleTimerDisabled = isDisabled
  }

  private func handleCameraStateChange(_ state: CameraCaptureState) {
    cameraState = state

    switch state {
    case .running:
      if thermalConstraint != .paused {
        transport.connect()
      }
    case .permissionDenied, .unavailable:
      transport.disconnect()
    case .idle, .awaitingPermission, .configuring:
      break
    }
  }

  private func applyThermalState(_ state: ProcessInfo.ThermalState) {
    switch state {
    case .nominal, .fair:
      thermalConstraint = .normal
      transport.setThermalConstraint(.normal)
      if setupPhase == .monitoring,
        camera.authorizationState == .authorized
      {
        camera.start()
      }

    case .serious:
      thermalConstraint = .limited
      transport.setThermalConstraint(.limited)

    case .critical:
      thermalConstraint = .paused
      transport.setThermalConstraint(.paused)
      camera.stop()

    @unknown default:
      thermalConstraint = .limited
      transport.setThermalConstraint(.limited)
    }
  }
}

@preconcurrency import AVFoundation
import Combine
import Foundation

enum CameraCaptureError: Error, LocalizedError, Sendable {
  case noVideoDevice
  case cannotCreateInput(message: String)
  case cannotAddInput
  case failedToStart

  var errorDescription: String? {
    switch self {
    case .noVideoDevice:
      "利用できるカメラが見つかりません。"
    case .cannotCreateInput(let message):
      "カメラを初期化できません。\(message)"
    case .cannotAddInput:
      "カメラセッションにカメラを追加できません。"
    case .failedToStart:
      "カメラの起動を確認できませんでした。"
    }
  }
}

/// Owns the authorization and lifecycle visible to SwiftUI. AVFoundation work is
/// delegated to a serial worker so `startRunning()` never blocks the main actor.
@MainActor
final class CameraCaptureService: ObservableObject {
  @Published private(set) var authorizationState: CameraAuthorizationState
  @Published private(set) var captureState: CameraCaptureState = .idle

  let captureSession: AVCaptureSession

  var onStateChange: ((CameraCaptureState) -> Void)?

  private let worker: CameraSessionWorker
  private var lifecycleGeneration: UInt = 0
  private var isSuspendedByOwner = false
  private var sessionNotificationTasks: [Task<Void, Never>] = []

  init() {
    let worker = CameraSessionWorker()
    self.worker = worker
    captureSession = worker.session
    authorizationState = Self.currentAuthorizationState
    observeSessionNotifications()
  }

  deinit {
    for task in sessionNotificationTasks {
      task.cancel()
    }
  }

  func refreshAuthorizationState() {
    authorizationState = Self.currentAuthorizationState

    switch authorizationState {
    case .authorized:
      if captureState == .permissionDenied {
        setCaptureState(.idle)
      }
    case .denied, .restricted:
      setCaptureState(.permissionDenied)
    case .notDetermined:
      break
    }
  }

  func requestAuthorization() async -> Bool {
    refreshAuthorizationState()

    switch authorizationState {
    case .authorized:
      return true
    case .denied, .restricted:
      setCaptureState(.permissionDenied)
      return false
    case .notDetermined:
      setCaptureState(.awaitingPermission)
    }

    let granted = await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .video) { granted in
        continuation.resume(returning: granted)
      }
    }

    refreshAuthorizationState()
    if !granted {
      setCaptureState(.permissionDenied)
    }
    return granted
  }

  func start() {
    refreshAuthorizationState()
    guard authorizationState == .authorized else {
      setCaptureState(.permissionDenied)
      return
    }

    guard captureState != .running, captureState != .configuring else { return }
    isSuspendedByOwner = false
    lifecycleGeneration &+= 1
    let requestedGeneration = lifecycleGeneration
    setCaptureState(.configuring)

    worker.start { [weak self] result in
      Task { @MainActor [weak self] in
        guard
          let self,
          self.lifecycleGeneration == requestedGeneration
        else { return }
        switch result {
        case .success:
          self.setCaptureState(.running)
        case .failure(let error):
          self.setCaptureState(
            .unavailable(message: error.localizedDescription)
          )
        }
      }
    }
  }

  func stop() {
    isSuspendedByOwner = true
    lifecycleGeneration &+= 1
    worker.stop()
    if authorizationState == .authorized {
      setCaptureState(.idle)
    }
  }

  private func setCaptureState(_ state: CameraCaptureState) {
    captureState = state
    onStateChange?(state)
  }

  private func observeSessionNotifications() {
    let session = captureSession

    sessionNotificationTasks = [
      Task { @MainActor [weak self] in
        for await _ in NotificationCenter.default.notifications(
          named: AVCaptureSession.wasInterruptedNotification,
          object: session
        ) {
          guard !Task.isCancelled, let self else { return }
          self.lifecycleGeneration &+= 1
          self.setCaptureState(
            .unavailable(
              message: "カメラがシステムにより一時中断されました。自動で再開します。"
            )
          )
        }
      },
      Task { @MainActor [weak self] in
        for await _ in NotificationCenter.default.notifications(
          named: AVCaptureSession.interruptionEndedNotification,
          object: session
        ) {
          guard !Task.isCancelled, let self else { return }
          if !self.isSuspendedByOwner {
            self.setCaptureState(.idle)
            self.start()
          }
        }
      },
      Task { @MainActor [weak self] in
        for await notification in NotificationCenter.default.notifications(
          named: AVCaptureSession.runtimeErrorNotification,
          object: session
        ) {
          guard !Task.isCancelled, let self else { return }
          self.lifecycleGeneration &+= 1

          let runtimeError =
            notification.userInfo?[AVCaptureSessionErrorKey]
            as? NSError
          let message =
            runtimeError?.localizedDescription
            ?? "カメラの実行中エラーが発生しました。"
          self.setCaptureState(.unavailable(message: message))

          guard !self.isSuspendedByOwner else { continue }
          try? await Task.sleep(for: .seconds(1))
          guard !Task.isCancelled, !self.isSuspendedByOwner else { continue }
          self.setCaptureState(.idle)
          self.start()
        }
      },
    ]
  }

  private static var currentAuthorizationState: CameraAuthorizationState {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      .notDetermined
    case .authorized:
      .authorized
    case .denied:
      .denied
    case .restricted:
      .restricted
    @unknown default:
      .restricted
    }
  }
}

/// All AVFoundation objects remain behind this serial, unchecked-Sendable owner.
/// Synchronization is provided by `sessionQueue`; callers never mutate the session.
private final class CameraSessionWorker: @unchecked Sendable {
  let session = AVCaptureSession()

  private let sessionQueue = DispatchQueue(
    label: "jp.chsystem.site-camera.capture-session",
    qos: .userInitiated
  )
  private var isConfigured = false

  func start(
    completion: @escaping @Sendable (Result<Void, CameraCaptureError>) -> Void
  ) {
    sessionQueue.async { [self] in
      do {
        try configureIfNeeded()
        if !session.isRunning {
          session.startRunning()
        }

        guard session.isRunning else {
          completion(.failure(.failedToStart))
          return
        }
        completion(.success(()))
      } catch let error as CameraCaptureError {
        completion(.failure(error))
      } catch {
        completion(
          .failure(.cannotCreateInput(message: error.localizedDescription))
        )
      }
    }
  }

  func stop() {
    sessionQueue.async { [self] in
      if session.isRunning {
        session.stopRunning()
      }
    }
  }

  private func configureIfNeeded() throws {
    guard !isConfigured else { return }

    session.beginConfiguration()
    defer { session.commitConfiguration() }

    if session.canSetSessionPreset(.hd1280x720) {
      session.sessionPreset = .hd1280x720
    }

    guard
      let device = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .back
      ) ?? AVCaptureDevice.default(for: .video)
    else {
      throw CameraCaptureError.noVideoDevice
    }

    do {
      try configure(device)
      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        throw CameraCaptureError.cannotAddInput
      }
      session.addInput(input)
    } catch let error as CameraCaptureError {
      throw error
    } catch {
      throw CameraCaptureError.cannotCreateInput(
        message: error.localizedDescription
      )
    }

    isConfigured = true
  }

  private func configure(_ device: AVCaptureDevice) throws {
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    if device.isFocusModeSupported(.continuousAutoFocus) {
      device.focusMode = .continuousAutoFocus
    }
    if device.isExposureModeSupported(.continuousAutoExposure) {
      device.exposureMode = .continuousAutoExposure
    }
    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
      device.whiteBalanceMode = .continuousAutoWhiteBalance
    }
  }
}

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> CameraPreviewView {
    let view = CameraPreviewView()
    view.previewLayer.session = session
    view.previewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ uiView: CameraPreviewView, context: Context) {
    if uiView.previewLayer.session !== session {
      uiView.previewLayer.session = session
    }
    uiView.updateVideoRotation()
  }
}

final class CameraPreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
      preconditionFailure("CameraPreviewView requires AVCaptureVideoPreviewLayer")
    }
    return previewLayer
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    updateVideoRotation()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateVideoRotation()
  }

  func updateVideoRotation() {
    guard
      let connection = previewLayer.connection,
      let orientation = window?.windowScene?.interfaceOrientation
    else { return }

    let angle: CGFloat =
      switch orientation {
      case .portrait:
        90
      case .portraitUpsideDown:
        270
      case .landscapeLeft:
        180
      case .landscapeRight:
        0
      default:
        90
      }

    if connection.isVideoRotationAngleSupported(angle) {
      connection.videoRotationAngle = angle
    }
  }
}

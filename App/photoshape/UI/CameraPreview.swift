import AVFoundation
import SwiftUI

/// Live camera image (or the simulator's still scene). The full 3:4 sensor frame fills the view;
/// the 4:5 frame is drawn on top by `FrameMask`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?
    let stillImage: CGImage?
    /// View point and the matching device point (0–1), for tap to focus.
    let onTap: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if let stillImage {
            view.layer.contents = stillImage
            view.layer.contentsGravity = .resizeAspectFill
        }
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped)))
        view.accessibilityIdentifier = "preview"
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: (CGPoint, CGPoint) -> Void
        init(onTap: @escaping (CGPoint, CGPoint) -> Void) { self.onTap = onTap }

        @MainActor @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? PreviewView else { return }
            let point = recognizer.location(in: view)
            let device = view.previewLayer.session != nil
                ? view.previewLayer.captureDevicePointConverted(fromLayerPoint: point)
                : CGPoint(x: point.x / max(view.bounds.width, 1), y: point.y / max(view.bounds.height, 1))
            onTap(point, device)
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

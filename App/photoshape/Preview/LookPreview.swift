import CoreImage
import LookKit
import MetalKit
import SwiftUI

/// Live camera image with the selected look applied (spec 03 Hikâye 1, FR-002). Uses the same `LookRenderer`
/// as the saved photo, at screen size. The full 3:4 frame fills the view; `FrameMask` marks the 4:5 crop.
struct LookPreview: UIViewRepresentable {
    let source: () -> CIImage?
    let look: LookRecipe
    let strength: Double
    let renderer: LookRenderer
    /// View point, for tap to focus.
    let onTap: (CGPoint, CGSize) -> Void
    /// Press and hold: compare without the app's adjustments (spec 02 FR-011).
    var onHold: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(renderer: renderer) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 30
        view.autoResizeDrawable = true
        view.backgroundColor = .black
        view.delegate = context.coordinator
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.held))
        hold.minimumPressDuration = 0.3
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        tap.require(toFail: hold)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        view.accessibilityIdentifier = "preview"
        view.isAccessibilityElement = true
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(source: source, look: look, strength: strength, onTap: onTap)
        context.coordinator.onHold = onHold
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        private let queue: MTLCommandQueue?
        private let context: CIContext?
        private let renderer: LookRenderer
        private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        private var source: () -> CIImage? = { nil }
        private var look = LookRecipe.natural
        private var strength = 0.0
        private var onTap: (CGPoint, CGSize) -> Void = { _, _ in }
        var onHold: (Bool) -> Void = { _ in }

        @MainActor @objc func held(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began: onHold(true)
            case .ended, .cancelled, .failed: onHold(false)
            default: break
            }
        }

        init(renderer: LookRenderer) {
            self.renderer = renderer
            queue = device?.makeCommandQueue()
            context = device.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false]) }
        }

        func update(source: @escaping () -> CIImage?, look: LookRecipe, strength: Double, onTap: @escaping (CGPoint, CGSize) -> Void) {
            self.source = source; self.look = look; self.strength = strength; self.onTap = onTap
        }

        @MainActor @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            onTap(recognizer.location(in: view), view.bounds.size)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let context, let queue, let image = source(), let drawable = view.currentDrawable,
                  let buffer = queue.makeCommandBuffer() else { return }
            let size = view.drawableSize
            guard size.width > 0, size.height > 0, image.extent.width > 0 else { return }

            // Fill the view, centered (preview and sensor are both 3:4), then apply the look at screen size.
            let scale = max(size.width / image.extent.width, size.height / image.extent.height)
            let scaled = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale)))
            let dx = (scaled.extent.width - size.width) / 2, dy = (scaled.extent.height - size.height) / 2
            let framed = scaled.transformed(by: CGAffineTransform(translationX: -dx, y: -dy))
                .cropped(to: CGRect(origin: .zero, size: size))
            let output = renderer.render(framed, recipe: look, strength: strength)

            let destination = CIRenderDestination(width: Int(size.width), height: Int(size.height),
                                                  pixelFormat: view.colorPixelFormat, commandBuffer: buffer) { drawable.texture }
            destination.colorSpace = sRGB
            _ = try? context.startTask(toRender: output, to: destination)
            buffer.present(drawable)
            buffer.commit()
        }
    }
}

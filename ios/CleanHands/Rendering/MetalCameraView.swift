import MetalKit
import SwiftUI

/// The live camera view, drawn by `Renderer` at the display rate.
struct MetalCameraView: UIViewRepresentable {
    let renderer: Renderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.isOpaque = true
        view.backgroundColor = .black
        view.delegate = renderer
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        view.delegate = renderer
    }
}

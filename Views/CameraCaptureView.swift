import SwiftUI
import UIKit
import AVFoundation
import ARKit
import RealityKit

struct CameraCaptureView: View {
    enum Mode: String, Identifiable {
        case ar
        case plain

        var id: String { rawValue }
        var title: String { self == .ar ? "AR" : "通常" }
    }

    let initialMode: Mode
    let onCancel: () -> Void
    let onCapture: (UIImage) -> Void

    @State private var mode: Mode
    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    init(initialMode: Mode, onCancel: @escaping () -> Void, onCapture: @escaping (UIImage) -> Void) {
        self.initialMode = initialMode
        self.onCancel = onCancel
        self.onCapture = onCapture
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                captureSurface
                    .ignoresSafeArea()

                Image("purpor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(geo.size.width * 0.45, 220))
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)

                VStack {
                    HStack {
                        Button("閉じる") { onCancel() }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.5), in: Capsule())

                        Spacer()

                        Picker("撮影", selection: $mode) {
                            ForEach([Mode.ar, .plain]) { captureMode in
                                Text(captureMode.title).tag(captureMode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                    .foregroundStyle(.white)
                    .padding()

                    Spacer()

                    Button {
                        captureSnapshot(size: geo.size)
                    } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.28)).frame(width: 78, height: 78)
                            Circle().fill(Color.white).frame(width: 62, height: 62)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(.black)
        }
    }

    @ViewBuilder
    private var captureSurface: some View {
        if mode == .ar {
            ARCameraBackgroundView()
        } else {
            CameraPreviewView()
        }
    }

    private var characterGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    characterOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = characterOffset
                },
            MagnificationGesture()
                .onChanged { value in
                    characterScale = max(0.4, min(2.8, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = characterScale
                }
        )
    }

    private func captureSnapshot(size: CGSize) {
        let renderer = ImageRenderer(content:
            ZStack {
                captureSurface
                    .frame(width: size.width, height: size.height)
                Image("purpor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(size.width * 0.45, 220))
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return }
        onCapture(image)
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.startRunning()
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.stopRunning()
    }

    final class PreviewUIView: UIView {
        private let session = AVCaptureSession()
        private let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupSession()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupSession()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }

        private func setupSession() {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return }

            session.beginConfiguration()
            session.sessionPreset = .photo
            session.addInput(input)
            session.commitConfiguration()
        }

        func startRunning() {
            DispatchQueue.global(qos: .userInitiated).async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }

        func stopRunning() {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
            }
        }
    }
}

private struct ARCameraBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        view.automaticallyConfigureSession = false
        view.session.run(config)
        view.renderOptions.insert(.disableMotionBlur)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}

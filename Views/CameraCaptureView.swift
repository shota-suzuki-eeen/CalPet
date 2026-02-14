import SwiftUI
import UIKit
import AVFoundation
import ARKit
import RealityKit

struct CameraCaptureView: View {

    // ✅ completion に UIImage? を返すだけの “撮影関数”
    typealias Snapshotter = (@escaping (UIImage?) -> Void) -> Void

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

    // キャラ操作
    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    // ✅ Representable 側から注入される “撮影関数”
    @State private var takeBackgroundSnapshot: Snapshotter?

    // 連打防止
    @State private var isCapturing: Bool = false

    init(initialMode: Mode, onCancel: @escaping () -> Void, onCapture: @escaping (UIImage) -> Void) {
        self.initialMode = initialMode
        self.onCancel = onCancel
        self.onCapture = onCapture
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        GeometryReader { geo in
            let characterW = min(geo.size.width * 0.45, 220)

            ZStack {
                // ✅ 背景（AR/カメラ）
                captureSurface
                    .ignoresSafeArea()
                    .background(Color.black)

            }
            // ✅ UIは overlay で上に固定（重なり順を確実に）
            .overlay(alignment: .center) {
                // キャラ（プレビュー用）
                Image("purpor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterW)
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)
            }
            .overlay(alignment: .top) {
                HStack {
                    Button("閉じる") { onCancel() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())

                    Spacer()

                    Picker("撮影", selection: $mode) {
                        ForEach([Mode.ar, .plain]) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                .foregroundStyle(.white)
                .padding()
            }
            .overlay(alignment: .bottom) {
                Button {
                    captureSnapshot(viewSize: geo.size)
                } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.28)).frame(width: 78, height: 78)
                        Circle().fill(Color.white).frame(width: 62, height: 62)
                    }
                }
                .disabled(isCapturing || takeBackgroundSnapshot == nil)
                .opacity((isCapturing || takeBackgroundSnapshot == nil) ? 0.6 : 1.0)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: mode) { _, _ in
            // ✅ モード切替時に古い snapshotter を使わないようクリア
            takeBackgroundSnapshot = nil
        }
    }

    // MARK: - Background Surface

    @ViewBuilder
    private var captureSurface: some View {
        if mode == .ar {
            ARCameraBackgroundView { snapshotter in
                // ✅ makeUIView中のState更新を避ける
                DispatchQueue.main.async {
                    self.takeBackgroundSnapshot = snapshotter
                }
            }
        } else {
            CameraPreviewView { snapshotter in
                // ✅ makeUIView中のState更新を避ける
                DispatchQueue.main.async {
                    self.takeBackgroundSnapshot = snapshotter
                }
            }
        }
    }

    // MARK: - Gesture

    private var characterGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    characterOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = characterOffset },
            MagnificationGesture()
                .onChanged { value in
                    characterScale = max(0.4, min(2.8, lastScale * value))
                }
                .onEnded { _ in lastScale = characterScale }
        )
    }

    // MARK: - Capture

    private func captureSnapshot(viewSize: CGSize) {
        guard !isCapturing else { return }
        guard let takeBackgroundSnapshot else { return }

        isCapturing = true

        takeBackgroundSnapshot { background in
            defer {
                DispatchQueue.main.async { self.isCapturing = false }
            }

            guard let background else { return }

            let composed = composeFinalImage(
                background: background,
                viewSize: viewSize,
                characterOffset: characterOffset,
                characterScale: characterScale
            )

            DispatchQueue.main.async {
                onCapture(composed)
            }
        }
    }

    /// 背景UIImage（カメラ/ARの実画像）に、UIで見えている purpor を同じ見た目で合成
    private func composeFinalImage(
        background: UIImage,
        viewSize: CGSize,
        characterOffset: CGSize,
        characterScale: CGFloat
    ) -> UIImage {

        let bgSize = background.size

        let sx = bgSize.width / max(viewSize.width, 1)
        let sy = bgSize.height / max(viewSize.height, 1)

        let baseCharacterWidthInView = min(viewSize.width * 0.45, 220)
        let finalCharacterWidthInView = baseCharacterWidthInView * characterScale

        let purpor = UIImage(named: "purpor") ?? UIImage()
        let characterWidth = finalCharacterWidthInView * sx
        let aspect = purpor.size.height / max(purpor.size.width, 1)
        let characterHeight = characterWidth * aspect

        let centerXInView = viewSize.width / 2 + characterOffset.width
        let centerYInView = viewSize.height / 2 + characterOffset.height

        let centerX = centerXInView * sx
        let centerY = centerYInView * sy

        let drawRect = CGRect(
            x: centerX - characterWidth / 2,
            y: centerY - characterHeight / 2,
            width: characterWidth,
            height: characterHeight
        )

        let renderer = UIGraphicsImageRenderer(size: bgSize)
        return renderer.image { _ in
            background.draw(in: CGRect(origin: .zero, size: bgSize))
            purpor.draw(in: drawRect)
        }
    }
}

// MARK: - Plain Camera (AVCapturePhotoOutput)

private struct CameraPreviewView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter

    /// ✅ 親に「撮影関数」を渡す（snapshotter は外に保持されるので @escaping）
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    init(onSnapshotReady: @escaping (@escaping Snapshotter) -> Void) {
        self.onSnapshotReady = onSnapshotReady
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()

        // ✅ UIKit側でもタッチを完全遮断（ここが重要）
        view.isUserInteractionEnabled = false

        view.startRunning()

        // ✅ makeUIView中の即時コールを避ける（State更新の警告回避）
        DispatchQueue.main.async {
            onSnapshotReady { completion in
                view.capturePhoto(completion: completion)
            }
        }

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.stopRunning()
    }

    final class PreviewUIView: UIView, AVCapturePhotoCaptureDelegate {
        private let session = AVCaptureSession()
        private let previewLayer = AVCaptureVideoPreviewLayer()

        private let photoOutput = AVCapturePhotoOutput()
        private var photoCompletion: ((UIImage?) -> Void)?

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

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

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

        func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            photoCompletion = completion

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photo: AVCapturePhoto,
                         error: Error?) {
            let image: UIImage?
            if let data = photo.fileDataRepresentation() {
                image = UIImage(data: data)
            } else {
                image = nil
            }
            DispatchQueue.main.async {
                self.photoCompletion?(image)
                self.photoCompletion = nil
            }
        }
    }
}

// MARK: - AR Background (ARView.snapshot)

private struct ARCameraBackgroundView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter

    /// ✅ 親に「撮影関数」を渡す（snapshotter は外に保持されるので @escaping）
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    init(onSnapshotReady: @escaping (@escaping Snapshotter) -> Void) {
        self.onSnapshotReady = onSnapshotReady
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)

        // ✅ UIKit側でもタッチを完全遮断（ここが重要）
        view.isUserInteractionEnabled = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]

        view.automaticallyConfigureSession = false
        view.session.run(config)
        view.renderOptions.insert(.disableMotionBlur)

        // ✅ makeUIView中の即時コールを避ける（State更新の警告回避）
        DispatchQueue.main.async {
            onSnapshotReady { completion in
                view.snapshot(saveToHDR: false) { img in
                    completion(img)
                }
            }
        }

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}

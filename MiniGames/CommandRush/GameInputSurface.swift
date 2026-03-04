import SwiftUI
import UIKit

struct GameInputSurface: UIViewRepresentable {
    var onInput: (InputEvent) -> Void

    func makeUIView(context: Context) -> InputSurfaceView {
        let view = InputSurfaceView()
        view.backgroundColor = .clear
        view.onInput = onInput
        view.setupRecognizers(delegate: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: InputSurfaceView, context: Context) {
        uiView.onInput = onInput
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let isPinch = gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
            return !isPinch
        }
    }
}

final class InputSurfaceView: ShakeAwareView {
    var onInput: ((InputEvent) -> Void)?

    func setupRecognizers(delegate: UIGestureRecognizerDelegate) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.25

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeUp.direction = .up

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeDown.direction = .down

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

        [tap, longPress, swipeUp, swipeDown, swipeLeft, swipeRight, pinch].forEach {
            $0.delegate = delegate
            addGestureRecognizer($0)
        }

        onShake = { [weak self] in
            self?.onInput?(.shake)
        }
    }

    @objc private func handleTap() {
        onInput?(.tap)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onInput?(.longPress)
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        switch recognizer.direction {
        case .up: onInput?(.swipeUp)
        case .down: onInput?(.swipeDown)
        case .left: onInput?(.swipeLeft)
        case .right: onInput?(.swipeRight)
        default: break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        if recognizer.scale >= 1.15 {
            onInput?(.pinchOut)
        } else if recognizer.scale <= 0.85 {
            onInput?(.pinchIn)
        }
    }
}

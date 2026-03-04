import UIKit

extension Notification.Name {
    static let commandRushDidShake = Notification.Name("commandRushDidShake")
}

final class ShakeAwareView: UIView {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake?()
        NotificationCenter.default.post(name: .commandRushDidShake, object: nil)
    }
}

import UIKit

final class DisplayLinkDriver {
    private var displayLink: CADisplayLink?
    var onFrame: (() -> Void)?

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        stop()
    }

    @objc private func step() {
        onFrame?()
    }
}

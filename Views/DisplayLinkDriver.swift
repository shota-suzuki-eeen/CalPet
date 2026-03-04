import Foundation
import QuartzCore

@MainActor
final class DisplayLinkDriver {
    var onFrame: ((CFTimeInterval) -> Void)?

    private var link: CADisplayLink?

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ sender: CADisplayLink) {
        onFrame?(sender.timestamp)
    }

    deinit {
        link?.invalidate()
    }
}

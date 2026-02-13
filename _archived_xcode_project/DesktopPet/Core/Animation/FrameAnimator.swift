import Foundation
import Combine
import CoreGraphics

class FrameAnimator: ObservableObject {
    @Published var currentFrameIndex: Int = 0
    @Published var currentTransform: FrameTransform = .identity
    @Published var isPlaying: Bool = false

    private var animationTimer: Timer?
    private var currentAnimation: AnimationType = .idle
    private var frameStartTime: Date = Date()
    private var animationProgress: CGFloat = 0.0
    private var loop: Bool = true

    private var cancellables = Set<AnyCancellable>()

    func play(animation: AnimationType, loop: Bool = true) {
        stop()
        currentAnimation = animation
        self.loop = loop
        frameStartTime = Date()
        isPlaying = true

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateFrame()
        }
    }

    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
        animationProgress = 0
        currentTransform = .identity
    }

    private func updateFrame() {
        let elapsed = Date().timeIntervalSince(frameStartTime)
        let duration = currentAnimation.duration

        animationProgress = CGFloat(elapsed / duration)

        if animationProgress >= 1.0 {
            if loop {
                frameStartTime = Date()
                animationProgress = 0
            } else {
                stop()
                return
            }
        }

        currentFrameIndex = Int(animationProgress * CGFloat(currentAnimation.frameCount)) % currentAnimation.frameCount
        currentTransform = calculateTransform(for: currentAnimation, progress: animationProgress)
    }

    private func calculateTransform(for animation: AnimationType, progress: CGFloat) -> FrameTransform {
        switch animation {
        case .idle:
            return .breathing(progress)
        case .walk:
            return .walking(progress)
        case .jump:
            return .jumping(progress)
        case .sit:
            return .sitting(min(progress * 2, 1.0))
        case .sleep:
            return .sleeping(progress)
        case .click:
            return .click(progress)
        case .drag:
            return .identity
        }
    }
}

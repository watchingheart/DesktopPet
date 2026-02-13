import Foundation
import CoreGraphics
import Combine

class AnimationEngine: ObservableObject {
    @Published var currentAnimation: AnimationType = .idle
    @Published var animationProgress: CGFloat = 0

    private let frameAnimator: FrameAnimator
    private var animationQueue: [AnimationType] = []
    private var cancellables = Set<AnyCancellable>()

    init(frameAnimator: FrameAnimator) {
        self.frameAnimator = frameAnimator

        // 监听动画播放状态
        frameAnimator.$isPlaying
            .removeDuplicates()
            .sink { [weak self] isPlaying in
                if !isPlaying {
                    self?.playNextAnimation()
                }
            }
            .store(in: &cancellables)

        frameAnimator.$animationProgress
            .assign(to: &$animationProgress)
    }

    func play(_ animation: AnimationType, loop: Bool = false) {
        currentAnimation = animation
        frameAnimator.play(animation: animation, loop: loop)
    }

    func queueAnimation(_ animation: AnimationType) {
        animationQueue.append(animation)
    }

    func playNextAnimation() {
        if !animationQueue.isEmpty {
            let next = animationQueue.removeFirst()
            play(next)
        }
    }

    func clearQueue() {
        animationQueue.removeAll()
    }

    var currentTransform: FrameTransform {
        frameAnimator.currentTransform
    }

    var isPlaying: Bool {
        frameAnimator.isPlaying
    }
}

import Foundation
import Combine

// 行为权重配置
struct BehaviorWeights {
    var idle: Double = 0.4
    var walk: Double = 0.3
    var sit: Double = 0.2
    var sleep: Double = 0.1

    func randomBehavior() -> PetState {
        let total = idle + walk + sit + sleep
        let random = Double.random(in: 0...total)

        if random < idle {
            return .idle
        } else if random < idle + walk {
            return .walking
        } else if random < idle + walk + sit {
            return .sitting
        } else {
            return .sleeping
        }
    }
}

class BehaviorController: ObservableObject {
    @Published var currentState: PetState = .idle
    @Published var behaviorTimer: Timer?

    private(set) var weights: BehaviorWeights = BehaviorWeights()
    private var minInterval: TimeInterval = 3.0
    private var maxInterval: TimeInterval = 10.0

    private let animationEngine: AnimationEngine
    private let movementController: MovementController
    private var cancellables = Set<AnyCancellable>()

    init(animationEngine: AnimationEngine, movementController: MovementController) {
        self.animationEngine = animationEngine
        self.movementController = movementController

        startBehaviorLoop()
    }

    func startBehaviorLoop() {
        scheduleNextBehavior()
    }

    func stopBehaviorLoop() {
        behaviorTimer?.invalidate()
        behaviorTimer = nil
    }

    private func scheduleNextBehavior() {
        behaviorTimer?.invalidate()

        let interval = TimeInterval.random(in: minInterval...maxInterval)
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performRandomBehavior()
        }
    }

    private func performRandomBehavior() {
        guard currentState.canInterrupt else {
            scheduleNextBehavior()
            return
        }

        let possibleStates = currentState.possibleTransitions()
        guard !possibleStates.isEmpty else {
            scheduleNextBehavior()
            return
        }

        // 根据权重选择下一个状态
        let validWeights = possibleStates.compactMap { state -> (PetState, Double)? in
            switch state {
            case .idle: return (state, weights.idle)
            case .walking: return (state, weights.walk)
            case .sitting: return (state, weights.sit)
            case .sleeping: return (state, weights.sleep)
            default: return nil
            }
        }

        guard !validWeights.isEmpty else {
            scheduleNextBehavior()
            return
        }

        let totalWeight = validWeights.reduce(0) { $0 + $1.1 }
        var random = Double.random(in: 0...totalWeight)

        for (state, weight) in validWeights {
            random -= weight
            if random <= 0 {
                transition(to: state)
                break
            }
        }

        scheduleNextBehavior()
    }

    func transition(to newState: PetState) {
        let transition = StateTransition.transition(from: currentState, to: newState)

        currentState = newState

        if let animation = transition.animation {
            animationEngine.play(animation, loop: newState == .walking || newState == .sleeping || newState == .idle)
        }

        // 如果是行走状态，启动移动
        if newState == .walking {
            movementController.startRandomMovement()
        } else {
            movementController.stopMovement()
        }
    }

    func forceState(_ state: PetState) {
        stopBehaviorLoop()
        transition(to: state)
        startBehaviorLoop()
    }

    func interrupt(with animation: AnimationType) {
        guard currentState.canInterrupt else { return }

        let previousState = currentState
        currentState = .interacting

        animationEngine.clearQueue()
        animationEngine.play(animation, loop: false)

        // 动画结束后恢复之前的状态
        DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration) { [weak self] in
            self?.transition(to: previousState)
            self?.scheduleNextBehavior()
        }
    }

    func updateWeights(_ newWeights: BehaviorWeights) {
        weights = newWeights
    }

    func updateIntervals(min: TimeInterval, max: TimeInterval) {
        minInterval = min
        maxInterval = max
    }
}

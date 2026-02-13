import Foundation

// 宠物状态
enum PetState: String, CaseIterable {
    case idle = "待机"
    case walking = "行走中"
    case sitting = "坐着"
    case sleeping = "睡觉中"
    case interacting = "交互中"
    case dragging = "被拖拽"

    var canInterrupt: Bool {
        switch self {
        case .interacting, .dragging:
            return false
        default:
            return true
        }
    }

    var defaultAnimation: AnimationType {
        switch self {
        case .idle: return .idle
        case .walking: return .walk
        case .sitting: return .sit
        case .sleeping: return .sleep
        case .interacting: return .click
        case .dragging: return .drag
        }
    }

    func possibleTransitions() -> [PetState] {
        switch self {
        case .idle:
            return [.walking, .sitting, .sleeping]
        case .walking:
            return [.idle, .sitting]
        case .sitting:
            return [.idle, .sleeping, .walking]
        case .sleeping:
            return [.idle, .sitting]
        case .interacting:
            return [.idle]
        case .dragging:
            return [.idle]
        }
    }
}

// 状态转换
struct StateTransition {
    let from: PetState
    let to: PetState
    let animation: AnimationType?
    let duration: TimeInterval?

    static func transition(from: PetState, to: PetState) -> StateTransition {
        let anim: AnimationType? = {
            switch (from, to) {
            case (.idle, .walking):
                return .walk
            case (_, .sitting):
                return .sit
            case (_, .sleeping):
                return .sleep
            case (_, .idle):
                return .idle
            default:
                return nil
            }
        }()

        return StateTransition(from: from, to: to, animation: anim, duration: anim?.duration)
    }
}

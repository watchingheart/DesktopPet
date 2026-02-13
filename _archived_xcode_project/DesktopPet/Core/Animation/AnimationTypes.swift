import Foundation
import CoreGraphics

// 动画类型
enum AnimationType: String, CaseIterable {
    case idle = "待机"
    case walk = "行走"
    case jump = "跳跃"
    case sit = "坐下"
    case sleep = "睡觉"
    case click = "点击"
    case drag = "拖拽"

    var duration: TimeInterval {
        switch self {
        case .idle: return 2.0
        case .walk: return 0.5
        case .jump: return 0.8
        case .sit: return 3.0
        case .sleep: return 4.0
        case .click: return 0.3
        case .drag: return 0.1
        }
    }

    var frameCount: Int {
        switch self {
        case .idle: return 4
        case .walk: return 6
        case .jump: return 8
        case .sit: return 4
        case .sleep: return 4
        case .click: return 2
        case .drag: return 1
        }
    }
}

// 动画帧
struct AnimationFrame {
    let image: CGImage?
    let transform: FrameTransform
    let duration: TimeInterval
}

// 帧变换参数
struct FrameTransform {
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var rotation: CGFloat = 0.0
    var offsetX: CGFloat = 0.0
    var offsetY: CGFloat = 0.0
    var opacity: CGFloat = 1.0

    static let identity = FrameTransform()

    static func breathing(_ progress: CGFloat) -> FrameTransform {
        let scale = 1.0 + 0.03 * sin(progress * .pi * 2)
        return FrameTransform(scaleX: scale, scaleY: scale)
    }

    static func walking(_ progress: CGFloat) -> FrameTransform {
        let bounce = 0.1 * sin(progress * .pi * 2)
        let tilt = 0.05 * sin(progress * .pi * 4)
        return FrameTransform(
            scaleX: 1.0,
            scaleY: 1.0,
            rotation: tilt,
            offsetY: bounce * 20
        )
    }

    static func jumping(_ progress: CGFloat) -> FrameTransform {
        let jumpPhase: CGFloat
        if progress < 0.5 {
            // 上升阶段：压缩
            jumpPhase = 1.0 - progress * 2
            let squash = 1.0 + 0.2 * (1.0 - jumpPhase)
            return FrameTransform(
                scaleX: squash,
                scaleY: 2.0 - squash,
                offsetY: -100 * sin(progress * .pi)
            )
        } else {
            // 下降阶段：拉伸
            jumpPhase = (progress - 0.5) * 2
            let stretch = 1.0 + 0.2 * jumpPhase
            return FrameTransform(
                scaleX: 2.0 - stretch,
                scaleY: stretch,
                offsetY: -100 * sin(progress * .pi)
            )
        }
    }

    static func sitting(_ progress: CGFloat) -> FrameTransform {
        let compress = 0.8 + 0.1 * progress
        return FrameTransform(
            scaleX: 1.0 + (1.0 - compress) * 0.5,
            scaleY: compress
        )
    }

    static func sleeping(_ progress: CGFloat) -> FrameTransform {
        let breathScale = 1.0 + 0.02 * sin(progress * .pi * 2)
        let opacity = 0.7 + 0.3 * cos(progress * .pi)
        return FrameTransform(
            scaleX: breathScale,
            scaleY: breathScale,
            rotation: 0.1,
            opacity: opacity
        )
    }

    static func click(_ progress: CGFloat) -> FrameTransform {
        let scale = 1.0 + 0.2 * sin(progress * .pi)
        return FrameTransform(scaleX: scale, scaleY: scale)
    }
}

// 动画配置
struct AnimationConfig {
    var frameRate: TimeInterval = 1.0 / 30.0
    var autoPlay: Bool = true
    var loop: Bool = true
}

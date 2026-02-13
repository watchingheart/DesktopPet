import Foundation
import AppKit
import Combine

class MovementController: ObservableObject {
    @Published var position: CGPoint = .zero
    @Published var isMoving: Bool = false
    @Published var facingRight: Bool = true

    private var movementTimer: Timer?
    private var targetPosition: CGPoint?
    private let moveSpeed: CGFloat = 2.0
    private let petSize: CGFloat = 150

    private weak var window: NSWindow?

    init() {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            position = CGPoint(
                x: screenFrame.midX,
                y: screenFrame.minY + 100
            )
        }
    }

    func setWindow(_ window: NSWindow) {
        self.window = window
        window.setFrameOrigin(position)
    }

    func startRandomMovement() {
        guard !isMoving else { return }

        isMoving = true
        scheduleNextMove()
    }

    func stopMovement() {
        isMoving = false
        movementTimer?.invalidate()
        movementTimer = nil
    }

    private func scheduleNextMove() {
        movementTimer?.invalidate()

        // 随机移动间隔
        let interval = TimeInterval.random(in: 1.0...3.0)
        movementTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performMove()
        }
    }

    private func performMove() {
        guard let screen = NSScreen.main else {
            scheduleNextMove()
            return
        }

        let screenFrame = screen.visibleFrame

        // 随机目标位置
        let targetX = CGFloat.random(in: screenFrame.minX...screenFrame.maxX - petSize)
        let targetY = CGFloat.random(in: screenFrame.minY...screenFrame.maxY - petSize)

        targetPosition = CGPoint(x: targetX, y: targetY)

        // 确定朝向
        facingRight = targetX > position.x

        // 开始平滑移动
        moveTo(targetPosition!, completion: { [weak self] in
            if self?.isMoving == true {
                self?.scheduleNextMove()
            }
        })
    }

    private func moveTo(_ target: CGPoint, completion: (() -> Void)? = nil) {
        let startX = position.x
        let startY = position.y
        let deltaX = target.x - startX
        let deltaY = target.y - startY
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        let duration = TimeInterval(distance / (moveSpeed * 60))
        let startTime = Date()

        movementTimer?.invalidate()
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(CGFloat(elapsed / duration), 1.0)

            // 缓动函数
            let easedProgress = self.easeInOut(progress)

            self.position = CGPoint(
                x: startX + deltaX * easedProgress,
                y: startY + deltaY * easedProgress
            )

            self.window?.setFrameOrigin(self.position)

            if progress >= 1.0 {
                timer.invalidate()
                completion?()
            }
        }
    }

    func moveToImmediately(_ position: CGPoint) {
        movementTimer?.invalidate()
        self.position = position
        window?.setFrameOrigin(position)
    }

    func dragTo(_ position: CGPoint) {
        self.position = position
        window?.setFrameOrigin(position)
        facingRight = position.x > self.position.x
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    func followMouse() {
        guard let mouseLocation = NSEvent.mouseLocation else { return }

        let targetX = mouseLocation.x - petSize / 2
        let targetY = mouseLocation.y - petSize / 2

        facingRight = targetX > position.x

        // 平滑跟随
        let smoothFactor: CGFloat = 0.05
        let newX = position.x + (targetX - position.x) * smoothFactor
        let newY = position.y + (targetY - position.y) * smoothFactor

        position = CGPoint(x: newX, y: newY)
        window?.setFrameOrigin(position)
    }

    func keepOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        var newPosition = position

        // 确保在屏幕范围内
        newPosition.x = max(screenFrame.minX, min(newPosition.x, screenFrame.maxX - petSize))
        newPosition.y = max(screenFrame.minY, min(newPosition.y, screenFrame.maxY - petSize))

        if newPosition != position {
            position = newPosition
            window?.setFrameOrigin(position)
        }
    }
}

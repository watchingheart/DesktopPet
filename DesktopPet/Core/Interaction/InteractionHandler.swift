import Foundation
import AppKit
import Combine

class InteractionHandler: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var isMouseFollowing: Bool = false

    private weak var behaviorController: BehaviorController?
    private weak var movementController: MovementController?
    private weak var animationEngine: AnimationEngine?

    private var lastClickTime: Date?
    private let doubleClickInterval: TimeInterval = 0.3
    private var mouseFollowTimer: Timer?
    private var dragOffset: CGPoint = .zero

    private var cancellables = Set<AnyCancellable>()

    init(behaviorController: BehaviorController,
         movementController: MovementController,
         animationEngine: AnimationEngine) {
        self.behaviorController = behaviorController
        self.movementController = movementController
        self.animationEngine = animationEngine
    }

    // MARK: - 点击处理

    func handleClick(at location: CGPoint, in window: NSWindow) {
        let now = Date()

        if let lastClick = lastClickTime, now.timeIntervalSince(lastClick) < doubleClickInterval {
            // 双击
            handleDoubleClick()
            lastClickTime = nil
        } else {
            // 单击
            lastClickTime = now
            handleClick()
        }
    }

    private func handleClick() {
        behaviorController?.interrupt(with: .click)
    }

    private func handleDoubleClick() {
        behaviorController?.interrupt(with: .jump)
    }

    // MARK: - 拖拽处理

    func beginDrag(at location: CGPoint, in window: NSWindow) {
        isDragging = true
        behaviorController?.stopBehaviorLoop()
        behaviorController?.transition(to: .dragging)

        let windowOrigin = window.frame.origin
        dragOffset = CGPoint(
            x: location.x - windowOrigin.x,
            y: location.y - windowOrigin.y
        )
    }

    func continueDrag(at location: CGPoint) {
        guard isDragging else { return }

        let newPosition = CGPoint(
            x: location.x - dragOffset.x,
            y: location.y - dragOffset.y
        )

        movementController?.dragTo(newPosition)
    }

    func endDrag() {
        isDragging = false
        behaviorController?.transition(to: .idle)
        behaviorController?.startBehaviorLoop()
    }

    // MARK: - 鼠标跟随

    func startMouseFollowing() {
        isMouseFollowing = true
        behaviorController?.stopBehaviorLoop()

        mouseFollowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.movementController?.followMouse()
        }
    }

    func stopMouseFollowing() {
        isMouseFollowing = false
        mouseFollowTimer?.invalidate()
        mouseFollowTimer = nil

        behaviorController?.startBehaviorLoop()
    }

    func toggleMouseFollowing() {
        if isMouseFollowing {
            stopMouseFollowing()
        } else {
            startMouseFollowing()
        }
    }

    // MARK: - 右键菜单

    func showContextMenu(at location: CGPoint, in view: NSView) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "跳跃", action: #selector(menuJump), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "坐下", action: #selector(menuSit), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "睡觉", action: #selector(menuSleep), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        let followItem = NSMenuItem(
            title: isMouseFollowing ? "停止跟随" : "跟随鼠标",
            action: #selector(toggleFollow),
            keyEquivalent: ""
        )
        menu.addItem(followItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "回到屏幕中央", action: #selector(centerPet), keyEquivalent: ""))

        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: view)
    }

    @objc private func menuJump() {
        behaviorController?.interrupt(with: .jump)
    }

    @objc private func menuSit() {
        behaviorController?.forceState(.sitting)
    }

    @objc private func menuSleep() {
        behaviorController?.forceState(.sleeping)
    }

    @objc private func toggleFollow() {
        toggleMouseFollowing()
    }

    @objc private func centerPet() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let centerPosition = CGPoint(
            x: screenFrame.midX - 75,
            y: screenFrame.midY - 75
        )
        movementController?.moveToImmediately(centerPosition)
    }
}

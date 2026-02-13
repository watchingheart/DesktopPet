import Foundation
import Combine
import AppKit

class PetViewModel: ObservableObject {
    // 状态
    @Published var petImage: NSImage?
    @Published var currentState: PetState = .idle
    @Published var currentTransform: FrameTransform = .identity
    @Published var facingRight: Bool = true

    // 配置
    @Published var configuration: PetConfiguration = .default

    // 子系统
    private(set) var frameAnimator: FrameAnimator
    private(set) var animationEngine: AnimationEngine
    private(set) var movementController: MovementController
    private(set) var behaviorController: BehaviorController
    private(set) var interactionHandler: InteractionHandler
    private(set) var imageProcessor: LocalImageProcessor

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 初始化子系统
        frameAnimator = FrameAnimator()
        animationEngine = AnimationEngine(frameAnimator: frameAnimator)
        movementController = MovementController()
        behaviorController = BehaviorController(animationEngine: animationEngine, movementController: movementController)
        interactionHandler = InteractionHandler(
            behaviorController: behaviorController,
            movementController: movementController,
            animationEngine: animationEngine
        )
        imageProcessor = LocalImageProcessor()

        // 加载配置
        configuration = ConfigurationManager.shared.configuration

        setupBindings()
        loadDefaultPetImage()
    }

    private func setupBindings() {
        // 绑定动画变换
        animationEngine.$currentAnimation
            .sink { [weak self] _ in
                self?.updateTransform()
            }
            .store(in: &cancellables)

        frameAnimator.$currentTransform
            .assign(to: &$currentTransform)

        // 绑定状态
        behaviorController.$currentState
            .assign(to: &$currentState)

        // 绑定朝向
        movementController.$facingRight
            .assign(to: &$facingRight)

        // 绑定位置
        movementController.$position
            .sink { [weak self] position in
                self?.updateWindowPosition(position)
            }
            .store(in: &cancellables)
    }

    private func updateTransform() {
        currentTransform = frameAnimator.currentTransform
    }

    private func updateWindowPosition(_ position: CGPoint) {
        // 通知窗口更新位置
        NotificationCenter.default.post(
            name: .petPositionChanged,
            object: position
        )
    }

    // 加载默认宠物图片
    private func loadDefaultPetImage() {
        // 创建一个简单的占位图片
        let defaultImage = createPlaceholderImage()
        petImage = defaultImage
    }

    // 创建占位图片
    private func createPlaceholderImage() -> NSImage {
        let size = NSSize(width: 150, height: 150)
        let image = NSImage(size: size)

        image.lockFocus()

        // 绘制一个可爱的圆形角色
        let center = NSPoint(x: size.width / 2, y: size.height / 2)

        // 身体
        NSColor.systemPink.withAlphaComponent(0.9).setFill()
        let bodyPath = NSBezierPath(ovalIn: NSRect(x: 25, y: 25, width: 100, height: 100))
        bodyPath.fill()

        // 眼睛
        NSColor.white.setFill()
        let leftEye = NSBezierPath(ovalIn: NSRect(x: 50, y: 85, width: 15, height: 15))
        let rightEye = NSBezierPath(ovalIn: NSRect(x: 85, y: 85, width: 15, height: 15))
        leftEye.fill()
        rightEye.fill()

        // 瞳孔
        NSColor.black.setFill()
        let leftPupil = NSBezierPath(ovalIn: NSRect(x: 55, y: 88, width: 8, height: 8))
        let rightPupil = NSBezierPath(ovalIn: NSRect(x: 90, y: 88, width: 8, height: 8))
        leftPupil.fill()
        rightPupil.fill()

        // 腮红
        NSColor.systemRed.withAlphaComponent(0.3).setFill()
        let leftBlush = NSBezierPath(ovalIn: NSRect(x: 35, y: 65, width: 20, height: 10))
        let rightBlush = NSBezierPath(ovalIn: NSRect(x: 95, y: 65, width: 20, height: 10))
        leftBlush.fill()
        rightBlush.fill()

        // 嘴巴
        NSColor.systemPink.darkerColor().setStroke()
        let mouthPath = NSBezierPath()
        mouthPath.move(to: NSPoint(x: 70, y: 60))
        mouthPath.curve(
            to: NSPoint(x: 80, y: 60),
            controlPoint1: NSPoint(x: 72, y: 55),
            controlPoint2: NSPoint(x: 78, y: 55)
        )
        mouthPath.lineWidth = 2
        mouthPath.stroke()

        image.unlockFocus()

        return image
    }

    // 从 URL 加载宠物图片
    func loadPetImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            print("无法加载图片: \(url.path)")
            return
        }

        // 调整图片大小
        let targetSize = NSSize(width: 150, height: 150)
        let resizedImage = imageProcessor.resizeImage(image, to: targetSize) ?? image

        // 可选：移除背景
        // let processedImage = imageProcessor.removeBackground(from: resizedImage) ?? resizedImage

        DispatchQueue.main.async {
            self.petImage = resizedImage
        }
    }

    // 保存配置
    func saveConfiguration() {
        ConfigurationManager.shared.configuration = configuration
    }

    // 重置配置
    func resetConfiguration() {
        configuration = .default
        ConfigurationManager.shared.reset()
    }

    // MARK: - 交互方法

    func handleClick(at location: CGPoint, in window: NSWindow) {
        interactionHandler.handleClick(at: location, in: window)
    }

    func handleRightClick(at location: CGPoint, in view: NSView) {
        interactionHandler.showContextMenu(at: location, in: view)
    }

    func beginDrag(at location: CGPoint, in window: NSWindow) {
        interactionHandler.beginDrag(at: location, in: window)
    }

    func continueDrag(at location: CGPoint) {
        interactionHandler.continueDrag(at: location)
    }

    func endDrag() {
        interactionHandler.endDrag()
    }
}

extension Notification.Name {
    static let petPositionChanged = Notification.Name("petPositionChanged")
}

extension NSColor {
    func darkerColor() -> NSColor {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(
            red: max(rgbColor.redComponent - 0.2, 0),
            green: max(rgbColor.greenComponent - 0.2, 0),
            blue: max(rgbColor.blueComponent - 0.2, 0),
            alpha: rgbColor.alphaComponent
        )
    }
}

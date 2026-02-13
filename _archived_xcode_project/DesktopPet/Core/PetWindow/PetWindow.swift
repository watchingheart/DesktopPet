import AppKit

class PetWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // 透明背景
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // 始终置顶
        level = .screenSaver

        // 在所有桌面显示
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 忽略鼠标事件（由视图处理）
        ignoresMouseEvents = false

        // 初始位置：屏幕右下角
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let petSize: CGFloat = 150
            setFrameOrigin(NSPoint(
                x: screenFrame.maxX - petSize - 50,
                y: screenFrame.minY + 50
            ))
        }
    }
}

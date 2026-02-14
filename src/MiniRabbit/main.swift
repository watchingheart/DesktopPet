import AppKit
import Foundation
import CoreGraphics
// Helper function for logging
func log(_ message: String) {
    NSLog("[MiniRabbit] \(message)")
}

// MARK: - Configuration

struct MiniRabbitConfig {
    var size: CGFloat = 200
    var lifetime: TimeInterval = 10
    var position: CGPoint?
    var noAutoDismiss: Bool = false

    static func parse(from args: [String]) -> MiniRabbitConfig {
        var config = MiniRabbitConfig()
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--size":
                if i + 1 < args.count, let sizeDouble = Double(args[i + 1]) {
                    config.size = CGFloat(sizeDouble)
                }
                i += 2
            case "--lifetime":
                if i + 1 < args.count, let lifetime = TimeInterval(args[i + 1]) {
                    config.lifetime = lifetime
                }
                i += 2
            case "--position":
                if i + 2 < args.count,
                   let xDouble = Double(args[i + 1]),
                   let yDouble = Double(args[i + 2]) {
                    config.position = CGPoint(x: CGFloat(xDouble), y: CGFloat(yDouble))
                }
                i += 3
            case "--no-auto-dismiss":
                config.noAutoDismiss = true
                i += 1
            default:
                i += 1
            }
        }
        return config
    }
}

// MARK: - Constants

enum MiniRabbitConstants {
    static let defaultSize: CGFloat = 200
    static let defaultLifetime: TimeInterval = 10
    static let animationFrameRate: TimeInterval = 1.0 / 30.0
    static let gifFrameRate: TimeInterval = 1.0 / 30.0
    static let rabbitSize: CGFloat = 200
}

// MARK: - Mini Rabbit Window

class MiniRabbitWindow: NSWindow {
    private var gifFrames: [NSImage] = []
    private var currentFrameIndex = 0
    private var animationTimer: Timer?
    private var config: MiniRabbitConfig

    init(config: MiniRabbitConfig) {
        self.config = config

        let size = NSSize(width: config.size, height: config.size)
        var origin = config.position ?? .zero

        // Get screen frame for positioning
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
                if origin == .zero {
                origin = CGPoint(
                    x: CGFloat.random(in: screenFrame.minX...(screenFrame.maxX - config.size)),
                    y: CGFloat.random(in: screenFrame.minY...(screenFrame.maxY - config.size))
                )
            } else {
                // Ensure position is within screen bounds
                origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - config.size))
                origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - config.size))
            }
        }

        log("Creating window at: \(NSPoint(x: origin.x, y: origin.y))")

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false

        setupImageView()

        makeKeyAndOrderFront(nil)
        orderFrontRegardless()

        loadGifFrames()
        startAnimation()
        startLifecycle()
    }

    private func setupImageView() {
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: frame.size))
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = .clear
        imageView.imageScaling = .scaleProportionallyUpOrDown
        contentView = imageView
    }

    private func startAnimation() {
        guard !gifFrames.isEmpty else { return }

        currentFrameIndex = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: MiniRabbitConstants.gifFrameRate, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.gifFrames.count
            if let imageView = self.contentView as? NSImageView {
                imageView.image = self.gifFrames[self.currentFrameIndex]
            }
        }
    }

    private func startLifecycle() {
        guard !config.noAutoDismiss else { return }

        // Fade in
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            animator().alphaValue = 1.0
        }

        // Schedule fade out and exit
        let fadeOutDelay = config.lifetime - 0.3

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDelay) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self?.animator().alphaValue = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + config.lifetime + 0.5) { [weak self] in
            self?.close()
        }
    }

    private func loadGifFrames() {
        guard let url = findGifURL() else {
            log("Error: Could not find GIF file")
            return
        }

        guard let imageData = try? Data(contentsOf: url) else {
            log("Error: Failed to load GIF from \(url.path)")
            return
        }

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            log("Error: Failed to create image source")
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        var frames: [NSImage] = []

        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: MiniRabbitConstants.rabbitSize, height: MiniRabbitConstants.rabbitSize))
                frames.append(nsImage)
            }
        }

        gifFrames = frames
        currentFrameIndex = 0

        log("Loaded \(gifFrames.count) frames from GIF")

        // Update first frame immediately
        if let imageView = contentView as? NSImageView, !gifFrames.isEmpty {
            imageView.image = gifFrames[0]
        }
    }

    private func findGifURL() -> URL? {
        let cwd = FileManager.default.currentDirectoryPath
        let paths = [
            "兔_idle.gif",
            "tools/rabbit_output/兔_idle.gif"
        ]

        for path in paths {
            let localURL = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: localURL.path) {
                log("Found GIF at: \(localURL.path)")
                return localURL
            }
        }

        log("GIF not found in any of these paths:")
        for path in paths {
            log("  - \(cwd)/\(path)")
        }
        return nil
    }
}

// MARK: - Application Delegate

class MiniRabbitDelegate: NSObject, NSApplicationDelegate {
    var window: MiniRabbitWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = MiniRabbitConfig.parse(from: CommandLine.arguments)

        var position = config.position
        if position == nil, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            position = CGPoint(
                x: CGFloat.random(in: 0...(frame.width - MiniRabbitConstants.rabbitSize)),
                y: CGFloat.random(in: 0...(frame.height - MiniRabbitConstants.rabbitSize))
            )
        }

        window = MiniRabbitWindow(config: config)

        log("MiniRabbit started successfully")
        log("Size: \(config.size)")
        log("Lifetime: \(config.lifetime)s")
        log("Position: \(String(describing: position))")
        log("GIF files checked:")
        let cwd = FileManager.default.currentDirectoryPath
        for path in ["兔_idle.gif", "tools/rabbit_output/兔_idle.gif"] {
            let fileURL = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                log("  ✓ \(path)")
            } else {
                log("  ✗ \(path)")
            }
        }
        log("Done checking...")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}

// MARK: - Main Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = MiniRabbitDelegate()
app.delegate = delegate

app.run()

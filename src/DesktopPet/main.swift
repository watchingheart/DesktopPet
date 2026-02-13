import SwiftUI
import AppKit
import Combine
import CoreGraphics
import CommonCrypto

// MARK: - Configuration Constants

/// Animation and timing constants
enum AnimationConstants {
    /// Frame rate for smooth animations (60 FPS)
    static let animationFrameRate: TimeInterval = 1.0 / 60.0

    /// Frame rate for GIF playback (10 FPS)
    static let gifFrameRate: TimeInterval = 0.1

    /// Duration for sound/text bubble display
    static let soundDisplayDuration: TimeInterval = 2.0

    /// Duration for jump animation
    static let jumpAnimationDuration: TimeInterval = 0.3

    /// Delay before processing single click (to detect double-click)
    static let clickDelay: TimeInterval = 0.25
}

/// UI Layout constants
enum LayoutConstants {
    /// Default size for pet images
    static let defaultPetSize: NSSize = NSSize(width: 100, height: 100)

    /// Size for the main window/view
    static let mainWindowSize: NSSize = NSSize(width: 600, height: 600)

    /// Display size for GIF animations (relative to pet size)
    static let gifDisplayScale: CGFloat = 0.5
}

/// API and network constants
enum NetworkConstants {
    /// Timeout for API requests (seconds)
    static let requestTimeout: TimeInterval = 120

    /// Delay before retrying a failed operation
    static let retryDelay: TimeInterval = 3.0

    /// Longer delay for second retry
    static let longRetryDelay: TimeInterval = 6.0
}

// MARK: - Resource Path Helper

/// Returns the path to a resource file, checking multiple possible locations
func resourcePath(named name: String) -> URL? {
    // First, try Bundle.main.resourcePath (for when resources are bundled)
    if let resourcePath = Bundle.main.resourcePath {
        let bundleURL = URL(fileURLWithPath: resourcePath).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
    }

    // Second, try relative to the executable
    if let executablePath = Bundle.main.executablePath {
        let execDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
        let relativeURL = execDir.appendingPathComponent("../resources").appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: relativeURL.path) {
            return relativeURL.standardizedFileURL
        }
    }

    // Third, try the project's tools directory (for development)
    let projectPath = FileManager.default.currentDirectoryPath
    let toolsURL = URL(fileURLWithPath: projectPath).appendingPathComponent("tools/rabbit_output").appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: toolsURL.path) {
        return toolsURL
    }

    print("Warning: Resource '\(name)' not found")
    return nil
}

// MARK: - Migration Helper

/// Handles migration from UserDefaults to Keychain for sensitive data
class KeychainMigration {
    static let shared = KeychainMigration()
    private let userDefaultsKey = "ai_api_key"
    private let migrationCompletedKey = "keychain_migration_completed"

    private init() {}

    /// Performs migration if not already done
    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return
        }

        // Check if there's an API key in UserDefaults
        if let existingKey = UserDefaults.standard.string(forKey: userDefaultsKey), !existingKey.isEmpty {
            // Migrate to Keychain
            if KeychainHelper.saveApiKey(existingKey) {
                print("Successfully migrated API Key from UserDefaults to Keychain")

                // Clear from UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)

                // Mark migration as complete
                UserDefaults.standard.set(true, forKey: migrationCompletedKey)
            } else {
                print("Failed to migrate API Key to Keychain")
            }
        } else {
            // No existing key, mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        }
    }
}

// MARK: - Animation Cache Manager

/// Manages caching of AI-generated animation frames to disk.
/// Reduces API calls by storing generated frames keyed by image hash and action type.
class AnimationCache {
    static let shared = AnimationCache()

    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("DesktopPet/AnimationCache")
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            } catch {
                print("Warning: Failed to create cache directory: \(error.localizedDescription)")
            }
        }
        return cacheDir
    }

    // 生成缓存键（基于图片哈希）
    private func cacheKey(for image: NSImage, action: String) -> String {
        guard let data = image.tiffRepresentation else { return "\(action)_default" }
        let hash = data.sha256?.prefix(16) ?? "default"
        return "\(action)_\(hash)"
    }

    // 保存动画帧到缓存
    func saveFrames(_ frames: [NSImage], for image: NSImage, action: String) {
        let key = cacheKey(for: image, action: action)
        for (index, frame) in frames.enumerated() {
            let fileURL = cacheDirectory.appendingPathComponent("\(key)_\(index).png")
            if let tiffData = frame.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: fileURL)
                } catch {
                    print("Warning: Failed to save cached frame \(index): \(error.localizedDescription)")
                }
            }
        }
    }

    // 从缓存加载动画帧
    func loadFrames(for image: NSImage, action: String) -> [NSImage]? {
        let key = cacheKey(for: image, action: action)
        var frames: [NSImage] = []

        var index = 0
        while true {
            let fileURL = cacheDirectory.appendingPathComponent("\(key)_\(index).png")
            if fileManager.fileExists(atPath: fileURL.path),
               let image = NSImage(contentsOf: fileURL) {
                frames.append(image)
                index += 1
            } else {
                break
            }
        }

        return frames.isEmpty ? nil : frames
    }

    // 检查是否有缓存
    func hasCache(for image: NSImage, action: String) -> Bool {
        let key = cacheKey(for: image, action: action)
        let fileURL = cacheDirectory.appendingPathComponent("\(key)_0.png")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // 清除所有缓存
    func clearCache() {
        do {
            try fileManager.removeItem(at: cacheDirectory)
        } catch {
            print("Warning: Failed to clear cache directory: \(error.localizedDescription)")
        }
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Warning: Failed to recreate cache directory: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Extensions

extension Data {
    /// Computes the SHA-256 hash of this data.
    /// - Returns: Hexadecimal string representation of the hash, or nil if computation fails.
    var sha256: String? {
        guard let digest = self.withUnsafeBytes({ bytes -> [UInt8]? in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &hash)
            return hash
        }) else { return nil }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - AI Animation Service

enum AIProvider: String, CaseIterable {
    case zhipu = "智谱 AI (GLM-4V)"
    case openai = "OpenAI (DALL-E)"
    case deepseek = "DeepSeek"
    case moonshot = "Moonshot"

    var defaultEndpoint: String {
        switch self {
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4/images/generations"
        case .openai: return "https://api.openai.com/v1/images/generations"
        case .deepseek: return "https://api.deepseek.com/v1/images/generations"
        case .moonshot: return "https://api.moonshot.cn/v1/images/generations"
        }
    }

    var modelName: String {
        switch self {
        case .zhipu: return "cogview-3"
        case .openai: return "dall-e-3"
        case .deepseek: return "dall-e-3"
        case .moonshot: return "dall-e-3"
        }
    }
}

/// Service for generating pet animations using AI image generation APIs.
/// Supports multiple AI providers (Zhipu AI, OpenAI, DeepSeek, Moonshot).
/// Includes caching to reduce API calls and local transformation fallback.
class AIAnimationService {
    static let shared = AIAnimationService()

    init() {
        // Perform migration on initialization
        KeychainMigration.shared.migrateIfNeeded()
    }

    var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "ai_provider") ?? "zhipu") ?? .zhipu }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "ai_provider") }
    }

    var apiKey: String {
        get {
            // Read from Keychain
            if let key = KeychainHelper.readApiKey() {
                return key
            }
            return ""
        }
        set {
            // Save to Keychain
            if newValue.isEmpty {
                // If setting to empty, delete from Keychain
                KeychainHelper.deleteApiKey()
            } else {
                KeychainHelper.saveApiKey(newValue)
            }
        }
    }

    var apiEndpoint: String {
        get { UserDefaults.standard.string(forKey: "ai_endpoint") ?? provider.defaultEndpoint }
        set { UserDefaults.standard.set(newValue, forKey: "ai_endpoint") }
    }

    // 动作对应的提示词
    private let actionPrompts: [String: String] = [
        "idle": "cute pet character standing still, breathing animation, kawaii style, simple background, front view",
        "walk": "cute pet character walking animation, 4 frames sequence, kawaii style, simple background, side view",
        "jump": "cute pet character jumping animation, 4 frames sequence, kawaii style, simple background, side view",
        "sleep": "cute pet character sleeping animation, closed eyes, zzz, kawaii style, simple background",
        "sit": "cute pet character sitting animation, kawaii style, simple background, front view",
        "happy": "cute pet character happy excited animation, bouncing, kawaii style, simple background"
    ]

    // 生成动画帧
    func generateFrames(for image: NSImage, action: String, progress: @escaping (String) -> Void, completion: @escaping ([NSImage]?) -> Void) {
        // 先检查缓存
        if let cachedFrames = AnimationCache.shared.loadFrames(for: image, action: action) {
            completion(cachedFrames)
            return
        }

        progress("正在生成 \(action) 动画...")

        // 如果没有 API Key，使用本地图像变换
        if apiKey.isEmpty {
            print("No API Key, using local transformation for \(action)")
            let frames = generateFrameSequence(from: image, action: action)
            AnimationCache.shared.saveFrames(frames, for: image, action: action)
            completion(frames)
            return
        }

        // 调用 AI API 生成图片
        generateImage(prompt: actionPrompts[action] ?? actionPrompts["idle"]!) { generatedImage in
            if let generatedImage = generatedImage {
                // 生成动画帧序列
                let frames = self.generateFrameSequence(from: generatedImage, action: action)
                AnimationCache.shared.saveFrames(frames, for: image, action: action)
                completion(frames)
            } else {
                // API 失败，使用本地变换作为后备
                print("API failed, using local transformation as fallback")
                let frames = self.generateFrameSequence(from: image, action: action)
                AnimationCache.shared.saveFrames(frames, for: image, action: action)
                completion(frames)
            }
        }
    }

    // 调用 AI API 生成图片
    private func generateImage(prompt: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: apiEndpoint) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 根据不同提供商使用不同的请求格式
        let body: [String: Any]
        if provider == .zhipu {
            // 智谱 AI GLM 格式
            body = [
                "model": provider.modelName,
                "prompt": prompt,
                "size": "1024x1024"
            ]
        } else {
            // OpenAI 兼容格式
            body = [
                "model": provider.modelName,
                "prompt": prompt,
                "n": 1,
                "size": "1024x1024",
                "response_format": "url"
            ]
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("Error: Failed to serialize JSON request body")
            completion(nil)
            return
        }
        request.httpBody = httpBody
        request.timeoutInterval = NetworkConstants.requestTimeout

        print("Calling API: \(apiEndpoint)")
        print("Provider: \(provider.rawValue)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // 打印响应用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response: \(responseString.prefix(500))")
            }

            // 解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 智谱 AI 返回格式
                if let dataArray = json["data"] as? [[String: Any]],
                   let firstItem = dataArray.first {
                    // 尝试获取 URL
                    if let imageUrlString = firstItem["url"] as? String,
                       let imageUrl = URL(string: imageUrlString) {
                        self.downloadImage(from: imageUrl, completion: completion)
                        return
                    }
                    // 尝试获取 base64
                    if let b64 = firstItem["b64_json"] as? String,
                       let imgData = Data(base64Encoded: b64),
                       let image = NSImage(data: imgData) {
                        let resized = self.resizeImage(image, to: NSSize(width: 100, height: 100))
                        let processed = self.removeBackground(from: resized)
                        DispatchQueue.main.async {
                            completion(processed)
                        }
                        return
                    }
                }
                // 智谱 AI 可能直接返回 url
                if let imageUrlString = json["url"] as? String,
                   let imageUrl = URL(string: imageUrlString) {
                    self.downloadImage(from: imageUrl, completion: completion)
                    return
                }
                // 检查错误
                if let errorDict = json["error"] as? [String: Any],
                   let errorMsg = errorDict["message"] as? String {
                    print("API Error Message: \(errorMsg)")
                }
            }

            DispatchQueue.main.async {
                completion(nil)
            }
        }.resume()
    }

    private func downloadImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { imgData, _, _ in
            if let imgData = imgData, let image = NSImage(data: imgData) {
                let resized = self.resizeImage(image, to: NSSize(width: 100, height: 100))
                let processed = self.removeBackground(from: resized)
                DispatchQueue.main.async {
                    completion(processed)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }

    // 生成帧序列（保持原图，只用于缓存标识）
    private func generateFrameSequence(from image: NSImage, action: String) -> [NSImage] {
        // 不再对图像进行变换，直接返回原图
        // 动画效果由 PetController 的 FrameTransform 实时渲染
        // 这样可以保持原图外观不变
        return [image]
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }

    private func rotateImage(_ image: NSImage, by angle: CGFloat) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let newSize = CGSize(width: width, height: height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.clear(CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: angle)
        context.draw(cgImage, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))

        guard let newCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: newCGImage, size: newSize)
    }

    private func scaleImage(_ image: NSImage, scaleX: CGFloat, scaleY: CGFloat) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = CGFloat(cgImage.width) * abs(scaleX)
        let height = CGFloat(cgImage.height) * abs(scaleY)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: width / 2, y: height / 2)
        context.scaleBy(x: scaleX, y: scaleY)
        context.draw(cgImage, in: CGRect(x: -width / 2 / abs(scaleX), y: -height / 2 / abs(scaleY), width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))

        guard let newCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: newCGImage, size: NSSize(width: width, height: height))
    }

    private func removeBackground(from image: NSImage) -> NSImage {
        // 使用之前的背景去除逻辑
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        let dataLength = height * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: dataLength)

        guard let data = dataProvider.data else { return image }
        CFDataGetBytes(data, CFRange(location: 0, length: dataLength), &pixels)

        // 采样四角
        let corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
        var bgColorR: CGFloat = 0, bgColorG: CGFloat = 0, bgColorB: CGFloat = 0

        for (x, y) in corners {
            let offset = y * bytesPerRow + x * bytesPerPixel
            if offset + 2 < pixels.count {
                bgColorR += CGFloat(pixels[offset])
                bgColorG += CGFloat(pixels[offset + 1])
                bgColorB += CGFloat(pixels[offset + 2])
            }
        }
        bgColorR /= 4; bgColorG /= 4; bgColorB /= 4

        let tolerance: CGFloat = 30

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if offset + 3 < pixels.count {
                    let r = CGFloat(pixels[offset])
                    let g = CGFloat(pixels[offset + 1])
                    let b = CGFloat(pixels[offset + 2])
                    let diff = sqrt(pow(r - bgColorR, 2) + pow(g - bgColorG, 2) + pow(b - bgColorB, 2))

                    if diff < tolerance {
                        pixels[offset + 3] = 0
                    } else if diff < tolerance * 2 {
                        let alpha = UInt8((diff - tolerance) / tolerance * 255)
                        pixels[offset + 3] = min(pixels[offset + 3], alpha)
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
              let newCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: newCGImage, size: image.size)
    }
}

// MARK: - Hugging Face API Service (备用)

class HuggingFaceService {
    static let shared = HuggingFaceService()
}

// MARK: - Animation Types

enum AnimationType: String, CaseIterable {
    case idle, walk, jump, sit, sleep, click

    var duration: TimeInterval {
        switch self {
        case .idle: return 2.0
        case .walk: return 0.5
        case .jump: return 0.8
        case .sit: return 3.0
        case .sleep: return 10.0
        case .click: return 0.3
        }
    }

    var displayName: String {
        switch self {
        case .idle: return "待机"
        case .walk: return "行走"
        case .jump: return "跳跃"
        case .sit: return "坐下"
        case .sleep: return "睡觉"
        case .click: return "点击"
        }
    }
}

struct FrameTransform: Equatable {
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var rotation: CGFloat = 0.0
    var offsetY: CGFloat = 0.0
    var opacity: CGFloat = 1.0

    static let identity = FrameTransform()

    static func breathing(_ progress: CGFloat) -> FrameTransform {
        let scale = 1.0 + 0.05 * sin(progress * .pi * 2)
        return FrameTransform(scaleX: scale, scaleY: scale)
    }

    static func walking(_ progress: CGFloat) -> FrameTransform {
        let bounce = 8.0 * abs(sin(progress * .pi * 2))
        let tilt = 0.08 * sin(progress * .pi * 4)
        return FrameTransform(rotation: tilt, offsetY: -bounce)
    }

    static func jumping(_ progress: CGFloat) -> FrameTransform {
        let jumpHeight = -80.0 * sin(progress * .pi)
        return FrameTransform(offsetY: jumpHeight)
    }

    static func sitting(_ progress: CGFloat) -> FrameTransform {
        let p = min(progress * 2, 1.0)
        return FrameTransform(scaleX: 1.0 + 0.15 * p, scaleY: 1.0 - 0.2 * p)
    }

    static func sleeping(_ progress: CGFloat) -> FrameTransform {
        let breathScale = 1.0 + 0.03 * sin(progress * .pi * 2)
        return FrameTransform(scaleX: breathScale, scaleY: breathScale, rotation: 0.15, opacity: 0.8)
    }

    static func click(_ progress: CGFloat) -> FrameTransform {
        let scale = 1.0 + 0.25 * sin(progress * .pi)
        return FrameTransform(scaleX: scale, scaleY: scale)
    }
}

// MARK: - Pet State

enum PetState: Int {
    case idle, walking, sitting, sleeping, interacting, jumping

    func possibleTransitions() -> [PetState] {
        switch self {
        case .idle: return [.walking, .sitting, .sleeping]
        case .walking: return [.idle, .sitting]
        case .sitting: return [.idle, .walking, .sleeping]
        case .sleeping: return [.idle, .sitting]
        case .interacting: return [.idle]
        case .jumping: return [.idle]
        }
    }

    var animation: AnimationType {
        switch self {
        case .idle: return .idle
        case .walking: return .walk
        case .sitting: return .sit
        case .sleeping: return .sleep
        case .interacting: return .click
        case .jumping: return .click
        }
    }
}

// MARK: - Pet Controller

/// Main controller for the desktop pet.
/// Manages pet state, animations, behaviors, and user interactions.
/// Coordinates between the pet model and the view layer.
class PetController: ObservableObject {
    @Published var transform: FrameTransform = .identity
    @Published var isSleeping: Bool = false
    @Published var petImage: NSImage?
    @Published var soundText: String? = nil

    var onPositionChange: ((CGPoint) -> Void)?
    var onJump: (() -> Void)?

    private var state: PetState = .idle
    private var animationTimer: Timer?
    private var behaviorTimer: Timer?
    private var soundTimer: Timer?
    private var position: CGPoint = .zero
    private let petSize: CGFloat = 80

    private let sounds = ["吱吱", "啾啾", "咕咕", "吱吱吱", "咕~", "啾!", "噗噗"]
    private let sleepWords = ["💤", "zzZ", "zzz", "呼噜...", "💤💤", "Zzz...", "呼呼~"]

    init() {
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            position = CGPoint(
                x: frame.midX - petSize/2,
                y: frame.midY - petSize/2
            )
        }
        // 默认加载兔子 GIF
        guard let gifURL = resourcePath(named: "兔_idle.gif") else {
            print("Error: Default GIF not found")
            return
        }
        loadGifFrames(from: gifURL)
        startAnimation()
        scheduleBehaviorChange()
        scheduleSound()
    }

    func getWindowPosition() -> CGPoint { position }

    func loadImage(from url: URL) {
        // 检查是否是GIF文件
        if url.pathExtension.lowercased() == "gif" {
            loadGifFrames(from: url)
            return
        }

        guard let image = NSImage(contentsOf: url) else { return }
        // 调整图片大小
        var resized = resizeImage(image, to: LayoutConstants.defaultPetSize)
        // 去除背景
        resized = removeBackground(from: resized)
        DispatchQueue.main.async {
            self.petImage = resized
        }
    }

    // MARK: - GIF 支持

    private var gifFrames: [NSImage] = []
    private var gifTimer: Timer?
    private var currentFrameIndex: Int = 0

    func loadGifFrames(from url: URL) {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Failed to load GIF from \(url.path)")
            return
        }

        // 使用 ImageIO 解析 GIF
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("Error: Failed to create image source from GIF")
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        var frames: [NSImage] = []

        // GIF 显示尺寸
        let displaySize: CGFloat = petSize * 0.5  // 40px

        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                // 直接转换为 RGBA 格式以保留透明度
                if let rgbaImage = cgImage.convertToRGBA() {
                    let nsImage = NSImage(cgImage: rgbaImage, size: NSSize(width: displaySize, height: displaySize))
                    frames.append(nsImage)
                } else {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: displaySize, height: displaySize))
                    frames.append(nsImage)
                }
            }
        }

        if frames.isEmpty {
            // 如果没有帧，当作普通图片处理
            if let image = NSImage(contentsOf: url) {
                let resized = resizeImage(image, to: LayoutConstants.defaultPetSize)
                DispatchQueue.main.async {
                    self.petImage = resized
                }
            }
            return
        }

        gifFrames = frames

        // 开始播放 GIF 动画
        DispatchQueue.main.async {
            self.startGifAnimation()
        }
    }

    private func startGifAnimation() {
        gifTimer?.invalidate()

        if !gifFrames.isEmpty {
            petImage = gifFrames[0]
            currentFrameIndex = 0

            // 默认每帧 100ms
            gifTimer = Timer.scheduledTimer(withTimeInterval: AnimationConstants.gifFrameRate, repeats: true) { [weak self] _ in
                guard let self = self, !self.gifFrames.isEmpty else { return }
                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.gifFrames.count
                self.petImage = self.gifFrames[self.currentFrameIndex]
            }
        }
    }

    func stopGifAnimation() {
        gifTimer?.invalidate()
        gifTimer = nil
        gifFrames = []
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }

    private func removeBackground(from image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // 创建可变的像素数据
        let dataLength = height * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: dataLength)

        guard let data = dataProvider.data else { return image }
        CFDataGetBytes(data, CFRange(location: 0, length: dataLength), &pixels)

        // 采样四个角落的颜色作为背景色
        let corners = [
            (0, 0),                           // 左上
            (width - 1, 0),                   // 右上
            (0, height - 1),                  // 左下
            (width - 1, height - 1)           // 右下
        ]

        var bgColorR: CGFloat = 0
        var bgColorG: CGFloat = 0
        var bgColorB: CGFloat = 0

        for (x, y) in corners {
            let offset = y * bytesPerRow + x * bytesPerPixel
            if offset + 2 < pixels.count {
                bgColorR += CGFloat(pixels[offset])
                bgColorG += CGFloat(pixels[offset + 1])
                bgColorB += CGFloat(pixels[offset + 2])
            }
        }

        bgColorR /= 4
        bgColorG /= 4
        bgColorB /= 4

        // 容差范围
        let tolerance: CGFloat = 30

        // 遍历所有像素，将接近背景色的像素设为透明
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if offset + 3 < pixels.count {
                    let r = CGFloat(pixels[offset])
                    let g = CGFloat(pixels[offset + 1])
                    let b = CGFloat(pixels[offset + 2])

                    // 计算与背景色的差异
                    let diff = sqrt(pow(r - bgColorR, 2) + pow(g - bgColorG, 2) + pow(b - bgColorB, 2))

                    if diff < tolerance {
                        // 接近背景色，设为透明
                        pixels[offset + 3] = 0
                    } else if diff < tolerance * 2 {
                        // 边缘部分，半透明
                        let alpha = UInt8((diff - tolerance) / tolerance * 255)
                        pixels[offset + 3] = min(pixels[offset + 3], alpha)
                    }
                }
            }
        }

        // 创建新图像
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
              let newCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: newCGImage, size: image.size)
    }

    // MARK: - Animation

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: AnimationConstants.animationFrameRate, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }

    private var animationStartTime: Date = Date()

    private func updateAnimation() {
        // 跳跃状态由 handleDoubleClick 单独处理
        guard state != .jumping else { return }

        let elapsed = Date().timeIntervalSince(animationStartTime)
        let duration = state.animation.duration
        let progress = CGFloat((elapsed.truncatingRemainder(dividingBy: duration)) / duration)

        switch state {
        case .idle: transform = .breathing(progress)
        case .walking: transform = .walking(progress)
        case .sitting: transform = .sitting(progress)
        case .sleeping:
            transform = .sleeping(progress)
            isSleeping = true
        case .interacting: transform = .click(progress)
        case .jumping: break
        }

        if state != .sleeping { isSleeping = false }
    }

    // MARK: - Behavior

    private func scheduleBehaviorChange() {
        behaviorTimer?.invalidate()
        let interval = TimeInterval.random(in: 3...8)
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.changeBehavior()
        }
    }

    private func scheduleSound() {
        soundTimer?.invalidate()
        let interval = TimeInterval.random(in: 5...15)
        soundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.playRandomSound()
            self?.scheduleSound()
        }
    }

    private func playRandomSound() {
        // 睡觉时不触发随机文字（showSleepingText 已处理）
        guard !isSleeping else { return }

        // 醒着时显示叫声
        soundText = sounds.randomElement()

        // 2秒后清除文字
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.soundDisplayDuration) { [weak self] in
            self?.soundText = nil
        }
    }

    private func changeBehavior() {
        guard state != .interacting else {
            scheduleBehaviorChange()
            return
        }
        if let newState = state.possibleTransitions().randomElement() {
            transitionTo(newState)
        }
        scheduleBehaviorChange()
    }

    func transitionTo(_ newState: PetState) {
        state = newState
        animationStartTime = Date()
        if newState == .walking { startWalking() } else { stopWalking() }

        // 进入睡觉状态时立即显示睡觉文字
        if newState == .sleeping {
            showSleepingText()
        }
    }

    private func showSleepingText() {
        soundText = sleepWords.randomElement()

        // 每2秒刷新一次睡觉文字
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.soundDisplayDuration) { [weak self] in
            guard self?.state == .sleeping else { return }
            self?.showSleepingText()
        }
    }

    // MARK: - Movement

    private var walkTimer: Timer?
    private var targetPosition: CGPoint?

    private func startWalking() {
        pickNewTarget()
        walkTimer = Timer.scheduledTimer(withTimeInterval: AnimationConstants.animationFrameRate, repeats: true) { [weak self] _ in
            self?.updateWalking()
        }
    }

    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
    }

    private func pickNewTarget() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        targetPosition = CGPoint(
            x: CGFloat.random(in: frame.minX...(frame.maxX - petSize)),
            y: CGFloat.random(in: frame.minY...(frame.maxY - petSize))
        )
    }

    private func updateWalking() {
        guard let target = targetPosition else { pickNewTarget(); return }
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = sqrt(dx*dx + dy*dy)

        if distance < 5 { pickNewTarget(); return }

        let speed: CGFloat = 1.5
        position.x += (dx / distance) * speed
        position.y += (dy / distance) * speed
        onPositionChange?(position)
    }

    // MARK: - Interaction

    func handleClick() {
        guard state != .interacting else { return }
        state = .interacting
        animationStartTime = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.jumpAnimationDuration) { [weak self] in
            self?.transitionTo(.idle)
            self?.scheduleBehaviorChange()
        }
    }

    func handleDoubleClick() {
        guard state != .jumping && state != .interacting else { return }
        state = .jumping

        let jumpDuration: TimeInterval = 0.5
        let startTime = Date()
        let originalPosition = position

        // 停止行走
        stopWalking()
        behaviorTimer?.invalidate()

        // 跳跃动画 - 移动窗口位置
        walkTimer = Timer.scheduledTimer(withTimeInterval: AnimationConstants.animationFrameRate, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = CGFloat(elapsed / jumpDuration)

            if progress >= 1.0 {
                timer.invalidate()
                self.transform = .identity
                self.position = originalPosition
                self.onPositionChange?(self.position)
                self.transitionTo(.idle)
                self.scheduleBehaviorChange()
                return
            }

            // 跳跃高度曲线
            let jumpHeight: CGFloat = 100
            let yOffset = jumpHeight * sin(progress * .pi)

            // 更新窗口位置（向上跳）
            self.position = CGPoint(x: originalPosition.x, y: originalPosition.y + yOffset)
            self.onPositionChange?(self.position)

            // 压缩拉伸效果
            let squash: CGFloat
            if progress < 0.2 {
                squash = 1.0 + 0.2 * (progress / 0.2)
            } else if progress > 0.8 {
                squash = 1.0 + 0.2 * ((1.0 - progress) / 0.2)
            } else {
                squash = 1.0
            }
            self.transform = FrameTransform(scaleX: squash, scaleY: 2.0 - squash)
        }
    }

    func beginDrag() {
        behaviorTimer?.invalidate()
        stopWalking()
    }

    func updateDrag(to newLocation: CGPoint, offset: CGPoint) {
        position = CGPoint(x: newLocation.x - offset.x, y: newLocation.y - offset.y)
        onPositionChange?(position)
    }

    func endDrag() {
        transitionTo(.idle)
        scheduleBehaviorChange()
    }
}

// MARK: - Pet View

struct PetViewContent: View {
    @ObservedObject var controller: PetController
    @State private var jumpOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // 背景色：透明

            // 叫声文字气泡
            if let sound = controller.soundText {
                Text(sound)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .offset(y: -100)  // 显示在宠物上方
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(10)
            }

            if let image = controller.petImage {
                // 自定义图片 - 使用固定尺寸显示
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
                    .scaleEffect(x: controller.transform.scaleX, y: controller.transform.scaleY)
                    .rotationEffect(.radians(Double(controller.transform.rotation)))
                    .offset(y: controller.transform.offsetY)
                    .opacity(controller.transform.opacity)
            } else {
                // 默认粉色宠物
                // Pet body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.95), Color.pink.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(x: controller.transform.scaleX, y: controller.transform.scaleY)
                    .rotationEffect(.radians(Double(controller.transform.rotation)))
                    .offset(y: controller.transform.offsetY + jumpOffset)
                    .opacity(controller.transform.opacity)

                // Eyes
                HStack(spacing: 25) {
                    EyeView(isSleeping: controller.isSleeping)
                    EyeView(isSleeping: controller.isSleeping)
                }
                .offset(y: 5)
                .scaleEffect(x: controller.transform.scaleX, y: controller.transform.scaleY)
                .offset(y: controller.transform.offsetY + jumpOffset)

                // Blush
                HStack {
                    Circle().fill(Color.red.opacity(0.25)).frame(width: 18, height: 10)
                    Spacer()
                    Circle().fill(Color.red.opacity(0.25)).frame(width: 18, height: 10)
                }
                .frame(width: 80)
                .offset(y: 20)
                .scaleEffect(x: controller.transform.scaleX, y: controller.transform.scaleY)
                .offset(y: controller.transform.offsetY + jumpOffset)

                // Sleep Z's
                if controller.isSleeping {
                    SleepZView()
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: controller.soundText)
        .background(Color.clear)
        .frame(maxWidth: LayoutConstants.mainWindowSize.width, maxHeight: LayoutConstants.mainWindowSize.height)
        .contentShape(Rectangle())
    }
}

struct EyeView: View {
    let isSleeping: Bool

    var body: some View {
        if isSleeping {
            Capsule()
                .fill(Color.black)
                .frame(width: 12, height: 3)
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                )
        }
    }
}

struct SleepZView: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        VStack {
            HStack(spacing: 3) {
                Text("Z").font(.system(size: 10, weight: .bold)).opacity(opacity * 0.5).offset(y: offset)
                Text("Z").font(.system(size: 14, weight: .bold)).opacity(opacity * 0.7).offset(y: offset + 5)
                Text("Z").font(.system(size: 18, weight: .bold)).opacity(opacity).offset(y: offset + 10)
            }
            .foregroundColor(.gray)
            .offset(x: 35, y: -45)
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                offset = -15
                opacity = 1
            }
        }
    }
}

// MARK: - Interaction View (NSView for proper mouse handling)

class PetInteractionView: NSView {
    private var hostingView: NSHostingView<PetViewContent>?
    private weak var controller: PetController?
    private weak var windowRef: NSWindow?
    private var isDragging = false
    private var dragOffset = CGPoint.zero
    private var lastClickTime: Date?

    init(controller: PetController, window: NSWindow) {
        self.controller = controller
        self.windowRef = window
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = .clear

        let hosting = NSHostingView(rootView: PetViewContent(controller: controller))
        hosting.frame = NSRect(origin: .zero, size: LayoutConstants.mainWindowSize)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        addSubview(hosting)
        self.hostingView = hosting
    }

    /// NSCoding is not supported for this view.
    /// This view is initialized programmatically via `init(controller:window:)`.
    /// If you need to use this view in a NIB/Storyboard, implement NSCoding support.
    required init?(coder: NSCoder) {
        // NSCoding/NIB loading is not supported - use init(controller:window:) instead
        return nil
    }


    override func mouseDown(with event: NSEvent) {
        let now = Date()
        let clickCount = event.clickCount

        // 使用系统的 clickCount 来判断单击/双击

        let clickLocation = event.locationInWindow

        }
        if clickCount == 2 {
            // 双击 - 直接处理，取消延迟的单击
            lastClickTime = nil
            controller?.handleDoubleClick()
        } else if clickCount == 1 {
            lastClickTime = now
            // 延迟处理单击，等待可能的第二次点击
            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.clickDelay) { [weak self] in
                if self?.lastClickTime != nil {
                    self?.controller?.handleClick()
                    self?.lastClickTime = nil
                }
            }
        }

        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        // 只有在拖拽开始后才处理
        if !isDragging {
            isDragging = true
            controller?.beginDrag()
        }

        guard let window = windowRef else { return }
        let mouseLocation = NSEvent.mouseLocation
        let newOffset = CGPoint(
            x: dragOffset.x,
            y: window.frame.height - dragOffset.y
        )
        controller?.updateDrag(to: mouseLocation, offset: newOffset)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            controller?.endDrag()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let jumpItem = NSMenuItem(title: "跳跃", action: #selector(doJump), keyEquivalent: "")
        jumpItem.target = self
        menu.addItem(jumpItem)

        menu.addItem(NSMenuItem.separator())

        // 动作切换菜单
        let actionMenu = NSMenu()
        let actionMenuItem = NSMenuItem(title: "动作", action: nil, keyEquivalent: "")

        for animType in AnimationType.allCases {
            let item = NSMenuItem(title: animType.displayName, action: #selector(switchAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = animType
            actionMenu.addItem(item)
        }

        menu.setSubmenu(actionMenu, for: actionMenuItem)
        menu.addItem(actionMenuItem)

        menu.addItem(NSMenuItem.separator())

        let imageItem = NSMenuItem(title: "更换图片...", action: #selector(selectImage), keyEquivalent: "")
        imageItem.target = self
        menu.addItem(imageItem)

        let resetItem = NSMenuItem(title: "恢复默认", action: #selector(resetImage), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // AI 动画生成
        let aiMenu = NSMenu()
        let aiMenuItem = NSMenuItem(title: "动画", action: nil, keyEquivalent: "")

        let testItem = NSMenuItem(title: "本地测试动画 (无需API)", action: #selector(testLocalAnimation), keyEquivalent: "")
        testItem.target = self
        aiMenu.addItem(testItem)

        aiMenu.addItem(NSMenuItem.separator())

        let setApiKeyItem = NSMenuItem(title: "设置 API Key...", action: #selector(setApiKey), keyEquivalent: "")
        setApiKeyItem.target = self
        aiMenu.addItem(setApiKeyItem)

        let generateItem = NSMenuItem(title: "AI 生成动画帧", action: #selector(generateAnimation), keyEquivalent: "")
        generateItem.target = self
        aiMenu.addItem(generateItem)

        let clearCacheItem = NSMenuItem(title: "清除动画缓存", action: #selector(clearAnimationCache), keyEquivalent: "")
        clearCacheItem.target = self
        aiMenu.addItem(clearCacheItem)

        menu.setSubmenu(aiMenu, for: aiMenuItem)
        menu.addItem(aiMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func testLocalAnimation() {
        guard controller?.petImage != nil else {
            showAlert(title: "提示", message: "请先选择一张宠物图片")
            return
        }

        // 本地动画已经在运行中，无需额外操作
        // 动画效果由 PetController 的 FrameTransform 实时渲染
        // 保持用户选择的原图不变

        // 强制切换几个动作展示效果
        controller?.transitionTo(.walking)

        DispatchQueue.main.asyncAfter(deadline: .now() + NetworkConstants.retryDelay) {
            self.controller?.transitionTo(.sleeping)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + NetworkConstants.longRetryDelay) {
            self.controller?.transitionTo(.idle)
        }

        showAlert(title: "动画测试", message: "动画效果正在运行！\n\n宠物会依次展示：\n• 行走动画 (3秒)\n• 睡觉动画 (3秒)\n• 返回待机\n\n图片保持原样不变。")
    }

    @objc private func clearAnimationCache() {
        AnimationCache.shared.clearCache()
        showAlert(title: "完成", message: "动画缓存已清除")
    }

    @objc private func doJump() {
        controller?.handleDoubleClick()
    }

    @objc private func switchAction(_ sender: NSMenuItem) {
        guard let animType = sender.representedObject as? AnimationType else { return }
        loadActionGIF(animType)
    }

    private func loadActionGIF(_ action: AnimationType) {
        let gifName = "兔_\(action.rawValue).gif"
        guard let gifURL = resourcePath(named: gifName) else {
            print("Error: GIF '\(gifName)' not found")
            return
        }
        controller?.loadGifFrames(from: gifURL)
    }

    @objc private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            controller?.loadImage(from: url)
        }
    }

    @objc private func resetImage() {
        // Reset to default idle animation (reloads default GIF)
        guard let gifURL = resourcePath(named: "兔_idle.gif") else {
            print("Error: Default GIF not found")
            return
        }
        controller?.loadGifFrames(from: gifURL)
    }

    @objc private func setApiKey() {
        // 创建设置窗口
        let alert = NSAlert()
        alert.messageText = "设置 AI API"
        alert.informativeText = "选择 AI 提供商并输入 API Key\n\n支持的提供商:\n• OpenAI (DALL-E)\n• DeepSeek\n• Moonshot\n• 智谱 AI"
        alert.alertStyle = .informational

        // 创建自定义视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 80))

        // 提供商选择
        let providerLabel = NSTextField(labelWithString: "提供商:")
        providerLabel.frame = NSRect(x: 0, y: 55, width: 80, height: 20)
        containerView.addSubview(providerLabel)

        let providerPopup = NSPopUpButton(frame: NSRect(x: 85, y: 52, width: 260, height: 25))
        for provider in AIProvider.allCases {
            providerPopup.addItem(withTitle: provider.rawValue)
        }
        providerPopup.selectItem(withTitle: AIAnimationService.shared.provider.rawValue)
        containerView.addSubview(providerPopup)

        // API Key 输入
        let keyLabel = NSTextField(labelWithString: "API Key:")
        keyLabel.frame = NSRect(x: 0, y: 25, width: 80, height: 20)
        containerView.addSubview(keyLabel)

        let keyField = NSSecureTextField(frame: NSRect(x: 85, y: 22, width: 260, height: 24))
        keyField.stringValue = AIAnimationService.shared.apiKey
        containerView.addSubview(keyField)

        alert.accessoryView = containerView

        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            if let selectedTitle = providerPopup.selectedItem?.title,
               let provider = AIProvider(rawValue: selectedTitle) {
                AIAnimationService.shared.provider = provider
            }
            AIAnimationService.shared.apiKey = keyField.stringValue
        }
    }

    @objc private func generateAnimation() {
        guard let image = controller?.petImage else {
            showAlert(title: "提示", message: "请先选择一张宠物图片")
            return
        }

        guard !AIAnimationService.shared.apiKey.isEmpty else {
            showAlert(title: "提示", message: "请先设置 AI API Key")
            return
        }

        // 显示进度窗口
        let progressAlert = NSAlert()
        progressAlert.messageText = "生成中..."
        progressAlert.informativeText = "正在调用 AI 生成动画帧，请稍候...\n这可能需要 30-60 秒"
        progressAlert.alertStyle = .informational
        progressAlert.addButton(withTitle: "取消")

        // 异步执行
        let actions = ["idle", "walk", "jump", "sleep", "sit"]
        var completedCount = 0
        let totalCount = actions.count

        for action in actions {
            // 检查缓存
            if AnimationCache.shared.hasCache(for: image, action: action) {
                completedCount += 1
                if completedCount == totalCount {
                    DispatchQueue.main.async {
                        self.showAlert(title: "完成", message: "所有动画帧已从缓存加载！")
                    }
                }
                continue
            }

            AIAnimationService.shared.generateFrames(for: image, action: action, progress: { status in
                // 进度更新
            }, completion: { frames in
                completedCount += 1
                DispatchQueue.main.async {
                    if completedCount == totalCount {
                        if let firstFrames = AnimationCache.shared.loadFrames(for: image, action: "idle"),
                           let firstFrame = firstFrames.first {
                            self.controller?.petImage = firstFrame
                        }
                        self.showAlert(title: "完成", message: "动画帧生成成功！\n已缓存到本地，下次无需重新生成。")
                    }
                }
            })
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Pet Window

/// A borderless, transparent window for displaying the desktop pet.
/// Configured to float above other windows and be visible on all spaces.
class PetWindow: NSWindow {
    init(position: CGPoint) {
        // 设置足够大的窗口尺寸来容纳各种图片
        let size = LayoutConstants.mainWindowSize
        super.init(
            contentRect: NSRect(origin: position, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating  // 始终浮在上面
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false

        // 确保窗口可见
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}

// MARK: - CGImage Extension for RGBA Conversion

extension CGImage {
    func convertToRGBA() -> CGImage? {
        let width = self.width
        let height = self.height

        // 创建 RGBA 上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bytesPerRow = width * 4

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // 绘制原图到 RGBA 上下文，自动处理透明度
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }
}

// MARK: - App Delegate

/// Application delegate for the desktop pet.
/// Sets up the main window, status bar menu, and handles app lifecycle events.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow?
    private var petController: PetController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pet")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu

        petController = PetController()
        let initialPos = petController!.getWindowPosition()
        petWindow = PetWindow(position: initialPos)

        let petView = PetInteractionView(controller: petController!, window: petWindow!)
        petWindow?.contentView = petView

        petController?.onPositionChange = { [weak self] position in
            self?.petWindow?.setFrameOrigin(position)
        }

        petWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - App Entry

_ = NSApplication.shared
NSApp.setActivationPolicy(.accessory)
let delegate = AppDelegate()
NSApp.delegate = delegate
NSApp.run()

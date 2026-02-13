import Foundation
import CoreGraphics
import AppKit
import ImageIO
import UniformTypeIdentifiers

class LocalImageProcessor {

    // 从静态图片生成动画帧
    func generateAnimationFrames(from image: NSImage, for animationType: AnimationType) -> [AnimationFrame] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let frameCount = animationType.frameCount
        var frames: [AnimationFrame] = []

        for i in 0..<frameCount {
            let progress = CGFloat(i) / CGFloat(frameCount)
            let transform = calculateTransform(for: animationType, progress: progress)
            let frameDuration = animationType.duration / Double(frameCount)

            // 生成变换后的图像
            if let transformedImage = applyTransform(cgImage, transform: transform) {
                let frame = AnimationFrame(
                    image: transformedImage,
                    transform: transform,
                    duration: frameDuration
                )
                frames.append(frame)
            }
        }

        return frames
    }

    // 为所有动画类型预生成帧
    func generateAllAnimationFrames(from image: NSImage) -> [AnimationType: [AnimationFrame]] {
        var allFrames: [AnimationType: [AnimationFrame]] = [:]

        for animationType in AnimationType.allCases {
            allFrames[animationType] = generateAnimationFrames(from: image, for: animationType)
        }

        return allFrames
    }

    // 计算指定动画类型的变换
    private func calculateTransform(for animationType: AnimationType, progress: CGFloat) -> FrameTransform {
        switch animationType {
        case .idle:
            return .breathing(progress)
        case .walk:
            return .walking(progress)
        case .jump:
            return .jumping(progress)
        case .sit:
            return .sitting(min(progress * 2, 1.0))
        case .sleep:
            return .sleeping(progress)
        case .click:
            return .click(progress)
        case .drag:
            return .identity
        }
    }

    // 应用变换到图像
    private func applyTransform(_ image: CGImage, transform: FrameTransform) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        // 计算变换后的尺寸
        let newWidth = width * abs(transform.scaleX)
        let newHeight = height * abs(transform.scaleY)

        // 创建位图上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 清除背景（透明）
        context.clear(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        // 设置透明度
        context.setAlpha(transform.opacity)

        // 应用变换
        context.translateBy(x: newWidth / 2, y: newHeight / 2)
        context.rotate(by: transform.rotation)
        context.scaleBy(x: transform.scaleX, y: transform.scaleY)
        context.translateBy(x: -width / 2 + transform.offsetX, y: -height / 2 + transform.offsetY)

        // 绘制图像
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    // 调整图像大小
    func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }

    // 移除背景（简单实现 - 将近白色变透明）
    func removeBackground(from image: NSImage, tolerance: CGFloat = 0.1) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return nil
        }

        let length = CFDataGetLength(data)
        var buffer = [UInt8](repeating: 0, count: length)
        CFDataGetBytes(data, CFRange(location: 0, length: length), &buffer)

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        // 遍历像素，将近白色变透明
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                if offset + 3 <= buffer.count {
                    let r = CGFloat(buffer[offset]) / 255.0
                    let g = CGFloat(buffer[offset + 1]) / 255.0
                    let b = CGFloat(buffer[offset + 2]) / 255.0

                    // 如果接近白色，设为透明
                    if r > (1.0 - tolerance) && g > (1.0 - tolerance) && b > (1.0 - tolerance) {
                        buffer[offset + 3] = 0 // Alpha
                    }
                }
            }
        }

        // 创建新图像
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
              let newCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: newCGImage, size: image.size)
    }

    // 创建简单动画效果（摇晃）
    func createWobbleAnimation(from image: NSImage, frameCount: Int = 6) -> [NSImage] {
        var frames: [NSImage] = []

        for i in 0..<frameCount {
            let angle = CGFloat(sin(Double(i) / Double(frameCount) * .pi * 2)) * 0.1
            if let rotated = rotateImage(image, by: angle) {
                frames.append(rotated)
            }
        }

        return frames
    }

    // 旋转图像
    private func rotateImage(_ image: NSImage, by angle: CGFloat) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // 计算旋转后的尺寸
        let newSize = CGSize(
            width: abs(width * cos(angle)) + abs(height * sin(angle)),
            height: abs(width * sin(angle)) + abs(height * cos(angle))
        )

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
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: angle)
        context.draw(cgImage, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))

        guard let newCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: newCGImage, size: newSize)
    }
}

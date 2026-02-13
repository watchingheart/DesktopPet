import SwiftUI
import AppKit

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if let image = viewModel.petImage {
                PetImageView(
                    image: image,
                    transform: viewModel.currentTransform,
                    facingRight: viewModel.facingRight
                )
            } else {
                PlaceholderPetView()
            }

            // 睡觉时的 ZZZ 效果
            if viewModel.currentState == .sleeping {
                SleepEffectView()
            }
        }
        .frame(width: 150, height: 150)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        if let window = NSApp.windows.first(where: { $0.contentView?.subviews.contains { $0.subviews.contains { ($0 as? NSHostingView<PetView>) != nil } } == true }) {
                            viewModel.beginDrag(at: NSEvent.mouseLocation, in: window)
                        }
                    }
                    viewModel.continueDrag(at: NSEvent.mouseLocation)
                }
                .onEnded { _ in
                    isDragging = false
                    viewModel.endDrag()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded { _ in
                    if let window = NSApp.windows.first(where: { $0.contentView?.subviews.contains { $0.subviews.contains { ($0 as? NSHostingView<PetView>) != nil } } == true }) {
                        viewModel.handleClick(at: NSEvent.mouseLocation, in: window)
                    }
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    // 双击处理已在 ViewModel 中处理
                }
        )
        .onContinuousHover { phase in
            // 可以添加悬停效果
        }
    }
}

// 宠物图像视图
struct PetImageView: View {
    let image: NSImage
    let transform: FrameTransform
    let facingRight: Bool

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(x: facingRight ? transform.scaleX : -transform.scaleX, y: transform.scaleY)
            .rotationEffect(.radians(Double(transform.rotation)))
            .offset(x: transform.offsetX, y: -transform.offsetY)
            .opacity(transform.opacity)
            .animation(.easeInOut(duration: 0.05), value: transform)
    }
}

// 占位宠物视图
struct PlaceholderPetView: View {
    @State private var bounce: Bool = false

    var body: some View {
        ZStack {
            // 身体
            Circle()
                .fill(Color.pink.opacity(0.9))
                .frame(width: 100, height: 100)

            // 眼睛
            HStack(spacing: 20) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: 2)
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                    )
            }
            .offset(y: 10)

            // 腮红
            HStack {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 20, height: 10)
                    .offset(x: -15)

                Spacer()

                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 20, height: 10)
                    .offset(x: 15)
            }
            .frame(width: 100)
            .offset(y: -5)

            // 嘴巴
            Path { path in
                path.move(to: CGPoint(x: 65, y: 40))
                path.addQuadCurve(
                    to: CGPoint(x: 85, y: 40),
                    control: CGPoint(x: 75, y: 35)
                )
            }
            .stroke(Color.pink, lineWidth: 2)
        }
        .scaleEffect(bounce ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

// 睡觉效果视图
struct SleepEffectView: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        VStack {
            HStack(spacing: 5) {
                Text("Z")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(opacity)
                    .offset(y: offset)

                Text("Z")
                    .font(.system(size: 16, weight: .bold))
                    .opacity(opacity * 0.8)
                    .offset(y: offset + 5)

                Text("Z")
                    .font(.system(size: 20, weight: .bold))
                    .opacity(opacity * 0.6)
                    .offset(y: offset + 10)
            }
            .foregroundColor(.gray)
            .offset(x: 40, y: -60)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                offset = -20
                opacity = 1
            }
        }
    }
}

// 点击效果视图
struct ClickEffectView: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
            .frame(width: 30, height: 30)
            .scaleEffect(scale)
            .opacity(2 - scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 2.0
                }
            }
    }
}

#Preview {
    PetView(viewModel: PetViewModel())
        .frame(width: 200, height: 200)
        .background(Color.clear)
}

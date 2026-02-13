import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingImagePicker = false

    var body: some View {
        TabView {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            BehaviorSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("行为", systemImage: "figure.walk")
                }

            AppearanceSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }

            InteractionSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("交互", systemImage: "hand.tap")
                }
        }
        .frame(width: 400, height: 450)
        .padding()
    }
}

class SettingsViewModel: ObservableObject {
    @Published var configuration: PetConfiguration = ConfigurationManager.shared.configuration

    func save() {
        ConfigurationManager.shared.configuration = configuration
    }

    func reset() {
        configuration = .default
        ConfigurationManager.shared.reset()
    }
}

// MARK: - 通用设置
struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("宠物信息") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("宠物名称:")
                        TextField("小宠物", text: $viewModel.configuration.petName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }

                    Button("选择宠物图片...") {
                        selectPetImage()
                    }
                }
                .padding()
            }

            GroupBox("操作") {
                HStack(spacing: 20) {
                    Button("保存设置") {
                        viewModel.save()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("重置为默认") {
                        viewModel.reset()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }

            Spacer()
        }
    }

    private func selectPetImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .petImageSelected, object: url)
        }
    }
}

// MARK: - 行为设置
struct BehaviorSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("行为权重") {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("待机:")
                        Slider(value: $viewModel.configuration.behaviorWeights.idle, in: 0...1)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorWeights.idle * 100))%")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("行走:")
                        Slider(value: $viewModel.configuration.behaviorWeights.walk, in: 0...1)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorWeights.walk * 100))%")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("坐下:")
                        Slider(value: $viewModel.configuration.behaviorWeights.sit, in: 0...1)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorWeights.sit * 100))%")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("睡觉:")
                        Slider(value: $viewModel.configuration.behaviorWeights.sleep, in: 0...1)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorWeights.sleep * 100))%")
                            .frame(width: 40)
                    }
                }
                .padding()
            }

            GroupBox("行为间隔") {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("最短间隔:")
                        Slider(value: $viewModel.configuration.behaviorIntervals.minInterval, in: 1...10)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorIntervals.minInterval))秒")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("最长间隔:")
                        Slider(value: $viewModel.configuration.behaviorIntervals.maxInterval, in: 5...30)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.behaviorIntervals.maxInterval))秒")
                            .frame(width: 40)
                    }
                }
                .padding()
            }

            Spacer()
        }
    }
}

// MARK: - 外观设置
struct AppearanceSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("显示设置") {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("宠物大小:")
                        Slider(value: $viewModel.configuration.petSize, in: 50...300)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.petSize))")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("透明度:")
                        Slider(value: $viewModel.configuration.appearanceSettings.opacity, in: 0.3...1)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.appearanceSettings.opacity * 100))%")
                            .frame(width: 40)
                    }

                    HStack {
                        Text("缩放:")
                        Slider(value: $viewModel.configuration.appearanceSettings.scale, in: 0.5...2)
                            .frame(width: 150)
                        Text("\(Int(viewModel.configuration.appearanceSettings.scale * 100))%")
                            .frame(width: 40)
                    }

                    Toggle("始终置顶", isOn: $viewModel.configuration.appearanceSettings.alwaysOnTop)

                    Toggle("显示阴影", isOn: $viewModel.configuration.appearanceSettings.showShadow)
                }
                .padding()
            }

            Spacer()
        }
    }
}

// MARK: - 交互设置
struct InteractionSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("交互功能") {
                VStack(alignment: .leading, spacing: 15) {
                    Toggle("启用点击反应", isOn: $viewModel.configuration.interactionSettings.enableClickReaction)

                    Toggle("启用双击跳跃", isOn: $viewModel.configuration.interactionSettings.enableDoubleClick)

                    Toggle("启用拖拽", isOn: $viewModel.configuration.interactionSettings.enableDrag)

                    Toggle("启用鼠标跟随", isOn: $viewModel.configuration.interactionSettings.enableMouseFollow)
                }
                .padding()
            }

            GroupBox("交互说明") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("• 单击宠物：触发点击动画")
                    Text("• 双击宠物：触发跳跃动画")
                    Text("• 拖拽宠物：移动宠物位置")
                    Text("• 右键点击：显示上下文菜单")
                    Text("• 菜单栏图标：快速访问设置")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            }

            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}

# DesktopPet

一个 macOS 桌面宠物应用，使用 SwiftUI + AppKit 构建。

## 项目结构

```
DesktopPet/
├── Package.swift              # Swift Package Manager 配置
├── src/                      # 源代码
│   └── DesktopPet/
│       ├── main.swift         # 主程序入口
│       └── KeychainHelper.swift
├── bin/                      # 可执行文件
│   └── DesktopPet
├── tools/                    # 开发工具
│   ├── pet_animator.py       # Python 动画生成器
│   └── rabbit_output/       # 生成的动画资源
├── animations/              # 动画资源
├── docs/                    # 项目文档
│   ├── KEYCHAIN_SECURITY_NOTES.md
│   └── SECURITY_FIX_SUMMARY.md
├── Tests/                   # 测试文件
└── _archived_xcode_project/ # 已归档的 Xcode 项目
```

## 构建

```bash
# 使用 Swift Package Manager
swift build

# 可执行文件输出到 bin/DesktopPet
```

## 运行

```bash
# 直接运行
./bin/DesktopPet

# 或使用 swift run
swift run
```

## 开发

### Python 动画工具

```bash
cd tools
pip install -r requirements.txt
python pet_animator.py
```

### AI 动画生成

支持以下 AI 提供商：
- 智谱 AI (GLM-4V)
- OpenAI (DALL-E)
- DeepSeek
- Moonshot

在菜单栏选择 "设置" 来配置 API Key。

## 许可证

MIT License

# 宠物动画工具集

## pet_animator.py - 静态图生成动画GIF

### 安装依赖

```bash
pip3 install pillow numpy
```

### 使用方法

```bash
# 生成所有动画（idle, walk, jump, sleep, sit）
python3 pet_animator.py your_pet_image.png

# 只生成特定动画
python3 pet_animator.py your_pet_image.png --action walk

# 指定输出目录
python3 pet_animator.py your_pet_image.png --output ./my_output
```

### 生成的动画

| 动画 | 效果 | 帧数 | 帧间隔 |
|------|------|------|--------|
| idle | 呼吸效果 | 8 | 100ms |
| walk | 弹跳摇摆 | 8 | 80ms |
| jump | 跳跃弧线 | 12 | 50ms |
| sleep | 呼吸+透明 | 12 | 150ms |
| sit | 压缩变扁 | 8 | 100ms |

### 输出示例

```
animations/
├── pet_idle.gif
├── pet_walk.gif
├── pet_jump.gif
├── pet_sleep.gif
└── pet_sit.gif
```

### 功能特点

- ✅ 自动去除白色/纯色背景
- ✅ 保持原图角色形象
- ✅ 多种动画类型
- ✅ 优化的GIF文件大小
- ✅ 支持PNG/JPG输入

### 在桌面宠物中使用

生成的GIF可以：
1. 直接作为宠物图片使用
2. 提取GIF帧用于帧动画
3. 集成到桌面宠物应用中

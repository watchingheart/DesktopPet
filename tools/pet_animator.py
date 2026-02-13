#!/usr/bin/env python3
"""
宠物动画生成器 - 从静态图片生成动画GIF
Pet Animator - Generate animated GIFs from static images
"""

import argparse
import os
import math
from pathlib import Path
from PIL import Image
import numpy as np

class PetAnimator:
    """宠物动画生成器"""

    def __init__(self, input_path: str, output_dir: str = "./animations", size: int = 400, draw_eyes: bool = False):
        self.input_path = input_path
        self.output_dir = output_dir
        self.original_image = None
        self.size = size
        self.draw_eyes = draw_eyes  # 是否绘制动画眼睛

        # 动画配置
        self.config = {
            'idle': {'frames': 8, 'duration': 100},
            'walk': {'frames': 8, 'duration': 80},
            'jump': {'frames': 12, 'duration': 50},
            'sleep': {'frames': 12, 'duration': 150},
            'sit': {'frames': 8, 'duration': 100},
            'blink': {'frames': 6, 'duration': 80},
            'look': {'frames': 8, 'duration': 100},
        }

        self._load_image()
        os.makedirs(self.output_dir, exist_ok=True)

    def _load_image(self):
        """加载并预处理图片（保留透明背景）"""
        img = Image.open(self.input_path)

        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        img.thumbnail((self.size, self.size), Image.LANCZOS)

        # 使用透明画布，不是白色
        canvas = Image.new('RGBA', (self.size, self.size), (0, 0, 0, 0))
        x = (self.size - img.width) // 2
        y = (self.size - img.height) // 2
        canvas.paste(img, (x, y), img)

        self.original_image = canvas
        print(f"📐 图片尺寸: {self.size}x{self.size}")

    def _transform_image(self, scale_x=1.0, scale_y=1.0, rotate=0, offset_y=0, alpha=1.0, eye_offset=(0, 0), eye_scale=1.0):
        """变换图片，支持眼睛动画"""
        img = self.original_image.copy()

        # 缩放
        new_w = int(self.size * scale_x)
        new_h = int(self.size * scale_y)
        img = img.resize((new_w, new_h), Image.LANCZOS)

        # 旋转
        if rotate != 0:
            img = img.rotate(rotate, Image.BICUBIC, expand=True)

        # 创建透明画布（给动画留出额外空间）
        canvas = Image.new('RGBA', (self.size + 40, self.size + 80), (0, 0, 0, 0))

        x = (canvas.width - img.width) // 2
        y = int((canvas.height - img.height) // 2 + offset_y)

        # 调整透明度
        if alpha < 1.0:
            arr = np.array(img)
            arr[:, :, 3] = (arr[:, :, 3] * alpha).astype(np.uint8)
            img = Image.fromarray(arr, 'RGBA')

        canvas.paste(img, (x, y), img)

        # 只有在启用眼睛动画时才绘制眼睛
        if self.draw_eyes and (eye_offset != (0, 0) or eye_scale != 1.0):
            canvas = self._draw_animated_eyes(canvas, eye_offset, eye_scale)

        return canvas

    def _draw_animated_eyes(self, canvas, eye_offset=(0, 0), eye_scale=1.0):
        """绘制动画眼睛"""
        from PIL import ImageDraw
        draw = ImageDraw.Draw(canvas)

        # 眼睛位置（基于图片中心）
        center_x = canvas.width // 2
        center_y = canvas.height // 2 - int(self.size * 0.1)

        # 眼睛参数
        eye_spacing = int(self.size * 0.15)
        eye_size = int(self.size * 0.06) * eye_scale
        pupil_size = int(eye_size * 0.5)

        # 左眼位置
        left_eye_x = center_x - eye_spacing + eye_offset[0]
        # 右眼位置
        right_eye_x = center_x + eye_spacing + eye_offset[0]
        eye_y = center_y + eye_offset[1]

        # 绘制眼白
        draw.ellipse([
            left_eye_x - eye_size, eye_y - eye_size,
            left_eye_x + eye_size, eye_y + eye_size
        ], fill=(255, 255, 255, 255))
        draw.ellipse([
            right_eye_x - eye_size, eye_y - eye_size,
            right_eye_x + eye_size, eye_y + eye_size
        ], fill=(255, 255, 255, 255))

        # 绘制瞳孔
        draw.ellipse([
            left_eye_x - pupil_size, eye_y - pupil_size,
            left_eye_x + pupil_size, eye_y + pupil_size
        ], fill=(30, 30, 30, 255))
        draw.ellipse([
            right_eye_x - pupil_size, eye_y - pupil_size,
            right_eye_x + pupil_size, eye_y + pupil_size
        ], fill=(30, 30, 30, 255))

        # 绘制高光
        highlight_size = int(pupil_size * 0.4)
        draw.ellipse([
            left_eye_x - highlight_size, eye_y - pupil_size - highlight_size,
            left_eye_x, eye_y - pupil_size
        ], fill=(255, 255, 255, 255))
        draw.ellipse([
            right_eye_x - highlight_size, eye_y - pupil_size - highlight_size,
            right_eye_x, eye_y - pupil_size
        ], fill=(255, 255, 255, 255))

        return canvas

    def generate_idle(self):
        """生成待机/呼吸动画"""
        frames = []
        config = self.config['idle']

        for i in range(config['frames']):
            progress = i / config['frames']
            scale = 1.0 + 0.03 * math.sin(progress * 2 * math.pi)
            frame = self._transform_image(scale_x=scale, scale_y=scale)
            frames.append(frame)

        return frames

    def generate_walk(self):
        """生成行走动画"""
        frames = []
        config = self.config['walk']

        for i in range(config['frames']):
            progress = i / config['frames']
            bounce = 3 * math.sin(progress * 2 * math.pi)
            tilt = 3 * math.sin(progress * 4 * math.pi)
            frame = self._transform_image(offset_y=-bounce, rotate=tilt)
            frames.append(frame)

        return frames

    def generate_jump(self):
        """生成跳跃动画"""
        frames = []
        config = self.config['jump']

        for i in range(config['frames']):
            progress = i / config['frames']
            jump_height = 30 * math.sin(progress * math.pi)

            # 压缩拉伸
            if progress < 0.15:
                sx, sy = 1.1, 0.85
            elif progress > 0.85:
                sx, sy = 1.15, 0.8
            else:
                sx, sy = 0.9, 1.15

            frame = self._transform_image(
                scale_x=sx, scale_y=sy,
                offset_y=-jump_height
            )
            frames.append(frame)

        return frames

    def generate_sleep(self):
        """生成睡觉动画"""
        frames = []
        config = self.config['sleep']

        for i in range(config['frames']):
            progress = i / config['frames']
            scale = 1.0 + 0.02 * math.sin(progress * 2 * math.pi)
            alpha = 0.7 + 0.2 * math.cos(progress * 2 * math.pi)
            frame = self._transform_image(scale_x=scale, scale_y=scale, rotate=5, alpha=alpha)
            frames.append(frame)

        return frames

    def generate_sit(self):
        """生成坐下动画"""
        frames = []
        config = self.config['sit']

        for i in range(config['frames']):
            progress = i / config['frames']
            sx = 1.0 + 0.15 * progress
            sy = 1.0 - 0.2 * min(progress * 2, 1.0)
            frame = self._transform_image(scale_x=sx, scale_y=sy)
            frames.append(frame)

        return frames

    def generate_blink(self):
        """生成眨眼动画"""
        frames = []
        config = self.config['blink']

        for i in range(config['frames']):
            progress = i / config['frames']

            # 眨眼：眼睛从大到小再到大
            if progress < 0.5:
                eye_scale = 1.0 - progress * 1.6  # 缩小
            else:
                eye_scale = (progress - 0.5) * 1.6  # 恢复

            eye_scale = max(0.1, eye_scale)  # 最小 10%

            frame = self._transform_image(eye_scale=eye_scale)
            frames.append(frame)

        return frames

    def generate_look(self):
        """生成眼睛看来看去动画"""
        frames = []
        config = self.config['look']

        for i in range(config['frames']):
            progress = i / config['frames']

            # 眼睛左右上下移动
            eye_x = int(self.size * 0.03 * math.sin(progress * 2 * math.pi))
            eye_y = int(self.size * 0.02 * math.cos(progress * 4 * math.pi))

            frame = self._transform_image(eye_offset=(eye_x, eye_y))
            frames.append(frame)

        return frames

    def save_gif(self, frames, action):
        """保存为GIF（透明背景）- 手动创建调色板确保透明度正确"""
        config = self.config.get(action, {'duration': 100})

        base_name = Path(self.input_path).stem
        output_path = os.path.join(self.output_dir, f"{base_name}_{action}.gif")

        # 透明色（品红色）
        transparent_color = (255, 0, 255)

        # 收集所有帧中出现的颜色
        all_colors = set()
        frames_rgb = []
        frames_alpha = []

        for frame in frames:
            if frame.mode != 'RGBA':
                frame = frame.convert('RGBA')

            pixels = np.array(frame)
            rgb_pixels = pixels[:, :, :3].copy()
            alpha_mask = pixels[:, :, 3] < 50
            rgb_pixels[alpha_mask] = transparent_color

            frames_rgb.append(rgb_pixels)
            frames_alpha.append(alpha_mask)

            # 收集唯一颜色（采样以加快速度）
            sample = rgb_pixels.reshape(-1, 3)[::100]  # 每100个像素采一个
            for color in sample:
                all_colors.add(tuple(color))

        # 确保透明色在调色板中
        all_colors.add(transparent_color)

        # 限制为254个颜色（留一个给透明色）
        if len(all_colors) > 254:
            import random
            all_colors = set(random.sample(list(all_colors), 254))
        all_colors.add(transparent_color)

        # 创建调色板
        color_list = list(all_colors)
        if transparent_color in color_list:
            color_list.remove(transparent_color)

        # 限制为255个颜色（留一个给透明色）
        if len(color_list) > 255:
            import random
            color_list = random.sample(color_list, 255)

        # 构建调色板：先放所有颜色，最后放透明色
        palette = []
        for color in color_list:
            palette.extend(list(color))
        palette.extend(list(transparent_color))  # 最后一个索引 = 透明色

        # 计算实际的透明色索引
        actual_trans_idx = len(color_list)

        # 创建颜色到索引的映射（包括透明色）
        # 计算实际的透明色索引（调色板最后一个索引）
        actual_trans_idx = len(color_list)  # 透明色放在调色板末尾

        color_to_idx = {}
        # 先映射透明色到实际索引
        color_to_idx[transparent_color] = actual_trans_idx
        # 然后映射其他颜色
        for i, color in enumerate(color_list):
            color_to_idx[color] = i

        # 转换所有帧
        p_frames = []
        for rgb_pixels, alpha_mask in zip(frames_rgb, frames_alpha):
            height, width = rgb_pixels.shape[:2]

            # 创建索引数组
            indices = np.zeros((height, width), dtype=np.uint8)

            # 将每个像素映射到索引
            for y in range(height):
                for x in range(width):
                    color = tuple(rgb_pixels[y, x])
                    if color in color_to_idx:
                        indices[y, x] = color_to_idx[color]
                    else:
                        # 找最接近的颜色
                        min_dist = float('inf')
                        best_idx = 0
                        for c, idx in color_to_idx.items():
                            dist = abs(c[0] - color[0]) + abs(c[1] - color[1]) + abs(c[2] - color[2])
                            if dist < min_dist:
                                min_dist = dist
                                best_idx = idx
                        indices[y, x] = best_idx

            # 创建 P 模式图像
            p_frame = Image.fromarray(indices, 'P')
            p_frame.putpalette(palette)
            p_frame.info['transparency'] = actual_trans_idx
            p_frames.append(p_frame)

        # 保存 GIF
        p_frames[0].save(
            output_path,
            save_all=True,
            append_images=p_frames[1:],
            duration=config['duration'],
            loop=0,
            disposal=2,
            transparency=actual_trans_idx
        )

        print(f"✅ 已保存: {output_path} (透明背景，共{len(p_frames)}帧)")
        return output_path
        return 0  # 默认返回索引0

    def generate_all(self):
        """生成所有动画"""
        actions = {
            'idle': self.generate_idle,
            'walk': self.generate_walk,
            'jump': self.generate_jump,
            'sleep': self.generate_sleep,
            'sit': self.generate_sit,
            'blink': self.generate_blink,
            'look': self.generate_look,
        }

        print(f"🎨 开始处理: {self.input_path}")
        print(f"📁 输出目录: {self.output_dir}\n")

        for action, generator in actions.items():
            print(f"🔄 生成 {action} 动画...")
            frames = generator()
            self.save_gif(frames, action)

        print("\n🎉 完成！")


def main():
    parser = argparse.ArgumentParser(description='宠物动画生成器')
    parser.add_argument('input', help='输入图片路径')
    parser.add_argument('--output', '-o', default='./animations', help='输出目录')
    parser.add_argument('--action', '-a', default='all',
                       choices=['idle', 'walk', 'jump', 'sleep', 'sit', 'blink', 'look', 'all'],
                       help='动画类型')
    parser.add_argument('--size', '-s', type=int, default=200, help='输出尺寸 (默认: 200)')
    parser.add_argument('--draw-eyes', action='store_true', help='绘制动画眼睛 (用于无眼睛的模板)')

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"❌ 找不到文件: {args.input}")
        return

    animator = PetAnimator(args.input, args.output, size=args.size, draw_eyes=args.draw_eyes)

    if args.action == 'all':
        animator.generate_all()
    else:
        generator = getattr(animator, f'generate_{args.action}')
        frames = generator()
        animator.save_gif(frames, args.action)


if __name__ == '__main__':
    main()

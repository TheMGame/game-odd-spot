# Odd Spot 后续图片 Prompt 强制标准

## 画布与设备适配

- 默认生成手机竖图：`1024 × 1536`，宽高比 `2:3`。
- 游戏模式为单图“找出时代错误”，不得生成左右对比图。
- 游戏在竖屏和横屏设备上都使用完整显示（contain），不裁切图片。
- 横屏设备允许在图片两侧显示主题背景，不允许为了铺满屏幕裁掉答案。

## 竖屏构图安全区

- 顶部 8%：只放天空、屋檐或不影响答题的环境，避免关键物件。
- 底部 10%：只放地面、桌沿或装饰，避免关键物件。
- 左右各 7%：避免放置微小答案，防止不同设备安全区影响观察。
- 主要人物、场景叙事中心和至少 70% 的答案放在画面中部 70% 区域。
- 答案之间至少保持画布短边 8% 的距离，避免命中区域重叠。
- 不要把答案放在刘海、圆角、系统手势条可能覆盖的位置。

## 难度规则

- 入门：5 个答案；中大型、无遮挡、高颜色反差。
- 简单：5–6 个答案；中型、最多 15% 遮挡。
- 普通：6–8 个答案；中小型、15–25% 遮挡。
- 困难：8 个答案；小型、25–35% 遮挡、颜色融入环境。
- 专家：10 个答案；小型、30–40% 遮挡，至少 3 个需要历史常识。
- 难度不得依靠把物件缩小到无法辨认，也不得使用生成失败或形态错误的物件。

## Prompt 必须包含的英文约束

> Create one single vertical mobile hidden-object game illustration, exactly 1024 × 1536, 2:3 portrait composition. Keep every required target fully inside the central safe area. Do not crop any target object. Reserve the top 8%, bottom 10%, and left/right 7% margins for non-essential background. The complete image must remain readable when displayed with contain scaling on both portrait and landscape devices. No split screen, no comparison image, no second panel, no watermark.

## 输出与导入

- 图片命名：`<level_id>.png`。
- 色彩空间：sRGB。
- 答案位置必须在最终生成图片上重新测量，不能直接沿用 Prompt 的预定坐标。
- Admin 保存时将像素热点转换为 0–1 归一化坐标，因此同一关卡可适配不同屏幕方向和分辨率。

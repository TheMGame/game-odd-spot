# 画面真实性与连续性规范

每次写 `prompt.md` 和审核最终图片时执行本规范。历史绘画等非摄影主题仍须
执行“人物面孔”“异常物融合”“非对称构图”和“去重”规则；摄影术语仅用于
写实照片主题。

## 人物面孔

- 禁止清晰正面人脸、证件照式构图和直视镜头。
- 只使用背影、三分之二侧脸、侧脸、低头、帽檐遮挡、前景遮挡或远景小人。
- 人群保持抓拍状态，不整齐排队、不统一微笑、不围绕镜头摆姿势。
- 负面提示必须包含：`frontal face, looking at camera, passport photo pose,
  centered face portrait, staged group portrait`。

## 真实人物与材质

摄影主题必须包含：`natural skin pores, subtle skin texture, slight uneven skin
tone, tiny freckles, messy stray hair strands, slightly wrinkled clothes, minor
blemishes, candid snapshot, unposed natural expression, slight sweat marks`。

静物、建筑和装备加入 `dust, tiny scratches, wear traces, faded fabric, mud
splashes` 中符合场景的部分。不得把所有物体做旧到相同程度。

## 写实光影

- 指定一个主光方向和来源，例如窗外自然光或左后方日光。
- 使用 `single main light source, soft natural shadow, no conflicting shadows,
  partial slight overexposure, dark shadow area retains detail, natural light
  gradient`。
- 禁止均匀平光、无来源轮廓光、多个方向相反的投影和死黑阴影。

## 镜头、胶片与构图

- 默认写实风格：`shot on Kodak Portra 400 film, 35mm or 50mm fixed focal
  length, slight film grain, subtle lens vignetting, shallow depth of field,
  slight lens softness, muted low saturation colors`。
- 现场新闻或生活场景加入 `mobile phone casual shooting, candid editorial
  snapshot`，但不要极致锐利或 HDR。
- 使用三分法、偏心主体、非对称画框、合理负空间和局部裁切；避免中轴对称、
  人物等距排列和模板化三角构图。

## 异常物融合

- 默认答案约占短边 2.5%–6%，并被正常物件遮挡 25%–40%。
- 优先让答案卡在绑带、货物、桌面杂物、工具堆、衣物或建筑结构中。
- 颜色、材质颗粒、透视、光源、阴影和清晰度必须与周围一致。
- 禁止孤立陈列、统一朝向、等距分布、规则网格、异常物自发光或过度鲜艳。
- 大型答案只有在语义必需且能被场景合理遮挡时使用；不得靠荒诞尺寸提高辨识度。
- 第一次目视必须先读成正常场景，放大后才发现异常；若异常物先于主题被注意，
  必须缩小、降对比、增加自然遮挡或重新生成。

## 通用负面提示

摄影主题必须加入：

`plastic skin, wax doll face, flawless smooth skin, airbrushed, perfect symmetry,
multiple conflicting light shadows, over-saturated colors, sharp ultra-clear
rendering, deformed hands, extra fingers, text, watermark, cartoon, 3d render,
anime, glowing skin, porcelain texture, dead pure black shadow, frontal face,
looking at camera, passport photo pose, centered face portrait, staged group
portrait, oversized anomaly objects, isolated props, surreal installation,
product display, staged lineup`

## 历史连续性与去重

- 扫描最近 30 关，比较主题、具体地点、主构图、玩法动作和答案物品。
- 同一历史题材续作不得复用旧答案；例如旧关出现手机，新关不得换成不同颜色手机。
- 在 `sources.md` 写出旧答案与新答案清单；普通新主题只需记录发现的近似关卡及规避方式。

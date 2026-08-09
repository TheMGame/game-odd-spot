---
name: generate-daily-trending-challenge
description: Search current domestic trends, select a safe and visually expressive non-sports topic, generate one natural high-difficulty Misplaced Detective image without frontal faces, inspect the finished image for actual answer locations, and produce a validated draft level package. Use for 每日挑战、今日热点关卡、热点找茬、daily challenge, or when one current-event-inspired hidden-object level is requested.
---

# 每日热点挑战生成器

每天只产出一张可用的高难度关卡图。先核实热点，再把热点转化成不依赖真人肖像、商标或大段文字的生活化场景；成图后根据实际画面定位答案，绝不使用提示词里的预估坐标。

## 工作流

### 1. 确定日期和输出目录

- 使用用户指定日期；未指定时使用执行环境的本地日期和时区。
- 输出到当前项目根目录的
  `build/daily-challenges/YYYY-MM-DD/<slug>/`。
- 写入前必须用 `git check-ignore build/daily-challenges` 确认 `build/`
  已被 Git 忽略；若未被忽略，先修正 `.gitignore`，避免每日内容进入版本库。
- 关卡 ID 使用 `daily_YYYYMMDD_<slug>`，`slug` 使用简短英文小写和下划线。
- 一次只生成一张图。只有成图未通过检查时才编辑或重生成，不批量制造候选图。

### 2. 搜索并核实当天热点

必须联网搜索，不能凭记忆判断“当前热点”。先完整阅读
`references/editorial-and-trend-selection.md`，然后：

1. 默认只搜索和选择发生在中国国内的热点事件；用户明确指定其他地区时才扩大范围。
2. 搜索当天或最近 24–48 小时的多个国内热点来源。
3. 对候选热点至少用两个相互独立的可靠来源核实；事实性事件优先使用官方或一手来源。
4. 区分报道发布日期和事件实际发生日期。
5. 选择既有热度、又能转化成丰富视觉场景的主题，而不是只看标题声量。
6. 在 `sources.md` 记录候选、选择理由、淘汰理由、来源标题、链接、发布日期和事件日期。

默认不选择体育主题。优先考虑吃喝玩乐、暑期旅游、夜间文旅、公共文化、
非遗、美食市集、展览和普通城市生活；只有用户明确要求体育时才选择体育。

若当天没有兼具安全性与视觉表现力的热点，选择近期仍在持续的无害公共话题，并在 `sources.md` 明确说明，不要虚构热点。

### 3. 设计高难度关卡

默认设计 8 个答案，难度为 `hard`。用户明确要求专家难度时改为 10 个。

开始设计前，扫描最近 30 个 `build/daily-challenges/*/*/level.json` 和
`prompt.md`，列出近期主题、场景构图和答案物品。新关卡不得重复近期主题的
核心构图；同主题续作必须更换地点、人物活动和全部答案物品，并在
`sources.md` 写明去重记录。

完整阅读 `references/image-quality-and-continuity.md`，把其中的真实性、
小型异常物和人物面孔限制写进本次 `prompt.md`。

- 把热点转化为一个统一、可信、细节密集的场景。
- 玩法默认为“找出不属于该场景、主题或时代的物品”，模式使用 `find_anachronism`。
- 答案物品必须小而可辨识，约 25%–35% 被遮挡或融入相近色环境。
- 异常物优先依附在正常装备、人物穿戴、摊位器具或环境结构中；禁止把转椅、
  台灯等大型孤立道具摆在空地上制造明显的“后贴感”。
- 分散答案位置，避免规则网格、集中在边缘或都落在同一视觉层级。
- 加入合理的相似物、重复纹理和非答案干扰物，但每个答案只能出现一次。
- 不依靠可读文字、品牌标志、名人面孔或新闻截图来识别主题或答案。

按 `references/challenge-contract.md` 写出 `prompt.md` 和初始 `level.json` 草稿。`level.json` 中的答案坐标此时保持待定，不得猜测。

### 4. 生成单张图片

此步骤必须使用 `imagegen` skill。执行前完整阅读其 `SKILL.md`。

- 生成 1024×1536 竖版单幅场景。
- 禁止拼图、左右对比、多面板、答案圈选、箭头、编号、水印和解释文字。
- 首次只生成一张。
- 生成后立即目视检查：整体质量、主题可读性、每个答案是否真实存在且只出现一次、是否有融合或畸形。
- 检查所有人物均无清晰正面人脸。只允许背影、侧脸、低头、远景、被帽檐或
  环境自然遮挡的脸；发现直视镜头或完整正脸时必须定向编辑。
- 按 `references/image-quality-and-continuity.md` 检查皮肤、衣物、光影、镜头、
  构图和异常物融合度。任何塑料皮、冲突阴影、对称摆拍或孤立大件均不通过。
- 若检查失败，优先定向编辑同一张图；仅当整体构图不可救时重生成一张。

### 5. 从成图识别答案坐标

必须查看最终图片本身，再记录热点：

1. 逐一确认实际可见的答案物品。
2. 以图片左上角为原点，计算每个答案中心的归一化坐标：
   `x = pixel_x / image_width`，`y = pixel_y / image_height`。
3. 半径 `radius` 应覆盖物品可点击主体并留少量容错，通常为 `0.025–0.06`。
4. 生成一张仅供审核的 `review.png`，把答案热点圈出并编号；正式图片不得带标记。
5. 若某答案缺失、重复或无法可靠定位，编辑图片或从答案列表移除并补做相应调整，禁止编造坐标。

### 6. 校验并交付草稿

目录至少包含：

- `<level_id>.png`：正式关卡图
- `review.png`：带热点标记的审核图
- `prompt.md`：最终生图提示词
- `sources.md`：热点来源与选题记录
- `level.json`：完整草稿配置

运行：

```powershell
python content-tools/skills/generate-daily-trending-challenge/scripts/validate_daily_challenge.py build/daily-challenges/YYYY-MM-DD/<slug>
```

校验失败时修正并重跑。默认只交付草稿，不自动上传或发布。

如果用户明确要求导入 admin，先完整阅读
`content-tools/skills/publish-oddspot-admin-content/SKILL.md`，再按该 skill 上传资源和配置；不要把 token 写入本 skill 或输出目录。
使用本 skill 的通用 importer：

```powershell
content-tools/skills/publish-oddspot-admin-content/scripts/publish-importer.ps1 `
  -ImporterPath content-tools/skills/generate-daily-trending-challenge/scripts/import_daily_challenge.ps1 `
  -SeriesId daily_task `
  -ExportDir build/daily-challenges/YYYY-MM-DD/<slug>
```

不要再为每个日期创建 `scripts/import-daily-task-YYYYMMDD.ps1`。

## 完成标准

- 热点有可追溯来源，日期正确。
- 只有一张正式候选图。
- 主题安全、视觉明确，不消费悲剧或争议。
- 默认选题为国内非体育内容，并优先吃喝玩乐与文化旅游。
- 不出现清晰正面人脸或直视镜头的人物。
- 画面通过真实性检查，异常物小型、自然遮挡且融入正常场景。
- 已检查近期关卡并记录必要的主题、构图和答案去重信息。
- 默认 8 个高难度答案全部真实存在、唯一且可点击。
- 坐标来自最终成图，审核图与配置一致。
- 校验脚本通过。
- 未经明确要求不发布到线上。
- 关卡图片、来源、答案配置和日期专属发布数据均位于项目
  `build/daily-challenges/` 目录，不进入 Git。

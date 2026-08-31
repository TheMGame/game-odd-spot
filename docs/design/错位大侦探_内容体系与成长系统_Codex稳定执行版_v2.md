# 《错位大侦探》内容体系与成长系统改造方案
## Codex 稳定执行版 v2

> 本版在原方案上新增并明确：章节关联、玩法扩展边界、首页 Lobby、内容生产规范。原则：兼容已上线内容，不破坏旧关卡、旧数据、找穿帮和拼图玩法。

## 1. 产品定位
> 穿梭古今中外，在精美场景中发现不属于这个世界的“错位”。

所有玩法围绕：**视觉观察 → 发现异常 → 调查 / 还原**。不要演变为无关联小游戏合集。

## 2. 内容结构
`World → Chapter → Level → Gameplay`

World 是题材分类，不是玩法分类。

- `daily_mystery` 日常奇案：80
- `ancient_china` 神韵华章 · 千载风华：80
- `world_journey` 环球奇遇：64
- `fantasy_world` 幻境奇闻：40
- `brainstorm` 脑洞异闻录：36

总容量 300 关，不要求一次完成。

## 3. 章节关联规则【新增】
章节采用：**强主题关联 + 中等视觉推进 + 弱剧情关联 + 单关独立成立**。

### 强主题
同章必须围绕同一主题、时代、人物或地点。

### 视觉推进
8 关应形成自然推进。例如《洛神赋》：
`抵达洛水 → 初见洛神 → 洛神显现 → 神女风姿 → 服饰细节 → 凌波洛水 → 人神诀别 → 洛水余梦`

### 弱剧情
每关只需 1～2 句背景，不做复杂对白、剧情树和大量过场。

### 单关独立
任何关卡被每日案件、随机挑战、活动复用时，都必须独立可理解、可完成，不依赖上一关剧情。

## 4. 标准章节
建议 8 关：
1. 建立主题：odd_spot
2. 深入场景：odd_spot
3. 节奏变化：puzzle
4. 扩展主题：odd_spot
5. 中高难：odd_spot
6. 节奏变化：puzzle
7. 高难调查：odd_spot
8. 章节终章：odd_spot / 综合

当前优先 `6 × odd_spot + 2 × puzzle`。

## 5. 玩法策略【更新】
当前正式支持：
- `odd_spot`
- `puzzle`

当前版本不增加第三玩法。先跑顺 `内容世界 → 章节 → 星级 → EXP → 收藏 → 解锁`。

未来如数据证明疲劳，第三玩法优先 `clue_hunt`（线索追踪），如“找到不属于魏晋时代的物品”。之后才考虑 `memory_case`、`scene_judge`。

暂不增加消消乐、连连看、数独、推箱子、合成、卡牌等无关联玩法。

## 6. 《洛神赋》
`world_id: ancient_china`
`chapter_id: luoshen_fu`

| 顺序 | 标题 | 推进 | 类型 |
|---|---|---|---|
|1|洛水初逢|抵达洛水|odd_spot|
|2|翩若惊鸿|初见洛神|odd_spot|
|3|婉若游龙|洛神显现|puzzle|
|4|荣曜秋菊|神女风姿|odd_spot|
|5|云髻峨峨|服饰细节|odd_spot|
|6|罗袜生尘|凌波洛水|puzzle|
|7|人神殊途|人神诀别|odd_spot|
|8|洛水余梦|章节终章|odd_spot|

收藏：`scroll_luoshen / 洛神赋卷`；称号：`翩若惊鸿`。已有 Level ID 必须保留。

## 7. 神韵华章章节
洛神赋、滕王阁序、兰亭集序、桃花源记、岳阳楼记、清明上河图、千里江山图、山海经、敦煌飞天、长安风华。每章建议 8 关。

## 8. 首页 Lobby【新增】
首页优先级：
1. 继续调查
2. 近期目标
3. 今日案件
4. 案件世界
5. 等级 / 星星
6. 收藏预览

结构：
`Logo + Lv/称号/星星/EXP → 继续调查 Hero → 近期目标 → 今日案件 → 案件世界 → 最近收藏 → 案件/博物馆/我的`

首页必须快速回答：**我现在玩什么？为什么继续？还有什么可玩？**

近期目标只显示一个，如“再完成 2 案，获得《洛神赋卷》”。

## 9. 星级 / EXP / 收藏
每关最多 3★：
- 1★ 通关
- 2★ 误点不超过配置
- 3★ odd_spot 不用提示；puzzle 在目标时间内完成

只保存历史最高星级，总星数不可重复累计。

默认 EXP：easy 10 / normal 15 / hard 20 / master 30；首次三星 +5；章节完成 +50。重复通关不重复获得基础 EXP；历史最佳每提升 1★ 可 +5。

收藏入口统一为“大侦探博物馆”，第一版不做碎片。

## 10. 数据模型
World：`id,name,description,cover,sort,enabled`

Chapter：`id,world_id,name,subtitle,description,cover,sort,unlock_type,unlock_value,collection_id,enabled`

Level 新增：`world_id,chapter_id,chapter_order,difficulty,gameplay_type,exp_reward,collection_id,release_status,release_at`

旧关默认：
`world_id=daily_mystery`
`chapter_id=classic_cases`
`difficulty=normal`
`exp_reward=15`
`collection_id=null`

必须建立 `daily_mystery / classic_cases / 经典案件`。

## 11. Admin
内容管理：内容世界 / 章节管理 / 关卡管理。

关卡新增：所属世界、所属章节、章节内排序、难度、EXP、星级规则、收藏奖励。odd_spot 和 puzzle 继续使用现有对应编辑器。

Chapter 建议增加内容生产字段：
`theme_summary, visual_style, story_arc, character_consistency_notes, location_consistency_notes`

并允许记录 8 关规划：`level_order, level_title, scene_summary, gameplay_type, narrative_note`。

## 12. 内容生产规范【更新】
禁止直接“做下一关”。必须：
`确定 World → Chapter → 章节主题 → 规划 8 关推进 → 玩法比例 → 锁定角色/地点/视觉 → 逐关生成 → 后台录入`

同一 Chapter 保持人物、服饰、建筑语言、时代、色彩一致；通过时间、天气、镜头、地点变化制造丰富度。

## 13. 实施顺序
Phase 1 Schema/兼容；Phase 2 Admin；Phase 3 首页/世界/章节；Phase 4 星级；Phase 5 EXP/等级；Phase 6 收藏；Phase 7 每日/每周/限时；Phase 8 数据证明需要后再评估 clue_hunt。

## 14. 稳定性约束
不得重写引擎、登录、资源 Hash、核心算法；不得删除旧字段、批量改 Level ID、升级无关依赖、格式化整个仓库或硬编码示例数据。先扫描实际 Admin/Web/WeChat/Server/Contracts/Catalog，优先复用已有等价模型。每个 Phase 独立构建和回归。

## 15. 最终循环
`首页 → 继续调查/世界 → Chapter → 关联的 8 个案件 → 找穿帮/拼图 → 星级+EXP → Chapter 完成 → 收藏 → 解锁下一章 → 首页新目标`

目标：从“散乱找茬关卡”升级为“具有主题章节、长期成长和收藏驱动的视觉调查游戏”。

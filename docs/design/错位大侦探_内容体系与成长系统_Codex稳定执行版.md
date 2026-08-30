# 《错位大侦探》内容体系与成长系统改造方案
## Codex 稳定执行版

> 目标：在**不推翻现有已上线内容、不破坏现有关卡兼容性**的前提下，将《错位大侦探》从“散关式找穿帮小游戏”升级为具有长期内容规划、章节进度、星级成长、收藏体系和后续持续运营能力的内容型游戏。
>
> 当前核心玩法继续保留：
>
> - 找穿帮 / 找错位（`odd_spot`）
> - 拼图 / 错位还原（`puzzle`）
>
> 本文档用于指导 Codex 修改：
>
> - Admin 后台
> - Web 版本
> - WeChat 微信小游戏版本
> - 服务端 / 数据协议 / Catalog（如项目中已有）
>
> **原则：优先兼容、渐进升级、禁止大规模重构。**

---

# 1. 改造目标

当前游戏核心循环偏短：

```text
进入关卡
↓
找穿帮 / 拼图
↓
通关
↓
下一关
```

问题：

1. 关卡之间缺少内容组织。
2. 用户无法明确感知长期目标。
3. 通关后缺少可积累成果。
4. 新增内容主要体现为“又多了几关”，缺少系列感。
5. 已发布微信版本，不适合推翻现有结构重新实现。
6. 后续中华文化、现代生活、环球、幻想等内容难以统一管理。

本轮改造后的目标循环：

```text
选择内容世界
↓
进入章节 / 卷
↓
挑战关卡
↓
获得星级 / EXP / 收藏进度
↓
推进章节
↓
完成章节收藏
↓
提升侦探等级
↓
解锁更多章节
```

核心 Meta Loop：

```text
玩关卡
→ 获得成长
→ 完成章节
→ 收集内容
→ 解锁新内容
→ 再玩关卡
```

---

# 2. 产品长期定位

《错位大侦探》统一定位为：

> 穿梭古今中外，在精美场景中发现不属于这个世界的“错位”。

“错位”不限制为传统找不同，可长期覆盖：

- 时代错误
- 物品错误
- 人物行为错误
- 服饰错误
- 建筑错误
- 动植物错误
- 文字 / 符号错误
- 物理逻辑错误
- 空间错位
- 拼图错位
- 超现实脑洞

---

# 3. 总体内容结构

内容层级统一调整为：

```text
World（内容世界 / 大系列）
    ↓
Chapter（章节 / 卷 / 案件系列）
    ↓
Level（具体关卡）
    ↓
Gameplay（找穿帮 / 拼图）
```

禁止再把所有关卡直接作为一个完全扁平列表维护。

---

# 4. 内容世界规划

第一阶段支持以下 5 个主要内容世界。

## 4.1 日常奇案

```text
id: daily_mystery
name: 日常奇案
```

定位：

- 城市
- 校园
- 办公室
- 商场
- 地铁
- 医院
- 公园
- 夜市
- 酒店
- 机场
- 家庭生活

主要承担：

- 高频更新
- 大众内容
- 低制作成本
- 日常留存

第一阶段目标：

```text
80 关
```

---

## 4.2 神韵华章 · 千载风华

```text
id: ancient_china
name: 神韵华章 · 千载风华
```

定位：

- 中华文化
- 古诗词
- 古文名篇
- 名画
- 历史
- 神话
- 非遗

这是游戏精品内容线，也是后续差异化重点。

第一阶段目标：

```text
80 关
```

章节建议：

```text
洛神赋
滕王阁序
兰亭集序
桃花源记
岳阳楼记
清明上河图
千里江山图
山海经
敦煌飞天
长安风华
```

每章建议：

```text
8 关
```

---

## 4.3 环球奇遇

```text
id: world_journey
name: 环球奇遇
```

定位：

- 世界城市
- 文化地标
- 旅行场景
- 当地特色

第一阶段目标：

```text
64 关
```

建议章节：

```text
日本奇遇
巴黎迷踪
纽约奇案
埃及秘闻
罗马往事
伦敦谜踪
迪拜奇遇
伊斯坦布尔
```

每章：

```text
8 关
```

---

## 4.4 幻境奇闻

```text
id: fantasy_world
name: 幻境奇闻
```

定位：

- 神话
- 奇幻
- 魔法
- 妖怪
- 架空世界

第一阶段目标：

```text
40 关
```

---

## 4.5 脑洞异闻录

```text
id: brainstorm
name: 脑洞异闻录
```

定位：

- 搞笑
- 反常识
- 穿越
- 荒诞
- 易传播题材

示例：

```text
如果古人有手机
恐龙上班
猫统治人类
古代世界杯
动物上学
外星人逛超市
未来人穿越唐朝
```

第一阶段目标：

```text
36 关
```

---

# 5. 第一阶段总关卡容量

规划容量：

| 内容世界 | 关卡数 |
|---|---:|
| 日常奇案 | 80 |
| 神韵华章 · 千载风华 | 80 |
| 环球奇遇 | 64 |
| 幻境奇闻 | 40 |
| 脑洞异闻录 | 36 |
| **总计** | **300** |

注意：

> 300 关是内容规划容量，不要求当前版本一次性制作完成。

后台和客户端的数据结构需要提前支持该规模。

---

# 6. 章节标准

推荐绝大多数章节统一使用：

```text
8 关 / Chapter
```

标准玩法节奏：

```text
第 1 关：简单找穿帮
第 2 关：普通找穿帮
第 3 关：拼图
第 4 关：普通找穿帮
第 5 关：中高难找穿帮
第 6 关：拼图
第 7 关：高难找穿帮
第 8 关：章节终章 / 综合关
```

推荐比例：

```text
6 个 odd_spot
2 个 puzzle
```

或：

```text
5 个普通 odd_spot
2 个 puzzle
1 个高难综合 odd_spot
```

不建议把拼图独立成完全分离的主游戏。

拼图应该作为各个内容章节中的节奏变化。

---

# 7. 现有《洛神赋》内容归档

现有中华文化第一关 / 第一批内容统一归入：

```text
World:
ancient_china
神韵华章 · 千载风华
```

第一章节：

```text
chapter_id: luoshen_fu
chapter_name: 洛神赋
```

建议完整扩展为：

| 顺序 | 标题 | 类型 |
|---|---|---|
| 1 | 洛水初逢 | odd_spot |
| 2 | 翩若惊鸿 | odd_spot |
| 3 | 婉若游龙 | puzzle |
| 4 | 荣曜秋菊 | odd_spot |
| 5 | 云髻峨峨 | odd_spot |
| 6 | 罗袜生尘 | puzzle |
| 7 | 人神殊途 | odd_spot |
| 8 | 洛水余梦 | odd_spot |

章节收藏奖励：

```text
collection_id: scroll_luoshen
collection_name: 洛神赋卷
```

章节称号：

```text
title_reward: 翩若惊鸿
```

现有已经上线的洛神赋关卡不得删除。

如果现有 ID 已经存在：

> 保留现有 level ID，只补充新的 `world_id` 和 `chapter_id`。

---

# 8. 现有关卡兼容原则

这是本次修改最重要的约束之一。

## 禁止行为

Codex 不得：

- 批量重命名现有 level ID。
- 删除旧字段。
- 强制所有旧关卡立即补齐全部新字段。
- 修改现有资源路径导致线上资源失效。
- 更换旧关卡的玩法逻辑。
- 大规模调整原有 API。
- 因新系统导致旧客户端无法加载 Catalog。
- 把找穿帮和拼图重新写成一套完全不同架构。

## 必须支持旧数据默认值

如果旧关卡没有：

```text
world_id
chapter_id
difficulty
exp_reward
collection_id
```

客户端和服务端必须使用默认值。

建议：

```text
world_id = daily_mystery
chapter_id = classic_cases
difficulty = normal
exp_reward = 10
collection_id = null
```

章节名称：

```text
经典案件
```

这样现有关卡无需立即重新编辑。

---

# 9. 数据结构扩展

## 9.1 World

建议增加：

```json
{
  "id": "ancient_china",
  "name": "神韵华章 · 千载风华",
  "description": "",
  "cover": "",
  "sort": 20,
  "enabled": true
}
```

字段：

```text
id
name
description
cover
sort
enabled
```

可选：

```text
name_i18n
description_i18n
theme
```

---

# 10. Chapter 数据结构

建议：

```json
{
  "id": "luoshen_fu",
  "world_id": "ancient_china",
  "name": "洛神赋",
  "subtitle": "翩若惊鸿，婉若游龙",
  "description": "",
  "cover": "",
  "sort": 10,
  "unlock_type": "previous",
  "unlock_value": 0,
  "collection_id": "scroll_luoshen",
  "enabled": true
}
```

最低必需字段：

```text
id
world_id
name
cover
sort
unlock_type
unlock_value
collection_id
enabled
```

---

# 11. Level 数据结构扩展

在现有关卡结构基础上扩展，不删除已有字段。

新增推荐字段：

```text
world_id
chapter_id
chapter_order
difficulty
gameplay_type
exp_reward
collection_id
release_status
release_at
```

示例：

```json
{
  "id": "luoshen_001",
  "world_id": "ancient_china",
  "chapter_id": "luoshen_fu",
  "chapter_order": 1,
  "title": "洛水初逢",
  "gameplay_type": "odd_spot",
  "difficulty": "easy",
  "exp_reward": 10,
  "collection_id": null,
  "release_status": "published"
}
```

---

# 12. gameplay_type

现阶段严格限制为：

```text
odd_spot
puzzle
```

含义：

```text
odd_spot = 找穿帮 / 找错位
puzzle   = 拼图 / 错位还原
```

不要添加未实现玩法。

---

# 13. difficulty

统一：

```text
easy
normal
hard
master
```

建议后台使用中文展示：

```text
easy    简单
normal  普通
hard    困难
master  大师
```

---

# 14. 星级系统

每关最大：

```text
3 星
```

第一版规则保持简单：

### 第 1 星

```text
成功通关
```

### 第 2 星

```text
误点次数 <= 配置值
```

默认：

```text
max_wrong_taps_for_star = 2
```

### 第 3 星

找穿帮：

```text
不使用提示
```

拼图：

```text
在目标时间内完成
```

所有规则应支持后台配置。

建议结构：

```json
{
  "star_rules": {
    "clear": true,
    "max_wrong_taps": 2,
    "no_hint": true,
    "time_limit": null
  }
}
```

旧关卡没有配置时使用默认规则。

---

# 15. EXP / 侦探等级

第一版只增加 EXP。

**暂时不要增加金币经济。**

原因：

- 当前游戏没有成熟商城。
- 金币加入后需要同时设计来源和消耗。
- 容易产生无意义资源堆积。
- 第一阶段的核心目标是建立长期成长反馈。

推荐默认 EXP：

```text
easy    10
normal  15
hard    20
master  30
```

额外奖励：

```text
首次三星：额外 +5 EXP
章节完成：额外 +50 EXP
```

---

# 16. 侦探等级

第一版可以采用简单累计等级。

例如：

| 等级范围 | 称号 |
|---|---|
| Lv.1–4 | 见习侦探 |
| Lv.5–9 | 新锐侦探 |
| Lv.10–19 | 敏锐侦探 |
| Lv.20–29 | 资深侦探 |
| Lv.30–39 | 明察秋毫 |
| Lv.40–49 | 洞若观火 |
| Lv.50+ | 大侦探 |

客户端主要展示：

```text
Lv.12
敏锐侦探
EXP 460 / 520
```

等级曲线第一版无需复杂。

推荐：

```text
next_level_exp = 100 + level * 20
```

未来可调整。

---

# 17. 收藏系统

收藏不是普通背包。

统一命名：

```text
大侦探博物馆
```

重点章节完成后获得：

```text
卷宗 / 文物 / 纪念收藏
```

例如：

```text
洛神赋卷
滕王阁卷
兰亭卷
清明上河图卷
```

第一版收藏只需要：

```text
id
name
description
image
source_chapter_id
unlocked
```

暂时不需要碎片系统。

---

# 18. Chapter 完成条件

默认：

```text
章节内全部关卡首次通关
```

不强制全部三星。

章节页面显示：

```text
洛神赋
5 / 8
17 / 24 ★
```

完成全部关卡：

```text
章节完成
```

奖励：

```text
收藏品
EXP
可选称号
```

---

# 19. 内容解锁

第一版保持简单。

章节解锁类型：

```text
default
previous
stars
level
```

含义：

```text
default  = 默认开放
previous = 完成上一章节
stars    = 达到指定总星数
level    = 达到指定侦探等级
```

第一版推荐主要使用：

```text
default
previous
```

避免前期数值设计过复杂。

---

# 20. 首页结构调整

旧首页不得完全推翻。

推荐调整为：

```text
顶部：
玩家等级 / 总星数

继续案件：
最近一个未完成章节

内容世界：
日常奇案
神韵华章
环球奇遇
幻境奇闻
脑洞异闻录

底部：
首页
博物馆
我的
```

如果当前导航结构不方便：

第一阶段至少增加：

```text
内容世界入口
```

不要为了新设计强制重写整个页面框架。

---

# 21. 世界列表页

显示卡片：

```text
神韵华章 · 千载风华

18 / 80 关
41 / 240 ★
```

数据必须动态读取。

禁止硬编码进度。

---

# 22. Chapter 列表页

例如：

```text
神韵华章 · 千载风华

第一卷
洛神赋
8 / 8
22 / 24 ★
✓ 已完成

第二卷
滕王阁序
4 / 8
9 / 24 ★

第三卷
兰亭集序
🔒 完成上一卷后解锁
```

---

# 23. 关卡结算页

原有通关弹窗基础上增加：

```text
★★☆
```

并展示：

```text
首次通关
+15 EXP

章节进度
5 / 8
```

如果章节完成：

显示：

```text
章节完成

获得收藏：
《洛神赋卷》

+50 EXP
```

---

# 24. Admin 后台改造

Admin 是这次改造重点。

后台导航建议增加：

```text
内容管理
├── 内容世界
├── 章节管理
└── 关卡管理
```

---

# 25. Admin：内容世界管理

支持：

```text
创建
编辑
排序
启用 / 禁用
上传封面
```

字段：

```text
ID
名称
说明
封面
排序
状态
```

---

# 26. Admin：章节管理

支持：

```text
创建章节
编辑章节
选择所属世界
章节排序
上传封面
配置解锁条件
配置收藏奖励
启用 / 禁用
```

显示：

```text
章节名
所属世界
关卡数量
发布状态
排序
```

---

# 27. Admin：关卡编辑器修改

当前关卡编辑器继续保留：

```text
找穿帮编辑器
拼图编辑器
```

新增基础字段：

```text
所属世界
所属章节
章节内排序
难度
EXP
星级规则
收藏奖励（可空）
```

要求：

选择：

```text
gameplay_type = odd_spot
```

显示原找穿帮编辑器。

选择：

```text
gameplay_type = puzzle
```

显示拼图编辑器。

不得同时展示两个编辑器。

---

# 28. Admin 旧关卡处理

后台加载旧关卡时：

如果不存在：

```text
world_id
```

UI 显示：

```text
日常奇案
```

如果不存在：

```text
chapter_id
```

显示：

```text
经典案件
```

但**不要因为打开编辑页面自动修改并保存旧数据**。

只有用户点击保存时，才写入补齐字段。

---

# 29. 迁移脚本

建议提供一次性迁移工具。

但迁移必须：

```text
可重复执行
幂等
```

行为：

```text
如果 world_id 不存在：
    设置 daily_mystery

如果 chapter_id 不存在：
    设置 classic_cases

如果 difficulty 不存在：
    设置 normal

如果 exp_reward 不存在：
    设置 15
```

禁止覆盖已经配置的字段。

---

# 30. Classic Cases 默认章节

必须创建系统默认章节：

```text
world:
daily_mystery

chapter:
classic_cases

name:
经典案件
```

现有全部无法自动分类的旧关卡先进入这里。

以后人工移动即可。

---

# 31. 用户进度数据

新增：

```text
level_progress
chapter_progress
player_progress
collection_progress
```

至少需要记录：

## level_progress

```text
user_id
level_id
cleared
best_stars
best_wrong_taps
best_time
hint_used
first_clear_at
last_play_at
```

## player_progress

```text
user_id
exp
level
total_stars
```

## collection_progress

```text
user_id
collection_id
unlocked_at
```

---

# 32. 星级更新规则

重复挑战允许刷新最好成绩。

例如：

第一次：

```text
2 星
```

第二次：

```text
3 星
```

保存：

```text
best_stars = 3
```

总星数只能计算每关历史最高星数。

禁止重复累计。

错误示例：

```text
第一次 2 星
第二次 3 星
总星数 +5
```

正确：

```text
总星数只增加 1
```

因为最高记录从 2 → 3。

---

# 33. EXP 防刷规则

EXP 推荐：

首次通关：

```text
获得 full exp_reward
```

重复通关：

第一版建议：

```text
不再获得基础 EXP
```

如果历史最佳星级提高：

```text
每新增 1 星 +5 EXP
```

防止玩家无限刷简单关升级。

---

# 34. Web 版本改造要求

Web 与 WeChat 使用相同：

```text
World
Chapter
Level
Progress
```

协议。

Web 需要：

1. 支持世界列表。
2. 支持章节列表。
3. 支持章节进度。
4. 支持星级展示。
5. 支持 EXP / 等级。
6. 支持收藏页面。
7. 保持当前邮箱登录逻辑。
8. 不引入微信专属逻辑。
9. 保持找穿帮和拼图玩法行为一致。

---

# 35. WeChat 版本改造要求

微信端：

1. 保持现有登录 / 用户身份体系。
2. 不修改已上线核心玩法。
3. 新增世界 / 章节入口。
4. 新增星级。
5. 新增 EXP。
6. 新增收藏。
7. 优先保证旧玩家数据正常加载。
8. 新字段缺失不得白屏。
9. Catalog 老版本数据仍应正常读取。
10. 新版本上线后旧进度不得丢失。

---

# 36. API / Catalog 兼容

如果已有 Catalog：

推荐新增：

```json
{
  "worlds": [],
  "chapters": [],
  "levels": []
}
```

如果现有结构无法直接修改：

可以新增：

```text
catalog_v2
```

但不要删除旧接口。

兼容优先级：

```text
新客户端 → 优先读取新结构
↓
失败
↓
兼容旧 Catalog
```

如果能通过扩展字段实现：

优先扩展现有 Catalog，不新开一套。

---

# 37. 发布状态

统一：

```text
draft
scheduled
published
disabled
```

含义：

```text
draft      草稿
scheduled  定时发布
published  已发布
disabled   下架
```

第一版如果现有系统只有：

```text
enabled
published
```

可继续沿用，不强制重构。

---

# 38. 第一阶段不做的内容

本次禁止 Codex 顺手扩展：

- 金币系统
- 商城
- 体力系统
- 抽卡
- 装备
- 复杂任务系统
- 好友系统
- 公会
- PvP
- 复杂排行榜
- 赛季通行证
- 宝箱
- NFT
- 新游戏玩法
- 大规模 UI 重做

这些以后再评估。

---

# 39. 后续 V1.2

V1.1 稳定后再做：

```text
侦探等级展示增强
称号系统
收藏博物馆
成就
章节完成动画
```

---

# 40. 后续 V1.3

再增加：

```text
每日案件
每周挑战
限时专题
老关随机复用
周榜
```

每日案件直接抽现有关卡。

不要重复维护第二份关卡。

---

# 41. 内容生产规范

以后新内容禁止直接从：

```text
“做下一关”
```

开始。

必须：

```text
先确定 World
↓
确定 Chapter
↓
规划章节全部 8 关
↓
确定玩法比例
↓
制作素材
↓
录入后台
```

---

# 42. 单关最低配置

每关至少需要：

```text
world_id
chapter_id
title
gameplay_type
chapter_order
difficulty
```

找穿帮关：

```text
mistake_count
mistake_points
```

拼图关：

使用当前已有拼图配置。

---

# 43. 穿帮类型标签

可预留：

```text
anachronism
object
behavior
costume
architecture
animal
text_symbol
physics
```

对应：

```text
时代错误
物品错误
行为错误
服饰错误
建筑错误
动植物错误
文字符号错误
物理逻辑错误
```

第一版后台可以只保存，不需要客户端展示。

未来用于：

```text
每日任务
统计
推荐
AI 内容生产
```

---

# 44. 实施顺序

Codex 严格按以下顺序实施。

## Phase 1：数据兼容

完成：

```text
World schema
Chapter schema
Level 扩展字段
默认值
旧关卡兼容
```

要求：

现有项目可以正常运行后再继续。

---

## Phase 2：Admin

完成：

```text
世界管理
章节管理
关卡关联世界 / 章节
难度配置
EXP 配置
星级配置
```

---

## Phase 3：客户端基础内容结构

Web + WeChat：

```text
世界列表
章节列表
章节进度
关卡列表
```

---

## Phase 4：星级

完成：

```text
通关结算
星级计算
最佳星级
总星数
```

---

## Phase 5：EXP

完成：

```text
首次通关 EXP
星级提升 EXP
等级计算
等级展示
```

---

## Phase 6：收藏

完成：

```text
章节收藏
收藏页面
章节完成奖励
```

---

# 45. 每个 Phase 后必须验证

禁止一次性改完所有模块再统一测试。

每阶段：

```text
修改
↓
编译
↓
单测 / 基础测试
↓
启动验证
↓
确认旧功能正常
↓
再进入下一阶段
```

---

# 46. 关键回归测试

至少测试：

## 老用户

```text
已有账号登录
旧关卡正常显示
旧关卡能进入
旧关卡能通关
旧进度不丢
```

## 新用户

```text
首次登录
看到世界
看到章节
可以正常进入第一关
```

## 找穿帮

```text
正确点击
错误点击
提示
通关
星级
```

## 拼图

```text
进入
移动
完成
结算
星级
```

## Chapter

```text
进度
完成
解锁下一章
收藏奖励
```

## EXP

```text
首次奖励
重复挑战
历史星级提高
升级
```

---

# 47. 验收标准

只有满足以下条件才算完成。

### 兼容性

- 旧关卡无需重新制作即可运行。
- 旧玩家数据不会丢失。
- 老关卡没有新字段不会报错。
- 找穿帮玩法行为没有改变。
- 拼图玩法行为没有改变。

### 内容管理

Admin 可以：

- 创建世界。
- 创建章节。
- 设置章节所属世界。
- 设置关卡所属章节。
- 设置玩法。
- 设置排序。
- 设置难度。
- 设置 EXP。
- 设置星级规则。

### 客户端

可以：

- 查看世界。
- 查看章节。
- 查看章节进度。
- 查看星级。
- 查看等级。
- 正常进入原有关卡。
- 正常进入拼图关。

### 成长

可以：

- 获得星星。
- 记录最佳成绩。
- 获得 EXP。
- 升级。
- 完成章节。
- 获得收藏。

---

# 48. Codex 执行约束

Codex 开始修改前：

1. 先扫描项目目录。
2. 找出 Admin、Web、Wechat、Server、Contracts / Schema / Catalog 实际位置。
3. 先阅读当前实现。
4. 根据实际代码映射本文档概念。
5. 不假设目录一定与本文一致。

如果实际项目已经存在类似：

```text
Series
Category
Collection
Group
```

优先复用。

不要为了名字完全一致而重复建模。

---

# 49. 禁止无关改动

Codex 不得：

```text
格式化整个项目
重命名无关文件
升级无关依赖
修改无关 UI
重写已有公共组件
修改登录体系
调整服务器部署
改资源目录结构
```

除非属于完成本需求的必要改动。

---

# 50. Git 修改要求

建议：

每个 Phase 一个独立 Commit。

例如：

```text
feat(content): add world and chapter schema
feat(admin): add world and chapter management
feat(game): add chapter progression
feat(progress): add star system
feat(progress): add detective exp
feat(collection): add chapter collectibles
```

方便出现问题时逐步回滚。

---

# 51. 第一批建议内容数据

至少初始化：

## World

```text
daily_mystery
ancient_china
world_journey
fantasy_world
brainstorm
```

## Chapter

### daily_mystery

```text
classic_cases
经典案件
```

用于兼容旧关卡。

### ancient_china

```text
luoshen_fu
洛神赋
```

如果现有洛神赋已经上线：

将其归入：

```text
ancient_china / luoshen_fu
```

其余旧关卡：

```text
daily_mystery / classic_cases
```

---

# 52. 最终产品结构

最终用户体验应逐步形成：

```text
错位大侦探

我的侦探
Lv.12 敏锐侦探
总星数：86

↓

继续案件
《洛神赋》
5 / 8

↓

内容世界

日常奇案
神韵华章 · 千载风华
环球奇遇
幻境奇闻
脑洞异闻录

↓

选择章节

↓

找穿帮 / 拼图

↓

通关结算
★★★
+15 EXP

↓

章节完成

↓

获得收藏

↓

继续下一个案件
```

---

# 53. 最终原则

本次升级的重点不是增加更多系统。

而是完成以下转变：

```text
散乱关卡
↓
系统内容

单次通关
↓
长期成长

新增图片
↓
新增章节

找茬小游戏
↓
可长期持续更新的内容型视觉推理游戏
```

所有代码和产品决策都围绕这三个目标：

```text
兼容现有内容
建立长期内容结构
增加用户长期目标
```

不要为了“架构漂亮”破坏现有已经上线的稳定功能。

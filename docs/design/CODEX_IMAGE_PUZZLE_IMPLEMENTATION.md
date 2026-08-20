# 《错位大侦探》新增「拼图 / 错位还原」玩法实施文档（Codex 执行版）

> 仓库：`TheMGame/game-odd-spot`  
> 基准：2026-08-18 `master` 当前代码结构  
> 目标目录：`contracts/`、`server/`、`admin/`、`webgame/`、`wechat/`  
> 本次不修改：`client/` Godot 客户端  
> 文档用途：直接交给 Codex，在仓库根目录按本文执行、编码、测试并提交修改。

---

## 0. Codex 执行要求

### 0.1 先做代码检查，再修改

开始编码前先搜索并确认以下内容的实际位置，避免只按本文行号机械修改：

```bash
git status
git grep -n "spot_difference"
git grep -n "find_anachronism"
git grep -n "difference_count"
git grep -n "series.mode"
git grep -n "level_differences"
git grep -n "attempt_differences"
git grep -n "validateLevel"
```

重点确认：

- `contracts/level.schema.json`
- `contracts/examples/`
- `server/internal/catalog/`
- `server/internal/level/`
- `server/internal/httpapi/`
- `admin/app.js`
- `admin/styles.css`
- `webgame/js/app.js`
- `webgame/js/core/renderer.js`
- `webgame/js/core/storage.js`
- `webgame/tests/`
- `wechat/js/app.js`
- `wechat/js/core/renderer.js`
- `wechat/js/core/storage.js`
- `wechat/tests/`

如果当前仓库在执行时已经发生新改动，优先保留新代码结构和已有功能，不要为了匹配本文而回退代码。

### 0.2 不做的事情

本次明确不做：

- 不新增“找不同”玩法。
- 不做“拼图 + 找穿帮”混合关。
- 不做传统散落式 jigsaw 锯齿拼图。
- 不做旋转拼图。
- 不做三块循环、隐藏块等高级规则。
- 不提前把原图切成几十张图片上传 CDN。
- 不修改 Godot `client/`。
- 不引入新游戏引擎。
- 不破坏现有登录、系列、每日挑战、进度、提示、音频、图片 hash/cache、水印等能力。
- 不因为拼图玩法而复制一套新的首页、选关页、完成页。

---

# 1. 最终产品定义

## 1.1 当前游戏只保留两种正式玩法

每个关卡必须且只能选择一种玩法：

```text
find_anachronism    找穿帮
image_puzzle        拼图 / 错位还原
```

产品 UI 中文：

- `find_anachronism` → **找穿帮**
- `image_puzzle` → **拼图（错位还原）**

不要继续在 Admin 创建入口中暴露：

```text
spot_difference
```

本次将 `spot_difference` 视为历史遗留代码，不再作为当前产品玩法。

---

## 1.2 系列不再决定玩法

当前代码中 `content_series.mode / series.mode` 会影响 Admin 创建关卡，这是本次必须修正的结构。

最终关系：

```text
Series
├── title
├── description
├── cover
├── sort_order
└── levels
      ├── level A: find_anachronism
      ├── level B: image_puzzle
      ├── level C: find_anachronism
      └── level D: image_puzzle
```

也就是说：

> **玩法属于 Level，不属于 Series。**

同一系列可以混排找穿帮关和拼图关。

### 数据库兼容要求

如果 `content_series.mode` 当前数据库列为 NOT NULL，不要求本次立刻 DROP COLUMN。

可以：

- 服务端暂时继续保存该字段用于 DB 兼容；
- 统一写入固定默认值 `find_anachronism`；
- Admin 不再显示、不再让用户配置；
- 客户端不再依据 `series.mode` 决定游戏模式；
- 真正玩法只读取 `level.mode`。

不要为了删除这个历史列引入一次高风险生产数据库迁移。

---

# 2. 拼图玩法定义

## 2.1 玩法不是完整随机拼图

本玩法核心是：

> 一张完整图片被规则网格切分，其中少量矩形区域被两两交换，玩家找出错位区域并把它们交换回正确位置。

例如原图逻辑网格：

```text
01 02 03 04
05 06 07 08
09 10 11 12
13 14 15 16
17 18 19 20
```

Admin 配置：

```text
06 ↔ 14
09 ↔ 11
```

玩家开局看到的图片只有这 4 个格子的内容发生错位，其余区域保持正确。

这不是传统 20 块全部洗牌。

---

## 2.2 P0 操作方式

客户端统一使用：

### 点击两块进行交换

1. 玩家点击一个格子。
2. 格子出现选中描边。
3. 玩家再点击另一个格子。
4. 两个格子的图片内容交换。
5. 检查当前棋盘是否恢复。
6. 如果全部恢复，通关。

交互规则：

- 点击已选中的同一格：取消选择。
- 点击第二格：立即交换。
- 不要求精确拖拽。
- Web 鼠标与手机触摸统一行为。
- 保留现有双指缩放 / Web 滚轮缩放和放大后拖动画面能力。
- 发生明显拖动时不要触发格子点击。
- 拼图格子的判定必须基于图片实际 `draw rect`，不能基于外层 panel，避免 `contain` 留白导致格子定位偏移。

---

## 2.3 开局显示

拼图关加载完成后直接应用 Admin 配置的交换并进入可操作状态，不播放或短暂展示完整原图。Admin 编辑器仍提供“原图 / 错位效果”切换，供内容制作时对照。

---

## 2.4 拼图网格

P0 支持：

```text
rows: 2 ~ 8
cols: 2 ~ 8
rows * cols <= 48
```

推荐运营使用：

```text
3 × 4
4 × 4
4 × 5
5 × 5
5 × 6
```

客户端必须按数学裁剪原图，不生成独立子图片文件。

每个 cell 对应原图 source rect：

```text
src_x = col * image_width  / cols
src_y = row * image_height / rows
src_w = image_width  / cols
src_h = image_height / rows
```

绘制到当前 cell 的 destination rect。

注意处理不能整除的像素边界，建议按浮点 source rect 绘制，避免累计误差形成缝隙。

---

## 2.5 初始交换规则

P0 只支持：

```json
{
  "type": "swap",
  "cells": [5, 13]
}
```

内部 cell 一律 **0-based**。

Admin 给运营显示 **1-based**。

例如：

```text
Admin: 06 ↔ 14
JSON:  [5, 13]
```

约束：

- 至少 1 组 swap。
- 每组必须正好 2 个不同 cell。
- cell 必须在 `[0, rows*cols-1]`。
- 同一个 cell 不能在两组初始 swap 中重复出现。
- P0 最大 12 组 swap。
- `operations` 数组仅允许 `type=swap`。

错误示例：

```json
[
  {"type":"swap","cells":[5,13]},
  {"type":"swap","cells":[13,17]}
]
```

必须拒绝，因为 `13` 重复参与两组初始交换。

---

# 3. Runtime Level 数据协议

## 3.1 本次建议继续使用 schema_version=1

为了避免把本次功能扩大为完整协议版本迁移，当前迭代继续保持：

```json
"schema_version": 1
```

但要把 schema 改成基于 `mode` 条件校验。

执行前 Codex 必须先搜索仓库和本地示例是否存在真实 `spot_difference` 内容。

如果仅代码/测试残留，可以删除。

如果发现仓库中存在明确仍在使用的正式 `spot_difference` 关卡数据，不要静默转换答案；先保留读取兼容或在最终报告中明确列出。

---

## 3.2 找穿帮关卡

保持现有结构：

```json
{
  "schema_version": 1,
  "level_id": "level_xxxxxxxx",
  "level_version": 3,
  "mode": "find_anachronism",
  "title": "80年代街头",
  "instruction": "找出 5 个不属于这个年代的物件",
  "assets": {
    "image": {
      "asset_id": "asset_xxx",
      "url": "https://...",
      "sha256": "...",
      "bytes": 123456,
      "content_type": "image/webp"
    },
    "width": 1024,
    "height": 1536
  },
  "differences": [
    {
      "id": "answer_1",
      "shape": "circle",
      "x": 0.3,
      "y": 0.5,
      "radius": 0.04,
      "label": "智能手机",
      "era": "多年后才出现",
      "explanation": "……",
      "difficulty": 2,
      "operation": "anachronism"
    }
  ],
  "tags": {},
  "difficulty": {
    "total": 2
  }
}
```

找穿帮：

- 必须有 `assets.image`
- 必须有 `differences`
- 不允许 `puzzle`

---

## 3.3 拼图关卡

新增：

```json
{
  "schema_version": 1,
  "level_id": "level_puzzle_001",
  "level_version": 1,
  "mode": "image_puzzle",
  "title": "老上海街景",
  "instruction": "交换错位区域，还原完整画面",
  "assets": {
    "image": {
      "asset_id": "asset_xxx",
      "url": "https://...",
      "sha256": "...",
      "bytes": 123456,
      "content_type": "image/webp"
    },
    "width": 1024,
    "height": 1536
  },
  "puzzle": {
    "rows": 5,
    "cols": 4,
    "operations": [
      {
        "type": "swap",
        "cells": [5, 13]
      },
      {
        "type": "swap",
        "cells": [8, 10]
      }
    ]
  },
  "tags": {},
  "difficulty": {
    "total": 2
  }
}
```

拼图：

- 必须有 `assets.image`
- 必须有 `puzzle`
- **不要求也不应该生成 `differences: []`**
- 不允许 `assets.base/target`
- `instruction` 默认：`交换错位区域，还原完整画面`

---

## 3.4 JSON Schema 修改要求

修改：

```text
contracts/level.schema.json
```

顶层 `required` 不要继续无条件包含 `differences`。

顶层：

```text
mode enum:
- find_anachronism
- image_puzzle
```

条件：

### find_anachronism

要求：

- `assets.image`
- `differences`
- `differences` 3~12
- 禁止 `puzzle`

### image_puzzle

要求：

- `assets.image`
- `puzzle`
- 禁止 `differences`
- 禁止 `assets.base`
- 禁止 `assets.target`

新增 `$defs.puzzle`：

```text
rows              integer 2..8
cols              integer 2..8
operations        array 1..12
```

新增 `$defs.puzzleOperation`：

```text
type  const "swap"
cells array exactly 2 unique integers >= 0
```

JSON Schema 很难单独表达：

- `cell < rows*cols`
- operations 之间 cell 不重复
- rows*cols <= 48

因此这些约束必须同时在：

- Server 保存校验
- Admin 发布校验
- Web `validateLevel`
- WeChat `validateLevel`

中进行代码级校验。

---

# 4. Server 修改

拼图不是纯前端功能。

当前服务端完成流程依赖：

```text
level_differences
attempt_differences
difference_ids
```

必须改成按 `level.mode` 判断。

---

## 4.1 Catalog Level 必须带自己的 mode

修改：

```text
server/internal/catalog/service.go
```

当前 `catalog.Level` 至少增加：

```go
Mode         string `json:"mode"`
ContentCount int    `json:"content_count"`
```

保留 `DifferenceCount` 可以作为过渡字段，但 Admin 新 UI 不再依赖它。

建议最终 Catalog 单关卡返回：

```json
{
  "id": "level_001",
  "version": 3,
  "title": "80年代街头",
  "mode": "find_anachronism",
  "difficulty": 2,
  "content_count": 5,
  "thumbnail_url": "...",
  "sort_order": 10,
  "completed": false
}
```

拼图：

```json
{
  "id": "level_002",
  "version": 1,
  "title": "老上海街景",
  "mode": "image_puzzle",
  "difficulty": 2,
  "content_count": 4
}
```

这里 `content_count` 定义：

### 找穿帮

```text
differences.length
```

### 拼图

```text
初始被错位的 cell 数量
= operations.length * 2
```

由于 P0 禁止 cell 重复，因此直接乘 2 即可。

---

## 4.2 Series mode 降级为兼容字段

修改：

```text
server/internal/catalog/service.go
admin/app.js
```

要求：

- Admin 系列创建/编辑页面删除“游戏模式”。
- Admin 系列列表不显示 `s.mode`。
- `newLevel()` 不再继承 `series.mode`。
- 新建 Level 默认：
  ```text
  mode=find_anachronism
  ```
- 如果后端 `UpsertSeries()` 因 DB NOT NULL 仍要求 mode：
  - 服务端默认补 `find_anachronism`
  - 不要求前端再传
- 不要用 series mode 过滤系列里的关卡。

---

## 4.3 UpsertLevel 增加严格 mode 校验

当前：

```text
server/internal/catalog/service.go
MySQLService.UpsertLevel()
```

主要只解析 `runtime_json` 并写数据库。

新增一个明确的运行时校验函数，例如：

```go
func validateRuntimeLevel(runtime map[string]any) error
```

或放到独立文件：

```text
server/internal/catalog/validation.go
```

要求：

### 通用

- `mode` 只能：
  - `find_anachronism`
  - `image_puzzle`
- `assets.image` 必须存在。
- 图片尺寸合法。
- level id / version 等继续沿用当前规则。

### find_anachronism

- differences 3~12
- id 唯一
- 保留现有热点规则

### image_puzzle

- puzzle 存在
- rows / cols 范围合法
- `rows*cols <= 48`
- operations 1~12
- 每个 operation type=swap
- cells 长度=2
- 两 cell 不同
- cell 范围合法
- 所有 operations 之间不得重复使用 cell
- 不允许 differences

发布和草稿都建议执行结构校验；“线索推理至少 20 字”这种内容完整性规则仍只在发布阶段执行。

---

## 4.4 Catalog 写入 differences

当前 `UpsertLevel()` 会：

1. 删除 `level_differences`
2. 遍历 runtime `differences`
3. 写入 `level_differences`

修改为：

```text
if mode == find_anachronism:
    维持当前流程

if mode == image_puzzle:
    删除该 version 的 level_differences
    不插任何 difference
```

不需要新增 `level_puzzle_cells` 表。

拼图配置完整保存在：

```text
level_versions.runtime_json
```

即可。

---

# 5. Server 进度 / 完成协议

## 5.1 Start

`POST /v1/levels/{levelId}/start`

保持原接口。

但 `AttemptResult.TotalCount` 不要再一律从 `level_differences` 计算。

应按 mode：

### find_anachronism

```text
total_count = differences.length
```

### image_puzzle

```text
total_count = initial misplaced cell count
```

即：

```text
operations.length * 2
```

如果改造 `AttemptResult` 成为更通用命名成本过大，本次可以保留 `FoundCount/TotalCount` 字段，只改变语义。

---

## 5.2 Progress

现有 `ProgressRequest` 可继续兼容：

```json
{
  "attempt_id": "...",
  "found": [],
  "hints_used": 1,
  "duration_ms": 30000
}
```

拼图不需要每次交换都打服务端。

本次推荐：

- 每次交换只保存客户端本地进度。
- 使用 hint 后，可以按现有节奏提交一次 progress。
- App hide / 页面隐藏时按现有逻辑保存本地。
- 不新增“每移动一步服务端写数据库”。

原因：

- 拼图交换频率比找穿帮高。
- 没必要造成大量 API 写请求。
- 当前产品已经有本地进度 + 离线队列体系。

---

## 5.3 CompleteRequest 扩展

当前完成请求是：

```json
{
  "attempt_id": "...",
  "difference_ids": ["..."],
  "hints_used": 0,
  "duration_ms": 50000
}
```

新增可选字段：

```go
PuzzleOrder []int `json:"puzzle_order,omitempty"`
PuzzleMoves int   `json:"puzzle_moves,omitempty"`
```

最终：

### 找穿帮

继续：

```json
{
  "attempt_id": "...",
  "difference_ids": ["a","b","c"],
  "hints_used": 0,
  "duration_ms": 50000
}
```

### 拼图

发送：

```json
{
  "attempt_id": "...",
  "puzzle_order": [0,1,2,3,4,5,6,7,8,9,10,11],
  "puzzle_moves": 7,
  "hints_used": 1,
  "duration_ms": 50000
}
```

服务端必须读取该 attempt 对应的：

```text
level_id
level_version
runtime_json.mode
runtime_json.puzzle
```

然后分支验证。

### image_puzzle 完成判定

必须确认：

```text
len(puzzle_order) == rows * cols
```

并且：

```text
puzzle_order[i] == i
```

全部成立。

否则：

```text
ErrIncomplete
```

不需要验证玩家具体用了什么移动路径，只验证最终棋盘已恢复。

---

## 5.4 MySQL 完成逻辑

重点修改：

```text
server/internal/level/mysql_service.go
```

当前 `Complete()` 使用：

```text
expected = level_differences count
actual   = attempt_differences count
actual == expected
```

改为：

```text
load level runtime/mode

switch mode:
  find_anachronism:
      保留现有 difference 完成校验

  image_puzzle:
      不调用 insertFound
      校验 request.PuzzleOrder 为 identity permutation
      校验长度 rows*cols
      校验成功后直接将 attempt 标记 completed
```

奖励、duration、hints、幂等写入维持现状。

---

# 6. Admin 改造

这是本次内容生产最重要部分。

当前 Admin 已经有：

- 关卡编辑器
- 原图
- 热点编辑
- Inspector
- 素材上传
- 保存草稿
- 发布
- 手机预览

不要重写 Admin。

在现有编辑器里根据 `level.mode` 渲染两套编辑器。

---

## 6.1 新建关卡

当前：

```text
newLevel(seriesId)
```

不要再：

```text
mode: series.mode
```

改成默认：

```json
{
  "schema_version": 1,
  "mode": "find_anachronism"
}
```

---

## 6.2 关卡信息新增玩法选择

左侧“关卡信息”增加：

```text
玩法类型

[找穿帮 ▼]
```

选项只有：

```text
找穿帮
拼图（错位还原）
```

内部：

```text
find_anachronism
image_puzzle
```

切换玩法时必须确认：

```text
切换玩法会重置当前玩法配置，是否继续？
```

### find_anachronism → image_puzzle

删除：

```text
differences
```

创建：

```json
"puzzle": {
  "rows": 5,
  "cols": 4,
  "operations": []
}
```

instruction 改成：

```text
交换错位区域，还原完整画面
```

### image_puzzle → find_anachronism

删除：

```text
puzzle
```

创建：

```json
"differences": []
```

instruction 改成：

```text
圈出不属于这个年代的物件
```

不要同时保留两套配置。

---

## 6.3 找穿帮编辑器

现有：

- 答案热点
- 标注工具
- 热点属性
- 坐标
- 半径
- 线索
- 推理
- 删除热点

保持功能不变。

---

## 6.4 拼图编辑器布局

当：

```text
level.mode === image_puzzle
```

左侧第二个 panel 不再显示“答案热点”。

改为：

```text
拼图设置

网格
[4] 列 × [5] 行

已配置错位 4 块
06 ↔ 14    [删除]
09 ↔ 11    [删除]

[＋ 添加交换]
[随机生成]
[重置错位]
```

中间 Canvas：

- 显示当前原图。
- 叠加清晰但不过重的规则网格。
- 每个 cell 中央显示 1-based 编号。
- 默认显示“配置后的玩家开局画面”，即 operations 已经应用。
- Toolbar 增加：
  - `原图`
  - `错位效果`
  - `随机生成`
  - `重置`
- “安全区域”“标注工具”仅找穿帮模式显示。

右侧 Inspector：

### 未选格

显示：

```text
拼图说明

点击两个格子即可配置一组交换。
一个格子只能出现在一组初始交换中。
```

### 已点第一格

显示：

```text
已选择：06
请选择第二个格子
[取消选择]
```

### 已有 operation

点击 operation 后显示：

```text
交换 06 ↔ 14

[定位]
[删除这组交换]
```

---

## 6.5 Admin 配置交互

### 添加交换

推荐最直接：

1. 点击图片上的 cell A。
2. A 高亮。
3. 点击 cell B。
4. 立即新增 operation。
5. 图片实时重绘为错位效果。

如果 A 或 B 已经被现有 operation 使用：

```text
“格子 06 已参与另一组交换，请先删除原交换。”
```

### 删除交换

删除 operation 后重新从 identity board 应用剩余 operations。

不要在当前已变换画面上“反操作”来恢复，避免状态累计错误。

统一使用：

```text
identity order
→ apply all operations
→ render
```

---

## 6.6 随机生成

Admin 增加：

```text
错位块数
[4 / 6 / 8 / 10]
```

或根据网格自动提供合法偶数。

点击：

```text
随机生成
```

行为：

1. 从全部 cell 随机选择 N 个不重复 cell。
2. 随机两两配对。
3. 写成 explicit operations。
4. 保存到 runtime JSON。

**客户端不根据 seed 再随机。**

Admin 随机只是内容制作工具。

最终发布 JSON 必须是确定的 explicit operations，保证：

- Web
- WeChat
- Admin preview

看到完全一样的初始棋盘。

---

## 6.7 原图 / 错位效果切换

拼图编辑 Toolbar：

```text
[原图] [错位效果]
```

默认：

```text
错位效果
```

原图模式仅用于运营对照。

切换只影响 Admin 显示，不修改数据。

---

## 6.8 玩家试玩 / 手机预览

现有 `showMobilePreview()` 对拼图不能只显示静态图。

至少做到：

- 使用实际 rows/cols。
- 应用 operations。
- 可以点击两个格子交换。
- 显示剩余错位数量。
- 能真实完成。
- 提示按钮至少能模拟自动还原一组。

如果当前手机预览架构不适合直接复用客户端代码，可以先在 Admin 内做轻量版 Puzzle Preview，但数学规则必须与客户端共用同样算法。

---

## 6.9 Admin 关卡列表

当前表头“答案”与 `difference_count` 绑定。

改为：

```text
预览 | 关卡 | 玩法 | 难度 | 内容 | 版本 | 状态
```

例：

```text
80年代街头   找穿帮   ◆◆     5 个异常
老上海街景   拼图     ◆◆◆    6 个错位块
```

显示：

```js
modeLabel(level.mode)

find_anachronism -> 找穿帮
image_puzzle     -> 拼图
```

内容：

```text
find_anachronism -> `${content_count} 个异常`
image_puzzle     -> `${content_count} 个错位块`
```

---

## 6.10 系列 Admin

删除：

- 系列列表的 `mode`
- 系列创建 modal 的“游戏模式”
- 系列编辑 modal 的“游戏模式”

系列排序保存时不要再依赖前端传 `s.mode`。

如果服务端兼容层仍需要 mode，由服务端补默认值。

---

# 7. Web 客户端实现

目标：

```text
webgame/
```

当前核心游戏逻辑集中在：

```text
webgame/js/app.js
webgame/js/core/renderer.js
```

建议新增：

```text
webgame/js/core/puzzle.js
```

将纯拼图数学逻辑独立出来，方便测试。

---

## 7.1 puzzle.js 建议 API

建议提供纯函数：

```js
function createIdentityOrder(rows, cols)
function applyOperations(rows, cols, operations)
function swapCells(order, a, b)
function isSolved(order)
function countMisplaced(order)
function validatePuzzleConfig(puzzle)
function cellFromNormalizedPoint(x, y, rows, cols)
function findHintSwap(order)
```

### applyOperations

输入：

```text
identity order
```

例如 2×3：

```js
[0,1,2,3,4,5]
```

操作：

```js
swap 1,4
```

得到：

```js
[0,4,2,3,1,5]
```

这里：

```text
order[cell] = 当前显示在这个 cell 里的原图 piece index
```

这个定义 Web / WeChat / Admin 必须完全一致。

---

## 7.2 loadGame()

当前逻辑：

```js
if find_anachronism:
    load assets.image
else:
    load base + target
```

改为明确 switch：

```js
switch (level.mode) {
  case 'find_anachronism':
  case 'image_puzzle':
      load assets.image
      break
  default:
      unsupported
}
```

删除当前产品对 `spot_difference` 的正式分支。

拼图初始化：

```js
game.puzzle = {
  rows,
  cols,
  previewUntil,
  selectedCell: -1,
  order: initialOrder,
  moves: 0,
  initialMisplaced: countMisplaced(initialOrder),
  flashCells: [],
  solved: false
}
```

---

## 7.3 拼图本地进度

现有 `ProgressStore` 中 find 关保存：

- found
- elapsed
- zoom
- offset

拼图增加可选：

```json
{
  "puzzle_order": [0,4,2,3,1,5],
  "puzzle_moves": 3
}
```

恢复关卡时：

- 如果本地 attempt 对应同 level_version；
- `puzzle_order` 长度正确且是合法 permutation；
- 则恢复；
- 否则重新从 operations 生成 initial order。

不要因为旧 attempt 没有 puzzle 字段报错。

---

## 7.4 renderGame()

不要再假设：

```js
game.level.differences.length
```

统一分支。

### 找穿帮顶部

保持：

```text
found / total
```

### 拼图顶部

建议：

```text
已还原 X / Y
```

其中：

```text
Y = initialMisplaced
currentWrong = countMisplaced(order)
X = clamp(initialMisplaced - currentWrong, 0, initialMisplaced)
```

如果玩家错误交换导致错位增加，进度可以回退到 0。

不要用 `rows*cols` 作为 Y，否则一个只有 4 个错位块的 20 格关卡一开始就显示 16/20，体验不合理。

---

## 7.5 拼图绘制

新增：

```js
renderPuzzleImage(image, rect, game)
```

流程：

1. 用现有 `contain` 规则计算完整图片 draw rect。
2. 对每个 destination cell：
   - `piece = order[cell]`
   - 根据 `piece` 算 source row/col。
   - 用 `ctx.drawImage()` 裁剪原图 piece。
   - 绘制到 destination cell。
3. 绘制轻量网格线。
4. selectedCell 绘制高亮边框。
5. 最近正确交换 cell 可闪一次金色边框。
6. WeChat 版本仍在整个图片 draw 区域叠加现有 AI 水印，不要给每个 cell 重复画水印。

预览期间：

```text
直接按完整原图绘制
```

不要提前应用 order。

---

## 7.6 点击映射

拼图触摸结束：

1. 先确认点在 `draw` 范围内。
2. 转成 normalized：
   ```js
   x = (point.x - draw.x) / draw.w
   y = (point.y - draw.y) / draw.h
   ```
3. cell：
   ```js
   col = min(cols-1, floor(x*cols))
   row = min(rows-1, floor(y*rows))
   cell = row*cols + col
   ```
4. 调用 `pressPuzzleCell(cell)`。

已有缩放/偏移后，必须使用实际绘制后的 `draw` 信息，不能直接用 panel 尺寸。

---

## 7.7 pressPuzzleCell()

逻辑：

```text
if preview:
    ignore

if no selected:
    selected = cell
    click sound
    return

if selected == cell:
    selected = -1
    return

swap(selected, cell)
moves += 1
selected = -1
saveAttempt()

if solved:
    correct/complete feedback
    finishAfterFeedback()
else:
    if swapped cells 中任意一个现在正确:
        correct.wav
        vibration
```

不要每次普通错误交换都弹 toast。

状态栏可以短暂显示：

```text
这两块还没还原，再观察一下
```

---

## 7.8 Hint

现有每天 3 次免费 Hint 逻辑继续复用。

拼图：

```js
findHintSwap(order)
```

算法：

1. 找第一个 `order[i] !== i`。
2. 找到 `j`，使 `order[j] === i`。
3. 自动 swap(i, j)。
4. moves 不建议增加，或者增加但单独标记 hint；本次建议 **不增加 puzzle_moves**。
5. hints_used +1。
6. 保存 attempt。
7. correct 音效 + 轻震。
8. 如果 solved，完成关卡。

该 Hint 至少会还原一个 cell；对于 Admin P0 的两两交换初始状态，通常一次直接还原一整对。

---

## 7.9 Complete

找穿帮保持原 complete。

拼图：

```js
{
  attempt_id,
  puzzle_order: game.puzzle.order,
  puzzle_moves: game.puzzle.moves,
  hints_used,
  duration_ms
}
```

只有本地 `isSolved(order)` 为 true 才调用 complete。

---

## 7.10 Prefetch

当前 `prefetchNext()` 根据 mode 选择：

```text
image 或 target
```

改为：

```text
find_anachronism -> assets.image
image_puzzle     -> assets.image
```

删除依赖 `spot_difference -> target` 的正式路径。

---

# 8. WeChat 客户端实现

目录：

```text
wechat/
```

WeChat 和 Web 当前业务结构高度相似。

原则：

> **拼图规则必须与 Web 完全一致，只替换平台输入、存储、震动、图片加载、水印等基础设施。**

新增：

```text
wechat/js/core/puzzle.js
```

API 与 Web 对应文件保持同名同语义。

可直接复制纯数学逻辑，但不要跨目录 runtime require。

---

## 8.1 必须保持的微信能力

不能因为拼图重构破坏：

- `wx.onTouchStart/Move/End`
- 双指缩放
- 微信图片缓存
- SHA-256
- 本地进度
- 离线队列
- 微信登录
- 背景/前台 saveAttempt
- 音效
- 震动
- AI 生成内容水印
- 分包

---

## 8.2 水印

当前 WeChat 游戏图片有 AI 水印。

拼图绘制时：

1. 先逐 cell 绘制完整拼图画面。
2. 再调用现有：
   ```js
   renderer.watermark(...)
   ```
3. 水印只覆盖整个图片区域一次。

不要：

```text
每个 cell 画一份水印
```

否则会严重影响可玩性。

---

## 8.3 Touch

WeChat 仍使用：

```text
tap first cell
tap second cell
swap
```

拖动阈值继续沿用当前逻辑。

Pinch 时不要触发 swap。

---

# 9. validateLevel 统一规则

Web 与 WeChat 当前各有一份 `validateLevel()`。

两份必须同步。

建议最终抽出相同逻辑，但当前项目没有跨客户端共享包，本次可各自维护，并用同样测试用例保证一致。

---

## 9.1 通用

```text
schema_version == 1
mode in [find_anachronism, image_puzzle]
assets.width/height valid
assets.image valid
```

---

## 9.2 find_anachronism

继续校验：

- differences array 3~12
- id 唯一
- circle
- polygon

---

## 9.3 image_puzzle

校验：

```text
puzzle object exists
rows integer 2..8
cols integer 2..8
rows*cols <= 48
operations array 1..12
```

每 operation：

```text
type == swap
cells length == 2
integers
a != b
0 <= a,b < rows*cols
```

全局：

```text
所有初始 swap cell 唯一
```

---

# 10. Admin 发布校验

`saveLevel('published')` 按 mode 分支。

---

## 10.1 找穿帮

维持当前：

- differences 数量
- era
- explanation 至少 20 字
- 其他已有发布要求

自动 instruction：

```text
圈出 N 个不属于这个年代的物件
```

---

## 10.2 拼图

必须：

- assets.image 完整
- rows/cols 合法
- operations 至少 1
- operations 全部合法
- 没有重复 cell
- 没有越界
- 没有 a==b

自动 instruction：

```text
交换错位区域，还原完整画面
```

不校验：

```text
era
explanation
differences
```

---

# 11. spot_difference 清理范围

本次产品不再提供找不同。

Codex 先：

```bash
git grep -n "spot_difference"
```

逐项处理。

至少检查：

- `contracts/level.schema.json`
- `contracts/examples/`
- `admin/app.js`
- `webgame/README.md`
- `webgame/js/app.js`
- `webgame/tests/`
- `wechat/README.md`
- `wechat/js/app.js`
- `wechat/tests/`
- 服务端 demo / memory service
- API examples / docs

目标：

### 创建侧

完全不再创建 `spot_difference`。

### Admin UI

完全不显示 `spot_difference`。

### Web/WeChat 当前正式 validator

只接受：

```text
find_anachronism
image_puzzle
```

### 文档

README 改成：

```text
find_anachronism 与 image_puzzle
```

如果仓库里存在仅用于历史迁移的 `spot_difference` fixture，可保留但必须明确命名 legacy，不得进入正常新建/发布流程。

---

# 12. Server MemoryService / Demo

当前 `server/internal/level/service.go` MemoryService demo 是 `spot_difference`，需要一起修掉。

最简单：

- demo 改为 `find_anachronism`
- 使用 `assets.image`
- 保持 5 个 difference demo

不要让测试/开发内存服务继续把已经删除的玩法当默认案例。

---

# 13. 测试要求

Codex 不允许只完成功能不加测试。

---

## 13.1 Contracts

增加：

### valid

```text
valid_find_anachronism.json
valid_image_puzzle.json
```

### invalid

至少：

```text
invalid_puzzle_missing_config.json
invalid_puzzle_missing_image.json
invalid_puzzle_cell_out_of_range.json
invalid_puzzle_same_cell.json
invalid_puzzle_duplicate_cell_across_operations.json
invalid_puzzle_too_many_cells.json
invalid_puzzle_unknown_operation.json
```

JSON Schema 无法表达的跨字段错误，Server 单测覆盖。

---

## 13.2 Server

新增测试：

1. image_puzzle 可以 Upsert。
2. image_puzzle catalog 返回：
   - mode=image_puzzle
   - content_count=错位 cell 数。
3. puzzle 不写 `level_differences`。
4. puzzle Start 的 total_count 正确。
5. puzzle Complete identity order 成功。
6. puzzle Complete 非 identity 返回 incomplete。
7. puzzle Complete order 长度不匹配失败。
8. find_anachronism 原有 complete 逻辑不回归。
9. series 中可以同时有两种 mode 的关卡。
10. Admin Upsert Series 不传 mode 时仍可兼容 DB。

---

## 13.3 Web

给 `webgame/js/core/puzzle.js` 写纯函数测试：

- identity
- apply swaps
- swap
- solved
- countMisplaced
- cell mapping
- hint swap
- invalid duplicate operations
- invalid out of range

更新现有 level validator tests：

```text
find_anachronism valid
image_puzzle valid
spot_difference unsupported
```

---

## 13.4 WeChat

与 Web 同样测试一套。

特别检查：

- 触摸映射
- puzzle local progress restore
- 水印函数没有按 cell 重复调用的结构性错误

---

# 14. UI / 体验验收标准

## 14.1 Admin

必须可以完成以下流程：

```text
新建关卡
→ 选择系列
→ 玩法选择“拼图”
→ 上传/选择一张图片
→ 选择 4×5
→ 点击 06、14
→ 点击 09、11
→ 画面实时显示两组错位
→ 点击“原图”可以对照
→ 点击“错位效果”返回
→ 手机预览可以真的交换
→ 保存草稿
→ 发布
```

重新打开这关：

- rows/cols 正确。
- operations 正确。
- 错位预览一致。
- 不出现找穿帮热点面板。

---

## 14.2 Web

打开该关：

```text
直接显示 Admin 配置的错位效果
→ 点击 06
→ 点击 14
→ 两块交换
→ 正确反馈
→ 继续还原
→ 全部恢复
→ 正常进入现有完成页
→ 完成状态被保存
→ 下一关正常解锁
```

刷新/离开再回来：

- 同 level_version 未完成 puzzle 可从本地恢复。
- 已完成状态正常。

---

## 14.3 WeChat

与 Web 视觉/规则一致。

另外真机检查：

- 单指点击。
- 双指缩放不误交换。
- 放大拖动不误交换。
- 返回前台后状态正常。
- 图片水印仍正确。
- 内存没有因为生成大量离屏 Canvas 显著增加。
- 不生成 N 张大尺寸 bitmap。

---

# 15. 性能要求

拼图必须使用：

```text
1 张已加载原图 + Canvas drawImage source crop
```

禁止：

- 为每个 cell 创建独立网络图片。
- 为每个 cell 创建永久大 Canvas。
- 每帧生成新的 bitmap。
- 每帧重复构造大量数组。

可以：

- `order` 使用普通长度 <=48 的数组。
- 每帧逐 cell `drawImage`。
- 只有 operation / swap 时更新状态。

对于 4×5 / 5×6，这个开销很低。

---

# 16. Analytics

保持现有分析体系，并增加：

```text
puzzle_cell_selected
puzzle_swap
puzzle_hint
```

最低必做：

### puzzle_swap

字段：

```json
{
  "level_id": "...",
  "a": 5,
  "b": 13,
  "moves": 3,
  "remaining_misplaced": 2
}
```

不要上传完整图片或敏感内容。

level_complete 继续复用现有事件，并增加可选：

```text
mode=image_puzzle
puzzle_moves
```

---

# 17. 文案 / i18n

新增中文：

```text
拼图
错位还原
交换错位区域，还原完整画面
记住画面，马上开始还原
已选择一块，再选择另一块
已还原
剩余错位
```

英文至少：

```text
Puzzle
Restore the Picture
Swap misplaced tiles to restore the picture.
Memorize the picture.
Select another tile to swap.
Restored
Misplaced
```

不要把中文硬编码散落到大量业务逻辑中；沿用项目现有 `i18n.js` 结构。

Admin 当前本身主要中文，可以保留中文 UI。

---

# 18. 推荐文件级修改清单

实际文件以 `git grep` 结果为准。

## Contracts

```text
contracts/level.schema.json
contracts/examples/*
contracts/README.md
```

如设计源仍在：

```text
docs/ai_spot_difference_solution/schemas/
```

必须同步对应 schema 镜像，避免下次生成覆盖 contracts。

---

## Server

重点：

```text
server/internal/catalog/service.go
server/internal/level/service.go
server/internal/level/mysql_service.go
server/internal/httpapi/router.go
```

建议新增：

```text
server/internal/catalog/validation.go
server/internal/catalog/validation_test.go
```

以及现有 catalog / level / httpapi 测试文件。

如 OpenAPI 中 CompleteRequest / Catalog Level 有明确 schema：

```text
contracts/api.openapi.yaml
```

同步更新：

- catalog level `mode`
- `content_count`
- complete `puzzle_order`
- complete `puzzle_moves`

---

## Admin

```text
admin/app.js
admin/styles.css
```

如需要新增 DOM 结构：

```text
admin/index.html
```

但优先保持现有单页动态渲染结构。

---

## Web

```text
webgame/js/app.js
webgame/js/core/renderer.js
webgame/js/core/storage.js
webgame/js/core/i18n.js
webgame/README.md
webgame/tests/*
```

新增：

```text
webgame/js/core/puzzle.js
webgame/tests/puzzle.test.js
```

如果项目通过 bundle 构建：

- 修改源 `webgame/js/**`
- 运行 npm build/check
- 确认 `app.bundle.js` 由构建命令重新生成
- 不要只手改 bundle 文件

---

## WeChat

```text
wechat/js/app.js
wechat/js/core/renderer.js
wechat/js/core/storage.js
wechat/js/core/i18n.js
wechat/README.md
wechat/tests/*
```

新增：

```text
wechat/js/core/puzzle.js
wechat/tests/puzzle.test.js
```

如果微信版本没有打 bundle，直接按现有 require 结构接入。

---

# 19. 实现顺序

必须按依赖顺序进行。

## Phase 1：协议与服务端

1. 更新 level schema。
2. 新增 puzzle config validator。
3. Catalog Level 增加 mode/content_count。
4. Series mode 降级为兼容字段。
5. Server UpsertLevel mode 分支。
6. Server Start/Progress/Complete mode 分支。
7. 更新 OpenAPI。
8. 更新 Server/Contract tests。

完成后：

```bash
cd server
go test ./...
go vet ./...
```

---

## Phase 2：Admin

1. 系列移除 mode UI。
2. Level 增加 mode selector。
3. 现有 HotspotEditor 做条件渲染。
4. 增加 PuzzleEditor。
5. 网格点击配置。
6. operations 列表。
7. 随机生成。
8. 原图/错位预览。
9. 发布校验。
10. 手机预览。
11. 关卡列表显示玩法和内容数。

检查：

```bash
node --check admin/app.js
```

并通过浏览器实际操作一次完整创建流程。

---

## Phase 3：Web

1. `puzzle.js`
2. validateLevel
3. loadGame
4. renderPuzzle
5. 输入映射
6. local progress
7. hint
8. complete
9. prefetch
10. i18n
11. tests
12. rebuild bundle

执行：

```bash
cd webgame
npm install
npm run check
```

如果 package scripts 有 build：

```bash
npm run build
```

以实际 `package.json` 为准。

---

## Phase 4：WeChat

对齐 Web：

1. puzzle.js
2. validate
3. load/render/input
4. progress
5. hint
6. complete
7. watermark
8. tests

执行：

```bash
cd wechat
npm install
npm run check
```

最后必须微信开发者工具 + 真机测试。

---

# 20. 最终验收矩阵

| 场景 | Admin | Web | WeChat | Server |
|---|---|---|---|---|
| 找穿帮旧关 | 可编辑发布 | 正常玩 | 正常玩 | 正常记录 |
| 新建找穿帮 | 支持 | 正常 | 正常 | 正常 |
| 新建拼图 | 支持 | 正常 | 正常 | 正常 |
| 同系列混两种玩法 | 支持 | 支持 | 支持 | Catalog 正确 |
| 拼图原图对照 | 可预览 | 不播放 | 不播放 | 无要求 |
| 拼图交换 | 可试玩 | 点击两格 | 点击两格 | 无逐步写入 |
| 拼图 Hint | 可模拟 | 自动还原 | 自动还原 | hints 正常 |
| 拼图完成 | 可试玩 | 正常完成 | 正常完成 | identity 校验 |
| spot_difference 新建 | 不允许 | unsupported | unsupported | 不允许发布 |
| 图片缓存/hash | 不破坏 | 正常 | 正常 | 无回归 |
| 微信 AI 水印 | N/A | N/A | 整图一次 | N/A |

---

# 21. Codex 完成后必须输出的报告

完成代码后，不要只回复“已完成”。

输出：

```text
1. 修改文件列表
2. 数据协议变化
3. Server API / DB 兼容说明
4. Admin 新玩法配置方式
5. Web 实现说明
6. WeChat 实现说明
7. spot_difference 清理结果
8. 自动化测试结果
9. 未能自动测试的真机项目
10. 是否需要生产 DB migration
```

并附：

```bash
git status --short
git diff --stat
```

如测试失败，不允许忽略；说明失败原因并继续修复到仓库内可修复的部分全部通过。

---

# 22. 本次最终定义，不要自行扩需求

本次最终产品结构就是：

```text
《错位大侦探》
    │
    ├── Series A
    │     ├── Level 1：找穿帮
    │     ├── Level 2：拼图
    │     ├── Level 3：找穿帮
    │     └── Level 4：拼图
    │
    └── Series B
          ├── Level 1：拼图
          └── Level 2：找穿帮
```

Level：

```text
mode=find_anachronism
    → Hotspot Editor
    → 找出所有异常
    → complete

mode=image_puzzle
    → Puzzle Editor
    → 少量矩形区域两两错位
    → 玩家点击两个格子交换
    → board identity
    → complete
```

P0 只把这两套玩法做完整、做稳定。

不要在本次 PR 中自行加入：

```text
spot_difference
restore_then_find
rotate
cycle
drag-jigsaw
timer mode
IAP
广告复活
复杂评分系统
```

---

# 23. Codex 可直接使用的首条执行指令

将本文件放在仓库后，可直接对 Codex 发送：

```text
请严格按照 docs/CODEX_IMAGE_PUZZLE_IMPLEMENTATION.md 实现本次功能。

先完整阅读文档和当前仓库代码，再执行 git grep 检查现状。
按 Phase 1 → 2 → 3 → 4 顺序实现：
contracts/server → admin → webgame → wechat。

不要修改 client/ Godot。
不要新增文档未定义的玩法。
不要保留 Admin 中的 spot_difference 创建入口。
所有修改必须补测试并运行文档要求的 check/test。
遇到当前代码与文档存在差异时，以产品定义和验收标准为准，在现有架构内做最小风险实现，不要推翻现有登录、进度、缓存、音频、水印等系统。

完成后按文档第 21 节输出完整执行报告。
```

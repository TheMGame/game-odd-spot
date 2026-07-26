# 每日挑战产物契约

## 图片

- 正式图：PNG，1024×1536，RGB/RGBA。
- 审核图：同尺寸 PNG，允许答案圈和编号。
- 正式图只能是单一连续场景，不得包含答案标记。

## level.json

```json
{
  "series_slug": "daily_task",
  "level_id": "daily_YYYYMMDD_topic_slug",
  "title": "中文标题",
  "description": "一句话说明热点场景",
  "instruction": "找出8个不属于这个场景的物品",
  "mode": "find_anachronism",
  "difficulty": "hard",
  "date": "YYYY-MM-DD",
  "image": {
    "local_path": "daily_YYYYMMDD_topic_slug.png",
    "width": 1024,
    "height": 1536
  },
  "differences": [
    {
      "id": "target_01",
      "name": "具体物品名",
      "description": "它在画面中的实际位置与特征",
      "x": 0.5,
      "y": 0.5,
      "radius": 0.04
    }
  ],
  "source_summary": "热点事实的简短概述，不复制新闻原文",
  "status": "draft"
}
```

## 字段规则

- `date` 必须和目录日期、关卡 ID 日期一致。
- 默认 `differences` 恰好 8 项；专家难度允许 10 项。
- `id` 唯一且连续。
- `x`、`y` 在 0–1 之间，必须来自最终成图。
- `radius` 在 0.02–0.08 之间。
- `description` 必须描述实际画面位置，便于人工复核。
- `image.local_path` 只能指向目录内的正式 PNG，不得指向 `review.png`。
- 默认 `status` 为 `draft`。

#!/usr/bin/env python3
"""Validate a generated daily Odd Spot challenge package."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image


LEVEL_ID_RE = re.compile(r"^daily_(\d{8})_[a-z0-9_]+$")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate(directory: Path) -> list[str]:
    errors: list[str] = []
    if not directory.is_dir():
        return [f"目录不存在：{directory}"]

    for required in ("level.json", "prompt.md", "sources.md", "review.png"):
        if not (directory / required).is_file():
            fail(errors, f"缺少文件：{required}")

    config_path = directory / "level.json"
    if not config_path.is_file():
        return errors

    try:
        data = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(errors, f"level.json 无法读取：{exc}")
        return errors

    level_id = data.get("level_id", "")
    match = LEVEL_ID_RE.fullmatch(level_id)
    if not match:
        fail(errors, "level_id 必须符合 daily_YYYYMMDD_topic_slug")

    date = data.get("date")
    if match and date != f"{match.group(1)[:4]}-{match.group(1)[4:6]}-{match.group(1)[6:]}":
        fail(errors, "date 与 level_id 中的日期不一致")

    if data.get("series_slug") != "daily_task":
        fail(errors, "series_slug 必须为 daily_task")
    if data.get("mode") != "find_anachronism":
        fail(errors, "mode 必须为 find_anachronism")
    if data.get("difficulty") not in {"hard", "expert"}:
        fail(errors, "difficulty 必须为 hard 或 expert")
    if data.get("status") != "draft":
        fail(errors, "默认交付状态必须为 draft")

    image_info = data.get("image")
    if not isinstance(image_info, dict):
        fail(errors, "image 必须是对象")
    else:
        image_name = image_info.get("local_path", "")
        if not image_name or Path(image_name).name != image_name or image_name == "review.png":
            fail(errors, "image.local_path 必须是目录内的正式图片文件名")
        else:
            image_path = directory / image_name
            if not image_path.is_file():
                fail(errors, f"正式图片不存在：{image_name}")
            else:
                try:
                    with Image.open(image_path) as image:
                        if image.format != "PNG":
                            fail(errors, "正式图片必须为 PNG")
                        if image.size != (1024, 1536):
                            fail(errors, f"正式图片尺寸必须为 1024×1536，当前为 {image.size}")
                except OSError as exc:
                    fail(errors, f"正式图片无法读取：{exc}")
        if image_info.get("width") != 1024 or image_info.get("height") != 1536:
            fail(errors, "image.width/height 必须为 1024/1536")

    differences = data.get("differences")
    expected = 10 if data.get("difficulty") == "expert" else 8
    if not isinstance(differences, list) or len(differences) != expected:
        fail(errors, f"differences 必须恰好包含 {expected} 项")
        differences = differences if isinstance(differences, list) else []

    seen_ids: set[str] = set()
    for index, item in enumerate(differences, start=1):
        prefix = f"differences[{index - 1}]"
        if not isinstance(item, dict):
            fail(errors, f"{prefix} 必须是对象")
            continue
        target_id = item.get("id")
        if target_id in seen_ids:
            fail(errors, f"{prefix}.id 重复：{target_id}")
        if target_id:
            seen_ids.add(target_id)
        for field in ("name", "description"):
            if not isinstance(item.get(field), str) or not item[field].strip():
                fail(errors, f"{prefix}.{field} 不能为空")
        for field in ("x", "y"):
            value = item.get(field)
            if not isinstance(value, (int, float)) or not 0 <= value <= 1:
                fail(errors, f"{prefix}.{field} 必须在 0–1 之间")
        radius = item.get("radius")
        if not isinstance(radius, (int, float)) or not 0.02 <= radius <= 0.08:
            fail(errors, f"{prefix}.radius 必须在 0.02–0.08 之间")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("challenge_directory", type=Path)
    args = parser.parse_args()
    errors = validate(args.challenge_directory.resolve())
    if errors:
        print("校验失败：")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"校验通过：{args.challenge_directory.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

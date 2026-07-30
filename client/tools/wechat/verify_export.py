#!/usr/bin/env python3
"""Validate a godot-minigame WeChat export without exposing secret contents."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

PLACEHOLDER_APP_IDS = {"", "wx0000000000000000"}
MAX_EXPECTED_FILE_BYTES = 32 * 1024 * 1024
TEXT_SUFFIXES = {
    ".cfg",
    ".html",
    ".ini",
    ".js",
    ".json",
    ".md",
    ".properties",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}
PRIVATE_KEY_PATTERN = re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")
APP_SECRET_PATTERN = re.compile(
    r"""(?ix)
    ["']?(?:app_?secret|secret)["']?
    \s*[:=]\s*
    ["']([a-z0-9_\-]{12,})["']
    """
)


def load_json(path: Path, failures: list[str]) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        failures.append(f"{path.name} is not valid UTF-8 JSON: {exc}")
        return None


def relative_parts(path: Path, root: Path) -> tuple[str, ...]:
    return tuple(part.lower() for part in path.relative_to(root).parts)


def validate_wasm_runtime(
    wasm_path: Path, failures: list[str], warnings: list[str]
) -> None:
    node = shutil.which("node")
    if node is None:
        warnings.append(
            "Node.js is unavailable; skipped Brotli WASM section validation."
        )
        return
    script = r"""
const fs = require("fs");
const zlib = require("zlib");
const path = process.argv[1];
const packed = fs.readFileSync(path);
const wasm = path.endsWith(".br") ? zlib.brotliDecompressSync(packed) : packed;
if (wasm.length < 8 || wasm.subarray(0, 4).toString("hex") !== "0061736d") {
    throw new Error("invalid WebAssembly header");
}
let offset = 8;
const sections = [];
function readUleb() {
    let value = 0;
    let shift = 0;
    while (offset < wasm.length) {
        const byte = wasm[offset++];
        value += (byte & 0x7f) * 2 ** shift;
        if ((byte & 0x80) === 0) return value;
        shift += 7;
    }
    throw new Error("truncated WebAssembly section length");
}
while (offset < wasm.length) {
    const id = wasm[offset++];
    const size = readUleb();
    sections.push(id);
    offset += size;
    if (offset > wasm.length) throw new Error("truncated WebAssembly section");
}
process.stdout.write(JSON.stringify({
    valid: WebAssembly.validate(wasm),
    sections,
    unpackedBytes: wasm.length,
}));
"""
    try:
        result = subprocess.run(
            [node, "-e", script, str(wasm_path)],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        report = json.loads(result.stdout)
    except (
        OSError,
        subprocess.SubprocessError,
        json.JSONDecodeError,
    ) as exc:
        failures.append(f"Cannot validate {wasm_path.name}: {exc}")
        return
    if not report.get("valid"):
        failures.append(f"{wasm_path.name} is not valid WebAssembly.")
    if 13 in report.get("sections", []):
        failures.append(
            f"{wasm_path.name} contains unsupported Wasm EH section 13."
        )


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: verify_export.py <wechat-output-dir>", file=sys.stderr)
        print("VERIFY_EXPORT_FAILED")
        return 2

    output_dir = Path(sys.argv[1]).expanduser().resolve()
    failures: list[str] = []
    warnings: list[str] = []

    if not output_dir.is_dir():
        failures.append(f"Output directory does not exist: {output_dir}")
        files: list[Path] = []
    else:
        files = sorted(path for path in output_dir.rglob("*") if path.is_file())
        if not files:
            failures.append("Output directory is empty.")

    by_name = {path.relative_to(output_dir).as_posix(): path for path in files}
    for required in ("project.config.json", "game.js", "game.json"):
        if required not in by_name:
            failures.append(f"Missing required file: {required}")

    engine_dir = output_dir / "engine"
    if not engine_dir.is_dir():
        failures.append("Missing engine/ directory.")

    bin_files = [path for path in files if path.suffix.lower() == ".bin"]
    wasm_files = [
        path
        for path in files
        if path.name.lower().endswith((".wasm", ".wasm.br"))
    ]
    if not bin_files:
        failures.append("No *.bin resource pack found.")
    if not wasm_files:
        failures.append("No *.wasm or *.wasm.br engine file found.")

    engine_game = output_dir / "engine" / "game.js"
    if engine_game.is_file():
        engine_game_source = engine_game.read_text(encoding="utf-8", errors="replace")
        if "/subpackages/project/demo-pck.bin" not in engine_game_source:
            failures.append(
                "engine/game.js does not load the project resource subpackage."
            )
        if "/engine/empty-tips.bin" in engine_game_source:
            failures.append("engine/game.js still loads the template demo pack.")
    project_pack = output_dir / "subpackages" / "project" / "demo-pck.bin"
    if not project_pack.is_file():
        failures.append("Missing project resource subpackage pack.")
    if (output_dir / "engine" / "demo-pck.bin").exists():
        failures.append("Project pack was not split out of the engine subpackage.")
    loader = output_dir / "godot-loader.js"
    if loader.is_file():
        loader_source = loader.read_text(encoding="utf-8", errors="replace")
        if "[OddSpot] engine subpackage ready" not in loader_source:
            failures.append("godot-loader.js lacks robust subpackage completion handling.")
        if "engine subpackage progress:" in loader_source:
            failures.append("godot-loader.js still logs every progress event.")
    root_game = output_dir / "game.js"
    if root_game.is_file():
        root_game_source = root_game.read_text(encoding="utf-8", errors="replace")
        if "GameGlobal.oddSpotWechatAuth" not in root_game_source:
            failures.append("game.js does not expose the WeChat login bridge.")
    if (output_dir / "engine" / "empty-tips.bin").exists():
        failures.append("Template demo pack engine/empty-tips.bin was not removed.")

    engine_runtime = output_dir / "engine" / "godot.js"
    if engine_runtime.is_file():
        runtime_source = engine_runtime.read_text(encoding="utf-8", errors="replace")
        request_body_markers = (
            "ArrayBuffer.isView(body)",
            "body.byteOffset",
            "body.byteLength",
            "wx.request",
        )
        if not all(marker in runtime_source for marker in request_body_markers):
            failures.append(
                "engine/godot.js does not normalize WASM TypedArray request bodies "
                "for wx.request."
            )

    for wasm_path in wasm_files:
        validate_wasm_runtime(wasm_path, failures, warnings)

    adapter = output_dir / "weapp-adapter.js"
    if adapter.is_file():
        adapter_source = adapter.read_text(encoding="utf-8", errors="replace")
        if "wx.showKeyboard({" not in adapter_source:
            failures.append(
                "weapp-adapter.js does not connect Godot text fields to "
                "the native WeChat keyboard."
            )

    for path in files:
        parts = relative_parts(path, output_dir)
        joined = "/".join(parts)
        if "tests" in parts:
            failures.append(f"Export contains tests/: {joined}")
        if joined.startswith("addons/godot-minigame/"):
            failures.append(f"Export contains editor plugin files: {joined}")
        if path.name.lower() == ".env" or path.name.lower().startswith(".env."):
            failures.append(f"Export contains environment file: {joined}")
        try:
            raw = path.read_bytes()
        except OSError as exc:
            failures.append(f"Cannot read {joined}: {exc}")
            continue
        if PRIVATE_KEY_PATTERN.search(raw):
            failures.append(f"Private key material detected in: {joined}")
        if path.suffix.lower() in TEXT_SUFFIXES:
            text = raw.decode("utf-8", errors="ignore")
            if APP_SECRET_PATTERN.search(text):
                failures.append(f"Possible non-empty AppSecret detected in: {joined}")

    project_config = None
    if "project.config.json" in by_name:
        project_config = load_json(by_name["project.config.json"], failures)
    if isinstance(project_config, dict):
        app_id = str(project_config.get("appid", "")).strip()
        if app_id in PLACEHOLDER_APP_IDS:
            warnings.append("AppID is still a placeholder; the export is not ready to upload.")
        elif not re.fullmatch(r"wx[0-9a-zA-Z]{16}", app_id):
            warnings.append("AppID does not match the expected wx + 16 character format.")

    if "game.json" in by_name:
        game_config = load_json(by_name["game.json"], failures)
        if isinstance(game_config, dict):
            orientation = str(game_config.get("deviceOrientation", "")).lower()
            if orientation != "portrait":
                failures.append(
                    f"game.json deviceOrientation must be portrait, found: {orientation or '<missing>'}"
                )
            subpackages = game_config.get("subpackages", [])
            if not any(
                isinstance(item, dict)
                and item.get("name") == "project"
                and item.get("root") == "subpackages/project/"
                for item in subpackages
            ):
                failures.append("game.json is missing the project resource subpackage.")

    engine_manifest = output_dir / "engine" / "native-audio-manifest.js"
    if engine_manifest.is_file():
        manifest_source = engine_manifest.read_text(encoding="utf-8", errors="replace")
        marker = "GameGlobal.__godotMinigameNativeAudioManifest = "
        assignment = next(
            (line for line in manifest_source.splitlines() if line.startswith(marker)),
            "",
        )
        if not assignment:
            failures.append("engine/native-audio-manifest.js has an unexpected format.")
        else:
            try:
                manifest = json.loads(assignment[len(marker) :].rstrip(";"))
                for asset in manifest.get("assets", {}).values():
                    if not isinstance(asset, dict):
                        continue
                    source = str(asset.get("src", "")).removeprefix("/")
                    if source and not (output_dir / source).is_file():
                        failures.append(f"Native audio manifest references a missing file: {source}")
            except json.JSONDecodeError as exc:
                failures.append(f"engine/native-audio-manifest.js contains invalid JSON: {exc}")

    ranked = sorted(files, key=lambda path: path.stat().st_size, reverse=True)
    total_bytes = sum(path.stat().st_size for path in files)
    print(f"Output: {output_dir}")
    print(f"Files: {len(files)}")
    print(f"Total bytes: {total_bytes}")
    print("Largest files:")
    for path in ranked[:10]:
        size = path.stat().st_size
        marker = " [LARGE]" if size > MAX_EXPECTED_FILE_BYTES else ""
        print(f"  {size:>12}  {path.relative_to(output_dir).as_posix()}{marker}")

    for warning in warnings:
        print(f"WARNING: {warning}")
    for failure in failures:
        print(f"ERROR: {failure}", file=sys.stderr)

    if failures:
        print("VERIFY_EXPORT_FAILED")
        return 1
    print("VERIFY_EXPORT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

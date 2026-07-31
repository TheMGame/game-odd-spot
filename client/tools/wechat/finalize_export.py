#!/usr/bin/env python3
"""Normalize template-owned runtime files after godot-minigame export."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

TEMPLATE_PACK = "/engine/empty-tips.bin"
PROJECT_PACK = "/engine/demo-pck.bin"
PROJECT_SUBPACKAGE = "project"
PROJECT_SUBPACKAGE_PACK = "/subpackages/project/demo-pck.bin"
ENGINE_BASENAME = "godot-wechat-clean"
WECHAT_ADAPTER_IMPORT = "import './weapp-adapter'\n"
WECHAT_BRIDGE_EXPORT = (
    "import './weapp-adapter'\n"
    "// Expose the WeChat API to Godot JavaScriptBridge.get_interface('wx').\n"
    "GameGlobal.wx = wx\n"
    "GameGlobal.oddSpotWechatAuth = {\n"
    "    result: { state: 'idle', code: '', message: '' },\n"
    "    begin() {\n"
    "        this.result = { state: 'pending', code: '', message: '' }\n"
    "        wx.login({\n"
    "            timeout: 10000,\n"
    "            success: (res) => {\n"
    "                this.result = res && res.code\n"
    "                    ? { state: 'success', code: res.code, message: '' }\n"
    "                    : { state: 'failed', code: '', message: 'wx.login did not return a code' }\n"
    "            },\n"
    "            fail: (res) => {\n"
    "                this.result = { state: 'failed', code: '', message: (res && res.errMsg) || 'wx.login failed' }\n"
    "            }\n"
    "        })\n"
    "    },\n"
    "    getResult() { return JSON.stringify(this.result) }\n"
    "}\n"
)
TYPED_ARRAY_REQUEST = "data:body,header:headers"
ARRAY_BUFFER_REQUEST = (
    "data:ArrayBuffer.isView(body)"
    "?body.buffer.slice(body.byteOffset,body.byteOffset+body.byteLength)"
    ":body,header:headers"
)
EMPTY_ELEMENT_FOCUS = "value: function focus() { }"
WECHAT_ELEMENT_FOCUS = """value: function focus() {
                    if ((this.tagName === 'INPUT' || this.tagName === 'TEXTAREA') &&
                        typeof wx !== 'undefined' && wx.showKeyboard) {
                        const elem = this
                        if (wx.offKeyboardInput) wx.offKeyboardInput()
                        if (wx.offKeyboardConfirm) wx.offKeyboardConfirm()
                        if (wx.offKeyboardComplete) wx.offKeyboardComplete()
                        const emitInput = function (res) {
                            elem.value = res.value || ''
                            elem.selectionStart = elem.value.length
                            elem.selectionEnd = elem.value.length
                            elem.dispatchEvent({ type: 'input', target: elem })
                        }
                        wx.onKeyboardInput(emitInput)
                        wx.onKeyboardConfirm(function (res) {
                            emitInput(res)
                            if (wx.hideKeyboard) wx.hideKeyboard()
                        })
                        wx.onKeyboardComplete(function () {
                            elem.dispatchEvent({ type: 'blur', target: elem })
                        })
                        wx.showKeyboard({
                            defaultValue: elem.value || '',
                            maxLength: 256,
                            multiple: this.tagName === 'TEXTAREA',
                            confirmHold: false,
                            confirmType: 'done'
                        })
                    }
                }"""
OLD_ENGINE_LOADER = (
    'loadGameEngine(){wx.loadSubpackage({complete:t=>{},name:"engine",success:()=>{'
    "this.progress=1,this.updateProgress(this.progress,this.config.textConfig.initText)"
    '}}).onProgressUpdate((({progress:t})=>{console.log("progress:",t),'
    "this.progress=t/100,this.updateProgress(this.progress,"
    "this.config.textConfig.downloadingText[0])}))}"
)
ROBUST_ENGINE_LOADER = (
    'loadGameEngine(){const t=()=>{let i=null;const e=t=>{'
    "let s=Number(t&&t.progress),o=-1;"
    "if(Number.isFinite(s)&&s>=0&&s<=1)o=s;"
    "else if(Number.isFinite(s)&&s>1&&s<=100)o=s/100;"
    "const n=Number(t&&t.totalBytesWritten),r=Number(t&&t.totalBytesExpectedToWrite);"
    "if(r>0&&r<4294967295&&n>=0&&n<=r)o=Math.max(o,n/r);"
    "if(o<0)return;o=Math.max(0,Math.min(1,o));"
    "this.updateProgress(.45*o,this.config.textConfig.downloadingText[0]);"
    "if(o>=.99&&i&&i.offProgressUpdate)i.offProgressUpdate(e)};"
    'i=wx.loadSubpackage({name:"engine",'
    'success:()=>{if(i&&i.offProgressUpdate)i.offProgressUpdate(e);'
    'console.log("[OddSpot] engine subpackage ready");'
    "this.updateProgress(.45,this.config.textConfig.initText)},"
    'fail:i=>{const e=i&&i.errMsg||"unknown error";console.error('
    '"[OddSpot] engine subpackage failed:",e);'
    'this.currentText="资源加载失败";this.render();wx.showModal&&wx.showModal({'
    'title:"资源加载失败",content:e,confirmText:"重试",cancelText:"退出",'
    "success:i=>{i.confirm?t():wx.exitMiniProgram&&wx.exitMiniProgram()}})}});"
    "i&&i.onProgressUpdate&&i.onProgressUpdate(e)};t()}"
)
BRAND_RENDER_ANCHOR = (
    "this.backgroundImage&&t.drawImage(this.backgroundImage,0,0,i,e);"
)
BRAND_RENDER_BLOCK = BRAND_RENDER_ANCHOR + (
    't.fillStyle="rgba(7,42,53,.18)",t.fillRect(0,0,i,e);'
    "const brandDpr=this.dpr,brandLogo=Math.min(160*brandDpr,i*.38),"
    "brandTop=Math.max(72*brandDpr,e*.1);"
    "if(this.iconImage){const naturalWidth=this.iconImage.width||1,"
    "naturalHeight=this.iconImage.height||1,ratio=naturalWidth/naturalHeight,"
    "logoWidth=ratio>=1?brandLogo:brandLogo*ratio,"
    "logoHeight=ratio>=1?brandLogo/ratio:brandLogo;"
    "t.drawImage(this.iconImage,(i-logoWidth)/2,brandTop,logoWidth,logoHeight)}"
    't.textAlign="center",t.textBaseline="middle",t.fillStyle="#fff7df",'
    't.font=`bold ${24*brandDpr}px sans-serif`,'
    't.fillText("火眼金睛",i/2,brandTop+brandLogo+34*brandDpr);'
    't.fillStyle="rgba(255,247,223,.94)",'
    't.font=`bold ${13*brandDpr}px sans-serif`,'
    't.fillText("健康游戏忠告",i/2,brandTop+brandLogo+76*brandDpr);'
    't.font=`${11*brandDpr}px sans-serif`;'
    "const advice=[\"抵制不良游戏，拒绝盗版游戏。\","
    "\"注意自我保护，谨防受骗上当。\","
    "\"适度游戏益脑，沉迷游戏伤身。\","
    "\"合理安排时间，享受健康生活。\"];"
    "advice.forEach((line,index)=>t.fillText(line,i/2,"
    "brandTop+brandLogo+(102+22*index)*brandDpr));"
)
DEFAULT_ICON_CONFIG = """    iconConfig: {
        visible: true,
        style: {
            width: 74,
            height: 30,
            bottom: 20,
        },
    },"""
BRANDED_ICON_CONFIG = DEFAULT_ICON_CONFIG.replace("visible: true", "visible: false")
DEFAULT_ICON_IMAGE = "iconImage: 'images/logo.png'"
BRANDED_ICON_IMAGE = "iconImage: 'images/oddspot-logo.png'"
DEFAULT_PROGRESS_COLOR = "foregroundColor: '#4CAF50'"
BRANDED_PROGRESS_COLOR = "foregroundColor: '#e6b95c'"
OLD_PROJECT_START = (
    "const pack = '/engine/demo-pck.bin';\n"
    "GODOTSDK.startGame(exe, pack)"
)
PROJECT_SUBPACKAGE_START = (
    f"const pack = '{PROJECT_SUBPACKAGE_PACK}';\n"
    "const projectTask = wx.loadSubpackage({\n"
    f"    name: '{PROJECT_SUBPACKAGE}',\n"
    "    success: () => {\n"
    "        if (projectTask.offProgressUpdate) "
    "projectTask.offProgressUpdate(onProjectProgress)\n"
    "        GameGlobal.godotLoader.updateProgress(0.9, "
    "GameGlobal.godotLoader.config.textConfig.compilingText)\n"
    "        GODOTSDK.startGame(exe, pack)\n"
    "    },\n"
    "    fail: (res) => {\n"
    "        const message = (res && res.errMsg) || 'unknown error'\n"
    "        console.error('[OddSpot] project subpackage failed:', message)\n"
    "        GameGlobal.godotLoader.currentText = '资源加载失败'\n"
    "        GameGlobal.godotLoader.render()\n"
    "        if (wx.showModal) wx.showModal({\n"
    "            title: '资源加载失败', content: message, showCancel: false\n"
    "        })\n"
    "    }\n"
    "})\n"
    "function onProjectProgress(res) {\n"
    "        let rawProgress = Number(res && res.progress)\n"
    "        let progress = -1\n"
    "        if (Number.isFinite(rawProgress) && rawProgress >= 0 && rawProgress <= 1) {\n"
    "            progress = rawProgress\n"
    "        } else if (Number.isFinite(rawProgress) && rawProgress > 1 && rawProgress <= 100) {\n"
    "            progress = rawProgress / 100\n"
    "        }\n"
    "        {\n"
    "            const written = Number(res && res.totalBytesWritten)\n"
    "            const total = Number(res && res.totalBytesExpectedToWrite)\n"
    "            if (total > 0 && total < 4294967295 && written >= 0 && written <= total) {\n"
    "                progress = Math.max(progress, written / total)\n"
    "            }\n"
    "        }\n"
    "        if (progress < 0) return\n"
    "        progress = Math.max(0, Math.min(1, progress))\n"
    "        GameGlobal.godotLoader.updateProgress(\n"
    "            0.45 + 0.45 * progress,\n"
    "            GameGlobal.godotLoader.config.textConfig.downloadingText[0]\n"
    "        )\n"
    "        if (progress >= 0.99 && projectTask.offProgressUpdate) {\n"
    "            projectTask.offProgressUpdate(onProjectProgress)\n"
    "        }\n"
    "}\n"
    "if (projectTask && projectTask.onProgressUpdate) {\n"
    "    projectTask.onProgressUpdate(onProjectProgress)\n"
    "}"
)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: finalize_export.py <wechat-output-dir>", file=sys.stderr)
        return 2

    output_dir = Path(sys.argv[1]).expanduser().resolve()
    engine_dir = output_dir / "engine"
    engine_game = engine_dir / "game.js"
    root_game = output_dir / "game.js"
    project_pack = engine_dir / "demo-pck.bin"
    root_manifest = output_dir / "native-audio-manifest.js"
    engine_manifest = engine_dir / "native-audio-manifest.js"

    existing_project_pack = (
        output_dir / "subpackages" / PROJECT_SUBPACKAGE / "demo-pck.bin"
    )
    for required in (engine_game, root_game, root_manifest):
        if not required.is_file():
            print(f"Missing required export file: {required}", file=sys.stderr)
            return 1
    if not project_pack.is_file() and not existing_project_pack.is_file():
        print(f"Missing required export file: {project_pack}", file=sys.stderr)
        return 1

    game_source = engine_game.read_text(encoding="utf-8")
    game_source = game_source.replace(
        "const exe = '/engine/godot';",
        f"const exe = '/engine/{ENGINE_BASENAME}';",
        1,
    )
    if TEMPLATE_PACK in game_source:
        game_source = game_source.replace(TEMPLATE_PACK, PROJECT_PACK)
    if OLD_PROJECT_START in game_source:
        game_source = game_source.replace(
            OLD_PROJECT_START, PROJECT_SUBPACKAGE_START, 1
        )
    elif f"const pack = '{PROJECT_SUBPACKAGE_PACK}';" in game_source:
        # Refresh a previously finalized export as well. Everything after this
        # declaration is finalizer-owned project-subpackage bootstrap code.
        game_source = (
            game_source.split(
                f"const pack = '{PROJECT_SUBPACKAGE_PACK}';", 1
            )[0]
            + PROJECT_SUBPACKAGE_START
        )
    engine_game.write_text(game_source, encoding="utf-8", newline="\n")
    if PROJECT_SUBPACKAGE_PACK not in game_source:
        print("engine/game.js does not load the project resource subpackage.", file=sys.stderr)
        return 1

    project_subpackage_dir = output_dir / "subpackages" / PROJECT_SUBPACKAGE
    project_subpackage_dir.mkdir(parents=True, exist_ok=True)
    project_subpackage_pack = project_subpackage_dir / "demo-pck.bin"
    if project_pack.is_file():
        if project_subpackage_pack.exists():
            project_subpackage_pack.unlink()
        shutil.move(str(project_pack), str(project_subpackage_pack))
    (project_subpackage_dir / "game.js").write_text(
        "// Odd Spot project resource subpackage.\n",
        encoding="utf-8",
        newline="\n",
    )

    game_config_path = output_dir / "game.json"
    game_config = json.loads(game_config_path.read_text(encoding="utf-8"))
    subpackages = game_config.setdefault("subpackages", [])
    if not any(
        isinstance(item, dict) and item.get("name") == PROJECT_SUBPACKAGE
        for item in subpackages
    ):
        subpackages.append({
            "name": PROJECT_SUBPACKAGE,
            "root": f"subpackages/{PROJECT_SUBPACKAGE}/",
        })
    game_config_path.write_text(
        json.dumps(game_config, ensure_ascii=False, indent=4) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    # Keep DevTools on the same modern base library used by current devices.
    # Older 3.15.x runtimes reject the WASM exception-handling section shipped
    # by the 4.3-4.6 WeChat engine templates.
    for project_config_name in ("project.config.json", "project.private.config.json"):
        project_config_path = output_dir / project_config_name
        if not project_config_path.is_file():
            continue
        project_config = json.loads(project_config_path.read_text(encoding="utf-8"))
        project_config["libVersion"] = "3.17.0"
        project_config_path.write_text(
            json.dumps(project_config, ensure_ascii=False, indent=4) + "\n",
            encoding="utf-8",
            newline="\n",
        )

    loader = output_dir / "godot-loader.js"
    loader_source = loader.read_text(encoding="utf-8")
    if OLD_ENGINE_LOADER in loader_source:
        loader_source = loader_source.replace(
            OLD_ENGINE_LOADER, ROBUST_ENGINE_LOADER, 1
        )
    if "健康游戏忠告" not in loader_source and BRAND_RENDER_ANCHOR in loader_source:
        loader_source = loader_source.replace(
            BRAND_RENDER_ANCHOR, BRAND_RENDER_BLOCK, 1
        )
    loader.write_text(loader_source, encoding="utf-8", newline="\n")
    if "[OddSpot] engine subpackage ready" not in loader_source:
        print("godot-loader.js does not contain the robust engine loader.", file=sys.stderr)
        return 1
    if "健康游戏忠告" not in loader_source:
        print("godot-loader.js does not contain the branded healthy-game notice.", file=sys.stderr)
        return 1
    root_game_source = root_game.read_text(encoding="utf-8")
    if "GameGlobal.oddSpotWechatAuth" not in root_game_source:
        root_game_source = root_game_source.replace(
            WECHAT_ADAPTER_IMPORT, WECHAT_BRIDGE_EXPORT, 1
        )
    if "GameGlobal.oddSpotWechatAuth" not in root_game_source:
        print("game.js does not expose the WeChat login bridge.", file=sys.stderr)
        return 1
    root_game_source = root_game_source.replace(
        DEFAULT_ICON_CONFIG, BRANDED_ICON_CONFIG, 1
    )
    root_game_source = root_game_source.replace(
        DEFAULT_ICON_IMAGE, BRANDED_ICON_IMAGE, 1
    )
    root_game_source = root_game_source.replace(
        DEFAULT_PROGRESS_COLOR, BRANDED_PROGRESS_COLOR, 1
    )
    root_game.write_text(root_game_source, encoding="utf-8", newline="\n")
    if BRANDED_ICON_IMAGE not in root_game_source or BRANDED_ICON_CONFIG not in root_game_source:
        print("game.js does not use the Odd Spot branded loading screen.", file=sys.stderr)
        return 1

    brand_logo = Path(__file__).resolve().parents[2] / "assets" / "branding" / "guagua-rabbit-logo.png"
    if not brand_logo.is_file():
        print(f"Missing Odd Spot brand logo: {brand_logo}", file=sys.stderr)
        return 1
    images_dir = output_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(brand_logo, images_dir / "oddspot-logo.png")

    # The minigame fetch bridge receives POST bodies as TypedArray views into
    # WASM memory. wx.request supports ArrayBuffer but not TypedArray here; an
    # unconverted view can become a numeric-keyed object, so JSON fields such as
    # app_id disappear at the server.
    engine_runtime = engine_dir / "godot.js"
    if not engine_runtime.is_file():
        print(f"Missing required export file: {engine_runtime}", file=sys.stderr)
        return 1
    runtime_source = engine_runtime.read_text(encoding="utf-8")
    if TYPED_ARRAY_REQUEST in runtime_source:
        runtime_source = runtime_source.replace(
            TYPED_ARRAY_REQUEST, ARRAY_BUFFER_REQUEST, 1
        )
        engine_runtime.write_text(runtime_source, encoding="utf-8", newline="\n")
    request_body_markers = (
        "ArrayBuffer.isView(body)",
        "body.byteOffset",
        "body.byteLength",
        "wx.request",
    )
    if not all(marker in runtime_source for marker in request_body_markers):
        print("engine/godot.js does not normalize TypedArray request bodies.", file=sys.stderr)
        return 1

    # Do not rewrite the memory section inside the compressed WASM binary.
    # The Godot 4.6 WeChat runtime contains section encodings that the old
    # patcher did not preserve, producing an invalid module ("unexpected
    # section") in WeChat DevTools. The JS heap cap above limits growth without
    # mutating the vendor-provided engine binary.
    original_wasm = engine_dir / "godot.wasm.br"
    versioned_wasm = engine_dir / f"{ENGINE_BASENAME}.wasm.br"
    if original_wasm.is_file():
        if versioned_wasm.exists():
            versioned_wasm.unlink()
        original_wasm.rename(versioned_wasm)

    adapter = output_dir / "weapp-adapter.js"
    if not adapter.is_file():
        print(f"Missing required export file: {adapter}", file=sys.stderr)
        return 1
    adapter_source = adapter.read_text(encoding="utf-8")
    if EMPTY_ELEMENT_FOCUS in adapter_source:
        adapter_source = adapter_source.replace(
            EMPTY_ELEMENT_FOCUS, WECHAT_ELEMENT_FOCUS, 1
        )
        adapter.write_text(adapter_source, encoding="utf-8", newline="\n")
    if "wx.showKeyboard({" not in adapter_source:
        print("weapp-adapter.js does not connect text fields to wx.showKeyboard.", file=sys.stderr)
        return 1

    template_pack = engine_dir / "empty-tips.bin"
    if template_pack.is_file():
        template_pack.unlink()

    # The template ships a demo MP3 manifest inside engine/. The exporter emits
    # the authoritative project manifest at the root, so mirror its data into
    # the engine subpackage before engine/game.js imports it.
    root_source = root_manifest.read_text(encoding="utf-8")
    marker = "GameGlobal.__godotMinigameNativeAudioManifest = "
    assignment = next(
        (line for line in root_source.splitlines() if line.startswith(marker)),
        "",
    )
    if not assignment:
        print("Root native audio manifest is not in the expected format.", file=sys.stderr)
        return 1
    manifest_data = json.loads(assignment[len(marker) :].rstrip(";"))
    engine_manifest.write_text(
        marker + json.dumps(manifest_data, ensure_ascii=False, separators=(",", ":")) + ";\n",
        encoding="utf-8",
        newline="\n",
    )

    referenced_audio = {
        str(asset.get("src", "")).replace("\\", "/").removeprefix("/")
        for asset in manifest_data.get("assets", {}).values()
        if isinstance(asset, dict) and asset.get("src")
    }
    native_audio_dir = output_dir / "native_audio"
    if native_audio_dir.is_dir():
        for path in native_audio_dir.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(output_dir).as_posix()
            if relative not in referenced_audio:
                path.unlink()
        if not any(native_audio_dir.iterdir()):
            shutil.rmtree(native_audio_dir)

    print("FINALIZE_EXPORT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

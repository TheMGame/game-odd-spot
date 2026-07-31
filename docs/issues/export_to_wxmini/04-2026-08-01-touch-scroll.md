# 2026-08-01 微信列表触摸滚动不灵敏

## 现象

微信小游戏真机中，首页系列列表、关卡列表和设置列表上下滑动时，经常第一次拖动没有响应，需要重复触摸后才能滚动。桌面 Web 和开发者工具鼠标滚轮不容易复现。

## 原因

Godot 的 `ScrollContainer` 依赖子控件将鼠标/触摸模拟事件继续传递给父控件。关卡列表的每张卡片都是覆盖整行的 `Button`，按钮默认使用：

```gdscript
Control.MOUSE_FILTER_STOP
```

微信适配层将真机触摸事件传入 Godot Web 输入系统后，拖动手势经常先落到卡片按钮。按钮截断事件后，父级 `ScrollContainer` 无法连续收到按下和移动事件，表现为首次滑动无响应或被当作点击。

## 修复

新增微信专用滚动优化入口：

```gdscript
Platform.optimize_touch_scroll(scroll)
```

微信环境中执行以下处理：

1. 将滚动区域内的 `BaseButton.mouse_filter` 改为 `MOUSE_FILTER_PASS`；
2. 按钮仍能正常响应点击；
3. 拖动事件继续传递给父级 `ScrollContainer`；
4. 将触摸滚动 deadzone 设置为 4 像素，提高开始拖动的灵敏度。

覆盖页面：

```text
client/scenes/home/home.gd
client/scenes/level_select/level_select.gd
client/scenes/settings/settings.gd
```

公共实现：

```text
client/scripts/platform/platform.gd
```

动态创建的首页“进入”按钮和关卡卡片按钮也会在创建时立即设置为 `MOUSE_FILTER_PASS`。

## Web 兼容性

`optimize_touch_scroll()` 首先检查：

```gdscript
Platform.is_wechat_minigame()
```

普通 Web 和原生版本不会修改现有控件行为，因此本修复只改变微信小游戏触摸滚动。

## 构建与验证

应用层脚本修改后使用 Godot 4.6.2 重新导出 PCK，无需重新编译微信 WASM 引擎。

微信项目包标识：

```text
build=20260801-scroll-driver
```

正式 PCK：

```text
build/wechat/subpackages/project/demo-pck.bin
```

SHA-256：

```text
C7BD8D5489F79AEB5FE0911FAA0DD8F2FCFF531EF03AB9C57C1F2DCD986F1E55
```

导出校验结果：

```text
FINALIZE_EXPORT_OK
VERIFY_EXPORT_OK
```

## 真机验收

1. 清除微信开发者工具全部缓存并重新编译；
2. 确认控制台显示 `build=20260801-scroll-driver`；
3. 在列表卡片正文、图片和按钮区域分别上下拖动；
4. 确认一次触摸即可开始滚动；
5. 确认短按按钮仍然进入对应页面；
6. 确认拖动后不会误触发关卡进入。

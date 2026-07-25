# 火眼金睛官网

无需构建工具的静态官网，生产环境由 Nginx 直接托管。

## 本地预览

```powershell
python -m http.server 4173 --directory website
```

浏览器访问 `http://127.0.0.1:4173/`。官网中的 `/game/` 链接需要在组合发布目录中验证。

## 生产发布

运行 `scripts/package-website.ps1 -Version <site-version>`，再使用 `scripts/deploy/deploy-website.sh` 发布到 `/opt/oddspot/www/oddspot-site/`。

官网源码与 Godot Web 输出分开维护，避免每次更新官网都重新导出游戏。

Godot Web 游戏使用 `scripts/package-web-game.ps1 -Version <game-version>` 独立打包，并由 `scripts/deploy/deploy-web-game.sh` 发布到 `/opt/oddspot/www/oddspot-game/`。

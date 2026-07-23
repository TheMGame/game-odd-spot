# AI 多地区找茬游戏完整开发方案

本包用于指导 AI 编程工具或开发团队，从零实现一套“单客户端、单后端、多地区内容运营”的 AI 找茬游戏。

## 文件结构

- `AI多地区找茬游戏完整方案.docx`：供评审阅读的汇总版；发生冲突时以分章 Markdown、Schema、OpenAPI 和 SQL 为准。
- `docs/01_product_and_scope.md`：产品定位、核心循环、MVP 范围。
- `docs/02_architecture_and_modules.md`：系统架构与模块边界。
- `docs/03_content_and_localization.md`：AI 内容生产、多地区与中国大陆策略。
- `docs/04_api_and_data.md`：API、数据模型、事件与幂等要求。
- `docs/05_deployment_and_operations.md`：部署、环境、监控、备份和发布。
- `docs/06_development_roadmap.md`：P0-P3 开发计划、验收标准。
- `configs/market-config.example.yaml`：地区远程配置示例。
- `schemas/level.schema.json`：统一关卡协议 JSON Schema。
- `schemas/core_tables.sql`：核心数据表草案。
- `docs/07_state_machines_and_quality.md`：身份、进度、奖励、内容状态机与 AI 质检阈值。
- `schemas/api.openapi.yaml`：P0-P2 HTTP API 契约。
- `schemas/examples/`：合法与非法关卡协议测试样例。
- `deploy/`：Ubuntu 原生二进制、systemd、Nginx、安装与回滚示例；当前不使用 Docker。
- `prompts/ai_developer_prompt.md`：交给 AI 开发工具的总提示词。

## 推荐使用方式

1. 先让 AI 阅读 `README.md`、分章文档和 Schema；DOCX 用于产品评审。
2. 再按 `docs/06_development_roadmap.md` 的 P0 → P3 顺序实施。
3. 每个阶段必须运行对应验收用例，不允许直接跳过内容质检、支付校验或数据埋点。
4. 所有地区差异必须由远程配置和内容标签驱动，禁止在客户端写国家分支。

## 已冻结的 MVP 默认决策

- 客户端竖屏；普通关每关 5 个差异；不设失败倒计时。
- P0 只做 20 个测试关卡和单一全球内容池；P1 再引入 AI 生产与第一个正式市场。
- 匿名登录；P0 不承诺跨设备进度恢复，P2 通过平台账号/游戏账号绑定实现。
- 奖励模型只包含免费提示次数、激励广告提示和永久去强制广告，不做金币商城。
- 服务端为 Go 模块化单体；Ubuntu 使用 Nginx + systemd 原生部署，MySQL/Redis 使用服务器本机服务或托管实例。

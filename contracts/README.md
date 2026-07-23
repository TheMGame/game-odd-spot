# Contracts

这里是客户端、服务端和内容工具共同遵守的协议镜像：

- `api.openapi.yaml`：HTTP API 契约，共 26 条路径。
- `level.schema.json`：不可变运行时关卡协议。
- `examples/`：合法和非法关卡样例。

设计源位于 `docs/ai_spot_difference_solution/schemas/`。协议变更必须同步更新服务端校验、客户端解析、示例和迁移说明。

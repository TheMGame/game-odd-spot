# 7. 状态机、幂等与 AI 质检规格

> 当前认证状态机：首次安装仍生成 `installation_id`，但 Godot 不自动创建匿名 Session。无 Session 进入登录页；有 Session 时必要时刷新 token、请求 bootstrap、重放队列，再进入首页。网络、5xx、429 等临时 refresh 失败保留现有 Session，只有服务端明确判定 refresh token 无效时才清除。

## 7.1 身份生命周期

客户端首次安装生成随机 `installation_id` 并持久化。下述匿名 Session 流程是服务端保留的原始设计能力；当前客户端改用账号服务登录和 `/v1/sessions/user-server` token 交换。服务端只保存 installation_id 的 HMAC，不保存原值。

P0 只保证同一安装身份恢复。P2 支持将匿名用户绑定到 Apple、Google 或游戏账号。绑定事务必须锁定源、目标用户，将进度按关卡最高完成状态合并、权益按有效交易合并、消耗型余额按账本重算，并留下 identity_merge_audit。匿名用户不能仅凭设备参数跨设备认领。

## 7.2 关卡与进度状态机

关卡版本不可变，发布后修图必须创建新 `level_version`。玩家开始时绑定确切版本。

`not_started → in_progress → completed`；completed 为终态。客户端可重复发送 start、progress、complete。progress 上传已找到的 `difference_id` 集合增量；服务端验证该 ID 属于绑定版本。complete 只有当全部差异已找到时成功；首次完成在同一数据库事务内更新进度并写入奖励账本，重复请求重放原响应。

客户端在发送前生成 `attempt_id` 和稳定的 Idempotency-Key，并按 start → progress → complete 顺序重放。2xx 为 `synced`；网络错误、401、408、429、5xx 为 `queued`；其他确定性 4xx 为 `rejected` 并进入有上限的 dead-letter。服务端拒绝不能计为正常完成。服务端时间仍是奖励和每日限额的最终依据。

## 7.3 通用幂等规则

- 作用域为 `(user_id, route, idempotency_key)`，建议 key 使用 UUIDv7。
- 服务端保存请求体 SHA-256、处理状态、HTTP 状态码和完整响应体。
- 相同 key、相同请求重放原响应；相同 key、不同请求返回 `409 IDEMPOTENCY_CONFLICT`。
- 正在处理返回 `409 REQUEST_IN_PROGRESS` 和 `Retry-After`。
- complete、广告奖励、购买验证和礼包领取记录长期保留；普通进度记录至少保留 7 天。
- 业务写入与幂等完成记录必须处于同一数据库事务。

## 7.4 奖励与商业化

所有奖励写入 append-only `reward_ledger`，余额由账本汇总或可校验快照得到。来源至少包括 `level_complete`、`daily_free_hint`、`rewarded_ad`、`purchase`、`admin_adjustment`。

激励广告优先使用广告平台服务端回调。客户端提交 `ad_session_id` 只能登记待确认记录，收到可信回调后才发奖；不支持回调的平台必须验证平台签名凭证。平台交易先写 `purchase_transactions`，校验成功后派生权益，退款或撤销不得覆盖历史交易。

## 7.5 内容状态机

`draft → generating → generated → auto_review_failed | pending_review → approved → staging → published → disabled`。

Worker 只能创建生成结果和自动审核记录，无权写 approved/published。人工审核操作保存审核人、前后状态、原因和时间。published 只能由 Content Service 在事务中完成；disabled 不删除资源，客户端刷新目录后停止推荐。

## 7.6 自动图像质检基线

所有图像转换为 sRGB、相同尺寸并完成像素对齐，再执行差分。阈值必须由标注基准集校准，以下是首轮工程默认值而非永久业务常量：

- mask 内变化召回率 ≥ 0.90；预测差分与膨胀后 mask 的 IoU ≥ 0.70。
- mask 外显著变化像素占全图比例 ≤ 0.20%，且不得形成面积超过全图 0.05% 的独立连通域。
- 单个差异有效面积占全图 0.15%～8%；距图片边缘至少为短边的 2%。
- 任意两个差异 mask 膨胀短边 1.5% 后不得相交。
- 5 差异关卡至少包含 1 个易、2 个中、1 个难差异；不得全部为颜色类差异。
- OCR 检出乱码、人物面部/手部严重畸形、品牌标识或高风险内容时必须进入人工复审，不允许自动发布。

自动分数 ≥ 90 且无风险标记进入 pending_review；70～89 进入人工复审队列；低于 70 自动失败。首发阶段所有关卡仍需人工审核，积累至少 500 个审核样本并评估误放率后，才可讨论低风险内容自动放行。

## 7.7 灰度与自动下架

关卡按稳定 hash 分桶灰度 1% → 10% → 100%，每阶段至少积累 200 次开始或运行 48 小时。举报率、崩溃率或资源错误超过硬阈值立即 disabled；提示率、误点率和退出率异常时停止扩量并进入复审。所有阈值由版本化远程配置管理。

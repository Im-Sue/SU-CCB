---
id: cmpqls8ny3f0b1c1c0c91b0d7
title: 对接CCB面板的tip动态编写
doc_type: requirement
status: delivered
created: 2026-05-29T07:31:18.622Z
analysis_input_hash: 4b872b56119777510529e6e797f5b7067e768e4fa5c4d9d94123febe615406cf
analysis_applied_at: 2026-05-29T13:56:44.768Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

CCB（ https://github.com/SeemSeam/claude_codex_bridge ）现在在tmux里有一个区域用来展示tips，支持自定义修改和动态更新，我们现在需求绑定slot之后打开slot面板（独立的tmux终端）没办法直观的看到哪个slot对应哪个需求，做一个功能：绑定slot的时候向ccb的配置文件（tip区的内容）加上slotN-需求名，解绑的时候清除。
## 原话（verbatim）

CCB现在在tmux里有一个区域用来展示tips，支持自定义修改和动态更新，我们现在需求绑定slot之后打开slot面板（独立的tmux终端）没办法直观的看到哪个slot对应哪个需求，做一个功能：绑定slot的时候向ccb的配置文件（tip区的内容）加上slotN-需求名，解绑的时候清除。

## Claude 解读

> 本节经 requirement_analysis 节点产出：源码双源核验（CCB v7.0.11 `~/.local/share/codex-dual` + Console `apps/ccb-console`）+ slot1_codex 协商（job_99750bb0b7dc）+ 用户拍板。

### 功能本质

Console 在"绑定 / 解绑 slot ↔ 需求"时，把 slot↔需求映射**投影**到 CCB 配置文件 `.ccb/ccb.config` 的 `[ui.sidebar.view].tips` 数组（受管行），使 CCB 原生 tmux sidebar 的 tip 区能直观显示哪个 slot 对应哪个需求。这是兼容当前 CCB 能力的**业务投影**（非 CCB 原生状态；属 ADR-0032 边界外的务实接线，已显式接受）。

### 设计模型（经协商定为「全量投影」而非「增量改单行」）

- **全量重算**：绑定 / 解绑 / 启动 reconciliation 时，在 per-project 锁内重查当前全部 SlotBinding + Requirement 标题，原子重写 Console 受管的全部 tip 行。幂等、抗并发、抗启动重写。
- **受管行隔离**：受管行带统一前缀（如 `CCB Console | slot-N: <标题>`），只增删 / 重写带前缀的行；用户手写 tips 与 TOML 注释 / 格式尽量保留，不整段接管。
- **内容**：每行 = `slot-N: <需求标题，过长截断>`，标题取**绑定时刻快照**（MVP）。
- **显示范围**：tips 是全局数组 → 每个 slot 的 sidebar 都显示全部映射表（用户已接受："tips 里能显示全部即可"）。
- **刷新**：正确性 P0（绑对位置、增删正确）。时效放宽——写完投影后 best-effort、非阻塞地向 sidebar pane（精确命中 `sidebar_pane_id`，绝不误发 agent pane）发 `'r'` 刷新；不承诺立即，允许靠 CCB 自然刷新（~1s TTL / 下次 view 重建）生效。
- **启动重写兼容**：`buildManagedCcbConfig()` 必须保留 / 重算 `[ui.sidebar.view]` 受管 tips（纳入保留集或启动 reconciliation），避免被项目启动重写抹掉。
- **错误隔离**：tips 写入 / 刷新在 `onSlotBound` / `onSlotReleased` 内必须 best-effort、非阻塞，失败不得导致"DB 已变更但绑定 / 解绑 API 返回失败"。
- **未启动 / 无 tmux**：只写投影、跳过刷新（非脏数据），CCB 启动后由 reconciliation 对齐。

### 验收口径

1. 绑定 slot→需求后，`[ui.sidebar.view].tips` 出现受管行且 slot↔需求对应正确。
2. 解绑后该 slot 受管行被移除，其它受管行与用户自定义 tips 不受影响。
3. 多 slot 并存时 tips 显示全部受管映射行（全局表），逐行对应正确。
4. 并发绑定 / 解绑不互相覆盖（锁内全量重算 + 原子写）。
5. 用户手写 tips 行在受管行增删后仍存在；TOML 注释 / 格式尽量不被破坏。
6. 项目重启后受管行不丢失。
7. tips 写入 / 刷新失败不导致绑定 / 解绑 API 失败。
8. （非严格）sidebar 通常在下次刷新内反映变化。

### 范围边界

- **本需求做**：Console 侧 slot↔需求投影到 tips；绑定 / 解绑 / 启动 reconcile；受管行隔离；best-effort 刷新；未启动安全降级。
- **本需求不做（留 TODO / 后续）**：改 CCB 本体加刷新 RPC；需求改名 / 状态变化实时同步 tips；per-window 单独显示。
- **硬约束**：不改外部 CCB 工具；不把 Console API 当业务真相源（tips = DB 派生投影）；TOML 重写保留用户内容。

### slot1_codex 协商要点（job_99750bb0b7dc）

纠正"无热重载"为"1s TTL 缓存 + project_view 重读"，无干净 invalidate RPC（`project_focus_*` 有改焦点副作用）；强烈建议全量投影模型；指出 `onSlotReleased` 不吞错的失败模式；提示 TOML 格式保留与标题 stale 风险。recommendation = 全量投影 + best-effort 刷新，analysis_depth_hint = human-decision（high confidence）。

### 4 锚点反思（摘要）

- **同意**：全量投影一招解决并发 / 启动重写 / 所有权；受管前缀隔离；未启动降级；`'r'` 精确命中 sidebar pane。
- **保留**：仍保留 best-effort 主动刷新（用户要"动态"语义），但文案不承诺立即；不现在改 CCB 本体；ADR-0032 边界 hack 是需求本意，按受限投影接受。
- **盲点**：漏了 1s TTL 缓存层、`onSlotReleased` 抛错污染事务、全量投影比增量更稳、TOML 注释保留与标题新鲜度生命周期。
- **下一步**：以投影模型为推荐解读落盘；进入技术设计前由用户决定是否继续。

## 歧义点

共 5 项核心歧义，均已闭合（用户拍板 / 工程决定 / 机制约束）：

1. **刷新时效**（"动态更新" = 立即？）→ **用户拍板**：时效不严格，正确性优先，靠默认 / best-effort 刷新即可，不为"立即"扩大范围改 CCB。
2. **显示格式**（slotN-需求名 具体串、长标题 / 窄 sidebar）→ **工程默认**：`CCB Console | slot-N: <标题截断>`，受管前缀兼作隔离标记；可后续微调。
3. **tips 数组所有权**（不碰用户自定义行）→ **工程决定**（Codex 方案）：全量投影只重写带前缀的受管行，保留用户手写 tips。
4. **与启动重写冲突**（`buildManagedCcbConfig` 抹掉 tips）→ **工程决定**：`sidebar.view` 纳入保留集 / 启动 reconciliation 重算。
5. **全局 vs 单 window 显示** → **用户拍板 + 机制约束**：tips 全局数组强制全局表；用户接受"tips 里显示全部映射"。

协商引出的补充闭合项：

- `onSlotReleased` 错误隔离 → 工程决定：tips 操作 best-effort 非阻塞，不污染绑定事务。
- 未启动 / 无 tmux → 工程决定：只写投影、跳过刷新、启动 reconcile。
- 标题改名 stale → **用户拍板**：MVP 绑定时快照，改名不自动同步，留 TODO。

**不命中维度说明**：隐私 / 合规 / 成本 / 外部服务**不命中**——纯本地配置文件读写、无数据外泄、无网络调用、无显著成本，故未就这些维度向用户提问。

## 保真差异

用户原话 → 澄清后的差异（以原话为准；差异处已获用户确认或属工程实现细节）：

1. 原话"支持……动态更新" / "打开 slot 面板直观看到" → 澄清：CCB 实际无热重载、有 ~1s TTL 缓存、无干净刷新 RPC；故落为 **best-effort 刷新、时效不严格、正确性优先**（用户已确认放宽时效）。
2. 原话"加上 slotN-需求名"（字面 = 增量加单行） → 实现为**全量投影重算**（语义不变：tips 里能看到全部映射；工程上更稳，用户已确认"显示全部即可"）。
3. 原话未区分"全局 / 单 window" → 澄清为**全局映射表**（机制强制），用户已接受。
4. 原话"需求名" → 澄清为**绑定时刻的标题快照**；改名不自动同步（MVP，用户已确认）。
5. 原话未提"用户自定义 tips 共存 / 所有权" → 补充为**受管前缀行隔离**，不碰用户手写内容（工程兜底，与原话无冲突）。
6. 原话"向 ccb 的配置文件加" → 精确化为 `.ccb/ccb.config` 的 `[ui.sidebar.view].tips`（当前文件尚无此段，需新建），属 ADR-0032 边界外的显式受限投影。

无遗留 TBD / 待定项。

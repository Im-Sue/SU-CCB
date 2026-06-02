---
id: ADR-0016
title: Node-Flow Action 结构化契约 — Deferred-with-Trigger
status: deferred
decided_at: 2026-05-10
decider: Claude
reviewer: ccb_codex (2 rounds plan review fail)
related_epic: pr13-task-detail-rewrite-fix
related_adr: [ADR-0011, ADR-0015]
related_tasks:
  - pr13-fix-f1-deferred-minimal-cleanup
deprecated_in: null
removed_in: null
grace_window: null
deferred_until: ReactiveScheduler user_arbitration_submitted apply 链路接通（见 §Trigger conditions）
impacted_components:
  - apps-ccb-console-server (modules/tasks/task-node-flow) — 仅最小 cleanup
  - apps-ccb-console-web (lib/use-task-node-flow + components/task-detail-v2/NodeActions) — 仅最小 cleanup
---

# ADR-0016: Node-Flow Action 结构化契约 — Deferred-with-Trigger

## Status

**Deferred-with-trigger**（2026-05-10）。两轮 plan review fail 后用户决策延期到触发条件满足。

## Context

### F1 finding 起源

PR-13（commit 49b060b）codex code review F1 (major)：

> 前端 `apps/ccb-console/web/src/lib/use-task-node-flow.ts:213-219` 从 `guard_reason` 文本里正则抠 UUID 作为 applyEventId，server schema 没有结构化 apply event 字段。文本变更会破坏 apply，review pass / replan 等 satisfied actions 也会被 NodeActions 禁用。

直觉上是个「web↔server 字段缺失」问题，应该可以加个结构化字段就修。

### 两轮 plan review 揭示真正的边界

**Round 1**（job_552180a988ca, overall 5.6 fail）：
- Codex P1 (blocker): 误把 `create_review_intent` payload.replanTarget 当作 transition 驱动入口
- 真相：`create_review_intent` 仅创建 pending intent，不直接 mutate task_state（`apply.routes.ts:309-350`）
- 真相：replan transition 由 `review.node.yaml` 的 `replan_from_review` subflow 内部决策（写 `task.rollback_origin`）

**Round 2**（job_bde36c0e62ed, overall 5.9 fail）：
- 调整为「Console emit `user_arbitration_submitted` event → ReactiveScheduler propose+apply」
- 看似真相源已支持（`transition-proposal.types.ts:25-54` 5 条 mappings + `event-journal.schemas.ts:42-57` payload schema）
- Codex R2-P1 (blocker): 真相源是**前置声明**，apply 链路对 user_arbitration_submitted **未实现**
  - `scheduler/handlers/autonomous-batch.handler.ts:119-128`：收 user_arbitration_submitted → pause 为 user_arbitration_pending
  - `transitions/transition-consumption.service.ts:87-102`：apply 仅支持 codex_picked_up + verification_finished
  - `tests/transition-consumption-routes.spec.ts:473-499`：user_arbitration_submitted apply 明确返回 apply_ineligible
- Codex R2-P2 (blocker): submit_event.request_body 缺 `emitEventSchema` 必填字段（event_id / task_id / emitted_at / source_actor / source_component）

### 为什么 defer 而不是继续 round 3

F1 修复在两轮探查后暴露的不是设计粗糙，是**架构未完工的边界**：

1. ReactiveScheduler 的 user_arbitration apply 链路是 v0.4 second-wave 范围（KA-2，Wave 4），当前不在范围
2. 即使继续 round 3，也只能选择两个 unsatisfying 路径之一：
   - 扩 batch 到包含 scheduler/transition-consumption apply 实现 → 跨 ReactiveScheduler 协议级，违反 batch_execution_contract.md §4「contract conflict → 停 + 升级」
   - 退到「event-submit-only」语义 → 用户点击按钮提交 event 但无副作用，UX 比当前「按钮 disable」更糟糕
3. F1 的「按钮失效」是**当前架构状态的诚实表达**，不是 bug —— Console 在 v0.4 v1 阶段是 projection / control surface（master roadmap §2.2），不是 transition apply 入口

## Decision

**defer F1 完整修复**，仅做最小 cleanup（不改变 user-facing 行为）：

1. 删除 web 端 `guard_reason` UUID 正则解析代码（`UUID_PATTERN` / `resolveApplyEventId` / `IMPLEMENTATION_READY_TRANSITION_ID`）
2. 删除 `applyTaskNodeTransition` 函数及其调用链（NodeActions 不再尝试 apply）
3. server `evaluateGuard` :198 不再向 `guard_reason` 拼接 UUID（仅留人类可读消息）
4. server `taskNodeFlowApplicableActionSchema` 新增 `applicability: "user_actionable" | "system_only"` 字段（仅类型与字段），全部 transition 当前标 `system_only`
5. web NodeActions 按 `applicability=system_only` 全部不渲染 apply 按钮（视觉退化为「只读节点状态」）

详见 `docs/.ccb/specs/active/2026-05-10-pr13-fix-f1-deferred-minimal-cleanup.md`。

## Trigger Conditions（触发重启条件）

满足以下**任一条件**时重新启动 F1 修复设计。Conditions 1-3 是机器可验证（machine_verifiable），Condition 4 是人工触发（human_override）。

### Condition 1 · ReactiveScheduler user_arbitration apply 链路落地（machine_verifiable）

具体证据要求（任一满足即触发）：

- `apps/ccb-console/server/src/modules/transitions/transition-consumption.service.ts` 中针对 `user_arbitration_submitted` event 不再返回 `apply_ineligible`，而是有成功 apply 分支
- `apps/ccb-console/server/src/tests/transition-consumption-routes.spec.ts` 中针对 `user_arbitration_submitted` 的 apply 测试断言 `result === "applied"` 而非 `apply_ineligible`
- `apps/ccb-console/server/src/modules/scheduler/handlers/autonomous-batch.handler.ts` 对 `user_arbitration_submitted` 的处理不再是 `pause to user_arbitration_pending`，改为 `propose+apply` 或 `k1_propose`
- grep `apps/ccb-console/server/src/` 出现 `user_arbitration_submitted` 与 `applied` 关键字共现的处理代码

### Condition 2 · 新增 user_arbitration_submitted apply primitive 或 K1 apply 扩展（machine_verifiable）

- `apps/ccb-console/server/src/modules/kernel/apply.routes.ts` 的 `publicKernelApplyRegistry` 新增针对 user_arbitration 的 primitive
- 或 `apps/ccb-console/server/src/modules/kernel/apply.routes.spec.ts` 含针对 user_arbitration 的成功 apply 测试

### Condition 3 · Console 定位发生变化（machine_verifiable via doc grep）

`docs/.ccb/specs/active/*roadmap*.md` 或 `docs/01_架构设计/ccb-plan/v0.4-node-kernel-northstar.md` 中 CA-5 / Console V2 描述出现 "designer UI" / "transition apply 入口" 等术语，或 master roadmap 列出新 epic 把 Console 升级为 transition driver。

### Condition 4 · F1 当前状态影响业务（human_override_trigger）

用户在实际工作流中明确表达「Console NodeActions 按钮 disable 阻碍工作」，且无法用 `/ccb:su-review` / `/ccb:su-archive` 等 skill 替代。**此条件不可机器验证**，需用户显式触发。

### 重启路径

满足任一条件后：
- 优先使用本 ADR 同目录的设计文档作为历史探查参考（`docs/03_开发计划/ccb-plan/2026-05-10-node-flow-apply-event-contract-design.md`）
- 重写设计需根据触发时点的真实架构状态调整（user_arbitration apply 实现细节、当时的 envelope schema 等）
- 走 `/ccb:su-flow` 或新 batch 重新进入 plan_review

## Consequences

### 正向

- 不在未完工架构上叠加越权 patch；与 ADR-0011 决策 2 + master roadmap §2.2 边界一致
- 删除 web 端 UUID 正则解析这个隐式契约，guard_reason 退回纯人类可读
- 当前 Console 直调 K1 越权（`use-task-node-flow.ts:172-187` 的 `applyTaskNodeTransition`）一并撤销
- 留下清晰的重启路径（trigger conditions 明确可机器验证）

### 负向

- F1 finding 中「review pass / replan 等 satisfied actions 不可执行」**不修复**：18 个 transition 全部不可点
- 用户视觉上 NodeActions 区域只剩「显示当前节点」无可操作元素 —— 比 PR-13 当前更「冷淡」
- 复杂工作流仍依赖 CLI（`/ccb:su-review` / `/ccb:su-dispatch` 等 skill），Console 不能替代
- 旧 web bundle 在新 server 下 `resolveApplyEventId` 拿不到 UUID → 该按钮 disable，行为与新 web 一致

### 兼容窗口

无 grace window 需求 —— 所有按钮都不渲染或 disable，新旧 web 行为一致（都不可点）。

## Alternatives Considered

### A1: Round 3 继续 plan review

否决：两轮探查的根因都不在「设计粗糙」，是架构未完工边界。Round 3 大概率撞同样的墙。

### A2: 扩 batch 到 6-7 slice，包含 scheduler+transition-consumption apply 实现

否决：跨 ReactiveScheduler 协议级实现，违反 `batch_execution_contract.md` §4「contract conflict → 停 + 升级」。这种规模需独立 epic + RFC。

### A3: 「event-submit-only」诚实降级

否决：用户点按钮 → server 接收 user_arbitration_submitted event → 无 apply 副作用 → UI 提示「请运行 /ccb:su-review」。UX 比当前「按钮 disable」更糟糕（诱导点击但无副作用）。

### A4: 直接接受 PR-13 review fail，强 merge 回 main

否决：F1 是 major finding；guard_reason UUID 解析是隐式契约 + 越权 K1 调用，长期会咬人。最小 cleanup（本 ADR 决策）至少把这两个隐式负担清掉。

### A5: 启动独立 RFC「Console-as-transition-apply-entry」

候选保留：如未来用户明确表达 Console 按钮失效阻碍工作（trigger condition 4），优先走 RFC 路径而非直接重启 F1 修复。

## Provenance

- PR-13 codex code review fail 报告：`docs/.ccb/state/2026-05-09-batch-pr13-followup.md` (review_result, job_dd162460f415)
- Round 1 plan review fail：job_552180a988ca, rep_18df25290950（5 P-issues）
- Round 2 plan review fail：job_bde36c0e62ed, rep_3b14335ea029（4 R2-P-issues + R1 P-status）
- Batch container：`docs/.ccb/state/2026-05-10-batch-pr13-review-fix.md`
- 历史探查设计：`docs/03_开发计划/ccb-plan/2026-05-10-node-flow-apply-event-contract-design.md` (superseded)
- 真相源验证（导致 R2 fail 的关键代码）：
  - `apps/ccb-console/server/src/modules/scheduler/handlers/autonomous-batch.handler.ts:119-128`
  - `apps/ccb-console/server/src/modules/transitions/transition-consumption.service.ts:87-102`
  - `apps/ccb-console/server/src/tests/transition-consumption-routes.spec.ts:473-499`
  - `apps/ccb-console/server/src/modules/events/event-journal.schemas.ts:20-57`
- 上游 ADR：
  - ADR-0011 决策 2（scheduler 不直接 mutate task_state）
  - ADR-0011 决策 3（K1 endpoint contract 锁定）
  - ADR-0015（defer DB CHECK + TRIGGER raw SQL — 同样是 deferred-with-trigger 模式参考）
- master roadmap §2.2：CA-5 Console V2 = projection/control surface, 不做 designer UI

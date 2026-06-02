---
doc_type: dev_task
task_id: subtask-3490a6ad2d4f
title: slot↔需求绑定投影到 ccb.config sidebar tips
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpqls8ny3f0b1c1c0c91b0d7
section_id: pr1-slot-tip-projection
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqls8ny3f0b1c1c0c91b0d7.json
source_draft_hash: 077aa228aef78b188265f5ad5dadcbb26876ac9153de4c17178065b32107cc07
created_at: 2026-05-29T14:37:26.685Z
updated_at: 2026-05-29T15:01:53.265Z
updated_by: ccb_claude
---

# slot↔需求绑定投影到 ccb.config sidebar tips

## 目标

把 slot↔需求绑定关系作 DB 派生全量投影，写入 `.ccb/ccb.config` 的 `[ui.sidebar.view].tips`，让 CCB 原生 tmux sidebar 显示 slotN→需求名；绑定增、解绑减。**同步时读取当前 `Requirement.title`**（标题改名本身不触发同步，下次任意 bind/release/startup 同步时自然跟上）。CCB sidebar 每 ~1s 自轮询自动显示，无需主动刷新。依据《技术设计》`docs/03_开发计划/slot绑定sidebar-tip投影技术设计.md`。

## 范围（实现 6 文件 + 测试）

- `[MODIFY] apps/ccb-console/server/src/modules/project-ccbd/managed-config.service.ts`：`buildManagedCcbConfig(preserved, opts?)` 支持 `opts.sidebarViewTips`；提供时渲染 `[ui.sidebar.view]` + `tips_enabled = true` + `tips = [...]`；每行字符串用 `JSON.stringify` 转义；tips **不纳入** coreSignature（`collectCoreLines`）与 preserved（`collectPreservedAgentFields`）。`renderManagedCcbConfig` / `ensureManagedCcbConfig` 透传 opts。**`ensureManagedCcbConfig` 写入改 temp+rename 原子写**（防 CCB 自轮询读到半写 TOML），对所有调用方生效。
- `[NEW] apps/ccb-console/server/src/modules/slot-binding/slot-tips-projection.service.ts`：`computeSlotTipsProjection(client, projectId)` = 查 SlotBinding（`state ∈ {bound,busy,unhealthy,recovering}` ∧ `requirementId ≠ null`）join `Requirement.title` → 行 `slot-N: <title 截断≈24 字>`，按 slotId 升序；`syncSlotTips(projectId)` = 解析 projectRoot（`Project.localPath`）、进程内 per-project mutex、锁内重查投影、调 `ensureManagedCcbConfig`（带 tips）；全程 try/catch best-effort。
- `[MODIFY] apps/ccb-console/server/src/modules/slot-binding/slot-binding.service.ts`：`releaseSlot` 调 `onSlotReleased` 补 try/catch 包装（`notifySlotReleased`，对称现有 `notifySlotBound`）；新增 `createDefaultSlotReleasedCallback`，并让默认 bind/release 回调**包含 tips sync**（覆盖走 default 的入口，如 anchor.routes）。
- `[MODIFY] apps/ccb-console/server/src/modules/slot-binding/slot.routes.ts`：bind callback 组合 `/new` + tips sync；release callback 组合 `router.tick()` + tips sync；**两件事各自 try/catch、互不阻断**；不得因自定义回调覆盖掉 tips sync。
- `[MODIFY] apps/ccb-console/server/src/modules/anchor-lifecycle/anchor.routes.ts`：确认 planning anchor 的 `bindRequirement` 走**含 tips sync 的默认 bind callback**（若未用 default 则显式组合）。
- `[MODIFY] apps/ccb-console/server/src/modules/project-ccbd/project-ccbd-manager.ts`：`ensureStarted` / `confirmRestore` 调 `ensureManagedCcbConfig` 时计算并传入 tips 投影（启动 reconciliation）；`onboarding` / `anchor-template` 保持无 tips。

## 验收

- 绑定 slot→需求后，ccb.config 出现 `[ui.sidebar.view].tips` 受管行、slot↔需求对应正确；CCB sidebar ~1-2s 自动显示。
- 解绑后该 slot 受管行移除，其它行不受影响。
- 多 slot：tips 含全部映射（全局表），逐行对应正确、按 slotId 排序。
- 并发绑定/解绑不互相覆盖（锁内全量重算）；**写入原子（temp+rename），并发读不会读到半写 TOML**。
- 启动 `ensureStarted`/`confirmRestore` 后 tips 反映当前绑定（reconciliation）；**`onboarding`/`anchor-template` 无参渲染不含 tips 且不误删主项目 tips**（测试锁定）。
- **三个绑定入口都触发 tips sync**：slot.routes bind（且 `/new` 仍执行）、slot.routes release（且 `router.tick` 仍执行）、anchor.routes bind；`onSlotReleased` 内 tips 同步抛错时 release API 仍成功；tips 写入失败不影响 bind/release。
- TOML 转义单测：引号 / 反斜杠 / 中文 / 长标题截断 / 空集合；tips 不影响 coreSignature 单测；managed-config drift 测试不被 tips 干扰。
- `pnpm --filter ccb-console-server typecheck` + 双侧 vitest 全绿。

## 边界

- 不引新 npm 依赖（手写 TOML）。不改 DB schema/migration。不改 bind/release HTTP API 签名。
- 不做主动刷新（不发 `'r'`、不碰 sidebar pane）。不保留用户手写 tips（全托管）。不做 per-window 单独显示。不做标题改名即时同步。
- 不误伤 managed-config 既有 windows/agents/ui.sidebar 渲染与 coreSignature；不改 `normalizeTaskStatus` 等无关逻辑。

## 依赖

无（单片，可立即开工）。先读《技术设计》`docs/03_开发计划/slot绑定sidebar-tip投影技术设计.md`。

## Materialization Context

- Requirement: cmpqls8ny3f0b1c1c0c91b0d7
- Section: pr1-slot-tip-projection
- Owner: ccb_codex
- Priority: high
- Dependencies: none

---
id: ADR-0018
title: Task Anchor Runtime —— 每 Epic 独立 CCB Anchor + Console MultiAnchorBroker
status: active
decided_at: 2026-05-13
last_updated: 2026-05-14
amendments: [2026-05-14 · Addendum · direct_pr subtask 独立 anchor 例外（F6-A1）]
decider: Claude
reviewer: ccb_codex
related_epic: epic-console-task-anchor-runtime
related_tasks: [ta1-task-anchor-bootstrap, ta2-multi-anchor-broker, ta3-create-task-dialog-v2, ta4-cross-anchor-timeline, ta5-anchor-lifecycle-recovery, ta6-xterm-web-attach]
supersedes_specs: [st1-rich-config-slot-schema, st2-slot-allocator-ccbd-integration, st3-create-task-dialog-ui, st4-active-sessions-panel-timeline, st5-stop-append-resume]
consult_evidence: [job_550836b235e0, job_029817e70a60]  # job_550836b235e0: round 1; job_029817e70a60: round 2
deprecated_in: null
removed_in: null
grace_window: null
impacted_components: [apps-ccb-console-server, apps-ccb-console-web, docs-ccb-workspace]
---

# ADR-0018: Task Anchor Runtime

## Status

Accepted（2026-05-13）。Codex round 1 (job_550836b235e0) + round 2 (job_029817e70a60) `pending_round_3: 空`。

## Context

用户在 2026-05-13 对 ST1-ST5 既有方向（"主项目 `.ccb/ccb.config` 内声明 task_auto 池 + 同 anchor 内 slot 调度"）提出质疑，原话核心北极星：「每个任务/子任务具有自己独立的 tmux 或者 session 或者 Work tree」「CCB 本身是通信协议」「tmux 只是壳」。Round 1 + Round 2 consult 已确认：

- ccb v6.1.8 `ccbd.supervision.loop.reconcile_once` 全量遍历 `config.agents` 做 desired-mount（`lib/ccbd/supervision/loop.py:56`），意味着主 `.ccb/ccb.config` 声明 dormant `task_auto_*` 必触发 reconcile mount
- `ccbd` namespace 内 `allow_detached_fallback = tmux_socket_path is None` 永远关闭（`lib/cli/services/runtime_launch.py:120`）；缺 assigned pane 必抛 `project namespace launch requires assigned tmux pane`
- provider manifest 仅声明 `pane-backed`，无 PTY/HEADLESS launch 路径
- 因此 ST1-ST5 的"池化"思路结构上失败；触发 `.ccb/ccbd/supervision.jsonl` 持续 `mount_failed`（image.png 报错根因）

而 ccb v6.1.8 原生提供：
- `WorkspaceMode.GIT_WORKTREE` 枚举（`enums.py:9`）
- `PathLayout` per project root，`.ccb/ccbd_dir/socket/tmux session/keeper/lease/startup-lock` 全部 layout-scoped（`storage/paths.py:54`、`storage/paths_ccbd.py:21`）
- `ccb --project <anchorPath>` 公开 CLI 监管 daemon（`cli/parser_runtime/start.py:12`、`ccbd/daemon_process.py:19`）
- ccbd JSON-RPC Unix socket control plane（`ccbd/socket_server.py`）

即"每 epic 一份独立 ccb anchor"在 CCB 设计原生支持下零源码改动即可实现。

## Decision

### 决策 1 · 1 Epic = 1 CCB Anchor

每个 active epic 绑定一个独立 CCB project anchor，含独立 git worktree + 独立 `.ccb/` + 独立 ccbd + 独立 tmux session + 独立 socket。Subtask 在所属 epic anchor 内**串行**执行，不独立 anchor。

### 决策 2 · 主 Console workspace `.ccb/ccb.config` 永久三格

主 anchor 永远只声明 `cmd + ccb_claude + ccb_codex`。**永久禁止**在主 anchor 声明 `task_auto_*` 等动态 agent —— 这是 mount_failed 的根因，由 lint 强制。

### 决策 3 · WIP 上限 = 2

同时活跃 anchor 数 ≤ 2（与 master-roadmap §3 WIP 约束一致）。第 3 epic 排队。

### 决策 4 · 兄弟目录 git worktree

物理位置：`../<repo-basename>-task-<epicTaskId>/`。利用 `git worktree add/remove` 原生命令，绑定 anchor lifecycle。

### 决策 5 · MultiAnchorBroker 为唯一跨 anchor 通信层

Console server 新增 `modules/anchor-broker/`，持 `anchorId → {socketPath, projectId, anchorPath}` 映射。所有跨 anchor `ccb ask / queue / cancel / trace` 由 Broker 路由到目标 anchor socket。**禁止** anchor 内 agent 直接跨 socket 与其他 anchor 内 agent 通信（避免事实上的 CCB 协议扩展）。

### 决策 6 · Anchor lifecycle 通过 ccb 公开 CLI 监管

Broker 用 `ccb --project <anchorPath>` 启动、用 `ccb --project <anchorPath> kill` 停止。**禁止**直接 import `lib/ccbd/main.py` 等私有入口（避免成为 CCB runtime 的事实 fork）。Console 崩溃时 anchor 默认 keep running，恢复时通过 `.ccb/ccbd/{lifecycle,lease,startup-report}` reattach。

### 决策 7 · EventJournal 集中 + `anchorId` 维度

EventJournal 保留 Console DB 集中表，**不**做 anchor-local SQLite。所有 anchor 内 agent 通过主 Console API 写集中 EventJournal，新增 `anchorId` / `epicTaskId` 字段。ordering：`(emittedAt, createdAt, eventId)`；dedup：`eventId` UNIQUE；replay：per-anchor cursor。ccbd queue/trace 这类 runtime 事件由 Broker pull 投影补齐。

## Anchor 状态机

```
planned → worktree_creating → configuring → mounting → ready → busy → idle_dirty → archiving → destroyed
                  ↓             ↓             ↓        ↓       ↓        ↓
              cleanup_required (any failure path)
                  ↓
              mount_failed | recovering | orphaned
```

- `planned`：epic 创建但尚未派工
- `worktree_creating`：`git worktree add` 进行中
- `configuring`：写 anchor 模板 `.ccb/ccb.config`
- `mounting`：`ccb --project <p>` 启动 ccbd
- `ready`：socket ready + 三 agent mounted
- `busy`：处理 task；可在 idle_dirty 上重新进入
- `idle_dirty`：本轮 task 完成但 worktree/agent state 未清理
- `archiving`：归档触发（用户显式或 WIP 调度）
- `destroyed`：`ccbd stop` + `git worktree remove` 完成

## 非目标（明确不做）

- 不演进 CCB v6 runtime（仍以 ADR-0001、master-roadmap §4 为准）
- 不实现 PTY-backed 或 HEADLESS provider runtime（pane-backed 仍是硬约束）
- 不做 anchor 内 agent 跨 socket 直连
- 不做主 Console (cwd) 与 task anchor 之间的 worktree 共享（物理隔离）
- 不实现跨项目 multi-tenant scheduler（仅服务当前 repo 的 active epics）
- 不在首批做 Web 内嵌 xterm.js 跨 anchor attach（TA6 可选后置）
- 不引入新 kernel node / capability / transition（这是 Console runtime binding 策略变化，不是协议演进）

## 替代方案

| 选项 | 核心差异 | 拒绝原因 |
|---|---|---|
| A · ST1-ST5 池化（原方向） | 主 anchor 内声明 4 个 `task_auto_*`，slot 调度 | 与 ccbd reconcile 全量 mount + namespace fallback 关闭硬冲突；不满足"每 task 独立 worktree" |
| B · 改 CCB runtime 加 PTY/HEADLESS | 真正"绕开 tmux" | 违反 ADR-0001、master-roadmap §4 |
| C · 跨 anchor 直连 agent | agent 间跨 socket ask | 等效改 CCB 协议（身份映射、reply routing） |

## 影响范围

- **替换**：ST1-ST5 spec → TA1-TA6
- **复用**：`modules/ccbd-client/`（扩 multi-anchor 维度）、`modules/task-slot/slot-allocator.service.ts`（改名 anchor-allocator）、ST5 user_intent / resume 思路
- **重做**：`TaskSlotAllocation` 表 → **新表 `AnchorAllocation`**（不 rename 已落地 schema，避免语义混淆）；ST1 的 `.ccb/ccb.config` rich-config 迁移取消
- **新增**：`modules/anchor-broker/`、anchor 状态机、`git worktree` lifecycle service
- **lint**：主 anchor `.ccb/ccb.config` 必须三格，CI 强制
- master-roadmap：新开 epic `epic-console-task-anchor-runtime`（编号 E17），与原 `epic-console-ccbd-task-exec` 并列；后者标 superseded

## 验收

- TA1 完成后：主 `.ccb/ccb.config` 切回三格，`supervision.jsonl` 不再出现 `mount_failed: task_auto_*`
- TA2 完成后：Console 能 spawn 1 个 task anchor 并 ask 跨 anchor，trace pass
- TA1-TA5 archived 后：WSL 8GB 内主 + 2 anchors 同时运行 smoke pass（内存 + WIP 降级策略验证）
- ST1-ST5 全部 archive + frontmatter `superseded_by: epic-console-task-anchor-runtime`

## 关联

- ADR-0001 · CCB 自研 workflow engine（兼容：本 ADR 不改 CCB runtime）
- ADR-0010 · /ccb:su-flow facade（无影响：本 ADR 是 Console runtime binding 层）
- D-zeta · kernel snapshot（无影响：本 ADR 不动 kernel）
- master-roadmap §3 E17（新增引用）

---

## Addendum 2026-05-14 · direct_pr subtask 独立 anchor 例外

### 触发

紧急修复 + F2 治理 batch 推进过程中发现：

- ADR-0017 v2 direct_pr 立项路径生成 **孤儿 subtask**（`kind === "subtask" && parentEpicId === null`）
- 按本 ADR 原决策 1 "SubTask 串行执行无独立 anchor"，既不该有独立 anchor，又无 Epic 父级可挂
- 结果 Console 任务详情页 AnchorStartStrip 不显示，用户立项后**卡死**（参见 F6 carrier spec 现状调研：`docs/.ccb/specs/active/2026-05-14-f6-direct-pr-orphan-anchor-entry.md`）

### 决策

direct_pr 路径生成的 **孤儿 subtask**（满足 `kind === "subtask" && parentEpicId === null`）**允许独立 CCB anchor**。

具体地：

- anchor lifecycle 概念从"严格 Epic-bound"扩展为"task-bound · 默认 epic · 例外 subtask 无 parent"
- anchor allocator / broker / registry kind 校验放开：从 hard reject `kind !== "epic"` 改为 reject `kind not in [epic, subtask] || (kind === "subtask" && parentEpicId)`
- API 路径 `/api/epics/:epicId/anchor/*` 与新 `/api/tasks/:taskId/anchor/*` 并存（渐进迁移）
- Prisma `boundEpicTaskId` 字段保留名称 + 语义扩展为 "bound task id"（避免破坏性 migration）

### 保留 Epic-anchor 主路径

epic_multi_pr 路径（ADR-0017 v2 主路径）仍按本 ADR 原决策 1：

- 1 Epic = 1 CCB Anchor
- 父 Epic 的 SubTask 串行执行无独立 anchor（共享 Epic anchor）

direct_pr 是**例外路径**（已立项的 subtask 没有 Epic 容器），不破坏主路径设计。

### 影响面

- **CCB 协作内核** (`references/kernel/`)：**0 影响**
- ADR-0018 原 7 条决策正文：**保持不变**（仅加本 addendum）
- 项目层：anchor schema + API + service + UI · 详见 F6-A2/A3/A4 sub-spec
- ADR-0017 Epic Multi-PR 路径：**不受影响**（主路径不动）
- ADR-0019 字段归属：**不受影响**

### 后续 sub-spec

| Sub-spec | 范围 | 实施者 |
|---|---|---|
| F6-A1 本 addendum | 协议依据 | **Claude direct** |
| F6-A2 anchor schema 字段语义扩展 | prisma `boundEpicTaskId` 注释 + matrix.yaml AnchorAllocation entity | codex |
| F6-A3 anchor API + service kind 校验放开 | `/api/tasks/:taskId/anchor/*` 加路径 + service kind 校验 | codex |
| F6-A4 AnchorStartStrip UI | visible 条件放开 + UX 细节 | **Claude direct**（UI/UX 用户 2026-05-14 明确 Claude 来）|

阻塞依赖：A1 → A2 → A3 → A4

---

frontmatter `last_updated: 2026-05-14`

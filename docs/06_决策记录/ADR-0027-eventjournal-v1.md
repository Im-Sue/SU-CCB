---
id: ADR-0027
title: EventJournal v1.0 · 双层结构 + Hook 整合
status: active
decided_at: 2026-05-22
last_updated: 2026-05-22
decider: 用户（基于 Phase 4 audit + Phase 1 已实质实现 EventJournal append）
reviewer: ccb_codex（rep_967c972f9d9d audit）
codename: eventjournal-v1
related_doc: docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md
parent_adrs:
  - ADR-0023  # plugin sovereignty 主决策
  - ADR-0024  # plugin primitive runtime（Phase 1 EventJournal append 实施）
  - ADR-0026  # entity field ownership
implements_via:
  - SP-Phase4 实施 spec（4b 内 ProjectionOutbox 删除 + Console event store 收敛）
phase: 4
---

# ADR-0027: EventJournal v1.0 · 双层结构 + Hook 整合

## Status

Accepted（2026-05-22）。Phase 1 已实质实现 plugin journal.jsonl append + Phase 2.5 已实施 Hook 通知机制，本 ADR 把这些零散决策正式入档 + 明确 Phase 4 清理范围。

## Context

Phase 1 引入 plugin `lib/runtime/event-journal.mjs`（journal.jsonl append + idempotency）；Hook 通知机制实施后 plugin → Console rescan 通道打通。但 Console 端仍有：
- DB EventJournal 表 + `enqueueProjectionOutbox` writer（活路径）
- `ProjectionOutbox` worker 反向驱动业务（违反 plugin sovereignty）
- Console 端 `event-journal-projector.spec` 等仍在维护

需要正式 ADR 明确：plugin journal 是 canonical / Console DB 是什么定位 / Hook 怎么衔接 / 两者怎么不交叉。

## Decision

### 决策 1 · 双层结构

| 层 | 路径 | 定位 |
|---|---|---|
| **plugin canonical journal** | `docs/.ccb/events/journal.jsonl` | append-only audit + 崩溃恢复锚点 |
| **Console DB event store** | `apps/ccb-console/server/prisma/.../EventJournal` 表 | UI/query/operational event store（投影/聚合，**不反向真相**）|

plugin journal 是单一真相源；Console DB 是它的投影 + Console 自己 operational events（如 dispatch queue 状态）。

### 决策 2 · plugin journal 契约

事件 schema：
```json
{
  "type": "<event_type>",
  "subject_type": "requirement|task|project|...",
  "subject_id": "<id>",
  "payload": { ... },
  "idempotency_key": "<unique>",
  "emitted_at": "<ISO8601>",
  "source_actor": "ccb_claude|ccb_codex|user|reconcile|..."
}
```

- 路径固定 `docs/.ccb/events/journal.jsonl`
- append-only（追加不修改）
- idempotency_key 去重（Phase 1 已实施 + schema-validator-hotfix 优化）
- 写入走 lib/runtime/event-journal.mjs（Phase 1 + Phase 2a hotfix）
- 坏 JSON 行 try-catch 跳过（Phase 2a hotfix 引入）

### 决策 3 · Console DB event store 定位

允许：
- UI 查询 / 渲染（用户在 Console 看 timeline）
- operational events（dispatch queue / scan job 状态）
- plugin journal 投影（indexer 读 journal.jsonl 写 Console DB）

禁止：
- **不反向驱动业务**（Console 不允许从 DB EventJournal 重建文件状态）
- **不替代 plugin journal**（reconcile 修复必须读 plugin journal.jsonl，不读 Console DB EventJournal）
- **不写入 plugin 已 emit 过的事件**（防止两端事件不一致）

### 决策 4 · Hook envelope（已实施 · 收敛入档）

```json
{
  "schema_version": "plugin-hook-v0.1",
  "source": "ccb-claude-plugin",
  "project_root": "/abs/path",
  "journal_path": "docs/.ccb/events/journal.jsonl",
  "event_hash": "<sha256(JSON.stringify(event))>",
  "event": { /* 原始 plugin EventJournal event */ }
}
```

Hook 定位：**fail-open notification bridge**，不是事件主权链路。失败不影响业务正确性，最多 Console UI 延迟刷新。

详见 `lib/runtime/hook-notifier.mjs`（Phase 2.5 已实施）+ `references/kernel/schemas/plugin-hook-envelope.schema.yaml`。

### 决策 5 · Idempotency / Retention

| 层 | idempotency | retention |
|---|---|---|
| plugin journal.jsonl | idempotency_key 扫整份去重（schema-validator-hotfix 容错坏行）| v1.0 不清理，v1.x 加归档 / rotation |
| Console DB event store | 投影时按 idempotency_key 去重 + Console operational events 自己生成 key | v1.0 clean start 一次性清空，v1.x 加 TTL |

### 决策 6 · ProjectionOutbox 删除（Phase 4 范围）

Console 端 `ProjectionOutbox` worker 是 v0.x 时代 "DB → 文件" 反向驱动机制，违反 v1.0 plugin sovereignty："文件是真相源 / DB 只是投影"。

Phase 4b 内删除：
- `modules/projection-outbox/` 整个模块
- `enqueueProjectionOutbox` 调用点
- `ProjectionOutboxItem` Prisma 表
- 配套测试

详见 SP-C04（已撤回归 Phase 4）+ Phase 4 实施 spec。

### 决策 7 · 禁止反向驱动业务

任何代码路径（包括 reconcile / drift / status-repair 残留）发现读 Console DB EventJournal 来"恢复 / 修复 / 重建" plugin canonical state → **lint 拒绝 + CI fail**。

reconcile / drift 修复必须读：
1. docs/.ccb/state/<task>.md
2. docs/.ccb/specs/active/<task_id>.md
3. docs/.ccb/drafts/breakdown/<rid>.json
4. requirement md
5. docs/.ccb/events/journal.jsonl

不读 Console DB EventJournal。

### 决策 8 · 迁移与兼容

按用户拍板"全新接入"（与 ADR-0026 决策 8 一致）：
- v1.0 发布前 Console DB EventJournal 表**完全清空**
- 例外同 ADR-0026：`Project` / `ProjectSettings` 是 console-internal 用户接入元数据，不随 clean start 清空
- 历史 events 不保留 / 不导出
- 重新跑 indexer 投影从 plugin journal.jsonl 回填

不做：导出 / data retention / backwards compatibility。

## 非目标（明确不做）

- 不做跨项目 event aggregation（v2+）
- 不做 event sourcing / replay-based state rebuild（v2+ 概念不引入）
- 不做 SSE / WebSocket push 到前端（v1.x）
- 不做 multi-receiver Hook（v1.x）

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| 单层结构（只用 plugin journal）| Console UI 需要查询/聚合，纯文件 grep 性能差 |
| Console DB 反向真相 | 违反核心理念（plugin = 主权 / Console = 投影）|
| 渐进迁移保留历史 events | 跟"全新接入"父需求不一致 |
| Hook 同步阻塞 plugin append | 跟 fail-open 设计冲突 |

## 风险

| 风险 | 缓解 |
|---|---|
| Console DB clean start 丢失现有 timeline | 父需求 + ADR-0026 已拍板"全新接入"，dev.db 是测试数据 |
| plugin journal 文件巨大（v1.x 归档前持续累积）| 一般项目 events 量小，v1.x 加归档 |
| Hook fail-open 导致 Console 长期 stale | fail-open 是设计选择，用户可主动 `/ccb:su-reconcile` 兜底 |
| 删除 ProjectionOutbox 影响 anchor dispatch worker | spec 必须先拆 `startProjectionServices` 内的多 worker 引用 |

## 关联

- 父需求：`docs/01_架构设计/ccb-plan/2026-05-17-v1.0-plugin-sovereignty.md`
- 路线图：`docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md`
- 触发 audit：codex `rep_967c972f9d9d`
- 父 ADR：0023 / 0024 / 0026
- 关联实施：Phase 1 plugin journal（已完成）+ Hook 通知（已完成）+ Phase 4b ProjectionOutbox 删除
- 吸收老 SP：SP-A05（本 ADR）+ SP-C04（ProjectionOutbox 物理删除）

## 协商证据

- codex Phase 4 audit `rep_967c972f9d9d`
- claude 4 锚点反思 2026-05-22 主对话
- 用户拍板 2026-05-22 5 项必问决策（全清 Console SQLite + 按钮派发 + console-internal 字段归属）

---
id: ADR-0024
title: Plugin-side Primitive Runtime（最小写入运行时）
status: active
decided_at: 2026-05-21
last_updated: 2026-05-21
decider: 用户（Claude + ccb_codex 二轮 consult 后拍板）
reviewer: ccb_codex
codename: plugin-write-runtime
related_doc: docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md
parent_adrs:
  - ADR-0023  # plugin sovereignty 主决策
  - ADR-0030  # SKILL.md / 节点 manifest 新形态规范
consult_evidence:
  - rep_bc4597221453  # codex 一轮 4-Phase 拓扑
  - rep_0bf6e84e73c2  # codex 二轮逐条反质疑（runtime 提前到 Phase 1）
phase: 1
implements_via:
  - Phase 1 实施 SP（待 ADR 落档后单独写）
---

# ADR-0024: Plugin-side Primitive Runtime（最小写入运行时）

## Status

Accepted（2026-05-21）。Phase 1 v1.0 必做基础设施。

## Context

ADR-0030 决策 6 写"plugin 直接读写文件作为真相源，Console 只做投影"。但仅有"plugin 可以写"远远不够——业务问题真实存在：

| 业务问题 | 后果 |
|---|---|
| 两个 anchor 同时改同一个 breakdown-draft.json | 后写的覆盖前写的，丢内容 |
| AI 写文件到一半 crash | 文件变成半截，下次读取直接报错 |
| AI 写文件时用户也在编辑 | 互相覆盖，用户改动丢失 |
| AI 写错 schema 的 yaml/json | Console indexer parse 失败，DB 投影错乱 |
| AI "写完"了但实际没写 | 业务认为完成但文件没更新 |

如果没有 runtime 兜底，Phase 2 解耦 endpoint 会让这些问题暴露给用户。**runtime 是 Phase 2 的前置基础**。

codex 二轮 consult (`rep_0bf6e84e73c2`) 明确：

> "先做 ADR-0024 的'最小写入运行时'，再做 Phase 1 的生产级脱耦。否则 Phase 2 会变成'看似 sovereignty，实际靠运气单写者'。"

## Decision

### 决策 1 · runtime 形态：plugin 子仓内的 Node.js module

不是独立 daemon，不是独立进程。runtime 是 plugin 子仓 `su-ccb-claude-plugin/lib/runtime/` 下的 ES module，由 skill 内 script 直接 import。

**业务问题**：plugin 需要的写入能力是"per-anchor 跑、随 anchor 生命周期消亡"，独立 daemon 太重。
**技术解法**：Node.js module，script 调用，无独立进程。

### 决策 2 · 提供的核心能力（最小集 5 项）

#### 能力 1 · 安全写文件（atomic write）

**业务问题**：AI 写文件到一半 crash，文件变成半截
**技术解法**：先写到 `<path>.tmp.<pid>`，写完 `fs.rename()` 到目标路径。rename 是原子操作，不会留半成品。

接口：
```js
await runtime.safeWriteFile(path, content, options?)
```

#### 能力 2 · 写前版本检查（CAS · compare-and-swap）

**业务问题**：A anchor 读了文件 v1，B anchor 也读了 v1 并改成 v2 写回；A 不知道 v2 存在，按 v1 改成 v1' 写回，覆盖了 B 的 v2
**技术解法**：写文件时必须提供"我读的时候 hash 是什么"。runtime 写前再读一次，hash 不同就 abort，让调用者重新读 + 重新决策。

接口：
```js
await runtime.safeWriteFile(path, content, { expectedHash })
// 不匹配抛 ConflictError，调用者捕获 → 重新读 → 重新写
```

#### 能力 3 · file-level lock

**业务问题**：两个 anchor 同时进入"读 → 改 → 写"流程，CAS 能防覆盖但不能防"两个都 abort"
**技术解法**：写之前 acquire `<path>.lock`（用 `proper-lockfile` 或等价库），写完释放。

接口：
```js
const release = await runtime.acquireFileLock(path)
try { ... } finally { await release() }
```

或封装版：
```js
await runtime.withFileLock(path, async () => { ... })
```

#### 能力 4 · schema 校验

**业务问题**：AI 生成的 json / yaml frontmatter 字段类型错，Console parse 失败导致 DB 投影乱
**技术解法**：runtime 内置 zod 校验。schema 定义在 `references/kernel/schemas/` 下（已有 decision-card-schema.yaml / agent-reply-reviewed-schema.yaml 占位）。写文件前校验，不通过抛 ValidationError。

接口：
```js
await runtime.validateAgainstSchema(content, schemaName)
```

可与 safeWriteFile 集成：
```js
await runtime.safeWriteFile(path, content, { schemaName: "breakdown-draft-v1" })
```

#### 能力 5 · 操作留痕（EventJournal append）

**业务问题**：AI 做了一连串操作，用户想审计"谁做了什么、为什么、什么时候"
**技术解法**：append-only journal 文件 `docs/.ccb/events/journal.jsonl`。每行一个 JSON event。runtime 提供 atomic append + idempotency key 兜底。

接口：
```js
await runtime.appendEvent({
  type: "decision_applied" | "agent_reply_reviewed" | "file_written" | ...,
  payload: { ... },
  subject_type, subject_id,
  idempotency_key,  // 防止重复 append
  emitted_at,
  source_actor: "ccb_claude" | "ccb_codex" | ...
})
```

### 决策 3 · runtime 不做的事（明确范围）

| 不做 | 原因 |
|---|---|
| 进程级 daemon | 太重，不在 Phase 1 最小集 |
| 跨 anchor 锁（distributed lock） | file-level lock 足够覆盖 Phase 2；distributed 留 v1.5+ |
| schema 版本协商 / migration | schema 由 kernel 管理，runtime 只 validate |
| EventJournal 投影到 DB | 投影是 Console indexer 的事 |
| Hook 集成（PreToolUse 等） | Hook 是 plugin 外部的事，runtime 只提供能力 |
| Reconcile 自检 | Phase 3 范围（ADR-0025） |

### 决策 4 · 失败策略

| 场景 | runtime 行为 |
|---|---|
| atomic write fail（disk full / permission）| 抛 IOError，调用者决定（通常 escalate 用户）|
| CAS conflict | 抛 ConflictError，**调用者必须捕获 + 重读 + 重决策**，runtime 不自动重试 |
| lock timeout（默认 30s）| 抛 LockTimeoutError，调用者决定（通常 escalate "另一个 anchor 在改")|
| schema validation fail | 抛 ValidationError，**禁止强行写**，escalate 用户 |
| EventJournal append fail | 业务操作已完成的情况下，log warning 但不回滚（journal 是审计辅助而非真相源）|

**核心原则**：runtime 失败默认 fail-closed（拒绝继续），不 fail-open。**业务一致性 > 用户体验流畅度**。

### 决策 5 · 性能 / 并发预算（v1.x 阶段不优化）

- 不要求高吞吐
- file lock 阻塞 30s 可接受
- atomic write 重命名延迟可接受
- 主要场景：1 用户 + 2-3 anchor 同时跑，总写入频次 < 10/sec

性能优化留 v1.5+。

## 非目标（明确不做）

- 不做 distributed lock（多机 / 多用户共享文件场景，留 v2+）
- 不做 transaction（跨多文件原子提交，留 v1.5+，需要时单独设计）
- 不做 file watcher（那是 Console indexer 的事）
- 不替代 git（版本控制由 git 管，runtime 只管"单次写不丢"）
- 不内置 conflict resolution（冲突时 runtime 报错让调用者决策）

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| A · 独立 daemon process | Phase 1 太重，per-anchor module 够用 |
| B · 用 git 当 lock（git lock files） | git 不是设计来做应用层并发控制的 |
| C · 用 sqlite as truth source | 违反 ADR-0030 "文件是真相源" |
| D · 完全 fail-open（不做 lock 不做 CAS） | 多 anchor 场景必然翻车 |

## 影响范围

### 新增

- `su-ccb-claude-plugin/lib/runtime/` 目录及 5 个能力模块
- `references/kernel/schemas/` 下 schema 文件（v1.x 慢慢补，Phase 1 至少有 breakdown-draft / requirement-md frontmatter）
- 单测覆盖所有 5 项能力 + 失败场景

### 复用

- 现有 `docs/.ccb/events/journal.jsonl` 路径（如不存在则 runtime 自动创建）

### 不动

- Console 代码（`apps/`）
- Prisma schema / 数据库
- SP-A11 / A11a 落地的 SKILL.md / manifest 文件

## 验收

ADR-0024 落地（通过 Phase 1 实施 SP）后必须满足：

1. `lib/runtime/` 5 个能力模块齐全
2. 单测覆盖：
   - atomic write 正常 + IOError 失败
   - CAS 命中 + ConflictError 失败
   - lock acquire + release + timeout
   - schema validate 通过 + 失败抛 ValidationError
   - EventJournal append 正常 + idempotency key 重复跳过
3. SP-A11a 的 frontmatter 写入逻辑改为走 runtime（验证集成）
4. ADR-0024 < 250 行（本文档）
5. 不改 Console 代码（`apps/` git diff 为空）

## 风险

| 风险 | 缓解 |
|---|---|
| AI 不主动使用 runtime（直接 fs.writeFile）| SKILL.md 强约束 + script 内 import runtime + Phase 2 实施时所有写入都通过 runtime |
| lock 死锁 | timeout 30s 兜底 + 强制 release on error |
| EventJournal append 高频写入卡顿 | v1.x 频次低；高频场景留 v1.5+ 优化（batch / async）|
| schema 演进 | schema 文件版本号 + runtime 容忍多版本（如 v0.1 v0.2 都接受）|

## 关联

- ADR-0023 plugin sovereignty 主决策
- ADR-0030 SKILL.md / 节点 manifest 新形态规范
- Phase 1 实施 SP（待 ADR 落档后单独起草）
- 路线图：`docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md`

## 协商证据

- codex 一轮：`rep_bc4597221453`（4-Phase 拓扑，runtime 排 Phase 2）
- codex 二轮：`rep_0bf6e84e73c2`（同意 runtime 必须提前到 Phase 1，否则 Phase 2 翻车）
- 用户拍板：2026-05-21 主对话"推进"

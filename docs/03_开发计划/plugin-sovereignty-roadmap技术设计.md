---
doc_type: technical_design
title: "Plugin Sovereignty 路线图"
---

# Plugin Sovereignty 路线图

## 根目标

> **Plugin 是主系统，Console 是可选观察 UI**

业务上：用户能用 CLI-only 跑完整工作流，不需要打开 Console；多个 AI 并发协作时不丢数据/不写半成品；状态错位时 AI 能自检 + 给修复方案。

---

## 4 Phase + Side Track 拓扑

```
✅ Phase 0 · 范式定型（已完成 2026-05-21）
   ADR-0023 / Addendum / ADR-0030 + SP-A11 + SP-A11a
   产出：17 SKILL.md + 7 节点 manifest + 4 kernel 文件 + 1 个 endpoint 解耦样板
   
✅ Phase 1 · 最小 Plugin 写入运行时（2026-05-22 完成）
   ADR-0024 + lib/runtime/ 5 模块 + 2 schema + SP-A11a 集成（plugin commit `b545670`）
   解决："多 anchor 写同一文件不丢内容、不写半截"
   
✅ Phase 2 · 计划域闭环脱耦（v1.0 必做，2026-05-22 实质闭环）
   ✅ 2a 拆分草案脱耦 + hotfix 实质闭环（plugin commit ebe9043，2026-05-22）
   ✅ 2b materialize 子任务生成脱耦 + hotfix 实质闭环（plugin 14ee1b6 / 主仓 c26354d / hotfix 主仓 待commit，2026-05-22）
   解决："CLI-only 能完整跑需求分析 → 拆分 → 子任务生成"

✅ Phase 3 · AI 自检与状态修复（2026-05-22 完成）
   ADR-0025 + /ccb:su-reconcile skill + status-repair 迁移 + state 文件层（plugin commit fa9a2d4）
   解决："状态错位时 AI 能自己说清楚 + 给修复方案"

✅ Phase 4 · Console clean start（2026-05-22 v1.0 发布闸口达成）
   删 scheduler / drift / projection-reconciler / ProjectionOutbox 等驱动层完成
   4a 字段所有权基线 `3b2a430` + 4b Console 主权 cleanup `7094b1d` + 4c Prisma clean start
   解决："Console 真的变成纯 UI，不再是半个引擎"——已落地

🔀 Side Track · SP-A10 实体模型审视
   独立挂着，不阻塞 Phase 1-3，不并入 Phase 4
   解决："系统对象关系想清楚"

🟧 Phase 5 · v1.x 治理增强 + 文档秩序（discussion-pending，等用户启动）
   登记 2026-05-22。4 件议题待讨论再启动实施：
   1. plugin 状态字段 flag 治理（防止 status/progress 随意更新）
   2. ccb 上游 worktree 机制对齐（github.com/SeemSeam/claude_codex_bridge）
   3. docs/ 目录命名规范 + 文档结构治理
   4. 需求任务拆分粒度治理（参考 prediction_market 项目维护方式）
   解决："v1.0 之后的治理痛点 + 协作约束规范化"
```

---

## 每个 Phase 详述

### ✅ Phase 0 · 范式定型（已完成）

**业务目标**：让用户和 AI 都知道新系统长什么样——节点是能力模式，plugin 独立，Console 不再是 driver。

**产出**：
- ADR-0023 plugin sovereignty 主决策（2026-05-17）
- ADR-0023 Addendum 节点 ≠ 流水线工序（2026-05-19）
- ADR-0030 SKILL.md / 节点 manifest 新形态规范（2026-05-21）
- SP-A11 plugin 全量文档形态重写（plugin commit `e5a75ea`）
- SP-A11a requirement-reanalyze 单 endpoint 解耦（commit `aa8a241`，作为模式样板）

**完成判据**：17 个 SKILL.md + 7 节点 manifest 已重写，1 个 endpoint 已按"plugin 写文件 + Console 投影"模式跑通。

---

### 🟧 Phase 1 · 最小 Plugin 写入运行时（v1.0 必做）

**业务目标**：让 plugin 安全地写文件——多个 AI 同时写同一份文档时不丢内容、不覆盖用户改动、不生成半截文件、能留下"谁做了什么"的痕迹。

**为什么先做这个**：Phase 2 解耦 endpoint 时会让 plugin 直接写文件。如果没有 runtime 兜底（lock / atomic write / CAS / schema 校验），多 anchor 并发场景会出问题。**runtime 是 Phase 2 的前置基础**。

**产出**：
- ADR-0024 plugin-side primitive runtime（最小集设计文档）
- runtime 最小实施（plugin 子仓内的 Node.js module）：
  - 安全写文件（atomic write：写 tmp + rename）
  - 写前版本检查（CAS：读 hash → 改 → 写时比对，不同则 abort）
  - 冲突提示
  - schema 校验（zod-like）
  - 操作留痕（写 EventJournal）

**完成判据**：
- ADR-0024 落档（<200 行）
- runtime module 提供 4-5 个核心函数
- 单测覆盖：atomic write、CAS 冲突场景、schema 校验、EventJournal append
- 至少一个真实场景使用（如 SP-A11a 的 frontmatter 写入改为走 runtime）

**预估**：4-6d（含 ADR + 实施 + 测试）

**依赖**：Phase 0

---

### 🟧 Phase 2 · 计划域闭环脱耦（v1.0 必做）

**业务目标**：用户从需求分析到拆分子任务，不再依赖 Console 业务写接口。CLI-only 路径也能完成计划阶段。

**两个验收闸口**：

#### Phase 2a · 拆分草案脱耦

**业务范围**：把 6 个 breakdown-draft Console endpoint 全部解耦
- `POST/PUT/DELETE /api/requirements/:rid/breakdown-draft`
- `POST /breakdown-draft/begin-review` / `/approve` / `/reject-and-feedback`

**技术解法**：plugin 通过 runtime 直接读写 `docs/.ccb/drafts/breakdown/<rid>.json`。审批状态变更也写到 draft 文件 frontmatter / status 字段。Console indexer 自动投影到 DB。

**完成判据**：6 个 endpoint 删除；用户 CLI-only 跑完整拆分流程。

#### Phase 2b · materialize 子任务生成脱耦

**业务范围**：2 个 materialize endpoint 解耦
- `POST /api/requirements/:rid/materialize-requirement`
- `POST /api/tasks/:carrierId/materialize-as-epic`

**技术解法**：plugin 通过 runtime 创建多个子任务 markdown 文件（跨实体写入），Console watcher 投影到 Task DB。

**完成判据**：2 个 endpoint 删除；用户 CLI-only 能从 draft 生成真实子任务文件。

**为什么 2a / 2b 分闸口**：materialize 跨实体复杂度比 draft 高一档；2a 验证完再做 2b 避免风险叠加。

**预估**：3-5d（2a 1-2d，2b 2-3d）

**依赖**：Phase 1 完成

---

### ✅ Phase 3 · AI 自检与状态修复（2026-05-22 完成）

**业务目标**：当 docs/.ccb/ 文件、Console DB 投影、任务状态出现不一致时，用户不用手工猜哪里错，AI 能自己发现 + 解释 + 给修复方案。

**产出**：
- ADR-0025 /ccb:su-reconcile skill 设计（业务问题 → 技术解法对照）
- /ccb:su-reconcile skill 实施
- status-repair endpoint 迁移（plugin reconcile 接管 → Console 删 2 个 status-repair endpoint）

**完成判据**：用户跑 `/ccb:su-reconcile` 能：
- 扫描差异（文件 vs DB 投影）
- 输出"哪些不一致 / 可能原因"
- 给修复方案（用户审批后执行）

**预估**：3-5d

**依赖**：Phase 2 完成

---

### ✅ Phase 4 · Console clean start（2026-05-22 v1.0 发布闸口达成）

**业务目标**：从根上消除"Console 还是半个 workflow engine"的混乱——删 scheduler / drift / projection-reconciler / ProjectionOutbox 等驱动层，Console 真的变成纯 UI。

**产出**：
- 大块 Console 代码删除（ADR-0023 决策 6）
- 数据库 schema 收敛（删 Console 业务字段）
- 文档同步（标 deprecated 历史代码）

**完成判据**：Console 不再有任何"主动维护业务字段"的代码路径；仅保留 indexer 投影 + dispatcher 触发器 + UI 渲染。

**预估**：1-2 周起

**依赖**：Phase 1-3 完成 + 用户拍板启动时机

---

### 🔀 Side Track · SP-A10 实体模型审视

**业务目标**：想清楚系统对象关系（Requirement / Task / Anchor / SubTask 等）的语义边界 + 主体映射。

**为什么不进 Phase**：实体模型审视是"概念整理"，跟 Phase 1-4 的代码改造节奏不同。可以并行讨论但不阻塞主线。

**产出**：SP-A10 spec + 可能产出新的 ADR（实体模型 v2）

**状态**：pending（已挂在 registry，等用户启动时机）

---

## 完整任务关联矩阵

> **本节是 plugin sovereignty 主进度的唯一真相源**。所有 ADR / SP spec / 实施 commit 在此一表打尽。
> registry（`2026-05-18-v1.0-plugin-sovereignty-subpr-registry.md`）只维护 Console UI 改造（SP-B 系列），不再维护本表。

### Phase 0 · 范式定型 ✅（2026-05-21 完成）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| ADR-0023 Plugin Sovereignty（含 Addendum 节点 ≠ 工序）| active | `docs/.ccb/decisions/ADR-0023-plugin-sovereignty.md` |
| ADR-0030 SKILL.md / 节点 manifest 新形态 | active | `docs/.ccb/decisions/ADR-0030-plugin-node-paradigm.md` |
| SP-A11 全量 plugin 重写 spec | spec-active | `docs/.ccb/specs/active/2026-05-21-sp-a11-plugin-paradigm-rewrite.md` |
| SP-A11 实施 | implemented | plugin commit `e5a75ea`（17 SKILL + 7 节点 manifest + 4 kernel 文件）|
| SP-A11a reanalyze 解耦 spec | spec-active | `docs/.ccb/specs/active/2026-05-21-sp-a11a-reanalyze-decouple-console.md` |
| SP-A11a 实施 | implemented | plugin `a99594b` + 主仓 `aa8a241` |

### Phase 1 · 最小写入运行时 ✅（2026-05-22 完成）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| ADR-0024 Plugin Primitive Runtime | active | `docs/.ccb/decisions/ADR-0024-plugin-primitive-runtime.md` |
| SP-Phase1 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-21-sp-phase1-plugin-runtime-impl.md` |
| Phase 1 实施 | implemented | plugin `b545670`（5 模块 + 2 schema + node test 9/9）+ 主仓 `43c7958` |

### Phase 2 · 计划域闭环脱耦 ✅（2026-05-22 实质闭环完成）

#### 2a · 拆分草案脱耦 ✅（实质闭环 2026-05-22）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| SP-Phase2a 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase2a-breakdown-draft-decouple.md` |
| Phase 2a 代码就位 | code-landed | plugin `1f36fdb` + 主仓 `3a83233`（lib/breakdown-draft/ 5 API + 删 6 mutation + indexer 投影 + 前端 dispatch）|
| 2026-05-22 codex review 发现 5 类未闭环 | review-found | `rep_53bc842dce57` + claude 4 锚点反思 |
| SP-Phase2a-hotfix 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase2a-hotfix-realclosure.md` |
| Phase 2a hotfix + follow-up 实施 | implemented | plugin `ebe9043`（5 类修复 + file-lock owner.json 原子写 + node --test 22/22）|

##### Phase 2a 实质闭环 hotfix 清单（5 类）

| # | 问题 | 严重度 | 修复方向 |
|---|---|---|---|
| 1 | SKILL.md 没明确"收到 `breakdown_draft_*` dispatch → 调 lib/breakdown-draft"——anchor 收到命令后 Claude 自由发挥 | 🔴 high | 涉及 breakdown-draft 的 SKILL.md 加显式调用契约 |
| 2 | `transitionBreakdownDraftStatus` 无 `expectedHash` 参数，前端发了也没消费——stale approval/reject 风险 | 🔴 high | 函数加 expectedHash + CAS 校验 + 单测覆盖 ConflictError |
| 3 | `file-lock.mjs` mkdir lock 无 stale owner 检测——anchor crash 后下次永久 LockTimeout | 🟠 medium | lock dir 写 owner.json（pid+hostname）+ acquire 时检测 pid 存活 |
| 4 | `event-journal.mjs` idempotency 扫整份 journal，遇坏 JSON 行直接阻断 append | 🟠 medium | try-parse 跳过坏行 + log warning，不阻断 |
| 5 | `deleteBreakdownDraft` 直接 rm，journal append 失败=删除无审计 | 🟠 medium | 先 appendEvent，append 成功才 rm；失败抛 IOError |

#### 2b · materialize 子任务生成脱耦 ✅（实质闭环 2026-05-22）

| 产物 | 状态 | 路径 |
|---|---|---|
| SP-Phase2b 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase2b-materialize-decouple.md` |
| Phase 2b 代码就位 | code-landed | plugin `14ee1b6` + 主仓 `c26354d`（lib/subtask + 删 2 endpoint + indexer 投影 + 前端 dispatch + 43/43 tests）|
| 2026-05-22 indexer audit 发现 Console 端校验未闭环 | review-found | `rep_0af7c8de2c30` + claude 4 锚点反思 |
| SP-Phase2b-hotfix 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase2b-hotfix-console-validation.md` |
| Phase 2b-hotfix 实施 | implemented | 主仓（document-parser parseStatus + subtask-spec-v0.1 专项校验 + breakdown schema 删 auto + 40 pass / 3 todo）|

##### Phase 2b 实质闭环 hotfix 清单（3 类）

| # | 问题 | 严重度 | 修复方向 |
|---|---|---|---|
| 1 | Console indexer 没识别 `schema_version: subtask-spec-v0.1`，坏 subtask spec 被当 active Task 投影 | 🔴 high | indexer 加 subtask 专项 schema 校验（缺字段/非法 owner/current_node/source_hash → partial 不创建 Task）|
| 2 | malformed markdown frontmatter parser 宽松吞掉，parseStatus 仍 success | 🟠 medium | parser 返回 issues + Document `parseStatus=parse_error/partial` |
| 3 | Console breakdown draft zod schema 仍允许 owner=auto（与 plugin schema-hotfix 不同步）| 🟡 low | Console 端 zod 同步删 auto |

##### 不在 Phase 2b-hotfix 范围（归 Phase 3）

- indexer 进程死掉漏事件补扫 / DB 投影失败 retry+backoff / stale delete 改 orphan 标记——归 Phase 3 reconcile spec

### Phase 3 · AI 自检与状态修复 ✅（2026-05-22 完成）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| ADR-0025 AI-native Reconcile + Diff Log | active | `docs/.ccb/decisions/ADR-0025-ai-native-reconcile.md` |
| SP-Phase3 实施 spec | spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase3-impl-reconcile.md` |
| Phase 3 实施 | implemented | plugin `fa9a2d4`（lib/reconcile + lib/state + skills/su-reconcile + task-state.schema + 62/62 tests）+ 主仓（删 3 status-repair 文件 + indexer state 投影 + HealthPanel 改 dispatch + ai-tools registry 同步）|
| 设计决策 | — | 触发仅用户主动 / 修复 3 级分类 / status-repair 直接删 / 不重做 Phase 2b（state 文件层覆盖 spec frontmatter 动态字段）|
| codex 自补设计 | — | apply 写 `docs/.ccb/state/<task_id>.md` 不动 spec（防破坏 execution contract）|
| 吸收的老 SP | — | SP-A03 + SP-A08 + SP-A12 + SP-C07 全部归入 |

### Phase 4 · Console clean start ✅（2026-05-22 v1.0 发布闸口达成）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| ADR-0026 Entity Field Ownership v1.0 | ✅ active | `docs/.ccb/decisions/ADR-0026-entity-field-ownership.md` |
| ADR-0027 EventJournal v1.0 | ✅ active | `docs/.ccb/decisions/ADR-0027-eventjournal-v1.md` |
| SP-Phase4 实施 spec（3 子阶段）| spec-active | `docs/.ccb/specs/active/2026-05-22-sp-phase4-impl-console-clean-start.md` |
| Phase 4a 字段所有权基线 | implemented | `3b2a430`（378 个 Prisma owner annotation + lint fail-on-violation + YAML→TS+ESM generator）|
| Phase 4b Console 主权 cleanup | implemented | `7094b1d`（删 ProjectionOutbox/scheduler/drift/transition + 禁活业务写入口 + 净删 14444 行）|
| Phase 4c v1.0 发布闸口 | implemented | Prisma migration `20260522000000_phase4c_clean_start` + 父需求 frontmatter v1.0-released + 维护脚本清理 |
| 吸收的老 SP | — | SP-A04 + SP-A05 + SP-C02 + SP-C03 + SP-C04 + SP-C05 + SP-C08（全部归入）|
| 待用户手工 E2E 验证 | 🟧 用户拍板 | CLI-only 全流程 / hook fail-open / reconcile apply / 重启补扫 / CAS 冲突 |

### Side Track · SP-A10 实体模型审视 🔀（不阻塞主线）

| 产物 | 状态 | 路径 / commit |
|---|---|---|
| ADR-0028 two-tier entity model | active | `docs/.ccb/decisions/ADR-0028-two-tier-entity-model.md` |
| ADR-0029 large-state command layer | active | `docs/.ccb/decisions/ADR-0029-large-state-command-layer.md` |
| SP-A10 v1.0 实施 | implemented（v1.0 范围内）| 既有 commit |
| 实体模型 v2 讨论 | 🟧 pending | 等用户启动 |

---

## 老 SP 归属清单（一表归位）

### A 系列 · 已被 Phase 化吸收（不再独立维护）

| SP | 原标题 | 新归属 | 状态 |
|---|---|---|---|
| SP-A01 | ADR-0023 plugin sovereignty | Phase 0 锚点 | ✅ implemented |
| SP-A02 | ADR-0024 primitive runtime | Phase 1 锚点 | ✅ implemented |
| SP-A03 | ADR-0025 reconcile | Phase 3 锚点 | 🟧 待起草 |
| SP-A04 | ADR-0026 entity field ownership | Phase 4 前置 | 🟧 待起草 |
| SP-A05 | ADR-0027 EventJournal | Phase 1 实质实现，正式 ADR 待补 | 🟧 半完成 |
| SP-A08 | /ccb:su-reconcile skill manifest | Phase 3 锚点 | 🟧 待 |
| SP-A10 | 实体模型审视 | Side Track | ✅（v1.0 范围）|
| SP-A11 | plugin 全量重写 | Phase 0 实施 | ✅ |
| SP-A11a | Console reanalyze 解耦 | Phase 0 收尾 | ✅ |
| SP-A11b / A11c / A12 | 5/20 临时拆分 | 归入 Phase 2a / 2b / 3 | ✅ 撤回 |

### A 系列 · 不归 Phase 化（独立维护）

| SP | 原标题 | 不归 Phase 的原因 |
|---|---|---|
| SP-A06 | UI Action Routing Matrix | 已并入 SP-B92（Console UI 改造范围）|
| SP-A07 | Contract Test Strategy | cross-cutting，codex 主笔，跟 plugin sovereignty 路线图正交 |
| SP-A09 | decisions.yaml 索引刷新 | 独立 housekeeping，不阻塞主线 |

### C 系列 · 已被 Phase 化吸收（不再独立维护）

| SP | 原标题 | 新归属 | 状态 |
|---|---|---|---|
| SP-C01 | Plugin runtime 工程骨架 | Phase 1 实施 | ✅ implemented |
| SP-C02 | transition-consumer-wrapper 拆除 | Phase 4 | 🟧 |
| SP-C03 | ReactiveScheduler 拆除 | Phase 4 | 🟧 |
| SP-C04 | ProjectionOutbox 物理删除 | Phase 4 | 🟧 |
| SP-C05 | Console SQLite + state clean start | Phase 4 | 🟧 |
| SP-C07 | /ccb:su-reconcile 实现 | Phase 3 | 🟧 |
| SP-C08 | AnchorAllocation runtime 对接 | Phase 2b 候选 / Phase 4 | 🟧 |

### C 系列 · 不归 Phase 化（独立维护）

| SP | 原标题 | 不归 Phase 的原因 |
|---|---|---|
| SP-C06 | Lint/CI 禁止 Console PATCH | Phase 4 完成后做兜底，不阻塞主线 |

### B 系列 · 不属于 plugin sovereignty 进度

SP-B 全系列是 Console UI 改造，维护位置 = registry，不在本路线图。

---

## 派工进度（时间轴）

| 时点 | 动作 | 结果 |
|---|---|---|
| 2026-05-17 | ADR-0023 落档 | Phase 0 启动 |
| 2026-05-19 | ADR-0023 Addendum + ADR-0028/0029 落档 | SP-A10 收口 |
| 2026-05-21 | ADR-0030 + SP-A11 + SP-A11a 落档实施 | **Phase 0 ✅ 完成** |
| 2026-05-21 | ADR-0024 + Phase 1 spec 落档 | Phase 1 启动 |
| 2026-05-22 | Phase 1 实施 `b545670` | **Phase 1 ✅ 完成** |
| 2026-05-22 | Phase 2a spec + 代码就位 `1f36fdb` + `3a83233` | Phase 2a 代码就位（非闭环）|
| 2026-05-22 | codex review `rep_53bc842dce57` + claude 4 锚点反思 | 发现 5 类未闭环，Phase 2a 降回 🟧 |
| 2026-05-22 | Phase 2a-hotfix + follow-up 实施 `ebe9043` | **Phase 2a ✅ 实质闭环**（5 类修复 + file-lock 原子写）|
| 2026-05-22 | codex schema audit `rep_cd25d52b98f7`（7 high + 2 medium uncovered）| 发现 schema yaml 是装饰性，所有规则硬编码 |
| 2026-05-22 | schema-validator hotfix 实施 `7a3670e` | **业务规则层落地**（business-rules.mjs + updateBreakdownDraft patch 限制 + ISO8601 严格 + yaml 同步）|
| 2026-05-22 | codex Phase 2b audit `rep_3f0b01092940` + 用户拍板（删 materialize-as-epic + 推迟 ADR-0026）| Phase 2b 设计定型 |
| 2026-05-22 | Phase 2b spec + 代码就位 plugin `14ee1b6` + 主仓 `c26354d` | Phase 2b 代码就位（非闭环）|
| 2026-05-22 | indexer audit `rep_0af7c8de2c30` + claude 4 锚点反思 | 发现 Console 端 subtask 校验未闭环，Phase 2b 降回 🟧 |
| 2026-05-22 | kernel deprecated 搬迁 plugin v0.9.1 + 主仓 `7665bdf` | ✅ housekeeping 完成 |
| 2026-05-22 | Phase 2b-hotfix 实施（document-parser parseStatus + subtask 专项校验 + breakdown 删 auto）| **Phase 2b ✅ 实质闭环** + **Phase 2 整体 ✅ 完成** |
| 2026-05-22 | ADR-0031 落档 + 实施 `rep_e27c69d285d0`（dispatch JSON payload + lib/dispatch-parser + 64KB/depth 8 安全限制 + `*_b64` fail-closed 拒绝）| **ADR-0031 ✅ 完成**（穿插 batch #2）|
| 2026-05-22 | Hook 通知机制实施 `rep_527c939bcd44`（lib/runtime/hook-notifier + envelope schema + Console plugin-hooks receiver + localhost-only + 300ms timeout + fail-open + debounce scanProject 200ms）| **Hook 通知 ✅ 完成**（穿插 batch #1）|
| 2026-05-22 | ADR-0025 + Phase 3 spec 落档 `8ed84e6`（10 章节 ADR + 3a/3b/3c 实施 spec）| Phase 3 设计完整 |
| 2026-05-22 | Phase 3 实施 `rep_7efe8fc0a66f`（plugin `fa9a2d4`：lib/reconcile + lib/state + skills/su-reconcile + task-state schema + 62/62 tests · 主仓：删 status-repair 3 文件 + indexer state 投影 + HealthPanel 改 dispatch + ai-tools registry 删）| **Phase 3 ✅ 完成** |
| codex 实施期 callback | rep_f13e50aa9ef1 | 主动 ask schema 冲突 → 引入 state 文件层（防破坏 subtask spec contract）|
| 2026-05-22 | ADR-0026 + ADR-0027 + Phase 4 spec 落档 `cd1b52d` + 3 阶段重组 `f74eb86` | Phase 4 设计完整 |
| 2026-05-22 | Phase 4a 实施 `3b2a430`（@owner annotation 378 个 + lint fail-on-violation + YAML→TS+ESM generator）| Phase 4a ✅ |
| 2026-05-22 | Phase 4b 实施 `7094b1d`（删 ProjectionOutbox/scheduler/drift/transition + 禁活业务写入口 + 净删 14444 行）| Phase 4b ✅ |
| 2026-05-22 | Phase 4c 实施（Prisma migration `20260522000000_phase4c_clean_start` + 父需求 v1.0-released + 维护脚本清理）`rep_6f1e670338e8` | **Phase 4 ✅ v1.0 发布闸口达成** |
| **下一步** | **用户手工 E2E 验证** + CHANGELOG plugin v1.0.0 正式版 bump | 🟧 v1.0 真发布前 |
| 之后 | Phase 5 v1.x 治理增强（discussion-pending · 4 件议题登记 `a9f27c2`）| 🟧 等用户启动 |

---

## 协商证据

| 节点 | 文件 / Job ID | 关键产出 |
|---|---|---|
| codex 一轮 4-Phase 提案 | rep_bc4597221453 | 初始拓扑 |
| claude 自省偷懒 | 主对话 | 识别 4 个质疑点 |
| codex 二轮逐条反质疑 | rep_0bf6e84e73c2 | 4 点 agree/部分 agree，修订拓扑 |
| **本路线图落档** | `docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md` | 当前版（2026-05-22 大改：补完整关联矩阵 + 老 SP 归位清单）|

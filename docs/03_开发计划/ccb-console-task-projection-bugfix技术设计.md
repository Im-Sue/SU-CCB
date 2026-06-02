---
doc_type: technical_design
title: "Console 任务投影修复 bugfix 技术设计"
---
# 技术设计 · Console 任务投影修复（bugfix）

- **task_id**: `ccb-console-task-projection-bugfix`
- **created**: 2026-04-27
- **state**: `docs/.ccb/state/2026-04-26-ccb-console-task-projection-bugfix.md`（revision=3）
- **requirement_doc**: `docs/02_需求设计/ccb-console/2026-04-26-ccb-console-task-projection-bugfix.md`
- **design layer consult**: R1 design consensus（与 F7 epic R3/R4 不同，本 task 自己的 R1）
- **complexity**: complex / **impact**: cross_module
- **estimate**: 1.5-2.5 天 single dispatch

---

## 1. 上下文

R8/R9 已锁 scope (a)：8 必做（S1-S8）+ 5 不做（N1-N5）+ 6 hard constraints + 4 根因 + 5 RF resolved。F7 epic 昨日完成（archived），新加 `engineering_decidable_decisions` task_state 字段 + L4 hook + 5 wording updates。本设计在 F7 已落基础上完成 bugfix 实施。

**详细需求** → 见 requirement_doc 第 1-9 节
**4 根因 + 8 必做 + 5 不做** → 见 requirement_doc 第 5/6 节
**6 hard constraints** → C1-C6 见 requirement_doc 第 4 节
**8 行为验收 AC1-AC8** → 见 requirement_doc 第 6 节

---

## 2. R1 design consult 关键决策

| 议题 | 共识 | 实施影响 |
|---|---|---|
| **D1 F7 hook coexistence** | safe by default，不改 F7 hook | F7 hook 仅在 evidence/escalation marker 触发，bugfix 改 parser/UI/CSS 不会误触；新增 fixture 含 `engineering_decidable_decisions` 时用 valid evidence block 或纯 unknown-field tolerance test |
| **D2 S7 历史 state 回填** | projection canonicalization，不重写 archived | inv_immutable_frozen_artifacts 锁档；Console projection 把 `epic_completed → archived/done bucket`；不改 ccb-v033-enforcement-consolidation state 文件 |
| **D3 实施顺序** | single dispatch with internal checkpoints | 4 根因经同一 task projection 耦合，分 slice 会引发临时 phase/status/UI 不一致 |
| **D4 F7 forward compatibility** | Console 容忍 `engineering_decidable_decisions` unknown frontmatter | 不语义解析 / 保持 frontmatterJson；不改 Prisma schema |

---

## 3. 实施顺序（single dispatch backend → frontend → tests）

按 R1 推荐：

1. **Add failing regressions first** — G1-G6 + F7 forward-compat fixture
2. **Backend：document-parser.ts** — path-derived doc_kind wins；frontmatter `kind` 仅作 semantic metadata
3. **Backend：project-indexer.ts** —
   - `normalizeTaskStatus`：`epic_completed → archived` bucket
   - `normalizeTaskPhase` 重写：boardLane 派生源 = `currentNode + runtimeState`，`phase` 仅 compat 读
   - `engineering_decidable_decisions` graceful skip
4. **Frontend：ui-mapping.ts + TasksPage.module.css** —
   - PHASE_COLUMNS 增加 archive 映射 / done 列承载归档
   - toggle 仅控显隐不改列存在
   - CSS 修横向溢出（常规视口 7 列可见或自适应换行）
5. **Frontend：planning_container subtype** — Epic badge + 屏蔽 workspace/dispatch/review CTA
6. **Test：fix project-routes.spec.ts:563** — 修 schema-invalid fixture（`currentNode=archive` + `status=active` + `runtimeState=done`）
7. **Test：window 完整 G1-G6 regression** + F7 unknown-field tolerance
8. **Run pnpm build / web tests / server tests / 27 guards fixture**

---

## 4. F7 epic 协同边界（C9 双向保护）

| 方向 | 保护 |
|---|---|
| F7 → bugfix | `engineering_decidable_decisions` 字段是 optional，Console 已经通过 frontmatterJson 容纳；本 bugfix 仅需添加一个"unknown field tolerance" test 验证不 regress |
| bugfix → F7 | 不动 `references/kernel/`（C6）；不动 .claude/hooks/（F7 已落 hook 不改）；不动 5 个 F7 措辞更新过的现有 guard 措辞；不重写归档 state（用 projection alias 替代） |

---

## 5. 涉及文件清单

| 文件 | 改动类型 |
|---|---|
| `apps/ccb-console/server/src/indexer/document-parser.ts` | 修 inferDocumentKind 优先级（路径强约束） |
| `apps/ccb-console/server/src/indexer/project-indexer.ts` | 修 normalizeTaskStatus + normalizeTaskPhase + boardLane 派生源 |
| `apps/ccb-console/web/src/lib/ui-mapping.ts` | PHASE_COLUMNS 调整 + 派生函数共用（C5 hard constraint）|
| `apps/ccb-console/web/src/pages/tasks/TasksPage.tsx` | toggle 行为 + Epic 子类型 badge + CTA gating |
| `apps/ccb-console/web/src/pages/tasks/TasksPage.module.css` | 横向溢出修复 |
| `apps/ccb-console/web/src/pages/overview/OverviewPage.tsx` | 概览计数共用同一派生函数（C5）|
| `apps/ccb-console/server/src/tests/project-routes.spec.ts` | 修 fixture + 加 G1-G6 regression |
| 新增/修改测试 fixture | F7 unknown-field tolerance + G1-G6 |

**绝不动**：references/kernel/ / .claude/hooks/ / docs/.ccb/specs/archive/ / docs/.ccb/state/2026-04-23-* / Prisma schema / 5+1 hotfix 文档

---

## 6. 测试覆盖矩阵

| 验收 | 测试形式 |
|---|---|
| AC1 G1 计数一致 | 概览 vs 索引健康 vs 看板可见+隐藏 三处对齐 |
| AC2 G2 不丢任务 | state-only task（含 epic 容器）出现在投影 |
| AC3 G3 archive 进 done 列 | toggle 开/关切换可见性，列存在与计数不变 |
| AC4 G4 epic 子类型 | 容器 task 渲染 badge + 无 workspace/dispatch CTA |
| AC5 G5 计数/过滤/列分桶共用派生 | grep 验证三处复用同一函数（C5）|
| AC6 G6 异常不静默穿透 | unregistered frontmatter kind/status 触发 lint 告警 |
| AC7 现有 27 guards | run-fixtures.sh 全绿 |
| AC8 F7 forward-compat | 含 `engineering_decidable_decisions` 的 state fixture 不 crash |

---

## 7. 升级触点（实施期 stop + re-escalate）

按 R2 共识 + Codex execution guard：

- 任何 N1-N5 相关改动尝试（重命名 Task.status/phase / 删 phase column / task_status 派生化 / Epic IA 独立页面 / lint taxonomy 扩张）
- 改动需扩到 references/kernel/ 任何文件
- 改动需扩到 .claude/hooks/ 任何文件
- 改动需 Prisma migration
- 改动需重写 docs/.ccb/specs/archive/ 或 docs/.ccb/state/2026-04-23-* 任何文件
- 1.5-2.5 天估时严重超出（>4 天）
- F7 hook 误触发或冲突

---

## 8. 下一步

step2_approval（Claude 自治）→ task_breakdown 节点 → spec 产出 → freeze → step3_approval（Claude 自治）→ dispatch 给 codex

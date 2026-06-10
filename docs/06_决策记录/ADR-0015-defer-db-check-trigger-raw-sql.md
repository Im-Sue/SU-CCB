---
id: ADR-0015
title: 显式延后 hierarchy 模型的 DB CHECK + TRIGGER raw SQL（won't-fix-now）
status: accepted
decided_at: 2026-05-09
decider: Claude
reviewer: ccb_codex
related_epic: task-hierarchy-three-tier-model
related_adr: [ADR-0013]
related_tasks: [task-hierarchy-m2-console-backend]  # task-hierarchy-m2-console-backend: 3d 部分
deprecated_in: null
removed_in: null
grace_window: open-ended（直至触发重启条件）
impacted_components: [apps-ccb-console-server (prisma schema only — 不变更)]
---

# ADR-0015: 显式延后 hierarchy 模型的 DB CHECK + TRIGGER raw SQL

## Status

Accepted（属于"决定不做"的关账记录）。

## Context

ADR-0013 §2.1 + 技术设计 §1 设计了三类 SQLite 层防护：

1. `chk_kind_node_consistency` CHECK：epic 必须 `currentNode IS NULL` + `parentEpicId IS NULL`，subtask 反之
2. `chk_requirement_status` CHECK：requirement.status 在 enum 内
3. 三条跨行 TRIGGER：subtask.parentEpicId 指向 kind=epic 同 project + 同 requirementId；UPDATE 时 re-validate；epic.requirementId 同 project

M2 spec §M2-PR5 把这部分定为 hard 落地项。实施时 ccb_codex 与 claude 评估后**未执行 raw SQL**，理由由 M2 spec frontmatter `non_blocking[3]` 记录："应用层 invariant tests 11 项兜底全 pass"。

batch slice 3 关账时显式记录这个 won't-fix 决定，避免 backlog 长期挂起反复重新评估。

## Decision

**不实施** ADR-0013 §2.1 + 技术设计 §1 的 DB CHECK constraints 与 SQLite TRIGGERs。

替代方案：保留 `apps/ccb-console/server/src/modules/task/hierarchy-invariants.spec.ts` 的 11 项应用层 invariant tests，作为 hierarchy 模型的事实防护。

## Rationale

| 维度 | 评估 |
|---|---|
| 防护覆盖 | 11 项应用层 invariant test 已覆盖 ADR-0013 §2.1 + 技术设计 §1 全部三类 SQL 防护的语义 |
| 实施成本 | raw SQL CHECK + 3 条 TRIGGER 需 Prisma migration + SQLite-specific syntax + Postgres 切换时全部重写 |
| 维护成本 | 双重维护（应用层 + DB 层）易漂移；DB 层 TRIGGER 调试困难；错误信息对后端开发不友好 |
| 故障窗口 | console 单进程部署，无并发写竞态；写路径全部经 `primitive-executor`，应用层 invariant 在写入前可前置校验 |
| 数据库无关 | 项目计划在 v0.5+ 切 Postgres；现写 SQLite TRIGGER 是 throw-away 投资 |
| 已知 escape hatch | raw `prisma.$executeRaw` 绕过 invariant — 但这本身是治理问题，DB CHECK 仅在违反 schema 时才命中，不能阻止 raw SQL 滥用 |

应用层 invariant 不是**完美等价**，但权衡 ROI 后判定：DB 层防护 ≤ 10% 增量保护、≥ 5× 维护成本，**不值**。

## Consequences

正向：
- 关账 hierarchy backlog 中一项长期 pending 项
- 简化 Prisma schema（无 raw SQL 块）
- Postgres 迁移时无 SQLite-specific 包袱

负向：
- 直接 `prisma.$executeRaw` 写入可绕过应用层 invariant；依赖 review 时 grep 拦截（治理而非工程层防护）
- 跨连接并发写理论窗口存在（但 SQLite + 单进程部署下不会发生）
- 数据从外部脚本导入时无 DB 层兜底（导入脚本必须自带校验，列入 hierarchy invariant test 套件）

## Alternatives considered

- **方案 A · 全做（ADR-0013 §2.1 原方案）**：拒，理由见 Rationale
- **方案 B · 部分做（只做 CHECK，不做 TRIGGER）**：拒，CHECK 只覆盖单行约束，跨行（parentEpicId 指向有效 epic）必须 TRIGGER，做半套等于没做
- **方案 C · 改用 Postgres 后做**：拒，Postgres 切换无明确时间表，也没必要绑 ADR；Postgres 切换时再独立评估
- **本方案 · 应用层 invariant 兜底 + DB 层 won't-fix**：accepted

## 触发重启条件

任一发生时**重新评估本决定**：

1. **多进程 / 水平扩展**：console 部署形态变化（单进程 → 多 worker / 水平扩展），并发写竞态成为现实风险
2. **DB 切换 Postgres**：迁移时同步评估是否引入 PG CHECK / TRIGGER（语法不同，需重新设计）
3. **invariant violation 漏出生产**：应用层 invariant 出现实际逃逸，事后回溯发现 DB 层防护可阻止
4. **外部数据导入需求**：出现需要直接导入 Task 行（脚本 / 迁移工具）的场景，且导入工具不接入 primitive-executor
5. **`prisma.$executeRaw` 滥用**：review 抓不住，raw SQL 写入污染 hierarchy 数据

## Restart procedure

触发重启条件后：
1. 在 ADR-0015 status 改为 `superseded`，新写 ADR-0015-revised
2. 重新跑 ADR-0013 §2.1 + 技术设计 §1 的 SQL 设计（按当时 DB 实情：SQLite or Postgres）
3. 加 Prisma migration + raw SQL 块
4. 跑 hierarchy-invariants 测试套件双校：应用层 + DB 层一致

## References

- `docs/.ccb/decisions/ADR-0013-task-hierarchy-three-tier-model.md` §2.1 — 原 SQL 设计
- `docs/03_开发计划/ccb-plan/2026-05-09-task-hierarchy-three-tier-model-技术设计.md` §1 — TRIGGER 详细 schema
- `docs/.ccb/specs/active/2026-05-09-task-hierarchy-m2-console-backend.md` — frontmatter `non_blocking[3]` 原始延后记录
- `apps/ccb-console/server/src/modules/task/hierarchy-invariants.spec.ts` — 应用层 11 项 invariant test

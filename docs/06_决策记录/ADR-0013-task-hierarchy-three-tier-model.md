---
id: ADR-0013
title: CCB 任务模型三层重构 — Requirement / Epic / SubTask
status: active
review_pass: R4 plan review 7.8/10
decided_at: 2026-05-09
last_updated: 2026-05-09
deciders: [user, claude (designer), ccb_codex (reviewer)]
consulted: ccb_codex
informed: 全 plugin/console 维护者
supersedes: null
related:
  - ADR-0010 (su-flow facade)
  - ADR-0011 (reactive scheduler)
  - ADR-0012 (task projection consistency)
parent_spec: docs/.ccb/specs/active/2026-05-09-task-hierarchy-three-tier-model.md
parent_design: docs/03_开发计划/ccb-plan/2026-05-09-task-hierarchy-three-tier-model-技术设计.md
---

# ADR-0013 · CCB 任务模型三层重构

## Status
**Proposed** （待 R2 plan review pass + step2_approval 后转 active）

## Context

CCB v0.3.2 的 Task 模型扁平，与实际工作模式（需求 → epic 容器 → 多个 PR 子任务）存在结构性 mismatch：

- DB schema 没 `parentTaskId` / `epicTaskKey` 字段
- 164/164 任务 `requirementId=null`（实测）
- 看板上 epic（卡在 `task_breakdown.ready_for_dispatch`）与子 PR（在 `dispatch`+）平铺各自显示 20% 进度，语义完全不同
- Epic 永远走不出 task_breakdown（它本身没法 dispatch）
- Requirement 模块代码已 implemented 但 0% 接入工作流

本 ADR 决定跨 plugin（kernel + skills + templates）+ console（schema + UI）双仓重构任务模型为三层。

## Decision

采纳 **三层模型 + 7 节点只挂 SubTask + 单 Task 表 + kind 列** 方案。具体决策表：

| # | 决策 | 选择 | 替代方案 |
|---|---|---|---|
| **D1** | roadmap 插入策略 | **B** · 独立 hierarchy epic + 触发 master-roadmap replan | A=Wave 2 新增 E6.5（不动 master），C=替换 E12 |
| **D2** | applicable_kinds 改造 | **A** · node-manifest-schema 加 applicable_kinds，7 节点全标 [subtask]，新增独立 epic_lifecycle.yaml + requirement_lifecycle.yaml manifest | B=epic 走 noop 7 节点（degenerate path，长期语义债） |
| **D3** | Schema 取舍 | **A** · 保留单 Task 表 + kind enum + DB CHECK constraints | B=拆 Epic / Requirement 独立表（API/读取层重写量大） |
| **D4** | SubTask 起步节点 | **A** · 从 `dispatch` 起步，继承 Epic 的 plan 三节点产物 | B=走完整 7 节点退化 noop，C=保留完整 7 节点（看板污染） |
| **D5** | 历史数据迁移 | **A** · 启发式分类 ≥95% 自动置信度 + dry-run + 人工 review 边界 case + `legacyKind` 字段保留可逆 | B=全量手动 review 164 task，C=全标 subtask 让用户事后重组 |
| **D6** | plugin 版本号 | **A** · v0.5.0（minor bump） | B=v1.0.0（major），C=v0.4.next（patch） |
| **D7** | API sunset 窗口 | **直接下架** /api/tasks 旧 schema，不做兼容层（用户自管本地调用） | 6 个月 / 3 个月 / 12 个月 / 永久兼容 |
| **D8** | Requirement 身份归属 | **A** · 独立 Requirement 表 + task_kind=[epic,subtask]（不含 requirement） | Task.kind=requirement 双实体 / 双轨桥接 |
| **D9** | epic_replan_requested wire | **A** · epic_lifecycle handler 直接调 epic.subtask_create primitive，不走 7 节点 | 手动决策 / 轻重分流 |
| **D10** | SubTask spec 粒度 | **A** · Epic spec 内嵌 subtask sections + linkedSpecId 共享 + spec_section_id 索引 | 每 SubTask 独立 spec 文件 / 现有表字段复用 |
| **D11** | UI/UX 实施归属 | **claude** · M3/M4 共 ~7 个 PR Claude 自实施，不派 codex | 视具体 PR 派工 |

## Consequences

### Positive
- **领域模型清晰**：Requirement / Epic / SubTask 三层显式建模，对应实际工作流
- **7 节点职责单一**：只挂 SubTask 层，Epic / Requirement 各自独立生命周期，进度语义明确
- **看板信息架构改善**：Epic 摘要置顶区 + SubTask 占节点列，用户能看到 epic 鸟瞰
- **Requirement 一等公民**：从对话工件升级成可追溯实体
- **可持续化**：v0.5.0 协议升级提供未来 multi-Epic / cross-Epic dependency 扩展空间
- **无双轨调用路径**（D7）：避免新旧 API 长期并存的代码调试复杂度

### Negative
- **协议级 breaking change**：plugin 升 v0.5.0，下游项目须同步 kernel snapshot
- **DB migration 风险**：164 历史 task 启发式分类有误分类风险（缓解：dry-run + 人工 review）
- **scheduler 行为变化**：epic 不再走 7 节点（缓解：DB CHECK + scheduler 入口检查 + invariant test）
- **总工期 ~17-20 工作日 / ~3.5-4 周**（含 codex consult 调整 +3-5 天）
- **看板 IA 用户感知变化**（缓解：?legacy=1 灰度 30 天）

### Neutral
- master-roadmap replan：增加 1 个 epic，调整 17 → 18 epic，4 wave 不变
- requirement-entry 模块从死字段激活成活路径，可能暴露隐藏 bug（M2 集成测试覆盖）

## Alternatives Considered

### Alt 1 · 不动数据模型，仅 UI grouping（被否）
- 看板用 taskKey 前缀启发式聚合 epic+PR 折叠
- **拒绝原因**：靠命名约定，跨命名规范的 epic 无法识别；进度不会真正合流；治标不治本

### Alt 2 · 拆表（Requirement / Epic / SubTask 独立 table）（被否，D3）
- 模型最纯净
- **拒绝原因**：API/读取层重写量大；现有 Task 表深度绑定 projection / state file / event journal；风险与工期不匹配

### Alt 3 · 两层模型（Requirement → SubTask，无 Epic）（被否）
- 摆脱 Epic 中间层
- **拒绝原因**：实际工作模式中 Epic（如「Task Detail 重设计」）就是协调器，强行扁平化会丢失重要语义层

### Alt 4 · 保留 epic 走 7 节点退化 noop（被否，D2）
- manifest 改动面最小
- **拒绝原因**：长期语义债；epic 的 review / archive 含义混乱；codex consult 明确不推荐

## Implementation

### Phase 0 · master-roadmap replan
本 ADR archived 后，PR 修改 `2026-05-02-ccb-master-roadmap-v0.4v1-console-v2-growth.md`，新增 Wave 1B 末或 Wave 2 起首一个 epic：
- ID: E5.5 或 E6.0-pre
- 名称: hierarchy-three-tier-model
- 依赖: 无（可立即启动）
- 阻塞: E6 / E11 / E12（需要 hierarchy 落地后才能完成 V2 UI 全量）

### Phase 1 (M0) · Plugin 协议升级
详见技术设计文档 §1。

### Phase 2-5 (M1-M4) · Console 改造
详见技术设计文档 §2-§7。

### Migration（M1）
- 启发式 + dry-run（≥95% 置信度阈值）
- 人工 review 低置信 case
- legacyKind 字段保留可逆

### Cutover（M2）
- /api/tasks 直接切换新 schema（D7 直接下架，不保留兼容）
- console-web 同步切换调用方
- 仅 README CHANGELOG 记 breaking

## Open questions

R1 + R2 引入的 7 项 open questions 在 technical_design R2 修订版全部 resolve（详见 spec §5）。无未决项。

## Provenance

- **R1 consult**: job_709e41e7d6cb (ccb_codex, 2026-05-09)，6 决策全 needs_user_arbitration → 用户在同回合接受
- **R2 consult**: job_d4442f312a91 (ccb_codex, 2026-05-09)，**FAIL** 4.75/10 (E2=3 E4=4)
  - 17 个 issue + 6 blockers + 7 missing invariants + 4 ordering risks
  - 用户在同回合拍 D8 (独立 Requirement 表) / D9 (epic_lifecycle handler) / D10 (Epic spec 嵌 subtask) / D11 (UI/UX claude)
  - Claude 完成技术设计 R2 修订版（详见技术设计文档）
- **R3 consult**: pending（评估 R2 修复完整性 + D8-D11 wire 是否通）
- **User arbitration**: 2026-05-09 同回合接受 R1 推荐 + D7 直拍 + R2 后 D8-D11 直拍
- **Plan review**: 待 (task_breakdown 节点完成后触发)

## References

- spec: `docs/.ccb/specs/active/2026-05-09-task-hierarchy-three-tier-model.md`
- 技术设计: `docs/03_开发计划/ccb-plan/2026-05-09-task-hierarchy-three-tier-model-技术设计.md`
- master roadmap: `docs/.ccb/specs/active/2026-05-02-ccb-master-roadmap-v0.4v1-console-v2-growth.md`
- 相关 ADR: ADR-0010 / ADR-0011 / ADR-0012
- kernel manifest: `references/kernel/state-schema.yaml` / `nodes/requirement_analysis.node.yaml` / `nodes/task_breakdown.node.yaml`

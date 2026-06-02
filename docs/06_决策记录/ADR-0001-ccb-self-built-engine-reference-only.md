---
id: ADR-0001
title: CCB 自研 workflow engine；vibeman 及类似产品仅作 reference
status: active
activated_at: 2026-04-22
decided_at: 2026-04-22
last_updated: 2026-05-14
decider: Claude
reviewer: User
consulted: Codex（R1 / R1-b / R2 / R3 / R4）
related_tasks:
  - ccb-pm-platform-mvp-planning
notes:
  - 原 markdown bullet 格式 status "accepted (pending step1_approval)"。项目已按本 ADR 实施 v0.3.x 工作流内核 + v0.4 ReactiveScheduler + Console V2 + 多 Anchor runtime，step1 隐式落实，故 2026-05-14 batch 规范化 status 为 active。
---

# ADR-0001: CCB 自研 workflow engine；vibeman 及类似产品仅作 reference

---

## Context

用户 2026-04-22 在 `/ccb:su-plan` 会话中明确 CCB 定位：

> "这套CCB是基于多LLM的协作工程化管理的项目管理平台（目前主要服务于产品、UI、前端、后端、架构、运维，管理方面可以对标TAPD或者其他的项目管理平台）。在项目管理平台的基础上，进行做一套协作工作流管理（可以考虑参考vibemen的一些思路或者借鉴，也可以去深度查找更多相关的平台进行借鉴）。在协作工作流的基础上再进行工作流节点动态化流转/执行由LLM对工作流内的节点进行动态化编排（节点像是herness里的tools或者claude codex里的tools一样的定义、使用）。"

三层递进依赖：Layer 0 PM 平台 → Layer 1 协作工作流 → Layer 2 LLM 动态编排。

本地 `.tmp/vibeman-inspect/` 部署 vibeman@0.0.18 (Apache-2.0)，schema 完整，能力与 Layer 1/2 重叠。

Claude 在 R2-R3 consult 把用户锚词"参考/借鉴"漂移为"Integrate as runtime adapter"；Codex 附和未挑战。用户 2026-04-22 R4 轮指出："**它不应该是我们的一部分或者对接对象**"。Codex R4 主动撤销 R3 integration 推荐。

---

## Decision

**CCB 自研** workflow engine / executor registry / run lifecycle / UI。

vibeman 及 n8n / Temporal / LangGraph / CrewAI / Harness / Dify / Airflow 等**仅作 reference / inspiration source**。借鉴维度和深度见 requirement doc 第四节借鉴矩阵（Scale 0–4）。

**禁止**：integrate / fork / depend-on / HTTP-adapter / runtime-adoption 任何产品代码；包括 vibeman 本地副本。

**起点**：**v0.3.2 就是 CCB 自研引擎的起点**。7 canonical 节点 / primitive / guard-registry / transition-table / CAS / consumed_events 已是 CCB-native engine seed。**只演进不重启**。

**MVP 范围**：5 引擎表（ExecutorProfile / WorkflowDefinition / WorkflowRun / WorkflowStepRun / WorkflowRunLog）+ 1 workspace 表（TaskWorkspace）+ 8–10 APIs + 4–5 UI 组件。

---

## Consequences

### Positive
- Product identity 清晰：CCB 是 PM-native + multi-LLM-native 平台，不是"加了 AI 的 TAPD 克隆"
- 不受 vibeman / 其他产品 schema 演进约束
- 治理层（primitive / guard / consult / replan / ADR / CAS）为一等公民
- Apache-2.0 等合规风险规避（借鉴概念不触版权）
- v0.3.2 既有投入（9 设计文档 + 7 manifest + lint + hook + Console Phase 3）100% 复用

### Negative
- 实现工作量大于"拿来即用"
- 短期发布速度慢于直接复用 vibeman 的场景
- 需要配套 Semantic Anchor Guard 防止未来再次漂移

### Required Companions
- **Semantic Anchor Guard** 立即采纳为 v0.3.2 第二个 hotfix（配合 DE Guard 与四段 brief 三件套）
- 切片新增 **Step 0 "Reference notes"**（借鉴矩阵 + borrow/reject 清单）作为研究输入产物
- requirement doc 第四节"借鉴矩阵"管理每维度深度边界

---

## Alternatives Rejected

### A1 — Fork & Embed Vibeman
**拒绝**。Vendoring 已编译 `dist` 高维护成本；违反用户"不对接"锚词；与 product identity 冲突；Apache-2.0 attribution 复杂。

### A2 — Integrate as Runtime Adapter
**拒绝**（曾为 R3 主推方案，R4 撤销）。违反用户"参考/借鉴"锚词；runtime gravity 会把 CCB 拉离 PM-first 身份；引入三真源漂移（CCB DB / docs/.ccb/state / .vibeman/vibeman.db）；造成语义扩大（见 feedback_semantic_anchor_guard memory）。

### A3 — Learn & Rebuild From Scratch
**部分采纳（借鉴深度 ≤ 4，学习层面），但不 rebuild**。v0.3.2 已是 CCB engine seed，从零重启会浪费 9 份设计文档 + 7 manifest + lint 工具等已落地投入。

---

## Related

- Memory: `ccb_project_northstar.md` / `vibeman_local_fact.md`
- Memory: `feedback_decision_escalation_guard.md` / `feedback_semantic_anchor_guard.md`
- Session: 2026-04-22 `/ccb:su-plan` 五轮 consult（R1/R1-b/R2/R3/R4）
- Requirement doc: `docs/02_需求设计/ccb-plan/2026-04-22-ccb-pm-platform-mvp-planning.md`
- State: `docs/.ccb/state/2026-04-22-ccb-pm-platform-mvp-planning.md`
- Kernel: `references/kernel/` 全部 canonical（保持 CCB 引擎 seed 地位）

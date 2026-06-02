---
task_id: subtask-eb6198ee5f7d
title: plugin su-flow 处理 derive_followup
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmppm45yt09j35fx6e2
section_id: pr8-su-flow-derive-followup
order: 8
implementation_owner: ccb_codex
dependencies: [subtask-a9771860331c]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 414236ed6b705f7dd089e4533efc0eb7cae0c9340733a57d34759be17a245f0b
created_at: 2026-05-29T09:30:00.000Z
updated_at: 2026-05-29T15:00:00.000Z
updated_by: ccb_claude
---

# plugin su-flow 处理 derive_followup

> 一句话:补 pr1 的 plugin 半边 —— 让 su-flow 接住 Console 派出的 `derive_followup`,端到端 derive 才通。
> 状态:已物化,**等待执行**(codex 串行,排在 pr4 之后,不并行派)。

## 背景
pr1(已完成 b3ec17c)让 Console derive 改派 `/ccb:su-flow`(step=breakdown_draft, action=derive_followup, 带 source_task provenance),不再直写 DB。但 plugin `su-flow` 尚不认 `derive_followup` → 派出去没人接,derive 端到端不通。

## 范围
- `su-flow` / `breakdown-draft` 识别 `action=derive_followup`,把 `followup.{type,title,description}` + source_task provenance 落成该需求 breakdown draft 的一个新 subtask。
- 走 approved → `su-materialize-requirement` 写 `docs/03` dev_task → 回投影。

## 触及
`su-ccb-claude-plugin`(skills/su-flow、lib/breakdown-draft)

## 依赖
pr1 真相流收口(已完成)

## 验收
- [ ] Console 点"派生 followup" → plugin 生成一条 followup 子任务(`docs/03` dev_task)→ 投影可见
- [ ] su-flow 测试覆盖 `derive_followup`
- [ ] 端到端验证通过

## 设计决策(2026-05-29 · Claude):reopen 新代次

codex check(rep_4ee8b2b31191)查出主场景(从已物化 task 派生 followup)命中 `consumed` draft,而 breakdown-draft 状态机(`lib/breakdown-draft/index.mjs` 的 `transitionAction`)无 `consumed→*` 转移;provenance 也无 frontmatter 落点。用户拍板 **重开 draft 新代次**。契约如下,codex 按此实施:

1. **新增 breakdown-draft 转移 `consumed → draft`(reopen)**:`transitionAction` 加 `consumed+draft → "reopen"`,`eventTypeForTransition` 加 `reopen: "breakdown_draft_reopened"`。语义:每需求保持单一 draft,reopen 把 consumed draft 拉回 draft 态追加 followup,开启新代次;`consumed_at/by/from_hash` 保留(下次 consume 覆盖)。status enum 已含 draft/consumed,无需改 enum;review_history 用现有 `status_changed` action。
2. **followup 追加**:走现有 `updateBreakdownDraft` 追加一条子任务 —— `order = max(order)+1`、`section_id = pr<order>-<slug>`、`include: true`,满足 order 连续 + section_id 前缀不变量。provenance 进该子任务 `spec_section_md` 正文的派生块(`> 派生自:task <source_task_id>(<source_task_key>)`);**不新增 schema 字段、不改 dev_task frontmatter/投影**。
3. **物化幂等**:`su-materialize-requirement`/`lib/subtask` 物化时**跳过已有 dev_task 文档的子任务**(按 section_id→task_id / docs/03 既存判定),只为新子任务建 dev_task;重 consume 一个 reopen 过的 draft 必须安全(只产出新 followup 的 dev_task)。
4. **su-flow derive_followup 编排**:读 draft 取 hash →(若 consumed)`consumed→draft` reopen(expected_hash CAS)→ 重读 hash → `updateBreakdownDraft` 追加 followup(expected_hash)→ `draft→reviewing→approved→consumed`(逐步 CAS)→ 物化(幂等)。draft 未 consumed 时直接追加。全程严禁 anchor 内 `fs.writeFile` 直写。
5. **延后(不在 pr8)**:可投影的"派生自 task X"关系(dev_task frontmatter + indexer + Console UI)作为独立增强。

kernel `transition-table.md` 不动(它是 7 节点流程表;breakdown-draft status 状态机由插件 lib 强制,二者分离)。

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr8-su-flow-derive-followup ｜ Owner: ccb_codex ｜ Priority: high ｜ Deps: pr1-truth-flow
- 派工状态:**已落地**(submodule `design/v0.3-protocol-kernel` @ `ddb147e`;v1.0 父仓 pointer 已 bump)

## 审查结论(2026-05-29 · Claude)
- **接受**(job_72cd396c85da,rep_5b680c2574a2)。实现完全对齐「设计决策(reopen 新代次)」:
  - `lib/breakdown-draft`:`consumed→draft` reopen transition + `breakdown_draft_reopened` event;`deriveFollowupBreakdownDraft()` 走 CAS 读→(consumed 则 reopen)→`updateBreakdownDraft` 追加 followup→`reviewing→approved`,返回 approved hash 供后续 consume+materialize。
  - `lib/subtask`:materialize 以 `task_id+requirement_id+section_id` 为幂等键识别既有 dev_task;`assertMaterializableDraft` 对 `consumed && consumed_from_hash===expectedHash` 返回 `already_consumed` 跳过重 consume → 重 materialize 安全;既有子任务 `source_draft_hash≠新 hash` 不重复发事件;只为新 followup 写 docs/03。
  - `skills/su-flow/SKILL.md`:补 `derive_followup` action 契约(reopen + consume + materialize 全程 CAS)。
  - provenance 只进新子任务 `spec_section_md` 正文(`> 派生自:task <id>(<key>)`),未扩 schema/frontmatter/投影 ✓。
- **验证**(Claude 独立复跑):pr8 三测试文件 35 pass;**整 plugin 套件 128/129 pass**。唯一失败 `skills/requirement-reanalyze/scripts/smoke-test.mjs`(req md not found)经 stash pr8 在 HEAD 复跑**同样失败 → 既有问题、与 pr8 无关**(疑似更早 doc-driven 路径迁移遗留),另案跟踪。
- **已落地(2026-05-29 · 用户选 a)**:submodule `design/v0.3-protocol-kernel` @ `ddb147e` 提交;v1.0 父仓 submodule pointer 已 bump,与本 pr8 doc 同提交。

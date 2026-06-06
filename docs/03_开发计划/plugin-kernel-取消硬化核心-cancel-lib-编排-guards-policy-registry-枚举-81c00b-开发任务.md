---
doc_type: dev_task
task_id: subtask-8685e781c00b
title: plugin/kernel 取消硬化核心：cancel lib 编排 + guards/policy/registry + 枚举漂移修复 + SKILL 重写
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmpzllxw73320bc3428913778
section_id: pr2-plugin-cancel-hardening
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzllxw73320bc3428913778.json
source_draft_hash: acb5232bfcd1c86c58b5b511afaca3f63f1ac749fd999d0c2a1edba3f6c421b1
created_at: 2026-06-06T09:05:52.211Z
code_workspace: {"path":"../SU-CCB-req-cmpzllxw73320bc3428913778","branch":"ccb/req-cmpzllxw73320bc3428913778"}
---

# plugin/kernel 取消硬化核心：cancel lib 编排 + guards/policy/registry + 枚举漂移修复 + SKILL 重写

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | [NEW] lib/requirement-cancel（六步编排+resumeMode+state-aware worktree+listDevTasksByRequirement）；validateExecutableGuards 增 cancel/defer/subtask 分支；policy 增 subtask.cancel+退休 analyze disabled 条目；global.yaml 补注册；state-schema/lifecycle/transition-table 枚举修复+generated-policy 重生；su-cancel SKILL.md 重写。跨需求依赖 260604 PR1。 |
| 需求来源 | cmpzllxw73320bc3428913778 |
| 本期范围 | pr2-plugin-cancel-hardening · plugin/kernel 取消硬化核心：cancel lib 编排 + guards/policy/registry + 枚举漂移修复 + SKILL 重写 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
取消语义闭环核心：状态写全部收口 applyCapabilityOutcome，墓碑先行+全步幂等可重入，级联完整。依据技术设计 §三/§四/§六（v1.1）。

#### 任务分解
1. **[NEW] `lib/requirement-cancel/index.mjs`**：`cancelRequirement({projectRoot,requirementId,reason,sourceActor,dispatchRef})` 六步编排——①resolve+前置（delivered→拒；cancelled→resumeMode 续清理）②append `user_cancel_authorized` 事件（reason/dispatchRef/idempotency_key）→ `applyCapabilityOutcome(requirement.cancel, expectedHash, mustAskRefs:[must_ask_9], evidence:[A file_exists, B journal_event_exists 指向授权事件])` 墓碑③`listDevTasksByRequirement`（新 helper，参考 lib/reconcile 扫描模式）→ status∉{done,cancelled} 逐个 `applyCapabilityOutcome(subtask.cancel, expectedHash)`，CAS_CONFLICT→重读重判④readBreakdownDraft 探测→有则 deleteBreakdownDraft/无则 skip⑤worktree state-aware：ready→discardRequirementWorktree(force) / merged→cleanupRequirementWorktree(260604 PR1) / missing|archived|discarded→skip⑥append `requirement_cancel_cascade_completed` 汇总（cancelled_task_ids/skipped/resumed/issues）。`cancelSubtask` 单任务同构。返回 {ok,noop,resumed,steps,issues}。
2. **guards**：`validateExecutableGuards` 增分支 + 实现 `requirement_cancel_terminal_protection`（delivered→REJECTED/cancelled→noop）、`subtask_cancel_terminal_protection`（done→REJECTED/cancelled→noop）、defer 镜像 guard（拍板③）；guard-registry.md 注册。
3. **policy yaml**：+`subtask.cancel:cancelled:subtask`（write_target dev_task，status set:cancelled，must_ask_refs [must_ask_9]）；requirement.cancel/defer 挂新 guard；**删除 disabled `requirement.analyze:analyzed`（拍板⑤）**。
4. **`capabilities/global.yaml`**：按 requirement.promote 既有样式补注册 requirement.cancel/defer/finalize + subtask.cancel（拍板②）。
5. **枚举漂移修复**：state-schema.yaml requirement_status `draft→drafting`/`analyzed→planning`；requirement_lifecycle.yaml from/to + transition id 同步重命名；cancel/defer from-list 加 deferred（拍板①）；transition-table.md 对齐；lint_manifest.py 回归；plugin `generated-policy.mjs` 重生。
6. **`skills/su-cancel/SKILL.md` 重写**：精确 import+调用合约（对齐 su-archive 工程化程度）；错误处置表（GUARD_REJECTED/MUST_ASK_APPROVAL_MISSING/CAS_CONFLICT/LOCK_TIMEOUT）；废除「discard 完成后再写 cancelled」改墓碑先行；末步 best-effort `POST /scan`（Console 缺席容忍）。
7. **单测矩阵**：guard 矩阵（requirement/subtask/defer × delivered拒/cancelled noop/done拒）；resumeMode 重入；draft/worktree 缺失 skip；worktree 三态分派；CAS 冲突重读重判；授权事件+B evidence 链路；must_ask 缺失拒绝。

#### 验收标准
- [ ] 全新 lib 测试绿 + plugin 既有测试无回归；lint_manifest.py 过。
- [ ] 取消后 frontmatter status=cancelled 且 journal 含授权/级联/汇总事件链。
- [ ] 人为中断后重派 su-cancel 可 resumeMode 续清理（测试覆盖）。
- [ ] sweep 后 kernel/lib/生成产物无 draft/analyzed 残留（journal/ADR/lastTransitionId 历史除外）。
- [ ] SKILL.md 与 lib 行为一致，无散文式状态写入表述。

#### 边界 / 不做
- 不碰 su-oriel（pr3）；不实现 reactivate transitions 文档化；不做 job 抢占；历史 journal/ADR/state 不 sweep。

#### 依赖 / 执行注意
- **跨需求依赖：cmpworktreearchive260604 PR1 先合并**（提供 cleanupRequirementWorktree + worktree state 语义 + discard guard）。其 dev_task 现为 awaiting_codex_pickup；若排期被迫并行，fallback=先落 capability/kernel/cancel core（步 1①-④⑥+2-7），worktree state-aware（步 1⑤）延后依赖满足后补，不自造兼容 helper。
- 与 260604 PR1 共改 `lib/capability-outcome`（其加 evidence check、本 PR 加 guard 分支）——串行合并消解冲突。
- plugin 是 submodule，按既有 worktree 流程；勿在主仓跑 server test（db:prepare 清 dev.db）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpzllxw73320bc3428913778
- Section: pr2-plugin-cancel-hardening
- Owner: ccb_codex
- Priority: high
- Dependencies: none

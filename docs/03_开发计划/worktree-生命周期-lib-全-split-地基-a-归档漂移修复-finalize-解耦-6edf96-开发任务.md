---
doc_type: dev_task
task_id: subtask-cef1146edf96
title: worktree 生命周期 lib 全 split 地基 + A 归档漂移修复 + finalize 解耦
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpworktreearchive260604
section_id: pr1-worktree-lifecycle-split
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpworktreearchive260604.json
source_draft_hash: 0d9d990c7e64a4f3fbee2476deb0e7adac5d696afba2fc3dd0557b74752a53ba
created_at: 2026-06-06T08:12:35.133Z
updated_at: 2026-06-06T08:54:34.393Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpworktreearchive260604","branch":"ccb/req-cmpworktreearchive260604"}
---

# worktree 生命周期 lib 全 split 地基 + A 归档漂移修复 + finalize 解耦

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 拆 merge/cleanup/reopen + discard guard + canonical-sync-commit + 幂等/recovery + state 字段 + dev_task_requirement_terminal evidence；子任务 archive 停碰 worktree、su-batch 尾全-done-gate merge→cleanup→finalize；补多子任务串行测试。bug A 在此修复。 |
| 需求来源 | cmpworktreearchive260604 |
| 本期范围 | pr1-worktree-lifecycle-split · worktree 生命周期 lib 全 split 地基 + A 归档漂移修复 + finalize 解耦 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
建 worktree 生命周期 lib 全 split 地基，并落地需求 A 的归档漂移 bug 修复 + finalize evidence 解耦。把最大风险的状态机/证据契约一次测透，PR2/3/4 在其上增量。
- **bug 根因**：worktree per-需求共享，但 merge+删分支放在每个子任务 archive（`archive.node.md` 第7点 + `su-batch` 第8点组合），`ensure` 对非 `ready` fail-fast（`lib/worktree/index.mjs:314`）→ 多子任务串行第 2 个 `ensure` 撞 `already archived`。
- **依据**：技术设计 §2/§3/§4.1/§4.2/§4.4/§4.5。

#### 任务分解
1. **`lib/worktree/index.mjs` 状态机 + 拆函数**：拆旧 `archiveRequirementWorktree` →
   - `mergeRequirementWorktree`（只吃 `ready`→`merged`；merge 回 target、**保留** worktree+分支）
   - `cleanupRequirementWorktree`（只吃 `merged`→`archived`；branch tip 须为 target 祖先后再 remove + `branch -d`）
   - `reopenRequirementWorktree`（只吃 `merged`→`ready`；不碰 git，校验 worktree+分支在 + worktree clean，dirty→escalation）
   - `discardRequirementWorktree` **补 guard**：只允 `ready→discarded`（现完全不看 status）
   - 旧 `archiveRequirementWorktree` 留 compat wrapper(merge+cleanup)
   - state 新增 optional：`status` 枚举加 `merged`；`merged_branch_sha`/`target_sha_after_merge`/`merged_at`/`reopened_at`。**schema_version 不 bump**（零迁移）。
2. **canonical-sync-commit（§4.1）**：merge 前只 `git add` 本需求 CCB-owned allowlist（本 req dev_task paths + `docs/02` 本 req md + `docs/00_文档地图.md` + `docs/.ccb/events/journal.jsonl` + `docs/.ccb/worktrees/<req>.json` + `docs/.ccb/drafts/breakdown/<req>.json`）→ commit；**allowlist 外 dirty → escalation `canonical_dirty_outside_allowlist`**。不 broad add 目录。
3. **幂等/recovery（§4.2/§4.5）**：merge 时 branch tip 已是 target 祖先 → no-op 补写 `merged`；否则 merge，冲突 `merge --abort`+escalation。cleanup 时 git 实况已清而 state 未写 → 补写 `archived`。
4. **finalize evidence 解耦（§4.4，Codex 要求前移本 PR）**：`lib/capability-outcome` 新增 evidence check `dev_task_requirement_terminal`（requirement 域，扫全部非 cancelled dev_task 终态，**不查 `batch_authorization_completed`**）；`capability-outcome-policy.yaml` finalize policy additive 接受；regen `generated-policy.mjs`。
5. **wiring（A 修复）**：子任务 archive 停止调 worktree 收尾、只写 done（`status:done/current_node:archive/review_status:passed`）；`su-batch` 尾部新 helper `isRequirementFullyTerminal`（扫全部 dev_task 按 `requirement_id` 聚合，全非 cancelled done+archive+passed、无未物化 approved follow-up）→ 真则 `merge→cleanup→finalize`（用新 evidence）。
6. **测试**：`worktree.test.mjs` 补多子任务串行（ensure→done→ensure 复用 noop）、`ready→merged→archived`、discard guard、sync-commit allowlist、cleanup ancestor、merge/cleanup recovery；`evidence-registry` `dev_task_requirement_terminal` 单测。

#### 验收标准
- [ ] 多子任务串行：`ensure→(子任务 done 不碰 worktree)→ensure` 复用 noop，不再撞 `already archived`。
- [ ] **跨多 batch 全需求 done → finalize 成功**（不再卡 `batch_authorization_completed` scope）。
- [ ] canonical-sync-commit：allowlist 内提交、allowlist 外 dirty→escalation（测试覆盖）。
- [ ] cleanup ancestor 校验、merge/cleanup recovery 重入（测试覆盖）。
- [ ] 全 lib + evidence 测试绿；plugin typecheck 过。
- [ ] `reopen` 函数已实现但**命令入口未启用**（PR2 接）——回执须注明「函数存在、入口未启用」。

#### 边界 / 不做
- 不引入 merged 预览暂停（su-batch 尾此 PR 仍 `merge→cleanup→finalize` 背靠背）；不做手动归档/reopen 命令入口（PR2）。
- 不碰 Console/su-oriel（PR3）；不碰 ADR/分发副本（PR4）。
- node manifest 仅改 A 行为必需处（子任务 archive 不碰 worktree）；B 语义文案 PR2。

#### 依赖 / 执行注意
- 无前置依赖。**最大子任务**，验收须覆盖 recovery/allowlist-dirty/finalize-evidence（Codex 风险1，否则回执不可信）。
- 与 PR2 共改 `su-batch` SKILL / `archive.node.md`（串行，PR2 依赖本 PR）。
- plugin 是 submodule：按既有 worktree 流程；本 PR 改 kernel 真相源，分发副本 sync 留 PR4。
- 别在主仓跑 server test（`db:prepare` 清 dev.db）。

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

- Requirement: cmpworktreearchive260604
- Section: pr1-worktree-lifecycle-split
- Owner: ccb_codex
- Priority: high
- Dependencies: none

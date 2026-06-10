---
doc_type: dev_task
task_id: subtask-92174773fd31
title: 合并洁净度三态 classifier + allowlist 补 technical_design + tolerated_paths 诊断
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cm6241561f52fc0d749mgsync
section_id: pr1-merge-gate-classifier
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cm6241561f52fc0d749mgsync.json
source_draft_hash: cf45558c4df36c2c8cbd8388d2f1db57dc99285282d6a279f0cf6d7bf46225e7
created_at: 2026-06-10T04:51:50.673Z
updated_at: 2026-06-10T05:30:42.803Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cm6241561f52fc0d749mgsync","branch":"ccb/req-cm6241561f52fc0d749mgsync"}
---

# 合并洁净度三态 classifier + allowlist 补 technical_design + tolerated_paths 诊断

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | canonicalSyncAllowlist 增 technical_design（doc_type+requirement_id 谓词）；新增 classifyDirtyEntry 三态（OWN 提交/TOLERATE 放行不提交/FOREIGN 仍 escalate，删除·rename 读不到 frontmatter 一律保守 FOREIGN）；canonicalSyncCommit 仅 FOREIGN escalate，payload 增去重排序 tolerated_paths，既有字段形状不变；classifier 单元 + vlr74b 重演集成 + 回归。 |
| 需求来源 | cm6241561f52fc0d749mgsync |
| 本期范围 | pr1-merge-gate-classifier · 合并洁净度三态 classifier + allowlist 补 technical_design + tolerated_paths 诊断 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把合并前的"现场检查"从一刀切改成三类分流。现状：`canonicalSyncCommit` 拿整个主仓 `git status`，只要有任一行路径不在"本需求白名单"里就拒绝合并（escalate `canonical_dirty_outside_allowlist`）——并行需求的在途文档互相挡死。本任务改成三态分类：**自己的**（OWN，收拢提交）/ **别人在途的**（TOLERATE，放行但绝不代提交）/ **异己的**（FOREIGN，照旧拦）。同时修白名单缺口：本需求的技术设计稿（`technical_design`）现在不在白名单里，连自己都挡自己。

> 术语白话：allowlist（白名单）＝「这个需求自己该收拾提交的文件清单」；escalate＝「停下来上报人工处理」；porcelain＝`git status --porcelain` 的逐行输出；frontmatter＝md 文件头部 `---` 包起来的元数据。

```
旧: porcelain 任一行 ∉ allowlist             → escalate（全局严格）
新: 每行走 classifyDirtyEntry:
      OWN      (∈ 本需求 allowlist)          → git add + commit
      TOLERATE (可识别的受管在途档)          → 放行，记 tolerated_paths
      FOREIGN  (源码/不明/读不出归属)        → escalate（带 tolerated_paths 诊断）
```

### 任务分解

全部在 `su-ccb-claude-plugin/lib/worktree/index.mjs` + 同目录测试：

1. `canonicalSyncAllowlist`(:309)：增 technical_design——`docs/03_开发计划/` 下 `doc_type==="technical_design" && requirement_id===requirementId`（复用 `markdownPathsMatchingFrontmatter`，与 dev_task 谓词并列）。
2. 新增 `classifyDirtyEntry(entry, allowlist, projectRoot)`，对 porcelain 单行判类（行内多路径时**每条路径都得 OWN/TOLERATE 才放行，任一 FOREIGN 即整行 FOREIGN**）：
   - OWN：路径 ∈ allowlist。
   - TOLERATE(bound)：`docs/02_需求设计/**.md` 且 frontmatter `doc_type==="requirement"` 且 `id` 存在；或 `docs/03_开发计划/**.md` 且 `doc_type ∈ {technical_design, dev_task}` 且 `requirement_id` 存在（即"别的需求的同类档"）。
   - TOLERATE(coord)：`docs/.ccb/worktrees/*.json`（别的需求 state）与 `docs/.ccb/drafts/breakdown/*.json`（别的需求草案）。
   - TOLERATE(evergreen-tracked)：`docs/04_模块规格|05_经验沉淀|06_决策记录/**.md` 且**已被 git 跟踪**（复用 `pathExistsOrTracked`/`ls-files` 思路）且 frontmatter `doc_type` 可识别。
   - FOREIGN：其余一切——源码、未跟踪无绑定常青档、frontmatter 读不出/字段缺失、**文件已删除或 rename 后读不到 frontmatter 且不在 allowlist**（保守拒绝，防吞人工操作）。
   - frontmatter 读取沿用现有 `parseFrontmatter`（只判字段存在性，不解析多行数组）。
3. `canonicalSyncCommit`(:360) 改造：提交前/提交后两次检查都走 classifier；仅 FOREIGN 非空才 escalate，payload `porcelain` 只含 FOREIGN 行、新增 `tolerated_paths`（**去重+排序**）；`git add` 仍只对 OWN；成功/noop result 同样带 `tolerated_paths`；**既有字段（status/reason/porcelain/allowlist）形状不变**，下游不需改读。`tolerated_paths` 形状在本任务定稿，pr2 只消费不重塑。
4. 测试（`lib/worktree/__tests__/worktree.test.mjs`）：
   - 单元：classifier 各类（OWN / bound / coord / evergreen-tracked / FOREIGN）；rename `a -> b` 双路径；带空格/引号路径；删除 allowlist 外文件 → FOREIGN；未跟踪新建常青档 → FOREIGN；源码改动 → FOREIGN。
   - 集成（重演 vlr74b）：主仓同时脏「本需求 td + 多个其它需求档 + 其它需求 state/draft」→ 只提交本需求路径、其余 tolerated、merge 推进；再加任一源码/未跟踪常青脏 → escalate 且 payload 带 tolerated_paths。
   - 回归：既有 canonicalSync 相关用例按新语义适配，其余 merge 用例不变。

### 验收标准

1. 本需求 technical_design 入 allowlist 并被提交；其它需求的 requirement/technical_design/dev_task/state/draft 全部 TOLERATE（不提交、不 escalate）。
2. 源码改动、未跟踪无绑定常青档、读不出 frontmatter 的删除/rename 路径 → 仍 escalate `canonical_dirty_outside_allowlist`，payload 含 FOREIGN 行 porcelain + 去重排序的 tolerated_paths。
3. TOLERATE 路径绝不出现在 `git add`/commit 中。
4. rename/引号/空格路径用例全绿；既有字段形状不变（porcelain/reason/status/allowlist 仍在、含义不变）。
5. plugin 仓 worktree 测试套件全绿；不动 associations.mjs、不加锁（pr2 范围）。

### 边界 / 不做项

- 不实现仓库锁（pr2）；不改 submodule association 隔离；不改 breakdown/dev_task schema；不动 Console。
- TOLERATE 边界以技术设计三、四章为准，不得擅自放宽（尤其不得容忍未跟踪常青档）。

> 来源：技术设计 td-mgsync（四、核心流程／八、变更清单）+ Codex 协商 job_121967901242（三态边界）／job_44bfe8f2a115（G7 验收增补、删除/rename 保守判定）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-10 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cm6241561f52fc0d749mgsync
- Section: pr1-merge-gate-classifier
- Owner: ccb_codex
- Priority: high
- Dependencies: none

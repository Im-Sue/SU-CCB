---
doc_type: dev_task
task_id: subtask-e2777258a4e1
title: B 交互：merged 预览暂停 + 手动归档命令 + reopen
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpworktreearchive260604
section_id: pr2-merged-preview-manual-archive
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-cef1146edf96]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpworktreearchive260604.json
source_draft_hash: 0d9d990c7e64a4f3fbee2476deb0e7adac5d696afba2fc3dd0557b74752a53ba
created_at: 2026-06-06T08:12:35.133Z
updated_at: 2026-06-06T09:05:26.438Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpworktreearchive260604","branch":"ccb/req-cmpworktreearchive260604"}
---

# B 交互：merged 预览暂停 + 手动归档命令 + reopen

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | su-batch 尾改 merge-only(进 merged 停) + 手动归档(cleanup+finalize) + reopen 命令(复用实施分支返工) + node manifests/skill 文案同步。仅插暂停+加入口，不返工 PR1 地基。 |
| 需求来源 | cmpworktreearchive260604 |
| 本期范围 | pr2-merged-preview-manual-archive · B 交互：merged 预览暂停 + 手动归档命令 + reopen |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
在 PR1 全 split 地基上插入「合并后预览暂停」并加用户入口，实现需求 B：su-batch 尾改 merge-only（进 `merged` 停）、手动归档命令（cleanup+finalize）、reopen 命令（复用实施分支返工）。依据技术设计 §4.3/§4.4/§4.5、§三决策5，及用户拍板（复用实施分支 + 显式 reopen）。

#### 任务分解
1. **`su-batch` 尾部改 merge-only**：从 PR1 的 `merge→cleanup→finalize` 背靠背改为**只 merge**（进 `merged`，requirement 保持 `delivering`），不 cleanup、不 finalize。
2. **手动归档命令（`su-archive` 需求级模式）**：requirement `delivering+merged` → `cleanupRequirementWorktree`（成功）→ `requirement.finalize`（delivered，用 PR1 的 `dev_task_requirement_terminal` evidence + `requirement_finalize_expected_hash`）。**支持 `archived` + 仍 `delivering` 的 finalize-only recovery 重入**（cleanup 成功但 finalize CAS 失败不卡死）。
3. **reopen 命令 / skill 入口**：`merged→ready`（接 PR1 `reopenRequirementWorktree`），返工后再走 su-batch / merge。
4. **node manifests + skill 文案**：`archive.node.md` / `batch.node.md` 同步（归档上提需求级、finalize 移手动、merged/reopen 语义）；`su-archive` / `su-quick-archive` SKILL 调用点改（禁子任务级 worktree 收尾、需求级手动归档入口）。
5. lib 只补命令入口需要的薄封装，**不重构 PR1 核心**。

#### 验收标准
- [ ] autonomous-batch 全需求 done → 进 `merged`、requirement 仍 `delivering`、worktree+分支**保留可预览**。
- [ ] 手动归档命令 → cleanup+finalize → requirement `delivered`、worktree+分支删除。
- [ ] cleanup 成功但 finalize 失败 → 重入 finalize-only 不卡死。
- [ ] reopen → 在实施分支追加 commit → 再 merge 幂等（祖先 no-op / 真合并两路）。
- [ ] manifest/skill 文案与新行为一致；相关测试绿。

#### 边界 / 不做
- **不做** Console UI「归档」按钮 + `RequirementDetailPage.tsx:250`「仅 delivered 可归档」文案改（follow-up；仅在 manifest 记「勿作唯一真相」提示）。
- 不重构 PR1 lib 核心（只加入口）。不碰 rollup（PR3）、ADR/副本（PR4）。

#### 依赖 / 执行注意
- 依赖 **PR1**（`merge`/`cleanup`/`reopen` 函数 + `dev_task_requirement_terminal` evidence）。
- 与 PR1 共改 `su-batch` SKILL + `archive.node.md`（串行，本 PR 在 PR1 之后；非并发冲突）。
- plugin submodule worktree 流程；分发副本 sync 留 PR4。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-cef1146edf96
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
- Section: pr2-merged-preview-manual-archive
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-cef1146edf96

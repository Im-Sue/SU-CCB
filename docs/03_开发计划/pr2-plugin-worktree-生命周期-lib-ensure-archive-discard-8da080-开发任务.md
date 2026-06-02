---
doc_type: dev_task
task_id: subtask-c3e3278da080
title: PR2：plugin worktree 生命周期 lib（ensure/archive/discard）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpimplworktree20260526
section_id: pr2-worktree-lifecycle-lib
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpimplworktree20260526.json
source_draft_hash: 6245378503ccbf894e02ae637921f99189cd0d8a285ca19cb3a0d80b2ed5497b
created_at: 2026-06-01T15:13:32.005Z
updated_at: 2026-06-01T15:49:14.023Z
updated_by: slot1_claude
---

# PR2：plugin worktree 生命周期 lib（ensure/archive/discard）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新 lib/worktree 三 helper + canonical-root lock 串行；ensure 时写运行态 target_branch/base_sha；archive 降级；discard force。 |
| 需求来源 | cmpimplworktree20260526 |
| 本期范围 | pr2-worktree-lifecycle-lib · PR2：plugin worktree 生命周期 lib（ensure/archive/discard） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
新增 plugin worktree 生命周期 lib：`ensureRequirementWorktree` / `archiveRequirementWorktree` / `discardRequirementWorktree`，canonical-root lock 串行同 req，保守幂等。

### 范围
- `[NEW] su-ccb-claude-plugin/lib/worktree/index.mjs`：
  - `ensure`：`git worktree prune` → `list --porcelain` 判 path/branch 绑定 → path 存在但非预期 worktree → fail → branch 已在他处 checkout 不盲 `--force` → 首次 `add`；**建成写运行态 `{confirmed_target_branch=当前分支, base_sha=HEAD}` 入 `docs/.ccb`（经 plugin lib）**。
  - `archive`：preflight（worktree+主仓 clean、target_branch 存在校验、divergence 报告）→ 在记录的 target_branch `merge` → `worktree remove` → `branch -d`；冲突 → `merge --abort` 保留现场 + 升级。
  - `discard`：`worktree remove --force` + `branch -D`，不 merge。
  - 复用 `lib/runtime` 的 file-lock（canonical-root lock）+ EventJournal 审计。

### 验收
- ensure 幂等（重复调 no-op）；path 冲突 fail；branch 他处 checkout 不盲 force；建成运行态含 confirmed_target_branch+base_sha。
- archive 在记录的 target_branch（非硬编码 main）merge；target 缺失→保留+升级；divergence→报告；冲突→abort 保留。
- discard 不 merge、强删 worktree+分支。
- 同 req 并发经 lock 串行（测试模拟）。

### 验证
```bash
pnpm --filter su-ccb-claude-plugin test -- worktree
pnpm --filter su-ccb-claude-plugin test
```

### 边界
- 只新增 lib；不接节点 manifest（PR3）；不碰 codex skill；canonical 写只经 lib、绝不进 worktree。

### 依赖
无（独立开发；被 PR3 调用）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-01 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpimplworktree20260526
- Section: pr2-worktree-lifecycle-lib
- Owner: ccb_codex
- Priority: high
- Dependencies: none

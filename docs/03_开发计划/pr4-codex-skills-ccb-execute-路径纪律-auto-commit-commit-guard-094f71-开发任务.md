---
doc_type: dev_task
task_id: subtask-95e27b094f71
title: PR4：codex-skills ccb-execute 路径纪律 + auto-commit + commit-guard
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpimplworktree20260526
section_id: pr4-ccb-execute-discipline
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-dc853486109b]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpimplworktree20260526.json
source_draft_hash: 6245378503ccbf894e02ae637921f99189cd0d8a285ca19cb3a0d80b2ed5497b
created_at: 2026-06-01T15:13:32.005Z
updated_at: 2026-06-01T16:22:18.901Z
updated_by: slot1_claude
---

# PR4：codex-skills ccb-execute 路径纪律 + auto-commit + commit-guard

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | ccb-execute 读字段 fail-fast + cwd=codeRoot 改码 + 子任务级 auto-commit(verified/unverified) + commit-guard 三态拒 docs/.ccb。 |
| 需求来源 | cmpimplworktree20260526 |
| 本期范围 | pr4-ccb-execute-discipline · PR4：codex-skills ccb-execute 路径纪律 + auto-commit + commit-guard |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
`ccb-execute`（su-ccb-codex-skills）落路径纪律 + 子任务级 auto-commit + commit-guard，只消费 plugin 已建好的 worktree。

### 范围
- `[MODIFY] su-ccb-codex-skills/.../ccb-execute`：
  - 读子任务 spec 的 `code_workspace` → **fail-fast**：字段缺失 / path 不存在 / branch 不匹配 → 拒绝实施并回执（**不自建 worktree**）。
  - `codeRoot = resolve(canonicalRoot, code_workspace.path)`；**所有代码命令 `cwd=codeRoot`、git 用 `git -C codeRoot`**；`docs/.ccb` 读写一律 canonicalRoot 绝对路径。
  - auto-commit：跑子任务 `## 验证` fenced 块命令，全 exit 0 → commit 标 `verified`（回执带命令+结果+sha）；无验证块 → commit 标 `unverified`。
  - commit-guard：拒任何 `docs/.ccb` 改动进 worktree 分支（查 **staged/unstaged/untracked 三态**）。

### 验收
- fail-fast：字段缺失/path 不存在/branch 不符均拒并回执，不自建。
- 代码命令在 codeRoot 执行（cwd/`-C`）；canonical 写在主仓。
- 验证块全绿才 verified；无块标 unverified；回执含 sha。
- commit-guard 三态都拒 `docs/.ccb`。

### 验证
```bash
## 在 su-ccb-codex-skills 仓内
npm test
```

### 边界
- 只动 ccb-execute；不建/删 worktree（plugin PR3 负责）；不写 canonical 业务真相。

### 依赖
pr1-code-workspace-field（开发期：读字段约定）；运行期需 pr2/pr3 的 ensure 已建好 worktree（非开发期阻塞）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-dc853486109b
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
- Section: pr4-ccb-execute-discipline
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-dc853486109b

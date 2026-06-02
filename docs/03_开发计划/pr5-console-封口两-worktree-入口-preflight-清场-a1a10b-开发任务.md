---
doc_type: dev_task
task_id: subtask-422a55a1a10b
title: PR5：Console 封口两 worktree 入口 + preflight 清场
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpimplworktree20260526
section_id: pr5-console-seal-preflight
order: 5
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpimplworktree20260526.json
source_draft_hash: 6245378503ccbf894e02ae637921f99189cd0d8a285ca19cb3a0d80b2ed5497b
created_at: 2026-06-01T15:13:32.005Z
updated_at: 2026-06-01T16:55:28.269Z
updated_by: slot1_claude
---

# PR5：Console 封口两 worktree 入口 + preflight 清场

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 封 task-run(apply.routes)+workspace(routes/Web 按钮) 两 worktree 入口恢复不变量#4；preflight prune 3 stale + 移除 3 已验证 clean+merged 的 .workspaces。 |
| 需求来源 | cmpimplworktree20260526 |
| 本期范围 | pr5-console-seal-preflight · PR5：Console 封口两 worktree 入口 + preflight 清场 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
封口 Console 两个仍 LIVE 的 worktree 入口（恢复 ADR-0036 不变量#4「Console 只投影、不建删」），并清场已验证安全的废弃 worktree。

### 范围
- `[MODIFY] apps/ccb-console/server/src/modules/kernel/apply.routes.ts`：封 `createWorktree`/`cleanupWorktree` 调用路径（feature-flag off / route disable）。
- `[MODIFY] apps/ccb-console/server/src/modules/workspace/workspace.routes.ts` + Web `WorkspaceDrawer.tsx`/`WorkspaceCard.tsx`（`console-api.ts` L745/L797）：隐藏/禁用「创建/清理工作区」入口。
- `[CLEANUP] preflight`（一次性）：`git worktree prune`（清 3 个 dir-missing stale）+ 移除 3 个已验证 clean+merged 的 `.workspaces` worktree（`2026-05-02-*`/`2026-05-08-*`/`task-待处理...0258c9`）。

### 验收
- Web 不再暴露建/清 worktree 入口；apply.routes/workspace.routes 的 worktree 建删路径关闭或拒绝。
- `git worktree list` 干净（无 prunable stale、无废弃 .workspaces）。
- 不删表、不 migration；死代码本体保留（follow-up 删）。

### 验证
```bash
pnpm --filter ccb-console-server typecheck
pnpm --filter ccb-console-server test
pnpm --filter ccb-console-web test
git worktree list --porcelain
```

### 边界
- 只封入口不删死代码本体（完整删码/schema 清理留 follow-up）；preflight 只清已验证 clean+merged 项，绝不删有未合并工作的 worktree。

### 依赖
无（独立，可与 PR1/PR2 并行）。

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
- Section: pr5-console-seal-preflight
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

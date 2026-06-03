---
doc_type: module_spec
title: "Task phase deprecation 归档记录"
status: archived
updated: 2026-06-03
---

# Task phase deprecation 归档记录

## 1. 归档原因

本文是旧阶段字段退役的点状迁移记录，已经不再作为 SU-Oriel 活模块规格维护。当前活结论已并入 `docs/04_模块规格/su-oriel-taskrun状态机模块规格.md`。

## 2. 已并入活规格的结论

- 任务业务节点真相是 `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId`。
- 旧阶段列已退役，不再作为 Prisma `Task` 持久化字段。
- 任务列表和详情仍可能返回 `phase` 展示兼容字段，但它由 `currentNode` 派生。
- 任务更新接口拒绝旧阶段字段写入。
- TaskRun 只表达一次执行尝试状态，不替代任务业务节点状态。

## 3. 当前实现锚点

- `su-oriel/server/prisma/schema.prisma`
- `su-oriel/server/src/modules/task/task.routes.ts`
- `su-oriel/server/src/modules/task/phase-derive.ts`
- `su-oriel/server/src/modules/task-run/task-run.state-machine.ts`
- `su-oriel/server/src/modules/task-run/task-run.routes.ts`

## 4. 清理说明

原文包含旧目录、旧迁移命令、旧兼容 timeline 和旧运行 checklist。multi-repo 与 SU-Oriel 重构后，这些内容容易误导执行者，因此本归档只保留当前可核对结论，不再提供操作步骤。

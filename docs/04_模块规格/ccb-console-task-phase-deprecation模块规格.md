---
doc_type: module_spec
title: "Task.phase Deprecation + Migration"
updated: 2026-05-28
---
# Task.phase Deprecation + Migration

## 1. 背景

| 项 | 内容 |
|---|---|
| 任务 | E7-T4 task phase deprecation + migration 文档 |
| gap | KA-6 phase 列删除 |
| 范围 | Console server / Prisma / 旧客户端兼容 |
| 状态 | 兼容期文档 |

v0.4 北极星要求任务运行状态以 node kernel 字段为真相源。
`Task.phase` 是 Console V1 看板时期的历史字段，语义和 `currentNode`、
`nodeSubstate`、`runtimeState` 重叠，容易造成状态分叉。

E7 已完成三步：

- E7-T1 删除 Prisma `Task.phase` 字段并生成 SQLite rebuild migration。
- E7-T2 在 API GET 路径上用 `mapNodeToPhase(currentNode)` 临时派生 `phase`。
- E7-T3 在 PATCH 路径拒绝 `phase` 写入，提示旧客户端改用 `currentNode`。

本文件锁定兼容期 timeline，并给出迁移、验证和回滚口径。

## 2. 兼容期 Timeline

| 阶段 | 行为 | 旧客户端影响 |
|---|---|---|
| Wave 2 当前 | DB 不再保存 `Task.phase`；GET 仍返回派生 `phase` | 只读客户端继续可用 |
| Wave 2 当前 | PATCH `phase` 返回 400 | 写入 `phase` 的客户端必须升级 |
| Wave 3 期间 | Console UI 继续迁移到 node 状态机视图 | 看板分组逐步从 `phase` 转向 node projection |
| Wave 3 末 | 移除 API GET derive `phase` 兼容层 | 客户端不应再依赖响应中的 `phase` |

兼容期截止点锁定为 **Wave 3 末**。
不得把 `phase` derive 兼容层无限延期；若 Wave 3 末仍有外部依赖，需要新 spec 明确重新评审。

## 3. 数据模型迁移

### 3.1 Dry-run

迁移前先跑 dry-run，验证删除 `phase` 不改变任务行数、任务 id 集合和关键字段：

```bash
node apps/ccb-console/server/scripts/migrate-task-phase-dry-run.cjs
```

期望输出：

- before / after task count 一致。
- task id 集合一致。
- `status`、`currentNode`、`nodeSubstate`、`runtimeState` 等字段保留。
- dry-run 报告不出现 integrity mismatch。

### 3.2 实际 migrate

在 server 包执行 Prisma migrate deploy：

```bash
cd apps/ccb-console/server
pnpm prisma migrate deploy
```

SQLite 下删除列会表现为 rebuild table：

- 创建新 Task table。
- 从旧表复制非 phase 字段。
- 删除旧表。
- 重命名新表。

迁移 SQL 不应包含对 `Task.phase` 的再次写入或兼容列重建。

### 3.3 数据完整性验证

迁移后执行：

```bash
cd apps/ccb-console/server
pnpm run prisma:generate
pnpm test project-routes phase-derive
```

再执行全仓验证：

```bash
pnpm -r build
pnpm -r test
python3 references/kernel/tools/lint_all.py --legacy-baseline
```

通过标准：

- server build 不再引用 Prisma `Task.phase`。
- GET `/api/tasks` 和 GET `/api/tasks/:id` 仍返回派生 `phase`。
- PATCH `/api/tasks/:id` 含 `phase` 返回 400。
- legacy baseline `ALL_GREEN: yes`。

### 3.4 Rollback

推荐 rollback 路径是代码回滚优先、数据库恢复谨慎处理：

```bash
git revert <E7-T1-commit>
git revert <E7-T2-commit>
git revert <E7-T3-commit>
```

如果生产库已经执行 migration，需要先从迁移前备份恢复 SQLite 文件，再回滚代码。
不要在已删除列的库上手写 `ALTER TABLE Task ADD COLUMN phase` 作为常规回滚方案；
这会恢复字段形态，但不能恢复旧值语义。

## 4. mapNodeToPhase 兼容映射

兼容期 GET 响应使用 `mapNodeToPhase(currentNode)` 派生 `phase`。

| currentNode | 派生 phase | 说明 |
|---|---|---|
| `requirement_analysis` | `需求` | 需求分析阶段 |
| `technical_design` | `设计` | 技术设计阶段 |
| `task_breakdown` | `拆分` | 任务拆分阶段 |
| `dispatch` | `派工` | 分派与等待执行阶段 |
| `implementation` | `实施` | Codex / worker 执行阶段 |
| `review` | `审查` | Review 与 replan 判断阶段 |
| `archive` | `归档` | 已归档终态 |

未知或空 `currentNode` 当前回退为 `设计`，仅用于兼容旧数据。
新数据必须通过 node kernel 字段表达状态，不应新增 phase 语义。

## 5. PATCH 客户端升级

旧客户端请求示例：

```json
{
  "phase": "blocked",
  "status": "blocked"
}
```

当前响应：

```json
{
  "error": "phase field is deprecated, use currentNode"
}
```

升级规则：

- 不再 PATCH `phase`。
- 用户可编辑字段仅保留 `status`、`priority`、`progress`、`blockedReason`。
- 节点推进必须走后续受控 transition / apply 入口，不通过 task PATCH 伪造。
- 只读展示优先读取 `currentNode`；在 Wave 3 末前可临时读取派生 `phase`。

例如：

```json
{
  "status": "blocked",
  "blockedReason": "等待外部 review"
}
```

## 6. 与 E12 / Wave 3 的关系

E7 不实施 web 看板分组改造。
Wave 3 和 E12 负责把 Console 主要视图从 `phase` 看板心智迁移到 node 状态机和 projection。

Wave 3 末必须完成：

- UI 不再依赖 API 响应中的 `phase`。
- 外部文档不再建议 PATCH `phase`。
- API GET derive `phase` 兼容层具备删除条件。
- 删除前至少跑一次全仓搜索，确认产品代码无 `task.phase` 读取。

## 7. 操作 Checklist

迁移前：

- 跑 dry-run。
- 确认数据库备份存在。
- 确认部署版本包含 E7-T2 和 E7-T3。

迁移中：

- 执行 `pnpm prisma migrate deploy`。
- 记录 migration hash 和部署时间。
- 观察 server 启动日志。

迁移后：

- 跑 `pnpm -r build`。
- 跑 `pnpm -r test`。
- 跑 `lint_all.py --legacy-baseline`。
- 抽样调用 GET `/api/tasks` 与 PATCH `/api/tasks/:id`。

Wave 3 末：

- 删除 GET derive `phase` 响应字段。
- 更新公开文档和 quickstart。
- 将本文件标记为历史迁移记录。

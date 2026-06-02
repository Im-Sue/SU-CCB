---
doc_type: architecture
title: "CCB Console 数据模型与索引链路文档"
updated: 2026-05-28
---
# CCB Console 数据模型与索引链路文档

## 1. 数据建模原则

| 原则 | 说明 |
|---|---|
| 文件是真源 | 文档内容以项目内文件为准 |
| 数据库是索引层 | 保存路径、状态、派生结果、运行记录 |
| 可重建 | 文档索引和任务视图应可由扫描重新构建 |
| 多人字段预留 | 当前按单人实现，后续保留多人扩展空间 |

## 2. 核心实体

### 2.1 Project

| 字段 | 类型建议 | 说明 |
|---|---|---|
| `project_id` | string | 稳定项目 ID |
| `name` | string | 项目名称 |
| `local_path` | string | 本地路径 |
| `summary` | text | 简介 |
| `init_status` | enum | `not_initialized / initialized / error` |
| `docs_root` | string | 文档根目录 |
| `last_scan_at` | datetime | 最近扫描时间 |
| `sync_status` | enum | `idle / running / failed / partial` |
| `owner_user_id` | string nullable | 预留 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 2.2 Document

| 字段 | 类型建议 | 说明 |
|---|---|---|
| `document_id` | string | 稳定文档 ID |
| `project_id` | string | 所属项目 |
| `path` | string | 文档路径 |
| `kind` | enum | `spec / plan / task / index / decision / other` |
| `title` | string | 标题 |
| `status` | string nullable | 文档中的状态 |
| `frontmatter_json` | json | frontmatter 原始结构 |
| `summary` | text nullable | 派生摘要 |
| `content_hash` | string | 内容哈希 |
| `mtime` | datetime | 文件修改时间 |
| `parse_status` | enum | `pending / success / failed / partial` |
| `parse_error` | text nullable | 解析错误 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 2.3 Task

| 字段 | 类型建议 | 说明 |
|---|---|---|
| `task_id` | string | 稳定任务 ID |
| `project_id` | string | 所属项目 |
| `title` | string | 任务标题 |
| `summary` | text | 摘要 |
| `status` | enum | `draft / active / blocked / done / archived` |
| `phase` | enum | `requirement / planning / ready / implementing / reviewing / blocked / done / archived` |
| `priority` | enum | `low / medium / high / urgent` |
| `progress` | integer | 0-100 |
| `primary_document_id` | string nullable | 主文档 |
| `linked_spec_id` | string nullable | 关联 spec |
| `linked_plan_id` | string nullable | 关联 plan |
| `linked_task_doc_id` | string nullable | 关联 task 文档 |
| `owner_user_id` | string nullable | 预留 |
| `assignee_user_id` | string nullable | 预留 |
| `reviewer_user_id` | string nullable | 预留 |
| `blocked_reason` | text nullable | 阻塞原因 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 2.4 Requirement

| 字段 | 类型建议 | 说明 |
|---|---|---|
| `requirement_id` | string | 需求 ID |
| `project_id` | string | 所属项目 |
| `title` | string | 标题 |
| `description` | text | 需求描述 |
| `status` | enum | `draft / clarified / converted / archived` |
| `source` | enum | `manual / imported / generated` |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 2.5 SyncJob

| 字段 | 类型建议 | 说明 |
|---|---|---|
| `job_id` | string | 作业 ID |
| `project_id` | string | 所属项目 |
| `job_type` | enum | `init / scan / parse / reconcile` |
| `status` | enum | `pending / running / success / failed / partial` |
| `started_at` | datetime | 开始时间 |
| `finished_at` | datetime nullable | 结束时间 |
| `log_summary` | text nullable | 摘要 |
| `error_message` | text nullable | 错误摘要 |

### 2.6 预留实体

| 实体 | 用途 | V1 状态 |
|---|---|---|
| `CommandRun` | 将来记录 `/ccb:su-*` 执行记录 | 预留 |
| `WorkflowRun` | 将来记录自动化流程运行 | 预留 |
| `NodeRun` | 将来记录节点级执行细节 | 预留 |

## 3. 任务归并模型

| 规则优先级 | 规则 |
|---|---|
| 1 | 文档中存在显式 `task_id` 时直接归并 |
| 2 | 文档中存在稳定引用字段时按引用归并 |
| 3 | 按标题、文件名、目录规则做启发式匹配 |
| 4 | 无法确定时生成待归并任务并允许人工绑定 |

## 4. 索引链路

### 4.1 全量链路

```text
项目重扫
  -> 扫描文件
  -> 识别文档类型
  -> 解析 frontmatter 与正文摘要
  -> 写入 Document 索引
  -> 归并 Task
  -> 更新项目统计
  -> 写入 SyncJob 结果
```

### 4.2 增量链路

```text
文件变更
  -> watcher 捕获路径
  -> 重新解析单个文档
  -> 更新 Document
  -> 局部重算相关 Task
  -> 更新项目统计
```

## 5. 解析产物

| 文档类型 | 最低解析项 |
|---|---|
| `spec` | 标题、状态、摘要、关联任务标识 |
| `plan` | 标题、状态、阶段、任务拆分线索 |
| `task` | 标题、状态、优先级、负责人、进度线索 |

## 6. 一致性策略

| 问题 | 策略 |
|---|---|
| 文档被手动修改 | 以文件内容为准，重扫后刷新索引 |
| UI 中只改结构化字段 | V1 优先改索引层，不直接覆盖正文 |
| 索引与文件不一致 | 通过手动重扫或自动监听修复 |
| 归并失败 | 标记为待处理，不静默丢弃 |

## 7. 表关系建议

| 关系 | 说明 |
|---|---|
| Project 1:N Document | 一个项目有多个文档 |
| Project 1:N Task | 一个项目有多个任务 |
| Project 1:N Requirement | 一个项目有多个需求 |
| Project 1:N SyncJob | 一个项目有多个同步作业 |
| Task 1:1 Document(spec) | 可选 |
| Task 1:1 Document(plan) | 可选 |
| Task 1:1 Document(task) | 可选 |

## 8. 查询视图建议

| 视图 | 用途 |
|---|---|
| `project_overview_view` | 项目概览页统计 |
| `task_board_view` | 看板页任务列表 |
| `document_reader_view` | 文档中心列表 |
| `sync_job_recent_view` | 最近运行记录 |

## 9. 风险与待补点

| 项 | 说明 |
|---|---|
| task_id 规范 | 后续建议在文档规范里加入稳定关联键 |
| progress 规则 | V1 可先手工维护，后续再自动推导 |
| 前端编辑边界 | V1 不做复杂正文编辑，避免双写冲突 |


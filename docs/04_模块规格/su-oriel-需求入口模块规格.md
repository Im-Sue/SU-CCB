---
doc_type: module_spec
title: "SU-Oriel 需求入口模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 需求入口模块规格

## 1. 模块目标

需求入口模块负责项目需求的列表/看板入口、md-first 创建、状态刷新和进入详情页。它把新需求登记为项目内 requirement Markdown，并把列表投影展示给用户；需求详情工作台能力已拆到 [SU-Oriel 需求详情页模块规格](./su-oriel-需求详情页模块规格.md)。

真实实现锚点：

- `su-oriel/server/src/modules/requirement/requirement.routes.ts`
- `su-oriel/server/src/modules/requirement/requirement.schemas.ts`
- `su-oriel/server/src/indexer/project-indexer.ts`
- `su-oriel/server/src/modules/task/task.routes.ts`
- `su-oriel/web/src/pages/requirements/RequirementsPage.tsx`
- `su-oriel/web/src/lib/requirement-board-config.ts`
- `su-oriel/web/src/components/task-board/UnstartedRequirementStrip.tsx`
- `su-oriel/web/src/stores/project-store.ts`
- `su-oriel/web/src/stores/ui-store.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 需求列表 | `GET /api/projects/:projectId/requirements` 返回项目需求投影，前端按创建时间倒序展示。 |
| 看板分组 | `createRequirementBoardProjection` 按需求状态分为 `pending`、`inProgress`、`delivered`、`archived`。 |
| 新建需求 | `POST /api/projects/:projectId/requirements` 走 md-first 创建，写 requirement Markdown 后同步 Prisma 投影。 |
| 创建期资产搬运 | 新建需求可携带 `asset_tmp_uuid`，服务端把临时资产引用改写到正式 requirement id。 |
| 全量状态刷新 | `POST /api/projects/:projectId/refresh-requirement-status` 按任务真实状态重算项目需求状态。 |
| 单条状态刷新 | `POST /api/requirements/:requirementId/refresh-status` 重算单个需求状态。 |
| 进入详情 | 点击 `RequirementsPage` 卡片或 `UnstartedRequirementStrip` 条目跳转 `/requirements/:requirementId`。 |
| 旧立项流程 | `RequirementView.outputMode` 固定为 `requirement_only`，旧“生成任务”流程不属于入口模块。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `RequirementsPage` | 需求四列看板、空状态新建入口、全量/单条状态刷新、点击卡片进入详情。 |
| `Card` + `Badge` | 需求卡片在 `RequirementsPage` 内直接渲染；当前没有独立需求列表项组件。 |
| `UnstartedRequirementStrip` | 任务看板中的计划中需求提示条，提供继续进入详情页的入口。 |
| `project-store` | 维护 `requirements`、`selectedProjectId`，创建需求后刷新项目数据。 |
| `ui-store` | 打开创建需求 modal，并展示刷新结果 toast。 |

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `Requirement` | `title`、`description`、`status`、`source`、`verbatimSource`、`claudeInterpretation`、`analysisInputHash`、`planDocPath`、`breakdownDraftPath`、`rollupProgress` | 入口页消费的需求投影；核心内容由 requirement Markdown 同步。 |
| `Task` | `requirementId` | 状态刷新按需求下任务投影回算。 |
| machine layer | `docs/.ccb/assets/requirements/` | 新建需求时可从临时资产目录归档到正式需求资产目录。 |

## 5. 接口边界

需求入口只负责“创建和进入”。它不承载需求编辑、Markdown 阅读、重新分析、局部重索引、slot 终端、artifact drawer、拆分草案审查或子任务批量派工；这些属于 [需求详情页](./su-oriel-需求详情页模块规格.md)。

创建需求会写项目内 requirement Markdown，但不会直接生成技术设计、拆分草案或 dev_task。后续分析、设计、拆分和派工由详情页触发 CCB plugin/anchor 生命周期完成。

## 6. 旧规格 vs 实际偏差

旧规格以“生成骨架预览、生成 spec、生成 plan/task”为中心。真实 v1.0 是 requirement md-first：入口只创建需求文档与投影，旧立项流程已退役，后续工作从详情页触发。

旧规格曾把编辑、资产、reanalyze、reindex 和拆分草案混入入口模块；这些已经拆分到需求详情页规格，避免入口页职责过重。

## 7. v1.0 校正点

- 入口页是列表/看板和创建入口，不是详情工作台。
- `RequirementsPage` 直接渲染需求卡片，没有独立列表项组件。
- 状态刷新接口在任务路由中实现，但入口页是主要消费方。
- 新建需求仍以项目文档为真相源，Prisma 是投影。

## 8. 待定事项

- reanalyze 与 slot/anchor 的用户可见错误恢复策略属于需求详情页模块。

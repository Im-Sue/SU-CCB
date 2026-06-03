---
doc_type: module_spec
title: "SU-Oriel 需求入口模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 需求入口模块规格

## 1. 模块目标

需求入口模块把用户录入的需求沉淀为项目内 requirement Markdown，并把需求分析、编辑、资产、重索引与拆分草案作为可观测触发器暴露给 UI。需求正文和状态真相源在项目文档中，SU-Oriel 维护的是投影、审计和触发记录。

真实实现锚点：

- `su-oriel/server/src/modules/requirement/requirement.routes.ts`
- `su-oriel/server/src/modules/requirement/requirement.schemas.ts`
- `su-oriel/server/src/modules/requirement/requirement-edit.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-assets.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-reanalyze.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-reindex.service.ts`
- `su-oriel/server/src/modules/breakdown-draft/breakdown-draft.routes.ts`
- `su-oriel/server/src/indexer/project-indexer.ts`
- `su-oriel/web/src/pages/requirements/RequirementsPage.tsx`
- `su-oriel/web/src/pages/requirements/RequirementDetailPage.tsx`
- `su-oriel/web/src/components/requirements/RequirementMarkdownEditor.tsx`
- `su-oriel/web/src/components/breakdown-review/BreakdownReviewEmbedded.tsx`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 需求列表 | `GET /api/projects/:projectId/requirements` 返回项目需求投影。 |
| 需求详情 | `GET /api/projects/:projectId/requirements/:requirementId` 返回需求字段与当前 md hash。 |
| 新增需求 | `POST /api/projects/:projectId/requirements` 走 md-first 创建，写 requirement Markdown 后同步 Prisma 投影。 |
| 编辑需求 | `PATCH /api/projects/:projectId/requirements/:requirementId` 使用 `expectedMdHash` 做 CAS，写回 Markdown 并创建 `RequirementEditAudit`。 |
| 图片资产 | 上传与读取需求图片，文件落在项目 `docs/.ccb/assets/requirements/` 下，限制图片类型与 5MB 大小。 |
| 重新分析 | `POST /reanalyze` 通过 anchor/ccbd 触发需求分析 job，并提供 job status 查询。 |
| 局部重索引 | `POST /reindex` 重新同步单个需求相关投影。 |
| 拆分草案读取 | `GET /api/requirements/:requirementId/breakdown-draft` 读取 machine layer 中的拆分草案。 |
| 旧生成任务入口 | `POST /generate-task` 当前返回 410，提示改用需求详情页的分析、设计、拆分草案流程。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `RequirementsPage` | 需求列表/看板入口，支持刷新需求状态和进入详情。 |
| `RequirementDetailPage` | 需求详情工作台，承载编辑、Markdown 阅读、生命周期触发、分析/重索引、资产上传、slot terminal、artifact drawer 和批量派工入口。 |
| `RequirementMarkdownEditor` | 需求 Markdown 编辑器，基于 md hash 做冲突保护。 |
| `BreakdownReviewEmbedded` | 展示拆分草案，支撑子任务列表、计划概览和拒绝反馈。 |
| `project-store` / `detail-store` | 缓存需求列表、详情和相关加载状态。 |

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `Requirement` | `title`、`description`、`status`、`verbatimSource`、`claudeInterpretation`、`analysisInputHash`、`currentPlanningStep`、`planDocPath`、`breakdownDraftPath`、`rollupProgress` | 需求投影；多数核心字段由 requirement Markdown 同步。 |
| `RequirementEditAudit` | `beforeTitle`、`afterTitle`、`beforeMdHash`、`afterMdHash`、`diffJson` | 需求编辑审计记录。 |
| `Task` | `requirementId` | 任务通过 `requirementId` 关联需求。 |
| machine layer | `docs/.ccb/drafts/breakdown/`、`docs/.ccb/assets/requirements/` | 拆分草案和需求资产的项目内存放位置。 |

## 5. 接口边界

需求入口是触发器和投影层。新增/编辑需求会写项目内 requirement Markdown，但不直接生成 spec、plan 或 dev_task；这些后续产物由 plugin 生命周期与索引流水线推进。`outputMode` 在响应中固定为 `requirement_only`，`splitMode` 固定为 `direct_pr`，旧“选择输出策略”已不是当前产品能力。

编辑只允许 `drafting`、`planning`、`delivering`、`deferred` 状态；终态需求需要先通过生命周期流程回到可编辑状态。分析、设计和拆分动作依赖 anchor/ccbd 可用性，失败时返回 409 或 503。

## 6. 旧规格 vs 实际偏差

旧规格以“生成骨架预览、生成 spec、生成 plan/task”为中心。真实 v1.0 是 requirement md-first：创建需求只产生需求文档与投影，旧立项接口已经 410；需求详情页才承载分析、设计、拆分草案和派工触发。

旧规格没有覆盖图片资产、md hash 冲突保护、`RequirementEditAudit`、reanalyze job、局部 reindex 和 breakdown draft，这些都是当前实现中的活能力。

## 7. v1.0 校正点

- 需求创建和编辑以项目文档为真相源，Prisma 是投影和审计。
- `requirement-edit.service.ts` 使用项目级 docs structure resolver，不再假设固定目录布局。
- 模块路径在 `su-oriel/server/src/modules/requirement/`，不存在独立的 `requirement-edit` 模块目录。
- 旧生成任务入口保留为 410 兼容提示，不再作为活流程。

## 8. 待定事项

- 需求详情页承担的触发入口较多，是否需要拆分为“需求编辑”“分析进度”“拆分审查”子规格还未决定。
- reanalyze 与 slot/anchor 的用户可见错误恢复策略仍依赖运行时实现细节。

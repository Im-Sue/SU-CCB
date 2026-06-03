---
doc_type: module_spec
title: "SU-Oriel 需求详情页模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 需求详情页模块规格

## 1. 模块目标

需求详情页模块是单个需求的工作台：读取需求详情和 md hash，展示需求文档与产物索引，提供 Markdown 编辑、重新分析、局部重索引、图片资产、slot 终端、artifact drawer、生命周期指令和子任务批量派工入口。它承接入口页进入后的工作流，入口页边界见 [SU-Oriel 需求入口模块规格](./su-oriel-需求入口模块规格.md)。

真实实现锚点：

- `su-oriel/web/src/pages/requirements/RequirementDetailPage.tsx`
- `su-oriel/web/src/components/requirements/RequirementMarkdownEditor.tsx`
- `su-oriel/web/src/components/shared/MarkdownViewer.tsx`
- `su-oriel/web/src/components/slot-terminal/SlotTerminalPanel.tsx`
- `su-oriel/web/src/components/task-detail-v2/DetailDrawer.tsx`
- `su-oriel/web/src/lib/requirement-asset-url.ts`
- `su-oriel/web/src/lib/console-api.ts`
- `su-oriel/web/src/stores/project-store.ts`
- `su-oriel/web/src/stores/ui-store.ts`
- `su-oriel/server/src/modules/requirement/requirement.routes.ts`
- `su-oriel/server/src/modules/requirement/requirement-edit.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-assets.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-reanalyze.service.ts`
- `su-oriel/server/src/modules/requirement/requirement-reindex.service.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 详情加载 | `fetchRequirementDetail` 拉取需求详情和 `mdHash`；同时拉取任务、可批量派工候选和 slot 投影。 |
| 文档阅读 | `MarkdownViewer` 展示需求摘要、全屏阅读 modal 和 AI/设计 drawer 内容。 |
| 文档编辑 | `RequirementMarkdownEditor` 在 modal 内编辑描述，`patchRequirement` 携带 `expectedMdHash` 做冲突保护。 |
| 图片资产 | 编辑器支持粘贴、拖拽、本地上传图片；上传后把相对资产路径插入 Markdown，阅读时改写为 API URL。 |
| 自动刷新 | 页面定时、focus、visibility 回前台时调用 `reindexRequirement` 并刷新详情。 |
| AI 分析 | 产物卡展示 Claude 解读、歧义点、保真差异，并可通过 `su-flow analysis` 触发重新生成。 |
| 技术设计 | 根据 `planDocPath` 从文档索引读取设计文档，使用 `DetailDrawer` 展示。 |
| 拆分草案 | 根据 `breakdownDraftPath` 提供进入拆分审查页的入口，并可触发 `su-flow breakdown_draft`。 |
| Slot 终端 | `SlotTerminalPanel` 展示需求绑定 slot，可绑定、解绑或强制解绑。 |
| 生命周期指令 | 通过 `dispatchRequirementAnchorCommand` 触发 `su-resume`、`su-defer`、`su-reactivate`、`su-archive`、`su-cancel`。 |
| 子任务批量派工 | 读取 batch candidates，确认后调用 `batchDispatchSubtasks` 派出 `su-batch`。 |
| 旧生成任务入口 | 服务端 `POST .../generate-task` 返回 410，详情页改用分析、设计、拆分草案流程。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `RequirementDetailPage` | 详情页总装：加载数据、维护 modal/drawer/slot/pending dispatch 状态、发起指令。 |
| `RequirementMarkdownEditor` | EasyMDE 编辑器，支持 Markdown 预览、图片上传、拖拽和粘贴。 |
| `MarkdownViewer` | 渲染需求摘要、全屏阅读正文、AI 解析和技术设计。 |
| `SlotTerminalPanel` / `SlotPanelActions` | 展示 slot 终端，并提供绑定/解绑操作入口。 |
| `DetailDrawer` | 作为 AI 解析和技术设计的侧边抽屉容器。 |
| `Modal` | 承载文档阅读/编辑、slot 解绑确认、生命周期危险操作确认、子任务批量派工。 |
| `project-store` / `ui-store` | 获取当前项目、刷新项目数据、展示 toast。 |

## 4. 后端端点

| 端点 | 职责 |
|---|---|
| `GET /api/projects/:projectId/requirements/:requirementId` | 返回需求详情和 `mdHash`；md 文件缺失时 `mdHash` 为 `null`。 |
| `PATCH /api/projects/:projectId/requirements/:requirementId` | 编辑需求标题/描述，使用 `expectedMdHash` 做 CAS，写回 requirement Markdown 并记录 `RequirementEditAudit`。 |
| `POST /api/projects/:projectId/requirements/:requirementId/reanalyze` | 提交重新分析任务，返回 job id、anchor id 和 pending 状态。 |
| `GET /api/projects/:projectId/requirements/:requirementId/reanalyze-jobs/:jobId` | 查询重新分析 job 状态。 |
| `POST /api/projects/:projectId/requirements/:requirementId/reindex` | 局部同步需求相关文档、任务、设计文档和拆分草案投影。 |
| `POST /api/projects/:projectId/requirements/:assetOwner/assets` | 上传需求图片，限制 png/jpeg/webp/gif 和 5MB。 |
| `GET /api/projects/:projectId/requirements/:assetOwner/assets/:filename` | 读取需求图片资产，校验 owner 和 hash 文件名。 |
| `POST /api/projects/:projectId/requirements/:requirementId/generate-task` | 返回 410；旧立项接口已退役。 |

详情页还调用 slot、anchor、event journal、document detail 和 batch dispatch API；这些端点归属其它模块，本规格只记录它们在详情页中的消费关系。

## 5. 数据流

1. 从入口页进入 `/requirements/:requirementId`。
2. 详情页并行拉取 requirement detail、项目任务、批量派工候选和 slot 投影。
3. 页面根据 `Requirement.status`、`analysisStaleAt`、`planDocPath`、`breakdownDraftPath` 和子任务数量计算产物索引状态。
4. 编辑需求时，前端用 `mdHash` 提交 `PATCH`；服务端写 Markdown、同步投影、记录审计；成功后刷新详情和项目数据。
5. 上传图片时，前端把文件发送到 assets API，服务端写到项目 `docs/.ccb/assets/requirements/`，编辑器插入相对路径。
6. 分析/设计/拆分/生命周期指令通过 anchor dispatch 排队；页面轮询 event journal 识别 dispatch 成功或失败。
7. 页面定时调用 `reindexRequirement`，把外部写回的 requirement Markdown、技术设计、拆分草案和子任务重新投影到 UI。

## 6. 接口边界

需求详情页是触发器和投影层，不是业务真相源。编辑操作写项目内 requirement Markdown；分析、设计、拆分和生命周期推进由 CCB plugin/anchor skill 执行并写回项目文档，SU-Oriel 负责提交指令、展示状态和刷新投影。

重新分析服务当前通过 ccbd/anchor 向 `ccb_claude` 提交 `requirement-reanalyze` skill，要求在 anchor 内生成真实 LLM 解析并写回 requirement Markdown。没有可用 anchor、状态不允许或 AI/ccbd 不可达时，服务端返回 409 或 503。

终态需求在页面上禁用编辑或触发按钮；`delivered`、`cancelled` 等状态恢复需要通过独立生命周期指令。`generate-task` 是兼容保留端点，不能作为活流程使用。

## 7. 与需求入口的关系

需求入口负责“看见所有需求、创建新需求、刷新状态、进入详情”。需求详情页负责“处理单个需求”。两者共享 `Requirement` 投影和 `project-store`，但不重复承载对方职责：入口页不编辑、不分析、不管理 slot；详情页不做项目级需求看板分组和新建需求入口。

## 8. 旧规格 vs 实际偏差

旧需求入口规格把详情工作台能力混在入口模块里，导致入口页被描述为编辑、资产、reanalyze、reindex 和拆分草案的承载者。真实代码中这些能力集中在 `RequirementDetailPage.tsx` 与 requirement detail 端点，入口页只负责列表/看板、创建、刷新和跳转。

旧“生成任务”流程也不符合当前实现：服务端 `generate-task` 返回 410，当前工作流是从详情页触发分析、设计、拆分草案，再进入子任务派工。

## 9. 待定事项

- reanalyze 服务代码标注 legacy dispatcher 路径，未来若统一走 SlotBinding/JobSlotRouter，需要更新本规格。
- 详情页承担 slot、artifact、生命周期、批量派工等多种入口，后续是否继续拆成更小模块规格仍可评审。

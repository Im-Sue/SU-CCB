---
doc_type: architecture
title: "SU-Oriel 前端架构"
status: active
updated: 2026-06-02
---

# SU-Oriel 前端架构

## 定位

SU-Oriel 前端是本地 Web 驾驶舱。它不直接读写项目文件，而是通过 Oriel 后端 API 展示项目、文档、任务、节点流转、协商记录、运行事件、终端和设置，并发起受控触发动作。

前端包名为 `su-oriel-web`，位于 `su-oriel/web/`，技术栈是 React 19、Vite 7、React Router 7、Zustand、CSS Modules、Vitest。

## 目录结构

| 路径 | 责任 |
|---|---|
| `su-oriel/web/src/App.tsx` | 全局 layout、路由、项目/需求弹窗、命令面板、页面标题与 header action |
| `su-oriel/web/src/pages/` | 页面级入口：overview、documents、tasks、requirements、runs、settings、AI CLI 等 |
| `su-oriel/web/src/components/` | UI primitives 与领域组件 |
| `su-oriel/web/src/lib/` | API client、projection hook、格式化与 UI 映射 |
| `su-oriel/web/src/stores/` | Zustand store；当前主要是 project-store 与 ui-store |
| `su-oriel/web/src/types/` | API view types |
| `su-oriel/web/src/styles/` | reset、tokens、动画 |
| `su-oriel/web/src/tests/` | 单元、组件与 acceptance snapshot 测试 |

## 路由与页面

`App.tsx` 当前注册的主要路由：

| 路由 | 页面 |
|---|---|
| `/overview` | `OverviewPage` |
| `/documents`、`/documents/:documentId` | `DocumentsPage` |
| `/my-work` | `MyWorkPage` |
| `/tasks`、`/tasks/:taskId` | `TasksPage` |
| `/requirements`、`/requirements/:requirementId` | `RequirementsPage` / `RequirementDetailPage` |
| `/requirements/:requirementId/breakdown-review` | `BreakdownReviewPage` |
| `/sprints`、`/sprints/:sprintId` | `SprintsPage` |
| `/runs` | `RunsPage` |
| `/reconcile` | `ReconcileReportsPage` |
| `/settings` | `SettingsPage` |
| `/anchors` | `SlotsPage` |
| `/ai-cli`、`/ai-cli/recordings/:recordingId` | `AiCliPage` / `RecordingPlayPage` |

根路径重定向到 `/overview`。

## 状态与数据流

| 层 | 当前实现 |
|---|---|
| API client | `lib/console-api.ts` 统一 `fetch`、base URL、错误解析和资源方法 |
| 项目状态 | `stores/project-store.ts` 保存 projects、selectedProjectId、documents、tasks、requirements、syncJobs、indexHealth |
| UI 状态 | `stores/ui-store.ts` 管理弹窗、toast、侧栏等 UI 状态 |
| 节点/协商投影 | `lib/use-task-node-flow.ts`、`lib/use-task-consultation.ts`、`lib/use-capability-status.ts`、`lib/use-activity-recent.ts` |
| 刷新策略 | `App.tsx` 对 project `lastScanAt` 做 30 秒 silent refresh；节点流 hook 也有 30 秒轮询 |

前端只通过 API 触发扫描、需求创建、任务更新、节点动作、终端、AI CLI 等行为。项目文件写入和数据库写入都发生在后端服务边界内。

## 组件分层

| 目录 | 职责 |
|---|---|
| `components/ui/` | Button、Card、Badge、Modal、Input、Toast、SegmentedControl、SlidePanel、Skeleton 等基础组件 |
| `components/layout/` | AppShell、Sidebar、PageHeader |
| `components/task-board/` | 任务看板过滤、健康面板、未启动需求条 |
| `components/task-detail-v2/` | 当前任务详情工作台、节点动作、consultation stream、checkpoint/workspace/review drawer |
| `components/node-flow/` | NodeStepper |
| `components/trace/` | TraceTimeline |
| `components/capability/` | CapabilityMatrix |
| `components/metric/` | MetricCard |
| `components/ai-cli/`、`components/slot-terminal/` | AI CLI 与终端运行面 |
| `components/breakdown-review/`、`components/requirements/` | 需求拆分与 Markdown 编辑 |

UI 使用 CSS Modules 与 `styles/tokens.css`。E12 沉淀下来的可活部分已经体现在 NodeStepper、TraceTimeline、CapabilityMatrix、MetricCard、ActivityFeed、Task Detail v2 等实现中。

## Projection UI

当前前端以节点和投影为主：

- 任务看板通过 `currentNode` / `runtimeState` / `reviewStatus` 派生分组与视觉状态，逻辑在 `lib/node-board-config.ts` 与 `lib/ui-mapping.ts`。
- Node Flow 通过 `GET /api/tasks/:id/node-flow` 读取当前节点、substate、runtime state、transition history 与 applicable actions。
- Consultation 通过 `GET /api/tasks/:id/consultation` 展示协商轮次。
- Capability Matrix 组合 `GET /api/capabilities/status` 与 `GET /api/noderuns/:taskId`，以 NodeRun capability decisions 为任务级主源。
- Activity Feed 通过 `GET /api/activity/recent` 展示近期事件。

这些视图是投影，不是节点设计器；用户动作最终仍由后端 guard / primitive / apply endpoint 控制。

## 构建与验证

| 命令 | 说明 |
|---|---|
| `cd su-oriel && pnpm --filter su-oriel-web dev` | Vite dev server |
| `cd su-oriel && pnpm --filter su-oriel-web build` | TypeScript noEmit |
| `cd su-oriel && pnpm --filter su-oriel-web test` | Vitest |

`web/src/tests/` 与组件旁 `*.spec.tsx` 覆盖布局、组件、projection hook、acceptance snapshots。

## 当前边界

- 前端没有通用实时数据 push；项目数据主要靠 silent refresh 和手动刷新。终端/AI CLI 有独立 websocket 面。
- 前端创建需求、上传需求图片、触发扫描和节点动作，但不直接改项目文件；文件落点由后端与 plugin/runtime 处理。
- `outputMode` 在需求表单类型中仍保留用于后端兼容，UI 当前只暴露 requirement-only 路径。
- `console-api.ts` 是当前主要 API client；部分节点/trace hook 有本地 `requestJson` 封装，尚未全部收敛到一个客户端。

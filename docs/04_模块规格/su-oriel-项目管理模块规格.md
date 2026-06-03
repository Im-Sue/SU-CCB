---
doc_type: module_spec
title: "SU-Oriel 项目管理模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 项目管理模块规格

## 1. 模块目标

项目管理模块负责把一个本地 CCB 项目登记为 SU-Oriel 可观测对象，并提供接入检查、知识库初始化、手动扫描、索引健康与主项目终端入口。它不拥有业务文档真相，只保存项目元数据与运行投影。

真实实现锚点：

- `su-oriel/server/src/modules/project/project.routes.ts`
- `su-oriel/server/src/modules/project/project.store.prisma.ts`
- `su-oriel/server/src/modules/project/project-onboarding.routes.ts`
- `su-oriel/server/src/modules/project-ccbd/project-ccbd-manager.ts`
- `su-oriel/server/src/modules/project-ccbd/managed-config.service.ts`
- `su-oriel/server/prisma/schema.prisma`
- `su-oriel/web/src/pages/overview/OverviewPage.tsx`
- `su-oriel/web/src/components/projects/ProjectOnboardingBanner.tsx`
- `su-oriel/web/src/components/projects/ProjectScanProgressBar.tsx`
- `su-oriel/web/src/stores/project-store.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 项目列表 | `GET /api/projects` 从 Prisma store 返回已登记项目。 |
| 创建项目 | `POST /api/projects` 校验输入，创建 `Project`，随后异步触发项目扫描并注册文件监听。 |
| 索引健康 | `GET /api/projects/:projectId/index-health` 返回文档数、任务数、需求数、解析失败数与 24 小时新鲜度。 |
| 手动扫描 | `POST /api/projects/:projectId/scan` 通过 `startProjectScan` 进入扫描流水线；重复触发时复用正在运行的 scan job。 |
| 扫描进度 | `GET /api/projects/:projectId/scan-status` 合并 `Project.syncStatus`、最新 scan job 与当前扫描阶段。 |
| 接入状态 | `GET /api/projects/:projectId/onboarding-status` 检查 `.ccb/ccb.config` 与 `docs/.ccb/docs-structure-contract.yaml`、文档地图或机器索引。 |
| CCB runtime 管理 | `project-ccbd` 路由检查 ccbd 状态、确认恢复、打开主项目终端。 |
| 知识库初始化 | `POST /api/projects/:projectId/init-knowledge-base` 通过 ccbd 向 Claude agent 提交 `/ccb:su-init`。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `OverviewPage` | 展示项目概览、需求/任务/文档统计、系统健康和最近活动。 |
| `ProjectOnboardingBanner` | 展示 CCB runtime 与知识库接入状态，并提供初始化、打开终端等触发入口。 |
| `ProjectScanProgressBar` | 在项目扫描期间轮询 scan status，展示 scan pipeline 阶段和失败信息。 |
| `Sidebar` | 提供项目选择、主要导航和项目级入口；部分旧导航项仍隐藏保留。 |
| `project-store` | 管理项目列表、当前项目、项目数据加载、创建项目和手动扫描。 |

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `Project` | `name`、`localPath`、`summary`、`initStatus`、`docsRoot`、`lastScanAt`、`syncStatus` | SU-Oriel 的项目登记表；`localPath` 唯一。 |
| `ProjectSettings` | `scanStrategyJson`、`parsingRulesJson`、`pathConfigJson` | 项目设置投影，独立于项目创建流程。 |
| `SyncJob` | `projectId`、`jobType`、`status`、`processedCount`、`totalCount`、`errorMessage` | 项目扫描与索引流水线的可观测记录。 |
| 关联模型 | `Document`、`Task`、`Requirement`、`TaskWorkspace`、`ReviewIntent`、`Sprint` 等 | 都按 `projectId` 归属项目。 |

## 5. 接口边界

项目管理模块只保存 SU-Oriel 自身的项目登记和运行投影。项目内 `.ccb`、`docs` 和业务文档仍属于被观测项目；创建项目不会把 SU-Oriel 变成业务写入者。

当前未实现项目更新、删除和远程仓库管理接口。`init-knowledge-base` 依赖本地 ccbd socket 和项目中的 Claude agent 配置；没有运行 CCB runtime 时返回冲突或服务不可用。

## 6. 旧规格 vs 实际偏差

旧规格只描述“项目卡片、创建弹窗、初始化状态标签”等早期页面概念。实际 v1.0 模块已经包含扫描状态、索引健康、接入检查、ccbd runtime 检查、主终端和知识库初始化。旧规格提到“编辑项目基础信息”，真实 API 当前没有对应更新路由。

## 7. v1.0 校正点

- 使用 `su-oriel` 当前目录与包语义，不再沿用旧产品命名。
- 创建项目后立即进入 `startProjectScan`，并尝试注册文件监听。
- 接入检查以 `.ccb/ccb.config`、`docs/.ccb/docs-structure-contract.yaml` 与文档地图/机器索引为准。
- 项目管理只触发初始化与扫描，不直接写业务需求、任务或文档正文。

## 8. 待定事项

- 是否需要项目编辑/删除能力仍未在当前实现中落地。
- UI 文案仍有少量历史品牌残留，是否统一替换为 SU-Oriel 需要产品侧确认。

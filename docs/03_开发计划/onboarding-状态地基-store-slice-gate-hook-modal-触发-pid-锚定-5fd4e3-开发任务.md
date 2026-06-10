---
doc_type: dev_task
task_id: subtask-bcdeaf5fd4e3
title: onboarding 状态地基:store slice + gate hook + modal 触发 pid 锚定
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq83fxgga520fb5d76b9d989
section_id: pr1-onboarding-state-foundation
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq83fxgga520fb5d76b9d989.json
source_draft_hash: 32e378a328f2bfe51ce3d5445386715e5040a5aecd5c02c990634e4d2609c850
created_at: 2026-06-10T15:35:29.773Z
updated_at: 2026-06-10T16:06:33.328Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq83fxgga520fb5d76b9d989","branch":"ccb/req-cmq83fxgga520fb5d76b9d989"}
---

# onboarding 状态地基:store slice + gate hook + modal 触发 pid 锚定

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | project-store 新增 onboardingByProject slice 与 ensureOnboarding(模块级 Map 去重 + 30s TTL + loading/error);useProjectOnboardingGate 派生 ready/locked 与 requireInit;ui-store 增 onboarding-required modalType 及 onboardingRequiredProjectId 字段 + openOnboardingRequired(pid) action。不改任何视图。 |
| 需求来源 | cmq83fxgga520fb5d76b9d989 |
| 本期范围 | pr1-onboarding-state-foundation · onboarding 状态地基:store slice + gate hook + modal 触发 pid 锚定 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 任务概述

**目标对齐**:给"首次使用初始化门控"打地基——把项目"接入状态"(是否初始化好 CCB 运行时 + 知识库)做成全局唯一一份数据源,让左侧导航、概览、引导框都读同一份,不再各拉各的。本片只建数据与判断地基(store + 派生 hook + 弹框触发通道),**不动任何界面**,合并后界面行为不变、全仓可编译。

> 术语白话:onboarding 状态(= 项目接入就绪信息,来自 `GET /api/projects/{id}/onboarding-status`);ready(= `ccbRuntimeReady && knowledgeBaseReady` 全绿);in-flight 去重(= 同一项目并发请求只发一次,共享同一个 Promise)。

技术设计:`docs/03_开发计划/优化-第一次使用引导问题-b9d989-技术设计.md`(二、三、四章为本片契约)。

### 任务分解

1. `[MODIFY] stores/project-store.ts`:新增 `onboardingByProject: Record<projectId, { value: ProjectOnboardingStatusView | null; fetchedAt: number; loading: boolean; error: string | null }>`;新增 `ensureOnboarding(projectId, { force? })`——模块级 `Map<projectId, Promise>` 做 in-flight 去重、沿用 30s TTL、写 loading/error、成功写 value + fetchedAt。
2. `[NEW] lib/use-project-onboarding-gate.ts`:`useProjectOnboardingGate(projectId)` → `{ ready, loading, error, requireInit() }`;挂载 / projectId 变化时调 `ensureOnboarding`;`ready = value?.ccbRuntimeReady === true && value?.knowledgeBaseReady === true`;`requireInit()` = `openOnboardingRequired(projectId)`。
3. `[MODIFY] stores/ui-store.ts`:`modalType` union 增 `"onboarding-required"`;新增 `onboardingRequiredProjectId: string | null` 字段 + `openOnboardingRequired(projectId)` action(置 modalType 与 pid);`closeModal` 一并清 `onboardingRequiredProjectId`。

### 验收标准

- [ ] 单元:`useProjectOnboardingGate` 四态——未加载 / loading / error / 未就绪均 `ready=false`;两步全绿 `ready=true`。
- [ ] 单元:`ensureOnboarding` 并发去重(同 pid 并发只发一次请求、共享 Promise)、TTL 命中复用 / 过期重拉、失败写 error 不抛。
- [ ] 单元:`openOnboardingRequired(pid)` 置 `modalType="onboarding-required"` 且 `onboardingRequiredProjectId=pid`;`closeModal` 清两者。
- [ ] typecheck / build 通过;现有界面行为不变(本片不渲染新 UI)。

### 边界 / 不做项

- 不改 Sidebar / OverviewPage / banner 任何视图(归 pr2 / pr3 / pr4)。
- 不动后端 / API / schema;in-flight Promise 只放模块级 Map,不进 Zustand state。
- 不在本片消费 modal(pr2 才渲染 onboarding-required modal)。

### 依赖

无(地基片;pr2 / pr3 依赖本片产物)。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-10 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq83fxgga520fb5d76b9d989
- Section: pr1-onboarding-state-foundation
- Owner: claude
- Priority: high
- Dependencies: none

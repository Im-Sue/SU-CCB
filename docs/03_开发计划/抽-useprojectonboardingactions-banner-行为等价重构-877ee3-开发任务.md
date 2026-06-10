---
doc_type: dev_task
task_id: subtask-25bc87877ee3
title: 抽 useProjectOnboardingActions + banner 行为等价重构
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq83fxgga520fb5d76b9d989
section_id: pr3-onboarding-actions-and-banner-refactor
order: 3
implementation_owner: claude
dependencies: [subtask-bcdeaf5fd4e3]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq83fxgga520fb5d76b9d989.json
source_draft_hash: 32e378a328f2bfe51ce3d5445386715e5040a5aecd5c02c990634e4d2609c850
created_at: 2026-06-10T15:35:29.773Z
updated_at: 2026-06-10T16:20:40.527Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq83fxgga520fb5d76b9d989","branch":"ccb/req-cmq83fxgga520fb5d76b9d989"}
---

# 抽 useProjectOnboardingActions + banner 行为等价重构

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 把 ProjectOnboardingBanner 的检测/动作(复制命令/一键 init/终端)/init-job 轮询抽到 useProjectOnboardingActions(结果写 store);banner 重构为消费该 hook,public props 与行为不变,仍在概览顶部,不碰 OverviewPage。 |
| 需求来源 | cmq83fxgga520fb5d76b9d989 |
| 本期范围 | pr3-onboarding-actions-and-banner-refactor · 抽 useProjectOnboardingActions + banner 行为等价重构 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 任务概述

**目标对齐**:把概览顶部那条初始化横幅(`ProjectOnboardingBanner`)的"检测 + 动作(复制命令 / 一键初始化 / 打开终端)+ 初始化任务轮询"逻辑抽成一个可复用 hook,横幅改成消费这个 hook。**本片是行为等价重构**——重构后横幅外观、动作、轮询行为与重构前完全一致,只是逻辑搬了位置,为 pr4 复用做准备。本片**不碰 OverviewPage**(保持横幅对外 props 不变)。

> 术语白话:init-job 轮询(= 提交 `/ccb:su-init` 后,每 3s 查一次知识库是否就绪,最长 60s);行为等价重构(= 只改代码结构,不改任何用户可见行为)。

技术设计:`docs/03_开发计划/优化-第一次使用引导问题-b9d989-技术设计.md`(二、三章 banner 拆分 + 轮询写 store)。

### 任务分解

1. `[NEW] lib/use-project-onboarding-actions.ts`:`useProjectOnboardingActions(projectId)` 内聚——检测(经 pr1 的 `ensureOnboarding` / store)、动作 `copyCommand` / `initKnowledgeBase` / `openTerminal`、init-job 轮询(3s / 60s,结果写 store 而非组件局部 state)。
2. `[MODIFY] components/projects/ProjectOnboardingBanner.tsx`:删除组件私有的 `statusCache` / `loadStatus` / 轮询 state,改为消费 `useProjectOnboardingActions`;**对外 props 与三态渲染(runtime-missing / knowledge-missing / ready)保持不变**;仍只挂概览顶部。

### 验收标准

- [ ] 集成:沿用并保持现有 `ProjectOnboardingBanner.spec.tsx` 语义全绿(三态渲染、复制命令、一键 init、重新检测、打开终端)。
- [ ] 集成:补一条——轮询拿到 `knowledgeBaseReady` 写 store 后,banner UI 切到 ready 态;`su-init` 失败 / 超时文案不回归。
- [ ] 组件卸载后无 unmounted setState 警告(轮询写 store,不写已卸载组件局部 state)。
- [ ] typecheck / build 通过;`OverviewPage` 未被改动(git diff 不含该文件)。

### 边界 / 不做项

- **不碰 OverviewPage**(保持 banner public API 稳定,避免与 pr4 文件冲突)。
- 不做整页引导 / 概览切换(归 pr4)。
- 不改初始化后端流程、不改 onboarding-status 接口契约。

### 依赖

> 依赖 pr1:`onboardingByProject` store slice 与 `ensureOnboarding`。pr1 合并前本片不可开工。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-bcdeaf5fd4e3
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
- Section: pr3-onboarding-actions-and-banner-refactor
- Owner: claude
- Priority: high
- Dependencies: subtask-bcdeaf5fd4e3

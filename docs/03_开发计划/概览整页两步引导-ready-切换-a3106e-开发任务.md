---
doc_type: dev_task
task_id: subtask-09eeb8a3106e
title: 概览整页两步引导 + ready 切换
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq83fxgga520fb5d76b9d989
section_id: pr4-overview-fullpage-guide
order: 4
implementation_owner: claude
dependencies: [subtask-25bc87877ee3]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq83fxgga520fb5d76b9d989.json
source_draft_hash: 32e378a328f2bfe51ce3d5445386715e5040a5aecd5c02c990634e4d2609c850
created_at: 2026-06-10T15:35:29.773Z
updated_at: 2026-06-10T16:27:08.388Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq83fxgga520fb5d76b9d989","branch":"ccb/req-cmq83fxgga520fb5d76b9d989"}
---

# 概览整页两步引导 + ready 切换

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增 ProjectSetupGuide(整页两步:CCB 运行时 + 知识库,按 ccbRuntimeReady/knowledgeBaseReady 高亮);OverviewPage 持有 actions hook,ready ? 现概览(banner+卡片) : 引导(隐藏指标卡);处理 loading 不抢渲染与卸载时序(写 store)。 |
| 需求来源 | cmq83fxgga520fb5d76b9d989 |
| 本期范围 | pr4-overview-fullpage-guide · 概览整页两步引导 + ready 切换 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 任务概述

**目标对齐**:实现用户要的"未初始化时概览整页做初始化引导"——项目没就绪时,概览不再显示空指标卡,而是整页一个**两步引导**(第①步初始化 CCB 运行时、第②步初始化知识库),照着做完两步,概览自动切回正常数据盘。复用 pr3 的 actions hook,不新造初始化逻辑。

> 术语白话:两步高亮(= 按 `ccbRuntimeReady` / `knowledgeBaseReady` 点亮当前该做哪步);卸载时序(= 就绪后引导组件被卸载的瞬间,轮询的末次结果必须已落 store、不丢、不报 unmounted setState)。

技术设计:`docs/03_开发计划/优化-第一次使用引导问题-b9d989-技术设计.md`(一、四章核心流程 + 十风险)。

### 任务分解

1. `[NEW] components/projects/ProjectSetupGuide.tsx`(+ `.module.css`):整页两步引导,消费 `useProjectOnboardingActions`;步骤① CCB 运行时(复制命令)、步骤② 知识库(一键 init + 打开终端 + 轮询状态);按 `ccbRuntimeReady` / `knowledgeBaseReady` 高亮 / 置完成当前步。
2. `[MODIFY] pages/overview/OverviewPage.tsx`(+ `OverviewPage.module.css`):在稳定层持有 `useProjectOnboardingActions(selectedProjectId)`(跨"引导↔数据盘"切换不卸载);`!ready` → 渲染 `<ProjectSetupGuide>` 且隐藏指标卡;`ready` → 现概览(banner + 指标卡);`loading` / 未加载 → 不抢渲染引导也不渲染数据盘(占位 / 骨架),不 fail-open;把 actions / status 传给 guide(或 guide 自取,二选一,保持单一来源)。

### 验收标准

- [ ] 组件:`!ready` 渲染 `ProjectSetupGuide` 且**不渲染指标卡**;`ready` 渲染现概览(banner + 卡片);store ready 翻转触发切换。
- [ ] 组件:两步高亮——runtime-missing 高亮步骤①、knowledge-missing 高亮步骤②、ready 不再展示引导。
- [ ] 时序(fake timers):模拟 init-job 轮询拿到 `knowledgeBaseReady` 写 store → ready 翻转 → guide 卸载;断言 store 末次值保留、无 unmounted setState 警告。
- [ ] loading 策略:`value=null` / `loading=true` 时概览既不渲染指标卡也不抢渲染错误 / 步骤态(显示检测中 / 骨架)。
- [ ] typecheck / build 通过;`!selectedProjectId` 的 EmptyState、`loadingData` 分支不回归。

### 边界 / 不做项

- 不做命令面板 / 直达 URL 拦截(产品豁免)。
- 不改初始化后端流程;不新增 onboarding 接口。
- 不在 modal 复刻初始化(pr2 的 modal 只跳概览,落到本片引导)。

### 依赖

> 依赖 pr3:`useProjectOnboardingActions`(检测 + 动作 + 轮询写 store)与重构后行为稳定的 banner。pr3 合并前本片不可开工。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-25bc87877ee3
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
- Section: pr4-overview-fullpage-guide
- Owner: claude
- Priority: high
- Dependencies: subtask-25bc87877ee3

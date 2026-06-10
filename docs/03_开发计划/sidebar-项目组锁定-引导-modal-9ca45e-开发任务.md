---
doc_type: dev_task
task_id: subtask-59b3df9ca45e
title: Sidebar 项目组锁定 + 引导 modal
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq83fxgga520fb5d76b9d989
section_id: pr2-sidebar-lock-and-modal
order: 2
implementation_owner: claude
dependencies: [subtask-bcdeaf5fd4e3]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq83fxgga520fb5d76b9d989.json
source_draft_hash: 32e378a328f2bfe51ce3d5445386715e5040a5aecd5c02c990634e4d2609c850
created_at: 2026-06-10T15:35:29.773Z
updated_at: 2026-06-10T16:13:17.683Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq83fxgga520fb5d76b9d989","branch":"ccb/req-cmq83fxgga520fb5d76b9d989"}
---

# Sidebar 项目组锁定 + 引导 modal

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | Sidebar 项目组消费 gate hook,未就绪渲染锁定 button(非 disabled/可聚焦/点击 openOnboardingRequired 不导航/不模拟 active/loading 显示检测中);新增 OnboardingRequiredModal(CTA 跳锚定 pid 的 /overview + closeModal);App 渲染该 modal。 |
| 需求来源 | cmq83fxgga520fb5d76b9d989 |
| 本期范围 | pr2-sidebar-lock-and-modal · Sidebar 项目组锁定 + 引导 modal |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 任务概述

**目标对齐**:把左侧"项目"组(需求 / 文档 / Slot / 运行)在未初始化时**锁起来**——显示锁图标、点了不跳转、改弹一个"请先去初始化"的框,框里按钮把人带回该项目概览。让首次用户不再误点进空页面。门控数据来自 pr1 的 gate hook,本片纯做 Sidebar 锁定渲染 + 引导弹框。

> 术语白话:gated(= 该组导航在未就绪时受门控锁定);触发 pid 锚定(= 弹框记录"是哪个项目触发的",CTA 跳那个项目,避免弹框期间切项目跳错)。

技术设计:`docs/03_开发计划/优化-第一次使用引导问题-b9d989-技术设计.md`(二、三章 Sidebar / modal 部分)。

### 任务分解

1. `[MODIFY] components/layout/Sidebar.tsx`(+ `Sidebar.module.css`):navSection 给"项目"组标 `gated`;消费 `useProjectOnboardingGate(selectedProjectId)`;`!ready` 时项目组项渲染为锁定 `button`(非 `disabled`、`type="button"`、保留键盘焦点、`aria-disabled="true"`、锁图标 / 弱化样式),点击调 `requireInit()` 不导航、不模拟 active 态;loading 时锁定并显示"检测中"语义;`ready` 恢复现有 `NavLink`。非"项目"组(工作 / 工具)不受影响。
2. `[NEW] components/projects/OnboardingRequiredModal.tsx`(+ `.module.css`):读 `onboardingRequiredProjectId`,文案"项目还没初始化 CCB / 知识库,请先初始化";`[去概览初始化]` → `navigate(/projects/<锚定 pid>/overview)` + `closeModal`;`[关闭]` → `closeModal`。
3. `[MODIFY] App.tsx`:在现有 modal 渲染处增加 `modalType === "onboarding-required"` 分支渲染 `OnboardingRequiredModal`。

### 验收标准

- [ ] 组件:`!ready` 时"项目"组渲染锁定 button(非 disabled、可键盘聚焦、点击触发 `openOnboardingRequired`、不发生导航);`ready` 时恢复 NavLink 正常跳转。
- [ ] 组件:工作组(概览 / 我的工作)、工具组(项目设置 / AI CLI)在 `!ready` 时始终可达、不被锁。
- [ ] 组件:loading 态项目组显示锁定 + "检测中",不放行。
- [ ] 组件:modal CTA 跳"触发时锚定 pid"的 `/overview`(模拟弹框打开后切项目,仍跳原 pid)+ `closeModal`。
- [ ] 回归(显式非拦截):命令面板 / 直达 URL / 新建需求(`create-requirement`)入口在 `!ready` 时**不被拦截**(产品接受的豁免),专项断言防误改。

### 边界 / 不做项

- 不改概览页呈现(归 pr4);不动 banner / 初始化流程。
- 不拦命令面板 / 直达 URL(产品豁免)。
- modal 不复刻初始化动作,只跳概览复用引导。

### 依赖

> 依赖 pr1:`useProjectOnboardingGate`、ui-store `onboarding-required` modalType 与 `openOnboardingRequired` / `onboardingRequiredProjectId`。pr1 合并前本片不可开工。

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
- Section: pr2-sidebar-lock-and-modal
- Owner: claude
- Priority: high
- Dependencies: subtask-bcdeaf5fd4e3

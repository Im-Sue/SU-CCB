---
doc_type: dev_task
task_id: subtask-ce9aa7166365
title: attention 数据与投递层：DND 拆层契约 + snapshot store + 投递互斥
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmq7mj42v10e7ef5f4eebadfe
section_id: pr1-attention-data-delivery-layer
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7mj42v10e7ef5f4eebadfe.json
source_draft_hash: b6a07fab75d454be15309f0dd3b4a2ff3b618ad143a36e8c79f1631a3ae00b17
created_at: 2026-06-10T09:52:50.664Z
code_workspace: {"path":"../SU-CCB-req-cmq7mj42v10e7ef5f4eebadfe","branch":"ccb/req-cmq7mj42v10e7ef5f4eebadfe"}
---

# attention 数据与投递层：DND 拆层契约 + snapshot store + 投递互斥

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | server computeAttention 删 DND 清空、响应加 dnd_active/dnd_until；ui-store 升级 attentionSnapshot（set/clear/removeRefs）；buildAttentionNavigatePath 抽 lib、导出 playAttentionSound；Manager tick 写 snapshot + 投递互斥（visible→Toast 聚合/hidden→浏览器通知/dnd→全停）；Bell 仅最小角标 selector 改动保编译；server service+routes spec 改写 DND 断言、Manager spec 重写投递断言。 |
| 需求来源 | cmq7mj42v10e7ef5f4eebadfe |
| 本期范围 | pr1-attention-data-delivery-layer · attention 数据与投递层：DND 拆层契约 + snapshot store + 投递互斥 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把通知系统的「数据与投递层」改对：①后端「项目暂停」(DND) 不再把未读消息藏起来——接口照常返回未读列表，只是多告诉前端「现在处于暂停中」；②前端把轮询拿到的完整消息数据存进全局 store（现在只存了个数字），给后续弹窗列表当数据源；③新消息提示改成互斥投递：你正看着页面就弹页面内 Toast，没看页面才走浏览器系统通知，暂停期间两者全停。本片不动弹窗 UI 重构（那是 pr2），但要对 NotificationBell 做最小改动（角标数据源换成新 store），保证本片合并后全仓可编译、行为自洽。

> 术语白话：snapshot（= 一次轮询结果的完整快照，含项目 id 防串台）；dnd_active（= 服务端判定的「暂停中」标记）；投递互斥（= 同一条新消息只走 Toast 或浏览器通知一个通道，不双发）。

技术设计：`docs/03_开发计划/bug-通知相关的消息没有展示出来-ebadfe-技术设计.md`（二、三、四、七章为本片契约）。

### 任务分解

1. server `attention-inbox.service.ts`：`computeAttention` 删除 `visible = dndActive ? [] : unacked` 清空逻辑，items/count 恒为排序后的 unacked；响应新增 `dnd_active: boolean`、`dnd_until: string|null`（snake_case）。`attention-inbox.types.ts` 同步 `AttentionListResponse`。
2. web `console-api.ts`：`AttentionListResponse` 类型同步两字段。
3. web `ui-store.ts`：`attentionUnreadCount` 升级为 `attentionSnapshot { projectId, items, count, dndActive, dndUntil, fetchedAt }`，配 `setAttentionSnapshot / clearAttentionSnapshot / removeAttentionRefs`（removeRefs 同步减 count）。
4. `[NEW]` web `lib/attention-navigation.ts`：`buildAttentionNavigatePath` 自 NotificationManager 迁入并导出；slot/project cta 沿用现状 fallback（落 overview/任务/需求路径），用测试钉住该行为。
5. web `browser-notify.ts`：导出 `playAttentionSound`。
6. web `NotificationManager.tsx`：tick 写 snapshot（projectId 为 null 或切换时 clear + badge 清零）；投递分支改写——`dnd_active` → 全静默仅更新展示；`document.visibilityState === "visible"` → `addToast`（1 条 `新通知：{title}`，多条 `${N} 条新通知`）+ `soundEnabled && playAttentionSound()`；hidden → 现状浏览器通知分支（leader 协调保留）。首轮不投递（knownRefs===null）与 shownRefs 去重沿用，Toast 分支同样登记 shownRefs。
7. web `NotificationBell.tsx`：仅最小改动——角标数据源从 `attentionUnreadCount` 换为 snapshot 派生 count（projectId 匹配校验），不做弹窗 UI 重构（Codex 协商否决保留旧 count 兼容字段，避免冗余 store 状态）。

### 验收标准

- [ ] server `attention-inbox.service` spec：DND 激活时 items/count 仍返回 unacked 且 `dnd_active=true`、`dnd_until` 透传；未设置时 `dnd_active=false`（改写旧「DND 后 count=0」断言）
- [ ] server `attention-inbox.routes` spec：DND 后 GET `/attention` 仍返回 items/count 且含 `dnd_active/dnd_until`（旧断言同批改写）
- [ ] `NotificationManager` spec：visible → 仅 Toast（聚合文案断言）+ 声音 mock，不走浏览器通知；hidden → 仅浏览器通知且仍走 leader 协调；`dnd_active=true` → toast/browser/sound 全停但 snapshot/badge 照常更新；ack pending 重试行为不回归；fixtures 补 `dnd_active/dnd_until` 字段
- [ ] 项目切换 / `projectId=null`：snapshot 清空、badge 清零、角标不读 stale 数据（专项断言）
- [ ] `attention-navigation` 测试：task / requirement / project / slot 四类 cta 的跳转与 fallback 行为明确钉住
- [ ] 全仓 `attentionUnreadCount` 引用清零（ui-store / Manager / Bell / spec 四处，grep 验证），typecheck/build 通过

### 边界 / 不做项

- 不做 Bell 弹窗列表 UI、全部已读、DND 横幅、设置折叠（全部归 pr2）
- 不动 Toast 组件模型（3s 纯文本）、不加批量端点、不改 DB/路由注册、不加依赖
- 不为多 tab 同时可见的重复 Toast 加协调逻辑（技设接受的 v1 边界）
- 技设排除项（历史分页 / 跨项目通知 / 轮询频率 / pageToastEnabled）禁止回塞

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

- Requirement: cmq7mj42v10e7ef5f4eebadfe
- Section: pr1-attention-data-delivery-layer
- Owner: ccb_codex
- Priority: high
- Dependencies: none

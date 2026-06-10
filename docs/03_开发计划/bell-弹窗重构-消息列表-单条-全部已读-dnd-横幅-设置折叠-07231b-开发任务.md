---
doc_type: dev_task
task_id: subtask-f90f0007231b
title: Bell 弹窗重构：消息列表 + 单条/全部已读 + DND 横幅 + 设置折叠
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmq7mj42v10e7ef5f4eebadfe
section_id: pr2-notification-bell-inbox-ui
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-ce9aa7166365]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7mj42v10e7ef5f4eebadfe.json
source_draft_hash: b6a07fab75d454be15309f0dd3b4a2ff3b618ad143a36e8c79f1631a3ae00b17
created_at: 2026-06-10T09:52:50.664Z
code_workspace: {"path":"../SU-CCB-req-cmq7mj42v10e7ef5f4eebadfe","branch":"ccb/req-cmq7mj42v10e7ef5f4eebadfe"}
---

# Bell 弹窗重构：消息列表 + 单条/全部已读 + DND 横幅 + 设置折叠

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | NotificationBell 重排为列表为主（severity/标题/摘要/时间，点击 navigate+ack）、全部已读 Promise.allSettled 部分失败语义、dndActive 横幅、saveDnd 即时同步 snapshot、设置原样折叠入 details、aria-label 修正；NotificationBell.spec.tsx 从零新增覆盖列表/ack 失败保留/全部已读/DND/stale 防护/折叠区回归。 |
| 需求来源 | cmq7mj42v10e7ef5f4eebadfe |
| 本期范围 | pr2-notification-bell-inbox-ui · Bell 弹窗重构：消息列表 + 单条/全部已读 + DND 横幅 + 设置折叠 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把「通知」弹窗从设置面板改造成真正的消息中心入口：点开先看到未读消息列表（severity 标记、标题、摘要单行省略、相对时间），点一条跳到对应任务/需求并自动标记已读；头部有未读数和「全部已读」；「项目暂停」激活时显示「已暂停投递，消息仍可见」横幅；原来的投递设置和项目暂停按钮原样收进底部折叠区。这是用户报告 bug 的直接修复面——点「通知」终于能看到消息了。数据全部来自 pr1 建好的 snapshot store，本片纯展示与交互。

> 术语白话：ack（= 标记已处理，消息从未读列表消失、角标减一）；severity（= 消息级别：attention 需要动作 / warning 警示 / info 通知）。

技术设计：`docs/03_开发计划/bug-通知相关的消息没有展示出来-ebadfe-技术设计.md`（三、四章「Bell 单条点击 / 全部已读 / saveDnd」流程为本片契约）。

```
┌─ 通知 (6)                 [全部已读] ─┐
│ ● title（attention 红点）             │
│   summary 单行省略…        12:03     │
│ ● title              [warning 标记]  │
│   …（max-height 滚动）                │
├──────────────────────────────────────┤
│ （dndActive 时）已暂停投递至 xx，消息仍可见 │
│ ▸ 通知设置（投递 / 项目暂停，默认折叠）   │
└──────────────────────────────────────┘
```

### 任务分解

1. `NotificationBell.tsx` 重排：头部（标题 + 未读数 + 全部已读按钮）→ 消息列表（snapshot.items，仅当 `snapshot.projectId === 当前项目`）→ DND 横幅（dndActive 时）→ `<details>` 折叠区移入现有投递设置与项目暂停 JSX（功能不变）。
2. 触发按钮 aria-label 由「通知设置」改为「通知」（弹窗 dialog 的 aria-label 同步语义）。
3. 单条点击：`navigate(buildAttentionNavigatePath(item))` → `ackAttention(ref)`；成功 → `removeAttentionRefs([ref])`；失败 → error toast「标记已读失败」，条目保留（不乐观清除，不承诺自动重试）。
4. 全部已读：`Promise.allSettled(items.map(ack))`；fulfilled refs 本地移除、rejected 保留并 toast「N 条标记失败」；count 同步为剩余条数。
5. `saveDnd` 成功后立即同步 snapshot 的 `dndActive/dndUntil`（不等下一轮 7s 轮询），DND 横幅即时出现/消失。
6. `NotificationBell.module.css`：列表区样式（max-height + overflow-y 滚动、severity 标记、摘要单行省略）。
7. `[NEW] NotificationBell.spec.tsx`：现状无此文件，从零新增完整组件测试。

### 验收标准

- [ ] 列表渲染：severity / 标题 / 摘要省略 / 相对时间；空列表显示「暂无未读通知」空态
- [ ] 单条点击：navigate 路径正确 + ack 成功后条目移除、角标减一；ack 失败条目保留 + error toast
- [ ] 全部已读：全成功角标清零；部分失败仅移除 fulfilled refs、rejected 保留、count = 剩余条数、toast 提示
- [ ] DND：dndActive 时横幅显示；saveDnd 成功后横幅与 snapshot 立即同步（不等轮询）
- [ ] snapshot.projectId 与当前项目不匹配时不渲染列表（stale 防护）
- [ ] 折叠设置区内浏览器通知/声音开关与 DND 三按钮功能不回归
- [ ] aria-label 断言更新；typecheck/build/spec 全绿

### 边界 / 不做项

- 不改投递逻辑与 NotificationManager（pr1 已定）
- 不加批量 ack 端点（逐条 `Promise.allSettled`，未读量常态个位数）
- 不动 Toast 组件（3s 纯文本不可点击）
- 不做历史分页 / 消息中心页 / 跨项目通知（技设排除项）

### 依赖

> 依赖 pr1：attentionSnapshot store API（set/clear/removeRefs）、`lib/attention-navigation.ts`、`dnd_active/dnd_until` 契约。pr1 合并前本片不可开工。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-ce9aa7166365
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
- Section: pr2-notification-bell-inbox-ui
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-ce9aa7166365

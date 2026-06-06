---
doc_type: dev_task
task_id: subtask-fc433baac395
title: Console 取消 UX：去 danger + 原因输入 + 级联影响文案 + 终态反馈
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpzllxw73320bc3428913778
section_id: pr1-console-cancel-ux
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzllxw73320bc3428913778.json
source_draft_hash: acb5232bfcd1c86c58b5b511afaca3f63f1ac749fd999d0c2a1edba3f6c421b1
created_at: 2026-06-06T09:05:52.211Z
updated_at: 2026-06-06T10:15:13.063Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzllxw73320bc3428913778","branch":"ccb/req-cmpzllxw73320bc3428913778"}
---

# Console 取消 UX：去 danger + 原因输入 + 级联影响文案 + 终态反馈

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 菜单项 danger→ghost；确认弹窗加 reason 输入与级联影响复述 + slot busy 非抢占提示；payload 带 reason；「取消执行中」banner→投影 cancelled 成功 toast / capability_outcome_rejected 失败 toast；409 错误文案兜底。 |
| 需求来源 | cmpzllxw73320bc3428913778 |
| 本期范围 | pr1-console-cancel-ux · Console 取消 UX：去 danger + 原因输入 + 级联影响文案 + 终态反馈 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

#### 任务概述
实现需求 L1：取消按钮普通化 + 原因输入 + 派出后终态反馈，消除「点了没反应」。依据技术设计 §二/§七/§八 L1 组；用户已拍板（去 danger、保留弹窗、原因建议填写允许为空、弹窗确认+原因=must_ask_9 授权）。

#### 任务分解
1. `web/src/pages/requirements/RequirementDetailPage.tsx`：LIFECYCLE_ACTIONS 渲染处（约 :972）su-cancel 菜单项 `variant="danger"` → `"ghost"`（与暂缓/复活一致）；确认弹窗确认按钮同步去 danger（用 primary）。
2. 确认弹窗（约 :1308-1341）：增加级联影响复述文案（需求→cancelled、非终态子任务级联取消、breakdown draft 删除、worktree 不可逆舍弃、slot 释放）+「取消原因」输入框（复用 slot-release 弹窗 Input 模式，约 :1198-1247；placeholder 建议填写、允许为空）。
3. slot busy 时弹窗附非抢占提示：取消将排队在当前任务之后生效；如需立即中断可到 Slots 页 cancel-current-job。
4. payload：`handleDispatchLifecycleCommand` 对 su-cancel 携带 `{reason}`（trim 后非空才带）；`web/src/lib/console-api.ts` dispatch 类型对齐。
5. 终态反馈：沿用 pendingDispatches reconcile（queued/submitted/failed toast）；新增「取消执行中」banner——su-cancel job submitted 后挂起，10s reindex 轮询见投影 status=cancelled → 成功 toast + banner 收敛；fetchEventJournalEvents 见该需求 `capability_outcome_rejected` → 失败 toast + banner 转错误态。
6. 409 错误文案兜底：dispatch 失败 toast 透出 server message（pr3 未合并时无新 code 也不破坏现有行为，向前兼容）。

#### 验收标准
- [ ] 菜单项与弹窗确认按钮均无 danger 样式；弹窗含级联影响复述 + reason 输入。
- [ ] 派出 payload 含 reason（空则省略 key）；slot busy 场景出现非抢占提示。
- [ ] banner 全链路：派出→执行中→投影 cancelled 成功收敛；rejected 事件转失败。
- [ ] web typecheck/lint/build 过；不触碰 server 代码。

#### 边界 / 不做
- 不碰 su-oriel server 与 plugin（pr3/pr2 范围）；不做列表页取消入口；不改其它 lifecycle 动作样式语义。

#### 依赖 / 执行注意
- 无前置依赖（409 新 code 文案向前兼容 pr3）。su-oriel 是 submodule，按既有需求 worktree 流程；owner=claude 亲自实施。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpzllxw73320bc3428913778
- Section: pr1-console-cancel-ux
- Owner: claude
- Priority: medium
- Dependencies: none

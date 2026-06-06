---
doc_type: dev_task
task_id: subtask-0a2de3c63343
title: Console 浏览器通知投影(A 舱):NotificationManager 单例 + 多标签 leader + deep-link/ack 闭环 + 最小设置 UI
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzoupdv863041443e52441f
section_id: pr2-console-notify-web
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-6bc47408a7f3]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: db12930dd087b69323ede0b4e05130f3d45a5ba88574794f6e8df3d6994729f6
created_at: 2026-06-06T15:34:39.688Z
updated_at: 2026-06-06T16:44:11.292Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# Console 浏览器通知投影(A 舱):NotificationManager 单例 + 多标签 leader + deep-link/ack 闭环 + 最小设置 UI

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | [NEW] browser-notify util + NotificationManager 单例(poll by-ref diff → 新 attention 级弹 Notification+声音+favicon/title badge;onclick deep-link + POST ack;BroadcastChannel leader 选举);ui-store notificationSettings+unread slice;console-api attention client;最小 DND/通知开关 UI。A 舱在业务 5 源上先闭环。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr2-console-notify-web · Console 浏览器通知投影(A 舱):NotificationManager 单例 + 多标签 leader + deep-link/ack 闭环 + 最小设置 UI |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
需求目标 1「主动抓注意力」+ 目标 2「一键切换」的 Console 端落地:浏览器通知只做 attention 源投影,不自算规则。依据技术设计 §二/§四 NotificationManager/§八。

#### 任务分解
1. **[NEW] `web/src/lib/browser-notify.ts`**:Notification 权限请求(仅首次触发时请求一次)、`new Notification` 封装、可选 Audio、favicon/title badge util、权限拒绝探测。
2. **[NEW] `web/src/components/notifications/NotificationManager.tsx`**(ConsoleLayout 单例,挂 `web/src/App.tsx`):每 5-10s(复用现有轮询 ticker 模式)拉 GET `/api/projects/:id/attention` → 与上次 by-ref diff → 新增 attention 级且非 DND → 弹通知+声音+badge;onclick → navigate(`/requirements/:id` 或 `/tasks/:id`,cta 为窗口聚焦/项目页的 main 类退化为项目页)→ POST ack;**多标签去重**:BroadcastChannel leader 选举(localStorage fallback;两者均缺失→退化为每标签 ref 级节流,不抛错)。
3. **`web/src/stores/ui-store.ts`**:notificationSettings(browser/sound 开关,浏览器本地持久化)+ unread slice(badge 计数)。
4. **`web/src/lib/console-api.ts`**:attention list/ack/settings client + 类型对齐(与 pr1 types 契约一致)。
5. **最小设置 UI**:通知开关(browser/sound)+ project DND 读写(GET/PUT settings),落点随 NotificationManager 给一个轻入口(如 header 小铃铛 popover);不做完整设置页。

#### 验收标准
- [ ] 组件测试:leader 选举只让一个标签弹;BroadcastChannel 缺失时降级不抛错;onclick 导航 + POST ack 闭环;ack 失败 toast 并下轮重试(by-ref diff 保证不重复弹)。
- [ ] 权限拒绝 → 降级 title/favicon badge(不再尝试弹窗)。
- [ ] project 切换时 diff 基线重置,旧项目 item 不被当作新项目新增误弹。
- [ ] hidden tab(document.hidden)下仍正常弹 Notification(核心场景:用户不在看 Console)。
- [ ] 仅 severity=attention 进弹窗候选;warning/info 只进 badge/unread。
- [ ] console-api attention client 类型测试;web typecheck/lint/build 过;不碰 server 代码。

#### 边界 / 不做
- 不动现有 toast/路由/store 结构;不做 SSE(P1);不做完整通知中心/历史列表页;不实现 C 舱 adapter。

#### 依赖 / 执行注意
- 依赖 **pr1**(API 与 types 契约)。pr3 尚未接入时通知覆盖=业务 5 源,属预期渐进;pr3 接入后本 PR 无需改动(by-ref diff 源无关)。su-oriel submodule 流程同前。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-6bc47408a7f3
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

- Requirement: cmpzoupdv863041443e52441f
- Section: pr2-console-notify-web
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-6bc47408a7f3

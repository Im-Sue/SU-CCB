---
doc_type: dev_task
task_id: subtask-200baf369434
title: 前端·MainTerminalPanel + 全局 launcher + Modal 变体
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxp7yyc6ff3ff4e15ea509d
section_id: pr4-frontend-main-launcher
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-edaac0e2eed9, subtask-9cb77d12195c]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxp7yyc6ff3ff4e15ea509d.json
source_draft_hash: b83ac26ce80783efeb6d8c6b8c0dfe5c30d9aee1bc46b64a0a23dc6bd9ab5ca0
created_at: 2026-06-03T09:17:07.818Z
updated_at: 2026-06-03T11:03:59.360Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxp7yyc6ff3ff4e15ea509d","branch":"ccb/req-cmpxp7yyc6ff3ff4e15ea509d"}
---

# 前端·MainTerminalPanel + 全局 launcher + Modal 变体

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | MainTerminalPanel(target=agentGroup:main+fallback+无 bind+默认可写)+MainTerminalLauncher(挂 ConsoleLayout,复用 a4017f --floating-action-reserved-bottom)+Modal contentClassName+App 挂载；e2e 用 mock WS。 |
| 需求来源 | cmpxp7yyc6ff3ff4e15ea509d |
| 本期范围 | pr4-frontend-main-launcher · 前端·MainTerminalPanel + 全局 launcher + Modal 变体 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
全局悬浮入口 → 弹窗内嵌 main 双 pane 终端(默认可写)，端到端打通。承接技术设计 §二/§四。复用 pr3 substrate + pr2 端点。

#### 任务分解(前端)
- `MainTerminalPanel.tsx`(新)：薄壳，调 pr3 substrate 传 `{kind:"agentGroup", projectId, group:"main"}`；main fallback 文案(「main 会话未启动，请在 ccb 启动后重试」)；**无** bind/release 动作(main 是 coordination lane)；默认可写 + 沿用写入目标红字标注。
- `MainTerminalLauncher.tsx`(新)：全局悬浮单例，挂 ConsoleLayout；读 `useProjectStore().selectedProjectId`(空则不渲染)；用 `fetchSlots(projectId).main.state` 做可连指示；点击开 Modal 装 MainTerminalPanel；Modal 关则断 WS(MainTerminalPanel unmount)。
- `Modal.tsx`(改)：加 additive `contentClassName?`，传入可覆盖 `.content` 的 `max-height/overflow/padding`，让终端自管单滚动层。
- `App.tsx(ConsoleLayout)`(改)：`<ToastViewport/>` 同级挂 `<MainTerminalLauncher/>`。
- **与 a4017f 的右下角协调**(执行约束，非硬依赖)：a4017f(已 consumed，owner=claude)已立 `--floating-action-reserved-bottom` CSS 变量 + 右缘堆叠约定，并假设 ea509d 在其上方堆叠。本片：① 开工前检查 App.tsx / Toast / 右下角 FAB 现状；② **复用** a4017f 的 `--floating-action-reserved-bottom`，不新增第二套变量；③ 落实用户「分占不同角」—— main launcher 用 right-edge 向上堆叠 offset(在 a4017f FAB 之上)或独立角位，二者不抢同一像素 / z-index；④ App.tsx 挂载并发冲突执行期 rebase / 人工合并。

#### 验收标准
- e2e(前端流程用 **mock WS**，避免依赖本机 main tmux)：悬浮入口 → 点击开 Modal → main claude/codex 双 pane 显实时帧 → 输入回显(默认可写 + 写入目标红字标注) → 关 Modal 断 WS。
- main 未起：descriptor 404 → MainTerminalPanel 显 fallback，不连 WS。
- Modal 滚动层：terminal 容器有**稳定非零高度**；modal content 用无 padding / 无纵向滚动变体 —— 无双滚动层回归。
- 与 a4017f FAB 共存：两入口不重叠、不抢 z-index；复用 `--floating-action-reserved-bottom`(无 main 入口时 offset 不变)。
- 后端真实协议行为由 pr2 集成测覆盖(本片前端测用 mock WS)。

#### 边界·不做项
- 不改 a4017f 入口 / 需求详情页。
- 写入沿用 pr2 的 agent-terminal WS 通道(不另起写路径)。
- 不建通用右下角 dock 框架(仅复用 a4017f 既有薄约定)。

#### 依赖·Owner
依赖：pr2-backend-ws-shared-core-audit(agent-terminal 端点/WS) + pr3-frontend-terminal-substrate(substrate)。owner：ccb_codex。
> 残余风险(回执列明)：本机多 session 前缀撞车(继承现状，不扩大)；多窗口写 main pane 交错(单人取舍，无全局锁)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-edaac0e2eed9, subtask-9cb77d12195c
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-03 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpxp7yyc6ff3ff4e15ea509d
- Section: pr4-frontend-main-launcher
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-edaac0e2eed9, subtask-9cb77d12195c

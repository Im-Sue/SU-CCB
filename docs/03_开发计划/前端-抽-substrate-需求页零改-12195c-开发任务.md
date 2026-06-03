---
doc_type: dev_task
task_id: subtask-9cb77d12195c
title: 前端·抽 substrate + 需求页零改
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxp7yyc6ff3ff4e15ea509d
section_id: pr3-frontend-terminal-substrate
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxp7yyc6ff3ff4e15ea509d.json
source_draft_hash: b83ac26ce80783efeb6d8c6b8c0dfe5c30d9aee1bc46b64a0a23dc6bd9ab5ca0
created_at: 2026-06-03T09:17:07.818Z
updated_at: 2026-06-03T10:45:03.641Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxp7yyc6ff3ff4e15ea509d","branch":"ccb/req-cmpxp7yyc6ff3ff4e15ea509d"}
---

# 前端·抽 substrate + 需求页零改

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 抽 TerminalPaneTabs/TerminalSurface/createTerminalClient+buildTerminalWsUrl+fetchTerminalDescriptor 吃 target union；SlotTerminalPanel 改薄壳传 {kind:requirement}；需求页 URL/测试/DOM 客观零变化。 |
| 需求来源 | cmpxp7yyc6ff3ff4e15ea509d |
| 本期范围 | pr3-frontend-terminal-substrate · 前端·抽 substrate + 需求页零改 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把终端的渲染/传输/寻址从硬绑 `requirementId` 抽成可按 `target` 复用的 substrate，**需求详情页行为零变化**。承接技术设计 §二/§八。本片是受保护的前端重构，**不引入任何 main 专用 UI**(在 pr4)、不动后端。

#### 任务分解(前端)
- 抽 substrate(requirement-agnostic)：
  - `TerminalPaneTabs`(claude/codex tab 切换) + `TerminalSurface`(=旧 `SlotTerminalSurface` 抽 target，xterm 渲染/粘贴/右键/写入目标标注) + `createTerminalClient` + `buildTerminalWsUrl` + `fetchTerminalDescriptor`，全部吃 `SlotTerminalTarget` 判别联合而非裸 `requirementId`。
  - `useXtermTerminal` / `SlotTerminalFrameRenderer` 零改(纯渲染)。
- `types/slot-terminal.ts` + `lib/console-api.ts`: 加 `SlotTerminalTarget` 联合 + `fetchTerminalDescriptor(target)`；requirement target 生成的 HTTP/WS URL 与旧**完全一致**。
- `SlotTerminalPanel.tsx`: 改为薄壳 —— 保留其 requirement-specific UI(已绑定/未绑定 slot、绑定动作、fallback 文案)，内部调 substrate 传 `{kind:"requirement", projectId, requirementId}`。

#### 验收标准(客观化)
- 现有 `SlotTerminalPanel` 测试**全过**。
- requirement 的 descriptor fetch URL 仍是旧 `/api/projects/:pid/requirements/:rid/slot-terminal`；WS URL/query 仍是旧 `/api/slot-terminal/ws?projectId=&requirementId=&pane=`(**字符串级一致**)。
- 需求详情页 DOM：写入目标红字标注、claude/codex 切 tab 时关旧 WS、绑定/未绑定文案 —— 行为不变。
- substrate 单测：`buildTerminalWsUrl` / `fetchTerminalDescriptor` 对 requirement target 产出旧 URL；对 agentGroup target 产出 `/api/agent-terminal/ws?group=` 形态(为 pr4 备好，但本片不挂 main UI)。

#### 边界·不做项
- 不动 xterm / FrameRenderer。
- 不新增 MainTerminalPanel / launcher(pr4)。
- 不动后端；不改 requirement 的外部 URL 契约。

#### 依赖·Owner
依赖：无(可与 pr1/pr2 并行)。owner：ccb_codex。
> 必须与 pr2 引用**同一** plan.spec_outline_md「共享协议契约」(target union / WS query / descriptor 解析规则)，避免前后端各写一套。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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
- Section: pr3-frontend-terminal-substrate
- Owner: ccb_codex
- Priority: high
- Dependencies: none

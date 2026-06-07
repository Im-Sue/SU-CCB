---
doc_type: dev_task
task_id: subtask-43f437d0744c
title: 确认初始化后自动弹出 main 终端弹窗 + fallback 显式重试
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3ifdhy0887ac1757c6c368
section_id: pr1-auto-open-main-terminal
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3ifdhy0887ac1757c6c368.json
source_draft_hash: 2d3e6026fc9074936e2ae68e9234aa39e73cc86dc07230920cecde3ef6c00184
created_at: 2026-06-07T09:54:20.114Z
updated_at: 2026-06-07T10:21:30.393Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3ifdhy0887ac1757c6c368","branch":"ccb/req-cmq3ifdhy0887ac1757c6c368"}
---

# 确认初始化后自动弹出 main 终端弹窗 + fallback 显式重试

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | ui-store 专用 open-request 通道;banner 确认成功发请求;launcher 消费(projectId 校验、消费即 clear、已开幂等);panel fallback 加「重试」(resolverEpoch);测试含集成断言(无确认 dialog/有终端 dialog/activeElement=关闭按钮)与 ready 态覆盖;验证 npm run build && npm test。 |
| 需求来源 | cmq3ifdhy0887ac1757c6c368 |
| 本期范围 | pr1-auto-open-main-terminal · 确认初始化后自动弹出 main 终端弹窗 + fallback 显式重试 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

#### 任务概述

su-oriel web 前端实现「确认初始化知识库成功后自动弹出 main agent 组终端弹窗」：ui-store 专用 open-request 通道，ProjectOnboardingBanner 确认成功后发请求，MainTerminalLauncher 消费（projectId 校验、消费即 clear），MainTerminalPanel fallback 态新增显式「重试」。改动面：4 个核心源码文件 + 相关测试 + 必要样式（如 `MainTerminalPanel.module.css`）；零新依赖；server 零改动。技术设计：`docs/03_开发计划/优化-一键初始化知识库的交互优化-c6c368-技术设计.md`（本 spec 自包含核心契约，与设计冲突时升级）。

#### 任务分解

1. `su-oriel/web/src/stores/ui-store.ts`：新增 `mainTerminalOpenRequest: { projectId: string } | null` 字段与 `requestOpenMainTerminal(projectId)` / `clearMainTerminalOpenRequest()` actions；不触碰既有 `modalOpen/modalType` 互斥机制。
2. `su-oriel/web/src/components/projects/ProjectOnboardingBanner.tsx`：`handleConfirmInit` 成功路径（`setInitJob` 之后）追加 `setConfirmOpen(false)` + `requestOpenMainTerminal(projectId)`；reject 路径不发请求；轮询/60s 超时/toast 全不动。
3. `su-oriel/web/src/components/main-terminal/MainTerminalLauncher.tsx`：新增消费 effect（声明在「selectedProjectId 变化 → setOpen(false)」effect 之后）：request 非空且 `projectId === selectedProjectId` ⇒ `loadMainState()` + `setOpen(true)`；不匹配 ⇒ 丢弃；两路均 clear；main Modal 已打开时再次请求保持幂等（`setOpen(true)` 幂等，不重置面板状态）。
4. `su-oriel/web/src/components/slot-terminal/MainTerminalPanel.tsx`：新增 `resolverEpoch` state 并纳入 descriptor fetch effect 依赖；fallback 态渲染「重试」按钮（点击 epoch+1）；失败/fallback 态不建立 websocket（surface 仅 ready 态渲染，维持现状语义）。
5. 测试（轻量，不穷举）：
   - banner spec：确认成功 → store 收到 `{projectId}`；`initProjectKnowledgeBase` reject → request 保持 null。
   - launcher spec：匹配 request → dialog 打开 + request cleared；不匹配 → 不打开 + cleared；已打开时再次 request → 仍打开且无异常（幂等）。
   - 集成断言：确认成功后无「初始化知识库」dialog、有「main agent 组终端」dialog、`document.activeElement` 为 main Modal 关闭按钮；ready 态「重新初始化知识库」同路径至少 1 条断言。
   - panel 重试：descriptor 失败 → 「重试」出现；点击 → 重新 fetch 成功 → 渲染 surface（优先扩展既有 spec 组织，必要时新增 `MainTerminalPanel.spec.tsx`）。
   - 测试卫生：涉及 ui-store 的 spec 在 afterEach reset 新增字段，防 request 泄漏污染后续用例。

#### 验收标准

- [ ] knowledge-missing 态「一键初始化知识库」与 ready 态「重新初始化知识库」确认成功后：确认弹窗关闭、「main agent 组终端」弹窗自动打开（默认 claude pane），`document.activeElement` 为弹窗关闭按钮（不触 xterm）
- [ ] `initProjectKnowledgeBase` reject：不弹终端弹窗，仅既有 error toast
- [ ] descriptor 失败/panes 空：fallback 显示「重试」，点击重新解析；重试成功进入 surface；失败态不建立 websocket；手动 M 入口路径零回归
- [ ] banner 既有 jobId 轮询/60s 超时/成功失败 toast 不变；知识库就绪后弹窗不自动关
- [ ] 验证命令通过：`cd su-oriel/web && npm run build && npm test`（targeted spec 先行，全量 web test 收尾）
- [ ] 零新依赖；server 零改动；不触碰 `modalOpen/modalType`、`AiCliPanel`、`EmbeddedTerminal`、`spawnMainTerminal`

#### 边界（不做项）

- 不自动重试 descriptor（仅显式按钮）；不在弹窗内叠加进度 UI；不自动关闭弹窗；不动实体终端按钮；不改 `Modal.tsx` / `SlotTerminalSurface.tsx`；不动 server / su-init 投递链路。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq3ifdhy0887ac1757c6c368
- Section: pr1-auto-open-main-terminal
- Owner: claude
- Priority: high
- Dependencies: none

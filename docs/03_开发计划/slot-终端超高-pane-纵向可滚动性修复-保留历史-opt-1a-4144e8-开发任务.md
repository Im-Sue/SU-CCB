---
doc_type: dev_task
task_id: subtask-c1e7ec4144e8
title: slot 终端超高 pane 纵向可滚动性修复（保留历史·Opt-1a'）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpy6y7oe23104eb766718db0
section_id: pr1-slot-terminal-vertical-scroll
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpy6y7oe23104eb766718db0.json
source_draft_hash: ae5eafde5d1f1a02c4b4402f155c9694f59e23318121af35e43fa4751f7b3056
created_at: 2026-06-04T09:44:17.151Z
updated_at: 2026-06-04T10:42:08.313Z
updated_by: ai_session
code_workspace: {"path":"../SU-CCB-req-cmpy6y7oe23104eb766718db0","branch":"ccb/req-cmpy6y7oe23104eb766718db0"}
---

# slot 终端超高 pane 纵向可滚动性修复（保留历史·Opt-1a'）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | host 外滚看全当前屏底部 + 隐藏 native 条、滚轮仲裁入历史、保留 scrollback；修共享 SlotTerminalSurface（连带 MainTerminalPanel），owner=claude，浏览器实测定稿仲裁体感。 |
| 需求来源 | cmpy6y7oe23104eb766718db0 |
| 本期范围 | pr1-slot-terminal-vertical-scroll · slot 终端超高 pane 纵向可滚动性修复（保留历史·Opt-1a'） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### pr1 slot 终端超高 pane 纵向可滚动性修复（保留历史·Opt-1a'）

#### 任务概述
修共享组件 `SlotTerminalSurface`（需求详情页 SlotTerminalPanel + main agent 组 MainTerminalPanel 复用）：左右 split 使 tmux pane 变高、`frame.rows` 翻倍后，当前屏高于固定 host、底部被裁且无可达外层滚动条。目标＝**既能滚到当前 pane 底部，又保留 xterm scrollback 上翻历史**（D3 用户拍板：历史核心）。机制定稿 **Opt-1a'**（协商 job_866cf3d43c0f）。owner=claude，web-UI 我亲自实施 + 浏览器实测定稿仲裁体感。

#### 任务分解（Opt-1a'：单一可见 host 条 + 滚轮仲裁入历史）
- **CSS（`SlotTerminalSurface.module.css`）**：`.terminalHost{overflow-y:auto}`（原 hidden）承载当前屏外滚；`.xterm{height:auto; min-height:100%}` 使 host 能滚到底；**隐藏 xterm6 原生 `.xterm-scrollable-element > .scrollbar.vertical`**（单一可见 host 条）。**保留 `scrollback`**（不置 0）。
- **renderer（`SlotTerminalFrameRenderer.ts`）**：构造增 `scrollHost?: HTMLElement`；跟随＝**双底部** `historyAtBottom && hostAtBottom`，**必须在 `resize()` 之前测**（Codex 纠正：resize 后 scrollHeight 变会误判离底）；仅双底部成立才写后条件 `terminal.scrollToBottom()` + `host.scrollTop=scrollHeight`，二者不无条件执行（否则破坏保留的历史位置）。
- **surface（`SlotTerminalSurface.tsx`）**：`new SlotTerminalFrameRenderer(terminal, containerRef.current)`；在 `.terminalHost` 挂 **capture-phase wheel 仲裁**——上滚：host 未到顶先滚 host，到顶后 `terminal.scrollLines(-n)` 入历史；下滚：历史未到底先 `scrollLines(+n)` 回 live，回 live 后滚 host 到底；**若 pane 应用启用 mouse tracking 则不强拦截**（避免破坏应用内滚动）。
- **scrollback 深度（`useXtermTerminal.ts`）**：核对 `scrollback:1000` 是否够大覆盖后端 initial capture 历史窗口；历史既为核心，必要时调大或对齐后端 capture 深度。
- **specs**：更新 `SlotTerminalFrameRenderer` spec（双底部 + resize 前测 + 条件贴底 + 缺 host 兜底）；保持现有 surface / useXtermTerminal spec 绿。

#### 验收标准
- [ ] 单测：renderer 注入 mock scrollHost + mock buffer——双底部为真（resize 前测）→ 写后 host 贴底 + scrollToBottom；任一不在底 → 不动；缺 host 退回条件 scrollToBottom 不抛。
- [ ] 回归：现有 SlotTerminalSurface 复制 / 粘贴 / 右键、useXtermTerminal spec 全绿。
- [ ] 手动·浏览器（关键验收，逐条走查，**需求详情页 + MainTerminalPanel 双场景各验**）：
  1. 左右 split 造比右栏高的 pane → **能滚到最底部**看最新输出 / prompt；
  2. **上翻历史可用** —— 滚轮 / PageUp 进历史、能看到更早输出（scrollback 未丢）；
  3. 双底部时新帧**自动贴底**；离底时**不被弹回**；
  4. 滚轮仲裁顺滑（trackpad / 快速滚动 / 缝合点不抖）；
  5. 横向滚动保留；选区复制对齐；粘贴正常；窄视口（移动端）不破。

#### 边界 / 不做项
- 不改后端 / WS 协议 / tmux resize 主权（WS READ_ONLY）。
- 不动 ai-cli `EmbeddedTerminal`（FitAddon 自适应，不在本 bug）。
- **不改 renderer 快照模型**（resize 到 pane_rows + live 帧 H+2J 全清重绘不动；不引入 stream/diff）。
- **不删 scrollback / 不砍历史**（D3 用户否决置 0）。
- 两条并存（Opt-1b）仅作 Opt-1a' 体感不佳时的快速回退，不作正式方案。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-04 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpy6y7oe23104eb766718db0
- Section: pr1-slot-terminal-vertical-scroll
- Owner: claude
- Priority: high
- Dependencies: none

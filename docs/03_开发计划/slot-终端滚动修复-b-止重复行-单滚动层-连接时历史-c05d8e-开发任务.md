---
doc_type: dev_task
task_id: subtask-d2d9a0c05d8e
title: slot 终端滚动修复（B+：止重复行 + 单滚动层 + 连接时历史）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpvdsgdf40042bda10261d73
section_id: pr1-slot-terminal-scroll-bplus
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdsgdf40042bda10261d73.json
source_draft_hash: e606d78bde6e7e6bedda7d03694f1e332b7cb5ec55a24f6c491ed4413915b3ee
created_at: 2026-06-02T08:04:41.800Z
updated_at: 2026-06-02T08:27:56.838Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdsgdf40042bda10261d73","branch":"ccb/req-cmpvdsgdf40042bda10261d73"}
---

# slot 终端滚动修复（B+：止重复行 + 单滚动层 + 连接时历史）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 后端 initial 帧 capture 带 -S -2000 历史；前端区分 initial/live 渲染并剥尾随换行止重复行、保历史、上翻不拽回；CSS 收敛为单一 xterm viewport 滚动。含实施前 commit 安全检查点。 |
| 需求来源 | cmpvdsgdf40042bda10261d73 |
| 本期范围 | pr1-slot-terminal-scroll-bplus · slot 终端滚动修复（B+：止重复行 + 单滚动层 + 连接时历史） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述
修复需求详情页内嵌 slot 终端（SlotTerminalPanel → SlotTerminalSurface，xterm.js 快照重绘模型）的两处滚动缺陷：①向上翻重复行/重复内容；②多层滚动条 + 有时只显当前屏无法上翻。方向 B+：干净实时当前屏 + 可上翻读最近 ~2000 行历史。

> ⚠️ 实施前安全检查点（用户硬性要求）：先 `git status` 确认工作树，提交当前版本（commit message：`chore(slot-terminal): checkpoint before scroll bugfix`），再开始改动。

### 任务分解
#### 1) 后端 — initial 帧带历史（slot-terminal.frame-stream.ts）
- capturePane 现不区分 initial/live；需把"是否首帧"透传进 capture：在 frame-stream.ts:186 capture 调用处，按"即将成为首帧（generation===0）"传 initial 标志给 capture backend。
- TmuxSlotTerminalFrameCapture.capturePane：initial 时历史范围 `-S -2000` 加在 `"capture-pane"` **之后**（现有 `["-S", socketPath]` 是 tmux 全局 socket flag、在子命令**之前**，勿混淆）：`tmux -S <socket> capture-pane -S -2000 -p -e -t <pane>`；live 帧保持只抓可见屏。
- 维持 active 150ms / idle 1s 节奏；仅首帧体积变大。

#### 2) 前端渲染 — 区分 initial/live（SlotTerminalFrameRenderer.ts）
- initial 帧：历史快照一次性写入（成为 xterm scrollback），**剥掉尾随换行**避免 baseY 堆叠。
- live 帧：继续 `\x1b[H\x1b[2J` + 当前屏快照重绘，但**剥掉尾随换行**（Codex 探针证实可止住重复行；`\x1b[2J` 不清 scrollback，上方历史保留）。
- 滚动跟随：用户停底部时 live 自动跟随；用户已上翻时**不被写入拽回底部**（按是否在底部再决定 follow，避免 term.write 强拽）。

#### 3) 前端布局 — 单一滚动层 = xterm viewport
- `.terminalHost` 改 `overflow:hidden`；`.xterm` 改 `width:100%;height:100%`（去掉 `height:auto;inline-block`），让 xterm 自身 viewport 作唯一滚动条（外层 DOM 滚动无法展示 xterm 虚拟渲染的 scrollback）。
- 去掉 `RequirementDetailPage.module.css` `.terminalColumn` 的 `overflow:auto`；保留其 sticky，但压实 `surfaceWrap`/surface 高度约束，确保内容不溢出右栏。

### 验收标准
- 向上翻**无重复行/重复内容**；
- 终端**只有一层滚动条**（xterm viewport）；
- 打开/重连终端后向上翻**可读最近 ~2000 行历史**；
- live 实时输出仍正常刷新（active 150ms），**停底部自动跟随、上翻不被拽回**；
- 不破坏输入/粘贴/复制语义；
- `pnpm --filter ccb-console-web test` 通过；若 `slot-terminal-substrate.spec.ts:155`（保留 `中文\n` 期望）与"剥尾随换行"冲突，同步更新该期望并在 PR 说明。

### 边界 / 不做项（含已知限制）
- **已知限制（B+ 本实现的诚实边界）**：上翻读到的是**打开/重连时抓到的最近 ~2000 行**；**不承诺** live 运行期间持续累积完整 scrollback —— 会话进行中滚出的内容可能在本地历史缺失。若实测需要"运行中持续维护最近历史"，属后续 B++（需 diff/append 或周期历史同步），不在本任务。
- 不做 A：不改流式/增量协议、不重设计帧模型。
- 不改 resize 语义（仍 READ_ONLY、尺寸主权 tmux pane）。
- 历史窗口固定 ~2000 行，不做可配置 UI。
- 深度/完整历史仍由 ccb 原生 sidebar 兜底。

### 依赖
无（单一原子子任务；后端首帧历史与前端首帧渲染是同一行为的两半，须端到端一起验收，不拆分）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-02 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpvdsgdf40042bda10261d73
- Section: pr1-slot-terminal-scroll-bplus
- Owner: ccb_codex
- Priority: high
- Dependencies: none

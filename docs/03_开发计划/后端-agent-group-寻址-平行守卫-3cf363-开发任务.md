---
doc_type: dev_task
task_id: subtask-02d1b93cf363
title: 后端·agent-group 寻址 + 平行守卫
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxp7yyc6ff3ff4e15ea509d
section_id: pr1-backend-agent-group-resolver
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxp7yyc6ff3ff4e15ea509d.json
source_draft_hash: b83ac26ce80783efeb6d8c6b8c0dfe5c30d9aee1bc46b64a0a23dc6bd9ab5ca0
created_at: 2026-06-03T09:17:07.818Z
updated_at: 2026-06-03T10:10:42.342Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxp7yyc6ff3ff4e15ea509d","branch":"ccb/req-cmpxp7yyc6ff3ff4e15ea509d"}
---

# 后端·agent-group 寻址 + 平行守卫

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增 resolveAgentGroupTerminal(allowlist{main}+候选层 strict role 唯一性/agent 名校验)+assertTargetBelongsToAgentGroup+matchPane+GET /agent-terminal/:group；requirement 路径首选语义零改。 |
| 需求来源 | cmpxp7yyc6ff3ff4e15ea509d |
| 本期范围 | pr1-backend-agent-group-resolver · 后端·agent-group 寻址 + 平行守卫 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
后端新增「按 agent-group(仅 main)寻址」的终端 descriptor 解析与平行写入守卫，复用 main 的 tmux pane 解析，但**不污染**现有 requirement 路径。承接技术设计 `main-agent组终端快捷入口-ea509d-技术设计.md` §三/§七/§八。本片只动 service + routes，不动 ws/input（在 pr2）。

#### 任务分解(后端)
- `slot-terminal.service.ts`:
  - 抽内部候选解析 helper（如 `collectPaneCandidatesByRole`）：返回每 role 的**全部**候选 pane（**不在此处 break 去重**），让 requirement 路径与 agent-group 路径共用底层 list-panes + runtime.json 解析。
  - `resolveRequirementTerminal` / `resolveSlotPanes` 保持**首选(first-pick)**语义不变 —— requirement 路径行为零变化（现有测试全过）。
  - 新增 `resolveAgentGroupTerminal({projectId, group})`：① `group` 过 `AGENT_GROUP_WINDOWS={"main"}` allowlist，非 main 抛 forbidden；② `findProject`；③ 用候选 helper 取 main(window_name="main")的候选 pane；④ **strict 校验**：每 role(claude/codex)恰一候选 pane，>1 或缺失即抛 —— 这是「role 唯一性拒多 runtime」的真实落点（**不能在 descriptor 层校**，因为首选语义已把重复吞掉）；⑤ 校验候选 runtime agent 身份(window_name="main" + provider，且 runtime agent_name ∈ {main_claude, main_codex})；⑥ 返回 `{slotId:"main", sessionName, panes:[claude,codex]}`(复用 `SlotTerminalDescriptor` 类型)。
  - 新增 `assertTargetBelongsToAgentGroup({projectId, group, role, target})`：重解析 agent-group descriptor，比对 `target ∈ panes`(role+target 双匹配)，不符抛 forbidden。
  - 抽私有 `matchPane(descriptor, role, target)` 供 requirement / agent-group 两守卫共用。
- `slot-terminal.routes.ts`: 新增 `GET /api/projects/:projectId/agent-terminal/:group` → `resolveAgentGroupTerminal`。

#### 验收标准
- 单测 `resolveAgentGroupTerminal`：① 非 main group 被 allowlist 拒；② main window 出现 >1 个 claude(或 codex)runtime 时 strict 校验**抛错**（用候选 helper 在去重前校验，证明非 descriptor 层假校验）；③ 正常 main 解析出 claude/codex 两 pane(target=runtime pane_id)。
- 单测 `assertTargetBelongsToAgentGroup`：不属于 main panes 的 target 抛 forbidden；合法 target 返回 pane。
- 回归：`resolveRequirementTerminal` / `resolveSlotPanes` 行为不变 —— 现有 slot-terminal service 单测全过(first-pick 语义保留)。
- 集成：`GET /agent-terminal/main` 返回 descriptor；`GET /agent-terminal/<非 main>` 被拒。

#### 边界·不做项
- 不动 `slot-terminal.ws.ts` / `slot-terminal.input.ts`(pr2)。
- 不改 requirement 路由 / resolver 的首选语义。
- 不开放任意 window 浏览(allowlist 仅 main)。
- 只 capture-pane / send-keys 语义；本片不实际写入(守卫供 pr2 用)。

#### 依赖·Owner
依赖：无。owner：ccb_codex。
> 协议契约见 plan.spec_outline_md「共享协议契约」，pr2/pr3/pr4 引用同一份。

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
- Section: pr1-backend-agent-group-resolver
- Owner: ccb_codex
- Priority: high
- Dependencies: none

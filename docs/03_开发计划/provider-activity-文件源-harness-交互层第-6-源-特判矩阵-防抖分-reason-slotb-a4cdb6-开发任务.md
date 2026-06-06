---
doc_type: dev_task
task_id: subtask-89e538a4cdb6
title: provider-activity 文件源(harness 交互层第 6 源):特判矩阵 + 防抖分 reason + SlotBinding 抑制 + ref 降级链 + main agents
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzoupdv863041443e52441f
section_id: pr3-provider-activity-source
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-0a2de3c63343]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: db12930dd087b69323ede0b4e05130f3d45a5ba88574794f6e8df3d6994729f6
created_at: 2026-06-06T15:34:39.688Z
updated_at: 2026-06-06T17:08:37.868Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# provider-activity 文件源(harness 交互层第 6 源):特判矩阵 + 防抖分 reason + SlotBinding 抑制 + ref 降级链 + main agents

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | [NEW] provider-activity.source.ts:ccb.config slot↔agent 映射 + 逐 agent 读 activity.json;权限框/选项框/计划批准/等输入/failed 特判;SlotBinding 状态显式抑制;ref 降级链(末级 TTL 防抖);防抖分 reason;main_claude/main_codex waiting+完成(active≥60s→idle 一次,in-memory 前态);依 pr1 smoke 结论走主路径或 agent_attention_suspect fallback;接入 computeAttention 第 6 源。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr3-provider-activity-source · provider-activity 文件源(harness 交互层第 6 源):特判矩阵 + 防抖分 reason + SlotBinding 抑制 + ref 降级链 + main agents |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把「agent 正在等你」从 tmux 窗格里捞出来:只读消费 CCB runtime activity 工件,零 migration、不改 runtime 本体。依据技术设计 §三 harness 交互层/§四 ProviderActivity 分支/§十 main agents 拍板。本 PR 逻辑密度最高,单测矩阵是验收核心。

#### 任务分解
1. **读 pr1 回执 smoke 结论定分支**:成立→主路径;不成立→fallback(`agent_attention_suspect`:SlotBinding.busy + 已派 job + activity 长时间无进展 → severity=warning 不主动弹),并在回执标注设计修订与「触达降级需用户知晓」。
2. **[NEW] `server/src/modules/attention-inbox/provider-activity.source.ts`**:解析 `.ccb/ccb.config` slot↔agent 映射——优先复用 managed-config 常量/现有解析片段;经核验 su-oriel 无 exported slot↔agent parser,如确认缺失则在 attention-inbox 内新增小型 `[windows]`/`[agents]` scoped parser(用真实 ccb.config 样例做测试覆盖,不引入完整 TOML 引擎)→ 逐 agent 读 `.ccb/agents/<agent>/provider-runtime/<provider>/activity.json`(只读;文件缺失/损坏静默跳过)。
3. **特判矩阵**:`state==pending` → agent_waiting(reason=permission|input);`event_name==PreToolUse` 且 `diagnostics.tool_name∈{AskUserQuestion, ExitPlanMode}` → agent_waiting(reason=question|plan);Notification idle 60s → pending(等输入);`state==failed` 且 slot∈{bound,busy} → agent_failed(runtime sticky 语义)。
4. **抑制规则**:SlotBinding∈{unhealthy, recovering, draining, released} 显式压掉该 slot 的 agent_waiting(让位 slot 健康 attention);无绑定模型的 slot(如 slot-4)跳过。
5. **ref 降级链**:`provider_activity:<agentName>/<provider_session_id>/<reason>` → provider_turn_id → ccb_session_id → agentName+provider+reason(末级必配 TTL 防抖);completed 类 ref 追加 idle updated_at 区分批次。
6. **防抖分 reason**:permission/question/plan 首次 poll 即报;input(idle)/flap 走 10s 防抖(in-memory)。
7. **main agents(main_claude/main_codex,用户拍板纳入)**:waiting 同 slot 规则;完成=state 由 active 持续 ≥60s 转 idle → 产生一次 agent_completed(in-memory 前态跟踪,与防抖同机制);cta 退化为窗口聚焦/项目页;sidebar 仍 slot-keyed 不投 main(pr4 不变)。
8. **接入 `computeAttention` 第 6 源**(types 已在 pr1 定稿,不改动 pr2 已消费契约字段)。
9. 单测矩阵(见验收)。

#### 验收标准
- [ ] 特判矩阵单测全覆盖(permission/question/plan/input/failed 各至少 1 正 1 反例);文件缺失/损坏静默跳过不抛错。
- [ ] 同 session 同 reason ref 跨多次 derive 稳定不重复弹;ack 后旧 item 不复活。
- [ ] 防抖分 reason 正确(permission 首 poll 即报;input/flap 10s 内不报);抑制规则生效(unhealthy 等 4 态压掉 agent_waiting)。
- [ ] main 完成:active≥60s→idle 仅产生一次;<60s 短对话不产生;**冷启动直接见 idle 不产生 completed**;**进程重启丢 in-memory 前态后不误报**(idle-only 不算完成)。
- [ ] fallback 分支(若启用):suspect 仅 severity=warning,不进主动弹候选(测试佐证)。
- [ ] server typecheck/lint/test 过;task SSE 回归不受影响。

#### 边界 / 不做
- 不改 CCB runtime 本体/hook 分类(跨仓,设计已排除);不写 activity.json;不做 runtime 分类上游卫生项;不动 pr2 已消费的 AttentionItem 契约字段。

#### 依赖 / 执行注意
- 逻辑依赖 **pr1**(types/service 框架 + smoke 结论);dependencies 字段指向 pr2 仅编码全串行执行顺序(共享触点决策),pr2 不提供本任务的代码输入。in-memory 前态重启丢失是设计接受的 best-effort(§十风险表),验收只要求「丢失后不误报」。su-oriel submodule 流程同前。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-0a2de3c63343
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
- Section: pr3-provider-activity-source
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-0a2de3c63343

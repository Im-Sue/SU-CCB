---
doc_type: dev_task
task_id: subtask-6bc47408a7f3
title: attention-inbox 后端核心:公共 severity helper + 小 migration + 业务 5 源批量 derive + ack/DND + routes + codex pending smoke
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzoupdv863041443e52441f
section_id: pr1-attention-core
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: db12930dd087b69323ede0b4e05130f3d45a5ba88574794f6e8df3d6994729f6
created_at: 2026-06-06T15:34:39.688Z
updated_at: 2026-06-06T16:24:58.316Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# attention-inbox 后端核心:公共 severity helper + 小 migration + 业务 5 源批量 derive + ack/DND + routes + codex pending smoke

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 抽公共 attention severity/type helper(task-event-view 行为不变);新增 AttentionAck + ProjectAttentionSettings 两张极小表(1 个 migration);[NEW] attention-inbox 模块实现 computeAttention 业务 5 源批量 derive + left-anti-join ack + DND 过滤;list/ack/settings 三组 API;末步零代码 codex pending smoke 出结论供 pr3 分支。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr1-attention-core · attention-inbox 后端核心:公共 severity helper + 小 migration + 业务 5 源批量 derive + ack/DND + routes + codex pending smoke |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
落地单一 attention 源的后端核心:内容 derive 不物化、仅持久化 ack/DND 极小状态。依据技术设计 §二/§四/§六/§七/§八。这是全需求的 contract 定稿点——AttentionItem types(kind 6 源全集 + `agent_attention_suspect` 预置、severity attention/warning/info)在本 PR 一次定稿,后续 PR 不得改动已消费契约字段。

#### 任务分解
1. **抽公共 severity/type helper**:把 `server/src/modules/task-event-view/task-event-view.service.ts:33` 的内部 severity 映射抽为公共 helper(落 attention-inbox 模块或 shared 层),task-event-view 改为引用,行为不变(回归测试佐证);AttentionItem/AttentionKind/severity types 定稿于 `attention-inbox.types.ts`。
2. **Prisma migration(1 个)**:`AttentionAck(id, projectId, ref, ackedAt, @@unique([projectId, ref]), @@index([projectId, ackedAt]), Cascade)` + `ProjectAttentionSettings(projectId unique, dndUntil DateTime?, ...)`。采 draft 决策①:独立表,不触碰 ProjectSettings strict payload schema/service/web types。
3. **[NEW] `server/src/modules/attention-inbox/attention-inbox.service.ts`**:`computeAttention(projectId)` 并行批量查业务 5 源——ReviewIntent[pending] / ConsultRequest[pending](无 projectId,经 task join,参考 `tasks/pending-interactions.service.ts:79` 既有映射但改批量)/ Document[kind=dev_task].approval_records+pending_user_decision / EventJournal[type∈{codex_receipt_ready, codex_rejected, state_write_conflict, anchor_dispatch_failed}, 近窗口] / SlotBinding[state∈{unhealthy, recovering}] → projector 映射(source-native ref:`review_intent:<id>`|`consult_request:<id>`|`event_journal:<eventId>`|`dev_task_approval:<taskKey>/<ref>`|`slot_binding:<slotId>/<state>`)→ left-anti-join AttentionAck → DND(dndUntil)过滤 → severity desc+time 排序。
4. **[NEW] `attention-inbox.projector.ts` / `attention-inbox.routes.ts` / `attention-inbox.types.ts` / `*.spec.ts`**:GET `/api/projects/:projectId/attention`、POST `.../attention/ack`(upsert 幂等)、GET/PUT `.../attention/settings`(DND 读写);`app.ts` 注册。
5. **零代码 codex pending smoke(可与 1-4 并行,结论必须入回执)**:真实 codex slot(approvals_reviewer=user)触发 PermissionRequest → 观察 `.ccb/agents/<agent>/provider-runtime/codex/activity.json` 是否出现 `state=pending`。成立→pr3 主路径;不成立→pr3 启用 fallback(`agent_attention_suspect`,severity=warning 不主动弹),并在回执标注「需升级用户:codex 等 approval 触达降级」。
6. 单测+集成(见验收)。

#### 验收标准
- [ ] computeAttention 批量查询无 N+1;ConsultRequest 经 task join 正确纳入。
- [ ] ack 后该 ref 从 derive 结果消失;未 ack 保留;DND 窗口内全部抑制;ack upsert 幂等(重复 ack 同 ref 不报错)。
- [ ] source-native ref 同一源对象跨两次 derive 不变;severity 分级正确(仅 attention 级进主动弹候选)。
- [ ] task-event-view 抽 helper 后既有行为回归不变;task 级 `/api/tasks/:taskId/events` SSE 与订阅者不受影响。
- [ ] migration 在干净库与存量 dev 库均可应用;不触碰 ProjectSettings 现有 schema/service/web types。
- [ ] smoke 结论(state=pending 成立与否 + 证据片段)落入回执。
- [ ] server typecheck/lint/test 过。

#### 边界 / 不做
- 不含 provider-activity 文件源(pr3)、web UI(pr2)、sidebar(pr4)、SSE stream(P1);不动 EventJournal 写入侧与 plugin 主权边界(ack 不入 EventJournal)。

#### 依赖 / 执行注意
- 无前置依赖。su-oriel 是 submodule,按既有需求 worktree 流程;勿在主仓跑 server test(db:prepare 清 dev.db)。EventJournal 4 类中 state_write_conflict / anchor_dispatch_failed 为低频硬信号(用户已拍板进首批)。

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

- Requirement: cmpzoupdv863041443e52441f
- Section: pr1-attention-core
- Owner: ccb_codex
- Priority: high
- Dependencies: none

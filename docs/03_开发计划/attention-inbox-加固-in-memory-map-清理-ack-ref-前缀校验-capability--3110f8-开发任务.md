---
doc_type: dev_task
task_id: subtask-50c6673110f8
title: attention-inbox 加固:in-memory Map 清理 + ack ref 前缀校验 + capability policy TS 重生
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzoupdv863041443e52441f
section_id: pr7-attention-inbox-in-memory-map-ack-ref-capability
order: 7
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: 329a0b40666b0e02adc5a28a1b19737d1dabb8d587439989e2b8192fe1a292fe
created_at: 2026-06-07T03:43:14.072Z
updated_at: 2026-06-07T04:10:09.594Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# attention-inbox 加固:in-memory Map 清理 + ack ref 前缀校验 + capability policy TS 重生

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | pr1/pr3 review 留档风险闭环(su-oriel,分支 ccb/req-52441f-attention 续作,依赖上一 follow-up 的 kernel 变更先合入 plugin):① provider-activity.source 的 completedItems 按 ack 集合清理——computeAttention 已拿到 ackRows,把已 ack 的 completed ref 从 Map 删除;安全性依据:ref 含 idle updated_at 且 mainAgentState 前态为 idle 时 projectMainCompletion 不会重新产生,无『历史 completed 消失』新语义;② debounceFirstSeen 按最后访问时间 TTL 清理(条目 >10min 未访问即删,防 fallback ref 的 10min bucket 键空间无界增长);③ attention-inbox.routes 的 POST ack 对 ref 加 source-native 前缀白名单(review_intent:\|consult_request:\|event_journal:\|dev_task_approval:\|slot_binding:\|provider_activity:),非法 ref 返回 400(闭合 pr1 review Q4 脏 ref 风险);④ 上一 follow-up 的 kernel delivering 条目落地后,重生 server/src/generated/capability-outcome-policy.ts(generate:capability-policy,注意确认脚本读取的 kernel 路径指向已更新的 plugin 副本)并对齐相关测试;⑤ 单测:ack 后 completedItems 条目消失且不复活、debounce TTL 过期清理、ack ref 白名单正反例、重生产物与 kernel 一致。边界:不动 AttentionItem 已消费 contract 字段;不引入 LRU 封顶(按 ack/TTL 语义化清理);不碰 task SSE。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr7-attention-inbox-in-memory-map-ack-ref-capability · attention-inbox 加固:in-memory Map 清理 + ack ref 前缀校验 + capability policy TS 重生 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### attention-inbox 加固:in-memory Map 清理 + ack ref 前缀校验 + capability policy TS 重生

> 派生自:task cmq2ikpmc0g6bqrplkujd4tue(subtask-89e538a4cdb6)

#### Follow-up

- Type: subtask
- Description: pr1/pr3 review 留档风险闭环(su-oriel,分支 ccb/req-52441f-attention 续作,依赖上一 follow-up 的 kernel 变更先合入 plugin):① provider-activity.source 的 completedItems 按 ack 集合清理——computeAttention 已拿到 ackRows,把已 ack 的 completed ref 从 Map 删除;安全性依据:ref 含 idle updated_at 且 mainAgentState 前态为 idle 时 projectMainCompletion 不会重新产生,无『历史 completed 消失』新语义;② debounceFirstSeen 按最后访问时间 TTL 清理(条目 >10min 未访问即删,防 fallback ref 的 10min bucket 键空间无界增长);③ attention-inbox.routes 的 POST ack 对 ref 加 source-native 前缀白名单(review_intent:|consult_request:|event_journal:|dev_task_approval:|slot_binding:|provider_activity:),非法 ref 返回 400(闭合 pr1 review Q4 脏 ref 风险);④ 上一 follow-up 的 kernel delivering 条目落地后,重生 server/src/generated/capability-outcome-policy.ts(generate:capability-policy,注意确认脚本读取的 kernel 路径指向已更新的 plugin 副本)并对齐相关测试;⑤ 单测:ack 后 completedItems 条目消失且不复活、debounce TTL 过期清理、ack ref 白名单正反例、重生产物与 kernel 一致。边界:不动 AttentionItem 已消费 contract 字段;不引入 LRU 封顶(按 ack/TTL 语义化清理);不碰 task SSE。
- Source task title: provider-activity 文件源
- Source task current node: archive

#### Acceptance

- Deliver the follow-up without changing unrelated requirement scope.
- Keep the source task provenance visible in the implementation receipt.

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

- Requirement: cmpzoupdv863041443e52441f
- Section: pr7-attention-inbox-in-memory-map-ack-ref-capability
- Owner: ccb_codex
- Priority: high
- Dependencies: none

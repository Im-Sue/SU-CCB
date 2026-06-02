---
task_id: subtask-8a83b2432463
title: P3a 清 legacy 活引用·web
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmppm45yt09j35fx6e2
section_id: pr5-clear-refs-web
order: 5
implementation_owner: claude
dependencies: [subtask-a9771860331c]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T16:00:00.000Z
updated_by: ccb_claude
---

# P3a 清 legacy 活引用·web

> 一句话:把前端对旧分类/死代码/spec 概念的引用清掉,followup provenance 换到 P1 的 payload。

## 范围
- 删 kind 过滤 legacy 值、outputMode 标签、"生成 Spec/Plan/Task"文案、`generate` job 类型、死 epic/Timeline 代码、3 个空页面目录(anchors/ai-sessions/anchor-terminal-recordings)。
- followup provenance 展示从 `sourceTaskId` 换成 P1 注入的 payload provenance(`DerivedFollowupsCard`/`UnstartedRequirementStrip`)。
- 清 code enum `spec_only`/`spec_plan_task`(types / UI label)。

## 触及
web:`types` / `lib/ui-mapping` / `components`

## 验收
- [x] outputMode 收窄到 requirement_only(删 spec_only/spec_plan_task 标签+预览)、删"生成 Spec/Plan/Task"文案、删 TimelinePage(epic 死页)+ 3 空目录、清 linked*/parentEpicId/epicStatus/materializationState 死字段
- [x] followup provenance:`DerivedFollowupsCard` 保留派生入口 + deriveFollowup 对齐 pr1 dispatch 返回;不再读 sourceTaskId(`UnstartedRequirementStrip` 去 source tab/chip)
- [x] web 构建通过(typecheck 绿 + 220 测试绿,e12 snapshot 重生成)
- 注:doc-kind 过滤重列归 pr7;可投影"派生自 task X"列表是 pr8 延后增强

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr5-clear-refs-web ｜ Owner: claude(web UI/UX)｜ Priority: medium ｜ Deps: pr1-truth-flow

## 审查结论(2026-05-29 · Claude 自实施 + 自验)
- **已交付**:`types` 收窄 `outputMode→requirement_only`、删 `sourceTaskId`/`linked*`/`parentEpicId`/`epicStatus`/`materializationState`;`ui-mapping` 删 spec 标签 + 预览 spec 分支;`console-api` `deriveFollowup` 响应对齐 pr1 dispatch(`kind:"dispatch"`)、`createRequirement` 不再带 sourceTaskId;`RequirementsPage` 文案改写;删 `TimelinePage`(epic 甘特死页,用户确认删)+ 路由/命令入口 + 3 空页面目录。
- **DerivedFollowupsCard 纠偏保留**:它的"+ 衍生"是 derive_followup 活入口(接 pr1/pr8 链),保留 + `handleConfirm` 对齐 dispatch;仅去掉靠 `sourceTaskId`/`parentEpicId` 的死列表(新模型恒空),换占位提示。`UnstartedRequirementStrip` 同理去 source tab/chip、留草稿列表。
- **验证**:web `tsc --noEmit` 绿;220 测试绿(41 文件);e12 snapshot 重生成 diff 仅 DerivedFollowupsCard 占位文案,干净。-867/+94 行。
- **边界**:doc-kind 过滤重列(plan/task/state/decision/template badge)留 pr7;可投影"派生自 task X"关系(dev_task frontmatter + 投影)是 pr8 延后的独立增强。`.ccb/ccb.config`(用户配置)未动。

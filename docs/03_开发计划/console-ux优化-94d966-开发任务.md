---
task_id: subtask-58b39b94d966
title: P4 UX 优化·web
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: low
requirement_id: cmppm45yt09j35fx6e2
section_id: pr7-ux
order: 7
implementation_owner: claude
dependencies: [subtask-70d16386a0b0, subtask-8a83b2432463]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T17:00:00.000Z
updated_by: ccb_claude
---

# P4 UX 优化·web

> 一句话:对齐完真相后,把界面分类/导航/概览打磨到位。

## 范围
- Documents kind 过滤按新 doc_type 重列:requirement / technical_design / dev_task / adr / architecture / index。
- 导航 `/tasks` + `/reconcile` 可见性确认(默认保留隐藏,需求详情页为主台)。
- Overview:基线已由 Claude 接手 + 项目级 drift 簇收口(2026-05-29 完成,见 pr3 审查结论);此 PR 仅剩按需视觉打磨。

## 触及
web:`DocumentsPage` / 导航 / `OverviewPage`

## 验收
- [x] Documents 分类反映新 doc_type(requirement/technical_design/dev_task/architecture/adr/module_spec/lessons + 其他),无 legacy 值;ui-mapping badge map 同步重列
- [x] 导航可见性:`/tasks` + `/reconcile` 已 `hidden:true`(需求详情页为主台),确认无需改
- [x] Overview 接手完成 + pr3 延后的 drift 簇清除(staleStateCount*/refresh-stale 端点/stale 板/Overview 卡/state-projection 整删,2026-05-29)

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr7-ux ｜ Owner: claude(web UI/UX)｜ Priority: low ｜ Deps: pr4-clear-refs-server, pr5-clear-refs-web

## 审查结论(2026-05-29 · Claude 自实施 + 自验)
- **Documents kind 重列**:`DocumentsPage` filterOptions/KNOWN_KINDS + `ui-mapping` BADGE_MAP/`getDocumentKindBadge` 按契约 doc_type 重列(requirement / technical_design / dev_task / architecture / adr / module_spec / lessons / doc_map / project_overview / archive_index / index),删 legacy plan/task/state/decision/template。
- **导航**:Sidebar `/tasks` + `/reconcile` 已 `hidden:true`(`visibleItems` 过滤),符合"默认隐藏、需求详情页为主台",无需改。
- **Overview/drift**:已在 `d8b24f1` 完成(见 pr3 审查结论)。
- **验证**:web `tsc --noEmit` 绿 + 220 测试绿;e12 snapshot 重生成 diff 仅过滤 chips 重列 + 1 个 legacy state-kind fixture doc badge 转 "其他",干净。

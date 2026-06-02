---
task_id: subtask-a784bfb38afc
title: indexer 自动索引 + inferDocumentKind 读契约
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmv55uy7d2673077860d06a
section_id: pr3-indexer-auto-index
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmv55uy7d2673077860d06a.json
source_draft_hash: 01dfecb840056c326d6941e7eeff491092f48e444bb712c9c079fab6163441af
created_at: 2026-05-27T12:57:49.805Z
updated_at: 2026-05-28T14:16:42.343Z
updated_by: ccb_claude
---

# indexer 自动索引 + inferDocumentKind 读契约

## B1 indexer 自动索引
- inferDocumentKind 改读目录契约(不靠路径子串);docs/02_需求设计 正确识别
- 扫各文档 frontmatter → 生成 00_文档地图(派生:位置+绑定实体状态)
- 生成 .ccb/index 缓存;移除对 4 个旧 yaml 的依赖
- 产出:indexer 改造 + 索引生成 + 测试

## Materialization Context

- Requirement: cmpmv55uy7d2673077860d06a
- Section: pr3-indexer-auto-index
- Owner: ccb_codex
- Priority: high
- Dependencies: none

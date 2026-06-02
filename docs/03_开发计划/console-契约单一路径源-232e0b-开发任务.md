---
task_id: subtask-9a6906232e0b
title: P1 契约成唯一路径源
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmppm45yt09j35fx6e2
section_id: pr2-contract-single-source
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T09:00:00.000Z
updated_by: ccb_claude
---

# P1 契约成唯一路径源

> 一句话:indexer 不再到处写死路径,全走目录契约 resolver。

## 范围
- `project-indexer` / `document-parser` 所有 docs 路径走 `docs-structure-resolver`,删 `docs/03_…`、`docs/02_…` 等写死字面量。
- 兑现 `docs-structure-contract.yaml` 声明的 consumers(契约成为路径的唯一来源)。

## 触及
server:`indexer/project-indexer` / `document-parser` / `docs-structure-resolver`

## 验收
- [ ] indexer/parser 无写死 docs 路径字面量,全部经 resolver
- [ ] 改 docs-structure-contract.yaml 的目录映射后,indexer 行为随之改变(契约生效验证)
- [ ] server 测试绿

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr2-contract-single-source ｜ Owner: ccb_codex ｜ Priority: high ｜ Deps: 无

## 审查结论(2026-05-29 · Claude)
- **接受**(job_5246a0d221eb):`docs-structure-resolver` 扩成项目级契约 resolver(human root / machine layer / legacy .ccb 识别 / mtime 缓存);`document-parser` / `project-indexer` 所有 docs 路径走 resolver。独立 rg 核验:无 `docs/0X_`、`docs/99_`、`docs/.ccb` 硬编码;新增 indexer-merge 测试验证随契约改路径。typecheck 绿,vitest 555 passed。
- 与 pr1 同改 `project-indexer.ts`,纠缠,合并入 **P1 server 批次**一起提交。

---
doc_type: dev_task
task_id: subtask-34e5b2ee6740
title: PR1:breakdown-draft schema fail-loud(+review_history 修正)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpqlbcw1e06bb166ae00d341
section_id: pr1-bd-schema-failloud
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqlbcw1e06bb166ae00d341.json
source_draft_hash: 32e6a56cb823328e84ea9f34bfe908d10c9a5bd77910b4943f2f9fb857c69576
created_at: 2026-05-29T09:38:09.240Z
updated_at: 2026-05-29T13:00:10.764Z
updated_by: ccb_claude
---

# PR1:breakdown-draft schema fail-loud(+review_history 修正)

## 目标
breakdown-draft schema fail-loud:`generation_source` 拒未知键(堵 `note` 死字段),并修 `review_history` required 漂移。源头改 + codegen,不手改产物。

## 范围
- `[MODIFY] su-ccb-claude-plugin/references/kernel/schemas/breakdown-draft.schema.yaml`:`generation_source` 增 `allowed_keys: [cc_agent, cx_agent, ccb_job_id, manual_actor]`;把 `review_history` 从 root.required 移除(对齐 root kernel `required:false`)。
- `[MODIFY] scripts/generate-schema-validators.mjs:213` object 分支支持 `allowed_keys`,未知键报错路径如 `generation_source.note`;重生成 plugin + console 双产物(`:289`)。
- `[MODIFY] lib/runtime/schema-validate.mjs:170`:校验四已知键前枚举 `Object.keys(generation_source)`,未知即 issue;`review_history` 改"存在时必须数组"。
- `[CLEANUP]` 先删 2 存量 `generation_source.note`(`cmpmwkb1ufac6cfd676fc4f42.json:12`、`cmpmwpuy8765c189497e7489a.json:12`),作为本 PR 第一个 commit(收紧前清,否则 read 锁死)。

## 验收
- generated + runtime + console 三处均拒 `generation_source.note` 并指明路径;合法四键通过。
- `review_history` 缺省通过;`review_history[].note` 仍通过(不可误伤)。
- 清洗后 2 存量 draft 可正常 read/update/scan,`breakdownDraftPath` 正常投影。
- `pnpm run generate:validators` 后产物无手改残留;`pnpm run lint:schema-ownership` 绿;相关 vitest 全绿。

## 边界
- 只动 `generation_source` 未知键 + `review_history` required;不碰其它字段、不改业务逻辑。

## 依赖
无(基础片,可立即合)。

## Materialization Context

- Requirement: cmpqlbcw1e06bb166ae00d341
- Section: pr1-bd-schema-failloud
- Owner: ccb_codex
- Priority: high
- Dependencies: none

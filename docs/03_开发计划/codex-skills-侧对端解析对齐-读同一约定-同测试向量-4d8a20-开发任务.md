---
doc_type: dev_task
task_id: subtask-42a4674d8a20
title: codex-skills 侧对端解析对齐(读同一约定 + 同测试向量)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpmlnqxd02346a524ec5c98f
section_id: pr3-codex-skills-peer
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-d1a5fed3a615]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmlnqxd02346a524ec5c98f.json
source_draft_hash: 9750cbc128d65b47876a065db851dadc30e5d3d63952966e447b861637086a82
created_at: 2026-05-31T12:06:01.567Z
updated_at: 2026-06-01T06:51:39.206Z
updated_by: ai_session
---

# codex-skills 侧对端解析对齐(读同一约定 + 同测试向量)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | Codex 侧读同一 kernel 约定实现对端解析,用与 PR1 相同测试向量对齐行为;不承诺共享同一 JS。 |
| 需求来源 | cmpmlnqxd02346a524ec5c98f |
| 本期范围 | pr3-codex-skills-peer · codex-skills 侧对端解析对齐(读同一约定 + 同测试向量) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标

Codex 侧对端解析与 Claude 侧行为对齐,避免漂移;不硬凑共享同一份代码。

### 范围(codex-skills,含测试/示例)

- [MODIFY/NEW] su-ccb-codex-skills:Codex 侧读 PR1 同一份 kernel 约定实现'同组对端'解析;维护与 PR1 同一组测试向量/示例保证行为一致(Codex 是 Markdown skill pack,不直接共享 Claude 的 JS 运行时)。
- 若 Codex 侧需要可执行脚本:在 codex-skills 新增 scripts/ 或 helper,并说明安装后如何调用。

### 验收

- 用与 PR1 相同测试向量(1c+1x → peer;单 provider → no_peer;多互补 → ambiguous;改名仍分组)验证 Codex 侧行为一致。

### 边界

不改 ccb.config 格式;不引 pairing/role;不要求与 Claude 共享同一 JS 运行时。

### 依赖

PR1(pr1-group-resolver)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-d1a5fed3a615
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-05-31 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpmlnqxd02346a524ec5c98f
- Section: pr3-codex-skills-peer
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-d1a5fed3a615

---
doc_type: dev_task
task_id: subtask-f36997098fed
title: 后端只读需求 md 端点 + service
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxs58o53dd491462f34a675
section_id: pr1-requirement-md-readonly-endpoint
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxs58o53dd491462f34a675.json
source_draft_hash: 4d33a31290f1bfc3d852f5bf18ae9dec4ec336c1b61ed23be1feb0a6b9be13c6
created_at: 2026-06-03T10:44:28.795Z
updated_at: 2026-06-03T11:26:55.416Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxs58o53dd491462f34a675","branch":"ccb/req-cmpxs58o53dd491462f34a675"}
---

# 后端只读需求 md 端点 + service

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增按 requirementId 读取完整需求 md 正文的只读端点，复用 findRequirementMarkdown，读盘即时绕开 documents 投影 stale。 |
| 需求来源 | cmpxs58o53dd491462f34a675 |
| 本期范围 | pr1-requirement-md-readonly-endpoint · 后端只读需求 md 端点 + service |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### pr1 后端只读需求 md 端点

#### 任务概述
为 AI 解析弹窗提供「按 requirementId 读取完整需求 md 正文」的只读后端能力，复用服务端既有定位器，读盘即时（绕开 documents 投影 stale）。

#### 任务分解
- `requirement-edit.service.ts`：把私有 `extractMarkdownBody` 导出；新增 `loadRequirementMarkdownBody(prisma, projectId, requirementId)` —— 先校验 requirement ∈ project（同 `loadRequirementMdHash` 模式），再 `findRequirementMarkdown` 读盘，返回 `{ path: relativePath, content: extractMarkdownBody(content) }`（body-only，去 frontmatter）。
- `requirement.routes.ts`：注册 `GET /api/projects/:projectId/requirements/:requirementId/markdown`，调 service，HTTP 状态映射：`200 { path, content }`；需求不存在 / md 缺失 → `404 { message }`。
- 补 server 单测。

#### 验收标准
- [ ] 命中：返回去 frontmatter 的 body-only 正文 + 相对 path。
- [ ] 需求不属于该 project / md 文件缺失 → 404。
- [ ] `extractMarkdownBody` 去 frontmatter 单测绿。
- [ ] 不改 DB / schema、不动编辑 / reindex / hash 既有逻辑。

#### 边界 / 不做项
- 不消除 `requirement-reindex.service.ts` 里 `extractMarkdownBody` 的既有重复实现（既有技术债，不在本 PR 范围；如需收敛另开清理任务）。本 PR 仅复用 edit service 版本。
- 只读：不写盘、不改状态。

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

- Requirement: cmpxs58o53dd491462f34a675
- Section: pr1-requirement-md-readonly-endpoint
- Owner: ccb_codex
- Priority: high
- Dependencies: none

---
doc_type: dev_task
task_id: subtask-4ae87bad2b7d
title: 文档中心两栏目录树浏览器重写
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpv7qw8ze4204ec112b65923
section_id: pr1-documents-browser-redesign
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpv7qw8ze4204ec112b65923.json
source_draft_hash: e12dc65d138414643e1d2f0172d5b5a8a4f08e0148ad4dd8f99b99975af1bacf
created_at: 2026-06-01T15:16:26.198Z
updated_at: 2026-06-01T15:42:05.808Z
updated_by: ccb_claude
---

# 文档中心两栏目录树浏览器重写

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | DocumentsPage 三栏治理中心 → 两栏目录树浏览器；投影改名 projectDocumentBrowser 只分组删聚合；档位筛选 + per-doc 标记；配套测试/快照改写。纯前端原子改动。 |
| 需求来源 | cmpv7qw8ze4204ec112b65923 |
| 本期范围 | pr1-documents-browser-redesign · 文档中心两栏目录树浏览器重写 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把 Console「文档中心」从三栏治理中心重写为 **A 两栏目录树浏览器**（左 = docs 目录折叠树 + 搜索 + 档位筛选，右 = MarkdownViewer 阅读），移除中栏全部聚合。纯前端原子改动，后端零改动。承接技术设计 `docs/03_开发计划/文档中心ui界面第二次重构-b65923-技术设计.md`。

### 任务分解（单 PR，按 4 阶段执行，每阶段后跑 tsc，末尾统一全量验证）

1. **投影 rename + slim**：`web/src/lib/document-governance-projection.ts` → `document-browser-projection.ts`；`projectDocumentGovernance` → `projectDocumentBrowser`；返回只剩 `{ groups: { directory, documents }[] }`（按 **full parent directory** 分组、组内 path 升序、组间 directory 升序）；删除 `coverage/coverageSummary/parseErrors/unbound` 及 `CoverageRow/CoverageSummary` 等类型；**不留旧 export 兼容层**。
2. **页面 + CSS 两栏重写**：`DocumentsPage.tsx` 删 `governancePane` 整段 + `coverageTarget` + 聚合解构；左栏加 tier 筛选（全部/生效中/历史/归档，过滤 `doc.governance.tier`）+ per-doc 档位标记（**仅 历史/归档 贴小标，生效中不贴**）+ parseError ⚠ 克制小标记；右栏 `readerPane` 不动，仅改空态文案去掉「或中栏覆盖卡」；`DocumentsPage.module.css` grid 三栏 → 两栏（`260px minmax(0,1fr)`），删 `gov/coverage/health/gapCount` 样式，加 tier 筛选/标记样式；loading skeleton 去中栏。
3. **测试改写**：`document-governance-projection.spec.ts` → `document-browser-projection.spec.ts`，改测 按 directory 分组 + 组内 path 排序 + 多级/嵌套目录兜底（`docs/.ccb/state` 不丢）+ 空输入；`DocumentsPage.spec.tsx` 重写——**保留**（点击导航 `/documents/:id`、搜索 title/path、阅读器空态/加载/详情），**新增负向断言**（无 `governancePane`；页面不出现 `文档覆盖`/`健康度`/`未绑定文档`/`覆盖缺口`；同目录不同 tier 合并为一个目录组；tier 筛选生效；parseError 仅 per-doc 出现；空态文案不再提「中栏覆盖卡」）。
4. **快照 + 全量验证**：重生成 `tests/__snapshots__/e12-acceptance-snapshots.spec.tsx.snap`，核对仅含 DocumentsPage 相关 diff（无意外 DOM 变化）。

### 验收标准

- `pnpm --filter ccb-console-web build`（tsc --noEmit）通过
- `pnpm --filter ccb-console-web test`（vitest run）通过；targeted 覆盖：`DocumentsPage.spec.tsx`、`document-browser-projection.spec.ts`、`e12-acceptance-snapshots.spec.tsx`
- **负向断言/grep 成立**：页面渲染不含 `文档覆盖`/`健康度`/`未绑定文档`/`覆盖缺口`/`governancePane`
- e12 快照 diff **仅涉及 DocumentsPage** 结构（无其它组件 DOM 漂移）
- **实机冒烟**（rebuild + 重启 server，肉眼）：两栏布局、目录折叠树、搜索、tier 筛选、点击文档右栏阅读、空态文案、历史/归档标记、parseError 小标记

### 边界 / 护栏（不做项）

- 后端 `deriveDocumentGovernance` / `document.routes` / indexer document-map **不碰**（per-doc governance 字段保留，被 list route + document-map 消费）
- **不留兼容层**；不保留旧 `projectDocumentGovernance`
- 目录树 MVP = full parent directory 分组，**不做递归树组件**
- parseError 克制：**不出现** 健康度区 / 计数 / 聚合列表 / 大红卡，仅 per-doc 小标记
- 档位只标 历史/归档，生效中（默认）不贴标
- 无新增依赖；无 DB / schema / API 变更

### 依赖

无（原子任务，单 PR 内闭环）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-01 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpv7qw8ze4204ec112b65923
- Section: pr1-documents-browser-redesign
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

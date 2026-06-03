---
doc_type: dev_task
task_id: subtask-799381c1f182
title: 详情页两处阅读改弹窗 + AI 取完整 md
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxs58o53dd491462f34a675
section_id: pr3-detail-reading-modal
order: 3
implementation_owner: claude
dependencies: [subtask-f36997098fed, subtask-469791fcbc38]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxs58o53dd491462f34a675.json
source_draft_hash: 4d33a31290f1bfc3d852f5bf18ae9dec4ec336c1b61ed23be1feb0a6b9be13c6
created_at: 2026-06-03T10:44:28.795Z
updated_at: 2026-06-03T14:11:27.313Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxs58o53dd491462f34a675","branch":"ccb/req-cmpxs58o53dd491462f34a675"}
---

# 详情页两处阅读改弹窗 + AI 取完整 md

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | AI 解析 / 技术设计阅读由侧边栏改 Modal；AI 解析经 pr1 端点展示完整需求 md；技术设计保留状态机仅换容器。 |
| 需求来源 | cmpxs58o53dd491462f34a675 |
| 本期范围 | pr3-detail-reading-modal · 详情页两处阅读改弹窗 + AI 取完整 md |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### pr3 详情页两处阅读改弹窗 + AI 取完整 md

#### 任务概述
把需求详情页「AI 解析」「技术设计」两个产物的阅读从侧边栏（`DetailDrawer`）改为弹窗（`Modal size="reader"`）；AI 解析弹窗展示完整需求 md 正文（经 pr1 端点），技术设计弹窗保留现有取文状态机仅换容器。

#### 任务分解
- `RequirementDetailPage.tsx`：`drawer` 状态改 `artifactModal`；两处 `DetailDrawer` → `Modal size="reader"`；AI 解析新增 `RequirementMarkdownState`，打开时 lazy 调 `fetchRequirementMarkdown` → `MarkdownViewer(rewriteRequirementAssetUrls(content))`，覆盖 loading / ready / empty / error / 404；`requirement.mdHash` 变化时重拉；迟到响应丢弃（沿用设计文档现有 requestId/seq 模式）；技术设计阅读 effect 触发条件由 `drawer==="design"` 改 `artifactModal==="design"`，内容逻辑不变。
- `console-api.ts`：新增 `fetchRequirementMarkdown(projectId, requirementId)`。
- 测试：更新 `RequirementDetailPage.spec.tsx`（drawer→modal 断言、AI 取文态、mdHash 重拉、AI 迟到响应丢弃）；更新 mock 整个 `console-api` 且 import `App` 的测试的 mock export：`app-redesign.spec.tsx`、`e12-acceptance-snapshots.spec.tsx`、`task-detail-v2-acceptance.spec.tsx`（补 `fetchRequirementMarkdown` mock，否则缺 export 直接炸）。

#### 验收标准
- [ ] AI 解析 / 技术设计阅读均为弹窗，开 / 关 / ESC / 焦点正常。
- [ ] AI 解析渲染完整需求 md（ready / empty / error / 404 态）。
- [ ] `mdHash` 变化时 AI md 重拉；关闭 / 切换时迟到响应被丢弃（有测试）。
- [ ] 技术设计弹窗沿用既有 idle/loading/ready/not-indexed/stale/not-found/error/empty 态。
- [ ] 全屏阅读按钮 / 拆分草案 / 子任务行为不变。
- [ ] App 级测试（app-redesign / e12-acceptance-snapshots / task-detail-v2-acceptance）因 console-api mock 补齐而通过。

#### 边界 / 不做项
- 不动「全屏阅读」按钮逻辑、拆分草案、子任务交互、`DetailDrawer` 组件本体。
- 依赖 pr1（端点）+ pr2（reader size / a11y），串行在二者之后。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-f36997098fed, subtask-469791fcbc38
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
- Section: pr3-detail-reading-modal
- Owner: claude
- Priority: high
- Dependencies: subtask-f36997098fed, subtask-469791fcbc38

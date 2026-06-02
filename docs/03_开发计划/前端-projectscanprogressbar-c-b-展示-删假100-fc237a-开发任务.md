---
doc_type: dev_task
task_id: subtask-dc0c0bfc237a
title: 前端 ProjectScanProgressBar C+B 展示(删假100%)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpvdegxq1c734729da1be5bc
section_id: pr2-progressbar-cb
order: 2
implementation_owner: claude
dependencies: [subtask-3ef55e7018a4]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdegxq1c734729da1be5bc.json
source_draft_hash: fb7ceefcca1dd25fe6656351203d3f3f3f9a6ab015a0c5d8cc0440e9cb3def16
created_at: 2026-06-02T03:09:57.855Z
updated_at: 2026-06-02T04:37:54.013Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdegxq1c734729da1be5bc","branch":"ccb/req-cmpvdegxq1c734729da1be5bc"}
---

# 前端 ProjectScanProgressBar C+B 展示(删假100%)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 进度条按 phase 决定 determinate(扫描 x/y)/indeterminate(阶段标签)；删终态强制100%；failed 展示。前端由 Claude 亲自做。 |
| 需求来源 | cmpvdegxq1c734729da1be5bc |
| 本期范围 | pr2-progressbar-cb · 前端 ProjectScanProgressBar C+B 展示(删假100%) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 目标
`ProjectScanProgressBar` 按 phase 诚实展示（C+B）；**删除假 100%**。前端由 Claude 亲自实现。

### 范围 / 任务分解
- `web/src/types/project.ts`：`ProjectScanStatusView` 增 `phase/phaseStatus/phaseJobId/phaseErrorMessage`（均可空）。
- `web/src/components/projects/ProjectScanProgressBar.tsx`：
  - 删除"终态强制 100% / markComplete 把 processed 拉到 total"的假完成逻辑（现 :66-87 markComplete、:131-144 percent 计算）。
  - scanning 期间：phase==="scan" && totalCount>0 && processedCount<totalCount → determinate「扫描文档 x/y · n%」；否则 indeterminate + 阶段中文标签（LABEL 映射见技术设计「四.3」）。
  - syncStatus 终态 →「扫描完成」(hold 700ms) → 隐藏；failed(syncStatus=failed 或 phaseStatus=failed) →「扫描失败」+ phaseErrorMessage||errorMessage。
  - 保留 750ms 轮询、项目切换/卸载清理逻辑。
- `web/src/components/projects/ProjectScanProgressBar.module.css`：不定态条纹动画（若缺）。

### 验收标准
- 组件 spec：scanning+scan+processed<total→determinate；scanning+其它阶段→indeterminate+正确标签；终态→complete→hidden；failed→展示 phaseErrorMessage。
- 浏览器手测：较大 docs 树点"扫描文档"，观察 determinate → 阶段 indeterminate → 完成消失，全程**不早现 100%**。

### 边界 / 不做项
- 不碰后端。阶段标签文案以技术设计映射为准，不自创。

### 依赖
pr1-scan-status-phase（需要其 phase 字段）。与 pr3 不同文件(web vs server)，pr1 提交后可与 pr3 并行。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-3ef55e7018a4
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-02 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpvdegxq1c734729da1be5bc
- Section: pr2-progressbar-cb
- Owner: claude
- Priority: high
- Dependencies: subtask-3ef55e7018a4

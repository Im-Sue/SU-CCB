---
doc_type: dev_task
task_id: subtask-3ef55e7018a4
title: 后端 /scan-status 增 phase 字段 + deriveScanPhase(run 边界+白名单)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpvdegxq1c734729da1be5bc
section_id: pr1-scan-status-phase
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdegxq1c734729da1be5bc.json
source_draft_hash: fb7ceefcca1dd25fe6656351203d3f3f3f9a6ab015a0c5d8cc0440e9cb3def16
created_at: 2026-06-02T03:09:57.855Z
updated_at: 2026-06-02T04:17:47.711Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdegxq1c734729da1be5bc","branch":"ccb/req-cmpvdegxq1c734729da1be5bc"}
blocked_reason: 已解决:基线修复后重做通过审查并归档
---

# 后端 /scan-status 增 phase 字段 + deriveScanPhase(run 边界+白名单)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增并导出 deriveScanPhase(run 边界+pipeline 白名单)，/scan-status 向后兼容加 phase/phaseStatus/phaseJobId/phaseErrorMessage。不改执行逻辑/完成时机。 |
| 需求来源 | cmpvdegxq1c734729da1be5bc |
| 本期范围 | pr1-scan-status-phase · 后端 /scan-status 增 phase 字段 + deriveScanPhase(run 边界+白名单) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
让 `GET /scan-status` 暴露"当前阶段"，为前端 C+B 提供数据。**只加字段、不改任何执行逻辑/完成时机**（完成时机由 pr3 做）。

### 范围 / 任务分解
- 新增并导出 `deriveScanPhase(prisma, projectId)`（`server/src/indexer/project-indexer.ts`），按技术设计「四.1」的 run 边界 + pipeline 白名单推导：
  - PIPELINE 白名单 = [scan, parse, template_conformance, requirement_sync, reconcile, plugin_journal_sync, requirement_design_doc_sync, breakdown_draft_sync, requirement_rollup]（含 requirement_rollup，pr3 落地后自然生效）。
  - rootScan = 最新 jobType=scan 且 startedAt > (project.lastScanAt ?? epoch)；无 → phase=null。
  - current = 白名单内 startedAt >= rootScan.startedAt 的最新 job（order by startedAt desc, createdAt desc）；无 → phase="preparing"。
  - 返回 { phase, phaseStatus, phaseJobId, phaseErrorMessage }；partial 只入 phaseStatus，不作终态。
- `server/src/modules/project/project.routes.ts` 的 GET `/scan-status`：调 deriveScanPhase，响应合入 phase/phaseStatus/phaseJobId/phaseErrorMessage；既有字段（projectSyncStatus/status/processedCount/totalCount/errorMessage/jobId/updatedAt）不变。

### 验收标准
- `deriveScanPhase` 单测：run 边界(startedAt>lastScanAt)；白名单过滤(构造一个 jobType=generate 的更新 job，断言不被选中)；空窗→preparing；partial→只入 phaseStatus；首扫 lastScanAt=null→命中本 run scan job；run 结束(scan.startedAt<lastScanAt)→phase=null。
- `/scan-status` spec：新增 4 字段存在且向后兼容（旧字段语义不变）。
- 测试保持轻量：覆盖核心分支即可，不必穷举每个组合。

### 边界 / 不做项
- 不改 scanProject 执行顺序/完成时机（pr3 做）。不改前端（pr2 做）。
- requirement_rollup 此刻还没有对应 job（pr3 才建），白名单先含上即可，无需此任务造数据。

### 依赖
无（先行任务）。注意：与 pr3 共享 `project-indexer.ts`，pr3 必须在本任务**提交后**再开工（同文件串行，避免纠缠）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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
- Section: pr1-scan-status-phase
- Owner: ccb_codex
- Priority: high
- Dependencies: none

---
doc_type: dev_task
task_id: subtask-bfc7fb0e25e7
title: scanProject lifecycle 重排(rollup 纳入扫描窗口)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpvdegxq1c734729da1be5bc
section_id: pr3-scanproject-lifecycle
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-3ef55e7018a4]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdegxq1c734729da1be5bc.json
source_draft_hash: fb7ceefcca1dd25fe6656351203d3f3f3f9a6ab015a0c5d8cc0440e9cb3def16
created_at: 2026-06-02T03:09:57.855Z
updated_at: 2026-06-02T04:29:53.332Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdegxq1c734729da1be5bc","branch":"ccb/req-cmpvdegxq1c734729da1be5bc"}
---

# scanProject lifecycle 重排(rollup 纳入扫描窗口)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 拆分 mark_initialized；rollup 建 requirement_rollup job 并前移；syncStatus=idle/lastScanAt 延到 rollup 成功后；rollup 失败→项目 failed。 |
| 需求来源 | cmpvdegxq1c734729da1be5bc |
| 本期范围 | pr3-scanproject-lifecycle · scanProject lifecycle 重排(rollup 纳入扫描窗口) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
"扫描完成"端到端诚实：把 rollup 纳入 scanning 窗口；rollup 失败 → 项目 failed。**已经用户审批确认采用此形态。**

### 范围 / 任务分解（均在 `server/src/indexer/project-indexer.ts`）
- 拆分 `mark_project_scan_initialized`（现 :586-602）：docsRoot/initStatus 仍在此写；`syncStatus=idle` + `lastScanAt` **移出**。
- 新增 requirement_rollup job：`createSyncJob(projectId, "requirement_rollup")` 包住 `rollupAllRequirementsForProject`（现 :605）；成功 finishSyncJob(success)；失败 finishSyncJob(failed) + 置 project.syncStatus=failed 并 throw（不留"idle 后 failed"窗口）。
- rollup 成功后再 `project.update { syncStatus:"idle", lastScanAt: now }`（独立幂等键，如 :mark_project_scan_idle）。
- schema-ownership-lint 如需登记 `requirement_rollup` jobType，一并处理。

### 验收标准
- 集成测试：跑完整 scanProject，断言 syncStatus 在 requirement_rollup **成功后**才 idle；requirement_rollup job 有序出现；rollup 失败 → syncStatus=failed 且无中间 idle 窗口。
- 与 pr1 联动：rollup 阶段可被 deriveScanPhase 推为 phase=requirement_rollup（前端显示"汇总状态"）。
- 测试保持轻量：核心生命周期断言即可。

### 边界 / 不做项
- 不改 rollup 内部聚合逻辑（仅包 job + 重排时机）。不改前端。

### 依赖
pr1-scan-status-phase（**同文件 `project-indexer.ts`，必须在 pr1 提交后串行开工**）。与 pr2 不同文件，可与 pr2 并行。

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
- Section: pr3-scanproject-lifecycle
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-3ef55e7018a4

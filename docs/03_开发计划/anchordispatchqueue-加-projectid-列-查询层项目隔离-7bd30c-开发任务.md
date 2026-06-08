---
doc_type: dev_task
task_id: subtask-99c76f7bd30c
title: AnchorDispatchQueue 加 projectId 列 + 查询层项目隔离
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr3-adq-migration
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T15:31:44.420Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# AnchorDispatchQueue 加 projectId 列 + 查询层项目隔离

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | schema 加列(nullable)+best-effort 回填+脏终态行清理;enqueue 上下文直写;tick 查询层 WHERE;queue policy/slot.routes 查询面与测试夹具全量补齐 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr3-adq-migration · AnchorDispatchQueue 加 projectId 列 + 查询层项目隔离 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

派工队列目前没有「属于哪个项目」字段,tick() 全局取行再事后跳过别项目——无法证明查询层隔离。本切按技设 D2b 与用户拍板(2026-06-07:DB 是可重建投影,历史行不过分兼容)落地:加列、回填、查询层过滤。**注意:这是有状态 schema 变更,独立批次(批1b),不与代码止血批混合。**

### 任务分解

1. `schema.prisma`:AnchorDispatchQueue 加 `projectId String?`(nullable 列,向后兼容回滚——回滚代码不回滚列);prisma migration + generate。
2. 回填脚本(migration 内或伴随脚本):按 subjectId→requirement/task 反查归属 best-effort 回填;**终态行**(completed/failed)查不到归属→直接 DELETE+计数;**active 行**(pending/submitted)查不到(预期为零)→标记+报告;migration 输出清理报告计数。
3. enqueue 全部写入点:派发上下文直写 projectId(禁止反查兜底——反查是 bug 温床);代码层对新行强制非空。
4. `job-slot-router.ts` tick():查询改 `WHERE status=pending AND projectId=…`(:174-198 的事后 continue 删除);若 pr1 的类型收紧波及本文件构造点(:373),编译适配在本切一并完成。
5. 影响面补全(协商 finding 4):queue policy、slot.routes 中的队列查询同步过滤;测试夹具中大量 `anchorDispatchQueue.create/createMany` 补 projectId——**夹具更新量大是已知风险,勿低估**。

### 验收标准

- migration 测试三路径:正确回填/终态脏行清理+计数/active 脏行标记。
- 双项目 fixture:tick 零跨项目取行(查询层断言,不是处理层 continue)。
- enqueue 单测:新行 projectId 必填;全仓绿。

### 边界 / 不做项

- AnchorAllocation 不加列(已有 projectId 字段,schema.prisma:247);EventJournal 不动(pr1 范围)。
- 不改派发/路由业务逻辑,只动队列的 scope 维度。

> 派生自:技设 D2b/六章 + 用户拍板「不过分兼容」+ 协商 finding 4(去 pr1 依赖、影响面补全)。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq3m1i8r5ac97ea38323ee06
- Section: pr3-adq-migration
- Owner: ccb_codex
- Priority: high
- Dependencies: none

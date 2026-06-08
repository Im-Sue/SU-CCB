---
doc_type: dev_task
task_id: subtask-e462bccf77ed
title: ccbd client 构造显式 scope 收紧 + EventJournal project_id 过滤
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr1-ccbd-scope-hardening
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T16:38:26.533Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# ccbd client 构造显式 scope 收紧 + EventJournal project_id 过滤

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | CcbdClientServiceOptions 三选一必填联合类型,删构造内 resolveCcbProjectRoot 隐式 fallback;构造点适配;EventJournal list 加可选 project_id 过滤。前置:e9f09f B1 先合并 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr1-ccbd-scope-hardening · ccbd client 构造显式 scope 收紧 + EventJournal project_id 过滤 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把「连到哪个项目的 ccbd」从可以不说(默认回落 server 自己的项目)改成必须明说:`CcbdClientService` 构造参数改为 `projectRoot | socketPath | anchorSocketResolver` 三选一必填的联合类型,构造函数里删掉 `resolveCcbProjectRoot()` 隐式回落(ccbd-client.service.ts:122)。这是技设 D2a——B1 修了当前肇事者,本切防未来新增。同捎 D2c:EventJournal 查询端点加可选 `project_id` 过滤(model 已有字段,纯查询扩展)。

### 任务分解

1. `ccbd-client.service.ts`:options 联合类型必填化;`resolveCcbProjectRoot`/`resolveCcbdSocketPath` 保留为公开导出函数(合法的 server 自身根场景显式传参,意图可见)。
2. 构造点适配:生产 13 处已显式传参(类型签名波及预期零或最小 diff);测试中 25 处 `resolveCcbProjectRoot` 调用点显式化。**范围排除**:`job-slot-router.ts` 一概不动——若类型变更导致其编译失败,适配工作移交 pr3(同文件单一任务改,避免并发冲突)。
3. `event-journal.schemas.ts`(:360-371 query schema)+ `event-journal.routes.ts`:加可选 `project_id` 过滤参数,不传=现行为(向后兼容)。

### 验收标准

- 无参 `new CcbdClientService()` 编译失败(类型层面禁止,有编译错误示例为证)。
- 全仓 server 测试绿;tsc/lint 干净。
- EventJournal 过滤单测:传 project_id 只返回该项目事件;不传行为不变。

### 边界 / 不做项

- **批内前置(2026-06-07 用户拍板 e9f09f 并入本 batch,协调确认 job_0046f204228c)**:本切在 e9f09f 单任务(subtask-e667d1e7f5aa,A4+B1)完成后执行——B1 已重写 `slot-context-reset.service.ts` 构造路径为显式 clientFactory,本切类型收紧直接基于 B1 最终签名,无需任何权宜适配。
- 不动 `job-slot-router.ts`(归 pr3);不动 anchor-terminal(归 pr2);不改 `CCB_CCBD_SOCKET_PATH` env 语义(尖角已由 e9f09f root 守卫覆盖)。

> 派生自:技设 D2a/D2c + 拆分协商 job_be3f979b8931 finding 1(e9f09f 前置)。

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
- Section: pr1-ccbd-scope-hardening
- Owner: ccb_codex
- Priority: high
- Dependencies: none

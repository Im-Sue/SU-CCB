---
doc_type: dev_task
task_id: subtask-408716669250
title: anchor-terminal 项目归属校验 + 去 ccb-su-ccb-task- 硬编码(共享 resolver)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr2-anchor-terminal-scope
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T15:04:20.443Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# anchor-terminal 项目归属校验 + 去 ccb-su-ccb-task- 硬编码(共享 resolver)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | panes/ws 按 AnchorAllocation.projectId 主路径校验(subjectId 反查仅 legacy 兜底);抽共享 anchor session resolver 删两处硬编码,多候选 fail-loud |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr2-anchor-terminal-scope · anchor-terminal 项目归属校验 + 去 ccb-su-ccb-task- 硬编码(共享 resolver) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

anchor 终端通道是已核验的可写通道(ws 支持 request_write/input/resize,anchor-terminal.routes.ts:186/201/213),但 `resolveAnchor` 按 anchorId 全局查、无项目归属校验——错误项目上下文拿到 anchorId 就能向别的项目的 anchor 终端写入。本切加归属校验(技设 D2d),并清理 `ccb-su-ccb-task-` 硬编码×2(技设 D4,e9f09f 移交项),session 解析对齐 A4「运行时证据」思路。

### 任务分解

1. 归属校验:panes/ws 入口按 **`AnchorAllocation.projectId` 主路径**校验(schema.prisma:247,字段已存在);`projectId` 为 null 的 legacy 行降级走 subjectId→requirement/task 反查一致性兜底;两路都查不到(孤儿 anchor)→ fail-closed 拒绝。recordings/cast 同步审计,按需加 scope 过滤。
2. 调用方传 scope:校验需要调用方声明期望项目——panes/ws 的 query 增加 projectId(或等效上下文),与前端调用点同步(前端当前消费点改动量小,实施时核定)。
3. **抽共享 anchor session resolver**:`tmux.service.ts:8` 与 `native-terminal.service.ts:12` 各有一套 `resolveAnchorSession` 与硬编码前缀——抽成单一共享 resolver 再删两处硬编码,否则双实现漂移。解析以 AnchorAllocation.anchorPath 等登记证据反推 session;多候选不唯一即 fail-loud,删除 `sessions[0]` 静默取第一。
4. 29 处测试引用 `ccb-su-ccb` 字面量联动更新(参数化 session 名)。

### 验收标准

- 跨项目 anchorId 调用 panes/ws → 403/404;孤儿 anchor → 拒绝;合法同项目调用不受影响(集成测试覆盖)。
- 非 SU-CCB 目录名项目的 anchor/worktree 终端可解析(参数化 session 名测试)。
- 共享 resolver 单测:多候选 fail-loud;两个 service 均消费共享实现(grep 无残留硬编码)。
- recordings/cast 给出明确 scope 结论:若加过滤,测试覆盖跨项目拒绝;若不加,以代码/数据证据说明无跨项目泄漏风险(结论同步登记 pr8 矩阵行)。
- 全仓绿;tsc/lint 干净。

### 边界 / 不做项

- 不动 slot-terminal(e9f09f A4 范围);不动终端 attach/lease/recording 机制本身;不改 ccbd 侧命名规则。
- 与 pr1 文件零交叉(本切只动 anchor-terminal 模块)。

> 派生自:技设 D2d/D4 + 协商 finding 2/3(allocation.projectId 主路径已核验;共享 resolver 防漂移)。

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
- Section: pr2-anchor-terminal-scope
- Owner: ccb_codex
- Priority: high
- Dependencies: none

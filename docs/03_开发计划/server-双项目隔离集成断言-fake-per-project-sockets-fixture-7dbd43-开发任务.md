---
doc_type: dev_task
task_id: subtask-20633b7dbd43
title: server 双项目隔离集成断言(fake per-project sockets fixture)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr6-server-isolation-integration
order: 6
implementation_owner: ccb_codex
dependencies: [subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T16:51:49.932Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# server 双项目隔离集成断言(fake per-project sockets fixture)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 双项目 fake ccbd sockets fixture 基建+bind/release/resize/cancel 全链路落点断言(send-keys/socket 写入只进目标项目);为 pr7 复用 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr6-server-isolation-integration · server 双项目隔离集成断言(fake per-project sockets fixture) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

「命令真正落到正确项目的 socket」不能靠 UI 测试证明(技设 D6 双层验收的落点层)。本切搭双项目 fake ccbd sockets fixture 并写全链路集成断言——与 Playwright 浏览器层(pr7)分开:两类验证工程混在一切会变 L+ 且失败归因混乱(协商 finding 6)。

### 任务分解

1. fixture 基建:双项目(两个临时 projectRoot+各自 fake ccbd socket/fake tmux 层)可复用 fixture,参考既有 ccbd-client.spec 的 socketPath 注入模式;fixture 设计为 pr7 的 Playwright 后端可复用。
2. 集成断言(server vitest):bind/release/resize/cancel-current-job 四条链路,双项目并发执行,断言每条链路的 ccbd 调用与 send-keys 只落目标项目 socket,另一项目 socket 零写入。
3. 队列隔离断言:双项目入队,tick 按 projectId 只取本项目行(消费 pr3 的查询层过滤)。
4. anchor-terminal 归属断言:跨项目 anchorId 拒绝路径(消费 pr2)。

### 验收标准

- 四链路双项目断言绿:目标 socket 有预期写入,非目标 socket 严格零写入。
- fixture 文档化(README 或注释):pr7 可直接复用启动。
- 全仓绿;不修改任何生产代码(只增测试与 fixture;发现 bug 回对应切片修)。

### 边界 / 不做项

- 不含浏览器层(pr7);不跑真 tmux(e9f09f 已有真 tmux 用例先例,本切 fake 层即可)。
- 批内前置(2026-06-07 用户拍板 e9f09f 并入本 batch):e9f09f(subtask-e667d1e7f5aa,A4+B1)已在批内先行,bind 链路 /new reset 落点断言为**正常绿断言**。全仓绿口径注明 requirement-status-rollup 既有失败 2 例。

> 派生自:技设 D6(落点层)/五章 + 协商 finding 6(拆分)与 risks(fixture 复杂度)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c
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
- Section: pr6-server-isolation-integration
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c

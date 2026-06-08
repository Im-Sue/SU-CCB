---
doc_type: dev_task
task_id: subtask-7f9dcd0eef2b
title: 全站多项目隔离审计矩阵(收口证据)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr8-audit-matrix
order: 8
implementation_owner: ccb_codex
dependencies: [subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c, subtask-c0d7847ade61]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-08T04:15:06.667Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# 全站多项目隔离审计矩阵(收口证据)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 入口×projectId 来源×隔离结论矩阵:246 消费点按文件归并/10 scoped 端点/4 anchor-terminal 端点/15 构造点,每行挂证据;落点 docs/05_经验沉淀/ |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr8-audit-matrix · 全站多项目隔离审计矩阵(收口证据) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

完整档的收口交付:用一张审计矩阵证明「全站隔离状态」,把「看代码应该没问题」变成逐行有证据的结论(技设 D5)。在 pr1-pr4 合并后做,矩阵记录的是修复后终态。

### 任务分解

1. 审计面(技设八章+事实清单):前端 246 处 selectedProjectId 消费点(按文件归并审计,标注:已迁 useProjectScope/只读投影最终一致/风险残留);server 10 个 projectId-scoped slot/terminal 端点;4 个 anchor-terminal 端点(pr2 后状态);15 个 CcbdClientService 构造点(pr1 后状态);队列/EventJournal 查询(pr3/pr1 后状态)。
2. 矩阵格式:入口 × projectId 来源(URL 路径段/请求参数/allocation 字段/构造参数) × 隔离结论(绿:查询层或类型层隔离/黄:最终一致或反查兜底/红:残留风险),每行挂测试名或 file:line 证据。
3. 红黄项处置:红项升级用户;黄项给出收敛建议(渐进收敛 backlog,不在本切实施)。
4. 落点:`docs/05_经验沉淀/`(常青参考,文件名含 23ee06 短 id;由本切按目录契约最终确认)。

### 验收标准

- 矩阵覆盖上述全部审计面,零「未审计」空行;每行结论可点击验证(测试名/file:line)。
- 红项为零或已逐项升级用户;黄项有收敛建议。
- 矩阵作为 review 节点的验收输入之一(需求验收口径:扫描面交付风险清单矩阵)。

### 边界 / 不做项

- 纯文档+审计交付,不改代码;发现新串扰风险→记录矩阵红项并升级,不在本切顺手修。
- 与 pr7 并行无冲突(都是只增层)。

> 派生自:技设 D5/五章 + 需求验收口径(矩阵三件套)+ 协商 open_question 3 裁量(落点 05_经验沉淀)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c, subtask-c0d7847ade61
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
- Section: pr8-audit-matrix
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-e462bccf77ed, subtask-408716669250, subtask-99c76f7bd30c, subtask-c0d7847ade61

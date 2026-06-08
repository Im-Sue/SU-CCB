---
doc_type: dev_task
task_id: subtask-d94c7d2e2325
title: Playwright 双 tab 多项目浏览器层 e2e(新依赖工程初始化)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr7-playwright-multitab-e2e
order: 7
implementation_owner: ccb_codex
dependencies: [subtask-c0d7847ade61, subtask-20633b7dbd43]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-08T04:07:54.665Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# Playwright 双 tab 多项目浏览器层 e2e(新依赖工程初始化)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | Playwright 工程初始化(用户已拍板引入)+双 context 双项目用例:绑定互不串扰/刷新身份不漂移/轮询不改身份/旧链接跳转/无效 projectId 报错 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr7-playwright-multitab-e2e · Playwright 双 tab 多项目浏览器层 e2e(新依赖工程初始化) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

多 tab 多项目并发是用户拍板「必须支持」的使用方式,没有浏览器层自动化它会持续回归。本切初始化 Playwright 工程(新 devDependency,用户 2026-06-07 已拍板)并落双 context 用例——双层验收的浏览器层,与 pr6 落点层互不替代。

### 任务分解

1. Playwright 工程初始化:su-oriel 内新 e2e 目录/工程(devDependency 进 package.json;CI 可选接入实施时定);против真 server+pr6 的双项目 fixture 启动。
2. 双 context 用例(每条双 tab 双项目):①A tab 绑 slot、B tab 观察自身项目 slot 零变化(配合 pr6 断言);②刷新后身份不漂移(URL 决定);③30s 轮询不改变身份;④旧格式链接智能跳转(三类 id+查无);⑤无效 projectId 显式「项目不存在」页;⑥sidebar 切项目=导航(URL 变化)。
3. 用例与 pr6 fixture 的接线文档。

### 验收标准

- 六类用例稳定绿(容忍合理重试);本地一条命令可跑。
- 不修改生产代码;发现 bug 回对应切片修。
- 全仓既有测试不受影响。

### 边界 / 不做项

- 不替代 pr6 的落点断言;不做性能/视觉测试;CI 集成深度实施时按现有工程惯例定。

> 派生自:技设 D6(浏览器层)/五章 + 用户拍板(Playwright 引入进验收口径)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-c0d7847ade61, subtask-20633b7dbd43
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
- Section: pr7-playwright-multitab-e2e
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-c0d7847ade61, subtask-20633b7dbd43

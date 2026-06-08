---
doc_type: dev_task
task_id: subtask-5ea230785c77
title: 「CCB bridge 错误」排查(报告型交付)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr5-bugc-investigation
order: 5
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T14:32:15.290Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# 「CCB bridge 错误」排查(报告型交付)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 双 tab 复现+reload_rejected/reload_failed 双路径检查清单;交付确证或排除+根因链+复现步骤+处置判断;纯排查不落代码 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr5-bugc-investigation · 「CCB bridge 错误」排查(报告型交付) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

用户报告的第一个现象「CCB tab 添加 slot 报 CCB bridge 错误」至今证据未闭环——resize 链路显式传 projectRoot 属正确模式(slot-resize.service.ts:120-122),不能赖在 default resetter 根因上。本切是**排查型任务**:交付的是结论三件套,不是代码 PR;不进代码批次的 blocking chain,可最早并行。

### 任务分解

1. 复现:双 tab(CCB+另一项目)并行场景下对 CCB 执行添加 slot(resize 扩容),记录精确报错文案与 server 日志。
2. 双路径检查清单:**reload_rejected**(「ccb bridge 拒绝了拓扑变更」,SlotsPage.tsx:51)→ 检查 ccb.config 与请求 diff、bridge 拒绝原因码;**reload_failed**(「ccb reload 执行失败」,SlotsPage.tsx:52)→ 检查 ccbd 进程状态、socket 通信、reload 执行日志。
3. 旁证排查:确认现象是否与双 tab 状态有关(单 tab 能否复现)、是否与 e9f09f Bug B 的 /new 副作用时序相关。
4. 产出排查报告:确证或排除 + 根因链(file:line 证据)+ 复现步骤 + 处置判断(归本需求修/另立需求/环境问题关闭)。

### 验收标准

- 报告三件套齐全,根因链每个环节有日志或代码证据。
- 无法复现时:给出已排除路径清单+建议的日志增强点(作为报告建议,不在本切落地),结论标注「未复现,按 X 条件再触发」。

### 边界 / 不做项

- **纯排查不落代码**:若需日志增强,在报告中提出建议由后续批次落地(避免与 pr1 并发碰 slot-resize 文件)。
- 修复动作不在本切:处置判断输出后由用户决定归属。

> 派生自:技设 D3 + 协商 finding 7(报告型任务不入 blocking chain)。

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
- Section: pr5-bugc-investigation
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

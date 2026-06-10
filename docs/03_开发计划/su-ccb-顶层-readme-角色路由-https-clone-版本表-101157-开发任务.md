---
doc_type: dev_task
task_id: subtask-ed5c47101157
title: SU-CCB 顶层 README 角色路由 + HTTPS clone + 版本表
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr4-succb-readme-roles-versions
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-a3ccf4713c2e, subtask-f3438763fe0a, subtask-0e918c1f75fd]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:19:51.288Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# SU-CCB 顶层 README 角色路由 + HTTPS clone + 版本表

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 顶层 README 三角色路由 + HTTPS --recursive + 分层版本表(真相源)+ 评估者指针 |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr4-succb-readme-roles-versions · SU-CCB 顶层 README 角色路由 + HTTPS clone + 版本表 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

把 `README.md`(SU-CCB 顶层)改成"总览 + 角色路由":一眼看清三种角色各去哪(只用 plugin/skills → 各组件 README;用控制台 → SU-Oriel README;整套开发者 → 本 README + docs/install)。补 HTTPS `git clone --recursive`,放一份**分层版本表(全仓版本真相源)**,并指向 pr3 的评估者路径。纯文档。

### 二、任务分解

- `README.md`:
  - 「三种使用角色」表加"上手去哪"列,链接到对应 README(plugin / codex-skills / SU-Oriel)。
  - 「上手」段补 HTTPS:`git clone --recursive https://github.com/Im-Sue/SU-CCB.git`(现仅 SSH,评估者第一步就可能卡)。
  - 新增「环境与版本」**分层版本表**:Python(bridge 3.10+ / 本仓脚本 3.8+)、Node 18+、pnpm 10.25.0、git 2.30+——作为全仓版本真相源,带锚点供 install.md 链接。
  - 「快速试用(评估者)」一句话指向 pr3 SU-Oriel README 的评估者锚点。

### 三、验收标准

- [ ] README 有角色路由(三角色 → 各自上手文档链接)。
- [ ] 有 HTTPS `git clone --recursive` 路径。
- [ ] 有分层版本表且带锚点。
- [ ] 评估者路径指向 pr3 锚点(非死链)。

### 四、边界 / 禁止

- 只改 `README.md`。不复制组件命令(链接 pr1/pr2)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a3ccf4713c2e, subtask-f3438763fe0a, subtask-0e918c1f75fd
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-10 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq7z6fmcdd8e3116c6ffc5ff
- Section: pr4-succb-readme-roles-versions
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a3ccf4713c2e, subtask-f3438763fe0a, subtask-0e918c1f75fd

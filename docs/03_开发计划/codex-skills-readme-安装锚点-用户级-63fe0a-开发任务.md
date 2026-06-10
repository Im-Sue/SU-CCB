---
doc_type: dev_task
task_id: subtask-f3438763fe0a
title: codex-skills README 安装锚点(用户级)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr2-codex-skills-readme-anchor
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:08:23.676Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# codex-skills README 安装锚点(用户级)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | su-ccb-codex-skills README install 段加锚点、强调用户级 ~/.codex/skills 先装再起 CCB |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr2-codex-skills-readme-anchor · codex-skills README 安装锚点(用户级) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

把 `su-ccb-codex-skills/README.md` 的安装段做成"命令真相源":稳定锚点 + 强调装到**用户级** Codex(`~/.codex/skills`),"先装再起 CCB,Codex agent 才继承"。纯文档,子仓改动。

### 二、任务分解

- `su-ccb-codex-skills/README.md`「快速开始」段:
  - 给 install 命令块加可被链接的锚点(供 plugin README、SU-Oriel README 指)。
  - 文案明确"装到用户级 `~/.codex/skills`(`$skill-installer` 或手动 `cp`),先装再起 CCB,派生 Codex agent 才继承";保留现有两种安装法。
- 不动其它段。

### 三、验收标准

- [ ] codex-skills README 有可链接的 install 锚点。
- [ ] install 段出现"用户级 + 先装再起 CCB 才继承"措辞。
- [ ] 子仓 commit+push;主仓抬 su-ccb-codex-skills gitlink。

### 四、边界 / 禁止

- 只改 `su-ccb-codex-skills/README.md`。不碰 skill 逻辑。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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
- Section: pr2-codex-skills-readme-anchor
- Owner: ccb_codex
- Priority: high
- Dependencies: none

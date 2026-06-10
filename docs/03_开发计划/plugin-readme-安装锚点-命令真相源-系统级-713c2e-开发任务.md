---
doc_type: dev_task
task_id: subtask-a3ccf4713c2e
title: plugin README 安装锚点 + 命令真相源(系统级)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr1-plugin-readme-anchor
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:05:25.414Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# plugin README 安装锚点 + 命令真相源(系统级)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | su-ccb-claude-plugin README install 段加锚点、强调系统级,把混入的 codex-skills 命令改为链接 |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr1-plugin-readme-anchor · plugin README 安装锚点 + 命令真相源(系统级) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

把 `su-ccb-claude-plugin/README.md` 的安装段做成"命令真相源":给它稳定锚点(`#install`),只放本组件自己的安装命令(`/plugin marketplace add` + `/plugin install ccb@SU-CCB`),并讲清"装在**系统级** Claude Code CLI,再起 CCB/Oriel,CCB 会把系统级 settings 投影进每个 agent"。现有"快速开始"里**混入的 codex-skills 安装命令改成链接**到 codex-skills README——落实"谁拥有组件谁放命令、别处只链接"。纯文档,子仓改动。

### 二、任务分解

- `su-ccb-claude-plugin/README.md`「快速开始」段:
  - 给 plugin 安装命令块加可被别仓链接的锚点(稳定标题或 `<a id="install">`)。
  - 补一句"先在系统级 Claude Code 装 plugin,再起 CCB/Oriel;CCB 把系统级 `~/.claude/settings.json` 投影进每个 slot"(**不写** "plugins 目录软链继承")。
  - 把第 2 步 codex-skills 的 `$skill-installer` 两行**改成一句话 + 链接**到 su-ccb-codex-skills README 的 install 锚点,不再复制完整命令。
- 不动 README 其它段(理念/流程/命令表/依赖表)。

### 三、验收标准

- [ ] plugin README 有可被别仓链接的 install 锚点。
- [ ] install 块含 `/plugin install ccb@SU-CCB` 且出现"系统级"措辞。
- [ ] `rg '\$skill-installer' su-ccb-claude-plugin/README.md` 0 命中(已改为链接)。
- [ ] 子仓 commit+push;主仓抬 su-ccb-claude-plugin gitlink。

### 四、边界 / 禁止

- 只改 `su-ccb-claude-plugin/README.md`。不碰 skills/lib/kernel。
- 不复制 codex-skills 命令(单一真相源)。

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
- Section: pr1-plugin-readme-anchor
- Owner: ccb_codex
- Priority: high
- Dependencies: none

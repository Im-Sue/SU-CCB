---
doc_type: dev_task
task_id: subtask-254a2416ee6a
title: check-prerequisites.sh 加 ccb/tmux + 防假绿
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr5-check-prerequisites-extend
order: 5
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:11:43.896Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# check-prerequisites.sh 加 ccb/tmux + 防假绿

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 加 ccb/tmux 检查(ccb --print-version)+ 自动可验/仅提示分段防假绿 |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr5-check-prerequisites-extend · check-prerequisites.sh 加 ccb/tmux + 防假绿 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

扩展 `scripts/check-prerequisites.sh`:在现有 Node/pnpm/git/python/build/WSL 检查上,加 `ccb`、`tmux` 存在性检查;并把输出分"自动可验"与"仅提示(需手动)"两段——明确"CLI 在 ≠ 已登录/已 init/plugin 已启用",防假绿。

### 二、任务分解

- `scripts/check-prerequisites.sh`:
  - 加 `command_required` 检查 `ccb`、`tmux`(缺失给安装提示,如指向 bridge README)。
  - 探测 ccb 用 `ccb --print-version` 或 `ccb --help`,**不用 `ccb version`**(会联网检查更新,不宜进脚本)。
  - 末尾输出"仅提示"段:列脚本**无法自动验证**的项(Claude/Codex CLI 已登录、项目已 `/ccb:su-init`、plugin 已系统级启用),提示用户自查。
  - 保持现有"全绿才 exit 0"退出码契约。

### 三、验收标准

- [ ] 缺 ccb 或 tmux 时脚本 `PREREQ_FAIL` 并给安装提示。
- [ ] `rg 'ccb version' scripts/check-prerequisites.sh` 0 命中(用 --print-version)。
- [ ] 输出含"仅提示/需手动"段,点名登录/init/plugin 启用三项不被自动验证。

### 四、边界 / 禁止

- 只改 `scripts/check-prerequisites.sh`。不改其"全绿 exit 0"契约语义。

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
- Section: pr5-check-prerequisites-extend
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

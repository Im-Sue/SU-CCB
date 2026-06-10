---
doc_type: dev_task
task_id: subtask-0e918c1f75fd
title: SU-Oriel README 控制台用户完整上手 + ccb kill 收尾
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr3-suoriel-readme-console
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-a3ccf4713c2e, subtask-f3438763fe0a]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:16:13.700Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# SU-Oriel README 控制台用户完整上手 + ccb kill 收尾

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 控制台用户独立 clone SU-Oriel 自洽上手 + 评估者 5 分钟 + ccb kill;链接 pr1/pr2 锚点 |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr3-suoriel-readme-console · SU-Oriel README 控制台用户完整上手 + ccb kill 收尾 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

给 `su-oriel/README.md` 写"控制台用户"的完整上手——这是控制台用户**唯一会看的仓**,必须自洽:独立 clone SU-Oriel(不要求 SU-CCB)→ 装/起控制台 → 系统级装 plugin/skills(链接 pr1/pr2 锚点,不复制命令)→ 装 bridge → 每加项目跑 `/ccb:su-init` → 用 `ccb kill` 收尾。再加一条"评估者 5 分钟看控制台"最短路径。纯文档,子仓改动。

### 二、任务分解

- `su-oriel/README.md`:
  - 「控制台用户上手」有序步骤:`git clone …/SU-Oriel.git && cd SU-Oriel && pnpm install && pnpm build` → 起 `scripts/dev-server.sh` + `dev-web.sh`(另开 shell)。
  - 「系统级装 plugin/skills」:一句话 + 链接 pr1(plugin README install 锚点)/ pr2(codex-skills README install 锚点),**不复制命令**。
  - 「装底层 bridge」:链接 claude_codex_bridge 官方 README(`./install.sh install`)。
  - 「每加一个项目」:说明控制台顶部 ProjectOnboardingBanner——一键投递或终端 `/ccb:su-init`;ready 判定(`.ccb/ccb.config` + `docs/.ccb/docs-structure-contract.yaml`)。
  - 「收尾」:`ccb kill`(残留 `ccb kill -f`);oriel dev server/web 关对应终端 / Ctrl-C;强调后台 `project ccbd` 是**有意常驻**(长任务不被打断),不是 bug。
  - 「评估者 5 分钟看控制台」最短路径,首屏可见,带稳定锚点供顶层 README 指。

### 三、验收标准

- [ ] SU-Oriel README 自洽:控制台用户不 clone SU-CCB 也能照走装→起→加项目→收尾。
- [ ] plugin/skills 安装为链接(非复制命令);含 `ccb kill` 收尾段 + "有意常驻"说明 + 评估者 5 分钟锚点。
- [ ] 子仓 commit+push;主仓抬 su-oriel gitlink。

### 四、边界 / 禁止

- 只改 `su-oriel/README.md`。不碰 oriel server/web 代码、不改启停行为。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a3ccf4713c2e, subtask-f3438763fe0a
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
- Section: pr3-suoriel-readme-console
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a3ccf4713c2e, subtask-f3438763fe0a

---
doc_type: dev_task
task_id: subtask-370cac426157
title: 打开 CCB_REPLY_LANG 默认中文 + 校准 CLAUDE.md 措辞
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpzb7fxf8d099992749dd2ae
section_id: pr1-ccb-reply-lang-zh
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzb7fxf8d099992749dd2ae.json
source_draft_hash: 071c14ae70e0f1b25ae33cdd9ad6c18f4312df4eae991638d7127ebac15c7443
created_at: 2026-06-04T13:15:58.339Z
updated_at: 2026-06-04T14:36:08.140Z
updated_by: ai_session
code_workspace: {"path":"../SU-CCB-req-cmpzb7fxf8d099992749dd2ae","branch":"ccb/req-cmpzb7fxf8d099992749dd2ae"}
---

# 打开 CCB_REPLY_LANG 默认中文 + 校准 CLAUDE.md 措辞

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | su-oriel launcher 注入规范化 CCB_REPLY_LANG=zh（+Vitest 单测）+ 主仓 CLAUDE.md 措辞校准；跨仓单原子任务。 |
| 需求来源 | cmpzb7fxf8d099992749dd2ae |
| 本期范围 | pr1-ccb-reply-lang-zh · 打开 CCB_REPLY_LANG 默认中文 + 校准 CLAUDE.md 措辞 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
打开 ccbd 既有的 `CCB_REPLY_LANG` 开关，让本项目所有 Claude provider agent 面向用户的自然语言回复默认中文；代码、路径、commit、工具原始输出保留英文。这是需求 9dd2ae 的完整交付。

**跨仓变更**：核心改动在 `su-oriel` 子模块（git submodule），CLAUDE.md 在主仓（superproject）——同一子任务内两个 git 边界，回执必须分别列出两个 repo 的状态。

#### 任务分解
1. **su-oriel · launcher env 注入**（核心行为改动）
   - 文件 `su-oriel/server/src/modules/anchor-lifecycle/ccbd-launcher.service.ts` 的 `buildTmuxLaunchCommand()`（现 env 前缀 `env -u TMUX -u TMUX_PANE CCB_NO_ATTACH=1 CCB_SKIP_STARTUP_UPDATE_CHECK=1`）。
   - 追加 `CCB_REPLY_LANG=<规范化值>`。取值规范化（可内联，**不必导出私有 helper**）：`raw = process.env.CCB_REPLY_LANG ?? process.env.CCB_LANG ?? ""`；`norm = lower(trim(raw))`；`en` 当 `norm ∈ {en, english}`；否则（`zh / cn / chinese / 空 / auto / 非法`）→ `zh`。合法显式值优先。
2. **su-oriel · 单测**（Vitest；扩展现有 spec 经 `start()` 捕获 launch command，无需导出私有函数）
   - 默认（无 env）→ `CCB_REPLY_LANG=zh`
   - `CCB_REPLY_LANG=en` → `en`；空 / `auto` / 非法 → `zh`；`cn` / `chinese` → `zh`
   - `CCB_LANG` fallback：`CCB_REPLY_LANG` 未设 + `CCB_LANG=en` → `en`；`CCB_LANG=cn/chinese` → `zh`
   - 优先级：`CCB_REPLY_LANG=en` + `CCB_LANG=zh` → `en`
   - 每个 env 用例必须 restore / delete `process.env.CCB_REPLY_LANG` 与 `process.env.CCB_LANG`，避免污染同进程 Vitest
3. **root · CLAUDE.md 措辞校准**
   - 现「永远中文回答」（粗口径）改为：「面向用户回复默认中文；代码 / 路径 / 标识符 / commit / 工具输出保留英文」，与验收口径一致。

#### 验收标准
**自动（硬门）**：
- [ ] launcher 单测全绿（默认 / 覆盖 / 回落 / 归一 / `CCB_LANG` fallback / 优先级）
- [ ] su-oriel typecheck 通过

**手动 / 门控（回执须注明是否已跑、结果如何）**：
- [ ] **kill 并重启对应 project 的 ccbd 守护进程后**，从 Console 发一条指令，Claude 面向用户回复为中文；回复中的代码块 / 路径仍英文（只刷新 Console 或复用旧 daemon 不算）
- [ ] `CCB_REPLY_LANG=en` + 重启 daemon → 回复英文

#### 边界 / 不做
- 不改仓外 ccbd 源码（`prompt.py` / `control_plane_env` 不碰）
- 不动 codex agent 行为
- 不删除 / 消费 payload `language`（follow-up，本轮不落地）
- 不为「严格 Console-only」改协议加 per-message route option
- **不把主仓现有未跟踪 / 已改的无关文档草稿混入本任务交付**（仅交付本任务的 su-oriel 代码 + 测试 + 根 CLAUDE.md）

#### 依赖 / 执行注意
- 依赖 ccbd 既有 `CCB_REPLY_LANG` 契约（`prompt.py:_language_hint`，已核验；传播链 `launcher env → control_plane_env allowlist → ccbd worker → prompt wrapper`）
- 单子任务，无内部并发冲突，无前置依赖
- su-oriel 是 submodule：按既有 worktree 流程实施，husky 缺失用 `--no-verify`；本任务不要求 push，若提交需分别处理子模块仓与主仓
- **生效前提**：改后必须重启对应 project ccbd，否则旧 worker 不受影响（验收易误判）

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-04 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpzb7fxf8d099992749dd2ae
- Section: pr1-ccb-reply-lang-zh
- Owner: ccb_codex
- Priority: high
- Dependencies: none

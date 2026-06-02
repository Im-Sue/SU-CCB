---
doc_type: technical_design
requirement_id: cmpimplworktree20260526
title: 实施期 per-需求 worktree · 技术设计（4 设计点定死）
status: drafting
created: 2026-06-01
updated: 2026-06-01
references:
  - docs/06_决策记录/ADR-0036-per-requirement-implementation-worktree.md
  - docs/02_需求设计/实施期-per-需求-worktree-字段驱动代码隔离-260526-需求.md
consult_evidence:
  - job_ad8e238d96de  # slot1_codex tech-design consult / rep_764b14480736
---

# 实施期 per-需求 worktree · 技术设计

> 本设计在 [ADR-0036](../06_决策记录/ADR-0036-per-requirement-implementation-worktree.md) 已定方向上，定死 4 个 requirement_analysis 阶段遗留的技术设计点。基准设计（**一需求一 worktree、字段驱动、plugin 全包、真相锚主仓、代码隔离回流**）见 ADR-0036，不在此重复，本文档只补「怎么做」的细节。
> 协商：slot1_codex tech-design consult `job_ad8e238d96de` / `rep_764b14480736`（1 轮，确认 4 点方向 + 硬化 4 处）。用户已拍板**范围 B**。

## 一、设计概述

- **目标**：把 ADR-0036 的 per-需求 worktree 机制落到可实施粒度，定死 4 个设计点：① 谁建 worktree ② codex 如何在 worktree 改码 ③ auto-commit 闸门 ④ 归档分支缺失降级；并补 1 个衍生决策（target_branch/base_sha 写入时机）。
- **范围 B（用户拍板）**：建新机制 + 封口 Console 两个旧 worktree 入口 + prune 已验证安全的废弃 worktree；完整删死代码留 follow-up。
- **不做项**：不改 ADR-0032 决策 1.3「真相 inplace」；不引新依赖；不删 Console worktree 死代码本体（只封入口）；不为存量 dev_task 回填字段；不新增全局结构化验证 schema 字段（用写作约定，见决策 3）。

## 二、方案与架构

- **两个工作区角色**：
  - `canonicalRoot` = ccb 启动 cwd = 主仓；只经 plugin lib 读写 `docs/.ccb` 与人读 docs。
  - `codeRoot` = worktree（sibling `../SU-CCB-req-<reqId>`）；只改代码、跑 git、跑测试。
- **职责归属**：
  - **plugin**：物化盖字段、`ensure/archive/discard` lib helper、dispatch/implementation/batch/archive/cancel 五节点 manifest 接入生命周期。
  - **codex `ccb-execute`**：只消费已建好的 codeRoot + fail-fast 校验 + 子任务级 auto-commit + commit-guard。**不参与 worktree 建删**。
  - **Console**：纯投影 + 封口两个旧 worktree 入口。
- 全流程阶段映射沿用 ADR-0036「worktree 在全流程的位置」表，不重复。

## 三、关键决策与取舍（4 点定死 + Codex 硬化）

### 决策 1 · ensure 归属 = plugin dispatch 侧（codex fail-fast 消费）

- **决定**：dispatch 节点（plugin/Claude 驱动；autonomous-batch 同）在 `ccb ask` 派工**前** `await ensureRequirementWorktree`（幂等：首次 `git worktree add`，后续 no-op）。codex `ccb-execute` **不自建**，只 fail-fast 校验：`code_workspace` 缺失 / path 不存在 / branch 不匹配 → 拒绝实施并回执。
- **取舍**：拒「codex 自 ensure」（跨分发依赖 plugin lib + 锁不在 codex 侧）；拒「ccb hook 隐式建」（worktree 生命周期脱离 manifest + 审计，Codex 反对）。
- **并发**：同 req 由 canonical-root lock 串行；autonomous-batch 重复 ensure 是幂等 no-op；dispatch 在 ask 前 await，不与 codex 启动竞态。

### 决策 2 · codeRoot 接入 = 每命令 `cwd=codeRoot`（非仅绝对路径）

- **决定**：进程 cwd 保持主仓不变（ADR-0032 1.3）；但 codex 所有**代码命令以 `cwd=codeRoot` 执行**、git 用 `git -C codeRoot`；`docs/.ccb` 读写一律 `canonicalRoot` 绝对路径。`codeRoot = resolve(canonicalRoot, code_workspace.path)`。
- **取舍**：拒「仅在主仓 cwd 下传绝对路径」——pnpm workspace 根 / 相对配置 / `.gitignore` 依赖执行 cwd，会踩坑（**Codex 纠正我原方案过软**）；拒「进程级 `cd` 进 worktree」——`docs/.ccb` 相对路径会写错地方，正是要根除的 bug。

### 决策 3 · auto-commit 闸门 = 子任务声明的结构化验证命令 exit 0

- **决定**：子任务 `spec_section_md` 用**固定写作约定**声明验证——`## 验证` 下一个 fenced 代码块逐行列可执行命令（typecheck/lint/test）。`ccb-execute` 逐条跑，全 exit 0 → auto-commit 标 `verified`，回执记命令+结果+sha。无验证块 → 仍 commit 但标 `unverified`，review/archive **不得**把它等价为已验证（review 须显式标未验证风险）。
- **取舍**：拒「解析中文验收自然语言」（不可执行，Codex 纠正）；拒「新增全局 `verification.commands[]` schema 字段」（越界扩 dev_task schema、影响所有任务）——改用写作约定（fenced block）给 PR4 稳定输入，**零 schema 扩张**。结构化 schema 字段列为 follow-up。

### 决策 4 · 归档分支缺失 = 保留现场升级用户（绝不 fallback main）

- **决定**：archive preflight 校验 `target_branch` 存在且可合。
  - 不存在/被删 → 不 auto-merge、保留 worktree+分支、升级用户。
  - divergence（target_branch 大幅前进/重写、`base_sha` 已非其祖先）→ 允许 merge 但 preflight **报告 divergence 风险**；冲突 → `merge --abort` 保留现场 + 升级。
  - `target_branch` ≠ 当前 canonical 分支 → 升级用户，**不自动 `switch`**。
  - **绝不 fallback 硬编码 main**（ADR-0036 不变量#3）。

### 决策 5 · target_branch / base_sha 在 ensure（建时）写，不在 materialize（采纳 Codex risk 1）

- **决定**：`code_workspace` 在 materialize 只盖**声明**字段 `path` + `branch`（由 reqId 确定）。`target_branch`（建时 canonical 分支）+ `base_sha`（建时 HEAD）由 `ensure` 在物理建时写入 **worktree 运行态**（`docs/.ccb`，经 plugin lib），archive 读运行态。
- **理由**：ADR-0036 字段注释本就说 target_branch/base_sha 是「建 worktree 时」的值，而 materialize 早于建时，盖死会失真。

## 四、核心流程 / 逻辑

1. **物化**：`su-materialize` 在子任务 spec frontmatter 盖 `code_workspace{path, branch}`（仅声明，不建）。
2. **首次派工**：plugin dispatch `await ensure` → `git worktree add` 建 codeRoot + 写运行态 `{confirmed_target_branch=当前分支, base_sha=HEAD}` → 再 `ccb ask` 派 codex。
3. **实施**：codex 读 `code_workspace` → fail-fast 校验 → 以 `cwd=codeRoot` 改码/跑测试/git；`docs/.ccb` 写一律 canonicalRoot。子任务验证块全 exit 0 → auto-commit（`verified`），回执带 sha；commit-guard 拒任何 `docs/.ccb` 改动进 worktree 分支（查 staged/unstaged/untracked 三态）。
4. **审查**：inplace 主仓读 worktree 分支 diff；`unverified` 提交显式标风险。
5. **归档**：preflight（worktree+主仓 clean、target_branch 校验，见决策 4）→ merge 回运行态记录的 target_branch → `worktree remove` → `branch -d`。
6. **取消**：`discard` = `worktree remove --force` + `branch -D`，不 merge。

## 五、测试策略

- **lib helper 单测**：ensure 幂等 / path 冲突 fail / branch 他处 checkout 不盲 force；archive target 缺失降级、divergence 报告、冲突 abort 保留；discard 不 merge；canonical-root lock 串行（模拟同 req 并发）。
- **commit-guard**：staged / unstaged / untracked 三态 `docs/.ccb` 都拒（Codex risk 3）。
- **ccb-execute**：`cwd=codeRoot` 跑 git/测试；fail-fast（字段缺失/path 不存在/branch 不符）；验证块解析 + verified/unverified 标记。
- **Console 封口**：Web 不再暴露建/清 worktree 入口；相关 route disable/拒。
- **回归**：现有 dev_task（无 `code_workspace`）validator 仍通过（字段 optional）。

## 六、数据设计

- `code_workspace`（`dev-task.schema.yaml` 新增 **optional** 对象）：materialize 盖 `path`、`branch`；`target_branch`、`base_sha` 可选（运行态优先，见决策 5）。
- **worktree 运行态**（`docs/.ccb`，plugin lib 写）：per-req 记 `confirmed_target_branch`、`base_sha`、worktree 物理建/合/删审计。

## 七、接口设计

- **无新增网络 API**。Console 封口是**移除/禁用**入口（task-run `apply.routes` worktree 分支 + `workspace.routes`/Web 按钮），不新增接口。
- **plugin lib 函数**：`ensureRequirementWorktree({projectRoot, requirementId, codeWorkspace})` / `archiveRequirementWorktree(...)` / `discardRequirementWorktree(...)`。

## 八、文件结构 / 变更清单（实施面，供拆分细化）

- **su-ccb-claude-plugin**：`references/kernel/schemas/dev-task.schema.yaml` + 重生 validator；`lib/subtask` materialize 盖 `path/branch`；新 `lib/worktree`（ensure/archive/discard + lock + 运行态写）；dispatch/implementation/batch/archive/cancel 五 manifest 接入。
- **su-ccb-codex-skills**：`ccb-execute` 路径纪律（`cwd=codeRoot`）+ fail-fast + auto-commit（verified/unverified）+ commit-guard（三态查 `docs/.ccb`）。
- **Console**：封 task-run + workspace 两 worktree 入口（feature-flag/隐藏 UI + route disable）；可选只读投影。
- **preflight**：`git worktree prune`（清 3 个 dir-missing stale）+ 移除 3 个已验证 clean+merged 的 `.workspaces` worktree。

## 九、依赖与配置

- **无新依赖**（git 原生 worktree）。**无 DB migration**（封口用 disable/flag，不删表）。

## 十、迁移影响与风险

- 长生命周期分支归档集中暴露冲突 → 升级用户，不自动 merge。
- commit-guard 漏查 untracked → archive 才暴露污染 → 三态全查。
- autonomous-batch 重复 ensure → 幂等 no-op 保证。
- **必问扫描结论**：schema 改动（`code_workspace` optional）已由 ADR-0036 + 用户方向拍板覆盖；无新依赖 / 无 migration / 无成本 / 无合规命中 → 本设计为 AI 自决实现细节，**无新增用户必问**。

## 变更记录

- 2026-06-01 创建。基于 ADR-0036 + slot1_codex consult `job_ad8e238d96de`。

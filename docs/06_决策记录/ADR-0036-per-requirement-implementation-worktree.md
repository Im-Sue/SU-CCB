---
id: ADR-0036
title: per-需求实施 worktree · 字段驱动的非 canonical 代码隔离
status: active
decided_at: 2026-05-26
last_updated: 2026-06-06
parent_adrs:
  - ADR-0023  # plugin sovereignty（本 ADR amend 决策 2 的 worktree 归属）
  - ADR-0032  # α-X slot topology（本 ADR refine 决策 1.4 的 opt-in 场景）
related_adrs:
  - ADR-0018  # task anchor runtime（每需求强制 worktree 已被 ADR-0032 废止）
consult_evidence:
  - job_a3bbe8b3fc7e  # main_codex consult / rep_f66fb0b1a03b
  - job_32f2decc1cf9  # cmpworktreearchive260604 技术设计共识
  - job_177c0723a3ee  # autonomous-batch 执行序与自指风险核对
tags:
  - worktree
  - plugin-sovereignty
  - code-isolation
  - ccb-execute
  - su-materialize
---

# ADR-0036: per-需求实施 worktree · 字段驱动的非 canonical 代码隔离

## Status

Active（2026-05-26）。2026-06-06 amended by requirement `cmpworktreearchive260604`：修复 per-需求 worktree 在多子任务串行归档时提前 archive 的分层错误，并加入 `merged` 预览暂停、手动归档与 reopen。

## Context

- v1.0 后发现 `su-batch` 推进子任务实施全程不建 worktree。排查确认：这是 ADR-0032 决策 1.4 **有意废止每需求强制 worktree** 的结果，不是回归 bug。Console 两套 worktree 代码（`anchor-lifecycle/git-worktree.service.ts`、`task-run/worktree.service.ts`）已死/孤儿。
- 但 1.4 把 worktree 降级为「opt-in 非 canonical 代码隔离」后，该 opt-in 路径一直没落地（roadmap「上游 worktree 机制对齐」未做）。现状是「完全无隔离」：跨 slot 并发改代码、autonomous batch 失败都会脏主仓。
- 两个 `.ccb` 命名空间：根 `/.ccb`（ccb runtime，上游保证锚主仓）vs `docs/.ccb`（业务 canonical，Console indexer 投影源，是普通工作树文件、上游不保护）。2026-05-23 投影 bug 的机制 = anchor 在 per-subject worktree 里写 `docs/.ccb`，Console 盯主仓看不到。
- 上游 ccb worktree = per-agent opt-in、代码隔离、runtime 真相锚主仓、无自动回流。我们对齐其精神，但 `docs/.ccb` 是工作树文件、上游不保护，必须自己补「真相锚主仓」不变量。
- 2026-06-04 需求 `cmpworktreearchive260604` 发现旧实现把 merge+删分支放在**每个子任务 archive**：同一需求第二个子任务再次 `ensure` 会撞到 runtime 已 `archived`。该语义与“一需求一 worktree、同需求子任务串行复用”冲突，故本 ADR 修订归档分层。

## Decision

### 1. worktree 归属：operational → plugin 业务规则（amend ADR-0023 决策 2）

ADR-0023 决策 2 曾把 worktree 管理划为 Operational（Console API 直驱）。本 ADR 改判：per-需求实施 worktree 的建/合/删由 **plugin lib + 节点 manifest** 拥有；Console 退回纯投影（从主仓 state/EventJournal 读 worktree 状态）。理由：worktree 路径键于需求（业务语义），实施由 plugin 驱动的 agent 执行，plugin 主权下业务编排归 plugin。

### 2. opt-in 场景具体化：per-需求实施 worktree（refine ADR-0032 决策 1.4）

1.4 的「opt-in 代码隔离」落为：**一需求一 worktree**，与 sticky slot 同生命周期。同需求子任务串行共用一个 worktree（ADR-0018 子任务串行）。**1.3 真相 inplace 一字不动**。agent 仍由 ccbd inplace 启动（cwd=主仓），worktree 是正交的代码暂存层，不改 ccb `workspace_mode`。

运行态状态机（`docs/.ccb/worktrees/<req>.json`，schema additive optional，不 bump）：

```text
missing -> ready -> merged -> archived
ready   -> discarded
merged  -> ready      # explicit reopen
```

- `ready`：实施分支和 worktree 存在，可继续派工。
- `merged`：实施分支已 merge 回记录的 target branch，但 worktree+分支仍保留；这是**合并后预览暂停态**，非终态、非 delivered。
- `archived` / `discarded`：终态。
- `discard` 只允许 `ready→discarded`；`merged→ready` 只能经显式 reopen。

### 3. 字段驱动（不靠 ask 协议传递）

`su-materialize` 创建子任务时在 spec frontmatter 盖**可选**字段：

```yaml
code_workspace:
  path: ../SU-CCB-req-<reqId>
  branch: ccb/req-<reqId>
  target_branch: <建 worktree 时的接入分支>   # 不硬编码 main，本仓当前为 v1.0-plugin-sovereignty
  base_sha: <建时 HEAD sha>
```

执行方读子任务 spec 时顺带读到，**无需新增 ask payload 字段或新协议**。字段名用 `code_workspace` 避免与 ccb `workspace_mode` 混淆。须同步 `subtask-spec` schema + 重新生成 validator（当前 validator 不拒未知字段，但 contract 层要补）。

### 4. plugin lib 生命周期 helper（保守幂等）

新增/修订 `ensureRequirementWorktree` / `mergeRequirementWorktree` / `cleanupRequirementWorktree` / `reopenRequirementWorktree` / `discardRequirementWorktree`，以 canonical-root lock 串行同 req 操作；旧 `archiveRequirementWorktree` 仅保留为兼容 wrapper（`merge+cleanup`），不再作为子任务 archive 入口。

- **ensure**：先 `git worktree prune`；`git worktree list --porcelain` 判 path/branch 绑定；path 存在但非预期 worktree → fail；branch 已在他处 checkout 不盲目 `--force`；首次才 `add`。
- **merge**：只吃 `ready→merged`；先 canonical-sync-commit（见决策 7），再把实施分支 merge 回 runtime 记录的 `target_branch`，保留 worktree+分支；分支 tip 已是 target 祖先时 no-op 补写 `merged`。
- **cleanup**：只吃 `merged→archived`；要求 branch tip 是 target 祖先，再 `worktree remove` + `branch -d`；若 git 资源已清但 state 未写，允许 recovery 补写 `archived`。
- **reopen**：只吃 `merged→ready`；不改 git，校验 worktree+分支仍在且 worktree clean，复用同一实施分支返工。
- **discard（cancel）**：只允许 `ready→discarded`，不 merge，`worktree remove --force` + `branch -D`。

### 4.1 归档分层翻转（amend 旧 archive 语义）

旧语义「子任务 archive 前 merge+删分支」被废止：

1. 子任务 archive 只写 dev_task 终态（`status: done`、`current_node: archive`、`review_status: passed`），不碰 worktree。
2. autonomous-batch 在全需求非 cancelled dev_task 终态后，只自动 `mergeRequirementWorktree()`，进入 `merged` 并停止；requirement 保持非 delivered（通常 `delivering`）。
3. cleanup + `requirement.finalize` 移到手动 `/ccb:su-archive requirement_id=<id>` 需求级入口。该入口在 cleanup 成功后重新读 requirement md hash，再 finalize 为 `delivered`。
4. 若 cleanup 成功但 finalize CAS/guard 失败，允许 `archived + requirement 仍非 delivered` 的 finalize-only 重入。

### 5. ccb-execute 路径纪律 + 子任务级 auto-commit

`canonicalRoot` = 启动 cwd（主仓），只读写 `docs/.ccb`；`codeRoot` = stamped worktree，只在此读改代码、跑 git、跑测试、用绝对路径 apply patch。每个子任务实现 + 验证通过后，在 worktree 分支 **auto-commit**，回执带 commit sha（用户 2026-05-26 授权 auto-commit；归档 merge 依赖有可合的提交）。

### 6. commit-guard 取代 sparse-checkout

不用 sparse 排除整个 `docs/`（会炸 indexer / 测试 / 模板 / schema）。真正护栏 = 路径纪律 + **commit 时拒绝任何 `docs/.ccb` 改动进 worktree 分支** + archive 前置校验。sparse 至多排 `docs/.ccb/` 且非主机制（agent 仍能 re-`mkdir`）。

### 7. canonical-sync-commit allowlist

merge 前允许 plugin 在 canonical root 自动提交**本需求 CCB-owned 件**：

- 本 requirement 的 dev_task md；
- `docs/02_需求设计/<req>.md`；
- `docs/00_文档地图.md`；
- `docs/.ccb/events/journal.jsonl`；
- `docs/.ccb/worktrees/<req>.json`；
- `docs/.ccb/drafts/breakdown/<req>.json`。

allowlist 外 dirty 必须升级 `canonical_dirty_outside_allowlist`，不得 broad add 或替用户合入其他需求杂件。

### 8. finalize evidence 解耦 batch scope

`requirement.finalize` policy additive 接受：

- 旧 `dev_task_scope_terminal`（batch scope + `batch_authorization_completed` 事件）；
- 新 `dev_task_requirement_terminal`（按 `requirement_id` 扫全部非 cancelled dev_task，要求 done+archive+passed，不依赖 batch 事件）。

手动需求级归档走 requirement-wide evidence；旧 scope evidence 保留兼容。

## 不变量（违反即视为回归）

1. canonical 真相（`docs/.ccb`）永远经 plugin lib 以主仓绝对路径写，绝不进 worktree、不靠 git 回流。
2. 代码改动只在 worktree；git 回流只回代码。
3. merge target = 记录的 `target_branch`，绝不硬编码 `main`。
4. `merged` 不是 delivered；Console rollup 不得凭全子任务 archive 推导 delivered，delivered 只镜像 canonical requirement status。
5. Console 始终只投影，不参与 worktree 建删。

## 实施面（派 Codex 实施）

- **su-ccb-claude-plugin**：`su-materialize` 盖字段；lib 生命周期 helper；`dispatch`/`implementation`/`batch`/`archive`/`cancel` 节点 manifest 接入 lifecycle；`subtask-spec` schema + 生成 validator；capability-outcome evidence policy additive。
- **su-ccb-codex-skills**：`ccb-execute` 加路径纪律 + 子任务级 auto-commit + commit-guard 条款。
- **su-oriel**：progress aggregation / rollup 严绑 canonical status；全子任务 archive 但 canonical 非 delivered 时仍为 delivering。
- **落地前**：先清理本仓 stale worktree 记录 + 主仓 dirty（helper preflight 依赖 clean 状态）。
- **Console**：仅加 worktree 状态投影（可选，从主仓读），不参与建删。

## Risks

- auto-commit 是新行为（已授权）；长生命周期分支会在归档时集中暴露冲突。
- sparse 配错或排整个 `docs/` 会破坏测试 / indexer / 模板 / schema 读取。
- 本仓当前 dirty + 有 stale worktree 记录，落地需先清场，且不要在脏树上贸然试。
- cleanup/finalize 非事务；必须保留 finalize-only recovery，避免 worktree 已清但 requirement 仍 delivering 卡死。

## Provenance

- 排查链：su-batch 不建 worktree → ADR-0032 1.4 有意废止 → 上游 worktree 机制核验（`/home/sue/.local/share/codex-dual`：默认 inplace、per-agent opt-in、runtime state 锚主仓）→ 字段驱动方案。
- consult：main_codex `job_a3bbe8b3fc7e` / `rep_f66fb0b1a03b`（findings + 4 点逐条可行性 + 最简稳妥形态；纠正了 sparse 越界、merge target 硬编码、helper 幂等保守性）。
- 用户拍板：worktree 归属 = plugin 全包、per-需求键（按 reqId）、子任务级 auto-commit。
- 2026-06-06 修订来源：需求 `cmpworktreearchive260604`、技术设计 `per-需求worktree-归档分层修复与预览式归档-260604-技术设计.md`、consult `job_32f2decc1cf9`（设计共识）与 `job_177c0723a3ee`（batch 自指风险/执行序核对）。

---
id: td-worktree-archive-layering-260604
title: per-需求 worktree 归档分层修复 + 合并后预览式归档 技术设计
doc_type: technical_design
requirement_id: cmpworktreearchive260604
updated: 2026-06-04
---

# per-需求 worktree 归档分层 + 合并后预览式归档 · 技术设计

> 一句话：把 worktree 的 merge/cleanup 从「子任务 archive」上提到「需求级」，新增 `merged` 预览运行态与 `merged→ready` 显式 reopen，自动合并落 su-batch 尾部（全需求 done 才触发）、`delivered` 改绑手动归档 cleanup 之后。
>
> **无独立 status** —— 跟随 `requirement_id`=cmpworktreearchive260604 的需求。｜协商：consult `job_ad0011770d37`(分析) + `job_32f2decc1cf9`(设计) @slot2_codex。

---

## 一、设计概述

- **目标**：(A) 修 ADR-0036 子任务级归档漂移 bug——多子任务串行第 2 个 `ensure` 撞 `already archived`；(B) 加「合并后预览、手动归档」交互。
- **根因**：worktree 是 per-需求共享，但 merge+删分支被放在**每个子任务** archive（`archive.node.md` 第7点 + `su-batch` 第8点组合触发），`ensure` 对非 `ready` fail-fast（`lib/worktree/index.mjs:314`）。
- **不做项**：auto-commit（已在 codex `ccb-execute`）；Console UI「归档」按钮（follow-up）；remote push（用户拍板不 push）；存量 state 迁移（零迁移，见 §十）。
- **用户已拍板（需求分析）**：返工=复用实施分支 + 显式 reopen；自动合并=全需求子任务 done 才触发；源分支可污染；不 push。本设计无新增用户拍板项（Codex 同意）。

## 二、方案与架构

### 2.1 worktree 状态机（`lib/worktree/index.mjs`）

| 转换 | 触发 | 守卫 |
|---|---|---|
| `missing→ready` | `ensure` | 同今 |
| `ready→merged` | `merge`（新） | 只吃 `ready`；merge 分支回 target，**保留** worktree+分支 |
| `merged→archived` | `cleanup`（新） | 只吃 `merged`；branch tip 须为 target 祖先后再删 worktree+`branch -d` |
| `merged→ready` | `reopen`（新） | 只吃 `merged`；worktree+分支须仍在、worktree clean |
| `ready→discarded` | `discard` | **补 guard**：只允 `ready`（今完全不看 status） |

- `ensure` 续对一切非 `ready` fail-fast（`merged` 自然 fail-fast，仅 `reopen` 解冻）。
- `merged→discarded` 禁；`archived`/`discarded` 为终态。

### 2.2 函数拆分（旧 `archiveRequirementWorktree` → 三函数）

- `mergeRequirementWorktree({projectRoot, requirementId})`：`ready`→`merged`。canonical-sync-commit(§4.1) → merge → 写 `merged`。
- `cleanupRequirementWorktree(...)`：`merged`→`archived`。ancestor 校验 → worktree remove + `branch -d` → 写 `archived`。
- `reopenRequirementWorktree(...)`：`merged`→`ready`（不碰 git）。
- 旧 `archiveRequirementWorktree`：保留为 compat wrapper(merge+cleanup)，**禁** `su-archive`/`su-quick-archive`/`archive.node` 子任务级调用。

## 三、关键决策与取舍

1. **canonical dirty 处理 = 方案 C（显式 sync-commit + 精确 allowlist）**，否决 A（`git add docs/03` 太粗，会扫入他需求 dev_task/生成索引）、B（放宽 clean，canonical 长期 dirty 难证清白）。详见 §4.1。
2. **finalize evidence 解耦 batch**：新增 `dev_task_requirement_terminal` check（requirement 域，不依赖 `batch_authorization_completed`）。今 `dev_task_scope_terminal` 硬依赖 batch 事件（`evidence-registry.mjs:199`），手动归档不在 batch scope 会失败。详见 §4.4。
3. **schema 不 bump**：`merged` 及 `merged_branch_sha`/`target_sha_after_merge`/`merged_at`/`reopened_at` 走**additive-optional 字段**，保留 `requirement-worktree-v0.1`，以维持零迁移（避免使 9 个存量文件“旧版”）。
4. **cancelled 不阻断自动合并**：与现 `progress-aggregation`（排除 cancelled）一致、且 cancel 为 command-only（即显式取消证据）。仅要求**全部非 cancelled** dev_task 终态。（与 Codex「默认阻断」温和分歧，理由：cancel 已是显式决定。）
5. **手动归档 gate**：命令入口本需求改（必需）；Console 按钮 + `RequirementDetailPage.tsx:250`「仅 delivered 可归档」文案留 follow-up（届时改为支持 `delivering+merged`），本需求仅记“勿作唯一真相”提示。

**4 锚点反思**：① 同意 Codex 的 Option C / cleanup ancestor / finalize 解耦 / 幂等-by-sha；② 修正自己——Option A 范围过粗，采 C；微调 Codex——schema 不 bump 保零迁移；③ 盲点——finalize 的 `batch_authorization_completed` 硬耦合（手动归档会卡）、reopen 后 branch tip 漂移使 cleanup 不能只信 status；④ 接下来——task_breakdown。

## 四、核心流程 / 逻辑

### 4.1 canonical-sync-commit（方案 C，merge 前）
1. 计算 **allowlist**（仅本需求 CCB-owned）：本 requirement 的 dev_task md 路径（按 `requirement_id` 解析）+ `docs/02_需求设计/<req>.md` + `docs/00_文档地图.md` + `docs/.ccb/events/journal.jsonl` + `docs/.ccb/worktrees/<req>.json` + `docs/.ccb/drafts/breakdown/<req>.json`（若在）。
2. `git add <allowlist 内已变更项>` → 若有暂存 `git commit -m "chore(<req>): canonical sync before requirement merge"`。
3. 复查 `git status --porcelain`：**任何 allowlist 外的 dirty → escalation `canonical_dirty_outside_allowlist`**（不替用户合其未提交工作）。
4. 进入 merge。

### 4.2 mergeRequirementWorktree（`ready→merged`）
- 前置：worktree clean、canonical 在 target_branch（沿用今 preflight）+ §4.1。
- 幂等：若 `workspace.branch` tip 已是 `targetBranch` 祖先 → 视为 already-merged no-op，直接写 `merged`（处理「merge 成功但 state 写失败」重入）；否则 `git merge --no-edit <branch>`，冲突 → `merge --abort` + escalation。
- 成功写 `merged` + 记 `merged_branch_sha`/`target_sha_after_merge`/`merged_at`。**不删** worktree/分支。requirement 保持 `delivering`。

### 4.3 su-batch 尾部触发（`skills/su-batch` 第8点 + `archive.node.md` 第10点）
- 子任务 archive：只写 `status:done / current_node:archive / review_status:passed`，**不碰 worktree**。
- 新增 helper `isRequirementFullyTerminal(requirementId)`：扫 docs-structure 下全部 dev_task，按 `requirement_id` 聚合；**全部非 cancelled** 须 done+archive+passed，且无未物化的 approved follow-up draft。
- last scope member done 后：`isRequirementFullyTerminal` 为真 → `mergeRequirementWorktree` → 维持 `delivering`；为假 → 不合并（等其余子任务/其余 batch）。
- **`requirement.finalize→delivered` 从此处移除**（改由手动归档）。

### 4.4 手动归档命令（`delivering+merged → delivered`）
- 入口：`su-archive` 需求级模式（命令）。
- 顺序：`cleanupRequirementWorktree`（成功）→ `requirement.finalize`（delivered）。
- evidence：手动归档提供全量 `task_keys`+`dev_task_paths`，走新 `dev_task_requirement_terminal`（校验=该需求全部非 cancelled dev_task 终态，**不查 batch 事件**）+ `requirement_finalize_expected_hash`。
- **recovery**：支持 `archived + requirement 仍 delivering` 的 finalize-only 重入（cleanup 成功但 finalize CAS 失败不卡死）。

### 4.5 cleanup / reopen / discard
- `cleanup`：校验 branch tip 已 merged into target（祖先）→ 删 worktree+分支 → 写 `archived`；若 git 实况已清而 state 未写，允许补写 `archived`（幂等）。
- `reopen`：校验 worktree+分支在、worktree clean（dirty → escalation，防下次 sync-commit 扫入用户改动）→ 写 `ready` + `reopened_at`。返工后再次走 §4.2（多次 merge 靠祖先检查幂等）。
- `discard`：补 guard 只允 `ready`（`merged/archived/discarded` → ConflictError）。

## 五、测试策略

`lib/worktree/__tests__/worktree.test.mjs` 补（**今缺多子任务串行覆盖**）：
1. 多子任务串行：`ensure→（子任务done不碰worktree）→ensure` 复用返 noop（回归 bug A）。
2. `ready→merged→archived` 全链；`merged` 保留 worktree+分支。
3. `merged→ready` reopen → 追加 commit → 再 merge 幂等（祖先 no-op / 真合并两路）。
4. `discard` guard 拒 `merged`/`archived`。
5. canonical-sync-commit：allowlist 内提交、allowlist 外 dirty → escalation。
6. cleanup ancestor 校验：branch tip 非祖先 → escalation。
7. recovery：merge 成功 state 失败重入、cleanup 成功 finalize 失败重入。
- evidence-registry：`dev_task_requirement_terminal` 新 check 单测（全终态/有非终态/cancelled 排除）。
- `progress-aggregation.spec.ts`：全子任务 archive 但 canonical 未 delivered → 不算 delivered。
- 注：勿在主仓跑 server test（`db:prepare` 清 dev.db）。

## 六、数据设计

worktree runtime state（`docs/.ccb/worktrees/<req>.json`，schema 不 bump）新增 optional：`merged_branch_sha`、`target_sha_after_merge`、`merged_at`、`reopened_at`、`status` 增枚举值 `merged`。

## 七、接口设计

- lib 导出：`mergeRequirementWorktree`/`cleanupRequirementWorktree`/`reopenRequirementWorktree`（+ `archiveRequirementWorktree` compat）。
- skill 命令：`su-archive` 需求级手动归档模式、reopen 入口（命令）。
- capability evidence：新 check_id `dev_task_requirement_terminal`（`evidence-registry.mjs` + `capability-outcome-policy.yaml` finalize policy additive 接受）。
- 无新增 HTTP 公共 API（Console rollup 为内部计算改动）。

## 八、文件结构 / 变更清单

- `su-ccb-claude-plugin/lib/worktree/index.mjs`：状态机 + 拆 3 函数 + discard guard + sync-commit + 幂等/recovery。
- `su-ccb-claude-plugin/lib/capability-outcome/{evidence-registry.mjs, capability-outcome-policy.yaml, generated-policy.mjs}`：新 evidence check。
- `su-ccb-claude-plugin/references/kernel/nodes/{archive,batch}.node.md` + `skills/{su-batch,su-archive,su-quick-archive}/SKILL.md`：触发上提、finalize 移位、调用点改。
- `su-oriel/server/src/modules/task/progress-aggregation.ts`：rollup 不凭 archive 算 delivered。
- `docs/06_决策记录/ADR-0036-*.md`：修订（新增 merged/reopen/手动归档；merged 非终态）。
- 主仓 kernel 真相源改动须同步 plugin distribution 副本。

## 九、依赖与配置

无新增依赖（git 经现有 `execFile`；纯 lib 逻辑）。无新环境变量。

## 十、迁移影响与风险

- **零迁移**：现盘 9 state（6 discarded+3 ready+1 archived 终态）皆 inert；`merge` 只吃 `ready`、`cleanup` 只吃 `merged`，旧 `archived` 不被新机误吃；无 `merged` 存量。
- **风险**：① sync-commit 是新增自动提交——**精确 allowlist** 是安全前提，越界即 escalation；② `merged→ready` 致多次 merge，靠 branch-sha/祖先幂等；③ cleanup/finalize 非事务——必须 recovery state，避免半归档；④ 跨层契约（lib+node manifest+skill+Console+ADR）改动面广，task_breakdown 勿拆太碎（遵需求 Phase 5 议题4）。

## 变更记录

- 2026-06-04：初版（technical_design 节点，Claude + slot2_codex consult `job_32f2decc1cf9` 达成共识）。

---
id: cmpworktreearchive260604
title: per-需求 worktree 归档分层修复 + 合并后预览式归档
doc_type: requirement
created: 2026-06-04T00:00:00.000Z
updated: 2026-06-04T00:00:00.000Z
status: delivered
source: discussion
output_mode: spec_plan_task
parent_epic: v1.0 plugin sovereignty
references: [docs/06_决策记录/ADR-0036-per-requirement-implementation-worktree.md, docs/02_需求设计/实施期-per-需求-worktree-字段驱动代码隔离-260526-需求.md]
consult_evidence: [job_9db4523eeb15]  # job_9db4523eeb15: main_codex consult（worktree 生命周期分层重构）
analysis_input_hash: b61e58ae379d63e80ae71174f3907937a1d29229f03c51a128ee9a76e2fc34a6
analysis_applied_at: 2026-06-04T14:36:07.055Z
---

# per-需求 worktree 归档分层修复 + 合并后预览式归档

> 2026-06-04 经与用户多轮讨论 + 两路审计 + main_codex consult（`job_9db4523eeb15`）登记。
> 本需求 = **修复 ADR-0036 实施漂移（bug）+ 一项交互增量**。基础机制见 ADR-0036（已 delivered），本需求不重做基础设计。

## 需求描述

### 用户原话（verbatim · 按对话顺序）

> 所有子任务做完了没有主动自动推送、合并到源分支，既然我们要快速开发、快速预览应该是默认实施（或者说 batch 指令完）应该主动提交、推送、合并，然后开发人员只需要关注自己的源分支进行 check 验收，没问题就归档的时候自动删除对应分支，有问题继续讨论在未删除的实施分支处理？

> 合并自动合并就行，但是归档我觉得这里有两层意义：首先子任务的实施完成改标记"已结束"这本质上不能称为归档，我理解的归档是指整个需求+子任务全部做已结束/交付/完成之类的标记结束需求。

> 这个可以不用自动归档，到合并就行。归档的话我后面再界面上加个操作。

> （UI / plugin 入口）我在页面上操作的是"批量推进子任务"，那么就是子任务推进完毕后自动提交合并……手动输入 /su-batch 是不是相当于走了 ui 界面操作的路径？

> 你还是需要深度 check 一下当前的 plugin 机制和所有的指令逻辑，确保分层、逻辑不要漂移。

**最终拍板（AskUserQuestion）**：源分支 = 个人开发/预览分支（可污染）；体验 = "合并后我先看再删"；不 push remote。

### 要解决的问题

1. 🔴 **archive 漂移 bug**：worktree 是 per-需求共享（同需求子任务串行共用一个 `ccb/req-<id>`），但实施把 merge+删分支放在**每个子任务** archive（`archive.node.md:39`），而 ensure 对状态非 `ready` 报错（`index.mjs:314`）→ 多子任务需求第 2 个子任务 dispatch 撞 `already archived`。与 ADR-0036 决策 2 / 原需求"归档时一次性 merge 回 target_branch + 删除"（全流程位置表）相悖。multi-子任务路径**无测试覆盖**。
2. **合并不自动**：archive 需手动 `su-archive`；autonomous-batch 跑完不自动合并。（注：子任务级 auto-commit 已落地于 `ccb-execute`，代码确实自动 commit 进工作分支，卡点纯在"合并"那步。）
3. **缺"合并后预览、手动归档"**：ADR-0036 是归档时一步 merge+删，无中间预览态。
4. 🔴 **Console rollup 误报**：子任务全 archive 后 rollup 算出 delivered（`progress-aggregation.ts`），但只写 `rollupStatus`、不改 canonical `Requirement.status` → UI 可能显示"已交付"但代码其实还没 merge。

### 范围

- **A · 修漂移（回归 ADR-0036，修 bug）**
  - worktree 的 merge/cleanup 从子任务 archive **上提到需求级**；子任务 archive 只写 `status: done`、不碰 worktree。
  - 一个需求所有子任务 done 后，**一次性** merge 整个 worktree 回 target_branch。
  - 连带修 Console rollup 误报 delivered。
  - auto-commit 已在（`ccb-execute`），不补。

- **B · 交互增量（需修订 ADR-0036）**
  - 新增 worktree `merged` 运行态：autonomous-batch 完成后**自动合并落地**（→ `merged`），保留 worktree+分支供用户在源分支预览。
  - 用户手动「归档」（UI 按钮 / 命令）→ cleanup（删 worktree+分支）+ requirement `delivered`。

### 关键约束（main_codex consult 已校验）

- `merged` 是 **worktree 运行态**，**非** requirement status（合法 status 仅 drafting/planning/delivering/delivered/deferred/cancelled，不动）。worktree 状态机：`missing → ready → merged → archived`，及 `ready → discarded`（`merged → discarded` 危险，禁）。
- `ensure` **不放开** merged：遇 merged **fail-fast**（合并后不可再往同一 worktree 派工，防"已合并待归档"预览被污染）。
- git 副作用**不进** `requirement.finalize` capability（它是 CAS/evidence/md 写入流，非 git executor）；git merge/cleanup 由 skill/helper 执行，capability 只写 md 状态。
- 合并落地后、用户手动归档前，requirement 保持 **delivering**；`delivered` 绑手动归档 cleanup 成功之后。
- `archiveRequirementWorktree` 拆 `merge` / `cleanup` 两阶段（旧函数保留为 compat wrapper，但禁止子任务 archive 调用）。
- 触发点：自动合并放 **su-batch 流程尾部**，不下沉到 `anchor-dispatch-worker`；UI「归档」按钮 enqueue 清理命令（入口与命令统一在 skill 层）。

### 影响面

- **su-ccb-claude-plugin**：`archive` / `batch` 等节点 manifest；`lib/worktree` 状态机 + 拆 merge/cleanup；`su-archive` / `su-quick-archive` / `su-cancel` skill；补多子任务测试用例。
- **su-ccb-codex-skills**：基本不动（auto-commit 已在）；如需要核对 commit-guard 与新流程衔接。
- **Console（su-oriel）**：修 rollup 误报（rollupStatus vs canonical 对齐 / UI 文案）；worktree 状态投影；UI「归档」按钮。
- **文档**：修订 ADR-0036（新增 `merged` 中间态与"合并后预览、手动归档"决策）。

### 待办 / 推进

- **分阶段（Codex 与 Claude 一致）**：先 **A**（修矛盾，让多子任务能跑，风险低）→ 再 **B**（交互增量）。
- 下一步：技术设计（定 `merged` 状态机 + 拆函数签名 + 触发编排 + rollup 修复 + 存量 `archived` state 迁移）→ 任务拆分（遵 Phase 5 议题 4：别拆太碎）→ 派 Codex。
- 存量风险：runtime state 已有 `archived/ready/discarded` 混存，迁移不可自动重解释（main_codex 提示）。

## 启动状态

- **当前**：drafting / 已登记，分析与 consult 已完成，方向已与用户拍板（A+B，先 A 后 B）。
- **协商证据**：main_codex consult `job_9db4523eeb15`；两路审计（skills 层 + nodes/lib/状态机层）。

## Claude 解读

> 本节由 requirement_analysis 节点写入：promote→planning + Codex consult `job_ad0011770d37`@slot2_codex + 用户 2 项拍板。前轮 consult `job_9db4523eeb15`@main_codex 仍为基础证据。

**一句话**：修 ADR-0036「子任务级归档」实施漂移（bug，A）+ 新增「合并后预览式归档」交互（B）；先 A 后 B。

**已核验事实（基于当前代码，非旧快照）**：

| # | 结论 | 证据 |
|---|---|---|
| 1 | worktree 是 per-需求 | `lib/worktree/index.mjs` `statePath(projectRoot, requirementId)` |
| 2 | ensure 对非 ready fail-fast | `lib/worktree/index.mjs:314` |
| 3 | `archiveRequirementWorktree` 一步 merge+remove+`branch -d`+写 `archived` | `lib/worktree/index.mjs:412-600` |
| 4 | 多子任务串行第 2 个 `ensure` 撞 `already archived`（bug 真实），由 `archive.node.md` 第7点 + su-batch 逐子任务 archive **组合**触发 | `archive.node.md:39` + su-batch |
| 5 | rollup 只写 `rollupStatus`（lint 强制不碰 canonical）、`computeRequirementAggregation` 仅凭「全子任务 archive」提前算 delivered | `requirement-status-rollup.ts:111` / `progress-aggregation.ts:81-85` / `schema-ownership-lint.ts:545` |
| 6 | **claim4 收窄**：web 用 canonical status、`RequirementDetailPage.tsx:903` 显式防 canonical/rollup 矛盾 → **无当前 UI 误报**，仅投影层 latent 不一致 | `RequirementDetailPage.tsx:123,903` |
| 7 | 多子任务串行路径无测试 | `worktree.test.mjs` 仅单次 archive |
| 8 | auto-commit 已在 codex，scope 外不补 | `ccb-execute-worktree.mjs` |

**A+B 模型 + worktree 状态机（含用户拍板修订）**：
- 子任务 archive：只写 `status: done`，**不碰 worktree**。
- 需求级合并：**该需求全部子任务 done 后**一次性 merge → `merged`（保留 worktree+分支供预览）。
- 手动归档（命令；UI 按钮列 follow-up）→ cleanup（删 worktree+分支）+ requirement `delivered`。
- 状态机：`missing → ready → merged → archived`；`ready → discarded`；**新增 `merged → ready` 显式 reopen（用户拍板：复用实施分支返工）**。
- `ensure` 续对 `merged` fail-fast（仅显式 reopen 解冻）；`merged → discarded` 续禁。
- `merged` 是 **worktree 运行态**，非 requirement status；合并后~手动归档前 requirement 保持 `delivering`，`delivered` 严绑手动归档 cleanup 成功。

**用户本轮拍板（2 项）**：
1. 返工路径 = **复用实施分支** + 显式 reopen（见 歧义点 A / 保真差异 2、4）。
2. 自动合并时机 = **该需求全部子任务 done 才合并**（部分 batch 子集跑完不合并）。

**4 锚点反思**：
- 同意：A+B；discard/merge/cleanup 必须显式 guard runtime status（真实代码缺口，现 `discardRequirementWorktree` 完全不看 status）。
- 不同意：不在 consult 内替用户定返工模型——属用户权利，已升级并由用户拍板。
- 盲点：① canonical-clean 自撞（上提 merge 后被子任务自身 docs/journal 写入挡住，A 头号风险）；② 部分 batch 触发时机自相矛盾。
- 接下来：technical_design。

**移交 technical_design 的必决项（需求层定方向，不硬编码解法）**：
1. **canonical-clean 自撞**：需求级 merge 不能原样复用「整仓 clean」前置（子任务 archive 已写 dev_task md + journal.jsonl）。设计「只阻断与 merge 变更路径冲突的 dirty」或独立 canonical 提交流。
2. **merge/state 非事务幂等**：merge 成功而 state 写失败、cleanup 删成功而 state 写失败的恢复。
3. **拆函数**：`mergeRequirementWorktree`（只吃 `ready`）/ `cleanupRequirementWorktree`（只吃 `merged`）；旧 `archiveRequirementWorktree` 留 compat wrapper、禁子任务 archive 调用；旧 `archived` 作 compat no-op 终态。
4. **reopen 边**：`merged → ready` 显式转换 + 重合并幂等；保 ensure「fail-fast-except-显式reopen」。
5. **触发判定**：su-batch 尾部须先判「requirement 全部子任务 done」再 merge。
6. **rollup 重定义**：新 merged 模型下 `computeRequirementAggregation` 不得仅凭「全子任务 archive」算 delivered；delivered 严绑 canonical。
7. **手动归档命令入口** vs `RequirementDetailPage.tsx:250`「仅 delivered 可归档」冲突：手动归档发生在 `delivering + merged`，入口门槛须重定。
8. 存量 state 迁移策略（见 歧义点 D）。

## 歧义点

按优先级；每项标【已解 / 移交设计】。

**A.【高 · 已解(用户拍板)】返工路径**
- 张力：用户原话「有问题继续在未删除的实施分支处理」 vs 约束「ensure 对 merged fail-fast + merged→discarded 禁」。
- 拍板：**复用实施分支**。Claude 反推、用户已知悉的工程要点：
  1. 自动合并已落地 → gen-1 已在源/预览分支，故复用 = **fix-forward**（叠加修复再重合并），**非**撤销已合代码；彻底撤销需在「可污染」源分支 `revert`/`reset`。
  2. 加**显式 `merged → ready` reopen**：保复用的同时守住 ensure fail-fast（防 autonomous-batch 自动污染正在预览的 merged）；返工时显式 reopen 即可再 dispatch。
  3. `merged → discarded` 仍禁（reopen 走 merged→ready）。
- 移交设计：reopen 边 + 重合并幂等。

**B.【高 · 移交设计】需求级自动合并失败/前置语义**
- canonical-clean 自撞（见 Claude 解读必决项 1）为关键。
- 需求层定方向（设计落细）：合并失败 / 前置不满足 → **不进 merged、requirement 停 delivering、向用户升级，绝不静默切分支或卷入用户未提交工作**。

**C.【中 · 已解(Claude 判定)】手动归档 scope 边界**
- 用户：「归档我后面再界面上加个操作」。
- 判定：本需求交付**命令入口 + cleanup 机制 + merged 态**（手动归档此版用命令即可完成）；**UI 按钮列 follow-up**。低风险、与用户「界面后面再加」一致。

**D.【中 · 已解方向 + 移交设计细节】存量 runtime state 迁移**
- 现存 `archived/ready/discarded` 混存；新模型区分「旧 `archived`(旧式一步 merge+clean)」与「新 `merged`/新 `archived`」。
- 方向：**不自动重解释**，旧 `archived` 视终态保留、作 compat no-op；新机只作用新 state。
- 移交设计：是否需一次性标注 / 隔离旧 state，避免新 cleanup/merge 误吃旧 `archived`。

**E.【中 · 已解 / 重定 scope】rollup 修复后显示**
- 因 claim4 收窄：web 已用 canonical、无 UI 误报。真正要做的不是「修 UI 误报」，而是 **新 merged 模型下 `rollupStatus` 投影语义对齐**——不得在「全子任务 archive 但 requirement 仍 delivering(merged 待归档)」时算 delivered；delivered 严绑 canonical。
- UI 文案：保持 canonical 驱动；可选「已合并待归档」子任务级提示（设计决定，非必须）。

**F.【新 · 已解(用户拍板)】部分 batch 自动合并时机**（Codex 提出）
- 需求文本「su-batch 尾部触发」与「所有子任务 done 后一次性 merge」在 batch=子集时矛盾。
- 拍板：**该需求全部子任务 done 才合并**；触发点须先判 requirement 全部子任务 done 再 merge。

**无遗留 TBD**：上述全部已解或明确移交 technical_design（带方向约束），不留「待用户后续确认」。

## 保真差异

记录用户字面原话 / 需求旧快照 与 本轮分析模型 的差异（保真，不静默改）。

1. **push**：原话「应该主动提交、推送、合并」（要 push remote） → 最终拍板 **不 push remote**（仅本地 merge）。[需求已记，重申]
2. **返工分支语义**：原话「有问题继续在未删除的实施分支处理」隐含「merge 尚未发生」的旧 ADR-0036 时序 → 新模型 **merge 先落地再预览**，故「复用实施分支」实为 **fix-forward + 重合并**，且需**显式 reopen** 解冻；用户已确认复用方向并知悉此差异。
3. **claim 4 严重度**：我原述「UI 可能显示已交付但代码没 merge」 → 核验后**收窄**：web 用 canonical status 且 `RequirementDetailPage.tsx:903` 显式防 canonical/rollup 矛盾，**无当前 UI 误报**；实为 `rollupStatus` 投影层 latent 不一致。修复重定为「投影语义对齐」而非「修 UI bug」。
4. **状态机**：需求旧快照（及前轮 main_codex consult）「关键约束」列 `missing→ready→merged→archived + ready→discarded`、称 merged 不放开/近终态 → 用户拍板复用后**新增 `merged→ready` 显式 reopen** 边（ensure 续 fail-fast、merged→discarded 续禁）。**此修订 ADR-0036**，技术设计须同步改 ADR。
5. **触发时机**：需求文本「su-batch 尾部触发」vs「所有子任务 done 后一次性 merge」在 batch=子集时矛盾 → 拍板统一为 **全部子任务 done 才合并**。

---
id: cmpimplworktree20260526
title: 实施期 per-需求 worktree · 字段驱动代码隔离
doc_type: requirement
created: 2026-05-26T00:00:00.000Z
updated: 2026-05-26T00:00:00.000Z
status: delivered
source: discussion
output_mode: spec_plan_task
parent_epic: v1.0 plugin sovereignty
references:
  - docs/.ccb/decisions/ADR-0036-per-requirement-implementation-worktree.md
  - docs/.ccb/decisions/ADR-0032-alpha-x-multiwindow-slot-topology.md
  - docs/.ccb/decisions/ADR-0023-plugin-sovereignty.md
  - docs/.ccb/requirements/active/2026-05-23-phase5-v1x-governance-enhancement.md
analysis_input_hash: 61be7a05d630f1ba341a08e64511c4c593ef4a910bb5d8da4be393005c6634bf
analysis_applied_at: 2026-06-01T13:02:59.101Z
---

# 实施期 per-需求 worktree · 字段驱动代码隔离

> 2026-05-26 经 `/ccb:su-flow` 排查 + 多轮设计协商登记。基础设计已落 [ADR-0036](../../decisions/ADR-0036-per-requirement-implementation-worktree.md)；本需求等下次进入需求分析 → 拆分 → 派工。

## 需求描述

### 用户原话（verbatim · 按对话顺序，未改写）

> 我发现现在 su-batch 命令去推进子任务实施，不会去触发worktree，你找下我们之前最新版本的worktree的机制，排查一下是什么问题

> 你先给我解释一下决策1.3和决策1.4对worktree的逻辑

> CCB本身好像带worktree机制，它的机制是怎样的？和我们的1.4是不是一个意思？然后思考一下我们的项目应该用什么样的worktree机制？

> 其实我理解是在什么时候建立worktree的问题？例如我们在讨论需求、技术设计、拆分的时候都不需要建立worktree，但是在批量推进子任务的时候先进行worktree然后子任务实施之后在git回去？

> worktree的建立不应该按batch，应该按需求名或者需求id（可以英文或中文），所以这个标准的建立应该是对plugin的规则设计？

> 但是这个本质上的问题不是不止是batch这个命令？而是整个plugin和codex skills都要有这个机制？或者说是plugin 处理好worktree也要告知到实施方？ 所以你的plugin lib 是在干这件事？

> 我觉得有点复杂了。 其实就是 我觉得可以直接在子任务创建的时候，直接标记上对应的 git worktree，这样无论谁、什么时候实施都会读到这个。只需要在plugin里建立好相关的如何处理需求的worktree逻辑即可？

### 要解决的问题

1. `su-batch` 及任何实施入口推进子任务时**不建 worktree**，全程 inplace 跑主仓 → 跨 slot 并发改代码会互踩、autonomous batch 失败会脏主仓、无代码隔离与干净回滚。
2. ADR-0032 决策 1.4 已把 worktree 降级为「opt-in 非 canonical 代码隔离」，但该 opt-in 路径**一直没落地**（roadmap「上游 worktree 机制对齐」未做），现状是「完全无隔离」。
3. Console 历史两套 worktree 代码（`anchor-lifecycle` / `task-run`）已死/孤儿；且曾因 per-subject worktree 写 `docs/.ccb` 触发 2026-05-23 投影 bug，新方案须从机制上根除该类风险。

### 与 Phase 5 议题 2 的关系

本需求是 [Phase 5 议题 2「ccb 上游 worktree 机制对齐」](2026-05-23-phase5-v1x-governance-enhancement.md) 的具体落地。已核验上游 ccb（`/home/sue/.local/share/codex-dual`）worktree = 默认 inplace、per-agent opt-in、runtime 真相锚主仓、无自动回流。本需求对齐其精神，并**补「`docs/.ccb` 真相锚主仓」不变量**——因为 `docs/.ccb` 是工作树文件，上游只保护根 `/.ccb` runtime、不保护它。

## 基础设计（详见 ADR-0036）

核心一句话：**一需求一 worktree、字段驱动、plugin 全包、真相锚主仓、代码隔离回流**。

- **字段驱动**：`su-materialize` 在子任务 spec 盖可选 `code_workspace: { path, branch, target_branch, base_sha }`；执行方读 spec 顺带读到，无需新 ask 协议。`target_branch` 记录建时接入分支，不硬编码 `main`。
- **生命周期**：物化盖字段（声明）→ 首次实施 `ensureRequirementWorktree` 物理建 → 整个需求期 batch/子任务串行共用、代码 commit 累积 → 归档时一次性 merge 回 `target_branch` + 删除；取消则 `discard` 不回流。
- **路径分工**：`canonicalRoot`=主仓（只经 lib 读写 `docs/.ccb`）；`codeRoot`=worktree（只改代码/跑 git/跑测试）。
- **auto-commit**：每子任务实现 + 验证通过在 worktree 分支 commit，回执带 sha（用户已授权）。
- **护栏**：不用 sparse 排 `docs/`（会炸 indexer/测试/模板）；用 **commit-guard 拒绝 `docs/.ccb` 改动进 worktree 分支** + archive 前置校验（worktree/主仓 clean）。

### worktree 在全流程的位置

| 阶段 | 工作区 | worktree 动作 |
|---|---|---|
| 需求分析 / 技术设计 / 任务拆分 | inplace 主仓 | 无 |
| 物化子任务 | inplace 主仓 | 盖 `code_workspace` 字段（声明，未物理建） |
| 首次派工/实施 | — | `ensure`：`git worktree add` |
| 实施 | worktree 改代码 + 主仓读 spec/经 lib 写真相 | 子任务级 auto-commit |
| 审查 | inplace 主仓（读 worktree 分支 diff） | 无 |
| 归档 | inplace 主仓 | 前置校验 → merge 回 `target_branch` → 删 worktree + 分支 |
| 取消 / defer | — | `discard`：不 merge，强删 |

## 范围与实施面

- **su-ccb-claude-plugin**：`su-materialize` 盖字段；lib 三个 helper（`ensure`/`archive`/`discard`，canonical-root lock 串行同 req）；`dispatch`/`implementation`/`batch`/`archive`/`cancel` 节点 manifest 接入生命周期；`subtask-spec` schema + 重新生成 validator。
- **su-ccb-codex-skills**：`ccb-execute` 加路径纪律 + 子任务级 auto-commit + commit-guard 条款。
- **Console**：仅加 worktree 状态投影（可选，从主仓 state/EventJournal 读），**不参与建删**。
- **前置阻塞**：落地前先清理本仓 stale worktree 记录 + 主仓 dirty（helper preflight 依赖 clean 状态，且不宜在脏树上试）。

## 启动状态

- **当前**：drafting / 已登记，基础设计已落 ADR-0036，方向已与用户拍板。
- **待办（下次处理）**：进入需求分析（核验 ADR-0036 设计、扫歧义）→ 视情况补技术设计细节 → 任务拆分（按上面 3 块实施面；注意 Phase 5 议题 4 的拆分粒度约束，**别拆太碎**）→ 派工 Codex。
- **协商证据**：main_codex consult `job_a3bbe8b3fc7e` / `rep_f66fb0b1a03b`。

## Claude 解读

> 本节点（requirement_analysis）2026-06-01 经 `/ccb:su-flow` 推进。基础设计已落 [ADR-0036](../06_决策记录/ADR-0036-per-requirement-implementation-worktree.md)，用户已多轮拍板方向。**本轮职责＝用当前代码核验 ADR-0036 的假设 + 扫歧义，不重做基础设计。** 协商：slot1_codex consult `job_8e5b65ea33cf`（callback `cb_2f3ad30de13a`），1 轮。

### 需求本质
一句话：**一需求一 worktree、字段驱动、plugin 全包、真相锚主仓、代码隔离回流**。机制核心＝`su-materialize` 在子任务 spec 盖可选 `code_workspace{path,branch,target_branch,base_sha}`；plugin lib 三 helper（ensure/archive/discard，canonical-root lock 串行同 req）；ccb-execute 加路径纪律 + 子任务级 auto-commit + commit-guard 拒 `docs/.ccb` 进 worktree 分支；Console 退回纯投影。

### 本轮核验出的关键事实（与 ADR-0036 冲突，已经 Codex 复核）
ADR-0036 称 Console 两套 worktree 代码「已死/孤儿」——**核验为假**。实为 **3 条路径、2 条 LIVE**：
- 🟢 `task-run/worktree.service.ts`：被 LIVE 内核路由 `kernel/apply.routes.ts` 调用（dispatch_task→`createWorktree`、cancel→`cleanupWorktree`）；`/api/task-runs/:taskId/dispatch`、`/api/kernel/apply/:primitive` 已注册。
- 🟢 `workspace/workspace.service.ts`：`registerWorkspaceRoutes` 已注册，Web `TaskDetailPage`「创建/清理工作区」直接调（`POST /api/tasks/:id/workspaces`、`DELETE /api/task-workspaces/:id`），落点 `.workspaces/<taskKey>`（**仓库内**）。
- ⚪ `anchor-lifecycle/git-worktree.service.ts`：才是真孤儿（无 live importer）。

这违反 ADR-0036 不变量#4「Console 只投影、不参与建删」。

### 4 锚点反思
- **我同意的**：Codex 对主链路的修正成立——当前 `su-dispatch→ccb ask→codex inplace` 主链路**不调** Console worktree API，故本需求不构成「上线即双重建 worktree」的硬冲突；可按「ship 新机制 + 封口旧入口」推进，不必在 82-dirty 现场做高风险删码。
- **我不同意/保留的**：「主链路不自动触发」≠「可不管」。live UI 入口仍违反不变量#4，用户点一下就在仓内建 worktree、且其内 canonical 写入对主仓投影不可见（2026-05-23 bug 同类复发面）。故「封口入口」应在本需求内做，而非纯 follow-up。
- **我的盲点**：① 高估了 watcher churn 风险，被 Codex 纠正（见保真差异）；② 起初没查 `.workspaces` 旧 worktree 的 git 干净度——补查后 **6 个 worktree 全 clean、分支全已并入当前分支、零未合并工作**，清理零数据丢失。
- **接下来**：把唯一高影响决策（本需求范围是否含「封口 Console 入口 + 清废弃 worktree」）升级用户拍板（给默认 B）；用户拍板后进 task_breakdown（遵 Phase 5 议题 4：别拆太碎）。

### 推荐结论
推荐 **范围 B＝建新机制 + 封口 2 个 Console worktree 入口（feature-flag/隐藏 UI，最便宜，恢复不变量#4）+ prune 已验证安全的废弃 worktree**；完整删死代码 / schema 清理 / 历史 `.workspaces` 处置留 follow-up TODO。详见「歧义点」1。

## 歧义点

按影响排序。🔴＝已升级用户拍板（命中必问：不可逆工程 / 产品行为变化 / 数据丢失）；🟡＝给默认、记录、不阻塞。

1. 🔴 **【范围边界】本需求是否顺手封口那条 LIVE 的 Console worktree 功能？**
   - 现状：Console 仍有 UI 可触发的 per-task worktree 功能（task-run + workspace 两入口），违反不变量#4，且在仓内建 worktree（投影不可见的复发面）。Codex 复核：主链路不自动触发，但 live 入口仍在。
   - 默认（推荐 B）：本需求内**封口两个入口**（feature-flag/隐藏，最便宜）+ prune 已验证安全的废弃 worktree；删死代码/schema 清理留 follow-up。
   - 备选 A（更解耦）：只建新机制，Console 入口 + 废弃 worktree 全留 follow-up（接受不变量#4 暂续违反）。
   - 备选 C（一步到位）：连死代码/schema/UI/test 一起删（范围大，82-dirty 现场误删风险高）。
   - → **已升级用户**。

2. 🔴 **【数据丢失】废弃 worktree 清理范围 + `.workspaces` 去留** —— 已补查降级
   - 证据：3 个 sibling stale 已是 dir-missing 记录（`git worktree prune` 即可）；3 个 `.workspaces/` worktree **working tree 全 clean、分支全已并入当前分支（0 未合并 commit）**。
   - 结论：清理**零数据丢失**。默认随 B 一并 prune。若用户范围选 A，则保留现状、列 follow-up。

3. 🟡 **【不可逆】`target_branch` 建时锚定后的归档行为**
   - ADR-0036 定建时锚定（当前 `v1.0-plugin-sovereignty`），但归档时若该分支已被合并/删除/改名，merge 行为未定义。
   - 默认：建时锚定**全程不可变**；归档时 target_branch 不存在 → 不自动 merge、保留 worktree + 升级用户（与 ADR-0036 archive 冲突降级一致）。技术设计/拆分阶段固化。

4. 🟡 **【质量门】auto-commit 的「子任务验证通过」定义**
   - auto-commit 授权本身已拍板；未定义的是「验证通过」由谁判、是否要测试绿。若仅 agent 自述 done 即 commit，归档 merge 盲信未验证提交。
   - 默认：auto-commit gate＝「ccb-execute 跑完子任务声明的验证步骤且无失败」；无显式验证步骤的子任务在回执标注「未独立验证」。拆分阶段为每子任务定验收/验证步骤即可消解。

5. 🟡 **【机制】worktree 落点 + 存量 backfill**
   - 落点：确认 sibling `../SU-CCB-req-<reqId>`（避开主仓 `docs/` 投影），in-repo `.workspaces/` 约定废弃。Codex 纠正：风险非「watcher 重复监听」，而是「仓内 worktree 的 canonical 写入主仓投影看不见」——sibling 同样规避。
   - backfill：默认 `code_workspace` **仅新物化子任务生效**，存量 dev_task 不回填（字段可选、旧任务无 worktree 语义）。

## 保真差异

本轮分析与来源文档（ADR-0036 / 本需求正文）的差异，及对我自己初判的纠正：

1. **ADR-0036「Console 两套 worktree 已死/孤儿」← 不成立。** 实为 3 路径、2 LIVE（task-run 经 `kernel/apply.routes.ts`、workspace 经 Web UI；仅 anchor-lifecycle 真孤儿）。Codex 复核确认。→ 影响不变量#4 与清理/封口范围，已纳入歧义点 1。

2. **我自己初判「`.workspaces` 在 indexer/watcher 监听路径内」← 被 Codex 纠正为证据不足/不准。** watcher 只盯主仓 `docs/`，`.workspaces/.../docs` 不在主仓 `docs/` 子树。真实风险＝「Console 仍能建仓内 worktree，且其内 canonical 写入不被主仓投影看见」（与 2026-05-23 bug 同类，但机制描述纠正）。

3. **「subtask-spec schema」命名 ← 实际文件为 `references/kernel/schemas/dev-task.schema.yaml`；** `code_workspace` 字段落点在此 + `lib/subtask/index.mjs` 物化盖字段处（L142-191 frontmatter 区）。

4. **「落地前先清理 stale worktree + 主仓 dirty」← 已现场量化：** 主仓 dirty 82 文件；3 sibling stale 是 dir-missing 记录（prune-only）；3 `.workspaces/` clean + 分支已全并入当前分支 → 清理零数据丢失。preflight 不是模糊待办，是低风险已量化动作。

5. **基础设计方向无差异**：一需求一 worktree、字段驱动、plugin 全包、真相锚主仓——与 ADR-0036 + 用户拍板一致，本轮不改方向，仅补「Console 入口封口」为新增范围项（待用户拍板）。

---
id: console-projection-sync-robustness-design
doc_type: technical_design
requirement_id: cmpqlbcw1e06bb166ae00d341
subject: ccb-console
title: Console 投影同步健壮性 — 技术设计
updated: 2026-05-29
---

# Console 投影同步健壮性 — 技术设计

> 一句话:用「源头改 schema + codegen / 需求级定时轮询 reindex / 操作层+kernel 协议层状态模型彻底对齐」修三类 plugin→Console 投影与交互不一致。｜ 最后更新: 2026-05-29
>
> **无独立 status** —— 跟随需求 `cmpqlbcw1e06bb166ae00d341`。做什么/为什么见《需求设计》同名需求,本文只讲「怎么做」。关联 **ADR-0038**(kernel 状态模型单一真相源)。

---

## 一 · 概述

承接需求三类问题,方向均已用户拍板:

| 编号 | 问题 | 方案 |
|---|---|---|
| P1 | breakdown-draft `generation_source.note` schema 漂移 | ① 源头改 schema + codegen 收紧拒未知键(fail-loud) + 停写 + 清 2 存量 |
| P2 | 扫描兜底缺失 | **需求页定时轮询(默认 10s)需求级 reindex** + 新浏览器端点 + 补 dev_task 漏投影 + 新项目动态注册 watcher |
| P3 | 「批量推进」恒灰 — 状态模型漂移 | **彻底统一含 kernel 协议层**:主仓 kernel 升级新模型 + 操作层四层对齐(见 ADR-0038) |
| 顺带 | `review_history` required 漂移 | 改生成源,从 plugin schema root.required 移除 |

**已替用户决定的小项(可否决)**:轮询默认 10s、仅更新 DB 投影(不动文档地图机器文件)、旧 status 保留一版 read-compat(归一 reviewing)、stale Task 暂沿用现有"只报 orphan 不删"。

---

## 二 · 方案

### P1 · schema fail-loud 收紧(源头改,非手改产物)
- **生成源** `kernel/schemas/breakdown-draft.schema.yaml:57` 给 `generation_source` 增 `allowed_keys: [cc_agent, cx_agent, ccb_job_id, manual_actor]`。
- **生成器** `scripts/generate-schema-validators.mjs:213` 的 `type==="object"` 分支支持 `allowed_keys`,未知键报 `generation_source.<key>`;重生成 plugin+console 双产物(`:289`)。
- **runtime** `lib/runtime/schema-validate.mjs:170` 校验四已知键前先枚举 `Object.keys`,未知即 issue。
- **停写**:plugin 无生产代码显式写 note(`createBreakdownDraft` 仅透传,`index.mjs:263`),靠 fail-loud 写入侧拦截。
- **清洗顺序**:先删 2 存量 note 再收紧(否则 read 锁死,`index.mjs:223,254`)。

### P2 · 需求级定时轮询 + 动态 watcher
- **新端点**:`POST /api/projects/:projectId/requirements/:requirementId/reindex`(`requirement.routes.ts:346` 附近),客户端 `console-api.ts:617` 附近。**不复用 plugin-hooks**(拒浏览器 origin)、**不整项目 scan**。
- **需求级 orchestrator**(放 `requirement-reindex.service.ts`):复用现有三段 reindex(req md `:32` / 设计文档 `:67` / breakdown draft `:136`),**并补关键缺口——需求级 dev_task reindex**:扫 `docs/03` 中 `doc_type=dev_task && requirement_id==rid` 文档 → upsert Document → derive/upsert 子任务。抽 `upsertTaskProjectionAsync`(现私有 `project-indexer.ts:475`)为可复用 helper,不复制投影逻辑。
- **前端轮询**:`RequirementDetailPage`(现有 30s 只 refetch DB,`:543`)改为「进页面立即 reindex 一次 + 默认 10s 轮询」;页面 hidden/unmount 停、focus 触发一次;`inFlight` 跳过重入。
- **后端串行化**:按 `projectId:requirementId` 做 mutex/TTL debounce(多 tab 并发写投影必须串行);解析半成品返回 partial/issue,不扩散为页面硬错。
- **动态 watcher**:`FileWatcherService` 重构 `watchers: Map<projectId,FSWatcher>` + `ensureProjectWatcher` + `ensureAllProjectWatchers`;`start()` 调 ensureAll(`file-watcher-service.ts:86,103`);项目创建在 route 层(`project.routes.ts:22`)注册,注册后补一次 scan backfill(`ignoreInitial` 漏注册前文件,`:123`)。

### P3 · 状态模型彻底统一(操作层 + kernel 协议层) — 详见 ADR-0038
- **canonical 模型**:`status={reviewing,done,cancelled}` + `current_node`(7 节点)管位置 + 异常态归 `runtime_state`(replanning→node_substate;waiting_for_user_arbitration→runtime_state+active_waiting_set)。
- **kernel(主仓正本,已授权)**:`state-schema.yaml:23` task_status 收敛 3 值、默认 reviewing;node-manifest `task_status_in` 废弃或 7 节点统一 `[reviewing]`;同步 `transition-table.md`/`guard-registry.md`/`primitive-executor-contract.md` 旧 status;升 kernel 版本号;再单向同步插件副本。
- **操作层(Console)**:`normalizeTaskStatus`(`project-indexer.ts:1785`)只出 3 值删 active+旧枚举;Prisma `Task.status` 默认 `active`→`reviewing`(`schema.prisma:123`);资格门 `anchor-broker/anchor.routes.ts:636` 改 **fail-closed** `currentNode==="dispatch" && status==="reviewing" && !hasActiveAnchor && !isPendingDispatch`,抽**共享 helper** 复用于 batch+单派工(单派工 `:421` 现无门)。
- **read-compat**:旧值保留一版归一(`lib/state/index.mjs:134`),停止写旧值。

### 顺带 · review_history required
- root kernel 本就 `required:false`(`breakdown-draft-schema.yaml:119`),plugin schema 误入 root.required(`breakdown-draft.schema.yaml:16`)。从 plugin schema required 移除 + runtime/business 改"存在时必须数组"。

---

## 三 · 关键决策

| ID | 决策 | 理由 |
|---|---|---|
| D1 | schema 收紧改**生成源+codegen**,不手改产物 | 产物是 codegen,手改会被覆盖 |
| D2 | 资格门 **fail-closed**(`status==="reviewing"`) | 未知/legacy 默认不可派工,比 `∉{done,cancelled}` 安全 |
| D3 | dispatch 资格抽**共享 helper**,单派工一并纳入 | 消除 batch 有门/单派工无门不一致(单派工加门=行为收紧,开工前验证现用法) |
| **D4** | **彻底统一含 kernel**:主仓 `references/kernel` 升级新模型、保持正本 | 用户拍板"连底层清干净";满足 U3/U1 治理(已授权)。详见 ADR-0038 |
| D5 | 需求页走**新需求级 reindex 端点**,不走 plugin-hooks、不整项目 scan | plugin-hooks 拒浏览器;整项目 scan 太重不适合 10s 轮询 |
| D6 | 存量清洗**先删 2 文件再收紧** | 反序会让 runtime 收紧后 read 锁死存量 |
| D7 | 需求级 reindex **必须补 dev_task**;轮询仅更新 DB、不更新机器文件 | 现有三段 reindex 漏子任务投影;避免 10s 制造文件 churn |

---

## 四 · 核心流程

- **P2 轮询**:`进页面 → 立即 POST .../requirements/:rid/reindex(需求级,含 dev_task)→ 后端 mutex 串行 → 更新 DB Document/Task → refetch → 之后每 10s 重复;页面切走停`。
- **P3 派工资格(共享 helper)**:`currentNode==="dispatch"? → status==="reviewing"? → 无 active anchor? → 无 pending dispatch? → 全真 eligible`。

---

## 五 · 测试要点

- P1:带 `generation_source.note` → 生成器/runtime/console 三处均拒并指明路径;合法四键通过;`review_history[].note` 不受影响;清洗后 2 文件正常 read/update/scan。
- P2:需求级 reindex 覆盖 req md+设计+draft+**dev_task**;多 tab 并发 → 后端串行不冲突;页面卸载停轮询;半成品文件返回 partial 不硬错。
- P3:reviewing+dispatch 节点子任务 → eligible 按钮亮;done/cancelled/非 dispatch → ineligible;batch 与单派工判定一致;旧值 read-compat 归一 reviewing。
- 回归:26 task rescan 后 `done=19/reviewing=7`、节点 `archive=19/dispatch=7` 不变;kernel lint(`lint_state.py`)通过。

---

## 六 · 数据 / 迁移

- Prisma `Task.status` 默认 `active`→`reviewing`;DB 可重建 → **改 code + rescan**,**无需改 docs/03 dev_task**(26 task 全 `{reviewing,done}`,无 legacy)。
- kernel 迁移:改主仓 YAML/manifests/契约文档 + 升版本 + 同步插件副本;旧值 read-compat 留一版。
- 存量 draft:删 `cmpmwkb1ufac6cfd676fc4f42.json:12`、`cmpmwpuy8765c189497e7489a.json:12` 的 `generation_source.note`(走 lib update CAS)。

---

## 七 · 接口

- **新增** `POST /api/projects/:projectId/requirements/:requirementId/reindex`(浏览器可调,需求级)。
- `FileWatcherService` 新增 `ensureProjectWatcher` / `ensureAllProjectWatchers`。
- 复用整项目 `POST /api/projects/:id/scan`(保留)。

---

## 八 · 改动文件清单(供任务拆分)

| 层 | 文件 | 改动 |
|---|---|---|
| P1 | `kernel/schemas/breakdown-draft.schema.yaml` + `scripts/generate-schema-validators.mjs:213` + `lib/runtime/schema-validate.mjs:170` | allowed_keys 收紧 + 重生成 |
| P1 | 2 存量 draft json | 清 `generation_source.note` |
| P2 | `server/.../requirement-reindex.service.ts` | 需求级 orchestrator + **dev_task reindex** |
| P2 | `server/.../requirement.routes.ts:346` + `web/.../console-api.ts:617` | 新端点 + 客户端 |
| P2 | `server/.../project-indexer.ts:475` | 抽 upsertTask helper |
| P2 | `web/.../RequirementDetailPage.tsx:543` | 立即+10s 轮询 reindex |
| P2 | `server/.../file-watcher-service.ts:86,103,123` + `project.routes.ts:22` | Map 重构 + ensureProjectWatcher + backfill |
| P3-kernel | `references/kernel/state-schema.yaml:23` + 7 node manifests `task_status_in` + `transition-table.md` + `guard-registry.md` + `primitive-executor-contract.md` + 版本号 + 同步插件副本 | 升级新模型(ADR-0038) |
| P3-Console | `project-indexer.ts:1785` + `prisma/schema.prisma:123` + `anchor-broker/anchor.routes.ts:636,421`(共享 helper) | normalizeTaskStatus 收敛 + 默认值 + 资格门 |
| P3-consumer | `node-board-config.ts:83`、`ui-mapping.ts:117,233`、`start-ai-session.routes.ts:48`、`RequirementDetailPage.tsx:245,1176`、`TaskDetailPage.tsx:421`、`MyWorkPage.tsx:116`、`AlertStrip.tsx:38`(blocked 转 runtime) | 同步旧 status 引用 |
| 顺带 | `breakdown-draft.schema.yaml:16` + runtime/business | review_history 去 required |

---

## 九 · 风险与不可破坏项

- **双 kernel 树**(最大):主仓旧、插件副本新;改完须确认**正本→副本单向同步**流程,否则继续漂移。(ADR-0038 §四)
- **U3 治理**:改 kernel 语义经 `lint_state.py` 校验,须带版本号 + ADR + 用户授权(已具备)。
- **单派工加门(D3)是行为收紧**:确认现有"非 dispatch 节点单独派工"是否有效用法,若是 helper 留旁路。**(开工前验证)**
- **stale Task**:本轮沿用"只报 orphan 不删"(`project-indexer.ts:555`),不在 10s 轮询里误删(并发写期间文件可能瞬时缺失)。
- **多 tab 轮询**:后端必须按 `projectId:requirementId` 串行化写投影。
- **不可误改的同名 `active`**:Sprint / capability registry / terminal viewport / anchor allocation / TaskRun `dispatched` / ReviewIntent `cancelled` —— 非 Task.status 域,grep 替换勿误伤。
- **review_history[].note** 合法在用,P1 只动 `generation_source.note`,勿泛删。

---
id: cmpqlbcw1e06bb166ae00d341
title: "Console 投影同步健壮性:breakdown-draft schema 漂移 + 扫描兜底 + 子任务状态模型漂移"
doc_type: requirement
status: delivered
created: 2026-05-29T07:18:10.945Z
analysis_input_hash: 7d91290981029ce2032a2c5d5adbfb63fe6cc4cc36ff860ad51a8150d990a8f7
analysis_applied_at: 2026-05-29T08:11:40.231Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

背景:plugin 直接写 docs/.ccb 产物后,Console UI(读 DB 投影)未同步。排查发现三类问题(问题 1/2 初始提出,问题 3 为后续补充发现),需系统性修复以保证 plugin 产物可靠投影到 Console、且物化出的子任务能正常进入派工流转。

【问题 1:breakdown-draft plugin↔server schema 漂移】
plugin 的 createBreakdownDraft 接受 generation_source.note 字段,但 server 的 breakdownDraftSchema 是 strict,拒绝该字段。后果:scan 时 syncBreakdownDraftsFromFiles 校验失败→静默跳过→breakdownDraftPath 一直为空,UI 显示拆分草案未生成。影响所有 plugin 生成的草案(历史 cmpmwpuy… 也带 note)。根因:kernel schema(真相源)的 generation_source 只有 cc_agent/cx_agent/ccb_job_id/manual_actor,note 从来不是合法字段;但 plugin 校验器对未知字段既不认也不拦(比 kernel/server 松),导致非法字段静默通过、拖到 server 投影才失败。note 全仓零读取,是死字段。

【问题 2:扫描兜底机制 scan fallback】
Console 靠 chokidar watcher(fs/file-watcher-service.ts)在 docs 变更时自动重扫,但:① 仅 server 启动时一次性枚举项目;② WSL2 inotify 不可靠会漏事件。导致 plugin 写入后投影不更新,需手动 POST /scan。用户建议:增加基于需求的兜底——例如打开某个需求详情页时轮询/触发该需求范围的扫描兜底,确保进入需求页即看到最新投影。

【问题 3:批量推进按钮恒灰 — 四层子任务状态模型语义漂移】
现象:需求详情页「批量推进」按钮恒灰、永远点不动。根因:批量派工资格门要求子任务 status==="active"(anchor-broker/anchor.routes.ts:642,且同时要求 currentNode==="dispatch"),但物化(materializeRequirement)产出的子任务 doc status 恒为 reviewing(lib/subtask/index.mjs:75);indexer 的 normalizeTaskStatus 把 reviewing 原样透传(project-indexer.ts:1788),active 只是 status 为空/无法识别时的兜底(:1787、:1795)。四层状态模型语义对不上:① materialize 只产 reviewing;② dev_task 业务规则只允许 {reviewing,done,cancelled}(business-rules.mjs:9),active 根本不是合法 dev_task 状态;③ indexer 还认 dispatch_ready/dispatched/implementing 等旧枚举;④ 资格门却要 active。后果:正常物化的子任务永远到不了 active → 资格门永不过 → 按钮恒灰(web RequirementDetailPage.tsx:992 据 eligibleSubtaskBatchCount===0 置灰)。用户实测全项目 26 个 task 从无一个 active(19 个完成的都是 reviewing → done@archive 直接走过)。本质:资格门 check 的 active 属已被 node-kernel 模型(currentNode 管流转位置 + status∈{reviewing,done,cancelled} 管生命周期)取代的过时状态概念。

【候选方案(待处理时细化)】
问题1:① plugin 停写 note + 把 plugin 校验器对 generation_source 收紧为拒绝未知字段(对齐 kernel/server strict,写入即报错 fail-loud;推荐);② 或 server 放宽允许 note(不推荐,note 无用)。
问题2:① 需求详情页打开时触发/轮询该项目(或该需求范围)的 scan 兜底(用户建议);② 全局 watcher 在 WSL2 加 polling fallback(chokidar usePolling);③ server 启动后对新项目动态注册 watcher。需评估轮询频率/范围/性能与重复扫描成本。
问题3:① 修资格门——把 status==="active" 改为对齐 node-kernel 模型的正确判定(如 currentNode==="dispatch" && status 非终态、即 reviewing 视为可派工)(方向待评估);② 或统一四层状态模型语义(materialize / dev_task 业务规则 / indexer normalizeTaskStatus / 资格门 的枚举对齐到单一真相源)。需先定「哪层是真相源、active 是否彻底退役」。

## 原话（verbatim）

ok，那现在的意思就是有两个点要修：1.是note 2是扫描兜底机制，那么我建议扫描兜底机制加一个基于需求的兜底机制，例如我打开某个需求页轮询扫描兜底机制 你把这些相关的问题、排查、思路、方案单独提个需求先记录一下，我后面处理

（补充 · 问题 3）为什么"批量推进"按钮恒灰
- 按钮资格门要求子任务 status === "active"(anchor.routes.ts:642)。
- 但物化出的子任务 doc status 是 reviewing,indexer 的 normalizeTaskStatus 把 reviewing 原样透传成 Task.status=reviewing(active 只是 status 为空/无法识别时的兜底)。
- 所以正常物化的子任务永远是 reviewing,永远过不了 active 门 → 按钮恒灰。实测整个项目 26 个 task 从来没有一个是 active(19 个已完成的都是 reviewing → done@archive 直接走过去的)。
- 四层状态模型对不上:materialize 产 reviewing / dev_task 业务规则只允许 {reviewing,done,cancelled} / indexer 还认 dispatch_ready、dispatched / 资格门要 active。
刚刚发现一个问题，同时纳入需求更新一下需求内容

## Claude 解读

> 本节由 requirement_analysis 节点产出（Claude 决策 + slot2_codex consult 核对，关键 claim 附 file:line 证据）。用户原话意图为「先记录、后处理」，本节点只做**忠实记录与分析**；问题 3 为用户后续补充、Claude 已逐条 code-verify。文档中候选方案/「推荐」均为**待决记录、非已定方案**。

### 一句话
系统性修复「plugin 直接写 `docs/.ccb` 产物后，Console 投影/交互不一致」的**三类根因**：① breakdown-draft 的 plugin↔kernel/server schema 漂移；② 缺少可靠的扫描兜底；③ 子任务四层状态模型语义漂移导致「批量推进」按钮恒灰。

### 问题 1 · breakdown-draft schema 漂移（已代码核实）
- **现象**：plugin 写入的 draft 带 `generation_source.note`；server `breakdownDraftSchema` strict，scan 时 `syncBreakdownDraftsFromFiles` 校验失败 → 该 draft 被跳过 → 投影 `breakdownDraftPath` 不写入 → UI 显示「拆分草案未生成」。
- **根因**：真相源 kernel `references/kernel/breakdown-draft-schema.yaml:49` 起的 `generation_source` 只允许 `cc_agent/cx_agent/ccb_job_id/manual_actor`，**从无 `note`**；plugin 校验器（`generated-validator.mjs`、runtime `schema-validate.mjs:170`）对 `generation_source` 只验「是 object / 已知键」、**不拒绝未知键** → 非法 `note` 写入侧静默通过、拖到 server strict 投影侧才失败（三层严格度不一致、违反 fail-loud）。
- **影响面**：存量已确认 **2 个**非法文件（见《保真差异》#2）。

### 问题 2 · 扫描兜底机制（已代码核实）
- **现象**：plugin 写入 `docs/.ccb` 后投影不更新，常需手动 `POST /scan`。
- **根因**：① `file-watcher-service.ts` 的 `start()` 有 `started` 守卫、只整批枚举当前项目、**无为新项目动态注册 watcher 的入口**；② 无 chokidar `usePolling` 后端轮询，WSL2 inotify 漏事件即丢。
- **现状兜底（非零）**：startup scan + plugin-hook event-journal targeted reindex。**真缺口**：WSL2 polling、需求页 scan 兜底（需求页当前只 refetch、不 scan）。

### 问题 3 · 「批量推进」按钮恒灰 — 四层子任务状态模型语义漂移（已代码核实）
- **现象**：需求详情页「批量推进」按钮恒灰、永远点不动（web `RequirementDetailPage.tsx:992` 按 `eligibleSubtaskBatchCount===0` 置灰）。
- **根因（四层对不上）**：① 物化 `materializeRequirement` 只产 `status: reviewing`（`lib/subtask/index.mjs:75`）；② dev_task 业务规则只允许 `{reviewing,done,cancelled}`（`business-rules.mjs:9`）——`active` **根本不是合法 dev_task 状态**；③ indexer `normalizeTaskStatus` 把 `reviewing` 原样透传、`active` 仅作空/未识别兜底，并仍识别 `dispatch_ready/dispatched/implementing` 等旧枚举（`project-indexer.ts:1787-1795`）；④ 批量派工资格门却要求 `status==="active" && currentNode==="dispatch"`（`anchor-broker/anchor.routes.ts:642`）。→ 正常物化子任务永远到不了 `active`，资格门永不过、按钮恒灰。
- **本质**：资格门 check 的 `active` 是**已被 node-kernel 模型取代的过时状态概念**（现模型：`currentNode` 管流转位置 + `status∈{reviewing,done,cancelled}` 管生命周期）。

### 范围与意图边界
- 本需求**只记录与分析**三类问题，供后续处理；**不**在本轮决策方案或实施。
- 三问题的候选方案均为**待决项**，留到 technical_design。
## 歧义点

### 已由用户拍板（设计方向，记录备查）
- **问题 1 方案 = ①**：plugin 停写 `generation_source.note` + 收紧校验器拒绝未知键（fail-loud、对齐 kernel/server）+ 清洗 2 个存量非法 draft。
- **问题 2 范围 = A**：以「进入需求页时单次触发该需求范围 scan、复用既有 scan 通道、非持续轮询」为基线，**额外补「server 启动后为新项目动态注册 watcher」**缺口。
- **顺带漂移（`review_history` required） = 纳入**一并修。

### 仍待拍板（留到 technical_design）
1. **问题 1 收紧层级与清洗顺序**：只收紧 plugin **generated** validator → 存量带 `note` 的 draft 仅在 **update/transition 写回**失败；连 **runtime** validator 一起收紧 → **read 路径直接失败**。须明确收紧到哪层、以及「清洗 2 文件 vs 收紧」的先后，避免锁死存量。
2. **问题 2 触发细节**：需求页「单次触发」的去抖/并发与 scan 范围（项目级 vs 该需求级）确认；动态注册 watcher 的注册时机（项目创建即注册 vs 首次访问时）。
3. **问题 3 真相源决策（高影响）**：四层对齐时**哪层是真相源、`active` 是否彻底退役**？候选方向：① 仅修资格门——把 `status==="active"` 改为对齐 node-kernel 的判定（`currentNode==="dispatch"` && status 非终态、即 `reviewing` 视为可派工）；② 或统一四层枚举语义（materialize / dev_task 业务规则 / indexer normalizeTaskStatus / 资格门）。需连带评估 indexer 仍识别的 `dispatch_ready/dispatched/implementing` 旧枚举是否一并退役。
## 保真差异

本节记录「Claude 解读」相对需求原文/原始描述的修正，均有代码证据（含 slot2_codex consult 与 Claude 独立 code-verify）：

1. **「note 全仓零读取 / 死字段」过宽** → 死字段须精确限定为 **`generation_source.note`**。`review_history[].note` 是**合法字段**（kernel `breakdown-draft-schema.yaml:119,136`；server `breakdown-draft.schema.ts:17`）且被 UI/服务端**大量读写**（`BreakdownReviewEmbedded.tsx:237,297`；`breakdown-draft.service.ts:78,188`）。收紧/删除**只能动 `generation_source.note`，绝不能误伤 `review_history[].note`**。
2. **存量受影响文件数：原文举例「历史 cmpmwpuy…」（似 1 个）** → 全量扫描（共 9 个）实为 **2 个**带非法 `generation_source.note`：`cmpmwkb1ufac6cfd676fc4f42.json:12`、`cmpmwpuy8765c189497e7489a.json:12`（均历史 backfill）。
3. **「校验失败 → 静默跳过」表述不精确** → scan 侧会把 `invalid_schema` 计入 issues、scan job 记 **partial**（`project-indexer.ts:390,1040`）；但投影上确实跳过、`breakdownDraftPath` 不写（`:1072`）。准确说法：「scan 层有记录、UI 层不可见」。
4. **「需手动 POST /scan」隐含「无其它兜底」→ 不准确** → 已有 startup scan（`app.ts:190`、`startup-project-scan.ts:25`）与 plugin-hook event-journal reindex/排队 scan（`plugin-hooks.routes.ts:96,142,171,186`）。真缺口是 WSL2 polling 与需求页 scan 兜底（`RequirementDetailPage.tsx:340,525` 仅 refetch）。
5. **问题 3 补充修正（Claude 已逐条核实用户分析）**：
   - 用户原文只提资格门 `status==="active"`；**实际资格门同时要求 `currentNode==="dispatch"`**（`anchor-broker/anchor.routes.ts:642`，路径是 `anchor-broker/` 而非 `anchor/`）——即便状态对了，子任务还须在 dispatch 节点。
   - **`active` 是 phantom 状态**：dev_task 业务规则压根不允许 `active`（仅 `{reviewing,done,cancelled}`，`business-rules.mjs:9`），indexer 也只把 `active` 当空/未识别兜底（`project-indexer.ts:1787,1795`）——故 `active` 不是「难达到」而是**正常链路根本产不出**。资格门 check 它属过时状态概念遗留。
   - **「26 个 task / 19 完成」为用户实测数据**，Claude 未独立重数 DB，按用户口径记录；机制层面「materialize 产 reviewing → 永不过 active 门」已 code-verify 为真。
6. **附带发现（同类漂移，已决定纳入）**：kernel 标 `review_history required:false`，但 plugin `generated-validator.mjs:6` 标 `required`——另一处 plugin↔kernel schema 漂移。

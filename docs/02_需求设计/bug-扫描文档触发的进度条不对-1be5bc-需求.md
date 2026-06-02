---
id: cmpvdegxq1c734729da1be5bc
title: "BUG:扫描文档触发的进度条不对"
doc_type: requirement
status: delivered
created: 2026-06-01T15:35:30.110Z
analysis_input_hash: dee7a5d06884e78ce51a896b8e4390f85f7476640e4df0e6fe6d05ce3dfe2592
analysis_applied_at: 2026-06-02T03:11:48.844Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

BUG:扫描文档触发的进度条不对：点击扫描文档之后，顶部的进度条直接显示100%，没有实质的进度逐步，并且感觉其实还正在执行中，

## 原话（verbatim）

BUG:扫描文档触发的进度条不对：点击扫描文档之后，顶部的进度条直接显示100%，没有实质的进度逐步，并且感觉其实还正在执行中，

## 二、背景与目标

- 背景：Console 顶部进度条用于反馈"扫描文档"的索引进度。当前它只反映索引流水线第一段（markdown 枚举+解析），对小项目几乎瞬间到 100%，其后约 8 个同步 job 仍在 scanning 状态下继续，进度条停在 100% 不动也不消失。
- 目标：让"扫描文档"的进度反馈**诚实** —— 进度推进对应真实索引工作，且只在索引真正完成时显示完成/消失，消除"假 100% + 还在跑"的割裂感。

## 三、讨论与决策

- ✅ **step1_approval 用户拍板（2026-06-01）**：进度条形态 = **C+B 诚实优先**；修复边界 = **含所有扫描触发点**。
- ✅ **technical_design + step2_approval 定稿**：范围落点 = 所有走 scanProject 的项目级触发点（建项目自动扫 / scan 按钮 / plugin-hook / startup / watcher），中心化一处覆盖；需求 reindex 经评估 out of scope（无进度条、无假100%症状）。完成定义 = rollup 纳入扫描窗口。
- 根因详见「Claude 解读」。一句话：UI 把 scan job（流水线第一段）的完成误表达成整个项目同步完成。
- 候选方案 A/B/C/D 对比详见「歧义点 1」。已选 C+B（先诚实，不重构 indexer 加权进度模型）。
- 协商出处：slot3_codex（job_b086d9d92b5a / job_525e097e5578，mode=consult）—— 纠正 rollup 与 idle 先后、确认无 scan 内部自触发重扫、纠正 phase 推导需 run 边界+白名单、给出 C+B 推荐。

## 四、功能 / 范围

- 进度条数据来源由"单一 scan job"改为能反映整条 scanning 窗口的进度/阶段：Phase 1 显示真实 x/y，其后切不定态 + 当前阶段名。
- /scan-status 语义调整为可暴露/推导"当前阶段"（供 C+B 的阶段标签）；不引入跨阶段加权百分比。
- **范围 = 所有走 scanProject 的项目级扫描触发点**（已拍板）：建项目自动扫、scan 按钮、plugin-hook、startup、watcher 文件变更触发扫，共享同一诚实进度表达（中心化一处覆盖）。
- **需求级 reindex out of scope**：reindexRequirementScope 不走 scanProject、不碰 syncStatus、前端无进度条，无本 bug 症状，本需求不动它。

## 六、边界 / 不做项

- 暂不把 indexer 多 job 模型重构为统一"加权总进度"（除非用户选 A）。
- 不改扫描本身的执行内容/性能（仅为"完成定义"将 idle 翻转后移 + 给 rollup 建 job）。
- 不在本需求处理 WSL2 polling 噪声等边缘场景（非本 bug 主体）。
- 不动需求级 reindex 链路（out of scope）。

## 七、开放问题 / 假设

- 歧义点 1~5 均已在 requirement_analysis / technical_design 闭合。
- 假设：当前代码即真相源；"还在执行中"主要来自 syncStatus=scanning 未结束，而非外部插件并发写文件。

## 十二、交互 / 流程（期望）

- 点"扫描文档" → 进度条出现，进入 scanning。
- scanning 期间：phase==scan 且未满 → determinate「扫描文档 x/y」；其余阶段 → indeterminate + 阶段中文标签；不提前定格在 100%。
- 索引真正完成（含 rollup）→ 显示"扫描完成" → 短暂停留后消失。
- 失败（syncStatus=failed 或当前阶段 job failed）→「扫描失败」+ 错误信息。

## 十三、风险

- 若保留百分比，用户仍可能把 100% 读作全流程完成（codex 提示）→ 用 C+B 的 indeterminate + 阶段标签缓解。
- phase 推导若不加 run 边界会被非扫描 job（如 generate）污染 → 设计已含 run 边界 + pipeline 白名单。
- rollup 重排需保证不出现"idle 后又 failed"窗口 → idle 延到 rollup 成功后。
- indexer/watcher 路径近期高频改动 → 小步分 commit、pr1↔pr3 串行避冲突。

## Claude 解读

用户要的不是"加一个更精确的数字"，而是"扫描进度条要诚实"：点"扫描文档"后，进度条应真实反映索引推进，并且只在索引真正完成时才显示完成/消失。当前两点都做不到。

根因（读码 + slot3_codex 对抗式协商确认）：
- 顶部进度条 ProjectScanProgressBar 只绑定**一个** SyncJob —— `scan` job，它只覆盖整条索引流水线的**第一段**（枚举 + 解析 markdown，project-indexer.ts:331-360）。该 job 在 :356 flush 到 totalCount、:360 即标 success；对小型 docs 树几乎瞬间完成。
- 但 project.syncStatus 直到 :598（mark_project_scan_initialized）才从 "scanning" 翻成 "idle"。其间还**串行**跑约 8 个后续 job：parse / template_conformance / requirement_sync / reconcile（含 task 投影）/ plugin_journal_sync / requirement_design_doc_sync / breakdown_draft_sync。前端只 poll /scan-status（取最新 scan job 的 processedCount/totalCount，project.routes.ts:159-189），完全看不到这些后续 job。
- 于是：scan job 早早到 100% → 整个 Phase 2+ 期间进度条停在 100% 且**不隐藏**（syncStatus 仍 scanning）→ 直到 idle 才闪现"扫描完成"并消失。

三症状对应：
1. "直接显示 100%"：Phase 1 对小项目快于前端 750ms 首个 poll，首采即 100%。
2. "没有实质的进度逐步"：双重原因 —— (a) Phase 1 太快，后端 flush 阈值(10 文件/250ms)与前端 poll(750ms)错配，采不到中间值；(b) 占大头的 Phase 2+ 根本没被进度条跟踪。
3. "感觉其实还正在执行中"：这是**准确感知** —— 进度条到 100% 后，后续 8 个 job 仍在真实执行。

协商修正（slot3_codex 纠错，已采纳）：rollupAllRequirementsForProject(:605) 在 syncStatus 置 idle(:598) **之后**才跑，不属于"100% 不消失"的 scanning 窗口；它只可能造成一种更轻微的"显示完成后 requirement 列表/详情投影仍在更新"的尾部体感，与本 bar 主症状无关，应单列。

本质（与 codex 一致）：UI 把"scan job 完成"误表达成"整个项目同步完成"。修复方向应先做到**进度表达诚实**，而非立刻重构 indexer 进度模型。
## 歧义点

1. ✅ **进度表达形态（已拍板·step1_approval 2026-06-01）= C+B 诚实优先**。Phase 1 有文件数时显示"扫描文档 x/y"；Phase 1 完成后在 scanning 期间切 indeterminate 并显示当前阶段标签。不做 A（加权百分比），不做纯 B/纯 C。备选 A/B/C/D 的代价对比已留档备查。
2. ✅ **修复边界（technical_design 定稿）**：限"前端 ProjectScanProgressBar + /scan-status 语义"，**不**重构 indexer 的加权进度模型。
3. ✅ **"扫描完成"的定义（technical_design + step2_approval 定稿）**：把 scan 末尾的 rollupAllRequirementsForProject 纳入"完成"——前移 + 建 requirement_rollup job + 把 idle/lastScanAt 延到 rollup 成功后；rollup 失败→项目 failed。
4. ✅ **影响范围（step1_approval 拍板"含所有扫描触发点" + technical_design 厘清口径）**：覆盖**所有走 scanProject 的项目级扫描触发点**（建项目自动扫 / scan 按钮 / plugin-hook / startup / watcher backfill+event）；因它们共享同一 syncStatus + scan job + 进度条，**中心化修一处即全覆盖**。需求级 reindex(reindexRequirementScope) 经评估为 **out of scope**：它不走 scanProject、不碰 project.syncStatus、前端无进度条，故无"假100%"症状、无可修之处。
5. ✅ **验收口径（technical_design 定稿）**：进度单调不回退；scanning 期间绝不显 100%；determinate 仅 Phase 1；只在真正终态后消失；failed 有展示。
## 保真差异

- 原话三症状（直接 100% / 无逐步 / 感觉还在执行）均被根因覆盖，无遗漏，也未发现夸大。
- **范围口径已在 technical_design 厘清并对齐**：step1_approval 时用户选"含所有扫描触发点"，我曾把它扩展表述为含"需求 reindex"。技术设计阶段确认 reindex 不走 scanProject、无进度条、无本 bug 症状，故 reindex 判为 out of scope；"所有扫描触发点"的真实落点是所有共享 scanProject 的项目级触发点（中心化一处覆盖）。本文档「四」「歧义点 4」已据已审批 TD 修正，消除与 TD 的措辞矛盾。
- 一处**体感归因细分**：原话"感觉还在执行中"我归因为 Phase 2+ 仍在跑（主因）；协商另指出一个更轻微的 post-idle rollup 尾部体感（次因）。已通过"rollup 纳入完成窗口"的设计一并消除。
- 未发现 scan 内部写入 watcher 监听路径的 writeback（codex 复核：scan 仅写被忽略的 00_文档地图.md 与 .ccb/index/document-map.json），故"还在执行"不源于自触发重扫；WSL2 polling 仅放大"外部"文件变更，属边缘场景，非本 bug 主体。

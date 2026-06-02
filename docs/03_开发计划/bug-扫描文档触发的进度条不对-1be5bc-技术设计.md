---
id: td-1be5bc-scan-progress-honest
title: 扫描进度条诚实化(C+B) 技术设计
doc_type: technical_design
requirement_id: cmpvdegxq1c734729da1be5bc
subject: ccb-console
updated: 2026-06-02
---

# 扫描进度条诚实化(C+B) 技术设计

> 一句话:让"扫描文档"进度条只反映真实索引推进，绝不提前定格 100%；Phase 1 显真实 x/y，其后切阶段标签 + 不定态，索引真正结束才消失。 ｜ 最后更新: 2026-06-02
>
> **无独立 status** —— 跟随 `requirement_id`(cmpvdegxq1c734729da1be5bc) 指向的需求。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | 项目扫描进度条诚实化(C+B 形态) |
| 核心职责 | 让所有项目级扫描的顶部进度条诚实反映索引流水线进度，而非只反映第一段 |
| 设计原则 | 诚实优先 / 单一真相通道 / 向后兼容(只加字段) / 小步可回退 |
| 需求来源 | `docs/02_需求设计/bug-扫描文档触发的进度条不对-1be5bc-需求.md` |
| 覆盖范围 | 所有走 `scanProject` 的项目级扫描(建项目 / POST /scan / plugin-hook / startup / watcher) 的进度展示 + scanProject 末尾生命周期 |
| 不覆盖 | 需求级 reindex(`reindexRequirementScope`，无进度条、无假100%症状)；WSL2 polling 噪声；indexer 加权总进度模型(否决 A 方案) |

---

## 二、方案与架构

```
扫描触发点(全部共享同一通道)            scanProject 流水线(单一真相)
 ├ 建项目 / POST /scan          scan─parse─template─req_sync─reconcile
 ├ plugin-hook                      ─journal─design_doc─breakdown─[rollup*]
 ├ startup                     project.syncStatus = scanning ──────► idle (rollup 成功后才翻)
 └ watcher(backfill/event)                    │
                                              ▼
   GET /scan-status ─ deriveScanPhase(run 边界 + pipeline 白名单) ─► { phase, phaseStatus,
                                              │                       processed/total(仅 scan 阶段) }
                                              │ poll 750ms (仅当 syncStatus=scanning)
                                              ▼
                        ProjectScanProgressBar:
                          phase==scan && processed<total → determinate「扫描文档 x/y」
                          否则                            → indeterminate +「阶段标签」
                          syncStatus 终态                 →「扫描完成」→ 隐藏；failed →「扫描失败」
* rollup 新建 requirement_rollup job 并纳入 scanning 窗口
```

| 关键原则 | 说明 |
|----------|------|
| 单一真相通道 | 所有触发点汇流 `scanProject`，中心化修一处即覆盖全部，无逐触发点散点改 |
| run 边界 + 白名单 | phase 推导必须锚定"本次 scan run"且只认 pipeline jobType，杜绝被 `generate` 等非扫描 job 污染 |
| 完成端到端 | `syncStatus=idle` 推迟到 `requirement_rollup` 成功后，"扫描完成"才真的代表全部完成 |
| 向后兼容 | `/scan-status` 只增字段，前端旧字段语义不变 |

**与现有系统的关系 / 边界**:

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `project-indexer.ts` | 末尾生命周期重排(rollup 前移+建 job、idle 延后)；新增 `deriveScanPhase()` | scan 各 job 的执行内容、Phase1 计数(processed/total)、claim 去重 |
| `project.routes.ts` `/scan-status` | 调 `deriveScanPhase`，响应加 phase 字段 | 既有字段与 `/scan`(202) 不变 |
| `ProjectScanProgressBar.tsx` | 删"终态强制100%"假完成；按 phase 决定 determinate/indeterminate + 标签 | 750ms 轮询、项目切换/卸载清理、failed 展示骨架 |
| `reindexRequirementScope` 链路 | **不动**(out of scope) | 全部 |

---

## 三、关键决策与取舍

- **进度形态**:选 **C+B**(Phase1 真实 x/y + 其后 indeterminate+阶段标签)。否决 **A 加权总进度**(需给约 9 阶段定权重、耗时随数据量剧烈波动、易伪精确、调参成本高)；否决**纯 C**(无阶段细节，体验偏弱)。
- **phase 推导**:选 **run 边界 + pipeline 白名单**。否决"全局 latest SyncJob"——经 slot3_codex 协商纠正:`SyncJob` 无 `runId`，同项目还有 `generate` 等非扫描 job，全局 latest 会显示错阶段。
- **完成定义(歧义点 3)**:选 **rollup 纳入 scanning 窗口**(rollup 前移 + 建 `requirement_rollup` job + `idle/lastScanAt` 延到 rollup 成功后)。否决保持现状(残留"显示完成后 requirement 列表/详情投影还在变"的尾部体感)。
- **接口形态**:选**扩展 `/scan-status` 加字段**。否决新端点(前端已 poll 该端点，无必要)。
- **范围边界**:仅项目级扫描进度通道；**reindex out of scope**(无进度条、无假100%症状，slot3_codex 同意)。
- **ADR**:本设计 impact 为"中"、非 design_affecting(无新架构模式，决策已在需求审批拍板)→ 不单独立 ADR，决策落本文档「三」；如需正式 ADR 可补。
- **协商出处**:slot3_codex(`job_525e097e5578`，mode=consult，answered)。

---

## 四、核心流程 / 逻辑

**(1) phase 推导 `deriveScanPhase(projectId)`**

```
PIPELINE = [scan, parse, template_conformance, requirement_sync, reconcile,
            plugin_journal_sync, requirement_design_doc_sync,
            breakdown_draft_sync, requirement_rollup]   // 有序，仅作白名单 + 标签

rootScan = 最新 SyncJob{ jobType=scan, startedAt > (project.lastScanAt ?? epoch) }
if !rootScan: return { phase: null }                 // 不在当前 run(已 idle/历史)
current  = 最新 SyncJob{ jobType ∈ PIPELINE, startedAt >= rootScan.startedAt }
                        order by startedAt desc, createdAt desc
if !current: return { phase: "preparing" }           // 空窗
return {
  phase: current.jobType, phaseStatus: current.status,
  phaseJobId: current.id, phaseErrorMessage: current.errorMessage
}
```

| 处理规则 | 说明 |
|----------|------|
| run 边界自洽 | `lastScanAt` 延到 rollup 后才写 → 运行中 `lastScanAt`=上次 run 结束时刻 < 本 run scan.startedAt，故能精准锚定本 run；run 结束后 `scan.startedAt < lastScanAt` → rootScan 为空 → phase null |
| 首扫 null 处理 | `project.lastScanAt` 为 null 时下界取 epoch，rootScan 仍命中本次 scan job |
| partial 非终态 | `partial` 只作 `phaseStatus` 展示，终态判定仍只看 `projectSyncStatus`(codex 修正) |
| Phase1 计数 | `/scan-status` 仍返回 scan job 的 processed/total；仅 `phase==scan` 时前端用作 determinate |

**(2) scanProject 末尾生命周期重排**

```
… breakdown_draft_sync 完成 → finishSyncJob(reconcile, success) …
project.update { docsRoot, initStatus }                 // 拆出:不再在此写 syncStatus/lastScanAt
rollupJob = createSyncJob(requirement_rollup)
try   { rollupAllRequirementsForProject(); finishSyncJob(rollupJob, success) }
catch { finishSyncJob(rollupJob, failed); project.syncStatus = failed; throw }   // 不留"idle 后失败"窗口
project.update { syncStatus: idle, lastScanAt: now }    // run 真正结束才翻 idle
```

| 处理规则 | 说明 |
|----------|------|
| 失败语义 | rollup 失败 → 该 run = failed(rollup job failed + project failed)，绝不"先 idle 再 failed" |
| 幂等 | `docsRoot/initStatus` 维持原 `mark_project_scan_initialized` 幂等键；`idle/lastScanAt` 用独立幂等键(如 `:mark_project_scan_idle`) |
| 无前置耦合 | rollup 为 DB-only，不依赖 `syncStatus=idle` 先行(codex 确认) |

**(3) 前端 `ProjectScanProgressBar` 展示状态机**

```
轮询 /scan-status @750ms (仅当 project.syncStatus==scanning)
 failed(syncStatus=failed 或 phaseStatus=failed) →「扫描失败」+ phaseErrorMessage||errorMessage
 syncStatus 非 scanning(终态)                    →「扫描完成」(hold 700ms)→ 隐藏
 scanning:
   phase==scan && total>0 && processed<total → determinate「扫描文档 {p}/{t} · {pct}%」
   否则                                       → indeterminate + LABEL[phase]||「同步索引中」
LABEL = {scan:扫描文档, parse:解析文档, template_conformance:模板校验,
         requirement_sync:同步需求, reconcile:归并任务, plugin_journal_sync:同步事件流水,
         requirement_design_doc_sync:同步设计文档, breakdown_draft_sync:同步拆分草稿,
         requirement_rollup:汇总状态, preparing:准备中}
```

| 处理规则 | 说明 |
|----------|------|
| 绝不假100% | 删除原"终态即 setProgress 100%/markComplete 强制 100%"；scanning 期间永不显 100% |
| 单调 | determinate 仅 Phase1 且 `processed<total`；切 indeterminate 后不回退为某个百分比 |

---

## 五、测试策略

- [ ] 单元 `deriveScanPhase`:run 边界(`startedAt>lastScanAt`)、白名单过滤(排除 `generate` job)、空窗→`preparing`、`partial`→只入 phaseStatus、首扫 `lastScanAt=null`、run 结束后→`phase null`
- [ ] 单元 前端 display 状态机:scanning+scan+processed<total→determinate；scanning+其它阶段→indeterminate+标签；终态→complete→hidden；failed→展示 phaseErrorMessage
- [ ] 集成 `scanProject` 全流程:断言 `syncStatus` 在 `requirement_rollup` 成功后才 `idle`；rollup 失败→`failed` 且无"idle 后 failed"窗口；`requirement_rollup` job 有序出现
- [ ] 端到端/手测:较大 docs 树点"扫描文档"，观察 determinate→阶段 indeterminate→完成消失，全程不早现 100%

---

## 六、数据设计

无新表 / 新列。`SyncJob.jobType`(String) 新增取值 `requirement_rollup`，无需 schema migration。

**状态 / 枚举**:

| 字段 | 值 | 说明 |
|------|----|------|
| `SyncJob.jobType` | 新增 `requirement_rollup` | rollup 阶段对应的 job 类型 |
| `/scan-status.phase` | PIPELINE jobType \| `preparing` \| `null` | 当前阶段；null=不在 run 中 |
| `/scan-status.phaseStatus` | pending/running/success/partial/failed | 当前阶段 job 状态(非终态判定依据) |

---

## 七、接口设计

| 端点 | 方法 | 作用 | 认证 |
|------|------|------|------|
| `/api/projects/:projectId/scan-status` | GET | 扩展:在既有字段基础上**增**返回 phase 信息 | 同现状 |
| `/api/projects/:projectId/scan` | POST | 不变 | 同现状 |

新增响应字段(向后兼容)：`phase: string|null`、`phaseStatus: string|null`、`phaseJobId: string|null`、`phaseErrorMessage: string|null`。

---

## 八、文件结构 / 变更清单

- `[MODIFY] server/src/indexer/project-indexer.ts`:拆分 `mark_project_scan_initialized`(docsRoot/initStatus 与 syncStatus=idle/lastScanAt 分离)；rollup 前移并建 `requirement_rollup` job + 失败置 failed；新增并导出 `deriveScanPhase()`
- `[MODIFY] server/src/modules/project/project.routes.ts`:`/scan-status` 调 `deriveScanPhase`，响应合入 phase 字段
- `[MODIFY] web/src/types/project.ts`:`ProjectScanStatusView` 增 `phase/phaseStatus/phaseJobId/phaseErrorMessage`
- `[MODIFY] web/src/components/projects/ProjectScanProgressBar.tsx`:删假100%逻辑；按 phase 决定 determinate/indeterminate + 阶段标签映射
- `[MODIFY] web/src/components/projects/ProjectScanProgressBar.module.css`:不定态条纹动画(若缺)
- `[MODIFY/NEW] 对应 *.spec`:`deriveScanPhase`、组件状态机、scanProject 生命周期集成测试
- `[MODIFY] schema-ownership-lint` 白名单(如需):登记 `requirement_rollup` jobType

---

## 十、迁移影响与风险

- **受影响**:所有项目级扫描的进度展示 + `scanProject` 末尾生命周期(idle 翻转时机)
- **打法(小步分 commit)**:① 后端 `/scan-status` 加字段(前端旧逻辑兼容) → ② 前端 C+B 展示 → ③ lifecycle 重排(rollup job + idle 延后) 独立 commit + 集成测试
- **回滚 / 恢复**:纯加字段 + 组件逻辑可逐项 git revert；lifecycle 重排为独立 commit，可单独回退

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| phase 推导跨 run / 并发 reindex 串扰 | 中(若不加 run 边界) | 显示错阶段 | run 边界 + pipeline 白名单(本设计已含) |
| rollup 重排引入"idle 后 failed"窗口 | 低 | 误报完成 | rollup 失败即 failed；idle 延到 rollup 成功后 |
| indexer/watcher 近期高频改动 → 冲突/回归 | 中 | 回归 | 小步分 commit、避开在途 watcher 工作、配集成测试 |
| startup 直连 `scanProject`(不走 claim) | 低 | 并发重扫 | 本需求不承诺去重(验收措辞已软化)；如需另案处理 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-02 | v1.0 | 初版:C+B 形态 + run 边界 phase 推导 + rollup 纳入完成窗口(经 slot3_codex 设计协商) |

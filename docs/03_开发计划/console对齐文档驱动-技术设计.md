---
id: console-doc-driven-alignment-design
doc_type: technical_design
requirement_id: cmppm45yt09j35fx6e2
subject: ccb-console
title: Console 对齐文档驱动新结构 — 技术设计
status: draft
version: v0.2
updated: 2026-05-28
---

# Console 对齐文档驱动新结构 — 技术设计

> 版本 v0.2 ｜ 状态 已定稿(Codex 协商完成 + 用户拍板:全对齐 / md-first / followup 走正规拆分) ｜ 最后更新 2026-05-28
> 对应需求 Console 对齐文档驱动新结构 (cmppm45yt09j35fx6e2)

一句话:plugin 已转文档驱动(ADR-0037),本设计把 Console 三层(web / server / DB)对齐同一真相模型 —— **剪死料、堵住还在写真相的口子,不重设计 DB**。

---

## 一、现状(大白话)

Console 已经基本是"触发 + 投影":

```
用户 / Console ──POST anchor-dispatch──▶ slot(plugin)
                                          │ 写 docs/01-99(真相)
                                          │ 追加 EventJournal
                                          ▼
                                POST /plugin-hooks(回调)
                                          │
                                    indexer 重投影
                                          ▼
            Document / Task / Requirement / EventJournal(DB 投影)
                                          │ REST
                                          ▼
                                   web(5s / 30s 轮询)
```

- DB 每字段带 `@owner`:`plugin-canonical`(真相)/ `console-projection`(投影)/ `console-internal`(运行态)/ `append-only-audit`。`schema-ownership-lint` 硬性禁止路由写真相字段,`materialize` 端点不注册(404),`Task.patch` 拒 status/progress。**骨架是对的。**
- 但残留改版前的模型 + 死料,见下面 4 桶。

## 二、4 桶错位

| 桶 | 问题 | 触及 |
|----|------|------|
| **A 状态文档模型** | UI 假设独立 `.ccb/state/*.md` 存活动状态(stateProjection / statePath / "State drift" / refresh-stale-projections);新真相在 `docs/03` dev_task frontmatter,服务端已 stub staleState=0 | web(+ server) |
| **B 写真相漏洞** | `/tasks/:id/derive` 造无文档的 Task/Requirement 行;planning / breakdown 直接翻 `Requirement.status` | server |
| **C legacy 死料** | DB 死列、server 的 `.ccb/{plans,tasks,decisions}` kind 分支、web 的 spec/plan/task/state 分类与死代码 | DB + server + web |
| **D 契约非唯一路径源** | indexer 读了契约,但旁边留写死路径字面量 | server(+ 契约) |

## 三、分阶段方案

顺序:先让真相流正确(P1),再在其上拆错模型(P2)、剪死料(P3)、打磨(P4)。

### P1 真相流收口(B + D)
- **derive 改走 plugin dispatch(Option A · 复用现有,不新造机制)**:派生 followup 不再 `task.create`。改用现有 `POST /requirements/:id/anchor-dispatch` 投 `/ccb:su-flow` 回 `task_breakdown`(payload 带 `source_task_id/source_task_key/followup` 作 provenance);真正的 dev_task 由现成链路 **`task_breakdown → 审查草案 → /ccb:su-materialize-requirement`** 写 `docs/03` → 再投影。`requirement_id` 从 source task 的 `requirementId` 取(缺失则 409)。`ai-tools/invoke` 的 derive_followup 同理。
  - **followup 交互(已定)**:走正规拆分流程 —— 追加任务 = 该需求的新一轮拆分,生成草案 → 人工审查 → 物化,与主流程完全一致,不做一键。
- **契约成唯一路径源**:indexer / document-parser 所有 docs 路径走 resolver,删写死字面量(`docs/03_…`、`docs/02_…` 等),兑现契约 consumers 项。
- **status 写收口**:planning-anchor start / breakdown-draft 翻 `Requirement.status` 的点,改为只写 console-internal 运行态(planningRuntimeState / anchorId),`status` 由 plugin 写 `docs/02` 后投影。
- md-first 需求创建/编辑保留为**唯一**被许可的 Console 写文档路径(其余一律 dispatch)。

### P2 杀状态文档模型(A)
- web 删 `stateProjection` / `statePath` / AlertStrip "数据已过期" / AdvancedDrawer "状态源" → 重指 `docs/03` dev_task 文档本身。
- 删 `refresh-stale-projections` / `refresh-projection` 入口 + index-health staleState 字段(server 已 stub 0)。
- Overview 的 "State drift" 卡换真实健康(解析失败数、投影滞后、dispatch 失败)。
- Documents 删 "实时状态文档(kind=state)" banner。

### P3 legacy 剪枝(C)— 依赖 P1,先清引用再删列
> Codex 协商纠正:目标列**都有活引用**(非死料),不能直接 migration 删。**先清代码引用(P3a)→ 再 migration 删列(P3b)**,顺序不能反。

**P3a 清活引用(代码 PR)**
- server:删 `inferDocumentKind` 的 `.ccb/{plans,tasks,decisions}` 分支、`deriveTasks` 的 plan/task 分组(只留 dev_task);改 task detail 的 `linkedDocuments` 查询(不再依赖 `linked*` 列);拆除 epic 兼容壳(server 固定返回 `parentEpicId:null` 等)。
- web:删 kind 过滤 legacy 值、outputMode 标签、"生成 Spec/Plan/Task"文案、`generate` job 类型、死 epic / Timeline 代码、3 个空页面目录(anchors / ai-sessions / anchor-terminal-recordings);followup provenance 展示从 `sourceTaskId` 换成 P1 注入的 payload provenance(`DerivedFollowupsCard` / `UnstartedRequirementStrip`);清 code enum `spec_only/spec_plan_task`(parser / types / UI label)。

**P3b Prisma migration 删列(在 P3a 之后)**
- 删 `linked{Spec,Plan,Task}Id`、`outputMode` / `splitMode` / `sourceTaskId`。epic 四件套已非 DB 列(只剩兼容壳,P3a 拆),无需 migration。

### P4 UX 优化
- Documents kind 过滤按新 doc_type 重列:requirement / technical_design / dev_task / adr / architecture / index。
- 导航:确认 `/tasks` + `/reconcile` 隐藏是否保留(默认保留,需求详情页为主台)。
- Overview 改版与用户在改版本对齐后再合(不擅动)。

## 四、三个子决策(已定)
- **derive**:改走 plugin dispatch(有真实用途:review 后派生 followup;非删)。
- **doc kind**:按契约重列新 doc_type,丢 spec/plan/task/state。
- **导航**:隐藏 `/tasks` + `/reconcile` 判为有意(需求驱动主流程),P4 与用户确认,不擅恢复。

## 五、DB 处置:剪枝,不重设计
- 不重设计:schema 已按投影模型(@owner)+ lint 强制;Document / Task / Requirement / EventJournal 真·可从 docs 重建。
- **删列纪律(Codex 协商纠正)**:目标列 `linked*` / `outputMode` / `splitMode` / `sourceTaskId` **都有活引用**(schema / API / create / parser / web types / followup UI 在读写),不是死料。**必须先 P3a 清代码引用,再 P3b migration 删列**,顺序不能反。epic 四件套已非 DB 列(只剩 API/web 兼容壳),P3a 拆壳即可,无 migration。`spec_only/spec_plan_task` 是 code enum 非 DB enum。
- 保留:console-internal 运行态表(SlotBinding / AnchorDispatchQueue / TaskRun / TaskWorkspace / Sprint / ReviewIntent / …)、append-only-audit、投影表 —— 与文档投影正交。

## 六、不做项
- 不重设计 DB schema(已是对的投影模型)。
- 不动用户在改的 Overview 部分(对齐后再合)。
- 不恢复隐藏导航(除非 P4 确认)。
- 不改 plugin 侧真相写入逻辑(前序迁移已完成);本设计只动 Console 三层 + 契约 consumers 接线。

## 七、Codex 协商结论(job_f7edc622115d · 已折叠)
1. **derive 落点**:选 Option A —— 复用现有 requirement anchor-dispatch + `su-flow → task_breakdown → 审查草案 → su-materialize-requirement`,不新造 plugin action/capability(详见 P1)。
2. **删列安全**:目标列都有活引用,必须先清引用(P3a)再 migration(P3b);P3 依赖 P1(详见 P3 / §五)。
3. **拆分粒度**:P1/P2 可独立 PR;P3 依赖 P1;P4 放最后不反向阻塞。
4. **followup 交互(用户已定)**:走正规拆分流程(草案 → 审查 → 物化),不做一键。

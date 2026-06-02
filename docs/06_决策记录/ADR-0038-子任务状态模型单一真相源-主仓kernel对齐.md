---
id: ADR-0038
title: 子任务状态模型单一真相源 — 主仓 kernel 对齐 reviewing/done/cancelled + current_node
doc_type: adr
status: accepted
supersedes: []
superseded_by:
date: 2026-05-29
---

# ADR-0038: 子任务状态模型单一真相源 — 主仓 kernel 对齐 `{reviewing,done,cancelled}` + `current_node`

> 一个决策一篇,记下"为什么这么定"。
>
> **状态**: accepted ｜ **拍板人**: 用户(im.suyejian)，2026-05-29 显式授权改 kernel 语义

---

## 一、背景

需求 `cmpqlbcw`(Console 投影同步健壮性)问题 3「批量推进按钮恒灰」排查,暴露子任务状态模型多层漂移:

1. **操作层四层不一致**:materialize 产 `reviewing`(`subtask/index.mjs:75`)/ dev_task 业务规则只允许 `{reviewing,done,cancelled}`(`business-rules.mjs:9`)/ indexer `normalizeTaskStatus` 仍认 `active`+旧枚举(`project-indexer.ts:1785`)/ 批量派工资格门却要 phantom `active`(`anchor.routes.ts:642`)。正常物化子任务永远到不了 `active`→按钮恒灰。
2. **更深:双 kernel 树漂移**。主仓 `references/kernel/state-schema.yaml:23` 仍是旧 10 值 `task_status`(proposed/planning/dispatch_ready/dispatched/reviewing/waiting_for_user_arbitration/replanning/archived/completed/blocked);而插件分发副本 `su-ccb-claude-plugin/references/kernel` 已是新模型 `{reviewing,done,cancelled}+current_node`。**"正本"(主仓)反比"副本"(插件)旧**;运行时不读主仓 YAML 做 gating(`task-node-flow.service.ts:42` 仅 projection mirror)。

**约束**:kernel 治理(`guard-registry.md` U3 / `lint_state.py` 强制 `changes_kernel_semantics=false`)规定改 kernel 语义须经 U1 用户授权 + 版本号 + ADR。用户已于 2026-05-29 授权。用户原则:长期工程彻底修复、不留债。

---

## 二、决策

1. **主仓 `references/kernel` 保持 canonical 真相源**,升级到新子任务状态模型:
   - `status = {reviewing, done, cancelled}`(生命周期)
   - `current_node` = 7 节点(requirement_analysis…archive,管流转位置)
   - 异常/运行态归 `runtime_state`(running/waiting_codex/waiting_user/escalated/completed/blocked);`replanning`→`node_substate`;`waiting_for_user_arbitration`→`runtime_state=waiting_user/escalated` + `batch_state.active_waiting_set[].waiting_for=user_arbitration`
2. `state-schema.yaml` 的 `task_status` 收敛到 3 值,默认值 `proposed`→`reviewing`。
3. node-manifest `task_status_in`:彻底做法是**废弃该字段**(入口由 `previous_nodes_any_of`/`current_node`/guard 判定);若为 schema 兼容暂留,则 7 节点统一 `[reviewing]`(含 archive 入口 `reviewing`、归档完成才写 `done`)。
4. 同步改主仓 `transition-table.md` / `guard-registry.md` / `primitive-executor-contract.md` 中旧 status 副作用与 guard;**升 kernel schema 版本号**;再单向同步插件分发副本(恢复 正本→副本)。
5. **操作层对齐(Console)**:`normalizeTaskStatus` 只出 3 值;Prisma `Task.status` 默认 `reviewing`;资格门 fail-closed `reviewing && currentNode==="dispatch"` 并抽共享 helper;旧值保留**一版 read-compat**(归一 `reviewing`),停止写旧值。

---

## 三、否决的方案

| 方案 | 为什么没选 |
|------|------------|
| 维持现状 / 止于操作层 | 主仓 kernel 仍漂移,"单一真相源"在协议层不成立,违背彻底修复原则(用户已否决) |
| 宣布插件 kernel 为正本、主仓退役 | 改变 CLAUDE.md 声明的"主仓=真相源"架构,影响更大、需连项目文档一起改;用户选保持主仓为正本 |
| server 放宽认 `active` | `active` 是 phantom 死状态(dev_task 规则压根不允许),放宽是给债镀金 |

---

## 四、影响

- **好处**:四层 + kernel 协议层单一真相源;按钮修复;消除 phantom `active` 与旧枚举债;正本/副本恢复单向同步。
- **代价 / 风险**:改 kernel 协议属治理敏感(已授权);双 kernel 树须先确认同步流程,否则再漂移;旧值 read-compat 退役留待后续版本;Console consumer 改动面较广(见技术设计 §八 改动清单)。
- **受影响**:`references/kernel`(state-schema / manifests / transition-table / guard-registry / primitive-executor-contract)、插件 kernel 副本、Console indexer/gate/Prisma/UI consumer、`lint_state.py` 治理。

---

## 五、关联

| 关系 | 对象 |
|------|------|
| 相关需求 | `cmpqlbcw`(Console 投影同步健壮性) |
| 相关设计 | `docs/03_开发计划/console-投影同步健壮性-技术设计.md` |
| 相关决策 | ADR-0037(文档驱动架构-真相源上移人读文档) |

---

## 六、决策依据

- `slot2_codex` 三轮 consult(`job_547e0ae7c541` / `job_9b68a8627fd5` / `job_b3c4a20555e0`):核实四层漂移、双 kernel 树(正本反旧)、canonical 模型建议、U3 治理约束、blast radius。
- 用户 2026-05-29 在技术设计阶段显式授权「升级主仓为新模型」,满足 U3/U1「改 kernel 语义需用户授权」治理前置。

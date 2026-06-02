---
id: ADR-0041
title: 需求绑定 slot 或执行分析后自动晋升 planning,Console 只触发不写 canonical
doc_type: adr
status: proposed
supersedes: []
superseded_by:
date: 2026-06-02
---

# ADR-0041: 需求绑定 slot 或执行分析后自动晋升 planning

> 一个决策一篇,记下"为什么这么定",防止以后反复扯 / 误改
>
> **状态**(见 frontmatter `status`):proposed ｜ **拍板人**: 用户(2026-06-02,经 su-flow 需求分析+技术设计门确认)

---

## 背景

需求 canonical `status`(真相在需求 md frontmatter)在「绑定 slot」「执行需求分析」两条路径都不流转,需求恒留 `drafting`→看板「待处理」,与用户对进度的直觉不符(需求 `cmpvdh2mj`)。

当前「绑定不改 status」是**受测试守护的显式契约**(`anchor-requirement-dispatch.routes.spec.ts:139` 断言绑定后仍 `drafting`)。本次是契约变更,故立 ADR。

## 决策

1. **目标态 = `planning`**。绑定/分析属早期生命周期,UI 已把 `planning` 映射「推进中」;`delivering` 留给子任务进入执行后的 rollup,不在此提前置位;不复活已废弃的 `analyzed`。
2. **解绑 slot 不回退**。晋升为单向语义,解绑只释放资源,已发生的推进事实不撤销。
3. **Console 只触发,不写 canonical**(遵守 ADR-0034/0037)。canonical 由 plugin agent 经 `requirement.promote:planning` capability-outcome 写 md;Console 绑定后只 enqueue 一个 plugin-side promotion command。
4. **forward-only 幂等**:仅 `drafting→planning`;`planning` no-op;`delivering|delivered|deferred|cancelled` 拒绝不覆盖。专用 guard `requirement_promote_forward_only`,不复用会放过 delivering 的 `requirement_not_cancelled_or_deferred`。
5. **触发组合本期 D1,D2 后续跟进**(用户拍板,2026-06-02):本期在 plugin agent 内两处幂等触发 —— su-flow planning 入口 promote(覆盖主按钮绑定→派工的主流程)+ `applyRequirementAnalysis` 成功后 affirm(覆盖"执行分析")。Console enqueue promotion(D2)覆盖无派工的纯手动 bind / startup recovery,降为后续需求;**已知缺口**:这些路径本期不晋升。

## 理由

- `planning-anchor/start` 只 bind slot + 写 runtimeState,不保证 agent 运行;主流程绑定经 anchor-dispatch 会跑 su-flow,故 D1(su-flow 入口 promote)覆盖主流程。纯手动 bind / startup recovery 无派工路径在 D1 下不晋升,作为已知缺口留待 D2。
- canonical 真相在 md、只能 plugin 写,是 ADR-0034/0037 既定边界;D2 的 Console enqueue 是后续唯一不破坏边界又能覆盖无派工 bind 的方式。
- forward-only 防止 reanalyze(允许 delivering/deferred)等路径误降级。

## 影响

- `requirement.promote` 为新 capability,需同步 capability registry。
- 更新 `anchor-requirement-dispatch.routes.spec.ts:139` 等锁定旧契约的断言。
- 新增 promotion 触发 + outcome policy + guard,详见同名《技术设计》。

## 备选与放弃

- **仅分析触发(D3)**:漏主流程绑定路径,放弃。
- **D2 本期一起做**:覆盖无派工 bind,但每次绑定多一次 agent dispatch;用户拍板本期先 D1,D2 后续。
- **Console 直接写 canonical**:违反 ADR-0034,放弃。
- **用 schema_valid 作 evidence**:planning 入口缺 analysis hash 会失败且不证明 forward-only,改用 CAS `hash_matches`。

---
id: cmpzllxw73320bc3428913778
title: 当前UI界面和plugin似乎缺少取消需求的指令
doc_type: requirement
status: planning
created: 2026-06-04T14:36:20.312Z
analysis_input_hash: e48ce1c4f379a6fe04063d0cec57e0daf12baa594dfa19838e19c212da26c360
analysis_applied_at: 2026-06-04T16:04:18.328Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

当前UI界面和plugin似乎缺少取消需求的指令，规划一个需求如果想要被取消如何处理

## 原话（verbatim）

当前UI界面和plugin似乎缺少取消需求的指令，规划一个需求如果想要被取消如何处理

## 二、背景与目标

- **现状**:取消相关三层均已存在(plugin skill / Console 详情页菜单 / kernel capability+lifecycle),自 SU-Oriel 初始 commit 起就在。
- **问题**:① 详情页点取消仅 enqueue 指令,需求状态当场不变、无 UI 反馈、未捕获原因;② skill 写 `cancelled` 状态步骤未接 capability lib(`SKILL.md` 只含糊说「再写 cancelled 状态」);③ 取消无子任务级联;④ worktree discard 无防护语义;⑤ `requirement_lifecycle.yaml` 状态枚举(`draft/analyzed`)与 canonical(`drafting/planning/delivering`)漂移。
- **目标**:让「取消」成为用户可一步发起、即时可见、语义闭环、符合文档状态规范的操作。

## 三、讨论与决策

- 1 轮 Codex 协商(`job_65d147d5d67f`):推翻「功能已端到端存在」的初判,确认仅派发链通、取消效果与级联未闭环,并发现 lifecycle 枚举漂移。
- 用户决策:① 取消按钮用普通样式(移除 danger),保留确认弹窗 + 原因输入;② 取消即**直接舍弃 worktree 并修改所有相关标记**(级联)。

## 四、功能 / 范围

**L1 · Console UI(Claude 亲自做)**
- 取消按钮改普通按钮交互(移除 `su-cancel` 的 `variant=danger`,与暂缓/复活一致)。
- 取消确认弹窗增加「取消原因」输入(建议填写,允许为空)。
- 派发 payload 携带 `reason`(当前为空 `{}`)。
- 取消派出后给出状态反馈(queued → cancelled / 失败),不再停留无反馈。

**L2 · 指令逻辑硬化(Codex 实施,Claude 审)**
- `su-cancel` skill 写 `cancelled` 状态走 `applyCapabilityOutcome`(`requirement.cancel`),不手写 status。
- 取消级联:需求→`cancelled`、相关非终态子任务→`cancelled`、删除 breakdown draft、释放绑定 slot / 清理在途 dispatch。
- worktree:直接 `discardRequirementWorktree`(force),不加 dirty/unmerged 拦截。
- 补齐 cancel guard(防重复取消 / expected-hash),对齐 `finalize`/`promote` 同级。
- 修复 `requirement_lifecycle.yaml` 状态枚举漂移。

## 五、业务规则

- 取消是大状态终止操作,终态 `cancelled`;可经 `su-reactivate` 复活状态(不恢复 worktree 代码)。
- 取消级联范围:该需求 + 其所有非终态子任务 + breakdown draft + worktree + 绑定 slot / 在途 dispatch。
- worktree 一律直接舍弃(用户已授权不可逆丢弃),不因未提交/未合并改动而拦截。
- 取消原因经确认弹窗输入,写入 payload 与 EventJournal 审计;弹窗确认 + 原因构成用户取消授权(满足 `must_ask_9`),无需 agent 二次确认。
- 已 `delivered` 需求不可取消(保持现有门控)。

## 六、边界 / 不做项

- 不在需求列表页新增取消入口(本轮只做详情页;列表页入口另议)。
- 不改 Console「只投影/触发、不写业务真相」的架构边界(状态写仍由 plugin agent 经 capability 落盘)。
- 不做取消后的代码恢复/回收站(舍弃即不可逆,reactivate 只复活状态)。

## 七、开放问题 / 假设

- 假设(已采纳,可调整):取消原因建议填写但允许为空;详情页确认弹窗 + 原因输入即构成 `must_ask_9` 用户授权。
- 无遗留 TBD。

## 八、拆分预览

- pr1 · L1 Console UI:取消按钮样式 + 原因输入弹窗 + payload `reason` + 状态反馈(Claude)。
- pr2 · L2 `su-cancel` 逻辑硬化:capability 写状态 + 级联 + worktree discard + guard + lifecycle 枚举修复(Codex,Claude 审)。

## 十、接口(草案)

- `POST /anchor-dispatch`:requirement cancel 的 dispatch payload 增加 `reason`(当前 UI 传 `{}`)。
- `/ccb:su-cancel --payload`:`reason` 透传至 capability 审计。

## 十一、界面 / 页面布局

- 需求详情页标题行 ⋯ 菜单「取消」项:普通按钮样式(非 danger)。
- 取消确认弹窗:标题 + 级联影响范围复述 + 原因输入框 + 确认/取消。

## 十二、交互 / 流程

用户点 ⋯ → 取消 → 弹窗(复述级联影响 + 原因输入)→ 确认 → 派发 `/ccb:su-cancel`(带 `reason`)→ agent 经 capability 写 `cancelled` + 级联标记 + 直接 discard worktree → UI 反馈最终态。

## 十三、风险

- 不可逆丢弃 worktree 未合并改动(用户已授权;弹窗须明确告知)。
- 级联取消在途子任务会中断正在运行的 agent job;须确保 slot 释放与 job 停止一致,避免孤儿 job。
- lifecycle 枚举漂移修复涉及 kernel,需回归 lint / 测试。

## Claude 解读

核实结论:取消功能**并非缺少,而是存在但未端到端闭环**。三层均已存在且自 SU-Oriel 初始 commit(119ad7e)起就在:plugin `/ccb:su-cancel` skill、Console 需求详情页标题行 ⋯ 生命周期菜单里的「取消」项、kernel `requirement.cancel` capability + `requirement_lifecycle`。

详情页确实有取消按钮(`RequirementDetailPage.tsx:93-99,940-981`,danger 样式),点击经二次确认 → `dispatchRequirementAnchorCommand`(payload 为空 `{}`)→ `POST /anchor-dispatch` → 拼出 `/ccb:su-cancel` → `jobSlotRouter.enqueue` 入槽队列。但**点击只 enqueue 指令,需求状态当场不变**(测试 `task.routes.spec.ts:299` 明确断言取消后仍是 `delivering`),要等 agent 接管才写 `cancelled`;UI 无「已取消/失败」反馈,也未捕获取消原因。

因此需求实质 = 让「取消」成为一个用户可一步发起、即时可见、语义闭环、符合文档状态规范的操作。分两层:**L1 Console UI**(取消按钮改普通样式 + 确认弹窗加原因输入 + payload 带 reason + 派出后状态反馈)由 Claude 亲自做;**L2 指令逻辑硬化**(skill 写状态走 `applyCapabilityOutcome`、取消级联、直接 discard worktree、补 guard、修 lifecycle 枚举漂移)由 Codex 实施、Claude 审。
## 歧义点

1. 「缺少取消指令」实指什么 —— 已核实:指令三层均存在,用户真实痛点是可发现性 + 点击后无即时效果/反馈。【已澄清】
2. 取消 delivering 且有在途子任务时的级联语义 —— 用户决定:**修改所有相关标记**(级联:需求→cancelled、相关非终态子任务→cancelled、删除 breakdown draft、释放绑定 slot/清理在途 dispatch)。【用户已定 · must_ask_9】
3. 取消时 worktree 处置 —— 用户决定:**直接舍弃**(force discard),不因未提交/未合并改动而拦截。【用户已定 · must_ask_1】
4. 取消按钮样式 —— 用户决定:普通按钮交互,**去掉红色 danger 背景**,与暂缓/复活一致;保留确认弹窗。【用户已定】
5. 取消授权与原因 —— 采纳(可调整):详情页确认弹窗 + 原因输入即构成用户取消授权(满足 must_ask_9);取消原因建议填写但允许为空,reason 写入 payload(当前为空 `{}`)与 EventJournal 审计。【默认已采纳,留待用户否决】
## 保真差异

原话称「当前UI界面和plugin似乎缺少取消需求的指令」。核实后:取消指令在 plugin(`/ccb:su-cancel` skill)、Console(详情页 ⋯ 菜单取消项 + `/anchor-dispatch` 派发链)、kernel(`requirement.cancel` capability + `requirement_lifecycle` 的 `user_cancel` transition)三层均已存在。

据此把交付范围由「新增取消功能」**校准为「审计 + 硬化既有取消链路 + 改进 UI(原因输入/状态反馈)」**。这是范围方向的修正,不是收窄:用户对级联(舍弃 worktree + 改所有相关标记)的要求,实为既有 capability 尚未覆盖的**新增级联效果**,属范围扩展。

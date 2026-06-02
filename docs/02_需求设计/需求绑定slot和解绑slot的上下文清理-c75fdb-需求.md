---
id: cmpl40j1ve2d3820066c75fdb
title: 需求绑定slot和解绑slot的上下文清理
doc_type: requirement
status: delivered
created: 2026-05-25T11:15:01.364Z
analysis_input_hash: 591ef779110bced61aca8ec93128d99300bb84d11b8098b4b8099319162dc3af
analysis_applied_at: 2026-05-26T12:29:53.916Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

对于需求和slot的绑定和解绑，需要对agent的session上下文进行清理，所以在触发绑定时逻辑绑定成功立即发送一个/new 的指令确保清理。对于解绑操作需要在解绑前先发送/new指令再进行逻辑解绑。
注意 /new 这个指令是对 slot分组下所有的 agent （cli）都要发送这个指令

## 原话（verbatim）

对于需求和slot的绑定和解绑，需要对agent的session上下文进行清理，所以在触发绑定时逻辑绑定成功立即发送一个/new 的指令确保清理。对于解绑操作需要在解绑前先发送/new指令再进行逻辑解绑。
注意 /new 这个指令是对 slot分组下所有的 agent （cli）都要发送这个指令

## Claude 解读

**目标**:在需求与 slot 绑定/解绑的时刻,让该 slot 分组下**所有 agent** 切换到全新会话(`/new`):不继承上一个需求的上下文,旧 session 保留、可 `/resume`。

**关键澄清(用户确认)**:
- 语义是 `/new`(新建可 resume session),非 `/clear`(原地清空)。
- `/new` 是 **provider 自带命令,对 claude 与 codex 均已验证有效**(用户验证)。因此**不实现、不重写 `/new`**,只负责**送达**。

**触发时机与顺序**:
- 绑定:`bindRequirement()` 逻辑绑定成功后,立即对该 slot 分组所有 agent 送达 `/new`。
- 解绑:在 `releaseSlot()` 逻辑解绑**之前**,先对所有 agent 送达 `/new`,再解绑。

**"所有 agent" 范围**:`.ccb/ccb.config` `[windows]` 中该 slot 对应的全部 agent(当前 = `slotN_claude` + `slotN_codex`,证据 `.ccb/ccb.config:4-10`),按拓扑动态枚举,不用 `claudeAgentForSlot()` 的 1:1。

**为什么涉及 ccbd**:绑定/解绑在 Console,但 agent 终端(pane)由 ccbd 持有;要让 provider 收到 `/new` 这个 slash 命令,需把它敲进 pane,而往 pane 敲命令的现成先例是 ccbd 的 `project_clear_context`(发 `/clear`+Enter)。ccbd 仅作传输,非 `/new` 的实现者。

**本次范围(先做传达观察)**:枚举 slot 分组 agent → 在 bind 后 / unbind 前把 `/new` 送达每个 pane → 挂进生命周期;best-effort,不做"确保清完"的强保证。
## 歧义点

**已全部拍板**:
- 命令:`/new`(新建可 resume session),对 claude / codex 均已验证有效(用户)。不实现命令本身,只送达。
- 解绑失败 / agent busy:best-effort,不阻断 `releaseSlot`。
- 绑定后送达失败(逻辑绑定已生效):仅告警,保留绑定,不回滚。
- 本次目标:先把 `/new` 传达打通并观察效果,不追求强一致。

**留给实现的小决策(非阻塞)**:
- 送达通道:`/new` 需作为 slash 命令进入 agent 的 pane。首选复用/泛化 ccbd 往 pane 敲命令的路径(类 `project_clear_context`,现写死 `/clear`)来发 `/new`;或实测 `submit()` 是否能让 provider 按 slash 命令解释。由实现者验证后取最简可行路径。
## 保真差异

1. **`/new` 不需我方实现(已更正)**:`/new` 是 provider 自带命令,claude / codex 均已验证有效。之前"CCB 无 `/new` 原语、需净新增能力"的说法**收回**——我方只做"把 `/new` 送达各 agent + 接线生命周期",非实现命令本身。复杂度据此下调为简单~中等。

2. **覆盖范围不符(仍需改)**:原话"对所有 agent 发送" vs 现状 `claudeAgentForSlot()` 写死只推 `slotN_claude`(`apps/ccb-console/server/src/modules/slot-binding/job-slot-router.ts:317-322`)。需改为按 windows 拓扑枚举全部 agent(参考 ccbd `project_view` 的 `windows[].agents`)。

3. **"确保清理" → best-effort 送达**:`submit()` 仅返回 job_id、不等 provider 实际完成(`apps/ccb-console/server/src/modules/ccbd-client/ccbd-client.service.ts:171-180`);本次按用户意图采 best-effort 送达 + 记录失败,不阻断主流程。

---
doc_type: technical_design
title: "绑定/解绑 slot 发送 /new 上下文清理技术设计"
requirement_id: cmpl40j1ve2d3820066c75fdb
---

# 技术设计 · 绑定/解绑 slot 时对分组内所有 agent 发送 /new

> 说明:本设计为已完成实现的**正规链路补齐**(此前走了 thin spec + 直接派工的捷径,Console 未投影技术设计/拆分/子任务)。需求解读见 `docs/.ccb/requirements/active/2026-05-25-需求绑定slot和解绑slot的上下文清理-c75fdb.md`。

## 1. 背景与已锁语义
- 需求:需求与 slot 绑定/解绑时,让该 slot 分组下**所有 agent** 切换到全新会话(`/new`),不继承上个需求上下文;旧 session 保留、可 `/resume`。
- `/new` 是 **provider 自带命令**(claude/codex 均已由用户实测有效),**不实现命令本身,只负责送达**。
- 失败语义(用户拍板):逐 agent best-effort;解绑即使 busy/送达失败也**不阻断 `releaseSlot`**;绑定后送达失败**仅告警、保留绑定不回滚**。

## 2. 设计决策
- **枚举来源**:`.ccb/ccb.config` `[windows]` 拓扑,经 ccbd `project_view` 拿 `windows[].agents` 与 `agents[].pane_id`、`namespace.socket_path`。**弃用** `claudeAgentForSlot()` 的 1:1 写死。
- **送达通道**:Console 侧用 `tmux -S <socket> send-keys` 把 `/new` 敲进每个 agent 的 pane(`C-u` 清行 → literal `/new` → `Enter`)。不走 `submit()`(它是 ask 任务管道,非原始按键),不改 ccbd Python。
- **触发时机**:
  - 绑定:`bindRequirement()` 事务提交**后**触发,仅 `newlyBound` 时(幂等),try/catch 吞错不回滚。
  - 解绑:`release` 路由在 `releaseSlot()` **之前** best-effort 触发,永不阻断。

## 3. 组件与改动
| 文件 | 改动 |
|---|---|
| `ccbd-client.types.ts` / `ccbd-client.service.ts` | 补 `projectView()` 类型 + 封装 ccbd `project_view` op |
| `slot-context-reset.service.ts`(新增) | 枚举 slot 分组 agent + 逐 pane `tmux send-keys` 送达 `/new`,逐 agent 记 sent/skipped/failed |
| `slot-binding.service.ts` | 新增 `onSlotBound` 回调;bind 提交后 best-effort reset,失败不回滚 |
| `slot.routes.ts` | release 前 `resetSlotContextBestEffort`,失败仅 warn、不阻断 |

## 4. 失败/可观测
- `SlotContextResetResult` 聚合 sent/skipped/failed + 逐 agent reason;非 `ok` 时 `app.log.warn`。
- pane 缺失→skipped;socket 缺失/project_view 失败→failed;均不抛断主流程。

## 5. 验证
- typecheck 通过;`slot-context-reset.service.spec.ts` 单元通过;DB 相关 spec 由 codex 报告 15 passed。
- 用户实测 slot2:bind/unbind 后 claude+codex 均收到 `/new`,claude 新建会话生效。

## 6. 已知技术债 / Out-of-scope
- **技术债**:Console 直接驱动 tmux,与 ccbd 既有 `project_clear_context`(Python 侧戳 pane)功能重叠、且 Console 耦合 tmux 细节。建议后续收敛为单一 ccbd op,Console 不碰 tmux。
- 不做"确保清理完成"的强一致/回执校验;busy agent 不先 stop(记 skipped)。

---
id: c80da33d2ae4e053b5f40d29c
title: Console 文件监听器不为运行时新建项目注册 watcher
doc_type: requirement
status: cancelled
created: 2026-05-26T10:35:09.615Z
analysis_input_hash: 9f0ef3ef94e349eb9f767dd93360dab30cc29566641b24a8ae326db96456e5a6
analysis_applied_at: 2026-05-26T10:43:22.821Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

Console 的 FileWatcherService 只在 server bootstrap（app.ts onReady → start()）时枚举「当时已存在」的 project，为每个项目的 docs/ 目录建立 chokidar watcher；start() 被 `if (this.started) return` 守卫，且该类只暴露 start/stop/queueProjectFileEvent，**没有「为运行时新建项目动态注册 watcher」的能力**。

后果：凡在 server 启动之后才创建/初始化的项目，其 docs/ 目录永远没有活的 watcher。plugin 侧基于文件的写入（物化子任务 spec、写 EventJournal、改需求 md、breakdown draft 等）不会触发 indexer 增量 scan，产物投影不进 Task DB，前端展示缺失；只能重启 server 或手动 `POST /api/projects/:id/scan` 才能恢复。

经核验的现状（证据）：
- FileWatcherService.start() 一次性枚举 project + `if (this.started) return` 守卫，无 addProjectWatcher：`apps/ccb-console/server/src/fs/file-watcher-service.ts:103-150`。
- start() 仅在 app bootstrap onReady 调用一次：`apps/ccb-console/server/src/app.ts:177`。
- 实证：项目 cmpmglu6w0000qrjaet0bj3z1 创建于 2026-05-26T09:55:17Z，server 启动于 09:54:49Z（早于项目创建 28 秒）；10:14:43Z 物化的 6 个子任务未自动投影，lastScanAt 停在 09:55:36Z；手动 `POST /scan` 后 `/epics` 立即返回 count:6 —— 证明 indexer 投影逻辑无误，唯一断点是「该项目没有活的 watcher」。

期望：项目创建/初始化后能自动获得文件 watcher（运行时动态注册），无需重启 server 即可对其 docs/ 改动自动触发 indexer 投影。

## 原话（verbatim）

（承接对话：用户先问「为什么我在需求详情页 …/requirements/cmpm4dnh766ea74feb4b5c2d5 看不到子任务的展示」，定位根因为 FileWatcherService 不给运行时新建项目注册 watcher；随后指示：）

> 把根治这个创建一个独立的需求

## Claude 解读

本需求把「Console 文件监听器不为运行时新建项目注册 watcher」从单点 bug，明确为 **indexer 自动投影链路的两层缺陷修复**：(1) watcher 生命周期；(2) plugin-hook 第二投影通道。用户已拍板两层都做。

**经核验的根因（证据，两层）**

- **第一层 · watcher 运行时不补注册**：`FileWatcherService.start()` 仅在 server bootstrap 枚举「当时已存在」的 project 建 chokidar watcher，被 `if (this.started) return` 守卫，类只暴露 `start/stop/queueProjectFileEvent`，无幂等 `ensureProjectWatcher`、无去重（`file-watcher-service.ts:103-150`）；`start()` 仅 onReady 调一次（`app.ts:177`），settings 再调被 `started` no-op。`POST /api/projects` 创建项目后不 scan、不注册 watcher。→ server 启动后才创建的项目永远无 watcher。
- **第一层补充 · 注册前窗口**：watcher 配 `ignoreInitial:true`（`file-watcher-service.ts:124`），不扫存量；即便补注册，「项目创建 → watcher ready」间隙写入的文件也会漏。
- **第二层 · hook classifier 不覆盖 materialize 事件**：plugin runtime 已有 hook notifier，但 Console `plugin-hooks/event-journal` 的 classifier 只对 `file_written`/`breakdown_draft_*` 等触发 reindex/scan，对 `subtask_materialized`/`requirement_materialized`/`state_write_done(resource_type=subtask_spec)` 不形成投影触发。→ 即便有通知通道也不补投影。
- **投影本身无误**：`scanProject()` 是投影事实源，手动 `POST /scan` 后 `/epics` 立即 count:6（实证：项目 cmpmglu6w… 创建 09:55:17Z 晚于 server 启动 09:54:49Z，物化 10:14:43Z 未投影、lastScanAt 停 09:55:36Z，手动 scan 后恢复）。

**已锁定范围（用户拍板：两条通道都做）**

- **P0 watcher 生命周期**：`FileWatcherService` 增幂等 `ensureProjectWatcher(projectId)` + `ensureAllProjectWatchers()`；`start()` 改为 reconciliation（不再 started 后 no-op，补齐缺失 watcher）；调用点 = onReady + 项目创建后 + 显式 `/scan` 成功后；新 watcher 注册后触发一次 backfill `scanProject`；`Map<projectId,watcher>`（或 docsRoot）去重，`stop()` 关闭全部并清 map。
- **第二通道 defense-in-depth**：扩展 Console plugin-hook classifier，使 `subtask_materialized`/`requirement_materialized`/`state_write_done(resource_type=subtask_spec)` 也触发 `queueProjectScan`（或精准投影）。
- **运行时幂等**：新代码部署需 server 重载；启动后应自动 reconcile 所有已有 project，运行期新建/手动 scan 也补注册，不要求再手动重启来救「已存在但无 watcher」的项目。

**验收口径**

1. server 启动后新建的项目，其 docs/ 文件改动能自动触发 indexer 投影，无需重启或手动 scan。
2. docs 目录晚于项目创建出现的情况，后续 scan 能补注册 watcher。
3. 重复 ensure 不产生重复 watcher（去重断言）；`stop()` 清空所有 watcher 与 map。
4. 新 watcher 注册后的 backfill 能投影注册前已写入的 spec（关闭 ignoreInitial 窗口）。
5. 不经 watcher 时，`subtask_materialized`/`requirement_materialized` 事件经 plugin-hook 也能触发投影（第二通道）。
6. 不新增对外端口/依赖、不破坏 schema；scan 幂等、重复可接受。

## 歧义点

本需求经 1 轮 Codex consult（`job_b2d8c2aa9826`，slot2_codex）+ 1 项用户拍板澄清。

1. **【动态注册切入点】** su-init / 项目创建 / scanProject ensure 哪个最根上？→ Codex：不押单点，给 FileWatcherService 加幂等 ensure，并把 `start()` 改为 reconciliation；若只能选一个补漏点则优先「scan 成功后 ensure」（能修 docs 目录晚出现的情况）。**决议**：onReady + 项目创建后 + scan 成功后三处都 ensure。
2. **【backfill 必要性】** `ignoreInitial:true` + 注册前窗口会漏？→ Codex：必要。**决议**：先建 watcher 再触发一次 `scanProject` 作 backfill，投影幂等、重复可接受。
3. **【第二投影通道是否并入】**（命中·产品方向，已升级用户）→ **用户拍板：纳入本需求**。扩展 plugin-hook classifier 让 materialize 类事件也触发投影，形成 watcher + hook 双保险。
4. **【运行中实例】** fix 后是否仍需重启救旧项目？→ Codex：代码部署需 server 重载，但新代码启动应自动 reconcile，运行期幂等补注册，不要求再手动重启。**决议**：按此。
5. **【多 watcher 去重 / 注销】** → Codex：去重纳入 P0 安全边界（Map + `stop()` 清空）；项目删除 / 单项目注销不进 P0（当前无项目删除 API，只留接口余地）。**决议**：按此。

**必问项扫描**

- **命中且已处理**：产品方向（第二通道是否并入 → 已升级用户、用户拍板纳入）；工程完整性（注册时机 / backfill / 去重 → Codex 判定 + 决议）。
- **不命中**：隐私 / 合规 / 成本 / 外部服务 / schema 变更 / 新依赖——纯 Console 内部 indexer 触发链路修复，无数据契约变更、无数据出境、无新增依赖、无对外端口。

## 保真差异

- **保真差异**：用户原话「把根治这个创建一个独立的需求」中的「根治」，我未按字面只修「创建后补 watcher」，而是基于逐行读码核验展开为**两层根因**（watcher 生命周期 + `ignoreInitial` 注册前窗口 + hook classifier 不覆盖 materialize 事件），并就「第二通道是否并入」回放用户、由用户拍板纳入。未把单点 bug 当作全部、也未替用户决定范围广度。
- **范围非锚定**：本需求独立立项，未用 slot-terminal(b5c2d5) 等其它需求边界否决或收窄；范围广度由用户本轮决定（两条通道都做）锚定，未凭假设放大；schema / 依赖 / 对外端口等硬约束保持不变（不引入）。
- **Codex 协商证据（job_b2d8c2aa9826）**：纠正我两处 framing——(1) 补出 `ignoreInitial` 注册前窗口 → backfill 必要；(2) 指出 runtime 已有 hook notifier、真正缺口是 Console classifier 不覆盖 `subtask_materialized`/`requirement_materialized`。Codex 推荐 P0 = 幂等注册 + backfill + 去重、`start()` 改 reconciliation，并建议第二通道单独立项；用户最终选择并入本需求。
- **4 锚点反思**：① 我同意 = framing 修正与 P0 形态（幂等 ensure + reconciliation + backfill + 去重）；② 我（保留）不同意 = ensure 接入点应三处全接而非只「scan 后」（与 Codex 备选一致，非实质分歧）；③ 我的盲点 = 漏了 `ignoreInitial` 注册前窗口、且误判物化"完全不通知 Console"（实为 classifier 不覆盖 materialize 事件）；④ 接下来 = 落 analysis（本次）→ scan 投影 → 由用户决定是否进入技术设计。
- **sc 替代说明**：未跑 `/sc:analyze`（已逐行读码核验、证据精确到行号，强于对一句话需求做静态分析）、`/sc:research`（Console 内部 indexer 触发链路，无行业调研价值）、`/sc:business-panel`（无成本 / 隐私 / 合规 / 外部服务暴露，用户权利维度仅"产品方向"已由必问扫描 + 用户拍板覆盖）。

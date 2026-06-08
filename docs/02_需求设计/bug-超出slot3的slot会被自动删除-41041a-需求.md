---
id: cmq4sjzxda85540e69141041a
title: "BUG: 超出slot3的slot会被自动删除"
doc_type: requirement
status: planning
created: 2026-06-08T05:49:37.825Z
analysis_input_hash: abddb5f3ce12d442238288ef9822c625376cd44078303763d4afc18b578df7c5
analysis_applied_at: 2026-06-08T06:28:46.832Z
expression_spec: v1
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

我不确定是因为归档还是因为“释放slot”按钮操作导致这个需求“cmq3m1i8r5ac97ea38323ee06”之前在的slot4被删除了(我们系统 的默认是3个slot)

## 原话（verbatim）

我不确定是因为归档还是因为“释放slot”按钮操作导致这个需求“cmq3m1i8r5ac97ea38323ee06”之前在的slot4被删除了(我们系统 的默认是3个slot)

## 二、背景与目标

今天（2026-06-08 05:21）你把 CCB 项目从控制台**重新添加**了一次。控制台用一个可重建的投影数据库（Prisma/SQLite）记录"这个项目有几个 slot"——这个数字叫 `slotCount`，新建项目时默认值是 **3**。问题在于：**`slotCount`（以及"slot-4 上绑着哪个需求"）只存在这个会被重建的投影库里，人读 `docs/` 真相源中没有任何持久记录**。所以当 Project 行被删除重建（重新添加 / 重建 `dev.db`）时，`slotCount` 静默回落默认 3，**所有超出 slot-3 的 slot（这次是装着 23ee06 的 slot-4）连同绑定与会话上下文一起被丢弃**，无警告、无恢复入口。

这正是标题"超出 slot3 的 slot 会被自动删除"的本质：不是某个按钮删了它，而是**投影重建时，凡超出默认 3 的 slot 拓扑都无法存活**。"自动"指投影重建的静默回落，不是定时任务。

**目标**：把 slot 拓扑（至少 `slotCount`，最好含 slot→requirement 绑定）落到能在投影重建后存活的真相源；让"重新添加项目 / 重建 DB"能**恢复**而非清零 slot 拓扑；超出默认的 slot **永不被静默回收**，移除须显式二次确认（你拍板的期望行为）。本需求是 23ee06（多项目隔离）同簇的延续，聚焦"slot 拓扑在投影模型下的持久性与一致性"。

模拟示例（本次事故时间线）：

```
昨天: CCB 项目 slotCount=4, slot-4 装 23ee06(多 tab 串扰排查中)
今天 05:21: 你重新添加 CCB 项目
  → Console 新建 Project 行, create 不接收 slotCount → 落 @default(3)
  → slot-4 绑定随旧 Project 行一并消失, 23ee06 脱离 slot
  → ensureStarted/confirmRestore 按 DB(=3) 重渲染 .ccb/ccb.config 为 3 槽
结果: 顶部"4 个 slot" → "3 个 slot", slot-4 消失(你的 Q1 观察)
```

## 三、讨论与决策

- **sc 替代**：`/sc:analyze` 以逐行代码取证 + 只读 DB 取证替代（内部 bug，代码/数据证据比静态澄清更权威）；`/sc:research`、`/sc:business-panel` 不命中（内部 bug，无外部领域/业务面）——与姊妹需求 23ee06 同口径。技术设计阶段建议 `/sc:troubleshoot` 视角（Codex hint，high confidence）。
- **Codex 协商（job_26738bc815af，consult）**：确认 release/archive 都不降 slotCount、唯一直接降 count 的代码路径是 resize shrink；**修正**我"scanProject 投影重建会重置 slotCount"过宽——scan 只更 `syncStatus/docsRoot/lastScanAt/initStatus`，真正回默认 3 的是 **Project 行被删后重建**（create 不接收 slotCount，`project.store.prisma.ts:23`）；**补充**第三路径 `confirmRestore` 按 DB 真相重写 config（`project-ccbd-manager.ts:119`）；提示 release 触发 context reset 会丢会话上下文。
- **Claude 4 锚点反思**：①**同意**——release/archive 排除成立、shrink 是唯一直接降 count 路径（双向印证）；②**被修正**——"投影重建重置 slotCount"站不住，精确机制是 Project 行删除+重建；③**盲点**——漏了 `confirmRestore` 反写 config 这条"按 DB 反写拓扑"路径，也漏把"会话上下文丢失"当并行用户伤害，教训：排查拓扑回退要枚举所有"按 DB 反写 config / 重建 Project 行"的入口；④**下一步**——先只读 DB 取证再落档（已完成，根因已钉死）。
- **DB 取证结论（read-only 查 `dev.db`，决定性）**：CCB 项目行 `createdAt=2026-06-08T05:21:07Z`（今天新建）、`slotCount=3`；而 23ee06 创建于 06-07、EventJournal 最早 05-28——**Project 行比它承载的需求/事件晚生数天，证实项目行今天被删后重建**。全库**无任何 resize 事件、无 slot-4 的 `slot_released` 事件**（排除缩容误触与正常释放）；23ee06 现 `status=delivered` 且不绑任何 slot。→ **根因钉死：重新添加项目导致 Project 行重建、slotCount 回落 `@default(3)`，slot-4 拓扑与绑定随旧行丢失。你最初怀疑的"归档/释放"两者均被排除。**
- **用户拍板（2026-06-08）**：① 现象=顶部数量 4→3（确证 slotCount 回退）；② 近期操作=重新添加项目 + 重启/重建 DB +（可能）释放/归档，记不清，授权我先取证（已完成，根因钉死，无需复现）；③ 期望行为=**超出默认 3 的 slot 永不自动删除 + 移除须二次确认**；④ 范围=**完整档·并入 23ee06 簇**。
- **范围载体决策（Claude 兜底）**：23ee06 已 `delivered`（`su-reactivate` 仅支持 cancelled/deferred，不支持 delivered），故"并入"以**独立需求 41041a + 显式标注为 23ee06 簇延续 + 双向交叉引用**实现，不重开 23ee06。如你确需重开 23ee06 字面合并，请指出。

## 四、功能 / 范围（完整档）

聚焦"slot 拓扑在投影模型下的持久化与一致性"，与 23ee06 的 projection/truth-source 主题（ADR-0037）同源：

1. **slot 拓扑的持久真相源**：把 `slotCount`（最好含 slot→requirement 绑定快照）落到能在投影重建后存活的位置（docs 真相源或等效可重建输入），使"重新添加项目 / 重建 `dev.db`"后投影能**恢复**而非清零 slot 拓扑。落点（docs frontmatter / `.ccb` 持久 state / 其它）在 technical_design 定，须遵守 ADR-0037（DB 为可重建投影、人读 docs 为真相）。
2. **重建/重加不静默清零**：Project 重建/重新添加时，若检测到既有 slot 拓扑（config 或持久真相），按真相恢复 slotCount；config 与 DB 冲突（如 config=4 vs DB=3）时**冲突检测 + 升级用户显式选择**，不静默以 DB 覆盖 config（Codex 风险③：避免反向破坏 DB-truth-source 契约）。
3. **超出默认的 slot 永不自动回收 + 二次确认**（你的拍板）：移除 slot 仅经显式缩容、且二次确认并**警告会丢失该 slot 会话上下文**；任何重建/恢复路径都不得自动删除超出默认的 slot。
4. **resize 审计事件**：grow/shrink/restore 落 EventJournal 审计（Codex 风险①：当前无 resize 审计，事后无法归因），含 who / when / from→to。
5. **超出 count 的 binding 修复/可见**：消除"僵尸 binding"——projection 只渲染 `deriveSlotIds(slotCount)`（`slot.routes.ts:555`）、validate 超出即 404（`:586`）、cancel reconcile 跳过（`slot-binding.service.ts:494`）；给超出 count 的残留 binding 一个可见/可清理/可恢复入口。
6. **缩容 UX 防误触**：「释放」(解绑) 与「缩容」(减 slot) 文案/交互区分（Codex 窄档要点并入），降低把缩容当释放的误触。

## 五、业务规则

1. 超出项目默认 slot 数（当前默认=3）的 slot **不得被任何自动 / 重建 / 恢复路径静默删除**。
2. 移除任何 slot 必须满足：slot 空闲 + 用户显式二次确认 + 明示"会丢失会话上下文"。
3. 投影（DB / config）与持久真相冲突时，以"升级用户显式选择"收敛，不静默单边覆盖。

## 六、边界 / 不做项

- 不重开已交付的 23ee06；本需求独立交付，仅交叉引用。
- 不改 ccbd（codex-dual runtime）命名 / 协议，以其为真相源做适配（沿用 23ee06 / e9f09f 边界）。
- 不在本需求修 23ee06 已交付的跨项目路由 / 隔离面；本需求专注 slot 拓扑持久性与一致性。
- 历史已丢失的 slot-4 会话上下文（tmux pane）不追溯恢复（物理已销毁）；目标是防止未来再丢，非找回本次。
- EventJournal / schema 若需迁移以承载持久拓扑，先在 technical_design 升级用户再动。

## 七、开放问题 / 假设

**移交 technical_design（届时按必问升级）**：① slot 拓扑持久真相源的落点与格式（docs frontmatter vs `.ccb` 持久 state vs 其它）；② 绑定是否一并持久（slot→requirement），还是只持久 slotCount + 靠 `backfillFromAnchorAllocations` 重建绑定；③ config↔DB 冲突的具体 UX（`confirmRestore` 改造）；④ 是否分批交付（先"不静默清零 + 审计"止血，后"持久真相源"根治）。

**工作假设**：当前代码 = 事故发生时代码；你未手工直接改 DB / config；当前 `.ccb/ccb.config` 的 3 槽与 DB `slotCount=3` 一致（已 DB 取证印证）。

## 八、拆分预览

预期方向（task_breakdown 定稿）：① slot 拓扑持久真相源 + 重建恢复；② 重加/重建 config↔DB 冲突检测 + `confirmRestore` 升级用户；③ 超出默认 slot 永不自动删 + 缩容二次确认 + context-loss 警告；④ resize / restore 审计事件；⑤ 超出 count 僵尸 binding 的可见/清理/恢复入口；⑥ 释放 vs 缩容 UX 区分；⑦ 回归与（可选）多 tab / 重加 e2e。

## 十二、交互 / 流程

失败链路（已 DB 取证确证）：

```
重新添加 CCB 项目 (2026-06-08 05:21)
 → 删除旧 Project 行 → slot-4/23ee06 绑定随之消失
 → 新建 Project 行: create 不接收 slotCount → @default(3) (project.store.prisma.ts:23)
 → ensureStarted/confirmRestore 按 DB slotCount=3 重渲染 .ccb/ccb.config 为 3 槽
    (project-ccbd-manager.ts:109/119; config 跟随 DB, 非反向)
 → 顶部"4 个 slot" → "3 个 slot"; slot-4 + 23ee06 会话上下文丢失
（全程无 resize 事件、无 slot-4 release 事件 → 排除缩容/释放/归档）
```

期望链路：

```
重新添加项目 → 读持久 slot 拓扑真相 → 恢复 slotCount(=4)
 → config 与真相一致则直接恢复; 冲突则升级用户选择(不静默清零)
 → 超出默认的 slot 保留, 仅显式二次确认才可移除
```

## 十三、风险

- **会话上下文丢失**：缩容 / 重建会销毁 tmux pane，扩回不恢复旧对话；release 也触发 context reset。所有移除 / 恢复路径须按"数据 / 会话丢失"对待并显式警告。
- **DB-truth-source 契约张力**（Codex 风险③）：若"按 config 反推 slotCount"或"按持久真相恢复"设计不当，会与 ADR-0037"DB 为可重建投影、docs 为真相"冲突；须设计成冲突检测 + 人工选择，不静默修复。
- **回归面**：触及项目新增 / 重建、ccbd config 渲染、slot resize / projection；需回归既有 grow / shrink / release / archive 与启动恢复。
- **持久真相源选型**：若落 docs frontmatter，需定义 schema 与 indexer 投影；若落 `.ccb` 持久 state，需保证它本身被 git / 备份留存（当前 `.ccb/ccb.config` 未被 git 跟踪，无法作持久真相）。

## Claude 解读

这是一个"slot 拓扑（超出默认 3 的 slot）在投影重建后被静默丢弃"的持久性 bug，经 Codex 协商修正 framing、再经只读 DB 取证**钉死根因**。

**根因（已确证）**：`slotCount` 是 Project 投影行字段 `@default(3)`，且 slot 拓扑（slotCount + slot→requirement 绑定）**只存于可重建的 Console 投影库，人读 docs 真相源无任何持久记录**。今天 05:21 你重新添加 CCB 项目 → 旧 Project 行删除（slot-4 / 23ee06 绑定随之消失）→ 新 Project 行 create 不接收 slotCount，落回 `@default(3)`（`project.store.prisma.ts:23`）→ `ensureStarted` / `confirmRestore` 按 DB=3 重渲染 `.ccb/ccb.config` 为 3 槽（`project-ccbd-manager.ts:109/119`，config 跟随 DB）。DB 取证：CCB 项目行 `createdAt=2026-06-08T05:21:07Z`（晚于其承载需求 / 事件数天）、`slotCount=3`，全库无 resize 事件、无 slot-4 release 事件。

**关键澄清**：你最初怀疑的"归档 / 释放"两个按钮**均被代码 + 数据双重排除**——释放只解绑、归档只入队 `/ccb:su-archive`，都不改 slotCount；连"缩容误触"也被排除（无 resize 事件）。真因是项目重建使投影回落默认值。标题"超出 slot3 的 slot 会被自动删除"在更深层准确：凡超出 `@default(3)` 的 slot 拓扑都无法在投影重建后存活。

**与 23ee06 的关系**：同属 ADR-0037 projection / truth-source 主题簇——23ee06 是跨项目"路由"隔离，本需求是 slot 拓扑"持久性"。你拍板完整档·并入该簇；因 23ee06 已 delivered（`su-reactivate` 不支持 delivered），以独立需求 41041a + 簇延续 + 交叉引用实现，不重开 23ee06。

**范围（完整档，已拍板）**：① slot 拓扑持久真相源 + 重建恢复；② 重加 / 重建 config↔DB 冲突检测 + 升级用户（不静默清零）；③ 超出默认 slot 永不自动删 + 移除二次确认 + context-loss 警告；④ resize / restore 审计事件；⑤ 超出 count 僵尸 binding 可见/清理/恢复入口；⑥ 释放 vs 缩容 UX 区分。

**验收口径（默认，review 可调）**：重新添加项目 / 重建 `dev.db` 后，既有 slot 拓扑（含 >3 的 slot）能恢复或在冲突时升级用户，**不再静默回落默认 3**；超出默认的 slot 无任一自动路径可删除；缩容须二次确认 + context-loss 警告；resize / restore 留审计事件；file:line + DB 根因链已具备（本分析）。

**下一步**：需求分析完成，建议进入 technical_design（需就"持久真相源落点"与"DB-truth-source 契约张力"做设计 + 必问升级）。
## 歧义点

1.【已确证-DB 取证】"被删除"的精确语义（slotCount 4→3 / binding 僵尸 / 需求实体）：你的 Q1 答"顶部数量 4→3" + DB 取证（项目行今天重建、slotCount=3）确证为 **slotCount 回退**，非僵尸 binding、非需求实体丢失（23ee06 md 与 delivered 状态都在）。

2.【已排除】触发操作（归档 / 释放 / 缩容）：代码 + DB 双重排除——release / archive 不改 slotCount，全库无 resize 事件排除缩容；真因是项目重建（你的 Q2 答"重新添加项目 + 重建 DB"）。你最初两个怀疑对象均不成立。

3.【已拍板】期望行为（超出默认 slot 的处置）：你拍板 **永不自动删除 + 移除须二次确认**（含 context-loss 警告）。据此 slot 拓扑须持久化、重建须恢复、移除须显式确认。

4.【已拍板·载体待你确认】范围与载体：你拍板 **完整档·并入 23ee06 簇**；因 23ee06 已 delivered，实现为独立 41041a + 簇延续 + 交叉引用（不重开）。如需字面重开 23ee06 合并，请指出。

5.【移交 technical_design】持久真相源落点（docs frontmatter vs `.ccb` 持久 state vs 其它）、绑定是否一并持久、config↔DB 冲突 UX、是否分批——均属技术设计必问项，届时按命中升级。

当前无待你拍板的需求层歧义；技术实现取舍移交 technical_design。
## 保真差异

1. 用户原话提出两个归因假设（"归档" / "释放 slot 按钮"）：经代码 + 只读 DB 取证**双双排除**——二者都不改 slotCount，且全库无 resize / 缩容事件、无 slot-4 release 事件。真因是"重新添加项目导致 Project 投影行重建、slotCount 回落 `@default(3)`"，属用户 Q2 补充的操作，非原话首选假设。如实记录此归因修正。

2. 原话"slot4 被删除了"：精确化为"slot-4 的拓扑与绑定随旧 Project 行一并消失、slotCount 回落默认 3"；伴随但原话未提的伤害是 **slot-4 会话上下文（tmux pane）一并销毁**（Codex 提示），已纳入风险与边界。

3. 标题"超出 slot3 的 slot 会被自动删除"宽于"某按钮删除"：分析确认其在更深层准确——凡超出 `@default(3)` 的 slot 拓扑都无法在投影重建后存活；"自动"指投影重建的静默回落，非定时任务。

4. 原话只描述现象与归因猜测，未要求架构改造："slot 拓扑持久真相源 + 完整档审计"的范围扩展源于你 2026-06-08 拍板（完整档 + 永不自动删），非分析者自行加戏。

5. "(我们系统默认是 3 个 slot)"：与代码 `slotCount @default(3)` 一致；正是该默认值在投影重建时覆盖了你已扩的 4，构成根因一环。

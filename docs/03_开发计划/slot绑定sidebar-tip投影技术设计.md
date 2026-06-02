---
id: td-slot-tip-projection-91b0d7
title: slot 绑定 sidebar tip 投影 技术设计
doc_type: technical_design
requirement_id: cmpqls8ny3f0b1c1c0c91b0d7
updated: 2026-05-29
---

# slot 绑定 sidebar tip 投影 技术设计

> 一句话：把 slot↔需求绑定关系作为 DB 派生投影，并入 ccb.config 唯一渲染器，写进 `[ui.sidebar.view].tips`，让 CCB 原生 tmux sidebar 直观显示 slotN→需求名 ｜ 最后更新：2026-05-29
>
> **无独立 status** —— 跟随 `requirement_id`（cmpqls8ny…91b0d7）指向的需求。

> 经 technical_design 节点产出：源码核验 + slot1_codex 两轮协商（job_99750bb0b7dc / job_e0e00410f373）+ 用户拍板（时效放宽、全局表、实时标题）。

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | slot 绑定 sidebar tip 投影 |
| 核心职责 | 绑定/解绑/启动时，把当前全部 slot↔需求映射重算为受管 tips，写入 `.ccb/ccb.config` |
| 设计原则 | DB 派生全量投影、幂等、唯一写者、best-effort 非阻塞、正确性优先于时效 |
| 需求来源 | `docs/02_需求设计/对接ccb面板的tip动态编写-91b0d7-需求.md` |
| 覆盖范围 | tips 投影渲染 + DB 感知重算 + 全部绑定入口接线 + 启动 reconciliation |
| 不覆盖（非目标） | 改 CCB 本体加刷新 RPC；**任何主动刷新触发**（CCB sidebar 自轮询，无需）；per-window 单独显示；保留用户手写 tips；标题改名即时同步 |

## 二、方案与架构

```
绑定/解绑(任一入口)         启动/restore
  slot.routes ┐               ProjectCcbdManager
  anchor.routes├─bindRequirement/releaseSlot   .ensureStarted/.confirmRestore
              │      │                              │
              ▼      ▼ (默认回调层, best-effort)     ▼ (传 tips 投影)
        SlotBindingService.onSlotBound/onSlotReleased
                     │  组合既有 /new、router.tick，不覆盖
                     ▼
        SlotTipsProjectionService.syncSlotTips(projectId)
          [per-project mutex] 锁内重查 DB → 算全量投影 → 调 ↓
                     ▼
        managed-config: buildManagedCcbConfig(preserved,{sidebarViewTips})
                     │  原子写(temp+rename) .ccb/ccb.config
                     ▼
        [ui.sidebar.view] tips_enabled=true / tips=[ "slot-1: 标题", ... ]
                     ▼
        CCB sidebar TUI 每 ~1s 自轮询 project_view(RPC) → 每次重读配置 → 自动显示
        (无需 Console 触发；view 1s TTL ⇒ 实际延迟 ~1-2s)
```

| 关键原则 | 说明 |
|----------|------|
| 全量投影 | 每次只"重算全部受管行"，不增删单行 → 幂等、抗并发、抗启动重写 |
| 唯一写者 | tips 并入既有 `buildManagedCcbConfig` 渲染器，避免多写者打架 |
| 接线在 service 层 | 投影同步挂 `SlotBindingService` 回调，覆盖 slot/anchor 全部绑定入口 |
| 实时标题 | 投影读当前 `Requirement.title`；改名下次同步自动跟上（用户拍板） |
| best-effort | tips 写入/刷新失败绝不影响 bind/release 主事务 |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `managed-config.service.ts` | 加 `sidebarViewTips` 渲染选项；tips **不进** coreSignature/preserved | windows/agents/ui.sidebar 核心渲染与签名逻辑不变 |
| `slot-binding.service.ts` | onSlotReleased 补 best-effort 包装；默认回调组合 tips sync | bindRequirement/releaseSlot 事务语义、emitEvent 不变 |
| `slot.routes.ts` / `anchor.routes.ts` | 确保经默认回调链触发 tips sync | 既有 `/new`(bind)、`router.tick()`(release) 回调**组合保留** |
| `project-ccbd-manager.ts` | ensureStarted/confirmRestore 传入 tips 投影 | 其余启动/drift 逻辑不变 |
| `anchor-template` / `project-onboarding` | **不动**（无参 buildManagedCcbConfig，不渲染 tips） | 由测试锁定"非主项目写者不带 tips"语义 |

## 三、关键决策与取舍

- **tips 落点**：选 ccb.config `[ui.sidebar.view].tips`，因为这是 CCB 原生 sidebar 唯一无需改 CCB 即可显示业务映射的入口；承认是 ADR-0032 边界外的 Console managed projection。
- **全量投影 vs 事件式增删单行**：选全量重算；否决增删单行——并发会互相覆盖，且与启动 wholesale 重写打架。
- **Fork 1 全托管 vs Fork 2 merge 用户 tips**：选 Fork 1（Console 全托管 tips 段）；否决 Fork 2——ccb.config 已是全托管文件（`buildManagedCcbConfig` 整文件重生成），用户手写 tips 本就活不过启动，merge 是为不存在场景引入 TOML 库依赖与复杂度。
- **实时标题 vs 绑定时快照**：选实时（投影读当前 title）；否决快照——快照需在 `SlotBinding.historyJson` 存 titleSnapshot 更费事，实时更简单且改名能跟上（用户复核后拍板，反转分析阶段 Q3）。
- **刷新**：选**不做任何主动刷新**——经 CCB 源码核验（`tools/ccb-agent-sidebar/src/tui.rs` 自轮询 1000ms + `lib/ccbd/project_view/service.py` view 层 1s TTL，配置层每次 `load_project_config()` 重读），sidebar TUI 每 ~1s 自轮询 `project_view` RPC 并重读配置 ⇒ Console 写完配置后 sidebar **~1-2s 内自动显示**。`'r'`（`force_refresh()`）仅强制提前下一次轮询、仍受 1s TTL 限制，收益可忽略，故连 P1 也不做。否决"Console 主动发 'r'"。
- **无新依赖**：手写 TOML 数组行（复用现有 string-line 风格），每个字符串 literal 用 `JSON.stringify` 生成以正确转义；否决引入 TOML 库。

## 四、核心流程 / 逻辑

```
syncSlotTips(projectId):
  acquire per-project mutex            # 同项目串行化
    projectRoot = Project.localPath(projectId)        # 解析根
    rows = SlotBinding[state∈{bound,busy,unhealthy,recovering} ∧ requirementId≠null]
           join Requirement.title                     # 实时标题
    tips = rows.sortBy(slotId).map(r => `${r.slotId}: ${truncate(title)}`)
    ensureManagedCcbConfig({projectId, projectRoot, sidebarViewTips: tips})  # 原子写
    # 无刷新触发：CCB sidebar 每 ~1s 自轮询会自动读到新配置
  release mutex
  # 全程 try/catch：任何失败只记日志，不抛给 bind/release
```

| 处理规则 | 说明 |
|----------|------|
| 幂等 | 全量重算 + 原子写：重复触发结果一致；崩溃重启由启动 reconciliation 兜底 |
| 并发 | per-project 进程内 mutex；锁内重查 DB（绑定事务已先于回调提交）→ 末次写反映全部已提交绑定 |
| 失败隔离 | onSlotBound 已 try/catch；onSlotReleased 补对称 best-effort 包装，杜绝"DB 已变更但 API 失败" |
| 接线完整性 | 必须覆盖：slot.routes bind / anchor.routes bind / release / startup restore（漏任一 → stale） |
| 未启动/无 tmux | 只写投影即可（本就无刷新动作，非脏数据）；CCB 启动/轮询时 project_view 重读对齐 |
| 可观测 | tips sync 结果（写入行数/失败原因）打 warn 日志，复用 slot-context-reset 的 summarize 风格 |

## 五、测试策略

- [ ] 单元：TOML 数组转义（引号 / 反斜杠 / 中文 / 长标题截断 / 空集合）
- [ ] 单元：`buildManagedCcbConfig({sidebarViewTips})` 渲染 + tips **不影响** coreSignature
- [ ] 单元：`computeSlotTipsProjection` 仅纳入活跃且有 requirementId 的绑定、按 slotId 排序
- [ ] 集成：slot.routes 绑定 / anchor.routes 绑定 / release 三入口都触发 tips 同步
- [ ] 集成：启动 ensureStarted/confirmRestore 后 tips 反映当前绑定（reconciliation）
- [ ] 集成：onSlotReleased 内 tips 同步抛错时，release API 仍成功
- [ ] 集成：onboarding / anchor-template 无参渲染**不含** tips（锁定非主写者语义）
- [ ] 回归：连续绑定多个 slot，tips 含全部映射且逐行对应正确

## 六、数据设计

**无 DB schema 变更 / 无 migration**。复用现有：

| 实体 / 表 | 关键字段 | 说明 |
|------|----------|------|
| `SlotBinding` | `projectId` `slotId` `requirementId` `state` | 投影数据源；只读 |
| `Requirement` | `id` `title` | 实时标题来源；只读 |
| `Project` | `localPath` | 解析 projectRoot |

**投影产物（非持久实体，写入 ccb.config）**：

```toml
[ui.sidebar.view]
tips_enabled = true
tips = [
  "slot-1: 对接CCB面板的tip动态编写",
  "slot-2: ……",
]
```

纳入投影的绑定状态：`bound` / `busy` / `unhealthy` / `recovering`（排除 `idle` / `draining`）。

## 七、接口设计

**无对外 HTTP 接口变更**。bind/release endpoint 签名与语义不变；tips 投影是其内部 best-effort 副作用。新增均为 server 内部模块方法（`computeSlotTipsProjection` / `syncSlotTips`）。

## 八、文件结构 / 变更清单

- `[NEW] apps/ccb-console/server/src/modules/slot-binding/slot-tips-projection.service.ts`：`computeSlotTipsProjection(client, projectId)` + `syncSlotTips(projectId)`（解析 projectRoot、per-project mutex、调 ensureManagedCcbConfig、best-effort）
- `[MODIFY] .../project-ccbd/managed-config.service.ts`：`buildManagedCcbConfig(preserved, opts?)` 支持 `sidebarViewTips`；渲染 `[ui.sidebar.view]`；tips 排除出 coreSignature/preserved；TOML 转义用 JSON.stringify
- `[MODIFY] .../slot-binding/slot-binding.service.ts`：加 `notifySlotReleased` best-effort 包装；默认回调组合 tips sync（覆盖所有 bind 入口）
- `[MODIFY] .../slot-binding/slot.routes.ts` `.../anchor-lifecycle/anchor.routes.ts`：确保绑定/解绑经默认回调链触发 tips sync，**组合**既有 `/new`、`router.tick()`
- `[MODIFY] .../project-ccbd/project-ccbd-manager.ts`：ensureStarted/confirmRestore 计算并传入 tips 投影
- `[NEW] tests`：上述五条测试策略对应的 spec

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| （无运行时新依赖） | — | 不依赖 tmux 刷新触发；CCB sidebar 自轮询（~1s）自动重读配置 |

**无新增 npm 依赖**。配置项：`[ui.sidebar.view].tips_enabled` 固定 true；`tips` 由投影生成，不接受用户手填（全托管）。截断长度建议常量化（默认约 24 字，可调）。

## 十、迁移影响与风险

- **受影响**：`managed-config.service`、`slot-binding.service`、bind/release/startup 接线链；产物 `.ccb/ccb.config` 新增 `[ui.sidebar.view]` 段。
- **打法**：纯增量；tips 默认不输出，只有显式传 `sidebarViewTips` 才渲染；先并入渲染器与投影服务，再逐入口接线，每步测试覆盖。
- **回滚 / 恢复**：移除 tips 传入即恢复旧行为；ccb.config 由启动 reconciliation 重建，无需手工修复。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 接线遗漏致 stale | 中 | tips 不更新 | service 默认回调层接线 + 三入口集成测试 |
| 无参写者清空 tips（onboarding/anchor-template/启动） | 中 | tips 被抹 | 启动传投影；锁定非主写者语义的测试 |
| TOML 转义错误破坏配置 | 低 | CCB 解析失败 | JSON.stringify 转义 + 转义单测 |
| 多 Console 实例并发写 | 低 | 互相覆盖 | **假设单实例**（本地工具）；多实例再升级文件锁 |
| 刷新延迟 ~1-2s | 低 | 轻微 | CCB sidebar 每 ~1s 自轮询自动重读配置显示（源码确证）；用户已放宽时效；无需任何触发 |

## 协商与反思留痕

- **协商**：slot1_codex 两轮（job_99750bb0b7dc 需求层、job_e0e00410f373 设计层）。设计层 Codex 抓出三处接线坑（anchor.routes 也绑定、回调已被 /new 与 router.tick 占用需组合、onSlotReleased 未 try/catch）+ 一处真实矛盾（"读实时标题"与分析阶段"快照"决定冲突），并确认 `sidebar_pane_id` 在原始 project_view 存在。
- **4 锚点反思**：①同意 Fork 1 + 接线放 service 默认回调层 + 启动传投影 + best-effort 隔离 + 锁内重查原子写 + 延后主动刷新；②修正——未直接落 titleSnapshot，而把"实时 vs 快照"反转交用户复核（实时更简单更好）；③盲点——曾漏 anchor.routes 绑定路径、漏回调需组合、漏自身实时/快照矛盾、不知 sidebar_pane_id 存在；④下一步——本设计落盘后判断进入任务拆分。
- **用户拍板**：时效放宽（正确性优先）、接受全局映射表、实时标题。
- **设计后追加核验（v1.1）**：用户质疑"是否需要发 'r'"。经 CCB 源码核验（`tui.rs` 自轮询 1000ms + `service.py` view 1s TTL，配置层每次重读），确认 sidebar 自轮询自动重读配置、~1-2s 显示 ⇒ **彻底去掉主动刷新**。用户直觉正确，修正了我"需 best-effort 发 'r'"这个未验证假设（盲点：把"存在 refresh_sidebar_panes 机制"误推为"Console 需主动触发"）。

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-05-29 | v1.0 | 初版：Fork 1 全量投影 + 单一渲染器 + service 层接线 + 实时标题 + 延后主动刷新 |
| 2026-05-29 | v1.1 | 源码核验 CCB sidebar 每 ~1s 自轮询、每次重读配置 → **彻底去掉主动 'r' 刷新**（连 P1 也不做）；设计进一步简化，无运行时新依赖 |

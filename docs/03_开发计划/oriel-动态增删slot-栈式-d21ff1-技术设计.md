---
doc_type: technical_design
requirement_id: cmmq2a2x3p25029cbd6d21ff1
title: "oriel 动态增删 slot（栈式）技术设计"
created: 2026-06-06
---

# oriel 动态增删 slot（栈式）技术设计

## 一、设计概述

oriel console 按项目动态调整业务 slot 数量（当前硬编码 3）。CCB bridge v7.3.2 `ccb reload` 已支持动态 add_window/add_agent/remove idle（2026-06-06 本项目实测），缺口全在 oriel 层。

**已拍板约束**（来源：需求文档 d21ff1）：栈式（编号连续、尾部增删）；min=1，无业务硬上限（防御常量 16）；缩容不删磁盘文件 + 扩回强制全新会话；resize 一次 ±1 单步；删除资格三重空；ccbd 离线写 desired 下次生效；reload 被拒直接报错不排队；存量 3-slot 项目零 drift。

**架构总览**：三个核心服务收敛全部逻辑，禁止各模块各自计算 N——

1. `ProjectSlotTopology`（新建，纯计算）：slotIds(slotCount) / agent-window 命名 / core signature 输入集。无 IO。
2. `ManagedConfigMutationLock`（新建）：per-project 文件写互斥，覆盖 resize / syncSlotTips / ensureStarted / confirmRestore 全部 config 写入方。
3. `SlotResizeService`（新建，编排）：资格判定 → DB → config → reload → 回滚/收尾。

**被拒方案**：从 config 反读 slot 数（双向同步漂移，2026-06-06 回写抹除事故即反例）；散点改"3→N"（无统一 topology，漂移复发）；任意删中间 slot（需求阶段已拒）；desired/effective 双轨拓扑（被不对称顺序方案替代，见四）；缩容时 config 保留 retired 段（破坏 managed 白名单与 drift 模型）。

## 二、方案与架构

- **真相源单向数据流**：`Project.slotCount`（DB）→ `ProjectSlotTopology` → managed config / 调度 SLOT_IDS / UI。config 永远是投影，不反读。
- **managed config 参数化**：`buildManagedCcbConfig(topology, overrides, options)`；`MANAGED_WINDOW_NAMES` / `MANAGED_AGENT_NAMES` / `AGENT_CORE` 由 topology 派生；`collectCoreLines` / signature 按 topology 白名单计算——slotCount=3 时输出与现状字节级一致，存量项目零 drift。
- **reload 集成**：新建独立 CLI wrapper（不混入 `CcbdClientService` socket RPC client）：spawn `ccb reload`（cwd=projectRoot），解析行协议输出（`reload_status` / `plan_class` / `safe_to_apply` / `reload_operation` / blocked 行），映射为结构化结果与错误类型。
- **non-core 配置保留**：`Project.slotAgentOverridesJson String?`（遵循本仓 `String ...Json` 列惯例）持久化 per-slot-agent 的 model/startup_args 等字段；缩容时从现 config 收割入库，扩回时注入生成——缩容不再丢配置。
- **删除资格**（`SlotResizeService` 内判定，不进 topology 也不塞 slot-binding）：尾部 slot 同时满足 ①无 SlotBinding 或 idle 且 requirementId=null ②无 pending/submitted AnchorDispatchQueue ③无 active runtime job。bound/busy/unhealthy/recovering/draining 一律拒绝。bridge reload 的 idle 检查作为第二道防线。

## 三、关键决策与取舍

| 决策 | 选择 | 拒绝项与理由 |
|---|---|---|
| slot 数真相源 | DB `slotCount` | config 反读：双向漂移 |
| 撕裂窗口消除 | 方向不对称顺序 + lock 挡绑定（见四） | desired/effective 双轨：状态翻倍，±1 单步下收益不成比例 |
| 资格判定归属 | SlotResizeService 编排层 | topology（要碰三张表，污染纯计算）；slot-binding（资格含 queue/job，越界） |
| overrides 存储 | `slotAgentOverridesJson String?` | Prisma `Json` 类型：违背本仓字符串列惯例 |
| reload 调用形态 | 独立 CLI wrapper | 混入 socket client：协议形态不同（CLI vs RPC） |
| 扩回全新会话 | reload 后等 agent active 再 context-reset（兜底） | 删 provider-state（违背拍板）；改 bridge fresh-mount（超范围） |
| 操作粒度 | ±1 单步（用户拍板） | 任意目标值：多 slot 部分成功中间态复杂 |

## 四、核心流程 / 逻辑

**扩容 +1**（reload 先行，DB 后行——调度看到新 slot 时运行态必已就绪）：

```
acquire ManagedConfigMutationLock(projectId)   # lock 期间 bind/enqueue 拒绝或等待
校验 slotCount+1 ≤ 16
write config(topology(slotCount+1) + overrides 注入)
ccbd 在线 → ccb reload
  ├─ 成功 → DB slotCount+1 → 等新 agents active（project_view retry）→ slot-context-reset（全新会话兜底）
  └─ 失败/被拒 → 回滚 config（DB 未动）→ 返回 bridge 原因
ccbd 离线 → DB slotCount+1，config 已写，下次 ensureStarted 生效
release lock
```

**缩容 -1**（DB 先行，reload 后行——调度先停派尾部再回收运行态）：

```
acquire lock
资格三重检查（尾部 slot）→ 不满足直接拒绝并报具体原因
收割尾部 slot non-core 字段 → slotAgentOverridesJson
DB slotCount-1（调度立即不再派尾部）
write config(topology(slotCount-1))
ccbd 在线 → ccb reload（remove_window；bridge idle 检查二道防线）
  └─ 失败 → 回滚 DB + config → 返回原因
ccbd 离线 → desired 已写，下次启动生效
release lock（磁盘 .ccb/agents/slotN_* 不删除）
```

**扩回全新会话**：实测显示 bridge mount 对 retired 残留未必 `--continue`（has_history 判定疑基于 session active 态），但不依赖此假设——扩容流程统一在 agents active 后执行 context-reset；绑定需求时的既有 reset 为第三道保证。已知限制：reset 前 pane 可能瞬时可见旧对话（若 bridge 恢复了），不影响后续工作上下文，smoke 验证实际行为。

**存量兼容**：migration 后所有项目 slotCount=3；topology(3) 生成的 signature 与现存 config 一致 → 启动零 drift；用户改 core 仍走现有 drift 确认流。

## 五、测试策略

- **单测**：topology 派生（1/3/16 边界）；managed config 参数化 + signature 兼容（旧 3-slot 字节级一致）；resize 编排（mock reload wrapper：成功/被拒/离线/回滚/lock 并发串行）；删除资格三重矩阵；isSlotId 动态判定（含取消 reconcile、terminal 路径）；reload 输出解析（fixture：今日实测的真实输出样本）。
- **真实 smoke（手动验收，非 CI）**：在测试项目执行 +1 → 派需求 → -1 被拒（busy）→ 释放 → -1 成功 → 再 +1，覆盖 pane ready、旧会话不恢复、其他 slot 无中断三个关键假设。验收步骤写入 dev_task。
- 既有测试矩阵全绿（typecheck + server/web 测试）。

## 六、数据设计

```prisma
model Project {
  slotCount              Int     @default(3)
  slotAgentOverridesJson String?   // { "<agentName>": { "model": "...", "startup_args": "[...]" } }
}
```

Migration：add-column-with-default，非破坏；执行时点在实施阶段经 dispatch 审批（不在设计期跑）。

## 七、接口设计

- `GET /api/projects/:id`（扩展）：返回 `slotCount` + 各 slot 删除资格摘要。
- `POST /api/projects/:id/slots/resize` `{ direction: "grow" | "shrink" }`：±1 单步；返回成功后拓扑或结构化失败原因（资格不满足项 / bridge 拒绝原因 / 离线 desired 已记录）。

## 八、文件结构 / 变更清单

| 位置 | 变更 |
|---|---|
| `server/src/modules/slot-topology/`（新） | ProjectSlotTopology 纯计算服务 |
| `server/src/modules/project-ccbd/managed-config.service.ts` | 参数化生成 + signature 动态白名单 |
| `server/src/modules/project-ccbd/managed-config-lock.ts`（新） | ManagedConfigMutationLock |
| `server/src/modules/slot-resize/`（新） | SlotResizeService + reload CLI wrapper + routes |
| `server/src/modules/slot-binding/slot-binding.service.ts` | SLOT_IDS → topology 注入 |
| `server/src/modules/slot-binding/job-slot-router.ts` | slotN_claude 写死 → topology（参照 slot-context-reset 动态枚举模式） |
| `server/src/modules/slot-binding/slot.routes.ts` | :436 过滤动态化 |
| `server/src/modules/slot-binding/slot-terminal.service.ts` | isSlotId → topology |
| `server/src/modules/anchor-broker/anchor-dispatch-worker.ts` | :159 isSlotId → topology |
| 取消投影 reconcile（reconcileCancelledRequirementProjection） | isSlotId → topology |
| `server/src/modules/project-ccbd/project-ccbd-manager.ts` | ensureStarted/confirmRestore 消费 slotCount |
| `server/src/modules/slot-binding/slot-tips-projection.service.ts` | 接入 mutation lock |
| project onboarding | module-level CCB_CONFIG_TEMPLATE 改为按项目惰性生成 |
| `web/src/pages/slots/SlotsPage.tsx` | 动态渲染 + ± 控件 + 缩容确认（列资格状态）+ 失败 toast + >5 资源提示 |
| API 类型 | slotCount / resize 状态 / 删除资格 |
| `server/scripts/lint_main_anchor_config.py` | 校验参数化 |
| Prisma schema + migration | 见六 |
| 关联 specs | e6d3663 文件面反向 + 本次新增服务 |

## 九、依赖与配置

无新外部依赖。运行时依赖 CCB bridge ≥ v7.1.0（reload 能力，当前 v7.3.2）；reload 输出为行协议，wrapper 对未知行容错（只依赖 `reload_status` / `plan_class` / blocked 前缀），bridge 输出演进时降级为"无法解析→视为失败+原样透出"。

## 十、迁移影响与风险

| 风险 | 应对 |
|---|---|
| resize 与绑定/派发竞态 | 不对称顺序 + lock 期间挡绑定；缩容资格三重空 + bridge idle 双防线 |
| config 多写者竞态 | ManagedConfigMutationLock 全写入方接入 |
| 存量 drift 误报 | signature(3) 与现状字节级一致，单测锁定 |
| 扩回恢复旧会话 | active 后 context-reset 兜底 + 绑定时 reset 三道保证；smoke 验证 |
| 缩容丢 non-core 配置 | 收割入 slotAgentOverridesJson |
| bridge 输出格式漂移 | wrapper 容错降级 |
| onboarding 模板时序 | 惰性生成，单测覆盖 |

## 变更记录

- 2026-06-06 初版。两轮 Codex 协商（job_941c3722dc10 需求轮 / job_4b055ddc4be1 设计轮）共识收敛；用户拍板：栈式、min=1 无业务硬上限（防御 16）、缩容不删文件+扩回全新会话、±1 单步。

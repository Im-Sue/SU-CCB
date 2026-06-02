---
id: td-c5c98f-agent-group-peer-routing
title: CCB 同组对端路由机制 技术设计
doc_type: technical_design
requirement_id: cmpmlnqxd02346a524ec5c98f
updated: 2026-05-31
---

# CCB 同组对端路由机制 技术设计

> 一句话：把"协商/派工先锚定自身 → 就近选同组(window)互补对端"做成 plugin 可确定性解析的机制；规则记在中立 kernel 约定、两侧各自实现；跨组只做软提示，真正强制力(runtime 拦截)列为上游 contract 依赖。｜ 最后更新: 2026-05-31
>
> **无独立 status** —— 跟随 `requirement_id` 指向的需求。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | CCB 同组对端路由机制 |
| 核心职责 | 给定当前 agent，确定其所属组(window)与同组互补对端；为协商/派工提供默认目标 + 跨组软提示 |
| 设计原则 | 身份先锚定；组 = window 成员关系(不绑 "slot" 字符串)；确定性优于启发(认不准就要显式)；中立层定约定、两侧各自实现；不改仓外 runtime(只提 contract) |
| 需求来源 | `docs/02_需求设计/ccb消息投递错乱问题-c5c98f-需求.md` |
| 覆盖范围 | 组抽象 + 对端 resolver(Claude 侧) + 中立 kernel 约定 + 跨组软提示 + runtime contract 诉求清单 |
| 不覆盖 | 改仓外 `ccb ask` 本体；Console `SLOT_IDS` / managed topology 去硬编码泛化(拆后续)；显式 `pairing/role` 配置 schema(v1 用唯一互补 provider，留后续) |

---

## 二、方案与架构

```
              ┌─────────────────────────────────────────────┐
              │  kernel 路由约定 (provider 中立 · 真相源)       │
              │  「先锚定自身 → 同组互补对端 → 跨组要理由」      │
              └───────────────┬─────────────────┬───────────┘
                  读约定+实现   │                 │  读约定+实现
            ┌──────────────────▼────┐       ┌────▼───────────────────┐
            │ plugin (Claude 侧)     │       │ codex-skills (Codex 侧) │
            │  agent-group resolver  │       │  对应实现 / 共享解析     │
            └──────────┬────────────┘       └───────────┬────────────┘
                       │  读                              │
              ┌────────▼──────────────────────────────────▼────────┐
              │   ccb.config [windows]   (组成员关系 · 数据真相源)    │
              └─────────────────────────────────────────────────────┘
                       │  发消息经过(仓外 · 本期不改)
              ┌────────▼──────────┐
              │   ccb ask runtime  │ ← 仅提 contract：暴露 actor/window/peers + 跨组 warning
              └───────────────────┘
```

| 关键原则 | 说明 |
|----------|------|
| 身份先锚定 | 任何协商/派工前先确定"我是谁、在哪个 window"，再选对端 |
| 组 = window | 用 `ccb.config [windows]` 成员关系定义组，不识别 "slot" 字符串 |
| 确定性优先 | 唯一互补对端才自动选，否则 `ambiguous`/`no_peer` 要求显式 target |
| 中立定义、两侧实现 | 约定落 kernel，Claude/Codex 各自实现，避免两份逻辑漂移 |
| 边界守恒 | 不改仓外 runtime，强制力作为上游 contract 依赖 |

**与现有系统的关系 / 边界：**

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `ccb.config [windows]` | 复用读取作为组数据源 | 不改配置格式 |
| plugin lib(`slot-health`/`su-init` 等) | 新增 agent-group resolver(纯函数) | 不动现有 lib 行为 |
| codex-skills | 新增/对齐对端解析，共享同一约定 | —— |
| `ccb ask` runtime(仓外) | 不动 | 仅产出 contract 诉求清单 |

---

## 三、关键决策与取舍

- **固化层**：选 **plugin 机制 + kernel 约定**，因为可确定性执行、可测、可版本化；**没选只写 CLAUDE.md**，因为纯提示拦不住自由发挥(本次事故根因)，且 CLAUDE.md 仅 Claude 可见、被 CCB 托管注入易被覆盖。
- **组抽象**：选 **window 成员关系**，因为它是现有拓扑真相源、对改名鲁棒；**没选 hardcode "slot" 前缀**，因为未来组可能改名(用户明确诉求)。
- **对端解析**：选 v1 **「唯一互补 provider」**，零配置改动、覆盖当前 1c+1x 组；**没选立刻引入 pairing/role schema**，因改动大且当前无多成员组；非唯一(0/多)→ `ambiguous`/`no_peer` 要显式，避免误选。
- **跨组策略**：选 **软提示(reason/warning)**，因为跨组 review/cross-check 合法不该禁；**没选硬拦截**，会误伤合法协作。
- **runtime**：选 **只提 contract、不直接改**，因仓外、影响所有项目、所有权不在本仓。

> 本节决策来源：需求分析 + 与同组对端 slot1_codex 的 mode=consult 协商(round 1，layer=requirement，已记录于事件流水)。

---

## 四、核心流程 / 逻辑

```
协商 / 派工前：
  1. 锚定自身   : 从 workspace 推断 agent 名 → 在 ccb.config 找含它的 window
        │
  2. 目标已显式? ──是──→ 跨组(目标 window ≠ 自身)? ──是──→ 要 reason/warning(不静默)──→ 放行
        │                                          └─否──→ 放行
        └─否
        ▼
  3. resolve 对端 : 同 window 排除自己 → 互补 provider 候选
        唯一? ──是──→ 默认投该对端
               └─否(0 / 多)──→ ambiguous / no_peer → 要求显式 target
```

| 处理规则 | 说明 |
|----------|------|
| 自身锚定失败 | 推不出 agent/window 时退化为"要求显式 target"，绝不猜 |
| 跨组判定 | 目标所在 window ≠ 自身 window 即跨组 |
| 默认值范围 | 仅"未显式 target 的 workflow consult/dispatch"启用默认对端；Claude→Claude 跨组 review 等显式场景不受限 |
| 可观测 | resolve 结果(peer / ambiguous / cross-group)应可记录，便于审计错投 |

---

## 五、测试策略

- [ ] 单元 · resolver 纯函数：1c+1x 组返回对端；纯单 provider 组返回 `no_peer`；多互补返回 `ambiguous`；未知 agent 退化显式
- [ ] 单元 · 组解析：window 成员 `name:provider` 解析；组改名(非 "slot" 前缀)仍正确分组
- [ ] 集成：协商/派工 skill 调 resolver 得默认对端；跨组触发 warning
- [ ] 回归：现有 `ccb ask` 未显式 target 的旧路径行为不被破坏

---

## 八、文件结构 / 变更清单（大纲 · 细节留拆分）

> 本文档为方案大纲，给"改动面"；逐文件细节由 `task_breakdown` / Codex 在实现时定。

- `[NEW]` **kernel 约定**：`references/kernel/` 下新增一条 provider 中立的"agent 路由 / 对端约定"，plugin 分发副本同步。
- `[NEW]` **plugin lib · agent-group resolver**：纯函数 `config → 组 → 对端`，返回 `peer | ambiguous | no_peer`。落点(新建 `lib/agent-group` vs 并入 `slot-health`)由 Codex 按最小改动定。
- `[MODIFY]` **协商/派工接线**：让 consult/dispatch skill 在发 `ccb ask` 前调 resolver(拿默认对端 + 跨组自检)。接线方式(skill helper / pre-ask hook / 仅供查)= Codex 实现时按最小改动定。
- `[NEW]` **codex-skills 侧**：对端解析对齐(读同一 kernel 约定 / 共享解析)，避免两侧漂移。
- `[NEW]` **contract 诉求清单**：记录希望仓外 `ccb ask` runtime 暴露 `current_actor` / `current_window` / `same_group_peers` + 跨组 warning(上游依赖，不在本期实现)。

---

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| `ccb.config [windows]` | 读取 | 组成员关系数据源 |
| 现有 config 读取工具 | 复用 | 优先复用，避免再写一份正则解析(round-1 协商指出现状脆弱) |

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| (无新增) | —— | v1 不新增 config key；显式 `pairing/role` 留后续需求 |

---

## 十、迁移影响与风险

- **受影响**：协商/派工发起路径(加一步 resolve)；**不改** `ccb.config` 格式、**不改** runtime。
- **打法**：先上 resolver + 软提示(尽力而为)；runtime 强制力作为后续上游依赖分批跟进。
- **回滚**：resolver 是新增纯函数 + 接线点，出问题可关闭接线、回退到旧"显式 target"路径。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 不改 runtime，手工 `ask` 跨组仍不被拦 | 中 | 错投仍可能发生 | kernel 约定 + plugin 软提示 + 上游 contract 诉求 |
| 两侧(Claude/Codex)实现漂移 | 中 | 行为不一致 | 约定下沉 kernel + 优先共享解析 |
| 唯一互补启发在未来多成员组误选 | 低(当前) | 选错对端 | `ambiguous` 回退 + 后续 `pairing/role` schema |
| 接线点选择不当增加耦合 | 低 | 维护成本 | 由 Codex 选最小改动切口 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-05-31 | v1.0 | 初版(需求分析 + 与 slot1_codex round-1 协商后产出) |

---
doc_type: dev_task
task_id: subtask-21ff25760f34
title: runtime v0.2 数据层:多空间 state 读写 + v0.1 lift + computeAggregateStatus + topology loader
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmpmultispacemerge260606
section_id: pr2-runtime-schema-multispace
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-be53b323049e]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmultispacemerge260606.json
source_draft_hash: 56f84fd263ca94c9bc00d4361027a499b9dbf4676109a462f9f7ce36d3eabf29
created_at: 2026-06-07T05:28:12.990Z
code_workspace: {"path":"../SU-CCB-req-cmpmultispacemerge260606","branch":"ccb/req-cmpmultispacemerge260606"}
---

# runtime v0.2 数据层:多空间 state 读写 + v0.1 lift + computeAggregateStatus + topology loader

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新增纯数据层:requirement-worktree-v0.2 读写、v0.1 读时内存 lift、aggregate 重算规则(含 pending 聚合态)、topology.mjs 声明加载/校验/展开(零声明默认+路径嵌套校验+content_hash+显式 YAML 子集)。只加新函数与单测,不重接既有 helper(pr3/pr4 接线),既有 22 用例零回归。 |
| 需求来源 | cmpmultispacemerge260606 |
| 本期范围 | pr2-runtime-schema-multispace · runtime v0.2 数据层:多空间 state 读写 + v0.1 lift + computeAggregateStatus + topology loader |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
为多空间编排打数据底座。本片只交付纯函数/数据层与单测,既有 5 个 helper 行为零改动——保证本片独立可验收、随时可落。

#### 任务分解(全部在 su-ccb-claude-plugin 子仓)
1. `lib/worktree/state.mjs`[NEW]:v0.2 结构定义与读写(字段见技术设计六:顶层 aggregate_status/spaces[]/associations[]/topology_source/last_error;space 含 space_id/kind/repo/path/branch/target_branch/base_sha/status/merge 簇/archive 簇/last_error;association 含 association_id/kind/from_space/to_space/submodule_path/status/synced_commit_sha/noop/synced_at/last_error);`liftV01ToV02(state)` 读时内存 lift(单记录→单 root space,associations:[],字段语义平移);写盘统一 v0.2 序列化。
2. `computeAggregateStatus(spaces, associations)` 优先序(设计 D5,Codex C2 修正版):all discarded→discarded;all archived→archived;all merged 且 all associations synced→merged;all ready→ready;仅 pending+ready 混合→pending;其余混合→escalated。
3. `lib/worktree/topology.mjs`[NEW]:加载 docs/.ccb/config/implementation-topology.yaml(文件不存在→零声明默认:单 root space 由调用方传入的 codeWorkspace 派生);schema 校验(schema_version 必为 implementation-topology-v0.1、space_id 唯一、kind 枚举、repo 相对路径、模板含 <requirementId> 占位、association from/to 引用存在的 space_id);`expandTopology({topology, requirementId, codeWorkspace})` 返回空间实例数组+associations 实例+content_hash;展开期校验:worktree path 解析后不得位于 projectRoot 内、不得位于任一 repo 目录内、彼此不得嵌套(Codex C4)。
4. YAML 解析:零新 npm 依赖,手写覆盖**显式子集**的极简解析器并在模块头注释声明子集——支持:`#` 整行/行尾注释、顶层与两空格缩进嵌套 map、`- ` 数组项(map 或标量)、单双引号与裸标量;不支持:anchors/aliases、flow 风格({}/[])、多行标量(|/>)、tab 缩进。超出子集→ValidationError 报行号,宁拒不猜(防模板含注释/列表时静默误读返工)。
5. 单测 `lib/worktree/__tests__/state.test.mjs` + `topology.test.mjs`[NEW]:lift 四态回归(ready/merged/archived/discarded 旧文件);aggregate 全规则矩阵——重点 ready+association pending→ready(不误 escalated)、仅 pending+ready→pending、merged+association pending→escalated、全 merged+synced→merged;topology 校验各拒绝路径+零声明默认+嵌套拒绝+content_hash 稳定性+YAML 子集边界(注释/数组/超子集拒绝)。

#### 验收标准
- a. `node --test su-ccb-claude-plugin/lib/worktree/__tests__/*.test.mjs` 全绿(glob 覆盖新增文件);既有 22 用例零回归(worktree.test.mjs 未触碰)。
- b. index.mjs 既有 helper 零行为变更(本片不改其读写路径)。
- c. 零新 npm 依赖(若发现必须引依赖,停止并升级,不得自行 npm install)。
- d. computeAggregateStatus 为纯函数,规则与设计 D5 文字逐条对应(测试用例名引 D5/C2/C8);YAML 子集在模块注释中可查。

#### 边界与不做
不重接 ensure/merge/cleanup/reopen/discard(pr3/pr4);不写 SU-CCB 真拓扑(pr5);不发事件、不改锁。

#### 引用
- 设计 D1/D5/D6 与六(数据设计);Codex consult C2/C3/C4(job_99a3e338f0fa)+B3/B7(job_7f48524ef45b,YAML 子集显式化)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-be53b323049e
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpmultispacemerge260606
- Section: pr2-runtime-schema-multispace
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-be53b323049e

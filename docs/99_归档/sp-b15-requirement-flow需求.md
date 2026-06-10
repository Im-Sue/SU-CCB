---
doc_type: requirement
title: "SP-B15 Requirement 完整交互流程设计 + Epic 迁移"
---

# SP-B15 · Requirement 完整交互流程设计 + Epic 迁移

## 1. 背景与范围

基于 SP-A10 路径 E（取消 Epic + Requirement 升格），设计 Requirement 完整交互流程 + 迁移 Epic 现有能力。

按 Console redesign 范围（用户 2026-05-18 收敛）：
- 关注 UI / 按钮 / 流程 ↔ 指令对应
- 不讨论指令内部逻辑（推到最后）
- 占位指令一律 mark 命名 + 预期效果

## 2. Epic 现状基线（Explore 已扫，详见 SP-B15 启动会话）

核心 4 角色：共享设计容器 / 子任务父任务 / Anchor 绑定主体 / 独立状态机
5 个 UI 位置：Epic 详情页 / breakdown-review / Requirement 详情页 Epic 列表 / GenerateTaskDialog / 任务看板

## 3. 迁移影响清单（4 类）

| 类 | 内容 |
|---|---|
| 简单移动 | materializationState / epicStatus / spec 文件 / 进度聚合 → Requirement |
| 直接删除 | Task.kind="epic" / Task.epicStatus / Task.materializationState / RequirementMaterialization 表 / Epic 详情页 |
| 需要重设计 | 立项流程 / su-flow carrier 检测 / breakdown review 路由 / SubTask.parentEpicId / Anchor 绑定 |
| 需要新设计 | Requirement 详情页承接 Epic 详情页能力 |

## 4. codex round 7 协商结论

- 派工：`job_a3f78d7fef3d`
- 回执：`rep_9b78d8e4c722`（status: completed）
- analysis_depth_hint: medium
- hint_confidence: high

### 4.1 4 设计点推荐（待用户拍板）

| # | 设计点 | codex 推荐 | 替代方案 |
|---|---|---|---|
| 1 | "立项"按钮语义 | **c · 取消"立项"词**，需求创建后就是 planning carrier，按钮按阶段叫"开始分析 / 开始设计 / 生成拆分草案" | 保留"启动计划"作为 PM gate，不再表示创建 Task carrier |
| 2 | Multi-PR 模式入口 | **a · 默认所有 Req 可拆 N 个子任务**，单 PR = N=1 特例，不在创建或首屏暴露 splitMode | 拆分审查页提供"重生成为单 PR / 多 PR"占位动作 |
| 3 | Breakdown Review 位置 | **b · 独立路由 `/requirements/:rid/breakdown-review`**，详情页只放摘要 + CTA | 小需求内联折叠；超过 3 个子任务自动引导全屏 |
| 4 | Requirement 详情页 | **吃掉 Epic 详情页主能力**（共享设计 / 进度 / 子任务时间线 / 拆分入口 / 活动时间线），保留子任务详情页 + 全屏拆分审查子页 | 保留 `/requirements/:rid/split` 作为大需求拆分视图 |

### 4.2 Q5 完整交互流程

```
创建 Req → 进详情 → "重新解析" → "开始设计" → "生成拆分草案"
→ 打开拆分审查 → "同意并创建子任务"
→ 子任务串行派工/实施/评审 → Req 聚合进度 → "归档需求"
```

cancel/defer 用独立按钮软标记，不在主流程里级联追问。

### 4.3 Q6 Requirement 详情页布局

```text
┌────────────────────────────────────────────────────────────┐
│ Header: 标题 / 状态 / 总进度 / 编辑 / 取消 / 暂缓             │
├────────────────────────────────────────────────────────────┤
│ Planning Strip: 当前计划状态 + planning anchor + 下一步按钮 │
├────────────────────────────────────────────────────────────┤
│ 需求内容: 原文 / 描述                                        │
├────────────────────────────────────────────────────────────┤
│ AI 解析: 解读 / 歧义 / 保真 / 重新解析                       │
├────────────────────────────────────────────────────────────┤
│ 技术设计: shared design 摘要                                 │
├────────────────────────────────────────────────────────────┤
│ 拆分草案: N 个子任务摘要 + 打开审查                          │
├────────────────────────────────────────────────────────────┤
│ 子任务时间线: 顺序 / 状态 / 当前动作 / 进度                  │
├────────────────────────────────────────────────────────────┤
│ 活动时间线: 默认折叠                                          │
└────────────────────────────────────────────────────────────┘
```

### 4.4 Q7 按钮 → 指令映射

| 按钮 | 指令 | 存在性 | 预期效果 |
|---|---|---|---|
| 重新解析 | `requirement-reanalyze` | ✅ | AI 生成新的解读 / 歧义 / 保真 |
| 开始 / 继续设计 | `/ccb:su-flow --subject=requirement --id=:rid` | ❓ 扩展现有 su-flow | 驱动 Req planning（需求分析 / 技术设计）|
| 生成 / 刷新拆分草案 | `/ccb:su-flow ... --goal=breakdown-draft` | ❓ 扩展现有 su-flow | 跑 task_breakdown 节点，产出 breakdown draft |
| 拒绝并送回 AI | `/ccb:su-revise-breakdown --requirement=:rid` | ❓ 占位 | 按用户意见重新生成拆分 |
| **同意并创建子任务** | `/ccb:su-materialize-requirement --requirement=:rid` | ❓ 占位 firm | 创建 N 个子任务直链 Requirement |
| 派工子任务 | `/ccb:su-dispatch --subtask=:id` | ✅ | 派 Codex / Claude 实施 |
| 评审子任务 | `/ccb:su-review --subtask=:id` | ✅ | review 子任务 |
| 归档子任务 | `/ccb:su-archive --subtask=:id` | ✅ | 归档子任务 |
| **取消 Req** | `/ccb:su-cancel --requirement=:rid` | ❓ 占位 firm | 软标记所有关联子任务 stopped |
| **暂缓 Req** | `/ccb:su-defer --requirement=:rid` | ❓ 占位 firm | 软标记暂缓 |
| **恢复 Req** | `/ccb:su-resume --requirement=:rid` | ❓ 占位 firm | 重新激活 |

### 4.5 Q8 待用户拍板（codex 留下 5 个）

| # | 问题 | 状态 |
|---|---|---|
| 1 | Req planning 状态标签 | ✅ 已拍板（见 §5.2）|
| 2 | shared design 在 UI 的命名 | ✅ 已拍板：**"技术设计"**（见 §5.5）|
| 3 | 子任务顺序是否可拖拽 | ✅ 已拍板：**首版不做拖拽**（见 §5.3）|
| 4 | 何时强制全屏审查 | ✅ 已拍板：**总是全屏**（见 §5.6）|
| 5 | Req 归档是否要求全部子任务 terminal | ✅ 已拍板：**硬约束**（见 §5.4）|

### 4.6 Q9 codex 标注风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 去掉"立项"后 backlog 心智变弱 | 用 status + "下一步"补足 |
| R2 | 详情页过载 | 三栏审查必须放子页 |
| R3 | 占位指令过多阻塞实施 | 优先固化 `materialize` / `cancel` / `defer` / `resume` 四个名 |

## 5. 用户拍板（2026-05-18 持续记录）

### 5.1 命名：子任务（SubTask）

- 中文 UI 文案：**子任务**
- 英文标识符：保留 `SubTask`（与现有 schema `Task.kind="subtask"` 一致）
- 数据层细节（Task 表名 / kind 字段去留）留 SP-A11

### 5.2 需求状态枚举（Q8.1）：6 个极简版

**用户偏好**：简单点 + 逐步增加。

| 状态 | 含义 |
|---|---|
| `drafting` | 刚创建，还在编辑内容 |
| `planning` | 在跑 AI 解析 / 设计 / 拆分（取代旧 `analyzed`） |
| `delivering` | 已拆子任务，在执行 |
| `delivered` | 全部子任务归档完 |
| `deferred` | 暂缓 |
| `cancelled` | 取消 |

**细分进度**通过 `currentPlanningStep` 字段表达（不扩状态枚举）：
- `analysis`（分析中）
- `design`（设计中）
- `breakdown_draft`（拆分草案中）
- `ready_to_materialize`（待批准创建子任务）

**未来如需增加细分，扩字段不扩状态**。

### 5.3 子任务顺序拖拽（Q8.3）

**用户拍板**：**首版不做拖拽**（草案审查里 + 时间线里都不做）

- 简化首版 UI 复杂度
- 子任务顺序由生成草案时 AI 决定 / 用户手动新增时按追加顺序
- 未来若有需求再增加（v1.1+）

### 5.4 需求归档约束（Q8.5）

**用户拍板**：**硬约束**

- 所有关联子任务必须全部 terminal（done / archived / stopped / cancelled）才能归档需求
- 不满足时归档按钮 disabled
- UI 上明示"还有 N 个子任务未完成"

### 5.5 shared design UI 命名（Q8.2）

**用户拍板**：**"技术设计"**

- 中文 UI 文案：技术设计
- 与现有 7 节点 `technical_design` 命名一致，PM 视角直观
- 拒绝候选：共享设计 / Spec Outline / 实施方案

### 5.6 全屏审查阈值（Q8.4）

**用户拍板**：**总是全屏**

- 无论子任务数量（1 个或 N 个），breakdown review 一律跳到独立全屏页 `/requirements/:rid/breakdown-review`
- 不做内联折叠 section 分支
- 简化 UI 复杂度，统一用户体验

### 5.7 codex round 7 四个推荐（§4.1 #1-#4）

**用户拍板**：**全盘接受 codex 推荐**

| # | 推荐 | 用户拍板 |
|---|---|---|
| 1 | 取消"立项"词，按阶段显示"开始分析 / 开始设计 / 生成拆分草案" | ✅ 接受 |
| 2 | 默认所有需求可拆多子任务；不在创建/首屏暴露 splitMode | ✅ 接受 |
| 3 | breakdown review 独立路由 `/requirements/:rid/breakdown-review` | ✅ 接受（间接接受，与 §5.6 总是全屏 一致） |
| 4 | Requirement 详情页吃掉 Epic 详情页主能力 | ✅ 接受 |

**SP-B15 至此所有决策点已拍板**，下一步进入 UI 草稿 + 流程时序设计。

## 6. 下一步

- 用户继续对剩余决策点拍板：
  - 4 个推荐（§4.1 设计点 1 / 2 / 3 / 4）
  - 4 个 open questions（§4.5 #2 #3 #4 #5）
- 拍板后 Claude 起草 Requirement 详情页 UI 草案（基于 §4.3 布局）
- 更新 SP-B92 mapping doc（已含 §4.4 按钮 → 指令对应）

## 7. 关联

- 子 PR 登记表：`docs/03_开发计划/ccb-plan/2026-05-18-v1.0-plugin-sovereignty-subpr-registry.md`
- SP-A10 备忘（实体模型依据）：`docs/02_需求设计/ccb-plan/2026-05-18-sp-a10-three-tier-model-consult.md`
- UI 按钮 ↔ 指令对应表：`docs/02_需求设计/ccb-console/2026-05-18-ui-skill-mapping.md`

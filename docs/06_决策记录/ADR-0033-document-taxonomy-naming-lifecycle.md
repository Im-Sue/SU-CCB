---
id: ADR-0033
title: Document Taxonomy + Naming/Lifecycle Policy + 主动清理策略
status: superseded
superseded_by: ADR-0037
decided_at: 2026-05-23
last_updated: 2026-05-23
decider: 用户 paradigm shift（议题 3 治理服务 v1.0 后长期 plugin/skills 管理）+ 路径 A（ADR 大方向先落档 → 启动议题 4 → 合并实施 spec）+ Claude 拍板 Q1-Q3
reviewer: ccb_codex（round 1 / rep_e0081d2530a1, round 2 / rep_b4476ca9483d, round 3 / rep_b820f44ea562）
codename: document-taxonomy
related_doc: [docs/.ccb/requirements/active/2026-05-23-phase5-v1x-governance-enhancement.md, docs/02_需求设计/ccb-plan/2026-05-22-phase5-governance-backlog.md]
parent_adrs: []
related_adrs: [ADR-0012, ADR-0026, ADR-0027, ADR-0030, ADR-0034]  # ADR-0012: task projection consistency（path-as-semantics 现有依赖）
consult_evidence: [job_db865fbb9142, job_f5e3cc3d946e, job_efececaf6144]  # job_db865fbb9142: round 1 现状盘点 + D 三层规则; job_f5e3cc3d946e: round 2 prediction_market paradigm → C 混合; job_efececaf6144: round 3 主动清理 + C 拆分（policy + cleanup spec）
upstream_reference: /mnt/f/python/web3/prediction_market/docs/
impacted_components: [apps-ccb-console-server, claude-plugin-distribution, docs-ccb-workspace]
size_exception: true
size_exception_reason: 含长期治理 paradigm + 主动清理策略 + keep list 类别 + 实施 phase 分工，分拆会丢上下文
---

# ADR-0033: Document Taxonomy + Naming/Lifecycle Policy + 主动清理策略

## Status

Accepted（2026-05-23）。Phase 5 议题 3 形式化。Codex 3 轮协商收敛 + Claude 拍板路径 A 与 Q1-Q3。

## Context

### 议题 3 用户原话（2026-05-22）

> 目前的 docs 下的各个目录下的文档的命名格式太混乱不够直观，并且文档内容过于随意和散乱。

用户原话同步指明参考项目：

> 可以去参考：`F:\python\web3\prediction_market\docs`

### 用户 2026-05-23 paradigm shift（核心）

> 这次的治理主要是针对**未来的新文档**或者说是**发布后的版本使用长久的 plugin、skills 项目管理的治理**，所以当前项目下的旧文档本质上**可以进行一次清理或者备份**，只保留**核心主路线或者发布版本后的核心总结**。

议题 3 治理的目标客户 = **v1.0 发布后 SU-CCB 作为长期 plugin/skills 项目管理工具的治理**，不是 v0.x → v1.0 发展期的过程文档 housekeeping。

### prediction_market 参考项目关键特征（codex round 2 验证）

- 104 份 md，102 份**无日期前缀**（2 例外在 `superpowers/plans/` 是执行计划）
- 5 个 `_模板_*.md` 模板文件
- `docs/00_架构设计/文档治理状态清单.md` 显式索引「当前主流程 / 子域 / 历史 / 归档」
- 单文档 + 头部版本标注 / 不创建多版本 / 大版本进 `99_归档/` / 主流程唯一真相源
- 文档头部统一：`# [模块] [文档类型] / **版本** / **状态** / **最后更新**`

### SU-CCB 现状（codex 3 轮 grep）

- 828 份 md / 日期前缀 700 / ADR 27（26 ADR + 1 consensus memo） / `v0-legacy-archive/` 686
- 长度 < 200 行 759 / 200-500 行 59 / > 500 行 9
- 资产错位：`.ccb/specs/active|archive` 均 0 / `.ccb/state/quarantine` 12

## Decision

### 3.1 长期治理范式 = C 混合

| 层 | 模式 |
|---|---|
| 知识库目录（`00-05/10+/`）| **prediction_market living-doc 模式**（每模块一份持续更新 / 不堆日期 / 主流程唯一真相源）|
| `docs/.ccb/` plugin canonical | **保留现有路径契约**（ADR-0012 path-as-semantics 不动）|

拒绝：A 维持现状（治理无效）/ B 全量迁移（破坏 plugin runtime 投影链）。

### 3.2 主动清理原则

旧文档**主动清理 / 备份**，只保留**核心主路线 + 发布版本核心总结**。不是历史冻结。

破坏面缓解：
1. **打 `pre-v1-docs-cleanup` tag + branch** 做完整 git 维度备份
2. 主分支**物理删除**过程文档（git 历史保留）
3. `docs/99_归档/pre-v1.0/README.md` 只留**索引 + 恢复路径**，**不搬** 686 份原文件占主 docs 空间

### 3.3 目录编号策略

- 改用 **`00_/01_/.../99_` 编号**（参考 prediction_market）
- 部分采用：改 `00_` 起编 + 新增 `99_归档/`
- 不照搬 `03_接口文档` / `06_项目交付`（SU-CCB 是元工具，不适用）
- 现有 `10+/` 项目特定扩展保留

### 3.4 命名规则

**知识库（00-05/10+/）= living-doc**：
- 默认 `<模块/主题>-<文档类型>.md`，**不加日期前缀**
- 例：`plugin-sovereignty-实施路线图.md` / `Console-模块规格.md`
- 中英文混用允许

**`.ccb` canonical = 现有路径契约**：

| 路径 | 状态 |
|---|---|
| `docs/.ccb/specs/{active,archive}/<task_key>.md` | 保留 |
| `docs/.ccb/state/<task>.md` | 保留（**不入 active 子目录**，ADR-0012） |
| `docs/.ccb/state/quarantine/<task>.md` | 保留 |
| `docs/.ccb/requirements/active/*.md` | 保留 |
| `docs/.ccb/decisions/ADR-NNNN-*.md` | 保留 |
| `docs/.ccb/decisions/YYYY-MM-DD-*-{consensus,memo}.md` | consensus memo 命名例外（保留）|
| `docs/.ccb/drafts/breakdown/<rid>.json` | 保留 |
| `docs/.ccb/reports/*.md` | 日期前缀允许 |
| `docs/.ccb/reconcile/YYYY-MM/*.md` | 保留 |
| `docs/.ccb/events/*.jsonl` | 保留 |

### 3.5 日期前缀窄白名单

仅以下场景允许 `YYYY-MM-DD-` 日期前缀：
- transient execution artifacts（一次性 PR 实施日志）
- consult snapshots（codex 协商快照）
- superpowers / agent plans
- 一次性报告（release / smoke test report）

### 3.6 文档治理状态清单（核心 paradigm）

新增 `docs/00_文档治理状态清单.md` 显式索引：「当前主流程 / 子域 living docs / 历史快照引用 / 归档目录指针」。每次重要文档新增 / 提升 / 归档 → 同步更新。**人维护，非生成**。

### 3.7 `_模板_` 系统

每个知识库主目录新增 `_模板_*.md`。**具体模板内容**由议题 4（ADR-0035）+ Phase 3 合并实施 spec 决定（fit ADR-0030 paradigm 「模板 = 起点，不是强约束」）。

### 3.8 文档头部统一格式（YAML + body 双轨）

YAML frontmatter（机器可解析，给 indexer / lint） + body markdown 头部（人类可读）双轨。frontmatter 字段：`id / doc_type / subject / status / version / updated / supersedes / size_exception`。

### 3.9 长度治理

| 类型 | budget |
|---|---|
| ADR | < 200 行 |
| spec | 50-150 行 |
| requirement | < 500 行 |
| 技术方案大纲 | < 300 行 |
| living doc / 经验沉淀 | 无硬上限 |

`size_exception: true` 必填 `size_exception_reason`。CI 只 warning，不 hard fail（ADR-0030 254 / ADR-0034 274 / 本 ADR 是合法超长）。

## Keep List（类别层 · 具体文件清单留 Phase 2 cleanup spec）

| 类别 | 内容 |
|---|---|
| **核心 ADR**（保留 active）| ADR-0023 / 0024 / 0025 / 0026 / 0027 / 0028 / 0029 / 0030 / 0031 / 0032 / 0033 / 0034 / 0035（共 13 份；ADR-0035 pre-impl amend 2026-05-23 补入，原 ADR-0033 起草时 ADR-0035 还未落档）|
| **临时兼容保留** | ADR-0012 task projection consistency（待 ADR-0033 + cleanup spec 接管 path-as-semantics 后归档）|
| **待归档** | ADR-0001 / 0010 / 0011 / 0014 / 0017 / 0018 / 0019（已被 ADR-0023 supersede）；ADR-0018 Addendum 2026-05-16 read-write attach 已并入 ADR-0032 |
| **新建 living docs**（v1.0 后核心总结）| `项目概览.md` / `文档治理状态清单.md` / `v1.0-plugin-sovereignty-架构总览.md` / `v1.0-release-retrospective.md` / `v1.0-lessons-learned.md` |
| **新建模块规格** | `Console-模块规格.md` / `Claude-Plugin-模块规格.md` / `Codex-Skills-模块规格.md` / `Protocol-Kernel-模块规格.md` |
| **运行入口**（按 v1.0 现状更新）| `README.md` / `docs/quickstart.md` / `docs/install.md` / `docs/requirements.md` |

## Sweep 范围（类别层）

- 700 份日期前缀过程文档（Phase 1-4 各阶段 SP / hotfix spec / batch / state / report / consult snapshots / draft）
- 686 份 `v0-legacy-archive/`
- 旧 `01-04/` 日期前缀知识快照（抽信息进新 living docs 后删除）
- `docs/.ccb/reports/` 视情况（当前 ADR / README 引用的保留）

## 实施 Phase 划分

| Phase | 范围 | 产出 |
|---|---|---|
| **Phase 1**（本 ADR）| 长期治理 paradigm + 主动清理原则 + 类别 keep list + 实施分工 | ADR-0033 落档 ✅ |
| **Phase 2**（独立 cleanup spec，Codex 主笔）| 精确 keep/sweep 清单（到文件名）+ backup tag/branch 操作 + link audit + 迁移命令 + 验证 | `SP-docs-cleanup-v1.0.md` |
| **Phase 3**（议题 3 + 议题 4 合并实施 spec，等 ADR-0035 落档后）| 具体命名规则细节 + 4 份模板内容 + 任务拆分粒度规则 + 内容切分 + 治理状态清单 创建 | `SP-docs-governance-impl.md` |
| **Phase 4**（housekeeping，独立 spec）| root `references/kernel/` legacy 清理 + ADR-0012 归档 + frontmatter 批量补全 | `SP-docs-housekeeping.md` |

## 不在本 ADR 范围

- **具体到文件名的清理清单** → Phase 2 cleanup spec
- **具体命名规则细节 / 4 份模板内容 / 任务拆分粒度** → Phase 3 合并实施 spec
- **root `references/kernel/` legacy 清理** → Phase 4 housekeeping
- 中英文 slug 强制统一 → 不强制
- 长度硬 CI → 不做
- `docs/.ccb/` canonical 路径迁移 → 永不做（ADR-0012 path-as-semantics 依赖）

## Risk & Guardrails

| 风险 | Guardrail |
|---|---|
| 误动 `.ccb/` runtime/canonical 路径 → indexer/reconcile 投影断裂 | cleanup spec 显式 `protected_paths` 列表 + lint 检查；`.ccb/**` 在 cleanup 范围外 |
| 物理删除破坏跨文档 link | cleanup spec **必须先跑 link audit**，更新 `.catalog.yaml` + `decisions.yaml` |
| backup tag/branch 丢失 | tag 推到 origin + 至少 2 个 remote / 验证 commit-ish 可 checkout |
| 模块规格新建丢细节 | Phase 3 合并实施 spec 由 Codex 主笔 + Claude 审 + 用户确认 keep list 精确版 |
| 治理清单与代码漂移 | 每次重要文档新增/提升/归档同步更新；CI 加 quick check |
| Phase 3 在议题 4 ADR-0035 未落档前推进 | Phase 3 严格依赖 ADR-0035 落档；本 ADR 后续段已声明 |
| 新文档不遵守 living-doc 规则 | CI lint check 校验新文档 doc_type / 路径 / 命名 / size_exception |

## Data Model

### doc_type registry（首批）

```
adr / consensus-memo / spec / state / requirement / breakdown-draft / report /
reconcile-diff-log / design-doc / requirement-doc / plan / roadmap /
module-spec / module-doc / retrospective / template / governance-index /
release-retrospective / lessons-learned / architecture-overview
```

### subject registry（首批）

```
ccb-plan / ccb-console / ccb-plugin / ccb-protocol-kernel /
docs-ccb-workspace / codex-skills / claude-plugin
```

新 type / subject 由后续 housekeeping spec 注册。

### lifecycle 表达

| lifecycle | 路径表达 | frontmatter 表达 |
|---|---|---|
| draft | 视 doc_type | `status: draft` |
| active | `*/active/` 或默认根 | `status: active` |
| archived | `*/archive/` 或 `99_归档/` | `status: archived` |
| quarantine | `*/quarantine/` 目录 | `status: quarantine` |
| superseded | 视情况 | `status: superseded` + `superseded_by: <ref>` |
| deprecated | 视情况 | `status: deprecated` |

路径优先 frontmatter；冲突 → indexer 以路径为准 + warning。

## Related

- **ADR-0012** task projection consistency（path-as-semantics 现有依赖，本 ADR 兼容保留，Phase 4 housekeeping 后归档）
- **ADR-0026** entity field ownership（frontmatter `doc_type` / owner 协调）
- **ADR-0027** EventJournal v1.0（路径表达 owner 现有约定）
- **ADR-0030** plugin node paradigm（模板系统不破坏 capability 动态判断）
- **ADR-0034** capability outcome policy（plugin-side active kernel 声明 / root kernel housekeeping 另起 Phase 4）
- **Phase 5 议题 4 → ADR-0035**（待启动，任务拆分粒度治理，Phase 3 实施 spec 与本 ADR 合并）

## 协商证据

`consult_evidence` 列 3 个 codex consult job_id：

- **round 1**（rep_e0081d2530a1）：现状盘点 828 份分布 + D 三层规则推荐 + 3 risks + 3 open questions
- **round 2**（rep_b4476ca9483d）：prediction_market paradigm 校准（102/104 无日期前缀 + `_模板_` + 文档治理状态清单 + 单文档持续更新）→ D 改为 **C 混合**；指出 `.ccb/state/active/<task>` 错误（事实路径 `.ccb/state/<task>.md`）
- **round 3**（rep_b820f44ea562）：用户 paradigm shift（v1.0 后长期治理）→ ADR-0033 大改 + 主动清理 + **C 拆分**（ADR-0033 paradigm + cleanup spec）+ keep list 类别 + sweep 范围

Claude 拍板：
- Q1 backup tag/branch + 主分支删除（不搬 686 份污染主 docs）
- Q2 部分采用 prediction_market 编号（`00_/.../99_` + 新增 `99_归档/`，不照搬 `03_接口文档/06_项目交付`）
- Q3 ADR-0012 短期留 active，待 Phase 2+3 实施完成后归档
- 路径 A：ADR-0033 大方向先落档 → 启动议题 4 → 合并 Phase 3 实施 spec

议题 3 不再起 round 4（paradigm + 主动清理 + 类别 keep list 已收敛，具体细节留各 Phase spec）。

## 后续

- **Phase 2 cleanup spec**（Codex 主笔，本 ADR commit 后启动）：精确 keep/sweep 清单 + backup tag 操作 + link audit + 迁移命令 + 验证
- **议题 4 ADR-0035**（本 ADR commit 后立即 submit codex round 1）：任务拆分粒度治理 + 内容切分
- **Phase 3 议题 3 + 议题 4 合并实施 spec**（等 ADR-0035 落档后启动）：具体命名规则 + 4 份模板内容 + 拆分粒度 + 内容切分 + 治理状态清单 创建
- **Phase 4 housekeeping**（独立 spec）：root kernel legacy 清理 + ADR-0012 归档 + frontmatter 批量补全

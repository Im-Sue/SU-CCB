---
doc_type: architecture
title: "SU/CCB Skills 架构设计总览"
updated: 2026-05-28
---
# SU/CCB Skills 架构设计总览

> 版本 v0.2 — 引入协商模式、SuperClaude 集成、/su: 命令前缀

## 设计目标与约束

### 目标
- 将现有 `CLAUDE.md` 与 `CODEX.md` 中的角色、流程、契约、回执与归档规则拆分为可分发、可复用、可按需加载的结构。
- 保持 CCB 核心协作语义不变，优化组织形式，降低项目初始化和后续维护成本。
- 让 Claude 侧负责决策、设计、审查，Codex 侧负责实施、验证、文档扩展的边界更清晰。
- 在需求分析与技术设计阶段，引入 Claude-Codex 多轮协商机制，提升方案质量。
- 集成 SuperClaude / Superpowers 生态，作为可选增强层。

### 约束
- 不修改 `~/.claude/CLAUDE.md` 或 `~/.codex/AGENTS.md`。
- CCB 必须作为 skill 包或 Plugin 分发，安装后即可在新项目中使用。
- 如需项目级 `CLAUDE.md` 或 `AGENTS.md`，由 `/su:init` 从模板生成。
- 现有硬规则不能丢失，包括 Async Guardrail、自动审查、高影响决策回抛、精简回执、索引驱动等。

## 命名约定

| 层面 | 前缀/标识 | 示例 | 说明 |
|------|----------|------|------|
| 用户命令 | `/su:` | `/su:init`, `/su:plan` | 用户直接调用的 Claude 侧入口 |
| 内部协议 | `CCB` | `CCB:CLAUDE-ROLE`, `CCB_TASK_COMPLETED` | 协议标识，不面向用户 |
| Codex 侧 skill | `ccb-` | `ccb-execute`, `ccb-doc` | 内部协议单元 |
| Block Marker | `CCB:` | `CCB:CLAUDE-ROLE:BEGIN/END` | 模板注入标记 |
| 模板文件 | `codex-md-template.md` | — | 生成运行时 `AGENTS.md`（兼容 Codex 运行时） |

## 架构总览

### 2 层包模型

```text
用户安装 SU/CCB
  ├─ Claude 侧：ccb-plugin（用户命令 /su:*）
  │    ├─ su-init
  │    ├─ su-plan         ← 含多轮协商机制
  │    ├─ su-dispatch
  │    ├─ su-review
  │    ├─ su-archive
  │    └─ su-resume
  │
  ├─ Claude 侧：ccb-transport skills（外部依赖）
  │    ├─ ask / pend / mounted / cping
  │    └─ 其他基础设施 skill
  │
  ├─ 增强层（可选，降级不阻塞）
  │    ├─ SuperClaude（/sc:* 命令）
  │    └─ Superpowers（Codex 侧能力增强）
  │
  └─ Codex 侧：codex skill-pack（内部 ccb-* 前缀）
       ├─ ccb-execute     ← 支持 execute / explore / consult 三模式
       └─ ccb-doc
```

### 分层职责
- `ccb-plugin`（/su:*）：承载主流程语义与用户入口。
- `ccb-transport skills`：承载 provider 通讯、挂载检查、兜底查询等基础设施能力。
- `SuperClaude / Superpowers`：可选增强层，缺失时不阻塞 CCB 核心流程。
- `codex skill-pack`：承载执行、验证、协商、回执与文档维护流程。
- 项目 `CLAUDE.md` / `AGENTS.md`：仅保留角色、硬规则、项目事实。
- `docs/.ccb/templates/`：存放项目级模板，可覆盖默认模板。

### 外部依赖说明

| 依赖 | 类型 | 缺失影响 |
|------|------|---------|
| `ccb-transport`（ask/pend/mounted/cping） | 必需 | `su-dispatch` 只能生成文本，不能异步派工 |
| SuperClaude（`~/.claude/commands/sc/`） | 可选增强 | 协商和审查阶段无深度分析增强，核心流程不受影响 |
| Superpowers（`~/.codex/superpowers/skills/`） | 可选增强 | Codex 使用自身基础能力，核心流程不受影响 |

## 三模式协作

### 模式定义

| 模式 | 标记 | 触发阶段 | Codex 行为 | 产出 |
|------|------|---------|-----------|------|
| **consult** | `mode: consult` | Step 1-2 | 只读/分析/推理，不修改代码 | 结构化意见 |
| **exploration** | `mode: explore` | Step 3-4 | 读取+轻量验证 | 现状/风险/建议切分 |
| **execution** | `mode: execute` | Step 4 | 完整实施+验证 | 代码变更+精简回执 |

### 协商模式详细

- **轮次控制**：soft_max=3, hard_max=5
- **停止条件**：
  - Codex 返回 `status=blocked`
  - 所有决策关键问题已回答
  - 连续两轮无新信息 + 建议稳定
  - 达到 hard_max_rounds
  - 剩余问题均为低影响可逆决策
- **到达上限后**：低风险 Claude 带假设冻结，高影响升级用户
- **归档策略**：默认 B（结构化摘要嵌入设计文档），重大决策 B+（加 ADR）

### 协商契约

- 请求契约：`consult-request-contract`（schema_version: consult-v1）
- 回复契约：包含 status / understanding / findings / options / recommendation / rationale / risks / assumptions / open_questions / analysis_depth_hint / hint_reason / hint_confidence
- 回复状态值：`answered` / `needs-clarification` / `blocked` / `insufficient-context`
- 详见 `codex-skills/skills/ccb-execute/references/consult-contract.md`

## SuperClaude / Superpowers 集成

### 集成策略：双层矩阵

| 矩阵 | 驱动方式 | 适用阶段 |
|------|---------|---------|
| Matrix 1: 协商轮次触发 | Codex 回复中的 `analysis_depth_hint` | Step 1-2 |
| Matrix 2: 工作流阶段触发 | CCB 步骤 + 项目能力 + 产物状态 | Step 4-6 + Resume |

### 降级策略
- SuperClaude 缺失：CCB 正常运行，/sc: 是增强层不阻塞
- Superpowers 缺失：Codex 使用自身基础能力

### Codex Superpowers 双模式边界

| Superpowers Skill | 执行模式 | 协商模式 |
|---|---|---|
| `executing-plans` | 适用 | 不适用 |
| `systematic-debugging` | 适用 | 仅故障分析咨询时适用 |
| `verification-before-completion` | 适用 | 不适用（替代为 evidence-before-conclusion） |
| `receiving-code-review` | 返工时适用 | 不适用 |
| `brainstorming` | Claude 侧 | Claude 侧 |
| `writing-plans` | Claude 侧 | Claude 侧 |

## 读取与索引规则

### Claude 侧
- 启动时优先读取：
  - `docs/.ccb/index/architecture.yaml`
  - `docs/.ccb/index/modules.yaml`
  - `docs/.ccb/index/decisions.yaml`
  - `docs/.catalog.yaml`
- 任务时按需读取：
  - `docs/.ccb/specs/active/*.md`
  - `docs/.ccb/decisions/*.md`
  - `docs/01_架构设计/`
  - `docs/02_需求设计/`
  - `docs/03_开发计划/`
- 默认不深读：
  - `docs/04_模块规格/`
  - `docs/05_经验沉淀/`
  - `docs/10+/` 详细内容

### Codex 侧
- 先读 Claude 指定文档，再按需补充。
- 通过 `.catalog.yaml` 快速定位文档分类。
- 协商模式下可读取代码和文档但不修改。

## Claude Plugin 目录结构

```text
ccb-plugin/
├── .claude-plugin/plugin.json
├── skills/
│   ├── su-init/
│   ├── su-plan/
│   ├── su-dispatch/
│   ├── su-review/
│   ├── su-archive/
│   └── su-resume/
├── templates/
│   ├── claude-md-template.md
│   ├── codex-md-template.md
│   ├── ccb-completion-hook.sh
│   └── project-scaffold.md
├── references/
│   ├── hooks-template.json
│   ├── settings-template.json
│   ├── sc-consultation-matrix.md
│   └── sc-workflow-matrix.md
└── README.md
```

## Codex skill-pack 目录结构

```text
codex-skills/
├── README.md
├── skills/
│   ├── ccb-execute/
│   │   └── references/
│   │       ├── execute-flow.md
│   │       ├── receipt-contract.md
│   │       ├── bounceback-rules.md
│   │       ├── validation-rules.md
│   │       ├── consult-contract.md          ← 新增
│   │       └── superpowers-integration.md   ← 新增
│   └── ccb-doc/
│       └── references/
├── templates/
│   └── codex-md-template.md
└── scripts/
    └── ccb-init-codex.sh
```

## `/su:init` 生成的项目文件

### 信息归属原则

| 信息类型 | 归属位置 | 说明 |
|---------|---------|------|
| 行为指令（角色、规则、路由） | `CLAUDE.md` / `AGENTS.md` | 不含可变项目事实 |
| 可变项目事实（技术栈、目录、命令） | `docs/.ccb/index/project.yaml` | 由自动扫描生成 |
| 详细架构知识 | `docs/01_架构设计/` 等 | 随项目演进维护 |

**关键规则**：`CLAUDE.md` / `AGENTS.md` 只包含"去哪里找信息"的路由指引，不包含"信息本身"。永远不生成 `[待填写]` 占位符。

### 生成目标
- 项目 `CLAUDE.md`（CCB:CLAUDE-ROLE 命名块 + 项目上下文路由指引）
- 项目 `AGENTS.md`（CCB:CODEX-ROLE 命名块 + 项目上下文路由指引）
- 项目 `.claude/settings.json`
- `docs/.ccb/` 骨架（templates/、state/、specs/、index/、decisions/）
- `docs/.ccb/index/project.yaml`（非空项目自动扫描生成）
- 可选：`docs/01_架构设计/` 到 `docs/05_经验沉淀/`

### 依赖检查
`/su:init` 执行时会检查：
- ccb-transport：Installed / Missing
- SuperClaude：Installed / Partial / Missing
- Superpowers：Installed / Partial / Missing

输出总评行：可完整运行 / 可降级运行 / 需先补依赖。

### 项目事实自动扫描

| 项目状态 | 扫描行为 | project.yaml |
|---------|---------|-------------|
| 非空项目 | best-effort 自动扫描 | 有发现则生成 |
| 空项目 | 跳过 | 延迟到首次 `/su:plan` |

自动检测信号：`package.json`、`pyproject.toml`、`go.mod`、`Cargo.toml`、`tsconfig.json`、`Dockerfile`、`.github/workflows/`、`Makefile` 等。

`project.yaml` 每个字段含 `value`/`confidence`/`source`，手动修正字段在重新扫描时受保护。

## Block Markers 策略

### 命名块格式

```md
<!-- CCB:CLAUDE-ROLE:BEGIN -->
...
<!-- CCB:CLAUDE-ROLE:END -->
```

### 使用规则
- `/su:init` 只创建或更新自己拥有的块。
- 已存在 marker 时执行幂等更新。
- 文件不存在时创建完整模板。
- 文件存在但无 marker 时追加 CCB 块，不重排用户原文。
- 若发现用户改动造成结构冲突，降级为手工合并提醒。

## 共享契约说明

### ask-contract（派工契约）
规范 Claude 向 Codex 派工时"传什么、不传什么"。

### consult-contract（协商契约，v0.2 新增）
规范 Claude 与 Codex 多轮协商的请求/回复格式。

### receipt-contract（回执契约）
规范 Codex 返回给 Claude 的最小必要信息。

## 审批门与快速模式

### 审批门
- 🔴 必审：必须等用户确认才能继续。
- 🟡 可审：展示摘要，用户可放行。
- 🟢 自动：无需用户参与。

### 快速模式
- 用户明确要求"快速模式"时，🟡 可审节点可自动放行。
- 以下情况默认不进入快速模式：数据结构变更、权限规则变更、事务链路变更、跨模块依赖新增、高风险链路改动。

## Git 工作流约定

```text
main
  └── [开发基础分支]
        └── [功能分支前缀]/<模块>-<功能>
```

## 完整用户使用流程

### 阶段 0：环境准备（一次性）

```text
用户环境
├── Claude Code（已安装）
├── Codex CLI（已安装）
├── ccb-plugin（安装到 ~/.claude/plugins/ 或项目 .claude/）
├── codex-skills（安装到 ~/.codex/ 或项目级）
├── ccb-transport（ask/pend/mounted/cping，已安装）
├── SuperClaude（可选，~/.claude/commands/sc/）
└── Superpowers（可选，~/.codex/superpowers/）
```

### 阶段 1：项目初始化（/su:init）

```text
用户 ──→ /su:init
         │
         ├─ 1. 依赖检查
         │    ├─ ccb-transport: ✅ Installed
         │    ├─ SuperClaude:   ✅ Installed / ⚠️ Partial / ❌ Missing
         │    └─ Superpowers:   ✅ Installed / ⚠️ Partial / ❌ Missing
         │    → 总评: 可完整运行 / 可降级运行 / 需先补依赖
         │
         ├─ 2. 生成项目文件
         │    ├─ CLAUDE.md       ← 角色+规则+路由指引（不含可变事实）
         │    ├─ AGENTS.md       ← 角色+规则+路由指引（Codex 运行时文件）
         │    └─ .claude/settings.json  ← hooks 配置
         │
         ├─ 3. 创建协作目录
         │    └─ docs/.ccb/
         │         ├─ templates/   ← ask/回执/协商/归档模板
         │         ├─ state/       ← 任务状态文件
         │         ├─ specs/active/ & archive/
         │         ├─ index/       ← 架构/模块/决策/项目事实索引
         │         └─ decisions/   ← ADR
         │
         ├─ 4. 自动扫描（非空项目）
         │    ├─ 扫描 package.json / pyproject.toml / go.mod 等
         │    ├─ 检测技术栈、关键目录、验证命令
         │    └─ 有发现 → 写入 docs/.ccb/index/project.yaml
         │       无发现或空项目 → 跳过，延迟到首次 /su:plan
         │
         └─ 5. 输出提示
              "项目已初始化，检测到 Python/FastAPI 技术栈。"
              "使用 /su:plan 开始你的第一个任务。"
```

**无需用户手动填写**：项目事实由自动扫描生成，CLAUDE.md/AGENTS.md 只包含角色规则和路由指引。

### 阶段 2：需求提出 → 规划（/su:plan）

```text
用户: "我需要给这个项目加一个用户钱包提现功能"
         │
         ▼
Claude 执行 /su:plan
         │
     ┌───┴───────────────────────────────────────────┐
     │  Step 1: 需求分析                               │
     │                                                 │
     │  1. Claude 读取索引（architecture.yaml 等）       │
     │  2. Claude 判断复杂度: 简单/中等/复杂              │
     │  3. ────── 自动发起协商 ──────                    │
     │     │                                           │
     │     │  Claude → Codex (mode: consult)            │
     │     │  "分析当前代码中钱包相关模块的现状，          │
     │     │   评估提现功能的可行性和影响范围"              │
     │     │                                           │
     │     │  Codex 回复:                               │
     │     │  - findings: 现有钱包模块结构...             │
     │     │  - options: 方案A/B/C...                   │
     │     │  - analysis_depth_hint: sc-design           │
     │     │  - hint_confidence: medium                  │
     │     │                                           │
     │     │  Claude 自动触发 /sc:design（如已安装 SC）    │
     │     │  Claude 判断是否需要更多轮协商                │
     │     │  （收敛？→ 停止。未收敛？→ 继续 round 2）     │
     │     └───────────────────────────────            │
     │  4. Claude 输出需求理解 + 协商结论摘要              │
     │                                                 │
     │  🔴 等待用户确认需求                               │
     └─────────────────────────────────────────────────┘
         │
         ▼ 用户确认
     ┌───┴───────────────────────────────────────────┐
     │  Step 2: 技术设计                               │
     │                                                 │
     │  1. Claude 通过索引定位架构和模块信息               │
     │  2. ────── 自动发起协商 ──────                    │
     │     │                                           │
     │     │  Claude → Codex (mode: consult)            │
     │     │  "针对提现功能，评估方案A和方案B的             │
     │     │   实现可行性、隐藏耦合、迁移成本"              │
     │     │                                           │
     │     │  Codex 回复:                               │
     │     │  - findings: 方案A需要改动3个模块...         │
     │     │  - recommendation: 方案B                   │
     │     │  - analysis_depth_hint: sc-spec-panel       │
     │     │  - hint_confidence: high                    │
     │     │                                           │
     │     │  Claude 自动触发 /sc:spec-panel             │
     │     │  多轮协商直到收敛（soft_max=3）               │
     │     └───────────────────────────────            │
     │  3. Claude 输出技术方案摘要 + 协商结论              │
     │     重大决策写入 ADR                               │
     │                                                 │
     │  🔴 等待用户确认设计                               │
     └─────────────────────────────────────────────────┘
         │
         ▼ 用户确认
     ┌───┴───────────────────────────────────────────┐
     │  Step 3: 任务切片                               │
     │                                                 │
     │  1. 判断模式: 实施 / 半开放实施 / 勘探              │
     │  2. 拆成可验收切片                                │
     │  3. 写精简 spec（20-50行）                        │
     │     → docs/.ccb/specs/active/wallet-withdraw.md  │
     │  4. 创建状态文件                                  │
     │     → docs/.ccb/state/wallet-withdraw.md          │
     │                                                 │
     │  🟡 展示给用户审阅（可放行）                        │
     └─────────────────────────────────────────────────┘
```

### 阶段 3：派工（/su:dispatch）

```text
Claude 执行 /su:dispatch
         │
         ├─ 1. 检查 Codex 是否挂载（mounted）
         ├─ 2. 按 ask-contract 组织派工内容
         │     ┌──────────────────────────────┐
         │     │ ## 任务: wallet - 提现功能     │
         │     │ ### 先读文档                    │
         │     │ - docs/.ccb/specs/active/...    │
         │     │ ### 任务标记                    │
         │     │ - 模式: 半开放实施              │
         │     │ - 风险: 中                      │
         │     │ ### 本轮只做                    │
         │     │ - ...                          │
         │     │ ### 验收标准                    │
         │     │ - ...                          │
         │     └──────────────────────────────┘
         ├─ 3. ask codex --foreground
         ├─ 4. 收到 [CCB_ASYNC_SUBMITTED]
         └─ 5. 回复 "Codex processing..." → 结束 turn
```

### 阶段 4：Codex 执行（ccb-execute）

```text
Codex 收到任务
         │
         ├─ 1. 读 spec → 读相关文档 → 看现有代码
         ├─ 2. mode: execute（半开放实施）
         │     ├─ 做最小充分改动
         │     ├─ 允许局部重构
         │     └─ 遇到高影响决策 → 回抛
         ├─ 3. 验证（单元测试、集成测试、手动验证）
         ├─ 4. 输出精简回执（<2k）
         │     ┌──────────────────────────────┐
         │     │ ## 完成报告                    │
         │     │ ✅ 已完成: 提现接口 + 余额扣减  │
         │     │ ### 验证结果                    │
         │     │ ✅ 单元测试 12/12 通过          │
         │     │ ### 风险点                      │
         │     │ 1. 并发提现需要分布式锁          │
         │     │ ### 建议文档更新                 │
         │     │ - docs/10_接口文档/withdraw.md  │
         │     └──────────────────────────────┘
         └─ 5. 完成 → completion hook 推送 [CCB_TASK_COMPLETED]
```

### 阶段 5：审查（/su:review，自动触发）

```text
Claude 收到 [CCB_TASK_COMPLETED]
         │
         ▼ 自动进入审查（不等用户触发）
Claude 执行 /su:review
         │
         ├─ 1. 读 Codex 精简回执
         ├─ 2. /sc:build（如有构建路径）
         ├─ 3. /sc:test（如有测试套件）
         ├─ 4. 符合性检查: 是否符合技术设计？
         ├─ 5. 边界检查: 是否越过任务范围？
         ├─ 6. 决策检查: 是否有未授权的设计决策？
         ├─ 7. 深度思考: 边界情况、潜在风险
         │
         └─ 结论:
              ├─ ✅ 通过 → 进入归档
              ├─ ⚠️ 局部缺陷 → 生成差分修复任务 → 回到 /su:dispatch
              └─ ❌ 设计冲突 → 停止实施 → 回到 /su:plan Step 2
```

### 阶段 6：归档（/su:archive）

```text
Claude 执行 /su:archive
         │
         ├─ 1. 决策: 是否需要补文档？
         │     → 需要: 生成精简指令交给 Codex（ccb-doc）
         │     → 不需要: 跳过
         ├─ 2. 更新 docs/.ccb/state/wallet-withdraw.md → status: done
         ├─ 3. 移动 spec → docs/.ccb/specs/archive/2026-04/
         ├─ 4. /sc:git（如需 Git 收尾）
         ├─ 5. 可选复盘记录
         │
         └─ 输出: "任务已归档，进入最终验收。"
              🔴 等待用户最终验收
```

### 阶段 7：恢复（/su:resume，下次会话）

```text
新会话开始
         │
用户: /su:resume
         │
Claude:
  ├─ 扫描 docs/.ccb/state/ 下非 done 的文件
  ├─ 找到: wallet-withdraw.md (status: in_progress, step: 4)
  ├─ 读取 spec + 检查 git 分支
  └─ "检测到进行中任务: 钱包提现功能, Step 4, 分支 feat/wallet-withdraw"
     "继续还是重新开始？"
```

### 指令使用速查

| 阶段 | 用户操作 | 指令 | Claude 自动行为 |
|------|---------|------|----------------|
| 初始化 | 首次启用 | `/su:init` | 依赖检查 + 生成项目文件 |
| 规划 | 提出需求 | `/su:plan` | 需求分析 → 协商 → 设计 → 协商 → 切片 |
| 派工 | 审阅后放行 | `/su:dispatch` | 检查挂载 → 生成 ask → 异步提交 |
| 执行 | 等待 | — | Codex 自动执行 + hook 回调 |
| 审查 | — | `/su:review` | **自动触发**，读回执 + 构建/测试 + 审查 |
| 归档 | 最终验收 | `/su:archive` | 文档决策 + 状态归档 + spec 归档 |
| 恢复 | 新会话 | `/su:resume` | 扫描状态 + 恢复上下文 |

### 用户必须参与的节点

| 标记 | 节点 | 用户动作 |
|------|------|---------|
| 🔴 | Step 1 后 | 确认需求理解 |
| 🔴 | Step 2 后 | 确认技术设计 |
| 🟡 | Step 3 后 | 审阅切片（可直接放行） |
| 🔴 | 归档后 | 最终验收 |

### 协商自动触发机制

用户**不需要手动触发协商**。在 `/su:plan` 执行过程中，Claude 自动判断是否需要与 Codex 协商：

```text
/su:plan 内部自动流程:

Step 1 需求分析
  → Claude 判断: 需要了解代码现状？
    → 是 → 自动 ask codex (mode: consult) → 收集意见 → 收敛后继续
    → 否 → 直接分析

Step 2 技术设计
  → Claude 判断: 需要验证方案可行性？
    → 是 → 自动 ask codex (mode: consult) → 多轮讨论 → 收敛后继续
    → 否 → 直接设计

协商过程中:
  → Codex 回复含 analysis_depth_hint？
    → 是 → Claude 自动触发对应 /sc:* 命令
    → 否 → 继续下一轮或结束协商
```

整个过程对用户透明，用户只需要在 🔴 必审门确认即可。

## 任务看板 Phase 状态机

CCB Console 的「任务看板」是 `/su:*` 工作流在 UI 层的投影。每一列对应一个 phase，由 `docs/.ccb/state/<task>.md` 的 `status` / `phase` / `step` 字段反推得出。本节定义 7 个 phase 的语义边界、进入与退出条件、以及与 `/su:*` 阶段的映射关系，作为 Console 与 Skill 双侧实现的契约。

### Phase ↔ /su:* 阶段映射表

| Phase 列 | 中文 | 对应 /su:* 阶段 | state 文件信号 | 主要文档 |
|---------|------|----------------|---------------|---------|
| `requirement` | 需求中 | `/su:plan` Step 1（需求分析） | `phase: requirement` 或仅有 spec 草稿，尚未生成 plan | spec（草稿） |
| `planning` | 规划中 | `/su:plan` Step 2-3（技术设计 + 切片） | `phase: planning`，或已有 plan/spec 但未 dispatch | spec + plan |
| `ready` | 待执行 | `/su:dispatch` 已生成 ask，等待 Codex 拉起 | `phase: ready`，或 `status: ready`、ask 已挂载 | spec + plan + task |
| `implementing` | 执行中 | `ccb-execute` 正在跑（Codex 侧） | `phase: implementing` 或 `status: in_progress`，含 `step` 字段 | spec + plan + task + state |
| `reviewing` | 评审中 | `/su:review` 已触发，等待用户验收 | `phase: reviewing`，或 receipt 已写回但 status 未变 done | + receipt |
| `blocked` | 阻塞中 | 任意阶段命中阻塞条件 | `status: blocked` / `phase: blocked`，配合 `blocked_reason` | 任意 |
| `done` | 已完成 | `/su:archive` 完成最终验收 | `status: done` / `completed` / `archived`，state 文件停止更新 | 全部归档 |

> 看板**不显示** `archived`：归档后的任务建议进入「归档视图」（独立 tab 或筛选），避免污染主看板。当前实现把 `archived` 折叠进 `done`，需要补一个归档视图入口（见下文偏差 3）。

### 进入 / 退出条件

| Phase | 进入条件 | 退出条件 | 触发指令 |
|-------|---------|---------|---------|
| `requirement` | 用户提出需求，`/su:plan` 启动 | 🔴 Step 1 必审门通过 | `/su:plan` |
| `planning` | Step 1 通过，进入技术设计 | 🟡 Step 3 切片审阅通过（可直接放行） | `/su:plan` Step 2-3 |
| `ready` | `/su:dispatch` 生成 ask 并挂载 | Codex 拉起任务，state 写入 `in_progress` | `/su:dispatch` |
| `implementing` | Codex 开始执行（首次写入 step） | Codex 写回 receipt，state 进入 reviewing | `ccb-execute`（Codex 侧） |
| `reviewing` | receipt 落盘，`/su:review` 自动触发 | 🔴 用户验收通过，进入 archive | `/su:review` |
| `blocked` | 任意阶段写入 `blocked_reason` | reason 解除，state 回写原 phase | 手动或 `ccb-execute` |
| `done` | `/su:archive` 写入 `status: done` 并归档 | — （终态） | `/su:archive` |

### 状态转移图

```text
        ┌────────── /su:plan Step 1 ─────────┐
        ▼                                     │
  ┌───────────┐  Step 1 🔴   ┌──────────┐    │
  │requirement│ ───────────► │ planning │    │
  └───────────┘              └────┬─────┘    │
                                  │ Step 3 🟡 │
                                  ▼           │
                            ┌──────────┐     │
                            │  ready   │     │
                            └────┬─────┘     │
                                 │ Codex 拉起 │
                                 ▼            │
                          ┌──────────────┐   │
                          │implementing  │   │
                          └────┬─────────┘   │
                               │ receipt 落盘 │
                               ▼              │
                          ┌──────────┐        │
                          │reviewing │        │
                          └────┬─────┘        │
                               │ 用户验收 🔴  │
                               ▼              │
                          ┌──────────┐        │
                          │   done   │        │
                          └──────────┘        │
                                              │
        ┌─────────────── 任意阶段 ◄──────────┘
        ▼     blocked_reason
  ┌──────────┐
  │ blocked  │ ─── reason 解除 ──► 回写原 phase
  └──────────┘
```

### Phase 推断优先级

`server/src/indexer/project-indexer.ts` 的 `normalizeTaskPhase` 按以下优先级判定：

1. **state 文件 `frontmatter.phase` 显式声明**（最高优先级）
2. **基于 `status` 派生**：
   - `done` / `completed` / `complete` / `archived` → `done`
   - `blocked` / `paused` → `blocked`
3. **基于文档存在性兜底**（仅在 1、2 都缺失时）：
   - 有 task 文档 → `implementing`
   - 仅有 plan 文档 → `planning`
   - 仅有 spec 文档 → `requirement`
   - 都没有 → `planning`

> **关键约束**：state 文件是任务真实状态的唯一来源（spec/plan/task 归档后 frontmatter 通常停留在创建时的 `ready/draft`，不能反映任务结束状态）。所有 phase 推断都以 state 文件为准，缺失 state 时才回落到文档存在性。

### 已知实现偏差（待修复）

| # | 偏差 | 现状 | 修复方向 |
|---|------|------|---------|
| 1 | `ready` / `reviewing` 无兜底推断 | 必须在 state 文件显式写 `phase: ready` 或 `phase: reviewing`，否则任务停留在 `planning` / `implementing` | 约束 `/su:dispatch` 和 `/su:review` skill 必须显式写入对应 phase；Console 不做隐式推断（避免误判） |
| 2 | `blocked_reason` 未在 UI 暴露 | 任务进入 `blocked` 列后，看不到为什么被阻塞 | 看板卡片增加 reason tooltip + 阻塞列加 callout banner |
| 3 | 归档任务无独立视图 | `archived` 与 `done` 合并显示在「已完成」列 | Console 概览页增加「已归档」筛选 / tab，看板默认隐藏 archived |
| 4 | Console 无 phase 转移触发能力 | 当前是只读镜像，无法从 UI 触发 🔴 / 🟡 必审门 | 短期保持只读（避免与 skill 双写冲突）；长期通过命令行集成层暴露「确认 Step 1/2/3」「触发归档」按钮 |

## Skill 职责速查表

| 侧别 | Skill | 命令 | 职责 |
|------|------|------|------|
| Claude | `su-init` | `/su:init` | 初始化项目骨架、依赖检查、插入角色块、创建模板和设置 |
| Claude | `su-plan` | `/su:plan` | 需求分析、多轮协商、技术设计、任务切片、生成 spec |
| Claude | `su-dispatch` | `/su:dispatch` | provider 检查、生成 ask、触发异步派工 |
| Claude | `su-review` | `/su:review` | 自动或手动审查，核对设计、边界、验证与风险 |
| Claude | `su-archive` | `/su:archive` | 文档交付决策、状态归档、spec 归档、复盘记录 |
| Claude | `su-resume` | `/su:resume` | 从 `.ccb/state/` 恢复上下文与当前步骤 |
| Codex | `ccb-execute` | — | 读取任务上下文，协商/实施/勘探，验证并回执 |
| Codex | `ccb-doc` | — | 文档分类判定、详细文档编写、索引维护 |

## 拆分映射说明

### 从 `CLAUDE.md` 拆出
- 角色与硬规则 → `templates/claude-md-template.md`
- Step 1-3 + 协商机制 → `skills/su-plan/`
- `/ask` 模板与派工原则 → `skills/su-dispatch/references/ask-contract.md`
- Step 5 审查 → `skills/su-review/`
- Step 6 归档 → `skills/su-archive/`
- 状态恢复 → `skills/su-resume/`

### 从 `CODEX.md` 拆出
- 角色与硬规则 → `templates/codex-md-template.md`
- 实施与回抛规则 → `skills/ccb-execute/`
- 协商契约 → `skills/ccb-execute/references/consult-contract.md`
- 精简回执契约 → `skills/ccb-execute/references/receipt-contract.md`
- 文档维护流程 → `skills/ccb-doc/`

## 发布与安装

### 仓库组织

```text
GitHub Organization: SU-CCB
│
├── su-ccb-plugin/              ← Claude Code Plugin（自身即 marketplace）
│   ├── .claude-plugin/
│   │   ├── plugin.json         ← 插件清单（官方 schema）
│   │   └── marketplace.json    ← marketplace 列表
│   ├── skills/                 ← 6 个 /su:* 命令
│   ├── templates/              ← 项目初始化模板
│   ├── references/             ← 共享参考材料
│   └── README.md
│
└── su-ccb-codex-skills/        ← Codex Skill Pack
    ├── skills/
    │   ├── ccb-execute/        ← 执行/协商/勘探
    │   └── ccb-doc/            ← 文档维护
    ├── templates/
    └── README.md
```

### 发布步骤

#### Claude 侧（Plugin）

```text
路径 A：自建 Marketplace（推荐先走这条）
  1. 创建 GitHub 仓库 SU-CCB/su-ccb-plugin
  2. 推送代码（含 .claude-plugin/plugin.json + marketplace.json）
  3. 完成。仓库本身就是 marketplace。

路径 B：提交到 Anthropic 官方目录（可选，更大曝光）
  1. 先走完路径 A
  2. 通过 claude.ai/settings/plugins/submit 提交审核
  3. 通过后出现在 /plugin > Discover 页面
```

#### Codex 侧（Skills）

```text
  1. 创建 GitHub 仓库 SU-CCB/su-ccb-codex-skills
  2. 推送代码（含 skills/ccb-execute/SKILL.md 等）
  3. 完成。用户通过 $skill-installer 或手动 clone 安装。
```

### 用户安装流程

```text
# Claude 侧（一条命令添加 marketplace，一条命令安装）
/plugin marketplace add SU-CCB/su-ccb-plugin
/plugin install su-ccb@SU-CCB

# Codex 侧（通过 skill-installer）
$skill-installer install https://github.com/SU-CCB/su-ccb-codex-skills/tree/main/skills/ccb-execute
$skill-installer install https://github.com/SU-CCB/su-ccb-codex-skills/tree/main/skills/ccb-doc

# 或手动安装
git clone https://github.com/SU-CCB/su-ccb-codex-skills.git
cp -r su-ccb-codex-skills/skills/* ~/.codex/skills/

# 项目初始化
/su:init
```

### 开发测试（发布前本地验证）

```bash
# Claude 侧：直接加载本地 plugin 目录
claude --plugin-dir ./tmp/ccb-plugin

# 验证 plugin 结构
/plugin validate .

# Codex 侧：复制到 skills 目录
cp -r ./tmp/codex-skills/skills/* ~/.codex/skills/
# 重启 Codex 生效
```

### 版本对齐策略

两个仓库版本独立发布，但通过 README 声明兼容性：
- `su-ccb-plugin v0.2.x` 兼容 `su-ccb-codex-skills v0.2.x`
- 主版本号对齐，次版本号独立迭代

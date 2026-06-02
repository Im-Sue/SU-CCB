---
doc_type: technical_design
requirement_id: req-restructure-713c13
title: 项目目录结构重构（multi-repo 四仓）技术设计
status: delivered
created: 2026-06-02T11:14:57.120Z
---

# 项目目录结构重构（multi-repo 四仓）技术设计

> 关联需求：`docs/02_需求设计/项目目录结构重构-multirepo四仓-713c13-需求.md`
> 协商：与 slot4_codex 完成 1 轮 technical_design 协商达成共识（job_874fbd116154）。

## 一、设计概述

把当前 monorepo（根仓库 + 两 submodule，console 在 `apps/ccb-console/`）重构为 **4 个各自独立 fresh-init 的 git 仓库**，平级共存：

- 根仓库 `Im-Sue/SU-CCB`：`docs/` + `.ccb/` + 框架文件；`.gitignore` 排除三子目录
- `su-oriel/`（`Im-Sue/SU-Oriel`）：原 console 更名 SU-Oriel，**自洽**
- `su-ccb-claude-plugin/`（`Im-Sue/su-ccb-claude-plugin`）：kernel 真相源，独立可测
- `su-ccb-codex-skills/`（`Im-Sue/su-ccb-codex-skills`）：独立可测

核心目标：**每仓独立 clone/build/test/push，无 sibling 依赖；运行时对"被观测项目"的耦合参数化而非硬编码。**

### 1.1 三个消费角色（驱动 bundled fallback 必要性）

拆分后系统有三类消费者，设计必须同时成立：

| 角色 | 获取方式 | 是否需 clone plugin/codex | 契约来源 |
|---|---|---|---|
| **R1 整套开发者** | 4 仓平级 clone，开发 Oriel+plugin+skills | 是（平级目录） | 项目本地 / 显式 `CCB_DOCS_STRUCTURE_CONTRACT` 指向 sibling plugin |
| **R2 仅用 plugin/skills** | `/plugin marketplace add` + skill-installer 装进 CLI；**不受本重构影响** | 否 | 不涉及 console |
| **R3 用 SU-Oriel 的用户** | 跑 Oriel 控制台；plugin/skills **装进各自 CLI**，**不 clone** | **否** | **`<projectRoot>/docs/.ccb/docs-structure-contract.yaml`（plugin 在该项目 su-init/su-flow 时写入）或 su-oriel 内置 fallback** |

**关键约束（R3 推导）**：Oriel 运行时**绝不能要求平级 plugin 目录在场**。因此 `DEFAULT_CONTRACT_PATH` 必须从现状的"猜 sibling plugin"改为"**su-oriel 内置 fallback**"。这是 T4a 的核心理由。
**待验证假设**：plugin 在用户项目首次运行（su-init）时是否已写入 `docs/.ccb/docs-structure-contract.yaml`；若否，R3 长期依赖 bundled fallback，存在与 plugin 契约漂移风险——在 T5/T7 一并确认。

## 二、方案与架构

### 2.1 三 root 分层（本设计基石，采纳 Codex 方案）

最初我提"两 root"，Codex 指出不够——必须把"协议来源"也显式化，否则源码位置和协议来源会再次混淆。最终采用**三 root**：

| root | 含义 | 来源 | 用于 |
|---|---|---|---|
| **sourceRoot** | su-oriel 源码根 | 模块自身位置 | 自身资源、Prisma DB、dist |
| **projectRoot** | 被观测 CCB 项目根 | DB `project.localPath` → `CCB_PROJECT_ROOT` → 向上发现 `.ccb/ccb.config` | docs/.ccb/journal/drafts/index 等业务读写 |
| **contractRoot/pluginRoot** | 协议/契约来源 | **仅显式配置**（env / 集成检查参数） | docs-structure-contract、跨仓 lint；**不参与普通 build/runtime 默认猜测** |

**第一原则**：su-oriel 必须"**无 sibling repo 即可 build/test/start**"。普通 CI 不依赖 plugin/codex/root。

### 2.2 contract 解析顺序（统一 dev 与 downstream 两种布局）

`docs-structure-resolver` 已有 `CCB_DOCS_STRUCTURE_CONTRACT` 优先级，复用之，**不再猜 sibling plugin**：

1. 显式 `CCB_DOCS_STRUCTURE_CONTRACT`
2. `<projectRoot>/docs/.ccb/docs-structure-contract.yaml`
3. **su-oriel 内置 fallback contract**（新增，保证脱离任何 sibling 仍可启动）
4. sibling plugin 仅允许在 `check:integration` / `check:generated --plugin-root` 使用

这样 downstream（plugin 作为分发安装、无平级目录）与本 dev 仓（plugin 是平级目录）统一：都走 project-local 优先 + bundled fallback；dev 想对齐 plugin 时显式设 `CCB_DOCS_STRUCTURE_CONTRACT=../su-ccb-claude-plugin/references/docs-structure-contract.yaml`。

### 2.3 generator / schema 归属

- schema 真相源 + generator **归 plugin**。
- plugin 生成 plugin 自己的产物；**generator 默认不写 console 路径**（否则 plugin 认识 su-oriel，违反拆仓）——改参数化输出 / 临时 diff。
- su-oriel **提交自身 `server/src/generated/*` TS**；普通 build 只校验已提交产物可用，**不在 build 前置跨仓再生成**。
- 跨仓 drift check 是 **O3 / integration gate**，不是每次 build 前置。
- 否决的替代：独立 npm 包（当前过重，schema 仍在快速变）；git subtree / vendor schema（制造第二真相源）。

### 2.4 pnpm 自洽 + 品牌收敛

- su-oriel 内置 `pnpm-workspace.yaml`，packages 为 `server`/`web`；根去 pnpm；重生 lock。
- **包名一并改** `ccb-console-web/server` → `su-oriel-web/server`，否则 filter、日志、localStorage key 残留旧品牌。
- husky / lint-staged 迁入 su-oriel（根不再钩 console）。

## 三、关键决策与取舍（命中必问项）

| 决策 | 取舍 | 是否需用户拍板 |
|---|---|---|
| 三 root 分层 | 复杂度↑，但杜绝"默认回落读自己"静默 bug | 否（架构自决） |
| generator 归 plugin + 各仓提交产物 | 放弃实时再生成的强一致，换独立性；drift 用 integration gate 兜 | 否（与 Codex 共识） |
| 包名改 su-oriel-* | 一次性破坏旧 localStorage/filter，但品牌干净 | **是**（影响命名，已默认采纳，待确认） |
| **.ccb 跟踪粒度** | 跟踪 `ccb.config`+`journal.jsonl`+`drafts/`+contract；排除 `index/*`（派生缓存）、`locks/`、runtime/job 快照 | **是**（影响版本控制内容与审计） |
| 跨仓 integration check 位置 | 本地 O3 脚本（不进任何仓必跑 CI） | 否（默认本地脚本，待确认） |

## 四、核心流程 / 逻辑（O3 执行顺序）

1. **冻结运行态**：停 CCB 队列（`ccb.config` agent target 全 `"."`，重构中旧 job 快照/路径失效）。
2. **备份**：四仓 refs / 工作树打 tag 或拷贝。
3. **解绑**：删 `.gitmodules`、gitlink、`.tmp/*` 垃圾 git 仓。
4. **本地重排 + 路径修复**：`apps/ccb-console/` → `su-oriel/`；迁构建工具；三 root 改造；删根 kernel + sync；CI 拆分；包名改。
5. **全量验证（脱 sibling）**：四仓各自 fresh clone 到临时父目录、不复用旧 node_modules，跑各自 gate（见五）。
6. **集成验证**：四仓相邻布局跑一次 umbrella check。
7. **推送**：先 plugin/codex/su-oriel，最后根仓库；全部推 Im-Sue 新仓。

## 五、测试策略（O3 验证 gate）

- **root**：仅含 docs/.ccb/框架；三子目录确为 ignored；`.ccb/ccb.config` tracked；无 `references/kernel` 残留命令。
- **su-oriel**：`pnpm install --frozen-lockfile`；server/web build/test；server 全量 test；启动 server 指向父 root 后 scan 一个 fixture 项目。
- **plugin**：kernel lint（`.node.md`）；plugin tests；generated drift check 无 diff。
- **codex-skills**：node tests；resolver 在"项目有 references/kernel"与"仅 .ccb/config + 显式 contract"两布局都过。
- **integration**：fresh 四仓相邻布局跑 su-oriel scan root、role-profile 校验、consult allowed-agent、docs resolver、schema ownership 集成。

## 八、文件结构 / 变更清单（全量耦合，须逐条修）

**A 构建工具迁入 su-oriel**：`scripts/generate-schema-validators.mjs`、`generate-capability-outcome-policy.mjs`、`references/schema-ownership-matrix.yaml`；server/package.json:8、scripts/lint-schema-ownership.ts:16/18；根 package.json 脚本。

**B 运行时 project-root 参数化**：`consult-requests.service.ts:24-25`、`role-profile.service.ts:12-14`、`docs-structure-resolver.ts:6/9-13`（默认 contract）、`requirement-edit.service.ts`（改用 project resolver）、`ai-cli.cwd.ts`（默认 cwd 回落会变 su-oriel）。

**C 硬编码 monorepo 路径**：`role-profile.ts:14`、`dev-server.sh:10` prisma dev.db、dev 脚本 pnpm filter、lint-staged glob、包名。

**D 反向耦合切断**：plugin `policy.test.mjs:17`（读根 generator）、plugin `lib/*/generated-*.mjs` 头注释、codex `resolve-same-group-peer.mjs:240/312`（agent-routing-contract 不默认要求 root kernel，改显式 contract 或仅校验 `.ccb/ccb.config [windows]`）。

**E kernel 清理**：删根 `references/kernel/` + `scripts/sync-kernel-to-plugin.sh`；`.github/workflows/manifest-strict.yml`（`.node.yaml`→`.node.md`）迁 plugin；PR 模板 `lint_all.py`；README/CONTRIBUTING/CLAUDE/AGENTS/docs 残留。

**F 测试/脚本硬读根**（Codex 补漏）：`executor-profile.schema.spec.ts:12`（`../../../docs/.ccb/schemas`）、`transition-proposal-routes.spec.ts`（读 plugin transition table / su-review skill）、`validate-prompt-template.cjs` 默认 prompt root、`dual-run-smoke.cjs` report/schema/artifact 路径、kernel tools `lint_*.py` 的 `parents[3]`（随 plugin 走，须验证 standalone 仍解析）。

**G .ccb / git 边界**：删 `.gitmodules`/gitlink；根 `.gitignore` **精确 unignore `.ccb/ccb.config`**（不整目录提交）；`docs/.ccb/index/*` 跟踪与否单独定。

## 十、迁移影响与风险

- **R1（最高）默认路径回落**：拆分后某处默认 cwd/repoRoot 回落到 su-oriel 自己，"看起来能启动但读的是自己"。→ 三 root + 启动期对 projectRoot 显式断言 + integration scan fixture 验证。
- **R2 generator 变隐形 monorepo**：generator 默认写 console → 重新耦合。→ generator 默认只写 plugin，console 走提交产物 + drift gate。
- **R3 .ccb 误提交/漏提交**：runtime/job 快照混入，或 `ccb.config` 漏跟踪。→ 精确 gitignore 规则 + tracked 清单校验。
- **R4 pnpm-lock**：importer 改名致 `--frozen-lockfile` 失败。→ 重生并验证 node-pty / prisma。
- **不可逆**：fresh-init 丢历史（已接受）；推 Im-Sue 新仓（新仓，无覆盖旧公开历史风险）。

## 留待 task_breakdown 的事项

按 A–G 七类拆成可独立验证的子任务，配 O3 gate 作为每类验收。generator 归属（D2）与三 root 改造（B）为高风险核心任务，优先并单独验证。

## 协商与反思摘要（节点合规）

**Codex 协商**：1 轮达成共识。Codex 关键贡献：① 两 root→**三 root**（显式 contractRoot）；② contract 解析顺序复用既有 env + 加 bundled fallback；③ generator 默认不得写 console；④ 包名改 su-oriel-*；⑤ 补 6+ 漏点；⑥ 详尽 O3 per-repo gate。

**4 锚点反思**：
- 同意：三 root 比我的两 root 更严谨；generator 默认写 console 确实会变隐形 monorepo；包名残留是真品牌债。
- 不同意/修正：无实质分歧；我的 D2 被 Codex 收紧（默认不写 console）后更稳。
- 盲点：我漏了"默认路径回落静默读自己"这个最高风险，只盯了显式硬编码；也漏了 spec/smoke 层的根 docs 读取。
- 下一步：进入 task_breakdown，按 A–G 拆子任务 + O3 gate。

**必问项**：命中"命名"（包名 su-oriel-*）、"项目状态/版本控制范围"（.ccb 跟踪粒度）——升级用户确认；无新依赖、无 schema 变更、无 DB migration。

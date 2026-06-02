---
id: req-restructure-713c13
title: 项目目录结构重构：multi-repo 四仓拆分（含 console 更名 SU-Oriel）
doc_type: requirement
status: planning
created: 2026-06-02T11:03:14.422Z
analysis_input_hash: 713c136e4ed12d5f1f64f7e620a7cf7c79384b8fcfe7f63cdc98a6c85ed51e89
analysis_applied_at: 2026-06-02T11:03:14.422Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。
> 本需求为基础设施/仓库重构类，分析由 Claude 直接撰写（未走 console 投影 lib 管线，因 console 本身是重构对象）。

## 需求描述

将当前 monorepo（根仓库 `SU-CCB/CCB` + 两个 submodule）重构为 **4 个各自独立的 git 仓库，平级共存于同一父目录**：

1. **根仓库** —— 管 `docs/` + `.ccb/` + 项目级框架文件，`.gitignore` 排除下面三个子目录
2. **`su-oriel/`** —— 原 console（前后端），更名 **SU-Oriel**，成为自洽的 console 根
3. **`su-ccb-claude-plugin/`** —— 保留原名
4. **`su-ccb-codex-skills/`** —— 保留原名

所有仓库 **fresh-init 不保留历史，全部建新仓**；旧公开仓（plugin/codex-skills 现有 GitHub 仓）废弃，**旧用户由用户本人通知**，不在本需求范围内做兼容。

## 原话（verbatim）

> 我打算整理一下当前项目的目录结构： 1. 先清理掉当前项目的所有git绑定，下面的子仓库也要清理。 2. 现在我理解这里一共有三个项目 a. console项目（包含前后端） b. su-ccb-claude-plugin 项目 c. su-ccb-codex-skills 项目。 我打算以当前根目录为一个git仓库，然后把console所有的代码相关、项目相关的都整理到完整的 su-console目录下，然后平级的是 docs、su-ccb-claude-plugin、su-ccb-codex-skills 相当于四个目录平级，然后想要console的根目录就是 su-console目录。你帮我扫描和整理一下思路

澄清过程中的关键原话（按时间）：

- Git 历史：「彻底 rm -rf .git 全新 init」；后续「全新即可，不需要历史」（含 plugin/codex-skills）
- 发布：「还要继续对外发布」→ 再澄清「不考虑旧用户，我会自己通知」「全部换新仓」
- 构建工具归属：「随 console 进 su-console，改相对路径」
- kernel：经讨论确认真相源归 plugin（「所以更加确定了你接下来处理的方向是对的对吧」）
- 命名：「感觉plugin和skills可以不改名。主要是console」「或者console不用SU相关的也行，起一个合适的名吧，根据项目定位」→ 最终选定「SU-Oriel吧。我们回到正轨」

## Claude 解读

用户真实意图不是简单"挪目录"，而是**把一个职责混杂的 monorepo 拆成边界清晰的 4 个独立可演进单元**，并借机为 console 建立独立产品 IP（SU-Oriel）。三层诉求：

1. **解耦**：去掉 submodule 绑定与根工作区对 console 的隐式托管，让每个项目能独立 clone / commit / 发布。
2. **自洽**：console 必须能脱离主仓单独构建（构建工具、pnpm workspace、schema 生成全部内聚到 `su-oriel/`）。
3. **真相源归位**：kernel 承认 plugin sovereignty，运行时真相源落 plugin，删根上过时副本。

"四个目录平级"是用户的心智模型；落地后根目录除四个内容单元外，不可避免还要承载仓库级元数据（git、.github、README/ROADMAP 等）——已与用户对齐，不视为偏差。

## 歧义点（均已澄清闭环，无遗留 TBD）

1. ~~"清理所有 git 绑定" = 重来还是只去 submodule？~~ → **全新 init，丢历史**
2. ~~plugin/codex-skills 独立发布如何保留？~~ → **全部换新仓，旧仓废弃，用户自行通知老用户**
3. ~~console 上行构建依赖归属？~~ → **随 console 进 su-oriel，改相对路径**
4. ~~kernel 真相源归属？~~ → **归 plugin，删根副本 + sync 脚本**
5. ~~console 命名？~~ → **SU-Oriel**（目录 `su-oriel/`），plugin/skills 保留原名
6. ~~根仓库是否独立仓 / 推回 CCB？~~ → **根仓库也是新仓，fresh-init**

## 保真差异

- 用户最初表述为 `su-console`，最终命名决策将 console 更名为 **SU-Oriel**，目录相应改为 `su-oriel/`。这是用户在澄清中主动升级的决定，非理解偏差。
- 用户最初设想"三个项目 + 根仓库一个仓库"，扫描后明确实际为 **4 个独立仓库**（根仓库也是其一）+ 根目录额外承载仓库级元数据。已对齐。

## 背景与目标

**现状**（已核验）：
- 根仓库 `SU-CCB/CCB`（分支 `v1.0-plugin-sovereignty`）+ `.gitmodules` 注册两个 submodule
- console 位于 `apps/ccb-console/{web,server,scripts}`；根 `pnpm-workspace.yaml` 把 web/server 作为 workspace 成员
- 根 `references/kernel/`（67 文件，旧 yaml 布局）与 plugin `references/kernel/`（70 文件，已迁 `.node.md`）**已分叉**，plugin 为运行时真相源
- `.tmp/` 下有两个垃圾 git 仓（CLIProxyAPI、su-ccb-codex-skills 副本）

**目标**：拆成 4 个边界清晰、各自独立 init / 提交 / 发布的仓库；console 自洽并更名 SU-Oriel；kernel 真相源归 plugin。

## 已确认决策清单

| 维度 | 决策 |
|---|---|
| 架构 | multi-repo，4 个独立 git 仓库平级；根仓库 `.gitignore` 排除三个子目录 |
| Git 历史 | 全部 fresh-init，不保留历史；全部新仓；旧仓废弃（用户自行通知老用户） |
| console | 更名 **SU-Oriel**，目录 `su-oriel/`，吸收构建工具 + pnpm 自洽 |
| plugin / skills | 保留原名 `su-ccb-claude-plugin` / `su-ccb-codex-skills` |
| 构建工具 | 根 `scripts/generate-*.mjs` + `references/schema-ownership-matrix.yaml` 迁入 `su-oriel/`，改相对路径 |
| kernel | 真相源归 `su-ccb-claude-plugin/references/kernel/`；删根 `references/kernel/` + `scripts/sync-kernel-to-plugin.sh` |
| pnpm | `su-oriel/` 内保留 workspace，packages 为 `server`/`web`（不合并成单 package） |
| CI | `schema-ownership-lint.yml` → su-oriel；`manifest-strict.yml` → plugin（并修 `.node.yaml`→`.node.md`） |
| 实施策略 | **O3：本地完整演练 + 全量验证后，再分仓推送** |

## 验收口径（什么算交付）

1. 父目录下存在 4 个独立 `.git`，各自可独立 `clone` / `commit` / `push`，无 submodule、无 `.gitmodules`、无 `.tmp` 残留 git 仓。
2. `su-oriel/` 可在**脱离主仓**的情况下完成 install / build / test（构建工具、pnpm workspace、schema 生成全部内聚，无 `../../../` 上行依赖）。
3. plugin 与 codex-skills **切断对主仓资源的反向依赖**（generator / 根 kernel），各自独立测试通过。
4. 根 `references/kernel/` 与 `scripts/sync-kernel-to-plugin.sh` 已删除；全仓无残留指向根 kernel 的引用（含 CI、文档命令、resolver 默认路径）。
5. kernel 相关 CI / 文档命令 / resolver 默认路径全部指向 plugin 内 kernel。
6. 根仓库 `.ccb` 跟踪边界正确：`ccb.config` 等配置纳入版本控制，agent runtime / job 快照不被误提交。
7. 四仓全部推送到各自新远程，验证无丢失。

## 风险与约束（Codex 协商核验）

**高影响不可逆点**（Codex `analysis_depth_hint: human-decision`）：
- fresh-init + 推新仓本身可逆性高（旧仓废弃是已接受的代价）；真正易错点是 **`.ccb` 跟踪边界**与 **submodule ahead 提交丢失**。

**隐性耦合（远超最初判断的"2 处"，须全量迁移）**：
- console → 上行：`role-profile.service.ts:12`（硬编码 `apps/ccb-console/server/scripts`）、`docs-structure-resolver.ts:5`（默认读平级 plugin contract）、`lint-schema-ownership.ts:16`（读根 matrix + plugin lib）、dev 脚本写死 `apps/ccb-console/...`、prompt validator、dual-run smoke、测试 fixtures、schema tests
- **反向**：plugin 测试读主仓 generator（`policy.test.mjs:16`）、codex resolver 默认读根 kernel（`resolve-same-group-peer.mjs:240`）
- pnpm：lock importer 改名导致 `--frozen-lockfile` 失败，需重生并验证 node-pty / prisma；旧 node_modules symlink、husky prepare 位置、Prisma DB 路径
- husky/lint-staged：根 hook 不应再管 console，须迁入 `su-oriel/`

**前置动作**：重构前**冻结 CCB 队列**（`ccb.config` agent target 全为 `"."`，重构中旧 job 快照/路径会失效）；备份四仓 refs / 工作树。

## 留待 technical_design 解决的设计决策

- **plugin generator 责任归属**：plugin 测试当前读主仓 generator。plugin 要独立发布就不能依赖平级 console。→ 选择"plugin 自带一份 generator"还是"砍掉该测试依赖"。

## 协商与反思摘要（节点合规记录）

- **Codex 协商**：2 轮。第 1 轮（风险）推翻"仅 2 处上行依赖"的 framing，补出 console 隐性耦合、反向耦合、`.ccb` 跟踪陷阱、pnpm-lock 必变、先冻结队列，并给出 O3 推荐执行顺序；第 2 轮（命名）产出候选并辅助定名。
- **4 锚点反思**：
  - 同意：耦合面被低估；采纳 O3；`.ccb` 边界 / lock 重生 / 冻结队列均为真风险。
  - 修正 Codex 前提：用户已决定"全部换新仓"，故"force-push 覆盖公开历史"这一头号不可逆点基本被拆除。
  - 盲点：只看了 console→根单向，漏了 plugin/codex 反读主仓的反向耦合。
  - 下一步：进入 technical_design，列全量耦合清单 + 制定 O3 演练步骤 + 定 generator 归属。
- **必问项**：命中"不可逆工程动作"（fresh-init/换新仓）、"产品方向"（命名）—— 均已升级用户并取得明确决定。

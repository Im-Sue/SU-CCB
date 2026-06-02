---
id: ADR-0042
title: Multi-repo 四仓拆分 + SU-CCB submodule 容器 + 角色化获取模型
status: active
decided_at: 2026-06-02
last_updated: 2026-06-02
decider: 用户（multi-repo 拆分 / console 更名 SU-Oriel / 全部换 Im-Sue 新仓 / submodule 版本绑定 / 角色化获取）+ Claude 设计与执行
reviewer: slot4_codex（需求风险 / 命名 / technical_design / task_breakdown 共 4 轮协商）
codename: multirepo-submodule
related_doc:
  - docs/02_需求设计/项目目录结构重构-multirepo四仓-713c13-需求.md
  - docs/03_开发计划/项目目录结构重构-multirepo四仓-技术设计.md
parent_adrs: []
related_adrs: []
---

## 背景

原项目是单 monorepo（根仓库 `SU-CCB/CCB` + 两个 submodule），console 位于 `apps/ccb-console/`，
`references/kernel/` 在根与 plugin 之间存在分叉副本，职责混杂、console 无法脱离主仓独立构建。

## 决策

拆分为 **4 个各自独立、fresh-init 的 git 仓库**（均在 GitHub `Im-Sue` 组织下，旧 `SU-CCB` 组织仓作历史备份）：

| 仓库 | 角色 |
|---|---|
| `Im-Sue/SU-CCB`（根容器） | `docs/` 人读文档 + `docs/.ccb/` 工作区 + 框架文件 + 跨仓脚本 |
| `Im-Sue/SU-Oriel` | 原 console 更名，自洽可视化控制台（web+server） |
| `Im-Sue/su-ccb-claude-plugin` | 协议内核真相源 + Claude 侧 skills/命令 + schema generators |
| `Im-Sue/su-ccb-codex-skills` | Codex 侧 execute/consult/doc skills |

### 1. SU-CCB 为根，三仓为 submodule

SU-CCB 是根容器，其余三仓以 **git submodule** 嵌套（`docs/` 同级）。理由：**整套开发者需要版本绑定 / 可复现** ——
SU-CCB 钉住三仓的精确 commit 组合，任何历史点都能还原整套版本；并白送 `git clone --recursive` 一行拉齐。
代价：子仓推新 commit 后需回 SU-CCB `git add <子仓> && git commit` 更新指针（这一步即"登记新版本组合"）。

> 演进说明：迁移期曾**先拆掉 submodule**（fresh-init 各仓、解耦避免指针在重构中碍事），稳态再**按角色重新挂回**。
> 这不是回退，而是把"绑定时机"从"重构中"移到"稳态版本管理"。

### 2. 角色化获取模型

| 角色 | 获取方式 | 是否需 SU-CCB / 平级 plugin |
|---|---|---|
| 整套开发者（维护者） | `git clone --recursive` SU-CCB，统一管理、跨仓提交、更新指针绑定版本 | 是 |
| 只用 plugin / skills | marketplace / skill-installer 装进 CLI；要改自行 fork | 否 |
| 用 SU-Oriel 控制台 | 单独 clone SU-Oriel + plugin/skills 装 CLI | 否（控制台经项目本地契约 + 内置 fallback，不要求平级 plugin） |

### 3. 内核与三 root（实现要点）

- **协议内核真相源归 plugin**（`su-ccb-claude-plugin/references/kernel/`），删除根上过时副本与 sync 脚本。
- **三 root 分层**：sourceRoot（SU-Oriel 源码）/ projectRoot（被观测项目，动态发现 `.ccb`，见 `su-oriel/server/src/lib/project-root.ts`）/ contractRoot（仅显式）。删除全部 `../../../` 硬编码攀爬。
- **generator 归 plugin**，默认不写 console；各仓提交自身 generated 产物；跨仓 drift 检查走 `scripts/check-cross-repo.sh`（umbrella，不进单仓 CI）。
- **模板真相源归 plugin** `templates/docs/`，删除项目内冗余 `docs/_模板_*` 副本。

## 后果

**正面**：每仓独立 clone/build/test/push/fork；console 脱 sibling 自洽（验证：SU-Oriel server 605 + web 243 测试、plugin 170 测试、codex 4 测试、umbrella 全绿）；版本可复现；使用者零负担。

**负面 / 约束**：
- 整套开发者需手动更新 submodule 指针（版本绑定的固有成本）。
- 跨仓一致性（schema ownership 跨 console+plugin、generated drift）不能进单仓 CI，只能在四仓凑齐时跑 umbrella。
- 维护者需在子仓内避免 detached HEAD 误提交（submodule 常见坑）。

## 验收

四仓已推 Im-Sue 新仓且本地=远程一致；`.gitmodules` 重新登记三仓 gitlink（钉定各自 main）；全量测试与 umbrella 通过。

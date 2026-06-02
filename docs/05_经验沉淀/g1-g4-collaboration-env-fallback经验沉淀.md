---
doc_type: lessons
title: "G1-G4 协作流程与环境兜底经验沉淀"
updated: 2026-05-28
---

# G1-G4 协作流程与环境兜底经验沉淀

> **Date**: 2026-05-01

## 背景
G1-G4 覆盖了 v6 兼容升级主线和 Console smoke follow-up。本轮不只是
代码修复，也暴露了 spec 生命周期、证据口径、批量归档、跨平台环境治理
上的可复用经验。

G1-G3 先完成 plugin/kernel/docs/dev-shell 兼容升级，再批量补 state、
推进 frontmatter、归档 spec，并重建 `.ccb/index`。G4 在 post-v6
Console smoke 后收口 3 个环境/测试 finding，最终补 state 并归档。

本 note 只沉淀机制与工程套路，不替代 archived spec、commit log 或
state 文件作为验收真相源。

## L1 · spec git rename 流程教训
### 现象
G4 spec 起草后没有单独 commit drafting 状态，直接让 Codex 执行
review 到 archive 闭环。执行 `git mv active -> archive` 时，这些 active
spec 对 Git 来说仍是 untracked 文件，最终 commit 只能显示 archive spec
create，而不能显示 rename。这不是 `git mv` 命令失败，而是 Git 没有旧路径
历史可追踪。

### 对比
G1-G3 的 v6 spec 在 `78c7138 chore: 解锁 docs/.ccb/ tracking + 冻结 v6 兼容升级 spec`
中先被纳入 Git。后续 archive 阶段移动 spec 时，Git 有旧路径基线，
因此能识别 active 到 archive 的 rename。

### 教训
| Rule | Rationale |
|---|---|
| spec 写完后先单独 commit drafting | 即使 frontmatter 仍是 drafting/proposed，也要先记录文件身份 |
| review/archive 不负责补历史 | archive 只能移动已经被 Git 跟踪的 spec |
| 不把 spec create 和 archive 合在同一 commit | 否则历史表现退化为 archive 文件新增 |

### 行动建议
在 `docs/.ccb/templates/` 或 v0.3.2 facade 中增加轻量 hint：

```text
Spec 文件创建后先单独 commit drafting/proposed 状态，再进入 dispatch/review/archive。
```

这条提示先作为 workflow hygiene，不必立即升级为新 guard。

## L2 · 环境兜底套路
### Locale 一致性
G2.5 暴露了跨平台 hash 计算的隐性差异。`find | sort | sha256sum`
如果不固定 locale，排序顺序会随 Linux、WSL、macOS、CI 环境变化。
对 snapshot、manifest、hash 这类可复现产物，应固定 `LC_ALL=C`。

### Python 命令兼容
G3-T2 修正了 `python` 命令假设。WSL、Linux、macOS 上经常只有
`python3`，没有 `python` 链接。项目脚本应优先写：

```bash
python3 ./scripts/ensure_dev_db.py
```

这类改动低风险，但能显著降低 onboarding 摩擦。

### Native binding 自愈
G4-T2 处理 `node-pty@1.1.0` 缺 linux-x64 prebuild 的问题。关键不是
简单写 `node-gyp rebuild`，而是把失败模式设计清楚。

| Requirement | Lesson |
|---|---|
| 路径解析 | 用 `require.resolve("node-pty/package.json", { paths: [process.cwd()] })` 适配 pnpm hoist/store |
| 平台守护 | 非 Linux 直接 skip，避免影响 macOS/Windows |
| 条件构建 | 已存在 `build/Release/pty.node` 或 prebuild 时不重复构建 |
| fail-fast | 缺 gcc/g++/make/python3 或 node-gyp 失败时退出非零 |
| grep-able marker | stderr 固定含 `node-pty linux-x64 native build failed` |

静默吞错会制造更坏状态：install 看似成功，但测试必挂。

### pnpm 嵌套调用
G4-T3 记录了 corepack 管理 pnpm 时的 PATH 问题。外层
`corepack pnpm ...` 可用，不代表 npm-script 子进程能找到 `pnpm`。
典型症状是 `sh: 1: pnpm: not found`。

有 sudo 权限时用 `corepack enable` 安装 shim；无 sudo 时用
`corepack enable --install-directory ~/.local/bin` 并更新 PATH。项目只应
文档化，不应自动修改用户 shell 或系统目录。

### 测试 environment 选型
G4-T1 证明 jsdom 与 undici 在 AbortSignal realm/type check 上会冲突。
当 react-router navigation 触发 undici `Request` 构造时，jsdom 的
AbortSignal 不是 undici 期望的 instance。

happy-dom 对现代 fetch/navigation 测试更稳，G4 验证 web 19/19 通过。
ad hoc polyfill 可作为 fallback，但 ESM/Vitest/undici export 形态更容易踩坑。

## L3 · 协作节奏教训
### batch dispatch 边界
G1-G3 闭环是批授权，但执行上仍逐 task 串行推进 state、frontmatter、
review evidence 与 archive guard。这样能减少重复人工操作，同时避免
bulk operation 绕过 review guard。

好的做法是批量列清单，但逐 task 写证据与状态，并在 archive 前检查
`review_status`、score 和 state 文件；坏做法是一次性移动文件后再补证据。

### plan review 不可跳过
G4 plan review 提前抓出 4 个问题：T2 升级路径实际无 stable 可用、T3
文档落点写错、T1 polyfill 依赖 undici export 不稳、Out of Scope 漏项。
这些 finding 全部进入修订版 spec。若跳过 plan review 直接派工，会在
execute round 中返工。

### Async Guardrail 实战检验
本轮 6 次 `ccb ask` 都遵守 `[CCB_ASYNC_SUBMITTED]` 后立即结束 turn，
没有 poll、sleep 或 pend。这减少了重复 trigger 和异步结果竞态，让
control-plane 事件流更清晰。

### 证据口径要明确
G1-G3 第一次批量补 state 的 job 因 `git log --grep=<完整 task_id>` 过严而
卡住。重派时明确允许短编号、聚合 commit、跨仓 plugin hash 后通过：
`fix(g2-t2): ...`、`fix: align plugin ask markers with ccb v6`、
`[plugin@f2d1db6] ...`、主仓 submodule pointer commit 都可作为证据。

派工时给定证据来源映射，比让 executor 自行猜 grep 口径更可靠。

## 适用范围
| Scenario | Apply |
|---|---|
| 多 task batch closeout | 先明确 evidence mapping，再逐 task state/archive |
| spec lifecycle | create spec 后先 commit drafting，再 dispatch/review/archive |
| 跨平台 snapshot/hash | 固定 locale、排序、hash 算法 |
| Console 本地环境 | 不可控环境差异文档化，可控 native build fail-fast |
| plan review | 中等以上 task batch 不跳过 plan review |

不适用范围：一次性 throwaway 调研、无 Git 历史要求的临时草稿、用户明确要求
不落文档的短期实验。

## 关联文档
| Type | Path |
|---|---|
| Parent archived spec | `docs/.ccb/specs/archive/2026-04-30-ccb-v6-compat-upgrade.md` |
| G4 follow-up parent | `docs/.ccb/specs/archive/2026-05-01-ccb-v6-console-env-followup.md` |
| G2.5 hash follow-up | `docs/.ccb/specs/archive/2026-05-01-g2-5-sync-followup-fix-plugin-hash.md` |
| G3-T2 env fix | `docs/.ccb/specs/archive/2026-05-01-g3-t2-env-fixes-python3-and-readme-troubleshoot.md` |
| G4-T1 web env | `docs/.ccb/specs/archive/2026-05-01-g4-t1-web-test-abortsignal-fix.md` |
| G4-T2 node-pty | `docs/.ccb/specs/archive/2026-05-01-g4-t2-node-pty-postinstall-rebuild.md` |
| G4-T3 pnpm corepack | `docs/.ccb/specs/archive/2026-05-01-g4-t3-pnpm-corepack-troubleshoot-doc.md` |

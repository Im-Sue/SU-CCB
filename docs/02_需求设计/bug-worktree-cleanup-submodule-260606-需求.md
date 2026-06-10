---
id: cmpwtcleanupsubmodule260606
title: BUG：cleanup 含 submodule 的 worktree 必拒 + git 异常未包装 escalation
doc_type: requirement
created: 2026-06-06T10:05:00.000Z
updated: 2026-06-06T10:05:00.000Z
status: delivered
source: archive-reflection (req cmpworktreearchive260604 收尾实战)
parent_epic: v1.0 plugin sovereignty
references: [docs/06_决策记录/ADR-0036-per-requirement-implementation-worktree.md, docs/02_需求设计/per-需求worktree-归档分层修复与预览式归档-260604-需求.md, su-ccb-claude-plugin/lib/worktree/index.mjs]
analysis_input_hash: f4e51dead885fa2d63bd12b41e79b9def2ca0394f8bdc1221cb7c6f962b45fd4
analysis_applied_at: 2026-06-06T10:09:11.100Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

req cmpworktreearchive260604 交付的 `cleanupRequirementWorktree`（需求级手动归档）在其自身收尾首跑时暴露两个缺陷：

1. **submodule 硬拒**：cleanup 用 `git worktree remove <path>` 删除 merged worktree，但 git 对含 submodule 的 worktree 硬性拒绝（`fatal: working trees containing submodules cannot be moved or removed`）。本仓是 superproject（su-oriel / su-ccb-claude-plugin / su-ccb-codex-skills 三个 submodule），意味着**每个需求的手动归档都必然在此步失败**。
2. **异常裸抛**：上述失败以 `GitCommandError` 直接抛出，而非按 archive manifest 契约返回 `status: "escalated"` 结果对象——调用方拿不到结构化 reason，journal 也没有 escalation 事件，违反「escalated 时停止」的设计契约。

已实战验证的恢复路径（req 260604 收尾）：前置校验（worktree porcelain 干净 + merged sha 是 target 祖先，均为 lib 既有检查）→ `rm -rf <worktree>` → `git worktree prune` → 重跑 `cleanupRequirementWorktree`，lib 走 `hasBranch && !targetRecord` 恢复分支完成 branch 删除与受治理状态写入。修复应把这条兜底路径吸收进 lib 主路径。

## 原话（verbatim）

> （Claude 归档报告，2026-06-06）踩到一个真 bug（本需求自己交付的代码，第一次实战就踩了）：`cleanupRequirementWorktree` 里用 `git worktree remove`，但 git 硬性拒绝删除含 submodule 的 worktree——而咱们这个仓永远带 submodule，意味着以后每个需求的手动归档都会在这一步炸。而且错误是裸抛异常，不是按设计返回 `escalated`。…… 建议：给这个 bug 立一个小需求（cleanup 支持 submodule worktree + git 异常包装成 escalation）。

> （用户，2026-06-06）立项

## 二、背景与目标

req cmpworktreearchive260604 交付的需求级手动归档（merged 预览 → cleanup → finalize delivered）在其自身收尾首跑时，cleanup 步骤被 git 硬拒：`git worktree remove` 不删含 submodule 的 worktree。本仓是 superproject（su-oriel / su-ccb-claude-plugin / su-ccb-codex-skills），**每个需求的手动归档都必然踩中**；且 GitCommandError 裸抛违反 archive manifest 的 escalated 契约（无结构化 reason、无 journal 事件）。目标：归档 cleanup 在 submodule 仓上开箱即用，删除段失败一律以 escalated 结构化返回。

## 三、讨论与决策

consult `job_ed7bca245829`（slot1_codex，2026-06-06，含 Git 2.43 真实 fixture 核验）：

- **关键事实**：已 init submodule 的 worktree，普通 remove 失败但 `git worktree remove --force` 成功，且清掉 `.git/worktrees/<id>/modules` 无残留；未 init submodule 的 worktree 普通 remove 即可删。
- **否决方案 a**（检测 .gitmodules → rm-rf+prune）：.gitmodules 过度命中未 init 场景；`git submodule status` 需处理递归/`-` 前缀/absorbed gitdir；rm-rf 路径存在 locked worktree 普通 prune 清不掉 → 后续 `branch -d` 认为分支仍被占用的连环坑。
- **否决全量 rm-rf 方案 c**：放弃 git 自有安全检查无增量收益，手写递归删除风险更高。
- **采纳**：普通 remove → stderr 精确命中 submodule 硬拒时 --force 重试 → 仍失败 escalated。其它 git 失败（locked/corrupt）不掩盖，直接 escalated，不自动 `-f -f`。
- **范围核验**：merge / reopen 不删不移 worktree，无同类坑；discardRequirementWorktree 已用 --force。

## 四、功能 / 范围

1. `cleanupRequirementWorktree` 删除段重构为结构化 helper：
   - 普通 `git worktree remove <path>`；
   - 失败且 stderr 匹配 submodule 硬拒 → `git worktree remove --force <path>` 重试一次；
   - 任一删除步骤最终失败 → 返回 `status: "escalated"`（reason: `cleanup_worktree_remove_failed`）+ append `requirement_worktree_archive_escalated` 事件，保留现场。
2. `git branch -d` 失败同样包装：reason `cleanup_branch_delete_failed`，不做 `-D` 强删。
3. 测试：
   - 真实 git 临时仓新增 initialized-submodule worktree cleanup 用例（验证 --force 路径 + `.git/worktrees/<id>/modules` 无残留）；
   - `runGit` 注入失败用例：remove/branch 失败 → escalated 结果 + journal 事件断言。

## 五、业务规则

- --force 重试的前提是 lib 既有前置已全部通过（runtime state=merged、worktree porcelain 干净、merged sha 为 target 祖先）——force 仅豁免 git 的 submodule 保守拒绝，不豁免任何业务安全检查。
- escalated 返回必须保留现场（worktree、分支、runtime state 不变），供人工或 reopen 处理。
- stderr 匹配必须精确到 submodule 硬拒文案，避免把 locked/dirty 等其它拒绝误升级为 --force。

## 六、边界 / 不做项

- 不做全 lib Git 异常治理（merge/ensure/reopen/discard 的 locked、corrupt 等裸抛场景）——证据显示值得做但另立项。
- 不改 merge / reopen / discard 行为。
- 不自动处理 locked worktree（不 `-f -f`），escalated 交人工。
- 不引入新依赖、不改 schema、不动 Console。

## 七、开放问题 / 假设

- 假设：Git 版本以当前环境 2.43 行为为准（--force 单次成功）；真实 submodule 测试用例会在未来 git 升级时充当回归哨兵。
- 假设：cleanup 的 clean/ancestor 前置是本需求可信安全边界（TOCTOU 窗口与现状等价，接受）。
- 无遗留待定项：escalation reason 命名已定稿（`cleanup_worktree_remove_failed` / `cleanup_branch_delete_failed`）。

## Claude 解读

修复 cleanupRequirementWorktree 的两个实战缺陷：(1) 删除段重构为结构化 helper——先普通 `git worktree remove`；stderr 精确命中 submodule 硬拒（working trees containing submodules cannot be...）时重试 `git worktree remove --force`（Git 2.43 fixture 已验证：单次 --force 成功且清掉 .git/worktrees/<id>/modules，无残留）；其它 git 失败不掩盖。(2) remove / `git branch -d` 失败不再裸抛 GitCommandError，统一返回 status:"escalated"（reason 定稿：cleanup_worktree_remove_failed / cleanup_branch_delete_failed）并 append requirement_worktree_archive_escalated 事件，保留现场不强删（不 -D、不 -f -f）。测试：复用现有真实 git 临时仓体系加一条 initialized-submodule cleanup 用例，另用 runGit 注入失败覆盖 escalation 转换与 journal 事件。right-size：单子任务 direct 修，不拆 PR。

## 歧义点

立项时 4 项歧义经 consult job_ed7bca245829（slot1_codex，含真实 fixture 核验）全部消解：A 修复策略——我原倾向「检测 .gitmodules → rm-rf+prune 兜底」被否：.gitmodules 过度命中未 init submodule（其 worktree 普通 remove 即可删），且 rm-rf 路径有 locked-worktree prune 不掉→branch -d 连环卡的边界；改为「普通 remove → submodule 拒绝时 --force 重试」。B 包装范围——最小范围（仅 cleanup 删除段），全 lib git 异常治理另立项。C branch -d——只 catch→escalated，不强删（ancestor gate 证明业务安全，但 -D 会掩盖 checked-out/locked/race）。D 测试——纠正我的错误认知：现有 worktree 测试是真实 git 临时仓非全 mock，故真实 submodule 用例可行。残余已知风险：status 检查到 remove 之间的 TOCTOU（与任何方案等价，接受）；locked worktree 仍 escalated（设计如此）。

## 保真差异

用户原话仅「立项」，需求范围承接 Claude 归档报告的建议两点（cleanup 支持 submodule worktree + git 异常包装成 escalation），用户默认采纳。协商后实现手段从报告中实战验证的「rm -rf + prune + 重入 lib」修正为更 Git-native 的「remove --force 重试」——目标与验收不变，手段升级（残留更少、不需手写递归删除）。明确排除项：全 lib Git 异常治理（merge/ensure/reopen 的 locked/corrupt 裸抛）不在本需求内，另立项；不改 merge/reopen 行为（核验无同类坑）；discard 已用 --force 不涉及。

---
id: td-worktree-cleanup-submodule-260606
title: BUG:cleanup 含 submodule worktree 必拒 + git 异常未包装 escalation 技术设计
doc_type: technical_design
requirement_id: cmpwtcleanupsubmodule260606
updated: 2026-06-06
---

# cleanup submodule 必拒 + escalation 包装 · 技术设计

> 一句话:`cleanupRequirementWorktree` 删除段重构为结构化 helper——普通 remove → stderr 精确命中 submodule 硬拒时 `--force` 重试一次 → 任何最终失败统一 `escalated` 结构化返回 + journal 事件,不再裸抛 `GitCommandError`。
>
> **无独立 status** —— 跟随 `requirement_id`=cmpwtcleanupsubmodule260606 的需求。｜协商:consult `job_ed7bca245829`(需求,含 Git 2.43 真实 fixture 核验) + `job_b40ac8ff2735`(设计) @codex。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | cleanup 删除段结构化(submodule --force 重试 + escalation 包装) |
| 核心职责 | 让需求级手动归档 cleanup 在 superproject(含 submodule)仓上开箱即用;删除段任何 git 失败按 archive 契约返回 `status:"escalated"` 而非裸抛 |
| 设计原则 | fail-safe(不确定就 escalated 保留现场)/ 精确匹配不误升级 / force 仅豁免 git 保守拒绝、不豁免业务前置 / 重入安全 |
| 需求来源 | `docs/02_需求设计/bug-worktree-cleanup-submodule-260606-需求.md` |
| 覆盖范围 | `cleanupRequirementWorktree` 删除段(worktree remove + branch -d)、`defaultRunGit` locale 固定、对应测试 |
| 不覆盖 | 全 lib Git 异常治理(另立项)、merge/reopen/discard 行为、locked worktree 自动处理(不 `-f -f`)、Console |

---

## 二、方案与架构

```
cleanupRequirementWorktree (lib/worktree/index.mjs)
  ├─ 既有业务前置(零改动): req 锁 → prune → state=merged → target 为当前分支
  │   → porcelain 干净 → branchSha 为 target 祖先
  └─ 删除段(本设计重构, 现 :947-954)
      ├─ removeWorktreeForCleanup()   [NEW 私有 helper]
      │    git worktree remove ─失败且 stderr 命中 submodule 硬拒→ remove --force(一次)
      └─ git branch -d                 [allowFailure 包装]
           任一最终失败 → escalation(reason) + requirement_worktree_archive_escalated 事件
                          现场保留(state 仍 merged, 不 -D / 不 -f -f)

defaultRunGit: env 固定 LC_ALL=C / LANG=C / LANGUAGE=C  [横切但行为不变, 仅诊断文案语言]
```

| 关键原则 | 说明 |
|----------|------|
| stderr 精确匹配才 force | 只对 git 的 submodule 保守拒绝重试;locked/dirty/corrupt 等其它失败直接 escalated,不掩盖 |
| escalated = 结构化停止 | 返回对象 + journal 事件双通道;调用方(su-archive / archiveRequirementWorktree / requirement-cancel)既有「escalated→停止」消费零改动 |
| 诊断文案 locale 固定 | git fatal 文案经 gettext 本地化,zh_CN 下正则会 miss → 退化为 escalated(fail-safe 但功能失效);统一 `C` locale 根除 |

**与现有系统的关系 / 边界**:

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `lib/worktree/index.mjs` cleanup 删除段(:947-954) | 重构为 helper + escalation | 删除段之前的全部业务前置零改动 |
| `defaultRunGit`(:129) | execFileAsync 增加 env locale 三变量 | 退出码/副作用/接口签名不变 |
| `escalation()` / `appendEscalationEvent()`(:430/:438) | 纯复用,新增 2 个 reason 枚举值 | helper 本身不改 |
| merge / reopen / discard | 零改动(范围核验:不删不移 worktree;discard 已 `--force`) | 全部 |
| `archiveRequirementWorktree`(:1091) / `lib/requirement-cancel`(:678) / su-archive skill | 零改动,自然受益(裸抛→结构化 issue) | 全部 |

---

## 三、关键决策与取舍(协商结论)

- **D1 修复策略**:选「普通 remove → stderr 命中 submodule 硬拒 → `--force` 重试一次」。否决 a「检测 .gitmodules → rm-rf+prune」:过度命中未 init 场景(其 worktree 普通 remove 即可删),且 rm-rf 有 locked-worktree prune 不掉 → `branch -d` 连环卡;否决 c「全量 rm-rf」:放弃 git 自有安全检查无增量收益。(需求阶段 consult 定稿,Git 2.43 真实 fixture 验证 --force 单次成功且 `.git/worktrees/<id>/modules` 无残留)
- **D2 locale 稳健性**:选「`defaultRunGit` 全局固定 `LC_ALL=C, LANG=C, LANGUAGE=C`」(merge 顺序 locale 在 `options.env` 之后兜底覆盖,`LANGUAGE` 防 GNU gettext 优先级穿透)。否决「仅 helper 两次调用传 env」:需加 env 透传改动面反而大,且留下其它 git 调用文案 locale 不稳暗坑;否决「不匹配文案、探测 `.git/worktrees/<id>/modules` 目录」:依赖 git 内部 absorbed gitdir 布局假设,modules 存在 ≠ remove 必拒,比官方文案更脆。该项为横切改动但**行为不变**(lib 解析的其它输出全是 porcelain/ref/sha 机器格式,locale 只影响人读诊断文案),不构成对「不改 merge/reopen/discard 行为」的违反——设计 consult 双方确认。
- **D3 branch -d 失败语义**:只 catch → `escalated`,不 `-D` 强删(ancestor gate 虽证明业务安全,但 -D 会掩盖 checked-out/locked/race)。此时 worktree 已删不可逆,「保留现场」=不进一步破坏 + 重入安全:重跑 cleanup 走既有 `hasBranch && !targetRecord` 路径(rev-parse → ancestor 复验 → branch -d 重试),静态推演 + T4 真实重跑双覆盖。
- **D4 命名**:escalation payload 用 `forceAttempted`(而非 `forced`——失败 payload 里 `forced:true` 易误读为"已强制成功";Codex 提出,采纳)。reason 沿用需求定稿:`cleanup_worktree_remove_failed` / `cleanup_branch_delete_failed`。
- **D5 payload 完整性**:escalation payload 同时记 `stderr` 与 `stdout`(各截断 500)——`GitCommandError` 现有诊断逻辑看 `stderr || stdout`,对齐(Codex 提出,采纳)。字段 camelCase 对齐既有 escalation result 风格(`requirementId`/`exitCode`)。
- **D6 正则**:`/working trees containing submodules cannot be moved or removed/`(不带 `fatal:` 前缀、不锚行首)。该文案 Git 2.19 引入至今未变;T1 真实 submodule 用例充当 git 升级回归哨兵。
- **D7 archived 事件 additive 增强(超需求最小范围,可砍)**:`requirement_worktree_archived` 事件 payload 增加 `removal_forced: boolean`——force 使用痕迹仅存在于此刻,丢了不可追;additive 不改既有字段,审计「哪些归档走过 force」。

**AI 自决实现细节**:helper 命名/返回结构、截断长度、测试 fixture 组织。**用户授权事项**:无新增(无依赖/schema/migration/成本变更;API 行为变更〔裸抛→escalated〕即立项目标本身)。

---

## 四、核心流程 / 逻辑

```
删除段(业务前置全过后):
targetRecord 存在?
  ├─ 是 → git worktree remove <path>                    (allowFailure)
  │        ├─ exit 0 ──────────────────────────────→ 继续 ↓
  │        ├─ 非 0 且 stderr 命中 SUBMODULE_REJECTION
  │        │    → git worktree remove --force <path>    (allowFailure, 仅一次)
  │        │        ├─ exit 0 → 继续 ↓ (forceAttempted=true)
  │        │        └─ 非 0 → escalated(cleanup_worktree_remove_failed,
  │        │                   forceAttempted=true) ✋ 现场全保留
  │        └─ 其它非 0 → escalated(同 reason, forceAttempted=false) ✋ 不误升级
  └─ 否 → assertPathAbsentOrExpectedWorktree            (既有,零改动)
branch 存在?
  └─ 是 → git branch -d <branch>                        (allowFailure)
           ├─ exit 0 → 写 archived state + requirement_worktree_archived 事件(removal_forced)
           └─ 非 0 → escalated(cleanup_branch_delete_failed) ✋ 不 -D;
                      worktree 已删,state 仍 merged,重跑走既有恢复路径
```

| 处理规则 | 说明 |
|----------|------|
| 重入 / 幂等 | escalated 后 runtime state 不写 archived(仍 merged);remove 段失败重跑 → 前置重验后重试 remove;branch 段失败重跑 → `hasBranch && !targetRecord` 既有路径复验 ancestor 后重试 `branch -d` |
| 失败处理 | 删除段不再向上抛 `GitCommandError`;统一 `{status:"escalated", reason, ...诊断}` + `requirement_worktree_archive_escalated` 事件 |
| 安全边界 | `--force` 仅在 merged state + porcelain 干净 + ancestor 全过后触发,仅豁免 git submodule 保守拒绝;TOCTOU 窗口与现状等价(需求已接受) |
| 可观测 | escalation payload:`forceAttempted` / `exitCode` / `stderr` / `stdout`(截 500);成功路径 archived 事件带 `removal_forced` |

---

## 五、测试策略(真实 git 临时仓体系 `worktree.test.mjs`,18 既有用例)

- [ ] **T1 集成·submodule 哨兵**:独立 sub 仓 → superproject `git -c protocol.file.allow=always submodule add`(Git 2.38+ file 协议默认禁,此 `-c` 是 fixture 关键)→ commit → ensure → worktree 内 `submodule update --init`(同需 `-c`)→ merge 前显式 assert porcelain 为空 → commit/merge → cleanup → 断言:archived + worktree 目录无 + `.git/worktrees/<id>`(含 `modules`)无残留 + branch 已删 + journal `requirement_worktree_archived`(`removal_forced:true`)
- [ ] **T2 单元·force 也失败**:注入 runGit——remove 返回 `{1, submodule 文案}`、`--force` 也失败 → escalated `cleanup_worktree_remove_failed` + `forceAttempted:true` + journal 事件断言
- [ ] **T3 单元·不误升级**:注入 remove 返回 `{1, "is dirty"}` → 断言注入器未收到 `--force` 调用(记录 args)→ escalated `forceAttempted:false`
- [ ] **T4 单元+集成·branch 失败重入**:注入器对 remove **透传真实 git**(必须真实产生删除副作用,fake success 覆盖不了真实重入——设计 consult 修正),仅对 `branch -d` 注入失败 → escalated `cleanup_branch_delete_failed` + 事件;随后去掉注入真实重跑 cleanup → archived(D3 重入路径回归)
- [ ] **T5 回归**:既有 18 用例零回归(无 submodule 时普通 remove 首试即成,不进 force 分支)

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-ccb-claude-plugin/lib/worktree/index.mjs`:
  - `defaultRunGit`(:129):execFileAsync 增加 `env: { ...process.env, ...(options.env ?? {}), LC_ALL: "C", LANG: "C", LANGUAGE: "C" }`(locale 兜底覆盖;`options.env` 为前向兼容,当前无调用方)
  - `[NEW]` 模块级常量 `SUBMODULE_REMOVE_REJECTION` + 私有 `async function removeWorktreeForCleanup(projectRoot, absolutePath, options)` → `{removed, forceAttempted, exitCode?, stderr?, stdout?}`
  - cleanup 删除段(:947-954):remove 改走 helper、`branch -d` 改 allowFailure,失败转 escalation + 事件;成功路径 archived 事件 payload 加 `removal_forced`
- `[MODIFY] su-ccb-claude-plugin/lib/worktree/__tests__/worktree.test.mjs`:新增 T1-T4

---

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| git ≥ 2.38(测试 fixture) | `protocol.file.allow=always` | 仅测试需要;lib 运行时无版本新要求 |
| git 2.19+ 文案假设 | stderr 正则 | 当前环境 2.43 实测;T1 哨兵守护未来升级 |

无新增 npm 依赖、无 schema/migration、无配置项。

---

## 十、迁移影响与风险

- **受影响**:`cleanupRequirementWorktree` 删除段失败语义(裸抛→escalated);三个消费方均已按 escalated 契约消费,零改动自然受益。
- **打法**:单子任务 direct 修(需求 right-size 共识),lib + 测试一次交付。
- **回滚 / 恢复**:纯 lib 内改动,git revert 单 commit 即回滚;escalated 现场保留,人工可按需求文档「已实战验证的恢复路径」兜底。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| git 未来版本改 submodule 拒绝文案 | 低 | force 路径失效,退化为 escalated(fail-safe) | T1 真实哨兵在 git 升级时报警 |
| gettext 环境 LANGUAGE 穿透 locale | 低 | 同上 | 三变量全设(LC_ALL/LANG/LANGUAGE) |
| `removal_forced` additive 字段触碰过紧投影断言 | 极低 | 个别 spec 断言挂 | additive 不改既有字段;若挂则修断言包容 additive(260604 rollup spec 债同类处理) |
| TOCTOU(前置检查到 remove 之间) | 低 | 与现状等价 | 需求已显式接受 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-06 | v1.0 | 初版(consult job_b40ac8ff2735 共识落盘) |

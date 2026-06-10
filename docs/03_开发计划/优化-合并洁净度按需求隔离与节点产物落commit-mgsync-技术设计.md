---
id: td-mgsync-merge-isolation-canonical-commit
title: 优化：合并洁净度按需求隔离 + technical_design 入 allowlist + 节点产物落 commit 技术设计
doc_type: technical_design
requirement_id: cm6241561f52fc0d749mgsync
expression_spec: v1
updated: 2026-06-08
---

# 合并洁净度按需求隔离 + technical_design 入 allowlist + 节点产物落 commit 技术设计

> 一句话：把合并前的洁净度检查从「整个 docs/ 必须干净」改成「只管本需求自己的东西、容忍别的需求在途文档」，并补 technical_design 进收拾名单 + 一把仓库级锁 ｜ 最后更新: 2026-06-08
>
> **无独立 status** —— 跟随 `requirement_id`（cm6241561f52fc0d749mgsync）指向的需求。

---

## 一、设计概述

**目标对齐**：现在多个需求的文档都堆在同一个主仓 `docs/` 里、长期没提交；等某个需求要「合并」时，系统先检查**整个** `docs/` 干不干净，一看到别的需求、甚至本需求自己的设计稿还没存，就判定"现场太乱"拒绝合并——于是并行的需求在合并这一步互相卡。这份设计做三件事：①把本需求自己的设计稿（`technical_design`）纳入"该提交"名单，让它能跟需求档一起被正确提交；②把合并前的洁净度检查从"整个 `docs/` 必须干净"改成"只关心本需求自己的东西、对别的需求在途的文档睁一只眼"，但对真正异己的脏东西（源码改动、不明文件）照旧拦；③因为放宽后会有多个需求同时动主仓，补一把**仓库级锁**（= 同一时间只让一个需求动主仓的提交/合并）防止互相踩。更彻底的"产物一生成就提交"（F1）留作独立后续需求。

| 项 | 说明 |
|----|------|
| 名称 | 合并洁净度按需求隔离 + canonical-sync allowlist 补全 + 仓库级锁 |
| 核心职责 | 让需求级合并不受其它并行需求未提交产物阻塞；本需求 canonical 产物（含设计稿）能正确收拢提交 |
| 设计原则 | 按需求隔离 · 安全降级有界（仍拦真正异己脏） · 诊断可观测 · 写主仓串行化 |
| 需求来源 | `docs/02_需求设计/优化-合并洁净度按需求隔离与节点产物落commit-mgsync-需求.md` |
| 覆盖范围 | F3（allowlist 补 technical_design）+ F2（洁净度三态 classifier 按需求隔离）+ 仓库级写锁 + tolerated_paths 诊断 |
| 不覆盖 | F1（节点产物即时落 commit，拆独立后续需求）；存量未提交档的一次性运维清理；submodule 代码空间隔离（已有 `statusEntryAllowedForAssociation` 先例，不重做） |

---

## 二、方案与架构

> 改的是 `su-ccb-claude-plugin/lib/worktree/index.mjs` 的合并预览链路：root 空间的 canonical 同步 gate。

```
mergeRequirementWorktree (root checkout = target branch, 如 main)
  │
  ├─[NEW] withCanonicalRepoLock(projectRoot)  ← 仓库级锁(按 projectRoot, 非按 requirement)
  │        包住: canonicalSyncCommit + git merge + (multi-space)association 写 root gitlink 的 commit
  │
  ├─ canonicalSyncCommit(projectRoot, reqId)
  │     status --porcelain(整个 root)
  │     └─ 逐条 entry 走 [NEW] classifyDirtyEntry():
  │          OWN      (本需求 allowlist, F3 后含 technical_design)  → 暂存+提交
  │          TOLERATE (别的需求 requirement-bound 档 / 已跟踪常青档 / 受管协调件) → 跳过, 记 tolerated_paths
  │          FOREIGN  (源码改动 / 未跟踪非 canonical / 新建无绑定常青档) → escalate(带 tolerated_paths 诊断)
  │
  └─ git merge ccb/req-<id> → target branch
```

| 关键原则 | 说明 |
|----------|------|
| 按需求隔离 | gate 只对"本需求该提交的"负责提交，对"别的需求在途的 canonical 档"容忍放行 |
| 安全降级有界 | 容忍集**严格限定**为可识别的受管 canonical 档；源码/不明/新建无绑定常青档仍 escalate，保留"拒绝合并进脏树"意图 |
| 只提交本需求 | TOLERATE 的路径**只放行、绝不替别的需求提交**（避免越权 / 把别人半成品提交进去） |
| 写主仓串行化 | F2 解除了"全局严格"附带的隐性串行（旧逻辑下别的需求脏就直接挡，等于一次只一个能合）；放宽后必须显式上仓库锁 |
| 诊断可观测 | escalation/event 保留 `tolerated_paths`，因为错误会从 `canonical_dirty_outside_allowlist` 漂移成 `merge_conflict`，需留痕归因 |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `canonicalSyncAllowlist` (index.mjs:309) | 增 `technical_design`（03，`doc_type==="technical_design" && requirement_id===reqId`）| 既有 02 需求档 / 03 dev_task / 文档地图 / journal / state / breakdown draft 不变 |
| `canonicalSyncCommit` (index.mjs:360) | `outside` 单一判断 → 三态 `classifyDirtyEntry`；提交逻辑仍只对 OWN | 提交/重查/幂等(noop) 主体流程保留 |
| `mergeRequirementWorktree` (:1465) / `mergeMultiSpaceRequirementWorktree` / `mergeOneSpace` (:859) | 外层套 `withCanonicalRepoLock(projectRoot)` | 既有 escalation 分支、worktree_dirty/target_branch 校验不变 |
| `lib/worktree/associations.mjs`（写 root gitlink 的 commit） | 纳入同一仓库锁覆盖范围 | submodule 内部 `statusEntryAllowedForAssociation` pathspec 隔离不动 |
| ADR（06，无 requirement_id） | **不**强行纳 allowlist；安全默认见三 D | 不改 ADR frontmatter schema |

---

## 三、关键决策与取舍

- **F2 设计：三态 classifier，不是"凡 canonical 都容忍"**：选「OWN / TOLERATE（限可识别受管档）/ FOREIGN」三分；否决「blanket 容忍整个 `docs/`」——后者太松，等于废掉脏树保护，源码改动和不明文件会被一起吞进合并。
- **常青档（05 经验 / 06 ADR / 04 模块规格）只容忍"已跟踪修改"**：否决「连新建未跟踪的无绑定常青档也默认容忍」——它们没有 `requirement_id`、没有提交归属，容忍后会把"挡合并"变成"产物永远没人提交"（Codex 指出的我方案最可能错的一处）。安全默认：**新建无绑定常青档仍 escalate**，由其产出节点 / F1 提交。
- **F1 延期，本需求不做**：选 F3+F2 先解并行合并互挡；否决「本需求一次做完 F1」——F1 要改提交模型（docs 从"合并时才落主仓"变"生成即提交")、加共享 commit helper + 仓库锁 + 每个节点写入口接线 + 提交分支语义，回归面独立、属独立需求体量。有 F3+F2 后 F1 紧迫性大降。
- **仓库锁按 `projectRoot` 而非 `requirementId`**：现有 `withRequirementLock`(:566) 按需求 keyed，挡不住"两个不同需求同时写 root index/HEAD"；新增 `withCanonicalRepoLock(projectRoot)` 串行化所有写 root repo 的路径。
- **ADR 归属（D 决策）**：选「安全默认——ADR 不进 allowlist、新建无绑定 ADR 仍 escalate」；`related_doc` 反查绑回需求作为**可选增强**，但现有简易 frontmatter parser 解析不了多行 YAML 数组（`related_doc` 是多行列表），需健壮解析才能可靠反查 → 列为 F1 / 后续，不在本需求强做。

### Codex 协商（slot1_codex，job_121967901242，mode: consult）

- **共识**：采用 O2（F3 + 有界 F2 + 仓库锁），F1 延期。
- **修正我**：F2 不应"凡 canonical 都容忍"，要做 status classifier；常青档 blanket 容忍过宽，新建未跟踪无绑定常青档不要默认容忍。
- **补充盲点**：F2 解除全局严格后需 root repo 级锁，且要覆盖 multi-space association 写 root gitlink 的 commit（不只 canonicalSyncCommit+merge）；gate 退化后错误从 `canonical_dirty` 漂成 `merge_conflict`，需保留 `tolerated_paths` 诊断。
- **B（安全退化反例排查）**：不会静默吞冲突——若合并分支真触碰同一路径，`git merge` 会拒绝/冲突，只是错误类型变化，故须留诊断。
- **指出我最可能错的一处**：把 ADR/经验沉淀这类无 requirement_id 的常青产物放进 F2 容忍集却无提交归属机制 → 把"挡合并"改成"产物长期未提交"。

### Claude 4 锚点反思

1. **同意 / 印证**：Codex 印证两层根因与 O2 方向、印证 technical_design 必须按 `doc_type+requirement_id` 纳 allowlist、印证 ADR/lessons 不稳定绑需求。读码与协商双向印证。
2. **被修正**：我把 F2 设成"凡 canonical 都容忍"过宽 → 改三态 classifier，常青档仅容忍"已跟踪修改 + 可识别 doc_type"。这是我方案最可能错的一处，已采纳。
3. **盲点**：① 漏了"放宽全局严格 gate 会解除它附带的并发串行化"，需 `projectRoot` 级仓库锁，且覆盖 association 写 root gitlink 的提交。② 漏了错误类型漂移（canonical_dirty→merge_conflict）需保留 tolerated_paths 诊断。教训：**放宽一个 gate 前先问"它顺带提供了什么隐性保证"**（这里是写主仓的并发串行化）。
4. **下一步**：按 O2 落档（本文档）→ 判断进 task_breakdown；F1 拆独立后续需求；ADR 归属取安全默认 + 列后续增强。

---

## 四、核心流程 / 逻辑

```
canonicalSyncCommit(projectRoot, reqId):
  allowlist = canonicalSyncAllowlist(reqId)   # F3 后含 technical_design
  entries  = status --porcelain(整个 root checkout)
  tolerated = []
  for entry in entries:
    cls = classifyDirtyEntry(entry, allowlist, projectRoot):
      if 每条 path ∈ allowlist                                  → OWN
      elif 路径在 02/ 且 frontmatter doc_type=requirement 且 id 存在        → TOLERATE(bound, 别的需求)
      elif 路径在 03/ 且 doc_type∈{technical_design,dev_task} 且有 requirement_id → TOLERATE(bound, 别的需求)
      elif 路径是受管协调件(.ccb/state/<其它reqId>.* | .ccb/drafts/breakdown/*.json) → TOLERATE(coord)
      elif 路径在 04|05|06/ 且 doc_type 可识别 且【已被 git 跟踪】           → TOLERATE(evergreen-tracked)
      else                                                       → FOREIGN
    if cls == FOREIGN: foreign.push(entry)
    elif cls != OWN:   tolerated.push(entry.path)
  if foreign 非空:
      return escalation("canonical_dirty_outside_allowlist", { porcelain: foreign, tolerated_paths: tolerated })
  # 仅提交 OWN（沿用既有 add/diff --cached/commit/重查 逻辑）
  commit(本需求 allowlist 内已变更且存在/被跟踪的路径)
  return { status: "committed"|"noop", tolerated_paths: tolerated, ... }
```

**模拟示例（重演 vlr74b 合并卡点）**：

输入：req mgsync `ready`，主 checkout 在 main，`docs/` 脏档 =
`{ mgsync 技术设计稿, mgsync 需求档, 6 个其它需求的需求/设计档, 1 个新建未跟踪经验沉淀档, su-oriel 某源码改动(假设) }`。

走查：

| 脏档 | 旧行为 | 新分类 | 新结果 |
|------|--------|--------|--------|
| mgsync 技术设计稿 | FOREIGN→escalate（allowlist 漏 td）| OWN（F3）| 暂存 + 提交 |
| mgsync 需求档 | OWN | OWN | 提交 |
| 6 个其它需求档/设计档 | 每个都 → escalate | TOLERATE(bound) | 放行、不提交、记 tolerated_paths |
| 新建未跟踪经验沉淀档（无绑定）| escalate | FOREIGN（新建无绑定）| **仍 escalate**（已知残留，见风险）|
| su-oriel 源码改动 | escalate | FOREIGN | escalate（安全意图保留）✅ |

结论：若主树**只有**前三类（典型并行场景），则 mgsync 自己的 canonical 档被正确提交、6 个其它需求不再挡、合并推进到 merged 预览。后两类（新建无绑定常青档 / 源码脏）仍会拦——前者是已知残留（F1 根治），后者是**正确**的安全拦截。仓库锁保证此刻没有第二个需求并发改 root index。

| 处理规则 | 说明 |
|----------|------|
| 幂等 | 无 OWN 变更 → `noop`；OWN 已提交 → `diff --cached` 为空 → `noop`（沿用现有） |
| 只提交本需求 | TOLERATE 路径绝不被 `git add`，避免越权提交别的需求半成品 |
| 并发 | `withCanonicalRepoLock(projectRoot)` 串行化 canonicalSyncCommit+merge+association root commit；超时走 LockTimeoutError 升级 |
| 可观测 | tolerated_paths 落 escalation payload 与 EventJournal，便于"为什么这些没提交/没挡"归因 |

---

## 五、测试策略

- [ ] 单元：`classifyDirtyEntry` 四类判定（OWN / TOLERATE-bound / TOLERATE-evergreen-tracked / FOREIGN）；新建未跟踪常青档判为 FOREIGN；源码改动判为 FOREIGN。
- [ ] 单元：`canonicalSyncAllowlist` 含本需求 `technical_design`（`doc_type+requirement_id`），不含别的需求的 td。
- [ ] 集成：`canonicalSyncCommit` 在"本需求设计稿 + 6 个其它需求脏档"下 → 只提交本需求、放行其它、返回 `tolerated_paths`；merge 成功。
- [ ] 集成：源码脏 / 新建无绑定常青档存在时 → 仍 `escalate`，且 payload 带 `tolerated_paths`。
- [ ] 端到端：重演 vlr74b 多需求并行 → autonomous-batch 推进到 merged 预览。
- [ ] 并发：两个需求同时 merge → 仓库锁串行化，root index/HEAD 无竞争、无损坏。
- [ ] 回归：单需求合并、multi-space（root + submodule）合并、worktree_dirty/target_branch 既有 escalation 不被破坏。

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-ccb-claude-plugin/lib/worktree/index.mjs`
  - `canonicalSyncAllowlist`(:309)：增 `technical_design`（03，`doc_type==="technical_design" && requirement_id===reqId`）。
  - `canonicalSyncCommit`(:360)：`outside` 单判 → `classifyDirtyEntry` 三态；提交仍只对 OWN；返回值 + escalation payload 增 `tolerated_paths`。
  - 新增 `classifyDirtyEntry()` + 健壮 frontmatter 读取（识别 doc_type / id / requirement_id）；常青档"已跟踪"判定复用 `pathExistsOrTracked` / `git ls-files`。
  - 新增 `withCanonicalRepoLock(projectRoot)`（仓库级锁，区别于 per-requirement `withRequirementLock`）。
  - `mergeRequirementWorktree`(:1465) / `mergeMultiSpaceRequirementWorktree` / `mergeOneSpace`(:859)：root 写路径外层套 `withCanonicalRepoLock`。
- `[MODIFY] su-ccb-claude-plugin/lib/worktree/associations.mjs`：写 root gitlink 的 commit 纳入同一仓库锁覆盖。
- `[MODIFY] su-ccb-claude-plugin/lib/worktree/__tests__/worktree.test.mjs`：classifier 四类、F3 allowlist、并发锁、tolerated_paths 诊断、回归用例。
- `[DOC] docs/06_决策记录/ADR-0036-*`（amendment 或新 ADR）：记录 clean-gate 安全模型从「全局严格」改「按需求隔离 + 有界容忍」——**建议 task_breakdown 列为子任务**（注意 ADR 自身受本 allowlist 缺口影响，需 F2 落地后或人工提交）。
- F1（节点产物即时落 commit）：**不在本设计落实现**，拆独立后续需求。

---

## 十、迁移影响与风险

- **受影响**：合并预览链路（root 空间 canonical 同步 + merge + association root commit）；不触 DB、不触对外 API、不改文档 schema。
- **打法**：F3（最小、纯 bug 修复）+ F2（classifier）+ 仓库锁 一并落；先单元后集成后并发 E2E；ADR amendment 随附。
- **回滚 / 恢复**：纯 lib 逻辑变更，`git revert` 即恢复旧 gate；无数据迁移、无投影重建。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| classifier 过宽吞人工脏档 | 中 | 误把脏树合并 | 三态严格判定（仅容忍可识别 doc_type+绑定 / 已跟踪常青）；FOREIGN 默认 escalate；tolerated_paths 全量审计 |
| classifier 过窄仍互挡 | 中 | 并行仍卡 | 覆盖 02/03 requirement-bound + 已跟踪常青 + 受管协调件；残留（新建无绑定常青）显式记为已知限制 |
| 仓库锁漏 association root commit | 中 | root index/HEAD 竞争、合并损坏 | 锁覆盖所有写 root repo 的路径；并发 E2E 用例 |
| 简易 parser 误判多行 frontmatter | 中 | doc_type/requirement_id/related_doc 误判 | 用健壮读取限定字段；ADR `related_doc` 反查若实现需多行解析，否则 ADR 走安全默认 |
| 错误类型从 canonical_dirty 漂成 merge_conflict | 低 | 诊断困惑 | escalation/event 保留 tolerated_paths + 原因 |
| **已知残留**：新建无绑定常青档（新 lessons/ADR）仍挡合并 | 中 | 偶发需人工提交或等 F1 | 安全取舍（不静默留无主产物）；F1 / 产出节点提交为根治 |

---

## 必问 12 类扫描 + 授权边界

| 必问类 | 命中? | 说明 |
|--------|-------|------|
| 依赖增减 | 否 | 纯 lib 内逻辑，无新依赖 |
| schema 变更 | 否 | `tolerated_paths` 是内部 result/event 附加诊断字段，非外部版本化 schema；不改文档 frontmatter schema |
| 公共 API | 否 | `canonicalSync*` 为内部 lib，不对外 |
| migration 方向 | 否 | 无 DB / 数据迁移 |
| 成本 / 许可证 / 合规 / 隐私 | 否 | 均无 |
| 业务规则 / 安全模型 | **方向已授权** | F2 修订 ADR-0036「拒绝放宽 clean」的安全取舍；但用户在 mgsync 立项时已明确要求"合并洁净度按需求隔离"，方向已授权；HOW（classifier 边界 + 仓库锁）属 AI 自决 |

- **AI 自决（实现细节）**：classifier 三态边界、仓库锁实现、tolerated_paths 诊断字段、F3 匹配谓词、ADR `related_doc` 反查是否实现。
- **用户已授权（需求层）**：按需求隔离合并洁净度、放宽全局严格 gate。
- **用户已拍板（2026-06-09，"先做1"）**：① F1 拆独立后续需求，本需求只做 F3+F2+仓库锁；② 接受残留——新建无绑定常青档（新经验沉淀/新 ADR）合并时仍被拦，人工提交过渡，F1 根治。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-08 | v1.0 | 初版：F3 allowlist 补 technical_design + F2 三态 classifier 按需求隔离 + 仓库级写锁 + tolerated_paths 诊断；F1 延期。经 slot1_codex 协商（O2）+ 4 锚点反思 |

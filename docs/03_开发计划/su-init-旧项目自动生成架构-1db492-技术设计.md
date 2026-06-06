---
doc_type: technical_design
title: su-init 旧项目自动生成 01_架构设计 技术设计
requirement_id: cmpxxyx7p1b024de1c81db492
updated: 2026-06-03
---

> 修订注记（2026-06-06）：本文记录 1db492 初版单架构生成设计；其中 `multiple_source_roots` gate 已被 726299 分层候选发现替换。现行规程以 `docs/03_开发计划/su-init-架构生成支持多源码根多子项目分层生成-726299-技术设计.md` 为准。

# su-init 旧项目自动生成 01_架构设计 技术设计

> 一句话：su-init 在确定性 lib 里加「架构生成够格」检测（无 LLM），agent 层据证据扫码生成一份带信任标记的架构文档、直落 `docs/01_架构设计/`；主策略「宁可跳过、不污染锚点」。｜ 最后更新：2026-06-03
>
> **无独立 status** —— 跟随 `requirement_id`（`docs/02_需求设计/su-init-对旧项目自动生成-01_架构设计-文档-1db492-需求.md`，status=planning）。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | su-init 旧项目架构自动生成 |
| 核心职责 | 确定性 lib 判「够不够格生成」+ agent 层据证据生成架构文档 + frontmatter 信任标记 + 回执提示 review |
| 设计原则 | lib 无 LLM · CLI/agent 共用单一判定算法 · 宁跳过不污染 · 只写有据不编造 · missing-only 绝不覆盖 · 信任标记承载未核实 |
| 需求来源 | `docs/02_需求设计/su-init-对旧项目自动生成-01_架构设计-文档-1db492-需求.md` |
| 覆盖范围 | lib eligibility 检测接口 + 判定算法；agent 生成与证据纪律；信任标记落地；契约声明 |
| 不覆盖 | 下游 su-flow/indexer 真正「读 `human_verified` 后谨慎当锚点」的接线（未来工作）；02_需求/04_模块规格 等其它文档；lib 跑 LLM |

---

## 二、方案与架构

```
/ccb:su-init  (agent 层 SKILL)
  │
  ├─① initProjectScaffold(lib · 确定性 · 无 LLM)
  │     ├─ 既有三步脚手架（human docs / machine layer / agent files）—— 不动
  │     └─ detectArchitectureCandidate()                    ← 新增确定性检测（scaffold 之后跑）
  │           └─ summary.architectureCandidate = {
  │                eligible, reason, targetPath, sourceRoots, existingArchitectureDocs }
  │
  ├─② init.mjs (CLI) 的 [CCB_SU_INIT_COMPLETED] stdout 增打印 architectureCandidate  ← 新增可见性
  │
  └─③ agent 据 architectureCandidate 分支：
        ├─ eligible=false → 跳过生成 + 回执说明 reason（no_source / multiple_source_roots / architecture_exists）
        └─ eligible=true  → agent 层「证据门槛」检查
              ├─ 证据不足 → 跳过 + 回执 evidence_insufficient（agent 层判断，不进 lib enum）
              └─ 证据够   → /sc:analyze + /sc:index-repo（不可用则兜底扫 README/入口/依赖）
                           → 按 `_模板_架构.md` 章节渲染（只填有据章节、省略推不出的）
                           → 写前二次 detect + exclusive-create 写 docs/01_架构设计/<name>.md
                           → 回执醒目提示：AI 生成 · 建议 review · 要改直接对话
```

| 关键原则 | 为什么 |
|----------|--------|
| 判定算法只在 lib 一处 | CLI（init.mjs）与 agent（SKILL）调同一个 `initProjectScaffold`，杜绝 skill 复制判定逻辑、CLI/agent 割裂 |
| lib 只判「项目形状」，agent 判「证据是否足够」 | 项目形状是确定性事实（源码/多根/已有架构）；「AI 能否抽出足够证据」是 agent 层判断，扩进 lib enum 会污染确定性接口 |
| 信任标记在 frontmatter、正文干净 | 不确定性由 `human_verified:false` 承载；正文不撒 TODO/待校正 噪声（用户「没问题就当成功」要求正文干净） |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `lib/su-init/index.mjs` | 新增导出 `detectArchitectureCandidate()`；`initProjectScaffold` 末尾调用并挂 `summary.architectureCandidate` | 既有三步脚手架确定性行为、无 LLM 属性 |
| `skills/su-init/scripts/init.mjs` | `[CCB_SU_INIT_COMPLETED]` 输出增 `architectureCandidate` 字段 | 既有 counts/warnings/verification 输出 |
| `skills/su-init/SKILL.md` | 新增「旧项目架构生成」步骤 + 证据门槛 + 信任标记 + 回执契约 | 既有 init lib 调用契约、节点 manifest 声明 |
| `docs-structure-contract.yaml`（plugin canonical + 项目副本 + Console default 第三副本） | **不动**（原拟加 `may_have`，Codex 复查后放弃：inert 声明跨两仓三副本不划算） | 全部——信任标记改由 SKILL 文档 + frontmatter 承载 |
| Console / indexer | 不碰 | 架构 frontmatter 容忍额外 scalar 字段，parse 仍 success |

---

## 三、关键决策与取舍（D1–D5 · Claude×Codex 协商结论）

> 协商：`slot1_codex`（child job `job_4a7997a826b2`，mode=consult，**1 轮达成共识**，Codex 提 6 点实质反驳/补强，非橡皮图章）。4 锚点反思与必问扫描见 §三末 + EventJournal `technical_design_consult_recorded`。

- **D1 lib eligibility 接口签名**：选「双接口」—— 导出 `detectArchitectureCandidate({projectRoot,resolver})` **且** `initProjectScaffold` 末尾调用挂 `summary.architectureCandidate`。否决「只挂 summary 不导出」（agent 难单测/重算）与「只导出不挂 summary」（CLI 纯跑拿不到）。返回 `{eligible, reason, targetPath, sourceRoots, existingArchitectureDocs}`，`reason ∈ {eligible, no_source, multiple_source_roots, architecture_exists}`。**Codex 补强**：必须同步改 init.mjs stdout 打印该字段（否则 CLISER 看不到），并给该函数加单测；检测时序放 scaffold 之后正确。

- **D2 源码根单一/多根 确定性算法**：选「marker 文件法 + monorepo 信号短路」（详见 §四）。否决「凭目录名猜」「只看 .git」。**Codex 补强**：① 裸 `.git`（空仓）应判 `no_source`，必须有真实 marker 或源码文件才算有源；② 扫描 depth=3；③ root marker + 子目录 marker 默认按「多根」跳过；④ ignore 清单补 `.next/coverage/tmp/.tmp/examples/fixtures/testdata` 及密钥类文件；marker 清单够 MVP、后续可追加。

- **D3 非模板 .md 判定**：选「**递归**扫 `docs/01_架构设计/`，排除 `_模板_` 前缀（对齐 indexer `isTemplateMarkdownFile`）；任一非模板 `.md` 即跳过（`doc_type:architecture` 为强信号，但非 architecture 的非模板 md 也跳过、保守不覆盖）」。否决「只查直接子级」（**Codex 抓到**：嵌套已有文档会漏判）与「只认 architecture 才算已有」（覆盖/污染风险高）。

- **D4 `generated_by`/`human_verified` 是否进 schema**：选 ——（a）架构 md frontmatter 写 `generated_by: su-init-ai` + `human_verified: false`；（b）**不**新建严格 architecture-md schema（kernel 本无此 schema，凭空造校验面=风险）；（c）**不**改 `docs-structure-contract.yaml`——task_breakdown 阶段 Codex 复查揭示：除 plugin canonical + 项目派生副本外，Console 侧 indexer 另有 `su-oriel/server/src/indexer/default-docs-structure-contract.yaml` fallback **第三副本**（我此前 `find` glob 太窄漏掉）；`may_have` 对 resolver 功能惰性，一条 inert 声明跨两仓三副本维护不划算，故放弃。信任标记改由 **su-init SKILL.md 生成步骤 + 架构 frontmatter** 承载——与现存架构 md 已带未声明 `status: active` 的容忍惯例一致；（d）**不**进 requirement frontmatter（那个有 schema，改它才是真 schema 变更）。**Codex 补强**：下游读取时 `false` 与字符串 `"false"` 都视为未核实；生成的新架构文档**不写** `status` 字段。**授权判定**：(c) 是用户已拍板「frontmatter 信任标记」决策的 additive 落地、功能惰性，按 AI 自决处理但已透明上报用户（见 §十 + 回执）。

- **D5 SC 不可用兜底最低证据**：选「证据门槛 + 章节落地纪律」。**生成硬门槛**（不够则即便 eligible 也 agent 层跳过、报 `evidence_insufficient`）：拿得到目录树 + ≥1 grounding 源（README / 依赖 manifest / 入口文件其一）+ 足够源码，**且**至少能填出「概述 / 技术栈 / 项目结构 / 核心模块·入口」四块。**章节纪律**：只填有据章节（技术栈←manifest；结构←目录树；核心模块←顶层目录+入口 import 标 inferred；概述←README）；推不出的章节（部署拓扑/外部服务/权限模型/关键数据流/历史意图）**直接省略**（模板允许删用不上的段），不编造、不 hedge。正文不写 TODO，但**回执必须提示 review**。**Codex 补强**：门槛从「三类证据其一」抬高到上述四块可填，否则跳过。

**4 锚点反思（精简）**：
- *我同意*：接受 Codex 4 点——CLI stdout 也要打印 `architectureCandidate`；D3 须递归非直接子级；裸 `.git` 不算 `hasSource`；`evidence_insufficient` 属 agent 层。
- *我修正*：lib `reason` enum 收窄（不含 `evidence_insufficient`）；`hasSource` 去裸 git 分支；depth=3 + ignore 扩列；D3 改递归；D5 门槛抬高；并发用「写前二次检测 + exclusive-create」兜底。
- *我的盲点*：信任标记下游读取 `false` vs `"false"` 歧义；并发 init 的 TOCTOU；查清后确认 `may_have` 惰性 additive、不必再拍板。
- *接下来*：共识达成不开二轮；落本文档；判进 task_breakdown（需求 §八已粗分 lib / SKILL / 契约文档 3 片）。

**/sc 使用记录（替代说明）**：`/sc:design` → 以 §二 自拟功能架构替代（方案已具体到接口签名/算法，无需再出草图）；`/sc:analyze` → 已直接通读 `lib/su-init/index.mjs`、`init.mjs`、indexer 解析路径（模板识别 + frontmatter 容忍）替代，等价于受影响代码影响分析；`/sc:research` → 跳过（本设计无新技术选型，纯 fs 遍历 + 模板渲染 + 既有模式，调研低价值）。

---

## 四、核心流程 / 逻辑

**`detectArchitectureCandidate` 确定性算法**（伪码）：
```
ignoreDirs = [node_modules,.git,dist,build,vendor,.venv,target,.next,coverage,
              tmp,.tmp,examples,fixtures,testdata, docs, docs/.ccb, .claude]
monorepoSignals = [.gitmodules, pnpm-workspace.yaml, lerna.json, nx.json, turbo.json,
                   go.work, package.json#workspaces, Cargo.toml#[workspace]]
markers = [package.json, pyproject.toml, Cargo.toml, go.mod, pom.xml,
           build.gradle, composer.json, Gemfile, *.csproj]   # MVP，可扩

1. existingArchitectureDocs = 递归(docs/01_架构设计/) 中非 `_模板_` 前缀的 .md
      → 非空 ⇒ {eligible:false, reason:"architecture_exists", existingArchitectureDocs}
2. 任一 monorepoSignal 命中 ⇒ {eligible:false, reason:"multiple_source_roots"}
3. markerDirs = depth≤3、跳过 ignoreDirs 后含 marker 的目录集
      |markerDirs| ≥ 2                      ⇒ multiple_source_roots（含 root+子 的 root-aggregator）
      hasSource = (|markerDirs|≥1) || 源码文件数≥阈值     # 裸 .git 不算
      !hasSource                            ⇒ no_source
4. 否则 ⇒ {eligible:true, reason:"eligible",
           sourceRoots:[单根], targetPath: docs/01_架构设计/<resolver 命名>.md}
```

**agent 层证据门槛 + 写入**（eligible=true 后）：
```
读 targetPath 目录候选证据 → 能否凑齐「目录树 + grounding 源 + 概述/技术栈/结构/核心模块四块」
  否 → 跳过 + 回执 evidence_insufficient（不写文件）
  是 → 渲染（只填有据章节）→ 写前再 detectArchitectureCandidate() 二次确认仍 eligible（TOCTOU）
       → exclusive-create 写文件（已存在则放弃、回执提示）→ frontmatter 信任标记 → 回执提示 review
```

| 处理规则 | 怎么保证 |
|----------|----------|
| 不覆盖既有文件 | 写前二次 detect + `wx`（exclusive create）—— 并发/竞态下也绝不 clobber |
| 不污染锚点 | 机器 gate 限定低歧义场景 + `human_verified:false` + 省略未证实章节 |
| 幂等 | 已有非模板架构 → `architecture_exists` 跳过；重复 init 不重复生成 |

**执行细节（task_breakdown 阶段 Codex 复查 job_b8fac5f8d787 补定，防实施时猜规则）**：
- **targetPath concrete 命名**：`<架构目录>/<sanitize(basename(projectRoot))>-架构.md`（sanitize：小写、非字母数字转 `-`、去首尾 `-`），对齐现存 `su-oriel-后端架构.md` 等命名；lib 返回 concrete `targetPath`，不留占位 pattern。
- **源码文件阈值/扩展名**：`hasSource` 的 marker-less 分支取 `源码文件数 ≥ 3`，扩展名清单 `.js .mjs .cjs .ts .tsx .jsx .py .go .rs .java .kt .rb .php .c .cc .cpp .h .hpp .cs .swift .scala .sh`。
- **pr2 独占写**：必须 final path `writeFile(targetPath,{flag:"wx"})` / `open("wx")`，**禁用** `safeWriteFile` 类 temp+rename（final rename 可能覆盖竞态文件）。
- **pr2 二次检测**：直接 `import` lib 的 `detectArchitectureCandidate`（不经 init.mjs）；若不再 `eligible` → 按最新 reason 跳过不写。
- **回执**：除 review 提示外，列 evidence sources 摘要（为何生成 / `evidence_insufficient` 缺哪类证据）。

---

## 五、测试策略

- [ ] 单元 · `detectArchitectureCandidate`：空项目→`no_source`；裸 git 空仓→`no_source`；单 `package.json`→`eligible`；`frontend/`+`backend/` 双 marker→`multiple_source_roots`；有 `.gitmodules`→`multiple_source_roots`；`01_架构设计/` 有非模板 md（含嵌套）→`architecture_exists`；只有 `_模板_架构.md`→不误判为已有。
- [ ] 单元 · `initProjectScaffold`：summary 含 `architectureCandidate`；既有三步脚手架行为不回归。
- [ ] 集成 · CLI：`init.mjs` 的 `[CCB_SU_INIT_COMPLETED]` JSON 含 `architectureCandidate`。
- [ ] 集成 · SU-CCB 自身（dogfood）：根仓有 `.gitmodules` → 正确跳过 + 提示。
- [ ] agent 层（人工/脚本核对）：证据不足→跳过报 `evidence_insufficient`；证据够→生成文档含信任标记、不写 `status`、未证实章节被省略、回执提示 review。

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-ccb-claude-plugin/lib/su-init/index.mjs`：新增导出 `detectArchitectureCandidate()`；`initProjectScaffold` 末尾调用、挂 `summary.architectureCandidate`。
- `[MODIFY] su-ccb-claude-plugin/skills/su-init/scripts/init.mjs`：`[CCB_SU_INIT_COMPLETED]` 输出增 `architectureCandidate`。
- `[MODIFY] su-ccb-claude-plugin/skills/su-init/SKILL.md`：新增「旧项目架构生成」步骤、证据门槛、信任标记（含 frontmatter 字段 `generated_by`/`human_verified` 说明）、回执契约、`/sc` 用法。
- ~~`docs-structure-contract.yaml`~~：经 Codex 复查**放弃**（Console 侧另有 default fallback 第三副本，inert 声明跨仓维护不划算）；信任标记由 SKILL 文档 + frontmatter 承载，不进契约。
- `[NEW] su-ccb-claude-plugin/lib/su-init/__tests__/*`：`detectArchitectureCandidate` 单测（覆盖上述向量）。
- 无新增运行时依赖；无 DB / migration；架构模板 `_模板_架构.md` 无需改（信任标记由 agent 写 frontmatter，不进模板）。

---

## 十、迁移影响与风险

- **受影响**：`lib/su-init`（additive 接口）、`skills/su-init`（新步骤）、canonical contract（声明性一行）。均向后兼容、additive。
- **打法**：lib + 测试先行（确定性、可单测）；agent SKILL 步骤随后；契约一行随 lib 一并提交。
- **回滚**：纯 additive，`git revert` 即可；契约 `may_have` 惰性，回滚零行为影响。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| AI 架构幻觉污染真相源 | 中 | 高 | 机器 gate 限低歧义 + `human_verified:false` + 省略未证实章节 + 人工 review |
| 误判源码根（monorepo/root-aggregator） | 中 | 中 | 保守按「多根」跳过 + 回执提示（可接受的误杀） |
| 并发 init 竞态写入 | 低 | 中 | 写前二次 detect + exclusive-create（`wx`） |
| 信任标记下游未接线 | —— | 低 | 本 SP 仅埋标记；下游消费列为未来工作（§一 不覆盖） |
| 慢命令 / 耗 token | 中 | 低 | 仅单根 eligible 时触发；用户已接受 |

**用户授权记录**：范围/落点/质量门/多源码根/防污染均已用户拍板（需求 §三）；本设计新增的 schema-adjacent 改动（架构 frontmatter 加 2 字段、`initProjectScaffold` summary additive）经判定为已批准决策的 additive 落地、功能惰性，按 AI 自决处理并已透明上报，待用户 review 可拦。原拟的 contract `may_have` 改动经 Codex 复查放弃（见 D4(c)）。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-03 | v1.0 | 初版（Claude 设计 + slot1_codex 协商 job_4a7997a826b2 共识） |
| 2026-06-03 | v1.1 | task_breakdown 阶段 Codex 复查（job_b8fac5f8d787）：①修正 D4(c) 放弃 contract `may_have`（Console 侧第三副本，inert 跨仓维护不划算），信任标记改由 SKILL + frontmatter 承载；②pr2 验收改场景走查；③§四补定 targetPath 命名 / 源码阈值+扩展名 / final `wx` 独占写 / pr2 直 import lib / 回执列 evidence sources。详见拆分草案与 EventJournal |

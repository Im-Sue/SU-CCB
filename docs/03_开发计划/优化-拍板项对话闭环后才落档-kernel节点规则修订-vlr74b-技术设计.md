---
id: td-vlr74b-decision-closeloop-before-doc
title: 优化：拍板项对话闭环后才落档——kernel 节点规则修订 技术设计
doc_type: technical_design
requirement_id: chce8igv76fw62d1eusvlr74b
expression_spec: v1
updated: 2026-06-08
---

# 拍板项对话闭环后才落档 · 技术设计

> 一句话：用「行为规则源改措辞 + 模板拆床位 + SKILL 防复活 + 四闸门加扫描」四层文档修订，把"待用户拍板"挡在正式档之外 ｜ 最后更新: 2026-06-08
>
> **无独立 status** —— 跟随 `requirement_id: chce8igv76fw62d1eusvlr74b`。

---

## 一、设计概述

**目标对齐**：这份设计要解决的是"AI 把该问你的问题偷偷写进文档、你翻不到就被漏掉"。做法不是加状态机或 UI 高亮，而是改一摞 plugin 文档的措辞，让规则变成"命中要你拍板的事 → 攒成一批在终端一次问你 → 挂着等你回话 → 拿到答案才把正式档落下来"。落不落档由 AI 行为约束，不靠机器拦截，所以**零代码、不碰 lib/schema/API**。本设计的真正产出是：把需求已定的 9 个修订点（11 个文件）写成可机械执行的逐文件改动清单，并把"四道闸门共用的扫描约定"和"正则 pattern"两个跨文件一致性物件**逐字钉死**，防止实现时漂移。

| 项 | 说明 |
|----|------|
| 名称 | 拍板项对话闭环后才落档（vlr74b） |
| 核心职责 | 修订 kernel 节点 manifest / 需求模板 / SKILL 文案 / 下游闸门，使"待用户拍板项"无法进入正式档 |
| 设计原则 | 零代码（纯文档）；行为约束优先于机器拦截；闸门只扫"在手文件"不扫全目录；机器辅助定位、人工裁决语义 |
| 需求来源 | [vlr74b 需求设计](../02_需求设计/优化-拍板项对话闭环后才落档-kernel节点规则修订-vlr74b-需求.md) |
| 覆盖范围 | 4 组 9 修订点 / 11 文件（见 §八）；统一扫描约定 v1 |
| 不覆盖 | 状态机 / UI 高亮 / 通知 / 超时防护 / 等待期草稿 / su-oriel 任何代码 / lib / schema / 存量文档回溯（均见需求六） |

---

## 二、方案与架构

> 三层修订堵住"未决项进正式档"的三层漏洞，第四层闸门做防御纵深。

```
用户原意（含拍板项）
   │
   ▼
┌─ 行为规则源（4.1 kernel manifest）──────────────┐
│ requirement_analysis / technical_design：       │  ← 收紧"已问"为"已答"，
│   命中拍板项→攒齐一次问→终端阻塞等→才落正式档   │     等待期不落正式档
│ dispatch：质量闸从"挡 TBD"扩为"挡任何待拍板项"  │
└──────────────────────────────────────────────┘
   │  正式档 = 分析结论主体 + 技术设计正文（决策5；不含 promote planning）
   ▼
┌─ 床位清除（4.2 需求模板×2）─────────────────────┐
│ 七章删"待谁定"列、歧义点注释改闭环语义           │  ← 脚手架不再"邀请"写未决项
└──────────────────────────────────────────────┘
   │
   ▼
┌─ 防复活（4.3 SKILL×3）──────────────────────────┐
│ su-flow / requirement-reanalyze / su-revise：    │  ← 用户可见输出节 + ambiguities
│   输出"已闭环记录"，不输出"待用户××"            │     字段写作约定改闭环形态
└──────────────────────────────────────────────┘
   │
   ▼
┌─ 防御纵深（4.4 四闸门：dispatch/review/archive/materialize）┐
│ 放行前对"在手文件"跑【拍板项扫描约定 v1】，命中逐一人工裁决  │
└──────────────────────────────────────────────────────────┘
```

| 关键原则 | 说明 |
|----------|------|
| 行为约束 > 机器拦截 | 真正的防护是"未决项根本进不了正式档"；扫描只是兜底的机器辅助 |
| 闸门只扫"在手文件" | 绝不扫整个 `docs/02`/`docs/03` 目录——存量历史文档有大量良性/旧命中会把闸门淹死（Codex risk #1） |
| 复制而非引用 | 四闸门逐字复制同一段扫描约定，在 plugin distribution snapshot 硬拷贝分发模型下比共享 reference 更抗"缺失"漂移 |
| 闭环态分层 | "命中未答=节点未完成、终端等待" 与 "已闭环=完成、可停下/进下一节点" 在文案上分清，避免节点永远卡"等待" |

**与现有系统的关系 / 边界**：

| 涉及对象 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `applyRequirementAnalysis` / `promoteRequirementToPlanning` lib | 不动 | 精确标题锚点、三字段非空校验、分析后自动 promote planning 全部保留 |
| 需求 md schema / Console indexer | 不动 | `ambiguities` 仍必填非空（写闭环记录即满足）；server 解析只抽 section 文本（需求六已核验） |
| su-oriel（含 project-indexer.ts 占位文案） | 不动 | 决策4：占位文案被正式分析整段覆盖，下次动 su-oriel 时顺手改 |

---

## 三、关键决策与取舍

- **D1 扫描约定单一措辞、四闸门复制**：选"逐字复制同一段（命名为扫描约定 v1）"，因为下游项目通过 plugin distribution snapshot 持有 hard-copy 副本，共享 reference 会有"副本缺失"漂移；复制 + 版本号让漂移可检测。没选"抽一处共享引用"，因为它在快照分发下更脆。
- **D2 task_breakdown 不进范围（守住需求 9 点）**：选"不改 task_breakdown.node.md"。理由：breakdown draft 是机制件、非正式档（决策5），且自带用户审查门；**关键证据**——`materializeRequirement`（[subtask/index.mjs:349](../../su-ccb-claude-plugin/lib/subtask/index.mjs)）先读 approved draft 再把 `spec_section_md` 渲染进 dev_task（[:82](../../su-ccb-claude-plugin/lib/subtask/index.mjs)），所以只要 **materialize 闸门在调 lib 前扫 draft JSON**，任何藏在 draft 里的待决项都会被拦在物化前，task_breakdown 已被防御纵深覆盖。没选"加第 12 文件"，因为它超出已定范围且收益被 materialize 前置扫描兜底（与用户最简取向一致）。
- **D3 既有 anti-TBD 条款协调而非删除**：requirement_analysis 的完成条件6/硬约束5/自检18/打回7 已"反对留 TBD"，与新规则同向；只把"解决方式"从含糊的"升级用户/别留 TBD"细化为"命中拍板项→终端问到答案→写成闭环记录"，措辞对齐、不矛盾、不新增矛盾条款。
- **D4 「正式档」边界沿用决策5**：= 分析结论主体 + 技术设计正文；**不含**立项动作（原话存档 + `promoteRequirementToPlanning`）。su-flow entry promotion 契约零改。

**被否决的方案**（需求三、决策已闭环，此处记录技术取舍依据）：①按交互/异步链路拆两套方案——否决，因 Console 派发的就是 su-flow、anchor 是交互式 TUI，本是同一问题；②pending_decisions 状态机 + UI 高亮 + 通知——否决，阻塞式等待让未决项进不了正式档，防护对象不存在；③等待期落 drafting 草稿——否决，与 lib 三字段校验 + 自动 promote 不兼容，丢了重做成本可接受；④扫整个 docs 目录——否决，被存量历史文档噪声淹死。

---

## 四、核心流程 / 逻辑

**流程 A · 运行期闭环问答（行为规则，落在 4.1/4.3 文案里）**

```
节点产出分析/设计
   │
   ├─ 扫出命中"用户拍板项"？
   │      │是                          │否
   │      ▼                            ▼
   │  攒齐同批全部命中项            正常落正式档 → 节点完成
   │      ▼
   │  当前终端一次性抛出（Console 派发的 anchor 会话同样挂着等）
   │      ▼
   │  阻塞等待用户答复（不做超时；等待期不调 applyRequirementAnalysis 落主体）
   │      ▼
   │  拿到答案 → 写入闭环记录（答案 + 理由）→ 才落正式档 → 节点完成
   └─ 后续节点新冒出的拍板项：允许追加一轮，同批内必须攒齐（R1）
```

**模拟示例**（拿真实案例 23ee06 端到端走一遍）：分析中扫出"修复档位三选一""多 tab 并发是否必须支持"两个拍板项 → 旧流程写进文档"七、开放问题"标【待用户拍板】、宣告完成落档（用户漏看=疏忽决策）；**新规则下** → 分析主体先不落档，终端一次性抛出这 2 个问题、会话挂起等答案 → 用户迟早看终端、问题就在眼前 → 拿到答案写进"三、讨论与决策" → 此时才落档，文档已是闭环形态。

**流程 B · 闸门扫描（防御纵深，落在 4.1 dispatch / 4.4 三闸门）**

```
闸门放行前
   │
   ▼
对"本节点在手文件"跑 rg（pattern 见 §八）
   │
   ├─ 无命中 → 放行
   └─ 有命中 → 逐一人工裁决，归入三类之一才放行：
              ① 已闭环拍板记录（含答案与理由）
              ② 非用户项（纯技术/中性词误命中）
              ③ 已显式移交下一节点的技术项
        任一命中无法归类 → 阻塞，回对应节点在终端问到答案
```

| 处理规则 | 说明 |
|----------|------|
| 攒齐一次问（R1） | 同批命中项一次性抛，禁止挤牙膏式多轮打断；后续节点新项允许追加一轮 |
| 等到答案前不落正式档（R2） | 正式档边界见 D4；等待期只保留对话上下文（决策3，丢了重做） |
| 闸门各自的"在手文件" | dispatch=当前 dev_task spec + 绑定 requirement；review=本次审查产物 + diff；archive=本次归档 dev_task + 收尾时该 requirement；materialize=draft JSON（见 §八 P11） |
| 机器辅助、人工裁决 | rg 只定位，不做语义硬判；命中是否真"待用户"由人裁决（R4） |

---

## 五、测试策略

> 纯文档修订，无代码单测；验证以"机器可验自检 + 人工复核 + lib 回归说明"为主。**所有 `rg` 清零类断言必须限定在 11 个目标文件，绝不扫全仓**（Codex risk：存量历史档噪声）。

- [ ] **改动面收口**：`git diff --name-only` 结果 ⊆ 本设计 §八 列出的 11 文件，无额外文件。
- [ ] **床位清零（限目标文件）**：对 11 文件 `rg "已问用户|待谁定"` 应 0 命中（旧床位已清）。
- [ ] **新规则句覆盖**：钉死物件 3 的标准句在 requirement_analysis / technical_design 各命中 1 次（`rg -F "<标准句稳定子串>"`）。
- [ ] **四闸门逐字一致（marker 机器抽取）**：用 Node 读取 dispatch / review / archive / materialize 四文件中 marker 包裹的扫描约定块，断言 `new Set(blocks).size === 1`（块含约定段 + pattern）。
- [ ] **两份模板字节一致**：`cmp templates/docs/02_需求设计/_模板_需求.md docs/02_需求设计/_模板_需求.md` 返回 0。
- [ ] **lib 锚点未动**：`rg '^## (需求描述|原话（verbatim）|Claude 解读|歧义点|保真差异)$'` 在两份模板各 5 个受保护标题仍在；佐以人工论证——`replaceSection`/`replaceBodyMarkdown` 只认精确标题锚点（[index.mjs:196,246](../../su-ccb-claude-plugin/lib/requirement-analysis/index.mjs)），模板只改正文（七章列 / 歧义点注释），故对分析落档零影响（作用域仅空白脚手架阶段）。
- [ ] **pattern 有效性（仅验证不改旧档）**：对 23ee06/c5c98f 旧档跑一次新 pattern，确认能命中其【待用户拍板】，证明 pattern 对真实未决措辞有效。
- [ ] **勿改清单复核**：确认 §十"良性命中"三处未被误改。

---

## 八、文件结构 / 变更清单

> 9 个修订点 / 11 文件。下列为逐文件改动**意图 + 锚点 + 验收**；最终成文措辞由实施节点（Codex）按意图落地。三个跨文件一致性物件**逐字钉死**见末尾：requirement_analysis / technical_design 的新规则句用**钉死物件 3**；dispatch / review / archive / materialize 的扫描块用 **marker 包裹的钉死物件 1 + pattern 钉死物件 2**（review/archive 插入 ② 核心要点 + ③ 完成条件；materialize 插入 `materialize lib 调用契约` 的 JS 代码块**之前**，禁止调 lib 后再扫）。

**4.1 kernel 节点 manifest（行为规则源）**

- `[MODIFY] references/kernel/nodes/requirement_analysis.node.md`
  - ② 核心要点：增一条新规则（用扫描约定外的"闭环问答"措辞，即流程 A 文字版）。
  - ③ 完成条件3「已问用户」→「已获用户答复（命中项已在终端拿到答案并写成闭环记录）、引用已有用户决定，或说明不命中理由」（rg 实测此为全 plugin 唯一"已问用户"）。
  - ③ 完成条件6 + ④ 硬约束5：保留"无遗留待定/TBD"，把解决方式对齐为"终端问到答案后落闭环记录"（D3）。
  - 自检18、打回7：对齐闭环语义。出口语义分层（命中未答=未完成/终端等；无命中或已闭环=完成）。
  - **验收**：rg "已问用户" 不再命中；新规则句出现；既有 anti-TBD 条款无矛盾。
- `[MODIFY] references/kernel/nodes/technical_design.node.md`
  - 同构补规则（轻，F1：无"已问用户"可替换）：② 核心要点增同一条（拍板项含 migration 方向 / 依赖 / schema / API 取舍等用户权利项）；③ 完成条件2 补"已获用户答复"、完成条件5"设计待定不得拆任务"对齐闭环；自检1 对齐。
  - **验收**：核心要点含新规则；完成条件闭环表述。
- `[MODIFY] references/kernel/nodes/dispatch.node.md`
  - ② 深度说明第2点 + ③ + ④ 硬约束2：质量闸从"spec 仍有 TBD 不能派工"扩为"存在任何待用户拍板项不能派工"。
  - 追加【拍板项扫描约定 v1】整段；在手文件 = 当前 dev_task spec + 绑定 requirement。
  - **验收**：扫描约定 v1 逐字一致；质量闸措辞已扩。

**4.2 需求模板（床位清除，两份逐字同步）**

- `[MODIFY] templates/docs/02_需求设计/_模板_需求.md`（plugin 源）
  - 七、开放问题/假设：删表头「待谁定」列（表改为「问题 / 假设 | 当前倾向 / 结论」）；注释改为"只允许两种形态：①已闭环拍板记录（含答案与理由）②显式移交下一节点的技术项；不留'待用户××'"。
  - 歧义点 section 注释（现"列出仍需用户确认的问题"）→"已闭环拍板记录或移交技术项；无遗留则写'无遗留待用户拍板项'"。
  - **不动** `## 七…`/`## 歧义点` 等标题（F2 lib 安全）。
- `[MODIFY] docs/02_需求设计/_模板_需求.md`（项目副本）：与上逐字同步。
  - **验收**：rg "待谁定" 两份均不再命中；标题锚点未变。

**4.3 SKILL 文案（防旧行为复活）**

- `[MODIFY] skills/su-flow/SKILL.md`
  - 第6节 用户可见输出第6点：把"等待用户拍板"分层——(a) 命中拍板项未获答复 = 节点未完成、正在终端等答案；(b) 节点已完成 = 等用户下一意图（Q4 分层，避免永卡"等待"）。
  - artifact projection 契约（analysisFile 字段说明处）：补 ambiguities 写作约定——写闭环形态（已问已答 + 理由 / 移交技术项），不写"待用户××"；命中未决项时不调 `applyRequirementAnalysis`，先终端问到答案。
- `[MODIFY] skills/requirement-reanalyze/SKILL.md`：第6节"需要用户重新拍板的问题"→"先在终端问到答案再落档，输出已闭环记录"。
- `[MODIFY] skills/su-revise-breakdown/SKILL.md`：第6节"需要重新拍板的问题"同构改闭环语义。
  - **验收**：三处输出节均无"待用户××"邀请式措辞。

**4.4 下游闸门（防御纵深，同一扫描约定 v1）**

- `[MODIFY] references/kernel/nodes/review.node.md`：②/③ 追加扫描约定 v1；在手文件 = 本次审查产物（requirement/technical_design/dev_task）+ diff；自检区补一项扫描自检。
- `[MODIFY] references/kernel/nodes/archive.node.md`：②/③ 追加扫描约定 v1；在手文件 = 本次归档 dev_task + requirement 收尾文档。
- `[MODIFY] skills/su-materialize-requirement/SKILL.md`：第3节 materialize lib 调用契约中、**在 `materializeRequirement` 调用之前**追加扫描约定 v1；扫描对象明确为 `docs/.ccb/drafts/breakdown/<requirementId>.json` 的 `plan.spec_outline_md` + 全部 `include: true` 的 `subtasks[].spec_section_md`；命中未闭环即阻塞、回 task_breakdown / `/ccb:su-revise-breakdown`，不得调 lib（Q3：materialize 必须前置扫 draft，否则污染先落档）。
  - **验收**：扫描约定 v1 逐字一致；materialize 扫描位于 lib 调用之前；字段名与 schema 一致。

---

### 钉死物件 1 ·【拍板项扫描约定 v1】（dispatch / review / archive / materialize 四处逐字一致复制）

> 四处必须**用下方 marker 包裹整段并逐字复制**（marker 让 §五"四闸门逐字一致"可机器抽取断言）：

```
<!-- PAIBAN-SCAN-CONVENTION v1 START -->
放行前对「本节点在手文件」（各节点的"在手文件"定义见所在 manifest）执行【拍板项扫描约定 v1】：对在手文件运行 §钉死物件 2 的 rg pattern；命中处逐一人工裁决，归入三类之一才放行：① 已闭环拍板记录（含答案与理由）；② 非用户项（纯技术 / 中性词误命中）；③ 已显式移交下一节点的技术项。任一命中无法归类即阻塞，回对应节点在终端问到答案。机器辅助定位、人工裁决语义，不做语义硬判。
<!-- PAIBAN-SCAN-CONVENTION v1 END -->
```

### 钉死物件 2 · 扫描 pattern（与物件 1 同处复制；勿扫裸"确认 / 开放问题 /?"，"?"仅作人工二级检查）

```
待用户|待谁定|TBD|TODO|后续确认|待(确认|拍板|定|澄清|商榷|评估|回复|补充|明确|决)|未(定|决|确认|澄清|明确)|尚未(确定|明确|拍板|确认)|仍需(用户)?确认|需(用户)?(确认|拍板|澄清|回复|补充|明确|决策|授权)|等待用户(确认|拍板|裁决|仲裁|回复)
```

### 钉死物件 3 · 闭环问答标准规则句（requirement_analysis / technical_design 核心要点处逐字复制）

> 下句逐字写入两节点 ② 核心要点，作为 §五"新规则句覆盖"的 rg 锚点；technical_design 可在其后另起一句补充"拍板项含 migration 方向 / 依赖 / schema / API 等用户权利项"：

```
闭环问答规则：命中用户拍板项时，必须攒齐同批全部命中项，在当前终端一次性提问并阻塞等待用户答复；等待期不落正式档（不调用落档 lib）；Console 派发的 anchor 会话同样挂着等（anchor 是交互式 Claude TUI，非后台进程）。拿到答案后写入闭环记录（答案 + 理由）才落正式档。
```

rg 稳定子串：`攒齐同批全部命中项，在当前终端一次性提问并阻塞等待用户答复`

---

## 十、迁移影响与风险

- **受影响**：仅 plugin 文档 + 项目模板副本；**零代码、无 schema/数据迁移、无回滚脚本**（最坏回退 = git revert 文档）。
- **存量不动**：23ee06 / c5c98f 等留档形态不动，新规则只约束此后产出（需求六）。
- **闸门"勿改"良性命中清单**（扫描会命中但**不得修改**——它们不在闸门扫描的业务文档路径内）：

| 位置 | 命中文本 | 为何勿改 |
|------|----------|----------|
| `references/kernel/nodes/task_breakdown.node.md` | 等待用户确认 | 合法 breakdown review 门，非待决床位（D2） |
| `references/kernel/registries/transition-table.md` | 等待用户仲裁 | escalation 终态描述 |
| `references/kernel/tools/lint_manifest.py` | 待定 | placeholder linter 正则，非文档内容 |

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 闸门误写成"扫全目录" | 中 | 被存量历史文档噪声淹死 | §四 钉死"只扫在手文件"；§八 P3/P9/P10/P11 各自写明在手文件范围 |
| materialize 只扫物化后 dev_task | 中 | 污染先落档 | P11 钉死"调 lib 前扫 draft JSON" |
| pattern 字面漏判/误判混写 | 中 | 漏网未决项进派工 | R4 命中处人工逐一裁决；review 语义兜底；pattern 已按 Codex 建议收紧 |
| 四闸门复制块日后漂移 | 低 | 床位话术局部复活 | 命名"约定 v1"+ 逐字一致自检（§五） |
| 两份模板日后漂移 | 低 | 床位复活 | 本次两份同步改；下游靠 distribution snapshot 分发 |

---

## 十一、协商与 4 锚点反思

**Codex 协商（job_ebdb4ba281c0，slot1_codex，consult）摘要**：达成共识"保持 11 文件范围、四闸门复制扫描约定"。Codex 三处硬化全部采纳——① 闸门**只扫在手文件、不扫全目录**（存量噪声 risk）；② **materialize 必须在调 lib 前扫 draft JSON**（含 `plan.spec_outline_md` + included `subtasks[].spec_section_md`），否则污染先落档；③ pattern 收紧为本文件钉死物件 2。Codex 与我一致：无需用户再拍板，唯一 Claude 可决项是"是否加第 12 文件 task_breakdown"——双方都倾向不加，靠 materialize 前置扫描兜底。

**4 锚点反思**：
- **我同意的**：Codex 对"扫全目录会被历史文档淹死"的判断成立——我原以为扫 `docs/02`/`docs/03` 目录即可，实测仓库存量档大量良性命中，必须收敛到"在手文件"，这是本轮最关键修正。
- **我不同意的**：不接受 Codex 备选的"加第 12 文件 task_breakdown"——因 materialize 前置扫 draft JSON 已在物化前拦住一切藏在 spec_section_md 的待决项，加它属超范围且收益重叠，与用户最简取向冲突。
- **我的盲点**：原 pattern 漏了"待定/待澄清"且"待确认"不子串匹配"仍需用户确认"；materialize 的扫描时序（draft vs dev_task）我未深究，Codex 用 subtask/index.mjs:349/82 的证据补上，这是 D2 成立的真正支点。
- **接下来**：本设计落档后判断进入 task_breakdown——需求八已定"单任务交付"，故拆分为单子任务（一批文档修订 + 一次 review），等待用户授权后再 materialize/dispatch。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-08 | v1.0 | 初版：4 组 9 修订点逐文件清单 + 扫描约定 v1 + pattern 钉死；采纳 Codex 设计期三处硬化 |
| 2026-06-08 | v1.1 | task_breakdown 期采纳 Codex 派工就绪硬化：扫描块加 marker、新增钉死物件 3（标准规则句）、§五 改机器可验断言（限 11 文件 / Set 去重 / cmp / git diff / 标题锚点 rg） |

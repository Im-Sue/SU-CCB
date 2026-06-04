---
id: cmpxxyx7p1b024de1c81db492
title: "su-init 对旧项目自动生成 01_架构设计 文档"
doc_type: requirement
status: delivered
created: 2026-06-03T10:46:48.998Z
analysis_input_hash: 0ac703c1f95562c9aee2aaeadd379a49965fd6fc183a09a8efde4b6481f488b8
analysis_applied_at: 2026-06-03T10:46:48.998Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

当 su-init 检测到符合条件的旧项目（已有源码/git 历史、且 01_架构设计 下无非模板架构文档）时，在 agent 层自动扫描代码生成一份 01_架构设计 文档，作为后续 su-flow 的架构锚点；确定性 lib（initProjectScaffold）保持无 LLM 可运行不变。

## 原话（verbatim）

- 「如果当前项目是一个旧项目，那么在执行su-init的时候，应该自动去总结01_架构设计的文档出来？」
- 「直接生成到对应的01_架构设计里吧，这样人工review有问题就让他自己打开对话框再聊，没问题就当作成功了」

## 二、背景与目标

su-init 当前对旧项目只 `copyIfMissing` 一个空 `_模板_架构.md`（`lib/su-init/index.mjs:84`），不扫描源码、不生成架构正文（`:56`、`:178`）。旧项目接入 CCB 后，`01_架构设计/` 只有空模板，后续 `/ccb:su-flow` 缺少架构上下文锚点。

**目标**：su-init 检测到符合条件的旧项目时，在 agent 层自动扫描代码、总结生成一份 `01_架构设计` 文档，给后续 su-flow 提供架构锚点；契合 ADR-0037（文档驱动架构·真相源上移人读文档）。确定性 lib（`initProjectScaffold`）保持无 LLM 可运行不变。

## 三、讨论与决策

经 4 轮用户对话 + 1 轮 Codex 协商（job_9ccb9340a69e / rep_503bbee3cf8c）+ 用户拍板：

- **范围**：用户拍板「仅 01_架构设计」。架构可从代码部分推断；需求/模块规格主观性高，不自动编造。
- **落点**：用户原话「直接生成到对应的 01_架构设计 里」——直落 `docs/01_架构设计/` 真相源，不走 drafts 中转。
- **质量门**：用户拍板「人工 review 即门——有问题打开对话框再聊，没问题就当成功」。经 Codex 协商修正为「机器 eligibility gate（生成前确定性判断）+ 人工 review 提醒」，机器闸不增加用户负担。
- **多源码根处理**：用户拍板「检测到就跳过 + 提示」——源码根不单一 / 已有非模板架构 md → 不自动生成，回执提示用户手动或指定范围。
- **防下游污染**：用户拍板「frontmatter 信任标记」——`generated_by: su-init-ai` + `human_verified: false`，正文保持干净；下游 su-flow / 工具据此识别「未核实」、谨慎当锚点。

**Claude 对 Codex 协商的 4 锚点反思**：

- **我同意**：最大失效不是覆盖文件，而是错误架构以 `parseStatus=success` 进文档地图、被 su-flow 当锚点（`su-oriel/server/src/indexer/project-indexer.ts:1641/1651/1949`，indexer 健康度发现不了）；"无真实产物"应按"`01_架构设计/` 下有无非模板 `.md`（优先 `doc_type: architecture`）"判，而非固定 `架构.md`。
- **我修正**：原"人工 review 即唯一质量门"不够 → 改"机器 eligibility gate + 人工 review"；原"lib 完全不动" → lib 仍不跑 LLM，但加确定性 eligibility 检测（返回 `architectureCandidate`），避免 CLI/agent 割裂、skill 复制判定逻辑。
- **我的盲点**：架构契约本是 `split_by_part: true`（可多 part），我默认单一 `架构.md`，而本项目 SU-CCB（multirepo 四仓 + submodule）会压扁边界；"架构可从代码客观推断"过于乐观——部署拓扑 / 外部服务 / 权限模型 / 历史意图 / 未来边界推不出，AI 易把依赖清单误写成架构事实。
- **接下来**：多源码根处理 + 防下游污染已升级用户拍板（见上）；lib eligibility 接口签名、源码根判定算法、非模板 md 判定、frontmatter 字段是否进 schema 留 technical_design。

## 四、功能 / 范围

1. su-init 执行时，agent 层在 lib 三步脚手架之后新增「旧项目架构生成」步骤。
2. **机器 eligibility gate（确定性，全满足才生成）**：有源码 / git 历史；源码根单一清晰；`01_架构设计/` 下无非模板 `.md`。
3. 不满足（空项目 / 多源码根 / 已有架构）→ 跳过 + 回执提示原因。
4. 够格 → `/sc:analyze` + `/sc:index-repo` 总结；SC 不可用 → 直读 README / 入口 / 依赖兜底。
5. 按 `_模板_架构.md` 章节结构生成，frontmatter 含 `doc_type: architecture` + `updated` + `generated_by: su-init-ai` + `human_verified: false`。
6. 直落 `docs/01_架构设计/`，正文干净（不留"待校正"标注）。
7. 回执醒目提示：AI 生成、建议 review、要改直接对话说。

## 五、业务规则

- 沿用 su-init missing-only：绝不覆盖任何已存在非模板文件。
- 质量门 = 机器 gate（生成前）+ 人工 review（生成后，不阻塞，即成功）。
- 下游识别：frontmatter `human_verified: false` 表示未经人工核实，su-flow / 工具谨慎当锚点。
- lib 不跑 LLM（保持无 LLM 可运行）；正文 AI 生成在 agent 层。

## 六、边界 / 不做项

- 仅 01_架构设计，不自动生成 02_需求 / 04_模块规格 等其他文档。
- 不覆盖用户已有非模板文件。
- lib 不跑 LLM、不引入 LLM 依赖。
- 多源码根不强行揉成一篇系统架构（跳过 + 提示）。
- 不改变 `initProjectScaffold` 既有三步脚手架的确定性行为。

## 七、开放问题 / 假设

**假设**：
- 本功能仅在 Claude agent 跑 `/ccb:su-init` 时生成 AI 正文；CLI 纯跑只得 eligibility 检测结果，不生成正文。
- 不改变 `initProjectScaffold` 无 LLM 可运行属性。
- 用户接受生成后自行 review，不要求阻塞初始化。

**留给 technical_design 的设计决策（非用户拍板项）**：
- lib eligibility 接口签名（`architectureCandidate { eligible, reason, targetPath, existingArchitectureDocs }`）。
- "源码根单一 / 多源码根"的确定性判定算法。
- "非模板 `.md`"判定细节（优先 `doc_type: architecture`）。
- `generated_by` / `human_verified` 是否进 requirement / architecture frontmatter schema。
- SC 不可用兜底的最低证据要求（避免把依赖清单误写成架构事实）。

## 八、拆分预览

粗分（最终切片在 task_breakdown 节点定）：
1. **lib**：确定性 eligibility 检测（`architectureCandidate`），不跑 LLM，CLI / agent 共用。
2. **SKILL（agent 层）**：据 eligibility 决定生成；`/sc` 总结 + 兜底；按模板章节渲染；frontmatter 信任标记；回执提示。
3. **契约 / schema / 文档**：architecture frontmatter 增 `generated_by` / `human_verified`（若决定进 schema）；更新 su-init SKILL 文档。

## 九、数据(草案)

不涉及 DB schema 变更；`architectureCandidate` 为返回值 / 内存结构，不持久化。

## 十、接口(草案)

- lib/su-init 暴露 eligibility 检测结果（`initProjectScaffold` summary 增字段，或独立导出函数）。具体签名留 technical_design。

## 十一、界面 / 页面布局

无界面改动；产出为 `docs/01_架构设计/` 文档 + su-init 回执文本。

## 十二、交互 / 流程

1. 用户跑 `/ccb:su-init`。
2. lib 三步脚手架（不变）。
3. agent 调 lib eligibility 检测。
4. eligible → `/sc` 扫描总结 → 写 `01_架构设计` 文档（信任标记）→ 回执提示 review。
5. 不 eligible → 跳过 → 回执说明原因（空项目 / 多源码根 / 已有架构）。
6. 用户事后 review：有问题开对话改，没问题即成功。

## 十三、风险

- **AI 架构幻觉污染真相源**：错误架构以 `parseStatus=success` 进文档地图、被 su-flow 当锚点（最大风险）；缓解 = frontmatter `human_verified: false` + 人工 review + 机器 gate 限定低歧义场景。
- **误判源码根**：monorepo / root aggregator 误判 → 生成错误范围架构；缓解 = 多源码根跳过 + 提示。
- **SC 兜底质量**：README / manifest / 入口易把依赖清单误写成架构事实；缓解 = 兜底最低证据要求（technical_design 定）。
- **慢命令**：旧项目首次 init 变慢 / 耗 token（仅单源码根 eligible 时）。
- **治理投影滞后（本需求文档自身）**：见保真差异。

## Claude 解读

「自动总结 01_架构设计」= su-init 检测到符合条件的旧项目时，在 agent 层（非确定性 lib）用代码扫描生成一份架构文档，直落 01_架构设计 真相源，给后续 su-flow 架构锚点。关键收窄：不是无条件生成，而是受「机器 eligibility gate」约束（单源码根、无既有架构、有源码）；质量门是「机器闸 + 人工 review」，非纯人工；防污染靠 frontmatter 信任标记（`human_verified: false`）而非正文标注。lib 保持无 LLM 可运行，只加确定性 eligibility 检测。

## 歧义点

1. **「旧项目」判定（P0）**：有源码/git 但 01 无真实产物 → 够不够准？monorepo 子目录、纯文档仓误判？→ 处理：机器 eligibility gate，多源码根跳过 + 提示（用户拍板）。
2. **「无真实产物」判定（P0）**：`_模板_架构.md` vs `架构.md` 哪个算已有？→ 处理：按"01_架构设计 下有无非模板 `.md`（优先 `doc_type: architecture`）"，有则跳过 + 提示、不覆盖（Codex 修正，接受）。
3. **质量门强度（P0 · 命中必问 · 用户已拍板）**：人工 review 够不够？→ 用户拍板人工 review 即门；经协商加机器 eligibility gate 前置闸。
4. **多源码根（P1 · 命中必问 · 用户已拍板）**：本项目即 multirepo → 用户拍板「检测到就跳过 + 提示」。
5. **防下游污染（P1 · 命中必问 · 用户已拍板）**：`parseStatus=success` ≠ 架构正确 → 用户拍板 frontmatter 信任标记。
6. **实现分层（P2）**：agent 层 vs lib → lib 加确定性 eligibility 检测，正文 agent 层生成。

## 保真差异

- 用户原话「自动去总结」「没问题就当作成功」——我未按字面理解为「无条件生成 + 纯人工单门」。经 Codex 协商核验：加「机器 eligibility gate」前置（防在不合适项目瞎生成），质量门改「机器闸 + 人工 review」。这是对「自动 / 即成功」的受控收窄，依据见「三、讨论与决策」+「Claude 解读」。
- 用户原话「生成到对应的 01_架构设计 里」——落点直落真相源（忠实）；防污染改用 frontmatter 信任标记（不在正文留标注），与用户「没问题就当成功（正文干净）」一致。
- **补充**（原文未提、实测/协商存在的约束，作为设计输入，不改变需求范围）：架构契约 `split_by_part: true`（多 part）；`parseStatus=success` 不证明架构正确；代码无法推断部署拓扑/外部服务/权限/历史意图；lib 须保持无 LLM 可运行。
- **本需求文档的创建方式（治理保真）**：因 su-oriel 后端（:3030）未运行、prisma client 未 generate，本文档由 main_claude 按官方 `createRequirementMdFirst` 的 md-first 同款逻辑直接写入真相源（id 用 `generateRequirementId` 同款算法、`analysis_input_hash` 用 `hashRequirementAnalysisInput` 同款算法），status 直接置 `planning`（分析已完成）。DB 投影（`prisma.requirement`）与 journal 的 promote/analysis 事件待 indexer scan / `su-reconcile` 时自愈补登记——md 是真源，scan 反向 upsert（`project-indexer.ts:1133`）。

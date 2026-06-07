---
doc_type: technical_design
requirement_id: cmq3feiumac1ad394d74d8dbf
title: "文档可读性：落档表达规范与写路径接线 技术设计"
created: 2026-06-07
expression_spec: v1
---

# 文档可读性：落档表达规范与写路径接线 技术设计

> 一句话：写一份「AI 怎么写文档」的规范，把它接进 AI 的写路径和巡检回路 ｜ 最后更新: 2026-06-07

## 一、设计概述

**目标对齐（白话）**：

你的痛点是 AI 产的文档看不动——开篇黑话、缺图缺表、没有一段先讲「AI 理解的目标」。调研结论是：好模板早就有，但 AI 写文档时根本不读它，写完也没人检查"看不看得懂"。所以这套方案不发明新东西，只做三件事：**把规则写成一份"表达规范"**（目标对齐开头、复杂的配示例、图表优先、黑话必须解释）；**把规范塞进 AI 写文档的必经之路**（节点说明书 + 模板）；**让 Console 巡检顺手盯一眼**（缺了就亮黄灯提醒，不拦人）。对你的影响：以后每份新文档开头 10 行内能确认 AI 理解对没对；存量旧文档完全不动、不会冒出一堆警告。

| 项 | 说明 |
|----|------|
| 名称 | 落档表达规范与写路径接线 |
| 核心职责 | 让 AI 产出的需求/技术设计/开发任务文档先给人看懂，再给 agent 执行 |
| 设计原则 | 规范单一真相源（kernel）；接线优于发文；软提醒不阻断；存量零打扰（rollout gate） |
| 需求来源 | `docs/02_需求设计/优化-关于需求分析-技术设计文档的可读性和直观性优化-4d8dbf-需求.md` |
| 覆盖范围 | 表达规范 reference、3 份模板补强、4 个节点 manifest 接线、Console 巡检表达检查、本项目 wiring 修复 |
| 不覆盖 | mermaid/UI 渲染改造；存量 35 份技术设计与已分析需求的回填；Console 骨架 13 章标题集与 5 投影锚点（零 schema 变更）；写入硬校验 |

## 二、方案与架构

```
            ┌─ 真相源（新增，PR1）──────────────────────┐
            │ references/kernel/document-expression-spec.md │
            │ R1-R6 规则 + doc_type 应用矩阵 + 豁免语义      │
            └────────┬──────────────────────────────────┘
        ┌────────────┼────────────────┐
        ▼            ▼                ▼
 ① 节点接线(PR1)   ② 模板补强(PR2)    ③ 软质量门(PR3, Oriel)
 分析/设计/拆分      _模板_需求         template-conformance:
 manifest: 落档前    _模板_技术设计      + expressionIssues(新类)
 必读模板+规范       _模板_开发任务      + placeholder 残留检查
 review: +3 审查项   (目标对齐+示例块)   + gate: expression_spec:v1
        │            │                ▲
        ▼            ▼                │ 仅新文档
     AI 落档产物（frontmatter 带 expression_spec: v1）
     requirement bodyMarkdown / technical_design 全文 / dev_task spec

 ④ 本项目 wiring 一次性修复(PR4)：契约三副本同步 + 9 份模板进 docs/
   + Console 骨架 13 空标题各注入一行📌短指引
```

| 关键原则 | 为什么 |
|----------|--------|
| 接线优于发文 | 规范不进写路径就是废纸——manifest 是 AI 写文档时实际消费的 prompt 真相源 |
| rollout gate（标记驱动） | 存量 35 份技术设计 + 存量已分析需求按新标准全不达标；只查带 `expression_spec: v1` 的新文档，历史零噪音 |
| 软提醒不阻断 | 防"为过校验画无意义图"的形式主义；真正的质量门是 review 节点的 AI 审查项 |
| 确定性检查 | 巡检只做字面标记/占位残留等机械检查，不做 LLM 评分（成本/不确定性） |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 不碰什么 |
|----------|----------------|----------|
| plugin kernel references | 新增 1 份规范 + 改 4 个 node manifest + README 索引 | manifest schema、transition/guard 表 |
| plugin templates | 3 份模板加目标对齐/示例占位块 | 模板文件名、章节标题集 |
| plugin lib (requirement-analysis) | applyRequirementAnalysis 写 frontmatter 时附加 `expression_spec: v1` | bodyMarkdown 校验逻辑、锚点替换语义 |
| su-oriel indexer | conformance 扩展 + 骨架指引注入 + default 契约副本同步 | 13 章标题集、5 投影锚点、parseRequirementSections、reindex 硬校验 |
| 本项目 docs/.ccb | 契约定向 merge（补 8 个 template 行 + consumers 段，保留 `config/` 行） | 项目其余契约定制 |

## 三、关键决策与取舍

- **rollout gate 用统一 frontmatter 标记**：选 `expression_spec: v1`（两类文档统一），因为存量零打扰、自文档化、与 `analysis_input_hash` 同路径写入。没选 Codex 初提的 requirement 用 `analysis_input_hash` gate——存量已分析需求全有该字段，会产生同样的警告积压；没选全量回查——35 份历史警告即时噪音化。
- **warning 拆类**：conformance 结果分 `missingSections`（旧）与 `expressionIssues`（新），因为消费方需要区分"缺章节"和"缺表达"两种严重度。没选塞同一数组——语义混淆。
- **placeholder 残留检查纳入**（Codex 建议，采纳）：非模板文档不得残留 `[占位]` / `<由系统生成>`，因为"复制了模板没填"是真实失败模式且检查零成本。
- **技术设计目标对齐放「一、设计概述」首块**（协商收敛）：保留独立叙事段（表格行承载不了"让人确认理解"），但锚进章节内、表格前——H2 前游离 preamble 有孤儿感且对标题切分工具不友好。极小设计允许一行白话（复杂度自适应下限）。
- **本项目 wiring 由实施子任务直接做**：没选走 su-reconcile——这是一次性已知修复，不是漂移巡检场景。
- **规范命名 `document-expression-spec.md`**，落 `references/kernel/` 顶层（与 must-ask-checklist.md 同级同模式）。
- **被拒方案汇总**：scan 内 LLM 评分（成本/不确定）；写入硬校验阻断（已拍板否决）；动 13 章标题集/锚点（已拍板否决）；mermaid 管线（UI 不渲染，独立需求）；expression-spec 放项目 docs/（kernel 才是 prompt 真相源）；模板内容内嵌 manifest（重复真相源）。
- **AI 自决 vs 用户授权**：自决——标记字段名/警告分类/指引措辞/测试组织（均为内部约定，additive，本文档可见可审）；已授权——范围四块（需求拍板 2026-06-07）；无新增用户授权事项（零依赖、零 DB schema、零公共 API 变更）。

## 四、核心流程 / 逻辑

**端到端走查示例**（一个新需求从创建到审查，四处改动如何接力）：

```
用户在 Console 新建需求「给报表加导出」
  → Console 生成骨架：13 空标题，每章带一行📌短指引          [改动④骨架注入]
用户触发分析
  → Claude 进 requirement_analysis 节点
  → manifest 要求：落档前读 _模板_需求.md + 表达规范          [改动①接线]
  → bodyMarkdown 落档：「二、背景与目标」首块 = 目标对齐白话
     + 模拟示例（或显式「无需示例，因为只是单表导出」）        [改动②模板范式]
  → applyRequirementAnalysis 附写 expression_spec: v1        [改动②lib]
Console 巡检（定时/手动 scan）
  → conformance：旧检查照跑；新表达检查仅对带标记文档启用      [改动③gate]
  → 缺「目标对齐」→ SyncJob expressionIssues 黄灯，不拦      [改动③软门]
进入 review 节点
  → checklist 增 3 项：目标对齐能秒懂吗 / 示例有或豁免合理吗
     / 黑话首现解释了吗                                      [改动①审查门]
```

| 处理规则 | 说明 |
|----------|------|
| gate 语义 | frontmatter `expression_spec: v1` 存在 → 启用表达检查；缺失 → 只跑旧检查（存量行为不变） |
| requirement 表达检查 | 正文含「目标对齐」；含「模拟示例」或「无需示例」 |
| technical_design 表达检查 | 同上两项（标记须在正文区出现） |
| placeholder 检查 | 非 `_模板_*` 文档含 `[占位]`、`<由系统生成>` → expressionIssues |
| dev_task | 本轮不查（轻改范围）；spec_section_md 表达由 task_breakdown manifest 接线约束 |
| 豁免语义 | 「无需示例，因为…」「无需图，因为…」是合法满足，审查看理由实质 |
| 幂等/失败 | conformance 纯函数无状态；scan 失败不影响文档解析与状态投影（沿用现有 SyncJob partial 通道） |

## 五、测试策略

- [ ] plugin：su-init scaffold 测试（新模板块复制、copyIfMissing 幂等）；applyRequirementAnalysis 写标记的单测（新分析带标记、重放幂等、旧文档不回写）
- [ ] su-oriel：conformance 矩阵单测（gate 开/关 × 三类检查 × 命中/豁免/残留）；renderRequirementMarkdown 骨架快照更新；parseRequirementSections roundtrip 回归（指引行不破坏 5 锚点提取）；targeted reindex 对 `_模板_*` 文件行为测试（占位 requirement_id 不误匹配）；frontmatter 未知字段容忍测试
- [ ] 本项目：契约 merge 后 `loadDocsStructureContract` 校验通过 + `resolver.templateFor` 断言；Console rescan 无新警告
- [ ] dogfood 验收：下一个真实需求用新规范走分析→设计全程，用户能看懂为验收口径（本设计文档与 4d8dbf 需求文档即首批样张）

## 六、数据设计

无 DB schema 变更。两个内部约定形状：

| 约定 | 形状 | 性质 |
|------|------|------|
| frontmatter 标记 | `expression_spec: v1`（可选字段，requirement / technical_design） | additive，must_have 不变，旧解析器容忍 |
| SyncJob metadata | `templateConformance[].expressionIssues: string[]`（与 missingSections 并列） | 自由 JSON 内部形状，additive |

## 八、文件结构 / 变更清单

**PR1 kernel 规范与接线（plugin 仓）**
- `[NEW] references/kernel/document-expression-spec.md`：R1-R6 + 应用矩阵 + 豁免语义 + d21ff1 before/after 微例（~150 行）
- `[MODIFY] references/kernel/nodes/requirement_analysis.node.md`：②增"bodyMarkdown 按 _模板_需求.md 主体章节组织 + 遵守表达规范"；③完成条件、自检清单各加对应项
- `[MODIFY] references/kernel/nodes/technical_design.node.md`：②.9 补表达规范引用 + 首屏目标对齐 + 端到端示例要求
- `[MODIFY] references/kernel/nodes/task_breakdown.node.md`：spec_section_md 遵守表达规范（一行）
- `[MODIFY] references/kernel/nodes/review.node.md`：checklist 增 3 项表达审查
- `[MODIFY] references/kernel/README.md`：索引加一行

**PR2 模板与 lib（plugin 仓）**
- `[MODIFY] templates/docs/02_需求设计/_模板_需求.md`：「二、背景与目标」内增目标对齐 + 模拟示例占位块（粗体块，不加 ## 标题）
- `[MODIFY] templates/docs/03_开发计划/_模板_技术设计.md`：「一、设计概述」表前增目标对齐叙事块；「四、核心流程」指引补端到端示例；frontmatter 示例加 `expression_spec: v1`
- `[MODIFY] templates/docs/03_开发计划/_模板_开发任务.md`：「一、任务概述」表上方补白话概述占位（轻）
- `[MODIFY] lib/requirement-analysis/index.mjs`：applyRequirementAnalysis 附写 `expression_spec: v1`

**PR3 巡检与骨架（su-oriel 仓）**
- `[MODIFY] server/src/indexer/template-conformance.ts`：expressionIssues 检查 + placeholder 残留 + `expression_spec: v1` gate
- `[MODIFY] server/src/indexer/project-indexer.ts`：骨架 13 空标题逐章一行📌指引（常量表）；export 共用自动一致
- `[MODIFY] server/.../default-docs-structure-contract.yaml`：补 template 行（第三处契约副本同步）
- `[MODIFY]` 相关测试：conformance fixtures、骨架快照、roundtrip、模板文件 reindex 行为、frontmatter 容忍

**PR4 本项目 wiring（本仓 docs，一次性）**
- `[MODIFY] docs/.ccb/docs-structure-contract.yaml`：定向 merge 8 个 template 行 + consumers 段（保留 `config/` 行）
- `[NEW] docs/**/_模板_*.md`：scaffold 复制 9 份
- 验收：Console rescan + dogfood

## 九、依赖与配置

零新依赖。无新配置 key（gate 由文档自带标记驱动，不引入全局开关）。

## 十、迁移影响与风险

- **受影响**：仅新产出文档与巡检警告面；存量文档、状态机、投影锚点零变更
- **打法**：PR1/PR2（plugin）→ PR3（Oriel）→ PR4（本项目 wiring + 验收）；PR1-PR3 可并行开发、PR4 依赖前三
- **回滚**：规范/模板/manifest 为纯文档改动，git revert 即回；conformance 扩展按 gate 隔离，revert 后存量行为本就未变

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 字面标记被形式主义满足（写四个字就过） | 中 | 表达仍差 | scan 只是黄灯；真门是 review 节点 3 项审查 + 用户 dogfood 验收 |
| 三处契约副本再漂移 | 中 | 新旧项目行为分裂 | PR3 把 Oriel default 副本纳入同步；升级说明记录三副本清单 |
| 模板复制进 docs/ 被局部 reindex 误读 | 低 | 占位 id 误匹配 | 主扫描已跳过 `_模板_*`；PR3 补 targeted reindex 行为测试 |
| frontmatter 新字段兼容性 | 低 | 解析失败 | YAML 自由字段 + must_have 不变；PR3 容忍测试锁定 |
| 指引行变噪音墙 | 低 | 骨架可读性反降 | 每章一行、短句；不搬完整模板内容 |

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-07 | v1.0 | 初版。一轮 Codex 协商（job_69a741aea1fe）收敛：rollout gate 统一标记、warning 拆类、placeholder 检查纳入、目标对齐锚进概述节、三契约副本同步、4 PR 拆分 |

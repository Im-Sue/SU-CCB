---
id: cm6241561f52fc0d749mgsync
title: 优化：节点产物即时落 commit + 合并洁净度按需求隔离 + 设计稿/ADR 进 allowlist
doc_type: requirement
status: drafting
created: 2026-06-08T07:42:15.103Z
expression_spec: v1
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

# 优化：节点产物即时落 commit + 合并洁净度按需求隔离 + 设计稿/ADR 进 allowlist 需求设计

> 一句话：让多个需求并行时合并不再互相挡——产物及时落 commit、合并洁净度按需求隔离、设计稿/ADR 纳入 canonical-sync 名单 ｜ 最后更新: 2026-06-08

> **状态(frontmatter `status`)**：本档为**立项注册**，status=`drafting`；完整需求分析待 requirement_analysis 节点产出。

---

## 需求描述

CCB 自治批次跑到「合并预览」(`mergeRequirementWorktree` → `canonicalSyncCommit`) 时，会因主仓 `docs/` 工作区不干净而 escalate `canonical_dirty_outside_allowlist`，导致并行的多个需求在合并这一步互相挡。实证：req vlr74b 实施/审查/归档全过，唯独合并被另外 6 个其它需求的未提交文档 + 1 个经验沉淀档 + 本需求自己的技术设计稿挡住。

根因有两层：①**没有「节点产物即时落 commit」的环节**——需求档/设计稿/任务档从生成起一直是未提交状态，要拖到各自需求走到合并那步才被顺带提交；而合并前的洁净度检查是**全局严格**的（要求整个 `docs/` 除当前需求白名单外一律干净），却只会自动提交当前需求那一小片 → 多需求并行必然互相挡。②**canonical-sync 的 allowlist 漏了 `technical_design`（疑似连 ADR 也漏）**——只收了需求档(02)、开发任务档(03 dev_task)、文档地图、journal、worktree 台账、拆分草案；设计稿不提交就被当「不明脏文件」挡合并。

目标：让需求级合并不受其它并行需求的未提交产物影响，且本需求自己的全部 canonical 产物（含设计稿/ADR）能被正确收拢提交，使 autonomous-batch 能顺畅推进到 merged 预览。

---

## 原话（verbatim）

> 所以我理解一下，现在的问题是：1. plugin没有处理根目录的docs主仓多需求文档创建、操作的逻辑？ 2. plugin的机制里缺少了"技术设计稿"的收拾名单？

> 提个立项需求

（背景对话：本需求源于 req vlr74b autonomous-batch 合并阶段的 `canonical_dirty_outside_allowlist` escalation；上述两点是用户对根因的复述确认，用户随即指示立项。）

---

## 二、背景与目标

**目标对齐**：现在多个需求的文档都堆在同一个主仓 `docs/` 里、长期不提交；等某个需求要「合并」时，系统先要把现场收拾干净，但它一看到别的需求、甚至自己的设计稿没保存，就判定"现场乱"拒绝合并。本需求要把这个卡点解决：合并只该关心"我这个需求自己的东西干不干净"，并且要能把本需求的全部产物（含设计稿）正确提交。

- **背景（实证锚点）**：req vlr74b（2026-06-08）autonomous-batch — 实施(plugin `5c10c92` / root `4f5c6c9`)、审查(5 条机器验收全过)、归档(dev_task 终态)均成功；`mergeRequirementWorktree` escalate `canonical_dirty_outside_allowlist`，porcelain 列出 6 个其它需求档 + 1 经验档 + 本需求设计稿。
- **目标**：
  1. 合并洁净度判断**按需求隔离**：其它需求的未提交产物不应阻塞当前需求合并。
  2. 本需求 canonical 产物**完整可落档**：`technical_design`（及 ADR 等）纳入 canonical-sync allowlist，或由"节点产物即时落 commit"覆盖。
  3. 多需求并行场景下 autonomous-batch 能顺畅到 merged 预览，不需人工先清树。

---

## 四、功能 / 范围（候选方向，细化移交技术设计）

| 方向 | 说明 |
|------|------|
| F1 节点产物即时落 commit | 在 requirement_analysis / technical_design / task_breakdown / materialize 等节点产出 canonical 文档后，及时提交，避免长期未提交堆积（落点/粒度/commit 信息待设计） |
| F2 合并洁净度按需求隔离 | `canonicalSyncCommit` 的 dirty 判断只针对"当前需求 allowlist 涉及的文件 + 真正会冲突的文件"，其它需求的未提交产物不触发 `canonical_dirty_outside_allowlist`（隔离边界/安全性待设计） |
| F3 allowlist 补全 | 把 `technical_design`（及 ADR 等需求绑定 canonical 文档）纳入 `canonicalSyncAllowlist`（lib/worktree/index.mjs:309） |

> F1 与 F2/F3 可能部分互斥或互补（若 F1 让产物始终已提交，F2/F3 的压力大减）；最优组合在技术设计阶段权衡。

---

## 六、边界 / 不做项

- 本档仅**立项注册**；具体方案、取舍、影响面在 requirement_analysis / technical_design 节点产出，不在本档拍实现。
- 不在本档承诺改动具体文件清单或代码（涉及 `lib/worktree/index.mjs` 等，需技术设计确认）。
- 不回溯处理已堆积的存量未提交文档（那是一次性运维清理，单独处理）。

---

## 七、开放问题 / 假设

> 以下为**移交需求分析 / 技术设计**的技术项，非待用户拍板项（按 vlr74b 已落地的闭环规则，不在正式档留"待用户××"）。

- F1 vs F2/F3 的取舍与组合（移交技术设计）。
- F2 的"按需求隔离"如何既隔离又保留"拒绝合并进脏树"的安全意图（移交技术设计）。
- allowlist 是否还漏其它需求绑定 canonical 类型（如 ADR、模块规格）（移交需求分析核验）。

**假设**：根因诊断（两层缺口）已由 vlr74b 实证 + 读码（`canonicalSyncCommit`/`canonicalSyncAllowlist` lib/worktree/index.mjs:360/309）确认。

---

## Claude 解读

本档为立项注册，完整分析（歧义扫描、Codex 协商、必问项、范围非锚定核验）待 requirement_analysis 节点。已知根因两层：①缺"节点产物即时落 commit"+ 合并洁净度全局严格 → 并行需求互相挡；②canonical-sync allowlist 漏 technical_design。候选修复 F1/F2/F3 见四。

## 歧义点

待 requirement_analysis 节点产出（本档为立项注册，分析未跑）。当前已识别的技术决策点见「七、开放问题」，均为移交技术节点的技术项，无遗留待用户拍板项。

## 保真差异

用户原话为对根因的两点复述确认 + 「提个立项需求」指示。需求主体的技术诊断（两层根因、F1/F2/F3 方向、lib 锚点）来自本会话 req vlr74b autonomous-batch 的实证与读码分析，用户已逐条理解并确认后指示立项；方向与用户复述一致，无扩大解释。

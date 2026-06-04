---
doc_type: dev_task
task_id: subtask-bad0af873c0d
title: su-init SKILL 旧项目架构生成步骤（agent 规程）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxxyx7p1b024de1c81db492
section_id: pr2-su-init-arch-skill-generation
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-5b8effac4287]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxxyx7p1b024de1c81db492.json
source_draft_hash: ce6b5a6109da2c4f342416732bf0faaebe0f8f0441b247680e1bc65b678c75d8
created_at: 2026-06-03T14:46:59.553Z
updated_at: 2026-06-03T15:17:39.009Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxxyx7p1b024de1c81db492","branch":"ccb/req-cmpxxyx7p1b024de1c81db492"}
---

# su-init SKILL 旧项目架构生成步骤（agent 规程）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | SKILL 新增旧项目架构生成步骤：据 architectureCandidate 分支，含证据门槛、信任标记、exclusive-create 防覆盖、回执。 |
| 需求来源 | cmpxxyx7p1b024de1c81db492 |
| 本期范围 | pr2-su-init-arch-skill-generation · su-init SKILL 旧项目架构生成步骤（agent 规程） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### pr2 su-init SKILL 旧项目架构生成步骤（agent 可执行规程）

#### 任务概述
在 `skills/su-init/SKILL.md` 新增「旧项目架构生成」步骤，规定 agent 据 pr1 的 `architectureCandidate` 决定是否生成架构文档，含证据门槛、信任标记、防覆盖与回执。**这是 agent 可执行规程（prose），非新增可单测代码**；验证靠场景走查 + pr1 的 lib 单测兜底。

#### 任务分解
- 读 `summary.architectureCandidate` 分支：`eligible=false` → 不生成 + 回执说明 `reason`（no_source / multiple_source_roots / architecture_exists）；`eligible=true` → 进证据门槛。
- 证据门槛（agent 层判断，`evidence_insufficient` 不进 lib enum）：能拿到目录树 + ≥1 grounding 源（README / 依赖 manifest / 入口文件 其一）+ 至少可填「概述 / 技术栈 / 项目结构 / 核心模块·入口」四块；否则跳过 + 回执 `evidence_insufficient`（证据不足、建议手写）。
- 够格 → 优先 `/sc:analyze` + `/sc:index-repo`；不可用 → 兜底直读 README / 入口 / 依赖 manifest。按 `_模板_架构.md` 章节渲染：只填**有据**章节（技术栈←manifest、结构←目录树、核心模块←顶层目录+入口 import 并标 inferred、概述←README）；**省略**推不出的章节（部署拓扑 / 外部服务 / 权限模型 / 关键数据流 / 历史意图），正文不写 TODO / 待校正 hedge。
- frontmatter 写 `doc_type: architecture` + `updated` + `generated_by: su-init-ai` + `human_verified: false`，**不写** `status`。
- **写盘前**：直接 `import` lib 的 `detectArchitectureCandidate`（不经 init.mjs）做二次检测；若不再 `eligible` → 按最新 `reason` 跳过、不写。
- **写入**：用 final path `writeFile(architectureCandidate.targetPath, content, { flag: "wx" })`（或 `open(targetPath, "wx")`）独占创建——**禁用** `safeWriteFile` 类 temp+rename helper（其 final rename 可能覆盖竞态文件）；`EEXIST` → 放弃 + 回执提示。
- 回执醒目提示：AI 生成 · 建议 review · 要改直接对话；并列 **evidence sources 摘要**（用了哪些证据 / 为何生成；`evidence_insufficient` 时列缺哪类证据），方便人工判断。

#### 验收标准（场景走查，非单测）
- [ ] `eligible=false`（空 / 多根 / 已有架构）→ 不生成，回执准确说明 `reason`。
- [ ] 证据不足 → 跳过，回执 `evidence_insufficient` 且列缺哪类证据。
- [ ] 够格 + 证据够 → 生成文档：含 4 个信任/必填 frontmatter 字段、**不含** `status`、未证实章节被省略、回执提示 review 且列 evidence sources。
- [ ] 架构目录已有非模板 `.md` / 目标文件已存在 → 不覆盖（final `wx` + 写前二次检测生效，`EEXIST` 放弃）。
- [ ] 写前二次检测发现不再 `eligible` → 按最新 reason 跳过、不写。
- [ ] SC 不可用时兜底仍遵守「只写有据、不编造」。

#### 边界 / 不做项
- 不改 `initProjectScaffold` 三步脚手架；不生成 02_需求 / 04_模块规格 等其它文档。
- 不做下游 su-flow / indexer 消费 `human_verified` 的接线（未来工作）。
- 不新增 breakdown draft / dev_task frontmatter 字段。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-5b8effac4287
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-03 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpxxyx7p1b024de1c81db492
- Section: pr2-su-init-arch-skill-generation
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-5b8effac4287

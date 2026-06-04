---
doc_type: dev_task
task_id: subtask-5b8effac4287
title: su-init 架构生成 eligibility 检测（确定性 lib）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxxyx7p1b024de1c81db492
section_id: pr1-su-init-arch-eligibility-lib
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxxyx7p1b024de1c81db492.json
source_draft_hash: ce6b5a6109da2c4f342416732bf0faaebe0f8f0441b247680e1bc65b678c75d8
created_at: 2026-06-03T14:46:59.553Z
updated_at: 2026-06-03T15:10:09.588Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxxyx7p1b024de1c81db492","branch":"ccb/req-cmpxxyx7p1b024de1c81db492"}
---

# su-init 架构生成 eligibility 检测（确定性 lib）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 确定性 lib(无 LLM)加架构生成够格检测，CLI/agent 共用，结果随 initProjectScaffold summary 与 CLI stdout 暴露。 |
| 需求来源 | cmpxxyx7p1b024de1c81db492 |
| 本期范围 | pr1-su-init-arch-eligibility-lib · su-init 架构生成 eligibility 检测（确定性 lib） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### pr1 su-init 架构生成 eligibility 检测（确定性 lib）

#### 任务概述
在确定性 lib（无 LLM）加「旧项目架构生成够格」检测，CLI 与 agent 共用同一判定；结果随 `initProjectScaffold` summary 与 CLI stdout 暴露。这是后续 agent 层生成（pr2）的判定地基。

#### 任务分解
- `lib/su-init/index.mjs`：导出 `detectArchitectureCandidate({ projectRoot, resolver })`，返回 `{ eligible, reason, targetPath, sourceRoots, existingArchitectureDocs }`，`reason ∈ {eligible, no_source, multiple_source_roots, architecture_exists}`。算法：
  1. **递归**扫 resolver 定位的架构目录（当前 `docs/01_架构设计/`）下非 `_模板_` 前缀 `.md`（对齐 indexer `isTemplateMarkdownFile`），非空 → `architecture_exists`（`existingArchitectureDocs` 填命中相对路径）。
  2. monorepo 信号（`.gitmodules` / `pnpm-workspace.yaml` / `lerna.json` / `nx.json` / `turbo.json` / `go.work` / `package.json#workspaces` / `Cargo.toml#[workspace]`）任一命中 → `multiple_source_roots`。
  3. depth ≤ 3、跳过 ignore 目录（`node_modules .git dist build vendor .venv target .next coverage tmp .tmp examples fixtures testdata docs .ccb .claude`）后统计含 marker（`package.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle composer.json Gemfile *.csproj`）的目录；`markerDirs ≥ 2`（含 root marker + 子目录 marker 的 root-aggregator）→ `multiple_source_roots`。
  4. `hasSource = markerDirs ≥ 1 || 源码文件数 ≥ 3`（**裸 `.git` 不算**有源）。源码扩展名清单：`.js .mjs .cjs .ts .tsx .jsx .py .go .rs .java .kt .rb .php .c .cc .cpp .h .hpp .cs .swift .scala .sh`。`!hasSource` → `no_source`。
  5. 余下 → `eligible`；`targetPath` = 架构目录 + `<sanitize(basename(projectRoot))>-架构.md`（sanitize：小写、非字母数字转 `-`、去首尾 `-`），返回 **concrete 路径**（不留占位 pattern），对齐现存 `su-oriel-后端架构.md` 命名惯例。
  在 `initProjectScaffold` 末尾调用，挂 `summary.architectureCandidate`。
- `skills/su-init/scripts/init.mjs`：`[CCB_SU_INIT_COMPLETED]` 输出 JSON 增 `architectureCandidate` 字段（CLI 可见性）。
- `lib/su-init/__tests__/`：新增 `detectArchitectureCandidate` 单测。

#### 验收标准
- [ ] 单测向量绿：空项目 / 裸 git 空仓 → `no_source`；单 `package.json` → `eligible`；**marker-less 但有 ≥3 源码文件 → `eligible`**；`frontend/`+`backend/` 双 marker / 有 `.gitmodules` / **root marker + 子目录 marker** → `multiple_source_roots`；架构目录有非模板 `.md`（含嵌套子目录）→ `architecture_exists`；仅 `_模板_架构.md` → 不误判为已有。`eligible` 时 `targetPath` 为 concrete 文件路径。
- [ ] `initProjectScaffold` summary 含 `architectureCandidate`，既有三步脚手架行为无回归（既有测试绿）。
- [ ] CLI：`node --test su-ccb-claude-plugin/lib/su-init/__tests__/su-init.test.mjs` 绿；`node su-ccb-claude-plugin/skills/su-init/scripts/init.mjs --project-root <tmp>` 的 `[CCB_SU_INIT_COMPLETED]` JSON 含 `architectureCandidate`。
- [ ] 对 SU-CCB 自身跑 → `multiple_source_roots`（有 `.gitmodules`）。

#### 边界 / 不做项
- 不跑 LLM、不引入新运行时依赖、不动三步脚手架既有确定性行为。
- 不写架构正文（属 pr2）。
- 不改 `docs-structure-contract.yaml`（Codex 复查后放弃 `may_have`；Console 侧另有 `default-docs-structure-contract.yaml` 第三副本，技术设计/本任务均不再声称无 Console fallback 副本，见技术设计 v1.1）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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
- Section: pr1-su-init-arch-eligibility-lib
- Owner: ccb_codex
- Priority: high
- Dependencies: none

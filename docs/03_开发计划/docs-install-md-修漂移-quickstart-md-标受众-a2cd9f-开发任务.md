---
doc_type: dev_task
task_id: subtask-4582e5a2cd9f
title: docs/install.md 修漂移 + quickstart.md 标受众
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
section_id: pr6-succb-docs-driftfix
order: 6
implementation_owner: ccb_codex
dependencies: [subtask-ed5c47101157, subtask-254a2416ee6a, subtask-0e918c1f75fd]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq7z6fmcdd8e3116c6ffc5ff.json
source_draft_hash: c1af8933a6068ea84d3503accd2515ba28eba26d1afdb466f7331f4cebf57756
created_at: 2026-06-10T15:50:25.604Z
updated_at: 2026-06-10T16:26:27.275Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq7z6fmcdd8e3116c6ffc5ff","branch":"ccb/req-cmq7z6fmcdd8e3116c6ffc5ff"}
---

# docs/install.md 修漂移 + quickstart.md 标受众

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | install.md 删 apps/ccb-console 改 multi-repo、版本链 pr4、解释 pr5;quickstart 标受众+链评估者 |
| 需求来源 | cmq7z6fmcdd8e3116c6ffc5ff |
| 本期范围 | pr6-succb-docs-driftfix · docs/install.md 修漂移 + quickstart.md 标受众 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 一、任务概述

修掉 SU-CCB 两份过时文档:`docs/install.md` 还按老单仓 `apps/ccb-console/` 布局写(照做即失败),`docs/quickstart.md` 演示开发者协作闭环却没标受众。install 改对 multi-repo 现实、版本口径链接 pr4 版本表、解释 pr5 脚本边界;quickstart 标注受众=开发者 + 首屏链接 pr3 评估者路径。纯文档。

### 二、任务分解

- `docs/install.md`:
  - 删所有 `apps/ccb-console/` 路径,改 `su-oriel/`(控制台)、`su-ccb-claude-plugin/references/kernel/`(内核);删根目录 `pnpm install`/`pnpm -r build` 假设(根仓无 pnpm 工程,只 su-oriel/ 内有)。
  - 版本要求改为**链接 pr4 顶层版本表**(不再各写数字,消除 3.8 vs 3.10 不一致)。
  - 接入并解释 pr5 `check-prerequisites.sh` 的新输出边界(自动可验 vs 仅提示)。
- `docs/quickstart.md`:
  - 顶部标注"受众=开发者(演示 spec→review→execute→archive 协作闭环)"。
  - 首屏加一句链接到 pr3 SU-Oriel README 的"评估者 5 分钟"路径。
  - 修正其中根目录 `references/kernel` / 根 pnpm 旧路径假设。

### 三、验收标准

- [ ] `rg 'apps/ccb-console' docs/install.md docs/quickstart.md` 0 命中。
- [ ] install.md 版本要求是链接 pr4 版本表,不再硬写数字。
- [ ] quickstart.md 有受众标注 + 评估者路径链接(非死链)。

### 四、边界 / 禁止

- 只改 `docs/install.md` 与 `docs/quickstart.md`。不改协作闭环 quickstart 的演示语义(只标受众 + 修路径)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-ed5c47101157, subtask-254a2416ee6a, subtask-0e918c1f75fd
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-10 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq7z6fmcdd8e3116c6ffc5ff
- Section: pr6-succb-docs-driftfix
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-ed5c47101157, subtask-254a2416ee6a, subtask-0e918c1f75fd

---
doc_type: dev_task
task_id: subtask-da3f8bd7d9a5
title: ADR-0043 合并洁净度安全模型修订留档 + ADR-0036 amended_by 指针
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cm6241561f52fc0d749mgsync
section_id: pr3-adr-0043-clean-gate-amendment
order: 3
implementation_owner: claude
dependencies: [subtask-92174773fd31, subtask-0efbf617a178]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cm6241561f52fc0d749mgsync.json
source_draft_hash: cf45558c4df36c2c8cbd8388d2f1db57dc99285282d6a279f0cf6d7bf46225e7
created_at: 2026-06-10T04:51:50.673Z
updated_at: 2026-06-10T05:54:16.521Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cm6241561f52fc0d749mgsync","branch":"ccb/req-cm6241561f52fc0d749mgsync"}
---

# ADR-0043 合并洁净度安全模型修订留档 + ADR-0036 amended_by 指针

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新建 ADR-0043 记录 clean-gate 从全局严格改为按需求隔离+有界容忍+主仓写锁（含否决项、已知残留、F1 延期拍板）；ADR-0036 frontmatter 加一行 amended_by: ADR-0043，结论原文零改动。Claude 直写（<200 行），依赖 pr1+pr2 定稿形态。 |
| 需求来源 | cm6241561f52fc0d749mgsync |
| 本期范围 | pr3-adr-0043-clean-gate-amendment · ADR-0043 合并洁净度安全模型修订留档 + ADR-0036 amended_by 指针 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### 任务概述

把这次"合并洁净度安全模型"的修订写成正式决策记录（ADR-0043），并在被修订的 ADR-0036 上留一行指针。背景：ADR-0036（per-需求实施 worktree）当年明确选了"合并前主仓必须全局干净"；本需求把它改成"按需求隔离 + 有界容忍 + 主仓写锁"。改安全模型必须留档，否则后人读 0036 会按旧规矩理解 merge gate。

> 术语白话：ADR＝架构决策记录，一事一档、定稿后不改写结论，只能被新 ADR 修订（amend）或取代（supersede）。

### 任务分解

1. 新建 `docs/06_决策记录/ADR-0043-合并洁净度按需求隔离与主仓写锁.md`（<200 行，Claude 直写）：
   - 背景：vlr74b 实证的并行互挡 + allowlist 漏 technical_design。
   - 决策：三态 classifier（OWN/TOLERATE/FOREIGN，边界同技术设计）+ withCanonicalRepoLock（`.ccb/locks/canonical-repo`）+ tolerated_paths 诊断；F1（节点产物即时落 commit）拆后续需求（用户 2026-06-09 拍板"先做1"）。
   - 否决项：blanket 容忍全 docs；ADR 按 related_doc 反查入 allowlist（现有 parser 不支持多行数组，留 F1/后续）；本需求一并做 F1。
   - 后果：已知残留——新建无绑定常青档仍挡合并，人工提交过渡，F1 根治。
   - 引用：需求档 mgsync、技术设计 td-mgsync、ADR-0036、协商 job_121967901242 / job_44bfe8f2a115。
2. `ADR-0036` frontmatter 加一行 `amended_by: ADR-0043`（不改其结论原文）。

### 验收标准

1. ADR-0043 落 `docs/06_决策记录/`，frontmatter 含 id / doc_type: adr / status，全文 <200 行。
2. 三态边界、锁、残留取舍、F1 延期与用户拍板均有记录；引用齐全。
3. ADR-0036 仅新增 amended_by 指针一行，结论原文零改动。

### 边界 / 不做项

- 不改 0036 正文结论；不在 ADR 里重复搬技术设计细节（链接即可）；不写实施代码。

> 来源：Codex 协商 job_44bfe8f2a115 G6（新 ADR 而非改写历史决策）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-92174773fd31, subtask-0efbf617a178
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

- Requirement: cm6241561f52fc0d749mgsync
- Section: pr3-adr-0043-clean-gate-amendment
- Owner: claude
- Priority: medium
- Dependencies: subtask-92174773fd31, subtask-0efbf617a178

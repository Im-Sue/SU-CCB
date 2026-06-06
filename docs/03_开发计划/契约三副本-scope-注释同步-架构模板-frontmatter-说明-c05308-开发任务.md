---
doc_type: dev_task
task_id: subtask-a98c5fc05308
title: 契约三副本 scope 注释同步 + 架构模板 frontmatter 说明
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq23elzh081b0a36b7726299
section_id: pr2-contract-template
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq23elzh081b0a36b7726299.json
source_draft_hash: 8add95651043c40293f36ec706b1a665b1a49224a347aa24d037d06a90ca79de
created_at: 2026-06-06T12:19:20.972Z
updated_at: 2026-06-06T12:57:38.078Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq23elzh081b0a36b7726299","branch":"ccb/req-cmq23elzh081b0a36b7726299"}
---

# 契约三副本 scope 注释同步 + 架构模板 frontmatter 说明

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | plugin canonical / 项目副本 / Oriel fallback 三份契约加逐字一致的注释级 scope 声明;模板加两字段可选说明+inline list 提示;su-oriel 子仓只 stage 目标文件、不 push、gitlink 留合并流程。 |
| 需求来源 | cmq23elzh081b0a36b7726299 |
| 本期范围 | pr2-contract-template · 契约三副本 scope 注释同步 + 架构模板 frontmatter 说明 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
scope 元数据声明面落地:契约三副本同步注释级 scope 字段声明 + 架构模板 frontmatter 注释说明。全部注释级,零行为影响。

#### 任务分解
1. `su-ccb-claude-plugin/references/docs-structure-contract.yaml`:`01_架构设计/` 条目注释加 scope 声明(architecture_scope: 子系统 slug 或 "overview";scope_source_roots: 单行 inline list 路径数组;su-init 分层生成写入,人工手写架构可选标注以参与补缺判断)
2. `docs/.ccb/docs-structure-contract.yaml`(项目副本):同步逐字一致的注释
3. `su-oriel/server/src/indexer/default-docs-structure-contract.yaml`(Oriel fallback 第三副本):同步逐字一致的注释 —— 子仓纪律见下
4. `su-ccb-claude-plugin/templates/docs/01_架构设计/_模板_架构.md`:frontmatter 区注释加 architecture_scope / scope_source_roots 可选字段说明 + 单行 inline list 写法提示(多行 YAML 数组会被行级 parser partial)

#### 子仓纪律(su-oriel,硬约束)
- 子仓当前有 unrelated dirty(如 server/src/generated/version.ts 生成物):只 stage 目标 yaml 一个文件,严禁带入任何其它变更
- 子仓改动 commit 留本地分支,不 push;父仓 gitlink 抬升不在本任务内做(随需求合并/归档流程统一走,需用户授权)
- 回执必须报告:子仓 git status 摘要、目标文件 diff、子仓 commit hash(若已 commit)、父仓 gitlink 当前状态
- 子仓操作受阻(权限/锁/冲突)时停止并回执升级,不得绕过;受阻时本片其余 3 个文件照常交付,Oriel 副本单独列 blocked

#### 验收标准
- 三份 yaml 的 scope 注释逐字一致(grep 比对通过)
- 模板注释含两字段说明 + inline list 单行写法提示
- 契约 schema 校验通过、docs-structure 相关既有测试不回归(注释零行为)
- 回执含子仓状态报告

#### 边界
- 不改契约结构字段/治理规则;不改模板章节结构;不碰 lib/SKILL

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq23elzh081b0a36b7726299
- Section: pr2-contract-template
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

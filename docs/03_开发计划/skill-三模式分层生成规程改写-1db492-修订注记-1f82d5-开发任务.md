---
doc_type: dev_task
task_id: subtask-8ee6421f82d5
title: SKILL 三模式分层生成规程改写 + 1db492 修订注记
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq23elzh081b0a36b7726299
section_id: pr3-skill-and-docs
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-783b6fe2f1fd]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq23elzh081b0a36b7726299.json
source_draft_hash: 8add95651043c40293f36ec706b1a665b1a49224a347aa24d037d06a90ca79de
created_at: 2026-06-06T12:19:20.972Z
updated_at: 2026-06-06T13:05:00.688Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq23elzh081b0a36b7726299","branch":"ccb/req-cmq23elzh081b0a36b7726299"}
---

# SKILL 三模式分层生成规程改写 + 1db492 修订注记

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | SKILL「旧项目架构生成」章改写:mode 四分支、per-candidate 证据门槛、scope frontmatter inline list、总架构固定 profile、回执终态枚举、二次 detect 新中止条件;1db492 设计文档头部加 gate 被替换注记。 |
| 需求来源 | cmq23elzh081b0a36b7726299 |
| 本期范围 | pr3-skill-and-docs · SKILL 三模式分层生成规程改写 + 1db492 修订注记 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
`skills/su-init/SKILL.md`「旧项目架构生成」章改写为三模式分层生成规程,对齐 pr1 落地的真实接口;1db492 技术设计文档加修订注记。**依赖 pr1**(字段名以 pr1 实际返回为准,完成前先核对);pr2 已完成时与其模板措辞保持一致(soft-after,非硬依赖)。

#### 任务分解
1. SKILL 消费规程改写:读 `summary.architectureCandidates`,按 mode 四分支——skip→回执 reason(no_source/architecture_exists);single→现行证据门槛路径 + 新增 scope frontmatter;layered→per-candidate 证据门槛(以候选目录为根:目录树+≥1 grounding 源+概述/技术栈/结构/核心模块四块可填,不满足记 evidence_insufficient 继续其余)→子架构逐个 final-path wx →总架构;overview_only→仅总架构+全部候选清单+点名补生成提示
2. scope frontmatter 示例:doc_type/updated/generated_by: su-init-ai/human_verified: false/architecture_scope: <slug>(总架构 "overview")/scope_source_roots: 单行 inline list(多行 YAML 会被行级 parser partial,硬要求)
3. 总架构固定渲染 profile:按 _模板_架构.md 固定填一(概述=系统全景)、二(整体结构图=子系统框图,仅证实连线)、五(核心模块=全部候选清单表:子系统/路径/职责/置信度/状态/文档链接)、六(关键流程=仅可证实关联:import 方向/HTTP client 指向/配置引用;推不出标「未推断」)、十一(相关文档=仅链接实际写成功的子架构);不得编造子系统关联
4. 写盘纪律更新:逐文件 final-path wx 独占写(禁 temp+rename,沿用);先子架构(按候选 id 排序)后总架构;单文件 EEXIST/失败→记 skipped 继续其余;写前二次 detect 中止条件=出现新增「无 scope 非模板 md」(本轮自写 scoped 文档走 existing 语义,不算形状变化)
5. 回执契约:每候选终态(generated|existing|evidence_insufficient|list_only|submodule|shell_merged|aggregator_excluded)、总架构状态(generated|existing)、overview 陈旧链接提示(补写子架构而旧总架构存在时)、AI 生成+建议 review 提醒、超限时全部候选+点名补生成指引
6. 1db492 技术设计文档(docs/03_开发计划/su-init-旧项目自动生成架构-1db492-技术设计.md)头部加修订注记:multiple_source_roots gate 已被 726299 分层候选发现替换,指向新设计文档;不改其余内容

#### 验收标准
- SKILL 无「multiple_source_roots→跳过」旧语义残留、无旧单数函数名残留
- 三模式规程完整(mode 四分支+证据门槛+总架构 profile+回执终态枚举)
- 字段名与 pr1 实际接口逐项核对一致(回执附核对清单)
- 1db492 文档含修订注记并指向 726299 设计文档
- 不改 lib/init.mjs/契约/模板(pr1/pr2 的面)

#### 边界
- 仅文档/规程改写,无代码;wx 纪律与信任标记语义不得削弱

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-783b6fe2f1fd
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
- Section: pr3-skill-and-docs
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-783b6fe2f1fd

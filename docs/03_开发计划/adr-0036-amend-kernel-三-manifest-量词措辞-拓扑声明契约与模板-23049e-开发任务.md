---
doc_type: dev_task
task_id: subtask-be53b323049e
title: ADR-0036 amend + kernel 三 manifest 量词措辞 + 拓扑声明契约与模板
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmpmultispacemerge260606
section_id: pr1-adr-kernel-topology-contract
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmultispacemerge260606.json
source_draft_hash: 56f84fd263ca94c9bc00d4361027a499b9dbf4676109a462f9f7ce36d3eabf29
created_at: 2026-06-07T05:28:12.990Z
code_workspace: {"path":"../SU-CCB-req-cmpmultispacemerge260606","branch":"ccb/req-cmpmultispacemerge260606"}
---

# ADR-0036 amend + kernel 三 manifest 量词措辞 + 拓扑声明契约与模板

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | ADR-0036 增补多空间不变量与拓扑契约决策;dispatch/archive/implementation 三 manifest 改为零拓扑词汇的全空间量词;docs-structure-contract machine_layer.holds 补 config/;新增 implementation-topology.yaml 模板骨架(注释版,落点写死,SU-CCB 实例留 pr5)。纯文档/契约片,零 lib 改动。 |
| 需求来源 | cmpmultispacemerge260606 |
| 本期范围 | pr1-adr-kernel-topology-contract · ADR-0036 amend + kernel 三 manifest 量词措辞 + 拓扑声明契约与模板 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把收尾规则的本体措辞从"仓/单 worktree"翻转为"需求名下全部实施空间",落进 ADR-0036、kernel 三个节点 manifest 与目录契约;同时给出拓扑声明 yaml 的模板骨架(schema_version: implementation-topology-v0.1)。落地序安全论证:零声明默认=单一主空间,措辞先行不破坏现行为——SU-CCB 真拓扑实例到 pr5 才启用,期间一切需求按退化单空间运行,与现 lib 行为一致。

#### 任务分解
1. `docs/06_决策记录/ADR-0036-per-requirement-implementation-worktree.md` amend(模式照 2026-06-06 既有 amend):不变量 3 推广为"每空间 merge target=该空间运行态记录的 target_branch";新增不变量"全部空间 merged+项目声明的关联同步完成+预览自洽 → 整体 merged;任一失败 → 整体 escalated 保留现场";新增决策 9"项目拓扑机器声明契约"(路径/schema 名/零声明退化/runtime 只记展开实例);决策 2 状态机注记 per-space status+aggregate(具体枚举引技术设计六);决策 4.1 量词同步。
2. `su-ccb-claude-plugin/references/kernel/nodes/dispatch.node.md`(:40/:53 一带):ensure 措辞改"派工提交前调用 ensureRequirementWorktree 展开并就绪该需求名下全部实施空间(按项目机器可读声明展开;无声明=单一主空间);全部空间就绪后才提交 ask;dispatch brief 附运行态空间表"。
3. `su-ccb-claude-plugin/references/kernel/nodes/archive.node.md`(§10/§11/§12 与深度说明):merge-only 量词改"全部实施空间各自合并回各自运行态记录的源分支+空间间关联按项目声明同步+整体 merged 预览暂停";cleanup 改逐空间;reopen 标注仅 requirement 级 all-or-nothing;"运行态记录的 target_branch"表述推广 per-space。
4. `su-ccb-claude-plugin/references/kernel/nodes/implementation.node.md`(:35/:49 一带):code_workspace 措辞补"主空间为 codeRoot;需求声明多实施空间时,按 dispatch brief 空间表各自为各自 codeRoot,跨空间路径纪律同主空间"。
5. `docs/.ccb/docs-structure-contract.yaml` machine_layer.holds 补一行 `config/`(项目层机器可读配置,additive)。
6. `su-ccb-claude-plugin/templates/docs/.ccb/config/implementation-topology.yaml`[NEW,落点写死]:全注释模板骨架(spaces[].space_id/kind/repo/worktree_path/branch 占位符 <requirementId>;associations[].kind/from_space/to_space/submodule_path),首行注明 Schema source: lib/worktree/topology.mjs(pr2 落)与"默认不存在=单空间退化"。

#### 验收标准
- a. `grep -riE 'submodule|gitlink|superproject' su-ccb-claude-plugin/references/kernel/nodes/` 零命中(kernel 零拓扑词汇;cwd=项目根)。
- b. ADR-0036 含上述 amend 全要素,带 2026-06 日期与本需求 id 溯源。
- c. contract yaml 语法有效且 config/ 条目 additive 不动其余键;模板 yaml 落在写死路径。
- d. 三 manifest 6 章节结构不变,仅措辞 amend;零 lib/测试改动。

#### 边界与不做
不改 lib 代码、不写 SU-CCB 真拓扑实例(pr5)、不动 su-dispatch/su-batch 等 SKILL.md(随行为片 pr3/pr4 落)、不动 Console。

#### 引用
- 设计 D1/D5/D9/D12 与"二、方案与架构"边界表;需求§四.1/§五;breakdown consult job_7f48524ef45b(模板落点写死)。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpmultispacemerge260606
- Section: pr1-adr-kernel-topology-contract
- Owner: ccb_codex
- Priority: high
- Dependencies: none

---
doc_type: dev_task
task_id: subtask-5eb49c4ce165
title: 本项目契约 wiring + 模板落地 + 全链路验收
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmq3feiumac1ad394d74d8dbf
section_id: pr4-project-wiring-acceptance
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-79edea2999c2, subtask-2c399dd77c80, subtask-1829d82d5952]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3feiumac1ad394d74d8dbf.json
source_draft_hash: ff7eb04d84c3a93a67878264b1f45843bf7dbf090332a2ab398e89f98f92ba3d
created_at: 2026-06-07T10:11:21.276Z
updated_at: 2026-06-07T11:25:00.000Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmq3feiumac1ad394d74d8dbf","branch":"ccb/req-cmq3feiumac1ad394d74d8dbf"}
---

# 本项目契约 wiring + 模板落地 + 全链路验收

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | docs-structure-contract.yaml 定向 merge 8 个 template 行+consumers 段；镜像复制 9 份 _模板_*.md 进 docs/（以 pr2 最终态为源）；loadDocsStructureContract+resolver.templateFor 断言+Console rescan+跨仓字面一致性 grep。主仓 docs，一次性 wiring，依赖前三。 |
| 需求来源 | cmq3feiumac1ad394d74d8dbf |
| 本期范围 | pr4-project-wiring-acceptance · 本项目契约 wiring + 模板落地 + 全链路验收 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述

收尾：把模板和契约声明落进本项目 docs/，修掉「模板黑户」真相分裂（plugin 有 9 份好模板但项目契约没声明、目录里没有），最后跑全链路验收确认无新警告。仓库：主仓 docs/（一次性 wiring，不改任何代码仓）。依赖 pr1+pr2+pr3 全部合入。

#### 任务分解

1. [MODIFY] docs/.ccb/docs-structure-contract.yaml：定向 merge plugin references/docs-structure-contract.yaml 的 8 个 template 声明行（00 项目总览/00 文档地图/01 架构/02 需求/03 复合行 [技术设计,开发任务]/04 模块规格/05 经验沉淀/06 ADR）+ consumers 段；保留项目既有定制行（config/ 等），只增不删。
2. [NEW] 按契约落点镜像复制 9 份 _模板_*.md 进 docs/ 对应目录，以 pr2 合入后的模板最终态为源。口径已决（Codex open question）：镜像全 9 份，含 _模板_项目总览/_模板_文档地图——契约 8 行声明与文件一一对应是 resolver 断言可机械化的前提；两份特殊模板按契约注释语义 = 输出格式参考（非手填）；不改 su-init 行为（scaffold 对新项目的分发逻辑不在本任务面，本任务是已初始化项目的一次性手动 wiring）。
3. 验收执行：node 断言 loadDocsStructureContract 校验通过 + resolver.templateFor 对 8 类声明逐一解析成功；触发 Console rescan（POST /scan，WSL2 下 watcher 可能漏事件需手动触发）。
4. 跨仓字面一致性终门：grep 对照 kernel 规范 R1/R2 用词 ↔ pr2 模板占位块 ↔ pr3 conformance 检查字面（「目标对齐」「模拟示例」「无需示例」「expression_spec: v1」）三处一致。

#### 验收标准

- [ ] loadDocsStructureContract 通过；resolver.templateFor 断言 8 类全过
- [ ] Console rescan：存量文档零新增 expressionIssues 且零新增 missingSections（_模板_* 文件被主扫描跳过，不产投影噪音）
- [ ] 跨仓字面标记 grep 一致性通过（三仓四标记零漂移）
- [ ] 契约 diff 可证只增不删（项目既有 config/ 等定制行保留）

#### 边界（不做项）

- 不回填/迁移存量文档；不改 su-init/scaffold 代码；不动 plugin 与 su-oriel 代码（前三 PR 已完）；dogfood 验收（下一个真实需求用新规范走分析→设计全程、用户能看懂）是需求级口径，不在本子任务内闭环。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-79edea2999c2, subtask-2c399dd77c80, subtask-1829d82d5952
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

- Requirement: cmq3feiumac1ad394d74d8dbf
- Section: pr4-project-wiring-acceptance
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-79edea2999c2, subtask-2c399dd77c80, subtask-1829d82d5952

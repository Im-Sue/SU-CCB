---
doc_type: dev_task
task_id: subtask-15cde33aa6a1
title: SU-CCB 拓扑声明落地 + git_submodule_gitlink executor + ccb-execute 措辞 + 端到端验收
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmultispacemerge260606
section_id: pr5-succb-topology-gitlink-e2e
order: 5
implementation_owner: ccb_codex
dependencies: [subtask-fa53a1897199]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmultispacemerge260606.json
source_draft_hash: 56f84fd263ca94c9bc00d4361027a499b9dbf4676109a462f9f7ce36d3eabf29
created_at: 2026-06-07T05:28:12.990Z
updated_at: 2026-06-07T07:03:14.155Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmpmultispacemerge260606","branch":"ccb/req-cmpmultispacemerge260606"}
---

# SU-CCB 拓扑声明落地 + git_submodule_gitlink executor + ccb-execute 措辞 + 端到端验收

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 写 SU-CCB 真拓扑(4 空间+3 gitlink association);实现 git_submodule_gitlink {sync, verify}(scoped pathspec commit/FF noop/dirty 拒绝/后置核验);su-ccb-codex-skills ccb-execute 多空间消费条款(独立子仓 commit+root gitlink 记录);E2E 全生命周期含手工 bump 校正;启用前置=全子仓 clean/attached/gitlink 对齐 gate(需用户授权);本需求自身收尾固定旧手动路径。 |
| 需求来源 | cmpmultispacemerge260606 |
| 本期范围 | pr5-succb-topology-gitlink-e2e · SU-CCB 拓扑声明落地 + git_submodule_gitlink executor + ccb-execute 措辞 + 端到端验收 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把通用机制落到 SU-CCB 本体并端到端验收。本片完成后,下一个跨仓需求的收尾即全自动:4 空间各自合并、gitlink 由 executor 抬升并 verify、整体 merged 预览。

#### 任务分解
1. `docs/.ccb/config/implementation-topology.yaml`[NEW]:4 空间(root "." ../SU-CCB-req-<requirementId>;su-ccb-claude-plugin/su-oriel/su-ccb-codex-skills 各 ../<name>-req-<requirementId>),branch 统一 ccb/req-<requirementId>;3 条 git_submodule_gitlink association(from=各子仓空间,to=root,submodule_path=各子仓相对路径)。需通过 pr2 topology 校验(含 YAML 子集)。
2. `lib/worktree/associations.mjs` 实现 git_submodule_gitlink(按 pr4 冻结签名):sync=校验 to_space repo 在其 target_branch 上+porcelain 仅含本 association submodule_path 脏件→git add -- <submodule_path>→commit(message 含 requirementId 与 association_id)→返回 syncedCommitSha;gitlink 已等于 from_space target tip(FF 情形)→noop:true+现 gitlink sha(仍跑 verify)。verify=gitlink sha==from_space target_sha_after_merge && to_space 在 target_branch && synced commit(非 noop 时)可达于 target_branch && pathspec 外零新增脏件。
3. su-ccb-codex-skills 子仓 ccb-execute 条款:消费 dispatch brief 空间表,多空间时各空间以各自 worktree 为 codeRoot,路径纪律/auto-commit 条款按空间生效;不自建 worktree、不跨空间混提交;实施分支不手工 bump gitlink(association 全权负责,设计 D4 推荐纪律)。**该改动必须为独立子仓 commit,root gitlink 更新作为独立记录,两个 sha 均入回执**(consult B5)。
4. E2E 用例(真实 git fixture,非 SU-CCB 本仓,复用 pr3 builder):superproject+2 submodule+拓扑 yaml→ensure 展开 3 空间→各空间提交→merge 编排(root-first+2 gitlink commit+verify)→aggregate merged→reopen 往返→再 merge(divergence warning 路径)→cleanup 全 archived。附加用例:实施分支手工 bump gitlink 后 association 校正到 post-merge tip(726299 式兼容)。
5. 启用前置 gate(执行期升级用户,不自行操作,泛化为全子仓):全部声明子仓 clean、attached 在各自意图 target 分支、root gitlink 与子仓 HEAD 对齐。现场已知欠账(consult 只读核验):plugin gitlink 偏移且 canonical 停在 ccb/req-cmpwtcleanupsubmodule260606(260606 残债)、su-oriel detached+dirty。残债未清时 D8 守卫/verify 会拦新需求(行为正确);须向用户列明每仓现状并取得授权后人工收敛。回执必须记录各子仓 gate 处理结果或未处理原因。

#### 验收标准
- a. E2E 与附加用例全绿;`node --test su-ccb-claude-plugin/lib/worktree/__tests__/*.test.mjs` 全绿。
- b. SU-CCB topology yaml 通过 lib 校验;`grep -riE 'submodule|gitlink|superproject' su-ccb-claude-plugin/references/kernel/nodes/` 仍零命中(cwd=项目根;拓扑词汇只在 config/lib/项目文档)。
- c. verify 失败路径有用例:gitlink 不等/repo 不在 target/pathspec 外脏件→不标 synced。
- d. ccb-execute 条款更新且与 implementation.node.md(pr1)措辞一致;su-ccb-codex-skills 为独立子仓 commit+root gitlink 记录,两 sha 入回执。
- e. 回执含全子仓启用前置 gate 的逐仓处理记录(已收敛/待用户授权)。

#### 边界与不做
不 push/不 PR/不动远端;不改 Console;不做跨需求并发锁;**本需求自身最终收尾固定走现行单空间流程+子仓手动收尾(最后一次),不 dogfood 新机制**,除非用户在收尾时显式授权(consult B5/open question 采纳)。

#### 引用
- 设计 D2/D3/D8/D12 与五(E2E)/十(落地前置);Codex C4/C6/C8(job_99a3e338f0fa)+B5/前置泛化/grep 修正(job_7f48524ef45b);需求§四.2/§四.6。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-fa53a1897199
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
- Section: pr5-succb-topology-gitlink-e2e
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-fa53a1897199

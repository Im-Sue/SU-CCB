---
doc_type: dev_task
task_id: subtask-eefc32c751ae
title: ensure 多空间展开 + D8 target 守卫 + 全 helper 过渡 lift 读取(含多空间拒绝守卫) + su-dispatch 措辞
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmultispacemerge260606
section_id: pr3-ensure-expansion-transitional-read
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-21ff25760f34]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmultispacemerge260606.json
source_draft_hash: 56f84fd263ca94c9bc00d4361027a499b9dbf4676109a462f9f7ce36d3eabf29
created_at: 2026-06-07T05:28:12.990Z
updated_at: 2026-06-07T06:18:52.455Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmpmultispacemerge260606","branch":"ccb/req-cmpmultispacemerge260606"}
---

# ensure 多空间展开 + D8 target 守卫 + 全 helper 过渡 lift 读取(含多空间拒绝守卫) + su-dispatch 措辞

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | ensureRequirementWorktree 按拓扑展开恰好一次(全量 pending→逐空间物理 ensure→ready),per-repo 捕获 target/base,D8 implementation_branch_as_target 守卫;其余 4 helper 改经 lift 读取且仅接受单空间 runtime(spaces.length===1 && associations.length===0,否则 ConflictError 拒绝,防 clobber);多仓 fixture builder 落为可复用 test helper;su-dispatch SKILL 措辞+brief 空间表;materialize 一致性交叉校验。 |
| 需求来源 | cmpmultispacemerge260606 |
| 本期范围 | pr3-ensure-expansion-transitional-read · ensure 多空间展开 + D8 target 守卫 + 全 helper 过渡 lift 读取(含多空间拒绝守卫) + su-dispatch 措辞 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把展开与就绪做实:ensure 成为多空间编排的唯一入口,写 v0.2;merge/cleanup/reopen/discard 本片只做读取兼容(经 lift)+**多空间显式拒绝**,多空间行为留 pr4——保证本片落地后全测试矩阵仍绿、单空间语义不变、且不存在"能测单空间但会破坏多空间 runtime"的过渡态(consult B1)。

#### 任务分解(su-ccb-claude-plugin 子仓为主)
1. `ensureRequirementWorktree` 重构:锁内 loadTopology+expandTopology;runtime 不存在→写全量空间实例(status=pending)+associations(pending)+topology_source;逐空间(声明序)物理 ensure:`git -C join(projectRoot, space.repo)` 域内 prune/worktree list/branch 检查/worktree add(逻辑=今天单空间体,cwd 参数化),per-repo 捕获 target_branch(currentBranch,detached 即 ConflictError throw)与 base_sha,成功翻 ready 增量写盘(aggregate 随写重算)。
2. D8 守卫:捕获的 target_branch 命中本拓扑 branch 模板前缀(模板去 <requirementId> 占位后的字面前缀,如 ccb/req-)→escalation("implementation_branch_as_target", {space_id, captured_target}) + 事件 + 不写 ready;ensure 整体对该空间停止(throw 语义保持:写 last_error{op:"ensure",space_id} 后 throw ConflictError)。
3. codeWorkspace 交叉校验:dev_task 盖的 code_workspace 必须与拓扑 root 空间展开一致(path/branch),不一致 ConflictError(语义=今天 assertStateMatchesWorkspace 推广);零声明时 root 空间直接由 codeWorkspace 派生(行为=今天)。重入:existing 空间逐个 noop 校验(逻辑=今天),半展开恢复=续 ensure 未 ready 空间;aggregate=ready 才算 ensure 成功返回。
4. 过渡读取接线+**多空间拒绝守卫**(consult B1 修订):merge/cleanup/reopen/discard 的 readRuntimeState 改为读后即 lift;入口处断言 `spaces.length===1 && associations.length===0`,否则 ConflictError("multi-space runtime requires the multi-space orchestrator (pr4)"),**绝不把单空间视图写回多空间 runtime**;单空间时继续操作 root 空间等价视图,写盘走 v0.2 单空间。行为断言:四 helper 对单空间 runtime 业务语义与 pr3 之前逐字节等价(escalation reason/事件 payload 既有字段不变,允许 additive)。
5. `skills/su-dispatch/SKILL.md`(:74-85 一带)措辞:ensure 展开全部空间、aggregate ready 才 ask、brief 附运行态空间表(space_id/repo/path/branch/target_branch,从 docs/.ccb/worktrees/<req>.json 读)。
6. materialize 一致性测试[NEW 用例]:断言 lib/subtask 盖章模板(../SU-CCB-req-<id>, ccb/req-<id>)与默认 root 展开一致(防双模板漂移;lib/subtask 代码零改动)。
7. 多仓 fixture builder[NEW,可复用]:落为 `lib/worktree/__tests__/helpers/multi-repo-fixture.mjs` 导出构建函数(superproject+真实 submodule+topology yaml 写入,复用 260606 的 protocol.file.allow=always 经验),worktree.test.mjs 与后续 pr4/pr5 测试统一 import,不复制 fixture 代码(consult B3)。
8. 测试用例:多空间展开 happy path(pending→ready×N)、detached 子仓 canonical ensure 失败、D8 守卫(子仓停在 ccb/req-* 分支→escalated+事件)、半展开重入续作、路径嵌套拓扑被 pr2 校验拒绝的 ensure 面断言、零声明 ensure=今天行为(写 v0.2 单空间)、**四 helper 对多空间 runtime 的 ConflictError 拒绝**、既有用例随 v0.2 断言机械更新(业务语义零变,diff 审查点)。

#### 验收标准
- a. `node --test su-ccb-claude-plugin/lib/worktree/__tests__/*.test.mjs` 全绿;既有用例仅 v0.2 断言形状更新,业务语义零变。
- b. ensure 后 runtime 为 v0.2:全空间 ready、aggregate=ready、topology_source.content_hash 在档。
- c. D8/detached/嵌套/半展开重入/多空间拒绝五类失败路径有事件或结构化错误与现场。
- d. 零声明项目(无 yaml)全链路与 pr3 之前行为一致(单 root 空间);多空间 runtime 下四 helper 必拒不写。
- e. su-dispatch SKILL 含空间表措辞;lib/subtask 零代码改动;fixture builder 为独立可 import 的 helper 文件。

#### 边界与不做
merge/cleanup/reopen/discard 的多空间行为(pr4);association 执行(pr4 框架/pr5 实现);SU-CCB 真拓扑启用(pr5)。

#### 引用
- 设计 D3/D6/D7/D8 与四(Phase 0 之前的 ensure 段);Codex C3/C4(job_99a3e338f0fa)+B1/B3(job_7f48524ef45b,多空间拒绝守卫+builder 复用);需求§四.4。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-21ff25760f34
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
- Section: pr3-ensure-expansion-transitional-read
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-21ff25760f34

---
doc_type: dev_task
task_id: subtask-fa53a1897199
title: merge/reopen/discard/cleanup 多空间 orchestrator + preflight + 显式恢复门 + association executor 框架(接口冻结)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmultispacemerge260606
section_id: pr4-merge-orchestrator-recovery
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-eefc32c751ae]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmultispacemerge260606.json
source_draft_hash: 56f84fd263ca94c9bc00d4361027a499b9dbf4676109a462f9f7ce36d3eabf29
created_at: 2026-06-07T05:28:12.990Z
updated_at: 2026-06-07T06:45:46.331Z
updated_by: slot1_claude
code_workspace: {"path":"../SU-CCB-req-cmpmultispacemerge260606","branch":"ccb/req-cmpmultispacemerge260606"}
---

# merge/reopen/discard/cleanup 多空间 orchestrator + preflight + 显式恢复门 + association executor 框架(接口冻结)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 四 helper 升 requirement 级 orchestrator:全空间只读 preflight→root-first 逐空间 merge→association(sync+verify 框架,接口签名冻结,test-only fake kind)→aggregate merged;显式恢复门表(escalated+last_error.op 匹配才准重入,修订自 consult B-pr4 状态门冲突);reopen all-or-nothing、discard 全 {pending,ready} 门、cleanup 逐空间复用 260606 删除语义;事件 additive;SKILL/文案同步。 |
| 需求来源 | cmpmultispacemerge260606 |
| 本期范围 | pr4-merge-orchestrator-recovery · merge/reopen/discard/cleanup 多空间 orchestrator + preflight + 显式恢复门 + association executor 框架(接口冻结) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
多空间收尾的核心行为片。merge 编排严格按设计四流程图:Phase 0 全空间只读 preflight(零副作用)→Phase 1 root merge(canonicalSyncCommit 仍仅 root)→Phase 2 子空间按声明序各自 merge 回各自记录的 target→Phase 3 associations 逐条 sync+verify→aggregate merged。任一失败:space.last_error+aggregate escalated+事件+停,已 merged 空间事实保留;恢复重跑按 per-space status 跳过 merged 只重试未成。

#### 显式恢复门表(binding,修订自 consult job_7f48524ef45b:原"仅 aggregate merged"门会拦死自家 partial 重入)
- merge 入口:aggregate==ready(首跑)｜aggregate==escalated 且 last_error.op∈{merge, associate}(恢复重入)｜aggregate==merged(幂等返回);其它拒。
- cleanup 入口:aggregate==merged(首跑)｜aggregate==escalated 且 last_error.op==cleanup(恢复重入)｜aggregate==archived(幂等返回);其它拒。
- reopen 入口:仅 aggregate==merged(all-or-nothing,不变)。
- discard 入口:全空间 status∈{pending, ready}(覆盖 ensure 半展开后放弃场景);任一 merged/archived 即 ConflictError。
- 恢复重入必须按 per-space status 续作:跳过 merged/archived 空间,只处理未成空间;全空间 merged+association pending/失败时自然走 association-only。

#### 任务分解(su-ccb-claude-plugin 子仓)
1. mergeRequirementWorktree 多空间化:Phase 0 preflight 每空间(worktree 在位+branch 匹配+porcelain clean+target_branch 存在+该 repo 当前在 target 上),任一不过 escalated(space_id, reason)且未动任何 repo;Phase 1/2 逐空间 merge(逻辑=今天单空间体 cwd 参数化;untouched 空间 branch tip==base 或已是 target 祖先→no-op 补 merged);增量写盘每空间一次;Phase 2 失败 payload 带 preview_consistency:"incomplete"(root target 已前进的诚实提示)。
2. `lib/worktree/associations.mjs`[NEW] executor 框架,**接口签名冻结**(consult B4):registry(kind→executor);executor 必须实现 `sync({projectRoot, requirementId, association, spacesById, runGit})` 与 `verify({projectRoot, requirementId, association, spacesById, runGit})`;orchestrator 集成:sync 前置校验 to_space repo porcelain 仅含声明 pathspec 脏件(其它脏→escalated association_dirty_outside_path)→sync→强制 verify 通过才标 synced+synced_commit_sha/noop 入档;verify 可对已 synced 重入独立运行(审计);未知 kind→escalated unknown_association_kind。本片注册 test-only fake kind 且 fake 必须覆盖**全签名面**:消费 spacesById/runGit、产生 synced_commit_sha、触发 dirty-pathspec 拒绝、verify 失败不标 synced——保证 pr5 真 executor 零框架返工。
3. reopenRequirementWorktree:仅 aggregate merged;逐空间校验(worktree+branch 在且 clean)全过才整体翻 ready,associations 重置 pending;任一不过 escalated 全程不写。discardRequirementWorktree:按门表(全空间∈{pending,ready});逐空间 force remove+branch -D,stop-on-first-failure。
4. cleanupRequirementWorktree:按门表;逐空间(声明序)removeWorktreeForCleanup(260606 force-retry 复用)+branch -d+per-repo ancestor gate;partial 失败 escalated(last_error.op=cleanup)、成功空间保留 archived;全 archived→aggregate archived。archiveRequirementWorktree 保持 merge→cleanup 链式 wrapper,JSDoc 标 legacy(无节点契约消费方)。
5. 事件:既有 requirement_worktree_* 保持 aggregate 级,payload 增 spaces 摘要数组(space_id/status/target_branch)+escalation 增 space_id/op;新增 requirement_worktree_association_synced(association_id/kind/synced_commit_sha/noop)。全部 additive。
6. SKILL 措辞:su-batch(:53-60 merge tail 量词)、su-archive(:67-138 cleanup/reopen 逐空间+escalated 分支+恢复门表引用)、su-quick-archive(禁令措辞推广多空间)、lib/requirement-cancel 内 discard 相关文案——API 调用形零改。
7. 测试(复用 pr3 helpers/multi-repo-fixture.mjs):多空间 happy path(root-first 序断言:git log 时序或注入器调用序)、Phase 2 注入失败→escalated(preview_consistency)→**重跑经恢复门进入**只重试未成不重放(已 merged 空间 git 状态不变断言)、association-only 重入、cleanup partial 失败→escalated(op=cleanup)→重入续作、fake executor sync 失败/verify 失败不标 synced/dirty-outside-path 拒绝、reopen all-or-nothing(一空间 dirty 整体拒)、discard 门表(pending+ready 可弃/任一 merged 拒)、reopen 后二次 merge divergence warning、v0.1 lift 后旧 merged 需求 cleanup/reopen 直通(associations vacuous)、零声明全生命周期=今天语义。

#### 验收标准
- a. `node --test su-ccb-claude-plugin/lib/worktree/__tests__/*.test.mjs` 全绿;设计五测试矩阵中除 gitlink 专项与 E2E(pr5)外全部落地,用例名可映射矩阵条目。
- b. 零声明项目 merge/cleanup/reopen/discard 与 pr4 之前行为等价(单空间回归套件)。
- c. 恢复门表四条全部有用例证明(含"escalated 但 op 不匹配→拒"的负例);不重放已 merged 空间、escalated 现场零删除。
- d. 事件仅 additive(对照既有断言);verify 未过永不出现 synced;executor 接口签名与本 spec 逐字一致。
- e. SKILL/文案更新到位且不改调用 API 形状。

#### 边界与不做
git_submodule_gitlink 真 executor 与 SU-CCB 拓扑(pr5);targeted 单空间 reopen 不做;跨需求 repo 级锁不做;Console 零接触。

#### 引用
- 设计 D2/D4/D5/D9/D10/D11 与四(核心流程);Codex C1/C2/C6/C7/C8(job_99a3e338f0fa)+B1/B4/恢复门修订(job_7f48524ef45b);需求§四.5/§五。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-eefc32c751ae
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
- Section: pr4-merge-orchestrator-recovery
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-eefc32c751ae

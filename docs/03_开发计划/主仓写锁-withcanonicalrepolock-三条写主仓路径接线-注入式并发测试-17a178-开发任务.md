---
doc_type: dev_task
task_id: subtask-0efbf617a178
title: 主仓写锁 withCanonicalRepoLock + 三条写主仓路径接线 + 注入式并发测试
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cm6241561f52fc0d749mgsync
section_id: pr2-canonical-repo-lock
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-92174773fd31]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cm6241561f52fc0d749mgsync.json
source_draft_hash: cf45558c4df36c2c8cbd8388d2f1db57dc99285282d6a279f0cf6d7bf46225e7
created_at: 2026-06-10T04:51:50.673Z
updated_at: 2026-06-10T05:46:34.656Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cm6241561f52fc0d749mgsync","branch":"ccb/req-cm6241561f52fc0d749mgsync"}
---

# 主仓写锁 withCanonicalRepoLock + 三条写主仓路径接线 + 注入式并发测试

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 复用 withFileLock 实现 withCanonicalRepoLock，锁文件 .ccb/locks/canonical-repo（严禁 docs/ 树内，防 gate 自爆）；锁序固定 requirement→canonical；接线单空间 merge、多空间 root mergeOneSpace、association root gitlink commit；LockTimeoutError 转结构化 canonical_repo_lock_timeout escalation + 事件；注入挂起式并发断言 + 锁文件不污染 status + 超时 + 回归测试。 |
| 需求来源 | cm6241561f52fc0d749mgsync |
| 本期范围 | pr2-canonical-repo-lock · 主仓写锁 withCanonicalRepoLock + 三条写主仓路径接线 + 注入式并发测试 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

pr1 放宽合并洁净度检查后，旧逻辑"别人脏就挡"带来的**隐性串行**消失了——多个需求可能真的同时往主仓做 `git add/commit/merge`，互相踩 index/HEAD。本任务加一把**主仓写锁**：同一时间只允许一个需求执行主仓的提交/合并临界区。

> 术语白话：临界区＝「同一时刻只能有一个人在里面干活的代码段」；锁文件＝「占坑文件，谁建成功谁持锁」；LockTimeoutError＝「等锁超时」。

```
锁序（固定，防死锁）: withRequirementLock(per-需求) ──之后──► withCanonicalRepoLock(per-主仓)
覆盖临界区:
  单空间 merge:   canonicalSyncCommit + root merge 段（index.mjs:1575 起）
  多空间 merge:   root space 的 mergeOneSpace（:859）
  association:    toSpace=root 的 sync/verify 段（associations.mjs:178-198 root gitlink add/commit）
```

### 任务分解

1. 新增 `withCanonicalRepoLock(projectRoot, fn, options)`：复用 `lib/runtime/file-lock.mjs` 的 `withFileLock`；锁目标 **`.ccb/locks/canonical-repo`**（项目级 `.ccb/`，与现有 `lockTargetPath`（index.mjs:74 → `.ccb/locks/worktree/<id>`）同目录约定）。**严禁放 `docs/` 下任何位置**——`withFileLock` 会创建 `<target>.lock/owner.json`，若落在 docs 树内会被 `canonicalSyncCommit` 的 porcelain 看见，gate 被自己的锁文件触发误报（Codex 协商抓出的自爆点）。
2. 接线（锁序固定为先 requirement 锁后 canonical 锁，绝不反向）：
   - `mergeRequirementWorktree`(:1465) 单空间路径：包住 canonicalSyncCommit + merge + headSha 段。
   - `mergeMultiSpaceRequirementWorktree` / `mergeOneSpace`(:859)：包住 root space 分支（canonicalSyncCommit + merge）。
   - `runAssociationExecutor`(:942)：toSpace 为 root 的 sync/verify（root gitlink add/commit）段。submodule toSpace 不加锁。
3. 超时语义：`LockTimeoutError` **不裸抛**，转结构化 escalation `canonical_repo_lock_timeout`（payload 含 requirementId/锁路径，holder 信息可得则带）+ EventJournal 事件——保持 merge/archive 的 escalation 契约（裸抛会破坏调用方处理；前科：cleanup 对 submodule worktree 裸抛非 escalated 的事故）。
4. 测试：
   - 并发（确定性，不靠计时；Codex G3 策略）：通过 git 执行注入，让需求 A 的 root commit/merge 在临界区内挂起 → 断言需求 B 未进入任何 root mutating git 命令 → 释放 A → 断言 A、B 都完成、git log 顺序可解释、最终 status clean。
   - 锁文件不污染：持锁期间主仓 `git status --porcelain --untracked-files=all` 不含锁路径。
   - 超时：制造持锁不放 → B 得到 `canonical_repo_lock_timeout` escalation + journal 事件，无裸抛。
   - 回归：既有 worktree_dirty/target_branch/merge_conflict/cleanup 用例不变。

### 验收标准

1. 两需求并发 merge 被串行化，root index/HEAD 无竞争损坏（注入式断言，非 sleep/计时）。
2. 锁文件位于 `.ccb/locks/canonical-repo*`，git status 全程不可见。
3. lock 超时产生结构化 `canonical_repo_lock_timeout` escalation + EventJournal 事件，不裸抛。
4. 单空间、多空间 root、association root gitlink 三条写主仓路径全部在锁内；submodule 路径不受影响。
5. 锁序全程 requirement→canonical，无反向获取；plugin 仓测试套件全绿。

### 边界 / 不做项

- 不重塑 pr1 的 classifier/tolerated_paths 形状（只消费）。
- 不引入新锁机制/依赖（只复用 withFileLock）；不做跨进程之外的分布式锁。
- 不动 submodule 内部 association 隔离逻辑。

> 来源：技术设计 td-mgsync（二、四、八）+ Codex 协商 job_44bfe8f2a115（G3 注入式并发断言、G4 锁序与结构化超时、锁路径自爆点）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-92174773fd31
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
- Section: pr2-canonical-repo-lock
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-92174773fd31

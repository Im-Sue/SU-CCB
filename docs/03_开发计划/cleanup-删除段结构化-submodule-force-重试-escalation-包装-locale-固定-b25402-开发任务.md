---
doc_type: dev_task
task_id: subtask-4116c1b25402
title: cleanup 删除段结构化:submodule --force 重试 + escalation 包装 + locale 固定
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpwtcleanupsubmodule260606
section_id: pr1-cleanup-submodule-escalation
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpwtcleanupsubmodule260606.json
source_draft_hash: 67b6acdd58c12ef06f21bfad86f3edbfc2a5da9cec9a2f14f4e5ccd19b4a00ee
created_at: 2026-06-06T13:33:43.360Z
updated_at: 2026-06-06T14:01:26.389Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpwtcleanupsubmodule260606","branch":"ccb/req-cmpwtcleanupsubmodule260606"}
---

# cleanup 删除段结构化:submodule --force 重试 + escalation 包装 + locale 固定

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | defaultRunGit 固定 C locale;新私有 helper removeWorktreeForCleanup(remove→submodule 硬拒→--force 一次);删除段失败统一 escalated(两 reason)+ 事件 + 现场保留;archived 事件加 removal_forced;真实 submodule 哨兵 + 注入失败 4 组新测试。 |
| 需求来源 | cmpwtcleanupsubmodule260606 |
| 本期范围 | pr1-cleanup-submodule-escalation · cleanup 删除段结构化:submodule --force 重试 + escalation 包装 + locale 固定 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
req cmpworktreearchive260604 交付的 `cleanupRequirementWorktree` 首跑实战暴露两缺陷:git 硬拒删除含 submodule 的 worktree(本仓为 superproject,每个需求手动归档必踩);失败以 `GitCommandError` 裸抛,违反 archive manifest 的 escalated 契约。本任务按技术设计 D1-D7 重构删除段:submodule 硬拒走 `--force` 单次重试,任何最终失败转 `status:"escalated"` 结构化返回 + `requirement_worktree_archive_escalated` 事件。

#### 任务分解(全部在 su-ccb-claude-plugin 子仓)
1. `lib/worktree/index.mjs` `defaultRunGit`(:129):execFileAsync 增加 `env: { ...process.env, ...(options.env ?? {}), LC_ALL: "C", LANG: "C", LANGUAGE: "C" }`(locale 三变量兜底覆盖,`options.env` 为前向兼容)。
2. 模块级常量 `SUBMODULE_REMOVE_REJECTION = /working trees containing submodules cannot be moved or removed/` + 私有 `async function removeWorktreeForCleanup(projectRoot, absolutePath, options)` → `{ removed, forceAttempted, exitCode?, stderr?, stdout? }`:普通 remove(allowFailure)→ 非 0 且 stderr 命中 → `--force` 重试一次(allowFailure);其它非 0 不重试。
3. cleanup 删除段(:947-954)重构:
   - targetRecord 分支走 helper,失败 → `escalation("cleanup_worktree_remove_failed", { requirementId, path, branch, forceAttempted, exitCode, stderr, stdout })`(stderr/stdout 各截断 500)+ `appendEscalationEvent` + return;
   - remove 成功后的 branch 环节(`branchExists`(:952)存在检查 + `git branch -d`)均不得裸抛:branch -d 改 allowFailure、branchExists 的非 0/1 异常 catch,失败统一 → `escalation("cleanup_branch_delete_failed", 同形态 payload)` + 事件 + return,不 `-D`。
   - helper 命名/位置、截断函数复用或新写等实现细节执行期自决(breakdown consult 确认无需先定死)。
4. 成功路径 `requirement_worktree_archived` 事件 payload 加 `removal_forced: boolean`——语义为**本次 cleanup 调用是否执行过 --force**(非历史事实;branch 失败重跑后的成功归档无法还原上次 forced,历史仅见前次 escalation event)。additive,不改既有字段。
5. 测试 `lib/worktree/__tests__/worktree.test.mjs` 新增 4 用例:
   - T1 真实 submodule 哨兵:独立 sub 仓(绝对路径 source)→ superproject `git -c protocol.file.allow=always submodule add`(cwd=superproject 根)→ 提交 .gitmodules+gitlink → ensure → worktree 内 `git -c protocol.file.allow=always submodule update --init`(cwd=requirement worktree 根)→ merge 前显式 assert porcelain 为空 → commit/merge → cleanup → 断言 archived + worktree 目录无 + `.git/worktrees/<id>`(含 `modules`)无残留 + branch 已删 + journal `requirement_worktree_archived` 含 `removal_forced: true`。
   - T2 注入 runGit:remove 返回 `{1, submodule 文案}` 且 `--force` 也注入失败 → escalated `cleanup_worktree_remove_failed` + `forceAttempted: true` + journal 事件断言。
   - T3 注入:remove 返回 `{1, "is dirty"}` → 断言注入器未收到 `--force` 调用(记录 args)→ escalated `forceAttempted: false`(精确匹配不误升级)。
   - T4 注入器对 remove **透传真实 git**(必须真实产生删除副作用,fake success 覆盖不了真实重入),仅对 `branch -d` 注入失败 → escalated `cleanup_branch_delete_failed` + 事件;随后去掉注入真实重跑 cleanup → archived(重入恢复路径回归)。

#### 验收标准
- a. 新增 4 用例 + 既有 18 用例全绿:`node --test lib/worktree/__tests__/worktree.test.mjs`(不扩展全仓测试矩阵)。
- b. 删除段不裸抛:remove、删除段内 branch 存在检查(:952)、branch -d 三处的任何 git 失败均以 escalated 结构化返回,不向上抛 `GitCommandError`(删除段之前的前置检查与之后的 state/journal IO 不在本范围)。
- c. escalated 现场保留(分场景):remove 失败 → worktree + branch + merged state 全保留;branch 环节失败 → worktree 已删(物理不可逆,设计如此),保留 branch + merged state,重跑 cleanup 走既有 `hasBranch && !targetRecord` 恢复路径完成归档。
- d. 不动 merge/reopen/discard 任何行为;不 `-D`、不 `-f -f`。
- e. 无新增依赖、无 schema 变更;`removal_forced` 为 additive 事件字段。

#### 边界与不做
全 lib Git 异常治理(merge/ensure/reopen/discard 的 locked、corrupt 裸抛)另立项;locked worktree 不自动处理;Console 零接触。

#### 引用
- 需求:docs/02_需求设计/bug-worktree-cleanup-submodule-260606-需求.md
- 技术设计(真相源):docs/03_开发计划/bug-worktree-cleanup-submodule-260606-技术设计.md
- consult 链:job_ed7bca245829(需求,Git 2.43 fixture 核验)→ job_b40ac8ff2735(设计)→ job_42a28c20720a(breakdown 可行性,owner 已接)

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

- Requirement: cmpwtcleanupsubmodule260606
- Section: pr1-cleanup-submodule-escalation
- Owner: ccb_codex
- Priority: high
- Dependencies: none

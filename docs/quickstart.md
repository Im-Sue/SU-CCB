# Quickstart：5-10 分钟跑通一次 SU-CCB 文档修复

这份 quickstart 用一个极小的 SU-CCB 自身文档修复任务演示完整协作链路：
起草 spec、Codex review、Codex execute、review 后 archive，并用 lint 与 git log 确认结果。
全程只走命令行，不需要启动 console。

## 前置条件

- Node.js 18+。
- pnpm 由 corepack 管理；如果 `pnpm: not found`，先看
  [apps/ccb-console/README.md](../apps/ccb-console/README.md) 的 troubleshooting。
- Git 已配置 `user.name` 和 `user.email`。
- 已安装并可调用 `ccb` CLI。

```bash
node --version
corepack --version
pnpm --version
git --version
ccb ask --help
# 期望输出片段：v18.x 或更高；pnpm 10.25.0；git version ...；Usage: ccb ask ...
```

## 1. 克隆主仓并安装依赖

```bash
git clone https://github.com/<your-org>/SU-CCB.git
cd SU-CCB
corepack enable
pnpm install --frozen-lockfile
# 期望输出片段：Lockfile is up to date；Done in ...
```

先确认当前分支和基线验证。

```bash
git status --short --branch
python3 references/kernel/tools/lint_all.py --legacy-baseline
# 期望输出片段：## main...origin/main；ALL_GREEN: yes；EXIT_STATUS: legacy_baseline_warn
```

## 2. 起一个极小 spec

本例使用临时分支演示“修复 README 中一个文档 typo”的最小任务。示例 spec
只用于 quickstart；真实任务请按当前仓库规范调整 `task_id`、标题和验收。

```bash
git switch -c quickstart-doc-typo
mkdir -p docs/.ccb/specs/active
cat > docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md <<'EOF'
---
task_id: quickstart-doc-typo
spec_id: quickstart-doc-typo
title: Quickstart demo · README 文档 typo 修复
parent: quickstart-demo
created: 2026-05-02
owner: ccb_codex
currentNode: task_breakdown
nodeSubstate: ready_for_dispatch
runtimeState: running
status: ready_for_review
mode: execute
---

# Quickstart demo · README 文档 typo 修复

## 目标

修复 README.md 中一个无业务影响的文档 typo，验证 spec → review → execute → archive。

## 硬约束

- 只允许修改 README.md。
- 不修改 references/kernel/、docs/.ccb/state/ 或 archive 文件。
- 不启动 dev-server.sh。

## 不做

- 不改产品代码。
- 不引入新依赖。

## 验收

- `git diff -- README.md` 只包含 1 处文案修正。
- `python3 references/kernel/tools/lint_spec.py docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md` 通过。
- `python3 references/kernel/tools/lint_all.py --legacy-baseline` 输出 `ALL_GREEN: yes`。
EOF
# 期望输出片段：Switched to a new branch 'quickstart-doc-typo'
```

校验 spec 自身。

```bash
python3 references/kernel/tools/lint_spec.py docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md
# 期望输出片段：SUMMARY；FAILED: 0
```

## 3. ccb ask codex review spec

将 spec 发给 Codex 做只读 plan review。异步提交后看到 `[CCB_ASYNC_SUBMITTED]`
即可停止等待，避免 poll/sleep 触发重复任务。

```bash
ccb ask --output /tmp/quickstart-review.json codex -- \
  "[PLAN REVIEW REQUEST] mode: consult; target_spec: docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md; 请只读 review 是否可执行。"
# 期望输出片段：[CCB_ASYNC_SUBMITTED]；job_id: ...
```

查看回执时只拉取一次对应 job。

```bash
REVIEW_JOB_ID="$(python3 -c "import json; print(json.load(open('/tmp/quickstart-review.json'))['job_id'])")"
ccb ask get "$REVIEW_JOB_ID"
# 期望输出片段：verdict: pass
```

## 4. ccb ask codex 实施修复

review pass 后，把 execute 任务发给 Codex。下面的示例命令要求 Codex 只改 README，
完成验证后提交一个独立 commit。

```bash
ccb ask --output /tmp/quickstart-execute.json codex -- \
  "[TASK · execute mode] spec: docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md; 请实施 README.md 1 处文档 typo 修复，运行 lint_all legacy-baseline，单 commit，不 push。"
# 期望输出片段：[CCB_ASYNC_SUBMITTED]；job_id: ...
```

拉取 execute 回执后确认 commit。

```bash
EXECUTE_JOB_ID="$(python3 -c "import json; print(json.load(open('/tmp/quickstart-execute.json'))['job_id'])")"
ccb ask get "$EXECUTE_JOB_ID"
git log --oneline -1
# 期望输出片段：status: completed；docs(quickstart): fix README typo
```

## 5. review 后 archive spec

真实项目中，archive 应由 review pass 后的 `su-archive` 流程推进；这里展示最小
CLI 形态。不要在 review 未通过时移动 spec。

```bash
mkdir -p docs/.ccb/specs/archive
git mv docs/.ccb/specs/active/2026-05-02-quickstart-doc-typo.md \
  docs/.ccb/specs/archive/2026-05-02-quickstart-doc-typo.md
python3 references/kernel/tools/lint_all.py --legacy-baseline
git commit -m "chore(quickstart): archive demo spec"
# 期望输出片段：ALL_GREEN: yes；chore(quickstart): archive demo spec
```

## 验证

最后看 git history 和工作树。演示分支可以保留给 review，也可以丢弃。

```bash
git log --oneline -3
git status --short
# 期望输出片段：chore(quickstart): archive demo spec；docs(quickstart): fix README typo
```

清理本地演示分支：

```bash
git switch main
git branch -D quickstart-doc-typo
# 期望输出片段：Deleted branch quickstart-doc-typo
```

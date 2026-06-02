# 贡献指南

感谢你愿意参与 SU-CCB。这个项目的贡献方式和普通开源仓库略有不同：
我们把需求、设计、执行、review 和 archive 都写进仓库，让每一次 AI 参与都能被
review、复盘和恢复。

如果你只是想先跑一遍流程，请从 [docs/quickstart.md](docs/quickstart.md) 开始。
如果你想理解整体设计，请读
[SU/CCB Skills 架构设计总览](docs/01_架构设计/ccb-plan/00-设计总览.md)。

## 协作模式

SU-CCB 使用 Claude + Codex 双角色协作。

- Claude 是 designer：负责需求理解、方案设计、协商、任务拆分和质量门。
- Codex 是 executor：负责按 frozen spec 实施、验证、提交和精简回执。
- reviewer 可以是 Claude、人类维护者，或两者组合；review 通过后才 archive。

三种工作模式用于控制风险：

- `consult`：只读分析，不修改文件，适合需求澄清和 plan review。
- `explore`：读取代码并做轻量验证，不写入，适合现状扫描。
- `execute`：按已批准 spec 实施，运行验证并提交。

贡献者不需要一次掌握全部 CCB 内部机制。先把问题写清楚，再让维护者决定是否进入
spec 流程。

## 适合提交什么

欢迎的贡献包括：

- 修正文档错误、过期链接或命令示例。
- 改进 quickstart、README、贡献指南和模板。
- 给现有 task 补充可复现的失败证据。
- 修复小范围 bug，并提供明确验证命令。
- 对架构或流程提出具体问题和改进建议。

不适合直接提交的内容包括：

- 大范围重构但没有 spec。
- 修改 `su-ccb-claude-plugin/references/kernel/` 协议语义但没有设计 review。
- 引入新依赖但没有替代方案和风险说明。
- 同时混入格式化、重命名和功能改动。

## 贡献流程

最小流程如下：

1. 先开 issue 或讨论，说明目标、影响范围和已有证据。
2. 维护者判断是否需要 spec；简单文档修复可直接走小 PR。
3. 需要 spec 时，先起草 active spec，并通过 plan review。
4. execute 阶段只按 spec 做最小充分改动。
5. PR 或 commit 回执必须列出验证命令和结果。
6. review 通过后，再由维护者推进 state 与 archive。

对于已经进入 CCB 流程的任务，请不要绕过 review gate 直接移动 archive 文件。

## Spec 起草标准

cutoff 之后的新 spec 必须通过 `lint_spec.py` 严格校验。最小结构包括：

- frontmatter 必须包含 `task_id` 和 `spec_id`。
- `## 目标`：说明要解决什么问题，不写实现流水账。
- `## 硬约束`：列出不可违反的边界和风险控制。
- `## 不做`：明确排除项，避免 scope creep。
- `## 验收`：写可机器验证的命令、artifact 或 grep 条件。

验收标准应尽量包含可复制命令，例如：

```bash
python3 su-ccb-claude-plugin/references/kernel/tools/lint_spec.py docs/.ccb/specs/active/<file>.md
python3 su-ccb-claude-plugin/references/kernel/tools/lint_all.py --legacy-baseline
pnpm -r build
pnpm -r test
```

如果验收依赖人工判断，需要写清楚证据来源、截图或 log bundle。

## 分支与提交

建议从最新 `main` 开始创建短分支：

```bash
git switch main
git pull --ff-only
git switch -c <short-task-name>
```

提交信息使用 Conventional Commits 前缀，并允许中文描述：

- `docs(scope): ...`
- `feat(scope): ...`
- `fix(scope): ...`
- `chore(scope): ...`
- `test(scope): ...`

每个 task 尽量一个独立 commit。不要把多个无关 task squash 到一起，也不要把本地
debug 输出、临时文件或未授权的 submodule pointer 混入提交。

## PR 要求

PR 描述至少包含：

- 关联 issue、spec 或 task id。
- 改动摘要，按文件或模块分组。
- 验收命令和输出摘要。
- 已知风险或未验证项。
- 是否修改 `su-ccb-claude-plugin/references/kernel/`、子模块或公开 API。

如果修改了文档链接，请运行：

```bash
pnpm dlx markdown-link-check <file>
```

如果修改了 console 代码，请运行相关 workspace 的 build/test；如果不确定影响范围，
默认运行：

```bash
pnpm -r build
pnpm -r test
```

## Review 与 archive

review 关注行为变化、边界、验证和回滚风险，不只看格式。

通过 review 后，维护者会补 state、记录 evidence，并按 archive 流程移动 spec。
贡献者不需要手动创建 state 文件，除非 task spec 明确要求。

## 维护者边界

Claude designer 负责需求和质量门；Codex executor 负责执行和验证。维护者会在高影响
决策上保留最终判断权，包括协议内核变更、公开承诺、依赖升级和跨仓分发。

如果你不确定某个改动是否越界，请先提交 issue 或 draft PR，说明你的假设和希望得到的
review 类型。

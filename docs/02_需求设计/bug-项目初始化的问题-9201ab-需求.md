---
id: cmq22nz3754ac31e9099201ab
title: BUG：项目初始化的问题
doc_type: requirement
status: planning
created: 2026-06-06T08:09:20.995Z
analysis_input_hash: 0c7f44f482f8928e4f778f2a80dafb8e7836038d4d67a0df9676e3f63d24e26c
analysis_applied_at: 2026-06-07T06:27:15.750Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

新建项目时有个“复制命令”，应该是初始化CCB的命令，创建的config文件是对的，但是命令第一次执行后直接进入了ccb，我看到“startup_args = ["--effort", "max"]” 这个参数应该是没有生效的

## 原话（verbatim）

新建项目时有个“复制命令”，应该是初始化CCB的命令，创建的config文件是对的，但是命令第一次执行后直接进入了ccb，我看到“startup_args = ["--effort", "max"]” 这个参数应该是没有生效的

## 二、背景与目标

Console 新建项目的 onboarding banner 提供「复制命令」（`su-oriel/server/src/modules/project/project-onboarding.routes.ts:31 buildManualSetupCommand`），生成 `cd <path> && mkdir -p .ccb && cat > .ccb/ccb.config <<'EOF' && ccb` 一体命令；config 模板含 `startup_args = ["--effort", "max"]`（`managed-config.service.ts:62 CLAUDE_AGENT_DEFAULTS`）。

本需求目标：判定「startup_args 未生效」的真伪与根因归属，并澄清复制命令的期望语义（init-only vs init+launch），再决定修复落点。

## 三、讨论与决策

### 证据链（2026-06-07 实测）

1. ccb v7.3.2（release 安装）配置解析用真 tomllib，`startup_args` 在 `ALLOWED_AGENT_KEYS`，claude launcher `service.py:104 cmd_parts.extend(spec.startup_args)`——静态链路完整。
2. realtime_translator（用户 2026-06-06 16:06 新建）4 个 claude pane 进程 cmdline 全部带 `--model opus[1m] --effort max`，无 `--continue`（首启路径）；本需求 16:09 创建。
3. Codex 补证：运行态 session 文件 `.claude-main_claude-session` 的 `start_cmd` 带 `--effort max`；`agents/main_claude/agent.json` 归一化 `startup_args` 为 `["--model","opus[1m]","--effort","max"]`。
4. `--effort` 合法值含 max（claude 2.1.168 `--help` 实测）；settings overlay 与用户 settings.json 均无 effort 覆盖。
5. claude-hud 的 effort 显示默认关闭（`config.ts:178 showEffortLevel: false`，已复核），开启时依赖 Claude Code statusline stdin 的 `effort.level`（2.1.115+）。

### Codex 协商纪要（consult，job_9f9b7f296756）

- 同意「ccb 传参链路无明显丢失」，并以 session/agent.json 两层补强。
- 不同意定性为「根本不是 bug」：准确表述是「ccb 传参 bug 基本排除，但 Claude Code 内部是否采用该 effort、HUD 是否显示、用户是否期望 init-only 仍未判定」。
- 新发现旁路：已有可复用 pane 时 ccb attach 不重启，config 新 `startup_args` 不 retroactive 生效；崩溃恢复用 session 文件旧 `start_cmd`。不符合本次首启场景，但解释「日后改配置看似不生效」。
- 建议：B（观察渠道/显示诊断）+ A（复制命令语义确认）拆分推进，不动 ccb 传参链路。analysis_depth_hint: human-decision。

### Claude 反思（4 锚点）

- **我同意的**：Codex 的限定表述比我最初「reframe 成观察渠道问题」更严谨——证据只覆盖「参数传到进程层」，不覆盖「Claude Code 会话内部采用」；B+A 拆分让根因诊断与产品语义解耦，可并行问用户；证据全绿时不动传参链路代码，避免制造回归。
- **我不同意的**：Codex 把 option C（关闭为非 bug）列为当前选项。HUD 默认不显示 effort 意味着用户大概率「看到了别的什么」才下结论，在观察渠道明确前预设结论方向会污染用户问题的中立性；C 只能是拍板后的可能出口。
- **我的盲点**：attach-不重启旁路和 HUD `showEffortLevel` 默认值都是 Codex 指出后我才补查的——我查到了 HUD 读 effort 的机制却没查显示开关默认值，取证只推进到 OS argv 层就停了。
- **接下来**：复核 HUD 默认值（已完成，属实）→ 写入本分析 → 升级用户 3 个拍板问题 → 停在需求分析完成态，不自动进技术设计（human-decision + 必问项未决）。

## 六、边界 / 不做项

1. 不修改 ccb 传参链路（codex-dual 仓）代码——证据全绿。
2. Claude Code 内部 effort 采用/钳制策略不在本仓与 ccb 仓修复范围，若根因落此只能适配（如显示提示）或上报上游。
3. attach-不重启旁路（运行中改 config 不 retroactive）若需修复，另立需求，不并入本 bug。

## 七、开放问题 / 假设

**待用户拍板（已升级，见需求分析产出）**：

1. 「没生效」的观察渠道与具体所见：HUD（若是，`display.showEffortLevel` 是否已开启）？`/status`？行为体感？还是其他？
2. 复制命令的期望语义：保持 init+launch 一体（现设计），还是改为 init-only（写完 config 提示用户手动跑 `ccb`）？
3. 第二次及以后进入 ccb 时，观察结果是否不同？

**假设（待证伪）**：

- 用户观察的是 2026-06-06 16:06 首启的 realtime_translator 会话。
- `ps` cmdline 可作为 ccb 传参到进程层的有效证据。

## 十三、风险

1. Claude Code 可能在特定模型组合（如 `opus[1m]`）或内部策略下静默忽略/钳制 effort——两仓均不可直接修复。
2. 用户真实诉求可能落在「复制命令直接进入 ccb」的 UX 上而非 effort 本身；只回复「已生效」会漏掉 init-only 诉求。
3. attach-不重启旁路会在「改 config 后重进」场景复现「看似不生效」，易与本 bug 混淆。

## Claude 解读

用户在 Console 新建项目后，使用 onboarding banner 的「复制命令」（由 su-oriel `project-onboarding.routes.ts` 的 `buildManualSetupCommand` 生成：写 `.ccb/ccb.config` 后立即启动 `ccb`）。用户报告两点：① 命令首次执行后直接进入 ccb（语气上为意外）；② config 中 `startup_args = ["--effort", "max"]` 疑似未生效。

实测取证（2026-06-07）：用户 2026-06-06 16:06:12 首启的 realtime_translator 项目 4 个 claude pane 进程 cmdline 均带 `--model opus[1m] --effort max`（无 `--continue`，即首启路径）；运行态 session 文件 `start_cmd` 与 `agent.json` 归一化后的 `startup_args` 同样带全。即 ccb 传参链路（Console 模板 → tomllib 解析 → spec 归一化 → claude launcher → OS argv）全绿，参数已传到进程层。本需求创建于 16:09，用户提 bug 时观察的正是这些已带参进程。

矛盾点收敛为：参数已传到，但用户基于某个未知观察渠道判断其未生效。结合 claude-hud 的 effort 显示开关 `display.showEffortLevel` 默认 false、且显示依赖 Claude Code statusline stdin 上报 `effort.level`，「没看到 max」不能等价于「参数没传」。真实工作项待用户拍板后预计落为：B) 观察渠道/显示诊断；A) 复制命令语义确认（init-only vs init+launch，现设计为后者）。ccb 传参链路本身证据全绿，不立即修改代码。
## 歧义点

1. 「应该是没有生效的」是推断非实证：用户未说明观察渠道（claude-hud？`/status`？行为体感？）。claude-hud 的 `display.showEffortLevel` 默认 false（config.ts:178 实证），且显示依赖 Claude Code statusline 上报——观察渠道决定根因归属（Claude Code 会话内部采用策略 vs 显示层 vs 认知偏差）。→ 升级用户（拍板问题 1）。
2. 「直接进入了ccb」是待修问题还是过程叙述：现设计即 init+launch 一体（banner 文案「完成 ccb.config 写入与 ccbd 启动」+ 测试断言），用户原话「应该是初始化CCB的命令」暗示期望 init-only。产品语义分歧。→ 升级用户（拍板问题 2）。
3. 「第一次执行后」是否暗示后续执行正常：未说明再次进入 ccb 时观察结果是否不同，复现条件未定义。→ 升级用户（拍板问题 3）。
4. 修复落点跨仓未定义：su-oriel（本仓，命令模板/文案）、ccb CLI（codex-dual 外仓，release 安装非本工作区）、Claude Code（上游闭源）三层；若根因在 Claude Code 内部 effort 采用策略，两仓均只能适配或上报。→ 依赖拍板问题 1 的答案，暂不可决。

本清单共 4 项，已满足「至少 3 项」要求；隐私/合规/成本/不可逆类不命中（纯本地 CLI 启动参数与 UX 语义问题，无数据外发、无 schema 变更、无新依赖）。
## 保真差异

① 用户断言「参数应该是没有生效的」；实测进程 argv、session start_cmd、agent.json 三层均带 `--effort max`。本文档将该断言降级表述为「用户观察到的某个信号显示 effort 未达 max」——断言强度被有意削弱，待用户提供观察证据后再定性。
② 用户「直接进入了ccb」语带意外；现设计与 banner 文案明示 init+launch 是预期行为。本文档将其标记为「期望与设计的分歧待拍板」而非既成 bug。
③ 用户主诉聚焦 effort 参数；本分析补充了用户未提及的 attach-不重启旁路（运行中改 config 不 retroactive 生效、崩溃恢复用 session 旧 start_cmd）作为关联风险——属分析扩展，非用户原意。

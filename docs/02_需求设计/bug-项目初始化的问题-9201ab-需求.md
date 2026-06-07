---
id: cmq22nz3754ac31e9099201ab
title: BUG：项目初始化的问题
doc_type: requirement
status: planning
created: 2026-06-06T08:09:20.995Z
analysis_input_hash: 0c7f44f482f8928e4f778f2a80dafb8e7836038d4d67a0df9676e3f63d24e26c
analysis_applied_at: 2026-06-07T06:39:27.912Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

新建项目时有个“复制命令”，应该是初始化CCB的命令，创建的config文件是对的，但是命令第一次执行后直接进入了ccb，我看到“startup_args = ["--effort", "max"]” 这个参数应该是没有生效的

## 原话（verbatim）

新建项目时有个“复制命令”，应该是初始化CCB的命令，创建的config文件是对的，但是命令第一次执行后直接进入了ccb，我看到“startup_args = ["--effort", "max"]” 这个参数应该是没有生效的

## 二、背景与目标

Console 新建项目的 onboarding banner 提供「复制命令」（`su-oriel/server/src/modules/project/project-onboarding.routes.ts:31 buildManualSetupCommand`），生成 `cd <path> && mkdir -p .ccb && cat > .ccb/ccb.config <<'EOF' && ccb` 一体命令；config 模板含 `startup_args = ["--effort", "max"]`（`managed-config.service.ts:62 CLAUDE_AGENT_DEFAULTS`）。

**目标**：复制命令首次执行启动的 claude pane 即带 `--effort max` 生效（现状：仅首次丢参，第二次起正常）。命令语义保持 init+launch 一体（用户拍板 A）。

## 三、讨论与决策

### 用户拍板（2026-06-07，原话）

> 1. 从claude code的终端里看到的   2. A保持现状   3. 退出后第二次跑会正常，仅首次问题

### 第一轮取证（2026-06-07，拍板前）

1. ccb v7.3.2（release 安装，BUILD_INFO：commit 1e1b778，2026-06-06 15:35 安装）配置解析用真 tomllib，`startup_args` 在 `ALLOWED_AGENT_KEYS`，claude launcher `service.py:104 cmd_parts.extend(spec.startup_args)`——静态链路完整。
2. realtime_translator 现存 4 个 claude pane 进程 cmdline 全带 `--model opus[1m] --effort max`；Codex 补证 session 文件 `start_cmd` 与 `agent.json` 归一化 `startup_args` 同样带全。
3. `--effort` 合法值含 max（claude 2.1.168）；settings overlay 与用户 settings.json 无 effort 覆盖；claude-hud effort 显示默认关闭（`config.ts:178`）。

### 第二轮取证（拍板后，时间线重建）

| 时刻（2026-06-06 +0800） | 事件 | 证据 |
|---|---|---|
| 15:23:54 | WSL 开机（旧 daemon 不可能存活） | `uptime -s` |
| 15:35 | 用户更新 ccb 至 v7.3.2 | BUILD_INFO `installed_at` |
| 16:04:36 | 粘贴复制命令，config 写入（此后未再改） | `ccb.config` mtime |
| 16:04:39 | **run-1 启动**（provider 目录创建）；用户亲见 claude 不带 `--effort max` | provider-runtime mtime + 用户拍板 1 |
| 16:04:46/51 | run-1 内 main_claude 两个 session-env（5 秒双启，relaunch churn 迹象） | session-env 目录 mtime |
| 16:06:09-13 | **run-2 启动**：keeper `restart_count=1`，ccbd.sock 重建，agent.json/session 写入，claude 带全参数启动至今 | keeper.json + ps lstart |
| 16:09 | 用户提本需求 | frontmatter created |

**环境关键事实**：`.ccb/agents/` 下存在 `agent1/2/3` + `ccb_codex`（2026-05-20 时代，attempts.jsonl 实证）多代残留；ccbd lifecycle `generation=5`。run-1 = 新版 ccb 在多代残留状态上的首次 mount。

### Codex 协商纪要（consult，job_9f9b7f296756，拍板前）

- 同意「ccb 静态传参链路无丢失」，补强 session/agent.json 两层证据。
- 不同意草率定性「非 bug」：「ccb 传参 bug 基本排除」仅指静态链路，Claude Code 采用、显示、用户期望仍未判定——**拍板后印证了这一审慎**：问题真实存在于首启动态路径。
- 新发现 attach-不重启旁路与崩溃恢复用旧 `start_cmd`——与拍板后锁定的根因方向（恢复路径丢参）直接呼应。
- 建议 B+A 拆分推进。analysis_depth_hint: human-decision。

### Claude 反思（4 锚点，拍板前原文保留）

- **我同意的**：Codex 的限定表述比我最初「reframe 成观察渠道问题」更严谨——证据只覆盖「参数传到进程层」，不覆盖「Claude Code 会话内部采用」；B+A 拆分让根因诊断与产品语义解耦；证据全绿时不动传参链路代码。
- **我不同意的**：Codex 把「关闭为非 bug」列为当前选项——在观察渠道明确前预设结论方向会污染用户问题中立性。
- **我的盲点**：attach-不重启旁路和 HUD 默认值都是 Codex 指出后我才补查；取证只推进到 OS argv 层就停了。**拍板后追加**：更大的盲点是把幸存进程当成首启进程——「带参进程在跑」证明的是 run-2，不证伪用户对 run-1 的观察。
- **接下来**：（已完成）复核 HUD 默认值 → 升级用户三问 → 拍板后二轮取证 → 本定稿。

## 四、功能 / 范围

**范围内**：ccb 首次启动（含带历史残留状态目录的首次 mount）时 `startup_args` 生效问题的根因定位与修复推动。

**范围外**：su-oriel 复制命令与 config 模板（已验证正确，且语义经拍板保持）；Claude Code 内部 effort 策略（上游闭源）；attach-不重启旁路的 retroactive 生效（如需修复另立需求）。

**验收口径**：
1. 场景 A（带多代残留 `.ccb` 状态的目录）与场景 B（全新干净目录）：执行复制命令后**首次** `ccb` 启动的全部 claude pane 进程 cmdline 即带 `--model opus[1m] --effort max`（`ps` 可验）。
2. 第二次及以后启动行为不回归。
3. 修复落地形态（ccb 上游仓修复 vs 上报移交 + 等待 release）由技术设计阶段给出方案并经用户拍板。

## 六、边界 / 不做项

1. 不改 su-oriel 复制命令语义（拍板 A：init+launch 保持）。
2. 不改 ccb 静态传参链路（证据全绿）；根因在首启动态路径，修复在 ccb 上游仓（本机无源码仓，仅 release 安装与 tarball）。
3. Claude Code 内部 effort 采用/钳制策略不在修复范围。
4. attach-不重启旁路不并入本 bug。

## 七、开放问题 / 假设

**用户拍板项**：已全部闭环（见「三、讨论与决策」），无遗留待用户确认项。

**技术设计阶段输入**（下一节点工作项，非用户 TBD）：
1. 在带残留状态目录上复现 run-1 丢参，定位精确机制（候选：recovery/迁移路径用非 config 来源 start_cmd；bootstrap 先行 spawn；relaunch 路径丢参——run-1 五秒双 session-env 是线索）。
2. 确认 ccb 源码仓接入方式或上报通道，给出修复落地方案供拍板。

**假设（已尽可能证实）**：
- run-1 与 run-2 使用同一 binary 与同一 config（mtime 链证实）。
- 用户终端所见可采信为 run-1 真实 spawn 状态（已无法从 ps/session-env 直接恢复 run-1 argv，session-env 为空目录）。

## 十三、风险

1. run-1 现场不可完全复原（进程已死、session-env 空、tmux server 已重建），根因定位依赖在残留状态目录上的主动复现；若复现不稳定，定位成本上升。
2. 修复在 ccb 上游仓，本工作区无源码——推动周期不完全可控；必要时以「上报 + 复现脚本 + 定位报告」交付。
3. attach-不重启旁路会在「改 config 后重进」场景复现「看似不生效」，易与本 bug 混淆，沟通时需区分。
4. 多代残留状态（agent1/2/3、ccb_codex）可能还隐藏其他首启异常，复现时可能发现衍生问题。

## Claude 解读

【用户拍板后定稿，2026-06-07】用户在 Console 新建项目 realtime_translator 后执行 onboarding「复制命令」（写 `.ccb/ccb.config` + 立即启动 `ccb`，su-oriel `project-onboarding.routes.ts buildManualSetupCommand`）。经三问拍板与二轮取证，问题收口为：

**同一 ccb binary（v7.3.2，用户当日 15:35 刚更新）+ 同一 config（16:04:36 写入后未再改）下：首次 `ccb` 启动（16:04:39）的 claude pane 不带 `--effort max`（用户在 Claude Code 终端亲见）；退出后第二次启动（16:06:09）起完全正常**（进程 argv / session start_cmd / agent.json 三层实证带参）。复制命令的 init+launch 一体语义经用户拍板保持现状（选 A），「直接进入了ccb」移出问题范围。

关键环境事实：该目录**非处女目录**——`.ccb/agents/` 下同时存在 `agent1/2/3`（更早默认拓扑时代）与 `ccb_codex`（2026-05-20 时代，attempts.jsonl 实证旧 agent 名）多代残留，ccbd lifecycle generation=5；WSL 当日 15:23 才开机，旧 daemon 不可能存活，即 run-1 是新版代码在旧残留状态上的首次 mount。run-1 期间 main_claude 的 session-env 在 5 秒内出现两次（16:04:46/16:04:51），暗示 pane relaunch churn。

根因方向锁定为 **ccb CLI 首启对残留运行态的 mount/recovery 路径在 spawn 时丢失 startup_args**，具体机制待技术设计阶段复现定位。修复落点在 ccb 上游仓（本机仅 release 安装与 tarball，无源码仓）；本仓 su-oriel 的命令与 config 生成均正确，无代码改动。
## 歧义点

分析期歧义 4 项已全部闭环（用户拍板 2026-06-07，原话见「三、讨论与决策」）：

1. 「没生效」观察渠道 → **已解决**：用户在 Claude Code 终端亲见（非 HUD/体感推断）。结合复现条件，采信为 run-1 真实现象。
2. 「直接进入了ccb」定性 → **已解决**：用户选 A 保持现状（init+launch 一体是预期），移出问题范围。
3. 复现条件 → **已解决**：仅首次启动异常，退出后第二次起正常。
4. 修复落点 → **方向已定**：根因在 ccb CLI 首启路径（上游仓）；本机无 ccb 源码仓（release 安装），「上报移交」还是「接入源码仓修复」由技术设计阶段连同根因复现一并给出方案供拍板。

遗留技术问题（设计阶段输入，非用户待定项）：run-1 丢参的精确机制——候选：① 对多代残留状态的 recovery/迁移路径用了非 config 来源的 start_cmd；② bootstrap 先行 spawn 早于 agent spec 归一化；③ run-1 内 5 秒双 session-env 对应的 relaunch 路径丢参。需在带残留状态的目录上复现验证。
## 保真差异

① 【本轮修正】分析初稿曾把用户断言「参数应该是没有生效的」降级为「观察渠道未知的推断」，并以 16:06 进程带参作为「决定性证据」——用户拍板（仅首次异常、第二次正常）后修正：该证据证明的是**第二次运行**正常，不证伪用户对**首次运行**的观察；用户断言对 run-1 恢复为采信。初稿误判根源是把幸存进程当成了首启进程。
② 用户原话「应该是初始化CCB的命令」对 init+launch 语义的意外语气：经拍板选 A（保持现状），该差异按用户决定归档，不再视为问题。
③ attach-不重启旁路（运行中改 config 不 retroactive 生效）仍为分析扩展，非用户原意，已记入风险节与边界节。

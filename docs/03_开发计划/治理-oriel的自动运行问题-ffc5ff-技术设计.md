---
id: td-ffc5ff-onboarding-docs-teardown
title: "治理：oriel的自动运行问题 技术设计"
doc_type: technical_design
requirement_id: cmq7z6fmcdd8e3116c6ffc5ff
expression_spec: v1
updated: 2026-06-10
---

# 治理：oriel 的自动运行问题 — onboarding 文档治理 + 收尾命令 技术设计

> 一句话：按三种使用角色把上手文档分仓落地（命令单一真相源 + 链接），并把"关不掉"治成"讲清有意常驻 + 文档化 `ccb kill` 收尾" ｜ 最后更新: 2026-06-10
>
> **无独立 status** —— 跟随 requirement `cmq7z6fmcdd8e3116c6ffc5ff`。

## 一、设计概述

**目标对齐**：让一个 GitHub 上刷到 SU-CCB 的人，按"他那种角色对应的那一份 README"就能顺利 装→跑→收尾，中途不踩死路径、不留"以为关了其实还在跑"的后台进程。本设计只讲"怎么落"（文档放哪、命令谁权威、收尾用什么），**不改任何运行行为、不加依赖/API/schema**。

| 项 | 说明 |
|----|------|
| 名称 | onboarding 文档治理 + 收尾命令 |
| 核心职责 | 按角色分仓的上手文档 + 命令单一真相源 + `ccb kill` 收尾 + 系统级预装/每项目 su-init 说明 |
| 设计原则 | 角色分仓 · 命令单一真相源（谁拥有组件谁放权威命令块）· 只改表达不改行为 · 防漂移 |
| 需求来源 | `docs/02_需求设计/治理-oriel的自动运行问题-ffc5ff-需求.md` |
| 覆盖范围 | SU-CCB（顶层 README + docs/install + docs/quickstart）+ SU-Oriel README + plugin/codex-skills README 小修 + check-prerequisites 扩展 |
| 不覆盖 | 不改 oriel 关闭行为、不加 stop API/UI、不做 down 脚本、不引依赖/schema、不重写第三方 installer（故省略六数据/七接口/九依赖） |

## 二、方案与架构

文档放置图（"组件归属"决定命令真相源，"角色路由"决定上手入口）：

```
[组件权威命令块 · 真相源 · 各自 README/官网一份 · 带锚点]
  ccb bridge ............ 官方 README   (./install.sh install / ccb / ccb kill)
  su-ccb-claude-plugin .. 本仓 README   (#install: /plugin install ccb@SU-CCB)
  su-ccb-codex-skills ... 本仓 README   (#install: $skill-installer …)
  SuperClaude(可选) ..... 官方 README   (pipx install superclaude)
        ▲  链接（不复制命令）
        │
[角色路由 README · 只写"顺序 + 链接锚点 + 本角色特有步骤"]
  只用 plugin/skills ─► plugin / codex-skills README 自身
  用 oriel 控制台   ─► SU-Oriel README（独立 clone→装/起→系统级装 plugin/skills[链接]→bridge→每项目 su-init→ccb kill）
  整套开发者        ─► SU-CCB 顶层 README + docs/install.md + docs/quickstart.md
```

| 关键原则 | 说明 |
|---|---|
| 命令单一真相源 | 谁拥有组件，谁的 README 放唯一可复制命令块（带锚点）；角色 README 只写顺序 + 链接，**绝不复制命令** → 根治漂移 |
| 角色分仓 | 三角色三条路；控制台用户的家在 SU-Oriel，**不要求 clone SU-CCB** |
| 只改表达不改行为 | 不动 oriel / ccbd / kernel 任何运行逻辑；本设计是文档 + 既有命令的编排 |

**与现有系统的关系 / 边界**：

| 涉及 | 本设计如何动它 | 保留 / 不动什么 |
|---|---|---|
| SU-CCB docs（install/quickstart/README） | `[MODIFY]` 修漂移、角色路由、版本分层 | 不改 kernel/lib/协议 |
| SU-Oriel README | `[MODIFY]`（子仓） 新增控制台用户上手 | 不改 oriel server/web 代码、不改启停行为 |
| `scripts/check-prerequisites.sh` | `[MODIFY]` 加 ccb/tmux 检查 + 边界说明 | 不改其退出码契约语义 |
| plugin/codex-skills README | `[MODIFY]` 小修：强调系统级 + 锚点 | 不改 skill 逻辑 |

## 三、关键决策与取舍

- **命令归属**：选"组件 README 拥有权威命令块 + 角色 README 链接锚点"；否决"角色 README 各自复制完整命令"（必漂移，正是要治的病），也否决"只甩裸链接"（评估者还是不会装——链接要写成带步骤的明确引用）。
- **插件传递文案**：选"系统级装 plugin → CCB 起项目时 `materialize_claude_home_config()` 把系统 `~/.claude/settings.json`（含 `enabledPlugins`+marketplace）投影进 slot"；否决"plugins 目录软链继承"的写法（源码证实 plugins 非软链，只有 commands/skills 软链）。
- **收尾形态**：选 A —— 文档化 `ccb kill` / `ccb kill -f` 为唯一 runtime 收尾，oriel dev server/web 写"关闭对应终端 / Ctrl-C"；否决 thin `su-down` 脚本（oriel dev 是前台 `exec` 进程、无 pidfile，脚本强杀会误伤用户自己的 node/vite，且要扩到改启动脚本写 pidfile = 扩范围）。
- **快速试用**：选"新增评估者向'5 分钟看控制台'最短路径（置于 SU-Oriel README + 顶层 README 首屏），不改现有 quickstart 语义"；否决"把现有协作闭环 quickstart 直接改成评估者向"（会丢掉开发者闭环演示价值）。
- **check-prerequisites 扩展**：选"加 ccb/tmux 存在性检查 + 明确输出'CLI 在 ≠ 已登录/已 init/plugin 已启用，还需手动 X'"；否决"扩到自动验证登录/init"（做不到，且会制造新假绿）。探测用 `ccb --print-version`/`--help`，**不用 `ccb version`**（会联网检查更新）。
- **版本口径**：选"一份分层版本表（Python：bridge 3.10+ / 本仓脚本 3.8+；Node 18+；pnpm 10.25.0；git 2.30+）放顶层，其它链接"；否决"各文档各写一个数字"（已造成 3.8 vs 3.10 不一致）。

## 四、核心流程 / 逻辑

控制台用户（独立 SU-Oriel）端到端，以及插件如何到达 agent：

```
[系统级·一次性] 装并登录 Claude/Codex CLI（用户自做，不可代办）
      ├─ 系统级装 plugin : /plugin marketplace add Im-Sue/su-ccb-claude-plugin ; /plugin install ccb@SU-CCB
      ├─ 系统级装 codex-skills : $skill-installer install …/ccb-execute (+ ccb-doc)
      └─ 装 bridge : ./install.sh install
                      │
                      ▼
[起 CCB / Oriel]  CCB materialize_claude_home_config()
      ├─ 把系统 ~/.claude/settings.json（enabledPlugins{ccb@SU-CCB} + marketplace）投影进每个 slot
      └─ commands / skills 软链回系统级   →   agent 继承 /ccb: 能力
                      │
                      ▼
[控制台·加项目]  ProjectOnboardingBanner 查 ready：
      runtime = .ccb/ccb.config 存在 ; knowledge = docs/.ccb/docs-structure-contract.yaml + 00_文档地图.md/index
      └─ 一键投递 /ccb:su-init（需 ccbd socket + ccb.config 能解析 claude agent）或终端手动
                      │
                      ▼
[用] 看到控制台/协作在转   →   [收尾] 项目目录 `ccb kill`（残留 `ccb kill -f`）；oriel dev 终端各 Ctrl-C
```

**模拟示例**：新用户 Bob（Mac）。① brew/nvm 备齐 → ② 系统级 `/plugin install ccb@SU-CCB` + Codex `$skill-installer install …/ccb-execute` + bridge `./install.sh install` → ③ `git clone SU-Oriel && cd SU-Oriel && pnpm install && pnpm build`，起 `scripts/dev-server.sh`、`dev-web.sh` → ④ 浏览器开控制台、Add Project 指向某仓 → 顶部横幅提示 → 点"投递 /ccb:su-init" → ⑤ 看到节点/任务投影 → ⑥ 不用了：该项目目录 `ccb kill`，两个 dev 终端各 Ctrl-C。**全程 Bob 没 clone SU-CCB。**

| 处理规则 | 说明 |
|---|---|
| 命令引用 | 角色 README 用"见 plugin README `#install`"式锚点链接；CI 死链检查保证锚点有效 |
| 收尾边界 | `ccb kill` 只停当前项目 ccbd/agents/tmux namespace，不碰别的项目；dev 进程交给终端 |
| 假绿防护 | check-prerequisites 输出分两段：自动可验（node/pnpm/git/python/ccb/tmux）+ 仅提示（CLI 登录/init/plugin 启用） |

## 五、测试策略

- [ ] 死链 / 锚点检查：所有角色 README 的命令锚点链接有效（可并入 `check-cross-repo.sh` 或新 lint）
- [ ] fresh-clone smoke：干净环境照 SU-Oriel README 走一遍，能起控制台、加项目、跑 su-init
- [ ] 插件继承验证：系统级装 plugin → 起 CCB → 新 slot 里 `/ccb:` 可用（对照 settings.json 投影）
- [ ] 收尾实测：`ccb kill` 后该项目 ccbd/tmux 真停；再 `ccb` 正常重建
- [ ] 口径校验：全仓 grep 无 `apps/ccb-console`、无根目录 pnpm 假设；版本表各处一致

## 八、文件结构 / 变更清单

```
SU-CCB（主仓）
  README.md                        [MODIFY] 角色路由 + HTTPS clone + 版本表锚点
  docs/install.md                  [MODIFY] 修漂移(删 apps/ccb-console、改 su-oriel/ + plugin kernel 路径)、版本分层
  docs/quickstart.md               [MODIFY] 标注受众=开发者；首屏链接评估者快速试用
  scripts/check-prerequisites.sh   [MODIFY] 加 ccb/tmux 检查 + 仅提示段(ccb --print-version)
su-oriel（子仓）
  README.md                        [MODIFY] 控制台用户完整上手 + 评估者 5 分钟路径 + ccb kill 收尾
su-ccb-claude-plugin（子仓）
  README.md                        [MODIFY] install 块加锚点、强调系统级
su-ccb-codex-skills（子仓）
  README.md                        [MODIFY] install 块加锚点、强调系统级(~/.codex/skills 用户级)
```

## 十、迁移影响与风险

- **受影响**：四个仓的文档 + 一个脚本；无运行时代码、无 schema/API、无数据迁移。
- **打法**：跨仓——子仓（su-oriel / plugin / codex-skills）各自 commit→push，主仓抬 gitlink；主仓 docs/脚本本仓直接改。按需求「八、拆分预览」的块 1~8 切分。
- **回滚 / 恢复**：纯文档/脚本，`git revert` 即可。

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| "不重复命令"过严 → 角色 README 变甩链接 | 中 | 评估者还是不会装 | 链接写成带步骤的明确引用 + 锚点；每步留一句上下文 |
| check-prerequisites 假绿 | 中 | CLI 在但没登录/init，用户以为齐了 | 输出分"自动可验/仅提示"两段，不声称验证了登录 |
| 外部命令上游漂移（ccb/SuperClaude） | 中 | 命令过时 | 只链官方入口 + 标核验日期，不深拷其步骤 |
| 跨仓 gitlink 不同步 | 低 | 子仓 README 改了主仓没抬指针 | 按既有子仓→主仓 gitlink 流程；归档前 `check-cross-repo.sh` |
| 插件投影文案随 ccb 版本变 | 低 | 未来 ccb 改 materialize 逻辑 | 文案锚定"系统级装 → CCB 投影"概念，不写死内部函数名 |

## 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-06-10 | v1.0 | 初版（Codex 协商 job_0857e4855d91；插件传递机制源码确认；收尾选 A：ccb kill，不做 down 脚本） |

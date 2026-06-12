---
id: cmq7z6fmcdd8e3116c6ffc5ff
title: 治理：oriel的自动运行问题
doc_type: requirement
status: delivered
created: 2026-06-10T11:18:20.821Z
analysis_input_hash: d44930b37771f2f5153ada13a96390977952f0c135d94fde0fc02c81bbcd82d8
analysis_applied_at: 2026-06-10T15:07:54.410Z
expression_spec: v1
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

1. 用户反应在github上看到项目不知道如何启动、如何快速启动、如何关闭
思考一下是我们readme、相关教程文档描述不够清晰还是我们缺少必要的一键安装、一键启动的或者快速命令完整安装、启动的脚本？整套系统的安装不止是oriel，还会涉及到ccb、superclaude、su-claude-plugin、su-codex-skills
## 原话（verbatim）

1. 用户反应在github上看到项目不知道如何启动、如何快速启动、如何关闭
思考一下是我们readme、相关教程文档描述不够清晰还是我们缺少必要的一键安装、一键启动的或者快速命令完整安装、启动的脚本？

## 二、背景与目标

**目标对齐**:一个在 GitHub 上刷到 SU-CCB 的人,现在大概率会卡住——不知道怎么装、怎么快速看到它真在跑、怎么干净关掉。这个需求要把这条路顺起来:**装上 → 几分钟内看到控制台/一次协作真的转起来 → 不想用时能干净收尾**;中途不卡壳,也不留下他"以为关了其实还在跑"的后台进程。说白了:把"上手"和"收尾"这两端,从"靠猜"变成"照着走就行"。

关键前提:**SU-CCB 有三种使用角色,是三条不同的上手路,文档必须按角色分开**(混在一起就是现在最大的坑):

| 用户角色 | 手上 clone 哪个仓 | plugin/skills 怎么来 | 上手文档的家 |
|---|---|---|---|
| 只用 plugin/skills | 都不 clone | 系统级 CLI 装:`/plugin install ccb@SU-CCB` + Codex `$skill-installer` | plugin README + codex-skills README(已有) |
| **用 oriel 控制台** | **只 clone SU-Oriel**(不碰 SU-CCB) | 同上(系统级装,文档链接过去) | **SU-Oriel 自己的 README** |
| 整套开发者 | `clone --recursive` SU-CCB | 随主仓作为子仓拉齐 | SU-CCB 顶层 README + docs/install/quickstart |

现状有两个硬伤(都已用代码/文档核验):

1. **安装/上手文档过时写错 + 角色混淆**:`docs/install.md`、`docs/quickstart.md` 还在教人去早就不存在的老目录 `apps/ccb-console/` 跑命令、在根目录 `pnpm install`;且把三种角色的路混成一条。但项目早拆成了 multi-repo(= 一个主仓 + 几个各自独立的子仓,用 git submodule 钉版本嵌进来):控制台在 `su-oriel/`、协议内核在 `su-ccb-claude-plugin/`,根目录根本没有 pnpm 工程。**照现有文档做,第一步就失败。**
2. **后台进程"有意常驻但没说清"**:打开 oriel 时,它会在后台拉起 `project ccbd`(ccbd = CCB 的常驻守护进程,挂在 tmux 后台替你盯项目跑)。关掉 oriel 时这些守护进程**故意继续活着**(让长任务别被打断)——是设计意图,不是 bug。但现在既没说"这是有意的",也没给"想停的时候怎么停",用户就会以为"关不掉"。

目标受众优先级:三种角色都要覆盖,但**首屏先保路人评估者**(GitHub 上想几分钟看到东西在跑、门槛越低越好);整套开发者与控制台用户走各自路径。

## 三、讨论与决策

| 议题 | 拍板 | 理由 |
|---|---|---|
| 核心是"文档不清楚"还是"缺脚本"? | 都不是单一项——**两层都坏**;本次走 **B 档**(文档优先 + 最小启停脚本) | 照现有文档做第一步就失败;在错文档上叠脚本只会把失败藏更深 |
| 标题"oriel 自动运行问题"是 bug 吗? | **不是 bug,是有意常驻**:关 oriel 后 `project ccbd` 故意继续跑(长任务不被打断) | 用户确认这是预期设计 |
| 那"关不掉"怎么办? | 不改"关 = 杀"的行为;改为**讲清楚"这是有意的" + 提供手动收尾命令** `ccb kill` | 既保住有意常驻的设计,又给用户明确的收尾出口 |
| 受众优先级? | 三角色都覆盖,**首屏先保路人评估者** | 原话"在 github 上看到",第一因是评估门槛 |
| 外部 + 自有组件给链接还是给命令? | **给全每个组件真实命令 + 完整有序引导流程**(含 ccb bridge、SuperClaude、我方 plugin/skills) | 用户明确:要有"完整的引导安装流程和命令" |
| 控制台用户要 clone SU-CCB 吗? | **不要**;控制台用户**单独 clone SU-Oriel**,plugin/skills 从 GitHub 装;**按角色分仓落文档** | 控制台用户手上只有 SU-Oriel,看不到 SU-CCB 的 docs |
| plugin/skills 装哪一级? | **系统级**(用户级)Claude Code / Codex CLI 先装好,再起 CCB/oriel,**CCB 派生 agent 才继承** | 已核实:slot 的 `.claude/skills`、`commands` 软链回系统级,系统级装一次全 slot 继承 |
| plugin/skills 命令写进 SU-Oriel 吗? | **不重复**,SU-Oriel 只**链接**到 plugin/codex-skills 各自 README(权威源) | 同一条命令抄多份必漂移——正是本次要治的病 |
| 每加一个项目后做什么? | 文档讲清:oriel 顶部 **ProjectOnboardingBanner** 一键投递或手动 `/ccb:su-init` | 控制台已有现成引导组件,文档需对齐 |

> 协商中纠正一处:SuperClaude / Superpowers 是**可选增强**,不是硬依赖;必需的是底层 `claude_codex_bridge`(提供 `ccb` 命令)+ 我方 `su-ccb-claude-plugin` + `su-ccb-codex-skills`。

## 四、功能 / 范围

本次交付(B 档)**按角色分仓落地**,交付物跨 SU-CCB 与 SU-Oriel 两个仓 + 我方 plugin/skills README 小修。

### 4.1 各仓交付物

- **SU-CCB(顶层 README + `docs/install.md` + `docs/quickstart.md`)**:服务"整套开发者"+ 充当总览导航(指清三种角色各去哪)。修漂移(删 `apps/ccb-console/`、根目录 pnpm 假设,改对 `su-oriel/`、`su-ccb-claude-plugin/`)、版本口径分层、README 补 HTTPS `git clone --recursive`。
- **SU-Oriel README(本次纳入改动的另一个仓)**:服务"控制台用户"的完整上手——`git clone SU-Oriel`(独立,不碰 SU-CCB)→ 装依赖/构建/起控制台 → 装底层 bridge → **系统级装 plugin/skills(链接权威 README,不重复命令)** → 每项目 `/ccb:su-init`(见 4.4)→ `ccb kill` 收尾。
- **plugin / codex-skills README**:服务"只用 plugin/skills"角色——已有权威 quickstart,本次小修:强调**系统级安装**、与上面两仓的链接收敛。

### 4.2 完整、有序、可照抄的引导安装流程

覆盖**每个组件**,每步给**实际命令**,标注必需/可选 + 哪几步必须用户自己做(装 agent CLI + 鉴权)。各组件命令**真相源**速查(详细引导按角色编排在各仓 README):

   | 组件 | 必需? | 安装命令(真相源) | 起 / 停 |
   |---|---|---|---|
   | 底层 ccb bridge | **必需** | 发行包 `tar -xzf ccb-*.tar.gz && cd ccb-* && ./install.sh install`;或源码 `git clone https://github.com/SeemSeam/claude_codex_bridge.git && cd claude_codex_bridge && ./install.sh install`;更新 `ccb update` | 起 `ccb`;**停 `ccb kill`**(收尾关键);强制 `ccb kill -f` |
   | Claude Code / Codex CLI | **必需**(至少一个) | 用户自行安装 + **登录鉴权**(我们不代办,只检查 + 提示) | —— |
   | su-ccb-claude-plugin(**主入口**) | **必需** | **系统级** Claude Code 内:`/plugin marketplace add Im-Sue/su-ccb-claude-plugin` → `/plugin install ccb@SU-CCB` | —— |
   | su-ccb-codex-skills | **必需** | **系统级** Codex:`$skill-installer install https://github.com/Im-Sue/su-ccb-codex-skills/tree/main/skills/ccb-execute`(再装 `ccb-doc`);或手动 `git clone … && cp -r skills/* ~/.codex/skills/` | —— |
   | SU-Oriel 控制台 | 用控制台时 | 控制台用户:`git clone https://github.com/Im-Sue/SU-Oriel.git && cd SU-Oriel && pnpm install && pnpm build`;整套开发者:随 SU-CCB 子仓 `cd su-oriel && …` | dev 起 `scripts/dev-server.sh` + `dev-web.sh` |
   | SU-CCB 主仓 + 3 子模块 | 仅整套开发者 | `git clone --recursive`(HTTPS 与 SSH 都给) | —— |
   | 项目初始化 | 必需(每项目) | `/ccb:su-init`(见 4.4) | —— |
   | SuperClaude(可选增强) | 可选 | `pipx install superclaude && superclaude install`;或源码 `git clone https://github.com/SuperClaude-Org/SuperClaude_Framework.git && cd SuperClaude_Framework && ./install.sh`;自检 `superclaude doctor` | —— |

### 4.3 系统级预装(plugin/skills 装哪一级)

文档须明确:**plugin/skills 要先装进系统级 CLI(Claude Code `~/.claude`、Codex `~/.codex`),再起 CCB/oriel**,这样 CCB 派生的每个 agent slot 才继承这些命令/技能。依据:已核实 slot 的 `provider-state/.../.claude/skills`、`commands` **软链回系统级**,系统级装一次全 slot 继承。⚠️ 但 `.claude/plugins` 是 per-slot 真实目录(非软链),`/ccb:` 插件命令到各 slot 的下发机制须在技术设计核实,确保"装哪一级"写对。

### 4.4 每项目 onboarding(加项目后做什么)

文档须讲清控制台里"**加项目 → 看横幅 → 跑 su-init**"这条每项目初始化流:oriel 顶部 `ProjectOnboardingBanner` 会查 onboarding-status 并提示——可**一键向主项目 ccbd 投递 `/ccb:su-init`**,或在终端手动 `/ccb:su-init`(失败用 `ccb pend <jobId>` 排查)。`su-init` 生成 `CLAUDE.md` / `AGENTS.md` / `docs/.ccb/` 骨架。

### 4.5 其它

- **新增"快速试用"路径**(给路人评估者):从"GitHub 看到"到"最快看到控制台/一次协作真在跑"的最短路线,首屏可见。
- **写清楚 + 给手动收尾**:文档明确 `project ccbd` 是有意常驻 + 收尾命令 `ccb kill`(必要时 `ccb kill -f`)。
- **最小启停脚本 + 接入前置检查**:复用 `su-oriel/scripts/*` 和 `ccb` 既有命令串薄脚本;`scripts/check-prerequisites.sh` 接进文档并扩展/标注边界(它现在不查 `ccb`/`tmux`/CLI/鉴权,"绿"会误导)。

**完成标准**:三种角色各自照"自己仓的 README"都能把所需组件按实际命令(系统级)装好、几分钟看到东西在跑、每加项目知道跑 `su-init`、并能用 `ccb kill` 干净收尾;命令单一真相源、无重复漂移;现有文档死路径清零。

## 五、业务规则

1. **不改有意常驻的行为**:关闭 oriel 不得变成强制杀掉 `project ccbd`;持续运行是设计意图。
2. **手动收尾必须存在且被文档化**:用户必须有一条明确、可复制的命令(`ccb kill`)把整套(含常驻守护进程)干净停掉。
3. **按角色分仓落文档**:控制台用户路径 = 独立 `clone SU-Oriel`,**不要求 clone SU-CCB**;控制台上手的家在 SU-Oriel README。
4. **plugin/skills 装系统/用户级**(非仅项目级),且在跑 CCB/oriel **之前**,确保派生 agent 继承。
5. **命令单一真相源**:plugin/skills 安装命令的权威源在各自 README;SU-Oriel / SU-CCB 文档**链接、不重复**。
6. **每个组件都要给实际命令 + 完整有序引导**(含外部 ccb bridge、SuperClaude)。
7. **"不全自动"的精确含义**:仅指不替用户执行第三方 installer、不替用户完成鉴权;**不等于省略命令或甩链接**。
8. **前置检查不得假绿**:`check-prerequisites.sh` 要么扩展覆盖真实可运行性(含 ccb/tmux/CLI),要么显式标注覆盖边界。
9. **文档以 multi-repo 现实为唯一口径**:不得保留任何指向 `apps/ccb-console/` 或根目录 pnpm 工程的旧路径。
10. **版本口径分层声明**:不同组件不同最低版本(如 Python:bridge 3.10+ / 本仓脚本 3.8+)分层写清。

## 六、边界 / 不做项

1. **不做**"关闭 oriel = 杀掉后台守护进程"的行为改造(与决策 #2 冲突)。
2. **不做**真·一键完整安装里"**替用户自动执行**"的部分:不替用户跑第三方 installer、不替用户完成鉴权(客观不可行)。**注意:命令和引导要给全——"不自动执行" ≠ "不给命令"。**
3. **不(本轮)承诺** Console UI 上的"停止"按钮 / 新增 HTTP stop API;手动收尾本轮先走 CLI(`ccb kill`)+ 文档。
4. **不做**跨平台大 installer;脚本保持"薄"。
5. **SU-Oriel / SU-CCB 文档不重复** plugin/skills 安装命令,链接到权威 README。
6. **不重写** SuperClaude / Superpowers 的安装逻辑,但**给出其官方安装命令**并纳入引导。
7. **不改** kernel / 协议 / 业务代码逻辑;本需求是 onboarding 表达层(跨 SU-CCB + SU-Oriel 文档)+ 收尾命令,不动协作内核、不改 oriel 业务行为。

## 七、开放问题 / 假设

技术移交(留给技术设计定,非用户待拍板):

1. **手动收尾的形态**:直接文档化 `ccb kill`,还是再包一个 `down` 薄脚本(顺带停 oriel dev server/web)?
2. **引导流程承载 + 快速试用载体**:SU-Oriel README 怎么编排三段(装控制台 / 系统级装 plug/skills 链接 / 每项目 su-init);"快速试用"是改造现有 `quickstart.md`(现演示协作闭环、偏开发者)还是新增评估者向"5 分钟看控制台"。
3. **核实 `/ccb:` 插件命令的 slot 下发机制**:skills/commands 已确认软链自系统级;但 `.claude/plugins` 是 per-slot 真实目录,需确认 `ccb` 插件如何到达各 slot(seed/copy/各装),据此把"装哪一级"写对,别误导。
4. **枚举 ProjectOnboardingBanner 的完整 onboarding-status 检查项**:`su-init` 之外是否还有每项目步骤(agent/slot 配置、ccbd confirm-restore 等),与横幅指引对齐。
5. **check-prerequisites.sh 扩展 vs 标注**:扩展去探测 ccb/tmux/CLI/鉴权,还是只加文档边界说明?

假设:

- 我方组件命令取自各自 README(权威):plugin `/plugin install ccb@SU-CCB`;codex-skills `$skill-installer …` 或 `cp -r skills/* ~/.codex/skills/`;`/ccb:su-init`。
- 外部组件命令已**联网核验**(2026-06-10):ccb `./install.sh install`、停 `ccb kill`;SuperClaude `pipx install superclaude && superclaude install`。命令随上游演进,落档复核。
- 系统级继承已**核实**:slot `provider-state/.../.claude/{skills,commands}` 软链回系统级(plugins 例外,见开放问题 3)。
- 本轮基于**静态读代码/文档,未实跑** oriel server/ccbd;技术设计/实施应实测一次"加项目→su-init→开 oriel→后台起 ccbd→关 oriel→ccbd 仍在→`ccb kill`→干净"。

## 八、拆分预览

给任务拆分一个起点(粗切,跨仓):

- 块 1 · SU-CCB 文档纠偏:改对 `install.md`/`quickstart.md` 的 multi-repo 路径 + 角色分流 + 版本分层 + README 补 HTTPS clone。
- 块 2 · SU-Oriel README 控制台上手:独立 clone → 装/起 → 系统级装 plugin/skills(链接)→ bridge → 每项目 su-init → `ccb kill`。
- 块 3 · 完整引导安装流程 + 系统级预装说明:每组件实际命令 + 顺序 + "装系统级才继承"。
- 块 4 · 每项目 onboarding 说明:对齐 ProjectOnboardingBanner 的 su-init 流。
- 块 5 · 快速试用路径:评估者向"最快看到在跑"。
- 块 6 · 生命周期讲清 + 手动收尾:文档化"有意常驻" + `ccb kill`。
- 块 7 · 前置检查接线:`check-prerequisites.sh` 接进文档并扩展/标注边界。
- 块 8 · plugin/codex-skills README 小修:强调系统级安装 + 链接收敛。

## 十、接口(草案)

本需求基本不涉及新接口(无数据模型变更,省略"九、数据";纯 onboarding 文档,省略"十一、界面")。

- 本轮**不新增 HTTP API**(沿用既有 `/api/projects/:id/onboarding-status` 与 su-init 投递,仅文档对齐,不改其行为)。
- 唯一"对外入口"是命令行收尾:从项目目录执行 **`ccb kill`**(+ 可选停 oriel dev 进程);是否包 `down` 薄脚本留技术设计。

## 十二、交互 / 流程

**控制台用户(独立 SU-Oriel)从"看到"到"收尾"的路线:**

```
GitHub 看到 → git clone SU-Oriel(不碰 SU-CCB)
      │
      ▼
[1] 系统级 CLI 先装好 plugin/skills(/plugin install ccb@SU-CCB、Codex $skill-installer)
      │    + 装底层 bridge(./install.sh install)；跑前置检查脚本
      ▼
[2] cd SU-Oriel && pnpm install && pnpm build → 起控制台(dev-server.sh + dev-web.sh)
      │
      ▼
[3] 控制台里【添加项目】→ 顶部 onboarding 横幅 → 一键/手动 /ccb:su-init   ← 每个项目都做
      │
      ▼
[4] 看到控制台/协作真的在转   ← "哦,原来是这样"
      │
      ▼
[5] 不用了 → ccb kill → 整套干净停掉(含后台 project ccbd)
```

**守护进程的心智模型——为什么"关 oriel 后台还在跑"是有意的:**

```
开 oriel(控制台/总管)
   └─ 后台拉起 project ccbd(长工,挂 tmux,替你盯项目跑)

关 oriel(总管下班)
   └─ 长工【有意】继续干活   ← 长任务不被打断(设计如此,不是 bug)

想彻底收工
   └─ 执行 `ccb kill` → 连长工一起辞退 → 干净
```

## 十三、风险

| 风险 | 影响 | 处理 |
|---|---|---|
| 文档纠偏不彻底,残留死路径 | 新人照着走仍第一步失败 | 以"根仓无 pnpm 工程、`apps/ccb-console` 不存在"为硬校验,逐条清死链 |
| 角色混淆没拆干净 | 控制台用户被引去 clone SU-CCB,白绕一圈 | 按角色分仓,SU-Oriel README 自洽,不要求 SU-CCB |
| "装哪一级"写错 | plugin 装在项目级 → 派生 agent 不继承 `/ccb:`,功能像没装 | 文档明确系统级;开放问题 3 先核实 plugin slot 下发机制 |
| 命令在多仓重复 | 抄三份迟早对不上,又制造新漂移 | 单一真相源 + 链接;外部命令标核验日期 |
| "有意常驻"没讲清 | 用户仍觉得"关不掉" | 文档明说设计意图 + `ccb kill`(功能 4.5) |
| 未实跑验证生命周期/每项目流 | 收尾或 su-init 流漏一环 | 技术设计/实施实测一次完整闭环 |

## Claude 解读

这个需求表面问"是文档不清楚还是缺脚本",真问题是 **GitHub 首次上手的体验在两端都断了,而且按角色全混在一起**:

- **进不去 + 角色混淆**:现有安装/快速上手文档过时写错(指向不存在的 `apps/ccb-console/`、根目录 `pnpm install`),还把三种使用角色(只用 plugin·用控制台·整套开发者)混成一条路。其中控制台用户**根本不该 clone SU-CCB**——他们单独 clone SU-Oriel,plugin/skills 从 GitHub 系统级装。
- **出不来**:打开 oriel 会在后台留下**有意常驻**的守护进程(`project ccbd`),没说"这是故意的"、也没给收尾命令,于是体感"关不掉"。

经多轮拍板,方向定为 **B 档**;"关不掉"不当 bug 修(常驻是设计意图),改为**讲清楚 + 手动收尾 `ccb kill`**。交付**按角色分仓**,跨 SU-CCB(整套开发者 + 总览)与 **SU-Oriel README**(控制台用户上手),plugin/skills 命令**单一真相源在各自 README、其它仓只链接不重复**(否则又制造漂移)。

两条用户补充的强约束:
1. **系统级预装**:plugin/skills 先装进系统级 Claude Code / Codex CLI,CCB 派生 agent 才继承——已核实 slot 的 `.claude/{skills,commands}` 软链回系统级(plugins 是 per-slot 真实目录,下发机制留设计核实)。
2. **每项目 onboarding**:控制台加项目后,顶部 `ProjectOnboardingBanner` 一键/手动跑 `/ccb:su-init`,文档要把这条流讲清。

一句话:**把三种角色的上手各归各仓、命令给齐且只放一处真相源,把"系统级装才继承""每项目要 su-init""关了用 ccb kill 收尾"这些隐性前提全摆到台面上。**
## 歧义点

> 形态:每条 = 问题 → 拍板/移交 → 理由。已全部闭环,无待定项。

1. **[已拍板] 核心是"文档问题"还是"脚本问题"?** → 两层都坏(文档过时写错 + 后台行为不透明);走 **B 档**。理由:照现有文档第一步就失败。

2. **[已拍板] "oriel 自动运行 / 关闭"是 bug 还是设计?** → **有意常驻**:关 oriel 后 `project ccbd` 故意继续跑。不做"关 = 杀",改为文档化 + 手动 `ccb kill`。理由:用户确认是预期设计。

3. **[已拍板] 受众优先级?** → 三角色都覆盖,**首屏先保 GitHub 路人评估者**。理由:原话"在 github 上看到"。

4. **[已拍板] 给链接还是给命令?** → **给全每个组件真实命令 + 完整有序引导**(含外部 ccb/SuperClaude + 我方 plugin/skills);"不全自动"仅指不替用户跑第三方 installer / 不替用户鉴权,不等于省略命令。理由:用户明确要"完整的引导安装流程和命令"。

5. **[已拍板] 控制台用户要 clone SU-CCB 吗?文档落哪?** → **不要**;控制台用户单独 clone SU-Oriel,**按角色分仓**:控制台上手写进 **SU-Oriel README**,plugin/skills 命令**链接到各自权威 README、不重复**。理由:控制台用户手上只有 SU-Oriel,且单一真相源防漂移。**本次交付因此跨 SU-CCB + SU-Oriel 两仓。**

6. **[已拍板] plugin/skills 装哪一级?** → **系统级**(用户级)CLI 先装,再起 CCB/oriel,派生 agent 才继承。理由:已核实 slot 的 `.claude/{skills,commands}` 软链回系统级。

7. **[已拍板] 每加项目后做什么?** → 文档讲清"加项目→看 onboarding 横幅→一键/手动 `/ccb:su-init`"。理由:控制台已有 `ProjectOnboardingBanner`,文档须对齐。

8. **[移交技术设计] 手动收尾形态**(`ccb kill` 文档化 vs 包 `down` 脚本)、**引导/快速试用载体编排**、**`/ccb:` 插件命令的 slot 下发机制核实**(skills/commands 已确认软链,plugins 为 per-slot 真实目录)、**ProjectOnboardingBanner 完整检查项枚举**、**check-prerequisites 扩展 vs 标注**。属实现/核实权衡,移交技术设计。
## 保真差异

记录"我对原话的扩展 / 收窄 / 修正",便于审计保真:

- **扩展**:用户把问题框成"文档 vs 脚本"二选一;我据核验扩展为"**两层都坏**"+ "现有文档**过时写错、照做即失败**"+ "**三种角色被混成一条路**"。基于事实加重,非凭空放大。
- **收窄**:标题"自动运行问题"一度疑似 bug;经拍板澄清为"**有意常驻**",方向从"修 bug"收窄为"文档化 + `ccb kill`"。
- **强化(忠实落实用户补充)**:用户先后明确——(a) 要"完整的引导安装流程和命令";(b) 要含我方 `su-ccb-claude-plugin`/`su-ccb-codex-skills`;(c) plugin/skills 先**系统级**装好让 CCB agent 继承;(d) 讲清 oriel 每加项目后的步骤。我据此把"引导"上调为"每组件实际命令 + 系统级安装 + 每项目 su-init 流",并按角色分仓。属对原话"一键/完整安装、启动脚本/引导"的忠实落实。
- **修正/分层**:用户把 oriel/ccb/superclaude/plugin/skills **并列**为"整套安装",并暗含"控制台用户也要这一套";我据实分层——控制台用户**不 clone SU-CCB**(独立 SU-Oriel);必需 = bridge + plugin + codex-skills,SuperClaude/Superpowers **可选**;命令真相源单一(各自 README),其它仓链接不重复。与原话并列列举有出入,已在范围/决策说明。
- **边界收窄**:用户期待"一键完整安装/启动";收窄为"命令给全 + 我们能控制的部分一键化,但不替用户跑第三方 installer / 不替用户鉴权",比"真·一键"窄,已显式标注。

---
id: cgagh71xo5g35r7cej9fqn0ds
title: "需求级动态 agent 拓扑（决策 agent 动态招募 + rolepack 角色）"
doc_type: requirement
status: deferred
created: 2026-06-07T08:13:04.841Z
analysis_input_hash: e69d97af82ef33646acf0bf26f2aca3a49803b5995e08df59986e6dad2fcad7b
analysis_applied_at: 2026-06-07T08:15:09.820Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

slot 从「固定 claude+codex 双人组」升级为「常驻决策 agent + 需求级动态成员」：需求绑定 slot 后，决策 agent（slotN_claude）分析需求并输出队伍决策单（JSON intent：cli × 角色 × 技能加减），oriel 需求级拓扑 API 负责校验、装配（角色守则 + 技能组合）、写 config、`ccb reload`，把异构 CLI 成员（claude/codex/gemini/opencode）动态追加到该 slot 窗口尾部；推进中可按同链路继续追加；需求归档/取消时自动回收全部动态成员。

可选项由两层目录承载：roles/（角色库，rolepack 机制，role.toml 名片自描述兼容 cli + 标配 skills 引用）与 skills/（公用技能库），按官方/个人/项目三格分层发现，文件夹即菜单，用户丢入自定义角色/技能后下一次招募即生效、零重启。

依赖 d21ff1（oriel 动态增删 slot，已 delivered）交付的 ProjectSlotTopology / ManagedConfigMutationLock / reload 封装 / slotAgentOverridesJson 作全部地基；本需求即 d21ff1 范围外清单第 2 条（per-slot provider 组合 / slot 模板）的正式立项延伸。

## 原话（verbatim）

> 我想做每个需求动态添加不同cli（claude\codex\gemini\opencode等）的agent或者设置不同的角色，它是如何支持的？我们要如何对接？灵活性如何。

> 我现在的想法是，我系统本身slot里可以固定一个决策agent，然后决策agent接到需求可以先思考需求然后决策一下需要哪些agent来参与这次需求，然后它动态add新agent到自己的slot，然后再继续推进，那么我的想法是plugin应该可以先预设可选择的cli列表、role列表，然后它决策要哪些cli参与每个cli是哪个决策，然后形成当前需求级的agent拓扑，再根据需求的具体推进继续决策是不是需要加入新的cli、角色。那么对plugin的挑战是 列表式罗列、动态化的选择、动态化的编排。

> 我觉得可以考虑rolepack，但是这个机制的意思，其实就是oriel可以直接先设定，再使用吧？而且plugin可以直接当作清单？

> 如果使用oriel或者claude-plugin的用户想自己增加一些自定义role、skills的话要如何设计这个动态的能力？

> 为了让我们更灵活，所以我们应该有两层目录？一层role、一层skills，这样可以让选择和组装更灵活，role先标配skills，然后后续可以用户自己动态编排和加载？

> 我们回来继续讨论刚刚的role、skills的话题，先立项

（AskUserQuestion 拍板回答：成员落点 =「挤进自己 slot 窗口（推荐）」；回收时机 =「需求结束自动回收（推荐）」。角色载体经两轮重新解释后用户确认采用 rolepack。共识总结页用户核对后仅追问 d21ff1 依赖状态，无内容纠偏。）

## 二、背景与目标

2026-06-07 需求探索全链路完成：CCB 源码排查（v7.3.2，/sc:design 入口）确证 reload patch 支持集——add_window 新窗任意组合无约束、既有窗口仅尾部 append、保序删、replace_agent/move_agent 被 block（lib/ccbd/reload_patch.py:11-19）；rolepack 机制完整（role.toml + memory + skills/<provider>/ + adapters，注入链路 lib/rolepacks/runtime_lookup.py:102-172）但本机生态为空；agent 私有记忆通道四 provider 全通（lib/project_memory/sources.py:67-74）；provider 能力差异显著（opencode 无 resume/hooks 最弱）。Codex 深度协商（job_21ad342b000c / rep_dd658efbf001）结论可行，推荐「决策 agent 出结构化 intent + oriel API 收口执行」最小闭环。d21ff1（oriel 动态增删 slot，栈式）已 delivered，其交付的 ProjectSlotTopology / ManagedConfigMutationLock / reload CLI wrapper / slotAgentOverridesJson 即本需求全部地基。

**目标**：slot 内成员可变、可异构、可带角色——每个需求按需组队（异构 CLI + 专属角色 + 定制技能组合），用户与生态可自由扩展角色/技能（丢文件夹即生效，零重启）。

## 三、讨论与决策

经 1 轮 Codex 深度协商（job_21ad342b000c / rep_dd658efbf001）+ 用户多轮拍板：

- **成员落点（用户拍板）**：动态成员追加到决策 agent 自己所在 slot 窗口尾部——CCB append-only 语义天然匹配且不动既有 pane（自指安全）；独立扩展窗口形态被放弃。现实上限：pane 宽度约束，单 slot 动态成员约 +2~3。
- **回收时机（用户拍板）**：需求归档/取消时自动回收该需求全部动态成员；中途显式提前回收不做（范围外）。
- **角色载体（用户拍板）**：rolepack 机制承载 + 轻内容起步——第一批角色只写 role.toml 名片 + memory.md 行为守则，角色专属 skills 用熟后渐进发育。备选「派工消息轻角色」「agent 私有记忆注入」作为机制内补充手段，不作主体。「招募-回收」模型天然化解 rolepack 最大死板点（运行中不可换角色——本模型从不换，成员生来带角色、用完即回收）。
- **两层目录（用户提出并拍板）**：roles/（角色库）与 skills/（公用技能库）分离；role.toml 声明标配 skills 引用；决策单可临时加减（skills_add/skills_remove）。技能只放一份、多角色引用，消除内嵌式复制漂移。装配薄层由我们实现（CCB 原生 rolepack 为技能内嵌格式，不认跨包引用）；装配产物为临时件，真相源永远是两层目录（同 d21ff1「DB 真相、config 投影」哲学）。
- **三格分层（Claude 提出，用户认可）**：官方（随 su-ccb-claude-plugin 分发）/ 个人（~/.ccb/roles，CCB 原生扫描位）/ 项目（项目内目录，随 git 团队共享），同名近者赢；项目格注册自动化塞入 su-init/oriel 启动流程，用户无感。
- **provider 门控（设计默认）**：catalog 全列 claude/codex/gemini/opencode 并标成熟度；首批解锁 claude/codex（派工回执链路已日常验证），gemini 跑通回执 smoke 后解锁，opencode 暂缓。
- **架构分工（Codex 建议采纳）**：plugin 只做决策并提交 topology intent；oriel API 负责 catalog 校验、持锁、装配、写 config、reload、active wait 与回收。决策 agent 不直接改 ccb.config（managed config 白名单回写抹除 + ccbd reconcile 回收，d21ff1 实测）。

**Claude 对 Codex 协商的 4 锚点反思**：

- **我同意**：intent + oriel API 收口、弱 provider capability gate、复用 d21ff1 锁与 reload 封装、per-requirement topology state 必要性——全部进设计输入。
- **我不同意**：Codex 倾向 MVP 角色用纯 ask 消息注入（轻角色 spec）；用户后续明确拍板 rolepack 机制承载。最终采用合成路线：rolepack 机制 + 轻内容起步——机制一步到位、内容渐进发育，两头收益兼得。
- **我的盲点**：自指风险（决策 agent 改自己所在 slot）首轮未给出源码级答案，后经逐行核验 append 前缀不变语义补上；roles/skills 两层分离是用户提出后我才意识到内嵌式角色包的复制漂移问题——用户的结构直觉先于我的分析。
- **接下来**：需求文档落盘立项；依赖已满足（d21ff1 delivered，2026-06-07 核验）；等用户排期进入技术设计（装配机制、决策单 schema、catalog 字段为设计期三大主题）。

## 四、范围与边界

**范围内**：
1. 两层目录契约：roles/ + skills/ 结构、role.toml schema（名片 + compatibility.providers + 标配 skills 引用）、三格发现与同名优先级规则。
2. plugin 侧：三格菜单扫描合并、决策单 schema（cli × role × skills_add/remove）与校验、决策 agent 招募流程接入节点工作流。
3. oriel 侧：需求级拓扑 API（校验 → mutation lock → 装配 → 写 config → `ccb reload` → active wait）、需求生命周期挂钩自动回收（归档/取消触发）、SlotsPage 最小展示动态成员。
4. 装配层：角色守则 + 技能组合 → CCB 可消费形态（rolepack 安装链路 or 私有记忆 + skills 投影，机制选型留技术设计）。
5. provider 门控 catalog（4 家 + 成熟度标记 + 解锁开关）。
6. 官方第一批角色包（轻内容：名片 + 守则；数量与角色清单留技术设计）。
7. gemini 派工回执链路 smoke 验证（解锁第三家的前置）。

**范围外**：
1. 中途显式提前回收动态成员。
2. 动态成员独立窗口形态。
3. 角色专属 skills 重内容批量建设（轻内容起步，按需发育）。
4. 项目级技能偏好 preset（「本项目所有角色都带 X」）。
5. oriel 角色管理 UI 页（文件夹即菜单已覆盖管理诉求）。
6. opencode 默认解锁（回执验证后另行解锁）。
7. CCB 新 provider 接入（droid/agy/自定义 CLI，属 CCB 源码层）。
8. main 组拓扑变更。

## 五、验收口径

1. 需求绑定 slot 后，决策 agent 能读到三格合并菜单（角色 × 兼容 cli × 标配技能）；项目格丢入自定义角色文件夹，下一次招募即可见，零重启。
2. 决策单提交 → 对应成员在本 slot 窗口尾部创建，出生即带角色守则 + 技能组合，可被 ask 派工；既有 pane（决策 agent、常驻 codex、其他 slot）全程无中断。
3. 推进中二次追加成员走同一链路成功。
4. 需求归档/取消 → 该需求全部动态成员自动回收，slot 缩回常驻形态；磁盘 provider-state 不删除（沿用 d21ff1 不删文件拍板；编号/名字复用时不恢复旧会话）。
5. 修改角色 memory.md → 下次招募生效；已在岗成员不受影响。
6. 非法决策单（未知角色 / 角色-cli 不兼容 / 未解锁 provider / 超 pane 防御上限）被 oriel 校验拒绝并返回具体原因。
7. 并发安全：recruit 与 resize / syncSlotTips / startup recovery 共用 per-project mutation lock，config 不互相覆盖。
8. typecheck + 既有测试 + 新增测试绿；真实 smoke：claude/codex 各招募一次 + 回收 + gemini 回执 smoke。

## 六、风险与依赖

| 风险/依赖 | 应对 |
|---|---|
| 依赖 d21ff1 交付物 | 已 delivered（2026-06-07 核验 canonical frontmatter），地基可用 |
| gemini/opencode 派工回执未验证 | capability gate：首批 claude/codex，gemini smoke 过后解锁，opencode 暂不解锁 |
| config churn / 并发竞态 | 全部 config 写入走 d21ff1 的 per-project mutation lock；recruit 串行化 |
| 磁盘 state 累积（.ccb/agents/ 不回收） | MVP 不删磁盘 + 记录动态成员生命周期；清理策略留后续需求 |
| rolepack role-lock.json 与 oriel 直写 config 的配合细节 | 技术设计期核验：lock 缺失仅告警 or 需同步写入 |
| pane 拥挤 | 决策单校验留防御上限（数值留技术设计），UI 提示资源开销 |
| CCB reload 行为依赖 | 依赖 CCB ≥ v7.3.2（reload patch 语义实测版本）；输出解析复用 d21ff1 wrapper 错误映射 |

## Claude 解读

用户要把 slot 从固定 claude+codex 双人组升级为「常驻决策 agent + 需求级动态成员」编队模型：决策 agent（slotN_claude）接需求后输出队伍决策单（cli × 角色 × 技能加减），oriel 需求级拓扑 API 校验、装配并经 config + `ccb reload` 落地到本 slot 窗口尾部，需求结束自动回收。可选项由两层目录承载——roles/ 角色库（rolepack 机制，role.toml 自描述兼容 cli 与标配 skills 引用）+ skills/ 公用技能库，按官方/个人/项目三格分层发现，文件夹即菜单，自定义零重启生效。架构分工延续既有铁律：plugin 决策、oriel 执行，决策 agent 不直接碰 ccb.config（managed config 回写抹除，d21ff1 实测）。全部地基为 d21ff1 交付物（ProjectSlotTopology / mutation lock / reload 封装 / overrides 存储），本需求是其范围外清单第 2 条（per-slot provider 组合 / slot 模板）的正式立项延伸。CCB 机制可行性已源码级核验：窗口尾部 append 不动既有 pane（决策 agent 改自己 slot 自指安全，lib/ccbd/reload_patch_additive_agents.py:31-35）、运行中改已有 agent 角色/provider 被 block（replace_agent 不在 patch 支持集——招募-回收模型天然规避）、角色守则注入链路 claude/codex/gemini/opencode 四 provider 全通（lib/project_memory/sources.py:67-74）。

## 歧义点

需求分析期识别 6 项歧义，全部已澄清，无遗留 TBD：
1. 成员落点（自己窗口 vs 独立扩展窗口）—— 用户拍板：挤进自己 slot 窗口尾部；pane 变窄为已知代价，现实上限约 +2~3 个动态成员。
2. 回收时机（自动兜底 vs 决策 agent 显式提前回收）—— 用户拍板：需求结束（归档/取消）自动回收；中途显式回收列范围外。
3. 角色载体（派工消息轻角色 / agent 私有记忆注入 / rolepack）—— 用户经两轮重新解释后拍板：rolepack 机制承载 + 轻内容起步（第一批只写名片+守则）；另两种作机制内补充手段。
4. 角色与技能的目录关系 —— 用户提出并拍板：roles/ 与 skills/ 两层分离，role.toml 标配引用 + 决策单临时加减（skills_add/remove）；装配薄层由我们实现（CCB 原生 rolepack 为技能内嵌格式，不支持跨包引用），装配产物是临时件、真相源永远是两层目录。
5. 自定义扩展形态 —— 三格分层（官方随 plugin 分发 / 个人 ~/.ccb/roles / 项目内目录）+ 同名近者赢，用户认可方向；项目格注册自动化进 su-init/oriel 启动流程。
6. provider 范围（4 家全开 vs 渐进）—— 设计默认：catalog 全列 + 成熟度门控，首批解锁 claude/codex（回执链路日常验证），gemini 跑通回执 smoke 后解锁，opencode 暂缓。
必问项扫描：成本命中（动态成员 = 常驻进程开销，已在落点拍板时向用户提示并接受）；不可逆命中（回收不删磁盘 provider-state，沿用 d21ff1「不删文件、复用需全新会话」同款拍板模式）；隐私/合规不命中（角色库为本地文件，无数据外发）；schema 变更属工程动作（oriel DB 字段留技术设计，有 migration 护栏）。

## 保真差异

用户原话直接表达：每需求动态添加不同 cli 的 agent 或设不同角色；slot 固定决策 agent、接需求先思考再决策参与者、动态 add 到自己 slot、按推进继续决策追加；plugin 预设 cli 列表/role 列表；三挑战命名（列表式罗列、动态化的选择、动态化的编排）；rolepack「先设定再使用、plugin 直接当清单」；roles/skills 两层目录、role 先标配 skills、用户后续动态编排和加载；自定义 role/skills 的动态能力设计之问。以下为 Claude/Codex 推导或补充拍板，非原话直接内容：(1) 落点/回收/角色载体的具体选项是 Claude 提出、用户在对比中拍板；(2)「轻内容起步」「三格分层」「文件夹即菜单」「装配薄层+临时产物」为 Claude 设计推导，用户认可方向；(3) intent + oriel API 收口、capability gate、复用 d21ff1 地基清单来自 Codex 协商（job_21ad342b000c / rep_dd658efbf001）；(4) provider 门控顺序（claude/codex 先行）为设计默认，未单独向用户拍板；(5) 范围内外清单与验收口径为 Claude 基于共识总结页（用户核对无内容纠偏）的推导整理。

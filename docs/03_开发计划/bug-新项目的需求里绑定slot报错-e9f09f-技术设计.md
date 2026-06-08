---
id: td-e9f09f-cross-project-slot-binding-fix
title: BUG：新项目的需求里绑定slot报错 技术设计
doc_type: technical_design
requirement_id: cmq3lp9jy559ead7b3fe9f09f
subject: su-oriel
expression_spec: v1
updated: 2026-06-07
---

# BUG：新项目的需求里绑定slot报错 技术设计

> 一句话:slot 终端 resolver 改「运行时证据交集」派生 session 名(删 `ccb-su-ccb-` 硬编码);slot 上下文重置改按 `input.projectId` 每次路由到目标项目自己的 ccbd,发送前 root 校验不一致拒发。 ｜ 最后更新: 2026-06-07

---

## 一、设计概述

**目标对齐**:你在新项目 realtime_translator 绑 slot 后看到「slot terminal unavailable」,并怀疑这次绑定影响了 CCB 项目的 slot1——两件事都已确认是 Console(su-oriel) server 的 bug,且互相独立。Bug A:终端定位代码写死只认 `ccb-su-ccb-` 开头的 tmux 会话名,任何目录名不是 SU-CCB 的项目都找不到终端。Bug B:绑定后自动发 `/new` 清上下文的组件永远连到 Console 自己所在的 CCB 项目,所以你在新项目绑 slot-1,被清空的却是 CCB 项目的 slot-1。本设计修这两处:终端定位不再认会话名,改用「ccbd 启动时登记的 pane 证据」反推会话;`/new` 重置组件改为每次按「这次操作属于哪个项目」查库拿项目目录、连那个项目自己的 ccbd,并在发送前校验对方项目根一致,不一致直接拒发。修完后:新项目绑定即见终端,跨项目零误伤。

| 项 | 说明 |
|----|------|
| 名称 | 跨项目 slot 绑定隔离修复(Bug A 终端 resolver + Bug B 上下文重置路由) |
| 核心职责 | slot/main 终端解析对任意项目目录名成立;bind/release 触发的 `/new` 重置严格落在目标项目 |
| 设计原则 | 名称知识归 ccbd,Console 只信运行时证据;副作用发送 fail-closed(= 校验不过就拒发,宁可不发不可错发);最小改动面 |
| 需求来源 | `docs/02_需求设计/bug-新项目的需求里绑定slot报错-e9f09f-需求.md` |
| 覆盖范围 | option 1(用户默认已定):`slot-terminal.service.ts` session 解析、`slot-context-reset.service.ts` ccbd 路由、`slot-resize.service.ts` 构造适配、对应测试 |
| 不覆盖 | anchor-terminal `ccb-su-ccb-task-` 硬编码与 bridge 错误(移交 23ee06,统一设计见 `bug-项目切换之后似乎有什么操作会数据错乱问题-23ee06-技术设计.md`);ccbd(codex-dual)侧任何改动;`CCB_CCBD_SOCKET_PATH` 全局 override 语义本身 |

---

## 二、方案与架构

```
现状(双 Bug):
  bind slot-1 @ realtime_translator
    ├─ Bug A: GET …/slot-terminal → resolver 在 realtime 自有 tmux.sock 上
    │         list-sessions → 只认 "ccb-su-ccb-*" 前缀 → 匹配不到
    │         → 404 → 前端 "slot terminal unavailable" ✗
    └─ Bug B: onSlotBound → 跨项目单例 resetter → projectView()
              → server 自身项目根(SU-CCB)的 ccbd ✗
              → 按窗口名 slot-1 匹配 → send-keys "/new"
              → CCB 项目 slot1_claude/slot1_codex 会话被清 ✗

修复后:
  bind slot-1 @ realtime_translator
    ├─ A4: 单次 list-panes -a(项目自有 socket)∩ .ccb/agents/*/runtime.json
    │      → 唯一 session 派生(ccb-realtime_translator-a8ae9ed1)
    │      → 双 pane descriptor ✓(main 组终端同路径修复)
    └─ B1: input.projectId → DB project.localPath
           → CcbdClientService({projectRoot: localPath}) → projectView()
           → view.project.root ≟ localPath(canonical 比较)
           → 一致才对该项目 panes send-keys "/new" ✓
```

| 关键原则 | 说明 |
|----------|------|
| 名称知识归 ccbd | Console 不复刻、不前缀匹配 session 命名;session 名由 pane 证据交集派生为「事实」而非「先验配置」 |
| 副作用 fail-closed | `/new` 是不可撤回的 send-keys;root 校验不一致 → failed 拒发,绝不"尽力发" |
| 路由键归位 | `input.projectId` 从只回显的装饰字段变成 ccbd 路由唯一来源 |
| 依赖边界不扩大 | 终端解析保持 tmux+fs:ws 键入路径每条消息都走解析(`slot-terminal.ws.ts:831-888`),不能挂 ccbd 往返 |

**与现有系统的关系 / 边界**:

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `slot-terminal/slot-terminal.service.ts` | 改 `TmuxSlotTerminalRuntimeResolver` 的 session 解析(A4) | Store/guard/ws/routes 接口与 descriptor 字段全不动 |
| `slot-binding/slot-context-reset.service.ts` | 构造签名改 store+clientFactory;`resetSlotContext` 按 projectId 路由+守卫(B1) | 单例工厂保留;两条消费回调(`slot.routes.ts:92-118`、`slot-binding.service.ts:554-573`)零改动 |
| `slot-resize/slot-resize.service.ts` | 仅适配 resetter 构造签名(:122 默认工厂),编译必要项 | resize 业务逻辑不动 |
| `ccbd-client` | 不动 | 类型已含 `namespace`/`project` 字段(`ccbd-client.types.ts:32-44`) |
| `anchor-terminal` | 不动 | 硬编码清理移交 23ee06 |

---

## 三、关键决策与取舍

- **Bug A 选 A4「运行时证据交集定位」;否决 A1「读 ccbd project_view.namespace.session_name」作主修法**:选 A4,因为 (1) ws 键入路径每条 input 消息都触发 session 解析,A1 会把每次键入挂上一次 ccbd unix-socket 往返(3s timeout 的单 python daemon 同时还在做 job 编排);(2) 可用性回归——现 resolver 只依赖 tmux+fs,ccbd 挂掉但 tmux 活着时终端仍可看,A1 丢掉该能力,A1+缓存又引入 session 重生成失效逻辑;(3) A4 比现状还省一次 tmux 调用。A1 保留为未来 fallback/诊断手段,不进本修复主路径。**注**:分析阶段倾向为 A1,设计期以上述两条新证据偏离,Codex 协商同意(见下)。
- **否决 A2「TS 复刻 ccbd 命名规则」**:双真相源漂移风险(codex-dual `ids.py` 变更时 TS 复刻悄然失效);A4 下连降级路径都不需要它。
- **否决 A3「该 socket 上任意 ccb-* session」**:残留/手工 session 风险,分析阶段已否决,维持。A4 对该风险天然免疫:残留 session 不含 runtime.json 登记的 pane_id(pane_id 在 tmux server 内唯一)。
- **Bug B 选 B1「resetter 内部按 projectId 路由」;否决 B2「逐调用点修」**:`SlotBindingService` 构造器对未显式传回调的消费方自动接默认 bind 回调(`slot-binding.service.ts:65-67`),B2 修不绝——未来任何新消费方都会复现 Bug B;B1 按构造防错,且同文件已有正确范式(`slot.routes.ts:809` 的 per-project `cancelCurrentJob`)。不做 client 缓存:bind/release 低频,每次构造换简单性。
- **root mismatch 守卫 fail-closed 而非 warn**:`CcbdClientService({projectRoot})` 仍会优先吃全局 `CCB_CCBD_SOCKET_PATH`(`ccbd-client.service.ts:86-100`),该 env 一旦设置,per-project 构造静默同 socket——守卫是防误路由的关键保护而非可选增强(Codex 强调)。比较用 canonical 化:两边 realpath 成功比 realpath,失败降级 resolve+斜杠归一化;ccbd 确返 `project.root`(codex-dual `project_view/service.py:316-319`)。
- **单任务落地,不拆 A/B 两子任务**:两处改动文件不同但验收共享「新项目终端可用 + 不跨项目 /new」回归面,拆分徒增中间态风险(Codex 同议)。

**Codex 协商**(1 轮 consult,job_339895b8d1bd,2026-06-07):同意 A4 作主修法强于 A1(补证:ws 订阅结构只存 slotId/role/target/socketPath 不存 sessionName,前端无 sessionName 实质消费——descriptor.sessionName 是返回/调试字段);给出实现顺序约束——必须**先收敛唯一 session 再产出 candidates**(session 集合 size≠1 直接 NotFound),不得按角色取第一个后才判 session;确认 A4 未扩大信任面(现行代码同源信任 `pane_id/active_pane_id/runtime_ref`,`slot-terminal.service.ts:414-417`);升级 root 守卫优先级(见上);新发现 `slot-resize.service.ts:122` 直接构造 resetter 的编译断点(已实测核验);风险补充:`list-panes -a` 重复 paneId 的 Map 覆盖可能掩盖异常,需显式检测。`analysis_depth_hint: none`(证据足够,剩余为实施细节)。

**Claude 4 锚点反思**:

- **我同意的**:(1)「先收敛唯一 session」的实现顺序约束——按角色先取 pane 再判 session 会让跨 session 异常被静默掩盖,Codex 点出的顺序才是 fail-loud;(2) root 守卫从"可选增强"升级"关键保护"——我提出守卫时未意识到 `CCB_CCBD_SOCKET_PATH` 会让它成为唯一防线;(3) 单任务落地。
- **我不同意的**:本轮无实质反对项(不为分歧而造分歧)。一处保留:Codex 称 descriptor.sessionName"基本是调试字段",我仍在本文档把它显式定义为「派生事实」语义(四、处理规则表),防未来消费者当先验配置使用——处理为文档显式声明而非代码改动。
- **我的盲点**:(1) `slot-resize.service.ts:122` 直接构造 resetter——我的 B1 草案只盯两条 bind 回调消费路径,漏了构造签名变更的编译波及面;(2) 重复 paneId/解析异常的防御测试缺口。
- **接下来做什么**:本文档落盘;payload step=design,完成后自然停下等用户触发 task_breakdown(与分析节点同模式,尊重 Console 分步触发);breakdown 时按"单任务"拆分结论产 draft。

**sc 指令使用说明**:本环境已安装 SuperClaude(`/sc:*` 可用;修正分析阶段"未安装"的记录)。本节点未调用而采用替代覆盖,理由:本设计是 2 个生产文件的收敛 bugfix,sc 各项的目标已被更强的一手证据覆盖——`/sc:design` 的架构全貌 → A1-A4/B1-B2 候选对比与否决理由(本章);`/sc:research` 的选型调研 → ccbd 命名真相源(`ids.py`/`paths_ccbd.py`)与 tmux pane_id 唯一性语义的一手核验;`/sc:analyze` 的现有代码影响面 → resolver/resetter 全消费方 grep+全文精读(routes/ws/guard/binding/resize);`/sc:business-panel` 的业务复核 → 必问项扫描(无依赖/schema/成本/合规面,见下)。泛化 sc pass 在此只会复推已有证据。

---

## 四、核心流程 / 逻辑

**A4:session 派生解析**(替换 `resolveSessionName` + `listPanes` 两段)

```
resolveSlotPaneCandidates({projectRoot, slotId}):
  socket = <projectRoot>/.ccb/ccbd/tmux.sock
  并行: allPanes = tmux -S socket list-panes -a          ← 单次调用,替代原 list-sessions+list-panes
        -F "#{session_name}\t#{window_name}\t#{pane_id}\t#{pane_index}"
        records  = read <projectRoot>/.ccb/agents/*/runtime.json
  防御: allPanes 中 pane_id 重复 → NotFound(fail-loud,不让 Map 覆盖掩盖)
  匹配: records(window=slotId, 合法 role, pane_id) ∩ allPanes(window=slotId, 同 pane_id)
  收敛: 匹配 pane 的 session_name 集合
        size == 0 → NotFound("panes not found")        ← 语义同现状
        size >= 2 → NotFound("not uniquely resolvable") ← 先收敛,再产出 candidates
  返回: { sessionName: 唯一 session, candidatesByRole }   ← sessionName=派生事实,非先验配置
```

**B1:按 projectId 路由的上下文重置**(`resetSlotContext` 前段重构,window/agent/pane/send-keys 段不变)

```
resetSlotContext(input):
  localPath = store.findProjectLocalPath(input.projectId)
    └─ 查不到 → failed "project_local_path_missing",拒发
  client = clientFactory(localPath)        默认 (root) => new CcbdClientService({projectRoot: root})
  view = client.projectView()
    └─ 异常 → failed "project_view_failed: …"(现状语义保持,best-effort)
  守卫: canonical(view.project.root) ≟ canonical(localPath)
    └─ 不一致 → failed "project_root_mismatch",拒发    ← fail-closed
  以下不变: windows 找 slotId → agents → pane → send-keys /new
```

**模拟示例**(端到端走查):用户在 realtime_translator(projectId `cmq3i7ffr03xdqr8g4gb0khi2`,localPath `/home/sue/dev/realtime_translator/`)的需求详情页点「绑定 slot」→ `POST …/bind-slot` → 绑定落库 slot-1 → `onSlotBound` 触发 resetter:查库得 localPath → 构造该根的 client → projectView 返回 realtime 的 ccbd 视图(root 一致,守卫过)→ 对 realtime 的 slot-1 双 pane 发 `/new`(CCB 项目零接触)→ 前端拉 `GET …/slot-terminal` → resolver 在 realtime 自有 socket `list-panes -a` 得 `ccb-realtime_translator-a8ae9ed1` 下 slot-1 两个 pane,与 runtime.json 的 pane_id 交集收敛唯一 session → 返回双 pane descriptor → 面板渲染 claude/codex 两格。用户在终端键入 → 每条 ws input 走 `assertTargetBelongsTo` → 同 A4 解析(纯 tmux+fs,无 ccbd 往返)→ 校验通过写入 pane。

| 处理规则 | 说明 |
|----------|------|
| 唯一 session 收敛 | 先收敛 session 集合再产出 candidates;≥2 个 session 含匹配 pane → fail-loud NotFound |
| 重复 paneId 防御 | `list-panes -a` 输出 pane_id 重复(理论不可能)→ NotFound,不静默取第一 |
| sessionName 语义 | descriptor.sessionName = 由 pane 证据派生的事实,仅作返回/展示/诊断;下游不得当先验配置 |
| root canonical 比较 | 双侧 realpath(失败降级 resolve)+ 尾斜杠归一;mismatch → 拒发 failed |
| localPath 缺失 | failed "project_local_path_missing",不构造 client |
| 触发覆盖 | bind(`slot.routes.ts:100-118`、`slot-binding.service.ts:554-573`)与 release(`slot.routes.ts:270-279`)双触发同路修复 |
| 幂等/频率 | bind/release 低频用户动作;client 每次构造不缓存;失败均 best-effort 记 warn 不阻断绑定状态机(现状语义) |

---

## 五、测试策略

- [ ] 单元(`slot-context-reset.service.spec.ts` 更新):fake store+clientFactory 捕获 projectRoot——factory 收到目标项目 localPath 而非 server 自身根;localPath 缺失 → failed 且零 client 构造;root mismatch → failed 且零 tmux 调用;既有 sent/skipped/failed 路径回归。
- [ ] 单元(`slot-terminal.service.spec.ts` 更新):fake execFileProcess 喂 `list-panes -a` 多 session 输出——非 SU-CCB 名 session(`ccb-realtime_translator-a8ae9ed1`)可解析;含无关残留 session 时忽略;匹配 pane 跨两 session → NotFound;重复 paneId → NotFound;零匹配 → NotFound;**main 组**在外来名 session 下可解析(Bug A 第二影响面,勿只测 slot 窗口)。
- [ ] 单元(`slot-resize` 既有 spec):构造签名适配后编译+回归通过。
- [ ] 集成(`slot-terminal.true-tmux.spec.ts`):真 tmux 用例 session 名参数化为非 SU-CCB 名,证明对真实 tmux 成立。
- [ ] 端到端(手工,对齐需求三条验收):realtime_translator 绑定后面板双 pane 正常;在 realtime 绑/解绑 slot-1 时观测 CCB slot1 双 pane 无 `/new` 注入;CCB 项目自身绑定/解绑/终端回归 + 两类项目 main 组终端可解析。

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-oriel/server/src/modules/slot-terminal/slot-terminal.service.ts`:删 `SESSION_PREFIX`(:13);`resolveSessionName`+`listPanes` 合并为单次 `list-panes -a` + 交集收敛派生 session(A4);`collectRuntimePaneCandidatesByRole` 适配先收敛后产出顺序。
- `[MODIFY] su-oriel/server/src/modules/slot-binding/slot-context-reset.service.ts`:构造签名 → `{ store?, clientFactory?, runTmux? }`;`resetSlotContext` 增 localPath 查询、per-project client、root mismatch 拒发;新增 Prisma store 默认实现(查 `project.localPath`)。
- `[MODIFY] su-oriel/server/src/modules/slot-resize/slot-resize.service.ts`:`:122` 默认 `contextResetterFactory` 适配新构造(per-call 路由后可直接用默认单例 resetter,DI seam 保留)。
- `[MODIFY]` 对应 spec:`slot-terminal.service.spec.ts`、`slot-context-reset.service.spec.ts`、`slot-terminal.true-tmux.spec.ts`、slot-resize 相关 spec。
- 六、数据 / 七、接口:不涉及——无 DB schema 变更;HTTP/WS 端点与 descriptor 字段不变(404 语义收窄为真实未找到;sessionName 语义声明见四)。

---

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| 无新增 | — | 全部复用现有 tmux CLI、fs、Prisma、CcbdClientService |

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| `CCB_CCBD_SOCKET_PATH` | 未设置 | 既有全局 env override,设置后所有 per-project client 同 socket——本设计不改其语义,由 root mismatch 守卫把"静默跨射"变"显式 failed"(尖角记录) |

---

## 十、迁移影响与风险

- **受影响**:slot 终端解析(需求详情页 + main 组入口 + ws 键入校验路径)、bind/release 后 `/new` 重置、slot-resize 构造。
- **打法**:单任务单 commit 落地;先单元后真 tmux 集成再手工 E2E。
- **回滚 / 恢复**:无数据迁移,git revert 单 commit 即回滚。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 过期 runtime.json + tmux 重启 pane_id 复用 → 误匹配 | 极低 | 错 pane 展示 | 与现状同信任面;window 名+唯一收敛双重约束;异常即 NotFound |
| root canonical 化不严谨误杀 symlink 项目根 | 低 | 终端正常但 `/new` 拒发(failed 日志) | realpath 优先、resolve 降级;failed reason 显式可查;E2E 含 WSL 实测 |
| `/new` 修复后真正打到新项目 panes(行为变化) | 确定发生 | 新项目 agent 收到 `/new` | 即设计意图;E2E 验证新项目 agent 对 `/new` 处理符合预期 |
| 未来 ccbd 一 socket 多 session | 低 | 收敛失败 NotFound | fail-loud 可见,届时按 project_view 增强(A1 备选已记录) |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-07 | v1.0 | 初版(A4+B1,Codex 1 轮协商收敛) |

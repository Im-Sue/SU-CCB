---
id: td-23ee06-multiproject-isolation-full
title: 多项目隔离完整档(URL scope + server 防御纵深 + 审计 + e2e) 技术设计
doc_type: technical_design
requirement_id: cmq3m1i8r5ac97ea38323ee06
subject: su-oriel
expression_spec: v1
updated: 2026-06-07
---

# 多项目隔离完整档(URL scope + server 防御纵深 + 审计 + e2e) 技术设计

> 一句话:前端把「当前项目」从内存隐式状态迁成 URL 显式路径段(唯一真相源),server 把所有 runtime 通道(ccbd client/派工队列/事件查询/anchor 终端)收紧到显式项目 scope,再用全站审计矩阵 + Playwright 双 tab e2e 证明隔离成立。 ｜ 最后更新: 2026-06-07
>
> **无独立 status** —— 跟随 `requirement_id` 指向的需求。

---

## 一、设计概述

**目标对齐**:你双 tab 同时开 CCB 和 realtime_translator 两个项目时撞上的串扰,直接根因(绑定后 `/new` 打错项目 = Bug B、新项目终端 404 = Bug A)已在姊妹需求 e9f09f 的技术设计里修;但你拍板了两件事——「这个问题很严重,要完整全站审计」和「多 tab 多项目并发必须支持」。本设计承接这两个拍板:第一,现在网址里根本没有「项目」这个概念,哪个 tab 属于哪个项目只存在页面内存里,刷新、轮询、切换都可能让它悄悄漂移——改造后每个网址都带项目前缀(`/projects/<项目id>/…`),tab 的项目身份钉死在地址栏里,天然多 tab 安全;第二,server 侧凡是能碰到运行时(tmux/ccbd/派工队列)的通道,逐一收紧成「必须显式声明属于哪个项目」,默认回落到 server 自己项目的写法从类型层面禁止;第三,「CCB bridge 错误」单独排查给结论;最后用全站审计矩阵和双 tab 自动化测试证明「改完了、改对了、以后不回退」。

| 项 | 说明 |
|----|------|
| 名称 | 多项目隔离完整档(D1 URL scope/D2 server 防御纵深/D3 Bug C 排查/D4 anchor-terminal 去硬编码/D5 审计矩阵/D6 多 tab e2e) |
| 核心职责 | 项目身份显式化(前端 URL/后端构造参数);跨项目串扰风险面系统性消除与证明 |
| 设计原则 | URL 是项目身份唯一真相源;runtime 通道无显式 scope 不放行(类型层面);有状态变更(schema)与可回滚代码变更分批;审计产出矩阵证据而非口头结论 |
| 需求来源 | `docs/02_需求设计/bug-项目切换之后似乎有什么操作会数据错乱问题-23ee06-需求.md` |
| 覆盖范围 | 完整档(用户 2026-06-07 拍板):D1-D6 全做 |
| 不覆盖 | Bug A/B 修复实现(归 e9f09f TD,见 `bug-新项目的需求里绑定slot报错-e9f09f-技术设计.md`);ccbd(codex-dual)侧改动;数据层错乱修复(无证据,审计中发现另立需求) |

**与 e9f09f TD 的衔接**:e9f09f 修「当前已确证的两条串扰链」(A4 运行时证据交集解析 + B1 resetter 按 projectId 路由 fail-closed);本设计修「让这类 bug 不再可能出现的结构」并承接其显式移交项(anchor-terminal 硬编码、Bug C 排查)。本设计 D4 对齐 A4 思路(运行时证据优先于前缀先验),D2 的构造收紧与 B1 互补:B1 修当前肇事者,D2 防未来新增。

---

## 二、方案与架构

```
前端(D1):                                server(D2/D4):
  ┌ URL /projects/:projectId/… ┐           ┌ CcbdClientService 构造必须显式 scope ┐
  │ ProjectScopeProvider        │           │ (projectRoot|socketPath|resolver 三选一)│
  │  ├ useParams 读+校验        │  API 调用  │ AnchorDispatchQueue + projectId 列     │
  │  ├ store 降级为只读投影     ├──────────▶│  └ tick() 查询层 WHERE projectId       │
  │  └ 业务 setter 封死         │           │ EventJournal list + project_id 过滤    │
  └ 旧链接智能跳转(redirect) ┘           │ anchor-terminal panes/ws 归属校验      │
                                            └ session 名派生(A4 思路,删硬编码) ┘
证明(D5/D6):审计矩阵(入口×projectId来源×隔离结论) + Playwright 双 tab e2e + server 集成断言
排查(D3):CCB bridge 错误双路径检查清单 → 根因链+复现步骤+处置判断
```

| 关键原则 | 说明 |
|----------|------|
| URL 即身份 | projectId 是路径段不是内存状态;刷新/新 tab/分享链接均无歧义;30s 轮询只刷数据不再改变身份 |
| 显式 scope 或不放行 | runtime 通道(ccbd/tmux/队列)的构造参数无默认回落;需要 server 自身根的场景显式传 `resolveCcbProjectRoot()`,意图可见 |
| 投影可重建 | SU-Oriel DB 是可重建投影(项目总览契约),ADQ 历史行不过分兼容:回填 best-effort,查不到归属直接清理 |
| 证据优先 | 每个风险面的「已隔离」结论必须落在审计矩阵或测试断言上,不接受「看代码应该没问题」 |

**与现有系统的关系 / 边界**:

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `web/src/App.tsx` 路由树(18 条) | 全部迁入 `/projects/:projectId/` 前缀;新增 ProjectScopeProvider layout route 与旧链接 redirect 层 | 页面组件内部逻辑不动(身份来源换接口) |
| `web/src/stores/project-store.ts` | `selectedProjectId` 降级为 URL 同步的只读投影;删 `projects[0]` fallback(:44-49);`selectProject` 业务写路径删除,改 navigate | projects/documents/tasks 等数据缓存职责不动 |
| `web` 各页面/组件(246 处消费点) | 消费接口过渡期不强改;新代码一律 `useProjectScope()`/path helper | 渐进收敛,不在本需求内 246 处全改 |
| `server ccbd-client` | 构造 options 类型收紧(三选一必填);`resolveCcbProjectRoot()` 保留为显式导出函数 | client 内部协议/方法不动 |
| `server slot-binding/job-slot-router.ts` | tick() 查询加 projectId 过滤(:174-198 事后 continue 改查询层 WHERE) | 路由/派发逻辑不动 |
| `server prisma schema` | AnchorDispatchQueue 加 `projectId` 列(migration + best-effort 回填) | 其余 model 不动(EventJournal 已有 projectId 字段) |
| `server events/event-journal` | list 端点 query schema 加可选 `project_id`(向后兼容) | POST/emit 不动 |
| `server anchor-terminal` | 删 `ccb-su-ccb-task-` 硬编码×2(D4);panes/ws 增加项目归属校验(D2d) | 终端 attach/lease/recording 机制不动 |

---

## 三、关键决策与取舍

- **D1 选「URL 真相源 + store 只读投影过渡」;否决「一步删除 selectedProjectId(246 处全改 useProjectScope)」**:后者隔离最干净但影响半径把 bugfix 变成前端大重构;否决「sessionStorage per-tab 持久化」——仍是隐式身份,新 tab 仍要 fallback,不可分享;否决「仅 project guard 弹窗」——用户拍板多 tab 必须支持,guard 治标。**过渡方案的硬约束(Codex 轮 1 调整①)**:store 的 setter 必须封死——`selectedProjectId` 唯一写入者是 URL 同步器,`selectProject` 删除业务写路径改为 navigate,`projects[0]` fallback 删除;违反即第二真相源复活。
- **D2a 构造收紧保留显式函数出口(Codex 轮 1 调整②)**:`CcbdClientServiceOptions` 改为 `projectRoot|socketPath|anchorSocketResolver` 三选一必填的联合类型,构造函数内删除 `resolveCcbProjectRoot()` 隐式 fallback;但 `resolveCcbProjectRoot()`/`resolveCcbdSocketPath()` 保留为公开函数——25 处测试调用点与 server 自身根的合法场景显式传参,不误伤。**尖角**:`CCB_CCBD_SOCKET_PATH` 全局 env 仍会覆盖 per-project socket(e9f09f TD 已记录),类型收紧管不住 env——root mismatch 守卫(B1)才是该尖角的防线,本设计不重复修。
- **D2b ADQ 加列;否决「join 反查」「不动 schema」**:join 无从 join(AnchorAllocation 也无 projectId);不动 schema 则审计矩阵该项永远标黄。**回填策略(用户 2026-06-07 拍板简化)**:DB 是可重建投影,历史行不过分兼容——加列后 best-effort 按 subjectId 反查回填,查不到归属的行直接删除(终态行)或标记后跳过(active 行,预期为零),migration 报告清理计数;不做 quarantine 长期保留,不因脏行阻断升级。
- **D2 拆批(Codex 轮 1 调整③)**:schema migration(D2b)单列批次,不与无状态代码 hardening(D2a/c/d)混在止血批——回滚性质不同。
- **D2d anchor-terminal 定级「高风险写通道」(Codex 发现,Claude 已核验)**:ws 消息协议支持 `request_write`/`input`/`resize`(anchor-terminal.routes.ts:186/201/213),`resolveAnchor` 按 anchorId 全局查 AnchorAllocation 无项目归属校验——本地守卫(assertLocalRequest)挡外部不挡误操作。修法:panes/ws 入口增加 anchorId→subjectId→项目归属解析与校验(查得到归属则校验 scope,孤儿 anchor fail-closed 拒绝),recordings/cast 同步审计。
- **D3 Bug C 排查交付「结论」而非预设「修复」**:resize 链路显式传 projectRoot 属正确模式,证据未闭环;双路径检查清单(reload_rejected:ccb.config 与请求 diff、bridge 拒绝原因码;reload_failed:ccbd 进程/socket 状态)+ 双 tab 复现;产出根因链+复现步骤,修复动作按根因属地归本需求或另立。
- **D4 对齐 A4 思路;否决「读 project_view」「TS 复刻命名规则」**:与 e9f09f TD 同理(运行时证据优先;anchor session 以 AnchorAllocation.anchorPath 等登记证据反推,实施时核定 anchor session 创建机制);现 `sessions[0]` fallback 语义在去硬编码时显式化——多候选不唯一即 fail-loud,不静默取第一。
- **D6 双层验收(对 Codex 轮 1 风险项的补充)**:Playwright 双 context 证明浏览器层隔离 + server 集成断言证明 ccbd/tmux 落点(fake per-project sockets fixture),两层互不替代,不是二选一。
- **批次划分**:批 1(代码止血,可 revert):D2a/c/d + D4;批 1b(schema,有状态):D2b migration;批 2(前端架构):D1 + 旧链接 redirect;批 3(证明与排查,可与批 1 并行):D3 + D5 + D6。e9f09f 的 A4+B1 独立先行,不依赖本批次。

**Codex 协商**(1 轮 consult,job_a6ebd14e11d7,2026-06-07):选 option A(保留总体方案+三点调整,均已吸收见上);实锤 anchor-terminal/ws 为可写通道并升级定级;风险补充——ADQ 回填脏行需显式策略(已被用户拍板简化取代)、store 投影期暴露 setter 即第二真相源(已转为硬约束)、Playwright 纯 UI mock 不足以证明落点(已转为双层验收)。open_questions 三项处置:脏行策略→用户拍板「不过分兼容」;旧深链兼容范围→用户拍板「智能跳转」(requirement/task/document 按 id 查归属 redirect,其余进项目选择页);Playwright→用户拍板引入并进验收口径。

**Claude 4 锚点反思**:

- **我同意的**:(1) setter 封死作为过渡方案的成立前提——我原案只说「URL 是唯一写入者」没有给出禁止机制,Codex 把它从约定升级为结构约束;(2) schema migration 单列批次——回滚性质不同的变更混批会让止血批被 migration 失败拖住;(3) 保留显式函数出口——「类型收紧」的目标是消灭隐式回落,不是消灭合法的显式自指。
- **我不同意的**:Codex 把「Playwright 双 context 只证浏览器隔离」表述为需要在 e2e 和 server 集成之间取舍——我处理为双层都要(D6),浏览器层与落点层证明的是两类不同回归。
- **我的盲点**:(1) anchor-terminal 我看到 GET 就默认只读,没审 ws 升级后的消息协议——教训:**ws 端点的风险面在消息协议不在 HTTP 方法**;(2) 批次划分最初把 schema 变更混进止血批,没按回滚性质分类;(3) 我发协商时 Bug A 修法还停在 project_view 优先,e9f09f 设计轮已用更强证据(ws 键入路径性能+可用性回归)演进为 A4——跨需求统一设计要以最新定稿为准,不能拿自己的旧快照当输入。
- **接下来做什么**:本文档落盘;两份 TD(本文档+e9f09f)同轮定稿互相引用;自然停下等用户触发 task_breakdown(尊重 Console 分步触发模式);breakdown 时按批次划分产 draft(预期 6-8 个 task)。

**sc 指令使用说明**:`/sc:design` 已运行(本节点入口,架构全貌驱动事实收集清单);`/sc:research` 以一手代码证据替代(路由/schema/构造点/硬编码/端点五面全量 grep+精读,Explore 收集 8 类事实);`/sc:analyze` 以影响面清单替代(246 消费点/15 构造点/29 测试引用点定量);`/sc:business-panel` 以必问项扫描替代(3 项全部升级用户拍板,见下)。

**用户拍板记录(2026-06-07)**:① ADQ 加列+回填批准,历史行不过分兼容(DB 可重建);② Playwright 引入并进验收口径;③ 旧链接智能跳转。**AI 自决项**:项目选择页/上次项目 localStorage 记忆的 UX 细节、redirect 实现方式、审计矩阵格式、测试 fixture 设计。

---

## 四、核心流程 / 逻辑

**D1:URL scope 链路**(前端身份解析)

```
浏览器进入 /projects/:projectId/requirements/:requirementId
  → ProjectScopeProvider(layout route)
      useParams 取 projectId → projects 列表校验存在性
        ├ 存在 → 同步 store.selectedProjectId(唯一写入点) → 渲染子路由
        ├ 不存在 → 「项目不存在」页(显式,不静默 fallback)
        └ projects 未加载 → 等待 loadProjects 后再判
  → 页面内 API 调用的 projectId 一律来自 scope(URL),与其他 tab 零共享
旧链接 /requirements/:id → RedirectResolver:按 id 查归属 projectId
  → 302 等效 navigate(/projects/<pid>/requirements/:id);查不到 → 项目选择页
切项目:sidebar 点击 → navigate(/projects/<newPid>/overview)(不再 setState)
```

**D2b:队列查询层隔离**

```
现状: tick() → findMany(status=pending) 全局取 → 处理时反查 subject 归属 → 异项目 continue
改后: enqueue 时写入 projectId(来源=派发上下文,非反查)
      tick(projectId 上下文) → findMany(WHERE status=pending AND projectId=…)
migration: ALTER TABLE 加列(nullable) → best-effort 回填(subjectId→requirement/task→projectId)
           → 终态行查不到归属 DELETE,active 行查不到(预期零)标记+报告 → 报告清理计数
```

**模拟示例**(端到端走查,双 tab 场景):tab1 开 `/projects/ccb…/anchors`,tab2 开 `/projects/rt…/requirements/xxx`。tab2 点「绑定 slot1」→ API path 的 projectId 来自 tab2 的 URL(rt)→ bind 落库 rt → onSlotBound 经 e9f09f B1 按 rt 的 localPath 构造 client → `/new` 只进 rt 的 slot-1 panes。同一时刻 tab1 做 resize → API path projectId=ccb → resize 走 ccb 自己的 ccbd → 两 tab 互不可见对方副作用。tab2 刷新页面 → URL 仍含 rt → 身份零漂移(对比现状:刷新后 store 重建,fallback 到 projects[0] 可能变成 ccb)。30s 轮询在两 tab 各自跑 → 只刷新数据,URL 不变 → 身份不可能被轮询改写。审计矩阵记录该链路两端的「projectId 来源=URL 路径段」,e2e 断言 rt 的 bind 期间 ccb 的 fake socket 零写入。

| 处理规则 | 说明 |
|----------|------|
| scope 校验时机 | ProjectScopeProvider 单点校验,子路由免重复校验;项目删除后轮询发现 → 显式提示而非静默切换 |
| store 写入纪律 | `selectedProjectId` 唯一写入者=URL 同步器;CI 可加 lint(禁止其他 set 调用)防回潮 |
| 队列 projectId 来源 | enqueue 上下文直写,禁止反查兜底(反查是 bug 温床也是审计矩阵黄项) |
| anchor 归属校验 | anchorId→AnchorAllocation.subjectId→requirement/task.projectId;孤儿 anchor fail-closed |
| 旧链接解析 | requirement/task/document 三类按 id 查归属;歧义/缺失 → 项目选择页,不猜 |

---

## 五、测试策略

- [ ] 单元(web):ProjectScopeProvider(存在/不存在/未加载三态);RedirectResolver 三类 id+查无;store setter 封死(业务调用 selectProject 编译失败或 lint 拦截)。
- [ ] 单元(server):ADQ enqueue 必写 projectId;tick() 查询过滤(双项目 fixture,断言零跨项目取行);EventJournal list project_id 过滤;anchor-terminal 归属校验(跨项目 anchorId 拒绝/孤儿拒绝);D4 session 派生(多 session fail-loud)。
- [ ] migration 测试:回填正确归属;终态脏行清理+计数;active 脏行标记路径。
- [ ] 集成(server):双项目 fake ccbd sockets fixture——bind/release/resize/cancel 全链路断言 send-keys/socket 写入只落目标项目(D6 落点层)。
- [ ] e2e(Playwright,新增):双 context 双项目并发——绑定互不串扰、刷新身份不漂移、轮询不改身份、旧链接智能跳转、无效 projectId 显式报错(D6 浏览器层)。
- [ ] 审计矩阵(D5):入口×projectId 来源×隔离结论,覆盖 246 消费点(按文件归并)/10 scoped 端点/4 anchor-terminal 端点/15 构造点;每行结论挂测试或代码证据链接。
- [ ] 手工:Bug C 复现脚本(D3)+ WSL 双项目实测。

---

## 六、数据设计

| 实体 / 表 | 关键字段 | 说明 |
|------|----------|------|
| AnchorDispatchQueue | + `projectId String?`(migration 后新行必填,代码层强制) | 查询层隔离的前提;历史行 best-effort 回填,脏终态行清理 |

其余:EventJournal 已有 `projectId` 字段(schema.prisma:721-765),零迁移;AnchorAllocation 不加列(经 anchorId→subject 归属解析覆盖,避免双写漂移)。

---

## 七、接口设计

| 端点 | 方法 | 变更 | 兼容性 |
|------|------|------|--------|
| `/api/event-journal/events` | GET | query 增可选 `project_id` | 向后兼容(不传=现行为) |
| `/api/anchor-terminal/panes` | GET | 增归属校验(anchorId→项目) | 合法调用不受影响;跨项目/孤儿 → 403/404 |
| `/api/anchor-terminal/ws` | WS | attach 前归属校验,同上 | 同上 |
| `/api/anchor-terminal/recordings(+/:id/cast)` | GET | 审计后按需加 scope 过滤 | 实施时定 |
| 前端路由(URL contract) | — | 全站 `/projects/:projectId/` 前缀;旧路径智能跳转 | 书签经 redirect 存活;通知深链生成端同步改 |

---

## 八、文件结构 / 变更清单

- `[MODIFY] web/src/App.tsx`:路由树迁前缀;ProjectScopeProvider;redirect 层;~30 处 navigate 改 path helper。
- `[NEW] web/src/lib/project-paths.ts`(或等效):path helper + useProjectScope()。
- `[MODIFY] web/src/stores/project-store.ts`:删 fallback(:44-49);selectProject 改语义;setter 封死。
- `[MODIFY] server …/ccbd-client/ccbd-client.service.ts`:options 三选一必填;删构造内隐式 fallback(:122);`resolveCcbProjectRoot` 转显式导出。15 构造点适配(13 生产已显式,主要是类型签名波及)。
- `[MODIFY] server …/slot-binding/job-slot-router.ts`:tick 查询过滤(:174-198);enqueue 写 projectId。
- `[MODIFY] server prisma/schema.prisma + migration`:ADQ 加列+回填+清理脚本。
- `[MODIFY] server …/events/event-journal.{routes,schemas}.ts`:project_id 过滤。
- `[MODIFY] server …/anchor-terminal/{anchor-terminal.routes,tmux.service,native-terminal.service}.ts`:归属校验;删 `ccb-su-ccb-task-`×2(A4 思路重派生);29 处测试引用联动。
- `[NEW] e2e/`(Playwright 工程)+ server 双项目 fake sockets fixture。
- `[NEW] docs 审计矩阵`(D5 交付物,落点 breakdown 时按目录契约定)。

---

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| Playwright(新增 devDependency) | e2e 工程 | 用户 2026-06-07 拍板引入;Apache-2.0;本地 dev 工具无合规/成本面 |

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| `CCB_CCBD_SOCKET_PATH` | 未设置 | 既有全局 override,语义不改;e9f09f 的 root 守卫负责把跨射变显式 failed(尖角已记录于两份 TD) |

---

## 十、迁移影响与风险

- **受影响**:全站前端导航/书签/通知深链;server ccbd 构造签名(15 点);派工队列 schema;anchor-terminal 端点行为(跨项目调用从放行变拒绝)。
- **打法**:批 1(D2a/c/d+D4,代码可 revert)→ 批 1b(D2b migration,单独上)→ 批 2(D1 一次性切换+redirect)→ 批 3(D3/D5/D6,可与批 1 并行)。e9f09f A4+B1 独立先行。
- **回滚 / 恢复**:批 1/2 git revert;批 1b 列保留向后兼容(回滚代码不回滚列,nullable 列不破坏旧代码);e2e/审计为纯增量。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| URL 改造回归面大(导航/深链/通知) | 中 | 局部导航断链 | path helper 单点收口;redirect 层兜底;e2e 覆盖主链路 |
| store 过渡期残留隐式消费(246 点未全改) | 中 | 个别页面身份短暂不同步 | scope 单点校验+唯一写入者保证最终一致;审计矩阵逐文件标注;lint 防新增 |
| ADQ 回填误归属 | 低 | 个别历史行错项目 | 仅 best-effort+报告;队列行短生命周期,可重建投影兜底 |
| anchor-terminal 收紧误伤合法调用 | 低 | anchor 终端 403 | 孤儿/跨项目才拒;集成测试覆盖合法路径 |
| Bug C 排查无法复现 | 中 | 该项只能交付排查报告 | 双路径清单+日志增强;不阻塞其他批次 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-07 | v1.0 | 初版(完整档,Codex 1 轮协商收敛,用户 3 项拍板吸收) |

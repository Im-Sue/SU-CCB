claude-pickup 路径 这是干什么的？

● "pickup"(接单)是任务流转里的一个交接动作。说人话:

  任务在引擎里怎么走

  一个任务会经过这几个节点:…→ 派工(dispatch)→ 实施(implementation)→ 审查(review)→ 归档。

  dispatch(派工)节点就是"这活准备好了,派给谁去干"。**pickup(接单)**就是那个干活的 agent
  把这单接走、开始干的那一下 —— 接了之后,任务才从"等人接"变成"有人在做",引擎把它推进到"实施"节点。

  打个比方:派工 = 把订单放到取餐台;pickup =
  厨师把订单拿走开始做。拿走这一下,系统才知道"这单开做了",状态翻成"制作中"。

  现在的问题

  CCB 这套 dispatch 节点是只为 Codex 设计的:
  - 等待态叫 awaiting_codex_pickup(等 codex 接)
  - 有个 codex_picked_up 事件,一触发就把任务推进到"实施"节点
  - 连派工动作都叫 dispatch_to_codex

  就是说:只有"Codex 这个厨师"有接单的机制。整套都假设"Claude 派活、Codex 干活"。

  但你现在要 Claude(我)亲自干 web。可引擎里没有"Claude 接单"这条路 —— 没有 awaiting_claude_pickup、没有
  claude_picked_up 事件、没有对应的推进 transition。所以一个标了"我来做"的任务,引擎没法像对 codex
  那样自动把它从 dispatch 推进到 implementation。

  它是干什么的 / 为什么提它

  "claude-pickup 路径"就是补上这套:让 Claude 接单也能被引擎识别、自动推进任务状态(Console
  看板上能看到任务从"待派工"自己挪到"实施中",node-flow 规则也照常套用)。

  我的决定(为什么不现在补)

  补它得把整个 dispatch 节点改成"认 owner"(codex 还是 claude),那是正经 kernel 重设计,不该顺手糊。所以对我的
  web 任务,我直接改 dev_task 文档里的状态字段(current_node/node_substate)来推进 ——
  文档本来就是真相,我手动翻就行,不依赖引擎那条自动接单路。

  一句话:claude-pickup 路径 = 让引擎能自动接管"Claude
  来实施"的任务;现在没有,我用"手动改文档状态"顶上,不耽误干活。要不要把它当个正式 kernel 任务以后做,你说。

✻ Cooked for 42s

❯  补它得把整个 dispatch 节点改成"认 owner"(codex 还是 claude),那是正经 kernel 重设计 什么意思？

● "认 owner"= 这个 dispatch 节点得根据干活的是 Codex 还是 Claude,走两套完全不同的流程。不是加个 if 那么简单
  —— 因为这两种情况本质就不一样。

  现在这个节点干的事(只有一套:派给 Codex)

  我刚读的 dispatch.node.yaml,整个节点写死了一条流水线:

  1. 准备(校验 spec)
  2. dispatch_to_codex —— 真的把任务"递出去"给 Codex(进队列/挂到 slot),还带一堆守卫:pre_codex_mounted(codex
  挂载了吗)、pre_dispatch_spec_hash_match、幂等检查…
  3. 标 waiting_codex —— 然后干等,等 Codex 那边发来"我接了"(codex_picked_up)或"我拒接/不可用"的外部事件
  4. 接到事件才推进到"实施"节点

  它的运行态(waiting_codex)、子状态(awaiting_codex_pickup)、能力(execution.dispatch)、出口条件(status==dispat
  ched)—— 全是为"递给另一个 agent 然后等"这件事服务的。

  为什么 Claude 这条路是另一种形状(不是改个名)

  关键区别:Codex 是另一个 agent,Claude 是我自己。

  - 派给 Codex:有真正的交接 —— 递出去、等对方接、对方可能拒接/挂不上、要守卫、要处理失败升级。是异步、跨
  agent、会失败的。
  - 我自己干:根本没有"递出去 +
  等"这回事。我就是干活的人,不会"把任务派给我自己再等我自己接"。dispatch_to_codex、waiting_codex、codex
  拒接、codex 挂载守卫 —— 这一整套对我全是无意义的。

  打比方:Codex
  那条是"把订单递给另一个厨房,贴个'已发出',然后等那边回'收到/做不了'";而我自己做,是"我就是厨师,直接开做" ——
  中间那段"递出去+等回执"的机器根本用不上。

  所以"认 owner"要动多少

  节点要支持两种不同形状的执行,就得改:
  - 动作序列(codex 那 3 步对我不适用,我得是另一条更短的)
  - 子状态 / 运行态(waiting_codex 对我不成立)
  - 守卫、能力(pre_codex_mounted、execution.dispatch 对我无关)
  - 新增 claude_picked_up 事件 + transition
  - 还有跑这个节点的引擎、transition-table 注册表、事件契约、测试

  而且这是 kernel(工作流的真相源),改它会波及所有读 kernel 的东西 —— 节点引擎、调度器、manifest lint、Console
  indexer 都得跟着对齐。牵一发动全身。

  一句话

  这等于在 kernel 里新开一种"实施者模型"(原来只认"Claude 派、Codex 做",现在要认"Claude 自己做")——
  是需要正经设计的改动,不是补一行。所以我先绕开它:我的 web 任务我直接改 dev_task
  文档里的状态字段往前推,不劳烦引擎那套接单机制。要不要以后把"owner-aware dispatch"当个正式 kernel





我们先简单聊聊，不做任何改动：我们现在一组agent里只有
  claude和codex，现在只分了决策是claude，实施是codex，如果我后期有想法接入更多的agent，例如拆分更细
  决策是claude1 ui是gemini 前端是claude
  后端是codex，甚至还有什么审查agent，那么我们是不是要对kernel做很大的改动？

● 好问题,值得想清楚。我的判断是:得分两件事看 ——
  工作流的"形状"几乎不用动,真正要动的是"谁干哪步"的绑定方式。而且好消息是,多 agent 的脚手架其实已经搭了一半。

  一、工作流形状:基本不用动

  节点图(需求分析→技术设计→拆分→派工→实施→审查→归档)是按"活的阶段"分的,跟有几个 agent 无关。
  - 加个"审查 agent"?不会多一个节点 —— review 节点本来就有,只是把它绑到另一个 agent而已。
  - gemini 做 UI、claude 做前端、codex 做后端?也不是多节点,是同一个"实施"阶段按任务类型派给不同的人。

  所以阶段图这层,几乎零改动。

  二、真正要动的:把"agent 身份"从节点里解耦出来

  这才是痛点,也正是我们刚撞上的 claude-pickup 那个坑的同一个根因:kernel
  现在把"Codex"这个具体身份焊死在节点机制里了 ——
  dispatch_to_codex、awaiting_codex_pickup、codex_picked_up、pre_codex_mounted…

  如果继续这种写法,那你每加一个 agent 就要在 kernel
  里复制一套:dispatch_to_gemini、dispatch_to_claude_frontend、gemini_picked_up、xxx_pickup… ——
  组合爆炸,撑不住。这才是"大改动"的来源。

  三、好消息:脚手架已经搭了一半

  你不是从零开始。系统里已经有多执行者的底子了,只是 kernel 节点还没去用:
  - DB 里有 ExecutorProfile(provider/model/runtime/permission/capability 绑定)和 RoleProfile ——
  这本来就是"一个角色 = 哪个 agent+模型"的抽象。
  - 有 capability 系统(节点本来就声明 capability_id、有 capability-outcome-policy、CapabilityStatus)。
  - 有 slot 绑定(slot1-3 × claude/codex)、implementation_owner 枚举(已含 claude)。

  也就是说:"谁来干"这套数据模型基本备好了,缺的是 dispatch/implementation
  节点去用它,而不是抄近路直接写"codex"。

  四、正确的一次性改法(等你真要上多 agent 时)

  做一次解耦,之后加 agent 就是改配置、不动 kernel:
  1. 节点/任务声明"需要什么角色/能力"(如 role: frontend / capability: ui),不写具体 agent。
  2. 一个绑定层把 角色/能力 → 执行者(agent+模型)—— ExecutorProfile/RoleProfile 就是干这个的。
  3. dispatch/implementation 变通用:"派给本任务角色绑定的那个执行者,等它接单",不再有 _codex 后缀。
  4. 加 gemini/claude-frontend/审查 agent = 注册一个 profile + 绑个角色 + 声明能力,kernel 一行不用改。

  一句话总结

  - 要一次性的、有边界的 kernel 重构(把 dispatch/implementation 从"认
  codex"改成"认角色/能力"),这是值得的投资。
  - 但只做一次 —— 做完之后,加多少 agent、怎么细分角色,都是配置层的事,不再是 kernel 手术。
  - 要避免的是:一个个 agent 往 kernel 里焊路径(claude-pickup、gemini-pickup…),那才是越改越大的坑。

  所以不是"每加一个 agent 都大改",而是"先花一次把身份解耦,之后就便宜了"。我们刚那个 claude-pickup
  缺口,正好是这件事的迷你预览 —— 真要走多 agent,建议把"owner/role-aware dispatch"当个正式 kernel
  设计项,一次做对。现在不动,先聊到这。
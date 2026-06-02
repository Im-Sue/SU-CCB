---
id: cmppm45yt09j35fx6e2
title: Console 对齐文档驱动新结构
doc_type: requirement
status: delivered
created: 2026-05-28T12:00:00.000Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

docs 文档驱动架构(ADR-0037)落地后,plugin 侧真相已上移到 `docs/01-99`、`.ccb` 降级为协调层、DB 退为可重建投影。但 Console(web + server + DB)仍残留改版前的模型与死料,需要一次全面对齐:

1. **杀掉"状态文档"模型**:UI 还假设有独立 `.ccb/state/*.md` 存活动状态(stateProjection / statePath / "State drift" / refresh-stale-projections);新模型状态在 `docs/03` dev_task frontmatter,根本没这份文档(服务端已把 staleState 检测 stub 成 0)。
2. **堵服务端写真相的漏洞**:`POST /tasks/:id/derive` 凭空造 Task/Requirement 行(无对应文档);planning / breakdown 还直接翻 `Requirement.status`。
3. **清 legacy 分类/死列**:DB 死列(linked* / outputMode / splitMode / epic 四件套 / spec 枚举)、server 的 `.ccb/{plans,tasks,decisions}` kind 分支、web 的 spec/plan/task/state 分类与死代码。
4. **契约成唯一路径源**:indexer 去掉写死路径字面量,全走 `docs-structure-contract.yaml` resolver。
5. **UX 优化**:Documents 按新 doc_type 重列、Overview 无意义的 drift 卡换真实健康、导航可见性确认。

## 原话（verbatim）

我们下面来讨论一下console的优化，先全面扫描一下当前console界面需要的数据、按钮、交互逻辑，深度分析和思考一下，对应功能如何对接新的目录结构或者说数据和plugin产出，相关的数据库是否需要重新设计调整？

## Claude 解读

这是 ADR-0037 文档驱动迁移的**下游收尾**:plugin 侧已转文档驱动,本需求把 Console 三层(web / server / DB)对齐到同一真相模型。

关键判断(已与用户对齐):
- **DB 不重新设计**:schema 已用 `@owner` 标注按投影模型设计好(plugin-canonical 真相 / console-projection 投影 / console-internal 运行态 / append-only-audit),且有 `schema-ownership-lint` 硬性强制。要做的是**剪枝(删死列)+ 堵漏(去掉还在写真相的路由)**,不是推倒重来。
- **范围**:全对齐 + 清理(P1 真相流收口 → P2 杀状态文档模型 → P3 legacy 剪枝 → P4 UX),符合"迁移不留旧逻辑"原则。
- **需求作者**:保持 Console md-first(写 md 再投影,已合规)。

## 歧义点

无重大歧义。范围(全对齐)、需求作者(md-first)已与用户拍板;三个子决策(derive 改 dispatch / doc kind 按契约重列 / 隐藏导航保留)按本设计推进,P4 与用户最终确认导航。

承接自需求《关于docs的规范制定》(cmpmv55uy7d2673077860d06a)与 ADR-0037。

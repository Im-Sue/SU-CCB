---
id: td-ebadfe-attention-inbox-list-toast-dnd
title: "BUG: 通知相关的消息没有展示出来 技术设计"
doc_type: technical_design
requirement_id: cmq7mj42v10e7ef5f4eebadfe
expression_spec: v1
updated: 2026-06-10
---

# 通知消息列表 + 页面 Toast + DND 拆层 技术设计

> 一句话：后端把「暂停打扰」和「隐藏消息」拆开，前端把通知弹窗改成消息列表为主、新消息按页面可见性互斥投递（可见弹页面 Toast、不可见走浏览器通知） ｜ 最后更新: 2026-06-10
>
> **无独立 status** —— 跟随 `requirement_id`（cmq7mj42v10e7ef5f4eebadfe）指向的需求。

---

## 一、设计概述

**目标对齐**：你点 Console 顶部的「通知 6」，现在只能看到设置项，看不到这 6 条消息——因为前端从来没渲染过消息列表，而数据其实早就有了。这份设计做三件事：①弹窗重排成「消息列表为主」，每条可点击跳转处理、可单条或全部标记已读，原来的设置收进底部折叠区；②新消息来时，如果你正看着页面就弹页面内 Toast（= 角落自动出现又消失的小提示条），没看页面才走浏览器系统通知，两者不重复打扰；③「项目暂停」改成只暂停打扰、不隐藏消息——暂停期间不弹任何提示，但点开弹窗仍能看到全部未读（这是唯一的后端改动，且不动数据库）。

| 项 | 说明 |
|----|------|
| 名称 | attention 通知列表 + 页面 Toast + DND 投递/展示拆层 |
| 核心职责 | 让未读 attention 消息可见、可处理、可被及时感知 |
| 设计原则 | 单一数据源（Manager 轮询 → snapshot store → Bell 渲染）；投递通道互斥；ack 失败不乐观清除 |
| 需求来源 | `docs/02_需求设计/bug-通知相关的消息没有展示出来-ebadfe-需求.md` |
| 覆盖范围 | su-oriel web 前端 + attention-inbox 服务端 DND 语义 |
| 不覆盖 | 历史消息分页/消息中心、跨项目通知、通知产生与聚合逻辑、轮询频率、Toast 组件交互模型（保持 3s 纯文本不可点击） |

---

## 二、方案与架构

```
server: attention-inbox.service.computeAttention
  items/count 恒为 unacked（不再因 DND 清空）
  响应新增 dnd_active / dnd_until
        │  GET /attention (7s 轮询，现状保留)
        ▼
web: NotificationManager (轮询者/投递者)
  ├─► ui-store.attentionSnapshot     ◄── 单一数据源
  │     {projectId, items, count,         （含 fetchedAt，
  │      dndActive, dndUntil, fetchedAt}    projectId 防 stale）
  │          │
  │          ▼
  │   NotificationBell (纯渲染消费者)
  │     头部: 未读数 + 全部已读
  │     列表: severity/title/summary/时间 → 点击跳转+ack
  │     横幅: dndActive 时「已暂停投递，消息仍可见」
  │     底部: <details> 折叠原投递/暂停设置
  │
  └─► 投递决策（每轮新增 attention 级 item）
        dndActive ────────► 全部静默
        页面 visible ─────► 页面 Toast（聚合）+ 声音
        页面 hidden ──────► 浏览器通知 + 声音（现状，leader 协调保留）
```

| 关键原则 | 说明 |
|----------|------|
| 投递与展示分层 | 服务端只负责「有哪些未读」；「现在该不该打扰」由客户端按 dnd_active + visibility 决策 |
| 单一数据源 | items 只由 Manager 轮询写入 snapshot，Bell 不自行 fetch，避免双请求与状态分叉 |
| 互斥投递 | 同一条新消息只走一个通道：Toast（可见）或浏览器通知（隐藏），不双发 |
| ack 不乐观 | ack 成功才本地移除该条；失败保留并 toast 提示 |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| attention-inbox.service.ts | 删 DND 清空逻辑，响应加 dnd_active/dnd_until | 聚合来源、排序、ack、settings 端点全不动；DB schema 零改动 |
| NotificationManager.tsx | tick 写 snapshot；投递分支按 dndActive/visibility 改写 | 7s 轮询、ackWithRetry、leader 多 tab 协调（仅服务浏览器通知）不动 |
| NotificationBell.tsx | 弹窗重排为列表为主；设置 JSX 原样移入折叠区 | 设置项功能、saveDnd 流程不动（仅补 snapshot 同步） |
| ui-store.ts | attentionUnreadCount 升级为 attentionSnapshot | toasts、notificationSettings 结构不动 |
| browser-notify.ts | 导出 playAttentionSound | 通知/角标实现不动 |
| Toast.tsx | 不动 | 3s 纯文本模型保持 |

---

## 三、关键决策与取舍

- **dnd 状态放轮询响应体**：选「`dnd_active`/`dnd_until` 随 GET /attention 返回」，因为单次轮询自洽、以服务端时钟为准、省一次 settings 请求；没选「前端另调 settings 接口判断」，因为多一次请求且前后端时钟可能不一致。
- **投递抑制移到客户端**：可行性依据是 `fetchAttention` 的生产消费者只有 NotificationManager 一处（已核验）；这是响应语义变更（旧契约「DND 时 count=0」作废），必须同步改服务端测试断言，不是纯加字段。
- **snapshot 化而非散字段**（Codex 方案，采纳）：选 `attentionSnapshot {projectId, items, count, dndActive, dndUntil, fetchedAt}` 整体读写，配 `setAttentionSnapshot / clearAttentionSnapshot / removeAttentionRefs`；没选「在 store 里加 attentionItems 散字段」，因为项目切换时散字段易留 stale 数据——Bell 只渲染 `snapshot.projectId === 当前项目` 的数据。
- **Bell 打开不另行 fetch**：7s 新鲜度足够，双请求路径（被否决的 O3）会造成状态不同步。
- **导航函数抽 lib**：`buildAttentionNavigatePath` 从 NotificationManager 移到 `lib/attention-navigation.ts`，Bell/Manager 共用；没选跨组件 import 组件模块的私有导出。
- **全部已读用逐条 ack**：`Promise.allSettled` 循环现有单条端点，成功的 refs 立即 `removeAttentionRefs` 本地移除，失败的保留并 toast「N 条标记失败」；没选新增批量 ack-all 端点，因为未读量常态个位数～二十以内，为此扩 API 面不值（量级变大再升级）。
- **Bell 的 ack 失败不承诺自动重试**：失败提示后由用户重点或等下轮（item 反正还在）；没选把 Manager 的 pending-ack 重试机制抽成共享模块，因为收益小于复杂度（Codex 同议）。
- **不加 pageToastEnabled 开关**（采纳 Codex，否决我的初稿）：Toast 默认开启，靠「仅 attention 级 + 同批聚合 + DND 静默」三层控噪；新增偏好设置不是本 bug 必需项，若实际使用反馈噪音再补（改动成本低）。
- **多 tab 同时可见的重复 Toast 接受为 v1 边界**：leader 协调只保留给浏览器通知；为页面 Toast 加跨 tab 协调不值。

---

## 四、核心流程 / 逻辑

```
tick()（7s，现状）:
  fetchAttention(projectId)
    → setAttentionSnapshot({projectId, items, count, dndActive, dndUntil, fetchedAt})
    → setAttentionBadge(count)            ← 页签角标照常（含 DND 期间）
    → retryPendingAcks(现状)
    → 计算新增候选 candidates（severity=attention 且首轮不投递，现状逻辑）
    → if (dndActive) return               ← 全部静默，仅展示层已更新
    → if (document.visibilityState === "visible")
         addToast("info", 1条 ? `新通知：${title}` : `${N} 条新通知`)
         soundEnabled && playAttentionSound()
      else
         （现状浏览器通知分支：leader 协调 + showBrowserNotification + 声音）

Bell 单条点击:
  navigate(buildAttentionNavigatePath(item)) → ackAttention(ref)
    成功 → removeAttentionRefs([ref])（角标随 count 同步减）
    失败 → toast「标记已读失败」，条目保留

Bell 全部已读:
  Promise.allSettled(items.map(ack)) → 成功 refs 本地移除
    全成功 → 角标清零；部分失败 → toast「N 条标记失败」，失败条目保留

saveDnd 成功（Bell 内，现状函数）:
  → 立即同步 snapshot.dndActive/dndUntil（不等下一轮 7s，消除竞态窗口）
```

**模拟示例**：你停留在看板页（visible），slot4 完成审查产生 1 条 attention 消息。≤7s 后轮询返回 `{items:[…7条], count:7, dnd_active:false}` → snapshot 更新、角标 6→7 → 该条是新增 attention 级且页面可见 → 右下角 Toast「新通知：审查回执待处理」+ 提示音（浏览器通知不弹）。你点「通知 7」→ 弹窗列表首条即该消息 → 点击跳到对应任务页，`ackAttention` 成功，本地移除，角标变 6。随后你点「项目暂停 1 小时」→ snapshot 立即 `dndActive=true` → 弹窗出现「已暂停投递，消息仍可见」横幅，新消息只涨角标/列表，不再有任何弹出提示。

| 处理规则 | 说明 |
|----------|------|
| stale 防护 | snapshot 带 projectId；projectId 变化时 clearAttentionSnapshot；Bell 仅渲染匹配项目的 snapshot |
| 首轮不投递 | 沿用现状 `knownRefs === null` 跳过，避免刷新页面被存量未读轰炸 |
| 投递幂等 | 沿用现状 shownRefs 去重；Toast 分支同样登记，防同一条跨轮重复弹 |
| ack 幂等 | 服务端 upsert（现状），重复 ack 无害 |
| 失败可观测 | ack 失败沿用现有 error toast 语义；轮询失败保持 best-effort 静默重试（现状） |

---

## 五、测试策略

- [ ] server 单元（attention-inbox.service.spec）：DND 激活时 items/count 仍返回 unacked 且 `dnd_active=true`、`dnd_until` 透传；未设置 DND 时 `dnd_active=false`（**改写旧断言「DND 后 count=0」**）
- [ ] web 单元（NotificationManager.spec）：visible → 仅 Toast（聚合文案、声音 mock）；hidden → 仅浏览器通知（现状断言保留）；`dnd_active=true` → 两通道全停但 snapshot/badge 照常更新；playAttentionSound mock 同步更新
- [ ] web 单元（NotificationBell.spec 新增）：列表渲染（severity/标题/时间）、单条点击 navigate+ack、ack 失败条目保留+toast、全部已读部分失败语义、DND 横幅、设置折叠区仍可操作、projectId 不匹配 snapshot 时不渲染列表
- [ ] 端到端走查（手动）：按「四、模拟示例」全流程过一遍，含浏览器通知权限「未询问」场景下页面 Toast 可达

---

## 七、接口设计

| 端点 | 方法 | 变化 | 认证 |
|------|------|------|------|
| /api/projects/:projectId/attention | GET | 响应新增 `dnd_active: boolean`、`dnd_until: string\|null`（snake_case 与现有字段一致）；DND 期间 items/count 不再清空（**语义变更**） | 现状 |
| /api/projects/:projectId/attention/ack | POST | 不变（「全部已读」由前端循环调用） | 现状 |
| /api/projects/:projectId/attention/settings | GET/PUT | 不变 | 现状 |

无 DB schema 变更、无新端点、无新依赖。

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-oriel/server/src/modules/attention-inbox/attention-inbox.service.ts`：computeAttention 删 `visible = dndActive ? [] : unacked`，返回体加 dnd_active/dnd_until
- `[MODIFY] su-oriel/server/src/modules/attention-inbox/attention-inbox.types.ts`：AttentionListResponse 加两字段
- `[MODIFY] su-oriel/web/src/lib/console-api.ts`：AttentionListResponse 类型同步
- `[MODIFY] su-oriel/web/src/stores/ui-store.ts`：attentionUnreadCount → attentionSnapshot（含 set/clear/removeRefs 三个 action；保留派生 count 供角标）
- `[NEW] su-oriel/web/src/lib/attention-navigation.ts`：buildAttentionNavigatePath 迁入（Manager/Bell 共用）
- `[MODIFY] su-oriel/web/src/lib/browser-notify.ts`：导出 playAttentionSound
- `[MODIFY] su-oriel/web/src/components/notifications/NotificationManager.tsx`：tick 写 snapshot；投递分支按 dndActive/visibility 互斥改写
- `[MODIFY] su-oriel/web/src/components/notifications/NotificationBell.tsx`：弹窗重排（列表/全部已读/DND 横幅/设置折叠），aria-label 改「通知」
- `[MODIFY] su-oriel/web/src/components/notifications/NotificationBell.module.css`：列表区样式（max-height + 滚动）
- `[MODIFY] 相关 spec 文件`：见「五、测试策略」

---

## 十、迁移影响与风险

- **受影响**：attention 响应契约（DND 语义）、NotificationManager 投递行为、ui-store attention 字段形态。
- **打法**：server 与 web 同一批改动同仓 su-oriel 交付，无跨版本兼容窗口（不支持旧 bundle 长期挂在旧 DND 语义上）。
- **回滚 / 恢复**：纯代码改动，git revert 即可；无数据迁移、无状态残留（attentionAck 数据兼容两种语义）。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 项目切换后 Bell 渲染 stale 列表 | 中 | 误导用户 | snapshot.projectId 防护 + 切换即 clear（专项测试覆盖） |
| saveDnd 后 7s 内投递未停 | 中 | 暂停后仍被打扰一次 | saveDnd 成功立即同步 snapshot，不等轮询 |
| 旧「DND=清空」语义的隐性依赖 | 低 | 角标行为变化让用户困惑 | 已 grep 确认唯一消费者；DND 横幅文案显式解释「仍可见」 |
| 全部已读部分失败的状态混乱 | 低 | 角标与列表短暂不一致 | 仅移除成功 refs，下一轮轮询收敛 |
| 多 tab 同时可见重复 Toast | 低 | 轻微重复提示 | 接受为 v1 边界（已记录），leader 协调仅保留给浏览器通知 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-10 | v1.0 | 初版（Claude 起草，Codex 协商 1 轮后定稿：采纳 snapshot 化、删 pageToastEnabled、导航抽 lib、saveDnd 竞态修补） |

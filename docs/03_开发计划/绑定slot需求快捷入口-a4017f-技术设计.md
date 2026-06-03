---
id: slot-requirements-fab-design
title: 绑定 slot 的需求快捷入口 技术设计
doc_type: technical_design
requirement_id: cmpxrd5tx5a10460b1fa4017f
updated: 2026-06-03
---

# 绑定 slot 的需求快捷入口 技术设计

> 一句话:在 App 全局右下角挂一个只读悬浮入口,点开懒加载 slots 投影、列出 `requirement != null` 的占用需求,点击跳需求详情页;不改后端、不加依赖、不建通用 dock。 ｜ 最后更新: 2026-06-03
>
> **无独立 status** —— 跟随需求 `cmpxrd5tx5a10460b1fa4017f`。做什么/为什么见同名《需求设计》。关联 **ADR-0041**(`planning` ↔ UI「推进中」语义,故本入口文案避开「推进中」)。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | 绑定 slot 的需求快捷入口(`SlotRequirementsFab`) |
| 核心职责 | 全局右下角悬浮入口,点开列出当前 project 下「绑定 slot 的需求」,点击导航到需求详情页 |
| 设计原则 | 只读 / 懒加载 / 轻量(不引入全局 slots store、不加常驻轮询、不建通用 dock) |
| 需求来源 | `docs/02_需求设计/增加一个推进中需求快捷入口-a4017f-需求.md` |
| 覆盖范围 | 前端单例 FAB 组件 + 取数过滤 + 路由跳转 + 与 Toast 的薄共存 |
| 不覆盖 | 后端/接口/schema 变更;跨 project 聚合;slot 绑定/释放操作;按生命周期(planning/delivering)筛选;排队(queued)需求 |

---

## 二、方案与架构

```
App.tsx / ConsoleLayout (全路由常驻)
  └─ <SlotRequirementsFab/>   (fixed 右下角, 与 <ToastViewport/> 同级)
        ├─ 收起态: 悬浮圆钮(icon)
        └─ 展开态(点击): 上方弹出小面板
              data ← 点开时 fetchSlots(selectedProjectId)   [本地 state, 无全局 store]
                   → filter(slot.requirement != null)        // 排除 idle / main coordination lane
                   → 按 requirementId 聚合(同需求多 slot 合一条, 保留多个 slot/state chip)
                   → 列表项: 需求 title + slot/state chip
              click 列表项 → navigate(/requirements/:id) → 收起
```

| 关键原则 | 说明 |
|----------|------|
| 只读 | 仅消费现有 `fetchSlots`,不回写任何状态 |
| 懒加载 | 仅在点开时取数,本地 state 持有;无全局 slots store、无常驻轮询 |
| 薄共存 | Toast 用 CSS 变量避让,不建通用 dock 框架;`load()` 写成可复用 callback,后续加「展开期轻刷」不改结构 |

**与现有系统的关系 / 边界**:

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `App.tsx`(ConsoleLayout) | `[MODIFY]` 在 `<ToastViewport/>` 同级挂 `<SlotRequirementsFab/>` | 不动路由与其它单例 |
| `console-api.fetchSlots` | `[复用]` 只读调用 | 不改接口/投影 schema |
| `Toast.module.css` | `[MODIFY]` 加 `--floating-action-reserved-bottom` 变量做避让 | 默认行为不变(无 FAB 时 0 偏移) |
| `SlotsPage` | `[不动]` | 不抽全局 hook(它还耦合 `fetchProjectCcbdStatus`),避免扩大 diff |

---

## 三、关键决策与取舍(Claude / Codex 协商结论)

**协商**:Codex consult `job_bbd9d8fa87d6`,一轮达成共识(`analysis_depth_hint: none`)。

- **取数 = 懒加载**:选「点开即取」,否决「全局 slots store + 常驻 5s 轮询」—— 给便捷入口挂常驻后台请求成本不值;懒加载即满足原话「点击展开」,且点击发起的 fetch 比后台轮询更新。slot 变态风险主要发生在面板已打开之后,不影响「跳详情」主任务。
- **始终渲染 + 空态**:选「有 selected project 即渲染 FAB、空数据在面板内显示空态」,否决「hide-when-empty」—— 后者为决定是否显示反而要后台拉数。
- **Toast 避让用 CSS 变量**:选「加 `--floating-action-reserved-bottom`,有 FAB 时置保留高度」,否决「硬改 Toast `bottom` 固定值」(会让 Toast 永久上移,即使无 FAB)。这不等于建 dock;ea509d 后续跟随同一变量约定即可。
- **z-index**:FAB / 面板高于页面内容、低于 drawer(60)/modal(100)/palette(140)/toast(200) 等聚焦浮层;**避开 50**(`SlidePanel` 占用)。聚焦交互打开时 FAB 被盖住,符合预期。
- **去重保留多 slot**:同需求占多 slot 时聚合一条,但展示多个 slot/state chip,不丢 slot 信息。
- **不建通用 dock 框架**:ea509d 未落地,不反向放大本需求;仅留「right-edge FAB 向上堆叠 + 共享 `--floating-action-reserved-bottom` 变量」的薄约定。

**4 锚点反思**:

- **我同意**:懒加载对主任务无陈旧风险、始终渲染 + 空态、不建框架 —— Codex 与我一致,增强信心。
- **我修正**:Toast 避让改 CSS 变量(不硬改 bottom)、z-index 明确避开 50、去重保留多 slot chip —— 均采纳,比我原案更稳/更准。
- **我的盲点**(原案漏标,采纳补入):① project 切换的请求竞态(点开后切 project、旧响应回来串数据);② fetch 失败要面板内错误态 + 重试,不能只 toast;③ 详情页当前项要标「当前」并禁点;④ 移动端 viewport-safe 尺寸。
- **接下来**:把上述修正写入设计;右下角 FAB 垂直顺序 / 聚焦浮层覆盖关系作 Claude 自决约定(Codex 确认不必升级用户);判断进 task_breakdown。

---

## 四、核心流程 / 逻辑

```
点 FAB(收起 → 展开)
  → fetchSlots(selectedProjectId)        [记录本次 projectId + requestId]
  → 成功: derive boundItems → 渲染列表(空则空态)
  → 失败: 面板内错误态 + 重试按钮
点列表项 → navigate(/requirements/:id) → 收起面板
切 project / 关面板: 丢弃在途旧响应(requestId 不符即忽略)
```

| 处理规则 | 说明 |
|----------|------|
| 请求竞态 | 每次取数记 `requestId` + `projectId`,响应回来与当前不符则丢弃(或 `AbortController`) |
| 去重聚合 | 按 `requirementId` 聚合,合并多 slot 的 state chip |
| 排除项 | `slot.requirement == null`(含 idle / main lane)、`queued[]` 不进列表 |
| 当前需求 | 在某需求详情页时,该项标「当前」并禁点(不移除,因 FAB 价值是跨需求切换) |
| 边界态 | 无 selected project → 不渲染;空列表 → 面板内「暂无绑定 slot 的需求」 |

---

## 五、测试策略

- [ ] 单元:`deriveBoundRequirementItems(slots)` —— filter `requirement != null`、按 id 聚合多 slot、排除 main/queue、空输入
- [ ] 组件:FAB 渲染 / 点开取数 / 列表点击 `navigate` / 空态 / 错误态 + 重试 / 无 project 不渲染 / 当前项禁点
- [ ] 竞态:切 project 后旧响应被丢弃
- [ ] 视觉(手动):FAB 不遮挡 Toast;drawer/modal 打开时 FAB 被覆盖;移动端面板不溢出

---

> 以下涉及才填。

## 七、接口设计

无新增接口。复用 `GET /api/projects/:projectId/slots`(`fetchSlots`),只读消费 `SlotProjectionView`。

---

## 八、文件结构 / 变更清单

```
su-oriel/web/src/components/slot-requirements-fab/
  ├─ SlotRequirementsFab.tsx         [NEW] 单例组件 + 懒加载 + 面板 + 错误/空态
  ├─ SlotRequirementsFab.module.css  [NEW] fixed 定位 / 动画 / 移动端约束
  └─ deriveBoundRequirementItems.ts  [NEW] 纯函数 SlotProjectionView → 列表项(可单测)
```

- `[MODIFY] su-oriel/web/src/App.tsx`:ConsoleLayout 内 `<ToastViewport/>` 同级挂 `<SlotRequirementsFab/>`
- `[MODIFY] su-oriel/web/src/components/ui/Toast.module.css`:用 `--floating-action-reserved-bottom` 变量做避让(默认 0,不影响现状)

---

## 九、依赖与配置

无新增运行时依赖(复用 React / Zustand / react-router / CSS modules)。

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| `--floating-action-reserved-bottom`(CSS 变量) | `0` | 右下角 FAB 共享避让约定;有 FAB 时置为 FAB 高度 + 间距,Toast 据此上移 |

---

## 十、迁移影响与风险

- **受影响**:`App.tsx` 挂载点、Toast 定位(经 CSS 变量,默认行为不变)。
- **打法**:纯新增组件 + 一处挂载 + 一处 CSS 变量;不碰后端 / 接口 / schema。
- **回滚 / 恢复**:移除 `<SlotRequirementsFab/>` 挂载 + 还原 `Toast.module.css` 即可(单 commit `git revert`)。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 请求竞态串数据 | 中 | 中 | `requestId`/`projectId` 校验丢弃旧响应 |
| Toast 堆叠被破坏 | 低 | 中 | CSS 变量避让,默认 0 偏移,无 FAB 不影响 |
| 懒加载点开瞬间状态略旧 | 低 | 低 | 面板内刷新按钮;主任务是跳转,不依赖实时态 |
| 移动端面板溢出 | 中 | 低 | `max-width`/`max-height` + viewport-safe 定位 |
| 文案「推进中」与 `planning` 混淆 | 低 | 中 | UI 用「绑定 slot 的需求 / Slot 中需求」 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-03 | v1.0 | 初版(需求 a4017f 技术设计,经 Codex `job_bbd9d8fa87d6` 协商达成共识) |

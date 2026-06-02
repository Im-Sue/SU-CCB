---
id: cmpmdz8n12azw9p19sicoaigj
title: 需求详情页缺少解绑 slot 按钮
doc_type: requirement
status: delivered
created: 2026-05-26T08:41:43.549Z
analysis_input_hash: 02f318c53f545821b0dcb06a38c9ac2a722cc95f19bd75230b2f263b926b7c33
analysis_applied_at: 2026-05-26T08:41:43.560Z
---

> ⚠️ Requirement status canonical 在本 md，Console 仅投影展示。

## 需求描述

需求详情页「Slot 运行位置」面板在需求绑定 slot 后缺少可发现的解绑入口。现状只有 bound 态显示释放按钮；slot 进入 busy（已派工、有 agent 在跑）后只剩一个跳转 SlotsPage 的文字链接，unhealthy/recovering 等态则完全无入口。本需求统一为：只要该需求绑定了 slot，详情页就显示解绑按钮；点击给出明确提示并由用户人工确认后执行，busy 态走带 reason 的强制释放，并复用既有后端 release API、不新增端点/schema/依赖。

## 原话（verbatim）

现在需求详情页 绑定了slot之后， 缺少解绑slot按钮

## Claude 解读

本需求把需求详情页「Slot 运行位置」面板的解绑入口，从"只在 bound 态出现"修正为"只要该需求绑定了 slot 就显示「解绑」按钮"，并补齐确认与副作用语义。

**经核验的现状（是 UI 状态覆盖 + 文案/确认缺口，不是"功能缺失"）**

- 后端释放能力已存在：`POST /api/projects/:projectId/slots/:slotId/release`（`slot.routes.ts:116`）；普通释放需 `confirm`，busy 态需 `force + reason + confirm`（`:151`）。
- 前端 API `releaseSlot()` 已存在（`console-api.ts:415`）；详情页已有 `handleReleaseSlot`（`RequirementDetailPage.tsx:646`）。
- 真实缺口在渲染分支（`RequirementDetailPage.tsx:994-1018`）：仅 `state==="bound"` 显示「释放 slot」按钮；`busy` 只给一个跳转 SlotsPage 的文字链接；`unhealthy/recovering/draining` 渲染 `null`。绑定后一旦派工，`markBusy` 把 slot 置为 `busy`（`job-slot-router.ts:117`、`user-intent.routes.ts:271`），按钮即消失——这是用户"绑定后看不到解绑按钮"的最可能成因。

**已锁定的需求决策（用户拍板）**

1. **状态覆盖**：只要该需求有 slot 绑定（`bound` / `busy` / `unhealthy` / `recovering`）就显示「解绑」按钮；`draining` 为"释放中"态，天然不显示。
2. **busy 态破坏性动作**：按钮照常显示，点击弹**警告提示**（有 agent 正在该 slot 运行、解绑会中断其工作）+ 必填 reason + 用户人工确认后，在详情页内联执行 force release（`force + reason + confirm`）。详情页作为单一控制台，不强制跳走 SlotsPage。
3. **确认与副作用披露**：所有解绑都弹二次确认；确认文案须披露"释放后该 slot 可能被队列中其它需求立即占用"（release 会触发 `onSlotReleased → router.tick` 再调度）。
4. **文案**：详情页「释放」统一改为「解绑」，与「绑定」对称（直接服务用户原话）。

**自决项（低影响）**

- 独立立项（小型 UX / bugfix），不并入 b5c2d5（slot 终端嵌入）；但 b5c2d5 的 T4 重设计 `slotGuidancePanel` 时**须保留**本解绑入口。
- 与 c75fdb（解绑前对 slot 组全部 agent 发 `/new` 清上下文）解耦：本需求只做前端入口 + 复用既有 release API；`/new` 清理由 c75fdb 落在后端 release API 内统一生效，前端按钮不内嵌 `/new` 逻辑。

**验收口径**

1. 需求绑定 slot 后，详情页在 `bound` / `busy` / `unhealthy` / `recovering` 任一态都能看到「解绑」按钮。
2. 非 busy 态点击「解绑」→ 二次确认（含再占用披露）→ 普通释放成功，面板刷新为未绑定。
3. busy 态点击「解绑」→ 含"中断运行工作"警告 + reason 必填的确认 → force release 成功。
4. `draining` 态不显示「解绑」按钮。
5. 不新增后端端点 / schema / 依赖；复用 `releaseSlot` API。

## 歧义点

本需求经 1 轮 Codex consult（`job_24cef357f43d`）+ 3 轮用户拍板澄清。已决歧义与决议：

1. **【状态覆盖】** 详情页解绑入口覆盖哪些 slot 态？→ 用户拍板："只要绑定了就显示解绑按钮"，覆盖 `bound` / `busy` / `unhealthy` / `recovering`（`draining` 释放中态除外）。
2. **【busy 破坏性动作】** busy（有 agent 在跑）态解绑如何处理？→ 用户拍板："一直显示解绑按钮、给个提示、人工自己确定"，即详情页内联 force release（警告 + reason + 人工确认），不强制跳 SlotsPage。
3. **【确认与副作用】** bound 解绑当前直接执行无前端确认，且释放会触发再调度、刚空出的 slot 可能被队列需求立即占用 → 用户拍板：加二次确认 + 披露再占用副作用。
4. **【与 c75fdb 的 /new 耦合】** 解绑是否触发上下文清理？→ 用户拍板：本需求独立先行，`/new` 由 c75fdb 在后端 release API 内统一落地，前端不塞 `/new`。
5. **【文案】** "释放" vs "解绑" → 自决统一为「解绑」（服务用户原话，低影响）。

**必问项扫描**

- **命中且已拍板**：产品方向（状态覆盖）、不可逆 / 破坏性动作（busy force release 中断运行工作、`/new` 清 slot 组全部 agent 上下文）、用户确认语义（二次确认 + 再占用披露）、依赖排序（与 c75fdb 解耦先行）。
- **不命中**：隐私 / 合规 / 成本 / 外部服务 / schema 变更 / 新依赖——复用既有 release API 与既有前端组件，无新数据契约、无数据出境、无新增依赖。

## 保真差异

- **保真差异（关键）**：用户原话"缺少解绑slot按钮"在字面上与代码存在差异——`bound` 态其实已有「释放 slot」按钮（且有测试 `RequirementDetailPage.spec.tsx:352-364`）。经读码核验，真实缺口是：① `busy` 及 `unhealthy/recovering/draining` 态在详情页拿不到解绑按钮（busy 仅文字链接、其余 `null`）；② 文案"释放"未被识别为"解绑"。已就此向用户回放"按钮显示条件 + 状态决策树"，用户据此把需求明确为"只要绑定就显示解绑按钮"。**未按字面"加个按钮"直接实施**。
- **范围非锚定**：立为独立新需求；未用 c75fdb（`/new` 清理）或 b5c2d5（终端嵌入）的旧边界否决或收窄本需求范围，亦未凭假设放大——busy force release 与 `/new` 的破坏性已作为"用户已拍板项"绑定，schema / 依赖等硬约束保持不变。
- **Codex 协商证据**：`job_24cef357f43d`（consult）确认 `bound` 态有按钮、基于读码排除投影 / 匹配 bug，并补出我两个盲点：bound 解绑当前无前端确认、release 触发 `router.tick` 再占用副作用；Codex 推荐 O1 最小安全，用户最终选择更进一步的"busy 内联 force release（带提示 + 人工确认）"。
- **4 锚点反思**：① 我同意 = framing 应从"无解绑能力"修正为"状态覆盖 + 确认语义缺口"；② 我（保留）不同意 = 不预先替用户排除 busy 内联 force release，交其拍板（用户最终确选）；③ 我的盲点 = 漏了"缺前端确认"与"释放再占用副作用"，由 Codex 补出；④ 接下来 = 落需求文件 + 进入技术设计，落实渲染分支扩展、解绑确认弹窗、busy force（reason 表单）、文案改名。
- **sc 替代说明**：未跑 `/sc:analyze`（以逐行读码核验替代，证据精确到行号，强于对一句话需求做静态分析）、`/sc:research`（内部工具控件缺口，无行业调研价值）、`/sc:business-panel`（用户权利 / 破坏性维度已由 Codex `human-decision` hint + 必问项扫描覆盖，无成本 / 隐私 / 合规 / 外部服务暴露）。

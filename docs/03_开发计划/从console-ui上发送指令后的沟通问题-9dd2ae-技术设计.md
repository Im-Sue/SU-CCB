---
id: td-9dd2ae-reply-language
title: 从console UI上发送指令后的沟通问题 技术设计
doc_type: technical_design
requirement_id: cmpzb7fxf8d099992749dd2ae
updated: 2026-06-04
---

# 从 console UI 发指令后 Claude 回复英文 · 技术设计

> 一句话：打开 ccbd 既有的 `CCB_REPLY_LANG` 开关——在 Console 拉起 ccbd 的启动命令里注入规范化后的 `CCB_REPLY_LANG=zh`，让 prompt wrapper 每轮给所有 Claude agent 追加「Reply in Chinese.」；CLAUDE.md 措辞校准为兜底。｜ 最后更新：2026-06-04
>
> **无独立 status** —— 跟随 `requirement_id` 指向的需求。

---

## 一、设计概述

| 项 | 说明 |
|----|------|
| 名称 | Claude 回复语言一致性（中文默认） |
| 核心职责 | 让 Console 触发的 Claude agent 面向用户回复稳定默认中文 |
| 设计原则 | 复用既有机制（不发明新注入）；近请求每轮重申；最小改动；不碰仓外 ccbd 源码 |
| 需求来源 | `docs/02_需求设计/从console-ui上发送指令后的沟通问题-9dd2ae-需求.md` |
| 覆盖范围 | 本项目 ccbd 下所有 Claude provider agent 的面向用户自然语言回复 |
| 不覆盖 | codex agent；代码 / 路径 / commit / 工具输出（保留英文）；per-agent 语言粒度；多语言泛化 |

---

## 二、方案与架构

三层语言控制，本设计「开最强、留兜底、延纵深」：

```
Console 派指令
     │
     ▼
ccbd-launcher.service.ts  buildTmuxLaunchCommand()
     │  env -u TMUX ... CCB_NO_ATTACH=1 [+ CCB_REPLY_LANG=zh]  ccb --project ...
     ▼
ccb 守护进程 ──(control_plane_env allowlist 放行 CCB_REPLY_LANG)──► ccbd worker
                                                                      │
                                  每轮 wrap_claude_turn_prompt() ──► prompt.py:_language_hint()
                                                                      │  读 os.environ[CCB_REPLY_LANG]=zh
                                                                      ▼
                                     喂给 Claude pane 的 prompt 末尾追加「Reply in Chinese.」
```

| 关键原则 | 说明 |
|----------|------|
| 复用既有开关 | ccbd 已内置 `CCB_REPLY_LANG` / `CCB_LANG` → `Reply in Chinese.`，只是没开 |
| 近请求每轮重申 | wrapper 每个 turn 注入，对抗英文主导 harness 的长上下文漂移 |
| 入口无关 | wrapper 包 `job.request.body`，自动覆盖 su-init / resume / cancel / defer / archive 等所有入口 |
| 不跨仓 | 只改 su-oriel launcher 的 env 前缀；ccbd 源码不动 |

**与现有系统的关系 / 边界**：

| 涉及模块 | 本设计如何动它 | 保留 / 不动什么 |
|----------|----------------|------------------|
| `su-oriel/.../ccbd-launcher.service.ts` | 改：启动命令注入规范化 `CCB_REPLY_LANG` | 不动启动流程其余部分 |
| 根 `CLAUDE.md` | 改：语言规则措辞校准为验收口径 | 不动其它规则 |
| ccbd（`~/.local/share/codex-dual/`） | 不动源码，仅依赖其既有 `CCB_REPLY_LANG` 契约 | prompt.py / control_plane_env 全不碰 |
| plugin payload `language` | 本轮不动，记 follow-up | structured-dispatch.ts / parser 不碰 |

---

## 三、关键决策与取舍（Claude / Codex 协商结论）

### 选了什么、否决了什么

- **决策点·注入层**：选 **L3 env 注入（launcher）**——最抗漂移、入口无关、仓内一行即可。否决：① 命令尾拼自然语言 → 破坏 `dispatch-parser:58` 的 `[\s\S]+` + JSON.parse（已证伪）；② 只强化 CLAUDE.md → 弱且物化可能 fail；③ 改 ccbd prompt.py 做 per-agent 粒度 → 跨仓、改动大，全局中文已契合纯中文项目。
- **决策点·取值**：选 **规范化 helper**（只认 `zh/cn/chinese/en/english`，`cn/chinese→zh`，空 / `auto` / 非法 → 默认 `zh`，合法显式 `process.env.CCB_REPLY_LANG` 优先）。否决 `process.env.CCB_REPLY_LANG ?? "zh"`——空串绕过默认、`auto` 被 prompt.py 忽略致无 hint（Codex 纠正）。
- **决策点·死契约**：本轮 **不处理** payload `language:"中文"`，记 follow-up——避免过度工程，L3 已覆盖其意图。

### Codex 协商摘要（job_02f0b1f69b42，1 轮，已达成共识）

- **证实正确性命门**：传播链 `launcher env → control_plane_env() allowlist（含 CCB_REPLY_LANG）→ ccbd 进程 env → wrap_claude_*_prompt()` 成立；自测 `system_fastpath_stress.sh` 为佐证。
- **纠正取值**：`?? "zh"` 不严谨 → 改规范化 helper。
- **澄清范围**：env 全局 → 同项目手工 `ccb ask` 到 Claude 也会中文，属「项目级 Claude 默认中文」策略，比字面「Console-only」略宽。
- **指出局限**：`Reply in Chinese.` 是无条件强命令，对「让 Claude 写英文邮件」类自然语言英文产物可能误伤（技术内容英文一般不受影响）。
- **运维风险**：已运行的 ccbd 不自动获得新 env，**需重启对应 project ccbd 才生效**。

### Claude 4 锚点反思

- **我同意的**：① L3 是最稳注入点（Codex 用 `control_plane_env` allowlist 证实传播）；② 不先做 L1（payload 消费覆盖不全、弱于每轮 wrapper）；③ 取值必须规范化，不能裸 `??`。
- **我不同意 / 保留的**：保持「最小修」边界——不为「严格 Console-only」去改协议加 per-message route option（Codex 列为更大替代），项目级默认中文已满足用户意图。
- **我的盲点**：① 原 snippet `?? "zh"` 有空串 / `auto` 漏洞；② 没强调「需重启 ccbd 才生效」的运维前提；③ 低估「无条件 Reply in Chinese」对英文产物的潜在误伤。
- **接下来**：按「规范化取值 + 重启前提 + 英文产物局限」三点收口，落任务拆分（预计 1 个子任务）。

---

## 四、核心流程 / 逻辑

```
取值规范化（launcher 内）:
  raw  = process.env.CCB_REPLY_LANG ?? process.env.CCB_LANG ?? ""
  norm = lower(trim(raw))
  → en   当 norm ∈ {en, english}
  → zh   当 norm ∈ {zh, cn, chinese} 或 ∈ {"", auto, 其它非法值}   （默认 zh）
  注入 `CCB_REPLY_LANG=<zh|en>` 到 buildTmuxLaunchCommand 的 env 前缀
```

| 处理规则 | 说明 |
|----------|------|
| 显式优先 | 运维已设合法 `CCB_REPLY_LANG`（如 en）则尊重，不强制 zh |
| 默认 zh | 缺省 / 空 / `auto` / 非法 → zh（本项目策略） |
| 不传 auto | `auto` 非 prompt.py 认的值，规范化时折叠为 zh，避免「传了等于没传」 |
| 生效时机 | 改动后需重启对应 project 的 ccbd 守护进程；验收须在「新启动」后核验 |

---

## 五、测试策略

- [ ] 单元（launcher）：默认（无 env）→ 启动命令含 `CCB_REPLY_LANG=zh`
- [ ] 单元：`CCB_REPLY_LANG=en` → 含 `CCB_REPLY_LANG=en`
- [ ] 单元：空串 / `auto` / 非法值 → 回落 `zh`
- [ ] 单元：`cn` / `chinese` → 归一 `zh`
- [ ] 端到端（门控 / 手动）：重启 project ccbd 后，从 Console 发一条指令，Claude 面向用户回复中文；代码块 / 路径仍英文
- [ ] 回归：CLAUDE.md 措辞改动不破坏既有规则

---

## 八、文件结构 / 变更清单

- `[MODIFY] su-oriel/server/src/modules/anchor-lifecycle/ccbd-launcher.service.ts`：`buildTmuxLaunchCommand()` env 前缀注入规范化 `CCB_REPLY_LANG`；新增取值规范化 helper（或内联）。
- `[MODIFY] su-oriel/.../ccbd-launcher.service.spec.ts`（同级 spec）：补默认 / 覆盖 / 回落 / 归一断言。
- `[MODIFY] CLAUDE.md`：语言规则措辞 →「面向用户回复默认中文；代码 / 路径 / 标识符 / commit / 工具输出保留英文」。
- `[FOLLOW-UP] su-oriel/.../structured-dispatch.ts` 的 payload `language`：本轮不动，后续 reserved / documented 或按入口消费。

---

## 九、依赖与配置

| 依赖 | 调用方式 | 说明 |
|------|----------|------|
| ccbd `CCB_REPLY_LANG` 契约 | env 传递 | 既有机制，prompt.py 每轮读取；不新增依赖 |

| 配置 key | 默认值 | 说明 |
|----------|--------|------|
| `CCB_REPLY_LANG` | `zh` | 本 Console managed launcher 默认；合法显式值（zh / en）优先；空 / auto / 非法 → zh |

---

## 十、迁移影响与风险

- **受影响**：本项目 ccbd 下所有 Claude provider agent 的面向用户回复（含 Console 派发 + 同项目手工 `ccb ask`）。
- **打法**：仅改 launcher env 前缀 + 文案；改后重启对应 project ccbd 生效。
- **回滚**：移除 env 注入即恢复原状（git revert 单文件）。

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 改后未重启 ccbd → 不生效 | 中 | 验收误判 | 验收明确「重启后核验」；交付说明提示重启 |
| 无条件中文误伤英文产物 | 低 | 用户要英文邮件时被中文 hint 干扰 | 记局限；用户显式要求英文时通常仍优先；成痛点再走「Reply in Chinese unless...」大改 |
| 运维已设 CCB_LANG=en 被覆盖 | 低 | 与运维意图冲突 | 规范化里合法显式 `CCB_REPLY_LANG` 优先，不动 `CCB_LANG` 语义 |
| no_wrap / reply_delivery 路径绕过 wrapper | 低 | 个别路径无 hint | 非 Console 普通 ask 主路径，记为已知边界 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-04 | v1.0 | 初版：L3 env 注入 + CLAUDE.md 校准 + payload.language follow-up |

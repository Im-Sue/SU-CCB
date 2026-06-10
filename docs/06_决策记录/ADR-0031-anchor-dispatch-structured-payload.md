---
id: ADR-0031
title: Anchor Dispatch 协议改进 · Structured JSON Payload
status: active
decided_at: 2026-05-22
last_updated: 2026-05-22
decider: 用户（基于 Phase 2a hotfix `feedback_b64` 暴露的协议缺陷）
reviewer: ccb_codex（rep_53bc842dce57 audit 提出）
codename: anchor-dispatch-structured-payload
related_doc: docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md
parent_adrs: [ADR-0023, ADR-0030]  # ADR-0023: plugin sovereignty 主决策; ADR-0030: plugin node paradigm
implements_via: [SP-ADR0031-impl 实施 spec]
---

# ADR-0031: Anchor Dispatch 协议改进 · Structured JSON Payload

## Status

Accepted（2026-05-22）。v1.0 范围内必做协议升级。

## Context

Phase 2a hotfix 实施 reject feedback 传递时，codex 引入 `feedback_b64` base64 编码字段——这是为了绕过现有 anchor-dispatch 协议**只能传 key=value token map**的限制（不支持空白字符 / 多行 / 大 payload）。

codex 后续 review (`rep_53bc842dce57`) 指出：

> `feedback_b64` 是当前协议限制下的工程绕路，但暴露了 anchor-dispatch 只能传 token map 的协议缺陷；长期应改协议，不应每个业务动作自造编码。

业务问题（不只是 `feedback_b64`）：
- 任何包含空格 / 换行 / 中文标点的字符串都需要业务层编码
- 任何嵌套结构（如 reject 反馈含字段细节）需要业务层序列化
- 协议层不能 schema 校验业务 payload 合法性
- 未来 plugin 接收的命令越多，业务编码 hack 越多

## Decision

### 决策 1 · dispatch payload 改 structured JSON

dispatch 命令格式由：

```text
/ccb:<skill> key1=value1 key2=value2 ... key_b64=<base64>
```

改为：

```text
/ccb:<skill> --payload <json-object>
```

或在 anchor 内部协议层用 JSON line:

```json
{
  "command": "su-revise-breakdown",
  "payload": {
    "requirement_id": "req_xxx",
    "expected_hash": "abc123",
    "action": "breakdown_draft_reject",
    "feedback": {
      "summary": "...",
      "items": ["...", "..."]
    }
  }
}
```

### 决策 2 · 直接换协议，不留双轨过渡

v1.0 还没真正稳定发布，外部依赖少，破坏性变更可接受。一次性脱掉历史包袱。

不做：grace period / `*_b64` compat wrapper / 双轨过渡。

### 决策 3 · schema 由 kernel/schemas 定义 + plugin 端校验

新增 `references/kernel/schemas/anchor-dispatch.schema.yaml`，描述：
- 顶层：`command` / `payload` 必填
- payload 内部字段由各 skill 自己声明（参考各 SKILL.md 命令章节）

plugin 端 dispatch parser 收到命令时：
1. 解析 JSON payload
2. 调 `validateAgainstSchema(payload, dispatch-schema)` 基础校验
3. 路由到 skill 时各 skill 自己校验业务字段

### 决策 4 · 前端构造 payload 直接给 JSON object

前端 anchor dispatch helper 改：
- 不再 base64 encode
- 不再 key=value token map 拼接
- 直接发 JSON object 到 anchor-dispatch endpoint
- anchor 内 plugin parser 解析 JSON

### 决策 5 · 业务层 `*_b64` 全部废弃

`feedback_b64` 等业务层 base64 编码字段全部删除，回归 native string + JSON nested structure。

## 非目标（明确不做）

- 不做 protobuf / msgpack 等二进制协议（JSON 文本足以）
- 不做协议版本字段（v1.0 一次性切换，未来如演进再加 `schema_version`）
- 不做 gRPC / WebSocket 等长连接（保持现有 HTTP / stdin/stdout 单向投递）
- 不动 ccbd 层协议（dispatch 是 anchor 内 plugin parser 范围）

## 替代方案

| 方案 | 拒绝原因 |
|---|---|
| A · 保留 token map 但允许 quoting / escape | 仍是字符串编码，业务层仍要逃逸，比 JSON 复杂 |
| B · 用 form-urlencoded 标准格式 | 不支持嵌套结构，仍需 base64 |
| C · 业务层逐个加 `*_b64` 编码 | 当前路径，每加一个业务字段就要一次工程层 hack |
| D · 双轨过渡 grace period | v1.0 没真稳定，没必要保留历史包袱 |

## 影响范围

### 改动文件

**Plugin 端**：
- `su-ccb-claude-plugin/lib/dispatch-parser/` 或类似（如不存在，新建）—— JSON payload 解析
- `references/kernel/schemas/anchor-dispatch.schema.yaml`（新建）
- 各 SKILL.md 命令章节（移除 `key_b64` 描述 + 改为 JSON payload 示例）

**Console 端**：
- `apps/ccb-console/server/src/modules/anchor-broker/` 或 anchor dispatch 调用方（构造 payload 改 JSON）
- `apps/ccb-console/web/src/lib/` 前端 dispatch helper

**前端**：
- 调用 dispatch helper 的所有地方（breakdown-review / requirement detail / 等）

### 不动

- ccbd 协议层
- Prisma schema
- runtime（lib/runtime/ 不动）
- breakdown-draft / subtask lib（业务层只改输入解析方式）

## 验收

ADR-0031 实施后必须满足：

1. dispatch payload 改 JSON 结构
2. plugin 端 dispatch parser 接收 + 解析 JSON + 基础 schema 校验
3. Phase 2a hotfix 引入的 `feedback_b64` 字段删除（reject feedback 改 JSON nested）
4. 前端 dispatch helper 改 JSON 构造
5. anchor-dispatch.schema.yaml 落档
6. 各 SKILL.md 命令章节同步（去 `_b64` 描述 + JSON payload 示例）
7. 主仓 + plugin 子仓测试全过
8. 主仓 git diff 不包含 Prisma migration

## 风险

| 风险 | 缓解 |
|---|---|
| 现有 ccbd 协议层不支持 JSON payload 透传 | 实施时 verify ccbd 层是否需要改（spec §待 codex 判断 1）|
| 删除 `feedback_b64` 影响 Phase 2a hotfix 测试 | 实施时同步改测试 fixture |
| anchor dispatch endpoint 接收 JSON 时的 size limit | 现有 size limit 已能容下典型 reject feedback；超大 payload v1.x 不优化 |
| 前端 / 后端 / plugin 三端 JSON 字段约定不一致 | schema 在 kernel 单一真相源，三端引用同 schema |

## 关联

- ADR-0023 plugin sovereignty
- ADR-0030 plugin node paradigm
- 触发 review：codex `rep_53bc842dce57`（Phase 2a hotfix audit）
- 父 spec：SP-ADR0031-impl（待 codex 实施）
- 路线图：`docs/03_开发计划/ccb-plan/2026-05-21-plugin-sovereignty-roadmap.md`

## 协商证据

- codex audit `rep_53bc842dce57`（最早提出协议缺陷）
- claude 4 锚点反思 2026-05-22 主对话（验证为协议设计问题非必问命中）
- 用户拍板 2026-05-22（按 claude 推荐方向 A · 直接换协议）

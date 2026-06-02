---
doc_type: dev_task
task_id: subtask-d1a5fed3a615
title: kernel 路由约定 + plugin agent-group resolver(独立 lib + 专用 windows parser)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpmlnqxd02346a524ec5c98f
section_id: pr1-group-resolver
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpmlnqxd02346a524ec5c98f.json
source_draft_hash: 9750cbc128d65b47876a065db851dadc30e5d3d63952966e447b861637086a82
created_at: 2026-05-31T12:06:01.567Z
updated_at: 2026-06-01T06:51:39.069Z
updated_by: ai_session
---

# kernel 路由约定 + plugin agent-group resolver(独立 lib + 专用 windows parser)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 中立 kernel 加 provider 中立路由约定;plugin 新增 lib/agent-group resolver(config→组→对端,peer\|ambiguous\|no_peer)+ 专用只读 [windows] parser(不引 TOML);组=window 成员关系不绑 slot。 |
| 需求来源 | cmpmlnqxd02346a524ec5c98f |
| 本期范围 | pr1-group-resolver · kernel 路由约定 + plugin agent-group resolver(独立 lib + 专用 windows parser) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标

落地'同组对端'真相源与 Claude 侧解析:中立 kernel 加 provider 中立路由约定;plugin 新增 agent-group resolver(纯函数)。依据技术设计 docs/03_开发计划/ccb消息投递错乱问题-c5c98f-技术设计.md。

### 范围(kernel + plugin lib,含测试)

- [NEW] references/kernel:新增 provider 中立的 agent 路由/对端约定(先锚定自身 → 同组互补对端 → 跨组要理由);同步 root 与 plugin 分发副本。
- [NEW] su-ccb-claude-plugin/lib/agent-group/(独立 lib,勿并入 slot-health —— 后者语义是 stale/health):resolver 纯函数,输入当前 agent 名 + 解析后的 windows,输出 {kind: peer|ambiguous|no_peer, peer?}。
- [NEW] [windows] 解析:plugin 目前无现成 ccb.config [windows] parser(现有解析在 Console ad-hoc 或仓外 runtime),故新增一个专用、测试覆盖的 [windows] topology parser —— 只解析分组与成员(name:provider),不做完整 TOML 引擎、不引第三方依赖。
- 组与对端规则:组 = 同 window 成员集合,不识别 'slot' 字符串;同 window 排除自己 → 互补 provider 候选;唯一 → peer;0/多 → no_peer/ambiguous。

### 验收

- 单测:1c+1x → peer;纯单 provider → no_peer;多互补 → ambiguous;未知 agent → 退化要求显式。
- 单测:组改名(非 slot 前缀)仍正确分组;parser 能解析当前 ccb.config 的 main / slot-1..5。
- resolver 纯函数、无副作用。

### 边界

不接线到 ask 发送路径(PR2 负责);不引 TOML 依赖;不改 ccb.config 格式;不引入 pairing/role。

### 依赖

无(先读技术设计)。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-05-31 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpmlnqxd02346a524ec5c98f
- Section: pr1-group-resolver
- Owner: ccb_codex
- Priority: high
- Dependencies: none

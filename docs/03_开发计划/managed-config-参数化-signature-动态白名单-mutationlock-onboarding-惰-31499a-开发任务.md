---
doc_type: dev_task
task_id: subtask-63cf9631499a
title: managed config 参数化 + signature 动态白名单 + MutationLock + onboarding 惰性模板
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr2-managed-config-param-lock
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-a49275357378]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# managed config 参数化 + signature 动态白名单 + MutationLock + onboarding 惰性模板

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | buildManagedCcbConfig(topology, overrides, options) 改造，collectCoreLines/signature 按 topology 白名单，新建 ManagedConfigMutationLock 并接入全部 config 写入方（含 anchor-template legacy 入口），onboarding module-level 模板改惰性（编译耦合必须同批），overrides 注入/收割函数。golden 单测锁定存量零 drift。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr2-managed-config-param-lock · managed config 参数化 + signature 动态白名单 + MutationLock + onboarding 惰性模板 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
managed-config.service.ts 从硬编码白名单改为 topology 驱动：`buildManagedCcbConfig(topology, preservedAgentFields, options)`；`collectCoreLines`/`computeManagedCoreSignature`/`collectPreservedAgentFields` 按 topology 的 window/agent 白名单动态计算。新建 per-project `ManagedConfigMutationLock`，接入全部 config 写入方。本批是存量兼容的根保证批，高风险，golden 测试先行。

#### 任务分解
1. buildManagedCcbConfig 签名与生成逻辑参数化（CLAUDE_AGENT_DEFAULTS 等保留语义不变）。
2. signature/coreLines/preserved 白名单动态化。
3. overrides 注入（slotAgentOverridesJson 解析 → 生成时 merge，preserved 优先级与现有 agentDefaults/preserved 关系保持）与收割函数（现 config 指定 slot 的 non-core 字段 → JSON 串），供 pr4 缩容调用。
4. 新建 ManagedConfigMutationLock（per-project 互斥，进程内即可——server 单实例）；ensureManagedCcbConfig 全调用方接入：slot-tips-projection.syncSlotTips、ProjectCcbdManager.ensureStarted、confirmRestore、anchor-lifecycle/anchor-template.service.ts:17（同文件 :12 的 module 内 `buildManagedCcbConfig()` 模板生成一并适配新签名——legacy anchor template 写入口，漏改会编译失败或绕过 lock）。
5. ProjectCcbdManager/status 路径从 DB 读 slotCount 构造 topology（替代隐式常量）。
6. project-onboarding.routes.ts 的 module-level `CCB_CONFIG_TEMPLATE = buildManagedCcbConfig()` 改为按需惰性生成（本批改签名的编译耦合，必须同批）。

#### 验收标准
- golden 单测：slotCount=3 + 空 overrides 的生成输出与改造前**字节级一致**（先固化现输出为 fixture 再改造）。
- signature(3) 对现存 config 零 drift 单测；slotCount=4 时 signature/coreLines 含 slot-4 行单测。
- lock 并发串行单测（两个并发 ensureManagedCcbConfig 串行执行）。
- overrides 注入/收割 roundtrip 单测；onboarding 与既有 managed-config/project-ccbd/tips/anchor-template 测试全绿。

#### 边界与依赖
- 依赖：pr1。
- lock 只覆盖 config 写入方；绑定/派发路径的 lock 可见性属 pr5。
- 不改 slot-binding/anchor-broker（pr3 范围）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a49275357378
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmmq2a2x3p25029cbd6d21ff1
- Section: pr2-managed-config-param-lock
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a49275357378

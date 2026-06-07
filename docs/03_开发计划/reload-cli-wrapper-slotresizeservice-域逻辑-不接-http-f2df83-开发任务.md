---
doc_type: dev_task
task_id: subtask-ec4511f2df83
title: reload CLI wrapper + SlotResizeService 域逻辑（不接 HTTP）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr4-resize-domain
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-a49275357378, subtask-63cf9631499a]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
updated_at: 2026-06-07T05:05:23.802Z
updated_by: slot3_claude
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# reload CLI wrapper + SlotResizeService 域逻辑（不接 HTTP）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 独立 reload CLI wrapper（行协议解析+容错+fixture）+ SlotResizeService ±1 编排（扩容 config→reload→DB→active-wait→context-reset；缩容 资格三重检查→收割→DB→config→reload；失败逆序回滚；离线 desired 分支）。纯域逻辑 mock 单测锁死。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr4-resize-domain · reload CLI wrapper + SlotResizeService 域逻辑（不接 HTTP） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
新建 `server/src/modules/slot-resize/`：reload CLI wrapper（独立模块，不混入 CcbdClientService socket client）+ SlotResizeService 编排域逻辑。本批不注册 route、不接 UI——状态机先被单测锁死，pr5 再做集成。

#### 任务分解
1. reload wrapper：spawn `ccb reload`（cwd=projectRoot）；解析行协议（reload_status/plan_class/safe_to_apply/future_safe_to_apply/reload_operation/blocked 前缀行）；未知行容错跳过；无法解析 → 结构化失败 + 原样透出；超时处理。fixture 须为本项目实测 `ccb reload` 真实输出（add_window dry-run/published 两套）：实施时采集并随实施固化提交（技术设计文档仅有 2026-06-06 实测结论，无原始输出可复用）。
2. SlotResizeService.grow(projectId)：acquire lock → 校验 slotCount+1 ≤ 16 → 生成 config(topology(N+1)+overrides 注入) → ccbd 在线? wrapper.reload : 离线写 desired → reload 成功 → DB slotCount+1 → project_view retry 等新 agents active → slot-context-reset（复用现有服务，全新会话兜底）→ 失败回滚 config（DB 未动）。
3. SlotResizeService.shrink(projectId)：acquire lock → 尾部 slot 资格三重检查（SlotBinding 不存在或 idle 且 requirementId=null；无 pending/submitted AnchorDispatchQueue 行——含 su-cancel 指令行，一律阻断（913778 取消闭环语义，缩容不得吞掉待执行取消）；无 active runtime job）→ 不满足返回结构化原因 → 收割尾部 non-core 字段入 slotAgentOverridesJson → DB slotCount-1 → config → reload（bridge idle 二道防线）→ 失败逆序回滚（DB+config）。
4. 磁盘 .ccb/agents/slotN_* 全程不删除（已拍板）。

#### 验收标准
- mock wrapper 单测矩阵：grow 成功/reload 被拒回滚/离线 desired/异常回滚；shrink 资格三重矩阵（每重单独不满足 + 全满足，queue 维包含 su-cancel 行阻断用例）/成功/reload 失败逆序回滚；lock 并发串行。
- parser fixture 单测：真实输出样本解析正确；畸形输出降级失败。
- typecheck + 全测试绿。

#### 边界与依赖
- 依赖：pr1（topology/schema）+ pr2（lock/config 参数化/收割函数）。
- 不注册 route；context-reset/active-wait 的真实时序留 pr5 smoke 验证。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a49275357378, subtask-63cf9631499a
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
- Section: pr4-resize-domain
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a49275357378, subtask-63cf9631499a

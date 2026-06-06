---
doc_type: dev_task
task_id: subtask-f0fa89a40964
title: Console server 运行态闭环：双 gate + supersede + reconcile 释放 slot + E2E 实机冒烟
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmpzllxw73320bc3428913778
section_id: pr3-console-cancel-runtime
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-fc433baac395, subtask-8685e781c00b]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzllxw73320bc3428913778.json
source_draft_hash: acb5232bfcd1c86c58b5b511afaca3f63f1ac749fd999d0c2a1edba3f6c421b1
created_at: 2026-06-06T09:05:52.211Z
code_workspace: {"path":"../SU-CCB-req-cmpzllxw73320bc3428913778","branch":"ccb/req-cmpzllxw73320bc3428913778"}
---

# Console server 运行态闭环：双 gate + supersede + reconcile 释放 slot + E2E 实机冒烟

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | anchor-dispatch 双 gate（cancel_in_progress / cancelled 白名单 409）+ enqueue 同事务 supersede；reconcile 投影 cancelled→释放 SlotBinding+兜底清 pending；superseded 消费方 sweep；generated policy 重生与 su-oriel 侧枚举 stale sweep；server 测试 + 全链路 E2E 实机冒烟收尾。 |
| 需求来源 | cmpzllxw73320bc3428913778 |
| 本期范围 | pr3-console-cancel-runtime · Console server 运行态闭环：双 gate + supersede + reconcile 释放 slot + E2E 实机冒烟 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
Console 运行态闭环与竞态防护：取消排队窗口不再放进新工作，取消落地后 slot/队列资源自动回收；全需求 E2E 实机验证收尾。依据技术设计 §二 gate/reconcile、§七、§五（v1.1）。

#### 任务分解
1. `server/src/modules/anchor-broker/anchor.routes.ts`（withTaskLock 同事务）：①gate-A：同需求存在 pending|submitted 的 su-cancel job 时，新 dispatch→409 `cancel_in_progress`；②gate-B：投影 status=cancelled 且 command∉{su-cancel, su-reactivate}→409 `requirement_cancelled`（白名单保 cleanup 重入与复活）；③enqueue su-cancel 时 supersede 同需求 scope（requirement+其 task ids）pending 非 cancel 队列行→status=`superseded`。
2. reconcile（投影侧）：requirement 投影为 cancelled→释放 SlotBinding（非 busy 即释；busy 等当前 job 完成后释）+ pending 队列行兜底 supersede。
3. **superseded 消费方 sweep**：所有只查 pending|submitted|failed 的 UI/worker/reconcile 路径适配新值（防漏展示/误处理）。
4. `generate:capability-policy` 重生 `server/src/generated/capability-outcome-policy.ts`（基于 pr2 kernel 变更；analyzed 条目随拍板⑤消失）+ su-oriel 侧枚举 stale 引用 sweep（UI legacy alias、测试夹具；breakdown draft 的合法 draft 状态不属修复范围）。
5. server 测试：双 gate、supersede、reconcile 释放、白名单放行；task.routes.spec.ts:299 既有「enqueue 不写业务状态」断言不回归。
6. **E2E 实机冒烟（必做收尾）**：rebuild+重启 server，沙盒需求全链路取消（含子任务+draft+worktree）；重入路径（人为中断后重派）；取消排队窗口 gate 验证；盯日志确认投影收敛/slot 释放/banner→toast。

#### 验收标准
- [ ] 双 gate 与白名单行为测试绿；supersede 同事务生效；reconcile 自动释放 slot。
- [ ] superseded 全消费方 sweep 完成（grep 佐证）；既有断言不回归。
- [ ] generated policy 与 pr2 kernel 一致；su-oriel 无 stale 枚举残留。
- [ ] E2E 冒烟回执：全链路取消 + 重入 + 排队窗口三场景日志/截图证据。

#### 边界 / 不做
- Console 不写业务真相（仅触发/投影/自身运行态）；不做自动抢占；不改 plugin（pr2 范围）。

#### 依赖 / 执行注意
- 依赖 **pr1**（banner/UX 联测面）+ **pr2**（cancel 语义与 kernel yaml 重生源）。
- su-oriel 是 submodule；**勿在主仓跑 server test（db:prepare 清 dev.db）**；E2E 冒烟在隔离环境 rebuild 后执行。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-fc433baac395, subtask-8685e781c00b
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

- Requirement: cmpzllxw73320bc3428913778
- Section: pr3-console-cancel-runtime
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-fc433baac395, subtask-8685e781c00b

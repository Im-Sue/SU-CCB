---
doc_type: dev_task
task_id: subtask-f16180b5ca9a
title: sidebar ⚠️ 投影(B 舱)+ journal 水位对账兜底:两段独立 commit
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpzoupdv863041443e52441f
section_id: pr4-sidebar-and-reconcile
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-89e538a4cdb6]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: db12930dd087b69323ede0b4e05130f3d45a5ba88574794f6e8df3d6994729f6
created_at: 2026-06-06T15:34:39.688Z
updated_at: 2026-06-06T17:33:14.890Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# sidebar ⚠️ 投影(B 舱)+ journal 水位对账兜底:两段独立 commit

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | A 段:slot-tips-projection join 同一 attention 源,高 severity 加 ⚠️ 标记,写前 debounce+content-hash guard(内容不变不写 managed-config)。B 段:journal.jsonl 写入水位 vs DB ingestion 对账,落后触发 reindex,带防无限循环护栏。两段独立 commit、分段验收,失败可二分定位。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr4-sidebar-and-reconcile · sidebar ⚠️ 投影(B 舱)+ journal 水位对账兜底:两段独立 commit |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
B 舱投影 + 需求「必达兜底」业务规则落地。两段无耦合面,强制独立 commit + 回执分段(Codex 协商风险项:混做失败定位会混)。依据技术设计 §二投影 B/§四 syncSlotTips/§八 sync-scan 兜底。

#### 任务分解
**A 段 · sidebar attention 投影**
1. `server/src/modules/slot-binding/slot-tips-projection.service.ts`:`computeSlotTipsProjection` join `computeAttention(projectId)`(同一源,严禁自算规则)→ 绑定需求存在 attention 级 item → `slot-N: ⚠️待你决策 <需求名>`;否则保持既有 `slot-N: <需求名>`。
2. 写前 guard:debounce 窗口 + content-hash(现状每次 sync 都写 managed-config——`slot-tips-projection.service.ts:78`;改为内容 hash 不变即跳过 `ensureManagedCcbConfig` 原子写)。
**B 段 · journal 水位对账兜底**
3. journal.jsonl 写入水位 vs DB ingestion 对账(触点:`server/src/modules/plugin-hooks/plugin-hooks.routes.ts:96` 接收链路 + `server/src/indexer/project-indexer.ts:594` 扫描链路):检测 journal 尾部水位领先 DB ingestion → 触发 reindex 补投(补偿 plugin hook fail-open 300ms 超时漏投)。
4. **误触发防护**:journal 文件缺失/截断/坏行 → 跳过该轮 + 告警日志,不得进入无限 reindex 循环(水位标记 + 冷却窗口);reindex 触发一次后水位收敛即停。

#### 验收标准
- [ ] A:content-hash 不变不写(单测:attention 高频变动但 tips 文本不变时零写入);既有 slot-tip 语义回归(slot↔需求名映射、项目锁、原子写不变)。
- [ ] A:集成——绑定需求出现 pending review → tips 出现 ⚠️;ack 后下轮 sync 消失。
- [ ] B:journal 水位落后 → 触发 reindex 且补投后收敛即停;缺文件/截断/坏行不死循环(测试佐证,含连续坏行场景)。
- [ ] 两段独立 commit;回执分 A/B 段给证据;server typecheck/lint/test 过;task SSE 回归不受影响。

#### 边界 / 不做
- sidebar 不投 main agents(仍 slot-keyed,main 仅 Console 投影);不改 CCB sidebar 自轮询语义(runtime 侧 ~1-2s 显示不动);不动 EventJournal 写入侧;B 段只做「检测+触发 reindex」,不重写 ingestion 链路。

#### 依赖 / 执行注意
- 依赖 **pr1**(computeAttention 接口);排在 pr3 后执行(共享 attention-inbox service 触点 + ⚠️ 冒烟面含 agent_waiting 更完整),但代码依赖仅 pr1。su-oriel submodule 流程同前;勿在主仓跑 server test。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-89e538a4cdb6
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

- Requirement: cmpzoupdv863041443e52441f
- Section: pr4-sidebar-and-reconcile
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-89e538a4cdb6

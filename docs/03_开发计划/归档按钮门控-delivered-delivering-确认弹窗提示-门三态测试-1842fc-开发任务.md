---
doc_type: dev_task
task_id: subtask-f461391842fc
title: 归档按钮门控 delivered→delivering + 确认弹窗提示 + 门三态测试
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq4tn9ub44963ca7baa654c0
section_id: pr1-archive-button-gate-fix
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq4tn9ub44963ca7baa654c0.json
source_draft_hash: f83ef32cfbc69720b1682a81860ae509fb61910a70260443ce3a1b934c275f74
created_at: 2026-06-10T05:08:40.215Z
updated_at: 2026-06-10T05:33:13.443Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq4tn9ub44963ca7baa654c0","branch":"ccb/req-cmq4tn9ub44963ca7baa654c0"}
---

# 归档按钮门控 delivered→delivering + 确认弹窗提示 + 门三态测试

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 前端 RequirementDetailPage：lifecycleDisabledReason(su-archive) 由 delivered 改 delivering + 新 tooltip；归档确认弹窗条件化加'子任务完成合并'提示；同文件 spec 补门三态与提示断言、翻转 delivered 归档断言、it.each 归档 fixture 改 delivering。 |
| 需求来源 | cmq4tn9ub44963ca7baa654c0 |
| 本期范围 | pr1-archive-button-gate-fix · 归档按钮门控 delivered→delivering + 确认弹窗提示 + 门三态测试 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

把需求详情页那个"一直点不动的归档按钮"修好：它现在要求需求"已交付(delivered)"才可点，而"已交付"恰恰是点完归档才会有的结果——死循环、永远灰。改成**需求处于"推进中(delivering)"就可点**；至于此刻能不能真归档成功，交给 plugin 既有硬关卡判断，前端不预先卡死。同时给归档确认弹窗加一句提醒，防手滑提前点。后端/DB/plugin 不动。

> 术语白话：delivering=需求推进中；delivered=需求已交付（终态）。"软门控"=前端只控制按钮亮不亮，真正能否归档由 plugin 硬关卡（cleanupGateAllows / requirement.finalize）判定。

```
当前（错）                          目标（对）
gate: status == "delivered"         gate: status == "delivering"
   └─ 永远点不到（死循环）              └─ 推进中即可点 ─► 派 /ccb:su-archive
                                          └─ 能否真 finalize 由 plugin 关卡判定
```

### 任务分解

改 2 个强耦合文件（行为 + 同文件测试，必须同改）：

1. `su-oriel/web/src/pages/requirements/RequirementDetailPage.tsx`
   - `lifecycleDisabledReason` 的 `case "su-archive"`（约 L257-260）：判据 `status==="delivered"` → `status==="delivering"`；非 delivering 态返回新 tooltip（如"仅 delivering（推进中）状态可归档"）。
   - 归档确认弹窗正文（约 L1433 起的非 su-cancel 分支）：**仅当 `confirmLifecycleAction.command === "su-archive"`** 时追加一行提示"请确认子任务已全部完成并合并后再归档"，不得污染暂缓/复活/恢复运行时/取消的弹窗文案。`confirmActionText`（L278-283）按需配合。
2. `su-oriel/web/src/pages/requirements/RequirementDetailPage.spec.tsx`
   - "shows lifecycle actions with status and runtime constraints" 用例（约 L1050-1073）：**保留 `status:"delivered"` fixture**（该用例还覆盖恢复运行时/暂缓/取消约束），只把"归档"断言从 `not.toBeDisabled()` 翻转为 `toBeDisabled()` 并断言新 title。
   - `it.each` 归档 dispatch 用例（约 L1075-1097）：归档项 fixture `status:"delivered"` → 改为 `delivering`，否则点不开确认弹窗（Codex 明确风险点）。
   - 新增门三态用例：`delivering` 亮（可打开"确认归档需求"弹窗）/ `planning` 等非 delivering 灰（断言新 tooltip）/ `delivered` 灰（断言新 tooltip）。
   - 新增确认弹窗提示断言：归档弹窗含"请确认子任务已全部完成并合并后再归档"。

### 验收标准

1. `delivering`：归档按钮 enabled，可打开"确认归档需求"弹窗。
2. `planning` / `cancelled` / `deferred` 等非 delivering：归档 disabled，title 为新 tooltip。
3. `delivered`：归档 disabled，title 为新 tooltip。
4. 归档确认弹窗包含"请确认子任务已全部完成并合并后再归档"提示；该提示不出现在取消/其它生命周期弹窗。
5. 确认后 dispatch 仍为 `{ command: "su-archive", payload: {} }`（与命令行 /ccb:su-archive 同 requirement-finalize 路径）。
6. `RequirementDetailPage.spec.tsx` 全绿；后端/DB/plugin 零改动。

### 边界 / 不做项

- 不投影 worktree 运行态进 DB；不加后端 dispatch 归档专用守卫；不改 kernel 两段式 archive 本体；不做 su-batch 自动 finalize。
- 不动 `node-board-config.ts`（仅命令描述文案，非门控）；不改其它含"归档"的 spec（Codex 已核实无"delivered 可归档"断言：RequirementsPage/ui-mapping 是分桶卡片动作、DocumentsPage 是文档档位、SlotsPage 是 slot 归档、app-redesign 是任务 archive 展示、e2e 仅 multitab 隔离）。
- finalize 安全完全由 plugin 既有两道关卡负责，本任务不削弱它们。

> 来源：技术设计 td-a654c0 全文（八·变更清单 + 五·测试策略）+ Codex 执行可行性协商 job_114fa6d8026f（spec fixture 翻转策略、提示条件化、验收增补）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-10 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq4tn9ub44963ca7baa654c0
- Section: pr1-archive-button-gate-fix
- Owner: ccb_codex
- Priority: high
- Dependencies: none

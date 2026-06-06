---
doc_type: dev_task
task_id: subtask-42f58c56b9cd
title: 全链路实机冒烟:6 源真实触发矩阵 + ack/sidebar/SSE 回归 + 浏览器侧人工验证清单
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpzoupdv863041443e52441f
section_id: pr5-e2e-live-smoke
order: 5
implementation_owner: ccb_codex
dependencies: [subtask-f16180b5ca9a]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpzoupdv863041443e52441f.json
source_draft_hash: db12930dd087b69323ede0b4e05130f3d45a5ba88574794f6e8df3d6994729f6
created_at: 2026-06-06T15:34:39.688Z
updated_at: 2026-06-06T18:05:43.081Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpzoupdv863041443e52441f","branch":"ccb/req-cmpzoupdv863041443e52441f"}
---

# 全链路实机冒烟:6 源真实触发矩阵 + ack/sidebar/SSE 回归 + 浏览器侧人工验证清单

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | rebuild+重启 server 实机:真实触发 review gate 等待/任务完成/agent_waiting(permission\|question)/failed/main 完成,验证 derive 正确、ack 闭环幂等、sidebar ⚠️ 出现与消失、debounce 不狂写、journal 对账收敛、task SSE 回归;浏览器通知部分产出人工验证清单。回执=场景×结果矩阵+日志证据。 |
| 需求来源 | cmpzoupdv863041443e52441f |
| 本期范围 | pr5-e2e-live-smoke · 全链路实机冒烟:6 源真实触发矩阵 + ack/sidebar/SSE 回归 + 浏览器侧人工验证清单 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
全需求验证收尾。本项目有实战教训:Console 运行态改动(watcher/scan/DB 并发)单测不够,cmpqlbcw 交付后实机暴露 3 个回归——本需求跨 provider 文件源、DB derive、web 通知、sidebar 写配置、journal 对账五个运行面,必须实机冒烟。依据技术设计 §五测试策略。

#### 任务分解
1. rebuild + 重启 server,盯启动日志(attention 路由注册、migration 应用、无扫描风暴)。
2. **真实触发矩阵**(每场景记录:触发动作 → GET attention 出现该 item(ref/kind/severity 正确)→ ack → 消失):① review gate 等待(沙盒需求推到待审,severity=attention);② 任务完成(codex_receipt_ready);③ agent_waiting:真实 slot 触发 permission 框与 AskUserQuestion 选项框(claude 侧必测;codex 侧按 pr1 smoke 结论);④ agent_failed(可控范围内模拟,如人为中断;不可行则记录跳过理由);⑤ main agent 完成(main 跑 >60s 任务转 idle → 一次 agent_completed;<60s 短对话不产生)。
3. **sidebar 联动**:②③ 场景验证 tips ⚠️ 出现 → ack 后消失;观察 managed-config 写入频次(content-hash guard 生效,无狂写)。
4. **journal 对账**:人为制造 hook 漏投(如临时拦截 POST)→ 水位落后 → reindex 触发一次后收敛;确认无循环 reindex。
5. **回归**:task 级 `/api/tasks/:taskId/events` SSE 正常;pending-interactions 既有端点正常;slot-tip 基础语义(无 attention 时)不变。
6. **DND/已读闭环**:设置 dndUntil → 全部抑制;到期恢复。
7. **浏览器侧人工验证清单**(自动化困难,产出文档供用户复核):权限请求弹出、通知弹窗与声音、点击 deep-link 落点正确、多标签只弹一个、权限拒绝降级 badge、DND 开关生效。

#### 验收标准
- [ ] 回执含场景×结果矩阵(每场景:触发证据、API 响应片段、日志行),全部通过或逐项标注偏差与处置。
- [ ] 发现的回归当场修复并复测,或升级为显式 issue(不得静默吞)。
- [ ] sidebar 写入频次证据(guard 生效);journal 对账触发与收敛日志。
- [ ] task SSE/pending-interactions/slot-tip 回归通过。
- [ ] 浏览器人工验证清单产出并随回执提交。

#### 边界 / 不做
- 不引入新功能代码;仅允许冒烟暴露问题的修复 commit(超出小修范围→升级 replan);不做性能压测;浏览器 UI 自动化不强求。

#### 依赖 / 执行注意
- 依赖 **pr1+pr2+pr3+pr4 全部合并**。在隔离环境 rebuild 后执行;勿在主仓跑 server test(db:prepare 清 dev.db);冒烟用沙盒需求/任务,勿污染真实 live 项目数据(本项目即 live 项目 cmq2ak0rr,场景①②⑤ 用专建沙盒需求承载)。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-f16180b5ca9a
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
- Section: pr5-e2e-live-smoke
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-f16180b5ca9a

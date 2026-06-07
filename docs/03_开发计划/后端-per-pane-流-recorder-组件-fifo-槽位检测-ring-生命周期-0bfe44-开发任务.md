---
doc_type: dev_task
task_id: subtask-c71bb70bfe44
title: 后端 per-pane 流 recorder 组件(FIFO+槽位检测+ring+生命周期)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3euisf1b2a90a0b3e057f6
section_id: pr2-recorder-registry
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3euisf1b2a90a0b3e057f6.json
source_draft_hash: 5b17e632c20263f23fee037170e920a8f175a0492e816e1f2a23ce07ae72134e
created_at: 2026-06-07T10:04:47.173Z
updated_at: 2026-06-07T11:58:16.169Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3euisf1b2a90a0b3e057f6","branch":"ccb/req-cmq3euisf1b2a90a0b3e057f6"}
---

# 后端 per-pane 流 recorder 组件(FIFO+槽位检测+ring+生命周期)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | pipe-pane→FIFO→chunk 流核心基建:registry/refcount、#{pane_pipe} 不抢占降级、UTF-8 安全、ring 补发、重启恢复;纯组件不接线 |
| 需求来源 | cmq3euisf1b2a90a0b3e057f6 |
| 本期范围 | pr2-recorder-registry · 后端 per-pane 流 recorder 组件(FIFO+槽位检测+ring+生命周期) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

后端 per-pane 流 recorder 组件(纯组件,不接线)。B-full-lite hybrid 核心新基建:pipe-pane→FIFO→chunk 流→多订阅 fanout,带槽位检测降级与生命周期管理。

### 任务分解

1. 新文件 `server/src/modules/slot-terminal/slot-terminal-stream-recorder.ts`:
   - per-pane 单例 registry + 引用计数(lazy 启动;末订阅者释放后 idle ~5min 关闭,常量可调);
   - FIFO:os.tmpdir 下 mkfifo,node 读端先 open 再 `pipe-pane -o 'cat > <fifo>'`(技设 D2:FIFO 数据不落盘);
   - 槽位检测:启动前查 `#{pane_pipe}`,被占(如 anchor-terminal 录制)→ 不抢占,降级态 + 周期重试(技设 D1);
   - chunk 处理:StringDecoder/Buffer 环处理 UTF-8 多字节跨 chunk 切割(禁止裸 chunk.toString(),协商风险项);
   - seq 计数 + ring buffer(~256KiB 常量):仅作订阅内 pause/resume 补发缓存(技设 D3);
   - 订阅 API:subscribe→cursor;pause/resume;超 ring 缺口→gap 信号(调用方触发 reset);
   - 重启恢复:启动序列先 pipe-pane off 再重开(技设 D8);pipe/FIFO 异常→错误事件+降级。
2. 单测:mock execFile + mock pipe source(借鉴 anchor-terminal ControlledPipeSource 模式);真 FIFO 仅小型生命周期/读写边界测试;不跑真 tmux。

### 验收标准

- 单测覆盖:槽位占用→降级→释放后重试升级;引用计数生命周期(双订阅/先后释放/idle 关闭);ring 补发边界(恰可补/超出→gap);UTF-8 多字节跨 chunk 断言;重启恢复序列;FIFO 读端异常。
- 不触碰 anchor-terminal/*、frame-stream.ts、ws.ts;tsc/lint 干净。

### 边界 / 不做项

不接 ws/pump(pr3);不改既有快照通道;不引新依赖(mkfifo 走 child_process,FIFO 读走 fs)。

> 派生自:技设 D1/D2/D3/D8 + 协商 finding 4 与 UTF-8 风险项。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq3euisf1b2a90a0b3e057f6
- Section: pr2-recorder-registry
- Owner: ccb_codex
- Priority: high
- Dependencies: none

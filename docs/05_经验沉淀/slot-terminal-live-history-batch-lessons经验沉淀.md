---
id: slot-terminal-live-history-batch-lessons
title: Slot Terminal Live History Batch 经验沉淀
doc_type: lessons
updated: 2026-06-07
---

# Slot Terminal Live History Batch 经验沉淀

> 需求 e057f6「需求详情里的终端/终端组件滚动问题」批量交付后的工程经验。本文只沉淀可复用教训,不替代需求文档、技术设计、commit log 或 review journal 作为验收真相源。最后更新: 2026-06-07。

## 背景

本需求把 slot terminal 从快照覆写模型扩展为「initial/reset 深快照 + pipe-pane stream + reconcile 兜底」的混合模型,目标是运行期持续累积最近约 2000 行历史,并保持和真实终端操作一致。

交付链包含:

| Commit | 内容 |
|---|---|
| `3be20cd2` | pr1 前端帧协议与渲染写入模型 |
| `9d83dc4d` | pr2 初版 recorder registry |
| `178babfa` | pr3 初版 WS stream 接线 |
| `7a356fdb` | pr3 fallback -> stream 升级 seam 修复 |
| `b54c86e5` | pr2 `#{pane_pipe}` 真实语义返工,引入 owner 标记 |
| `eb769b7e` | pr4 真 tmux 五断言与人工清单 |
| `356ef88e` | pr3 reconcile 升格 + pr4 断言 b 最终一致语义 |

journal 里本需求共有 7 次 passed review 与 3 次 request_changes 闭环。三次返工都由真环境验收或 review 环境亲跑触发,说明这类外部进程/终端/吞吐链路不能只靠 mock 和单机绿灯收口。

## L1 · mock 自证陷阱:外部工具语义必须先实机验证

### 教训本体

包裹外部 CLI、tmux format、系统管道、文件描述符等边界时,mock 的返回形状不能由实现者凭直觉编。必须先在真实工具上确认输入输出语义,再按真实形状写 mock。

本次 pr2 初版用 `#{pane_pipe}` 返回值是否包含 FIFO 前缀来判断「是不是自家 pipe」,mock 返回了 pipe 命令字符串,组件测试绿。但真 tmux 3.4 里 `#{pane_pipe}` 只返回 `0` 或 `1`,不包含命令内容,导致真实环境下自家遗留 pipe 永远不可识别。

### 实证细节

- 初版提交: `9d83dc4d`。
- 返工提交: `b54c86e5 e057f6/pr2-fix: use tmux pane owner marker`。
- review journal 记录:pr2 mock 自证被 pr4 真环境击穿;`#{pane_pipe}` 仅 0/1,不能用 `includes(FIFO_PREFIX)` 判定 owner。
- 返工后证据:tracked slot-terminal 49/49 通过;检测矩阵覆盖 `0` 空闲、`0+残留标记` 清理、`1+标记` 自家回收、`1+无标记` 外部降级。

实机语义应先用类似命令确认:

```bash
tmux display-message -p -t "$pane" '#{pane_pipe}'
# 输出: 0 或 1

tmux set-option -p -t "$pane" @slot_terminal_pipe /tmp/slot-terminal-demo/fifo
tmux display-message -p -t "$pane" '#{@slot_terminal_pipe}'
# 输出: /tmp/slot-terminal-demo/fifo
```

### 适用场景

- tmux、git、docker、ssh、sqlite CLI 等外部命令 wrapper。
- mock execFile/spawn/stdout/stderr 的单测。
- 外部工具 format variable、状态码、错误输出语义参与业务判断的代码。

### 复用指引

- 先实机,后 mock。把实机命令和关键输出写进测试注释或经验文档。
- mock 只模拟真实输出形状,不要模拟「希望工具返回什么」。
- 如果外部语义影响 owner、安全、恢复或降级路径,至少补一个真环境集成断言。

## L2 · 速度敏感断言必须在 review 环境亲跑

### 教训本体

时序、吞吐、竞态类集成测试在执行者机器上通过,只能说明该机器条件下通过。review 环境更慢或调度不同,可能稳定暴露丢包、反压、超时和 race。

本次 pr4 初始回执真 tmux 五断言 5/5,但 review 环境同 commit 下断言 b 三连挂:瞬时 2524 行洪峰里前 575 行丢失。执行机消费速度跟上,review 机稳定复现 tmux pipe 反压丢弃。FIFO 字节流仍连续,没有 gap 信号,因此原架构无法感知静默丢失。

### 实证细节

- 初始 pr4 提交: `eb769b7e`。
- review 发现:断言 b 在 review 环境 3 连挂,2524 行丢前 575 行。
- 修复提交: `356ef88e e057f6/pr3-fix2+pr4: add stream reconcile acceptance`。
- 返工后 evidence:ws.spec 31/31,slot-terminal 模块 56/56;真 tmux 五断言在 review 环境 5/5 x 3;全量 728/735,仅 rollup 2 个既有失败。

### 适用场景

- 大量 stdout/stderr、pipe、WebSocket、tail、file watcher、流式协议。
- 测试结果依赖时间窗口、缓冲区大小、读写速率或事件循环调度。
- “执行机绿,review/CI 挂”的问题可能来自真实吞吐差异,不应先假设回执不实。

### 复用指引

- 对吞吐/竞态断言设置 review 亲跑门槛,关键用例至少 3 连跑。
- 验收语义优先选「最终一致 + 自愈路径」,不要只断言峰值期间永不丢。
- 测试报告要写明机器范围:执行者机器绿不等于 review 环境绿。
- 对静默丢失风险,设计旁路校验或 reconcile,不要只依赖主数据流 gap。

## L3 · tmux pipe-pane owner 标记模式

### 教训本体

tmux pane 的 pipe 槽位是单一资源,`pipe-pane -o` 不会为多个组件提供自然共享。`#{pane_pipe}` 只能告诉你有没有 pipe,不能告诉你是谁占用。组件需要自己维护 owner 标记,才能同时满足「自家遗留可恢复」和「外部占用不抢占」。

本次最终模式:

1. 开 pipe 成功后写 pane 级 user option:`set-option -p @slot_terminal_pipe <fifoPath>`。
2. 检测时一次 `display-message` 读取双值:`#{pane_pipe}\t#{@slot_terminal_pipe}`。
3. `0` 表示槽位空闲:best-effort 清残留标记后正常开。
4. `1 + 标记非空` 表示自家遗留:先 `pipe-pane` off,再 `set-option -pu @slot_terminal_pipe`,再重开并重新 set 标记。
5. `1 + 标记空` 表示外部占用:不抢占,进入 snapshot-fallback 并周期重试。
6. 正常关闭必须按 `pipe-pane` off -> unset 标记顺序执行。

### 实证细节

- 技设 D8 批内实证修订:真 tmux 3.4 下 `#{pane_pipe}` 仅 0/1;pane 级 user option `set-option -p` 与 `#{@x}` 读回可用。
- 僵尸 pipe 不自愈:测试中 FIFO 读端死亡并让 pane 继续输出后,`pane_pipe` 仍为 1,不能依赖 SIGPIPE 或被动等待恢复槽位。
- 实现参照: `server/src/modules/slot-terminal/slot-terminal-stream-recorder.ts`。
- 修复提交: `b54c86e5`,修改 recorder 与 spec,新增/适配 owner 标记矩阵。

### 适用场景

- 多组件可能竞争同一 tmux pane pipe 槽位。
- 需要区分「自家上次崩溃遗留」与「其他功能正在使用」。
- READ_ONLY 语义允许管理面元数据,但不允许写 pane 输入、resize 或改显示。

### 复用指引

- owner 标记必须使用组件命名空间,如 `@slot_terminal_pipe`。
- 关闭顺序用 off -> unset,避免先清标记后留下不可识别的自家 pipe。
- 外部占用时只降级和重试,不要为恢复自己而抢占别人。
- 把僵尸 pipe 当主路径处理,不要把它归为罕见异常。

## L4 · 主 checkout 孤立未提交改动先判断是否来自并行工作

### 教训本体

多 agent 共享主 checkout 时,孤立的 `D`/`M` 状态不必然是事故、误删或构建产物污染。它可能是另一个 agent 刚开始的合法改动。默认 restore 会直接撤销别人的在途工作。

本次 e057f6 批尾 merge 排障期间,把并行需求 4d8dbf 的首步删除 `server/src/fs/git-worktree.ts` 误判为工作区损伤并 restore,实际撤销了对方操作。journal 已记录该 incident:并行 agent 需重做删除,问题已透明报告。

### 实证细节

- 事件来源:e057f6 batch authorization completed 的 incident disclosure。
- 现象:主 checkout 出现孤立 `D server/src/fs/git-worktree.ts`。
- 误判:按「工作区损伤」处理并 restore。
- 真相:这是并行 agent 的在途删除,不是本需求交付造成的损伤。

### 适用场景

- CCB 多 agent 同时使用主 checkout。
- merge/cleanup/finalize 前后看到非本需求文件的 `D`、`M`、未跟踪文件。
- canonical docs、submodule gitlink、workspace 模块同时存在并行写入。

### 复用指引

- 不确定归属的孤立变更先查 active requirement/agent,不要直接 restore。
- 能等就等一拍,或询问 owner;不能确认时在回执里报告风险。
- 规范实施仍应在各自 worktree 内完成,主 checkout 只做受控 merge/cleanup/finalize。
- 只对明确属于自己、且明确是错误的改动执行恢复。

## 复用检查表

| 场景 | 检查项 |
|---|---|
| 外部 CLI wrapper | 是否已用真实命令确认输出形状,并让 mock 严格匹配 |
| tmux pipe owner | 是否用 user option 标记 owner,并覆盖 `0` / `0+残留` / `1+标记` / `1+无标记` |
| 流式吞吐测试 | 是否在 review 环境 3 连跑,并覆盖慢消费或洪峰 |
| 静默丢失 | 是否有旁路 reconcile,而不是只依赖 gap |
| 主 checkout dirty | 是否先确认并行 agent 归属,再决定是否恢复 |

## 关联文档

| Type | Path |
|---|---|
| Requirement | `docs/02_需求设计/bug-需求详情里的终端-终端组件滚动问题-e057f6-需求.md` |
| Technical design | `docs/03_开发计划/bug-slot终端运行期历史持续累积-e057f6-技术设计.md` |
| pr2 task | `docs/03_开发计划/后端-per-pane-流-recorder-组件-fifo-槽位检测-ring-生命周期-0bfe44-开发任务.md` |
| pr3 task | `docs/03_开发计划/ws-pump-接线-stream-模式端到端-mock-集成-降级链-6c874a-开发任务.md` |
| pr4 task | `docs/03_开发计划/真-tmux-集成五断言-真浏览器人工验收清单-p2-837460-开发任务.md` |

## 变更记录

| 日期 | 新增 / 变更 |
|---|---|
| 2026-06-07 | 初版:沉淀 e057f6 batch 的 mock 自证、速度敏感验收、tmux owner 标记、主 checkout 并行改动四条经验 |

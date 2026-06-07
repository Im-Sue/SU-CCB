---
id: td-e057f6-slot-terminal-live-history
title: slot 终端运行期历史持续累积(B-full-lite hybrid) 技术设计
doc_type: technical_design
requirement_id: cmq3euisf1b2a90a0b3e057f6
subject: su-oriel
updated: 2026-06-07
---

# slot 终端运行期历史持续累积(B-full-lite hybrid) 技术设计

> 一句话:用 per-pane 单例 `pipe-pane` 原始流让 xterm 像真终端一样自然滚动累积运行期历史;快照通道(initial 深 capture + reset 重灌)保留做连接前历史与 reconcile 兜底;pipe 槽位被占/失败时优雅降级回现状快照模式。 ｜ 最后更新: 2026-06-07

## 一、设计概述

**目标**(锚定用户拍板 2026-06-07):
1. 一体化终端滚动:「直接滚动上下看,和在终端里的操作保持一致」——上滚可见的历史 = 连接前 tmux history 尾部(~2000 行)∪ 连接后运行期间全部滚出内容,连续无缝。
2. 历史窗口 ~2000 行「暂时够了」:scrollback 上限实现为可调常量,不写死。
3. 并入 P1:修复 `scrollback:1000` < initial 2000 的截断 bug。
4. 并入 P2:补 `06c62eb` 真浏览器验收欠账(验收清单首项)。

**非目标**:完整会话录制/回放(用户未要);改输入/粘贴语义;动 anchor-terminal 模块行为。

**核心选型反转记录**:初始 proposal 为 B-lite(`#{history_size}` 增量信号),被协商实验击穿——tmux `history-limit` 饱和后 `history_size`/`history_bytes` 双双冻结(隔离实验:limit=5 时输出 30+30 行,hs 钉死 5;双方独立复验一致),而饱和是长寿 agent pane 的**稳态**。运行期历史的唯一确定性来源是 pane 原始输出流。

## 二、方案与架构

```
tmux pane(真相源)
 ├─ [新] SlotTerminalStreamRecorder(per-pane 单例,lazy)
 │    pipe-pane -o 'cat > <FIFO>' → node 读 FIFO → chunk 流
 │    ├─ seq 计数 + ring buffer(仅作断线重连补发缓存)
 │    └─ fanout → 各 WS 连接 stream 帧 {kind:"stream", seq, data}
 ├─ [改] SlotTerminalFramePump(快照通道,降频保留)
 │    ├─ initial:capture -S -<DEPTH>(连接前历史,现状)
 │    └─ reset/reconcile:resize、流异常、缺口超 ring 时深快照重灌
 └─ display-message(尺寸,现状)

web FrameRenderer(写入模型)
 ├─ initial / reset 帧:terminal.reset() → 写深快照(灌 scrollback)
 ├─ stream 帧:terminal.write(data) 直写(自然滚动 → scrollback 真实累积)
 └─ 不再每帧 \x1b[H\x1b[2J 覆写(顺带消除全清重涂)
```

**被拒方案**:
- **B-lite(history_size 增量)**:核心信号被 history-limit 饱和击穿(上文);修补(饱和检测/visible 比对)会退化为不确定 diff 系统,失去确定性卖点。
- **E(快照启发式 diff)**:无确定性信号,TUI/进度条/wrap 误判产生历史污染;复杂度不低于本方案。
- **A(`scrollOnEraseInDisplay`)/F(独立历史视图)**:用户拍板派生排除(快照堆叠史不符「与终端一致」;要一体化滚动)。
- **B-full 纯流式(弃快照通道)**:连接前历史仍需 capture 兜底,且 reconcile 需要快照;混合是必要形态而非折衷。

## 三、关键决策与取舍

| # | 决策 | 取舍理由 |
|---|---|---|
| D1 | **pipe 槽位检测 + 优雅降级**:recorder 启动前查 `#{pane_pipe}`;被占(如 anchor-terminal 录制流,`terminal-manager.ts:347` 真实使用同一槽位空间)→ 不抢占,降级为现状快照模式,状态可见 + 定期重试 | anchor 录制与 slot 镜像同 pane 并发是低频场景;`pipe-pane -o` 冲突是静默失败,必须显式检测;共享 PipeOwner 基建留作后续演进,不在本需求动 anchor 已交付模块 |
| D2 | **FIFO 内存管道,不落盘**:`mkfifo` + node 读端先 open,再开 pipe-pane | 需求业务规则「历史仅 client 内存,不落盘」;anchor 的 `cat > file` 模式(其录制功能本职)不可照搬;FIFO 无新依赖 |
| D3 | **ring buffer 语义收窄 = 重连 seq 补发缓存**(非历史源) | 历史源 = initial 深 capture(连接前,tmux history 兜底)+ 连接后实时流;无 viewer 期间输出仍在 tmux history,下次连接 capture 可达 → 语义自洽,ring 只需覆盖 WS 短暂断线 |
| D4 | **渐进增强**:快照模式是 base(行为=今天),stream 是 enhancement;任何 stream 异常回退 base | 回归风险可控;降级路径天然存在 |
| D5 | **alt-screen 按真终端语义直通**:TUI 进出 alt buffer,不产生 scrollback 历史 | 与拍板「和终端一致」吻合;不是缺陷是语义 |
| D6 | **reset 用 `terminal.reset()` 全复位再重灌** | raw 直通会留下模式污染(mouse-tracking/bracketed paste/charset);重灌前必须清 |
| D7 | scrollback 常量 `SLOT_TERMINAL_SCROLLBACK = 2500`(≈2000 历史 + 屏 + 余量,单点可调) | P1 修复;「暂时够了」→ 加深只改常量 |
| D8 | recorder 生命周期:首 viewer lazy 启动,末 viewer 断开后 idle 延迟(~5min)关闭(pipe-pane off + unset 标记)。**所有权判定用 pane 级 user option**:开 pipe 成功后 `set-option -p @slot_terminal_pipe <fifoPath>`,正常关闭时 off+unset;槽位检测一次 display-message 读 `#{pane_pipe}` 与 `#{@slot_terminal_pipe}`——`1`+标记非空=自家遗留(off→unset→重开恢复),`1`+标记空=外部(D1 不抢占降级) | **批内实证修订(原「FIFO 读端死后 cat 阻塞自愈」不成立)**:真 tmux 3.4 下 `#{pane_pipe}` 只返回 0/1 不含命令内容,无法靠内容匹配识别自家 pipe;且读端死+pane 输出后 pane_pipe 实测仍=1(僵尸不自愈)。user option 实测可用(set -p/`#{@x}` 读回正常)。READ_ONLY 边界澄清:只读=不写 pane 输入/不 resize/不改显示;pipe-pane 与 `@slot_terminal_*` 命名空间的管理元数据操作属已接受的管理面 |

## 四、核心流程 / 逻辑

**连接(每 WS)**:
1. 解析 target→pane(现状);recorder 获取或创建(per-pane 注册表 + 引用计数)。
2. 查 `#{pane_pipe}`:占用→降级路径(纯快照,现状行为);空闲→mkfifo→node open read→`pipe-pane -o 'cat > fifo'`。
3. 发 initial 帧:**先开 pipe 并缓冲,initial capture `-S -<DEPTH>` 完成后再 flush 缓冲为 stream 帧**(顺序消除缺口;capture 与缓冲间毫秒级重复为验收容忍项,真终端 attach 同语义)。
4. 前端:initial → reset+写入;stream → 直写。

**运行期**:chunk → seq++ → ring 入环 → fanout 各连接。前端直写,xterm 自然滚动,scrollback 累积;用户上滚查看时新写入不拽视口(xterm 原生),贴底时沿用 `06c62eb` 双底部跟随判定。

**断线重连(v1 简化,协商定)**:现有 client 无重连机制——WS 断开即订阅终止,重连=全新连接走 initial 深快照(语义 = 真终端 re-attach,与拍板一致)。**不引入 client→server resume/lastSeq 协议**;ring 补发仅服务连接内 hidden→visible 恢复,cursor 为 server 侧 per-subscription 状态。帧 `seq` 保留为可选诊断字段,协议不依赖。

**reset 触发**:pane resize(cols/rows 变)、stream 错误、缺口不可补、**低频快照 reconcile 校验不一致(必须,batch 实证升格)** → reset 帧 → 前端 `terminal.reset()` + 深快照重灌(scrollback 重建为 tmux history 尾部)。

**reconcile 必要性实证(batch pr4 断言 b)**:高速洪峰(瞬时数千行)下 tmux pipe-pane 链路反压丢弃,FIFO 字节流保持连续 → **无任何 gap 信号,数据链层无法感知丢失**(实测 2524 行丢前 575 行且环境速度敏感)。低频 capture 旁路比对(尾行不一致 → `reset(reconcile)`)是唯一恢复路径,洪峰丢失收敛为秒级自愈;符合「和终端一致」体验承诺与用户「彻底修复不留债」原则。

**降级运行**:pipe 槽位占用/FIFO 失败/tmux 异常 → 纯快照模式(= 现状:initial + 150ms 覆写帧),周期重试升级;降级状态在帧元数据中可见(前端可提示「历史受限」)。

**可见性/活跃节流**:stream 帧不轮询故无 150ms/1s 节奏;hidden 时暂停 fanout(chunk 仍入 ring),visible 恢复:缺口 ∈ ring 补发,否则 reset。

## 五、测试策略

**单测(renderer)**:initial/stream/reset 三类帧状态机;stream 直写后 reset 不残留(短行、SGR、宽字符);mouse-tracking 序列直通后 wheel 仲裁仍可滚 scrollback;贴底/非贴底写入行为(上滚不拽回)。

**单测(recorder/pump)**:槽位占用检测分支;引用计数生命周期;ring 补发边界(恰好可补/超出);降级与重试状态机。

**集成(ws.spec,真 tmux)**:
1. 连接后输出 N 行 → 上滚断言 scrollback 含全部 N 行(运行期历史核心断言)。
2. 输出超过 scrollback cap → 尾部 2000 行与 tmux 末尾一致,最老行被挤出。
3. hidden→大量输出→visible:ring 内无缝补发;超 ring 走 reset,无重复无丢失。
4. `pipe-pane` 已被占(模拟 anchor 录制)→ 降级模式工作且状态可见;释放后重试升级。
5. server 重启 → pipe off/重建 → 流恢复。

**真浏览器验收清单(P2 欠账并入,实施完成门)**:滚轮连续回看连接前+连接后历史;claude/codex CLI 真实 TUI 场景观感;`06c62eb` host 外滚/双底部贴底回归;PageUp/触控入口检查(可访问性风险项)。

## 七、接口设计(WS 帧,内部协议,向后兼容)

现有帧(snapshot)字段不变;新增可选帧:
```
{ kind: "stream", seq?: number, data: string }      // seq 仅诊断,协议不依赖
{ kind: "reset", reason: "resize"|"gap"|"error"|"reconcile", ...snapshot 字段 }
帧元数据 + { mode: "stream"|"snapshot-fallback" }(降级可见性,Surface header 复用现有状态槽位提示,不碰仲裁)
```
旧帧无 kind = snapshot 语义;前端按 kind 分派。**无 client resume 协议**(v1 简化,见四章)。不动握手、输入、粘贴、READ_ONLY 契约。渲染调度注意:renderer 现行单 `pendingFrame` RAF 合批仅适用于 snapshot/reset;stream 帧必须有序直写(同 RAF 周期多 chunk 不丢不乱序)。

## 八、文件结构 / 变更清单

| 文件 | 动作 |
|---|---|
| `server/src/modules/slot-terminal/slot-terminal-stream-recorder.ts` | 新增:per-pane recorder(FIFO+pipe-pane+seq+ring+fanout+槽位检测+生命周期) |
| `server/src/modules/slot-terminal/slot-terminal.frame-stream.ts` | 改:pump 与 recorder 协作;快照通道降频为 initial/reset/降级 |
| `server/src/modules/slot-terminal/slot-terminal.ws.ts` | 改:帧类型分派、per-pane 共享接线、降级 mode 透传 |
| `web/src/lib/slot-terminal-ws.ts` | 改:stream/reset 帧 parse 与回调分派(协商补) |
| `web/src/components/slot-terminal/SlotTerminalFrameRenderer.ts` | 改:三类帧写入模型(去 live 全帧覆写) |
| `web/src/components/slot-terminal/useXtermTerminal.ts` | 改:`scrollback` 1000→常量 2500(P1) |
| 对应 spec 文件 | 扩:上述测试策略 |

不动:`anchor-terminal/*`、WS 握手/鉴权、`SlotTerminalSurface` 滚动仲裁(`06c62eb`)、粘贴/复制链路。

## 九、依赖与配置

- 新依赖:**无**(FIFO 用 `mkfifo` + node fs;不引 socat/node-pty)。
- 常量:`SLOT_TERMINAL_SCROLLBACK=2500`、`STREAM_RING_BYTES≈256KiB`、`RECORDER_IDLE_CLOSE_MS≈5min`、`HISTORY_DEPTH=2000`(initial capture,现状)。
- 环境:WSL2 FIFO 行为常规;tmux ≥ 项目现用版本(`pipe-pane -o`/`#{pane_pipe}` 均为老特性)。

## 十、迁移影响与风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| pipe 槽位与 anchor 录制并发冲突 | 中 | D1 检测+降级+重试;不抢占;后续演进共享 PipeOwner 基建 |
| FIFO 背压(node 读端死)| 低 | cat 阻塞只丢 pipe 数据不伤 pane;健康检查;重启恢复流程 D8 |
| pipe chunk 切断 UTF-8 多字节字符 | 中 | recorder 用 `StringDecoder`/Buffer 环处理,禁止裸 `chunk.toString()`(协商新增) |
| 自家崩溃遗留僵尸 pipe 挡 anchor(`pipe-pane -o` 静默不开) | 低 | 互不抢占原则下的共生边缘(anchor 的 file pipe 同款);自家侧靠 @标记重启回收;优雅关闭必 off+unset;写明现状不在本需求扩解 |
| raw 直通模式污染 xterm | 中 | D6 reset 全复位;mouse-tracking 不影响 capture-phase 仲裁(测试覆盖) |
| initial/流接缝毫秒级重叠或缺口 | 低 | 已知噪声,真终端 attach 同语义;reconcile 可校 |
| client-local 历史(各端连接时刻不同) | 低 | 语义如实呈现(与真终端 attach 一致);需「同一事实历史」时属后续录制档 |
| 多 surface 资源(每 pane FIFO+cat) | 低 | per-pane 单例共享多 viewer(优于现状 per-connection 双 capture);~10 pane 级 |
| `06c62eb` 滚动仲裁回归 | 中 | 仲裁代码不动;renderer 单测+真浏览器验收清单首项 |

**回滚**:渐进增强(D4)——禁用 recorder 即回现状快照模式,前端帧分派向后兼容。

## 变更记录

- 2026-06-07:初稿。协商:slot2_codex job_7536389cd155(B-lite 饱和反例击穿→方向反转 B-full-lite hybrid);槽位冲突为本侧新增约束(anchor `terminal-manager.ts:347` 核验)。
- 2026-06-07(batch 实施期 reconcile 升格,pr4 断言 b 实证):洪峰下 tmux pipe 反压丢弃且 FIFO 流连续无 gap 信号(静默丢失,实测丢 575/2524 行、环境速度敏感)→ 四章 reconcile 低频校验由「可选」升格「必须」,断言 b 语义改「经 reconcile 最终一致」。pr3 二次返工接线。
- 2026-06-07(batch 实施期 D8 实证修订,pr4 job_105adec31adb 发现+实机核验):真 tmux `#{pane_pipe}` 仅 0/1 无命令内容,内容匹配识别自家 pipe 不可行;僵尸 pipe 不自愈(读端死+输出后实测仍 1)。D8 改为 pane 级 `@slot_terminal_pipe` user option 所有权标记(实测可用);新增僵尸挡 anchor 边缘风险;READ_ONLY 边界澄清。pr2 据此返工。
- 2026-06-07(breakdown 协商 job_6a4e5c3c62e4 修正):①砍 client resume 协议(现有 client 无重连机制,断线=新 initial=真终端 re-attach 语义;ring 收窄为连接内 hidden 补发,server 侧 cursor);②seam 顺序定为「pipe 先开缓冲,capture 后 flush」消缺口;③新增 UTF-8 chunk 切割风险(StringDecoder);④渲染调度:stream 帧不得沿用 RAF 合批;⑤web client(`slot-terminal-ws.ts`)在变更清单内(帧 parse/分派)。

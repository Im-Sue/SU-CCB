---
id: ADR-0018-addendum-anchor-read-write-attach
title: ADR-0018 Addendum · Anchor Terminal Read-Write Attach
status: active
decided_at: 2026-05-16
parent_adr: ADR-0018
related_specs: [docs/.ccb/specs/active/2026-05-16-ta8b-read-write-attach.md]
impacted_components: [apps-ccb-console-server, apps-ccb-console-web]
---

# ADR-0018 Addendum: Anchor Terminal Read-Write Attach

## 1. 背景

TA6 read-only attach 和 TA8a viewport-only resize 已让用户能在 Console 内观看
anchor tmux pane 输出。Dogfood 后仍需要少量人工干预能力，例如向 anchor 内
Claude/Codex 输入 slash command、补上下文或发送 Ctrl-C。

## 2. 决策

anchor terminal 引入 read-write attach mode，但默认仍是 read-only。浏览器必须先
申请 writer lease，成功后才能发送 `in` / write-mode `resize` frame。

## 3. Writer Lease

writer lease 是 server 内存态，key 为 `<anchorId>:<pane>`。同一 pane 同时只允许
一个 writer，多 reader 可共存。`ccb_claude` 与 `ccb_codex` 是不同 pane，因此可各自
独立持有 writer。

server 重启或 WebSocket 断开会使 lease 自然失效，重连后默认回到 read-only。

## 4. 权限确认

后端沿用 anchor-terminal 的 local IP guard，不开放跨 origin 或远程 attach。前端在
申请 writer lease 前必须弹出二次确认，明确告知这等价于从浏览器向 anchor 内
Claude/Codex 发送 keystroke，并会写入审计 metadata。

## 5. 审计

服务端只记录 metadata，不存 raw keystroke。审计文件为
`data/anchor-terminal/audit/<anchorId>.jsonl`，按 `<anchorId>:<pane>:<clientId>` 聚合，
每 250ms 或约 8KB flush 一条：

- `anchorId`
- `pane`
- `clientId`
- `remoteAddr`
- `frame_count`
- `bytes`
- `sha256`
- `first_at`
- `last_at`

`sha256` 用于证明输入批次发生且内容可校验，不暴露 secret。

## 6. 录像

asciinema cast 继续只记录 output。input 不写入 cast，不参与 replay，以避免泄露凭据
或用户临时输入。

## 7. 安全边界

read-write attach 仍只是本地 Console 的 anchor 操作能力，边界与 CLI attach 一致。
本 addendum 不引入跨项目、跨用户、跨 origin 或公开网络访问能力。

## 8. 不做范围

- writer lease takeover / 强制夺权
- SSH-style read-only invite
- 跨 anchor 输入广播
- raw input storage
- input keystroke cast replay
- 修改 ccb-dual 上游

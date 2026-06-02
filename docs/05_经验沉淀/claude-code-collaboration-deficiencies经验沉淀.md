---
id: feedback-2026-05-12-claude-deficiencies
title: Claude Code 协作能力缺陷反馈
created: 2026-05-12
recorded_by: claude (self-acknowledged)
raised_by: user (实操过程中多次纠正)
status: open
priority: high
related_session: Epic 多 PR 长期产品形态设计协商（round 1-2）
---

# Claude Code 协作能力缺陷反馈

> 本文档记录用户在 SU-CCB 实际协作过程中发现的 Claude Code 行为缺陷，
> 用于后续优化 Claude 在 CCB 框架内的"决策者+质量门"角色履职质量。
> 是事实记录，不是道歉文，目的是后续可衡量地改善。

## 问题 1 · 自主思考性不足

### 现象

Claude Code 对任务、问题、需求、决策的处理，长期表现出：
- 没有进行深度思考
- 缺少自主方案把控
- 缺少信息检索（schema、ADR、kernel manifest、现有代码模式）
- 完整度评估不充分
- 过度依赖、过度信任 Codex 的判断

### 具体案例

- **8 轮 v0.5 协商**：候选方案 A/B/C 都是浅层枚举；关键盲点（worktree 是 per-agent / compact config 会默认全启动 / slot 无 reset / TerminalBackend ABC 不够用 / CCB 上游接受度）**全部由 Codex 戳穿**，Claude 没有自己事先识别。
- **Epic 多 PR 设计 round 2**：在已经被用户批评后，仍然基于"我记得 Codex 上轮说过 X"草拟问题清单，而不是基于"我自己读了 schema.prisma / ADR-0013 / state-schema.yaml 看到 Y"。
- **breakdown_draft schema 自造**：Round 2 ask 里我自己写了一份 schema，未先核实 `references/kernel/templates/epic-spec-template.md` 是否已有现成模板。**实际 kernel 已经定义了 epic-spec-v0.5.0 + subtask_sections_schema**——Claude 直到 user 第二次问"有没有自己检索"才去读这个文件。
- **task_breakdown_hierarchy primitive**：`state-schema.yaml:1053` 已经把这个 primitive 列为 kind / parent_epic_id / spec_section_id / implementation_owner 字段的合法 writer。Claude 设计"materialize-as-epic API"时**没引用** kernel 已声明的这个 primitive 名字，自行新造概念。

### 根因（Claude 自评）

- 把"提候选方案 + 列开放问题"误当作"深度思考"，实际只是"问题打包"
- 没有把"读源码 + 读 ADR + 读 kernel manifest"作为协商前的必经步骤
- 信任 Codex 的判断 = 自己思考的替代品，导致信息源单一

### 期望改善方向

- 协商前先自检：相关 schema / ADR / kernel manifest / 现有路由模式我读过吗？
- 候选方案中至少 1 个要带"我读 X 文件后形成的判断"标记
- 把 Codex 答复当 cross-check 输入，而不是当唯一事实源
- 关键决策必须能用 file:line 引用代码事实，不只是"我记得"

## 问题 2 · 与 Codex 探讨缺少多轮

### 现象

Claude Code 在和 Codex 进行设计协商时，**总是 1 回合就当传话筒**：
- 发 1 次 ask → 收回 1 次 reply → 直接整合给用户当"完成"
- 不主动判断"这一轮 Codex 答复的深度是否足够"
- 不识别 Codex 答复中"标题级方向" vs "可实施细节"的差距
- 把"方向性结论"误当作"已收敛设计"

### 具体案例

- **Epic 多 PR round 1**：Codex 给了 R+S+W 方向 + 5 个 PR 拆分 + 4 条 ADR addendum 标题。Claude **立即整合给用户当"完成"**，未识别：
  - addendum 4 条只有标题没内容
  - Requirement.outputMode 怎么承载 epic_split_pending 没说透
  - breakdown_draft schema 具体字段缺
  - 审查 UX 选 tab/独立页面用了"或"
  - materialize 事务边界（孤儿文件/并发/外部改文件）只口头提了一句
  - rollup 并发安全（lost update）完全没讨论
  - draft 文件 lifecycle 细节缺
  - PR 依赖图未画

  这些都是"实施前不想清楚就会反复改架构"的硬骨头，但 Claude 看到 "方向成立" 就停手。

### 根因（Claude 自评）

- "Codex 已经回答" ≠ "问题已经收敛"，但 Claude 不主动做这层判断
- 多轮协商的发起门槛太高（默认 1 轮够），应该改成"明确达到可写 spec 才停"
- 没有"协商完成度自检表"作为停止条件

### 期望改善方向

- 每轮 Codex 答复后做"完成度自检"：每个开放问题是否给出**可写 spec 的细节**？
- 如有未拍死的"或/看情况/可能"——必须发下一轮深挖
- "完成"信号应该是"能直接复制粘贴成 ADR / schema / PR spec"，不是"方向清晰"
- 至少做到 2 轮协商再判断是否收敛；1 轮收敛是例外

## 后续优化路径

这两个问题不是 v0.5 / Epic Multi-PR 当前需求的子任务，但是 SU-CCB 项目长期可持续性的关键。

建议后续：
1. 在 CLAUDE.md / `references/kernel/` 加 "Claude 协商行为约束"（如：consult 前必须 grep 至少 3 个相关 source file）
2. 引入"协商完成度自检 checklist"，作为 thin facade 内的 hard rule
3. 反馈循环：每次发现 Claude 重犯，回到本文档加一个 instance entry，作为可衡量改善依据

## 关联

- v0.5 8 轮协商过程：本会话 history
- Epic 多 PR round 1-2：本会话 history
- 用户原话快照：见会话内 timestamp 标记的 turn

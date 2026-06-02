# SU-CCB Roadmap

SU-CCB 的愿景是成为可审计、可复现、可分工的 AI 工程协作框架。

当前里程碑：**Wave 1A 进行中**。这一阶段优先补齐协议地基和对外入口，
让新贡献者能理解项目、跑通 quickstart，并看到后续演进方向。

路线图的方向锚点：

- [v0.4 node kernel northstar](docs/01_架构设计/ccb-plan/v0.4-node-kernel-northstar.md)
- [master roadmap gap analysis](docs/01_架构设计/ccb-plan/2026-05-02-master-roadmap-gap-analysis.md)
- [贡献指南](CONTRIBUTING.md)

## Wave 1A · 立即可启动

目标：建立协议一致性硬门槛、capability runtime 基础，以及开源项目基础入口。

当前进度：

- 主仓 README 已建立，包含一句话定位、架构图、核心价值和入口链接。
- Quickstart 已建立，覆盖 5-10 分钟自身文档修复流程。
- Legacy archive baseline 已建立，cutoff 后新 spec 执行 strict lint。
- Manifest strict lint 与 CI 前置已建立。
- Capability resolver、dual-run trace schema 和基础测试已建立。
- 社区基础设施正在补齐：贡献指南、行为准则、公开 roadmap、issue/PR 模板。

完成标准：

- 新贡献者能从 README 进入 quickstart。
- 新 spec 能通过严格 lint。
- 主仓具备最小开源协作入口。
- 协议地基改动有自动化 guard 和可追溯验证。

## Wave 1B · V1 补齐与 UI 基础

目标：补齐 console V1 自报完成但实际缺口仍在的部分，并为后续 V2 UI 打底。

计划方向：

- 设置能力补齐，让扫描策略和项目规则有明确入口。
- 命令入口和本地工作流继续与 console 视图靠拢。
- Requirement、Sync、Task 等主链路补测试覆盖。
- UI redesign 先做基础切片，避免在不稳定信息架构上做大规模重绘。

完成标准：

- Console V1 范围不再依赖口头说明。
- 关键链路有可重复测试。
- UI 基础层可支撑后续节点流转视图。

## Wave 2 · Event / Transition / Apply 三件套

目标：把 v0.4 协议能力从文档和 lint 推进到可调用、可审计、可投影的运行链路。

计划方向：

- 建立事件记录和投影契约。
- 建立 transition consumer wrapper。
- 建立 apply endpoint，让 console 和插件能通过受控入口触发关键原语。
- 迁移 `Task.phase` 的历史兼容路径，推动 node 字段成为真相源。
- 推进 ExecutorProfile，为多执行器配置提供稳定边界。
- 建立版本治理、安装指引和依赖矩阵。

完成标准：

- 状态变更有统一入口、幂等策略和审计记录。
- Console 可展示关键运行事实，而不依赖散落日志。
- 安装和版本组合可以被外部用户复现。

## Wave 3 · v0.4 v1 收口

目标：收敛公开心智模型，形成 v0.4 v1 可理解、可演示、可维护的闭环。

计划方向：

- 收敛到统一的 `/ccb:su-flow` 入口。
- 建立节点流转 projection 和协作可视化。
- 完成 UI redesign 的主要视图。
- 在 Wave 3 末移除 `Task.phase` GET derive 兼容层，公开视图改以 node 状态机为准。
- 把内部评估材料重组为公开定位、场景矩阵和证据摘要。
- 补齐品牌与视觉说明，但不提前承诺未稳定能力。

完成标准：

- 用户看到的是节点状态机，而不是散落脚本和内部提示。
- Console 能解释一条任务从需求到归档的关键事实。
- 对外材料与实际可运行能力一致。

## Wave 4 · Second-wave 与公开案例

目标：在 v0.4 v1 稳定后推进更强调度能力，并产出可复现的公开案例。

计划方向：

- ReactiveScheduler 作为 second-wave 能力接入事件契约。
- parallel_join subflow 进入模拟器和失败传播验证。
- 基于 SU-CCB 自身 dogfooding 整理公开案例。
- 让案例、安装文档、版本矩阵和 console 证据相互指向。

完成标准：

- second-wave 能力不破坏 v0.4 v1 的稳定边界。
- 外部用户能按文档复现至少一个真实协作案例。
- 案例材料能展示价值，也能展示限制。

## 贡献入口

如果你想参与：

1. 先跑 [Quickstart](docs/quickstart.md)。
2. 阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
3. 用 issue 模板提交问题、建议或复现证据。

路线图会随每个 wave 的完成情况更新。公开版只记录稳定方向和已验证进度；
未定设计和内部失败清单会保留在维护流程中，等形成可复现证据后再公开。

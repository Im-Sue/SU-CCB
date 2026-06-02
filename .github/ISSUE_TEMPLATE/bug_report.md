---
name: Bug report
about: 报告可复现的问题或回归
title: "[bug] "
labels: bug
---

## 问题概述

请用 1-2 句话说明发生了什么，以及你原本期望看到什么。

## 环境

- OS：
- Shell：
- Node 版本：
- pnpm 版本：
- Git commit：
- 运行方式（本地 / WSL / CI / 其他）：

## 重现步骤

1.
2.
3.

请尽量给出从干净工作树开始的最短命令序列。

## expected behavior

描述你期望的结果。

## Actual behavior

描述实际结果，包括错误信息、退出码或异常 UI 状态。

## evidence

请粘贴关键 log、截图路径、命令输出或失败测试名称。

```text
在这里粘贴最小必要输出
```

## 影响范围

- 影响模块：
- 是否阻塞当前任务：
- 是否有临时绕过方式：

## CCB 关联信息（可选）

- task_id：
- parent：
- wave：

## 验收提示

修复后建议至少提供：

- 复现命令从失败变为通过。
- 相关 lint / build / test 输出。
- 如涉及文档链接，提供 markdown-link-check 输出。

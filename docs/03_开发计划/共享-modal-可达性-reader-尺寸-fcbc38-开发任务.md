---
doc_type: dev_task
task_id: subtask-469791fcbc38
title: 共享 Modal 可达性 + reader 尺寸
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxs58o53dd491462f34a675
section_id: pr2-modal-a11y-reader
order: 2
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxs58o53dd491462f34a675.json
source_draft_hash: 4d33a31290f1bfc3d852f5bf18ae9dec4ec336c1b61ed23be1feb0a6b9be13c6
created_at: 2026-06-03T10:44:28.795Z
updated_at: 2026-06-03T13:57:01.753Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxs58o53dd491462f34a675","branch":"ccb/req-cmpxs58o53dd491462f34a675"}
---

# 共享 Modal 可达性 + reader 尺寸

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | Modal 补初始聚焦 / focus trap / 焦点恢复 + 新增 reader 尺寸，全局焦点行为修复，供两处阅读弹窗用。 |
| 需求来源 | cmpxs58o53dd491462f34a675 |
| 本期范围 | pr2-modal-a11y-reader · 共享 Modal 可达性 + reader 尺寸 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

### pr2 共享 Modal 可达性 + reader 尺寸

#### 任务概述
补齐共享 `Modal` 的键盘可达性（对齐现有 `DetailDrawer` 能力），并新增长文阅读尺寸，供详情页两处阅读弹窗使用。**这是对所有 Modal 使用方生效的全局焦点行为变更**（预期内的 a11y 修复）。

#### 任务分解
- `Modal.tsx`：打开时默认聚焦关闭按钮（不假设首个可聚焦是编辑器，规避 EasyMDE fullscreen）；focus trap（Tab / Shift+Tab 回环）；关闭后恢复 previousFocus；新增可选 `initialFocus` prop；新增 `reader`（近全屏、内容区可滚）size。
- `Modal.module.css`：新增 `reader` size 样式。
- 新增 `Modal.spec.tsx`。

#### 验收标准
- [ ] 初始聚焦落在关闭按钮 / dialog。
- [ ] focus trap 在弹窗内回环；关闭恢复触发前焦点。
- [ ] `reader` size 渲染正确、长内容可滚。
- [ ] 回归：编辑 / 确认 / 批量 / 解绑等既有 Modal 调用方在焦点行为变更后仍正常（跑 web Modal 相关全量测试）。

#### 边界 / 不做项
- 保留既有 sm/md/lg/xl 与 ESC / 遮罩关闭语义。
- 明确：本 PR 改变所有 Modal 的焦点行为（全局），非"零行为变更"，需覆盖回归。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-03 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpxs58o53dd491462f34a675
- Section: pr2-modal-a11y-reader
- Owner: claude
- Priority: high
- Dependencies: none

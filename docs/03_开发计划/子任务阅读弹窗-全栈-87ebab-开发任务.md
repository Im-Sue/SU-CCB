---
doc_type: dev_task
task_id: subtask-f613ae87ebab
title: 子任务阅读弹窗 — 全栈
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpy6tq9ub50045ca16560b82
section_id: pr1-subtask-doc-reader
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpy6tq9ub50045ca16560b82.json
source_draft_hash: 1cc16632ec4f9447249744de23f2d0e2663cc9d8577315adbf98e10a86060266
created_at: 2026-06-04T08:46:49.691Z
updated_at: 2026-06-04T10:09:52.568Z
updated_by: ai_session
code_workspace: {"path":"../SU-CCB-req-cmpy6tq9ub50045ca16560b82","branch":"ccb/req-cmpy6tq9ub50045ca16560b82"}
---

# 子任务阅读弹窗 — 全栈

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 需求详情页子任务点击改只读 reader 弹窗读 canonical dev_task md；后端新增项目级 body-only 端点（primaryDocumentId + taskKey 守卫 + 候选降级 + resolveProjectPath containment）；helper 抽中立 lib；前端复用 reader 状态机 + Modal，类型泛化 MarkdownReaderState（不并 design state）。 |
| 需求来源 | cmpy6tq9ub50045ca16560b82 |
| 本期范围 | pr1-subtask-doc-reader · 子任务阅读弹窗 — 全栈 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 子任务阅读弹窗 — 全栈

#### 任务概述
需求详情页（RequirementDetailPage）点击子任务，由「navigate(`/tasks/:id`) 跳转任务详情页」改为「打开只读 reader 弹窗，内联展示该子任务 canonical dev_task markdown 正文」。复用现有 Modal(size="reader") + MarkdownViewer + requirement reader 状态机基座；后端新增一个项目级 body-only 取文端点（按 canonical dev_task 解析）。全程 additive，不动任务详情页/其它入口。设计真相源：`docs/03_开发计划/需求详情里的子任务交互效果-560b82-技术设计.md`。

#### 任务分解

后端：
1. 共享 helper 抽中立 lib：
   - [NEW] `server/src/lib/markdown.ts` — 导出 `extractMarkdownBody`（从 requirement-edit.service.ts 提取）。
   - [NEW] `server/src/lib/project-path.ts` — 导出 `resolveProjectPath`（从 requirement-reindex.service.ts:564 提取，路径 containment 守卫）。
   - [MODIFY] `requirement-edit.service.ts` — `extractMarkdownBody` 改为从 `lib/markdown` re-export，**保持原导出名**（requirement.routes.spec.ts 仍从此处 import，re-export 不能破）。
   - [MODIFY] `requirement-reindex.service.ts` — `resolveProjectPath` 改为从 `lib/project-path` import，移除局部副本。
2. [NEW] `server/src/modules/task/task-markdown.service.ts` — `loadTaskMarkdownBody(prisma, projectId, taskId)` + `TaskMarkdownNotFoundError`：
   - `task = prisma.task.findFirst({ where:{ id:taskId, projectId }, include:{ project:true } })`；无 → 抛 NotFound。
   - canonical 候选列表：`primary = task.primaryDocumentId ? document.findFirst({ where:{ id:task.primaryDocumentId, projectId, kind:"dev_task", taskKey:task.taskKey } }) : null`；`fallback = document.findMany({ where:{ projectId, taskKey:task.taskKey, kind:"dev_task", NOT:{ id:{ in:已选 id } } }, orderBy:{ path:"asc" } })`。primary 在前。
   - 逐候选：`resolveProjectPath(task.project.localPath, doc.path)` 守卫（越界/绝对路径 → 跳过该候选）+ `readFile`；首个成功 → `return { path: doc.path, content: extractMarkdownBody(raw) }`（body-only）。
   - 所有候选失败（无候选 / 全部越界或 ENOENT）→ 抛 `TaskMarkdownNotFoundError`。
3. [MODIFY] `server/src/modules/task/task.routes.ts` — 注册 `GET /api/projects/:projectId/tasks/:taskId/markdown`：try `loadTaskMarkdownBody` → `200 { path, content }`；catch `TaskMarkdownNotFoundError` → `404 { message:"任务文档不存在或尚未进入索引" }`。

前端：
4. [MODIFY] `web/src/lib/console-api.ts` — 新增 `fetchTaskMarkdown(projectId, taskId): Promise<{ path, content }>`（GET `.../tasks/:taskId/markdown`，复用 RequirementMarkdownView 形态或等价类型）。
5. [MODIFY] `web/src/pages/requirements/RequirementDetailPage.tsx`：
   - 子任务按钮 onClick：`navigate(`/tasks/${task.id}`)` → `setSubtaskReader(task)`（按钮视觉/结构不变）。
   - 新增 state：`subtaskReader: TaskView|null`；`subtaskMarkdownState: MarkdownReaderState`；`subtaskMarkdownRequestSeqRef`。
   - effect([subtaskReader])：null → 重置 idle；否则 seq-ref 守卫下 `fetchTaskMarkdown(projectId, subtaskReader.id)` → loading/ready/empty/error；`ConsoleApiError.status===404` → not-found。迟到响应（关闭后或切到另一子任务）按 seq-ref 丢弃。
   - `renderTaskMarkdownContent(state)`：镜像 renderRequirementMarkdownContent，但：empty → 「任务文档正文为空」；not-found → 「任务文档不存在或尚未进入索引」；ready → `MarkdownViewer(state.content)`（**不做** rewriteRequirementAssetUrls 资产重写）。
   - `<Modal open={subtaskReader!==null} onClose={()=>setSubtaskReader(null)} size="reader" title={subtaskReader ? `任务文档 · ${subtaskReader.title}` : "任务文档"}>{renderTaskMarkdownContent(subtaskMarkdownState)}</Modal>`。
   - 类型改名：`RequirementMarkdownState` → `MarkdownReaderState`。**仅 AI requirement reader（aiMarkdownState）与本 subtask reader 共用此类型；技术设计 reader 的 `DesignDocumentState`（含 not-indexed/stale/documentId 等独有态）不动、不合并。**

#### 验收标准

行为：
- [ ] 点击子任务：**不发生路由跳转**（在 RequirementDetailPage.spec.tsx 的 renderPage 加 `/tasks/:taskId` 哨兵 route，点击后断言仍在需求页、任务页哨兵不出现），就地打开 reader 弹窗渲染该子任务 dev_task 正文。
- [ ] 快速点击 A→B：只显示 B 的内容（A 的迟到响应被 seq-ref 丢弃）。
- [ ] 404 → 弹窗内「任务文档不存在或尚未进入索引」；空 body → 「任务文档正文为空」；loading 态显示；ESC/遮罩关闭 + 焦点恢复正常。
- [ ] 任务详情页/其它入口、AI 解析/技术设计 reader 行为均不变。

后端单测（`task-markdown.service`，**独立于 route**）：
- [ ] primary 命中返回 body-only（去 frontmatter）。
- [ ] primary 脏指向同项目其它 taskKey → 不读它、降级 fallback。
- [ ] primary 文件 ENOENT → 降级 fallback。
- [ ] `doc.path` 越界（`../` / 绝对路径）→ 该候选判失败，不读盘。
- [ ] 无任何可读 dev_task 文档 → NotFound。
- [ ] body 空 → 返回空 content。

后端 route 测（`task.routes.spec.ts`，仅 200/404）：
- [ ] 200 `{ path, content }`；task 跨 project / 无可读文档 → 404。

回归（helper 抽取）：
- [ ] `requirement.routes.spec.ts` 仍从 requirement-edit.service.ts import `extractMarkdownBody`，re-export 后绿。
- [ ] `requirement-reindex.service.ts` 的既有设计路径/草稿路径测试绿（resolveProjectPath 抽取后）。

前端 mock 扇出（**必补**，否则无关 App 测试因缺 export 静态 import RequirementDetailPage 而炸）：
- [ ] 给以下手写 `vi.mock("../lib/console-api.js")` 的测试补 `fetchTaskMarkdown` mock：`RequirementDetailPage.spec.tsx`、`app-redesign.spec.tsx`、`e12-acceptance-snapshots.spec.tsx`、`task-detail-v2-acceptance.spec.tsx`。

验证命令（双栈 + tsc）：
- [ ] `cd su-oriel && pnpm --filter su-oriel-server test`（task/requirement 相关）+ `pnpm --filter su-oriel-server typecheck`。
- [ ] `cd su-oriel && pnpm dev:web` 对应 web 包 `test`（RequirementDetailPage/App 相关）+ web tsc/build。
- [ ] 实机冒烟：rebuild + 起 server/web，需求详情页点子任务 → 弹窗渲染 dev_task 正文、ESC/焦点、不跳转。

#### 边界 / 不做项
- 不动任务详情页 TaskDetailPage、`/tasks/:id` 路由及其它入口（看板/迭代/我的工作/活动流/命令面板）。
- **不合并**技术设计 reader 的 `DesignDocumentState`。
- 只读：不提供编辑/流转/工作区操作。
- 不消除 indexer/template-conformance 里 `extractMarkdownBody` 的其余复制（既有技术债，本任务只抽 requirement-edit 一处 + 新建中立 lib；如需收敛另开任务）。
- 不做相对图片资产解析（与现有 reader 同限制）。
- 无 schema 变更、无新依赖、无 migration。

#### 依赖
- 无外部/跨任务依赖。任务内顺序：先后端端点 + helper，再前端接线（同一交付单元内串行）。

#### 建议 owner
`ccb_codex`（全栈实施）。Claude 任务后审查。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-04 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpy6tq9ub50045ca16560b82
- Section: pr1-subtask-doc-reader
- Owner: ccb_codex
- Priority: high
- Dependencies: none

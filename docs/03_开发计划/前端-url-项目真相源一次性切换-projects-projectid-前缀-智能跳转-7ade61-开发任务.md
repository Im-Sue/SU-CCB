---
doc_type: dev_task
task_id: subtask-c0d7847ade61
title: 前端 URL 项目真相源一次性切换(/projects/:projectId/ 前缀+智能跳转)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3m1i8r5ac97ea38323ee06
section_id: pr4-url-scope
order: 4
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3m1i8r5ac97ea38323ee06.json
source_draft_hash: 8da0587b44c17898083802f051006f8365936b0aa2fb695bfce2da9b6bbbf5f8
created_at: 2026-06-07T14:08:11.026Z
updated_at: 2026-06-07T16:22:13.797Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3m1i8r5ac97ea38323ee06","branch":"ccb/req-cmq3m1i8r5ac97ea38323ee06"}
---

# 前端 URL 项目真相源一次性切换(/projects/:projectId/ 前缀+智能跳转)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 18 条路由迁前缀;ProjectScopeProvider 三态;store 降级只读投影+setter 封死;全部导航面(navigate/Link/href/pathname 判断/通知深链)改 path helper;旧链接智能跳转 |
| 需求来源 | cmq3m1i8r5ac97ea38323ee06 |
| 本期范围 | pr4-url-scope · 前端 URL 项目真相源一次性切换(/projects/:projectId/ 前缀+智能跳转) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

现在网址里没有「项目」概念,tab 的项目身份只存在页面内存里,刷新/轮询/fallback 都可能让它悄悄漂移。本切按技设 D1 做一次性切换:每个网址带 `/projects/:projectId/` 前缀,URL 成为项目身份唯一真相源,天然多 tab 安全。**L 体量单切是有意为之**:拆开会产生「路由带前缀而导航还是旧路径」的断链中间态。

### 任务分解

1. `App.tsx`:18 条路由全部迁入 `/projects/:projectId/` 前缀;新增 ProjectScopeProvider layout route——useParams 取 projectId 校验三态(存在→同步 store 渲染;不存在→显式「项目不存在」页;projects 未加载→等待后再判)。
2. `[NEW] web/src/lib/project-paths.ts`:path helper(全部路径构造单点收口)+ `useProjectScope()`(新代码唯一身份入口)。
3. `project-store.ts`:删 `projects[0]` 静默 fallback(:44-49);`selectProject` 删业务写路径改 navigate 语义;`selectedProjectId` 唯一写入者=URL 同步器——**setter 封死,允许并鼓励同切内新增小型 lint/单测固化该约束**(防回潮)。
4. 导航面全量改 helper(协商 finding 5 补全,作为回归清单):~30 处 `useNavigate`/`navigate(`;**`<Link to`/`href` 面包屑**;**`getPageTitle`/`renderGlobalAction` 的 pathname 判断逻辑**;**NotificationManager deep-link 生成**;**AnchorStartStrip 的 `/slots` 旧路径**;命令面板跳转;FAB。
5. 旧链接智能跳转(用户拍板):`/requirements/:id`、`/tasks/:id`、`/documents/:id` 按 id 查归属 projectId → redirect 到带前缀路径;查无归属或其他旧路径(`/overview` 等)→ 项目选择页;30s silentRefresh 只刷数据不再改变身份。
6. 测试面:**MemoryRouter 测试中的旧路由全部更新**;三态 Provider 单测;redirect 三类+查无单测。

### 验收标准

- 刷新/新开 tab 身份零漂移(URL 决定);双 tab 不同项目互不影响(手工冒烟,自动化归 pr7)。
- 旧书签三类 id 链接自动跳到正确项目;其余进项目选择页。
- 业务代码调用 `selectProject` 写身份 → lint/编译拦截。
- 全部 web 测试绿(含 MemoryRouter 路由更新);tsc/lint 干净。

### 边界 / 不做项

- 246 处 `selectedProjectId` 消费点**不强制全改**(过渡方案:store 是只读投影最终一致;新代码用 useProjectScope;渐进收敛不在本切)。
- 不动 server;不改 API 路径契约。

> 派生自:技设 D1/四章 + 用户拍板(多 tab 必须支持/智能跳转)+ 协商 finding 5(导航面补全)与 open_question 2 裁量(允许同切加 lint)。

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

- Requirement: cmq3m1i8r5ac97ea38323ee06
- Section: pr4-url-scope
- Owner: ccb_codex
- Priority: high
- Dependencies: none

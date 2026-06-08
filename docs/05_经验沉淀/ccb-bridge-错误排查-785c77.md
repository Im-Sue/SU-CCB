---
id: ccb-bridge-bugc-investigation-785c77
title: CCB bridge 错误排查报告
doc_type: lessons
updated: 2026-06-07
---

# CCB bridge 错误排查报告

> 关联任务: subtask-5ea230785c77 / pr5-bugc-investigation  
> 关联需求: cmq3m1i8r5ac97ea38323ee06  
> 结论类型: 报告型交付,不含生产代码改动

## 一、结论摘要

1. 本轮未做会改变 slot 拓扑的实机点击复现;需求 worktree 不是已绑定的 CCB runtime 根,无法在该目录直接执行 runtime reload 复现。
2. 代码链路可确证:前端「ccb bridge 拒绝了拓扑变更」只对应 `reload_rejected`,「ccb reload 执行失败」只对应 `reload_failed`。
3. resize 添加 slot 的服务端链路显式使用目标项目 `project.localPath` 执行 `ccb reload`,不走无参 `CcbdClientService()` 默认回落,因此不支持把 Bug C 直接归为 e9f09f Bug B 的同一代码根因。
4. 仍存在前端上下文误打项目的旁路风险:路由不带 projectId,`selectedProjectId` 可在刷新项目列表时 fallback 到 `projects[0]`;这可能导致用户以为在 CCB tab 操作,实际请求带了另一个 projectId。
5. 若现场 Network 确认请求 projectId 是 CCB 且仍报 bridge 错误,根因应落在 `ccb reload` 的运行态结果:blocked/reasons/diagnostics、输出协议、timeout 或 ccbd/socket 环境。
6. 本需求内应继续修 URL project scope 和日志可观测性;若实机日志证明是 `ccb reload`/bridge runtime 协议或状态 bug,建议另立运行时/ccbd 需求。

## 二、证据范围与限制

- 任务 worktree: `/home/sue/dev/SU-CCB-req-cmq3m1i8r5ac97ea38323ee06`,分支 `ccb/req-cmq3m1i8r5ac97ea38323ee06`,校验通过。
- 该 worktree 的 `su-oriel` 是未初始化子模块空目录;gitlink 指向 `ffec23df5c739c4306c4cea7ca2e7f9a0e12849a`。
- 主仓 `/home/sue/dev/SU-CCB/su-oriel` 当前 HEAD 正好是同一 commit `ffec23df5c739c4306c4cea7ca2e7f9a0e12849a`;以下 `su-oriel/...` 代码证据基于该同 commit 只读来源。
- 未执行真实「添加 slot」点击,因为它会写 `.ccb/ccb.config` 并发布拓扑;本报告按无法破坏性复现口径提供已排除路径和触发条件。

## 三、根因链

### 3.1 前端报错文案来源

- `su-oriel/web/src/pages/slots/SlotsPage.tsx:45-56` 定义 resize 失败 reason 到 toast 文案的映射:
  - `reload_rejected` => 「ccb bridge 拒绝了拓扑变更」
  - `reload_failed` => 「ccb reload 执行失败」
- `su-oriel/web/src/pages/slots/SlotsPage.tsx:298-310` 的添加 slot 入口调用 `resizeSlots(selectedProjectId,{ direction: "grow" })`,失败时展示 `describeResizeFailure(error,"grow")`。
- `su-oriel/web/src/lib/console-api.ts:641-654` 将 projectId 编码进 `POST /api/projects/:projectId/slots/resize`。

结论:用户说的「CCB bridge 错误」需要现场确认精确文案;如果是「ccb bridge 拒绝了拓扑变更」,后端 reason 是 `reload_rejected`;如果是「ccb reload 执行失败」,后端 reason 是 `reload_failed`。

### 3.2 服务端 resize 入口

- `su-oriel/server/src/modules/slot-binding/slot.routes.ts:148-164` 的 resize 路由显式读取 URL `:projectId`,调用 `slotResizeService.grow(projectId)` 或 `shrink(projectId)`,失败统一以 409 返回 reason。
- `su-oriel/server/src/modules/slot-resize/slot-resize.service.ts:125-172` 的 grow 链路:
  - 先按 projectId 查项目。
  - 写目标项目根目录下 managed config。
  - `runtime.isOnline(project.localPath)` 为 false 时走 `offline_desired`,不执行 reload。
  - 在线时执行 `this.reload({ projectRoot: project.localPath })`。
  - reload throw => `reload_failed`,并回滚 config。
  - reload 返回但不是 published/safe => `reload_rejected`,并回滚 config。
- `su-oriel/server/src/modules/slot-resize/slot-resize.service.ts:115-122` 默认 reload runner 是 `runCcbReload({ projectRoot })`;context resetter 也是 `new CcbdClientService({ projectRoot })`,不是无参构造。
- `su-oriel/server/src/modules/slot-resize/slot-resize.service.ts:531-567` 的默认 runtime `ping/projectView/queue` 均显式传 `projectRoot`。

结论:resize 链路属于「显式目标项目根」模式,与 e9f09f Bug B 中 default resetter 无参 `CcbdClientService()` 回落到 Console server 自身项目的根因不同。

### 3.3 reload_rejected 与 reload_failed 的分叉条件

- `su-oriel/server/src/modules/slot-resize/reload-cli.ts:41-48` 通过 `execFile("ccb",["reload"],{ cwd: options.projectRoot })` 执行 reload。
- `su-oriel/server/src/modules/slot-resize/reload-cli.ts:95-147` 解析 `reload_status`、`blocked/reload_blocked`、`reload_reason`、`reload_diagnostic` 等协议行。
- `su-oriel/server/src/modules/slot-resize/reload-cli.ts:150-167` 在无已知协议行或缺 status 时返回 `unable to parse ccb reload output`。
- `su-oriel/server/src/modules/slot-resize/reload-cli.ts:170-188` 的解析层 `ok` 要求 exitCode 为 0、无 blocked、status 为 `ok` 或 `published`。
- `su-oriel/server/src/modules/slot-resize/slot-resize.service.ts:488-490` 的 resize 发布判定更严:必须 `result.ok && result.status === "published" && safeToApply !== false`。

结论:

- `reload_rejected` 表示 reload 命令有结构化返回,但对在线 resize 来说未达到「published 且 safeToApply 不是 false」。常见触发条件是 bridge blocked、config drift、计划不安全、reload 只 dry-run/未发布或状态不是 published。
- `reload_failed` 表示 reload runner throw,或输出不可解析、timeout、命令不可用、ccbd/socket/环境异常等执行失败。

### 3.4 与双 tab 串扰的关系

- `su-oriel/web/src/App.tsx:714-792` 的业务路由不包含 projectId 前缀,例如 `/requirements/:requirementId`、`/anchors`。
- `su-oriel/web/src/stores/project-store.ts:44-49` 的 `resolveSelectedProjectId` 在当前 selectedProjectId 不存在时静默 fallback 到 `projects[0]`。
- `su-oriel/web/src/stores/project-store.ts:72-100` 的 `loadProjects` 和 `silentRefreshProjects` 都会调用该 fallback 并写回 `selectedProjectId`。

结论:双 tab 场景下仍可能发生「页面视觉/用户认知是 CCB,但 `selectedProjectId` 已漂移」,导致 resize API 打到非 CCB projectId。这条路径能解释误操作项目,但不能单独解释正确 CCB projectId 下的 `ccb reload` bridge 拒绝。

## 四、已排除、未排除与触发条件

### 已排除

1. 已排除「resize 直接使用无参 CcbdClientService 回落 CCB 根」:resize 代码和现有单测都显示 reload/projectView/context resetter 传入目标 `projectRoot`。
2. 已排除「resize API 是全局无 projectId 入口」:路由是 `/api/projects/:projectId/slots/resize`。
3. 已排除「当前 CCB 主仓 dry-run reload 基础协议不可解析」:`ccb reload --dry-run` 在 `/home/sue/dev/SU-CCB` 返回结构化协议行 `reload_status: ok`、`plan_class: no_change`。

### 未排除

1. 未排除现场 CCB 项目在真实添加 slot 时 `ccb reload` 返回 blocked 或非 published,触发 `reload_rejected`。
2. 未排除现场 `ccb reload` 在真实发布时 timeout、socket 异常、输出协议漂移或 stderr 异常,触发 `reload_failed`。
3. 未排除双 tab 下 `selectedProjectId` 漂移,使 CCB tab 的按钮请求实际带了 realtime_translator 或其他项目 projectId。
4. 未排除 `findBlockingQueueRows` 当前先全局查 `anchorDispatchQueue` 再反查项目的性能/隔离风险;但它主要影响 shrink 的尾部 slot 队列检查,不是 grow 添加 slot 的 reload bridge 主路径。

### 再触发条件

需要在运行中的 Console + 两个已 onboarding 项目 + 浏览器双 tab 下触发,并同时记录:

- Network 中 `POST /api/projects/<projectId>/slots/resize` 的 `<projectId>` 是否等于 CCB 项目 id。
- 响应 JSON 的 `reason`、`details`、`reload.status`、`reload.blocked`、`reload.reasons`、`reload.diagnostics`、`reload.rawStderr` 摘要。
- server 日志中对应 request 的 resize/reload 输出。
- CCB 项目根下 `ccb reload --dry-run` 的输出;只有确认安全后再由人工执行非 dry-run reload。

## 五、复现步骤建议

1. 启动 Console,确认 CCB 与 realtime_translator 两个项目都已出现在项目列表。
2. Tab A 选择 CCB 项目并进入 `/anchors`;Tab B 选择 realtime_translator 项目并进入需求详情页。
3. 在 Tab A 打开浏览器 DevTools Network,点击「添加 slot」。
4. 记录请求 URL 中的 projectId:
   - 若不是 CCB projectId,归入前端 URL/store 项目身份漂移问题,由本需求 pr4 修。
   - 若是 CCB projectId,继续看响应 reason。
5. 若 reason 是 `reload_rejected`,记录 response.reload 的 status/blocked/reasons/diagnostics,并对照 CCB 根目录 `ccb reload --dry-run` 输出判断是否 bridge 计划不安全或 blocked。
6. 若 reason 是 `reload_failed`,记录 details.error、stdout/stderr、server 日志,重点检查 ccb 命令、ccbd 进程、socket、timeout、输出协议是否异常。
7. 单 tab 只打开 CCB 重复第 3-6 步:
   - 单 tab 复现:优先运行态/bridge 问题。
   - 仅双 tab 复现:优先前端 projectId 漂移或跨 tab 刷新时序。

## 六、处置判断

- 归本需求修:
  - URL 编码 projectId,移除 `projects[0]` 静默 fallback,让 `/anchors` 等入口的项目身份来自 URL。
  - 在 resize API/server 日志和前端失败详情中暴露 `reload.status/blocked/reasons/diagnostics/errorMessage` 摘要,避免只剩「bridge 错误」。
- 另立需求:
  - 如果现场确认 projectId 正确且 `ccb reload` 返回 blocked/unsafe/协议不兼容,应归运行时/ccbd bridge reload 需求处理。
- 环境问题关闭:
  - 如果现场只是 ccbd 未启动、socket 不可用、项目未绑定 runtime、或 local CLI 不可用,且修复环境后无法复现,可按环境问题关闭 Bug C。

## 七、验证记录

| 命令 | 目录 | 结果 |
|------|------|------|
| `node .../ccb-execute-worktree.mjs validate-worktree --project-root /home/sue/dev/SU-CCB --spec .../ccb-bridge-错误-排查-报告型交付-785c77-开发任务.md --pretty` | `/home/sue/dev/SU-CCB` | 通过;codeRoot 为需求 worktree,分支匹配 |
| `git -C /home/sue/dev/SU-CCB-req-cmq3m1i8r5ac97ea38323ee06 ls-tree HEAD su-oriel` | `/home/sue/dev/SU-CCB` | gitlink 为 `ffec23df5c739c4306c4cea7ca2e7f9a0e12849a` |
| `git -C /home/sue/dev/SU-CCB/su-oriel rev-parse HEAD` | `/home/sue/dev/SU-CCB` | HEAD 同为 `ffec23df5c739c4306c4cea7ca2e7f9a0e12849a` |
| `pnpm exec vitest run src/modules/slot-resize/slot-resize.service.spec.ts src/modules/slot-resize/reload-cli.spec.ts --pool=forks --poolOptions.forks.singleFork` | `/home/sue/dev/SU-CCB/su-oriel/server` | 通过;2 files,16 tests |
| `pnpm exec vitest run src/pages/slots/SlotsPage.spec.tsx src/tests/console-api.spec.ts` | `/home/sue/dev/SU-CCB/su-oriel/web` | 通过;2 files,27 tests |
| `ccb reload --dry-run` | `/home/sue/dev/SU-CCB-req-cmq3m1i8r5ac97ea38323ee06` | 失败:`no .ccb anchor or workspace binding found`;说明需求 worktree 不是 runtime 复现根 |
| `ccb reload --dry-run` | `/home/sue/dev/SU-CCB` | 通过;`reload_status: ok`,`plan_class: no_change` |

补充:曾误用 `pnpm test -- <files>` 触发 server 大范围测试;目标 `slot-resize`/`reload-cli` 通过,但全量命令因无关 `requirement-status-rollup.spec.ts` 既有断言失败退出 1。已用精确 `pnpm exec vitest run` 重跑目标文件并通过。

## 变更记录

| 日期 | 新增 / 变更 |
|------|------------|
| 2026-06-07 | 初版:完成 Bug C 代码链路排查、无法破坏性复现说明、复现步骤与处置判断 |

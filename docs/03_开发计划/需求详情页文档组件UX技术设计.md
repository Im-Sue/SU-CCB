---
doc_type: technical_design
title: "需求详情页文档组件 UX 技术设计"
requirement_id: cmph5nd2va01cb8b41e07ae88
---

> 真相源：本文件为 plugin 独立产出的技术设计。需求决策已在分析阶段锁定并经用户拍板，本设计只确定「如何实现」，不重开已锁决策。

## 1. 目标与范围

把需求详情页「需求文档」卡片及其阅读/编辑弹窗、以及「技术设计」产物的「阅读设计」抽屉落到可实施设计。N1-N3 为纯前端 CSS/JSX；N4 为前端 + 复用一处既有只读 API（不新增后端端点）：

- N1 去冗余按钮、N2 去重复描述块、N3-a 编辑态滚动修复（P0）、N3-b 阅读态改渲染 Markdown。
- N4（2026-05-25 追加）「阅读设计」抽屉渲染设计文档正文（替代当前指针文本）。详见 §11。

**不做**：需求数据模型/字段、verbatim/description 存储、后端 API、新依赖、摘要块内联「展开全文」、MarkdownViewer 的全局行为变更（仅做 read 弹窗 scoped 增强，避免波及 AI 解析卡片 / 设计卡片等其他复用处）。

涉及文件：
- `apps/ccb-console/web/src/pages/requirements/RequirementDetailPage.tsx`
- `apps/ccb-console/web/src/pages/requirements/RequirementDetailPage.module.css`
- `apps/ccb-console/web/src/components/requirements/RequirementMarkdownEditor.tsx`（抽出共享的资产 URL rewrite）
- `apps/ccb-console/web/src/components/requirements/RequirementMarkdownEditor.module.css`
- 新增共享 util：`apps/ccb-console/web/src/components/requirements/requirementAssetUrl.ts`（建议名）

## 2. 分项设计

### N1 去冗余按钮
`RequirementDetailPage.tsx:678` 与 `:679` 的 onClick 都是 `setDocumentModal("read")`，完全等价。删除 `:678`「展开」Button，保留 `:679`「全屏阅读」；「编辑需求文档」按钮不动。

### N2 去重复描述块
删除 `RequirementDetailPage.tsx:690` 的 `requirement.verbatimSource` 段（`<p className={styles.verbatim}>…`），仅保留下方 `:691-693` 的 `summaryMarkdown` 块（`createExcerpt` 默认 220 字截断不变）。`.verbatim` 样式（`RequirementDetailPage.module.css:265`）经核仅此一处使用 → 一并删除，避免 dead CSS。`RequirementsPage` 的 `.verbatimBlock/.verbatimText` 是另一套，不受影响。需求文件原话永久保留，不动。

### N3-a 编辑态滚动（P0）
根因：高度/滚动约束放在外层 `.CodeMirror`（CodeMirror 默认 `overflow:hidden`），而真实滚动层是 `.CodeMirror-scroll`（默认 `overflow:scroll !important`），未被约束 → 内容裁剪且无滚动。

修复（`RequirementMarkdownEditor.module.css`）：
- `.editor :global(.CodeMirror){ height:auto; min-height:360px; }`（去掉 wrapper 上的 `max-height:60vh`）
- `.editor :global(.CodeMirror-scroll){ max-height:60vh; }`（限高落到真实滚动层，纵向滚动由其原生 overflow 承载）
- fullscreen 例外：`.editor :global(.CodeMirror-fullscreen) :global(.CodeMirror-scroll){ max-height:none; }`，避免全屏仍被 60vh 截断。

依据：EasyMDE 通过 JS 把 `minHeight:"360px"` 写到 scroller 元素（`RequirementMarkdownEditor.tsx:80`），与「限高落到 `.CodeMirror-scroll`」方向一致；side-by-side 默认不开（`tsx:111-113`），且联动 fullscreen，本次默认路径不命中其特殊高度。

### N3-b 阅读态渲染 Markdown
现状：read/edit 共用 Modal（`tsx:865-895`），内部 `:888-894` 渲染 `disabled` 的 `RequirementMarkdownEditor`，read 态实为只读 CodeMirror 源码视图。

改造：弹窗内容按 `documentModal` 分流——
- `edit` 态：继续 `RequirementMarkdownEditor`（disabled=false，value=editDraft）。
- `read` 态：改渲染 `<MarkdownViewer content={rewriteAssetUrls(descriptionMarkdown, selectedProjectId ?? "")} />`（完整内容，非摘要）。

read 态纵向滚动交给 `Modal.content`（`Modal.module.css:54-58` 已有 `max-height:calc(90vh-140px); overflow-y:auto`），无需额外 JS。

### N3-b 配套：资产图片 URL rewrite（必须，correctness）
`RequirementMarkdownEditor` 的 `previewRender`（`tsx:84-90`）会用 `rewriteAssetUrls`（`tsx:18-26`）把 `./assets/requirements/{reqId}/{file}` 重写为 `/api/projects/{projectId}/requirements/{reqId}/assets/{file}`。当前 read 态显示源码、图片不渲染，故问题不暴露；一旦改用 MarkdownViewer **真正渲染** `<img>`，相对路径会按当前页面 URL 解析而失效。

设计：把 `ASSET_RELATIVE_RE` + `rewriteAssetUrls` 从 `RequirementMarkdownEditor.tsx` 抽到共享 util `requirementAssetUrl.ts`，editor 的 `previewRender` 与详情页 read 渲染共用同一份逻辑，避免规则漂移（编辑器行为不变，只是改为 import）。

### N3-b 配套：read 弹窗横向溢出与残留错误
- `MarkdownViewer` 当前无 `img max-width` / 表格横向滚动 / 长词换行；`Modal.content` 只处理纵向溢出。为 read 弹窗内的 MarkdownViewer 包一层详情页 scoped class（或 read 专用 wrapper class），加：`img{max-width:100%;height:auto}`、表格容器 `overflow-x:auto`、长 URL/长词 `overflow-wrap:anywhere`。**scoped 到 read 弹窗**，不改全局 MarkdownViewer。
- `editError`（`tsx:887`）当前在 Modal children 顶层无条件渲染，保存失败→关闭→再开 read 会残留编辑错误。改为 `documentModal === "edit" && editError ? … : null`。

## 3. 复用回归面
`RequirementMarkdownEditor` 还被 `App.tsx`（需求创建/编辑入口）复用。N3-a 的 CSS 改 `.CodeMirror`/`.CodeMirror-scroll` 会同时作用于该入口——属预期（同样修好其滚动），但必须回归验证创建/编辑页编辑器高度、滚动、图片上传仍正常。资产 rewrite 抽取为纯重构、不改 editor 行为，回归风险低。

## 4. 风险
- **双层纵向滚动**：限高落到 `.CodeMirror-scroll` 后，编辑器内滚动与 Modal.content 滚动可能并存——编辑器类组件可接受的局部滚动，非缺陷。
- **资产 rewrite 漂移**：抽取为单一 util 即可消除「两处各写一份」的长期漂移风险。
- **side-by-side**：仅用户手动开启且联动 fullscreen，默认路径不命中；如未来改 `sideBySideFullscreen` 需另行匹配高度（本次不处理，列入不做项）。

## 5. 测试策略（验收口径）
- N1：「需求文档」区仅「全屏阅读」一个阅读入口，「编辑需求文档」保留。
- N2：仅显示下方摘要块（≤220 字）；上方原话块消失；需求文件原话不变。
- N3-a：编辑态超长内容可滚到底、滚动条在编辑器内；切 fullscreen 不被 60vh 限制。
- N3-b：「全屏阅读」渲染 Markdown（标题/列表/代码/图片格式正确），超长可在弹窗内滚到底；含 `./assets/...` 上传图片能正常显示（URL 已 rewrite）；横向不溢出；空描述显示「暂无描述。」。
- 残留错误：保存失败→关闭→再开 read 不显示旧的 editError。
- 回归：`App.tsx` 需求创建/编辑入口编辑器高度/滚动/图片上传正常；`RequirementMarkdownEditor.spec.tsx` 仍通过。

## 6. AI 自决 vs 用户授权
- **用户已授权（分析阶段拍板）**：删页面原话块（N2）、阅读弹窗升级为渲染 Markdown（N3-b）。
- **AI 自决（低影响实现细节，本设计新增）**：资产 URL rewrite 复用、read 弹窗 scoped 溢出 CSS、`editError` 仅 edit 显示、CSS 限高层级与 fullscreen 例外。均为「让已授权决策正确落地」的实现细节，无 schema/API/依赖/成本/合规命中，无需新增用户拍板（Codex 同此判断）。

## 7. Codex 设计协商摘要（job_d638f2bf2951）
Codex 同意 N1/N2 与 N3-a 主方向（确认 EasyMDE 把 minHeight 写到 scroller、`.CodeMirror-scroll overflow:scroll`、fullscreen 例外可行）。补两处我漏掉的盲点：① **资产图片 URL rewrite**——MarkdownViewer 无 editor 的 rewrite，read 渲染会让上传图片相对路径失效（最关键）；② MarkdownViewer 无 img/表格/长词溢出处理，xl Modal 内可能横向溢出；并指出 `editError` 跨 read/edit 残留。推荐 Option B（原方案 + rewrite 复用 + scoped 溢出 CSS + editError 仅 edit）。我已核实源码（`RequirementMarkdownEditor.tsx:18-26/84-90`、`:887`）确认两处成立，采纳 B。

## 8. 四锚点反思
- **我同意的**：资产 URL rewrite 是真盲点且属 correctness，不补会让用户「看到渲染后的图却裂图」；抽共享 util 比两处复制更稳。
- **我不同意/收窄的**：Codex Option C（全局增强 MarkdownViewer）被我收窄为 read 弹窗 scoped——AI 解析卡片/设计卡片（`tsx:992/996`）也用 MarkdownViewer，全局改会扩大影响面、超出本需求范围。
- **我的盲点**：只盯着「换组件 + 滚动」，漏了换组件后图片渲染路径和横向溢出这类「渲染真正生效后才暴露」的问题，以及 editError 的跨态残留。
- **接下来**：设计已完整、决策已锁、无新增用户必问 → 自动进入 task_breakdown（按文件/关注点切分为：N1+N2 详情页清理、N3-a 编辑器 CSS、N3-b read 渲染+rewrite 抽取+scoped CSS+editError），各子任务自带回归验收点。

## 9. sc 说明
- `/sc:analyze`：以**直接通读全部相关源码**替代（RequirementDetailPage / RequirementMarkdownEditor / MarkdownViewer / Modal 及各自 CSS），获得比通用扫描更精确的 ground truth，已覆盖现有代码影响分析视角。
- `/sc:design`、`/sc:research`：不命中——无新系统架构、无选型/调研需求（纯既有组件的 CSS/JSX 局部修复）。
- `/sc:business-panel`：不命中——无成本/合规/业务权衡，用户权利项已在分析阶段处理。

## 10. 下一节点
设计完成（N1-N4 全覆盖）、无 TBD、无新增用户必问、Codex 共识达成。流转 `task_breakdown`，把五项工作（N1+N2 详情页清理、N3-a 编辑器 CSS、N3-b read 渲染+rewrite 抽取、N4 阅读设计抽屉读取正文、共享 `stripFrontmatter` helper 抽取）落为子任务 breakdown draft（`docs/.ccb/drafts/breakdown/cmph5nd2va01cb8b41e07ae88.json`）。

## 11. N4 阅读设计抽屉渲染正文（2026-05-25 追加）

### 现状
「阅读设计」按钮（`RequirementDetailPage.tsx:724`）打开 `DetailDrawer`（`:995-997`），抽屉渲染 `buildDesignMarkdown(requirement)`（`:104-109`）——只是「已生成文档：<planDocPath>…仅提供产物索引和快速入口」的**指针文本**。对比「阅读解读」抽屉渲染 `buildAiMarkdown`（requirement 投影字段，正文）。N4 要让设计抽屉显示设计文档**正文**。

### 数据链路（已核验）
- `planDocPath` 由 indexer 直接写为某 Document 的 path（`project-indexer.ts:1204` `planDocPath: doc.path`）→ 与 `useProjectStore.documents` 列表里的 `document.path` **同源**，`documents.find(d => d.path === planDocPath)` 可靠命中。
- 读正文复用既有 `fetchDocumentDetail(documentId)`（`console-api.ts:246` → `GET /api/documents/:documentId` → 返回 `DocumentDetailView.content`）。
- 渲染复用 `MarkdownViewer` + `stripFrontmatter`。

### 设计
1. **path→documentId 解析**：详情页用 `useProjectStore.documents` 做 `find`，比对时轻量 normalize（trim、去开头 `./`、反斜杠转 `/`，**不折叠大小写**——Linux 路径大小写敏感）。命中得 `documentId`。
2. **读取与状态——用局部 fetch，不复用全局 detail-store**：`detail-store` 的 `documentDetail` 是与 `DocumentsPage` 共享的全局单例、且 `loadDocumentDetail` 无错误态（`detail-store.ts:23-31`），直接复用会「闪现上一份文档」且吞错误（Codex job_1166abcbf933 标的风险）。改用详情页局部状态（`designDoc/designDocLoading/designDocError`）直接调 `fetchDocumentDetail`，按 documentId 守护、抽屉关闭时清理、防 race（关闭或 id 变更后丢弃迟到响应）。
3. **渲染**：抽屉内 `<MarkdownViewer content={stripFrontmatter(designDoc.content)} />`。
4. **`stripFrontmatter` 抽共享 helper**：当前是 `DocumentsPage.tsx:238` 私有函数，抽到共享（如 `lib/markdown.ts`），`DocumentsPage` 与详情页同源引用，避免复制漂移（Codex）。
5. **横向溢出兜底**：`DetailDrawer .body` 仅 `overflow-y:auto`（`DetailDrawer.module.css:55-62`）；设计文档更长更宽，复用 N3-b 同批 scoped 兜底（`img{max-width:100%}`、表格 `overflow-x:auto`、长词 `overflow-wrap:anywhere`），scoped 到设计抽屉的 MarkdownViewer。

### fallback（按状态分支，Codex 补全）
- 索引未命中（`find` 失败）/ 索引 stale：抽屉显示「设计文档尚未被索引，请在文档中心扫描后重试」+ 保留 `planDocPath` 文本。
- `fetchDocumentDetail` 404 / 读文件失败：显示「读取设计文档失败」+ 路径 + 重试入口。
- 加载中：骨架 /「加载中」。
- 正文为空：显示「文档为空」。

### 范围边界（重推、非锚定）
前端为主 + 复用既有只读 `GET /api/documents/:documentId`；**不新增后端端点、不改 schema/字段/存储、不加依赖**。不顺带统一「阅读解读」（投影字段）与「阅读设计」（文件正文）——性质不同，统一另开需求（Codex）。

### 测试 / 验收
- 「阅读设计」抽屉显示设计文档**正文**（标题/列表/代码/表格/图片格式正确），长文可在抽屉内纵向滚到底、横向不溢出。
- planDocPath 命中既有索引文档时正常渲染；未索引 / 404 / 空 / 加载中各 fallback 正确，不闪现上一份文档（局部状态 + id 守护）。
- 回归：`DocumentsPage` 改用共享 `stripFrontmatter` 后阅读正常；「阅读解读」抽屉不受影响（仍渲染投影字段）。

### Codex 协商与自决
- N4 设计经 job_1166abcbf933 协商（覆盖 path normalize、fallback 覆盖面、stripFrontmatter 抽取、横向溢出、detail-store 异步态与 stale-flash 风险、不统一阅读解读）。本设计落实其全部建议。
- **未开第二轮**：上述协商已覆盖 N4 设计维度，且 ground truth 已核验（indexer:1204、detail-store 形态、抽屉 CSS）；唯一 fork「局部 fetch vs 全局 store」属低影响实现细节，按 Codex 标的 stale-flash 风险自决为局部 fetch。再开一轮无新增信息（避免为讨论而讨论）。
- 必问扫描：N4 无 schema/API/依赖/成本/合规命中（复用既有只读接口）。产品取向「内嵌正文 vs 跳转文档中心」用户已（以「继续推进」）确认为内嵌。

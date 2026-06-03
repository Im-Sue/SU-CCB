---
doc_type: module_spec
title: "SU-Oriel 文档中心模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 文档中心模块规格

## 1. 模块目标

文档中心模块把被观测项目的 Markdown 文档索引为可搜索、可分组、可阅读的投影视图。它强调“文档是真相源”，SU-Oriel 提供目录、档位、解析状态、治理信息和正文阅读，不在文档中心直接编辑正文。

真实实现锚点：

- `su-oriel/server/src/modules/document/document.routes.ts`
- `su-oriel/server/src/indexer/document-parser.ts`
- `su-oriel/server/src/indexer/document-governance.ts`
- `su-oriel/server/src/indexer/docs-structure-resolver.ts`
- `su-oriel/server/src/indexer/default-docs-structure-contract.yaml`
- `su-oriel/server/prisma/schema.prisma`
- `su-oriel/web/src/pages/documents/DocumentsPage.tsx`
- `su-oriel/web/src/lib/document-browser-projection.ts`
- `su-oriel/web/src/components/shared/MarkdownViewer.tsx`
- `su-oriel/web/src/lib/markdown.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 文档列表 | `GET /api/projects/:projectId/documents` 返回项目下全部文档投影，按 kind 与更新时间排序。 |
| 文档治理 | 列表响应附带 governance，包括档位、归档判断、解析异常和与实体状态的关系。 |
| 文档详情 | `GET /api/documents/:documentId` 读取项目本地文件内容，返回 frontmatter 与正文。 |
| 搜索筛选 | 前端按标题、路径和治理档位筛选。 |
| 目录分组 | `document-browser-projection.ts` 按目录组织左侧导航组。 |
| Markdown 阅读 | `MarkdownViewer` 渲染去除 frontmatter 后的正文，并保留元数据展开区。 |
| 空项目处理 | 文档列表为空时返回 `items: []`，不把空项目当作 404。 |

## 3. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `DocumentsPage` | 左侧目录与筛选，右侧 Markdown 阅读器；URL 参数驱动当前文档详情。 |
| `document-browser-projection.ts` | 将文档按目录分组，并提供浏览器投影。 |
| `MarkdownViewer` | 渲染 Markdown 内容。 |
| `Badge` / `ui-mapping` | 展示文档类型与状态标签。 |
| `project-store` / `detail-store` | 缓存文档列表和文档详情。 |

## 4. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `Document` | `projectId`、`taskKey`、`path`、`kind`、`title`、`status`、`frontmatterJson`、`summary`、`contentHash`、`mtime`、`parseStatus`、`parseError` | 文档索引投影；`projectId + path` 唯一。 |
| `Requirement` | `id`、`status` | 文档治理规则会读取需求状态上下文。 |
| docs structure resolver | doc type、目录、模板、状态规则、machine layer path | 文档类型、档位和目录解析来源。 |

## 5. 接口边界

文档中心是只读模块。详情接口从 `Project.localPath + Document.path` 读取文件；若文件被外部删除或移动，下一次扫描前可能出现列表存在但详情读取失败的短暂不一致。

文档类型、目录和 machine layer 规则来自 docs structure resolver。解析优先级是显式 `CCB_DOCS_STRUCTURE_CONTRACT`、项目本地 `docs/.ccb/docs-structure-contract.yaml`、SU-Oriel 内置 fallback。

## 6. 旧规格 vs 实际偏差

旧规格描述为“类型筛选、目录树、正文阅读”的概念文档，未覆盖 governance、档位筛选、URL 驱动详情、frontmatter 展示和 docs structure resolver。真实实现也不是三栏 `DocumentTree/DocumentList/DocumentReader` 组件拆分，而是 `DocumentsPage` 内的导航面板与阅读面板。

## 7. v1.0 校正点

- 文档中心读取的是项目根下的真实文档，不读取旧 monorepo 固定路径。
- `docs/.ccb/index/document-map.json` 是 machine layer 索引缓存；文档中心展示以 Prisma `Document` 投影和本地文件内容为准。
- 文档中心不负责正文编辑；需求正文编辑属于需求入口模块。

## 8. 待定事项

- 文档详情文件缺失时是否需要专门的“索引过期”恢复 UI 仍未单独实现。
- governance 标签的产品命名是否需要进一步统一，当前按实现输出展示。

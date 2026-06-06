---
doc_type: dev_task
task_id: subtask-783b6fe2f1fd
title: lib 候选发现接口升级(detectArchitectureCandidates)+ 测试全向量
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: high
requirement_id: cmq23elzh081b0a36b7726299
section_id: pr1-lib-candidates
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq23elzh081b0a36b7726299.json
source_draft_hash: 8add95651043c40293f36ec706b1a665b1a49224a347aa24d037d06a90ca79de
created_at: 2026-06-06T12:19:20.972Z
code_workspace: {"path":"../SU-CCB-req-cmq23elzh081b0a36b7726299","branch":"ccb/req-cmq23elzh081b0a36b7726299"}
---

# lib 候选发现接口升级(detectArchitectureCandidates)+ 测试全向量

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 删旧单数 gate,新复数候选发现 12 步算法(壳归并/aggregator/submodule 排除/置信度/disposition/existing/cap/mode);initProjectScaffold+init.mjs stdout 同步;双跑 bit-identical 测试。 |
| 需求来源 | cmq23elzh081b0a36b7726299 |
| 本期范围 | pr1-lib-candidates · lib 候选发现接口升级(detectArchitectureCandidates)+ 测试全向量 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
把 `lib/su-init/index.mjs` 旧单数 gate `detectArchitectureCandidate` 替换为复数候选发现 `detectArchitectureCandidates`(技术设计 §四 0-12 步算法);`initProjectScaffold` 挂 `summary.architectureCandidates`;init.mjs stdout 同步;测试全向量重写。零新增运行时依赖。

#### 关键枚举(spec 自包含,实现以此为准,与设计文档冲突时升级)
- 返回模型:`{ mode: "single"|"layered"|"overview_only"|"skip", reason: null|"no_source"|"architecture_exists", candidates[], overviewTargetPath, overviewExisting, excluded[], scopeConflicts[], existingArchitectureDocs, capLimit: 8 }`
- candidate:`{ id, path, kind: "source_root"|"submodule", disposition: "generate"|"list_only", confidence: "high"|"medium", evidence: string[], targetPath, existing: bool }`;excluded 条目 `{ path, reason: "framework_shell_merged"|"root_aggregator"|"nested_absorbed" }`
- evidence label:`marker:<file>`、`workspace_member`、`entry:<相对路径>`、`run_script:<name>`、`deploy:<file>`、`git_submodule`
- 硬运行证据(→high):package.json scripts.start|dev|serve、bin/main 字段、Dockerfile、docker-compose.yml 服务、pyproject `[project.scripts]`、入口源文件 main.go|src/main.rs|main.py|manage.py|app.py|src/index.{js,ts,mjs};仅 marker/workspace_member 无入口→medium(workspace member 不抬置信度)
- disposition:high→generate;medium 与 submodule→list_only;cap 按 generate 计(submodule/list_only 不占)
- 壳归并表初版(壳目录+宿主证据对,宿主证据不存在不归并):src-tauri/Cargo.toml + 根 tauri.conf.json 或根 package.json 依赖含 @tauri-apps → 归并;android/build.gradle 或 ios/ + 根依赖 react-native|expo|capacitor → 归并;壳 path 并入宿主 scope_source_roots
- workspace 解析 MVP 语法(零依赖,超出范围按不识别处理并记 warning):package.json workspaces 数组形式与 {packages:[...]} 对象形式;pnpm-workspace.yaml 仅 packages 列表的 `- "glob"` 行级解析;Cargo.toml [workspace] members 数组;go.work use 块。glob 仅支持尾部 /* 单层展开;`!` 否定模式忽略+warning;成员目录必须存在且含 marker 才成候选
- 判定顺序:①docs/01_架构设计/ 非模板 md 任一缺 architecture_scope → 整体 skip(architecture_exists) 最优先;②.gitmodules 路径从 marker 扫描整体排除(防重复枚举);③root 声明 workspaces → 默认 aggregator 排除(记 excluded),但有硬运行证据(Dockerfile/入口源文件,scripts.start 不算)→ 纳入 id="root";④嵌套吸收:祖先候选吸收子孙 marker 目录,显式 workspace member 除外
- existing 匹配:scoped 已有文档按 scope_source_roots ∩ 候选 path;scope=overview → overviewExisting=true
- 排序规则:目录遍历/glob 展开/evidence/candidates 全部字典序;同 fixture 双跑 JSON 深比较必须相等(bit-identical)
- slug:路径小写、非字母数字→`-`、去首尾 `-`;根候选 id="root";targetPath 全局唯一断言,冲突附 sha256(path) 前 6 位后缀(deterministic)
- 命名:子架构 `<subsystem-slug>-架构.md`,总架构 `<project-slug>-总架构.md`,均落 docs/01_架构设计/
- mode 推导:0 候选→skip(no_source);generatable==1→single;2..8→layered;>8→overview_only(全转 list_only);generatable==0 且候选>0→overview_only

#### 任务分解
1. 抽公共 helper(frontmatter 行级解析 / 排序遍历 / slug / .gitmodules 解析)
2. 候选发现主算法(上述判定顺序 0-12 步)
3. initProjectScaffold 挂新字段;删旧单数导出
4. skills/su-init/scripts/init.mjs stdout 字段更名 architectureCandidates
5. __tests__ 重写全向量 fixtures(先 fixtures 后断言,控制复杂度)

#### 验收标准
- node --test 全过,向量覆盖:空项目→skip/no_source;单 marker+入口→single 候选 root;frontend+backend 双入口→layered;pnpm workspace(apps/* generate、packages/* list_only、root aggregator 排除);root-app(workspaces+Dockerfile)→root 纳入;Tauri 形状(根 pyproject+main.py + src-tauri+tauri.conf.json)→壳归并 single+excluded 记录;src-tauri 无宿主证据→不归并 2 候选;9 个 generatable→overview_only;.gitmodules→submodule 候选且其内部 marker 不重复枚举;已有无 scope md→整体 skip 优先于一切;scoped md 部分覆盖→对应 existing 其余 generate;overview 已存在→overviewExisting;slug 冲突→deterministic 后缀;目录乱序创建 fixture 双跑深比较相等;`!` 否定模式忽略+warning
- grep lib/su-init、skills/su-init/scripts 无旧 detectArchitectureCandidate 单数残留(SKILL.md 残留由 pr3 清理)
- 无新增 package 依赖;既有三步脚手架测试不回归

#### 边界
- 不改 SKILL.md(pr3)、不改契约/模板(pr2)、不碰 Console/indexer 代码

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq23elzh081b0a36b7726299
- Section: pr1-lib-candidates
- Owner: ccb_codex
- Priority: high
- Dependencies: none

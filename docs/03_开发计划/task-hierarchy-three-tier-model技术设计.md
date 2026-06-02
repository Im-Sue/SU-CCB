---
doc_type: technical_design
title: "CCB 任务模型三层重构技术设计"
---

# CCB 任务模型三层重构 — 技术设计 (R2 修订版)

## 0. 文档范围与 R2 修复说明

本文档对应 spec `2026-05-09-task-hierarchy-three-tier-model.md` 的 technical_design 节点产出。

R2 review (`job_d4442f312a91`) 评分 4.75/10，E2 (3) E4 (4) fail。本版修复全部 17 个 issue + 用户拍板 D8 (Requirement 独立表) / D9 (epic_replan 走 lifecycle) / D10 (Epic spec 嵌 subtask sections) / D11 (UI/UX 实施由 Claude)。

## 1. Kernel Schema Diff (R2 修复版)

### 1.1 state-schema.yaml 增量

```yaml
enums:
  task_kind:                                 # NEW
    description: Task 表内的角色（不含 requirement，Requirement 由独立表承载，详 D8）
    values: [epic, subtask]                  # ← R2 修：移除 requirement

  epic_status:                                # NEW
    values: [planning, delivering, delivered, cancelled]

  requirement_status:                         # NEW，独立 Requirement 表使用
    values: [draft, analyzed, delivering, delivered, deferred, cancelled]

# task_state 字段扩展
task_state:
  kind:                                       # NEW，必填，default=subtask
    type: enum
    enum_ref: task_kind
    invariants:                               # R3 修：解 blocker 1，移除 XOR
      - kind=epic ⇒ current_node IS NULL
      - kind=epic ⇒ requirement_id IS NOT NULL
      - kind=epic ⇒ parent_epic_id IS NULL
      - kind=subtask ⇒ current_node IN 7-node-set OR completed
      - kind=subtask ⇒ requirement_id IS NOT NULL                 # 必填：直接 link
      - kind=subtask AND parent_epic_id IS NOT NULL ⇒
          Task[parent_epic_id].requirement_id == this.requirement_id   # 一致性而非 XOR
      - applicable_kinds(current_node) MUST contain kind
      - kind=subtask ⇒ epic_status IS NULL                        # R3 补：subtask 不能有 epicStatus
      - kind=epic ⇒ epic_status IN ('planning','delivering','delivered','cancelled')

  parent_epic_id:                             # NEW，FK → Task.id (kind=epic)
                                              # nullable: epic 模式 subtask 必有；direct_pr 模式 subtask 无
  # requirement_id 复用现有字段，subtask 必填（不再 XOR）
  spec_section_id:                            # NEW R3：D10 spec 内 section 索引
  implementation_owner:                       # NEW R3：D11 'claude' or 'ccb_codex'

  epic_status:                                # NEW，仅 kind=epic 使用，nullable for subtask
    enum_ref: epic_status

  legacy_kind:                                # NEW，迁移可逆
  legacy_parent_hint:                         # NEW，启发式分类证据
  migration_batch_id:                         # NEW，R2 补：审计字段
  migration_rule_id:                          # NEW，R2 补
  migration_confidence:                       # NEW，R2 补：0-1
  migration_reviewed_by:                      # NEW，R2 补
  migration_reviewed_at:                      # NEW，R2 补
```

### 1.2 node-manifest-schema.yaml 增量

```yaml
node:
  applicable_kinds:                           # NEW
    type: array<task_kind>
    default: [subtask]                        # ← R2 修：默认收紧为 [subtask]，老 manifest 显式声明
```

7 节点全部声明 `applicable_kinds: [subtask]`。CAS 写入时增加 invariant check：`applicable_kinds(task.currentNode) MUST contain task.kind`。

### 1.3 新 lifecycle manifest（独立于 7 节点）

`references/kernel/lifecycles/epic_lifecycle.yaml`
```yaml
schema_version: lifecycle-v0.1
lifecycle_id: epic
status_enum_ref: epic_status
applicable_to:
  table: Task
  kind_filter: epic

transitions:
  - id: epic__on_first_subtask_dispatched__planning_to_delivering
    from: planning
    to: delivering
    trigger_event: subtask_dispatched
  - id: epic__on_all_subtasks_archived__delivering_to_delivered
    from: delivering
    to: delivered
    trigger_event: subtask_archived
    guard: all_child_subtasks_archived
  - id: epic__on_subtask_review_fail__delivering_to_planning
    from: delivering
    to: planning
    trigger_event: epic_replan_requested
  - id: epic__on_user_cancel__any_to_cancelled
    from: [planning, delivering]
    to: cancelled
    trigger_event: user_cancel

handlers:                                     # R2 新增 (D9)，R3 加强幂等
  - id: handler__epic_replan
    triggered_by: epic__on_subtask_review_fail__delivering_to_planning
    action: epic.subtask_create
    capability_id: epic.subtask_create
    idempotency_key: '${event.failed_review_intent_id}'   # R3 补：防重复处理同 fail intent
    guard_refs:
      - source_subtask_belongs_to_target_epic              # R3 补：source_subtask.parentEpicId == target_epic.id
      - epic_replan_not_already_processed                  # R3 补：依据 idempotency_key 去重
    inputs:
      epic_id: <epic.id>
      replan_reason: <event.reason>
      failed_subtask_id: <event.source_subtask_id>
      failed_review_intent_id: <event.failed_review_intent_id>
    output:
      new_subtask_id: <task.id>
    notes: 不重走 task_breakdown 节点，直接由 lifecycle handler 调 primitive 产新 SubTask；幂等
```

`references/kernel/lifecycles/requirement_lifecycle.yaml`
```yaml
schema_version: lifecycle-v0.1
lifecycle_id: requirement
status_enum_ref: requirement_status
applicable_to:
  table: Requirement                          # ← R2 修：独立表 (D8)

transitions:
  - id: req__on_analysis_done__draft_to_analyzed
  - id: req__on_first_epic_delivering__analyzed_to_delivering
  - id: req__on_all_epics_delivered__delivering_to_delivered
    guard: all_child_epics_delivered
  - id: req__on_user_defer__any_to_deferred
  - id: req__on_user_cancel__any_to_cancelled
```

### 1.4 task_breakdown.node.yaml 增量 (R2 修复 D10/E4)

```yaml
fixed_actions:
  steps:
    # context flag，不污染 task_kind enum (R2 修：移除 epic_seed 概念)
    - step_id: detect_planning_mode
      capability_id: state.read_write
      output: context.planning_mode  # 'epic' | 'direct_pr'，由 requirement_analysis 节点产出

    # epic 模式：先产 Epic
    - step_id: create_epic_when_needed
      capability_id: epic.create
      when: 'context.planning_mode == "epic"'
      must_produce:
        - produced.epic.id
        - produced.epic.requirement_id
        - produced.epic.linked_spec_id        # 指向本 epic spec
      side_effects:
        - emit_event: epic_created

    # 拆分 subtask 批次（R2 修：显式消费 produced.epic.id）
    - step_id: create_subtask_batch
      capability_id: epic.subtask_create
      when: 'produced.epic.id != null OR context.planning_mode == "direct_pr"'
      must_produce:
        - subtask_batch.subtask_ids
        - each_subtask.parent_epic_id == produced.epic.id      # epic 模式
        - each_subtask.requirement_id == produced.epic.requirement_id  # epic 模式继承
        - each_subtask.linked_spec_id == produced.epic.linked_spec_id  # D10 共享 epic spec
        - each_subtask.spec_section_id != null                 # D10 指向 epic spec 内 section
        - each_subtask.current_node == "dispatch"              # D4 跳过 plan 三节点
      side_effects:
        - emit_event: subtask_created
        - emit_event: subtask_planning_inherited               # R2 补：审计 transition
          payload:
            from_epic_id: <produced.epic.id>
            from_node: task_breakdown
            inherit_artifacts: [spec, plan]
```

`subtask_planning_inherited` 是 synthetic event，写入 EventJournal 留审计：SubTask 没走 plan 三节点，但来源 transition 可追溯。

### 1.5 transition-table.md 增量

```
# Epic lifecycle (不在 7 节点内)
epic__on_first_subtask_dispatched__planning_to_delivering   guard: epic.lifecycle/has_dispatched_child
epic__on_all_subtasks_archived__delivering_to_delivered     guard: all_child_subtasks_archived
epic__on_subtask_review_fail__delivering_to_planning        guard: subtask.review_fail emit epic_replan_requested
                                                            handler: epic_lifecycle/handler__epic_replan
epic__on_user_cancel__planning_to_cancelled
epic__on_user_cancel__delivering_to_cancelled

# Requirement lifecycle (Requirement 表)
req__on_analysis_done__draft_to_analyzed
req__on_first_epic_delivering__analyzed_to_delivering
req__on_all_epics_delivered__delivering_to_delivered
req__on_user_defer__any_to_deferred
req__on_user_cancel__any_to_cancelled

# Audit transition (R2 新增，写 EventJournal 不实改 task state)
audit_event__subtask_planning_inherited                     emit_only
```

### 1.6 capabilities/global.yaml 增量

```yaml
- capability_id: epic.create
  required_for: [task_breakdown]
  criticality: blocking
- capability_id: epic.subtask_create
  required_for: [task_breakdown, epic_lifecycle/handler__epic_replan]   # R2 修：lifecycle 也需要
  criticality: blocking
- capability_id: epic.aggregate_progress
  required_for: [aggregate_hook]
  criticality: warn_only
- capability_id: requirement.publish
  required_for: [requirement_analysis]
  criticality: blocking
- capability_id: applicable_kinds_check       # R2 新增
  required_for: [persist]
  criticality: blocking
```

### 1.7 guard-registry.md 增量

```
- id: kind_node_consistency_guard
  invariant: applicable_kinds(task.current_node) MUST contain task.kind  # R2 加强
  scope: pre_persist
- id: parent_existence_guard (with kind check)
  invariant:
    - kind=subtask AND parent_epic_id != null ⇒ Task[parent_epic_id].kind == 'epic'
    - kind=epic ⇒ Requirement[requirement_id] EXISTS AND same_project
  scope: pre_persist (via SQLite trigger + app invariant test)            # R2 修：跨行验证
- id: all_child_subtasks_archived
- id: all_child_epics_delivered                                            # R2 新增 for requirement lifecycle
```

## 2. Console DB Migration (R2 修复版)

### 2.1 Prisma migration

```prisma
model Task {
  // 现有字段保留
  kind               String     @default("subtask")
  parentEpicId       String?
  // requirementId 已存在，subtask 必填（R3 修：移除 XOR）
  epicStatus         String?    // 仅 kind=epic 使用，subtask=NULL
  specSectionId      String?    // R3 新增 (D10)：epic spec 内 section 索引
  implementationOwner String?   // R3 新增 (D11)：'claude' or 'ccb_codex'
  legacyKind         String?
  legacyParentHint   String?
  migrationBatchId   String?
  migrationRuleId    String?
  migrationConfidence Float?
  migrationReviewedBy String?
  migrationReviewedAt DateTime?

  parentEpic         Task?      @relation("EpicSubtasks", fields: [parentEpicId], references: [id])
  childSubtasks      Task[]     @relation("EpicSubtasks")
  requirement        Requirement @relation(fields: [requirementId], references: [id])  // subtask 必填
}

model Requirement {
  status             String     @default("draft")
  // 现有 generatedTaskId 保留
}

// R3 新增：projection outbox table（解 blocker 4）
model ProjectionOutbox {
  id              String   @id @default(cuid())
  taskId          String
  revision        Int
  idempotencyKey  String   @unique  // = taskId + ':' + revision
  status          String   @default("pending")  // pending|projected|failed
  retryCount      Int      @default(0)
  lastError       String?
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  @@index([status, createdAt])
}
```

DB CHECK constraints (R3 重写，解 blocker 1+2):
```sql
-- kind 与 currentNode 一致性
ALTER TABLE Task ADD CONSTRAINT chk_kind_node_consistency CHECK (
  (kind = 'epic' AND currentNode IS NULL AND requirementId IS NOT NULL AND parentEpicId IS NULL
       AND epicStatus IN ('planning','delivering','delivered','cancelled'))
  OR (kind = 'subtask' AND currentNode IS NOT NULL AND requirementId IS NOT NULL
       AND epicStatus IS NULL)
);

-- requirement.status enum CHECK (R3 新增)
ALTER TABLE Requirement ADD CONSTRAINT chk_requirement_status CHECK (
  status IN ('draft','analyzed','delivering','delivered','deferred','cancelled')
);
```

跨行验证 SQLite TRIGGERs (R3 完整版，解 blocker 2):
```sql
-- INSERT: parentEpicId 指向 kind=epic + same project
CREATE TRIGGER trg_subtask_insert_parent_check
BEFORE INSERT ON Task
FOR EACH ROW
WHEN NEW.kind = 'subtask' AND NEW.parentEpicId IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'parentEpicId must point to kind=epic in same project + matching requirementId')
  WHERE NOT EXISTS (
    SELECT 1 FROM Task
    WHERE id = NEW.parentEpicId
      AND kind = 'epic'
      AND projectId = NEW.projectId
      AND requirementId = NEW.requirementId  -- R3 解 blocker 1：一致性
  );
END;

-- UPDATE: parentEpicId / kind / requirementId 任一改变都要重验
CREATE TRIGGER trg_subtask_update_parent_check
BEFORE UPDATE OF parentEpicId, kind, requirementId ON Task
FOR EACH ROW
WHEN NEW.kind = 'subtask' AND NEW.parentEpicId IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'subtask parent invariant violation')
  WHERE NOT EXISTS (
    SELECT 1 FROM Task
    WHERE id = NEW.parentEpicId AND kind = 'epic'
      AND projectId = NEW.projectId AND requirementId = NEW.requirementId
  );
END;

-- epic.requirementId 同 project (R3 新增)
CREATE TRIGGER trg_epic_requirement_same_project
BEFORE INSERT ON Task
FOR EACH ROW
WHEN NEW.kind = 'epic' AND NEW.requirementId IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'epic.requirementId must be in same project')
  WHERE NOT EXISTS (
    SELECT 1 FROM Requirement WHERE id = NEW.requirementId AND projectId = NEW.projectId
  );
END;
```

应用层 invariant test（vitest）兜底每个写路径，UPDATE / DELETE / INSERT 全覆盖。

### 2.2 启发式迁移算法 (R2 加强版)

```
classify(task):
  audit = { batchId, taskKey, hits: [] }

  # Epic 信号
  if spec frontmatter task.kind == 'epic' OR parent == 'ccb-master-roadmap-...':
    audit.hits += 'spec_explicit_or_roadmap_child'
    return (kind=epic, confidence=0.99, audit)

  if task.taskKey matches keyword: redesign|epic|initiative|consolidation|three-tier|master-roadmap:
    audit.hits += 'keyword_epic'
    return (kind=epic, confidence=0.95, audit)

  # SubTask 信号 (R2 加强：补 e14/e15/slice/t-pattern)
  if task.taskKey matches:
    /-pr\d+(-\d+)?-/                    # PR 系列
    /-(e|ka|ga|ca|d)\d+-t\d+/           # E14-T1, KA-2, etc
    /-slice-?\d+/                       # slice 1, slice-2
    /-(fix|hotfix|patch)-/              # fix/hotfix
    /-(rfc|spec|adr)-/                  # 单独 RFC/spec/ADR (这些可能是 subtask)
    audit.hits += 'pattern_<matched>'
    return (kind=subtask, confidence=0.93, audit)

  # 父 epic 候选（同 prefix epic 任务存在）
  if 同前缀 epic candidate exists in already-classified set:
    audit.hits += 'shared_prefix:<epic_taskKey>'
    return (kind=subtask, parentEpicId=candidate.id, confidence=0.85, audit)

  # Requirement 候选（已属 Requirement 表的）→ 不进 Task 重写
  # 实际所有 164 task.requirementId=null，所以无 requirement 类候选

  # 边界 case
  audit.hits += 'undecided'
  return (kind=undecided, confidence=0.50, audit)
```

audit 字段全部存 Task.legacyKind / migrationRuleId / migrationConfidence / legacyParentHint。R2 补 manual review 字段：reviewedBy / reviewedAt 必须 set 后才能 confidence < 0.80 的记录被 apply。

实测验证：用脚本对 164 任务跑 dry-run，输出分布报告（high/medium/low confidence count），M1-PR2 验收标准 ≥95% high confidence (≥0.85)。

### 2.3 Migration 执行顺序

```
M1-PR1: Prisma migrate (schema 加字段全部 nullable + default)
M1-PR2: 启发式分类脚本 dry-run → 输出 CSV (taskKey/kind/confidence/parentEpicId/audit)
        → 自动产分布报告（high/medium/low）+ 关键数据：≥95% high?
M1-PR3: 人工 review medium/low confidence cases (≤10 项预估)
        → 写 reviewedBy/At
M1-PR4: 写迁移脚本 (基于 reviewed CSV) apply
M1-PR5: ALTER TABLE 加 NOT NULL + CHECK constraints + TRIGGER
        → R2 修：M1-PR5 必须在 M2 后端 kind-aware 写路径完成后 apply（否则 M1-PR4 之后到 PR5 之间的写入会被未来 CHECK 拒）
        → 实操：M1-PR5 = M2 末尾的 final cutover migration
```

## 3. Progress 语义（R2 修复 E1）

```
Task.progress 字段保留，仅 SubTask 使用：
  现有语义不变。基于 currentNode：
    requirement_analysis=10, technical_design=25, task_breakdown=35,
    dispatch=50, implementation=70, review=85, archive=100
  + nodeSubstate 微调 ±5
  Task.kind=epic 时 progress 字段忽略（read model overlay）

Epic.progress (computed, read-only):
  let active = SubTasks where kind=subtask AND parentEpicId=epic.id AND status NOT IN (cancelled)
  if COUNT(active) == 0:
    return 0   // R2 补：空集合
  return ROUND(SUM(active.progress) / COUNT(active))

Epic.status (computed):
  if all SubTasks status = cancelled: return 'cancelled'   // R2 补：全 cancelled
  if all SubTasks currentNode = archive: return 'delivered'
  if any SubTasks currentNode IN (dispatch, implementation, review): return 'delivering'
  default: return 'planning'

Requirement.progress (computed):
  let direct_subtasks = SubTasks where requirementId=req.id AND parentEpicId IS NULL
  let epics = Tasks where kind=epic AND requirementId=req.id
  if COUNT(direct_subtasks) == 0 AND COUNT(epics) == 0:
    return 0
  weight: epic = 10x, direct_subtask = 1x
  return weighted_average(epics.progress, direct_subtasks.progress)
```

实现：read model `task_aggregation_view`（DB view），每次 read 计算；写时通过 hook 触发 cache 刷新（v1 不缓存，read 直接 query；v2 加 materialized view）。

## 4. epic_replan 事件流（D9 + R2 修复 E1）

```
SubTask review fail 路径:
  1. SubTask.review fail → review_intent.intentType = 'request_replan'
  2. emit event: epic_replan_requested
     payload:
       source_subtask_id: <subtask>
       target_epic_id: <epic>
       reason: <review fail reason>
       failed_review_intent_id: <id>
  3. epic_lifecycle 检测事件 → transition delivering_to_planning
  4. ← R2 + D9 修：lifecycle handler__epic_replan 直接调 epic.subtask_create primitive
     - 不进 task_breakdown 节点（applicable_kinds=[subtask] 严格守约）
     - primitive 产 1 个新 SubTask 补救（继承 epic.linked_spec_id + 新 spec_section_id）
  5. 用户/Claude 在 Epic detail 页可查看：
     - 失败 SubTask（已 archive 或 blocked 状态）
     - 新生成的补救 SubTask（kind=subtask, currentNode=dispatch）
     - banner: "SubTask <X> review 失败，已自动产生补救 SubTask <Y>"

UI 表现:
  Epic detail 页 banner: "SubTask <X> 触发 epic_replan_requested"
  按钮：[查看补救 SubTask <Y>] [手动添加 SubTask] [Epic 整体 cancel]
```

## 5. Projection ↔ state file 同步（R2 修复 E1）

```
DB Task 表 = source-of-truth
docs/.ccb/state/<task>.md = async outbox / projection

写路径 (CAS-safe + outbox，R3 修 blocker 4):
  1. tx_begin
  2. UPDATE Task SET ... WHERE state_revision = expected_rev
  3. INSERT INTO ProjectionOutbox (taskId, revision, idempotencyKey=`${taskId}:${revision}`, status='pending')
     -- idempotencyKey UNIQUE 防重复 enqueue
  4. tx_commit  (DB write + outbox enqueue 同事务原子)
  5. async projection worker:
     - SELECT * FROM ProjectionOutbox WHERE status='pending' ORDER BY createdAt LIMIT N
     - for each row: read Task from DB → write state file
       - on success: UPDATE outbox SET status='projected', updatedAt=NOW
       - on failure: UPDATE outbox SET retryCount+=1, lastError=..., status='pending' if retryCount<5 else 'failed'
     - 'failed' rows 触发 projection_failed event → ops alert

读路径 (consistency):
  read_task_state(taskId):
    return prisma.task.findUnique(taskId)  # DB 是 SoT，state file 不参与 read

启动时 reconcile:
  - 处理 outbox 中 status='pending' 历史项（不丢）
  - 对所有 Task 比对 state file revision，mismatch 时 re-enqueue outbox
  - 输出 reconcile report

Failure recovery:
  - DB write failed → tx rollback，无 state 文件污染
  - outbox 已写但 worker 没跑 → 启动 reconcile / 持续 worker 拉
  - 重复事件触发 → idempotencyKey UNIQUE 拒绝重复 enqueue（worker 也按 idempotencyKey 去重）
  - state file corrupt → 不影响 read（DB SoT），异步从 DB 重生
```

invariant test:
- 任意 write_task_state 后立即查 ProjectionOutbox：必有对应 (taskId, revision) row，status='pending' 或 'projected'
- start-up reconcile job 必跑，输出 metrics（reconciled / mismatched 数）
- 不再用 100ms 时间窗（不可靠）—— 改用 outbox row 状态查询

## 6. SubTask 跳过 plan 三节点的审计 (R2 修复 E4)

```
epic 模式 task_breakdown 节点 fixed_actions 末尾:
  for each planned_pr in epic.spec.subtask_sections:    # D10：从 epic spec 内 section 解析
    new_subtask = createTask({
      kind: 'subtask',
      parentEpicId: epic.id,
      requirementId: epic.requirementId,                 # 也直接 link，便于 cross-epic query
      taskKey: `${epic.taskKey}-pr${index}`,
      title: planned_pr.title,
      summary: planned_pr.summary,
      currentNode: 'dispatch',                           # D4
      runtimeState: 'running',
      nodeSubstate: 'ready_for_pickup',
      linkedSpecId: epic.linkedSpecId,                   # D10 共享 epic spec
      specSectionId: planned_pr.section_id,              # D10 指向具体 section
      implementationOwner: planned_pr.owner              # D11 'claude' or 'ccb_codex'
    })

    # R2 新增：synthetic event 留审计
    EventJournal.append({
      event_type: 'subtask_planning_inherited',
      task_id: new_subtask.id,
      payload: {
        from_epic_id: epic.id,
        from_node: 'task_breakdown',
        inherit_artifacts: ['linkedSpecId', 'requirementId'],
        spec_section_id: planned_pr.section_id,
        skipped_nodes: ['requirement_analysis', 'technical_design', 'task_breakdown']
      }
    })

  scheduler 接到 subtask_created event → 检查 applicable_kinds → 拉起 dispatch
```

时间线视图（Epic detail UI）：每个 SubTask 显示 "继承自 Epic 的 plan，从 dispatch 起步"，链接到 epic spec 对应 section。

## 7. API 直接切换 (D7) + ?legacy=1 边界明确 (R3 解 blocker 5)

M2-PR5 cutover：
- 删除 `/api/tasks` 旧 schema
- 直接返回 kind / parentEpicId / requirementId / epicStatus / specSectionId / implementationOwner 新字段
- 同步切换 console-web 调用方
- 仅 README CHANGELOG 记 breaking
- 不写 sunset deprecation header / 不发 telemetry warning

**`?legacy=1` 灰度边界**（R3 解 blocker 5）：
- 仅切换**前端看板视觉布局**（旧 7 节点平铺 vs 新 Epic 摘要置顶 + SubTask 列）
- **不影响 API schema**：?legacy=1 模式下 console-web 仍调新 /api/tasks，仅 UI 渲染走旧布局组件
- 不存在"旧 schema + 新 schema 双轨"，仅"新 schema + UI layout 双视图"
- 30 天后移除 ?legacy=1 路径，删除旧布局组件代码

## 8. 5 Milestone + Implementation Owner (D11 应用)

| Milestone | 拆分预览 | implementation_owner |
|---|---|---|
| **M0** Plugin | M0-PR1~PR8 (state-schema / manifests / lifecycles / templates / ADR / release) | **ccb_codex** （协议层 + spec / ADR 撰写） |
| **M1** Console DB | M1-PR1~PR5 (Prisma migration / dry-run / human review / apply / CHECK+trigger) | **ccb_codex** （DB / migration script） |
| **M2** Console 后端 | M2-PR1~PR5 (task_breakdown adapter / epic_replan handler / progress read model / endpoints / API cutover) | **ccb_codex** （后端 adapter / API） |
| **M3** 看板 IA | M3-PR1~PR3 (Epic 摘要置顶 / SubTask 父 Epic 面包屑 / view 切换+灰度) | **claude** （D11：UI/UX 全 Claude） |
| **M4** Detail 分化 | M4-PR1~PR4 (/requirements/:id / Epic detail / SubTask detail 面包屑 / 灰度移除) | **claude** （D11） |

总 PR ~25 个。**M3/M4 共 ~7 个 PR Claude 自己实施，不派 codex**。

## 9. 跨仓 ordering 与发布 (R2 修复 ordering risks)

```
Day 1-6:  M0 plugin 仓全部完成 → v0.5.0 git tag
Day 7:    console feature branch 拉 plugin v0.5.0 snapshot 同步到 references/kernel/
          ← R2 修：在 feature branch 而非 main，避免 console main 立即消费新 manifest
Day 7-10: M1 console DB migration（feature branch 上）
Day 11-14: M2 console 后端
          ← R2 修：M2-PR5 (API cutover) 完成 + M1-PR5 (CHECK+trigger) 同 PR apply
          避免 M1 CHECK 后 M2 旧写入被拒
Day 11-14（并行）: M2-PR5 + M1-PR5 合并 cutover migration
Day 15-17: M3 看板（claude 自实施）
Day 18-20: M4 detail 分化（claude 自实施）
Day 20:   feature branch merge to main + release
M4 GA 后 30 天 (相对，不是 Day 50 绝对): ?legacy=1 灰度移除
          ← R2 修：相对时间，避免延期导致提前移除
```

compatibility gate (R2 新增):
- console main 在 plugin v0.5.0 release 前**禁止**消费新 manifest（CI check）
- M0 完成后才创 console feature branch
- M1-M4 全在 feature branch，merge to main 之前所有功能 PR 测试 pass

## 10. 验收（与 spec §7 同步，不重复）

每个 PR 必须包含 (a) Prisma migration test (M1) / fixture（M0 schema validate / M2 fixture trace / M3-M4 Playwright screenshot）+ (b) 可执行命令证据。

## 11. 风险与缓解

无新增（spec §8 同步）。R2 ordering risks 已在 §9 修复。

## 12. R3 修订记录 + R4 触发

### R3 评分: 6.0/10 (E1=7 E2=4 E3=7 E4=6)，单维 fail E2，仍未到 7.0

R3 反馈的 5 个 blocker 已在本版（R3 修订）解：
- ✅ blocker 1 · parent invariant 冲突 → §1.1 + §2.1：删除 chk_subtask_parent_xor，改为一致性 invariant `parentEpic.requirementId == subtask.requirementId`，trigger 验证
- ✅ blocker 2 · DB trigger 完整性 → §2.1：3 个 trigger（INSERT + UPDATE + epic same-project）
- ✅ blocker 3 · specSectionId / implementationOwner 存储 → §2.1：进 Prisma Task schema
- ✅ blocker 4 · projection outbox idempotency → §2.1 ProjectionOutbox 表 + idempotencyKey UNIQUE，§5 重写
- ✅ blocker 5 · ?legacy=1 边界 → §7：明确仅 UI layout，不影响 API schema

### R4 Consult 触发

本 R3 修订完成后立即触发 R4，评估范围：
- 5 R3 blockers 全部 resolve 验证
- §1.1 invariants + §2.1 SQL CHECK / TRIGGER 一致性 + 完备性
- §5 outbox 协议是否充分（包括 worker idempotency / 重试上限 / DLQ 策略）
- specSectionId / implementationOwner 字段是否需要 NOT NULL 约束 / 默认值
- ?legacy=1 文案是否够清晰

R3 已 pass E1 + E3。**R4 目标 overall ≥ 7.0 + no dim ≤ 3 → 通过 framework gate → step2_approval**

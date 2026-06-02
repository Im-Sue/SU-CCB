---
doc_type: lessons
title: "CCB MVP 参考研究笔记 Vibeman 与同类产品"
updated: 2026-05-28
---
# CCB MVP 参考研究笔记 — Vibeman 与同类产品

> **Date**: 2026-04-22  
> **Status**: Step 0 reference notes  
> **Scope**: reference only; no integrate / fork / depend / adapter  
> **Related**: ADR-0001, CCB PM 平台北极星校准与自研引擎 MVP 规划

---

## 1. Reference-Only Boundary

| Rule | Decision |
|---|---|
| Product identity | CCB is PM platform + governed multi-LLM execution |
| Third-party role | research input only |
| Forbidden | integrate / fork / depend / adapter / runtime adoption / overlay / direct DB coupling |
| Source anchor | 用户原话："参考 / 借鉴"；R4 纠偏："它不应该是我们的一部分或者对接对象" |

## 2. Research Scope

| Product | Scope |
|---|---|
| Vibeman | local workflow/run/task/workspace semantics, schema shape, UX pattern |
| n8n | node automation, triggers, connectors, webhooks |
| Temporal | durable workflow execution, activity contract, retry/versioning |
| LangGraph | state graph, checkpoint, interrupt, human-in-the-loop |
| CrewAI | role/team collaboration vocabulary |
| Harness AI | enterprise governance in CI/CD-like execution |
| Dify | LLM app flow, prompt management, app operations |
| Airflow | DAG scheduling, operator/sensor model |

## 3. Borrowing Depth Scale

| Level | Meaning | Boundary |
|---|---|---|
| 0 | read only | no design dependency |
| 1 | borrow concept | CCB names and models independently |
| 2 | borrow structure | similar separation of concerns |
| 3 | borrow schema shape | comparable fields, CCB-owned semantics |
| 4 | rebuild implementation pattern | implement from CCB kernel, no code reuse |

## 4. Depth Matrix

| Dimension | Max depth | CCB landing |
|---|---:|---|
| Executor classification | 2 | `ExecutorProfile.type = llm_agent / shell_command / human_gate` |
| Workflow/run layering | 2 | definition / run / step / log separation |
| Pause/resume/cancel/retry | 4 | CCB lifecycle events and guards |
| Human gate | 3 | `gate.user_confirmation` and approval primitive |
| Thread/session reuse | 3 | provider thread IDs + CCB policy |
| Observability granularity | 3 | step logs, token usage, redacted payload |
| Error handling/retry class | 4 | CCB-owned failure taxonomy |
| UX timeline/detail/palette | 2 | Console-native components |
| Prisma/local DB | 1 | Console already uses Prisma/SQLite |
| UI bundle/product shell | 0-1 | no product shell inheritance |

## 5. Multi-Product Borrow / Reject Matrix

| Product | Borrow | Reject |
|---|---|---|
| Vibeman | workflow/run/step/log separation; task workspace UX | runtime integration; product shell; direct DB coupling |
| n8n | trigger/connectors mental model | visual node editor as MVP center |
| Temporal | durable execution; retry policy; activity contract; versioning | distributed infra complexity |
| LangGraph | state graph; checkpoints; interrupts | agent DAG bypassing CCB guards |
| CrewAI | role/team vocabulary | role theater without ownership/permissions |
| Harness AI | governance in execution pipelines | enterprise pipeline sprawl |
| Dify | prompt/app flow management | generic LLM app-builder identity |
| Airflow | operator/sensor scheduling concepts | batch scheduler identity |

## 6. Vibeman Local Fact Summary

Local inspection path: `.tmp/vibeman-inspect/node_modules/vibeman/` (read only).

| Area | Observed fact |
|---|---|
| Package | `vibeman` 0.0.18, Apache-2.0, CLI binary `vibeman` |
| Runtime DB | Prisma schema under `dist/prisma/schema.prisma` |
| Executors | `Executor(type, config, tags)` with observed types `coding_agent`, `shell`, `human_input` |
| Workflow definition | `WorkflowDefinition` + `WorkflowNode`, with `startNodeKey`, `transitionMap`, retry/timeout fields |
| Run records | `WorkflowRun`, `WorkflowRunStepResult`, `WorkflowRunLog` |
| Observability | step output, messages, graph state, token usage, session/thread IDs |
| Lifecycle fixtures | pause/resume/cancel/restart/retry, human gate, cross-agent handoff |
| Task storage | `.vibeman/tasks/*.md` markdown + frontmatter |
| Workspace | git branch/worktree semantics visible in built runtime code |
| UI | React/Radix/Vite-style bundled UI assets |

## 7. CCB Aggregation Principle

| Principle | Application |
|---|---|
| PM-first | project / requirement / task / document remain the product shell |
| Governed execution | workflow execution cannot bypass primitive / guard / transition truth sources |
| CCB-owned semantics | third-party names are not copied unless they match CCB language |
| Minimal MVP | no node designer, no generic automation platform, no adapter layer |
| Runtime observability | logs explain execution but never replace canonical state |

## 8. Keep / Reject Summary

| Keep | Reject |
|---|---|
| definition/run/step/log separation | external runtime adoption |
| worktree-per-task as Git isolation pattern | branch-only MVP if concurrent work is required |
| human gate as first-class governance event | human gate as generic pause without CCB approval semantics |
| thread reuse as explicit policy | hidden provider state |
| redacted step observability | raw secrets in logs/messages |

## Provenance

Compiled from 2026-04-22 CCB consult R1-R5, ADR-0001, requirement/design docs, and local read-only Vibeman inspection facts.

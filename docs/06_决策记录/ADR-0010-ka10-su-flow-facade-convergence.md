---
id: ADR-0010
title: KA-10 /ccb:su-flow public facade convergence
status: active
decided_at: 2026-05-03
decider: Claude
reviewer: ccb_codex
related_epic: e11-ka10-su-flow-facade
related_task: e11-t1-adr-su-flow-convergence
deprecated_in: "0.4-v1"
removed_in: "0.4-v2"
grace_window: "v0.4 v2 release OR at least 90 天 wall-clock after decided_at, whichever is later"
impacted_components:
  - claude-plugin-distribution
  - codex-skills-distribution
  - docs-ccb-workspace
---

# ADR-0010: KA-10 /ccb:su-flow Public Facade Convergence

## Status

Accepted.

## Context

v0.4 northstar §3.5 defines the target shape: `/ccb:su-plan` and `/ccb:su-agent` converge into `/ccb:su-flow`, user-facing behavior switches through `policy_profile`, and the implementation should not maintain two scheduler code paths.

Current repository facts narrow that decision:

- `su-ccb-claude-plugin/skills/su-plan/SKILL.md` exists as a v0.3.2 thin facade over `requirement_analysis -> technical_design -> task_breakdown`.
- `/ccb:su-agent` was never implemented. Northstar §3.5 explicitly said v0.3.2 should not add it.
- E1.5 primitive wrapper rollout is complete: 18 wrapped + 2 legacy, no new inventory-scope unwrapped mutation entry.
- master roadmap §11 Round 2 Q6 already chose soft alias, not hard symlink, with the draft landing at `su-ccb-claude-plugin/skills/su-flow/SKILL.md`.

The remaining decision is therefore not a runtime merge. It is a public facade convergence: add `/ccb:su-flow`, keep `/ccb:su-plan` as a temporary alias, and move public documentation to the new name.

## Decision

`/ccb:su-flow` becomes the v0.4 v1 public entry for SingleTaskScheduler planning flow.

`/ccb:su-plan` remains for one grace window as a soft alias:

- implemented as documentation / SKILL redirect wording;
- no hard symlink;
- no second runtime scheduler path;
- no change to canonical node manifests in `references/kernel/`.

`policy_profile` is reserved in `/ccb:su-flow` documentation:

- default: `interactive-single`;
- `autonomous-batch`: reserved and must report `not_implemented_in_v0.4_v1` until E14 ReactiveScheduler unlocks it.

`deprecated_in` and `removed_in` metadata may appear in SKILL frontmatter as human-readable metadata. Whether the plugin loader parses those fields is explicitly outside this decision.

## Deprecation Schedule

`/ccb:su-plan` is deprecated starting v0.4 v1.

Removal is allowed only at v0.4 v2 release OR at least 90 天 wall-clock after `decided_at: 2026-05-03`, whichever is later.

Until then:

- existing users may continue to call `/ccb:su-plan`;
- public docs should prefer `/ccb:su-flow`;
- old-name references may remain only in historical archive, decisions, and explicit deprecated-alias sections.

## Scope

In scope:

- `su-ccb-claude-plugin/skills/su-flow/SKILL.md`;
- `su-ccb-claude-plugin/skills/su-plan/SKILL.md` deprecation banner / redirect wording;
- public docs and prompt templates that teach users which command to call;
- migration check fixture / grep script for old-name leakage.

Out of scope:

- hard symlink or file-level aliasing;
- ReactiveScheduler;
- autonomous-batch implementation;
- runtime dispatch / review / archive behavior;
- `references/kernel/` canonical manifest changes;
- plugin loader support for `deprecated_in` / `removed_in`.

## Alternatives Rejected

### A1 - Hard Symlink Alias

Rejected. Symlink behavior is brittle across platforms and plugin distribution snapshots. It also adds filesystem semantics to what should be a facade naming decision.

### A2 - Immediate Removal of /ccb:su-plan

Rejected. Existing projects and copied prompt templates may still reference the old entry. Immediate removal would create avoidable migration breakage.

### A3 - Implement /ccb:su-agent Before Convergence

Rejected. Northstar explicitly said v0.3.2 should not add `/ccb:su-agent`; adding it now would create the second facade that this ADR is trying to avoid.

## Consequences

Positive:

- users learn one public planning entry, `/ccb:su-flow`;
- v0.4 v1 closes KA-10 without expanding scheduler scope;
- E14 can later attach `autonomous-batch` without renaming the public command again.

Negative:

- docs and templates need a grep-driven migration;
- old and new command names coexist during the grace window;
- downstream plugin snapshots need an explicit plugin push / refresh before `/ccb:su-flow` is visible.

## Verification

Follow-up tasks must provide machine-checkable evidence:

- `test -f su-ccb-claude-plugin/skills/su-flow/SKILL.md`;
- `grep -q 'deprecated_in\|Deprecated' su-ccb-claude-plugin/skills/su-plan/SKILL.md`;
- `bash scripts/check-su-flow-migration.sh`;
- sample trace showing `/ccb:su-flow` output includes `currentNode`, `nodeSubstate`, and `runtimeState`;
- sample trace showing `/ccb:su-plan` displays deprecated alias guidance;
- `python3 references/kernel/tools/lint_all.py` reports `ALL_GREEN: yes`.

## Related

- Master roadmap: `docs/.ccb/specs/active/2026-05-02-ccb-master-roadmap-v0.4v1-console-v2-growth.md` §11 Round 2 Q6
- Northstar: `docs/01_架构设计/ccb-plan/v0.4-node-kernel-northstar.md` §3.5 and §6
- Parent epic: `docs/.ccb/specs/active/2026-05-03-e11-ka10-su-flow-facade.md`
- Upstream evidence: `docs/.ccb/reports/e1-5-t6-rollout-final-report.md`

---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Ship It
status: unknown
last_updated: "2026-03-01T01:32:14.564Z"
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 13
  completed_plans: 13
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-28)

**Core value:** Unlimited, free, real-cluster CKAD practice with automated validation
**Current focus:** Milestone v1.1 Ship It — Phase 4 (Exam Mode) complete, Phase 5 (Learn Mode) next

## Current Position

Phase: 4 of 7 (Exam Mode) — first v1.1 phase
Plan: 2/2 complete (04-01 exam session engine, 04-02 exam CLI wiring)
Status: Phase 4 complete
Last activity: 2026-03-01 — 04-02 complete: exam CLI wired into bin/ckad-drill, 94 tests passing

Progress: [####------] 40% (4/7 phases complete — v1.0 phases done; Phase 4 in progress)

## Performance Metrics

**Velocity (from v1.0):**
- Total plans completed: 11
- Average duration: ~4 min
- Total execution time: ~0.7 hours

**By Phase (v1.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation-cluster | 2 | 5 min | 2.5 min |
| 02-scenario-validation-engine | 2 | 11 min | 5.5 min |
| 03-cli-drill-mode | 6 | 16 min | 2.7 min |
| 03.1-drill-integration-fixes | 1 | 14 min | 14 min |
| 04-exam-mode | 2/2 | 22 min | 11 min |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table and architecture.md ADRs.
Key decisions affecting v1.1 work:

- All phases: Pure bash, no build step — source is the product
- Phase 4: Exam mode as distinct component with separate session state (ADR-11)
- 04-01: D3 target set to 3 (not 2) so integer weights 3+3+3+4+3=16 total cleanly
- 04-01: exam_select_questions takes file paths as args (not internal discover) — caller controls pool
- 04-01: exam_grade implemented in pure jq (single invocation via group_by+reduce)
- 04-01: flagged=true overrides status icon in exam_list — [?] displayed instead of status
- Phase 5: Learn mode shares scenario engine; concept text in YAML `learn_intro` field
- Phase 6: Same repo, archive study guide (preserves git history, transforms in place)

**From v1.0 execution (patterns that carry forward):**
- error() is print-only (no exit) — callers decide on exit
- yq v3 syntax required (yq -r '.field // empty' file) — not v4
- ((n++)) || true required with set -e — arithmetic increment from 0 is falsy
- jq atomic write pattern (tmp + mv) for all file updates
- SCENARIO_NAMESPACE bridge pattern for cleanup paths
- Index-based yq extraction (.solution.steps[N]) for multi-line YAML block scalars
- [Phase 04-02]: Exam subcommands extracted to helper functions (_exam_start/_exam_submit) because local keyword not valid in case blocks
- [Phase 04-02]: check) branches on SESSION_MODE after session_require — avoids dual session_require/exam_require calls

### Pending Todos

None yet.

### Blockers/Concerns

- Learn mode detailed UX (lesson navigation, progression) not fully specified — design during Phase 5 planning
- PRD at docs/prd.md still references Go/Bubble Tea — architecture.md is source of truth

## Session Continuity

Last session: 2026-03-01
Stopped at: Completed 04-02-PLAN.md — exam CLI wiring, 94 tests, exam mode fully functional
Resume file: None

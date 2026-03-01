---
phase: 05-learn-mode
plan: "02"
subsystem: learn-cli
tags: [bash, learn-mode, cli, dispatch, bats, shellcheck]

# Dependency graph
requires:
  - phase: 05-learn-mode
    plan: "01"
    provides: "lib/learn.sh with learn_discover, learn_list_domain, learn_show_intro, learn_next_lesson + progress_record_learn/progress_learn_completed"
  - phase: 04-exam-mode
    plan: "02"
    provides: "bin/ckad-drill CLI wiring patterns (_exam_start/_exam_submit helpers, check) SESSION_MODE branching)"

provides:
  - "bin/ckad-drill learn subcommand: domain listing with [x]/[ ] completion status"
  - "bin/ckad-drill learn --domain N: next uncompleted lesson with concept text then task"
  - "bin/ckad-drill check extended for learn mode: validates, records progress_record_learn, suggests next lesson"
  - "test/unit/drill.bats extended with 6 learn mode regression tests (30 total)"

affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Learn subcommands extracted to _learn_start/_learn_list helpers (local keyword not valid in case blocks)"
    - "cluster_check_active called first in _learn_start before learn_next_lesson — ensures cluster error even when no scenarios found"
    - "Learn check) branch uses unscoped variables (no local) for learn_domain/next_lesson_file — case block restriction"

key-files:
  created: []
  modified:
    - bin/ckad-drill
    - test/unit/drill.bats

key-decisions:
  - "cluster_check_active called before learn_next_lesson in _learn_start — ensures meaningful error when cluster down regardless of scenario count"
  - "_learn_list and _learn_start extracted as helper functions (local keyword not valid in case blocks — same pattern as exam mode)"
  - "Learn check) branch uses plain variables not local — case block restriction in bash"
  - "Concept text (learn_intro) displayed with Concepts header before scenario task card — concept first then practice"

requirements-completed: [LERN-01, LERN-02, LERN-03, LERN-04, LERN-05]

# Metrics
duration: 7min
completed: 2026-03-01
---

# Phase 5 Plan 02: Learn Mode CLI Wiring Summary

**Learn subcommands wired into bin/ckad-drill following exam mode patterns: `learn` lists all domains, `learn --domain N` starts next uncompleted lesson with concept text before task, `check` extended to record completion and suggest next lesson — 87 tests passing**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-01T01:56:25Z
- **Completed:** 2026-03-01T02:03:30Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments

- `ckad-drill learn` lists all 5 domains with `[x]`/`[ ]` completion status per lesson (LERN-01)
- `ckad-drill learn --domain N` finds next uncompleted lesson, checks cluster, sets up scenario, displays concept text (learn_intro) before task card (LERN-02, LERN-03)
- `ckad-drill check` extended with learn mode branch: validates, calls `progress_record_learn` on pass, suggests next lesson or congratulates on domain completion (LERN-04, LERN-05)
- `hint` and `solution` pass through to learn mode session (not blocked like exam mode)
- Help text updated with learn and learn --domain N subcommands
- All 6 new learn tests pass; total 87 tests (30 drill + 17 learn + 40 progress) with zero failures
- shellcheck clean on bin/ckad-drill and lib/learn.sh

## Task Commits

Each TDD phase committed atomically:

1. **RED: Failing tests for learn mode CLI** - `f885599` (test)
2. **GREEN: Implement learn subcommands in bin/ckad-drill** - `1d97ce2` (feat)

## Files Created/Modified

- `/home/jeff/Projects/cka/bin/ckad-drill` — sourced lib/learn.sh; added _learn_list, _learn_start helpers; added learn) dispatch; extended check) with learn branch; updated help text
- `/home/jeff/Projects/cka/test/unit/drill.bats` — 6 new learn mode tests (learn list, learn --domain cluster check, hint/solution allowed in learn, check records completion, help shows learn)

## Decisions Made

- **cluster_check_active before learn_next_lesson**: Called cluster check first in _learn_start so that "no active cluster" error fires even when there are no learn scenarios in the test environment — mirrors the behavior users expect
- **Helper function extraction**: _learn_start and _learn_list extracted from case block — bash forbids `local` at case statement top level; same pattern established by exam mode
- **No local in check) learn branch**: Variables learn_domain/next_lesson_file/next_lesson_title declared without `local` in the case block — case block restriction
- **Concept text with Concepts header**: learn_intro displayed under a "Concepts" section header before the task card — establishes progressive learning: understand first, then practice

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] local not valid in case block for check) learn branch**
- **Found during:** Task 1 GREEN phase (test failure)
- **Issue:** Plan action spec showed `local learn_domain`, `local next_file`, `local next_title` inside the `check)` case block — bash does not allow `local` in case blocks (only in functions)
- **Fix:** Removed `local` declarations for learn_domain, next_lesson_file, next_lesson_title in the check) learn branch; used plain global-scoped variables
- **Files modified:** bin/ckad-drill
- **Impact:** Minor scope pollution acceptable — these variables are ephemeral in the top-level case dispatch

**2. [Rule 1 - Bug] cluster_check_active called after learn_next_lesson (wrong order)**
- **Found during:** Task 1 GREEN phase (test failure: "learn --domain exits with No active cluster error when cluster is down")
- **Issue:** Initial implementation called `learn_next_lesson` first; when no learn scenarios exist (test environment), the function returned empty and triggered "All lessons complete" before the cluster check ran
- **Fix:** Moved `cluster_check_active || exit "${EXIT_NO_CLUSTER}"` to be the first call in `_learn_start`, before `learn_next_lesson`
- **Files modified:** bin/ckad-drill
- **Impact:** Correct behavior — cluster availability checked before any scenario discovery work

## Issues Encountered

- Two bash-specific pitfalls caught by TDD: local-in-case-block and cluster-check ordering — both resolved in GREEN phase without needing additional fix cycles

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All LERN requirements (LERN-01 through LERN-05) now complete
- Phase 5 (Learn Mode) fully wired end-to-end: `learn` → `learn --domain N` → `check` → completion + progression
- Phase 6 (Study Guide Archive) can proceed independently

## Self-Check: PASSED

- bin/ckad-drill: FOUND (contains learn), FOUND (contains learn_start), FOUND (contains learn_list)
- test/unit/drill.bats: FOUND (30 tests)
- 87 total tests passing (drill + learn + progress)
- f885599 (RED commit): FOUND
- 1d97ce2 (GREEN commit): FOUND

---
*Phase: 05-learn-mode*
*Completed: 2026-03-01*

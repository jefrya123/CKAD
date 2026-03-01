---
phase: 03-cli-drill-mode
plan: "06"
subsystem: cli
tags: [bash, yq, heredoc, eval, validate-scenario, bats]

requires:
  - phase: 03-cli-drill-mode
    provides: "_validate_single_scenario function with broken while-read solution loop"

provides:
  - "Fixed _validate_single_scenario using index-based yq .solution.steps[N] extraction"
  - "Unit tests confirming yq v3 index-based extraction behavior (no cluster needed)"

affects: [03-UAT, 04-exam-mode]

tech-stack:
  added: []
  patterns:
    - "Index-based yq extraction for multi-line YAML block scalars: yq -r '.array[N]' file"
    - "C-style for loop with yq length + indexed reads to preserve multi-line step integrity"

key-files:
  created: []
  modified:
    - bin/ckad-drill
    - test/unit/drill.bats

key-decisions:
  - "Use C-style for loop with sol_i counter (not while-read) to feed complete multi-line strings to eval"
  - "Failed solution steps emit warn but do not abort — preserves || true semantics with visibility"
  - "yq 2>/dev/null suppression kept on extraction calls; eval errors intentionally visible"

patterns-established:
  - "Multi-line YAML values: always extract by index (yq -r '.array[N]'), never iterate output lines"
  - "sol_i variable name (not i) to avoid shadowing outer loop variables in nested contexts"

requirements-completed: [DIST-03, DIST-04]

duration: 1min
completed: "2026-02-28"
---

# Phase 3 Plan 06: validate-scenario Solution Step Fix Summary

**Fixed multi-line heredoc solution steps by replacing while-read yq iteration with C-style for loop using index-based yq .solution.steps[N] extraction — eval now receives complete heredoc blocks**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-28T23:00:28Z
- **Completed:** 2026-02-28T23:01:28Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced the broken `while IFS= read -r step` loop in `_validate_single_scenario` with a C-style for loop that uses `yq -r ".solution.steps[${sol_i}]"` to retrieve each step as a complete, unbroken multi-line string
- Failed solution steps now emit a `warn` message instead of being silently suppressed by `2>/dev/null || true`
- Added 2 unit tests in `drill.bats` confirming yq v3 index-based extraction returns correct count (0 for missing key) and correct per-index values — no cluster required

## Task Commits

1. **Task 1: Fix _validate_single_scenario index-based yq extraction** - `5f61aff` (fix)
2. **Task 2: Add unit tests for solution step extraction** - `1dad22e` (test)

## Files Created/Modified

- `/home/jeff/Projects/cka/bin/ckad-drill` - Replaced lines 222-228: while-read loop replaced with C-style for loop using `.solution.steps[N]` index extraction
- `/home/jeff/Projects/cka/test/unit/drill.bats` - Added 2 tests: missing solution.steps returns 0, 2-step scenario returns correct count and per-index values

## Decisions Made

- Variable named `sol_i` (not `i`) to avoid shadowing any outer loop variable — clearly scoped to solution application
- `step_count=0` fallback via `|| echo "0"` handles YAML with no `solution.steps` key — loop never executes, no error
- `warn` on failed eval instead of silent discard — operator can see when their solution step fails during validate-scenario

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - shellcheck passed on first attempt, all 15 bats tests passed on first run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `validate-scenario sc-multi-container-pod.yaml` against a live cluster should now correctly apply both solution steps (including the heredoc step) before running validations
- Phase 3 UAT test 10 (validate-scenario lifecycle) is unblocked
- Phase 4 exam mode can proceed — validate-scenario is now functionally correct

---
*Phase: 03-cli-drill-mode*
*Completed: 2026-02-28*

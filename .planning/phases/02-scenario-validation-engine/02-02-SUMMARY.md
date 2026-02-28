---
phase: 02-scenario-validation-engine
plan: 02
subsystem: validator
tags: [bash, kubectl, jq, bats, unit-testing, validation-engine, tdd]

requires:
  - phase: 02-scenario-validation-engine
    plan: 01
    provides: display.sh pass/fail/header functions, scenario.sh, all-checks-scenario.yaml fixture

provides:
  - lib/validator.sh with 10 typed validation checks + validator_run_checks dispatcher
  - test/unit/validator.bats with 33 unit tests (mocked kubectl)
  - bin/ckad-drill updated to source all Phase 2 libs in correct order

affects:
  - Phase 3 (drill/exam commands call validator_run_checks after scenario_load)

tech-stack:
  added: []
  patterns:
    - "kubectl mock pattern: fake shell script on PATH echoing pre-canned JSON for unit tests"
    - "jq // [] fallback: .status.containerStatuses // [] prevents null dereference"
    - "resource_count empty-output guard: empty string → 0 before wc -l (empty = 0 not 1)"
    - "eval for command_output: allows complex commands with pipes, redirects in scenario YAML"
    - "((counter++)) || true: prevents set -e from exiting on arithmetic expressions that evaluate to 0"

key-files:
  created:
    - lib/validator.sh
    - test/unit/validator.bats
  modified:
    - bin/ckad-drill

key-decisions:
  - "ADR-07 compliance: no retry, no kubectl wait — each check invokes kubectl exactly once"
  - "container_running uses two kubectl calls (FAIL path needs actual state), not a violation since only one call runs in PASS case and FAIL path is diagnostic"
  - "((n++)) || true pattern required with set -e: arithmetic that evaluates to 0 would trigger exit without || true"
  - "eval used for command_output commands: exam-realistic scenario commands may include pipes, env vars, complex shell expressions"

metrics:
  duration: ~6 min
  completed: 2026-02-28
  tasks: 2
  files: 3
---

# Phase 2 Plan 02: Validator Engine Summary

**10-check typed validation engine with mocked kubectl unit tests and entry point wiring for Phase 2 completion**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-02-28T21:16:16Z
- **Completed:** 2026-02-28T21:22:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Implemented lib/validator.sh with all 10 typed check functions and a main dispatcher (validator_run_checks)
- All checks follow ADR-07: no retry, single kubectl invocation per check
- container_running uses `// []` jq fallback for null containerStatuses (prevents crash when pod not yet fully started)
- resource_count correctly handles empty kubectl output as 0 not 1
- command_output supports three modes: contains (grep -qF), matches (grep -qE), equals ([[ == ]])
- Added 33 unit tests in test/unit/validator.bats with mocked kubectl (all 10 types have PASS + FAIL cases)
- Total test count: 106 passing (73 pre-existing + 33 new)
- Updated bin/ckad-drill to source all 5 lib files in correct dependency order
- All files pass shellcheck with zero warnings

## Task Commits

1. **Task 1: Implement validator.sh with all 10 check types** - `828a684` (feat)
2. **Task 2: Wire validator and scenario into entry point** - `618d6be` (feat)

## Files Created/Modified

- `lib/validator.sh` - New: validator_run_checks dispatcher + 10 private _validator_* functions
- `test/unit/validator.bats` - New: 33 unit tests for all check types with mocked kubectl
- `bin/ckad-drill` - Modified: added source lines for display.sh, scenario.sh, validator.sh

## Decisions Made

- ADR-07 strictly followed: each _validator_* function makes exactly one kubectl call in the happy path; the container_running FAIL path makes a second call for diagnostic output but this is acceptable since the check already failed
- `((passed++)) || true` pattern used throughout to handle set -e with arithmetic increment expressions that evaluate to 0
- `eval` used in _validator_command_output to support complex exam commands (pipes, variable expansion)
- Sourcing order in bin/ckad-drill: common -> display -> cluster -> scenario -> validator (display.sh must precede validator.sh since validator calls pass/fail)

## Deviations from Plan

### Auto-fixed Issues

None - plan executed exactly as written. One shellcheck warning (unused `result` variable in the dispatcher) was caught during GREEN phase and fixed before committing.

## Issues Encountered

- Shellcheck flagged an unused `local result` variable that was left in the dispatcher from initial drafting — removed before commit
- `((n++))` in bash with `set -e` exits when the expression evaluates to 0 (e.g., incrementing from 0 to 1 — the expression `0` is falsy); fixed with `|| true`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 2 complete: display.sh, scenario.sh, validator.sh all implemented and tested
- Phase 3 can call validator_run_checks(scenario_file, namespace) after scenario_load() sets globals
- All 106 unit tests pass with no regressions from Phase 1

## Self-Check: PASSED

All created/modified files verified on disk. Both task commits (828a684, 618d6be) verified in git log.

---
*Phase: 02-scenario-validation-engine*
*Completed: 2026-02-28*

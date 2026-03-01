---
phase: 02-scenario-validation-engine
plan: 01
subsystem: scenario
tags: [bash, yq, yaml-parsing, bats, unit-testing, scenario-engine]

requires:
  - phase: 01-foundation-cluster
    provides: common.sh with _color_enabled(), info/warn/error, EXIT_PARSE_ERROR, test helper infrastructure

provides:
  - lib/display.sh with working pass/fail/header output functions
  - lib/scenario.sh with YAML loading, discovery, filtering, and namespace lifecycle
  - test/fixtures/valid/ with 3 test scenario YAML files
  - test/fixtures/invalid/ with 2 invalid scenario YAML files
  - test/unit/display.bats with 11 passing unit tests
  - test/unit/scenario.bats with 26 passing unit tests

affects:
  - 02-02 (validator.sh uses display.sh pass/fail functions)
  - Phase 3 (drill/exam commands use scenario_load, scenario_filter, scenario_setup, scenario_cleanup)

tech-stack:
  added: []
  patterns:
    - "yq v3 syntax: yq -r '.field // empty' file (NOT yq eval — v4 syntax)"
    - "nameref arrays for passing state into helpers: local -n _seen=$2"
    - "shellcheck disable=SC2034 for exported globals (SCENARIO_* pattern)"
    - "Subshell command() override for mocking command -v in bats tests"
    - "Absolute path loading pattern for bats helpers (matching existing cluster/common bats pattern)"

key-files:
  created:
    - lib/scenario.sh
    - test/fixtures/valid/minimal-scenario.yaml
    - test/fixtures/valid/all-checks-scenario.yaml
    - test/fixtures/valid/helm-scenario.yaml
    - test/fixtures/invalid/missing-id.yaml
    - test/fixtures/invalid/missing-domain.yaml
    - test/unit/display.bats
    - test/unit/scenario.bats
  modified:
    - lib/display.sh (replaced stubs with working pass/fail/header)

key-decisions:
  - "Test-helper.bash load() calls fail when used from unit tests; use absolute path loading pattern instead (matching existing bats files)"
  - "grep -c counts all lines containing .yaml including WARN messages; use grep .yaml$ | grep -vc WARN for path-only count"
  - "_mock_command_missing does not fool command -v; use bash -c subshell with command() override for helm presence tests"

patterns-established:
  - "Bats test files use absolute CKAD_DRILL_ROOT + direct load calls (not test-helper.bash) — consistent with cluster.bats and common.bats"
  - "scenario_load returns EXIT_PARSE_ERROR without calling exit — caller decides on termination"
  - "Namespace fallback: drill-<id> when YAML omits namespace field (ADR-06)"

requirements-completed: [SCEN-01, SCEN-02, SCEN-03, SCEN-04, SCEN-05, SCEN-06]

duration: 5min
completed: 2026-02-28
---

# Phase 2 Plan 01: Scenario Engine + Display Summary

**YAML-based scenario loading engine with yq v3 field extraction, namespace lifecycle, 5-function filtering API, and 37 new passing unit tests**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-28T20:47:56Z
- **Completed:** 2026-02-28T20:52:56Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Replaced display.sh stubs with working pass/fail/header using _color_enabled() from common.sh
- Created scenario.sh with 5 public functions: scenario_discover, scenario_load, scenario_filter, scenario_setup, scenario_cleanup
- Built 5 YAML test fixtures (3 valid, 2 invalid) covering minimal, all-check-types, helm, missing-id, and missing-domain cases
- Added 37 new unit tests (11 display + 26 scenario), bringing total to 73 passing unit tests
- All files pass shellcheck with zero warnings

## Task Commits

1. **Task 1: Implement display.sh and scenario.sh** - `315f569` (feat)
2. **Task 2: Create test fixtures and unit tests** - `498c98f` (feat)

## Files Created/Modified

- `lib/display.sh` - Replaced stubs: pass() green [PASS], fail() red [FAIL] with expected/actual, header() with dash underline
- `lib/scenario.sh` - New: scenario_discover (find + sort -z + nameref dedup), scenario_load (yq v3 required field extraction), scenario_filter (FILTER_DOMAIN/FILTER_DIFFICULTY env vars), scenario_setup (helm check + kubectl create namespace), scenario_cleanup (kubectl delete namespace --ignore-not-found)
- `test/fixtures/valid/minimal-scenario.yaml` - id: test-minimal, domain 1, easy, single resource_exists check
- `test/fixtures/valid/all-checks-scenario.yaml` - id: test-all-checks, all 10 validation types, explicit namespace all-checks-ns
- `test/fixtures/valid/helm-scenario.yaml` - id: test-helm, tags: [helm], domain 3, medium
- `test/fixtures/invalid/missing-id.yaml` - Valid YAML without id field (triggers EXIT_PARSE_ERROR)
- `test/fixtures/invalid/missing-domain.yaml` - Valid YAML without domain field (triggers EXIT_PARSE_ERROR)
- `test/unit/display.bats` - 11 tests for pass/fail/header output formatting
- `test/unit/scenario.bats` - 26 tests for scenario_load, discover, filter, setup, cleanup

## Decisions Made

- Followed absolute path bats loading pattern (same as cluster.bats/common.bats) instead of load "../helpers/test-helper" — the test-helper.bash uses relative `load` calls that don't resolve correctly from unit/ subdirectory
- Used bash -c subshell with command() override for helm mock — _mock_command_missing creates a stub that exits 127 but `command -v` still finds the file in PATH, so it doesn't simulate a missing command
- Grep path-counting in duplicate ID test uses `grep "\.yaml$" | grep -vc "\[WARN\]"` to exclude WARN lines that also mention the file path

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed bats test helper loading approach**
- **Found during:** Task 2 (unit test creation)
- **Issue:** Using `load "../helpers/test-helper"` failed because test-helper.bash uses relative `load "bats-support/load"` which resolves relative to the test file's directory (test/unit/) not the helpers directory
- **Fix:** Used absolute path loading pattern `load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"` directly in each .bats file, consistent with existing cluster.bats and common.bats
- **Files modified:** test/unit/display.bats, test/unit/scenario.bats
- **Verification:** All tests pass: `bats test/unit/display.bats test/unit/scenario.bats`
- **Committed in:** 498c98f (Task 2 commit)

**2. [Rule 1 - Bug] Fixed helm-missing mock using command() override**
- **Found during:** Task 2 (scenario_setup helm test)
- **Issue:** _mock_command_missing creates a stub script in PATH that exits 127, but `command -v helm` checks for binary existence in PATH (not exit code) — the stub file exists, so command -v succeeds
- **Fix:** Used bash -c subshell with `command()` function override (same pattern as cluster.bats) to intercept `command -v helm` specifically
- **Files modified:** test/unit/scenario.bats
- **Verification:** Test 26 passes: "scenario_setup: errors when helm required but not installed"
- **Committed in:** 498c98f (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bugs in test approach)
**Impact on plan:** Both fixes purely in test implementation, no changes to lib code. No scope creep.

## Issues Encountered

- Grep counting in duplicate ID test counted WARN lines (which contain "second.yaml") as file paths — fixed by anchoring grep to lines ending in `.yaml` and excluding [WARN] prefix lines

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- display.sh and scenario.sh fully implemented and tested, ready for Plan 02-02 (validator.sh)
- validator.sh will import display.sh pass/fail and be called after scenario_load sets SCENARIO_* globals
- All 73 unit tests pass including Phase 1 tests — no regressions

## Self-Check: PASSED

All created files verified present on disk. Both task commits (315f569, 498c98f) verified in git log.

---
*Phase: 02-scenario-validation-engine*
*Completed: 2026-02-28*

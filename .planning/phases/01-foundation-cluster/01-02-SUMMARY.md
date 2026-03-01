---
phase: 01-foundation-cluster
plan: 02
subsystem: testing
tags: [bash, bats, shellcheck, bats-support, bats-assert, unit-testing]

# Dependency graph
requires:
  - phase: 01-01
    provides: "lib/common.sh output functions, exit codes, constants; lib/cluster.sh cluster_check_deps and lifecycle functions"
provides:
  - "test/unit/common.bats — 19 tests for info/warn/error/success output functions, cluster constants, exit codes, XDG paths"
  - "test/unit/cluster.bats — 17 tests for cluster_check_deps collect-all-missing pattern (mocked), addon version pinning, lifecycle function existence"
  - "test/helpers/test-helper.bash — shared bats setup with CKAD_DRILL_ROOT, bats library loading, mock command helpers"
  - "scripts/dev-setup.sh — installs bats-core, shellcheck, bats-support, bats-assert"
  - "make test-unit and make shellcheck both verified working"
affects:
  - "all future phases: test infrastructure available for any new lib functions"
  - "02-scenario-engine: can add test/unit/scenario.bats using same pattern"

# Tech tracking
tech-stack:
  added:
    - "bats-core 1.13.0 (bash testing framework)"
    - "bats-support (bats test helper: output/failure formatting)"
    - "bats-assert (bats assertion library)"
    - "shellcheck (static analysis for bash)"
  patterns:
    - "Subshell isolation for tests that re-source common.sh (avoids readonly variable conflicts)"
    - "command() function override in bash subshell for mocking command -v checks"
    - "CKAD_DRILL_ROOT resolved from BATS_TEST_FILENAME — works regardless of cwd"
    - "skip directive for tests requiring system state (kind cluster)"

key-files:
  created:
    - "scripts/dev-setup.sh"
    - "test/helpers/test-helper.bash"
    - "test/unit/common.bats"
    - "test/unit/cluster.bats"
  modified:
    - ".gitignore"

key-decisions:
  - "Re-source tests run in subshells (bash -c) — common.sh uses readonly so re-sourcing in same process fails with 'readonly variable' error"
  - "command() function override preferred over PATH manipulation for mocking command -v — simpler and more reliable for subshell tests"
  - "bats-support and bats-assert installed as git clones into test/helpers/ (gitignored) — keeps them out of repo but available after dev-setup.sh"

patterns-established:
  - "Test files resolve repo root via BATS_TEST_FILENAME — no assumption about cwd"
  - "Integration tests (requiring cluster) deferred — test/unit/ only contains tests that run without Docker/kind"
  - "shellcheck applied to scripts/ and test/helpers/ in addition to lib/ and bin/"

requirements-completed:
  - CLST-01
  - CLST-02
  - CLST-03
  - CLST-04
  - CLST-05

# Metrics
duration: 3min
completed: 2026-02-28
---

# Phase 1 Plan 2: Test Infrastructure + Unit Tests Summary

**bats-core unit test suite (36 tests) covering common.sh output functions and cluster.sh dep checking, runnable without Docker or kind via command() mocking**

## Performance

- **Duration:** ~3 minutes
- **Started:** 2026-02-28T20:01:56Z
- **Completed:** 2026-02-28T20:04:52Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- 36 unit tests across common.bats (19) and cluster.bats (17), all passing without a running cluster
- collect-all-missing dep checker tested with command() override mocking — verifies kind AND kubectl AND yq AND jq all appear in one output pass
- docker daemon detection tested separately from docker binary check
- dev-setup.sh automates full dev environment bootstrap (bats-core, shellcheck, bats-support, bats-assert) across macOS/Linux

## Task Commits

Each task was committed atomically:

1. **Task 1: Create dev-setup.sh and test helper infrastructure** - `63b5482` (feat)
2. **Task 2: Write unit tests for common.sh and cluster.sh dep checking** - `8f79f7d` (feat)

**Plan metadata:** `81f59d9` (docs: complete plan)

## Files Created/Modified

- `scripts/dev-setup.sh` - Bootstrap script: installs bats-core, shellcheck, bats-support, bats-assert (macOS/Linux paths, gitignored clone dirs)
- `test/helpers/test-helper.bash` - Shared bats setup: CKAD_DRILL_ROOT resolution, bats library loading, _mock_command_missing/_mock_command_present helpers
- `test/unit/common.bats` - 19 tests: info/warn/error/success output format, stdout vs stderr routing, error() non-exit behavior, cluster constants, exit codes, XDG path resolution
- `test/unit/cluster.bats` - 17 tests: CALICO/INGRESS/METRICS version pattern checks, cluster_check_deps mocked for all failure modes, lifecycle function existence
- `.gitignore` - Added test/helpers/bats-support/ and test/helpers/bats-assert/ exclusions

## Decisions Made

- Re-source XDG tests run in `bash -c` subshells: `common.sh` uses `readonly` for exit codes, so re-sourcing in the same bats process raises errors. Subshell isolation is the clean fix.
- `command()` function override chosen over PATH manipulation: overriding the builtin in a bash subshell is more surgical — affects only the specific dep name being tested without impacting other PATH-dependent operations.
- bats-support/bats-assert are gitignored git clones in `test/helpers/` — avoids vendoring 3rd-party test libs in the repo; `scripts/dev-setup.sh` re-bootstraps them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Subshell isolation for re-source tests**
- **Found during:** Task 2 (writing common.bats XDG path tests)
- **Issue:** Tests 17-19 (XDG path tests) failed with "EXIT_OK: readonly variable" when re-sourcing common.sh in the same bats process — common.sh uses `readonly` for exit codes.
- **Fix:** Moved XDG path tests to `bash -c` subshells so each gets a fresh environment
- **Files modified:** test/unit/common.bats
- **Verification:** `bats test/unit/common.bats` — all 19 tests pass including XDG tests
- **Committed in:** 8f79f7d (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for test correctness. No scope creep.

## Issues Encountered

- bats not installed on the system — installed via `npm install -g bats` (bats-core 1.13.0) before running tests. This is expected for a fresh dev environment; dev-setup.sh handles this going forward.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 2 (Scenario Engine) can add `test/unit/scenario.bats` using the same infrastructure
- `test/helpers/test-helper.bash` mock helpers are ready for testing functions that call external tools
- Integration tests (`test/integration/cluster.bats`) remain deferred — requires Docker + kind cluster

---
*Phase: 01-foundation-cluster*
*Completed: 2026-02-28*

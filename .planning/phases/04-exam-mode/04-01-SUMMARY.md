---
phase: 04-exam-mode
plan: "01"
subsystem: exam
tags: [bash, exam-mode, session, jq, yq, bats]

# Dependency graph
requires:
  - phase: 03-cli-drill-mode
    provides: session.sh format, scenario.sh interfaces, bats test patterns
  - phase: 01-foundation-cluster
    provides: common.sh constants, EXIT_* codes, output functions
provides:
  - lib/exam.sh exam session engine (select, write, read, navigate, flag, grade)
  - CKAD domain-weighted question selection (D1:20%, D2:20%, D3:15%, D4:25%, D5:20%)
  - Atomic jq-based multi-question session state management
affects:
  - 04-02-PLAN.md (CLI wiring — sources exam.sh and calls all functions)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "exam_session_write uses mode=exam with questions array extending drill session format"
    - "Domain weights as readonly constant string 'D:N D:N...' for zero-subshell parsing"
    - "jq-native grading via reduce+group_by — no bash loops over questions at runtime"
    - "Flagged icon [?] overrides status icon in exam_list display"

key-files:
  created:
    - lib/exam.sh
    - test/unit/exam.bats
  modified: []

key-decisions:
  - "D3 target set to 3 (not 2) to reach total of 16 with integer math: 3+3+3+4+3=16"
  - "exam_select_questions takes file paths as args (not internal discover) to allow caller-controlled pool"
  - "exam_grade implemented in pure jq (single jq invocation) for correctness and speed"
  - "flagged=true overrides status icon in exam_list — [?] displayed instead of [ ]/[+]/[x]"

patterns-established:
  - "Exam session extends drill session.json schema: adds questions[], current_question, replaces scenario_id"
  - "All session mutations use atomic tmp+mv jq writes — consistent with session.sh and progress.sh"
  - "exam_session_read returns EXIT_NO_SESSION for both missing file and non-exam mode sessions"

requirements-completed:
  - EXAM-01
  - EXAM-02
  - EXAM-03
  - EXAM-04
  - EXAM-05
  - EXAM-06
  - EXAM-09
  - EXAM-10

# Metrics
duration: 9min
completed: "2026-03-01"
---

# Phase 4 Plan 1: Exam Session Engine Summary

**Exam session engine in lib/exam.sh with CKAD domain-weighted question selection, atomic JSON state, navigation/flagging, and jq-native 66% grading — 39 unit tests passing**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-01T00:56:07Z
- **Completed:** 2026-03-01T01:05:57Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- `lib/exam.sh` (458 lines) implements all exam session engine functions
- CKAD domain weighting: D1:3, D2:3, D3:3, D4:4, D5:3 questions (total 16)
- `exam_grade` uses single jq invocation with group_by+reduce for per-domain breakdown
- 39 unit tests in `test/unit/exam.bats` — all passing, shellcheck clean

## Task Commits

Each task was committed atomically with TDD:

1. **RED: Failing tests** - `32ed59d` (test)
2. **GREEN: Implementation + test fix** - `625ce59` (feat)

**Plan metadata:** (docs commit — created in this step)

_Note: TDD task — RED commit (failing tests) followed by GREEN commit (implementation + test correction)_

## Files Created/Modified
- `/home/jeff/Projects/cka/lib/exam.sh` - Exam session engine: select, write, read, list, navigate, flag, grade, setup/cleanup namespaces
- `/home/jeff/Projects/cka/test/unit/exam.bats` - 39 unit tests covering all exam functions

## Decisions Made
- **D3 target = 3, not 2**: Integer math 3+3+3+4+3=16 totals cleanly; plan spec said "distribute remainder to D3"
- **exam_select_questions takes file paths as args**: Caller controls the discovery pool — enables custom exam pools in future; CLI wiring calls scenario_discover and passes results
- **jq-native grading**: Single jq invocation with group_by+reduce for per-domain breakdown; no bash loops over questions for correctness and performance
- **[?] icon overrides status**: When a question is flagged, the [?] icon replaces whatever status icon would show — makes flagged state always visible

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed 11/16 pass threshold test using all 24 fixture files**
- **Found during:** Task 1 (TDD GREEN — running tests)
- **Issue:** Test collected all 24 fixture files, passed them to exam_session_write, then checked 11/24 (45.8%) as >= 66% — this was wrong
- **Fix:** Updated test to call exam_select_questions 16 first to get exactly 16 files before writing session
- **Files modified:** test/unit/exam.bats
- **Verification:** Test 30 now passes; 11/16 = 68.75% correctly returns pass=true
- **Committed in:** 625ce59 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - test logic bug)
**Impact on plan:** Test was verifying incorrect math. Fix ensures test correctly validates the 66% threshold spec.

## Issues Encountered
None beyond the test logic bug documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `lib/exam.sh` is complete and ready for Plan 02 CLI wiring
- All functions have clear signatures matching Plan 02's interface expectations
- Plan 02 needs to: call exam_select_questions with scenario_discover output, wire exam start/stop/navigate/flag/grade to ckad-drill subcommands

---
*Phase: 04-exam-mode*
*Completed: 2026-03-01*

---
phase: 04-exam-mode
verified: 2026-02-28T03:30:00Z
status: passed
score: 6/6 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Run ckad-drill exam with a live cluster, navigate between questions, and submit"
    expected: "Questions appear, navigation works, PASS/FAIL result shows per-domain breakdown"
    why_human: "Requires live kind cluster, actual kubectl namespace creation, and end-to-end CLI interaction"
  - test: "Trigger Ctrl+C during an active exam session"
    expected: "All exam namespaces are deleted and session file is cleared"
    why_human: "Trap handler behavior under signal cannot be verified with bats unit tests alone"
---

# Phase 4: Exam Mode Verification Report

**Phase Goal:** A user can run a full 2-hour mock exam with multiple questions, navigation, and graded results
**Verified:** 2026-02-28T03:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | exam_select_questions picks 15-20 scenarios weighted by CKAD domain percentages | VERIFIED | lib/exam.sh lines 33-118; domain weights D1:3 D2:3 D3:3 D4:4 D5:3 (16 total); 4 tests pass including "domain 4 gets most questions" and "all 5 domains represented" |
| 2 | exam_session_write creates a session.json with mode=exam, all question entries, and a global timer | VERIFIED | lib/exam.sh lines 123-192; atomic jq write with mode="exam", questions[], current_question=0, end_at epoch, time_limit=7200; 6 tests verify JSON structure |
| 3 | exam_list outputs all questions with status icons (pending/passed/failed/flagged) | VERIFIED | lib/exam.sh lines 247-290; icons [ ] [+] [x] [?]; current marker >; 6 tests verify all icon types |
| 4 | exam_navigate allows next/prev/jump to change current question index | VERIFIED | lib/exam.sh lines 295-336; clamps at bounds (no wrap); 5 tests pass including boundary clamping |
| 5 | exam_flag toggles a flag on the current question | VERIFIED | lib/exam.sh lines 340-360; toggles true/false with atomic write; 2 tests verify toggle behavior |
| 6 | exam_grade computes per-domain scores and overall pass/fail at 66% threshold | VERIFIED | lib/exam.sh lines 365-406; pure jq group_by+reduce; 11/16 = 68.75% passes, 10/16 = 62.5% fails; 8 tests verify all cases |
| 7 | ckad-drill exam starts a mock exam with weighted questions, all namespaces created, and global 2-hour timer | VERIFIED | bin/ckad-drill _exam_start() lines 58-114; calls scenario_discover + exam_select_questions + exam_session_write + exam_setup_all_namespaces; trap installed before namespace creation |
| 8 | ckad-drill exam list/next/prev/jump/flag navigate and manage exam questions | VERIFIED | bin/ckad-drill lines 552-581; all subcommands dispatch to exam_list, exam_navigate, exam_flag |
| 9 | ckad-drill check during exam validates only the current question without showing hints or solutions | VERIFIED | bin/ckad-drill lines 431-462; branches on SESSION_MODE=="exam", calls validator_run_checks then exam_update_question_status; test "check: updates question status to failed in exam mode" passes; no progress.json written |
| 10 | ckad-drill exam submit grades all questions and shows PASS/FAIL result | VERIFIED | bin/ckad-drill _exam_submit() lines 119-149; calls exam_grade, displays per-domain breakdown and PASS/FAIL with 66% threshold |
| 11 | Exam results are recorded to progress.json | VERIFIED | lib/progress.sh lines 119-143 progress_record_exam; bin/ckad-drill line 144 calls it on submit; 8 tests in progress.bats verify all fields |
| 12 | All exam namespaces are cleaned up on submit or Ctrl+C | VERIFIED | exam_cleanup_all_namespaces in lib/exam.sh lines 436-458; called in _exam_submit and _exam_cleanup trap; session_clear called in both paths |

**Score:** 12/12 truths verified (all truths from both plans combined)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/exam.sh` | Exam session engine with selection, navigation, flagging, and grading; min 200 lines | VERIFIED | 458 lines; all required functions present: exam_select_questions, exam_session_write, exam_session_read, exam_list, exam_navigate, exam_flag, exam_grade, exam_update_question_status, exam_current_question, exam_setup_all_namespaces, exam_cleanup_all_namespaces |
| `test/unit/exam.bats` | Unit tests for exam session functions; min 100 lines | VERIFIED | 650 lines; 39 tests, all passing |
| `bin/ckad-drill` | Exam subcommands wired into CLI dispatch; contains "exam)" | VERIFIED | 635 lines; contains exam) dispatch at line 544; _exam_start, _exam_submit helpers; all subcommands wired |
| `lib/progress.sh` | progress_record_exam function for exam results; contains "progress_record_exam" | VERIFIED | 224 lines; function at lines 119-143; atomic write, 8 tests pass |
| `test/unit/drill.bats` | Regression tests for exam CLI paths | VERIFIED | 24 tests total; 4 exam-specific tests (hint blocked, solution blocked, check in exam mode, exam in help) |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| lib/exam.sh | lib/session.sh | CKAD_SESSION_FILE constant | VERIFIED | exam.sh reads/writes CKAD_SESSION_FILE at 12 locations; calls session_clear in exam_cleanup_all_namespaces |
| lib/exam.sh | lib/scenario.sh | scenario_discover and scenario_load for question selection | PARTIAL | exam.sh does NOT call scenario_discover or scenario_load internally; instead uses yq directly on file paths for performance (D1 decision documented in SUMMARY). The caller (_exam_start in bin/ckad-drill) calls scenario_discover and passes results to exam_select_questions. Functional requirement is fully met; the boundary is at the caller level, not within exam.sh itself. This is an intentional architectural decision. |
| bin/ckad-drill | lib/exam.sh | source and function calls | VERIFIED | Line 24: source "${CKAD_DRILL_ROOT}/lib/exam.sh"; calls exam_select_questions, exam_session_write, exam_session_read, exam_setup_all_namespaces, exam_cleanup_all_namespaces, exam_navigate, exam_list, exam_flag, exam_grade, exam_update_question_status |
| bin/ckad-drill | lib/progress.sh | progress_record_exam call on submit | VERIFIED | Line 144: progress_record_exam "${score}" "${passed}" "${domain_results}" in _exam_submit |
| bin/ckad-drill check | lib/exam.sh | exam_session_read to detect exam mode, exam_update_question_status to record result | VERIFIED | Lines 434, 438, 441: exam_session_read; exam_update_question_status called for both pass and fail cases |

**Note on key_link deviation:** Plan 01 specified `exam.sh` would call `scenario_discover\|scenario_load` directly. The executor made an intentional design decision (documented in SUMMARY key-decisions) to have exam.sh accept file paths as arguments from the caller, using yq directly for domain extraction instead of full scenario_load. This is architecturally sound (separation of discovery from selection) and all functions are verified to work correctly end-to-end.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EXAM-01 | 04-01 | ckad-drill exam starts a mock exam with 15-20 questions weighted by CKAD domain percentages | SATISFIED | exam_select_questions implemented with D1:3 D2:3 D3:3 D4:4 D5:3; _exam_start wired in bin/ckad-drill; 4 selection tests pass |
| EXAM-02 | 04-01 | All exam namespaces are created at exam start | SATISFIED | exam_setup_all_namespaces called in _exam_start before first question display |
| EXAM-03 | 04-01 | Global timer (default 2 hours, configurable with --time) | SATISFIED | _exam_start accepts --time flag (line 62-64); exam_end_at computed as date+%s + exam_time; stored in session.json end_at field |
| EXAM-04 | 04-01 | ckad-drill exam list shows all questions with status icons | SATISFIED | exam_list function; exam list) dispatch in bin/ckad-drill line 552; 6 icon tests pass |
| EXAM-05 | 04-01 | ckad-drill exam next/prev/jump N navigates between questions | SATISFIED | exam_navigate; next/prev/jump dispatch lines 556-579; 5 navigation tests pass including boundary clamping |
| EXAM-06 | 04-01 | ckad-drill exam flag flags current question for review | SATISFIED | exam_flag; flag) dispatch line 581; 2 toggle tests pass |
| EXAM-07 | 04-02 | ckad-drill check during exam validates only the current question | SATISFIED | check) at line 431 branches on SESSION_MODE=="exam"; calls validator_run_checks on EXAM_CURRENT_FILE; updates question status; does not record to progress.json; test passes |
| EXAM-08 | 04-02 | Hints and solutions are blocked during exam mode | SATISFIED | hint) at line 465 and solution) at line 475 check SESSION_MODE=="exam" and exit EXIT_ERROR; 2 tests verify blocking behavior |
| EXAM-09 | 04-01 | ckad-drill exam submit grades all questions, shows per-domain scores | SATISFIED | _exam_submit calls exam_grade; displays per-domain via jq; grade outputs domains[] array |
| EXAM-10 | 04-01 | Pass threshold is 66% — clear PASS/FAIL display | SATISFIED | exam_grade: `($score >= 66)` as pass boolean; _exam_submit: "RESULT: PASS" / "RESULT: FAIL (66% required)"; 6 grade threshold tests pass |
| EXAM-11 | 04-02 | Exam results recorded to progress.json | SATISFIED | progress_record_exam called in _exam_submit line 144; appends to .exams[]; 8 tests in progress.bats verify all fields (date, score, passed, domains) |
| EXAM-12 | 04-02 | All exam namespaces cleaned up on submit or Ctrl+C | SATISFIED | exam_cleanup_all_namespaces called in _exam_submit line 147 and _exam_cleanup trap line 50; session_clear called in both paths |

**All 12 requirements satisfied. No orphaned requirements.**

---

### Anti-Patterns Found

No anti-patterns found across all modified files:

- No TODO/FIXME/PLACEHOLDER comments
- No empty implementations (return null/return {}/return [])
- No stub handlers
- shellcheck reports zero errors on lib/exam.sh, bin/ckad-drill, lib/progress.sh

---

### Human Verification Required

#### 1. Full End-to-End Exam Workflow

**Test:** With a running kind cluster, run `ckad-drill exam`, then `ckad-drill exam list`, navigate with `ckad-drill exam next`, run `ckad-drill check`, and finally `ckad-drill exam submit`
**Expected:** Questions display with task descriptions, navigation updates the current marker in list, check validates and marks question status, submit shows per-domain scores and PASS/FAIL result
**Why human:** Requires a live kind cluster with actual kubectl, real namespace creation, and interactive terminal flow

#### 2. Ctrl+C Cleanup During Exam

**Test:** Start `ckad-drill exam`, verify namespaces are created with `kubectl get ns`, then press Ctrl+C
**Expected:** All exam namespaces are deleted and session.json is removed
**Why human:** Signal trap behavior under interactive terminal cannot be unit-tested; requires live cluster and manual signal delivery

---

### Gaps Summary

No gaps. All phase 4 must-haves are verified:

- `lib/exam.sh` (458 lines) implements all exam engine functions with atomic jq writes and correct CKAD domain weighting
- `test/unit/exam.bats` (650 lines, 39 tests) verifies all core functions — all passing
- `bin/ckad-drill` fully wired with exam subcommands, exam mode guardrails, and cleanup trap
- `lib/progress.sh` extended with `progress_record_exam` — 8 tests verify all fields
- `test/unit/drill.bats` extended with 4 exam regression tests — all 24 tests passing
- `test/unit/progress.bats` extended with 8 exam result tests — all 31 tests passing
- shellcheck reports zero errors on all modified files
- All 12 EXAM-* requirements (EXAM-01 through EXAM-12) satisfied and cross-referenced

The one key_link deviation (exam.sh not calling scenario_discover directly) is an intentional architectural decision documented in the SUMMARY and does not affect goal achievement — discovery happens in the CLI layer (_exam_start) and results are passed into exam_select_questions.

---

_Verified: 2026-02-28T03:30:00Z_
_Verifier: Claude (gsd-verifier)_

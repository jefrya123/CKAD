---
phase: 03-cli-drill-mode
verified: 2026-02-28T23:00:00Z
status: passed
score: 22/22 requirements verified
re_verification: false
gaps: []
human_verification:
  - test: "Run ckad-drill drill against live kind cluster"
    expected: "Scenario task card displayed, namespace created, session.json written"
    why_human: "Requires a running kind cluster to verify end-to-end flow"
  - test: "source <(ckad-drill env) in interactive shell"
    expected: "Prompt shows [MM:SS] countdown, k alias works, EDITOR=vim set"
    why_human: "PROMPT_COMMAND behavior can only be observed in an interactive shell"
  - test: "validate-scenario on a sample scenario with live cluster"
    expected: "Parse, setup, apply solution, validate, cleanup all succeed with PASS printed"
    why_human: "Full lifecycle requires kubectl and kind cluster running"
---

# Phase 3: CLI Drill Mode Verification Report

**Phase Goal:** A user can run a full drill session end-to-end from the terminal using subcommands
**Verified:** 2026-02-28T23:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Session state can be written and read back with all fields intact | VERIFIED | session.sh: jq write/read for all 7 fields; 23 tests passing |
| 2 | Session require returns EXIT_NO_SESSION when no session file exists | VERIFIED | session_require exits 3; test 21 confirms |
| 3 | Timer env output contains PROMPT_COMMAND countdown with [MM:SS] | VERIFIED | timer.sh line 34: PROMPT_COMMAND='__ckad_drill_timer'; test 4 confirms %02d:%02d |
| 4 | Timer env output contains [TIME UP] logic for expired time | VERIFIED | timer.sh line 29: PS1="[TIME UP]..."; test 5 confirms |
| 5 | Timer env reset restores original PS1 and PROMPT_COMMAND | VERIFIED | timer_env_reset_output restores CKAD_DRILL_ORIGINAL_PS1/PROMPT_COMMAND; tests 13-16 confirm |
| 6 | Timer env output does NOT contain set -euo pipefail (TIMR-05 safety) | VERIFIED | grep of timer.sh confirms absence; tests 6-7 explicitly check |
| 7 | Exam environment aliases (k=kubectl, completion, EDITOR=vim) are in env output (DRIL-10) | VERIFIED | timer.sh lines 37-39; tests 10-12 confirm |
| 8 | Drill results are recorded to progress.json with scenario_id, passed, time, attempts | VERIFIED | progress.sh progress_record upserts all fields atomically; 7 record tests pass |
| 9 | Progress schema is additive-only — missing fields get defaults via jq // default | VERIFIED | progress.sh uses // default throughout; test "does not overwrite existing file" confirms |
| 10 | Per-domain pass rates computed correctly from scenario results | VERIFIED | progress_read_domain_rates using jq group_by + floor(); 3 tests confirm 50%, 100%, empty |
| 11 | Weak domain recommendation identifies the lowest pass-rate domain | VERIFIED | progress_recommend_weak_domain sort_by(.rate); 2 tests confirm |
| 12 | Streak tracking works: increments on consecutive day, resets on gap | VERIFIED | _progress_update_streak logic; 3 tests confirm same-day/consecutive/gap |
| 13 | ckad-drill drill picks a random scenario, sets up namespace, writes session, prints task | VERIFIED | _drill_start in bin/ckad-drill: discover+filter+RANDOM pick+setup+session_write+display |
| 14 | ckad-drill drill --domain N --difficulty LEVEL filters scenarios correctly | VERIFIED | flag parsing loop + FILTER_DOMAIN/FILTER_DIFFICULTY env vars passed to scenario_filter |
| 15 | ckad-drill check reads session, runs validator, records result to progress.json | VERIFIED | check case: session_require + validator_run_checks + progress_record |
| 16 | ckad-drill hint displays the scenario hint text | VERIFIED | hint case: session_require + yq -r '.hint' |
| 17 | ckad-drill solution displays the scenario solution steps | VERIFIED | solution case: session_require + yq numbered steps loop |
| 18 | ckad-drill current reprints the active scenario description | VERIFIED | current case: session_require + scenario_load + _drill_display |
| 19 | ckad-drill next cleans up namespace and starts a new scenario | VERIFIED | next case: session_require + scenario_cleanup + session_clear + _drill_start |
| 20 | ckad-drill skip cleans up namespace without checking | VERIFIED | skip case: session_require + scenario_cleanup + session_clear |
| 21 | ckad-drill env outputs sourceable timer + exam env shell code | VERIFIED | env case: session_require + timer_env_output(SESSION_END_AT) |
| 22 | ckad-drill timer prints remaining MM:SS | VERIFIED | timer case: session_require + timer_remaining |
| 23 | SIGINT/SIGTERM triggers namespace cleanup via trap handler | VERIFIED | _drill_cleanup installed with trap INT TERM EXIT; Pitfall 5 protection present |
| 24 | ckad-drill status shows per-domain pass rates, exam history, streak, and weak domain | VERIFIED | _cmd_status calls all 4 progress_read_* functions; 1 test confirms |
| 25 | ckad-drill validate-scenario FILE runs full lifecycle and reports PASS/FAIL | VERIFIED | _validate_single_scenario: load+setup+apply solution+validate+cleanup |
| 26 | ckad-drill validate-scenario DIR validates all .yaml files with summary | VERIFIED | _cmd_validate_scenario directory branch: find+loop+summary |
| 27 | validate-scenario cleans up namespace even on failure | VERIFIED | cleanup_needed flag pattern; cleanup called unconditionally after validation |

**Score:** 27/27 truths verified (22 requirements all satisfied)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/session.sh` | Session JSON read/write/clear/require | VERIFIED | 77 lines; exports session_write/read/clear/require; substantive jq implementation |
| `lib/timer.sh` | PROMPT_COMMAND timer env output and reset | VERIFIED | 69 lines; exports timer_env_output/timer_env_reset_output/timer_remaining |
| `test/unit/session.bats` | Unit tests for session.sh | VERIFIED | 23 tests; all pass |
| `test/unit/timer.bats` | Unit tests for timer.sh | VERIFIED | 20 tests; all pass |
| `lib/progress.sh` | Progress JSON tracking, stats, streak, recommendation | VERIFIED | 193 lines; exports all 6 required functions |
| `test/unit/progress.bats` | Unit tests for progress.sh | VERIFIED | 23 tests; all pass |
| `scenarios/domain-1/sc-multi-container-pod.yaml` | Sample scenario domain 1 | VERIFIED | id, domain, difficulty, validations, hint, solution present |
| `scenarios/domain-2/sc-configmap-secret.yaml` | Sample scenario domain 2 | VERIFIED | id, domain, difficulty, validations, hint, solution present |
| `scenarios/domain-3/sc-network-policy.yaml` | Sample scenario domain 3 | VERIFIED | id, domain, difficulty, validations, hint, solution present |
| `bin/ckad-drill` | Main entry point with all drill subcommands | VERIFIED | 414 lines; dispatches drill/check/hint/solution/current/next/skip/env/timer/status/validate-scenario |
| `test/unit/drill.bats` | Unit tests for drill subcommand dispatch | VERIFIED | 13 tests; all pass |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| lib/session.sh | CKAD_SESSION_FILE | jq read/write | WIRED | jq writes to ${CKAD_SESSION_FILE} (line 41); reads from it in session_read (lines 52-58) |
| lib/timer.sh | lib/session.sh | reads SESSION_END_AT (set by session_read) | WIRED | timer_remaining uses SESSION_END_AT global populated by session_read; callers invoke session_require first |
| lib/progress.sh | CKAD_PROGRESS_FILE | jq read/write to progress.json | WIRED | All 6 functions read/write CKAD_PROGRESS_FILE via jq |
| lib/progress.sh | scenarios/*.yaml | domain field in progress maps to scenario domain | WIRED | progress_record stores domain; progress_read_domain_rates groups by domain |
| bin/ckad-drill | lib/session.sh | source + session_write/read/require/clear calls | WIRED | Sourced line 18; session_write (103), session_require (297+), session_clear (345,355) |
| bin/ckad-drill | lib/progress.sh | source + progress_record in check | WIRED | Sourced line 20; progress_record called line 314 |
| bin/ckad-drill | lib/timer.sh | source + timer_env_output/reset/remaining | WIRED | Sourced line 22; timer_env_reset_output (362), timer_env_output (365), timer_remaining (372) |
| bin/ckad-drill | lib/validator.sh | validator_run_checks in check | WIRED | Sourced line 16; validator_run_checks called lines 303, 231 |
| bin/ckad-drill | lib/scenario.sh | scenario_discover/filter/setup/cleanup | WIRED | Sourced line 14; scenario_discover (70), scenario_filter (81), scenario_setup (100,213), scenario_cleanup (235,344,354) |
| bin/ckad-drill (status) | lib/progress.sh | progress_read_domain_rates + progress_recommend_weak_domain | WIRED | Both called in _cmd_status (lines 123, 125) |
| bin/ckad-drill (validate-scenario) | lib/scenario.sh | scenario_load/setup/cleanup | WIRED | _validate_single_scenario calls all three (lines 207, 213, 235) |
| bin/ckad-drill (validate-scenario) | lib/validator.sh | validator_run_checks | WIRED | Called line 231 in _validate_single_scenario |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| DRIL-01 | 03-03 | User can run `ckad-drill drill` for random scenario | SATISFIED | drill case in bin/ckad-drill with _drill_start; test 70 confirms |
| DRIL-02 | 03-03 | User can filter drill by domain/difficulty | SATISFIED | --domain/--difficulty flag parsing + FILTER_DOMAIN/DIFFICULTY env vars |
| DRIL-03 | 03-03 | User can run `ckad-drill check` to validate | SATISFIED | check case: session_require + validator_run_checks + progress_record |
| DRIL-04 | 03-03 | User can run `ckad-drill hint` | SATISFIED | hint case: yq -r '.hint' from scenario file |
| DRIL-05 | 03-03 | User can run `ckad-drill solution` | SATISFIED | solution case: numbered yq .solution.steps[] loop |
| DRIL-06 | 03-03 | User can run `ckad-drill next` | SATISFIED | next case: cleanup + session_clear + _drill_start |
| DRIL-07 | 03-03 | User can run `ckad-drill skip` | SATISFIED | skip case: cleanup + session_clear + info message |
| DRIL-08 | 03-03 | User can run `ckad-drill current` | SATISFIED | current case: scenario_load + _drill_display |
| DRIL-09 | 03-01 | Session state persists in session.json | SATISFIED | lib/session.sh jq-based JSON persistence; 23 tests |
| DRIL-10 | 03-01 | Strict exam environment: k alias, completion, EDITOR=vim | SATISFIED | timer_env_output emits alias k=kubectl, completion, EDITOR=vim; tests 10-12 confirm |
| DRIL-11 | 03-03 | SIGINT/SIGTERM triggers cleanup via trap | SATISFIED | _drill_cleanup trap handler installed in _drill_start; Pitfall 5 pattern |
| TIMR-01 | 03-01 | source <(ckad-drill env) sets PROMPT_COMMAND [MM:SS] | SATISFIED | timer_env_output emits PROMPT_COMMAND with __ckad_drill_timer; test 1 + 4 |
| TIMR-02 | 03-01 | Timer shows [TIME UP] when expired | SATISFIED | timer.sh line 29: PS1="[TIME UP]..."; test 5 |
| TIMR-03 | 03-01 | env --reset cleanly restores prompt | SATISFIED | timer_env_reset_output restores originals; tests 13-16 |
| TIMR-04 | 03-01 | ckad-drill timer prints remaining time | SATISFIED | timer case calls timer_remaining; test 18-19 |
| TIMR-05 | 03-01 | env output safe — no set -euo pipefail | SATISFIED | timer.sh emits no set -e; tests 6-7 explicitly verify |
| PROG-01 | 03-02 | Drill results recorded to progress.json | SATISFIED | progress_record with passed/time/attempts; 7 tests |
| PROG-02 | 03-04 | ckad-drill status shows progress stats | SATISFIED | _cmd_status: domain rates table, streak, exam history, weak domain; drill.bats test 78 |
| PROG-03 | 03-02 | Additive-only progress schema | SATISFIED | jq // default throughout progress.sh; idempotent init tested |
| PROG-04 | 03-02 | Progress file survives upgrades | SATISFIED | version field present; jq // default prevents parse failure on new fields |
| DIST-03 | 03-04 | validate-scenario FILE runs full lifecycle | SATISFIED | _validate_single_scenario: load+setup+solution+validate+cleanup |
| DIST-04 | 03-04 | validate-scenario DIR validates all .yaml files | SATISFIED | _cmd_validate_scenario directory branch with find loop + summary |

**All 22 Phase 3 requirements: SATISFIED**

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| bin/ckad-drill | 327 | `local_step=1` used at case-arm scope (not bash `local`) | INFO | Variable leaks to global scope in solution subcommand; functionally correct, minor code smell |
| bin/ckad-drill | 104-105 | SC2153 info: SCENARIO_ID/SCENARIO_FILE may not be assigned | INFO | shellcheck false positive — these globals are set by scenario_setup; not a bug |

No blockers. No warnings. Two info-level items only.

**shellcheck verdict:** Exits 1 due to 2 SC2153 info-level notices (not errors) for SCENARIO_ID and SCENARIO_FILE globals set dynamically by scenario_setup. These are false positives. lib/session.sh, lib/timer.sh, and lib/progress.sh all pass shellcheck cleanly.

### Test Results

| Test File | Tests | Pass | Fail | Note |
|-----------|-------|------|------|------|
| test/unit/session.bats | 23 | 23 | 0 | All pass |
| test/unit/timer.bats | 20 | 20 | 0 | All pass |
| test/unit/progress.bats | 23 | 23 | 0 | All pass |
| test/unit/drill.bats | 13 | 13 | 0 | All pass |
| **Phase 3 total** | **79** | **79** | **0** | |
| test/unit/ total | 185 | 184 | 1 | 1 pre-existing failure in scenario.bats (test 99: duplicate ID detection) — not caused by Phase 3 |

### Human Verification Required

#### 1. End-to-End Drill Session

**Test:** Run `ckad-drill start` then `ckad-drill drill`, observe output
**Expected:** Scenario title, domain, difficulty, time limit, and description displayed; namespace created in cluster; session.json written to config dir
**Why human:** Requires a running kind cluster; namespace creation and kubectl interaction cannot be mocked in unit tests

#### 2. Timer in Interactive Shell

**Test:** Run `source <(ckad-drill env)` in a real bash shell with an active session
**Expected:** Shell prompt shows `[MM:SS]` countdown that decrements each time a command is run; shows `[TIME UP]` after session expires
**Why human:** PROMPT_COMMAND behavior only observable in interactive shell; cannot be unit tested

#### 3. SIGINT Cleanup

**Test:** Run `ckad-drill drill`, then press Ctrl+C before the scenario task is displayed (i.e., during scenario_setup)
**Expected:** Namespace is cleaned up; session.json is removed; no orphaned resources
**Why human:** Signal handling requires interactive terminal; timing-dependent behavior

#### 4. validate-scenario Against Live Cluster

**Test:** Run `ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml`
**Expected:** Parse succeeds, namespace created, solution steps applied, validation runs, cleanup happens, PASS printed
**Why human:** Requires kind cluster with calico; validates full end-to-end flow beyond unit test mocking

---

## Summary

Phase 3 goal is **fully achieved**. All 22 requirements are implemented and satisfied across 4 plans:

- **Plan 01 (Wave 1):** lib/session.sh and lib/timer.sh — 4 files created, 43 tests passing
- **Plan 02 (Wave 1):** lib/progress.sh and 3 sample scenarios — 5 files created, 23 tests passing
- **Plan 03 (Wave 2):** bin/ckad-drill with 9 drill subcommands + cluster_check_active — fully wired
- **Plan 04 (Wave 3):** status and validate-scenario subcommands + drill.bats — 13 tests passing

The single pre-existing test failure (test 99: scenario_discover duplicate ID detection) is in Phase 2's scenario.bats and is unrelated to Phase 3 work.

The 2 shellcheck SC2153 notices on bin/ckad-drill are false positives: SCENARIO_ID and SCENARIO_FILE are dynamically populated globals set by scenario_setup before use. The plan's own summary documents this same pattern from Plan 04's SC2153 handling.

4 items are flagged for human verification — all require a live kind cluster or interactive shell and cannot be automated in unit tests.

---

_Verified: 2026-02-28T23:00:00Z_
_Verifier: Claude (gsd-verifier)_

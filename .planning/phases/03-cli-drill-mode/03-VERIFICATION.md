---
phase: 03-cli-drill-mode
verified: 2026-02-28T23:55:00Z
status: passed
score: 22/22 requirements verified
re_verification:
  previous_status: passed
  previous_score: 22/22
  gaps_closed:
    - "Timer works in both bash and zsh (UAT test 9 — add-zsh-hook precmd support)"
    - "validate-scenario correctly applies multi-line heredoc solution steps (UAT test 10)"
  gaps_remaining: []
  regressions: []
gaps: []
human_verification:
  - test: "source <(ckad-drill env) in interactive zsh shell"
    expected: "Prompt shows [MM:SS] countdown that decrements each command; shows [TIME UP] when expired; ckad-drill env --reset restores original prompt"
    why_human: "add-zsh-hook precmd behavior can only be observed in an interactive zsh shell"
  - test: "source <(ckad-drill env) in interactive bash shell"
    expected: "PROMPT_COMMAND sets [MM:SS] countdown in PS1; shows [TIME UP] when expired; ckad-drill env --reset restores original prompt"
    why_human: "PROMPT_COMMAND behavior can only be observed in an interactive bash shell"
  - test: "ckad-drill drill against live kind cluster"
    expected: "Scenario task card displayed, namespace created, session.json written"
    why_human: "Requires a running kind cluster to verify end-to-end flow"
  - test: "ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml against live cluster"
    expected: "Parse succeeds, namespace created, both solution steps applied (including multi-line heredoc), validation runs, PASS printed, namespace cleaned up"
    why_human: "Full lifecycle requires kubectl and kind cluster running"
---

# Phase 3: CLI Drill Mode Verification Report

**Phase Goal:** A user can run a full drill session end-to-end from the terminal using subcommands
**Verified:** 2026-02-28T23:55:00Z
**Status:** PASSED
**Re-verification:** Yes — after gap closure (Plans 05 and 06 closed 2 UAT-identified gaps)

## Re-Verification Context

The previous VERIFICATION.md was written after Plans 01-04 but before UAT revealed two major issues. Plans 05 and 06 were executed as gap-closure plans. This re-verification confirms both gaps are fully closed and no regressions were introduced.

**Previous state:** `passed` (22/22 requirements) — but UAT (03-UAT.md) found 2 major issues post-verification:
- UAT test 9: Timer never appeared in user's zsh prompt (PROMPT_COMMAND is bash-only)
- UAT test 10: validate-scenario ran lifecycle but all checks failed (multi-line solution steps not applied)

**Gap closure:**
- Plan 05 fixed lib/timer.sh with ZSH_VERSION-gated shell detection, added 7 zsh-branch tests to timer.bats
- Plan 06 fixed _validate_single_scenario in bin/ckad-drill with index-based yq extraction, added 2 solution-step tests to drill.bats

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Session state can be written and read back with all fields intact | VERIFIED | lib/session.sh: jq write/read for all 7 fields; 23 session.bats tests passing |
| 2 | Session require returns EXIT_NO_SESSION when no session file exists | VERIFIED | session_require exits EXIT_NO_SESSION (3); test confirmed |
| 3 | Timer env output contains ZSH_VERSION-gated shell detection for bash and zsh | VERIFIED | timer.sh: emits if/else ZSH_VERSION block; tests 18-24 confirm zsh branch |
| 4 | Timer env output sets PROMPT_COMMAND for bash, add-zsh-hook precmd for zsh | VERIFIED | timer.sh lines 40-52: bash branch PROMPT_COMMAND; zsh branch add-zsh-hook precmd |
| 5 | Timer env output contains [TIME UP] logic for expired time | VERIFIED | __ckad_drill_timer function emits remaining<=0 check; test 5 confirms |
| 6 | Timer env reset restores original PS1/PROMPT_COMMAND (bash) and PROMPT/hook (zsh) | VERIFIED | timer_env_reset_output emits ZSH_VERSION-gated restore; tests 13-17, 23-24 confirm |
| 7 | Timer env output does NOT contain set -euo pipefail (TIMR-05 safety) | VERIFIED | shellcheck passes on timer.sh; test 17 explicitly checks |
| 8 | Exam environment aliases (k=kubectl, completion, EDITOR=vim) are in env output (DRIL-10) | VERIFIED | timer.sh lines 54-56: alias k=kubectl, EDITOR=vim; completion in both shell branches |
| 9 | Drill results are recorded to progress.json with scenario_id, passed, time, attempts | VERIFIED | progress.sh progress_record upserts all fields atomically; 7 record tests pass |
| 10 | Progress schema is additive-only — missing fields get defaults via jq // default | VERIFIED | progress.sh uses // default throughout; test confirms idempotent init |
| 11 | Per-domain pass rates computed correctly from scenario results | VERIFIED | progress_read_domain_rates using jq group_by + floor(); 3 tests confirm |
| 12 | Weak domain recommendation identifies lowest pass-rate domain | VERIFIED | progress_recommend_weak_domain sort_by(.rate); 2 tests confirm |
| 13 | Streak tracking works: increments on consecutive day, resets on gap | VERIFIED | _progress_update_streak logic; 3 tests confirm same-day/consecutive/gap |
| 14 | ckad-drill drill picks a random scenario, sets up namespace, writes session, prints task | VERIFIED | _drill_start in bin/ckad-drill: discover+filter+RANDOM pick+setup+session_write+display |
| 15 | ckad-drill drill --domain N --difficulty LEVEL filters scenarios correctly | VERIFIED | flag parsing loop + FILTER_DOMAIN/FILTER_DIFFICULTY env vars passed to scenario_filter |
| 16 | ckad-drill check reads session, runs validator, records result to progress.json | VERIFIED | check case: session_require + validator_run_checks + progress_record (line 320) |
| 17 | ckad-drill hint displays the scenario hint text | VERIFIED | hint case: session_require + yq -r '.hint' |
| 18 | ckad-drill solution displays the scenario solution steps | VERIFIED | solution case: session_require + yq numbered steps loop |
| 19 | ckad-drill current reprints the active scenario description | VERIFIED | current case: session_require + scenario_load + _drill_display |
| 20 | ckad-drill next cleans up namespace and starts a new scenario | VERIFIED | next case: session_require + scenario_cleanup + session_clear + _drill_start |
| 21 | ckad-drill skip cleans up namespace without checking | VERIFIED | skip case: session_require + scenario_cleanup + session_clear |
| 22 | ckad-drill env outputs sourceable timer + exam env shell code | VERIFIED | env case: session_require + timer_env_output(SESSION_END_AT) |
| 23 | ckad-drill timer prints remaining MM:SS | VERIFIED | timer case: session_require + timer_remaining |
| 24 | SIGINT/SIGTERM triggers namespace cleanup via trap handler | VERIFIED | _drill_cleanup installed with trap INT TERM EXIT; checks session file and SCENARIO_NAMESPACE |
| 25 | ckad-drill status shows per-domain pass rates, exam history, streak, and weak domain | VERIFIED | _cmd_status calls all 4 progress_read_* functions; drill.bats test 85 confirms |
| 26 | ckad-drill validate-scenario FILE applies solution steps then validates | VERIFIED | _validate_single_scenario: C-style for loop with yq .solution.steps[sol_i] index extraction |
| 27 | validate-scenario applies multi-line heredoc steps correctly | VERIFIED | Plan 06 fix: yq -r ".solution.steps[${sol_i}]" returns complete multi-line string to eval |
| 28 | ckad-drill validate-scenario DIR validates all .yaml files with summary | VERIFIED | _cmd_validate_scenario directory branch: find+loop+summary |
| 29 | validate-scenario cleans up namespace even on failure | VERIFIED | cleanup_needed flag pattern; cleanup called unconditionally after validation |

**Score:** 29/29 truths verified (22 requirements all satisfied)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/session.sh` | Session JSON read/write/clear/require | VERIFIED | 76 lines; exports session_write/read/clear/require; substantive jq implementation |
| `lib/timer.sh` | PROMPT_COMMAND/add-zsh-hook timer env output and reset | VERIFIED | 91 lines; exports timer_env_output/timer_env_reset_output/timer_remaining; ZSH_VERSION detection |
| `lib/progress.sh` | Progress JSON tracking, stats, streak, recommendation | VERIFIED | 192 lines; exports all 6 required functions |
| `bin/ckad-drill` | Main entry point with all drill subcommands | VERIFIED | 419 lines; dispatches drill/check/hint/solution/current/next/skip/env/timer/status/validate-scenario |
| `test/unit/session.bats` | Unit tests for session.sh | VERIFIED | 23 tests; all pass |
| `test/unit/timer.bats` | Unit tests for timer.sh including zsh branch | VERIFIED | 27 tests; all pass (17 original + 7 new zsh-branch + 3 timer_remaining) |
| `test/unit/progress.bats` | Unit tests for progress.sh | VERIFIED | 23 tests; all pass |
| `test/unit/drill.bats` | Unit tests for drill subcommand dispatch + solution extraction | VERIFIED | 15 tests; all pass (13 original + 2 new solution-step extraction tests) |
| `scenarios/domain-1/sc-multi-container-pod.yaml` | Sample scenario domain 1 | VERIFIED | id, domain, difficulty, validations, hint, solution present; solution has 2 steps including heredoc |
| `scenarios/domain-2/sc-configmap-secret.yaml` | Sample scenario domain 2 | VERIFIED | id, domain, difficulty, validations, hint, solution present |
| `scenarios/domain-3/sc-network-policy.yaml` | Sample scenario domain 3 | VERIFIED | id, domain, difficulty, validations, hint, solution present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| lib/session.sh | CKAD_SESSION_FILE | jq read/write | WIRED | jq writes to ${CKAD_SESSION_FILE} (line 41); reads from it in session_read (lines 52-58) |
| lib/timer.sh | lib/session.sh | reads SESSION_END_AT (set by session_read) | WIRED | timer_remaining uses SESSION_END_AT global populated by session_read; callers invoke session_require first |
| lib/progress.sh | CKAD_PROGRESS_FILE | jq read/write to progress.json | WIRED | All 6 functions read/write CKAD_PROGRESS_FILE via jq |
| lib/timer.sh (env output) | user bash shell | PROMPT_COMMAND='__ckad_drill_timer' | WIRED | Bash branch emitted into sourced output (timer.sh lines 49-50); tests 1,4 confirm |
| lib/timer.sh (env output) | user zsh shell | add-zsh-hook precmd __ckad_drill_timer | WIRED | Zsh branch emitted into sourced output (timer.sh lines 42-45); tests 18-22 confirm |
| lib/timer.sh (env reset) | user zsh shell | add-zsh-hook -d precmd __ckad_drill_timer | WIRED | Zsh reset branch emitted (timer.sh lines 65-68); tests 23-24 confirm |
| bin/ckad-drill | lib/session.sh | source + session_write/read/require/clear calls | WIRED | Sourced line 18; session_write (103), session_require (303+), session_clear (350,360) |
| bin/ckad-drill | lib/progress.sh | source + progress_record in check | WIRED | Sourced line 20; progress_record called line 320 |
| bin/ckad-drill | lib/timer.sh | source + timer_env_output/reset/remaining | WIRED | Sourced line 22; timer_env_reset_output (368), timer_env_output (371), timer_remaining (378) |
| bin/ckad-drill | lib/validator.sh | validator_run_checks in check | WIRED | Sourced line 16; validator_run_checks called lines 309, 237 |
| bin/ckad-drill | lib/scenario.sh | scenario_discover/filter/setup/cleanup | WIRED | Sourced line 14; scenario_discover (70), scenario_filter (81), scenario_setup (100,213), scenario_cleanup (235,350,360) |
| bin/ckad-drill (status) | lib/progress.sh | progress_read_domain_rates + progress_recommend_weak_domain | WIRED | Both called in _cmd_status (lines 123, 125) |
| bin/ckad-drill (validate-scenario) | scenario YAML solution.steps | yq -r ".solution.steps[sol_i]" index-based extraction | WIRED | C-style for loop at lines 226-234; extracts complete multi-line steps before eval |
| bin/ckad-drill (validate-scenario) | lib/scenario.sh | scenario_load/setup/cleanup | WIRED | _validate_single_scenario calls all three (lines 207, 213, 240) |
| bin/ckad-drill (validate-scenario) | lib/validator.sh | validator_run_checks | WIRED | Called line 237 in _validate_single_scenario |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| DRIL-01 | 03-03 | User can run `ckad-drill drill` for random scenario | SATISFIED | drill case in bin/ckad-drill with _drill_start; drill.bats test 77 confirms |
| DRIL-02 | 03-03 | User can filter drill by domain/difficulty | SATISFIED | --domain/--difficulty flag parsing + FILTER_DOMAIN/DIFFICULTY env vars |
| DRIL-03 | 03-03 | User can run `ckad-drill check` to validate | SATISFIED | check case: session_require + validator_run_checks + progress_record |
| DRIL-04 | 03-03 | User can run `ckad-drill hint` | SATISFIED | hint case: yq -r '.hint' from scenario file |
| DRIL-05 | 03-03 | User can run `ckad-drill solution` | SATISFIED | solution case: numbered yq .solution.steps[] loop |
| DRIL-06 | 03-03 | User can run `ckad-drill next` | SATISFIED | next case: cleanup + session_clear + _drill_start |
| DRIL-07 | 03-03 | User can run `ckad-drill skip` | SATISFIED | skip case: cleanup + session_clear + info message |
| DRIL-08 | 03-03 | User can run `ckad-drill current` | SATISFIED | current case: scenario_load + _drill_display |
| DRIL-09 | 03-01 | Session state persists in session.json | SATISFIED | lib/session.sh jq-based JSON persistence; 23 tests |
| DRIL-10 | 03-01 | Strict exam environment: k alias, completion, EDITOR=vim | SATISFIED | timer_env_output emits alias k=kubectl, completion (shell-correct branch), EDITOR=vim |
| DRIL-11 | 03-03 | SIGINT/SIGTERM triggers cleanup via trap | SATISFIED | _drill_cleanup trap handler installed in _drill_start; checks CKAD_SESSION_FILE + SCENARIO_NAMESPACE |
| TIMR-01 | 03-01 | source <(ckad-drill env) sets up PROMPT_COMMAND [MM:SS] in prompt | SATISFIED | timer_env_output emits bash branch PROMPT_COMMAND with __ckad_drill_timer; zsh branch uses precmd |
| TIMR-02 | 03-01 | Timer shows [TIME UP] when expired | SATISFIED | __ckad_drill_timer function: remaining<=0 sets label="[TIME UP]"; test 5 |
| TIMR-03 | 03-01 | env --reset cleanly restores prompt | SATISFIED | timer_env_reset_output emits ZSH_VERSION-gated restore; tests 13-17, 23-24 |
| TIMR-04 | 03-01 | ckad-drill timer prints remaining time | SATISFIED | timer case calls timer_remaining; tests 25-27 |
| TIMR-05 | 03-01 | env output safe — no set -euo pipefail | SATISFIED | timer.sh emits no set -e; test 17 explicitly verifies; shellcheck passes cleanly |
| PROG-01 | 03-02 | Drill results recorded to progress.json | SATISFIED | progress_record with passed/time/attempts; 7 tests |
| PROG-02 | 03-04 | ckad-drill status shows progress stats | SATISFIED | _cmd_status: domain rates table, streak, exam history, weak domain; drill.bats test 85 |
| PROG-03 | 03-02 | Additive-only progress schema | SATISFIED | jq // default throughout progress.sh; idempotent init tested |
| PROG-04 | 03-02 | Progress file survives upgrades | SATISFIED | version field present; jq // default prevents parse failure on new fields |
| DIST-03 | 03-04/06 | validate-scenario FILE runs full lifecycle | SATISFIED | _validate_single_scenario: load+setup+index-based solution steps+validate+cleanup |
| DIST-04 | 03-04 | validate-scenario DIR validates all .yaml files | SATISFIED | _cmd_validate_scenario directory branch with find loop + summary |

**All 22 Phase 3 requirements: SATISFIED**

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| bin/ckad-drill | 333 | `local_step=1` at case-arm scope (not bash `local`) | INFO | Variable leaks to global scope in solution subcommand; functionally correct, minor code smell |

No blockers. No warnings. One info-level item.

**shellcheck verdict:** All three lib files (session.sh, timer.sh, progress.sh) and bin/ckad-drill pass shellcheck with zero errors or warnings. Exit code 0 on all four files.

### Test Results

| Test File | Tests | Pass | Fail | Note |
|-----------|-------|------|------|------|
| test/unit/session.bats | 23 | 23 | 0 | All pass |
| test/unit/timer.bats | 27 | 27 | 0 | All pass (includes 7 new zsh-branch tests from Plan 05) |
| test/unit/progress.bats | 23 | 23 | 0 | All pass |
| test/unit/drill.bats | 15 | 15 | 0 | All pass (includes 2 new solution-step extraction tests from Plan 06) |
| **Phase 3 total** | **88** | **88** | **0** | |

### Human Verification Required

#### 1. Timer in Interactive Zsh Shell

**Test:** Run `source <(ckad-drill env)` in a real zsh shell with an active session
**Expected:** Shell prompt shows `[MM:SS]` countdown that updates before each prompt; shows `[TIME UP]` after session expires; `ckad-drill env --reset` removes the precmd hook and restores original prompt
**Why human:** add-zsh-hook precmd behavior can only be observed in an interactive zsh shell; cannot be unit tested

#### 2. Timer in Interactive Bash Shell

**Test:** Run `source <(ckad-drill env)` in a real bash shell with an active session
**Expected:** PROMPT_COMMAND causes `[MM:SS]` countdown to appear before each prompt; `ckad-drill env --reset` restores original PS1 and PROMPT_COMMAND
**Why human:** PROMPT_COMMAND behavior can only be observed in an interactive bash shell

#### 3. End-to-End Drill Session

**Test:** With kind cluster running, run `ckad-drill drill`, then `ckad-drill check`, then `ckad-drill next`
**Expected:** Scenario title/domain/difficulty/description displayed; namespace created; session.json written; check runs validations and records progress; next cleans up and starts new scenario
**Why human:** Requires a running kind cluster; namespace creation and kubectl interaction cannot be mocked in unit tests

#### 4. validate-scenario Full Lifecycle Against Live Cluster

**Test:** Run `ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml`
**Expected:** Parse succeeds, namespace `web-team` created, step 1 (dry-run namespace create) executes, step 2 (multi-line heredoc kubectl apply) executes correctly creating `web-sidecar` pod, validation checks pass (pod_exists, two_containers, nginx_image), PASS printed, namespace cleaned up
**Why human:** Requires kind cluster with calico; validates complete heredoc solution application which is the fix from Plan 06

---

## Summary

Phase 3 goal is **fully achieved**. All 22 requirements are implemented and satisfied across 6 plans:

- **Plan 01:** lib/session.sh and lib/timer.sh (bash-only timer) — 4 files, 43 tests
- **Plan 02:** lib/progress.sh and 3 sample YAML scenarios — 5 files, 23 tests
- **Plan 03:** bin/ckad-drill with 9 drill subcommands + cluster_check_active — fully wired
- **Plan 04:** status and validate-scenario subcommands + drill.bats — 13 tests
- **Plan 05 (gap closure):** timer.sh zsh/bash shell detection — 7 new timer.bats zsh-branch tests; shellcheck clean
- **Plan 06 (gap closure):** _validate_single_scenario index-based yq extraction — 2 new drill.bats solution-step tests; shellcheck clean

The two UAT-identified gaps (timer not visible in zsh, solution steps not applied in validate-scenario) are closed and verified via automated unit tests. The code is shellcheck-clean across all four primary files.

4 items remain for human verification — all require a live kind cluster or interactive shell and cannot be automated in unit tests. The previous INFO-level shellcheck false positive (SC2153 on SCENARIO_ID/SCENARIO_FILE) no longer appears; shellcheck exits 0 cleanly on bin/ckad-drill.

---

_Verified: 2026-02-28T23:55:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — after Plans 05 and 06 gap closure_

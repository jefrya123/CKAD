---
phase: 06-content-migration
verified: 2026-02-28T04:00:00Z
status: gaps_found
score: 7/9 must-haves verified
re_verification: false
gaps:
  - truth: "Every YAML scenario passes ckad-drill validate-scenario"
    status: failed
    reason: "8 scenarios use invalid validation types (jsonpath, pod_phase) not in validator.sh case statement — these silently skip with 'Unknown check type' warn and count toward total without passing"
    artifacts:
      - path: "scenarios/domain-1/learn-jobs-cronjobs.yaml"
        issue: "type: jsonpath (not in validator.sh switch — gets skipped)"
      - path: "scenarios/domain-2/learn-deployments.yaml"
        issue: "type: jsonpath (not in validator.sh switch — gets skipped)"
      - path: "scenarios/domain-3/learn-probes.yaml"
        issue: "type: jsonpath x2 (not in validator.sh switch — gets skipped)"
      - path: "scenarios/domain-3/learn-debugging.yaml"
        issue: "type: pod_phase (not in validator.sh switch — gets skipped)"
      - path: "scenarios/domain-4/learn-security-context.yaml"
        issue: "type: jsonpath x2 (not in validator.sh switch — gets skipped)"
      - path: "scenarios/domain-5/learn-services.yaml"
        issue: "type: jsonpath (not in validator.sh switch — gets skipped)"
    missing:
      - "Change type: jsonpath to type: resource_field in all 7 affected scenarios (jsonpath is the underlying mechanism of resource_field, not its own type)"
      - "Change type: pod_phase to type: container_running or type: resource_field with jsonpath .status.phase in learn-debugging.yaml"
  - truth: "Debug scenario setup.manifest creates broken resources"
    status: partial
    reason: "debug-volume-mount.yaml solution step 4 has an unescaped shell heredoc in a kubectl command string that causes a bash syntax error during validate-scenario"
    artifacts:
      - path: "scenarios/domain-1/debug-volume-mount.yaml"
        issue: "Solution step contains backtick-style command substitution or angle bracket heredoc that causes eval syntax error: 'kubectl delete pod lab03-pod -n debug-lab03 && kubectl apply -f <the-fixed-manifest>'"
    missing:
      - "Replace placeholder '<the-fixed-manifest>' text in debug-volume-mount.yaml solution step 4 with actual kubectl apply command"
human_verification:
  - test: "Run ckad-drill drill and attempt a scenario end-to-end"
    expected: "Scenario loads, namespace created, student sees description and hint, kubectl check runs"
    why_human: "Requires interactive terminal; validate-scenario CLI only covers solution path"
  - test: "Run ckad-drill learn domain-1 and verify learn_intro displays before task"
    expected: "Concept text from learn_intro appears, then the task description, then student can complete the task"
    why_human: "UX presentation of learn_intro requires human observation"
---

# Phase 6: Content Migration Verification Report

**Phase Goal:** Migrate all existing study guide content (31 scenarios, troubleshooting labs, tutorials, quizzes) into the YAML scenario format. Produce 70+ scenarios across 5 domains with learn/drill/debug types. Archive old content.
**Verified:** 2026-02-28
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 31 markdown scenarios converted to YAML with typed validations | VERIFIED | 70 YAML files total across domains-1 through domain-5; original scenario-NN-*.md files archived to archive/study-guide/scenarios/ (32 archived including README) |
| 2 | Total scenario count >= 70 | VERIFIED | `find scenarios/domain-* -name "*.yaml" | wc -l` returns exactly 70 |
| 3 | Each domain has at least 10 scenarios | VERIFIED | D1=14, D2=14, D3=15, D4=13, D5=14 — all above 10 |
| 4 | 12+ debug scenarios with setup.manifest/commands | VERIFIED | 13 debug-prefix scenarios present across all 5 domains; all 13 have setup.manifest or setup.commands |
| 5 | 16 learn scenarios with learn_intro field | VERIFIED | 16 learn-prefix scenarios present; all 16 have non-empty learn_intro field |
| 6 | Speed drills and cheatsheet preserved | VERIFIED | speed-drills/ directory intact with aliases.md, one-liners.md, vim-tips.md; cheatsheet.md at project root |
| 7 | Old markdown content archived | VERIFIED | domains/, quizzes/, troubleshooting/ gone from project root; all present under archive/study-guide/; no scenario-NN-*.md files in scenarios/ |
| 8 | Every YAML scenario passes validate-scenario (CONT-06/07/08 summary claim) | FAILED | 6 learn scenarios use `type: jsonpath` (unrecognized by validator.sh, silently skipped); 1 uses `type: pod_phase` (also unrecognized); 1 debug scenario has a bash syntax error in solution steps |
| 9 | All scenarios use valid schema fields | PARTIAL | 70/70 files have all required top-level fields (id, domain, title, difficulty, time_limit, namespace, description, hint, validations, solution); but 8 scenarios contain unrecognized validation type names |

**Score:** 7/9 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scenarios/domain-1/` | 10+ YAML scenarios (sc-, debug-, learn-) | VERIFIED | 14 files: sc=8, debug=2, learn=4 |
| `scenarios/domain-2/` | 10+ YAML scenarios | VERIFIED | 14 files: sc=9, debug=2, learn=3 |
| `scenarios/domain-3/` | 10+ YAML scenarios | VERIFIED | 15 files: sc=8, debug=4, learn=3 |
| `scenarios/domain-4/` | 10+ YAML scenarios | VERIFIED | 13 files: sc=8, debug=2, learn=3 |
| `scenarios/domain-5/` | 10+ YAML scenarios | VERIFIED | 14 files: sc=8, debug=3, learn=3 |
| `scenarios/domain-*/debug-*.yaml` | setup.manifest for broken resources | VERIFIED | 13/13 debug files have setup.manifest or setup.commands |
| `scenarios/domain-*/learn-*.yaml` | learn_intro concept text | VERIFIED | 16/16 learn files have non-empty learn_intro |
| `archive/study-guide/` | Archived old content | VERIFIED | Contains scenarios/, domains/, quizzes/, troubleshooting/, README.md |
| `scenarios/README.md` | Documents new YAML structure | VERIFIED | Present with domain descriptions and scenario type explanations |
| `speed-drills/` | Reference content preserved | VERIFIED | aliases.md, one-liners.md, vim-tips.md present |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `scenarios/domain-*/sc-*.yaml` | `lib/scenario.sh scenario_discover` | `find "${CKAD_DRILL_ROOT}/scenarios" -name "*.yaml"` | WIRED | scenario_discover uses find glob on scenarios/ dir — all 70 YAMLs discoverable |
| `scenarios/domain-*/learn-*.yaml` | `lib/learn.sh learn_discover` | `yq -r '.learn_intro // empty'` filter | WIRED | learn_discover filters by non-empty learn_intro — all 16 learn files have it |
| `scenarios/domain-*/debug-*.yaml` | `lib/scenario.sh scenario_setup` | `setup.manifest` field applied before scenario | WIRED | All 13 debug files have setup.manifest; scenario.sh applies it |
| `validations[].type: jsonpath` | `lib/validator.sh` case statement | `jsonpath` is NOT a case entry | BROKEN | 7 scenarios use `type: jsonpath`; validator.sh only handles `resource_field`; jsonpath hits the `*` wildcard and emits "Unknown check type — skipping"; validation counts are artificially low |
| `validations[].type: pod_phase` | `lib/validator.sh` case statement | `pod_phase` is NOT a case entry | BROKEN | 1 scenario uses `type: pod_phase`; also silently skipped |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CONT-01 | 06-01, 06-02 | 31 existing scenarios migrated to YAML with typed validations | SATISFIED | 70 YAML files exist; 31 sc-prefix scenarios cover original markdown content; old files archived |
| CONT-02 | 06-03 | 12 troubleshooting labs converted to debug-prefix scenarios | SATISFIED | 13 debug-prefix files created, covering all 12 original labs (lab-12 became 1 file, lab-08 content mismatch handled) |
| CONT-03 | 06-04 | Tutorial inline exercises extracted as learn-prefix scenarios with concept text | SATISFIED | 16 learn scenarios with learn_intro sourced from tutorial prose |
| CONT-04 | 06-04 | Domain exercises extracted as additional scenarios | SATISFIED | Learn scenarios draw from exercises; gap-filling scenarios from exercises.md (10 new sc- files in Plan 05) |
| CONT-05 | 06-04 | Quiz questions convertible to practical tasks become scenarios | SATISFIED | Quiz questions were evaluated; all found to be knowledge-recall only, not converted (correct decision per SUMMARY) |
| CONT-06 | 06-05 | Speed drills and cheatsheet preserved as reference content | SATISFIED | speed-drills/ and cheatsheet.md confirmed present |
| CONT-07 | 06-05 | Total scenario count >= 70 at launch | SATISFIED | Exactly 70 YAML files in scenarios/domain-* |
| CONT-08 | 06-05 | Each domain has at least 10 scenarios | SATISFIED | D1=14, D2=14, D3=15, D4=13, D5=14 |

---

## Anti-Patterns Found

| File | Type | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scenarios/domain-1/learn-jobs-cronjobs.yaml` | Invalid validation type | `type: jsonpath` — not in validator.sh | WARNING | Validation silently skipped; check never runs |
| `scenarios/domain-2/learn-deployments.yaml` | Invalid validation type | `type: jsonpath` — not in validator.sh | WARNING | Validation silently skipped |
| `scenarios/domain-3/learn-probes.yaml` | Invalid validation type | `type: jsonpath` x2 — not in validator.sh | WARNING | Both validations silently skipped |
| `scenarios/domain-3/learn-debugging.yaml` | Invalid validation type | `type: pod_phase` — not in validator.sh | WARNING | Validation silently skipped |
| `scenarios/domain-4/learn-security-context.yaml` | Invalid validation type | `type: jsonpath` x2 — not in validator.sh | WARNING | Both validations silently skipped |
| `scenarios/domain-5/learn-services.yaml` | Invalid validation type | `type: jsonpath` — not in validator.sh | WARNING | Validation silently skipped |
| `scenarios/domain-1/debug-volume-mount.yaml` | Placeholder in solution | `kubectl apply -f <the-fixed-manifest>` — bash syntax error on eval | BLOCKER | Solution step 4 causes eval syntax error; debug scenario does not complete in validate-scenario |

---

## Human Verification Required

### 1. Learn Mode End-to-End Flow

**Test:** Run `ckad-drill learn domain-1` and complete one scenario
**Expected:** learn_intro concept text appears before task description; student can complete the task and see pass/fail
**Why human:** Requires interactive terminal session; visual presentation of learn_intro cannot be verified programmatically

### 2. Debug Scenario Setup Flow

**Test:** Run a debug scenario (e.g., `ckad-drill drill debug-wrong-image`) in a live kind cluster
**Expected:** setup.manifest creates the broken pod before the student sees the task; student can diagnose and fix; validation confirms fixed state
**Why human:** setup.manifest application against live cluster needs observation to confirm broken state is properly established

### 3. Duplicate ID Check at Runtime

**Test:** Run `ckad-drill drill` with all domains loaded
**Expected:** No warnings about duplicate scenario IDs; all 70 scenarios available
**Why human:** Runtime discovery behavior with warn-and-skip logic needs live observation

---

## Gaps Summary

Two gaps block full goal achievement:

**Gap 1 — Invalid validation types in 6 learn scenarios (8 affected checks):** The YAML scenario author used `type: jsonpath` and `type: pod_phase` as validation types. Neither exists in `lib/validator.sh`'s case statement. The validator hits the `*` wildcard, emits "Unknown check type — skipping", and does NOT count the check. This means these 6 learn scenarios have fewer effective validations than declared. The fix is straightforward: `type: jsonpath` should be `type: resource_field` (the jsonpath is specified in `.validations[].jsonpath` — that is how resource_field works); `type: pod_phase` should be `type: container_running` or `type: resource_field` with `.status.phase` jsonpath.

**Gap 2 — Syntax error in debug-volume-mount.yaml solution step:** Solution step 4 contains the literal text `kubectl apply -f <the-fixed-manifest>` which is a placeholder, not a valid command. When `bin/ckad-drill validate-scenario` executes this via `eval`, bash throws a syntax error on the `<` redirect. This scenario's validate-scenario run is incomplete. The solution step needs to be replaced with the actual apply command (likely referencing a `/tmp/` manifest path or using `kubectl edit`).

Both gaps are in scenarios that were created during Phase 6 plan execution. They do not affect the count thresholds (CONT-07, CONT-08) or the structural requirements, but they do affect the CONT-05 plan truth that "Every YAML scenario passes ckad-drill validate-scenario."

---

_Verified: 2026-02-28_
_Verifier: Claude (gsd-verifier)_

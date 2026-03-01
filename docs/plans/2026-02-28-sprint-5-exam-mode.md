# Sprint 5: Exam Mode — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement exam mode — a full CKAD mock exam experience with multi-scenario session management, question navigation, flagging, timed scoring, and cleanup. Covers Stories 7.1 (Exam Session Management) and 7.2 (Exam Submission & Scoring).

**Architecture:** `lib/exam.sh` is a distinct component (ADR-11) managing multi-scenario sessions. It depends on `scenario.sh` for loading/setup/cleanup, `validator.sh` for grading, `timer.sh` for the global countdown, `progress.sh` for recording exam results, and `display.sh` for all output. Exam session state lives in `session.json` with `mode: "exam"`. See `_bmad-output/planning-artifacts/architecture.md` ADR-02 and ADR-11 for full schemas and rationale.

**Tech Stack:** Bash, kind, kubectl, yq, jq, bats-core, shellcheck

**Key conventions (from architecture doc):**
- `set -euo pipefail` ONLY in `bin/ckad-drill`, never in lib files
- Functions: `module_action()` public, `_module_helper()` private
- Variables: `UPPER_SNAKE` globals, `lower_snake` locals, always `"${braced}"`
- All output through `display.sh` functions — no raw echo with escape codes in libs
- Lib files are source-only — no top-level execution, only function definitions
- 2-space indent, no tabs
- shellcheck clean — no suppressed warnings without justification

**Dependencies:** Sprints 1-3 must be complete. Specifically: `lib/common.sh`, `lib/display.sh`, `lib/cluster.sh`, `lib/scenario.sh`, `lib/validator.sh`, `lib/timer.sh`, `lib/progress.sh`, and `bin/ckad-drill` must all exist and function. Drill mode (`ckad-drill drill` / `ckad-drill check`) must work end-to-end.

---

### Task 1: Write test/unit/exam.bats — Full Unit Test Suite (Story 7.1 + 7.2)

**Files:**
- Create: `test/unit/exam.bats`
- Create: `test/helpers/fixtures/exam-scenarios/` (fixture scenario YAMLs)

TDD: write all unit tests first, then implement `lib/exam.sh` in Tasks 2-4.

**Step 1: Create fixture scenarios for exam tests**

Create minimal scenario YAML fixtures in `test/helpers/fixtures/exam-scenarios/` — one per domain, enough to test selection and scoring logic. These are intentionally minimal (no real setup/validation) for unit testing.

Create `test/helpers/fixtures/exam-scenarios/domain-1/fixture-d1-easy.yaml`:
```yaml
id: fixture-d1-easy
domain: 1
title: "Fixture D1 Easy"
difficulty: easy
time_limit: 120
weight: 1
namespace: exam-fixture-d1-easy
description: |
  Fixture scenario for domain 1 exam testing.
validations:
  - type: resource_exists
    resource: pod/test-pod
    description: "Test pod exists"
solution: |
  kubectl run test-pod --image=nginx -n exam-fixture-d1-easy
```

Create `test/helpers/fixtures/exam-scenarios/domain-1/fixture-d1-hard.yaml`:
```yaml
id: fixture-d1-hard
domain: 1
title: "Fixture D1 Hard"
difficulty: hard
time_limit: 300
weight: 3
namespace: exam-fixture-d1-hard
description: |
  Fixture scenario for domain 1 hard exam testing.
validations:
  - type: resource_exists
    resource: pod/hard-pod
    description: "Hard pod exists"
solution: |
  kubectl run hard-pod --image=nginx -n exam-fixture-d1-hard
```

Create `test/helpers/fixtures/exam-scenarios/domain-2/fixture-d2-medium.yaml`:
```yaml
id: fixture-d2-medium
domain: 2
title: "Fixture D2 Medium"
difficulty: medium
time_limit: 180
weight: 2
namespace: exam-fixture-d2
description: |
  Fixture scenario for domain 2 exam testing.
validations:
  - type: resource_exists
    resource: deployment/test-deploy
    description: "Test deployment exists"
solution: |
  kubectl create deployment test-deploy --image=nginx -n exam-fixture-d2
```

Create `test/helpers/fixtures/exam-scenarios/domain-3/fixture-d3-easy.yaml`:
```yaml
id: fixture-d3-easy
domain: 3
title: "Fixture D3 Easy"
difficulty: easy
time_limit: 120
weight: 1
namespace: exam-fixture-d3
description: |
  Fixture scenario for domain 3 exam testing.
validations:
  - type: resource_exists
    resource: pod/log-pod
    description: "Log pod exists"
solution: |
  kubectl run log-pod --image=busybox -n exam-fixture-d3
```

Create `test/helpers/fixtures/exam-scenarios/domain-4/fixture-d4-medium.yaml`:
```yaml
id: fixture-d4-medium
domain: 4
title: "Fixture D4 Medium"
difficulty: medium
time_limit: 240
weight: 2
namespace: exam-fixture-d4
description: |
  Fixture scenario for domain 4 exam testing.
validations:
  - type: resource_exists
    resource: configmap/test-config
    description: "Test configmap exists"
solution: |
  kubectl create configmap test-config --from-literal=key=val -n exam-fixture-d4
```

Create `test/helpers/fixtures/exam-scenarios/domain-5/fixture-d5-easy.yaml`:
```yaml
id: fixture-d5-easy
domain: 5
title: "Fixture D5 Easy"
difficulty: easy
time_limit: 120
weight: 1
namespace: exam-fixture-d5
description: |
  Fixture scenario for domain 5 exam testing.
validations:
  - type: resource_exists
    resource: service/test-svc
    description: "Test service exists"
solution: |
  kubectl expose pod test-pod --port=80 --name=test-svc -n exam-fixture-d5
```

**Step 2: Write comprehensive unit tests**

Create `test/unit/exam.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"

  # Source scenario.sh and its dependencies (mocked where needed)
  source "${CKAD_ROOT}/lib/scenario.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
  source "${CKAD_ROOT}/lib/timer.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  source "${CKAD_ROOT}/lib/exam.sh"

  # Use fixture scenarios for tests
  EXAM_FIXTURE_DIR="${CKAD_ROOT}/test/helpers/fixtures/exam-scenarios"

  # Ensure clean session state for each test
  rm -f "${CKAD_SESSION_FILE}"
  mkdir -p "$(dirname "${CKAD_SESSION_FILE}")"
  mkdir -p "$(dirname "${CKAD_PROGRESS_FILE}")"
}

teardown() {
  rm -f "${CKAD_SESSION_FILE}"
}

# ───────────────────────────────────────────────────────────────
# Sourcing & function existence
# ───────────────────────────────────────────────────────────────

@test "sourcing exam.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"
            source "${CKAD_ROOT}/lib/display.sh"
            source "${CKAD_ROOT}/lib/scenario.sh"
            source "${CKAD_ROOT}/lib/validator.sh"
            source "${CKAD_ROOT}/lib/timer.sh"
            source "${CKAD_ROOT}/lib/progress.sh"
            source "${CKAD_ROOT}/lib/exam.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "exam public functions are defined" {
  declare -f exam_start > /dev/null
  declare -f exam_list > /dev/null
  declare -f exam_next > /dev/null
  declare -f exam_prev > /dev/null
  declare -f exam_jump > /dev/null
  declare -f exam_flag > /dev/null
  declare -f exam_show_current > /dev/null
  declare -f exam_submit > /dev/null
  declare -f exam_cleanup > /dev/null
  declare -f exam_is_active > /dev/null
}

# ───────────────────────────────────────────────────────────────
# Domain weight distribution (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "EXAM_DOMAIN_WEIGHTS constants are defined" {
  [[ "${EXAM_DOMAIN_WEIGHTS[1]}" -eq 20 ]]
  [[ "${EXAM_DOMAIN_WEIGHTS[2]}" -eq 20 ]]
  [[ "${EXAM_DOMAIN_WEIGHTS[3]}" -eq 15 ]]
  [[ "${EXAM_DOMAIN_WEIGHTS[4]}" -eq 25 ]]
  [[ "${EXAM_DOMAIN_WEIGHTS[5]}" -eq 20 ]]
}

@test "_exam_calculate_question_counts returns correct counts for 15 questions" {
  local -A counts
  _exam_calculate_question_counts 15 counts
  # D1:20%=3, D2:20%=3, D3:15%=2, D4:25%=4, D5:20%=3 => 15
  [[ "${counts[1]}" -eq 3 ]]
  [[ "${counts[2]}" -eq 3 ]]
  [[ "${counts[3]}" -eq 2 ]]
  [[ "${counts[4]}" -eq 4 ]]
  [[ "${counts[5]}" -eq 3 ]]
}

@test "_exam_calculate_question_counts returns correct counts for 20 questions" {
  local -A counts
  _exam_calculate_question_counts 20 counts
  # D1:20%=4, D2:20%=4, D3:15%=3, D4:25%=5, D5:20%=4 => 20
  [[ "${counts[1]}" -eq 4 ]]
  [[ "${counts[2]}" -eq 4 ]]
  [[ "${counts[3]}" -eq 3 ]]
  [[ "${counts[4]}" -eq 5 ]]
  [[ "${counts[5]}" -eq 4 ]]
}

# ───────────────────────────────────────────────────────────────
# Weighted scenario selection (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_select_from_domain selects scenarios from specified domain" {
  # This test verifies the function returns scenario IDs from the correct domain
  local result
  result="$(_exam_select_from_domain 1 2 "${EXAM_FIXTURE_DIR}")"
  [[ -n "${result}" ]]
  # Should contain domain-1 fixture IDs
  echo "${result}" | grep -q "fixture-d1"
}

@test "_exam_select_from_domain respects count parameter" {
  local result
  result="$(_exam_select_from_domain 1 1 "${EXAM_FIXTURE_DIR}")"
  local count
  count="$(echo "${result}" | wc -l)"
  [[ "${count}" -eq 1 ]]
}

@test "_exam_select_from_domain uses weight field for selection probability" {
  # fixture-d1-hard has weight:3, fixture-d1-easy has weight:1
  # Over many iterations, hard should appear more often.
  # This is a statistical test — run 100 selections of 1 and count.
  local hard_count=0
  local i
  for i in $(seq 1 100); do
    local result
    result="$(_exam_select_from_domain 1 1 "${EXAM_FIXTURE_DIR}")"
    if [[ "${result}" == *"fixture-d1-hard"* ]]; then
      hard_count=$((hard_count + 1))
    fi
  done
  # With weight 3:1, we expect ~75% hard. Accept >50% as passing (avoids flaky).
  [[ "${hard_count}" -gt 50 ]]
}

# ───────────────────────────────────────────────────────────────
# Session management (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "exam_is_active returns false when no session exists" {
  rm -f "${CKAD_SESSION_FILE}"
  ! exam_is_active
}

@test "exam_is_active returns false when session is drill mode" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "drill",
  "scenario_id": "some-scenario",
  "namespace": "drill-test",
  "started_at": "2026-02-28T10:00:00Z",
  "time_limit": 180
}
EOF
  ! exam_is_active
}

@test "exam_is_active returns true when session is exam mode" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": []
}
EOF
  exam_is_active
}

@test "_exam_write_session creates valid JSON session file" {
  local questions_json='[
    {"scenario_id":"fixture-d1-easy","namespace":"exam-fixture-d1-easy","status":"pending","passed":false,"domain":1},
    {"scenario_id":"fixture-d2-medium","namespace":"exam-fixture-d2","status":"pending","passed":false,"domain":2}
  ]'
  _exam_write_session 7200 "${questions_json}"

  # Verify session file exists and has correct fields
  [[ -f "${CKAD_SESSION_FILE}" ]]
  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}")"
  [[ "${mode}" == "exam" ]]

  local time_limit
  time_limit="$(jq -r '.time_limit' "${CKAD_SESSION_FILE}")"
  [[ "${time_limit}" -eq 7200 ]]

  local question_count
  question_count="$(jq '.questions | length' "${CKAD_SESSION_FILE}")"
  [[ "${question_count}" -eq 2 ]]

  local current
  current="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${current}" -eq 0 ]]
}

@test "_exam_read_session returns session fields correctly" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 2,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"flagged","passed":false,"domain":2},
    {"scenario_id":"q3","namespace":"ns3","status":"pending","passed":false,"domain":3}
  ]
}
EOF
  local current
  current="$(_exam_get_current_index)"
  [[ "${current}" -eq 2 ]]

  local total
  total="$(_exam_get_question_count)"
  [[ "${total}" -eq 3 ]]
}

# ───────────────────────────────────────────────────────────────
# Navigation (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_set_current_question updates session file" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"pending","passed":false,"domain":2},
    {"scenario_id":"q3","namespace":"ns3","status":"pending","passed":false,"domain":3}
  ]
}
EOF
  _exam_set_current_question 2
  local current
  current="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${current}" -eq 2 ]]
}

@test "_exam_set_current_question rejects out-of-bounds index" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1}
  ]
}
EOF
  run _exam_set_current_question 5
  [[ "${status}" -ne 0 ]]
}

@test "_exam_set_current_question rejects negative index" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1}
  ]
}
EOF
  run _exam_set_current_question -1
  [[ "${status}" -ne 0 ]]
}

# ───────────────────────────────────────────────────────────────
# Flagging (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_flag_question sets status to flagged" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 1,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"pending","passed":false,"domain":2}
  ]
}
EOF
  _exam_flag_question 1
  local flag_status
  flag_status="$(jq -r '.questions[1].status' "${CKAD_SESSION_FILE}")"
  [[ "${flag_status}" == "flagged" ]]
}

@test "_exam_flag_question toggles flagged back to pending" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"flagged","passed":false,"domain":1}
  ]
}
EOF
  _exam_flag_question 0
  local flag_status
  flag_status="$(jq -r '.questions[0].status' "${CKAD_SESSION_FILE}")"
  [[ "${flag_status}" == "pending" ]]
}

@test "_exam_flag_question does not unflag a checked question" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1}
  ]
}
EOF
  _exam_flag_question 0
  local flag_status
  flag_status="$(jq -r '.questions[0].status' "${CKAD_SESSION_FILE}")"
  # Flagging a checked question should add a flag marker but preserve the checked state
  [[ "${flag_status}" == "checked-flagged" ]]
}

# ───────────────────────────────────────────────────────────────
# Question status update (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_update_question_status sets checked and passed" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1}
  ]
}
EOF
  _exam_update_question_status 0 "checked" true
  local q_status q_passed
  q_status="$(jq -r '.questions[0].status' "${CKAD_SESSION_FILE}")"
  q_passed="$(jq -r '.questions[0].passed' "${CKAD_SESSION_FILE}")"
  [[ "${q_status}" == "checked" ]]
  [[ "${q_passed}" == "true" ]]
}

@test "_exam_update_question_status sets checked and failed" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1}
  ]
}
EOF
  _exam_update_question_status 0 "checked" false
  local q_passed
  q_passed="$(jq -r '.questions[0].passed' "${CKAD_SESSION_FILE}")"
  [[ "${q_passed}" == "false" ]]
}

# ───────────────────────────────────────────────────────────────
# Exam list display (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "exam_list shows all questions with status emojis" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 1,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1,"title":"Question One"},
    {"scenario_id":"q2","namespace":"ns2","status":"flagged","passed":false,"domain":2,"title":"Question Two"},
    {"scenario_id":"q3","namespace":"ns3","status":"pending","passed":false,"domain":3,"title":"Question Three"},
    {"scenario_id":"q4","namespace":"ns4","status":"checked","passed":false,"domain":4,"title":"Question Four"}
  ]
}
EOF
  run exam_list
  [[ "${status}" -eq 0 ]]
  # Should contain status indicators
  [[ "${output}" == *"Question One"* ]]
  [[ "${output}" == *"Question Two"* ]]
  [[ "${output}" == *"Question Three"* ]]
  [[ "${output}" == *"Question Four"* ]]
}

# ───────────────────────────────────────────────────────────────
# Scoring logic (Story 7.2)
# ───────────────────────────────────────────────────────────────

@test "_exam_calculate_score returns correct total percentage" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"checked","passed":true,"domain":2},
    {"scenario_id":"q3","namespace":"ns3","status":"checked","passed":false,"domain":3},
    {"scenario_id":"q4","namespace":"ns4","status":"checked","passed":true,"domain":4}
  ]
}
EOF
  local score
  score="$(_exam_calculate_total_score)"
  # 3 out of 4 passed = 75%
  [[ "${score}" -eq 75 ]]
}

@test "_exam_calculate_domain_scores returns per-domain percentages" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"checked","passed":false,"domain":1},
    {"scenario_id":"q3","namespace":"ns3","status":"checked","passed":true,"domain":2},
    {"scenario_id":"q4","namespace":"ns4","status":"checked","passed":true,"domain":2},
    {"scenario_id":"q5","namespace":"ns5","status":"checked","passed":false,"domain":3}
  ]
}
EOF
  local domain_scores
  domain_scores="$(_exam_calculate_domain_scores)"
  # Domain 1: 1/2 = 50%, Domain 2: 2/2 = 100%, Domain 3: 0/1 = 0%
  local d1_score d2_score d3_score
  d1_score="$(echo "${domain_scores}" | jq -r '."1"')"
  d2_score="$(echo "${domain_scores}" | jq -r '."2"')"
  d3_score="$(echo "${domain_scores}" | jq -r '."3"')"
  [[ "${d1_score}" -eq 50 ]]
  [[ "${d2_score}" -eq 100 ]]
  [[ "${d3_score}" -eq 0 ]]
}

@test "_exam_calculate_total_score treats pending questions as failed" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"checked","passed":true,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"pending","passed":false,"domain":2}
  ]
}
EOF
  local score
  score="$(_exam_calculate_total_score)"
  # 1 out of 2 = 50%
  [[ "${score}" -eq 50 ]]
}

@test "_exam_is_passing returns true at 66%" {
  _exam_is_passing 66
}

@test "_exam_is_passing returns true above 66%" {
  _exam_is_passing 80
}

@test "_exam_is_passing returns false below 66%" {
  ! _exam_is_passing 65
}

@test "_exam_is_passing returns false at 0%" {
  ! _exam_is_passing 0
}

# ───────────────────────────────────────────────────────────────
# Hint/solution blocking (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "exam_is_active blocks hint access pattern" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": []
}
EOF
  # exam_is_active should return 0 (true) so caller can block hints
  exam_is_active
}

# ───────────────────────────────────────────────────────────────
# Time parsing (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_parse_time converts minutes to seconds" {
  local result
  result="$(_exam_parse_time "60m")"
  [[ "${result}" -eq 3600 ]]
}

@test "_exam_parse_time converts hours to seconds" {
  local result
  result="$(_exam_parse_time "2h")"
  [[ "${result}" -eq 7200 ]]
}

@test "_exam_parse_time defaults to 2 hours with no argument" {
  local result
  result="$(_exam_parse_time "")"
  [[ "${result}" -eq 7200 ]]
}

@test "_exam_parse_time rejects invalid format" {
  run _exam_parse_time "abc"
  [[ "${status}" -ne 0 ]]
}

# ───────────────────────────────────────────────────────────────
# Namespace list generation (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_get_all_namespaces returns all question namespaces" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"alpha-ns","status":"pending","passed":false,"domain":1},
    {"scenario_id":"q2","namespace":"bravo-ns","status":"pending","passed":false,"domain":2},
    {"scenario_id":"q3","namespace":"charlie-ns","status":"pending","passed":false,"domain":3}
  ]
}
EOF
  local namespaces
  namespaces="$(_exam_get_all_namespaces)"
  [[ "${namespaces}" == *"alpha-ns"* ]]
  [[ "${namespaces}" == *"bravo-ns"* ]]
  [[ "${namespaces}" == *"charlie-ns"* ]]
  local count
  count="$(echo "${namespaces}" | wc -l)"
  [[ "${count}" -eq 3 ]]
}

# ───────────────────────────────────────────────────────────────
# Current question data retrieval (Story 7.1)
# ───────────────────────────────────────────────────────────────

@test "_exam_get_current_question_field retrieves scenario_id" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 1,
  "questions": [
    {"scenario_id":"q1","namespace":"ns1","status":"pending","passed":false,"domain":1},
    {"scenario_id":"q2","namespace":"ns2","status":"pending","passed":false,"domain":2}
  ]
}
EOF
  local sid
  sid="$(_exam_get_current_question_field "scenario_id")"
  [[ "${sid}" == "q2" ]]
}

@test "_exam_get_current_question_field retrieves namespace" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": [
    {"scenario_id":"q1","namespace":"web-team","status":"pending","passed":false,"domain":1}
  ]
}
EOF
  local ns
  ns="$(_exam_get_current_question_field "namespace")"
  [[ "${ns}" == "web-team" ]]
}
```

**Step 3: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/exam.bats
```

Expected: FAIL — `lib/exam.sh` doesn't exist yet.

**Step 4: Commit test scaffolding**

```bash
git add test/unit/exam.bats test/helpers/fixtures/exam-scenarios/
git commit -m "test: add exam mode unit tests and fixtures (red phase)

Comprehensive bats tests for lib/exam.sh covering: session
management, domain-weighted selection, navigation, flagging,
scoring, time parsing, namespace listing, and hint blocking.
All tests expected to fail until exam.sh is implemented."
```

---

### Task 2: Implement lib/exam.sh — Session Management & Selection (Story 7.1)

**Files:**
- Create: `lib/exam.sh`

This task covers: constants, time parsing, session read/write, domain-weighted scenario selection, question count calculation, and the `exam_is_active` check.

**Step 1: Implement lib/exam.sh core**

Create `lib/exam.sh`:
```bash
#!/usr/bin/env bash
# lib/exam.sh — Exam mode session management, navigation, and scoring
#
# Manages multi-scenario exam sessions with timed scoring per ADR-11.
# Depends on: common.sh, display.sh, scenario.sh, validator.sh, timer.sh, progress.sh
#
# This file is sourced by bin/ckad-drill. It MUST NOT set -euo pipefail
# or produce any output when sourced. Functions and variable assignments only.

# ---------------------------------------------------------------------------
# Constants — CKAD domain weight percentages
# ---------------------------------------------------------------------------
declare -gA EXAM_DOMAIN_WEIGHTS=(
  [1]=20
  [2]=20
  [3]=15
  [4]=25
  [5]=20
)

EXAM_DEFAULT_TIME=7200       # 2 hours in seconds
EXAM_PASS_THRESHOLD=66       # 66% to pass
EXAM_MIN_QUESTIONS=15
EXAM_MAX_QUESTIONS=20

# ---------------------------------------------------------------------------
# Time parsing
# ---------------------------------------------------------------------------

# Parse time string (e.g., "60m", "2h") to seconds.
# Empty string defaults to EXAM_DEFAULT_TIME.
_exam_parse_time() {
  local input="${1:-}"

  if [[ -z "${input}" ]]; then
    echo "${EXAM_DEFAULT_TIME}"
    return 0
  fi

  local value="${input%[mMhH]}"
  local unit="${input: -1}"

  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    error "Invalid time format: '${input}'. Use format like '60m' or '2h'."
    return 1
  fi

  case "${unit}" in
    m|M) echo $(( value * 60 )) ;;
    h|H) echo $(( value * 3600 )) ;;
    *)
      error "Invalid time format: '${input}'. Use format like '60m' or '2h'."
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Session state queries
# ---------------------------------------------------------------------------

# Returns 0 if an exam session is active, 1 otherwise.
exam_is_active() {
  [[ -f "${CKAD_SESSION_FILE}" ]] || return 1
  local mode
  mode="$(jq -r '.mode // ""' "${CKAD_SESSION_FILE}" 2>/dev/null)" || return 1
  [[ "${mode}" == "exam" ]]
}

# Get the 0-based index of the current question.
_exam_get_current_index() {
  jq -r '.current_question' "${CKAD_SESSION_FILE}"
}

# Get total number of questions in the exam.
_exam_get_question_count() {
  jq '.questions | length' "${CKAD_SESSION_FILE}"
}

# Get a field from the current question.
_exam_get_current_question_field() {
  local field="${1}"
  local idx
  idx="$(_exam_get_current_index)"
  jq -r ".questions[${idx}].${field}" "${CKAD_SESSION_FILE}"
}

# Get all exam namespaces, one per line.
_exam_get_all_namespaces() {
  jq -r '.questions[].namespace' "${CKAD_SESSION_FILE}"
}

# ---------------------------------------------------------------------------
# Session state mutations
# ---------------------------------------------------------------------------

# Write a new exam session to session.json.
# Args: time_limit_seconds, questions_json_array
_exam_write_session() {
  local time_limit="${1}"
  local questions_json="${2}"
  local started_at
  started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  jq -n \
    --arg mode "exam" \
    --arg started_at "${started_at}" \
    --argjson time_limit "${time_limit}" \
    --argjson questions "${questions_json}" \
    '{
      mode: $mode,
      started_at: $started_at,
      time_limit: $time_limit,
      current_question: 0,
      questions: $questions
    }' > "${CKAD_SESSION_FILE}"
}

# Set the current question index.
_exam_set_current_question() {
  local idx="${1}"
  local total
  total="$(_exam_get_question_count)"

  if [[ "${idx}" -lt 0 ]] || [[ "${idx}" -ge "${total}" ]]; then
    error "Question ${idx} out of range. Valid range: 0-$((total - 1))."
    return 1
  fi

  local tmp
  tmp="$(jq --argjson idx "${idx}" '.current_question = $idx' "${CKAD_SESSION_FILE}")"
  echo "${tmp}" > "${CKAD_SESSION_FILE}"
}

# Update a question's status and passed fields.
_exam_update_question_status() {
  local idx="${1}"
  local new_status="${2}"
  local passed="${3}"

  local tmp
  tmp="$(jq --argjson idx "${idx}" \
            --arg status "${new_status}" \
            --argjson passed "${passed}" \
    '.questions[$idx].status = $status | .questions[$idx].passed = $passed' \
    "${CKAD_SESSION_FILE}")"
  echo "${tmp}" > "${CKAD_SESSION_FILE}"
}

# Flag or unflag a question.
_exam_flag_question() {
  local idx="${1}"
  local current_status
  current_status="$(jq -r ".questions[${idx}].status" "${CKAD_SESSION_FILE}")"

  local new_status
  case "${current_status}" in
    pending)          new_status="flagged" ;;
    flagged)          new_status="pending" ;;
    checked)          new_status="checked-flagged" ;;
    checked-flagged)  new_status="checked" ;;
    *)                new_status="flagged" ;;
  esac

  local tmp
  tmp="$(jq --argjson idx "${idx}" \
            --arg status "${new_status}" \
    '.questions[$idx].status = $status' "${CKAD_SESSION_FILE}")"
  echo "${tmp}" > "${CKAD_SESSION_FILE}"
}

# ---------------------------------------------------------------------------
# Domain-weighted question selection
# ---------------------------------------------------------------------------

# Calculate how many questions to select per domain for a given total.
# Args: total_questions, nameref_to_associative_array
_exam_calculate_question_counts() {
  local total="${1}"
  local -n _counts="${2}"

  local allocated=0
  local domain
  for domain in 1 2 3 4 5; do
    _counts[${domain}]=$(( total * EXAM_DOMAIN_WEIGHTS[${domain}] / 100 ))
    allocated=$(( allocated + _counts[${domain}] ))
  done

  # Distribute remainder to highest-weighted domains first
  local remainder=$(( total - allocated ))
  local -a priority_order=(4 1 2 5 3)  # D4:25%, D1:20%, D2:20%, D5:20%, D3:15%
  local i=0
  while [[ "${remainder}" -gt 0 ]]; do
    local d="${priority_order[${i}]}"
    _counts[${d}]=$(( _counts[${d}] + 1 ))
    remainder=$(( remainder - 1 ))
    i=$(( (i + 1) % 5 ))
  done
}

# Select N scenarios from a domain using weight-based probability.
# Args: domain_number, count, scenario_base_dir
# Outputs: scenario IDs, one per line
_exam_select_from_domain() {
  local domain="${1}"
  local count="${2}"
  local scenario_dir="${3:-${CKAD_ROOT}/scenarios}"

  local domain_dir="${scenario_dir}/domain-${domain}"
  if [[ ! -d "${domain_dir}" ]]; then
    warn "No scenarios found for domain ${domain}"
    return 0
  fi

  # Build weighted list: each scenario ID appears (weight) times
  local -a weighted_pool=()
  local yaml_file
  for yaml_file in "${domain_dir}"/*.yaml; do
    [[ -f "${yaml_file}" ]] || continue
    local sid sw
    sid="$(yq -r '.id' "${yaml_file}")"
    sw="$(yq -r '.weight // 1' "${yaml_file}")"
    local w
    for w in $(seq 1 "${sw}"); do
      weighted_pool+=("${sid}:${yaml_file}")
    done
  done

  if [[ ${#weighted_pool[@]} -eq 0 ]]; then
    warn "No scenarios found in domain ${domain}"
    return 0
  fi

  # Shuffle and pick unique scenarios up to count
  local -a selected_ids=()
  local -a shuffled
  mapfile -t shuffled < <(printf '%s\n' "${weighted_pool[@]}" | shuf)

  local entry
  for entry in "${shuffled[@]}"; do
    local sid="${entry%%:*}"
    # Check if already selected
    local already=false
    local existing
    for existing in "${selected_ids[@]}"; do
      if [[ "${existing}" == "${sid}" ]]; then
        already=true
        break
      fi
    done
    if [[ "${already}" == false ]]; then
      selected_ids+=("${sid}")
      echo "${sid}"
      if [[ ${#selected_ids[@]} -ge ${count} ]]; then
        break
      fi
    fi
  done
}

# Select all exam scenarios across all domains using weighted distribution.
# Args: total_questions, scenario_base_dir (optional)
# Outputs: JSON array of question objects
_exam_select_all_questions() {
  local total="${1:-${EXAM_MIN_QUESTIONS}}"
  local scenario_dir="${2:-${CKAD_ROOT}/scenarios}"

  local -A domain_counts
  _exam_calculate_question_counts "${total}" domain_counts

  local questions_json="["
  local first=true
  local domain

  for domain in 1 2 3 4 5; do
    local need="${domain_counts[${domain}]}"
    [[ "${need}" -gt 0 ]] || continue

    local ids
    ids="$(_exam_select_from_domain "${domain}" "${need}" "${scenario_dir}")"
    [[ -n "${ids}" ]] || continue

    local sid
    while IFS= read -r sid; do
      [[ -n "${sid}" ]] || continue

      # Find the YAML file for this scenario ID
      local yaml_file
      yaml_file="$(find "${scenario_dir}/domain-${domain}" -name "*.yaml" -exec grep -l "^id: ${sid}$" {} \; | head -1)"
      [[ -n "${yaml_file}" ]] || continue

      local namespace title
      namespace="$(yq -r '.namespace // "drill-" + .id' "${yaml_file}")"
      title="$(yq -r '.title' "${yaml_file}")"

      if [[ "${first}" == true ]]; then
        first=false
      else
        questions_json+=","
      fi

      questions_json+="$(jq -n \
        --arg sid "${sid}" \
        --arg ns "${namespace}" \
        --arg title "${title}" \
        --argjson domain "${domain}" \
        --arg yaml_file "${yaml_file}" \
        '{
          scenario_id: $sid,
          namespace: $ns,
          title: $title,
          status: "pending",
          passed: false,
          domain: $domain,
          yaml_file: $yaml_file
        }')"
    done <<< "${ids}"
  done

  questions_json+="]"
  echo "${questions_json}"
}
```

**Step 2: Run passing tests**

```bash
cd /home/jeff/Projects/cka
bats test/unit/exam.bats
```

Expected: Tests covering constants, time parsing, session read/write, navigation, flagging, question status, scoring helpers, and namespace listing should PASS. Tests that require `exam_start`, `exam_list`, `exam_submit` (which depend on cluster) may still fail — those are wired in Tasks 3-4.

**Step 3: Run shellcheck**

```bash
shellcheck lib/exam.sh
```

Expected: No warnings.

**Step 4: Commit**

```bash
git add lib/exam.sh
git commit -m "feat: implement lib/exam.sh core — session management and selection

Domain-weighted scenario selection (D1:20%, D2:20%, D3:15%,
D4:25%, D5:20%), weight-based within-domain probability,
session JSON read/write, navigation helpers, flagging,
time parsing, and exam_is_active check."
```

---

### Task 3: Implement Exam Navigation & Display (Story 7.1)

**Files:**
- Modify: `lib/exam.sh` (add public functions)

This task adds the public-facing exam functions that handle starting, navigating, displaying, and listing exam questions.

**Step 1: Add exam_start() to lib/exam.sh**

Append to `lib/exam.sh`:
```bash
# ---------------------------------------------------------------------------
# Public API — Exam lifecycle
# ---------------------------------------------------------------------------

# Start a new exam session.
# Args: [--time Nm|Nh] [--questions N]
exam_start() {
  if exam_is_active; then
    error "An exam is already in progress. Run 'ckad-drill exam submit' or 'ckad-drill exam quit' first."
    return 1
  fi

  # Parse options
  local time_str=""
  local num_questions="${EXAM_MIN_QUESTIONS}"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --time)
        time_str="${2:-}"
        shift 2
        ;;
      --questions)
        num_questions="${2:-${EXAM_MIN_QUESTIONS}}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local time_seconds
  time_seconds="$(_exam_parse_time "${time_str}")" || return $?

  # Validate question count
  if [[ "${num_questions}" -lt "${EXAM_MIN_QUESTIONS}" ]] || [[ "${num_questions}" -gt "${EXAM_MAX_QUESTIONS}" ]]; then
    error "Question count must be between ${EXAM_MIN_QUESTIONS} and ${EXAM_MAX_QUESTIONS}."
    return 1
  fi

  # Ensure cluster is running
  cluster_ensure_running || return $?

  header "CKAD Mock Exam"
  info "Selecting ${num_questions} questions weighted by CKAD domain percentages..."

  # Select scenarios
  local questions_json
  questions_json="$(_exam_select_all_questions "${num_questions}")"

  local actual_count
  actual_count="$(echo "${questions_json}" | jq 'length')"
  if [[ "${actual_count}" -lt 1 ]]; then
    error "Could not select enough scenarios for the exam. Ensure scenarios exist in all 5 domains."
    return 1
  fi

  info "Selected ${actual_count} questions across 5 domains."

  # Write session
  _exam_write_session "${time_seconds}" "${questions_json}"

  # Create ALL namespaces at once (ADR-06: exam mode batch creation)
  info "Creating exam namespaces..."
  local ns
  while IFS= read -r ns; do
    [[ -n "${ns}" ]] || continue
    kubectl create namespace "${ns}" --context "kind-${CKAD_CLUSTER_NAME}" 2>/dev/null || true
  done < <(_exam_get_all_namespaces)

  # Run setup for all scenarios
  info "Setting up exam scenarios..."
  local i
  for i in $(seq 0 $(( actual_count - 1 ))); do
    local yaml_file
    yaml_file="$(jq -r ".questions[${i}].yaml_file" "${CKAD_SESSION_FILE}")"
    local ns
    ns="$(jq -r ".questions[${i}].namespace" "${CKAD_SESSION_FILE}")"
    if [[ -n "${yaml_file}" ]] && [[ -f "${yaml_file}" ]]; then
      local setup_cmds
      setup_cmds="$(yq -r '.setup[]? // empty' "${yaml_file}" 2>/dev/null)"
      if [[ -n "${setup_cmds}" ]]; then
        while IFS= read -r cmd; do
          eval "${cmd}" 2>/dev/null || true
        done <<< "${setup_cmds}"
      fi
    fi
  done

  # Start global timer
  timer_start "${time_seconds}"

  local time_display
  local minutes=$(( time_seconds / 60 ))
  time_display="${minutes} minutes"

  pass "Exam started! ${actual_count} questions, ${time_display} time limit."
  echo ""
  info "Commands:"
  info "  ckad-drill check          — Check current question"
  info "  ckad-drill exam list      — List all questions with status"
  info "  ckad-drill exam next      — Next question"
  info "  ckad-drill exam prev      — Previous question"
  info "  ckad-drill exam jump N    — Jump to question N"
  info "  ckad-drill exam flag      — Flag current question for review"
  info "  ckad-drill exam submit    — Submit exam for grading"
  info "  ckad-drill timer          — Show remaining time"
  echo ""
  info "Hints and solutions are NOT available during exam mode."
  echo ""

  # Show first question
  exam_show_current
}

# Display the current exam question.
exam_show_current() {
  if ! exam_is_active; then
    error "No exam in progress. Run 'ckad-drill exam' to start."
    return "${EXIT_NO_SESSION}"
  fi

  local idx total sid ns title yaml_file domain
  idx="$(_exam_get_current_index)"
  total="$(_exam_get_question_count)"
  sid="$(_exam_get_current_question_field "scenario_id")"
  ns="$(_exam_get_current_question_field "namespace")"
  title="$(_exam_get_current_question_field "title")"
  yaml_file="$(_exam_get_current_question_field "yaml_file")"
  domain="$(_exam_get_current_question_field "domain")"

  local question_num=$(( idx + 1 ))
  local status_str
  status_str="$(_exam_get_current_question_field "status")"
  local status_emoji
  status_emoji="$(_exam_status_emoji "${status_str}")"

  header "Question ${question_num}/${total} ${status_emoji}  —  ${title}"
  info "Domain: ${domain}  |  Namespace: ${ns}"
  echo ""

  # Display description from YAML
  if [[ -n "${yaml_file}" ]] && [[ -f "${yaml_file}" ]]; then
    local description
    description="$(yq -r '.description' "${yaml_file}")"
    echo "${description}"
  fi
  echo ""
  info "Namespace: ${ns}"
  info "Work in this namespace: kubectl config set-context --current --namespace=${ns}"
}

# List all exam questions with status emojis.
exam_list() {
  if ! exam_is_active; then
    error "No exam in progress. Run 'ckad-drill exam' to start."
    return "${EXIT_NO_SESSION}"
  fi

  local total current_idx
  total="$(_exam_get_question_count)"
  current_idx="$(_exam_get_current_index)"

  header "Exam Questions"

  local i
  for i in $(seq 0 $(( total - 1 ))); do
    local sid title q_status domain
    sid="$(jq -r ".questions[${i}].scenario_id" "${CKAD_SESSION_FILE}")"
    title="$(jq -r ".questions[${i}].title" "${CKAD_SESSION_FILE}")"
    q_status="$(jq -r ".questions[${i}].status" "${CKAD_SESSION_FILE}")"
    domain="$(jq -r ".questions[${i}].domain" "${CKAD_SESSION_FILE}")"

    local num=$(( i + 1 ))
    local emoji
    emoji="$(_exam_status_emoji "${q_status}")"
    local pointer=""
    if [[ "${i}" -eq "${current_idx}" ]]; then
      pointer="  <-- current"
    fi
    printf '  %s  %2d. [D%s] %s%s\n' "${emoji}" "${num}" "${domain}" "${title}" "${pointer}"
  done
  echo ""
}

# Navigate to the next question.
exam_next() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  local idx total
  idx="$(_exam_get_current_index)"
  total="$(_exam_get_question_count)"
  local next_idx=$(( idx + 1 ))

  if [[ "${next_idx}" -ge "${total}" ]]; then
    warn "Already at the last question (${total}/${total}). Use 'ckad-drill exam submit' when done."
    return 0
  fi

  _exam_set_current_question "${next_idx}"
  exam_show_current
}

# Navigate to the previous question.
exam_prev() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  local idx
  idx="$(_exam_get_current_index)"

  if [[ "${idx}" -le 0 ]]; then
    warn "Already at the first question (1). Use 'ckad-drill exam next' to move forward."
    return 0
  fi

  _exam_set_current_question $(( idx - 1 ))
  exam_show_current
}

# Jump to question N (1-based for user, 0-based internally).
exam_jump() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  local user_num="${1:-}"
  if [[ -z "${user_num}" ]] || ! [[ "${user_num}" =~ ^[0-9]+$ ]]; then
    error "Usage: ckad-drill exam jump <question-number>"
    return 1
  fi

  local total
  total="$(_exam_get_question_count)"
  local idx=$(( user_num - 1 ))

  if [[ "${idx}" -lt 0 ]] || [[ "${idx}" -ge "${total}" ]]; then
    error "Question ${user_num} does not exist. Valid range: 1-${total}."
    return 1
  fi

  _exam_set_current_question "${idx}"
  exam_show_current
}

# Flag/unflag the current question.
exam_flag() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  local idx
  idx="$(_exam_get_current_index)"
  _exam_flag_question "${idx}"

  local new_status
  new_status="$(jq -r ".questions[${idx}].status" "${CKAD_SESSION_FILE}")"

  local num=$(( idx + 1 ))
  if [[ "${new_status}" == *"flagged"* ]]; then
    info "Question ${num} flagged for review."
  else
    info "Question ${num} unflagged."
  fi
}

# ---------------------------------------------------------------------------
# Status emoji helper
# ---------------------------------------------------------------------------

_exam_status_emoji() {
  local status="${1}"
  case "${status}" in
    checked)          echo "✅" ;;
    checked-flagged)  echo "✅🚩" ;;
    flagged)          echo "🚩" ;;
    pending)          echo "⬜" ;;
    *)                echo "⬜" ;;
  esac
}
```

**Step 2: Run tests**

```bash
bats test/unit/exam.bats
```

Expected: All navigation, list, and display tests should PASS.

**Step 3: Run shellcheck**

```bash
shellcheck lib/exam.sh
```

Expected: No warnings.

**Step 4: Commit**

```bash
git add lib/exam.sh
git commit -m "feat: add exam navigation, display, and start functions

exam_start (with --time and --questions flags), exam_show_current,
exam_list, exam_next, exam_prev, exam_jump, exam_flag. Batch
namespace creation at exam start. Status emoji display."
```

---

### Task 4: Implement Exam Submission & Scoring (Story 7.2)

**Files:**
- Modify: `lib/exam.sh` (add scoring and submit functions)

**Step 1: Add scoring and submission functions to lib/exam.sh**

Append to `lib/exam.sh`:
```bash
# ---------------------------------------------------------------------------
# Scoring (Story 7.2)
# ---------------------------------------------------------------------------

# Calculate total score as a percentage (integer).
_exam_calculate_total_score() {
  local total passed
  total="$(_exam_get_question_count)"
  passed="$(jq '[.questions[] | select(.passed == true)] | length' "${CKAD_SESSION_FILE}")"

  if [[ "${total}" -eq 0 ]]; then
    echo 0
    return
  fi

  echo $(( passed * 100 / total ))
}

# Calculate per-domain scores as a JSON object: {"1": 80, "2": 60, ...}
_exam_calculate_domain_scores() {
  jq '
    .questions
    | group_by(.domain)
    | map({
        domain: (.[0].domain | tostring),
        score: (
          ([.[] | select(.passed == true)] | length) as $passed |
          (length) as $total |
          if $total == 0 then 0
          else ($passed * 100 / $total)
          end
        )
      })
    | from_entries
    | to_entries
    | map({(.value | .domain): .value.score})
    | add // {}
  ' "${CKAD_SESSION_FILE}" 2>/dev/null || \
  jq '
    .questions
    | group_by(.domain)
    | map({
        key: (.[0].domain | tostring),
        value: (
          ([.[] | select(.passed == true)] | length) as $passed |
          (length) as $total |
          if $total == 0 then 0
          else ($passed * 100 / $total)
          end
        )
      })
    | from_entries
  ' "${CKAD_SESSION_FILE}"
}

# Check if a score meets the passing threshold.
_exam_is_passing() {
  local score="${1}"
  [[ "${score}" -ge "${EXAM_PASS_THRESHOLD}" ]]
}

# ---------------------------------------------------------------------------
# Exam check — validate current question only
# ---------------------------------------------------------------------------

# Run validations for the current exam question.
# Called from bin/ckad-drill when mode is exam and user runs `ckad-drill check`.
exam_check_current() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  local idx yaml_file ns
  idx="$(_exam_get_current_index)"
  yaml_file="$(_exam_get_current_question_field "yaml_file")"
  ns="$(_exam_get_current_question_field "namespace")"

  if [[ -z "${yaml_file}" ]] || [[ ! -f "${yaml_file}" ]]; then
    error "Scenario file not found for current question."
    return 1
  fi

  local num=$(( idx + 1 ))
  info "Checking question ${num}..."

  # Load validations from YAML
  local validations_json
  validations_json="$(yq -o=json '.validations' "${yaml_file}")"

  # Run the validator
  local result
  if validator_run_checks "${ns}" "${validations_json}"; then
    _exam_update_question_status "${idx}" "checked" true
    pass "Question ${num}: All checks passed!"
  else
    _exam_update_question_status "${idx}" "checked" false
    fail "Question ${num}: Some checks failed."
  fi
}

# ---------------------------------------------------------------------------
# Exam submission (Story 7.2)
# ---------------------------------------------------------------------------

# Submit the exam: validate ALL questions, calculate scores, display results, clean up.
exam_submit() {
  if ! exam_is_active; then
    error "No exam in progress."
    return "${EXIT_NO_SESSION}"
  fi

  header "Submitting Exam..."
  info "Validating all questions. This may take a moment..."
  echo ""

  local total
  total="$(_exam_get_question_count)"

  # Validate ALL questions (not just previously checked ones)
  local i
  for i in $(seq 0 $(( total - 1 ))); do
    local yaml_file ns sid
    yaml_file="$(jq -r ".questions[${i}].yaml_file" "${CKAD_SESSION_FILE}")"
    ns="$(jq -r ".questions[${i}].namespace" "${CKAD_SESSION_FILE}")"
    sid="$(jq -r ".questions[${i}].scenario_id" "${CKAD_SESSION_FILE}")"

    local num=$(( i + 1 ))

    if [[ -z "${yaml_file}" ]] || [[ ! -f "${yaml_file}" ]]; then
      _exam_update_question_status "${i}" "checked" false
      fail "  Q${num} [${sid}]: Scenario file not found"
      continue
    fi

    local validations_json
    validations_json="$(yq -o=json '.validations' "${yaml_file}" 2>/dev/null)"

    if [[ -z "${validations_json}" ]] || [[ "${validations_json}" == "null" ]]; then
      _exam_update_question_status "${i}" "checked" false
      fail "  Q${num} [${sid}]: No validations defined"
      continue
    fi

    if validator_run_checks "${ns}" "${validations_json}" 2>/dev/null; then
      _exam_update_question_status "${i}" "checked" true
      pass "  Q${num} [${sid}]: PASSED"
    else
      _exam_update_question_status "${i}" "checked" false
      fail "  Q${num} [${sid}]: FAILED"
    fi
  done

  echo ""

  # Calculate scores
  local total_score
  total_score="$(_exam_calculate_total_score)"

  local domain_scores
  domain_scores="$(_exam_calculate_domain_scores)"

  # Display results
  header "Exam Results"

  # Per-domain breakdown
  local domain_names=("" "Application Design & Build" "Application Deployment" "Application Observability & Maintenance" "Application Environment, Configuration & Security" "Services & Networking")
  local domain
  for domain in 1 2 3 4 5; do
    local d_score
    d_score="$(echo "${domain_scores}" | jq -r ".\"${domain}\" // \"N/A\"")"
    local d_name="${domain_names[${domain}]}"
    local d_weight="${EXAM_DOMAIN_WEIGHTS[${domain}]}"

    if [[ "${d_score}" == "N/A" ]] || [[ "${d_score}" == "null" ]]; then
      printf '  Domain %d (%s%% weight): %s — %s\n' "${domain}" "${d_weight}" "N/A" "${d_name}"
    elif [[ "${d_score}" -ge "${EXAM_PASS_THRESHOLD}" ]]; then
      pass "  Domain ${domain} (${d_weight}% weight): ${d_score}% — ${d_name}"
    else
      fail "  Domain ${domain} (${d_weight}% weight): ${d_score}% — ${d_name}"
    fi
  done

  echo ""
  printf '  ─────────────────────────────────\n'
  printf '  Total Score: %d%%\n' "${total_score}"
  printf '  Pass Threshold: %d%%\n' "${EXAM_PASS_THRESHOLD}"
  echo ""

  # Pass/fail verdict
  if _exam_is_passing "${total_score}"; then
    pass "EXAM PASSED! Congratulations!"
  else
    fail "EXAM FAILED — Score: ${total_score}% (need ${EXAM_PASS_THRESHOLD}%)"
  fi

  # Identify weakest domain
  local weakest_domain weakest_score=101
  for domain in 1 2 3 4 5; do
    local d_score
    d_score="$(echo "${domain_scores}" | jq -r ".\"${domain}\" // 101")"
    if [[ "${d_score}" != "null" ]] && [[ "${d_score}" -lt "${weakest_score}" ]]; then
      weakest_score="${d_score}"
      weakest_domain="${domain}"
    fi
  done

  if [[ -n "${weakest_domain:-}" ]] && [[ "${weakest_score}" -lt 100 ]]; then
    echo ""
    warn "Weakest area: Domain ${weakest_domain} — ${domain_names[${weakest_domain}]} (${weakest_score}%)"
    info "Focus your next study session on this domain: ckad-drill drill --domain ${weakest_domain}"
  fi

  # Record exam results to progress
  if declare -f progress_record_exam &>/dev/null; then
    progress_record_exam "${total_score}" "${domain_scores}"
  fi

  # Cleanup all namespaces
  echo ""
  info "Cleaning up exam namespaces..."
  exam_cleanup

  pass "Exam session complete."
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

# Delete all exam namespaces and remove session file.
exam_cleanup() {
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    return 0
  fi

  # Only clean up if this is an exam session
  local mode
  mode="$(jq -r '.mode // ""' "${CKAD_SESSION_FILE}" 2>/dev/null)" || true
  if [[ "${mode}" != "exam" ]]; then
    return 0
  fi

  local ns
  while IFS= read -r ns; do
    [[ -n "${ns}" ]] || continue
    kubectl delete namespace "${ns}" --context "kind-${CKAD_CLUSTER_NAME}" --ignore-not-found=true 2>/dev/null || true
  done < <(_exam_get_all_namespaces)

  rm -f "${CKAD_SESSION_FILE}"
}

# Quit exam without submitting (triggered by Ctrl+C trap or explicit quit).
exam_quit() {
  if ! exam_is_active; then
    return 0
  fi

  warn "Exam aborted. Cleaning up..."
  exam_cleanup
  info "Exam session discarded. No results recorded."
}
```

**Step 2: Run all exam tests**

```bash
cd /home/jeff/Projects/cka
bats test/unit/exam.bats
```

Expected: All PASS.

**Step 3: Run shellcheck**

```bash
shellcheck lib/exam.sh
```

Expected: No warnings.

**Step 4: Commit**

```bash
git add lib/exam.sh
git commit -m "feat: add exam submission, scoring, and cleanup

exam_submit validates ALL questions, calculates per-domain and
total scores, displays pass/fail at 66% threshold, identifies
weakest domain, records results via progress_record_exam(),
and deletes all exam namespaces. exam_quit for Ctrl+C cleanup."
```

---

### Task 5: Wire Exam Commands into bin/ckad-drill (Story 5.1 integration)

**Files:**
- Modify: `bin/ckad-drill`
- Modify: `test/unit/cli.bats`

**Step 1: Add exam tests to cli.bats**

Append to `test/unit/cli.bats`:
```bash
@test "ckad-drill exam with no subcommand shows exam help when no session" {
  # Without a cluster, exam start should error — but the dispatch should work
  run ckad-drill exam --help 2>&1
  # Should not be "Unknown command"
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill hint during exam shows error" {
  # Create a fake exam session
  mkdir -p "$(dirname "${CKAD_SESSION_FILE}")"
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": []
}
EOF

  run ckad-drill hint
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not available during exam"* ]]

  rm -f "${CKAD_SESSION_FILE}"
}

@test "ckad-drill solution during exam shows error" {
  mkdir -p "$(dirname "${CKAD_SESSION_FILE}")"
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 0,
  "questions": []
}
EOF

  run ckad-drill solution
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not available during exam"* ]]

  rm -f "${CKAD_SESSION_FILE}"
}
```

**Step 2: Update bin/ckad-drill dispatch**

Add `source "${CKAD_ROOT}/lib/exam.sh"` to the sourcing block (after progress.sh).

Update the `main()` case/esac to add exam subcommand dispatch:

```bash
    exam)
      shift
      local exam_subcmd="${1:-}"
      case "${exam_subcmd}" in
        "")        exam_start ;;
        list)      exam_list ;;
        next)      exam_next ;;
        prev)      exam_prev ;;
        jump)      shift; exam_jump "$@" ;;
        flag)      exam_flag ;;
        submit)    exam_submit ;;
        quit)      exam_quit ;;
        --time|--questions)
          # Pass all args to exam_start
          exam_start "${exam_subcmd}" "$@"
          ;;
        --help)
          cat <<'EXAM_EOF'
Usage: ckad-drill exam [subcommand] [options]

Start exam:
  exam [--time Nm|Nh] [--questions N]    Start a new exam

During exam:
  exam list              List all questions with status
  exam next              Go to next question
  exam prev              Go to previous question
  exam jump N            Jump to question N
  exam flag              Flag/unflag current question
  exam submit            Submit exam for grading
  exam quit              Quit without scoring

EXAM_EOF
          ;;
        *)
          error "Unknown exam subcommand: ${exam_subcmd}. Run 'ckad-drill exam --help'."
          ;;
      esac
      ;;
```

Update the `cmd_hint` and `cmd_solution` functions (or add them if missing) to block during exam mode:

```bash
cmd_hint() {
  if exam_is_active; then
    error "Hints are not available during exam mode."
    return 1
  fi
  # ... existing hint logic ...
}

cmd_solution() {
  if exam_is_active; then
    error "Solutions are not available during exam mode."
    return 1
  fi
  # ... existing solution logic ...
}
```

Update the `cmd_check` function to dispatch to exam check when in exam mode:

```bash
cmd_check() {
  if exam_is_active; then
    exam_check_current
    return $?
  fi
  # ... existing drill check logic ...
}
```

Add exam cleanup to the trap handler:

```bash
_cleanup() {
  if exam_is_active 2>/dev/null; then
    exam_quit
  fi
  # ... existing cleanup (scenario_cleanup, etc.) ...
}

trap _cleanup EXIT INT TERM
```

**Step 3: Run tests**

```bash
cd /home/jeff/Projects/cka
bats test/unit/cli.bats
bats test/unit/exam.bats
```

Expected: All PASS.

**Step 4: Run shellcheck on everything**

```bash
shellcheck bin/ckad-drill lib/*.sh
```

Expected: No warnings.

**Step 5: Commit**

```bash
git add bin/ckad-drill test/unit/cli.bats
git commit -m "feat: wire exam subcommands into bin/ckad-drill

Dispatch for exam start/list/next/prev/jump/flag/submit/quit.
Block hints and solutions during exam mode. Route 'check' to
exam_check_current when exam is active. Add exam cleanup to
trap handler for Ctrl+C safety."
```

---

### Task 6: Write Integration Tests (Story 7.1 + 7.2)

**Files:**
- Create: `test/integration/exam.bats`

These tests require a running kind cluster and real scenarios.

**Step 1: Write integration tests**

Create `test/integration/exam.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  export PATH="${CKAD_ROOT}/bin:${PATH}"

  # Skip if no cluster
  if ! kind get clusters 2>/dev/null | grep -q "^ckad-drill$"; then
    skip "No ckad-drill cluster running. Run 'ckad-drill start' first."
  fi

  # Ensure clean state
  rm -f "${CKAD_SESSION_FILE}"
}

teardown() {
  # Clean up any exam session left behind
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    local mode
    mode="$(jq -r '.mode // ""' "${CKAD_SESSION_FILE}" 2>/dev/null)" || true
    if [[ "${mode}" == "exam" ]]; then
      ckad-drill exam quit 2>/dev/null || true
    fi
  fi
  rm -f "${CKAD_SESSION_FILE}"
}

@test "exam start creates session file with exam mode" {
  run ckad-drill exam --time 5m --questions 15
  [[ "${status}" -eq 0 ]]
  [[ -f "${CKAD_SESSION_FILE}" ]]

  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}")"
  [[ "${mode}" == "exam" ]]
}

@test "exam start creates all namespaces at once" {
  ckad-drill exam --time 5m --questions 15

  # All namespaces should exist
  local ns
  while IFS= read -r ns; do
    [[ -n "${ns}" ]] || continue
    kubectl get namespace "${ns}" --context "kind-ckad-drill" &>/dev/null
  done < <(jq -r '.questions[].namespace' "${CKAD_SESSION_FILE}")
}

@test "exam list shows all questions" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill exam list
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Exam Questions"* ]]
}

@test "exam next advances to next question" {
  ckad-drill exam --time 5m --questions 15
  local initial
  initial="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${initial}" -eq 0 ]]

  ckad-drill exam next
  local after
  after="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${after}" -eq 1 ]]
}

@test "exam prev goes back to previous question" {
  ckad-drill exam --time 5m --questions 15
  ckad-drill exam next
  ckad-drill exam next
  ckad-drill exam prev
  local current
  current="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${current}" -eq 1 ]]
}

@test "exam jump goes to specified question" {
  ckad-drill exam --time 5m --questions 15
  ckad-drill exam jump 5
  local current
  current="$(jq '.current_question' "${CKAD_SESSION_FILE}")"
  [[ "${current}" -eq 4 ]]  # 0-based
}

@test "exam flag marks question as flagged" {
  ckad-drill exam --time 5m --questions 15
  ckad-drill exam flag
  local q_status
  q_status="$(jq -r '.questions[0].status' "${CKAD_SESSION_FILE}")"
  [[ "${q_status}" == "flagged" ]]
}

@test "exam check validates current question" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill check
  # Should run without crashing — may pass or fail depending on user work
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
  local q_status
  q_status="$(jq -r '.questions[0].status' "${CKAD_SESSION_FILE}")"
  [[ "${q_status}" == "checked" ]]
}

@test "exam submit grades all questions and shows results" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill exam submit
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Exam Results"* ]]
  [[ "${output}" == *"Total Score"* ]]
  [[ "${output}" == *"Domain"* ]]

  # Session file should be cleaned up
  [[ ! -f "${CKAD_SESSION_FILE}" ]]
}

@test "exam submit cleans up all namespaces" {
  ckad-drill exam --time 5m --questions 15

  # Capture namespaces before submit
  local namespaces
  namespaces="$(jq -r '.questions[].namespace' "${CKAD_SESSION_FILE}")"

  ckad-drill exam submit

  # All exam namespaces should be deleted
  local ns
  while IFS= read -r ns; do
    [[ -n "${ns}" ]] || continue
    ! kubectl get namespace "${ns}" --context "kind-ckad-drill" 2>/dev/null
  done <<< "${namespaces}"
}

@test "exam quit cleans up without scoring" {
  ckad-drill exam --time 5m --questions 15

  local namespaces
  namespaces="$(jq -r '.questions[].namespace' "${CKAD_SESSION_FILE}")"

  ckad-drill exam quit

  # Session file cleaned up
  [[ ! -f "${CKAD_SESSION_FILE}" ]]

  # Namespaces cleaned up
  local ns
  while IFS= read -r ns; do
    [[ -n "${ns}" ]] || continue
    ! kubectl get namespace "${ns}" --context "kind-ckad-drill" 2>/dev/null
  done <<< "${namespaces}"
}

@test "hints blocked during exam" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill hint
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not available during exam"* ]]
}

@test "solutions blocked during exam" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill solution
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not available during exam"* ]]
}

@test "cannot start second exam while one is active" {
  ckad-drill exam --time 5m --questions 15
  run ckad-drill exam --time 5m --questions 15
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"already in progress"* ]]
}
```

**Step 2: Run integration tests (requires cluster)**

```bash
cd /home/jeff/Projects/cka
# Only if cluster is running:
bats test/integration/exam.bats
```

Expected: All PASS (when cluster is running and scenarios exist).

**Step 3: Commit**

```bash
git add test/integration/exam.bats
git commit -m "test: add exam mode integration tests

Full lifecycle tests: start, navigate (next/prev/jump), flag,
check, submit with scoring, cleanup. Tests hint/solution blocking,
namespace creation/deletion, and double-start prevention.
Requires running kind cluster."
```

---

### Task 7: Update Makefile and Run Full Suite

**Files:**
- Modify: `Makefile`

**Step 1: Ensure Makefile includes exam.sh in shellcheck**

Verify that `SCRIPTS` wildcard in Makefile (`$(wildcard lib/*.sh)`) already picks up `lib/exam.sh`. If the Makefile uses an explicit list, add `lib/exam.sh` to it.

**Step 2: Run full test suite**

```bash
cd /home/jeff/Projects/cka
make test
```

Expected: shellcheck passes, all unit tests pass.

**Step 3: Run shellcheck on everything**

```bash
shellcheck bin/ckad-drill lib/*.sh
```

Expected: No warnings.

**Step 4: Commit if Makefile changed**

```bash
git add Makefile
git commit -m "chore: verify Makefile includes exam.sh in lint targets"
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 7.1, 7.2 | test/unit/exam.bats, test fixtures | TDD red phase |
| 2 | 7.1 | lib/exam.sh core (session, selection, helpers) | test/unit/exam.bats (partial) |
| 3 | 7.1 | lib/exam.sh navigation & display (start, list, next, prev, jump, flag) | test/unit/exam.bats |
| 4 | 7.2 | lib/exam.sh scoring & submission (submit, score, cleanup, quit) | test/unit/exam.bats |
| 5 | 5.1 | bin/ckad-drill exam dispatch, hint/solution blocking, trap handler | test/unit/cli.bats |
| 6 | 7.1, 7.2 | test/integration/exam.bats | Integration tests (requires cluster) |
| 7 | — | Makefile verification | make test |

**After Sprint 5:** `ckad-drill exam` starts a full mock exam with 15-20 domain-weighted questions, creates all namespaces upfront, provides navigation (next/prev/jump/flag/list), blocks hints/solutions, and on submit grades all questions with per-domain scoring against a 66% pass threshold. Ctrl+C cleanly destroys all exam namespaces via trap handler. Results are recorded to progress.json.

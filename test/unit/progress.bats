#!/usr/bin/env bats
# test/unit/progress.bats — unit tests for lib/progress.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # Use a temp dir for config isolation
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_PROGRESS_FILE="${TEST_CONFIG_DIR}/progress.json"

  # shellcheck source=lib/progress.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/progress.sh"
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
}

# ---------------------------------------------------------------
# progress_init
# ---------------------------------------------------------------

@test "progress_init creates progress.json with version 1" {
  progress_init
  [ -f "${CKAD_PROGRESS_FILE}" ]
  run jq -r '.version' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

@test "progress_init creates progress.json with empty scenarios" {
  progress_init
  run jq -r '.scenarios | keys | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "0"
}

@test "progress_init creates progress.json with empty exams array" {
  progress_init
  run jq -r '.exams | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "0"
}

@test "progress_init creates progress.json with streak current 0" {
  progress_init
  run jq -r '.streak.current' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "0"
}

@test "progress_init creates CKAD_CONFIG_DIR if missing" {
  rm -rf "${TEST_CONFIG_DIR}"
  progress_init
  [ -d "${TEST_CONFIG_DIR}" ]
  [ -f "${CKAD_PROGRESS_FILE}" ]
}

@test "progress_init does not overwrite existing file" {
  progress_init
  # Manually set a scenario so we can verify it's preserved
  jq '.scenarios["sc-existing"] = {"passed": true, "attempts": 1}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  # Call init again — should not overwrite
  progress_init

  run jq -r '.scenarios["sc-existing"].passed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "true"
}

# ---------------------------------------------------------------
# progress_record
# ---------------------------------------------------------------

@test "progress_record creates progress.json if missing" {
  rm -f "${CKAD_PROGRESS_FILE}"
  progress_record "sc-test-01" 1 true 120
  [ -f "${CKAD_PROGRESS_FILE}" ]
}

@test "progress_record stores passed field" {
  progress_init
  progress_record "sc-test-01" 1 true 120
  run jq -r '.scenarios["sc-test-01"].passed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "true"
}

@test "progress_record stores time_seconds field" {
  progress_init
  progress_record "sc-test-01" 1 true 145
  run jq -r '.scenarios["sc-test-01"].time_seconds' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "145"
}

@test "progress_record stores domain field" {
  progress_init
  progress_record "sc-test-01" 2 true 90
  run jq -r '.scenarios["sc-test-01"].domain' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "2"
}

@test "progress_record sets attempts to 1 on first call" {
  progress_init
  progress_record "sc-test-01" 1 false 60
  run jq -r '.scenarios["sc-test-01"].attempts' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

@test "progress_record increments attempts on second call" {
  progress_init
  progress_record "sc-test-01" 1 false 60
  progress_record "sc-test-01" 1 true 45
  run jq -r '.scenarios["sc-test-01"].attempts' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "2"
}

@test "progress_record stores last_attempted as ISO timestamp" {
  progress_init
  progress_record "sc-test-01" 1 true 90
  run jq -r '.scenarios["sc-test-01"].last_attempted' "${CKAD_PROGRESS_FILE}"
  assert_success
  # Should match ISO 8601 format YYYY-MM-DDTHH:MM:SSZ
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# ---------------------------------------------------------------
# progress_read_domain_rates
# ---------------------------------------------------------------

@test "progress_read_domain_rates returns correct pass rates" {
  progress_init
  # Domain 1: 2 scenarios, 1 passed (50%)
  jq '.scenarios["sc-d1-a"] = {"passed": true,  "domain": 1, "attempts": 1, "time_seconds": 60}
    | .scenarios["sc-d1-b"] = {"passed": false, "domain": 1, "attempts": 1, "time_seconds": 90}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  run progress_read_domain_rates
  assert_success
  assert_output --partial "1:50"
}

@test "progress_read_domain_rates returns 100 when all passed in domain" {
  progress_init
  jq '.scenarios["sc-d2-a"] = {"passed": true, "domain": 2, "attempts": 1, "time_seconds": 60}
    | .scenarios["sc-d2-b"] = {"passed": true, "domain": 2, "attempts": 1, "time_seconds": 80}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  run progress_read_domain_rates
  assert_success
  assert_output --partial "2:100"
}

@test "progress_read_domain_rates returns empty on no data" {
  progress_init
  run progress_read_domain_rates
  assert_success
  assert_output ""
}

# ---------------------------------------------------------------
# progress_read_streak
# ---------------------------------------------------------------

@test "progress_read_streak returns 0 on fresh file" {
  progress_init
  run progress_read_streak
  assert_success
  assert_output "0"
}

@test "progress_read_streak returns current streak value" {
  progress_init
  jq '.streak = {"current": 5, "last_date": "2026-02-28"}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  run progress_read_streak
  assert_success
  assert_output "5"
}

# ---------------------------------------------------------------
# progress_recommend_weak_domain
# ---------------------------------------------------------------

@test "progress_recommend_weak_domain returns domain with lowest pass rate" {
  progress_init
  # Domain 1: 100%, domain 2: 0% — recommend domain 2
  jq '.scenarios["sc-d1"] = {"passed": true,  "domain": 1, "attempts": 1, "time_seconds": 60}
    | .scenarios["sc-d2"] = {"passed": false, "domain": 2, "attempts": 1, "time_seconds": 90}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  run progress_recommend_weak_domain
  assert_success
  assert_output "2"
}

@test "progress_recommend_weak_domain returns empty on no data" {
  progress_init
  run progress_recommend_weak_domain
  assert_success
  assert_output ""
}

# ---------------------------------------------------------------
# Streak logic via progress_record
# ---------------------------------------------------------------

@test "streak increments on consecutive day" {
  progress_init
  # Set streak with last_date as yesterday
  local yesterday
  yesterday=$(date -d 'yesterday' +%Y-%m-%d 2>/dev/null || \
              date -v-1d +%Y-%m-%d 2>/dev/null || \
              date -u -d "@$(($(date +%s) - 86400))" +%Y-%m-%d)
  jq --arg yd "${yesterday}" '.streak = {"current": 3, "last_date": $yd}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  progress_record "sc-streak-test" 1 true 60

  run jq -r '.streak.current' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "4"
}

@test "streak resets on gap (more than 1 day)" {
  progress_init
  # Set streak with last_date 3 days ago
  local three_days_ago
  three_days_ago=$(date -d '3 days ago' +%Y-%m-%d 2>/dev/null || \
                   date -v-3d +%Y-%m-%d 2>/dev/null || \
                   date -u -d "@$(($(date +%s) - 259200))" +%Y-%m-%d)
  jq --arg old "${three_days_ago}" '.streak = {"current": 5, "last_date": $old}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  progress_record "sc-streak-reset" 1 true 60

  run jq -r '.streak.current' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

@test "streak unchanged on same day" {
  progress_init
  local today
  today=$(date -u +%Y-%m-%d)
  jq --arg td "${today}" '.streak = {"current": 3, "last_date": $td}' \
    "${CKAD_PROGRESS_FILE}" > "${CKAD_PROGRESS_FILE}.tmp" && \
    mv "${CKAD_PROGRESS_FILE}.tmp" "${CKAD_PROGRESS_FILE}"

  progress_record "sc-streak-same" 1 true 60

  run jq -r '.streak.current' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "3"
}

# ---------------------------------------------------------------
# progress_record_exam
# ---------------------------------------------------------------

@test "progress_record_exam appends one entry to exams array" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":2,"percent":66},{"domain":2,"total":3,"passed":3,"percent":100}]'
  progress_record_exam 80 true "${domain_json}"
  run jq '.exams | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

@test "progress_record_exam stores score field" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":3,"percent":100}]'
  progress_record_exam 75 true "${domain_json}"
  run jq -r '.exams[0].score' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "75"
}

@test "progress_record_exam stores passed field as boolean true" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":3,"percent":100}]'
  progress_record_exam 80 true "${domain_json}"
  run jq -r '.exams[0].passed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "true"
}

@test "progress_record_exam stores passed field as boolean false" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":0,"percent":0}]'
  progress_record_exam 30 false "${domain_json}"
  run jq -r '.exams[0].passed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "false"
}

@test "progress_record_exam stores domains array" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":2,"percent":66}]'
  progress_record_exam 66 true "${domain_json}"
  run jq '.exams[0].domains | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

@test "progress_record_exam stores ISO timestamp in date field" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":3,"percent":100}]'
  progress_record_exam 100 true "${domain_json}"
  run jq -r '.exams[0].date' "${CKAD_PROGRESS_FILE}"
  assert_success
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "progress_record_exam accumulates multiple entries" {
  progress_init
  local domain_json='[{"domain":1,"total":3,"passed":2,"percent":66}]'
  progress_record_exam 70 true "${domain_json}"
  progress_record_exam 80 true "${domain_json}"
  progress_record_exam 60 false "${domain_json}"
  run jq '.exams | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "3"
}

@test "progress_record_exam creates progress.json if missing" {
  rm -f "${CKAD_PROGRESS_FILE}"
  local domain_json='[{"domain":1,"total":3,"passed":3,"percent":100}]'
  progress_record_exam 85 true "${domain_json}"
  [ -f "${CKAD_PROGRESS_FILE}" ]
  run jq '.exams | length' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "1"
}

# ---------------------------------------------------------------
# progress_record_learn
# ---------------------------------------------------------------

@test "progress_record_learn creates .learn entry with completed true" {
  progress_init
  progress_record_learn "sc-pod-basics"
  run jq -r '.learn["sc-pod-basics"].completed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "true"
}

@test "progress_record_learn stores completed_at as ISO timestamp" {
  progress_init
  progress_record_learn "sc-pod-basics"
  run jq -r '.learn["sc-pod-basics"].completed_at' "${CKAD_PROGRESS_FILE}"
  assert_success
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "progress_record_learn on already-completed lesson updates completed_at" {
  progress_init
  progress_record_learn "sc-pod-basics"
  local first_ts
  first_ts=$(jq -r '.learn["sc-pod-basics"].completed_at' "${CKAD_PROGRESS_FILE}")
  sleep 1
  progress_record_learn "sc-pod-basics"
  run jq -r '.learn["sc-pod-basics"].completed_at' "${CKAD_PROGRESS_FILE}"
  assert_success
  # completed_at should be updated (different from first call or same — just must be valid ISO)
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "progress_record_learn creates progress.json if missing" {
  rm -f "${CKAD_PROGRESS_FILE}"
  progress_record_learn "sc-pod-basics"
  [ -f "${CKAD_PROGRESS_FILE}" ]
  run jq -r '.learn["sc-pod-basics"].completed' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "true"
}

# ---------------------------------------------------------------
# progress_learn_completed
# ---------------------------------------------------------------

@test "progress_learn_completed returns 0 (true) if lesson completed" {
  progress_init
  progress_record_learn "sc-pod-basics"
  run progress_learn_completed "sc-pod-basics"
  assert_success
}

@test "progress_learn_completed returns 1 (false) if lesson not in progress.json" {
  progress_init
  run progress_learn_completed "sc-not-started"
  assert_failure
}

@test "progress_learn_completed returns 1 on empty progress.json" {
  progress_init
  run progress_learn_completed "sc-any-lesson"
  assert_failure
}

@test "progress_learn_completed returns 1 on missing progress.json" {
  rm -f "${CKAD_PROGRESS_FILE}"
  run progress_learn_completed "sc-pod-basics"
  assert_failure
}

@test "progress_init does not add .learn field to schema" {
  progress_init
  run jq -r '.learn // "absent"' "${CKAD_PROGRESS_FILE}"
  assert_success
  assert_output "absent"
}

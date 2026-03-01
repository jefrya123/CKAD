#!/usr/bin/env bats
# test/unit/exam.bats — unit tests for lib/exam.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # shellcheck source=lib/session.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/session.sh"

  # shellcheck source=lib/scenario.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/scenario.sh"

  # Use a temp dir for session file to avoid polluting real config
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_SESSION_FILE="${TEST_CONFIG_DIR}/session.json"

  # Create fixture scenario files in temp dirs — one per domain
  FIXTURE_EXAM_DIR="$(mktemp -d)"
  export FIXTURE_EXAM_DIR

  # Create fixture scenarios for domains 1-5
  # Domain 1 — 5 scenarios
  for i in 1 2 3 4 5; do
    cat > "${FIXTURE_EXAM_DIR}/d1-sc${i}.yaml" <<YAML
id: d1-sc${i}
domain: 1
title: "Domain 1 Scenario ${i}"
difficulty: easy
time_limit: 120
namespace: exam-d1-sc${i}
description: "Domain 1 test scenario ${i}"
validations: []
solution:
  steps:
    - "echo done"
YAML
  done

  # Domain 2 — 5 scenarios
  for i in 1 2 3 4 5; do
    cat > "${FIXTURE_EXAM_DIR}/d2-sc${i}.yaml" <<YAML
id: d2-sc${i}
domain: 2
title: "Domain 2 Scenario ${i}"
difficulty: medium
time_limit: 180
namespace: exam-d2-sc${i}
description: "Domain 2 test scenario ${i}"
validations: []
solution:
  steps:
    - "echo done"
YAML
  done

  # Domain 3 — 3 scenarios (fewer than target)
  for i in 1 2 3; do
    cat > "${FIXTURE_EXAM_DIR}/d3-sc${i}.yaml" <<YAML
id: d3-sc${i}
domain: 3
title: "Domain 3 Scenario ${i}"
difficulty: medium
time_limit: 150
namespace: exam-d3-sc${i}
description: "Domain 3 test scenario ${i}"
validations: []
solution:
  steps:
    - "echo done"
YAML
  done

  # Domain 4 — 6 scenarios
  for i in 1 2 3 4 5 6; do
    cat > "${FIXTURE_EXAM_DIR}/d4-sc${i}.yaml" <<YAML
id: d4-sc${i}
domain: 4
title: "Domain 4 Scenario ${i}"
difficulty: hard
time_limit: 240
namespace: exam-d4-sc${i}
description: "Domain 4 test scenario ${i}"
validations: []
solution:
  steps:
    - "echo done"
YAML
  done

  # Domain 5 — 5 scenarios
  for i in 1 2 3 4 5; do
    cat > "${FIXTURE_EXAM_DIR}/d5-sc${i}.yaml" <<YAML
id: d5-sc${i}
domain: 5
title: "Domain 5 Scenario ${i}"
difficulty: easy
time_limit: 120
namespace: exam-d5-sc${i}
description: "Domain 5 test scenario ${i}"
validations: []
solution:
  steps:
    - "echo done"
YAML
  done

  # Override CKAD_DRILL_ROOT scenarios dir for exam functions
  # that call scenario_discover
  TEST_SCENARIOS_DIR="${FIXTURE_EXAM_DIR}"
  export TEST_SCENARIOS_DIR
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
  rm -rf "${FIXTURE_EXAM_DIR}"
}

_load_exam() {
  # shellcheck source=lib/exam.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/exam.sh"
}

_make_question_files() {
  # Output file paths for all fixture scenarios (one per line)
  find "${FIXTURE_EXAM_DIR}" -name "*.yaml" -type f | sort
}

_write_exam_session() {
  # Helper: write a minimal exam session for N questions (from fixture files)
  local count="${1:-5}"
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))

  # Gather file paths
  local -a files=()
  while IFS= read -r f; do
    files+=("$f")
    [[ "${#files[@]}" -ge "${count}" ]] && break
  done < <(find "${FIXTURE_EXAM_DIR}" -name "*.yaml" | sort)

  exam_session_write "${end_at}" "${files[@]}"
}

# ---------------------------------------------------------------------------
# exam_select_questions
# ---------------------------------------------------------------------------

@test "exam_select_questions: returns 16 files by default" {
  _load_exam

  # Provide all fixture files as candidates
  local -a all_files=()
  while IFS= read -r f; do
    all_files+=("$f")
  done < <(_make_question_files)

  run exam_select_questions 16 "${all_files[@]}"
  assert_success
  local count
  count=$(echo "${output}" | grep -c "\.yaml" || true)
  [[ "${count}" -eq 16 ]]
}

@test "exam_select_questions: domain 4 gets most questions (4 target)" {
  _load_exam

  local -a all_files=()
  while IFS= read -r f; do
    all_files+=("$f")
  done < <(_make_question_files)

  run exam_select_questions 16 "${all_files[@]}"
  assert_success

  local d4_count
  d4_count=0
  while IFS= read -r f; do
    local dom
    dom=$(yq -r '.domain // empty' "${f}")
    [[ "${dom}" == "4" ]] && (( d4_count++ )) || true
  done <<< "${output}"
  [[ "${d4_count}" -ge 3 ]]
}

@test "exam_select_questions: all 5 domains represented in output" {
  _load_exam

  local -a all_files=()
  while IFS= read -r f; do
    all_files+=("$f")
  done < <(_make_question_files)

  run exam_select_questions 16 "${all_files[@]}"
  assert_success

  local domains_seen
  domains_seen=$(while IFS= read -r f; do
    yq -r '.domain // empty' "${f}"
  done <<< "${output}" | sort -u | tr '\n' ' ')

  [[ "${domains_seen}" == *"1"* ]]
  [[ "${domains_seen}" == *"2"* ]]
  [[ "${domains_seen}" == *"3"* ]]
  [[ "${domains_seen}" == *"4"* ]]
  [[ "${domains_seen}" == *"5"* ]]
}

@test "exam_select_questions: returns fewer when pool is small" {
  _load_exam

  # Only provide 5 files total
  local -a few_files=()
  while IFS= read -r f; do
    few_files+=("$f")
    [[ "${#few_files[@]}" -ge 5 ]] && break
  done < <(_make_question_files)

  run exam_select_questions 16 "${few_files[@]}"
  assert_success
  local count
  count=$(echo "${output}" | grep -c "\.yaml" || true)
  [[ "${count}" -le 5 ]]
}

# ---------------------------------------------------------------------------
# exam_session_write
# ---------------------------------------------------------------------------

@test "exam_session_write: creates session.json at CKAD_SESSION_FILE" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml" "${FIXTURE_EXAM_DIR}/d2-sc1.yaml")

  run exam_session_write "${end_at}" "${files[@]}"
  assert_success
  [[ -f "${CKAD_SESSION_FILE}" ]]
}

@test "exam_session_write: creates valid JSON with mode=exam" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml" "${FIXTURE_EXAM_DIR}/d2-sc1.yaml")

  exam_session_write "${end_at}" "${files[@]}"
  local mode
  mode=$(jq -r '.mode' "${CKAD_SESSION_FILE}")
  [[ "${mode}" == "exam" ]]
}

@test "exam_session_write: questions array has correct length" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml" "${FIXTURE_EXAM_DIR}/d2-sc1.yaml" "${FIXTURE_EXAM_DIR}/d3-sc1.yaml")

  exam_session_write "${end_at}" "${files[@]}"
  local count
  count=$(jq '.questions | length' "${CKAD_SESSION_FILE}")
  [[ "${count}" -eq 3 ]]
}

@test "exam_session_write: each question has required fields" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml")

  exam_session_write "${end_at}" "${files[@]}"
  local has_id has_file has_ns has_domain has_status has_flagged
  has_id=$(jq -r '.questions[0].id // empty' "${CKAD_SESSION_FILE}")
  has_file=$(jq -r '.questions[0].file // empty' "${CKAD_SESSION_FILE}")
  has_ns=$(jq -r '.questions[0].namespace // empty' "${CKAD_SESSION_FILE}")
  has_domain=$(jq -r '.questions[0].domain // empty' "${CKAD_SESSION_FILE}")
  has_status=$(jq -r '.questions[0].status // empty' "${CKAD_SESSION_FILE}")
  has_flagged=$(jq -r '.questions[0].flagged' "${CKAD_SESSION_FILE}")

  [[ -n "${has_id}" ]]
  [[ -n "${has_file}" ]]
  [[ -n "${has_ns}" ]]
  [[ -n "${has_domain}" ]]
  [[ "${has_status}" == "pending" ]]
  [[ "${has_flagged}" == "false" ]]
}

@test "exam_session_write: current_question starts at 0" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml" "${FIXTURE_EXAM_DIR}/d2-sc1.yaml")

  exam_session_write "${end_at}" "${files[@]}"
  local cur
  cur=$(jq '.current_question' "${CKAD_SESSION_FILE}")
  [[ "${cur}" -eq 0 ]]
}

@test "exam_session_write: end_at is stored as epoch integer" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=("${FIXTURE_EXAM_DIR}/d1-sc1.yaml")

  exam_session_write "${end_at}" "${files[@]}"
  local stored
  stored=$(jq -r '.end_at' "${CKAD_SESSION_FILE}")
  [[ "${stored}" =~ ^[0-9]+$ ]]
  [[ "${stored}" -eq "${end_at}" ]]
}

# ---------------------------------------------------------------------------
# exam_session_read
# ---------------------------------------------------------------------------

@test "exam_session_read: populates SESSION_MODE=exam" {
  _write_exam_session 3
  exam_session_read
  [[ "${SESSION_MODE}" == "exam" ]]
}

@test "exam_session_read: populates EXAM_QUESTIONS as JSON array" {
  _write_exam_session 3
  exam_session_read
  local len
  len=$(echo "${EXAM_QUESTIONS}" | jq 'length')
  [[ "${len}" -eq 3 ]]
}

@test "exam_session_read: populates EXAM_CURRENT as integer" {
  _write_exam_session 3
  exam_session_read
  [[ "${EXAM_CURRENT}" =~ ^[0-9]+$ ]]
  [[ "${EXAM_CURRENT}" -eq 0 ]]
}

@test "exam_session_read: populates EXAM_END_AT as epoch integer" {
  _write_exam_session 3
  exam_session_read
  [[ "${EXAM_END_AT}" =~ ^[0-9]+$ ]]
}

@test "exam_session_read: populates EXAM_QUESTION_COUNT" {
  _write_exam_session 5
  exam_session_read
  [[ "${EXAM_QUESTION_COUNT}" -eq 5 ]]
}

@test "exam_session_read: returns EXIT_NO_SESSION when file missing" {
  _load_exam
  rm -f "${CKAD_SESSION_FILE}"
  run exam_session_read
  [[ "${status}" -eq 3 ]]
}

@test "exam_session_read: returns EXIT_NO_SESSION when mode is not exam" {
  _load_exam
  session_write "drill" "sc-01" "/tmp/sc-01.yaml" "test-ns" 180
  run exam_session_read
  [[ "${status}" -eq 3 ]]
}

@test "exam_session_read: populates EXAM_CURRENT_FILE from current question" {
  _write_exam_session 3
  exam_session_read
  [[ -n "${EXAM_CURRENT_FILE}" ]]
  [[ "${EXAM_CURRENT_FILE}" == *".yaml" ]]
}

# ---------------------------------------------------------------------------
# exam_navigate
# ---------------------------------------------------------------------------

@test "exam_navigate next: increments current_question" {
  _write_exam_session 5
  exam_navigate "next"
  exam_session_read
  [[ "${EXAM_CURRENT}" -eq 1 ]]
}

@test "exam_navigate prev: decrements current_question" {
  _write_exam_session 5
  exam_navigate "next"
  exam_navigate "prev"
  exam_session_read
  [[ "${EXAM_CURRENT}" -eq 0 ]]
}

@test "exam_navigate with integer: jumps to 1-based index" {
  _write_exam_session 5
  exam_navigate 3
  exam_session_read
  [[ "${EXAM_CURRENT}" -eq 2 ]]
}

@test "exam_navigate next: clamps at last question (no wrap)" {
  _write_exam_session 3
  # Navigate to end
  exam_navigate 3
  # Try to go beyond
  exam_navigate "next"
  exam_session_read
  [[ "${EXAM_CURRENT}" -eq 2 ]]
}

@test "exam_navigate prev: clamps at first question (no wrap)" {
  _write_exam_session 3
  # Already at 0
  exam_navigate "prev"
  exam_session_read
  [[ "${EXAM_CURRENT}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# exam_flag
# ---------------------------------------------------------------------------

@test "exam_flag: sets flagged=true on first call" {
  _write_exam_session 3
  exam_flag
  local flagged
  flagged=$(jq -r '.questions[0].flagged' "${CKAD_SESSION_FILE}")
  [[ "${flagged}" == "true" ]]
}

@test "exam_flag: toggles flagged back to false on second call" {
  _write_exam_session 3
  exam_flag
  exam_flag
  local flagged
  flagged=$(jq -r '.questions[0].flagged' "${CKAD_SESSION_FILE}")
  [[ "${flagged}" == "false" ]]
}

# ---------------------------------------------------------------------------
# exam_grade
# ---------------------------------------------------------------------------

@test "exam_grade: returns valid JSON output" {
  _write_exam_session 4
  run exam_grade
  assert_success
  run jq -e '.' <<< "${output}"
  assert_success
}

@test "exam_grade: all pending questions gives 0 score" {
  _write_exam_session 4
  local result
  result=$(exam_grade)
  local score
  score=$(echo "${result}" | jq -r '.score')
  [[ "${score}" -eq 0 ]]
}

@test "exam_grade: pass=false when score below 66%" {
  # 2 passed out of 4 = 50% — fail
  _write_exam_session 4
  # Mark first 2 as passed
  jq '.questions[0].status = "passed" | .questions[1].status = "passed"' \
    "${CKAD_SESSION_FILE}" > "${CKAD_SESSION_FILE}.tmp" && \
    mv "${CKAD_SESSION_FILE}.tmp" "${CKAD_SESSION_FILE}"

  local result
  result=$(exam_grade)
  local passed
  passed=$(echo "${result}" | jq -r '.passed')
  [[ "${passed}" == "false" ]]
}

@test "exam_grade: pass=true when score is at or above 66%" {
  # 3 passed out of 4 = 75% — pass
  _write_exam_session 4
  jq '.questions[0].status = "passed" | .questions[1].status = "passed" | .questions[2].status = "passed"' \
    "${CKAD_SESSION_FILE}" > "${CKAD_SESSION_FILE}.tmp" && \
    mv "${CKAD_SESSION_FILE}.tmp" "${CKAD_SESSION_FILE}"

  local result
  result=$(exam_grade)
  local passed
  passed=$(echo "${result}" | jq -r '.passed')
  [[ "${passed}" == "true" ]]
}

@test "exam_grade: 11/16 questions passed gives pass=true (68.75%)" {
  # Create 16 questions across domains
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(_make_question_files)

  exam_session_write "${end_at}" "${files[@]}"

  # Mark 11 as passed
  local tmp="${CKAD_SESSION_FILE}.tmp"
  jq '
    reduce range(11) as $i (
      .;
      .questions[$i].status = "passed"
    )
  ' "${CKAD_SESSION_FILE}" > "${tmp}" && mv "${tmp}" "${CKAD_SESSION_FILE}"

  local result
  result=$(exam_grade)
  local passed
  passed=$(echo "${result}" | jq -r '.passed')
  [[ "${passed}" == "true" ]]
}

@test "exam_grade: 10/16 questions passed gives pass=false (62.5%)" {
  _load_exam
  local end_at
  end_at=$(( $(date +%s) + 7200 ))
  local -a files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(_make_question_files)

  exam_session_write "${end_at}" "${files[@]}"

  # Mark 10 as passed
  local tmp="${CKAD_SESSION_FILE}.tmp"
  jq '
    reduce range(10) as $i (
      .;
      .questions[$i].status = "passed"
    )
  ' "${CKAD_SESSION_FILE}" > "${tmp}" && mv "${tmp}" "${CKAD_SESSION_FILE}"

  local result
  result=$(exam_grade)
  local passed
  passed=$(echo "${result}" | jq -r '.passed')
  [[ "${passed}" == "false" ]]
}

@test "exam_grade: output contains domains array" {
  _write_exam_session 4
  local result
  result=$(exam_grade)
  local domains_len
  domains_len=$(echo "${result}" | jq '.domains | length')
  [[ "${domains_len}" -ge 1 ]]
}

@test "exam_grade: output contains questions array with id and passed fields" {
  _write_exam_session 3
  local result
  result=$(exam_grade)
  local has_id has_passed
  has_id=$(echo "${result}" | jq -r '.questions[0].id // empty')
  has_passed=$(echo "${result}" | jq -r '.questions[0].passed')
  [[ -n "${has_id}" ]]
  [[ "${has_passed}" == "true" || "${has_passed}" == "false" ]]
}

# ---------------------------------------------------------------------------
# exam_list
# ---------------------------------------------------------------------------

@test "exam_list: outputs one line per question" {
  _write_exam_session 4
  run exam_list
  assert_success
  local count
  count=$(echo "${output}" | grep -c "\." || true)
  [[ "${count}" -ge 4 ]]
}

@test "exam_list: marks current question with >" {
  _write_exam_session 3
  run exam_list
  assert_success
  assert_output --partial ">"
}

@test "exam_list: shows pending status icon [ ] for pending questions" {
  _write_exam_session 3
  run exam_list
  assert_success
  assert_output --partial "[ ]"
}

@test "exam_list: shows passed icon [+] for passed questions" {
  _write_exam_session 3
  jq '.questions[0].status = "passed"' \
    "${CKAD_SESSION_FILE}" > "${CKAD_SESSION_FILE}.tmp" && \
    mv "${CKAD_SESSION_FILE}.tmp" "${CKAD_SESSION_FILE}"

  # Navigate to question 2 so current marker is not on question 1
  exam_navigate 2

  run exam_list
  assert_success
  assert_output --partial "[+]"
}

@test "exam_list: shows failed icon [x] for failed questions" {
  _write_exam_session 3
  jq '.questions[1].status = "failed"' \
    "${CKAD_SESSION_FILE}" > "${CKAD_SESSION_FILE}.tmp" && \
    mv "${CKAD_SESSION_FILE}.tmp" "${CKAD_SESSION_FILE}"

  run exam_list
  assert_success
  assert_output --partial "[x]"
}

@test "exam_list: shows flagged marker for flagged questions" {
  _write_exam_session 3
  exam_flag
  run exam_list
  assert_success
  assert_output --partial "[?]"
}

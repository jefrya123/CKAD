#!/usr/bin/env bats
# test/unit/session.bats — unit tests for lib/session.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # Use a temp dir for session file to avoid polluting real config
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_SESSION_FILE="${TEST_CONFIG_DIR}/session.json"
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
}

_load_session() {
  # shellcheck source=lib/session.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/session.sh"
}

# --- session_write ---

@test "session_write: creates session.json at CKAD_SESSION_FILE" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  [[ -f "${CKAD_SESSION_FILE}" ]]
}

@test "session_write: creates valid JSON (jq can parse it)" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  run jq -e '.' "${CKAD_SESSION_FILE}"
  assert_success
}

@test "session_write: JSON contains correct mode field" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local mode
  mode=$(jq -r '.mode' "${CKAD_SESSION_FILE}")
  [[ "${mode}" == "drill" ]]
}

@test "session_write: JSON contains correct scenario_id field" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local id
  id=$(jq -r '.scenario_id' "${CKAD_SESSION_FILE}")
  [[ "${id}" == "sc-01" ]]
}

@test "session_write: JSON contains correct scenario_file field" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local sf
  sf=$(jq -r '.scenario_file' "${CKAD_SESSION_FILE}")
  [[ "${sf}" == "/path/to/sc-01.yaml" ]]
}

@test "session_write: JSON contains correct namespace field" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local ns
  ns=$(jq -r '.namespace' "${CKAD_SESSION_FILE}")
  [[ "${ns}" == "test-ns" ]]
}

@test "session_write: JSON contains time_limit as number" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local tl
  tl=$(jq -r '.time_limit' "${CKAD_SESSION_FILE}")
  [[ "${tl}" == "180" ]]
}

@test "session_write: JSON contains started_at as ISO 8601 string" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local sa
  sa=$(jq -r '.started_at' "${CKAD_SESSION_FILE}")
  [[ "${sa}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "session_write: JSON contains end_at as epoch seconds (integer)" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local ea
  ea=$(jq -r '.end_at' "${CKAD_SESSION_FILE}")
  [[ "${ea}" =~ ^[0-9]+$ ]]
}

@test "session_write: end_at is approximately started_epoch + time_limit" {
  _load_session
  local before_epoch
  before_epoch=$(date +%s)
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  local after_epoch
  after_epoch=$(date +%s)
  local ea
  ea=$(jq -r '.end_at' "${CKAD_SESSION_FILE}")
  [[ "${ea}" -ge $(( before_epoch + 180 )) ]]
  [[ "${ea}" -le $(( after_epoch + 180 )) ]]
}

@test "session_write: creates CKAD_CONFIG_DIR if it does not exist" {
  _load_session
  local new_dir
  new_dir="$(mktemp -d)"
  rm -rf "${new_dir}"
  CKAD_CONFIG_DIR="${new_dir}"
  CKAD_SESSION_FILE="${new_dir}/session.json"
  session_write "drill" "sc-02" "/path/to/sc-02.yaml" "other-ns" 120
  [[ -d "${new_dir}" ]]
  [[ -f "${new_dir}/session.json" ]]
  rm -rf "${new_dir}"
}

# --- session_read ---

@test "session_read: populates SESSION_MODE from session file" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_MODE}" == "drill" ]]
}

@test "session_read: populates SESSION_SCENARIO_ID" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_SCENARIO_ID}" == "sc-01" ]]
}

@test "session_read: populates SESSION_SCENARIO_FILE" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_SCENARIO_FILE}" == "/path/to/sc-01.yaml" ]]
}

@test "session_read: populates SESSION_NAMESPACE" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_NAMESPACE}" == "test-ns" ]]
}

@test "session_read: populates SESSION_TIME_LIMIT" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_TIME_LIMIT}" == "180" ]]
}

@test "session_read: populates SESSION_END_AT as epoch integer" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  session_read
  [[ "${SESSION_END_AT}" =~ ^[0-9]+$ ]]
}

@test "session_read: returns EXIT_NO_SESSION (3) when session file missing" {
  _load_session
  rm -f "${CKAD_SESSION_FILE}"
  run session_read
  [[ "${status}" -eq 3 ]]
}

# --- session_clear ---

@test "session_clear: removes session file" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  [[ -f "${CKAD_SESSION_FILE}" ]]
  session_clear
  [[ ! -f "${CKAD_SESSION_FILE}" ]]
}

@test "session_clear: succeeds even when file does not exist" {
  _load_session
  rm -f "${CKAD_SESSION_FILE}"
  run session_clear
  assert_success
}

# --- session_require ---

@test "session_require: succeeds and reads session when file exists" {
  _load_session
  session_write "drill" "sc-01" "/path/to/sc-01.yaml" "test-ns" 180
  run session_require
  assert_success
}

@test "session_require: exits EXIT_NO_SESSION when no session file" {
  local root="${CKAD_DRILL_ROOT}"
  local test_dir
  test_dir="$(mktemp -d)"
  run bash -c "
    source '${root}/lib/common.sh'
    CKAD_CONFIG_DIR='${test_dir}'
    CKAD_SESSION_FILE='${test_dir}/session.json'
    source '${root}/lib/session.sh'
    session_require
  "
  [[ "${status}" -eq 3 ]]
  rm -rf "${test_dir}"
}

@test "session_require: prints error message when no session" {
  local root="${CKAD_DRILL_ROOT}"
  local test_dir
  test_dir="$(mktemp -d)"
  run bash -c "
    source '${root}/lib/common.sh'
    CKAD_CONFIG_DIR='${test_dir}'
    CKAD_SESSION_FILE='${test_dir}/session.json'
    source '${root}/lib/session.sh'
    session_require 2>&1
  "
  assert_output --partial "No active drill session"
  rm -rf "${test_dir}"
}

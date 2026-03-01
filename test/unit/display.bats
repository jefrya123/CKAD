#!/usr/bin/env bats
# test/unit/display.bats — unit tests for lib/display.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # shellcheck source=lib/display.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/display.sh"

  MOCK_DIRS=()
}

teardown() {
  local dir
  for dir in "${MOCK_DIRS[@]+"${MOCK_DIRS[@]}"}"; do
    rm -rf "${dir}"
  done
  MOCK_DIRS=()
}

# --- pass() ---

@test "pass: outputs [PASS] and check name to stdout" {
  run pass "pod_exists"
  assert_success
  assert_output --partial "[PASS]"
  assert_output --partial "pod_exists"
}

@test "pass: output goes to stdout not stderr" {
  local stdout stderr
  stdout=$(pass "my_check" 2>/dev/null)
  stderr=$(pass "my_check" 2>&1 >/dev/null)
  [[ "${stdout}" == *"[PASS]"* ]]
  [[ -z "${stderr}" ]]
}

@test "pass: works with multi-word check names" {
  run pass "container image check"
  assert_success
  assert_output --partial "container image check"
}

# --- fail() ---

@test "fail: outputs [FAIL] and check name to stdout" {
  run fail "pod_exists" "pod/nginx" "not found"
  assert_success
  assert_output --partial "[FAIL]"
  assert_output --partial "pod_exists"
}

@test "fail: outputs expected value" {
  run fail "image_check" "nginx:1.25" "nginx:1.24"
  assert_output --partial "expected:"
  assert_output --partial "nginx:1.25"
}

@test "fail: outputs actual value" {
  run fail "image_check" "nginx:1.25" "nginx:1.24"
  assert_output --partial "actual:"
  assert_output --partial "nginx:1.24"
}

@test "fail: expected and actual are on separate lines" {
  run fail "check" "want" "got"
  [[ "${#lines[@]}" -ge 3 ]]
}

# --- header() ---

@test "header: outputs the text" {
  run header "Validation Results"
  assert_success
  assert_output --partial "Validation Results"
}

@test "header: outputs a dash underline" {
  run header "Hello"
  assert_output --partial "-----"
}

@test "header: underline matches text length" {
  run header "AB"
  # Two chars → exactly "--" on a line
  assert_output --partial "--"
  # Should NOT have more dashes than the text length
  [[ "${output}" != *"---"* ]]
}

@test "header: text and underline are on separate lines" {
  run header "Section"
  [[ "${#lines[@]}" -ge 2 ]]
}

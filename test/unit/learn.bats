#!/usr/bin/env bats
# test/unit/learn.bats — unit tests for lib/learn.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # shellcheck source=lib/scenario.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/scenario.sh"

  # shellcheck source=lib/progress.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/progress.sh"

  # shellcheck source=lib/learn.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/learn.sh"

  # Use a temp dir for config isolation
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_PROGRESS_FILE="${TEST_CONFIG_DIR}/progress.json"

  # Temp scenario dir (override CKAD_DRILL_ROOT scenarios dir)
  TEST_SCENARIO_DIR="$(mktemp -d)"
  export CKAD_DRILL_ROOT="${TEST_CONFIG_DIR}/root"
  mkdir -p "${CKAD_DRILL_ROOT}/scenarios"

  # Convenience: create a learn scenario YAML file
  # Usage: _make_scenario DIR ID DOMAIN DIFFICULTY [has_learn_intro]
  _make_scenario() {
    local dir="$1"
    local id="$2"
    local domain="$3"
    local difficulty="$4"
    local has_intro="${5:-true}"

    local file="${dir}/${id}.yaml"
    if [[ "${has_intro}" == "true" ]]; then
      cat > "${file}" <<YAML
id: ${id}
domain: ${domain}
title: "Title for ${id}"
difficulty: ${difficulty}
time_limit: 120
namespace: test-ns-${id}
description: "Description text"
learn_intro: |
  Concept text for ${id}.
YAML
    else
      cat > "${file}" <<YAML
id: ${id}
domain: ${domain}
title: "Title for ${id}"
difficulty: ${difficulty}
time_limit: 120
namespace: test-ns-${id}
description: "Description text"
YAML
    fi
    echo "${file}"
  }
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
  rm -rf "${TEST_SCENARIO_DIR}"
}

# ---------------------------------------------------------------
# learn_discover
# ---------------------------------------------------------------

@test "learn_discover outputs only files with non-empty learn_intro" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-with-intro" 1 easy true
  _make_scenario "${sdir}" "sc-no-intro"   1 easy false

  run learn_discover
  assert_success
  assert_output --partial "sc-with-intro.yaml"
  refute_output --partial "sc-no-intro.yaml"
}

@test "learn_discover with no learn scenarios outputs nothing" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-no-intro-1" 1 easy false
  _make_scenario "${sdir}" "sc-no-intro-2" 2 medium false

  run learn_discover
  assert_success
  assert_output ""
}

@test "learn_discover with empty scenarios dir outputs nothing" {
  run learn_discover
  assert_success
  assert_output ""
}

@test "learn_discover returns files sorted by domain ascending" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d3" 3 easy true
  _make_scenario "${sdir}" "sc-d1" 1 easy true
  _make_scenario "${sdir}" "sc-d2" 2 easy true

  run learn_discover
  assert_success
  # Check ordering: d1 before d2 before d3
  local d1_line d2_line d3_line
  d1_line=$(echo "${output}" | grep -n "sc-d1" | cut -d: -f1)
  d2_line=$(echo "${output}" | grep -n "sc-d2" | cut -d: -f1)
  d3_line=$(echo "${output}" | grep -n "sc-d3" | cut -d: -f1)
  [ "${d1_line}" -lt "${d2_line}" ]
  [ "${d2_line}" -lt "${d3_line}" ]
}

@test "learn_discover sorts easy before medium before hard within domain" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-hard"   1 hard   true
  _make_scenario "${sdir}" "sc-easy"   1 easy   true
  _make_scenario "${sdir}" "sc-medium" 1 medium true

  run learn_discover
  assert_success
  local easy_line medium_line hard_line
  easy_line=$(echo "${output}" | grep -n "sc-easy" | cut -d: -f1)
  medium_line=$(echo "${output}" | grep -n "sc-medium" | cut -d: -f1)
  hard_line=$(echo "${output}" | grep -n "sc-hard" | cut -d: -f1)
  [ "${easy_line}" -lt "${medium_line}" ]
  [ "${medium_line}" -lt "${hard_line}" ]
}

# ---------------------------------------------------------------
# learn_list_domain
# ---------------------------------------------------------------

@test "learn_list_domain outputs uncompleted lesson with [ ] prefix" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy" 1 easy true

  run learn_list_domain 1
  assert_success
  assert_output --partial "[ ]"
  assert_output --partial "Title for sc-d1-easy"
}

@test "learn_list_domain outputs completed lesson with [x] prefix" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy" 1 easy true
  progress_record_learn "sc-d1-easy"

  run learn_list_domain 1
  assert_success
  assert_output --partial "[x]"
  assert_output --partial "Title for sc-d1-easy"
}

@test "learn_list_domain outputs nothing for domain with no learn scenarios" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-no-intro" 1 easy false

  run learn_list_domain 1
  assert_success
  assert_output ""
}

@test "learn_list_domain outputs nothing for non-existent domain" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy" 1 easy true

  run learn_list_domain 99
  assert_success
  assert_output ""
}

@test "learn_list_domain lists multiple lessons in progressive order" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-hard"   1 hard   true
  _make_scenario "${sdir}" "sc-d1-easy"   1 easy   true
  _make_scenario "${sdir}" "sc-d1-medium" 1 medium true

  run learn_list_domain 1
  assert_success
  local easy_line medium_line hard_line
  easy_line=$(echo "${output}" | grep -n "sc-d1-easy" | cut -d: -f1)
  medium_line=$(echo "${output}" | grep -n "sc-d1-medium" | cut -d: -f1)
  hard_line=$(echo "${output}" | grep -n "sc-d1-hard" | cut -d: -f1)
  [ "${easy_line}" -lt "${medium_line}" ]
  [ "${medium_line}" -lt "${hard_line}" ]
}

@test "learn_list_domain only shows scenarios for the requested domain" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy" 1 easy true
  _make_scenario "${sdir}" "sc-d2-easy" 2 easy true

  run learn_list_domain 1
  assert_success
  assert_output --partial "sc-d1-easy"
  refute_output --partial "sc-d2-easy"
}

# ---------------------------------------------------------------
# learn_show_intro
# ---------------------------------------------------------------

@test "learn_show_intro outputs learn_intro text from YAML" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  local file
  file=$(_make_scenario "${sdir}" "sc-intro-test" 1 easy true)

  run learn_show_intro "${file}"
  assert_success
  assert_output --partial "Concept text for sc-intro-test"
}

@test "learn_show_intro on file with no learn_intro outputs empty string" {
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  local file
  file=$(_make_scenario "${sdir}" "sc-no-intro" 1 easy false)

  run learn_show_intro "${file}"
  assert_success
  assert_output ""
}

# ---------------------------------------------------------------
# learn_next_lesson
# ---------------------------------------------------------------

@test "learn_next_lesson returns first uncompleted lesson file path" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy"   1 easy   true
  _make_scenario "${sdir}" "sc-d1-medium" 1 medium true

  run learn_next_lesson 1
  assert_success
  assert_output --partial "sc-d1-easy"
}

@test "learn_next_lesson skips completed lessons" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy"   1 easy   true
  _make_scenario "${sdir}" "sc-d1-medium" 1 medium true
  progress_record_learn "sc-d1-easy"

  run learn_next_lesson 1
  assert_success
  assert_output --partial "sc-d1-medium"
}

@test "learn_next_lesson outputs empty string when all lessons completed" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-easy" 1 easy true
  progress_record_learn "sc-d1-easy"

  run learn_next_lesson 1
  assert_success
  assert_output ""
}

@test "learn_next_lesson outputs empty string when no learn scenarios for domain" {
  progress_init
  local sdir="${CKAD_DRILL_ROOT}/scenarios"
  _make_scenario "${sdir}" "sc-d1-no-intro" 1 easy false

  run learn_next_lesson 1
  assert_success
  assert_output ""
}

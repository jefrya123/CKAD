#!/usr/bin/env bats
# test/unit/schema.bats — schema validation tests for scenario YAML files
# Tests that scenario_load correctly handles valid and invalid YAML structures.
# Does NOT require Docker or a kind cluster.

setup() {
  # Resolve repo root relative to this test file
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  # Load bats helper libraries
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=../../lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # shellcheck source=../../lib/display.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/display.sh"

  # shellcheck source=../../lib/scenario.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/scenario.sh"

  FIXTURE_DIR="${CKAD_DRILL_ROOT}/test/fixtures"
}

# --- valid scenario loading ---

@test "scenario_load succeeds on minimal valid scenario" {
  run scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  assert_success
}

@test "scenario_load sets SCENARIO_ID from minimal scenario" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ -n "${SCENARIO_ID}" ]]
}

@test "scenario_load succeeds on all-checks scenario" {
  run scenario_load "${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  assert_success
}

@test "scenario_load succeeds on scenario with all optional fields" {
  run scenario_load "${FIXTURE_DIR}/valid/all-fields-scenario.yaml"
  assert_success
}

@test "scenario_load sets SCENARIO_ID on all-fields scenario" {
  scenario_load "${FIXTURE_DIR}/valid/all-fields-scenario.yaml"
  [[ "${SCENARIO_ID}" == "all-fields-test" ]]
}

@test "scenario_load sets SCENARIO_NAMESPACE from all-fields scenario" {
  scenario_load "${FIXTURE_DIR}/valid/all-fields-scenario.yaml"
  [[ "${SCENARIO_NAMESPACE}" == "test-all-fields" ]]
}

@test "scenario_load sets SCENARIO_DIFFICULTY from all-fields scenario" {
  scenario_load "${FIXTURE_DIR}/valid/all-fields-scenario.yaml"
  [[ "${SCENARIO_DIFFICULTY}" == "easy" ]]
}

# --- invalid scenario: missing required fields ---

@test "scenario_load fails on missing-id fixture" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-id.yaml"
  [[ "${status}" -ne 0 ]]
}

@test "scenario_load returns EXIT_PARSE_ERROR for missing-id fixture" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-id.yaml"
  [[ "${status}" -eq "${EXIT_PARSE_ERROR}" ]]
}

@test "scenario_load fails on missing-domain fixture" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-domain.yaml"
  [[ "${status}" -ne 0 ]]
}

@test "scenario_load returns EXIT_PARSE_ERROR for missing-domain fixture" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-domain.yaml"
  [[ "${status}" -eq "${EXIT_PARSE_ERROR}" ]]
}

# --- invalid scenario: missing validations ---

@test "scenario_load handles missing-validations fixture without crashing" {
  # missing-validations.yaml has no validations field — scenario_load only checks
  # required fields (id, domain, title, difficulty, time_limit), not validations.
  # This fixture should LOAD successfully (schema is structurally valid),
  # but validator_run_checks would find no checks to run.
  run scenario_load "${FIXTURE_DIR}/invalid/missing-validations.yaml"
  assert_success
}

@test "scenario_load sets SCENARIO_ID from missing-validations fixture" {
  scenario_load "${FIXTURE_DIR}/invalid/missing-validations.yaml"
  [[ "${SCENARIO_ID}" == "missing-validations" ]]
}

# --- invalid scenario: bad difficulty value ---

@test "scenario_load handles bad-difficulty fixture without crashing" {
  # bad-difficulty.yaml has difficulty: extreme — scenario_load does not validate
  # the difficulty enum (it trusts the field exists). Load should succeed.
  run scenario_load "${FIXTURE_DIR}/invalid/bad-difficulty.yaml"
  assert_success
}

@test "scenario_load stores the raw difficulty value from bad-difficulty fixture" {
  scenario_load "${FIXTURE_DIR}/invalid/bad-difficulty.yaml"
  [[ "${SCENARIO_DIFFICULTY}" == "extreme" ]]
}

# --- invalid scenario: empty solution steps ---

@test "scenario_load handles empty-solution fixture without crashing" {
  # empty-solution.yaml has solution.steps: [] — scenario_load does not parse
  # solution steps; they are read later during solve/hint display.
  run scenario_load "${FIXTURE_DIR}/invalid/empty-solution.yaml"
  assert_success
}

@test "scenario_load sets SCENARIO_ID from empty-solution fixture" {
  scenario_load "${FIXTURE_DIR}/invalid/empty-solution.yaml"
  [[ "${SCENARIO_ID}" == "empty-solution" ]]
}

# --- smoke test: all scenario files in scenarios/ load without error ---

@test "all scenario files in scenarios/ have required fields" {
  # Efficiently validate all 70 scenario files in one yq pass.
  # scenario_load requires: id, domain, title, difficulty, time_limit.
  # Running scenario_load per file (5 yq calls each) would take ~100s for 70 files.
  # Instead, we use yq's multi-file mode to check all files in a single call.
  local scenarios_dir="${CKAD_DRILL_ROOT}/scenarios"

  # Collect files with missing required fields
  local bad_files
  bad_files=$(
    yq -r '
      select(.id == null or .domain == null or .title == null
             or .difficulty == null or .time_limit == null)
      | "MISSING_FIELD"
    ' "${scenarios_dir}"/**/*.yaml 2>/dev/null | grep -c "MISSING_FIELD" || true
  )

  [[ "${bad_files}" -eq 0 ]] || {
    echo "Found ${bad_files} scenario file(s) with missing required fields"
    return 1
  }
}

@test "all scenario files in scenarios/ are valid YAML" {
  local scenarios_dir="${CKAD_DRILL_ROOT}/scenarios"
  local failed=0

  # yq exits non-zero if any file is malformed YAML
  if ! yq -r '.' "${scenarios_dir}"/**/*.yaml > /dev/null 2>&1; then
    failed=1
  fi

  [[ "${failed}" -eq 0 ]] || {
    echo "One or more scenario files contain invalid YAML"
    return 1
  }
}

#!/usr/bin/env bats
# test/unit/scenario.bats — unit tests for lib/scenario.sh

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

  # shellcheck source=lib/scenario.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/scenario.sh"

  FIXTURE_DIR="${CKAD_DRILL_ROOT}/test/fixtures"
  MOCK_DIRS=()
}

teardown() {
  local dir
  for dir in "${MOCK_DIRS[@]+"${MOCK_DIRS[@]}"}"; do
    rm -rf "${dir}"
  done
  MOCK_DIRS=()
}

# _mock_command_present — minimal version of helper
_mock_command_present() {
  local name="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${mock_dir}/${name}"
  chmod +x "${mock_dir}/${name}"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# _mock_command_missing — minimal version of helper
_mock_command_missing() {
  local name="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 127\n' > "${mock_dir}/${name}"
  chmod +x "${mock_dir}/${name}"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# --- scenario_load: valid scenarios ---

@test "scenario_load: loads minimal scenario and sets SCENARIO_ID" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_ID}" == "test-minimal" ]]
}

@test "scenario_load: sets SCENARIO_DOMAIN" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_DOMAIN}" == "1" ]]
}

@test "scenario_load: sets SCENARIO_TITLE" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ -n "${SCENARIO_TITLE}" ]]
}

@test "scenario_load: sets SCENARIO_DIFFICULTY" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_DIFFICULTY}" == "easy" ]]
}

@test "scenario_load: sets SCENARIO_TIME_LIMIT" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_TIME_LIMIT}" == "60" ]]
}

@test "scenario_load: sets SCENARIO_FILE to the loaded file path" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_FILE}" == "${FIXTURE_DIR}/valid/minimal-scenario.yaml" ]]
}

@test "scenario_load: namespace defaults to drill-<id> when not specified" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_NAMESPACE}" == "drill-test-minimal" ]]
}

@test "scenario_load: uses explicit namespace when specified in YAML" {
  scenario_load "${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  [[ "${SCENARIO_NAMESPACE}" == "all-checks-ns" ]]
}

@test "scenario_load: sets SCENARIO_HAS_HELM=false when no helm tag" {
  scenario_load "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  [[ "${SCENARIO_HAS_HELM}" == "false" ]]
}

@test "scenario_load: sets SCENARIO_HAS_HELM=true for helm-tagged scenario" {
  scenario_load "${FIXTURE_DIR}/valid/helm-scenario.yaml"
  [[ "${SCENARIO_HAS_HELM}" == "true" ]]
}

# --- scenario_load: invalid scenarios ---

@test "scenario_load: returns EXIT_PARSE_ERROR for missing id" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-id.yaml"
  [[ "${status}" -eq "${EXIT_PARSE_ERROR}" ]]
}

@test "scenario_load: returns EXIT_PARSE_ERROR for missing domain" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-domain.yaml"
  [[ "${status}" -eq "${EXIT_PARSE_ERROR}" ]]
}

@test "scenario_load: prints error message for missing required field" {
  run scenario_load "${FIXTURE_DIR}/invalid/missing-id.yaml"
  assert_output --partial "missing required field"
}

# --- scenario_discover ---

@test "scenario_discover: finds YAML files in a directory" {
  run scenario_discover "${FIXTURE_DIR}/valid"
  assert_success
  assert_output --partial "minimal-scenario.yaml"
}

@test "scenario_discover: finds multiple YAML files" {
  run scenario_discover "${FIXTURE_DIR}/valid"
  assert_success
  local count
  count=$(echo "${output}" | grep -c "\.yaml" || true)
  [[ "${count}" -ge 3 ]]
}

@test "scenario_discover: warns on duplicate IDs and skips second" {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cat > "${tmp_dir}/first.yaml" <<'YAML'
id: dup-id
domain: 1
title: First
difficulty: easy
time_limit: 60
YAML
  cat > "${tmp_dir}/second.yaml" <<'YAML'
id: dup-id
domain: 1
title: Second
difficulty: easy
time_limit: 60
YAML

  run scenario_discover "${tmp_dir}"
  assert_output --partial "Duplicate"
  # Only path output lines (not WARN lines) should contain file paths
  local path_count
  path_count=$(echo "${output}" | grep "\.yaml$" | grep -vc "\[WARN\]" || true)
  [[ "${path_count}" -eq 1 ]]

  rm -rf "${tmp_dir}"
}

@test "scenario_discover: skips files missing id field" {
  run scenario_discover "${FIXTURE_DIR}/invalid"
  assert_output --partial "Skipping"
}

# --- scenario_filter ---

@test "scenario_filter: returns all files when no filter set" {
  local -a files=("${FIXTURE_DIR}/valid/minimal-scenario.yaml" "${FIXTURE_DIR}/valid/all-checks-scenario.yaml")
  unset FILTER_DOMAIN FILTER_DIFFICULTY
  run scenario_filter "${files[@]}"
  assert_success
  local count
  count=$(echo "${output}" | grep -c "\.yaml" || true)
  [[ "${count}" -eq 2 ]]
}

@test "scenario_filter: filters by domain" {
  local -a files=("${FIXTURE_DIR}/valid/minimal-scenario.yaml" "${FIXTURE_DIR}/valid/helm-scenario.yaml")
  FILTER_DOMAIN="3"
  run scenario_filter "${files[@]}"
  unset FILTER_DOMAIN
  assert_success
  assert_output --partial "helm-scenario.yaml"
  [[ "${output}" != *"minimal-scenario.yaml"* ]]
}

@test "scenario_filter: filters by difficulty" {
  local -a files=("${FIXTURE_DIR}/valid/minimal-scenario.yaml" "${FIXTURE_DIR}/valid/all-checks-scenario.yaml")
  FILTER_DIFFICULTY="hard"
  run scenario_filter "${files[@]}"
  unset FILTER_DIFFICULTY
  assert_success
  assert_output --partial "all-checks-scenario.yaml"
  [[ "${output}" != *"minimal-scenario.yaml"* ]]
}

@test "scenario_filter: returns nothing when no files match domain filter" {
  local -a files=("${FIXTURE_DIR}/valid/minimal-scenario.yaml")
  FILTER_DOMAIN="99"
  run scenario_filter "${files[@]}"
  unset FILTER_DOMAIN
  assert_success
  [[ -z "${output}" ]]
}

@test "scenario_filter: handles empty file list gracefully" {
  unset FILTER_DOMAIN FILTER_DIFFICULTY
  run scenario_filter
  assert_success
  [[ -z "${output}" ]]
}

# --- scenario_setup / scenario_cleanup ---

@test "scenario_setup: calls kubectl to create namespace" {
  _mock_command_present kubectl
  run scenario_setup "${FIXTURE_DIR}/valid/minimal-scenario.yaml"
  assert_success
}

@test "scenario_cleanup: succeeds when SCENARIO_NAMESPACE is set" {
  _mock_command_present kubectl
  SCENARIO_NAMESPACE="drill-test-minimal"
  run scenario_cleanup
  assert_success
}

@test "scenario_cleanup: returns 0 when SCENARIO_NAMESPACE is unset" {
  unset SCENARIO_NAMESPACE
  run scenario_cleanup
  assert_success
}

@test "scenario_setup: errors when helm required but not installed" {
  local fixture_dir="${FIXTURE_DIR}"
  local root="${CKAD_DRILL_ROOT}"
  run bash -c "
    source '${root}/lib/common.sh'
    source '${root}/lib/display.sh'
    source '${root}/lib/scenario.sh'

    # Override command to simulate helm missing
    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && \"\${name}\" == 'helm' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    scenario_setup '${fixture_dir}/valid/helm-scenario.yaml' 2>&1
  "
  [[ "${status}" -ne 0 ]]
  assert_output --partial "Helm"
}

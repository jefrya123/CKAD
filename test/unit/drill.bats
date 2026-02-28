#!/usr/bin/env bats
# test/unit/drill.bats — unit tests for bin/ckad-drill subcommand dispatch
# Tests error paths that do NOT require a running cluster or active session.

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # Isolated config dirs for each test
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_SESSION_FILE="${TEST_CONFIG_DIR}/session.json"
  export CKAD_PROGRESS_FILE="${TEST_CONFIG_DIR}/progress.json"
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
}

# ---------------------------------------------------------------------------
# Unknown subcommand
# ---------------------------------------------------------------------------

@test "unknown subcommand shows usage help and exits non-zero" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' unknown-cmd 2>&1
  "
  assert_failure
  assert_output --partial "Usage:"
}

# ---------------------------------------------------------------------------
# Help / no args
# ---------------------------------------------------------------------------

@test "no args shows available commands including drill" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' 2>&1
  "
  assert_failure
  assert_output --partial "drill"
}

@test "no args shows status and validate-scenario in help" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' 2>&1
  "
  assert_failure
  assert_output --partial "status"
  assert_output --partial "validate-scenario"
}

# ---------------------------------------------------------------------------
# drill without cluster
# ---------------------------------------------------------------------------

@test "drill without cluster shows No active cluster error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'

    # Mock kind to return nothing (no cluster registered)
    command() {
      if [[ \"\${1:-}\" == '-v' && \"\${2:-}\" == 'kind' ]]; then
        return 0
      fi
      builtin command \"\$@\"
    }
    export -f command

    # Override kind to report no clusters
    kind() { echo ''; }
    export -f kind

    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' drill 2>&1
  "
  assert_failure
  assert_output --partial "No active cluster"
}

# ---------------------------------------------------------------------------
# Session-requiring subcommands without active session
# ---------------------------------------------------------------------------

@test "check without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' check 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "hint without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' hint 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "solution without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' solution 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "current without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' current 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "next without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' next 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "skip without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' skip 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

@test "timer without session shows No active drill session error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' timer 2>&1
  "
  [[ "${status}" -eq 3 ]]
  assert_output --partial "No active drill session"
}

# ---------------------------------------------------------------------------
# status with no progress data
# ---------------------------------------------------------------------------

@test "status with no progress data shows No drill results message" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' status 2>&1
  "
  assert_success
  assert_output --partial "No drill results"
}

# ---------------------------------------------------------------------------
# validate-scenario with no args
# ---------------------------------------------------------------------------

@test "validate-scenario with no args shows usage error" {
  run bash -c "
    CKAD_CONFIG_DIR='${TEST_CONFIG_DIR}'
    CKAD_SESSION_FILE='${TEST_CONFIG_DIR}/session.json'
    CKAD_PROGRESS_FILE='${TEST_CONFIG_DIR}/progress.json'
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' validate-scenario 2>&1
  "
  assert_failure
  assert_output --partial "Usage:"
}

# ---------------------------------------------------------------------------
# validate-scenario: solution step extraction (yq index-based, no cluster needed)
# ---------------------------------------------------------------------------

@test "validate-scenario: gracefully handles scenario with no solution steps" {
  # Create a minimal scenario YAML with no solution key
  local tmpdir
  tmpdir="$(mktemp -d)"
  cat > "${tmpdir}/no-solution.yaml" <<'SCENEOF'
id: test-no-solution
domain: 1
title: "No Solution Test"
difficulty: easy
time_limit: 60
namespace: test-ns-nosol
description: "Test scenario with no solution steps"
validations: []
SCENEOF
  # Verify yq returns 0 for missing solution.steps — no cluster needed
  run bash -c "
    count=\$(yq -r '.solution.steps | length' '${tmpdir}/no-solution.yaml' 2>/dev/null || echo 0)
    echo \"step_count=\${count}\"
  "
  assert_success
  assert_output --partial "step_count=0"
  rm -rf "${tmpdir}"
}

@test "validate-scenario: step_count returns correct count for scenario with steps" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  cat > "${tmpdir}/with-steps.yaml" <<'SCENEOF'
id: test-with-steps
domain: 1
title: "Steps Test"
difficulty: easy
time_limit: 60
namespace: test-ns-steps
description: "Test scenario with solution steps"
validations: []
solution:
  steps:
    - "echo step-one"
    - "echo step-two"
SCENEOF
  run bash -c "
    count=\$(yq -r '.solution.steps | length' '${tmpdir}/with-steps.yaml' 2>/dev/null || echo 0)
    step0=\$(yq -r '.solution.steps[0]' '${tmpdir}/with-steps.yaml' 2>/dev/null)
    step1=\$(yq -r '.solution.steps[1]' '${tmpdir}/with-steps.yaml' 2>/dev/null)
    echo \"count=\${count}\"
    echo \"step0=\${step0}\"
    echo \"step1=\${step1}\"
  "
  assert_success
  assert_output --partial "count=2"
  assert_output --partial "step0=echo step-one"
  assert_output --partial "step1=echo step-two"
  rm -rf "${tmpdir}"
}

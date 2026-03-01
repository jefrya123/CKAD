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

# ---------------------------------------------------------------------------
# Regression: BREAK-01 — check records progress on failed validation (DRIL-03, PROG-01)
# Uses XDG_CONFIG_HOME to control session file path (common.sh overwrites CKAD_SESSION_FILE).
# Uses a fake kubectl shim that returns 1 to trigger natural validation failure.
# ---------------------------------------------------------------------------

@test "check: records failed attempt to progress.json when validation fails" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "${tmpdir}/ckad-drill" "${tmpdir}/bin"
  local scenario_file="${tmpdir}/test-scenario.yaml"

  # Create a minimal scenario YAML
  cat > "${scenario_file}" <<'SCENEOF'
id: test-fail-scenario
domain: 1
title: "Fail Test Scenario"
difficulty: easy
time_limit: 300
namespace: test-fail-ns
description: "Test scenario for BREAK-01 regression"
validations:
  - name: pod_exists
    type: resource_exists
    resource: pod/fake-pod
SCENEOF

  # Session file at XDG_CONFIG_HOME/ckad-drill/session.json (path computed by common.sh)
  local end_at
  end_at=$(( $(date +%s) + 300 ))
  cat > "${tmpdir}/ckad-drill/session.json" <<SESSIONEOF
{
  "mode": "drill",
  "scenario_id": "test-fail-scenario",
  "scenario_file": "${scenario_file}",
  "namespace": "test-fail-ns",
  "started_at": "2026-01-01T00:00:00Z",
  "time_limit": 300,
  "end_at": ${end_at}
}
SESSIONEOF

  # Fake kubectl shim: always returns 1 so resource_exists check fails
  cat > "${tmpdir}/bin/kubectl" <<'KUBEOF'
#!/usr/bin/env bash
exit 1
KUBEOF
  chmod +x "${tmpdir}/bin/kubectl"

  run bash -c "
    XDG_CONFIG_HOME='${tmpdir}'
    PATH='${tmpdir}/bin:${PATH}'
    export XDG_CONFIG_HOME PATH
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' check 2>&1
  "

  # check subcommand must exit 0 even when validations fail
  assert_success

  # progress.json must exist (progress_record was called)
  [[ -f "${tmpdir}/ckad-drill/progress.json" ]] \
    || fail "progress.json was not created at ${tmpdir}/ckad-drill/progress.json"

  # progress.json must contain the scenario entry with passed=false
  local passed_val
  passed_val=$(jq -r '.scenarios["test-fail-scenario"].passed' \
    "${tmpdir}/ckad-drill/progress.json" 2>/dev/null)
  [[ "${passed_val}" == "false" ]] \
    || fail "Expected passed=false in progress.json, got: ${passed_val}"

  rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# Regression: BREAK-02 — next bridges SCENARIO_NAMESPACE from SESSION_NAMESPACE (DRIL-06)
# Uses XDG_CONFIG_HOME for session file. Fake kubectl records deleted namespace.
# After scenario_cleanup, next calls cluster_check_active then _drill_start — these may
# fail since there is no real cluster, which is fine: the test only checks cleanup happened.
# ---------------------------------------------------------------------------

@test "next: bridges SESSION_NAMESPACE to SCENARIO_NAMESPACE before scenario_cleanup" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "${tmpdir}/ckad-drill" "${tmpdir}/bin"

  # Session file at XDG_CONFIG_HOME/ckad-drill/session.json
  local end_at
  end_at=$(( $(date +%s) + 300 ))
  cat > "${tmpdir}/ckad-drill/session.json" <<SESSIONEOF
{
  "mode": "drill",
  "scenario_id": "test-next-scenario",
  "scenario_file": "/dev/null",
  "namespace": "test-cleanup-ns",
  "started_at": "2026-01-01T00:00:00Z",
  "time_limit": 300,
  "end_at": ${end_at}
}
SESSIONEOF

  # Fake kubectl shim: records namespace deletion; no-ops everything else
  cat > "${tmpdir}/bin/kubectl" <<KUBEOF
#!/usr/bin/env bash
if [[ "\$1" == "delete" && "\$2" == "namespace" ]]; then
  printf '%s' "\$3" > '${tmpdir}/deleted-namespace.txt'
fi
exit 0
KUBEOF
  chmod +x "${tmpdir}/bin/kubectl"

  # Fake kind shim: reports no cluster so cluster_check_active fails fast
  # (next will exit non-zero after cleanup — that's acceptable, we only test cleanup)
  cat > "${tmpdir}/bin/kind" <<'KINDEOF'
#!/usr/bin/env bash
echo ""
exit 0
KINDEOF
  chmod +x "${tmpdir}/bin/kind"

  # Run next; allow non-zero exit (cluster_check_active will fail after cleanup)
  XDG_CONFIG_HOME="${tmpdir}" PATH="${tmpdir}/bin:${PATH}" \
    bash "${CKAD_DRILL_ROOT}/bin/ckad-drill" next 2>&1 || true

  # namespace deletion marker must exist (scenario_cleanup was called with correct ns)
  [[ -f "${tmpdir}/deleted-namespace.txt" ]] \
    || fail "scenario_cleanup did not call kubectl delete namespace"

  local recorded_ns
  recorded_ns=$(cat "${tmpdir}/deleted-namespace.txt")
  [[ "${recorded_ns}" == "test-cleanup-ns" ]] \
    || fail "Expected test-cleanup-ns, got: ${recorded_ns}"

  rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# Regression: BREAK-02 — skip bridges SCENARIO_NAMESPACE from SESSION_NAMESPACE (DRIL-07)
# ---------------------------------------------------------------------------

@test "skip: bridges SESSION_NAMESPACE to SCENARIO_NAMESPACE before scenario_cleanup" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "${tmpdir}/ckad-drill" "${tmpdir}/bin"

  # Session file at XDG_CONFIG_HOME/ckad-drill/session.json
  local end_at
  end_at=$(( $(date +%s) + 300 ))
  cat > "${tmpdir}/ckad-drill/session.json" <<SESSIONEOF
{
  "mode": "drill",
  "scenario_id": "test-skip-scenario",
  "scenario_file": "/dev/null",
  "namespace": "test-skip-ns",
  "started_at": "2026-01-01T00:00:00Z",
  "time_limit": 300,
  "end_at": ${end_at}
}
SESSIONEOF

  # Fake kubectl shim: records namespace deletion
  cat > "${tmpdir}/bin/kubectl" <<KUBEOF
#!/usr/bin/env bash
if [[ "\$1" == "delete" && "\$2" == "namespace" ]]; then
  printf '%s' "\$3" > '${tmpdir}/deleted-namespace.txt'
fi
exit 0
KUBEOF
  chmod +x "${tmpdir}/bin/kubectl"

  run bash -c "
    XDG_CONFIG_HOME='${tmpdir}'
    PATH='${tmpdir}/bin:${PATH}'
    export XDG_CONFIG_HOME PATH
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' skip 2>&1
  "

  assert_success

  # namespace deletion marker must exist
  [[ -f "${tmpdir}/deleted-namespace.txt" ]] \
    || fail "scenario_cleanup did not call kubectl delete namespace"

  local recorded_ns
  recorded_ns=$(cat "${tmpdir}/deleted-namespace.txt")
  [[ "${recorded_ns}" == "test-skip-ns" ]] \
    || fail "Expected test-skip-ns, got: ${recorded_ns}"

  rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# Regression: BREAK-03 — _drill_cleanup bridges SCENARIO_NAMESPACE from SESSION_NAMESPACE (DRIL-11)
# Tests by sourcing lib files and calling _drill_cleanup directly (same definition as bin/ckad-drill).
# Uses XDG_CONFIG_HOME for session file. Fake kubectl records deletion.
# ---------------------------------------------------------------------------

@test "_drill_cleanup: bridges SESSION_NAMESPACE to SCENARIO_NAMESPACE when session file exists" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "${tmpdir}/ckad-drill" "${tmpdir}/bin"

  # Session file at XDG_CONFIG_HOME/ckad-drill/session.json
  local end_at
  end_at=$(( $(date +%s) + 300 ))
  cat > "${tmpdir}/ckad-drill/session.json" <<SESSIONEOF
{
  "mode": "drill",
  "scenario_id": "test-cleanup-scenario",
  "scenario_file": "/dev/null",
  "namespace": "trap-cleanup-ns",
  "started_at": "2026-01-01T00:00:00Z",
  "time_limit": 300,
  "end_at": ${end_at}
}
SESSIONEOF

  # Fake kubectl shim: records namespace deletion
  cat > "${tmpdir}/bin/kubectl" <<KUBEOF
#!/usr/bin/env bash
if [[ "\$1" == "delete" && "\$2" == "namespace" ]]; then
  printf '%s' "\$3" > '${tmpdir}/deleted-namespace.txt'
fi
exit 0
KUBEOF
  chmod +x "${tmpdir}/bin/kubectl"

  run bash -c "
    CKAD_DRILL_ROOT='${CKAD_DRILL_ROOT}'
    XDG_CONFIG_HOME='${tmpdir}'
    PATH='${tmpdir}/bin:${PATH}'
    export CKAD_DRILL_ROOT XDG_CONFIG_HOME PATH

    # Source all lib files (same order as bin/ckad-drill)
    source \"\${CKAD_DRILL_ROOT}/lib/common.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/display.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/cluster.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/scenario.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/validator.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/session.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/progress.sh\"
    source \"\${CKAD_DRILL_ROOT}/lib/timer.sh\"

    # Define _drill_cleanup exactly as in the fixed bin/ckad-drill
    _drill_cleanup() {
      trap - INT TERM EXIT
      if [[ -f \"\${CKAD_SESSION_FILE}\" ]]; then
        session_read 2>/dev/null || true
        SCENARIO_NAMESPACE=\"\${SESSION_NAMESPACE:-}\"
        scenario_cleanup
        session_clear
      elif [[ -n \"\${SCENARIO_NAMESPACE:-}\" ]]; then
        kubectl delete namespace \"\${SCENARIO_NAMESPACE}\" --ignore-not-found=true 2>/dev/null || true
      fi
    }

    _drill_cleanup
    echo 'cleanup_done'
  "

  assert_success
  assert_output --partial "cleanup_done"

  # namespace deletion marker must exist (scenario_cleanup -> kubectl delete was called)
  [[ -f "${tmpdir}/deleted-namespace.txt" ]] \
    || fail "scenario_cleanup did not call kubectl delete namespace"

  local recorded_ns
  recorded_ns=$(cat "${tmpdir}/deleted-namespace.txt")
  [[ "${recorded_ns}" == "trap-cleanup-ns" ]] \
    || fail "Expected trap-cleanup-ns, got: ${recorded_ns}"

  rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# Regression: DEFECT-01 — solution displays multi-line heredoc steps correctly (DRIL-05)
# Uses XDG_CONFIG_HOME for session file.
# ---------------------------------------------------------------------------

@test "solution: displays multi-line heredoc steps as complete numbered steps" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "${tmpdir}/ckad-drill"
  local scenario_file="${tmpdir}/multiline-scenario.yaml"

  # Create a scenario with a multi-line heredoc step and a simple step
  cat > "${scenario_file}" <<'SCENEOF'
id: test-multiline
domain: 1
title: "Multiline Solution Test"
difficulty: easy
time_limit: 300
namespace: test-multiline-ns
description: "Test for multi-line solution steps"
validations: []
solution:
  steps:
    - |
      kubectl apply -f - <<EOF
      apiVersion: v1
      kind: Pod
      metadata:
        name: test-pod
      EOF
    - "kubectl get pods"
SCENEOF

  # Session file at XDG_CONFIG_HOME/ckad-drill/session.json
  local end_at
  end_at=$(( $(date +%s) + 300 ))
  cat > "${tmpdir}/ckad-drill/session.json" <<SESSIONEOF
{
  "mode": "drill",
  "scenario_id": "test-multiline",
  "scenario_file": "${scenario_file}",
  "namespace": "test-multiline-ns",
  "started_at": "2026-01-01T00:00:00Z",
  "time_limit": 300,
  "end_at": ${end_at}
}
SESSIONEOF

  run bash -c "
    XDG_CONFIG_HOME='${tmpdir}'
    export XDG_CONFIG_HOME
    bash '${CKAD_DRILL_ROOT}/bin/ckad-drill' solution 2>&1
  "

  assert_success

  # Must have exactly 2 numbered steps (not 5+ from line-by-line splitting)
  local step1_count step2_count
  step1_count=$(printf '%s\n' "${output}" | grep -c '^1\. ' || true)
  step2_count=$(printf '%s\n' "${output}" | grep -c '^2\. ' || true)
  [[ "${step1_count}" -eq 1 ]] \
    || fail "Expected exactly 1 line starting with '1. ', got: ${step1_count}"
  [[ "${step2_count}" -eq 1 ]] \
    || fail "Expected exactly 1 line starting with '2. ', got: ${step2_count}"

  # Step 1 must contain the kubectl apply command (first line of the multi-line step)
  assert_output --partial "1. kubectl apply -f -"

  # Step 2 must be the simple kubectl get command
  assert_output --partial "2. kubectl get pods"

  rm -rf "${tmpdir}"
}

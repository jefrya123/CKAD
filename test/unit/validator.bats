#!/usr/bin/env bats
# test/unit/validator.bats — unit tests for lib/validator.sh

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

  # shellcheck source=lib/validator.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/validator.sh"

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

# ---------------------------------------------------------------
# Mock helpers
# ---------------------------------------------------------------

# _mock_kubectl_json OUTPUT
# Creates a kubectl stub that echoes JSON output and exits 0.
_mock_kubectl_json() {
  local json="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho %q\n' "${json}" > "${mock_dir}/kubectl"
  chmod +x "${mock_dir}/kubectl"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# _mock_kubectl_fail
# Creates a kubectl stub that exits non-zero (resource not found).
_mock_kubectl_fail() {
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho "Error: not found" >&2\nexit 1\n' > "${mock_dir}/kubectl"
  chmod +x "${mock_dir}/kubectl"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# _mock_kubectl_lines LINES
# Creates a kubectl stub that echoes raw text lines.
_mock_kubectl_lines() {
  local lines_output="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nprintf "%%s" %q\n' "${lines_output}" > "${mock_dir}/kubectl"
  chmod +x "${mock_dir}/kubectl"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# ---------------------------------------------------------------
# resource_exists
# ---------------------------------------------------------------

@test "resource_exists: PASS when kubectl get exits 0" {
  _mock_kubectl_json '{"kind":"Pod"}'
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 0 is resource_exists check
  run _validator_resource_exists "${fixture}" 0 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "resource_exists: FAIL when kubectl get exits non-zero" {
  _mock_kubectl_fail
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_resource_exists "${fixture}" 0 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

@test "resource_exists: FAIL output shows not found in actual" {
  _mock_kubectl_fail
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_resource_exists "${fixture}" 0 "test-ns"
  assert_output --partial "not found"
}

# ---------------------------------------------------------------
# resource_field
# ---------------------------------------------------------------

@test "resource_field: PASS when jsonpath output matches expected" {
  _mock_kubectl_json "web"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 1 is resource_field, expected: "web"
  run _validator_resource_field "${fixture}" 1 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "resource_field: FAIL when jsonpath output does not match expected" {
  _mock_kubectl_json "other-value"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_resource_field "${fixture}" 1 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

@test "resource_field: FAIL shows expected vs actual values" {
  _mock_kubectl_json "wrong-value"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_resource_field "${fixture}" 1 "test-ns"
  assert_output --partial "expected:"
  assert_output --partial "actual:"
}

# ---------------------------------------------------------------
# container_count
# ---------------------------------------------------------------

@test "container_count: PASS when container count matches expected" {
  local pod_json='{"spec":{"containers":[{"name":"web","image":"nginx:latest"}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 2 is container_count, expected: 1
  run _validator_container_count "${fixture}" 2 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "container_count: FAIL when container count does not match expected" {
  local pod_json='{"spec":{"containers":[{"name":"a"},{"name":"b"}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 2 expects 1 container, but JSON has 2
  run _validator_container_count "${fixture}" 2 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# container_image
# ---------------------------------------------------------------

@test "container_image: PASS when image matches expected" {
  local pod_json='{"spec":{"containers":[{"name":"web","image":"nginx:latest"}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 3 is container_image, container: web, expected: nginx:latest
  run _validator_container_image "${fixture}" 3 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "container_image: FAIL when image does not match expected" {
  local pod_json='{"spec":{"containers":[{"name":"web","image":"nginx:1.24"}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_container_image "${fixture}" 3 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# container_env
# ---------------------------------------------------------------

@test "container_env: PASS when env var value matches expected" {
  local pod_json='{"spec":{"containers":[{"name":"web","env":[{"name":"ENV_MODE","value":"production"}]}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 4 is container_env, env_var: ENV_MODE, expected: production
  run _validator_container_env "${fixture}" 4 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "container_env: FAIL when env var value does not match" {
  local pod_json='{"spec":{"containers":[{"name":"web","env":[{"name":"ENV_MODE","value":"staging"}]}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_container_env "${fixture}" 4 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# volume_mount
# ---------------------------------------------------------------

@test "volume_mount: PASS when mount path exists on container" {
  local pod_json='{"spec":{"containers":[{"name":"web","volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 5 is volume_mount, container: web, mount_path: /data
  run _validator_volume_mount "${fixture}" 5 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "volume_mount: FAIL when mount path does not exist on container" {
  local pod_json='{"spec":{"containers":[{"name":"web","volumeMounts":[{"name":"other","mountPath":"/other"}]}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_volume_mount "${fixture}" 5 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# container_running
# ---------------------------------------------------------------

@test "container_running: PASS when container state has running" {
  local pod_json='{"status":{"containerStatuses":[{"name":"web","state":{"running":{"startedAt":"2024-01-01T00:00:00Z"}}}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 6 is container_running, container: web
  run _validator_container_running "${fixture}" 6 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "container_running: FAIL when container state is not running" {
  local pod_json='{"status":{"containerStatuses":[{"name":"web","state":{"waiting":{"reason":"CrashLoopBackOff"}}}]}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_container_running "${fixture}" 6 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

@test "container_running: FAIL gracefully when containerStatuses is null" {
  local pod_json='{"status":{}}'
  _mock_kubectl_json "${pod_json}"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_container_running "${fixture}" 6 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# label_selector
# ---------------------------------------------------------------

@test "label_selector: PASS when resources matching selector are found" {
  _mock_kubectl_lines "web-pod   Running   1/1"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 7 is label_selector, kind: pod, selector: app=web
  run _validator_label_selector "${fixture}" 7 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "label_selector: FAIL when no resources match selector" {
  _mock_kubectl_lines ""
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_label_selector "${fixture}" 7 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# resource_count
# ---------------------------------------------------------------

@test "resource_count: PASS when resource count matches expected" {
  _mock_kubectl_lines "web-pod   Running   1/1"
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 8 is resource_count, kind: pod, selector: app=web, expected: 1
  run _validator_resource_count "${fixture}" 8 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "resource_count: FAIL when resource count does not match expected" {
  _mock_kubectl_lines ""
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 8 expects 1, but empty output = 0
  run _validator_resource_count "${fixture}" 8 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

@test "resource_count: empty kubectl output counts as 0 not 1" {
  _mock_kubectl_lines ""
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  run _validator_resource_count "${fixture}" 8 "test-ns"
  assert_output --partial "actual:   0"
}

# ---------------------------------------------------------------
# command_output: contains mode
# ---------------------------------------------------------------

@test "command_output contains: PASS when output contains expected string" {
  local fixture="${FIXTURE_DIR}/valid/all-checks-scenario.yaml"
  # idx 9 is command_output, command: echo hello, mode: contains, expected: hello
  run _validator_command_output "${fixture}" 9 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "command_output contains: FAIL when output does not contain expected string" {
  # Create a temp fixture with a command that outputs something different
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-cmd
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: cmd_check
    type: command_output
    command: "echo goodbye"
    mode: contains
    expected: "hello"
solution:
  commands: []
YAML
  run _validator_command_output "${tmp_fixture}" 0 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# command_output: matches mode (regex)
# ---------------------------------------------------------------

@test "command_output matches: PASS when output matches regex" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-cmd
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: cmd_check
    type: command_output
    command: "echo hello123"
    mode: matches
    expected: "hello[0-9]+"
solution:
  commands: []
YAML
  run _validator_command_output "${tmp_fixture}" 0 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "command_output matches: FAIL when output does not match regex" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-cmd
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: cmd_check
    type: command_output
    command: "echo goodbye"
    mode: matches
    expected: "hello[0-9]+"
solution:
  commands: []
YAML
  run _validator_command_output "${tmp_fixture}" 0 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# command_output: equals mode
# ---------------------------------------------------------------

@test "command_output equals: PASS when output exactly equals expected" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-cmd
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: cmd_check
    type: command_output
    command: "printf 'hello'"
    mode: equals
    expected: "hello"
solution:
  commands: []
YAML
  run _validator_command_output "${tmp_fixture}" 0 "test-ns"
  assert_success
  assert_output --partial "PASS"
}

@test "command_output equals: FAIL when output does not exactly equal expected" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-cmd
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: cmd_check
    type: command_output
    command: "echo hello world"
    mode: equals
    expected: "hello"
solution:
  commands: []
YAML
  run _validator_command_output "${tmp_fixture}" 0 "test-ns"
  assert_failure
  assert_output --partial "FAIL"
}

# ---------------------------------------------------------------
# Unknown check type
# ---------------------------------------------------------------

@test "unknown check type: warns and is skipped by dispatcher" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-unknown
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: weird_check
    type: unknown_type
solution:
  commands: []
YAML
  run validator_run_checks "${tmp_fixture}" "test-ns"
  # Should not error out completely
  assert_output --partial "WARN"
}

# ---------------------------------------------------------------
# validator_run_checks dispatch
# ---------------------------------------------------------------

@test "validator_run_checks: returns 0 when all checks pass" {
  # Use a fixture with only command_output checks (no kubectl needed)
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-dispatch
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: check1
    type: command_output
    command: "echo hello"
    mode: contains
    expected: "hello"
  - name: check2
    type: command_output
    command: "echo world"
    mode: equals
    expected: "world"
solution:
  commands: []
YAML
  run validator_run_checks "${tmp_fixture}" "test-ns"
  assert_success
}

@test "validator_run_checks: returns 1 when any check fails" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-dispatch-fail
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: pass_check
    type: command_output
    command: "echo hello"
    mode: contains
    expected: "hello"
  - name: fail_check
    type: command_output
    command: "echo goodbye"
    mode: contains
    expected: "hello"
solution:
  commands: []
YAML
  run validator_run_checks "${tmp_fixture}" "test-ns"
  assert_failure
}

@test "validator_run_checks: calls pass for passing checks" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-pass-call
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: my_check
    type: command_output
    command: "echo yes"
    mode: contains
    expected: "yes"
solution:
  commands: []
YAML
  run validator_run_checks "${tmp_fixture}" "test-ns"
  assert_output --partial "[PASS]"
}

@test "validator_run_checks: calls fail for failing checks" {
  local tmp_fixture
  tmp_fixture="$(mktemp /tmp/test-XXXXXX.yaml)"
  MOCK_DIRS+=("${tmp_fixture}")
  cat > "${tmp_fixture}" << 'YAML'
id: test-fail-call
domain: 1
title: Test
difficulty: easy
time_limit: 60
description: test
validations:
  - name: my_check
    type: command_output
    command: "echo no"
    mode: contains
    expected: "yes"
solution:
  commands: []
YAML
  run validator_run_checks "${tmp_fixture}" "test-ns"
  assert_output --partial "[FAIL]"
}

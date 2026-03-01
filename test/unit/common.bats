#!/usr/bin/env bats
# test/unit/common.bats — unit tests for lib/common.sh
# Tests output functions (info/warn/error/success) and shared constants.
# Does NOT require Docker or a kind cluster.

setup() {
  # Resolve repo root relative to this test file
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  # Load bats helper libraries
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # Source the library under test
  # shellcheck source=../../lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"
}

# --- info() ---

@test "info() prints [INFO] prefix to stdout" {
  run info "test message"
  assert_success
  assert_output --partial "[INFO] test message"
}

@test "info() output goes to stdout not stderr" {
  # Capture only stdout; stderr should be empty
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && info 'hello' 2>/dev/null"
  assert_success
  assert_output --partial "[INFO] hello"
}

# --- warn() ---

@test "warn() prints [WARN] prefix" {
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && warn 'something off' 2>&1"
  assert_success
  assert_output --partial "[WARN] something off"
}

@test "warn() writes to stderr not stdout" {
  # Redirect stderr to /dev/null — output should be empty
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && warn 'hidden' 2>/dev/null"
  assert_success
  refute_output --partial "[WARN]"
}

# --- error() ---

@test "error() prints [ERROR] prefix" {
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && error 'something broke' 2>&1"
  assert_success
  assert_output --partial "[ERROR] something broke"
}

@test "error() writes to stderr not stdout" {
  # Redirect stderr to /dev/null — output should be empty
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && error 'hidden' 2>/dev/null"
  assert_success
  refute_output --partial "[ERROR]"
}

@test "error() does not exit (print-only)" {
  # error() must NOT call exit; after calling it, script continues
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh; error 'oops' 2>/dev/null; echo 'still running'"
  assert_success
  assert_output "still running"
}

# --- success() ---

@test "success() prints [OK] prefix to stdout" {
  run success "all good"
  assert_success
  assert_output --partial "[OK] all good"
}

@test "success() output goes to stdout not stderr" {
  run bash -c "source ${CKAD_DRILL_ROOT}/lib/common.sh && success 'done' 2>/dev/null"
  assert_success
  assert_output --partial "[OK] done"
}

# --- cluster constants ---

@test "CKAD_CLUSTER_NAME equals ckad-drill" {
  assert_equal "${CKAD_CLUSTER_NAME}" "ckad-drill"
}

@test "CKAD_KUBE_CONTEXT equals kind-ckad-drill" {
  assert_equal "${CKAD_KUBE_CONTEXT}" "kind-ckad-drill"
}

# --- exit codes ---

@test "EXIT_OK equals 0" {
  assert_equal "${EXIT_OK}" "0"
}

@test "EXIT_ERROR equals 1" {
  assert_equal "${EXIT_ERROR}" "1"
}

@test "EXIT_NO_CLUSTER equals 2" {
  assert_equal "${EXIT_NO_CLUSTER}" "2"
}

@test "EXIT_NO_SESSION equals 3" {
  assert_equal "${EXIT_NO_SESSION}" "3"
}

@test "EXIT_PARSE_ERROR equals 4" {
  assert_equal "${EXIT_PARSE_ERROR}" "4"
}

# --- XDG config paths ---
# Must run in subshells: common.sh uses `readonly` so re-sourcing in the same
# process raises "readonly variable" errors.

@test "CKAD_CONFIG_DIR defaults to ~/.config/ckad-drill" {
  run bash -c "
    unset XDG_CONFIG_HOME
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    echo \"\${CKAD_CONFIG_DIR}\"
  "
  assert_success
  assert_output "${HOME}/.config/ckad-drill"
}

@test "CKAD_CONFIG_DIR respects XDG_CONFIG_HOME when set" {
  run bash -c "
    export XDG_CONFIG_HOME=/tmp/test-xdg-config
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    echo \"\${CKAD_CONFIG_DIR}\"
  "
  assert_success
  assert_output "/tmp/test-xdg-config/ckad-drill"
}

@test "CKAD_DATA_DIR defaults to ~/.local/share/ckad-drill" {
  run bash -c "
    unset XDG_DATA_HOME
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    echo \"\${CKAD_DATA_DIR}\"
  "
  assert_success
  assert_output "${HOME}/.local/share/ckad-drill"
}

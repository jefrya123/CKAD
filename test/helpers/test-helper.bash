# test/helpers/test-helper.bash — shared bats test setup
# Source this from test setup() functions via: load "../helpers/test-helper"
# shellcheck shell=bash

# Absolute path to the repo root, resolved from this file's location
CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
export CKAD_DRILL_ROOT

# Load bats helper libraries (must be installed via scripts/dev-setup.sh)
load "bats-support/load"
load "bats-assert/load"

# Source the common library so all tests have access to shared functions
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source "${CKAD_DRILL_ROOT}/lib/common.sh"

# _mock_command_missing NAME
# Creates a bash function named NAME that returns 127 (command not found).
# Also prepends a fake bin directory to PATH so `command -v NAME` returns failure.
# Usage:
#   _mock_command_missing kind
_mock_command_missing() {
  local name="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  # Write a stub script that exits 127
  printf '#!/usr/bin/env bash\nexit 127\n' > "${mock_dir}/${name}"
  chmod +x "${mock_dir}/${name}"
  # Remove real binary from PATH by placing mock first — but we still need
  # command -v to fail. We use a wrapper script that always fails for this name.
  export PATH="${mock_dir}:${PATH}"
  # Record mock dirs for cleanup in teardown
  MOCK_DIRS+=("${mock_dir}")
}

# _mock_command_present NAME
# Ensures NAME is resolvable on PATH (creates a no-op stub if not present).
# Useful to guarantee a dep exists for tests that need all deps present.
_mock_command_present() {
  local name="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${mock_dir}/${name}"
  chmod +x "${mock_dir}/${name}"
  export PATH="${mock_dir}:${PATH}"
  MOCK_DIRS+=("${mock_dir}")
}

# _cleanup_mocks — remove all temp mock directories
# Call from bats teardown()
_cleanup_mocks() {
  local dir
  for dir in "${MOCK_DIRS[@]+"${MOCK_DIRS[@]}"}"; do
    rm -rf "${dir}"
  done
  MOCK_DIRS=()
}

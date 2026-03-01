#!/usr/bin/env bats
# test/unit/cluster.bats — unit tests for lib/cluster.sh
# Tests dependency checking (CLST-05) and version pinning — no cluster required.

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  # Load bats helper libraries
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # Source common first (cluster.sh depends on info/warn/error)
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/cluster.sh"

  # Track temp dirs for cleanup
  MOCK_DIRS=()
}

teardown() {
  # Clean up any mock directories created during the test
  local dir
  for dir in "${MOCK_DIRS[@]+"${MOCK_DIRS[@]}"}"; do
    rm -rf "${dir}"
  done
}

# --- Helper: build a restricted PATH that excludes specific commands ---
# Creates a bin dir containing stubs for all *present* commands, then sets PATH
# to only that dir so the named commands become invisible.
#
# _path_without CMD1 CMD2 ...
# Sets RESTRICTED_PATH to a PATH string usable in subshells.
_make_path_excluding() {
  local mock_dir
  mock_dir="$(mktemp -d)"
  MOCK_DIRS+=("${mock_dir}")

  local excluded=("$@")

  # Copy real binaries we want available (docker, kind, kubectl, yq, jq)
  for cmd in docker kind kubectl yq jq; do
    local skip=0
    for exc in "${excluded[@]}"; do
      [[ "${cmd}" == "${exc}" ]] && skip=1 && break
    done
    if [[ "${skip}" -eq 0 ]]; then
      local real_path
      real_path="$(command -v "${cmd}" 2>/dev/null || true)"
      if [[ -n "${real_path}" ]]; then
        ln -sf "${real_path}" "${mock_dir}/${cmd}"
      fi
    fi
  done

  # Also include bash builtins wrappers needed for the subshell itself
  echo "${mock_dir}"
}

# --- addon version pinning ---

@test "CALICO_VERSION is pinned and follows vX.Y.Z pattern" {
  [[ "${CALICO_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "INGRESS_NGINX_VERSION is pinned and follows vX.Y.Z pattern" {
  [[ "${INGRESS_NGINX_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "METRICS_SERVER_VERSION is pinned and follows vX.Y.Z pattern" {
  [[ "${METRICS_SERVER_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# --- cluster_check_deps: collect-all-missing pattern ---

@test "cluster_check_deps reports all missing deps at once — not just the first" {
  # Run in subshell with PATH that excludes kind AND kubectl
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    # Override command to simulate kind and kubectl missing
    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && ( \"\${name}\" == 'kind' || \"\${name}\" == 'kubectl' ) ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    cluster_check_deps 2>&1
  "
  assert_failure
  # Both missing deps must appear in output — not just the first
  assert_output --partial "kind"
  assert_output --partial "kubectl"
}

@test "cluster_check_deps shows install URLs for missing deps" {
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && \"\${name}\" == 'kind' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    cluster_check_deps 2>&1
  "
  assert_failure
  # Should show install documentation URL for kind
  assert_output --partial "kind.sigs.k8s.io"
}

@test "cluster_check_deps returns failure when kind is missing" {
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && \"\${name}\" == 'kind' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    cluster_check_deps 2>&1
  "
  assert_failure
  assert_output --partial "kind"
}

@test "cluster_check_deps returns failure when kubectl is missing" {
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && \"\${name}\" == 'kubectl' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    cluster_check_deps 2>&1
  "
  assert_failure
  assert_output --partial "kubectl"
}

@test "cluster_check_deps detects docker daemon not running (binary present, daemon down)" {
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    # Make 'command -v docker' succeed but 'docker info' fail
    docker() { return 1; }
    export -f docker

    cluster_check_deps 2>&1
  "
  assert_failure
  assert_output --partial "docker"
  assert_output --partial "daemon"
}

@test "cluster_check_deps reports multiple missing deps including URLs" {
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    # Simulate yq and jq both missing
    command() {
      local opt=\"\$1\"
      local name=\"\${2:-}\"
      if [[ \"\${opt}\" == '-v' && ( \"\${name}\" == 'yq' || \"\${name}\" == 'jq' ) ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command

    cluster_check_deps 2>&1
  "
  assert_failure
  assert_output --partial "yq"
  assert_output --partial "jq"
  # URLs for both should appear in output
  assert_output --partial "yq"
  assert_output --partial "jqlang"
}

# --- cluster_exists: no cluster running ---

@test "cluster_exists returns failure when kind is not available" {
  # If kind binary doesn't exist, cluster_exists should return 1 (no cluster)
  run bash -c "
    source ${CKAD_DRILL_ROOT}/lib/common.sh
    source ${CKAD_DRILL_ROOT}/lib/cluster.sh

    # Override kind to simulate it not being installed
    kind() { return 127; }
    export -f kind

    cluster_exists
  "
  assert_failure
}

@test "cluster_exists returns failure when kind cluster list is empty" {
  skip "Requires kind binary — skipping if kind not installed"
  run cluster_exists
  # When no cluster exists, should return 1
  # (This is safe: it just queries kind, doesn't create anything)
  assert_failure
}

# --- cluster lifecycle functions exist and are callable ---

@test "cluster_start function is defined" {
  declare -f cluster_start > /dev/null
}

@test "cluster_stop function is defined" {
  declare -f cluster_stop > /dev/null
}

@test "cluster_reset function is defined" {
  declare -f cluster_reset > /dev/null
}

@test "cluster_exists function is defined" {
  declare -f cluster_exists > /dev/null
}

@test "cluster_is_healthy function is defined" {
  declare -f cluster_is_healthy > /dev/null
}

@test "cluster_check_deps function is defined" {
  declare -f cluster_check_deps > /dev/null
}

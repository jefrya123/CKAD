# Sprint 1: Foundation & Cluster Management — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scaffold ckad-drill project structure, implement shared utilities (common.sh, display.sh), and kind cluster lifecycle management (cluster.sh, cluster-setup.sh).

**Architecture:** Pure bash tool with sourced lib files. `bin/ckad-drill` is the entry point, `lib/*.sh` are function-only source files. All output through display.sh. Config via XDG paths. Testing via bats-core + shellcheck. See `_bmad-output/planning-artifacts/architecture.md` for full ADRs.

**Tech Stack:** Bash, kind, kubectl, yq, jq, bats-core, shellcheck

**Key conventions (from architecture doc):**
- `set -euo pipefail` ONLY in `bin/ckad-drill`, never in lib files
- Functions: `module_action()` public, `_module_helper()` private
- Variables: `UPPER_SNAKE` globals, `lower_snake` locals, always `"${braced}"`
- All output through `display.sh` functions — no raw echo with escape codes in libs
- Lib files are source-only — no top-level execution, only function definitions
- 2-space indent, no tabs
- shellcheck clean — no suppressed warnings without justification

---

### Task 1: Archive Existing Content & Create Directory Structure (Story 1.1)

**Files:**
- Create: `bin/.gitkeep` (placeholder until bin/ckad-drill is written in Task 5)
- Create: `lib/.gitkeep`
- Create: `content/domain-1/.gitkeep`, `content/domain-2/.gitkeep`, `content/domain-3/.gitkeep`, `content/domain-4/.gitkeep`, `content/domain-5/.gitkeep`
- Create: `test/unit/.gitkeep`, `test/integration/.gitkeep`, `test/schema/.gitkeep`, `test/helpers/.gitkeep`
- Create: `scripts/.gitkeep`
- Create: `Makefile`
- Create: `LICENSE`
- Move: all existing content directories → `archive/`

**Step 1: Move existing content to archive/**

```bash
cd /home/jeff/Projects/cka
mkdir -p archive
# Move study guide content (preserve git history via git mv)
git mv scenarios archive/scenarios
git mv domains archive/domains
git mv practice archive/practice
git mv quizzes archive/quizzes
git mv speed-drills archive/speed-drills
git mv troubleshooting archive/troubleshooting
git mv cheatsheet.md archive/cheatsheet.md
git mv exam-tips archive/exam-tips
git mv setup archive/setup
```

Note: `README.md`, `docs/`, `_bmad-output/` stay at root.

**Step 2: Create new directory structure**

```bash
mkdir -p bin lib scripts
mkdir -p scenarios/domain-{1..5}
mkdir -p content/domain-{1..5}
mkdir -p test/{unit,integration,schema,helpers/fixtures}
# Add .gitkeep to empty dirs
for dir in bin lib scripts scenarios/domain-{1..5} content/domain-{1..5} test/unit test/integration test/schema test/helpers test/helpers/fixtures; do
  touch "$dir/.gitkeep"
done
```

**Step 3: Create LICENSE (MIT)**

```
MIT License

Copyright (c) 2026 ckad-drill contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Step 4: Create Makefile**

```makefile
.PHONY: test shellcheck test-unit test-integration install

SHELL := /bin/bash

# All bash scripts to lint
SCRIPTS := $(wildcard bin/ckad-drill lib/*.sh scripts/*.sh)

test: shellcheck test-unit

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck $(SCRIPTS) || true
	@echo "shellcheck complete"

test-unit:
	@echo "Running unit tests..."
	@bats test/unit/ || true
	@echo "Unit tests complete"

test-integration:
	@echo "Running integration tests (requires kind cluster)..."
	@bats test/integration/
	@echo "Integration tests complete"

install:
	@echo "Run: scripts/install.sh"
```

Note: `|| true` on shellcheck/test-unit so make doesn't fail on empty dirs initially. Remove once real files exist.

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: scaffold project structure, archive study guide content

Move existing study guide to archive/. Create ckad-drill project
structure: bin/, lib/, scenarios/, content/, test/, scripts/.
Add Makefile with test/shellcheck/install targets and MIT LICENSE."
```

---

### Task 2: Implement lib/common.sh (Story 1.2)

**Files:**
- Create: `lib/common.sh`
- Test: `test/unit/common.bats`
- Create: `test/helpers/test-helper.bash`

**Step 1: Create test helper**

Create `test/helpers/test-helper.bash`:
```bash
#!/usr/bin/env bash
# Common test setup for all bats tests

# Use a temp dir for config/data during tests
export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"

# Source from project root
CKAD_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
export CKAD_ROOT
```

**Step 2: Write failing tests for common.sh**

Create `test/unit/common.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
}

@test "CKAD_ROOT is set to project root" {
  [[ -n "${CKAD_ROOT}" ]]
  [[ -d "${CKAD_ROOT}/lib" ]]
}

@test "CKAD_CONFIG_DIR respects XDG_CONFIG_HOME" {
  export XDG_CONFIG_HOME="/tmp/test-xdg-config"
  source "${CKAD_ROOT}/lib/common.sh"
  [[ "${CKAD_CONFIG_DIR}" == "/tmp/test-xdg-config/ckad-drill" ]]
}

@test "CKAD_CONFIG_DIR defaults to ~/.config/ckad-drill" {
  unset XDG_CONFIG_HOME
  source "${CKAD_ROOT}/lib/common.sh"
  [[ "${CKAD_CONFIG_DIR}" == "${HOME}/.config/ckad-drill" ]]
}

@test "CKAD_DATA_DIR respects XDG_DATA_HOME" {
  export XDG_DATA_HOME="/tmp/test-xdg-data"
  source "${CKAD_ROOT}/lib/common.sh"
  [[ "${CKAD_DATA_DIR}" == "/tmp/test-xdg-data/ckad-drill" ]]
}

@test "CKAD_DATA_DIR defaults to ~/.local/share/ckad-drill" {
  unset XDG_DATA_HOME
  source "${CKAD_ROOT}/lib/common.sh"
  [[ "${CKAD_DATA_DIR}" == "${HOME}/.local/share/ckad-drill" ]]
}

@test "CKAD_SESSION_FILE is defined" {
  [[ -n "${CKAD_SESSION_FILE}" ]]
  [[ "${CKAD_SESSION_FILE}" == "${CKAD_CONFIG_DIR}/session.json" ]]
}

@test "CKAD_PROGRESS_FILE is defined" {
  [[ -n "${CKAD_PROGRESS_FILE}" ]]
  [[ "${CKAD_PROGRESS_FILE}" == "${CKAD_CONFIG_DIR}/progress.json" ]]
}

@test "exit code constants are defined" {
  [[ "${EXIT_OK}" -eq 0 ]]
  [[ "${EXIT_ERROR}" -eq 1 ]]
  [[ "${EXIT_NO_CLUSTER}" -eq 2 ]]
  [[ "${EXIT_NO_SESSION}" -eq 3 ]]
  [[ "${EXIT_PARSE_ERROR}" -eq 4 ]]
}

@test "sourcing common.sh does not produce output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "common.sh does not set errexit/nounset/pipefail" {
  # Lib files must NOT set these — only bin/ckad-drill does
  source "${CKAD_ROOT}/lib/common.sh"
  # If set -e were active, this false would exit the test
  false || true
}
```

**Step 3: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/common.bats
```

Expected: FAIL — `lib/common.sh` doesn't exist yet.

**Step 4: Implement lib/common.sh**

Create `lib/common.sh`:
```bash
#!/usr/bin/env bash
# lib/common.sh — Shared constants, paths, and utilities for ckad-drill
#
# This file is sourced by bin/ckad-drill and other lib files.
# It MUST NOT set -euo pipefail or produce any output when sourced.
# It MUST NOT execute any top-level code — functions and variable assignments only.

# ---------------------------------------------------------------------------
# Project root (set by bin/ckad-drill; fallback for direct sourcing in tests)
# ---------------------------------------------------------------------------
CKAD_ROOT="${CKAD_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------------------------------------------------------------------------
# XDG-compliant paths
# ---------------------------------------------------------------------------
CKAD_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/ckad-drill"
CKAD_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/ckad-drill"

# ---------------------------------------------------------------------------
# State file locations
# ---------------------------------------------------------------------------
CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
CKAD_PROGRESS_FILE="${CKAD_CONFIG_DIR}/progress.json"

# ---------------------------------------------------------------------------
# Exit codes
# ---------------------------------------------------------------------------
EXIT_OK=0
EXIT_ERROR=1
EXIT_NO_CLUSTER=2
EXIT_NO_SESSION=3
EXIT_PARSE_ERROR=4

# ---------------------------------------------------------------------------
# Tool version requirements
# ---------------------------------------------------------------------------
CKAD_CLUSTER_NAME="ckad-drill"
CKAD_K8S_VERSION="v1.31"

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

# Ensure config directory exists
common_ensure_dirs() {
  mkdir -p "${CKAD_CONFIG_DIR}"
  mkdir -p "${CKAD_DATA_DIR}"
}
```

**Step 5: Run tests to verify they pass**

```bash
bats test/unit/common.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck lib/common.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add lib/common.sh test/unit/common.bats test/helpers/test-helper.bash
git commit -m "feat: implement lib/common.sh with XDG paths and exit codes

Shared constants, XDG-compliant config/data paths, session/progress
file locations, and exit code constants. Includes bats unit tests."
```

---

### Task 3: Implement lib/display.sh (Story 1.3)

**Files:**
- Create: `lib/display.sh`
- Test: `test/unit/display.bats`

**Step 1: Write failing tests**

Create `test/unit/display.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
}

@test "pass() outputs green message with checkmark" {
  # Force non-terminal to strip colors for easier testing
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; pass 'test message'"
  [[ "${output}" == *"test message"* ]]
  [[ "${status}" -eq 0 ]]
}

@test "fail() outputs red message with X" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; fail 'test failure'"
  [[ "${output}" == *"test failure"* ]]
  [[ "${status}" -eq 0 ]]
}

@test "info() outputs message" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; info 'info message'"
  [[ "${output}" == *"info message"* ]]
  [[ "${status}" -eq 0 ]]
}

@test "warn() outputs warning message" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; warn 'warning message'"
  [[ "${output}" == *"warning message"* ]]
  [[ "${status}" -eq 0 ]]
}

@test "error() outputs to stderr and exits 1" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; error 'fatal error'"
  [[ "${output}" == *"fatal error"* ]]
  [[ "${status}" -eq 1 ]]
}

@test "header() outputs bold text with rule" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; header 'Test Header'"
  [[ "${output}" == *"Test Header"* ]]
  [[ "${status}" -eq 0 ]]
}

@test "colors are stripped when stdout is not a terminal" {
  # bats 'run' already uses a pipe (non-terminal), so colors should be stripped
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; pass 'no color'"
  # Output should not contain escape sequences
  [[ "${output}" != *$'\033'* ]]
}

@test "sourcing display.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh" 2>&1)"
  [[ -z "${output}" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/display.bats
```

Expected: FAIL — `lib/display.sh` doesn't exist yet.

**Step 3: Implement lib/display.sh**

Create `lib/display.sh`:
```bash
#!/usr/bin/env bash
# lib/display.sh — Terminal output functions for ckad-drill
#
# All user-facing output goes through these functions.
# Colors are automatically disabled when stdout is not a terminal.

# ---------------------------------------------------------------------------
# Color setup — disabled when not a terminal
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _CLR_GREEN=$'\033[0;32m'
  _CLR_RED=$'\033[0;31m'
  _CLR_RED_BOLD=$'\033[1;31m'
  _CLR_BLUE=$'\033[0;34m'
  _CLR_YELLOW=$'\033[0;33m'
  _CLR_WHITE_BOLD=$'\033[1;37m'
  _CLR_RESET=$'\033[0m'
else
  _CLR_GREEN=""
  _CLR_RED=""
  _CLR_RED_BOLD=""
  _CLR_BLUE=""
  _CLR_YELLOW=""
  _CLR_WHITE_BOLD=""
  _CLR_RESET=""
fi

# ---------------------------------------------------------------------------
# Output functions
# ---------------------------------------------------------------------------

pass() {
  printf '%s\n' "${_CLR_GREEN}✅ ${1}${_CLR_RESET}"
}

fail() {
  printf '%s\n' "${_CLR_RED}❌ ${1}${_CLR_RESET}"
}

info() {
  printf '%s\n' "${_CLR_BLUE}${1}${_CLR_RESET}"
}

warn() {
  printf '%s\n' "${_CLR_YELLOW}⚠  ${1}${_CLR_RESET}"
}

error() {
  printf '%s\n' "${_CLR_RED_BOLD}ERROR: ${1}${_CLR_RESET}" >&2
  return 1
}

header() {
  local text="${1}"
  local width=60
  local rule
  rule="$(printf '%*s' "${width}" '' | tr ' ' '─')"
  printf '\n%s\n' "${_CLR_WHITE_BOLD}${rule}"
  printf '  %s\n' "${text}"
  printf '%s%s\n\n' "${rule}" "${_CLR_RESET}"
}
```

Note: `error()` uses `return 1` not `exit 1` — per architecture, lib functions return codes, never exit directly. The calling code in `bin/ckad-drill` with `set -e` will cause this to exit. When called directly (e.g., `error "msg" || true`), callers can handle it.

**Step 4: Run tests**

```bash
bats test/unit/display.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/display.sh
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add lib/display.sh test/unit/display.bats
git commit -m "feat: implement lib/display.sh with color-aware output functions

pass/fail/info/warn/error/header functions with ANSI colors.
Colors auto-disabled when stdout is not a terminal.
Includes bats unit tests."
```

---

### Task 4: Implement lib/cluster.sh (Story 2.1)

**Files:**
- Create: `lib/cluster.sh`
- Test: `test/unit/cluster.bats`

**Step 1: Write failing unit tests**

Create `test/unit/cluster.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/cluster.sh"
}

@test "cluster functions are defined" {
  declare -f cluster_create > /dev/null
  declare -f cluster_delete > /dev/null
  declare -f cluster_reset > /dev/null
  declare -f cluster_ensure_running > /dev/null
  declare -f cluster_exists > /dev/null
}

@test "CKAD_CLUSTER_NAME is set" {
  [[ "${CKAD_CLUSTER_NAME}" == "ckad-drill" ]]
}

@test "sourcing cluster.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/cluster.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "_cluster_check_docker detects missing docker" {
  # Override PATH to hide docker
  PATH="/nonexistent" run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/cluster.sh'
    _cluster_check_docker
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"Docker"* ]]
}

@test "_cluster_check_kind detects missing kind" {
  PATH="/nonexistent" run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/cluster.sh'
    _cluster_check_kind
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"kind"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/cluster.bats
```

**Step 3: Implement lib/cluster.sh**

Create `lib/cluster.sh`:
```bash
#!/usr/bin/env bash
# lib/cluster.sh — Kind cluster lifecycle management for ckad-drill
#
# Functions for creating, deleting, and health-checking the kind cluster.
# All output goes through display.sh functions.

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

_cluster_check_docker() {
  if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Install Docker first: https://docs.docker.com/get-docker/"
    return 1
  fi
  if ! docker info &>/dev/null; then
    error "Docker is not running. Start Docker and try again."
    return 1
  fi
}

_cluster_check_kind() {
  if ! command -v kind &>/dev/null; then
    error "kind is not installed. Install it: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Cluster state queries
# ---------------------------------------------------------------------------

cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^${CKAD_CLUSTER_NAME}$"
}

cluster_ensure_running() {
  if ! cluster_exists; then
    error "Cluster '${CKAD_CLUSTER_NAME}' is not running. Run 'ckad-drill start' first."
    return "${EXIT_NO_CLUSTER}"
  fi
  if ! kubectl --context "kind-${CKAD_CLUSTER_NAME}" cluster-info &>/dev/null; then
    error "Cluster '${CKAD_CLUSTER_NAME}' exists but is not healthy. Run 'ckad-drill reset' to recreate."
    return "${EXIT_NO_CLUSTER}"
  fi
}

# ---------------------------------------------------------------------------
# Cluster lifecycle
# ---------------------------------------------------------------------------

cluster_create() {
  _cluster_check_docker || return $?
  _cluster_check_kind || return $?

  if cluster_exists; then
    info "Cluster '${CKAD_CLUSTER_NAME}' already exists."
    return 0
  fi

  info "Creating kind cluster '${CKAD_CLUSTER_NAME}'..."

  local kind_config="${CKAD_ROOT}/scripts/kind-config.yaml"
  if [[ -f "${kind_config}" ]]; then
    kind create cluster --name "${CKAD_CLUSTER_NAME}" --config "${kind_config}"
  else
    kind create cluster --name "${CKAD_CLUSTER_NAME}"
  fi

  kubectl config use-context "kind-${CKAD_CLUSTER_NAME}" &>/dev/null
  pass "Cluster '${CKAD_CLUSTER_NAME}' created successfully."
}

cluster_delete() {
  _cluster_check_kind || return $?

  if ! cluster_exists; then
    info "Cluster '${CKAD_CLUSTER_NAME}' does not exist."
    return 0
  fi

  info "Deleting kind cluster '${CKAD_CLUSTER_NAME}'..."
  kind delete cluster --name "${CKAD_CLUSTER_NAME}"
  pass "Cluster '${CKAD_CLUSTER_NAME}' deleted."
}

cluster_reset() {
  info "Resetting cluster '${CKAD_CLUSTER_NAME}'..."
  cluster_delete
  cluster_create
}
```

**Step 4: Run tests**

```bash
bats test/unit/cluster.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/cluster.sh
```

Expected: No warnings. (Note: shellcheck may flag `$?` usage — adjust if needed.)

**Step 6: Commit**

```bash
git add lib/cluster.sh test/unit/cluster.bats
git commit -m "feat: implement lib/cluster.sh for kind cluster lifecycle

cluster_create/delete/reset/ensure_running/exists functions.
Checks for Docker and kind before operations. Idempotent create/delete.
Includes bats unit tests."
```

---

### Task 5: Create kind config and scripts/cluster-setup.sh (Story 2.2)

**Files:**
- Create: `scripts/kind-config.yaml`
- Create: `scripts/cluster-setup.sh`
- Test: `test/unit/cluster-setup.bats`

**Step 1: Create kind cluster config**

Create `scripts/kind-config.yaml`:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
```

Note: `disableDefaultCNI: true` because we install Calico separately for NetworkPolicy support.

**Step 2: Write basic tests**

Create `test/unit/cluster-setup.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
}

@test "kind-config.yaml exists" {
  [[ -f "${CKAD_ROOT}/scripts/kind-config.yaml" ]]
}

@test "kind-config.yaml disables default CNI" {
  grep -q "disableDefaultCNI: true" "${CKAD_ROOT}/scripts/kind-config.yaml"
}

@test "kind-config.yaml has control-plane and workers" {
  grep -c "role:" "${CKAD_ROOT}/scripts/kind-config.yaml" | grep -q "3"
}

@test "cluster-setup.sh exists and is executable" {
  [[ -x "${CKAD_ROOT}/scripts/cluster-setup.sh" ]]
}

@test "cluster-setup.sh passes shellcheck" {
  shellcheck "${CKAD_ROOT}/scripts/cluster-setup.sh"
}

@test "cluster-setup.sh defines install functions" {
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  # Just check that sourcing + function existence works (don't run against real cluster)
  bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/scripts/cluster-setup.sh'
    declare -f cluster_setup_addons > /dev/null
  "
}
```

**Step 3: Run tests to verify they fail**

```bash
bats test/unit/cluster-setup.bats
```

**Step 4: Implement scripts/cluster-setup.sh**

Create `scripts/cluster-setup.sh`:
```bash
#!/usr/bin/env bash
# scripts/cluster-setup.sh — Install cluster addons for ckad-drill
#
# Installs Calico CNI, nginx ingress controller, and metrics-server
# on a kind cluster to match the real CKAD exam environment (ADR-04).
#
# Usage: source this file and call cluster_setup_addons, OR run directly.

# Source display.sh if not already loaded
if ! declare -f info &>/dev/null; then
  _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_SCRIPT_DIR}/../lib/common.sh"
  source "${_SCRIPT_DIR}/../lib/display.sh"
fi

# ---------------------------------------------------------------------------
# Addon URLs (pinned versions for reproducibility)
# ---------------------------------------------------------------------------
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml"
INGRESS_NGINX_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/kind/deploy.yaml"
METRICS_SERVER_URL="https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.1/components.yaml"

# ---------------------------------------------------------------------------
# Addon installation functions
# ---------------------------------------------------------------------------

_setup_calico() {
  info "Installing Calico CNI..."
  kubectl apply -f "${CALICO_URL}" --context "kind-${CKAD_CLUSTER_NAME}"

  info "Waiting for Calico pods to be ready..."
  kubectl wait --for=condition=ready pod -l k8s-app=calico-node \
    -n kube-system --timeout=120s --context "kind-${CKAD_CLUSTER_NAME}"
  pass "Calico CNI installed."
}

_setup_ingress_nginx() {
  info "Installing nginx ingress controller..."
  kubectl apply -f "${INGRESS_NGINX_URL}" --context "kind-${CKAD_CLUSTER_NAME}"

  info "Waiting for ingress controller to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller \
    -n ingress-nginx --timeout=120s --context "kind-${CKAD_CLUSTER_NAME}"
  pass "Nginx ingress controller installed."
}

_setup_metrics_server() {
  info "Installing metrics-server..."
  kubectl apply -f "${METRICS_SERVER_URL}" --context "kind-${CKAD_CLUSTER_NAME}"

  # Patch metrics-server for kind (needs --kubelet-insecure-tls)
  kubectl patch deployment metrics-server -n kube-system \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

  info "Waiting for metrics-server to be ready..."
  kubectl wait --for=condition=ready pod -l k8s-app=metrics-server \
    -n kube-system --timeout=120s --context "kind-${CKAD_CLUSTER_NAME}"
  pass "Metrics-server installed."
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

cluster_setup_addons() {
  info "Setting up cluster addons for CKAD exam environment..."

  _setup_calico
  _setup_ingress_nginx
  _setup_metrics_server

  # Wait for all nodes to be ready
  info "Waiting for all nodes to be ready..."
  kubectl wait --for=condition=ready node --all \
    --timeout=120s --context "kind-${CKAD_CLUSTER_NAME}"

  pass "All addons installed. Cluster is ready for CKAD practice."
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  cluster_setup_addons
fi
```

**Step 5: Make executable**

```bash
chmod +x scripts/cluster-setup.sh
```

**Step 6: Run tests**

```bash
bats test/unit/cluster-setup.bats
```

Expected: All PASS.

**Step 7: Run shellcheck**

```bash
shellcheck scripts/cluster-setup.sh
```

Expected: No warnings.

**Step 8: Commit**

```bash
git add scripts/kind-config.yaml scripts/cluster-setup.sh test/unit/cluster-setup.bats
git commit -m "feat: add kind config and cluster-setup.sh for CKAD addons

Kind config with Calico CNI support (disableDefaultCNI), ingress
port mappings, 3 nodes. cluster-setup.sh installs Calico, nginx
ingress controller, and metrics-server. Includes bats tests."
```

---

### Task 6: Create stub bin/ckad-drill with start/stop/reset (Story 5.1 partial)

This is a minimal entry point — just enough to wire up cluster management and verify the Sprint 1 deliverable works end-to-end.

**Files:**
- Create: `bin/ckad-drill`
- Test: `test/unit/cli.bats`

**Step 1: Write tests for CLI dispatch**

Create `test/unit/cli.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  export PATH="${CKAD_ROOT}/bin:${PATH}"
}

@test "ckad-drill with no args shows usage" {
  run ckad-drill
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "ckad-drill --help shows usage" {
  run ckad-drill --help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "ckad-drill unknown-command shows error" {
  run ckad-drill unknown-command
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown command"* ]]
}

@test "ckad-drill is executable" {
  [[ -x "${CKAD_ROOT}/bin/ckad-drill" ]]
}

@test "ckad-drill passes shellcheck" {
  shellcheck "${CKAD_ROOT}/bin/ckad-drill"
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/cli.bats
```

**Step 3: Implement bin/ckad-drill**

Create `bin/ckad-drill`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# ckad-drill — CKAD exam practice tool
# ---------------------------------------------------------------------------

CKAD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKAD_ROOT

# Source libraries in dependency order
source "${CKAD_ROOT}/lib/common.sh"
source "${CKAD_ROOT}/lib/display.sh"
source "${CKAD_ROOT}/lib/cluster.sh"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

_usage() {
  cat <<'EOF'
Usage: ckad-drill <command> [options]

Cluster Management:
  start             Create kind cluster and install addons
  stop              Delete kind cluster
  reset             Recreate kind cluster

Practice (coming soon):
  drill             Start a drill scenario
  check             Validate current scenario
  hint              Show hint for current scenario
  solution          Show solution for current scenario
  next              Move to next scenario
  skip              Skip current scenario
  current           Reprint current scenario task
  learn             Start learn mode
  exam              Start exam mode
  status            Show progress dashboard

Options:
  --help            Show this help message
  --version         Show version

EOF
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_start() {
  cluster_create
  # Install addons
  source "${CKAD_ROOT}/scripts/cluster-setup.sh"
  cluster_setup_addons
}

cmd_stop() {
  cluster_delete
}

cmd_reset() {
  cluster_reset
  source "${CKAD_ROOT}/scripts/cluster-setup.sh"
  cluster_setup_addons
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

main() {
  local command="${1:-}"

  case "${command}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    reset)   cmd_reset ;;
    --help)  _usage ;;
    --version) echo "ckad-drill 0.1.0-dev" ;;
    "")
      _usage >&2
      return 1
      ;;
    *)
      error "Unknown command: ${command}. Run 'ckad-drill --help' for usage."
      ;;
  esac
}

main "$@"
```

**Step 4: Make executable**

```bash
chmod +x bin/ckad-drill
```

**Step 5: Run tests**

```bash
bats test/unit/cli.bats
```

Expected: All PASS.

**Step 6: Run shellcheck on everything**

```bash
shellcheck bin/ckad-drill lib/*.sh scripts/cluster-setup.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add bin/ckad-drill test/unit/cli.bats
git commit -m "feat: add bin/ckad-drill entry point with start/stop/reset

Minimal CLI entry point that dispatches cluster management commands.
Sources lib files in dependency order. Includes usage help and
unknown command handling. Includes bats tests."
```

---

### Task 7: Update Makefile and remove .gitkeep placeholders

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile now that real files exist**

Replace the Makefile with:
```makefile
.PHONY: test shellcheck test-unit test-integration install

SHELL := /bin/bash

# All bash scripts to lint
SCRIPTS := bin/ckad-drill $(wildcard lib/*.sh) $(wildcard scripts/*.sh)

test: shellcheck test-unit

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck $(SCRIPTS)
	@echo "shellcheck passed"

test-unit:
	@echo "Running unit tests..."
	@bats test/unit/
	@echo "Unit tests passed"

test-integration:
	@echo "Running integration tests (requires kind cluster)..."
	@bats test/integration/
	@echo "Integration tests passed"

install:
	@echo "Run: scripts/install.sh"
```

**Step 2: Remove .gitkeep files from directories that now have content**

```bash
rm -f bin/.gitkeep lib/.gitkeep scripts/.gitkeep test/unit/.gitkeep test/helpers/.gitkeep
```

**Step 3: Run full test suite**

```bash
make test
```

Expected: shellcheck passes, all unit tests pass.

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: update Makefile for real scripts, clean up gitkeep files"
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 1.1 | Directory structure, archive content, Makefile, LICENSE | — |
| 2 | 1.2 | lib/common.sh | test/unit/common.bats |
| 3 | 1.3 | lib/display.sh | test/unit/display.bats |
| 4 | 2.1 | lib/cluster.sh | test/unit/cluster.bats |
| 5 | 2.2 | scripts/kind-config.yaml, scripts/cluster-setup.sh | test/unit/cluster-setup.bats |
| 6 | 5.1 (partial) | bin/ckad-drill (start/stop/reset) | test/unit/cli.bats |
| 7 | — | Makefile cleanup | make test |

**After Sprint 1:** `ckad-drill start` creates a kind cluster with Calico, ingress, and metrics-server. `ckad-drill stop` tears it down. Foundation libs (common.sh, display.sh) are ready for Sprint 2.

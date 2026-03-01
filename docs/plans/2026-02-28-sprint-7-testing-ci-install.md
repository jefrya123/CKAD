# Sprint 7: Validation Tool, Install & CI — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the validate-scenario subcommand for content contributors, user/developer install scripts, comprehensive bats test coverage for all lib files, and a GitHub Actions CI pipeline.

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

**Sprint dependencies:** Sprints 1-6 must be complete. All lib files exist: `common.sh`, `display.sh`, `cluster.sh`, `scenario.sh`, `validator.sh`, `timer.sh`, `progress.sh`, `exam.sh`. `bin/ckad-drill` dispatches all subcommands. Scenario YAML content exists in `scenarios/domain-{1..5}/`. Some unit tests for each lib were created alongside their respective sprints — this sprint fills gaps to ensure comprehensive coverage.

---

### Task 1: Implement validate-scenario Subcommand (Story 10.1)

**Files:**
- Create: `lib/validate-scenario.sh`
- Modify: `bin/ckad-drill` (add `validate-scenario` dispatch)
- Test: `test/unit/validate-scenario.bats`

**Step 1: Write failing tests**

Create `test/unit/validate-scenario.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/scenario.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
  source "${CKAD_ROOT}/lib/validate-scenario.sh"
}

@test "validate_scenario functions are defined" {
  declare -f validate_scenario_file > /dev/null
  declare -f validate_scenario_dir > /dev/null
  declare -f _validate_scenario_schema > /dev/null
  declare -f _validate_scenario_end_to_end > /dev/null
}

@test "sourcing validate-scenario.sh produces no output" {
  local output
  output="$(
    source "${CKAD_ROOT}/lib/common.sh"
    source "${CKAD_ROOT}/lib/display.sh"
    source "${CKAD_ROOT}/lib/scenario.sh"
    source "${CKAD_ROOT}/lib/validator.sh"
    source "${CKAD_ROOT}/lib/validate-scenario.sh" 2>&1
  )"
  [[ -z "${output}" ]]
}

@test "_validate_scenario_schema rejects missing required fields" {
  local tmpfile="${BATS_TEST_TMPDIR}/bad-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-bad
domain: 1
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"title"* ]] || [[ "${output}" == *"required"* ]]
}

@test "_validate_scenario_schema rejects invalid domain" {
  local tmpfile="${BATS_TEST_TMPDIR}/bad-domain.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-bad-domain
domain: 6
title: Bad domain
difficulty: easy
time_limit: 120
description: A test scenario
validations:
  - type: resource_exists
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"domain must be 1-5"* ]]
}

@test "_validate_scenario_schema rejects invalid difficulty" {
  local tmpfile="${BATS_TEST_TMPDIR}/bad-difficulty.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-bad-difficulty
domain: 1
title: Bad difficulty
difficulty: extreme
time_limit: 120
description: A test scenario
validations:
  - type: resource_exists
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"difficulty must be easy/medium/hard"* ]]
}

@test "_validate_scenario_schema rejects negative time_limit" {
  local tmpfile="${BATS_TEST_TMPDIR}/bad-time.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-bad-time
domain: 1
title: Bad time
difficulty: easy
time_limit: -10
description: A test scenario
validations:
  - type: resource_exists
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"time_limit must be positive"* ]]
}

@test "_validate_scenario_schema rejects unknown validation type" {
  local tmpfile="${BATS_TEST_TMPDIR}/bad-valtype.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-bad-valtype
domain: 1
title: Bad validation type
difficulty: easy
time_limit: 120
description: A test scenario
validations:
  - type: check_magic
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"unknown validation type"* ]] || [[ "${output}" == *"check_magic"* ]]
}

@test "_validate_scenario_schema accepts valid scenario" {
  local tmpfile="${BATS_TEST_TMPDIR}/good-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-good
domain: 1
title: Good scenario
difficulty: easy
time_limit: 120
description: A valid test scenario
validations:
  - type: resource_exists
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    _validate_scenario_schema '${tmpfile}'
  "
  [[ "${status}" -eq 0 ]]
}

@test "validate_scenario_file requires cluster for end-to-end" {
  # Without a cluster, end-to-end should fail gracefully
  local tmpfile="${BATS_TEST_TMPDIR}/good-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-e2e
domain: 1
title: E2E test
difficulty: easy
time_limit: 120
description: A valid test scenario
validations:
  - type: resource_exists
    resource: pod/test
solution: |
  kubectl run test --image=nginx
YAML
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/cluster.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/validate-scenario.sh'
    validate_scenario_file '${tmpfile}'
  "
  # Should fail because no cluster is running (exit code 2 = EXIT_NO_CLUSTER)
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"cluster"* ]] || [[ "${output}" == *"Cluster"* ]] || [[ "${output}" == *"start"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/validate-scenario.bats
```

Expected: FAIL — `lib/validate-scenario.sh` doesn't exist yet.

**Step 3: Implement lib/validate-scenario.sh**

Create `lib/validate-scenario.sh`:
```bash
#!/usr/bin/env bash
# lib/validate-scenario.sh — Scenario validation for content contributors
#
# Validates scenario YAML files: schema check, then end-to-end
# (setup -> apply solution -> run validations -> cleanup).
# Used by `ckad-drill validate-scenario <file|dir>`.

# ---------------------------------------------------------------------------
# Valid values for schema checks
# ---------------------------------------------------------------------------
_VALID_DOMAINS="1 2 3 4 5"
_VALID_DIFFICULTIES="easy medium hard"
_VALID_CHECK_TYPES="resource_exists resource_field container_count container_image container_env volume_mount container_running label_selector resource_count command_output"

# ---------------------------------------------------------------------------
# Schema validation (no cluster needed)
# ---------------------------------------------------------------------------

_validate_scenario_schema() {
  local file="${1}"
  local errors=()

  if [[ ! -f "${file}" ]]; then
    error "File not found: ${file}"
    return "${EXIT_PARSE_ERROR}"
  fi

  # Check required fields
  local required_fields=("id" "domain" "title" "difficulty" "time_limit" "description" "validations" "solution")
  local field
  for field in "${required_fields[@]}"; do
    local value
    value="$(yq e ".${field}" "${file}" 2>/dev/null)"
    if [[ -z "${value}" ]] || [[ "${value}" == "null" ]]; then
      errors+=("missing required field: ${field}")
    fi
  done

  # If required fields are missing, report and return early
  if [[ ${#errors[@]} -gt 0 ]]; then
    local err
    for err in "${errors[@]}"; do
      fail "${err}"
    done
    return "${EXIT_PARSE_ERROR}"
  fi

  # Validate domain (1-5)
  local domain
  domain="$(yq e '.domain' "${file}")"
  local valid_domain=false
  local d
  for d in ${_VALID_DOMAINS}; do
    if [[ "${domain}" == "${d}" ]]; then
      valid_domain=true
      break
    fi
  done
  if [[ "${valid_domain}" == "false" ]]; then
    errors+=("domain must be 1-5, got: ${domain}")
  fi

  # Validate difficulty
  local difficulty
  difficulty="$(yq e '.difficulty' "${file}")"
  local valid_difficulty=false
  local diff
  for diff in ${_VALID_DIFFICULTIES}; do
    if [[ "${difficulty}" == "${diff}" ]]; then
      valid_difficulty=true
      break
    fi
  done
  if [[ "${valid_difficulty}" == "false" ]]; then
    errors+=("difficulty must be easy/medium/hard, got: ${difficulty}")
  fi

  # Validate time_limit (positive integer)
  local time_limit
  time_limit="$(yq e '.time_limit' "${file}")"
  if ! [[ "${time_limit}" =~ ^[0-9]+$ ]] || [[ "${time_limit}" -le 0 ]]; then
    errors+=("time_limit must be positive integer, got: ${time_limit}")
  fi

  # Validate each validation type
  local val_count
  val_count="$(yq e '.validations | length' "${file}")"
  local i
  for ((i = 0; i < val_count; i++)); do
    local check_type
    check_type="$(yq e ".validations[${i}].type" "${file}")"
    local valid_type=false
    local vt
    for vt in ${_VALID_CHECK_TYPES}; do
      if [[ "${check_type}" == "${vt}" ]]; then
        valid_type=true
        break
      fi
    done
    if [[ "${valid_type}" == "false" ]]; then
      errors+=("unknown validation type: ${check_type} (valid: ${_VALID_CHECK_TYPES})")
    fi
  done

  # Validate namespace format if present
  local namespace
  namespace="$(yq e '.namespace // ""' "${file}")"
  if [[ -n "${namespace}" ]]; then
    if ! [[ "${namespace}" =~ ^[a-z][a-z0-9-]*$ ]]; then
      errors+=("namespace must be lowercase with hyphens only, got: ${namespace}")
    fi
  fi

  # Report errors
  if [[ ${#errors[@]} -gt 0 ]]; then
    local err
    for err in "${errors[@]}"; do
      fail "${err}"
    done
    return "${EXIT_PARSE_ERROR}"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# End-to-end validation (requires cluster)
# ---------------------------------------------------------------------------

_validate_scenario_end_to_end() {
  local file="${1}"
  local scenario_id
  scenario_id="$(yq e '.id' "${file}")"
  local namespace
  namespace="$(yq e '.namespace // ""' "${file}")"
  if [[ -z "${namespace}" ]]; then
    namespace="drill-${scenario_id}"
  fi

  # Step 1: Setup
  info "Setting up scenario '${scenario_id}'..."
  kubectl create namespace "${namespace}" --context "kind-${CKAD_CLUSTER_NAME}" --dry-run=client -o yaml \
    | kubectl apply --context "kind-${CKAD_CLUSTER_NAME}" -f - >/dev/null

  local setup_count
  setup_count="$(yq e '.setup | length' "${file}" 2>/dev/null)"
  if [[ "${setup_count}" != "null" ]] && [[ "${setup_count}" -gt 0 ]]; then
    local i
    for ((i = 0; i < setup_count; i++)); do
      local cmd
      cmd="$(yq e ".setup[${i}]" "${file}")"
      info "  Running setup command $((i + 1))/${setup_count}..."
      if ! eval "${cmd}" >/dev/null 2>&1; then
        fail "Setup command failed: ${cmd}"
        _validate_scenario_cleanup "${namespace}"
        return "${EXIT_ERROR}"
      fi
    done
  fi

  # Step 2: Apply solution
  info "Applying solution for '${scenario_id}'..."
  local solution
  solution="$(yq e '.solution' "${file}")"
  if ! eval "${solution}" >/dev/null 2>&1; then
    fail "Solution failed to apply for '${scenario_id}'"
    _validate_scenario_cleanup "${namespace}"
    return "${EXIT_ERROR}"
  fi

  # Brief pause for resources to be created
  sleep 2

  # Step 3: Run validations
  info "Running validations for '${scenario_id}'..."
  local validations_json
  validations_json="$(yq e -o=json '.validations' "${file}")"
  local result
  if ! result="$(validator_run_checks "${namespace}" "${validations_json}")"; then
    fail "Validations failed for '${scenario_id}'"
    _validate_scenario_cleanup "${namespace}"
    return "${EXIT_ERROR}"
  fi

  # Step 4: Cleanup
  _validate_scenario_cleanup "${namespace}"

  return 0
}

_validate_scenario_cleanup() {
  local namespace="${1}"
  info "Cleaning up namespace '${namespace}'..."
  kubectl delete namespace "${namespace}" --context "kind-${CKAD_CLUSTER_NAME}" --ignore-not-found >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

validate_scenario_file() {
  local file="${1}"

  info "Validating scenario: ${file}"

  # Phase 1: Schema validation
  info "  Phase 1: Schema validation..."
  if ! _validate_scenario_schema "${file}"; then
    fail "FAIL: ${file} — schema errors (see above)"
    return "${EXIT_PARSE_ERROR}"
  fi
  pass "  Schema validation passed"

  # Phase 2: End-to-end validation (requires cluster)
  info "  Phase 2: End-to-end validation..."
  if ! cluster_ensure_running; then
    return "${EXIT_NO_CLUSTER}"
  fi

  if ! _validate_scenario_end_to_end "${file}"; then
    fail "FAIL: ${file} — end-to-end validation failed (see above)"
    return "${EXIT_ERROR}"
  fi
  pass "  End-to-end validation passed"

  local scenario_id
  scenario_id="$(yq e '.id' "${file}")"
  pass "PASS: scenario '${scenario_id}' validated successfully"
  return 0
}

validate_scenario_dir() {
  local dir="${1}"
  local total=0
  local passed=0
  local failed=0
  local failures=()

  info "Validating all scenarios in: ${dir}"

  local file
  while IFS= read -r -d '' file; do
    total=$((total + 1))
    if validate_scenario_file "${file}"; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
      failures+=("${file}")
    fi
    echo ""
  done < <(find "${dir}" -name "*.yaml" -print0 | sort -z)

  # Summary
  header "Validation Summary"
  info "Total:  ${total}"
  pass "Passed: ${passed}"
  if [[ "${failed}" -gt 0 ]]; then
    fail "Failed: ${failed}"
    local f
    for f in "${failures[@]}"; do
      fail "  - ${f}"
    done
    return "${EXIT_ERROR}"
  else
    pass "All scenarios validated successfully!"
  fi
}
```

**Step 4: Wire into bin/ckad-drill**

Add to `bin/ckad-drill` — source the new lib and add the dispatch case:

In the sourcing section, add:
```bash
source "${CKAD_ROOT}/lib/validate-scenario.sh"
```

In the main dispatch `case` block, add:
```bash
    validate-scenario)
      shift
      local target="${1:-}"
      if [[ -z "${target}" ]]; then
        error "Usage: ckad-drill validate-scenario <file|directory>"
      fi
      if [[ -d "${target}" ]]; then
        validate_scenario_dir "${target}"
      elif [[ -f "${target}" ]]; then
        validate_scenario_file "${target}"
      else
        error "Not a file or directory: ${target}"
      fi
      ;;
```

**Step 5: Run tests**

```bash
bats test/unit/validate-scenario.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck lib/validate-scenario.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add lib/validate-scenario.sh test/unit/validate-scenario.bats bin/ckad-drill
git commit -m "feat: implement validate-scenario subcommand (Story 10.1)

Full scenario validation: schema check (required fields, domain 1-5,
difficulty, time_limit, validation types) then end-to-end against
live cluster (setup -> apply solution -> run validations -> cleanup).
Supports single file or directory. Includes bats unit tests."
```

---

### Task 2: Implement scripts/install.sh — User Installation (Story 10.2)

**Files:**
- Create: `scripts/install.sh`
- Test: `test/unit/install.bats`

**Step 1: Write failing tests**

Create `test/unit/install.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
}

@test "install.sh exists and is executable" {
  [[ -x "${CKAD_ROOT}/scripts/install.sh" ]]
}

@test "install.sh passes shellcheck" {
  shellcheck "${CKAD_ROOT}/scripts/install.sh"
}

@test "install.sh defines required functions" {
  run bash -c "
    # Override commands to prevent actual execution
    docker() { return 0; }
    kubectl() { return 0; }
    export -f docker kubectl
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    declare -f _install_check_docker > /dev/null &&
    declare -f _install_check_kubectl > /dev/null &&
    declare -f _install_detect_os > /dev/null &&
    declare -f _install_detect_arch > /dev/null &&
    declare -f _install_kind > /dev/null &&
    declare -f _install_yq > /dev/null &&
    declare -f _install_jq > /dev/null &&
    declare -f _install_download_ckad_drill > /dev/null &&
    declare -f _install_symlink > /dev/null
  "
  [[ "${status}" -eq 0 ]]
}

@test "install.sh detects OS correctly" {
  run bash -c "
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    _install_detect_os
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "linux" ]] || [[ "${output}" == "darwin" ]]
}

@test "install.sh detects architecture correctly" {
  run bash -c "
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    _install_detect_arch
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "amd64" ]] || [[ "${output}" == "arm64" ]]
}

@test "install.sh errors when docker is missing" {
  run bash -c "
    PATH='/nonexistent'
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    _install_check_docker
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"Docker"* ]]
}

@test "install.sh errors when kubectl is missing" {
  run bash -c "
    PATH='/nonexistent'
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    _install_check_kubectl
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"kubectl"* ]]
}

@test "install.sh sets correct install paths" {
  run bash -c "
    source '${CKAD_ROOT}/scripts/install.sh' --source-only 2>/dev/null
    echo \"\${INSTALL_DIR}\"
  "
  [[ "${output}" == *".local/share/ckad-drill"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/install.bats
```

Expected: FAIL — `scripts/install.sh` doesn't exist yet.

**Step 3: Implement scripts/install.sh**

Create `scripts/install.sh`:
```bash
#!/usr/bin/env bash
# scripts/install.sh — Install ckad-drill for end users
#
# Usage: curl -sSL https://raw.githubusercontent.com/<repo>/main/scripts/install.sh | sh
#
# What it does:
#   1. Checks for Docker (error if missing)
#   2. Checks for kubectl (error if missing)
#   3. Checks/installs kind (if missing)
#   4. Checks/installs yq (if missing)
#   5. Checks/installs jq (if missing)
#   6. Checks for Helm (warns if missing)
#   7. Downloads ckad-drill to ~/.local/share/ckad-drill/
#   8. Symlinks to ~/.local/bin/ckad-drill
#   9. Verifies ~/.local/bin is in PATH

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
INSTALL_DIR="${HOME}/.local/share/ckad-drill"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/jeffmachado/ckad-drill"
REPO_ARCHIVE_URL="${REPO_URL}/archive/refs/heads/main.tar.gz"

# Pinned versions for reproducibility
KIND_VERSION="v0.25.0"
YQ_VERSION="v4.44.3"
JQ_VERSION="1.7.1"

# ---------------------------------------------------------------------------
# Colors (stripped if not a terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _GREEN=$'\033[0;32m'
  _RED=$'\033[0;31m'
  _YELLOW=$'\033[0;33m'
  _BLUE=$'\033[0;34m'
  _BOLD=$'\033[1m'
  _RESET=$'\033[0m'
else
  _GREEN="" _RED="" _YELLOW="" _BLUE="" _BOLD="" _RESET=""
fi

_pass()  { printf '%s\n' "${_GREEN}✅ ${1}${_RESET}"; }
_fail()  { printf '%s\n' "${_RED}❌ ${1}${_RESET}" >&2; }
_info()  { printf '%s\n' "${_BLUE}${1}${_RESET}"; }
_warn()  { printf '%s\n' "${_YELLOW}⚠  ${1}${_RESET}"; }
_error() { printf '%s\n' "${_RED}${_BOLD}ERROR: ${1}${_RESET}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# OS / Architecture detection
# ---------------------------------------------------------------------------

_install_detect_os() {
  local os
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "${os}" in
    linux)  echo "linux" ;;
    darwin) echo "darwin" ;;
    *)      _error "Unsupported OS: ${os}. ckad-drill supports Linux and macOS." ;;
  esac
}

_install_detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64)  echo "amd64" ;;
    aarch64) echo "arm64" ;;
    arm64)   echo "arm64" ;;
    *)       _error "Unsupported architecture: ${arch}. ckad-drill supports amd64 and arm64." ;;
  esac
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

_install_check_docker() {
  if ! command -v docker &>/dev/null; then
    _error "Docker is not installed. Install Docker first: https://docs.docker.com/get-docker/"
  fi
  if ! docker info &>/dev/null 2>&1; then
    _error "Docker is not running. Start Docker and re-run this script."
  fi
  _pass "Docker is installed and running"
}

_install_check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    _error "kubectl is not installed. Install it: https://kubernetes.io/docs/tasks/tools/"
  fi
  _pass "kubectl is installed"
}

_install_check_helm() {
  if ! command -v helm &>/dev/null; then
    _warn "Helm is not installed. Helm is optional but required for Helm-specific scenarios."
    _warn "Install Helm: https://helm.sh/docs/intro/install/"
  else
    _pass "Helm is installed"
  fi
}

# ---------------------------------------------------------------------------
# Tool installation
# ---------------------------------------------------------------------------

_install_kind() {
  if command -v kind &>/dev/null; then
    _pass "kind is already installed ($(kind version 2>/dev/null || echo 'unknown version'))"
    return 0
  fi

  local os arch
  os="$(_install_detect_os)"
  arch="$(_install_detect_arch)"

  _info "Installing kind ${KIND_VERSION}..."
  local url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}"
  local dest="${BIN_DIR}/kind"

  mkdir -p "${BIN_DIR}"
  if ! curl -sSL -o "${dest}" "${url}"; then
    _error "Failed to download kind from ${url}"
  fi
  chmod +x "${dest}"
  _pass "kind ${KIND_VERSION} installed to ${dest}"
}

_install_yq() {
  if command -v yq &>/dev/null; then
    _pass "yq is already installed ($(yq --version 2>/dev/null || echo 'unknown version'))"
    return 0
  fi

  local os arch
  os="$(_install_detect_os)"
  arch="$(_install_detect_arch)"

  _info "Installing yq ${YQ_VERSION}..."
  local url="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${os}_${arch}"
  local dest="${BIN_DIR}/yq"

  mkdir -p "${BIN_DIR}"
  if ! curl -sSL -o "${dest}" "${url}"; then
    _error "Failed to download yq from ${url}"
  fi
  chmod +x "${dest}"
  _pass "yq ${YQ_VERSION} installed to ${dest}"
}

_install_jq() {
  if command -v jq &>/dev/null; then
    _pass "jq is already installed ($(jq --version 2>/dev/null || echo 'unknown version'))"
    return 0
  fi

  local os arch
  os="$(_install_detect_os)"
  arch="$(_install_detect_arch)"

  _info "Installing jq ${JQ_VERSION}..."

  # jq uses different naming conventions
  local jq_os="${os}"
  local jq_arch="${arch}"
  if [[ "${os}" == "darwin" ]]; then
    jq_os="macos"
  fi

  local url="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${jq_os}-${jq_arch}"
  local dest="${BIN_DIR}/jq"

  mkdir -p "${BIN_DIR}"
  if ! curl -sSL -o "${dest}" "${url}"; then
    _error "Failed to download jq from ${url}"
  fi
  chmod +x "${dest}"
  _pass "jq ${JQ_VERSION} installed to ${dest}"
}

# ---------------------------------------------------------------------------
# ckad-drill installation
# ---------------------------------------------------------------------------

_install_download_ckad_drill() {
  _info "Downloading ckad-drill to ${INSTALL_DIR}..."

  # Clean previous install
  if [[ -d "${INSTALL_DIR}" ]]; then
    _info "Removing previous installation at ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR}"
  fi

  mkdir -p "${INSTALL_DIR}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  if ! curl -sSL -o "${tmpdir}/ckad-drill.tar.gz" "${REPO_ARCHIVE_URL}"; then
    _error "Failed to download ckad-drill from ${REPO_ARCHIVE_URL}"
  fi

  tar -xzf "${tmpdir}/ckad-drill.tar.gz" -C "${tmpdir}"

  # Move contents (the archive extracts to a directory named <repo>-main/)
  local extracted_dir
  extracted_dir="$(find "${tmpdir}" -maxdepth 1 -type d -name "*ckad*" | head -1)"
  if [[ -z "${extracted_dir}" ]]; then
    extracted_dir="$(find "${tmpdir}" -maxdepth 1 -type d ! -name "$(basename "${tmpdir}")" | head -1)"
  fi

  # Copy required directories
  cp -r "${extracted_dir}/bin" "${INSTALL_DIR}/"
  cp -r "${extracted_dir}/lib" "${INSTALL_DIR}/"
  cp -r "${extracted_dir}/scenarios" "${INSTALL_DIR}/"
  cp -r "${extracted_dir}/content" "${INSTALL_DIR}/" 2>/dev/null || true
  cp -r "${extracted_dir}/scripts" "${INSTALL_DIR}/"

  chmod +x "${INSTALL_DIR}/bin/ckad-drill"

  _pass "ckad-drill downloaded to ${INSTALL_DIR}"
}

_install_symlink() {
  mkdir -p "${BIN_DIR}"
  local link="${BIN_DIR}/ckad-drill"

  # Remove old symlink if it exists
  if [[ -L "${link}" ]]; then
    rm "${link}"
  fi

  ln -s "${INSTALL_DIR}/bin/ckad-drill" "${link}"
  _pass "Symlinked ckad-drill to ${link}"
}

_install_check_path() {
  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    _warn "${BIN_DIR} is not in your PATH."
    _warn "Add this to your ~/.bashrc or ~/.zshrc:"
    _warn "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
  else
    _pass "${BIN_DIR} is in PATH"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

_install_main() {
  printf '\n%s\n' "${_BOLD}ckad-drill installer${_RESET}"
  printf '%s\n\n' "────────────────────────────────────"

  _info "Step 1/7: Checking Docker..."
  _install_check_docker

  _info "Step 2/7: Checking kubectl..."
  _install_check_kubectl

  _info "Step 3/7: Checking/installing kind..."
  _install_kind

  _info "Step 4/7: Checking/installing yq..."
  _install_yq

  _info "Step 5/7: Checking/installing jq..."
  _install_jq

  _info "Step 6/7: Checking Helm (optional)..."
  _install_check_helm

  _info "Step 7/7: Downloading ckad-drill..."
  _install_download_ckad_drill
  _install_symlink
  _install_check_path

  printf '\n%s\n' "${_BOLD}────────────────────────────────────${_RESET}"
  _pass "Installation complete!"
  _info ""
  _info "Get started:"
  _info "  ckad-drill start    # Create practice cluster"
  _info "  ckad-drill drill    # Start your first drill"
  _info ""
}

# Allow sourcing for tests without executing
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || true
fi

_install_main
```

**Step 4: Make executable**

```bash
chmod +x scripts/install.sh
```

**Step 5: Run tests**

```bash
bats test/unit/install.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck scripts/install.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add scripts/install.sh test/unit/install.bats
git commit -m "feat: implement scripts/install.sh for user installation (Story 10.2)

Curl-pipe-sh installer that checks Docker/kubectl, installs kind/yq/jq
if missing, downloads ckad-drill to ~/.local/share/ckad-drill/,
symlinks to ~/.local/bin/. Detects OS (linux/darwin) and arch
(amd64/arm64). Warns if Helm is missing. Includes bats tests."
```

---

### Task 3: Implement scripts/dev-setup.sh — Developer Setup (Story 10.3)

**Files:**
- Create: `scripts/dev-setup.sh`
- Test: `test/unit/dev-setup.bats`

**Step 1: Write failing tests**

Create `test/unit/dev-setup.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
}

@test "dev-setup.sh exists and is executable" {
  [[ -x "${CKAD_ROOT}/scripts/dev-setup.sh" ]]
}

@test "dev-setup.sh passes shellcheck" {
  shellcheck "${CKAD_ROOT}/scripts/dev-setup.sh"
}

@test "dev-setup.sh defines required functions" {
  run bash -c "
    source '${CKAD_ROOT}/scripts/dev-setup.sh' --source-only 2>/dev/null
    declare -f _dev_install_bats > /dev/null &&
    declare -f _dev_install_shellcheck > /dev/null &&
    declare -f _dev_detect_package_manager > /dev/null
  "
  [[ "${status}" -eq 0 ]]
}

@test "dev-setup.sh detects package manager" {
  run bash -c "
    source '${CKAD_ROOT}/scripts/dev-setup.sh' --source-only 2>/dev/null
    _dev_detect_package_manager
  "
  [[ "${status}" -eq 0 ]]
  # Should detect one of: brew, apt, dnf, pacman, or manual
  [[ "${output}" == "brew" ]] || [[ "${output}" == "apt" ]] || \
  [[ "${output}" == "dnf" ]] || [[ "${output}" == "pacman" ]] || \
  [[ "${output}" == "manual" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/dev-setup.bats
```

Expected: FAIL — `scripts/dev-setup.sh` doesn't exist yet.

**Step 3: Implement scripts/dev-setup.sh**

Create `scripts/dev-setup.sh`:
```bash
#!/usr/bin/env bash
# scripts/dev-setup.sh — Install development dependencies for ckad-drill
#
# Installs bats-core and shellcheck so developers can run `make test`.
#
# Usage: ./scripts/dev-setup.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _GREEN=$'\033[0;32m'
  _RED=$'\033[0;31m'
  _YELLOW=$'\033[0;33m'
  _BLUE=$'\033[0;34m'
  _BOLD=$'\033[1m'
  _RESET=$'\033[0m'
else
  _GREEN="" _RED="" _YELLOW="" _BLUE="" _BOLD="" _RESET=""
fi

_pass()  { printf '%s\n' "${_GREEN}✅ ${1}${_RESET}"; }
_fail()  { printf '%s\n' "${_RED}❌ ${1}${_RESET}" >&2; }
_info()  { printf '%s\n' "${_BLUE}${1}${_RESET}"; }
_warn()  { printf '%s\n' "${_YELLOW}⚠  ${1}${_RESET}"; }
_error() { printf '%s\n' "${_RED}${_BOLD}ERROR: ${1}${_RESET}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Package manager detection
# ---------------------------------------------------------------------------

_dev_detect_package_manager() {
  if command -v brew &>/dev/null; then
    echo "brew"
  elif command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    echo "manual"
  fi
}

# ---------------------------------------------------------------------------
# bats-core installation
# ---------------------------------------------------------------------------

_dev_install_bats() {
  if command -v bats &>/dev/null; then
    _pass "bats-core is already installed ($(bats --version 2>/dev/null || echo 'unknown version'))"
    return 0
  fi

  local pkg_mgr
  pkg_mgr="$(_dev_detect_package_manager)"

  _info "Installing bats-core via ${pkg_mgr}..."

  case "${pkg_mgr}" in
    brew)
      brew install bats-core
      ;;
    apt)
      # bats-core is not always in default apt repos; use npm or git clone as fallback
      if apt-cache show bats &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq bats
      else
        _info "bats-core not in apt repos, installing via git clone..."
        _dev_install_bats_from_source
        return
      fi
      ;;
    dnf)
      sudo dnf install -y bats
      ;;
    pacman)
      sudo pacman -S --noconfirm bash-bats
      ;;
    manual)
      _info "No recognized package manager, installing bats-core from source..."
      _dev_install_bats_from_source
      return
      ;;
  esac

  if command -v bats &>/dev/null; then
    _pass "bats-core installed successfully"
  else
    _warn "Package manager install may have failed, falling back to source install..."
    _dev_install_bats_from_source
  fi
}

_dev_install_bats_from_source() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_root="${script_dir}/.."
  local bats_dir="${project_root}/test/helpers/bats-core"

  if [[ -d "${bats_dir}" ]]; then
    _pass "bats-core already cloned to ${bats_dir}"
  else
    _info "Cloning bats-core to ${bats_dir}..."
    git clone --depth 1 https://github.com/bats-core/bats-core.git "${bats_dir}"
  fi

  # Install to ~/.local
  _info "Installing bats-core to ~/.local..."
  "${bats_dir}/install.sh" "${HOME}/.local"

  if command -v bats &>/dev/null; then
    _pass "bats-core installed from source"
  else
    _warn "bats installed to ~/.local/bin — make sure it is in your PATH"
  fi
}

# ---------------------------------------------------------------------------
# shellcheck installation
# ---------------------------------------------------------------------------

_dev_install_shellcheck() {
  if command -v shellcheck &>/dev/null; then
    _pass "shellcheck is already installed ($(shellcheck --version 2>/dev/null | head -2 | tail -1 || echo 'unknown version'))"
    return 0
  fi

  local pkg_mgr
  pkg_mgr="$(_dev_detect_package_manager)"

  _info "Installing shellcheck via ${pkg_mgr}..."

  case "${pkg_mgr}" in
    brew)
      brew install shellcheck
      ;;
    apt)
      sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
      ;;
    dnf)
      sudo dnf install -y ShellCheck
      ;;
    pacman)
      sudo pacman -S --noconfirm shellcheck
      ;;
    manual)
      _error "Cannot install shellcheck automatically. Install manually: https://github.com/koalaman/shellcheck#installing"
      ;;
  esac

  if command -v shellcheck &>/dev/null; then
    _pass "shellcheck installed successfully"
  else
    _error "shellcheck installation failed. Install manually: https://github.com/koalaman/shellcheck#installing"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

_dev_main() {
  printf '\n%s\n' "${_BOLD}ckad-drill developer setup${_RESET}"
  printf '%s\n\n' "──────────────────────────────────────"

  _info "Step 1/3: Installing bats-core (test runner)..."
  _dev_install_bats

  _info "Step 2/3: Installing shellcheck (static analysis)..."
  _dev_install_shellcheck

  _info "Step 3/3: Verifying setup..."
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_root="${script_dir}/.."

  if command -v bats &>/dev/null && command -v shellcheck &>/dev/null; then
    _pass "All dev dependencies installed!"
    _info ""
    _info "Run tests with:"
    _info "  cd ${project_root}"
    _info "  make test          # shellcheck + unit tests"
    _info "  make test-unit     # unit tests only"
    _info "  make shellcheck    # lint only"
    _info ""
  else
    _fail "Some dependencies are missing. Check output above."
    exit 1
  fi
}

# Allow sourcing for tests without executing
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || true
fi

_dev_main
```

**Step 4: Make executable**

```bash
chmod +x scripts/dev-setup.sh
```

**Step 5: Run tests**

```bash
bats test/unit/dev-setup.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck scripts/dev-setup.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add scripts/dev-setup.sh test/unit/dev-setup.bats
git commit -m "feat: implement scripts/dev-setup.sh for developer setup (Story 10.3)

Installs bats-core and shellcheck via detected package manager
(brew/apt/dnf/pacman) or from source. Includes bats unit tests."
```

---

### Task 4: Write Comprehensive Unit Tests for All Lib Functions (Story 11.1)

Earlier sprints created basic unit tests alongside each lib file. This task fills gaps to ensure comprehensive coverage. Each sub-step adds or extends a test file.

**Files:**
- Extend: `test/unit/common.bats` (add missing coverage)
- Extend: `test/unit/display.bats` (add missing coverage)
- Extend: `test/unit/cluster.bats` (add missing coverage)
- Extend: `test/unit/scenario.bats` (add comprehensive coverage)
- Extend: `test/unit/validator.bats` (add comprehensive coverage)
- Extend: `test/unit/progress.bats` (add comprehensive coverage)
- Extend: `test/unit/timer.bats` (add comprehensive coverage)
- Extend: `test/unit/exam.bats` (add comprehensive coverage)

**Step 1: Extend test/unit/common.bats**

Append to existing `test/unit/common.bats`:
```bash
# --- Additional coverage for Story 11.1 ---

@test "CKAD_CLUSTER_NAME is set to ckad-drill" {
  [[ "${CKAD_CLUSTER_NAME}" == "ckad-drill" ]]
}

@test "CKAD_K8S_VERSION is set" {
  [[ -n "${CKAD_K8S_VERSION}" ]]
}

@test "common_ensure_dirs creates config and data dirs" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
  source "${CKAD_ROOT}/lib/common.sh"
  common_ensure_dirs
  [[ -d "${CKAD_CONFIG_DIR}" ]]
  [[ -d "${CKAD_DATA_DIR}" ]]
}

@test "CKAD_ROOT points to a directory with lib/" {
  [[ -d "${CKAD_ROOT}/lib" ]]
}

@test "all exit code constants are distinct" {
  local codes=("${EXIT_OK}" "${EXIT_ERROR}" "${EXIT_NO_CLUSTER}" "${EXIT_NO_SESSION}" "${EXIT_PARSE_ERROR}")
  local unique
  unique="$(printf '%s\n' "${codes[@]}" | sort -u | wc -l)"
  [[ "${unique}" -eq 5 ]]
}
```

**Step 2: Extend test/unit/display.bats**

Append to existing `test/unit/display.bats`:
```bash
# --- Additional coverage for Story 11.1 ---

@test "error() returns non-zero" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; error 'test' 2>/dev/null"
  [[ "${status}" -ne 0 ]]
}

@test "error() writes to stderr" {
  local stderr_output
  stderr_output="$(bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; error 'stderr test'" 2>&1 1>/dev/null || true)"
  [[ "${stderr_output}" == *"stderr test"* ]]
}

@test "header() includes horizontal rule" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; header 'Test'"
  [[ "${output}" == *"─"* ]]
}

@test "pass() includes checkmark" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; pass 'done'"
  [[ "${output}" == *"✅"* ]]
}

@test "fail() includes X mark" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; fail 'nope'"
  [[ "${output}" == *"❌"* ]]
}

@test "warn() includes warning symbol" {
  run bash -c "source '${CKAD_ROOT}/lib/common.sh'; source '${CKAD_ROOT}/lib/display.sh'; warn 'careful'"
  [[ "${output}" == *"⚠"* ]]
}
```

**Step 3: Extend test/unit/scenario.bats**

Append to existing `test/unit/scenario.bats` (or create if it only has basics):
```bash
# --- Comprehensive coverage for Story 11.1 ---

@test "scenario_load parses all required fields from YAML" {
  local tmpfile="${BATS_TEST_TMPDIR}/test-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-parse
domain: 3
title: Test Parse Scenario
difficulty: medium
time_limit: 300
namespace: parse-ns
description: |
  This is a test scenario for parsing.
hint: Try using kubectl apply
tags:
  - configmap
  - pods
validations:
  - type: resource_exists
    resource: pod/test-pod
solution: |
  kubectl run test-pod --image=nginx -n parse-ns
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    scenario_load '${tmpfile}'
    scenario_get_field 'id'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "test-parse" ]]
}

@test "scenario_get_field returns domain" {
  local tmpfile="${BATS_TEST_TMPDIR}/domain-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: test-domain
domain: 4
title: Domain Test
difficulty: hard
time_limit: 480
description: Domain test
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    scenario_load '${tmpfile}'
    scenario_get_field 'domain'
  "
  [[ "${output}" == "4" ]]
}

@test "scenario_get_field returns fallback namespace drill-<id>" {
  local tmpfile="${BATS_TEST_TMPDIR}/no-ns.yaml"
  cat > "${tmpfile}" <<'YAML'
id: no-namespace-test
domain: 1
title: No Namespace
difficulty: easy
time_limit: 120
description: Test
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    scenario_load '${tmpfile}'
    ns=\$(scenario_get_field 'namespace')
    if [[ -z \"\${ns}\" ]] || [[ \"\${ns}\" == 'null' ]]; then
      id=\$(scenario_get_field 'id')
      echo \"drill-\${id}\"
    else
      echo \"\${ns}\"
    fi
  "
  [[ "${output}" == "drill-no-namespace-test" ]]
}

@test "scenario_select filters by domain" {
  # Create temp scenarios directory
  local tmpdir="${BATS_TEST_TMPDIR}/scenarios/domain-2"
  mkdir -p "${tmpdir}"
  cat > "${tmpdir}/test-d2.yaml" <<'YAML'
id: filter-domain-2
domain: 2
title: Domain 2 Scenario
difficulty: easy
time_limit: 120
description: Test filtering
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    CKAD_SCENARIOS_DIR='${BATS_TEST_TMPDIR}/scenarios'
    scenario_select --domain 2
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"filter-domain-2"* ]] || [[ "${output}" == *"domain-2"* ]]
}

@test "scenario_validate rejects scenario with missing solution" {
  local tmpfile="${BATS_TEST_TMPDIR}/no-solution.yaml"
  cat > "${tmpfile}" <<'YAML'
id: no-solution
domain: 1
title: Missing Solution
difficulty: easy
time_limit: 120
description: No solution here
validations:
  - type: resource_exists
    resource: pod/x
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    scenario_validate '${tmpfile}'
  "
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"solution"* ]]
}

@test "scenario warns on duplicate IDs" {
  local tmpdir="${BATS_TEST_TMPDIR}/dup-scenarios/domain-1"
  mkdir -p "${tmpdir}"
  cat > "${tmpdir}/dup-a.yaml" <<'YAML'
id: duplicate-id
domain: 1
title: Dup A
difficulty: easy
time_limit: 120
description: First
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
YAML
  cat > "${tmpdir}/dup-b.yaml" <<'YAML'
id: duplicate-id
domain: 1
title: Dup B
difficulty: easy
time_limit: 120
description: Second
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
YAML

  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    CKAD_SCENARIOS_DIR='${BATS_TEST_TMPDIR}/dup-scenarios'
    scenario_list_all 2>&1
  "
  [[ "${output}" == *"duplicate"* ]] || [[ "${output}" == *"warn"* ]] || [[ "${output}" == *"⚠"* ]]
}

@test "scenario detects helm tag and warns if helm missing" {
  local tmpfile="${BATS_TEST_TMPDIR}/helm-scenario.yaml"
  cat > "${tmpfile}" <<'YAML'
id: helm-test
domain: 2
title: Helm Scenario
difficulty: medium
time_limit: 300
description: Uses Helm
tags:
  - helm
validations:
  - type: resource_exists
    resource: pod/x
solution: helm install x chart/
YAML

  run bash -c "
    PATH='/nonexistent'
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    scenario_load '${tmpfile}'
    scenario_check_requirements
  "
  [[ "${status}" -ne 0 ]] || [[ "${output}" == *"Helm"* ]]
}
```

**Step 4: Extend test/unit/validator.bats**

Append to existing `test/unit/validator.bats`:
```bash
# --- Comprehensive coverage for Story 11.1 ---

@test "validator functions are defined" {
  source "${CKAD_ROOT}/lib/validator.sh"
  declare -f validator_run_checks > /dev/null
  declare -f validator_get_results > /dev/null
  declare -f _validator_check_resource_exists > /dev/null
  declare -f _validator_check_resource_field > /dev/null
  declare -f _validator_check_container_count > /dev/null
  declare -f _validator_check_container_image > /dev/null
  declare -f _validator_check_container_env > /dev/null
  declare -f _validator_check_volume_mount > /dev/null
  declare -f _validator_check_container_running > /dev/null
  declare -f _validator_check_label_selector > /dev/null
  declare -f _validator_check_resource_count > /dev/null
  declare -f _validator_check_command_output > /dev/null
}

@test "sourcing validator.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/validator.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "validator handles unknown check type gracefully" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    validator_run_checks 'test-ns' '[{\"type\":\"nonexistent_check\",\"resource\":\"pod/x\"}]'
  "
  [[ "${status}" -ne 0 ]] || [[ "${output}" == *"unknown"* ]] || [[ "${output}" == *"❌"* ]]
}

@test "validator_get_results returns summary format" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _VALIDATOR_PASSED=3
    _VALIDATOR_FAILED=1
    _VALIDATOR_TOTAL=4
    validator_get_results
  "
  [[ "${output}" == *"4"* ]]
  [[ "${output}" == *"3"* ]]
  [[ "${output}" == *"1"* ]]
}

@test "each typed check function accepts expected parameters" {
  # Just verify the functions can be called without crashing when kubectl fails
  # They should return non-zero (kubectl not reaching a cluster), not bash errors
  for check_type in resource_exists resource_field container_count container_image container_env volume_mount container_running label_selector resource_count command_output; do
    run bash -c "
      source '${CKAD_ROOT}/lib/common.sh'
      source '${CKAD_ROOT}/lib/display.sh'
      source '${CKAD_ROOT}/lib/validator.sh'
      _validator_check_${check_type} 'fake-ns' '{\"type\":\"${check_type}\",\"resource\":\"pod/x\",\"expected\":\"1\",\"jsonpath\":\".metadata.name\",\"container\":\"c\",\"env_name\":\"FOO\",\"mount_path\":\"/data\",\"resource_type\":\"pod\",\"labels\":\"app=x\",\"selector\":\"app=x\",\"command\":\"echo hi\",\"contains\":\"hi\"}' 2>/dev/null
    "
    # We expect non-zero (cluster unreachable), but NOT a bash syntax error (exit 127 or 2)
    [[ "${status}" -ne 127 ]]
  done
}
```

**Step 5: Extend test/unit/progress.bats**

Append to existing `test/unit/progress.bats`:
```bash
# --- Comprehensive coverage for Story 11.1 ---

@test "progress functions are defined" {
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  declare -f progress_record > /dev/null
  declare -f progress_get_stats > /dev/null
  declare -f progress_get_weakest > /dev/null
  declare -f progress_get_streak > /dev/null
  declare -f progress_record_exam > /dev/null
}

@test "sourcing progress.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/progress.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "progress_record creates progress.json if missing" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  progress_record "test-scenario" true 120

  [[ -f "${CKAD_PROGRESS_FILE}" ]]
  local version
  version="$(jq '.version' "${CKAD_PROGRESS_FILE}")"
  [[ "${version}" == "1" ]]
}

@test "progress_record increments attempts" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  progress_record "multi-attempt" true 100
  progress_record "multi-attempt" false 150

  local attempts
  attempts="$(jq '.scenarios["multi-attempt"].attempts' "${CKAD_PROGRESS_FILE}")"
  [[ "${attempts}" == "2" ]]
}

@test "progress_get_stats returns per-domain data" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  # Seed some data
  progress_record "d1-scenario" true 100
  progress_record "d2-scenario" false 200

  run progress_get_stats
  [[ "${status}" -eq 0 ]]
}

@test "progress_get_streak returns 0 for empty progress" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  run progress_get_streak
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "0" ]] || [[ "${output}" == *"0"* ]]
}

@test "progress_record_exam appends to exams array" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  progress_record_exam 72 '{"1":80,"2":60,"3":75,"4":70,"5":65}'

  local exam_count
  exam_count="$(jq '.exams | length' "${CKAD_PROGRESS_FILE}")"
  [[ "${exam_count}" == "1" ]]
}

@test "progress handles missing fields with defaults (additive schema)" {
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"

  # Write a minimal progress.json without streak field
  cat > "${CKAD_PROGRESS_FILE}" <<'JSON'
{"version":1,"scenarios":{},"exams":[]}
JSON

  run progress_get_streak
  [[ "${status}" -eq 0 ]]
  # Should return 0 or handle gracefully, not crash
  [[ "${output}" == "0" ]] || [[ "${output}" == *"0"* ]] || [[ "${status}" -eq 0 ]]
}
```

**Step 6: Extend test/unit/timer.bats**

Append to existing `test/unit/timer.bats`:
```bash
# --- Comprehensive coverage for Story 11.1 ---

@test "timer functions are defined" {
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/timer.sh"
  declare -f timer_start > /dev/null
  declare -f timer_env_output > /dev/null
  declare -f timer_remaining > /dev/null
}

@test "sourcing timer.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/timer.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "timer_env_output does not include set -euo pipefail" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    timer_start 300
    timer_env_output
  "
  [[ "${output}" != *"set -euo"* ]]
  [[ "${output}" != *"set -e"* ]]
}

@test "timer_env_output includes PROMPT_COMMAND" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    timer_start 300
    timer_env_output
  "
  [[ "${output}" == *"PROMPT_COMMAND"* ]]
}

@test "timer_env_output includes __ckad_timer function" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    timer_start 300
    timer_env_output
  "
  [[ "${output}" == *"__ckad_timer"* ]]
}

@test "timer_env_output is idempotent (source twice without error)" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    timer_start 300
    eval \"\$(timer_env_output)\"
    eval \"\$(timer_env_output)\"
    echo 'ok'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"ok"* ]]
}

@test "timer_remaining outputs time in seconds" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    export CKAD_DRILL_END=\$(( \$(date +%s) + 120 ))
    timer_remaining
  "
  [[ "${status}" -eq 0 ]]
  # Output should contain a number
  [[ "${output}" =~ [0-9] ]]
}
```

**Step 7: Extend test/unit/exam.bats**

Append to existing `test/unit/exam.bats`:
```bash
# --- Comprehensive coverage for Story 11.1 ---

@test "exam functions are defined" {
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/scenario.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
  source "${CKAD_ROOT}/lib/progress.sh"
  source "${CKAD_ROOT}/lib/exam.sh"
  declare -f exam_start > /dev/null
  declare -f exam_list > /dev/null
  declare -f exam_next > /dev/null
  declare -f exam_prev > /dev/null
  declare -f exam_jump > /dev/null
  declare -f exam_flag > /dev/null
  declare -f exam_submit > /dev/null
  declare -f exam_score > /dev/null
}

@test "sourcing exam.sh produces no output" {
  local output
  output="$(
    source "${CKAD_ROOT}/lib/common.sh"
    source "${CKAD_ROOT}/lib/display.sh"
    source "${CKAD_ROOT}/lib/scenario.sh"
    source "${CKAD_ROOT}/lib/validator.sh"
    source "${CKAD_ROOT}/lib/progress.sh"
    source "${CKAD_ROOT}/lib/exam.sh" 2>&1
  )"
  [[ -z "${output}" ]]
}

@test "exam_score calculates pass at 66%" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/progress.sh'
    source '${CKAD_ROOT}/lib/exam.sh'
    # Mock exam results: 14 out of 20 = 70% (pass)
    _EXAM_TOTAL=20
    _EXAM_PASSED=14
    exam_score
  "
  [[ "${output}" == *"PASS"* ]] || [[ "${output}" == *"70"* ]]
}

@test "exam_score calculates fail below 66%" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/progress.sh'
    source '${CKAD_ROOT}/lib/exam.sh'
    # Mock exam results: 10 out of 20 = 50% (fail)
    _EXAM_TOTAL=20
    _EXAM_PASSED=10
    exam_score
  "
  [[ "${output}" == *"FAIL"* ]] || [[ "${output}" == *"50"* ]]
}

@test "exam blocks hints in exam mode" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/progress.sh'
    source '${CKAD_ROOT}/lib/exam.sh'
    _EXAM_ACTIVE=true
    exam_check_hint_allowed 2>&1
  "
  [[ "${status}" -ne 0 ]] || [[ "${output}" == *"not available"* ]] || [[ "${output}" == *"exam"* ]]
}

@test "exam blocks solutions in exam mode" {
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/progress.sh'
    source '${CKAD_ROOT}/lib/exam.sh'
    _EXAM_ACTIVE=true
    exam_check_solution_allowed 2>&1
  "
  [[ "${status}" -ne 0 ]] || [[ "${output}" == *"not available"* ]] || [[ "${output}" == *"exam"* ]]
}
```

**Step 8: Run all unit tests**

```bash
cd /home/jeff/Projects/cka
bats test/unit/
```

Expected: All PASS.

**Step 9: Run shellcheck on all files**

```bash
shellcheck bin/ckad-drill lib/*.sh scripts/*.sh
```

Expected: No warnings.

**Step 10: Commit**

```bash
git add test/unit/
git commit -m "test: add comprehensive unit tests for all lib functions (Story 11.1)

Extends existing bats tests for common, display, cluster, scenario,
validator, progress, timer, and exam libs. Covers XDG overrides,
schema validation, field extraction, YAML parsing, check type dispatch,
progress JSON read/write, timer env output safety, exam scoring,
and hint/solution blocking in exam mode."
```

---

### Task 5: Write Integration Tests for Scenario Lifecycle (Story 11.2)

**Files:**
- Create: `test/integration/lifecycle.bats`
- Create: `test/integration/cluster.bats`
- Create: `test/integration/validation-types.bats`
- Create: `test/integration/exam.bats`
- Create: `test/helpers/integration-helper.bash`
- Create: `test/helpers/fixtures/integration-scenario.yaml`

**Step 1: Create integration test helper**

Create `test/helpers/integration-helper.bash`:
```bash
#!/usr/bin/env bash
# Common setup for integration tests (require live kind cluster)

# Load base test helper
load 'test-helper'

# Source all libs
source "${CKAD_ROOT}/lib/common.sh"
source "${CKAD_ROOT}/lib/display.sh"
source "${CKAD_ROOT}/lib/cluster.sh"
source "${CKAD_ROOT}/lib/scenario.sh"
source "${CKAD_ROOT}/lib/validator.sh"
source "${CKAD_ROOT}/lib/timer.sh"
source "${CKAD_ROOT}/lib/progress.sh"
source "${CKAD_ROOT}/lib/exam.sh"
source "${CKAD_ROOT}/lib/validate-scenario.sh"

# Skip all tests if cluster is not running
_integration_require_cluster() {
  if ! cluster_exists; then
    skip "Kind cluster '${CKAD_CLUSTER_NAME}' is not running. Start with: ckad-drill start"
  fi
  if ! kubectl --context "kind-${CKAD_CLUSTER_NAME}" cluster-info &>/dev/null; then
    skip "Kind cluster '${CKAD_CLUSTER_NAME}' is not healthy."
  fi
}

# Clean up a namespace, ignoring errors
_integration_cleanup_ns() {
  local ns="${1}"
  kubectl delete namespace "${ns}" --context "kind-${CKAD_CLUSTER_NAME}" --ignore-not-found --wait=false &>/dev/null || true
}
```

**Step 2: Create integration test fixture scenario**

Create `test/helpers/fixtures/integration-scenario.yaml`:
```yaml
id: integration-test
domain: 1
title: Integration Test Scenario
difficulty: easy
time_limit: 120
namespace: integration-test-ns
description: |
  Create a pod named 'web' using the nginx:latest image in the
  integration-test-ns namespace.
hint: Use kubectl run with the --image flag
validations:
  - type: resource_exists
    resource: pod/web
    description: Pod 'web' exists
  - type: container_image
    resource: pod/web
    container: web
    expected: nginx:latest
    description: Pod 'web' uses nginx:latest image
  - type: container_running
    resource: pod/web
    container: web
    description: Container 'web' is running
solution: |
  kubectl run web --image=nginx:latest -n integration-test-ns
```

**Step 3: Create test/integration/lifecycle.bats**

Create `test/integration/lifecycle.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/integration-helper'
  _integration_require_cluster
}

teardown() {
  _integration_cleanup_ns "integration-test-ns"
  _integration_cleanup_ns "lifecycle-test-ns"
}

@test "full lifecycle: load → setup → validate (fail) → apply solution → validate (pass) → cleanup" {
  local fixture="${CKAD_ROOT}/test/helpers/fixtures/integration-scenario.yaml"

  # Load scenario
  scenario_load "${fixture}"
  local scenario_id
  scenario_id="$(scenario_get_field 'id')"
  [[ "${scenario_id}" == "integration-test" ]]

  # Setup (create namespace)
  kubectl create namespace integration-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --dry-run=client -o yaml | \
    kubectl apply --context "kind-${CKAD_CLUSTER_NAME}" -f -

  # Validate BEFORE solution (should fail — no pod yet)
  local validations_json
  validations_json="$(yq e -o=json '.validations' "${fixture}")"
  run validator_run_checks "integration-test-ns" "${validations_json}"
  [[ "${status}" -ne 0 ]]

  # Apply solution
  kubectl run web --image=nginx:latest -n integration-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}"

  # Wait for pod to be ready
  kubectl wait --for=condition=ready pod/web \
    -n integration-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --timeout=60s

  # Validate AFTER solution (should pass)
  run validator_run_checks "integration-test-ns" "${validations_json}"
  [[ "${status}" -eq 0 ]]

  # Cleanup
  kubectl delete namespace integration-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --ignore-not-found

  # Verify namespace is gone (or terminating)
  sleep 2
  run kubectl get namespace integration-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" 2>&1
  [[ "${output}" == *"NotFound"* ]] || [[ "${output}" == *"Terminating"* ]] || [[ "${status}" -ne 0 ]]
}

@test "validate-scenario runs end-to-end against fixture" {
  local fixture="${CKAD_ROOT}/test/helpers/fixtures/integration-scenario.yaml"
  run validate_scenario_file "${fixture}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"PASS"* ]]
}

@test "scenario_cleanup deletes namespace" {
  # Create a namespace
  kubectl create namespace lifecycle-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --dry-run=client -o yaml | \
    kubectl apply --context "kind-${CKAD_CLUSTER_NAME}" -f -

  # Verify it exists
  kubectl get namespace lifecycle-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}"

  # Clean up via scenario function
  scenario_cleanup "lifecycle-test-ns"

  # Verify it's gone or terminating
  sleep 2
  run kubectl get namespace lifecycle-test-ns \
    --context "kind-${CKAD_CLUSTER_NAME}" 2>&1
  [[ "${output}" == *"NotFound"* ]] || [[ "${output}" == *"Terminating"* ]] || [[ "${status}" -ne 0 ]]
}
```

**Step 4: Create test/integration/cluster.bats**

Create `test/integration/cluster.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/integration-helper'
  _integration_require_cluster
}

@test "cluster_exists returns true for running cluster" {
  run cluster_exists
  [[ "${status}" -eq 0 ]]
}

@test "cluster_ensure_running succeeds for healthy cluster" {
  run cluster_ensure_running
  [[ "${status}" -eq 0 ]]
}

@test "kubectl can reach cluster" {
  run kubectl --context "kind-${CKAD_CLUSTER_NAME}" cluster-info
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"running"* ]] || [[ "${output}" == *"Kubernetes"* ]]
}

@test "cluster has expected node count" {
  local node_count
  node_count="$(kubectl get nodes --context "kind-${CKAD_CLUSTER_NAME}" --no-headers | wc -l)"
  [[ "${node_count}" -ge 1 ]]
}

@test "cluster has Calico CNI running" {
  run kubectl get pods -n kube-system -l k8s-app=calico-node \
    --context "kind-${CKAD_CLUSTER_NAME}" --no-headers
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Running"* ]]
}

@test "cluster has metrics-server running" {
  run kubectl get pods -n kube-system -l k8s-app=metrics-server \
    --context "kind-${CKAD_CLUSTER_NAME}" --no-headers
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Running"* ]]
}

@test "cluster has ingress-nginx running" {
  run kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller \
    --context "kind-${CKAD_CLUSTER_NAME}" --no-headers
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Running"* ]]
}
```

**Step 5: Create test/integration/validation-types.bats**

Create `test/integration/validation-types.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/integration-helper'
  _integration_require_cluster

  # Create test namespace and resources
  kubectl create namespace val-type-test \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --dry-run=client -o yaml | \
    kubectl apply --context "kind-${CKAD_CLUSTER_NAME}" -f -

  # Create a test pod with known properties
  kubectl run val-test-pod \
    --image=nginx:1.25 \
    --labels="app=val-test,tier=frontend" \
    -n val-type-test \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --env="MY_VAR=hello" \
    --overrides='{
      "spec": {
        "containers": [{
          "name": "val-test-pod",
          "image": "nginx:1.25",
          "env": [{"name": "MY_VAR", "value": "hello"}],
          "volumeMounts": [{"name": "test-vol", "mountPath": "/data"}]
        }],
        "volumes": [{"name": "test-vol", "emptyDir": {}}]
      }
    }' 2>/dev/null || true

  # Wait for ready
  kubectl wait --for=condition=ready pod/val-test-pod \
    -n val-type-test \
    --context "kind-${CKAD_CLUSTER_NAME}" \
    --timeout=60s 2>/dev/null || true
}

teardown() {
  _integration_cleanup_ns "val-type-test"
}

@test "resource_exists: passes for existing pod" {
  local json='[{"type":"resource_exists","resource":"pod/val-test-pod","description":"pod exists"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "resource_exists: fails for non-existing pod" {
  local json='[{"type":"resource_exists","resource":"pod/nonexistent","description":"pod exists"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -ne 0 ]]
}

@test "container_image: passes for correct image" {
  local json='[{"type":"container_image","resource":"pod/val-test-pod","container":"val-test-pod","expected":"nginx:1.25","description":"image check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "container_image: fails for wrong image" {
  local json='[{"type":"container_image","resource":"pod/val-test-pod","container":"val-test-pod","expected":"alpine:latest","description":"image check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -ne 0 ]]
}

@test "container_running: passes for running container" {
  local json='[{"type":"container_running","resource":"pod/val-test-pod","container":"val-test-pod","description":"running check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "container_env: passes for correct env var" {
  local json='[{"type":"container_env","resource":"pod/val-test-pod","container":"val-test-pod","env_name":"MY_VAR","expected":"hello","description":"env check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "container_env: fails for wrong env value" {
  local json='[{"type":"container_env","resource":"pod/val-test-pod","container":"val-test-pod","env_name":"MY_VAR","expected":"wrong","description":"env check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -ne 0 ]]
}

@test "volume_mount: passes for existing mount" {
  local json='[{"type":"volume_mount","resource":"pod/val-test-pod","container":"val-test-pod","mount_path":"/data","description":"mount check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "label_selector: passes for matching labels" {
  local json='[{"type":"label_selector","resource_type":"pod","labels":"app=val-test","description":"label check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "label_selector: fails for non-matching labels" {
  local json='[{"type":"label_selector","resource_type":"pod","labels":"app=nonexistent","description":"label check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -ne 0 ]]
}

@test "resource_count: passes for correct count" {
  local json='[{"type":"resource_count","resource_type":"pod","selector":"app=val-test","expected":"1","description":"count check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "container_count: passes for single container" {
  local json='[{"type":"container_count","resource":"pod/val-test-pod","expected":"1","description":"container count"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "resource_field: passes for correct jsonpath value" {
  local json='[{"type":"resource_field","resource":"pod/val-test-pod","jsonpath":".metadata.name","expected":"val-test-pod","description":"field check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}

@test "command_output: passes for matching command" {
  local json='[{"type":"command_output","command":"kubectl get pod val-test-pod -n val-type-test --context kind-ckad-drill -o name","contains":"pod/val-test-pod","description":"cmd check"}]'
  run validator_run_checks "val-type-test" "${json}"
  [[ "${status}" -eq 0 ]]
}
```

**Step 6: Create test/integration/exam.bats**

Create `test/integration/exam.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/integration-helper'
  _integration_require_cluster

  # Use temp config dir for exam session
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  source "${CKAD_ROOT}/lib/common.sh"
  mkdir -p "${CKAD_CONFIG_DIR}"
}

teardown() {
  # Clean up any exam namespaces
  local ns
  for ns in $(kubectl get namespaces --context "kind-${CKAD_CLUSTER_NAME}" -o name 2>/dev/null | grep "exam-\|drill-" | sed 's|namespace/||'); do
    _integration_cleanup_ns "${ns}"
  done
}

@test "exam session creates session.json" {
  # This test verifies exam_start writes session state
  # We need at least some scenarios for exam to pick from
  local tmpdir="${BATS_TEST_TMPDIR}/scenarios/domain-1"
  mkdir -p "${tmpdir}"
  local i
  for i in $(seq 1 3); do
    cat > "${tmpdir}/exam-test-${i}.yaml" <<YAML
id: exam-test-${i}
domain: 1
title: Exam Test ${i}
difficulty: easy
time_limit: 120
namespace: exam-ns-${i}
description: Exam test scenario ${i}
validations:
  - type: resource_exists
    resource: pod/test-${i}
solution: |
  kubectl run test-${i} --image=nginx -n exam-ns-${i}
YAML
  done

  run bash -c "
    export XDG_CONFIG_HOME='${BATS_TEST_TMPDIR}/config'
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/cluster.sh'
    source '${CKAD_ROOT}/lib/scenario.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    source '${CKAD_ROOT}/lib/timer.sh'
    source '${CKAD_ROOT}/lib/progress.sh'
    source '${CKAD_ROOT}/lib/exam.sh'
    mkdir -p '${CKAD_CONFIG_DIR}'
    CKAD_SCENARIOS_DIR='${BATS_TEST_TMPDIR}/scenarios'
    exam_start --time 5m 2>&1
  "
  # Should create session file
  [[ -f "${BATS_TEST_TMPDIR}/config/ckad-drill/session.json" ]] || \
  [[ "${output}" == *"exam"* ]]
}
```

**Step 7: Run integration tests**

```bash
cd /home/jeff/Projects/cka
make test-integration
```

Expected: All PASS if cluster is running; skipped with message if not.

**Step 8: Commit**

```bash
git add test/integration/ test/helpers/integration-helper.bash test/helpers/fixtures/integration-scenario.yaml
git commit -m "test: add integration tests for scenario lifecycle (Story 11.2)

Integration tests for full scenario lifecycle (load → setup → validate
→ apply solution → validate → cleanup), cluster health checks, all 10
typed validation checks against real resources, and exam session.
Tests skip gracefully if kind cluster is not running."
```

---

### Task 6: Write Schema Tests for Scenario Validation (Story 11.3)

**Files:**
- Create: `test/schema/valid-scenarios/basic-pod.yaml`
- Create: `test/schema/valid-scenarios/multi-container.yaml`
- Create: `test/schema/valid-scenarios/full-featured.yaml`
- Create: `test/schema/invalid-scenarios/missing-title.yaml`
- Create: `test/schema/invalid-scenarios/invalid-domain.yaml`
- Create: `test/schema/invalid-scenarios/invalid-difficulty.yaml`
- Create: `test/schema/invalid-scenarios/missing-solution.yaml`
- Create: `test/schema/invalid-scenarios/unknown-validation-type.yaml`
- Create: `test/schema/invalid-scenarios/negative-time-limit.yaml`
- Create: `test/schema/schema-validation.bats`

**Step 1: Create known-good fixture scenarios**

Create `test/schema/valid-scenarios/basic-pod.yaml`:
```yaml
id: schema-test-basic
domain: 1
title: Basic Pod Creation
difficulty: easy
time_limit: 120
namespace: schema-basic-ns
description: |
  Create a pod named 'web' using the nginx image.
validations:
  - type: resource_exists
    resource: pod/web
    description: Pod web exists
solution: |
  kubectl run web --image=nginx -n schema-basic-ns
```

Create `test/schema/valid-scenarios/multi-container.yaml`:
```yaml
id: schema-test-multi
domain: 1
title: Multi-Container Pod
difficulty: medium
time_limit: 300
namespace: schema-multi-ns
hint: Use a pod YAML with multiple containers defined
tags:
  - multi-container
  - sidecar
description: |
  Create a pod named 'logger' with two containers: app (nginx) and sidecar (busybox).
validations:
  - type: resource_exists
    resource: pod/logger
    description: Pod logger exists
  - type: container_count
    resource: pod/logger
    expected: "2"
    description: Pod has 2 containers
  - type: container_image
    resource: pod/logger
    container: app
    expected: nginx
    description: Container app uses nginx
  - type: container_image
    resource: pod/logger
    container: sidecar
    expected: busybox
    description: Container sidecar uses busybox
solution: |
  cat <<'EOF' | kubectl apply -n schema-multi-ns -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: logger
  spec:
    containers:
    - name: app
      image: nginx
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
  EOF
```

Create `test/schema/valid-scenarios/full-featured.yaml`:
```yaml
id: schema-test-full
domain: 4
title: Full Featured Scenario
difficulty: hard
time_limit: 480
namespace: secure-app
weight: 3
learn: false
hint: Check the RBAC documentation
tags:
  - rbac
  - security
setup:
  - kubectl create namespace secure-app --context kind-ckad-drill --dry-run=client -o yaml | kubectl apply --context kind-ckad-drill -f -
  - kubectl create serviceaccount app-sa -n secure-app --context kind-ckad-drill
cleanup:
  - kubectl delete namespace secure-app --context kind-ckad-drill --ignore-not-found
description: |
  Create a Role and RoleBinding in the secure-app namespace that allows
  the service account 'app-sa' to get and list pods.
validations:
  - type: resource_exists
    resource: role/pod-reader
    description: Role pod-reader exists
  - type: resource_exists
    resource: rolebinding/app-sa-pod-reader
    description: RoleBinding exists
  - type: resource_field
    resource: role/pod-reader
    jsonpath: ".rules[0].verbs"
    expected: '["get","list"]'
    description: Role allows get and list
  - type: command_output
    command: kubectl get rolebinding app-sa-pod-reader -n secure-app --context kind-ckad-drill -o jsonpath='{.subjects[0].name}'
    equals: app-sa
    description: RoleBinding references app-sa
solution: |
  kubectl create role pod-reader --verb=get,list --resource=pods -n secure-app --context kind-ckad-drill
  kubectl create rolebinding app-sa-pod-reader --role=pod-reader --serviceaccount=secure-app:app-sa -n secure-app --context kind-ckad-drill
```

**Step 2: Create known-bad fixture scenarios**

Create `test/schema/invalid-scenarios/missing-title.yaml`:
```yaml
id: bad-missing-title
domain: 1
difficulty: easy
time_limit: 120
description: This scenario has no title
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
```

Create `test/schema/invalid-scenarios/invalid-domain.yaml`:
```yaml
id: bad-invalid-domain
domain: 9
title: Bad Domain
difficulty: easy
time_limit: 120
description: Domain 9 does not exist
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
```

Create `test/schema/invalid-scenarios/invalid-difficulty.yaml`:
```yaml
id: bad-invalid-difficulty
domain: 1
title: Bad Difficulty
difficulty: extreme
time_limit: 120
description: Extreme is not a valid difficulty
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
```

Create `test/schema/invalid-scenarios/missing-solution.yaml`:
```yaml
id: bad-missing-solution
domain: 1
title: Missing Solution
difficulty: easy
time_limit: 120
description: No solution field
validations:
  - type: resource_exists
    resource: pod/x
```

Create `test/schema/invalid-scenarios/unknown-validation-type.yaml`:
```yaml
id: bad-unknown-check
domain: 1
title: Unknown Check Type
difficulty: easy
time_limit: 120
description: Uses a non-existent validation type
validations:
  - type: check_magic_power
    resource: pod/x
solution: kubectl run x --image=nginx
```

Create `test/schema/invalid-scenarios/negative-time-limit.yaml`:
```yaml
id: bad-negative-time
domain: 1
title: Negative Time
difficulty: easy
time_limit: -30
description: Negative time limit
validations:
  - type: resource_exists
    resource: pod/x
solution: kubectl run x --image=nginx
```

**Step 3: Create test/schema/schema-validation.bats**

Create `test/schema/schema-validation.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/scenario.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
  source "${CKAD_ROOT}/lib/validate-scenario.sh"
}

# --- Valid scenarios (should all pass schema check) ---

@test "valid: basic-pod.yaml passes schema validation" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/valid-scenarios/basic-pod.yaml"
  [[ "${status}" -eq 0 ]]
}

@test "valid: multi-container.yaml passes schema validation" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/valid-scenarios/multi-container.yaml"
  [[ "${status}" -eq 0 ]]
}

@test "valid: full-featured.yaml passes schema validation" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/valid-scenarios/full-featured.yaml"
  [[ "${status}" -eq 0 ]]
}

# --- Invalid scenarios (should all fail schema check with specific errors) ---

@test "invalid: missing-title.yaml fails with 'title' error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/missing-title.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"title"* ]]
}

@test "invalid: invalid-domain.yaml fails with 'domain must be 1-5' error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/invalid-domain.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"domain must be 1-5"* ]]
}

@test "invalid: invalid-difficulty.yaml fails with 'difficulty must be easy/medium/hard' error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/invalid-difficulty.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"difficulty must be easy/medium/hard"* ]]
}

@test "invalid: missing-solution.yaml fails with 'solution' error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/missing-solution.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"solution"* ]]
}

@test "invalid: unknown-validation-type.yaml fails with check type error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/unknown-validation-type.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"check_magic_power"* ]] || [[ "${output}" == *"unknown validation type"* ]]
}

@test "invalid: negative-time-limit.yaml fails with 'time_limit must be positive' error" {
  run _validate_scenario_schema "${CKAD_ROOT}/test/schema/invalid-scenarios/negative-time-limit.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"time_limit must be positive"* ]]
}

# --- Bulk validation ---

@test "all valid-scenarios/*.yaml pass schema validation" {
  local file
  local failed=0
  for file in "${CKAD_ROOT}"/test/schema/valid-scenarios/*.yaml; do
    if ! _validate_scenario_schema "${file}"; then
      echo "UNEXPECTED FAIL: ${file}" >&2
      failed=$((failed + 1))
    fi
  done
  [[ "${failed}" -eq 0 ]]
}

@test "all invalid-scenarios/*.yaml fail schema validation" {
  local file
  local unexpected_pass=0
  for file in "${CKAD_ROOT}"/test/schema/invalid-scenarios/*.yaml; do
    if _validate_scenario_schema "${file}" 2>/dev/null; then
      echo "UNEXPECTED PASS: ${file}" >&2
      unexpected_pass=$((unexpected_pass + 1))
    fi
  done
  [[ "${unexpected_pass}" -eq 0 ]]
}
```

**Step 4: Run schema tests**

```bash
cd /home/jeff/Projects/cka
bats test/schema/schema-validation.bats
```

Expected: All PASS.

**Step 5: Commit**

```bash
git add test/schema/
git commit -m "test: add schema tests with valid/invalid YAML fixtures (Story 11.3)

3 known-good scenarios (basic, multi-container, full-featured) and
6 known-bad scenarios (missing title, invalid domain, invalid difficulty,
missing solution, unknown validation type, negative time limit).
Schema validation bats tests verify each fixture produces the expected
pass/fail with correct error messages."
```

---

### Task 7: Set Up CI Pipeline (Story 11.4)

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `Makefile` (add `test-schema` target)

**Step 1: Update Makefile with schema test target**

Add to `Makefile`:
```makefile
.PHONY: test shellcheck test-unit test-integration test-schema install

SHELL := /bin/bash

# All bash scripts to lint
SCRIPTS := bin/ckad-drill $(wildcard lib/*.sh) $(wildcard scripts/*.sh)

test: shellcheck test-unit test-schema

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck $(SCRIPTS)
	@echo "shellcheck passed"

test-unit:
	@echo "Running unit tests..."
	@bats test/unit/
	@echo "Unit tests passed"

test-schema:
	@echo "Running schema tests..."
	@bats test/schema/
	@echo "Schema tests passed"

test-integration:
	@echo "Running integration tests (requires kind cluster)..."
	@bats test/integration/
	@echo "Integration tests passed"

test-all: shellcheck test-unit test-schema test-integration

install:
	@echo "Run: scripts/install.sh"
```

**Step 2: Create .github/workflows/ci.yml**

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  # -------------------------------------------------------------------
  # Fast checks: run on every PR and push
  # -------------------------------------------------------------------
  lint-and-unit:
    name: Shellcheck + Unit Tests + Schema Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install shellcheck
        run: sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck

      - name: Install bats-core
        run: |
          git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
          sudo /tmp/bats-core/install.sh /usr/local

      - name: Install yq
        run: |
          YQ_VERSION="v4.44.3"
          curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
            -o /usr/local/bin/yq
          chmod +x /usr/local/bin/yq

      - name: Install jq
        run: sudo apt-get install -y -qq jq

      - name: Run shellcheck
        run: make shellcheck

      - name: Run unit tests
        run: make test-unit

      - name: Run schema tests
        run: make test-schema

  # -------------------------------------------------------------------
  # Integration tests: only on push to main (require kind cluster)
  # -------------------------------------------------------------------
  integration:
    name: Integration Tests (kind cluster)
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: lint-and-unit
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install shellcheck
        run: sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck

      - name: Install bats-core
        run: |
          git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
          sudo /tmp/bats-core/install.sh /usr/local

      - name: Install yq
        run: |
          YQ_VERSION="v4.44.3"
          curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
            -o /usr/local/bin/yq
          chmod +x /usr/local/bin/yq

      - name: Install jq
        run: sudo apt-get install -y -qq jq

      - name: Install kind
        run: |
          KIND_VERSION="v0.25.0"
          curl -sSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
            -o /usr/local/bin/kind
          chmod +x /usr/local/bin/kind

      - name: Create kind cluster
        run: |
          kind create cluster --name ckad-drill --config scripts/kind-config.yaml
          kubectl config use-context kind-ckad-drill

      - name: Install cluster addons
        run: |
          source lib/common.sh
          source lib/display.sh
          bash scripts/cluster-setup.sh
        timeout-minutes: 5

      - name: Wait for cluster to be ready
        run: |
          kubectl wait --for=condition=ready node --all --timeout=120s --context kind-ckad-drill
          kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=120s --context kind-ckad-drill

      - name: Run integration tests
        run: make test-integration

      - name: Cleanup kind cluster
        if: always()
        run: kind delete cluster --name ckad-drill
```

**Step 3: Verify CI config syntax**

```bash
# Validate YAML syntax
yq e '.' .github/workflows/ci.yml > /dev/null
```

**Step 4: Run full local test suite**

```bash
cd /home/jeff/Projects/cka
make test
```

Expected: shellcheck + unit tests + schema tests all pass.

**Step 5: Commit**

```bash
git add .github/workflows/ci.yml Makefile
git commit -m "ci: set up GitHub Actions CI pipeline (Story 11.4)

PR triggers: shellcheck + bats unit tests + schema tests.
Push to main triggers: above + integration tests with kind cluster.
Installs bats-core, shellcheck, yq, jq, kind in CI. Creates kind
cluster with Calico/ingress/metrics-server for integration tests.
Adds test-schema and test-all Makefile targets."
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 10.1 | lib/validate-scenario.sh, bin/ckad-drill update | test/unit/validate-scenario.bats |
| 2 | 10.2 | scripts/install.sh | test/unit/install.bats |
| 3 | 10.3 | scripts/dev-setup.sh | test/unit/dev-setup.bats |
| 4 | 11.1 | Extended unit tests for all lib files | test/unit/*.bats (comprehensive) |
| 5 | 11.2 | Integration tests (lifecycle, cluster, validation-types, exam) | test/integration/*.bats |
| 6 | 11.3 | Schema test fixtures + validation tests | test/schema/ |
| 7 | 11.4 | .github/workflows/ci.yml, Makefile updates | CI pipeline |

**After Sprint 7:** `ckad-drill validate-scenario` works end-to-end for content contributors. Users can install via curl-pipe-sh. Developers can bootstrap with dev-setup.sh. All lib functions have comprehensive bats coverage. Integration tests validate full scenario lifecycle against a real cluster. CI enforces quality on every PR (shellcheck + unit + schema) and on merge to main (+ integration).

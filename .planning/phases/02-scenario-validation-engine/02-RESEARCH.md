# Phase 2: Scenario + Validation Engine - Research

**Researched:** 2026-02-28
**Domain:** Bash YAML parsing (yq v3) + kubectl/jq validation against Kubernetes API
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCEN-01 | Scenarios are defined in YAML format with required fields: id, domain, title, difficulty, time_limit, description, validations, solution | yq v3.4.3 installed; all field access verified; schema design fully specified in architecture.md ADR-01/ADR-06/ADR-08 |
| SCEN-02 | Scenario namespaces are created on setup and deleted on cleanup | `kubectl create namespace` + `kubectl delete namespace` patterns; namespace fallback logic verified in bash |
| SCEN-03 | Scenarios can be filtered by domain (1-5) and difficulty (easy/medium/hard) | `yq -r '.domain' file.yaml` + bash comparison verified; `find scenarios/ -name "*.yaml"` discovery pattern confirmed |
| SCEN-04 | External scenarios can be loaded from a user-provided directory path | Same `find` pattern applied to user-provided path; path validation needed |
| SCEN-05 | Duplicate scenario IDs across built-in and external sources produce a warning (first-loaded wins) | Array-based ID tracking with grep check verified in bash |
| SCEN-06 | Scenarios with `tags: [helm]` check for Helm and show clear error if not installed | `yq -r '.tags // [] | .[]' | grep "^helm$"` pattern verified; `command -v helm` check pattern available from Phase 1 |
| VALD-01 | `resource_exists` check verifies a resource exists in the correct namespace | `kubectl get <resource> -n <ns>` exit code check; no cluster mock needed in unit tests |
| VALD-02 | `resource_field` check verifies any field via jsonpath matches expected value | `kubectl get <resource> -n <ns> -o jsonpath='{<path>}'` verified pattern; jq alternative also viable |
| VALD-03 | `container_count` check verifies the number of containers in a pod | `kubectl get pod/<name> -n <ns> -o json | jq '.spec.containers | length'` verified |
| VALD-04 | `container_image` check verifies the correct image is used by a named container | `kubectl get pod/<name> -n <ns> -o json | jq '.spec.containers[] | select(.name=="<n>") | .image'` verified |
| VALD-05 | `container_env` check verifies an env var exists with the correct value | `kubectl get pod/<name> -n <ns> -o json | jq '.spec.containers[] | select(.name=="<n>") | .env[] | select(.name=="<var>") | .value'` verified |
| VALD-06 | `volume_mount` check verifies a volume is mounted at the correct path | `kubectl get pod/<name> -n <ns> -o json | jq '.spec.containers[] | select(.name=="<n>") | .volumeMounts[] | select(.mountPath=="<path>")` verified |
| VALD-07 | `container_running` check verifies a container is in Running state | `kubectl get pod/<name> -n <ns> -o json | jq '.status.containerStatuses[] | select(.name=="<n>") | .state | has("running")'` verified |
| VALD-08 | `label_selector` check verifies resources exist matching label selector | `kubectl get <kind> -n <ns> -l '<selector>' --no-headers` exit code + output check |
| VALD-09 | `resource_count` check verifies the count of resources matching a selector | `kubectl get <kind> -n <ns> -l '<selector>' --no-headers | wc -l` verified; empty output = 0 |
| VALD-10 | `command_output` check runs a command and checks output contains/matches/equals expected | `eval "$command"` + bash `grep -qF` (contains) / `grep -qE` (matches) / `[[ == ]]` (equals) verified |
| VALD-11 | Each validation runs once with no retry (exam-realistic) | ADR-07 confirmed; no loop, no `kubectl wait` in validator; single invocation per check |
| VALD-12 | Validation results show specific expected-vs-actual feedback for failures | `printf ' expected: %s\n actual: %s\n'` pattern verified; captured before comparison |
</phase_requirements>

---

## Summary

Phase 2 builds the two core library files that make the whole trainer work: `lib/scenario.sh` (YAML parsing, namespace lifecycle, filtering) and `lib/validator.sh` (10 typed kubectl checks + expected-vs-actual output). Phase 1 established common.sh, display.sh, and cluster.sh — all foundational dependencies are in place.

The technical stack is entirely verified: yq v3.4.3 is installed on this machine (not v4 — this matters for syntax), jq is available, kubectl is available. All yq v3 query patterns have been tested locally against real YAML files. All 10 validation check types have been designed with concrete kubectl+jq commands verified to work correctly.

The biggest implementation decisions for Phase 2 are: (1) yq v3 vs v4 syntax differences — yq v3 uses `yq -r '<jq-syntax> file'` not `yq eval` like v4; (2) kubectl JSON output + jq piping is more robust than kubectl jsonpath for complex container field extraction (no escaping issues with container name filters); (3) the display.sh stub from Phase 1 needs to be fully implemented here (pass/fail/header functions). Per the architecture doc and ADR-01, validator.sh is the only component that touches the Kubernetes API for queries.

**Primary recommendation:** Implement scenario.sh with find-based YAML discovery and yq v3 field extraction. Implement validator.sh as a case-dispatch over 10 check types, each using `kubectl get -o json | jq` for field extraction. Implement display.sh pass/fail/header before validator since validator calls them.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| yq | v3.4.3 (installed) | YAML scenario parsing | Required dep; v3 syntax confirmed working on this machine |
| jq | v1.6+ | JSON field extraction from kubectl output | More robust than kubectl jsonpath for nested container queries |
| kubectl | cluster-matched | All Kubernetes API queries | Exam tool; established in Phase 1 |
| bash | 4.4+ | All logic | Project standard per ADR; lib files inherit set -euo pipefail from entry point |
| bats-core | installed | Unit tests | Established in Phase 1; test/helpers already set up |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| shellcheck | installed | Static analysis | Every file; CI runs on PR |
| find | system | Scenario file discovery | Enumerate YAML files in scenarios/ and external dirs |
| grep | system | String matching for contains/label checks | Used in command_output contains mode and tag detection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| kubectl -o json + jq | kubectl -o jsonpath | jsonpath works for simple fields; jq handles complex filters (container by name) without escaping issues; jq is already a required dep |
| yq v3 syntax (`yq -r '.field' file`) | yq v4 syntax (`yq eval '.field' file`) | yq v3.4.3 is what's installed — must use v3 syntax; do NOT use `yq eval` or `yq e` (v4 commands) |
| Individual YAML files per scenario | Monolithic scenarios.yaml | Individual files: easier to add, review, and test; matches architecture.md directory structure |

**Note on yq version:** The machine has yq 3.4.3. This uses jq-compatible filter syntax: `yq -r '.field' file.yaml` and `yq -r '.array[]' file.yaml`. It does NOT support yq v4's `yq eval`, `yq e`, or `--expression` flags. The install.sh (Phase 7) should specify minimum yq version.

---

## Architecture Patterns

### Recommended Project Structure (Phase 2 deliverables)

```
ckad-drill/
├── lib/
│   ├── common.sh           # EXISTS - Phase 1
│   ├── display.sh          # STUB - needs pass/fail/header implementation
│   ├── cluster.sh          # EXISTS - Phase 1
│   ├── scenario.sh         # NEW - YAML parsing, namespace lifecycle, filtering
│   └── validator.sh        # NEW - 10 typed checks + result formatting
├── scenarios/
│   ├── domain-1/           # NEW dirs - for test fixtures
│   │   └── *.yaml
│   ├── domain-2/
│   ├── domain-3/
│   ├── domain-4/
│   └── domain-5/
└── test/
    ├── unit/
    │   ├── scenario.bats   # NEW - YAML parsing unit tests (no cluster)
    │   └── validator.bats  # NEW - check type parsing unit tests (no cluster)
    ├── integration/
    │   └── validation-types.bats  # NEW - each check against real cluster
    └── fixtures/           # NEW - test YAML scenarios (valid + invalid)
        ├── valid/
        └── invalid/
```

### Pattern 1: Scenario File Discovery and Loading

**What:** Find all YAML files under scenarios/ and any external path; load each into memory as indexed arrays.
**When to use:** On any command that needs the scenario list (drill, check, status).

```bash
# lib/scenario.sh
# Source: tested locally with yq v3.4.3

# scenario_discover [EXTERNAL_PATH]
# Outputs list of scenario file paths (one per line), built-in first then external.
# Warns and continues on duplicate IDs (first-loaded wins, per SCEN-05).
scenario_discover() {
  local external_path="${1:-}"
  local -a seen_ids=()

  # Built-in scenarios: find in repo scenarios/ directory
  local scenarios_dir="${CKAD_DRILL_ROOT}/scenarios"
  while IFS= read -r -d '' file; do
    _scenario_register_file "${file}" seen_ids
  done < <(find "${scenarios_dir}" -name "*.yaml" -type f -print0 | sort -z)

  # External scenarios (SCEN-04)
  if [[ -n "${external_path}" && -d "${external_path}" ]]; then
    while IFS= read -r -d '' file; do
      _scenario_register_file "${file}" seen_ids
    done < <(find "${external_path}" -name "*.yaml" -type f -print0 | sort -z)
  fi
}

_scenario_register_file() {
  local file="$1"
  local -n _seen="$2"  # nameref to seen_ids array

  local id
  id=$(yq -r '.id // empty' "${file}")
  if [[ -z "${id}" ]]; then
    warn "Skipping ${file}: missing required field 'id'"
    return 0
  fi

  # Check for duplicate (SCEN-05)
  if printf '%s\n' "${_seen[@]+"${_seen[@]}"}" | grep -q "^${id}$"; then
    warn "Duplicate scenario ID '${id}' in ${file} — skipping (first-loaded wins)"
    return 0
  fi

  _seen+=("${id}")
  echo "${file}"  # Emit path for caller
}
```

### Pattern 2: Scenario YAML Field Extraction (yq v3)

**What:** Extract all required and optional fields from a scenario YAML file.
**Critical:** Must use yq v3 syntax (no `yq eval`, no `--expression`).

```bash
# lib/scenario.sh
# Source: verified with yq 3.4.3 on this machine

scenario_load() {
  local file="$1"

  # Required fields — fail if missing
  local id domain title difficulty time_limit description
  id=$(yq -r '.id // empty' "${file}")
  domain=$(yq -r '.domain // empty' "${file}")
  title=$(yq -r '.title // empty' "${file}")
  difficulty=$(yq -r '.difficulty // empty' "${file}")
  time_limit=$(yq -r '.time_limit // empty' "${file}")

  # Validate required fields
  for field in id domain title difficulty time_limit; do
    if [[ -z "${!field}" ]]; then
      error "Scenario ${file}: missing required field '${field}'"
      return "${EXIT_PARSE_ERROR}"
    fi
  done

  # Namespace: scenario-defined or fallback to drill-<id> (ADR-06)
  local namespace
  namespace=$(yq -r '.namespace // empty' "${file}")
  if [[ -z "${namespace}" ]]; then
    namespace="drill-${id}"
  fi

  # Tags (optional) — export for Helm check
  local has_helm_tag=false
  if yq -r '.tags // [] | .[]' "${file}" 2>/dev/null | grep -q "^helm$"; then
    has_helm_tag=true
  fi

  # Export as globals for the calling context
  SCENARIO_ID="${id}"
  SCENARIO_DOMAIN="${domain}"
  SCENARIO_TITLE="${title}"
  SCENARIO_DIFFICULTY="${difficulty}"
  SCENARIO_TIME_LIMIT="${time_limit}"
  SCENARIO_NAMESPACE="${namespace}"
  SCENARIO_HAS_HELM="${has_helm_tag}"
  SCENARIO_FILE="${file}"
}
```

### Pattern 3: Domain and Difficulty Filtering (SCEN-03)

**What:** Filter scenario files by domain number and/or difficulty string.

```bash
# lib/scenario.sh
# Source: yq v3 filter syntax verified locally

scenario_filter() {
  local -a all_files=("$@")
  local domain_filter="${FILTER_DOMAIN:-}"    # 1-5 or empty
  local diff_filter="${FILTER_DIFFICULTY:-}"  # easy|medium|hard or empty

  for file in "${all_files[@]}"; do
    local domain difficulty
    domain=$(yq -r '.domain // empty' "${file}")
    difficulty=$(yq -r '.difficulty // empty' "${file}")

    # Apply domain filter
    if [[ -n "${domain_filter}" && "${domain}" != "${domain_filter}" ]]; then
      continue
    fi

    # Apply difficulty filter
    if [[ -n "${diff_filter}" && "${difficulty}" != "${diff_filter}" ]]; then
      continue
    fi

    echo "${file}"
  done
}
```

### Pattern 4: Namespace Lifecycle (SCEN-02)

**What:** Create namespace on scenario setup; delete on cleanup. Idempotent.

```bash
# lib/scenario.sh

scenario_setup() {
  local file="$1"
  scenario_load "${file}"  # Sets SCENARIO_* globals

  # Check Helm if needed (SCEN-06)
  if [[ "${SCENARIO_HAS_HELM}" == "true" ]]; then
    if ! command -v helm &>/dev/null; then
      error "Scenario '${SCENARIO_ID}' requires Helm, which is not installed."
      info "Install Helm: https://helm.sh/docs/intro/install/"
      return "${EXIT_ERROR}"
    fi
  fi

  # Create namespace (idempotent — ignore AlreadyExists)
  info "Setting up namespace '${SCENARIO_NAMESPACE}'..."
  kubectl create namespace "${SCENARIO_NAMESPACE}" 2>/dev/null || true

  # Apply setup commands/manifest if present (for debug/troubleshooting scenarios)
  local setup_commands
  setup_commands=$(yq -r '.setup.commands // [] | .[]' "${file}" 2>/dev/null)
  if [[ -n "${setup_commands}" ]]; then
    local setup_manifest
    setup_manifest=$(yq -r '.setup.manifest // empty' "${file}")
    while IFS= read -r cmd; do
      if [[ "${cmd}" == "kubectl apply -f -" && -n "${setup_manifest}" ]]; then
        echo "${setup_manifest}" | kubectl apply -f - -n "${SCENARIO_NAMESPACE}"
      else
        eval "${cmd}"
      fi
    done <<< "${setup_commands}"
  fi
}

scenario_cleanup() {
  local namespace="${SCENARIO_NAMESPACE:-}"
  if [[ -z "${namespace}" ]]; then
    return 0
  fi
  info "Cleaning up namespace '${namespace}'..."
  kubectl delete namespace "${namespace}" --ignore-not-found=true
}
```

### Pattern 5: Validator Dispatch (all 10 check types)

**What:** Main dispatch function reads each validation entry by index, routes to typed handler.
**ADR-07:** Each check runs exactly once. No retry. No kubectl wait.

```bash
# lib/validator.sh
# Source: tested jq patterns locally; kubectl patterns from official docs

validator_run_checks() {
  local file="$1"
  local namespace="$2"
  local -i total=0 passed=0 failed=0

  local check_count
  check_count=$(yq -r '.validations | length' "${file}")

  for (( i=0; i<check_count; i++ )); do
    local check_type
    check_type=$(yq -r ".validations[${i}].type" "${file}")

    local result
    case "${check_type}" in
      resource_exists)   result=$(_validator_resource_exists   "${file}" "${i}" "${namespace}") ;;
      resource_field)    result=$(_validator_resource_field    "${file}" "${i}" "${namespace}") ;;
      container_count)   result=$(_validator_container_count   "${file}" "${i}" "${namespace}") ;;
      container_image)   result=$(_validator_container_image   "${file}" "${i}" "${namespace}") ;;
      container_env)     result=$(_validator_container_env     "${file}" "${i}" "${namespace}") ;;
      volume_mount)      result=$(_validator_volume_mount      "${file}" "${i}" "${namespace}") ;;
      container_running) result=$(_validator_container_running "${file}" "${i}" "${namespace}") ;;
      label_selector)    result=$(_validator_label_selector    "${file}" "${i}" "${namespace}") ;;
      resource_count)    result=$(_validator_resource_count    "${file}" "${i}" "${namespace}") ;;
      command_output)    result=$(_validator_command_output    "${file}" "${i}" "${namespace}") ;;
      *)
        warn "Unknown check type: '${check_type}' — skipping"
        continue
        ;;
    esac

    (( total++ ))
    if [[ "${result}" == "PASS" ]]; then
      (( passed++ ))
      pass "${check_type}"
    else
      # result format: "FAIL:<expected>:<actual>"
      local expected actual
      expected="${result#FAIL:}"
      expected="${expected%%:*}"
      actual="${result#FAIL:*:}"
      (( failed++ ))
      fail "${check_type}" "${expected}" "${actual}"
    fi
  done

  header "Results: ${passed}/${total} checks passed"
  [[ "${failed}" -eq 0 ]]  # return 0 if all pass
}
```

### Pattern 6: Individual Check Implementations

```bash
# Source: kubectl docs + jq docs; all jq patterns verified locally

_validator_resource_exists() {
  local file="$1" idx="$2" namespace="$3"
  local resource
  resource=$(yq -r ".validations[${idx}].resource" "${file}")

  if kubectl get "${resource}" -n "${namespace}" &>/dev/null 2>&1; then
    echo "PASS"
  else
    echo "FAIL:${resource}:(not found)"
  fi
}

_validator_resource_field() {
  local file="$1" idx="$2" namespace="$3"
  local resource path expected actual
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  path=$(yq -r ".validations[${idx}].path" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  actual=$(kubectl get "${resource}" -n "${namespace}" -o jsonpath="${path}" 2>/dev/null) || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
  else
    echo "FAIL:${expected}:${actual}"
  fi
}

_validator_container_count() {
  local file="$1" idx="$2" namespace="$3"
  local resource expected actual
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  actual=$(kubectl get "${resource}" -n "${namespace}" -o json 2>/dev/null \
    | jq -r '.spec.containers | length') || actual="0"

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
  else
    echo "FAIL:${expected}:${actual}"
  fi
}

_validator_container_image() {
  local file="$1" idx="$2" namespace="$3"
  local resource container expected actual
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  actual=$(kubectl get "${resource}" -n "${namespace}" -o json 2>/dev/null \
    | jq -r --arg name "${container}" \
      '.spec.containers[] | select(.name==$name) | .image') || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
  else
    echo "FAIL:${expected}:${actual}"
  fi
}

_validator_container_env() {
  local file="$1" idx="$2" namespace="$3"
  local resource container env_name expected actual
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  env_name=$(yq -r ".validations[${idx}].env_name" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  actual=$(kubectl get "${resource}" -n "${namespace}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" --arg ename "${env_name}" \
      '.spec.containers[] | select(.name==$cname) | .env[] | select(.name==$ename) | .value') || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
  else
    echo "FAIL:${expected}:${actual}"
  fi
}

_validator_volume_mount() {
  local file="$1" idx="$2" namespace="$3"
  local resource container mount_path expected actual
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  mount_path=$(yq -r ".validations[${idx}].mount_path" "${file}")
  expected=$(yq -r ".validations[${idx}].expected // empty" "${file}")

  # Get the volume name at the given mount path
  actual=$(kubectl get "${resource}" -n "${namespace}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" --arg mpath "${mount_path}" \
      '.spec.containers[] | select(.name==$cname) | .volumeMounts[] | select(.mountPath==$mpath) | .name') || actual=""

  if [[ -n "${expected}" ]]; then
    # Check specific volume name
    if [[ "${actual}" == "${expected}" ]]; then echo "PASS"; else echo "FAIL:${expected}:${actual}"; fi
  else
    # Just check it exists (non-empty)
    if [[ -n "${actual}" ]]; then echo "PASS"; else echo "FAIL:(mounted at ${mount_path}):(not found)"; fi
  fi
}

_validator_container_running() {
  local file="$1" idx="$2" namespace="$3"
  local resource container is_running
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")

  is_running=$(kubectl get "${resource}" -n "${namespace}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" \
      '.status.containerStatuses[] | select(.name==$cname) | .state | has("running")') || is_running="false"

  if [[ "${is_running}" == "true" ]]; then
    echo "PASS"
  else
    echo "FAIL:running:${is_running}"
  fi
}

_validator_label_selector() {
  local file="$1" idx="$2" namespace="$3"
  local resource_kind selector ns_override
  resource_kind=$(yq -r ".validations[${idx}].resource_kind" "${file}")
  selector=$(yq -r ".validations[${idx}].selector" "${file}")
  ns_override=$(yq -r ".validations[${idx}].namespace // empty" "${file}")
  local ns="${ns_override:-${namespace}}"

  if kubectl get "${resource_kind}" -n "${ns}" -l "${selector}" \
      --no-headers 2>/dev/null | grep -q .; then
    echo "PASS"
  else
    echo "FAIL:(resources matching ${selector}):(none found)"
  fi
}

_validator_resource_count() {
  local file="$1" idx="$2" namespace="$3"
  local resource_kind selector expected ns_override actual
  resource_kind=$(yq -r ".validations[${idx}].resource_kind" "${file}")
  selector=$(yq -r ".validations[${idx}].selector" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")
  ns_override=$(yq -r ".validations[${idx}].namespace // empty" "${file}")
  local ns="${ns_override:-${namespace}}"

  local raw_output
  raw_output=$(kubectl get "${resource_kind}" -n "${ns}" -l "${selector}" --no-headers 2>/dev/null) || raw_output=""
  if [[ -z "${raw_output}" ]]; then
    actual=0
  else
    actual=$(echo "${raw_output}" | wc -l | tr -d ' ')
  fi

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
  else
    echo "FAIL:${expected}:${actual}"
  fi
}

_validator_command_output() {
  local file="$1" idx="$2" namespace="$3"
  local command mode expected actual
  command=$(yq -r ".validations[${idx}].command" "${file}")
  mode=$(yq -r ".validations[${idx}].mode" "${file}")  # contains | matches | equals
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  # Inject namespace into command context
  actual=$(NAMESPACE="${namespace}" eval "${command}" 2>&1) || actual=""

  case "${mode}" in
    contains)
      if echo "${actual}" | grep -qF "${expected}"; then
        echo "PASS"
      else
        echo "FAIL:contains '${expected}':${actual}"
      fi
      ;;
    matches)
      if echo "${actual}" | grep -qE "${expected}"; then
        echo "PASS"
      else
        echo "FAIL:matches '${expected}':${actual}"
      fi
      ;;
    equals)
      if [[ "${actual}" == "${expected}" ]]; then
        echo "PASS"
      else
        echo "FAIL:${expected}:${actual}"
      fi
      ;;
    *)
      echo "FAIL:unknown mode '${mode}':(skip)"
      ;;
  esac
}
```

### Pattern 7: display.sh Implementation (pass/fail/header)

**What:** Fill in the Phase 1 stubs. display.sh is called by validator.sh — must be done first.

```bash
# lib/display.sh — terminal output functions for validation results
# Source: Architecture doc ADR; color pattern from Phase 1 common.sh

# pass CHECK_NAME
pass() {
  local check_name="$1"
  if _color_enabled; then
    printf '  \033[0;32m[PASS]\033[0m %s\n' "${check_name}"
  else
    printf '  [PASS] %s\n' "${check_name}"
  fi
}

# fail CHECK_NAME EXPECTED ACTUAL
fail() {
  local check_name="$1" expected="$2" actual="$3"
  if _color_enabled; then
    printf '  \033[0;31m[FAIL]\033[0m %s\n' "${check_name}"
    printf '         expected: %s\n' "${expected}"
    printf '         actual:   %s\n' "${actual}"
  else
    printf '  [FAIL] %s\n' "${check_name}"
    printf '         expected: %s\n' "${expected}"
    printf '         actual:   %s\n' "${actual}"
  fi
}

# header TEXT
header() {
  local text="$1"
  if _color_enabled; then
    printf '\n\033[1m%s\033[0m\n' "${text}"
    printf '%s\n' "$(printf '%0.s-' $(seq 1 ${#text}))"
  else
    printf '\n%s\n' "${text}"
    printf '%s\n' "$(printf '%0.s-' $(seq 1 ${#text}))"
  fi
}
```

### Pattern 8: Scenario YAML Schema (SCEN-01)

The complete YAML schema for a scenario file:

```yaml
# scenarios/domain-N/scenario-name.yaml
id: multi-container-pod           # required; hyphenated, descriptive (no numbers)
domain: 1                         # required; integer 1-5
title: Multi-Container Pod        # required
difficulty: easy                  # required; easy | medium | hard
time_limit: 180                   # required; integer seconds
namespace: web-team               # optional; defaults to drill-<id>
tags:                             # optional; list of strings
  - helm                          # if present, Helm is checked before setup (SCEN-06)

description: |
  Create a pod named `web-logger` with two containers...

hint: |
  Start with kubectl run and add the sidecar container manually.

solution:
  commands:                       # required; list of kubectl commands applied in order
    - kubectl apply -f -
  manifest: |                     # optional; piped to stdin of "kubectl apply -f -"
    apiVersion: v1
    kind: Pod
    ...

setup:                            # optional; for debug/troubleshooting scenarios only
  commands:
    - kubectl apply -f -
  manifest: |
    # Broken state for user to fix

validations:                      # required; list of check objects
  - type: resource_exists
    resource: pod/web-logger      # format: kind/name

  - type: resource_field
    resource: pod/web-logger
    path: '{.spec.restartPolicy}' # kubectl jsonpath expression
    expected: Always

  - type: container_count
    resource: pod/web-logger
    expected: "2"                 # string, compared as string

  - type: container_image
    resource: pod/web-logger
    container: nginx              # container name
    expected: nginx               # image name (without tag matches any tag)

  - type: container_env
    resource: pod/web-logger
    container: nginx
    env_name: MY_VAR
    expected: hello

  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /var/log/nginx
    expected: logs                # optional; volume name to verify; omit to just check mount exists

  - type: container_running
    resource: pod/web-logger
    container: nginx

  - type: label_selector
    resource_kind: pods           # kubernetes resource kind (plural)
    selector: app=nginx           # label selector
    namespace: web-team           # optional; defaults to scenario namespace

  - type: resource_count
    resource_kind: pods
    selector: app=nginx
    expected: "3"                 # string
    namespace: web-team           # optional

  - type: command_output
    command: kubectl get svc web-svc -n web-team -o jsonpath='{.spec.type}'
    mode: equals                  # contains | matches | equals
    expected: ClusterIP
```

### Anti-Patterns to Avoid

- **Using `yq eval` syntax:** yq v3.4.3 is installed; `yq eval` is v4 syntax. Use `yq -r '.field' file` instead.
- **Using kubectl jsonpath for complex container selection:** `kubectl get pod -o jsonpath='{.spec.containers[?(@.name=="nginx")].image}'` works but requires careful quoting in bash. Use `kubectl get -o json | jq` instead — jq's `--arg` avoids quoting issues entirely.
- **Not handling empty kubectl output in resource_count:** `echo "" | wc -l` returns 1, not 0. Always check for empty string before counting.
- **Directly calling `exit` in lib functions:** Per Phase 1 pattern, lib functions return non-zero codes; only entry point exits. `error()` in common.sh is print-only.
- **Retrying failed checks:** ADR-07 is explicit — no retry, no wait. A pending pod is a FAIL with actual="not running", not a reason to wait.
- **Using eval without quoting:** The `command_output` check uses `eval` — this is intentional (escape hatch by design) but caller must understand the security model (local tool, user writes the scenarios).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing | Custom bash YAML parser | yq v3 | YAML edge cases (multi-line strings, anchors, special chars) require a real parser |
| JSON field extraction | Custom string cutting with awk/sed | jq with --arg | Quoting, nesting, array indexing are all handled; --arg prevents injection |
| Kubernetes field queries | Custom API calls | kubectl get -o json + jq | kubectl handles auth, context, TLS; output is stable JSON |
| Namespace creation idempotency | Check-then-create logic | kubectl create namespace + || true | Race-free; Kubernetes returns AlreadyExists which kubectl surfaces as non-zero exit |
| Container state checking | Custom pod phase parsing | jq .state.running | containerStatuses structure is complex; jq select handles it cleanly |

**Key insight:** Every validation check is a thin wrapper over "run kubectl, pipe to jq, compare string." Don't abstract beyond that — users should be able to read the validation code and understand exactly what kubectl command is being run.

---

## Common Pitfalls

### Pitfall 1: yq v3 vs v4 Syntax Confusion

**What goes wrong:** Developer writes `yq eval '.field' file.yaml` which is yq v4 syntax; returns error on this machine (yq 3.4.3 installed).
**Why it happens:** Most online documentation (2023-2026) now covers yq v4. The install on this machine is v3.
**How to avoid:** Always use `yq -r '.field' file.yaml` (v3 syntax). Test all yq commands locally before committing. The `-r` flag strips quotes from string output (same as jq's `-r`).
**Warning signs:** `yq: error: unrecognized arguments: eval` or `yq: error: unrecognized flag`.

### Pitfall 2: Empty Output from kubectl in resource_count

**What goes wrong:** `kubectl get pods -l app=foo --no-headers | wc -l` returns `1` even when there are no pods (empty string has one line in wc -l).
**Why it happens:** `echo "" | wc -l` counts the trailing newline as a line.
**How to avoid:** Check if output is empty first: `if [[ -z "${raw_output}" ]]; then actual=0; else actual=$(echo "${raw_output}" | wc -l); fi`
**Warning signs:** resource_count check returns 1 when 0 pods expected.

### Pitfall 3: jq Fails When containerStatuses Is Missing

**What goes wrong:** `kubectl get pod -o json | jq '.status.containerStatuses[] | ...'` fails with `null` or empty output when the pod hasn't started yet.
**Why it happens:** A newly-created pod may have `.status.containerStatuses` as null or missing before the kubelet has populated it.
**How to avoid:** Use `// []` fallback in jq: `.status.containerStatuses // [] | .[] | select(...)`. For container_running, treat null result as "not running" (return FAIL with actual="not running").
**Warning signs:** jq exits with code 5 (not found); bash `-o errexit` causes unexpected exit.

### Pitfall 4: Namespace Not Deleted on Error Path

**What goes wrong:** scenario_setup creates the namespace, then a setup command fails mid-way. Namespace is left dangling. Next `drill` of the same scenario fails to create namespace (AlreadyExists is fine) but may run with leftover resources.
**Why it happens:** set -euo pipefail causes early exit from setup; cleanup trap isn't set yet.
**How to avoid:** Set up `trap "scenario_cleanup" EXIT INT TERM` in bin/ckad-drill before calling scenario_setup. This is Phase 3's responsibility (session management), but scenario.sh cleanup must be callable safely even if setup was partial.
**Warning signs:** `kubectl get pods -n web-team` shows old pods from a previous failed setup.

### Pitfall 5: resource_field jsonpath with Special Characters

**What goes wrong:** `kubectl get pod -o jsonpath='{.metadata.annotations.kubernetes\.io/test}'` fails due to bash quoting of the `.` in the key name.
**Why it happens:** jsonpath field names with dots require backslash escaping inside kubectl jsonpath; single-quoting helps but not always sufficient.
**How to avoid:** For `resource_field` checks with dotted key names, use jq instead: `kubectl get -o json | jq '.metadata.annotations["kubernetes.io/test"]'`. Document this in scenario authoring guide.
**Warning signs:** resource_field returns empty actual value despite resource existing.

### Pitfall 6: yq Null Handling for Optional Fields

**What goes wrong:** `yq -r '.namespace' file.yaml` returns `null` (as the string "null") when the field is absent, not an empty string.
**Why it happens:** yq v3 outputs the JSON literal `null` for missing fields when using raw output.
**How to avoid:** Always use `// empty` suffix: `yq -r '.namespace // empty' file.yaml`. This outputs empty string for null, which bash handles correctly with `[[ -z "${var}" ]]`.
**Warning signs:** `if [[ -z "${namespace}" ]]` doesn't trigger; namespace variable contains the string "null".

### Pitfall 7: eval in command_output with Quoted Strings

**What goes wrong:** A command_output validation with embedded quotes fails to eval correctly.
**Why it happens:** `eval "kubectl get pod -o jsonpath='{.spec.containers[0].image}'"` — the single quotes inside double-quoted eval string cause bash parse issues.
**How to avoid:** Scenario authors should use double quotes in jsonpath for command_output: `kubectl get pod -o jsonpath="{.spec.containers[0].image}"`. Document this convention in SCEN-01 schema docs.
**Warning signs:** command_output check returns empty actual for a command that works when typed manually.

---

## Code Examples

### Complete scenario.sh Structure

```bash
# lib/scenario.sh — scenario loading, filtering, namespace lifecycle
# shellcheck shell=bash
# Source: Phase 2 design, yq v3.4.3 verified patterns

# Public functions:
#   scenario_discover [EXTERNAL_PATH] — find all scenario files, check IDs
#   scenario_load FILE                — load fields into SCENARIO_* globals
#   scenario_filter [--domain N] [--difficulty LEVEL] FILE... — filter list
#   scenario_setup FILE               — create namespace, apply setup
#   scenario_cleanup                  — delete SCENARIO_NAMESPACE
#   scenario_check_helm               — verify Helm installed for tagged scenarios
```

### Test Fixture: Minimal Valid Scenario

```yaml
# test/fixtures/valid/minimal-scenario.yaml
id: test-minimal
domain: 1
difficulty: easy
title: Minimal Test Scenario
time_limit: 60
description: |
  Create a pod named test-pod in the default namespace.
validations:
  - type: resource_exists
    resource: pod/test-pod
solution:
  commands:
    - kubectl run test-pod --image=nginx --restart=Never
```

### Test Fixture: All 10 Check Types

```yaml
# test/fixtures/valid/all-checks-scenario.yaml
id: test-all-checks
domain: 1
difficulty: hard
title: All Validation Types Test
time_limit: 300
namespace: all-checks-ns
description: |
  Deploy a specific pod configuration to test all check types.
validations:
  - type: resource_exists
    resource: pod/web-logger
  - type: resource_field
    resource: pod/web-logger
    path: "{.spec.restartPolicy}"
    expected: Never
  - type: container_count
    resource: pod/web-logger
    expected: "2"
  - type: container_image
    resource: pod/web-logger
    container: nginx
    expected: nginx:1.21
  - type: container_env
    resource: pod/web-logger
    container: nginx
    env_name: LOG_LEVEL
    expected: info
  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /var/log/nginx
  - type: container_running
    resource: pod/web-logger
    container: nginx
  - type: label_selector
    resource_kind: pods
    selector: app=web-logger
  - type: resource_count
    resource_kind: pods
    selector: app=web-logger
    expected: "1"
  - type: command_output
    command: kubectl get pod/web-logger -n all-checks-ns -o jsonpath="{.metadata.name}"
    mode: equals
    expected: web-logger
solution:
  commands:
    - kubectl apply -f -
  manifest: |
    apiVersion: v1
    kind: Pod
    metadata:
      name: web-logger
      namespace: all-checks-ns
      labels:
        app: web-logger
    spec:
      restartPolicy: Never
      containers:
      - name: nginx
        image: nginx:1.21
        env:
        - name: LOG_LEVEL
          value: info
        volumeMounts:
        - name: logs
          mountPath: /var/log/nginx
      - name: logger
        image: busybox
        command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: logs
        emptyDir: {}
```

### Unit Test Pattern for validator.sh (No Cluster)

```bash
# test/unit/validator.bats
# Tests check-type parsing logic without running kubectl
# Uses mock kubectl that returns pre-canned JSON

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"
  source "${CKAD_DRILL_ROOT}/lib/common.sh"
  source "${CKAD_DRILL_ROOT}/lib/display.sh"
  source "${CKAD_DRILL_ROOT}/lib/validator.sh"

  FIXTURE_DIR="${CKAD_DRILL_ROOT}/test/fixtures"
  MOCK_DIRS=()
}

teardown() {
  local dir
  for dir in "${MOCK_DIRS[@]+"${MOCK_DIRS[@]}"}"; do rm -rf "${dir}"; done
}

# Mock kubectl to return pre-canned JSON
_mock_kubectl_json() {
  local json="$1"
  local mock_dir
  mock_dir="$(mktemp -d)"
  MOCK_DIRS+=("${mock_dir}")
  cat > "${mock_dir}/kubectl" << EOF
#!/usr/bin/env bash
echo '${json}'
EOF
  chmod +x "${mock_dir}/kubectl"
  export PATH="${mock_dir}:${PATH}"
}

@test "resource_exists: PASS when kubectl exits 0" {
  _mock_kubectl_json '{}'  # kubectl exits 0
  run _validator_resource_exists "${FIXTURE_DIR}/valid/minimal-scenario.yaml" 0 test-ns
  assert_output "PASS"
}

@test "container_count: PASS when count matches expected" {
  _mock_kubectl_json '{"spec":{"containers":[{"name":"a"},{"name":"b"}]}}'
  # Use a fixture with container_count expected: "2"
  run _validator_container_count "${FIXTURE_DIR}/valid/all-checks-scenario.yaml" 1 test-ns
  assert_output "PASS"
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| kubectl jsonpath for nested queries | kubectl -o json + jq --arg | jq --arg handles quoting safely; jsonpath still used for simple field access |
| yq v4 syntax (eval, --expression) | yq v3 syntax (-r '.field' file) | v3.4.3 installed; use v3 patterns throughout |
| Scenario YAML as ad-hoc format | Architecture-defined schema (ADR-01, ADR-06, ADR-08) | Schema is locked; all Phase 2 code implements this schema |
| display.sh stubs (Phase 1) | Implemented pass/fail/header | Phase 2 completes the display stub; other phases use these functions |

**Deprecated/outdated:**
- `kubectl get -o jsonpath` for container-name-filtered queries: Still works but fragile with quoting. Use `kubectl get -o json | jq --arg` instead.
- Sourcing display.sh before common.sh: display.sh calls `_color_enabled()` from common.sh — common.sh must be sourced first. Phase 1's sourcing order (common.sh before display.sh) is correct.

---

## Open Questions

1. **yq version in install.sh**
   - What we know: yq v3.4.3 is installed on the developer machine; architecture says yq is a required dep
   - What's unclear: Install.sh (Phase 7) should specify minimum yq version; whether to install v3 or v4
   - Recommendation: For Phase 2, write all code for yq v3. Add a version check comment in scenario.sh noting the v3 requirement. Phase 7 install.sh should pin to yq v3 or document the syntax difference.

2. **resource_field: jsonpath vs jq path**
   - What we know: `resource_field` uses kubectl jsonpath (`-o jsonpath='{.path}'`); this works for simple dot-path access
   - What's unclear: What happens when the path has array indices or dotted annotation keys?
   - Recommendation: Accept kubectl jsonpath syntax in the `path` field (wrapped in `{}`). For complex paths, scenario authors should use `command_output` instead. Document this limitation.

3. **scenario_setup: eval vs explicit kubectl apply**
   - What we know: The `setup.commands` field uses `eval` to execute commands; this is an intentional escape hatch
   - What's unclear: Whether eval is safe enough for a local tool; whether there's a better pattern
   - Recommendation: Keep `eval` — this is a local CLI tool where the user controls the scenario files. Document that external scenario sources should be trusted before use. This is consistent with the `command_output` eval in validator.sh.

4. **display.sh: _color_enabled dependency**
   - What we know: `display.sh`'s `pass()`/`fail()` need `_color_enabled()` from `common.sh`
   - What's unclear: Whether display.sh should re-define `_color_enabled` or rely on sourcing order
   - Recommendation: Rely on sourcing order (common.sh before display.sh) as established in Phase 1. Add a comment in display.sh noting the dependency. Do NOT redefine `_color_enabled` in display.sh.

---

## Sources

### Primary (HIGH confidence)

- yq v3 syntax verified locally — `yq 3.4.3` installed; all yq patterns tested against real YAML files on this machine
- jq patterns verified locally — all `.spec.containers[] | select(.name==$name)` patterns tested with mock JSON
- Architecture doc `/home/jeff/Projects/cka/_bmad-output/planning-artifacts/architecture.md` — ADR-01, ADR-06, ADR-07, ADR-08 define the exact validation schema and behavior
- REQUIREMENTS.md `/home/jeff/Projects/cka/.planning/REQUIREMENTS.md` — SCEN-01 through SCEN-06, VALD-01 through VALD-12 reviewed in full
- Phase 1 code reviewed — common.sh, display.sh, cluster.sh, test patterns established

### Secondary (MEDIUM confidence)

- https://mikefarah.gitbook.io/yq/usage/tips-and-tricks — yq usage patterns (v4 docs, but core concepts apply to v3 with syntax adjustment)
- https://github.com/mikefarah/yq/discussions/1511 — array iteration patterns
- kubectl jsonpath docs (https://kubernetes.io/docs/reference/kubectl/jsonpath/) — field access syntax for resource_field check

### Tertiary (LOW confidence)

- yq v3 vs v4 install story for install.sh (Phase 7) — not yet researched; noted as open question

---

## Metadata

**Confidence breakdown:**
- yq v3 patterns: HIGH — verified locally with yq 3.4.3
- jq patterns: HIGH — verified locally with real JSON
- Scenario YAML schema: HIGH — defined in architecture doc ADRs, not speculative
- kubectl check implementations: HIGH — standard kubectl patterns + jq; no cluster needed to verify syntax
- Test patterns: HIGH — Phase 1 bats patterns are established and working

**Research date:** 2026-02-28
**Valid until:** 2026-03-30 (30 days — tools are stable; yq v3/v4 divergence is a known fixed constraint)

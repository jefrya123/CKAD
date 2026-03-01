# Sprint 2: Scenario & Validation Engines — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Define the scenario YAML schema, implement scenario loading and lifecycle management, schema validation, and the full validation engine with 10 typed checks.

**Architecture:** Builds on Sprint 1 foundation (common.sh, display.sh, cluster.sh). Scenario YAML files parsed with yq. Validation checks run kubectl against the live kind cluster. All output through display.sh. See `_bmad-output/planning-artifacts/architecture.md` for full ADRs.

**Tech Stack:** Bash, yq, kubectl, jq, bats-core, shellcheck

**Key conventions (from architecture doc):**
- `set -euo pipefail` ONLY in `bin/ckad-drill`, never in lib files
- Functions: `module_action()` public, `_module_helper()` private
- Variables: `UPPER_SNAKE` globals, `lower_snake` locals, always `"${braced}"`
- All output through `display.sh` functions — no raw echo with escape codes in libs
- Lib files are source-only — no top-level execution, only function definitions
- 2-space indent, no tabs
- shellcheck clean — no suppressed warnings without justification
- YAML parsing via yq, JSON via jq
- ADR-07: Single check, no retry
- Scenario IDs: descriptive hyphenated (e.g., `multi-container-pod`)
- Namespace: scenario-defined with fallback to `drill-<id>`

**Sprint 1 deliverables available:** `lib/common.sh`, `lib/display.sh`, `lib/cluster.sh`, `test/helpers/test-helper.bash`, `bin/ckad-drill`, `Makefile`

---

### Task 1: Define Scenario YAML Schema (Story 3.1)

**Files:**
- Create: `docs/scenario-schema.md`
- Create: `scenarios/domain-1/multi-container-pod.yaml`

**Step 1: Create schema documentation**

Create `docs/scenario-schema.md`:
```markdown
# Scenario YAML Schema

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique descriptive hyphenated ID (e.g., `multi-container-pod`). No numeric prefixes. Learn scenarios use `learn-` prefix. Debug scenarios use `debug-` prefix. |
| `domain` | integer | CKAD domain 1-5 |
| `title` | string | Human-readable scenario title |
| `difficulty` | string | One of: `easy`, `medium`, `hard` |
| `time_limit` | integer | Time limit in seconds (positive integer) |
| `description` | string | Task description shown to the user (YAML block scalar `\|`) |
| `validations` | list | List of validation check objects (see Validation Types below) |
| `solution` | string | Solution commands/YAML shown on request (YAML block scalar `\|`) |

## Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `namespace` | string | `drill-<id>` | Namespace for this scenario. Lowercase with hyphens only. |
| `tags` | list | `[]` | Tags for filtering (e.g., `[helm]`) |
| `weight` | integer | `1` | Selection weight for exam mode (higher = more likely) |
| `hint` | string | none | Hint text shown on request |
| `setup` | list | `[]` | Shell commands to run during scenario setup |
| `cleanup` | list | `[]` | Shell commands to run during scenario cleanup |
| `learn` | boolean | `false` | Whether this is a learn-mode scenario |
| `concept_text` | string | none | Concept explanation for learn mode |

## Validation Types

Each validation object has a `type` field and type-specific parameters:

### resource_exists
Checks that a resource exists in the namespace.
- `resource` (required): Resource reference as `kind/name` (e.g., `pod/web-logger`)
- `description` (optional): Human-readable check description

### resource_field
Checks a jsonpath field value on a resource.
- `resource` (required): Resource reference as `kind/name`
- `jsonpath` (required): JSONPath expression (e.g., `{.spec.replicas}`)
- `expected` (required): Expected value
- `description` (optional): Human-readable check description

### container_count
Checks the number of containers in a pod.
- `resource` (required): Pod reference as `pod/name`
- `expected` (required): Expected container count (integer)
- `description` (optional): Human-readable check description

### container_image
Checks the image of a named container.
- `resource` (required): Pod reference as `pod/name`
- `container` (required): Container name
- `expected` (required): Expected image (e.g., `nginx:1.25`)
- `description` (optional): Human-readable check description

### container_env
Checks an environment variable in a named container.
- `resource` (required): Pod reference as `pod/name`
- `container` (required): Container name
- `env_name` (required): Environment variable name
- `expected` (required): Expected value
- `description` (optional): Human-readable check description

### volume_mount
Checks that a volume mount exists at a given path.
- `resource` (required): Pod reference as `pod/name`
- `container` (required): Container name
- `mount_path` (required): Expected mount path
- `description` (optional): Human-readable check description

### container_running
Checks that a named container is in Running state.
- `resource` (required): Pod reference as `pod/name`
- `container` (required): Container name
- `description` (optional): Human-readable check description

### label_selector
Checks that resources matching a label selector exist.
- `resource_type` (required): Resource type (e.g., `pod`, `deployment`)
- `labels` (required): Label selector string (e.g., `app=web,tier=frontend`)
- `description` (optional): Human-readable check description

### resource_count
Checks the count of resources matching a selector.
- `resource_type` (required): Resource type (e.g., `pod`)
- `selector` (required): Label selector string
- `expected` (required): Expected count (integer)
- `description` (optional): Human-readable check description

### command_output
Runs an arbitrary command and checks its output.
- `command` (required): Shell command to execute
- One of the following (exactly one required):
  - `contains` (string): Output must contain this substring
  - `matches` (string): Output must match this regex
  - `equals` (string): Output must equal this string exactly
- `description` (optional): Human-readable check description

## Example Scenario

See `scenarios/domain-1/multi-container-pod.yaml` for a complete working example.
```

**Step 2: Create reference scenario YAML**

Create `scenarios/domain-1/multi-container-pod.yaml`:
```yaml
id: multi-container-pod
domain: 1
title: Multi-Container Pod with Shared Volume
difficulty: medium
time_limit: 300
namespace: web-team
tags:
  - multi-container
  - volumes
weight: 2
hint: |
  A multi-container pod shares the same network namespace and can
  share volumes. Use an emptyDir volume mounted into both containers.
  The nginx container should serve from /usr/share/nginx/html and
  the sidecar should write to the same path.
description: |
  Create a pod named `web-logger` in the `web-team` namespace with two containers:

  1. **nginx** container:
     - Image: `nginx:1.25`
     - Port: 80
     - Volume mount: a shared volume at `/usr/share/nginx/html`

  2. **logger** container:
     - Image: `busybox:1.36`
     - Command: `sh -c 'while true; do echo "$(date) - request logged" >> /output/access.log; sleep 5; done'`
     - Volume mount: the same shared volume at `/output`

  The pod should use an `emptyDir` volume named `shared-data`.
setup:
  - kubectl create namespace web-team --dry-run=client -o yaml | kubectl apply -f -
validations:
  - type: resource_exists
    resource: pod/web-logger
    description: Pod web-logger exists
  - type: container_count
    resource: pod/web-logger
    expected: 2
    description: Pod has exactly 2 containers
  - type: container_image
    resource: pod/web-logger
    container: nginx
    expected: nginx:1.25
    description: nginx container uses correct image
  - type: container_image
    resource: pod/web-logger
    container: logger
    expected: busybox:1.36
    description: logger container uses correct image
  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /usr/share/nginx/html
    description: nginx has shared volume mounted
  - type: volume_mount
    resource: pod/web-logger
    container: logger
    mount_path: /output
    description: logger has shared volume mounted
  - type: container_running
    resource: pod/web-logger
    container: nginx
    description: nginx container is running
  - type: container_running
    resource: pod/web-logger
    container: logger
    description: logger container is running
  - type: resource_field
    resource: pod/web-logger
    jsonpath: "{.spec.volumes[?(@.name=='shared-data')].emptyDir}"
    expected: "{}"
    description: shared-data volume is emptyDir type
solution: |
  cat <<'SOL' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: web-logger
    namespace: web-team
  spec:
    containers:
    - name: nginx
      image: nginx:1.25
      ports:
      - containerPort: 80
      volumeMounts:
      - name: shared-data
        mountPath: /usr/share/nginx/html
    - name: logger
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo \"$(date) - request logged\" >> /output/access.log; sleep 5; done"]
      volumeMounts:
      - name: shared-data
        mountPath: /output
    volumes:
    - name: shared-data
      emptyDir: {}
  SOL
```

**Step 3: Commit**

```bash
git add docs/scenario-schema.md scenarios/domain-1/multi-container-pod.yaml
git commit -m "docs: define scenario YAML schema with reference example

Schema documentation covering all required/optional fields, 10 typed
validation checks with parameters, and a complete multi-container-pod
reference scenario in scenarios/domain-1/."
```

---

### Task 2: Implement lib/scenario.sh — Scenario Loading & Lifecycle (Story 3.2)

**Files:**
- Create: `lib/scenario.sh`
- Create: `test/unit/scenario.bats`
- Create: `test/helpers/fixtures/valid-scenario.yaml`
- Create: `test/helpers/fixtures/minimal-scenario.yaml`
- Create: `test/helpers/fixtures/learn-scenario.yaml`

**Step 1: Create test fixture files**

Create `test/helpers/fixtures/valid-scenario.yaml`:
```yaml
id: test-valid-scenario
domain: 1
title: Test Valid Scenario
difficulty: easy
time_limit: 120
namespace: test-ns
tags:
  - test
weight: 1
hint: |
  This is a test hint.
description: |
  This is a test scenario description.
  Create a pod named test-pod.
setup:
  - kubectl create namespace test-ns --dry-run=client -o yaml | kubectl apply -f -
cleanup:
  - kubectl delete namespace test-ns --ignore-not-found
validations:
  - type: resource_exists
    resource: pod/test-pod
    description: Pod test-pod exists
  - type: container_image
    resource: pod/test-pod
    container: main
    expected: nginx:1.25
    description: Container uses correct image
solution: |
  kubectl run test-pod --image=nginx:1.25 -n test-ns
```

Create `test/helpers/fixtures/minimal-scenario.yaml`:
```yaml
id: test-minimal
domain: 2
title: Minimal Test Scenario
difficulty: easy
time_limit: 60
description: |
  This is a minimal scenario with only required fields.
validations:
  - type: resource_exists
    resource: pod/minimal-pod
    description: Pod exists
solution: |
  kubectl run minimal-pod --image=nginx
```

Create `test/helpers/fixtures/learn-scenario.yaml`:
```yaml
id: learn-test-pods
domain: 1
title: Learn About Pods
difficulty: easy
time_limit: 180
learn: true
concept_text: |
  A Pod is the smallest deployable unit in Kubernetes.
  Pods contain one or more containers that share networking and storage.
description: |
  Create a pod named my-first-pod using the nginx:1.25 image.
validations:
  - type: resource_exists
    resource: pod/my-first-pod
    description: Pod exists
solution: |
  kubectl run my-first-pod --image=nginx:1.25
```

**Step 2: Write failing tests**

Create `test/unit/scenario.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/scenario.sh"
  FIXTURE_DIR="${CKAD_ROOT}/test/helpers/fixtures"
}

# --- scenario_load() tests ---

@test "scenario_load() parses id from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_ID}" == "test-valid-scenario" ]]
}

@test "scenario_load() parses domain from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_DOMAIN}" == "1" ]]
}

@test "scenario_load() parses title from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_TITLE}" == "Test Valid Scenario" ]]
}

@test "scenario_load() parses difficulty from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_DIFFICULTY}" == "easy" ]]
}

@test "scenario_load() parses time_limit from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_TIME_LIMIT}" == "120" ]]
}

@test "scenario_load() parses namespace from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_NAMESPACE}" == "test-ns" ]]
}

@test "scenario_load() defaults namespace to drill-<id>" {
  scenario_load "${FIXTURE_DIR}/minimal-scenario.yaml"
  [[ "${SCENARIO_NAMESPACE}" == "drill-test-minimal" ]]
}

@test "scenario_load() parses hint from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_HINT}" == *"test hint"* ]]
}

@test "scenario_load() parses description from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_DESCRIPTION}" == *"test scenario description"* ]]
}

@test "scenario_load() parses solution from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_SOLUTION}" == *"kubectl run test-pod"* ]]
}

@test "scenario_load() parses learn flag from YAML" {
  scenario_load "${FIXTURE_DIR}/learn-scenario.yaml"
  [[ "${SCENARIO_LEARN}" == "true" ]]
}

@test "scenario_load() defaults learn to false" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_LEARN}" == "false" ]]
}

@test "scenario_load() parses concept_text from learn scenario" {
  scenario_load "${FIXTURE_DIR}/learn-scenario.yaml"
  [[ "${SCENARIO_CONCEPT_TEXT}" == *"smallest deployable unit"* ]]
}

@test "scenario_load() parses weight from YAML" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_WEIGHT}" == "1" ]]
}

@test "scenario_load() defaults weight to 1" {
  scenario_load "${FIXTURE_DIR}/minimal-scenario.yaml"
  [[ "${SCENARIO_WEIGHT}" == "1" ]]
}

@test "scenario_load() stores SCENARIO_FILE path" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${SCENARIO_FILE}" == "${FIXTURE_DIR}/valid-scenario.yaml" ]]
}

@test "scenario_load() stores raw validations JSON" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ -n "${SCENARIO_VALIDATIONS}" ]]
  # Should be valid JSON array
  echo "${SCENARIO_VALIDATIONS}" | jq empty
}

@test "scenario_load() fails on missing file" {
  run scenario_load "${FIXTURE_DIR}/nonexistent.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not found"* ]]
}

@test "scenario_load() parses setup commands as JSON array" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ -n "${SCENARIO_SETUP}" ]]
  local count
  count="$(echo "${SCENARIO_SETUP}" | jq 'length')"
  [[ "${count}" -eq 1 ]]
}

@test "scenario_load() defaults setup to empty array" {
  scenario_load "${FIXTURE_DIR}/minimal-scenario.yaml"
  local count
  count="$(echo "${SCENARIO_SETUP}" | jq 'length')"
  [[ "${count}" -eq 0 ]]
}

@test "scenario_load() parses tags as JSON array" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  local has_test
  has_test="$(echo "${SCENARIO_TAGS}" | jq 'index("test") != null')"
  [[ "${has_test}" == "true" ]]
}

# --- scenario_get_field() tests ---

@test "scenario_get_field() returns field value" {
  scenario_load "${FIXTURE_DIR}/valid-scenario.yaml"
  local result
  result="$(scenario_get_field "id")"
  [[ "${result}" == "test-valid-scenario" ]]
}

@test "scenario_get_field() returns empty for missing optional field" {
  scenario_load "${FIXTURE_DIR}/minimal-scenario.yaml"
  local result
  result="$(scenario_get_field "hint")"
  [[ -z "${result}" || "${result}" == "null" ]]
}

# --- scenario_list() tests ---

@test "scenario_list() finds YAML files in scenarios directory" {
  local results
  results="$(scenario_list)"
  [[ -n "${results}" ]]
  [[ "${results}" == *"multi-container-pod.yaml"* ]]
}

# --- scenario_select() tests ---

@test "scenario_select() with --domain filters by domain" {
  local result
  result="$(scenario_select --domain 1)"
  [[ -n "${result}" ]]
}

@test "scenario_select() with invalid domain returns error" {
  run scenario_select --domain 9
  [[ "${status}" -ne 0 ]]
}

# --- Sourcing safety ---

@test "sourcing scenario.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/scenario.sh" 2>&1)"
  [[ -z "${output}" ]]
}

@test "scenario functions are defined" {
  declare -f scenario_load > /dev/null
  declare -f scenario_setup > /dev/null
  declare -f scenario_cleanup > /dev/null
  declare -f scenario_select > /dev/null
  declare -f scenario_get_field > /dev/null
  declare -f scenario_list > /dev/null
}
```

**Step 3: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/scenario.bats
```

Expected: FAIL — `lib/scenario.sh` doesn't exist yet.

**Step 4: Implement lib/scenario.sh**

Create `lib/scenario.sh`:
```bash
#!/usr/bin/env bash
# lib/scenario.sh — Scenario loading, lifecycle, and selection for ckad-drill
#
# Parses scenario YAML files via yq. Manages scenario setup/cleanup lifecycle.
# All output goes through display.sh functions.
#
# Public API:
#   scenario_load(file)                    — Parse YAML, populate SCENARIO_* vars
#   scenario_setup()                       — Create namespace, run setup commands
#   scenario_cleanup()                     — Delete namespace
#   scenario_get_field(field)              — Get raw field from loaded YAML
#   scenario_list()                        — List all scenario YAML files
#   scenario_select([--domain N] [--difficulty LEVEL]) — Pick a scenario

# ---------------------------------------------------------------------------
# Global state for loaded scenario
# ---------------------------------------------------------------------------
SCENARIO_FILE=""
SCENARIO_ID=""
SCENARIO_DOMAIN=""
SCENARIO_TITLE=""
SCENARIO_DIFFICULTY=""
SCENARIO_TIME_LIMIT=""
SCENARIO_NAMESPACE=""
SCENARIO_DESCRIPTION=""
SCENARIO_HINT=""
SCENARIO_SOLUTION=""
SCENARIO_LEARN=""
SCENARIO_CONCEPT_TEXT=""
SCENARIO_WEIGHT=""
SCENARIO_TAGS=""
SCENARIO_SETUP=""
SCENARIO_CLEANUP=""
SCENARIO_VALIDATIONS=""

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

_scenario_check_yq() {
  if ! command -v yq &>/dev/null; then
    error "yq is not installed. Install it: https://github.com/mikefarah/yq#install"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Scenario loading
# ---------------------------------------------------------------------------

scenario_load() {
  local file="${1}"

  if [[ ! -f "${file}" ]]; then
    error "Scenario file not found: ${file}"
    return 1
  fi

  _scenario_check_yq || return $?

  SCENARIO_FILE="${file}"

  # Parse required fields
  SCENARIO_ID="$(yq '.id // ""' "${file}")"
  SCENARIO_DOMAIN="$(yq '.domain // ""' "${file}")"
  SCENARIO_TITLE="$(yq '.title // ""' "${file}")"
  SCENARIO_DIFFICULTY="$(yq '.difficulty // ""' "${file}")"
  SCENARIO_TIME_LIMIT="$(yq '.time_limit // ""' "${file}")"
  SCENARIO_DESCRIPTION="$(yq '.description // ""' "${file}")"
  SCENARIO_SOLUTION="$(yq '.solution // ""' "${file}")"

  # Parse optional fields with defaults
  local raw_namespace
  raw_namespace="$(yq '.namespace // ""' "${file}")"
  if [[ -z "${raw_namespace}" ]]; then
    SCENARIO_NAMESPACE="drill-${SCENARIO_ID}"
  else
    SCENARIO_NAMESPACE="${raw_namespace}"
  fi

  SCENARIO_HINT="$(yq '.hint // ""' "${file}")"
  SCENARIO_LEARN="$(yq '.learn // false' "${file}")"
  SCENARIO_CONCEPT_TEXT="$(yq '.concept_text // ""' "${file}")"

  local raw_weight
  raw_weight="$(yq '.weight // ""' "${file}")"
  if [[ -z "${raw_weight}" ]]; then
    SCENARIO_WEIGHT="1"
  else
    SCENARIO_WEIGHT="${raw_weight}"
  fi

  # Parse arrays as JSON
  SCENARIO_TAGS="$(yq -o=json '.tags // []' "${file}")"
  SCENARIO_SETUP="$(yq -o=json '.setup // []' "${file}")"
  SCENARIO_CLEANUP="$(yq -o=json '.cleanup // []' "${file}")"
  SCENARIO_VALIDATIONS="$(yq -o=json '.validations // []' "${file}")"
}

# ---------------------------------------------------------------------------
# Field access
# ---------------------------------------------------------------------------

scenario_get_field() {
  local field="${1}"

  if [[ -z "${SCENARIO_FILE}" ]]; then
    error "No scenario loaded. Call scenario_load() first."
    return 1
  fi

  yq ".${field} // \"\"" "${SCENARIO_FILE}"
}

# ---------------------------------------------------------------------------
# Scenario lifecycle
# ---------------------------------------------------------------------------

scenario_setup() {
  if [[ -z "${SCENARIO_ID}" ]]; then
    error "No scenario loaded. Call scenario_load() first."
    return 1
  fi

  info "Setting up scenario: ${SCENARIO_TITLE}"

  # Create namespace
  if ! kubectl get namespace "${SCENARIO_NAMESPACE}" &>/dev/null; then
    kubectl create namespace "${SCENARIO_NAMESPACE}" &>/dev/null
    info "Created namespace: ${SCENARIO_NAMESPACE}"
  fi

  # Check for helm tag dependency
  local has_helm
  has_helm="$(echo "${SCENARIO_TAGS}" | jq 'index("helm") != null')"
  if [[ "${has_helm}" == "true" ]]; then
    if ! command -v helm &>/dev/null; then
      error "Helm is required for this scenario. Install Helm and try again."
      return 1
    fi
  fi

  # Run setup commands
  local cmd_count
  cmd_count="$(echo "${SCENARIO_SETUP}" | jq 'length')"
  if [[ "${cmd_count}" -gt 0 ]]; then
    local i
    for (( i = 0; i < cmd_count; i++ )); do
      local cmd
      cmd="$(echo "${SCENARIO_SETUP}" | jq -r ".[${i}]")"
      info "Running setup: ${cmd}"
      if ! eval "${cmd}" &>/dev/null; then
        warn "Setup command failed: ${cmd}"
      fi
    done
  fi

  pass "Scenario ready."
}

scenario_cleanup() {
  if [[ -z "${SCENARIO_ID}" ]]; then
    return 0
  fi

  info "Cleaning up scenario: ${SCENARIO_ID}"

  # Run custom cleanup commands
  local cmd_count
  cmd_count="$(echo "${SCENARIO_CLEANUP}" | jq 'length')"
  if [[ "${cmd_count}" -gt 0 ]]; then
    local i
    for (( i = 0; i < cmd_count; i++ )); do
      local cmd
      cmd="$(echo "${SCENARIO_CLEANUP}" | jq -r ".[${i}]")"
      eval "${cmd}" &>/dev/null || true
    done
  fi

  # Delete namespace (removes all resources in it)
  if kubectl get namespace "${SCENARIO_NAMESPACE}" &>/dev/null; then
    kubectl delete namespace "${SCENARIO_NAMESPACE}" --ignore-not-found &>/dev/null || true
    info "Deleted namespace: ${SCENARIO_NAMESPACE}"
  fi

  # Clear state
  _scenario_clear_state
}

_scenario_clear_state() {
  SCENARIO_FILE=""
  SCENARIO_ID=""
  SCENARIO_DOMAIN=""
  SCENARIO_TITLE=""
  SCENARIO_DIFFICULTY=""
  SCENARIO_TIME_LIMIT=""
  SCENARIO_NAMESPACE=""
  SCENARIO_DESCRIPTION=""
  SCENARIO_HINT=""
  SCENARIO_SOLUTION=""
  SCENARIO_LEARN=""
  SCENARIO_CONCEPT_TEXT=""
  SCENARIO_WEIGHT=""
  SCENARIO_TAGS=""
  SCENARIO_SETUP=""
  SCENARIO_CLEANUP=""
  SCENARIO_VALIDATIONS=""
}

# ---------------------------------------------------------------------------
# Scenario discovery and selection
# ---------------------------------------------------------------------------

scenario_list() {
  local search_dirs=()

  # Built-in scenarios
  if [[ -d "${CKAD_ROOT}/scenarios" ]]; then
    search_dirs+=("${CKAD_ROOT}/scenarios")
  fi

  # External scenarios path (if configured)
  if [[ -n "${CKAD_SCENARIOS_PATH:-}" ]] && [[ -d "${CKAD_SCENARIOS_PATH}" ]]; then
    search_dirs+=("${CKAD_SCENARIOS_PATH}")
  fi

  local dir
  for dir in "${search_dirs[@]}"; do
    find "${dir}" -name '*.yaml' -o -name '*.yml' | sort
  done
}

scenario_select() {
  local filter_domain=""
  local filter_difficulty=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --domain)
        filter_domain="${2}"
        if [[ "${filter_domain}" -lt 1 ]] || [[ "${filter_domain}" -gt 5 ]]; then
          error "Invalid domain: ${filter_domain}. Must be 1-5."
          return 1
        fi
        shift 2
        ;;
      --difficulty)
        filter_difficulty="${2}"
        if [[ "${filter_difficulty}" != "easy" ]] && \
           [[ "${filter_difficulty}" != "medium" ]] && \
           [[ "${filter_difficulty}" != "hard" ]]; then
          error "Invalid difficulty: ${filter_difficulty}. Must be easy/medium/hard."
          return 1
        fi
        shift 2
        ;;
      *)
        error "Unknown option: ${1}"
        return 1
        ;;
    esac
  done

  _scenario_check_yq || return $?

  local candidates=()
  local seen_ids=()
  local file

  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue

    local id domain difficulty
    id="$(yq '.id // ""' "${file}")"
    domain="$(yq '.domain // ""' "${file}")"
    difficulty="$(yq '.difficulty // ""' "${file}")"

    # Check for duplicate IDs
    local seen_id
    for seen_id in "${seen_ids[@]+"${seen_ids[@]}"}"; do
      if [[ "${seen_id}" == "${id}" ]]; then
        warn "Duplicate scenario ID '${id}' in ${file} — skipping (first-loaded wins)."
        continue 2
      fi
    done
    seen_ids+=("${id}")

    # Apply filters
    if [[ -n "${filter_domain}" ]] && [[ "${domain}" != "${filter_domain}" ]]; then
      continue
    fi
    if [[ -n "${filter_difficulty}" ]] && [[ "${difficulty}" != "${filter_difficulty}" ]]; then
      continue
    fi

    candidates+=("${file}")
  done < <(scenario_list)

  if [[ ${#candidates[@]} -eq 0 ]]; then
    error "No scenarios found matching filters."
    return 1
  fi

  # Random selection
  local index=$(( RANDOM % ${#candidates[@]} ))
  echo "${candidates[${index}]}"
}
```

**Step 5: Run tests to verify they pass**

```bash
bats test/unit/scenario.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck lib/scenario.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add lib/scenario.sh test/unit/scenario.bats test/helpers/fixtures/valid-scenario.yaml test/helpers/fixtures/minimal-scenario.yaml test/helpers/fixtures/learn-scenario.yaml
git commit -m "feat: implement lib/scenario.sh for scenario loading and lifecycle

scenario_load() parses YAML via yq into SCENARIO_* globals.
scenario_setup() creates namespace and runs setup commands.
scenario_cleanup() deletes namespace and clears state.
scenario_select() filters by domain/difficulty with random pick.
scenario_list() discovers built-in and external scenarios.
Includes bats unit tests and test fixture YAML files."
```

---

### Task 3: Implement Scenario Schema Validation (Story 3.3)

**Files:**
- Modify: `lib/scenario.sh` (add `scenario_validate()`)
- Create: `test/unit/schema-validation.bats`
- Create: `test/helpers/fixtures/invalid-domain.yaml`
- Create: `test/helpers/fixtures/invalid-difficulty.yaml`
- Create: `test/helpers/fixtures/invalid-time-limit.yaml`
- Create: `test/helpers/fixtures/missing-solution.yaml`
- Create: `test/helpers/fixtures/unknown-check-type.yaml`

**Step 1: Create invalid fixture files**

Create `test/helpers/fixtures/invalid-domain.yaml`:
```yaml
id: test-bad-domain
domain: 6
title: Invalid Domain
difficulty: easy
time_limit: 60
description: |
  This scenario has an invalid domain.
validations:
  - type: resource_exists
    resource: pod/test
    description: check
solution: |
  kubectl run test --image=nginx
```

Create `test/helpers/fixtures/invalid-difficulty.yaml`:
```yaml
id: test-bad-difficulty
domain: 1
title: Invalid Difficulty
difficulty: extreme
time_limit: 60
description: |
  This scenario has an invalid difficulty.
validations:
  - type: resource_exists
    resource: pod/test
    description: check
solution: |
  kubectl run test --image=nginx
```

Create `test/helpers/fixtures/invalid-time-limit.yaml`:
```yaml
id: test-bad-time
domain: 1
title: Invalid Time Limit
difficulty: easy
time_limit: -10
description: |
  This scenario has a negative time limit.
validations:
  - type: resource_exists
    resource: pod/test
    description: check
solution: |
  kubectl run test --image=nginx
```

Create `test/helpers/fixtures/missing-solution.yaml`:
```yaml
id: test-no-solution
domain: 1
title: Missing Solution
difficulty: easy
time_limit: 60
description: |
  This scenario has no solution field.
validations:
  - type: resource_exists
    resource: pod/test
    description: check
```

Create `test/helpers/fixtures/unknown-check-type.yaml`:
```yaml
id: test-bad-check
domain: 1
title: Unknown Check Type
difficulty: easy
time_limit: 60
description: |
  This scenario uses an unknown validation type.
validations:
  - type: pod_is_happy
    resource: pod/test
    description: check
solution: |
  kubectl run test --image=nginx
```

**Step 2: Write failing tests**

Create `test/unit/schema-validation.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/scenario.sh"
  FIXTURE_DIR="${CKAD_ROOT}/test/helpers/fixtures"
}

@test "scenario_validate() passes for valid scenario" {
  run scenario_validate "${FIXTURE_DIR}/valid-scenario.yaml"
  [[ "${status}" -eq 0 ]]
}

@test "scenario_validate() passes for minimal valid scenario" {
  run scenario_validate "${FIXTURE_DIR}/minimal-scenario.yaml"
  [[ "${status}" -eq 0 ]]
}

@test "scenario_validate() passes for learn scenario" {
  run scenario_validate "${FIXTURE_DIR}/learn-scenario.yaml"
  [[ "${status}" -eq 0 ]]
}

@test "scenario_validate() fails for invalid domain (6)" {
  run scenario_validate "${FIXTURE_DIR}/invalid-domain.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"domain must be 1-5"* ]]
}

@test "scenario_validate() fails for invalid difficulty (extreme)" {
  run scenario_validate "${FIXTURE_DIR}/invalid-difficulty.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"difficulty must be easy/medium/hard"* ]]
}

@test "scenario_validate() fails for negative time_limit" {
  run scenario_validate "${FIXTURE_DIR}/invalid-time-limit.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"time_limit must be positive"* ]]
}

@test "scenario_validate() fails for missing solution" {
  run scenario_validate "${FIXTURE_DIR}/missing-solution.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"solution is required"* ]]
}

@test "scenario_validate() fails for unknown validation type" {
  run scenario_validate "${FIXTURE_DIR}/unknown-check-type.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"unknown validation type"* ]]
}

@test "scenario_validate() fails for missing file" {
  run scenario_validate "${FIXTURE_DIR}/nonexistent.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"not found"* ]]
}

@test "scenario_validate() checks missing required field: id" {
  local tmpfile="${BATS_TEST_TMPDIR}/no-id.yaml"
  cat > "${tmpfile}" <<'YAML'
domain: 1
title: No ID
difficulty: easy
time_limit: 60
description: |
  Missing id field.
validations:
  - type: resource_exists
    resource: pod/test
    description: check
solution: |
  kubectl run test --image=nginx
YAML
  run scenario_validate "${tmpfile}"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"id"* ]]
  [[ "${output}" == *"required"* ]]
}
```

**Step 3: Run tests to verify they fail**

```bash
bats test/unit/schema-validation.bats
```

Expected: FAIL — `scenario_validate()` doesn't exist yet.

**Step 4: Add scenario_validate() to lib/scenario.sh**

Append the following to `lib/scenario.sh` (before the closing comments, after the `scenario_select()` function):

```bash
# ---------------------------------------------------------------------------
# Schema validation
# ---------------------------------------------------------------------------

# Valid typed check types (ADR-01)
SCENARIO_VALID_CHECK_TYPES=(
  "resource_exists"
  "resource_field"
  "container_count"
  "container_image"
  "container_env"
  "volume_mount"
  "container_running"
  "label_selector"
  "resource_count"
  "command_output"
)

scenario_validate() {
  local file="${1}"
  local errors=()

  if [[ ! -f "${file}" ]]; then
    error "Scenario file not found: ${file}"
    return 1
  fi

  _scenario_check_yq || return $?

  # --- Check required fields ---
  local required_fields=("id" "domain" "title" "difficulty" "time_limit" "description" "validations" "solution")
  local field
  for field in "${required_fields[@]}"; do
    local value
    value="$(yq ".${field} // \"\"" "${file}")"
    if [[ -z "${value}" ]]; then
      errors+=("${field} is required but missing or empty")
    fi
  done

  # If required fields are missing, report and exit early
  if [[ ${#errors[@]} -gt 0 ]]; then
    local err
    for err in "${errors[@]}"; do
      fail "${err}"
    done
    error "Schema validation failed for ${file}"
    return "${EXIT_PARSE_ERROR}"
  fi

  # --- Validate field values ---
  local domain
  domain="$(yq '.domain' "${file}")"
  if [[ "${domain}" -lt 1 ]] || [[ "${domain}" -gt 5 ]]; then
    errors+=("domain must be 1-5, got: ${domain}")
  fi

  local difficulty
  difficulty="$(yq '.difficulty' "${file}")"
  if [[ "${difficulty}" != "easy" ]] && \
     [[ "${difficulty}" != "medium" ]] && \
     [[ "${difficulty}" != "hard" ]]; then
    errors+=("difficulty must be easy/medium/hard, got: ${difficulty}")
  fi

  local time_limit
  time_limit="$(yq '.time_limit' "${file}")"
  if [[ "${time_limit}" -le 0 ]]; then
    errors+=("time_limit must be positive, got: ${time_limit}")
  fi

  # --- Validate solution is present and non-empty ---
  local solution
  solution="$(yq '.solution // ""' "${file}")"
  if [[ -z "${solution}" ]]; then
    errors+=("solution is required but missing or empty")
  fi

  # --- Validate validation types ---
  local validations_json
  validations_json="$(yq -o=json '.validations // []' "${file}")"
  local val_count
  val_count="$(echo "${validations_json}" | jq 'length')"

  if [[ "${val_count}" -eq 0 ]]; then
    errors+=("validations must contain at least one check")
  fi

  local i
  for (( i = 0; i < val_count; i++ )); do
    local check_type
    check_type="$(echo "${validations_json}" | jq -r ".[${i}].type // \"\"")"

    local valid=false
    local known_type
    for known_type in "${SCENARIO_VALID_CHECK_TYPES[@]}"; do
      if [[ "${check_type}" == "${known_type}" ]]; then
        valid=true
        break
      fi
    done

    if [[ "${valid}" == "false" ]]; then
      errors+=("unknown validation type: '${check_type}' — valid types: ${SCENARIO_VALID_CHECK_TYPES[*]}")
    fi
  done

  # --- Report results ---
  if [[ ${#errors[@]} -gt 0 ]]; then
    local err
    for err in "${errors[@]}"; do
      fail "${err}"
    done
    error "Schema validation failed for ${file}"
    return "${EXIT_PARSE_ERROR}"
  fi

  return 0
}
```

**Step 5: Run tests to verify they pass**

```bash
bats test/unit/schema-validation.bats
```

Expected: All PASS.

**Step 6: Run shellcheck**

```bash
shellcheck lib/scenario.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add lib/scenario.sh test/unit/schema-validation.bats test/helpers/fixtures/invalid-domain.yaml test/helpers/fixtures/invalid-difficulty.yaml test/helpers/fixtures/invalid-time-limit.yaml test/helpers/fixtures/missing-solution.yaml test/helpers/fixtures/unknown-check-type.yaml
git commit -m "feat: implement scenario_validate() for schema validation

Validates all required fields, domain range (1-5), difficulty values,
positive time_limit, solution presence, and typed check types against
the 10 known types from ADR-01. Reports all errors before failing.
Includes bats tests with valid and invalid fixture YAML files."
```

---

### Task 4: Implement lib/validator.sh — Core Validation Framework (Story 4.1)

**Files:**
- Create: `lib/validator.sh`
- Create: `test/unit/validator.bats`

**Step 1: Write failing tests**

Create `test/unit/validator.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
}

# --- Function existence ---

@test "validator functions are defined" {
  declare -f validator_run_checks > /dev/null
  declare -f validator_get_results > /dev/null
  declare -f validator_reset > /dev/null
}

@test "typed check functions are defined" {
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

# --- Result tracking ---

@test "validator_reset() clears results" {
  validator_reset
  local results
  results="$(validator_get_results)"
  local total
  total="$(echo "${results}" | jq '.total')"
  [[ "${total}" -eq 0 ]]
}

@test "validator_get_results() returns JSON with total, passed, failed" {
  validator_reset
  local results
  results="$(validator_get_results)"
  echo "${results}" | jq -e '.total' > /dev/null
  echo "${results}" | jq -e '.passed' > /dev/null
  echo "${results}" | jq -e '.failed' > /dev/null
}

@test "_validator_record_pass() increments passed count" {
  validator_reset
  _validator_record_pass "test check"
  local results
  results="$(validator_get_results)"
  local passed
  passed="$(echo "${results}" | jq '.passed')"
  [[ "${passed}" -eq 1 ]]
}

@test "_validator_record_fail() increments failed count" {
  validator_reset
  _validator_record_fail "test check" "expected X" "got Y"
  local results
  results="$(validator_get_results)"
  local failed
  failed="$(echo "${results}" | jq '.failed')"
  [[ "${failed}" -eq 1 ]]
}

@test "multiple records accumulate correctly" {
  validator_reset
  _validator_record_pass "check 1"
  _validator_record_pass "check 2"
  _validator_record_fail "check 3" "expected A" "got B"
  local results
  results="$(validator_get_results)"
  [[ "$(echo "${results}" | jq '.total')" -eq 3 ]]
  [[ "$(echo "${results}" | jq '.passed')" -eq 2 ]]
  [[ "$(echo "${results}" | jq '.failed')" -eq 1 ]]
}

# --- Dispatch ---

@test "validator_run_checks() handles unknown type gracefully" {
  validator_reset
  local validations='[{"type":"nonexistent_type","description":"bad check"}]'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    validator_run_checks 'test-ns' '${validations}'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"unknown validation type"* ]]
}

@test "validator_run_checks() processes checks in order" {
  validator_reset
  # This tests dispatch logic with a known type that will fail (no cluster)
  local validations='[{"type":"resource_exists","resource":"pod/fake","description":"check 1"},{"type":"resource_exists","resource":"pod/fake2","description":"check 2"}]'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    validator_run_checks 'test-ns' '${validations}'
    validator_get_results
  "
  # Should have processed both checks (both will fail without cluster)
  [[ "${output}" == *"check 1"* ]]
  [[ "${output}" == *"check 2"* ]]
}

# --- Sourcing safety ---

@test "sourcing validator.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/validator.sh" 2>&1)"
  [[ -z "${output}" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/validator.bats
```

Expected: FAIL — `lib/validator.sh` doesn't exist yet.

**Step 3: Implement lib/validator.sh**

Create `lib/validator.sh`:
```bash
#!/usr/bin/env bash
# lib/validator.sh — Validation engine for ckad-drill
#
# Dispatches typed validation checks against a live Kubernetes cluster
# and aggregates pass/fail results. All cluster queries use kubectl.
#
# ADR-07: Single check, no retry. Each validation runs once.
# ADR-01: 10 typed checks + command_output escape hatch.
#
# Public API:
#   validator_run_checks(namespace, validations_json)  — Run all checks
#   validator_get_results()                            — Get JSON summary
#   validator_reset()                                  — Clear results

# ---------------------------------------------------------------------------
# Result tracking state
# ---------------------------------------------------------------------------
_VALIDATOR_TOTAL=0
_VALIDATOR_PASSED=0
_VALIDATOR_FAILED=0

# ---------------------------------------------------------------------------
# Result recording (private)
# ---------------------------------------------------------------------------

_validator_record_pass() {
  local description="${1}"
  pass "${description}"
  (( _VALIDATOR_TOTAL++ )) || true
  (( _VALIDATOR_PASSED++ )) || true
}

_validator_record_fail() {
  local description="${1}"
  local expected="${2:-}"
  local actual="${3:-}"
  if [[ -n "${expected}" ]] && [[ -n "${actual}" ]]; then
    fail "${description}: expected '${expected}', got '${actual}'"
  else
    fail "${description}"
  fi
  (( _VALIDATOR_TOTAL++ )) || true
  (( _VALIDATOR_FAILED++ )) || true
}

# ---------------------------------------------------------------------------
# Public: result management
# ---------------------------------------------------------------------------

validator_reset() {
  _VALIDATOR_TOTAL=0
  _VALIDATOR_PASSED=0
  _VALIDATOR_FAILED=0
}

validator_get_results() {
  printf '{"total":%d,"passed":%d,"failed":%d}\n' \
    "${_VALIDATOR_TOTAL}" "${_VALIDATOR_PASSED}" "${_VALIDATOR_FAILED}"
}

# ---------------------------------------------------------------------------
# Public: run checks
# ---------------------------------------------------------------------------

validator_run_checks() {
  local namespace="${1}"
  local validations_json="${2}"

  validator_reset

  local check_count
  check_count="$(echo "${validations_json}" | jq 'length')"

  local i
  for (( i = 0; i < check_count; i++ )); do
    local check_json
    check_json="$(echo "${validations_json}" | jq ".[${i}]")"

    local check_type
    check_type="$(echo "${check_json}" | jq -r '.type // ""')"

    local description
    description="$(echo "${check_json}" | jq -r '.description // "check"')"

    case "${check_type}" in
      resource_exists)    _validator_check_resource_exists    "${namespace}" "${check_json}" "${description}" ;;
      resource_field)     _validator_check_resource_field     "${namespace}" "${check_json}" "${description}" ;;
      container_count)    _validator_check_container_count    "${namespace}" "${check_json}" "${description}" ;;
      container_image)    _validator_check_container_image    "${namespace}" "${check_json}" "${description}" ;;
      container_env)      _validator_check_container_env      "${namespace}" "${check_json}" "${description}" ;;
      volume_mount)       _validator_check_volume_mount       "${namespace}" "${check_json}" "${description}" ;;
      container_running)  _validator_check_container_running  "${namespace}" "${check_json}" "${description}" ;;
      label_selector)     _validator_check_label_selector     "${namespace}" "${check_json}" "${description}" ;;
      resource_count)     _validator_check_resource_count     "${namespace}" "${check_json}" "${description}" ;;
      command_output)     _validator_check_command_output     "${namespace}" "${check_json}" "${description}" ;;
      *)
        _validator_record_fail "unknown validation type: '${check_type}'"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Typed check implementations (private)
# ---------------------------------------------------------------------------

# --- resource_exists ---
# Checks: kubectl get <kind>/<name> -n <namespace>
_validator_check_resource_exists() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"

  if kubectl get "${resource}" -n "${namespace}" &>/dev/null; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "resource ${resource} to exist" "not found"
  fi
}

# --- resource_field ---
# Checks: kubectl get <kind>/<name> -n <namespace> -o jsonpath=<jsonpath>
_validator_check_resource_field() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource jsonpath expected
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  jsonpath="$(echo "${check_json}" | jq -r '.jsonpath // ""')"
  expected="$(echo "${check_json}" | jq -r '.expected // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" -o jsonpath="${jsonpath}" 2>/dev/null)" || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "${expected}" "${actual}"
  fi
}

# --- container_count ---
# Checks: number of containers in pod spec
_validator_check_container_count() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource expected
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  expected="$(echo "${check_json}" | jq -r '.expected // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" \
    -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)" || actual=""

  # Count space-separated names
  local count=0
  if [[ -n "${actual}" ]]; then
    count="$(echo "${actual}" | wc -w | tr -d ' ')"
  fi

  if [[ "${count}" -eq "${expected}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "${expected} containers" "${count} containers"
  fi
}

# --- container_image ---
# Checks: image of a named container
_validator_check_container_image() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource container expected
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  container="$(echo "${check_json}" | jq -r '.container // ""')"
  expected="$(echo "${check_json}" | jq -r '.expected // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" \
    -o jsonpath="{.spec.containers[?(@.name==\"${container}\")].image}" 2>/dev/null)" || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "${expected}" "${actual}"
  fi
}

# --- container_env ---
# Checks: env var value in a named container
_validator_check_container_env() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource container env_name expected
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  container="$(echo "${check_json}" | jq -r '.container // ""')"
  env_name="$(echo "${check_json}" | jq -r '.env_name // ""')"
  expected="$(echo "${check_json}" | jq -r '.expected // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" \
    -o jsonpath="{.spec.containers[?(@.name==\"${container}\")].env[?(@.name==\"${env_name}\")].value}" 2>/dev/null)" || actual=""

  if [[ "${actual}" == "${expected}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "${expected}" "${actual}"
  fi
}

# --- volume_mount ---
# Checks: mount path exists in a named container
_validator_check_volume_mount() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource container mount_path
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  container="$(echo "${check_json}" | jq -r '.container // ""')"
  mount_path="$(echo "${check_json}" | jq -r '.mount_path // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" \
    -o jsonpath="{.spec.containers[?(@.name==\"${container}\")].volumeMounts[?(@.mountPath==\"${mount_path}\")].mountPath}" 2>/dev/null)" || actual=""

  if [[ "${actual}" == "${mount_path}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "mount at ${mount_path}" "not found"
  fi
}

# --- container_running ---
# Checks: container status is Running
_validator_check_container_running() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource container
  resource="$(echo "${check_json}" | jq -r '.resource // ""')"
  container="$(echo "${check_json}" | jq -r '.container // ""')"

  local actual
  actual="$(kubectl get "${resource}" -n "${namespace}" \
    -o jsonpath="{.status.containerStatuses[?(@.name==\"${container}\")].state}" 2>/dev/null)" || actual=""

  if [[ "${actual}" == *"running"* ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "container '${container}' running" "not running"
  fi
}

# --- label_selector ---
# Checks: kubectl get <type> -l <labels> returns results
_validator_check_label_selector() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource_type labels
  resource_type="$(echo "${check_json}" | jq -r '.resource_type // ""')"
  labels="$(echo "${check_json}" | jq -r '.labels // ""')"

  local result
  result="$(kubectl get "${resource_type}" -l "${labels}" -n "${namespace}" \
    --no-headers 2>/dev/null)" || result=""

  if [[ -n "${result}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "resources matching ${labels}" "none found"
  fi
}

# --- resource_count ---
# Checks: count of resources matching a selector
_validator_check_resource_count() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local resource_type selector expected
  resource_type="$(echo "${check_json}" | jq -r '.resource_type // ""')"
  selector="$(echo "${check_json}" | jq -r '.selector // ""')"
  expected="$(echo "${check_json}" | jq -r '.expected // ""')"

  local actual
  actual="$(kubectl get "${resource_type}" -l "${selector}" -n "${namespace}" \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')" || actual="0"

  if [[ "${actual}" -eq "${expected}" ]]; then
    _validator_record_pass "${description}"
  else
    _validator_record_fail "${description}" "${expected}" "${actual}"
  fi
}

# --- command_output ---
# Checks: run arbitrary command, check output with contains/matches/equals
_validator_check_command_output() {
  local namespace="${1}"
  local check_json="${2}"
  local description="${3}"

  local cmd
  cmd="$(echo "${check_json}" | jq -r '.command // ""')"

  # Replace $NAMESPACE placeholder if present
  cmd="${cmd//\$NAMESPACE/${namespace}}"

  local actual
  actual="$(eval "${cmd}" 2>/dev/null)" || actual=""

  # Determine check mode
  local contains matches equals
  contains="$(echo "${check_json}" | jq -r '.contains // ""')"
  matches="$(echo "${check_json}" | jq -r '.matches // ""')"
  equals="$(echo "${check_json}" | jq -r '.equals // ""')"

  if [[ -n "${contains}" ]]; then
    if [[ "${actual}" == *"${contains}"* ]]; then
      _validator_record_pass "${description}"
    else
      _validator_record_fail "${description}" "output containing '${contains}'" "'${actual}'"
    fi
  elif [[ -n "${matches}" ]]; then
    if [[ "${actual}" =~ ${matches} ]]; then
      _validator_record_pass "${description}"
    else
      _validator_record_fail "${description}" "output matching '${matches}'" "'${actual}'"
    fi
  elif [[ -n "${equals}" ]]; then
    if [[ "${actual}" == "${equals}" ]]; then
      _validator_record_pass "${description}"
    else
      _validator_record_fail "${description}" "'${equals}'" "'${actual}'"
    fi
  else
    _validator_record_fail "${description}: command_output requires one of: contains, matches, equals"
  fi
}
```

**Step 4: Run tests to verify they pass**

```bash
bats test/unit/validator.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/validator.sh
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add lib/validator.sh test/unit/validator.bats
git commit -m "feat: implement lib/validator.sh core validation framework

validator_run_checks() dispatches typed checks and aggregates results.
validator_get_results() returns JSON summary (total/passed/failed).
Gracefully handles unknown types without crashing.
Includes 10 stub typed check functions for Story 4.2.
ADR-07: single check, no retry. Includes bats unit tests."
```

---

### Task 5: Implement Typed Validation Checks (Story 4.2)

**Files:**
- Modify: `test/unit/validator.bats` (add typed check parsing tests)
- Create: `test/unit/validator-checks.bats`

Note: The 10 typed check implementations were included in Task 4 since the framework and checks are tightly coupled. This task adds thorough unit tests for each typed check's parameter parsing and dispatch logic.

**Step 1: Write tests for each typed check**

Create `test/unit/validator-checks.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/validator.sh"
}

# ---------------------------------------------------------------------------
# These tests verify check dispatch and parameter parsing.
# Checks will fail because there's no cluster, but they should NOT crash.
# Integration tests (Sprint 2+) will test against a real cluster.
# ---------------------------------------------------------------------------

# --- resource_exists ---

@test "resource_exists dispatches without crash" {
  validator_reset
  local check='{"type":"resource_exists","resource":"pod/test-pod","description":"pod exists"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_resource_exists 'default' '${check}' 'pod exists'
  "
  # Should not crash — will fail due to no cluster, but that's expected
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"pod exists"* ]]
}

# --- resource_field ---

@test "resource_field dispatches without crash" {
  validator_reset
  local check='{"type":"resource_field","resource":"pod/test-pod","jsonpath":"{.spec.nodeName}","expected":"node1","description":"field check"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_resource_field 'default' '${check}' 'field check'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"field check"* ]]
}

# --- container_count ---

@test "container_count dispatches without crash" {
  validator_reset
  local check='{"type":"container_count","resource":"pod/test-pod","expected":"2","description":"has 2 containers"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_container_count 'default' '${check}' 'has 2 containers'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"has 2 containers"* ]]
}

# --- container_image ---

@test "container_image dispatches without crash" {
  validator_reset
  local check='{"type":"container_image","resource":"pod/test-pod","container":"nginx","expected":"nginx:1.25","description":"correct image"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_container_image 'default' '${check}' 'correct image'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"correct image"* ]]
}

# --- container_env ---

@test "container_env dispatches without crash" {
  validator_reset
  local check='{"type":"container_env","resource":"pod/test-pod","container":"app","env_name":"DB_HOST","expected":"localhost","description":"env var set"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_container_env 'default' '${check}' 'env var set'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"env var set"* ]]
}

# --- volume_mount ---

@test "volume_mount dispatches without crash" {
  validator_reset
  local check='{"type":"volume_mount","resource":"pod/test-pod","container":"app","mount_path":"/data","description":"mount exists"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_volume_mount 'default' '${check}' 'mount exists'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"mount exists"* ]]
}

# --- container_running ---

@test "container_running dispatches without crash" {
  validator_reset
  local check='{"type":"container_running","resource":"pod/test-pod","container":"app","description":"container running"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_container_running 'default' '${check}' 'container running'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"container running"* ]]
}

# --- label_selector ---

@test "label_selector dispatches without crash" {
  validator_reset
  local check='{"type":"label_selector","resource_type":"pod","labels":"app=web","description":"labeled pods exist"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_label_selector 'default' '${check}' 'labeled pods exist'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"labeled pods exist"* ]]
}

# --- resource_count ---

@test "resource_count dispatches without crash" {
  validator_reset
  local check='{"type":"resource_count","resource_type":"pod","selector":"app=web","expected":"3","description":"3 pods running"}'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    _validator_check_resource_count 'default' '${check}' '3 pods running'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"3 pods running"* ]]
}

# --- command_output (contains) ---

@test "command_output with contains dispatches correctly" {
  validator_reset
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    local check='{\"type\":\"command_output\",\"command\":\"echo hello world\",\"contains\":\"hello\",\"description\":\"output check\"}'
    _validator_check_command_output 'default' \"\${check}\" 'output check'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"output check"* ]]
  # echo hello world contains "hello" — should pass
  [[ "${output}" != *"expected"* ]]
}

# --- command_output (equals) ---

@test "command_output with equals dispatches correctly" {
  validator_reset
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    local check='{\"type\":\"command_output\",\"command\":\"echo -n exact\",\"equals\":\"exact\",\"description\":\"exact match\"}'
    _validator_check_command_output 'default' \"\${check}\" 'exact match'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"exact match"* ]]
}

# --- command_output (matches) ---

@test "command_output with matches dispatches correctly" {
  validator_reset
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    local check='{\"type\":\"command_output\",\"command\":\"echo abc123\",\"matches\":\"^abc[0-9]+$\",\"description\":\"regex match\"}'
    _validator_check_command_output 'default' \"\${check}\" 'regex match'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"regex match"* ]]
}

# --- command_output (missing condition) ---

@test "command_output without condition records failure" {
  validator_reset
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    local check='{\"type\":\"command_output\",\"command\":\"echo test\",\"description\":\"no condition\"}'
    _validator_check_command_output 'default' \"\${check}\" 'no condition'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"requires one of"* ]]
}

# --- command_output ($NAMESPACE substitution) ---

@test "command_output substitutes \$NAMESPACE placeholder" {
  validator_reset
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    local check='{\"type\":\"command_output\",\"command\":\"echo \$NAMESPACE\",\"equals\":\"my-ns\",\"description\":\"ns substitution\"}'
    _validator_check_command_output 'my-ns' \"\${check}\" 'ns substitution'
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"ns substitution"* ]]
}

# --- Full dispatch via validator_run_checks ---

@test "validator_run_checks dispatches all 10 types without crash" {
  local validations='[
    {"type":"resource_exists","resource":"pod/t","description":"c1"},
    {"type":"resource_field","resource":"pod/t","jsonpath":"{.x}","expected":"y","description":"c2"},
    {"type":"container_count","resource":"pod/t","expected":"1","description":"c3"},
    {"type":"container_image","resource":"pod/t","container":"c","expected":"img","description":"c4"},
    {"type":"container_env","resource":"pod/t","container":"c","env_name":"K","expected":"V","description":"c5"},
    {"type":"volume_mount","resource":"pod/t","container":"c","mount_path":"/m","description":"c6"},
    {"type":"container_running","resource":"pod/t","container":"c","description":"c7"},
    {"type":"label_selector","resource_type":"pod","labels":"a=b","description":"c8"},
    {"type":"resource_count","resource_type":"pod","selector":"a=b","expected":"1","description":"c9"},
    {"type":"command_output","command":"echo hi","contains":"hi","description":"c10"}
  ]'
  run bash -c "
    source '${CKAD_ROOT}/lib/common.sh'
    source '${CKAD_ROOT}/lib/display.sh'
    source '${CKAD_ROOT}/lib/validator.sh'
    validator_run_checks 'default' '$(echo "${validations}" | tr -d '\n')'
    validator_get_results
  "
  [[ "${status}" -eq 0 ]]
  # All 10 checks should have been processed
  [[ "${output}" == *'"total":10'* ]]
}
```

**Step 2: Run tests to verify they pass**

```bash
bats test/unit/validator-checks.bats
```

Expected: All PASS. (The typed check implementations from Task 4 are already in place.)

**Step 3: Run shellcheck on everything**

```bash
shellcheck lib/validator.sh lib/scenario.sh
```

Expected: No warnings.

**Step 4: Commit**

```bash
git add test/unit/validator-checks.bats
git commit -m "test: add comprehensive unit tests for all 10 typed validation checks

Tests each check type's dispatch, parameter parsing, and graceful
failure without a cluster. Tests command_output contains/matches/equals
modes, \$NAMESPACE substitution, and missing condition handling.
Verifies all 10 types dispatch without crash via validator_run_checks."
```

---

### Task 6: Wire scenario.sh and validator.sh into bin/ckad-drill

**Files:**
- Modify: `bin/ckad-drill`
- Modify: `test/unit/cli.bats`

**Step 1: Update bin/ckad-drill to source new libs**

Add the new source lines to `bin/ckad-drill` after the existing source lines:

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
source "${CKAD_ROOT}/lib/scenario.sh"
source "${CKAD_ROOT}/lib/validator.sh"

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

Scenario Tools:
  validate-scenario <file|dir>   Validate scenario YAML

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

cmd_validate_scenario() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    error "Usage: ckad-drill validate-scenario <file|dir>"
    return 1
  fi

  if [[ -d "${target}" ]]; then
    local file
    local total=0
    local passed=0
    local failed=0
    while IFS= read -r file; do
      (( total++ )) || true
      info "Validating: ${file}"
      if scenario_validate "${file}"; then
        pass "PASS: ${file}"
        (( passed++ )) || true
      else
        (( failed++ )) || true
      fi
    done < <(find "${target}" -name '*.yaml' -o -name '*.yml' | sort)
    echo ""
    info "Results: ${passed}/${total} passed, ${failed} failed"
    if [[ "${failed}" -gt 0 ]]; then
      return 1
    fi
  elif [[ -f "${target}" ]]; then
    if scenario_validate "${target}"; then
      pass "PASS: scenario validated successfully"
    else
      return 1
    fi
  else
    error "Not a file or directory: ${target}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

main() {
  local command="${1:-}"

  case "${command}" in
    start)              cmd_start ;;
    stop)               cmd_stop ;;
    reset)              cmd_reset ;;
    validate-scenario)  shift; cmd_validate_scenario "$@" ;;
    --help)             _usage ;;
    --version)          echo "ckad-drill 0.1.0-dev" ;;
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

**Step 2: Update CLI tests**

Add to `test/unit/cli.bats`:
```bash
@test "ckad-drill validate-scenario with no args shows error" {
  run ckad-drill validate-scenario
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"Usage"* ]]
}

@test "ckad-drill validate-scenario with valid file passes" {
  run ckad-drill validate-scenario "${CKAD_ROOT}/test/helpers/fixtures/valid-scenario.yaml"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"PASS"* ]]
}

@test "ckad-drill validate-scenario with invalid file fails" {
  run ckad-drill validate-scenario "${CKAD_ROOT}/test/helpers/fixtures/invalid-domain.yaml"
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"domain must be 1-5"* ]]
}

@test "ckad-drill validate-scenario with directory validates all files" {
  run ckad-drill validate-scenario "${CKAD_ROOT}/scenarios/domain-1"
  [[ "${output}" == *"Results:"* ]]
}
```

**Step 3: Run tests**

```bash
bats test/unit/cli.bats
```

Expected: All PASS.

**Step 4: Run shellcheck on everything**

```bash
shellcheck bin/ckad-drill lib/*.sh
```

Expected: No warnings.

**Step 5: Commit**

```bash
git add bin/ckad-drill test/unit/cli.bats
git commit -m "feat: wire scenario.sh and validator.sh into CLI entry point

bin/ckad-drill now sources scenario.sh and validator.sh. Adds
validate-scenario subcommand that runs schema validation on a
single file or all YAML files in a directory. Includes CLI tests."
```

---

### Task 7: Update Makefile and run full test suite

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile SCRIPTS list**

Replace the SCRIPTS line in the Makefile:
```makefile
SCRIPTS := bin/ckad-drill $(wildcard lib/*.sh) $(wildcard scripts/*.sh)
```

(This should already be correct from Sprint 1. Verify it picks up the new lib files.)

**Step 2: Run full test suite**

```bash
make test
```

Expected: shellcheck passes for all files including new `lib/scenario.sh` and `lib/validator.sh`. All unit tests pass:
- `test/unit/common.bats`
- `test/unit/display.bats`
- `test/unit/cluster.bats`
- `test/unit/cluster-setup.bats`
- `test/unit/cli.bats`
- `test/unit/scenario.bats`
- `test/unit/schema-validation.bats`
- `test/unit/validator.bats`
- `test/unit/validator-checks.bats`

**Step 3: Remove .gitkeep files from directories that now have content**

```bash
rm -f scenarios/domain-1/.gitkeep test/helpers/fixtures/.gitkeep
```

(Only remove if these files exist and directories now have real content.)

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: clean up gitkeep files, verify full test suite passes

All Sprint 2 deliverables verified: lib/scenario.sh, lib/validator.sh,
scenario YAML schema, reference scenario, and schema validation.
shellcheck and bats unit tests all pass."
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 3.1 | `docs/scenario-schema.md`, `scenarios/domain-1/multi-container-pod.yaml` | — |
| 2 | 3.2 | `lib/scenario.sh` (load, setup, cleanup, select, list) | `test/unit/scenario.bats` |
| 3 | 3.3 | `scenario_validate()` in `lib/scenario.sh` | `test/unit/schema-validation.bats` |
| 4 | 4.1 | `lib/validator.sh` (framework + dispatch + results) | `test/unit/validator.bats` |
| 5 | 4.2 | 10 typed validation checks in `lib/validator.sh` | `test/unit/validator-checks.bats` |
| 6 | 5.1 (partial) | `bin/ckad-drill` updated with `validate-scenario` subcommand | `test/unit/cli.bats` |
| 7 | — | Makefile cleanup, full test suite verification | `make test` |

**After Sprint 2:** Scenarios can be loaded from YAML, validated against the schema, and checked against a live cluster using 10 typed validation checks. The `ckad-drill validate-scenario` subcommand works. Foundation is ready for Sprint 3 (CLI + Drill Mode + Timer + Progress).

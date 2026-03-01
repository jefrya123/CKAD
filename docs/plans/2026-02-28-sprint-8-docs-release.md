# Sprint 8: Documentation & Content Gap — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Write README.md and CONTRIBUTING.md, author net-new scenarios to reach the 70+ launch target (NFR-06), and cut V1.0 release.

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
- Scenario IDs: descriptive hyphenated (e.g., `configmap-env-injection`), `learn-` prefix for learn mode, `debug-` prefix for debug scenarios
- Namespace names: lowercase with hyphens, realistic names per ADR-06

---

### Task 1: Write README.md (Story 12.1)

**Files:**
- Create: `README.md`

**Step 1: Write README.md**

Create `README.md` with the following complete content:

```markdown
# ckad-drill

**Free, open-source CKAD exam trainer with real-cluster validation.**

Stop practicing Kubernetes in your head. ckad-drill runs exam-style scenarios against a real kind cluster, validates your work with kubectl checks, and builds you from guided tutorials to full mock exams — all in your terminal, all for free.

## The Problem

Preparing for the CKAD exam means practicing real Kubernetes tasks under time pressure against a real cluster. Today, your options are:

- **killer.sh** — 2 sessions for $36, not repeatable, no learning progression
- **Random GitHub repos** — static markdown with solutions you can peek at, no validation
- **Your own kind cluster** — you do the task but have no way to verify you got it right

There is no free, open-source tool that combines progressive learning with real-cluster validation under exam-like time constraints.

## How ckad-drill Is Different

| Feature | killer.sh | kodekloud | CKAD-exercises (GitHub) | **ckad-drill** |
|---------|-----------|-----------|-------------------------|----------------|
| Real cluster validation | Yes | Yes | No | **Yes** |
| Free | No ($36) | No (subscription) | Yes | **Yes** |
| Unlimited practice | No (2 sessions) | Yes | Yes | **Yes** |
| Progressive learning | No | Yes | No | **Yes** |
| Offline capable | No | No | Yes | **Yes** |
| Open source | No | No | Yes | **Yes** |

## Quick Start

Three commands from zero to your first drill:

```bash
# 1. Install ckad-drill and dependencies
curl -sSL https://raw.githubusercontent.com/<repo>/main/scripts/install.sh | sh

# 2. Create a kind cluster with CKAD exam addons
ckad-drill start

# 3. Start your first drill
ckad-drill drill
```

The cluster comes pre-configured with Calico CNI, nginx ingress, and metrics-server — matching the real CKAD exam environment.

## Demo

```
────────────────────────────────────────────────────────
  Domain 4: Config & Security — configmap-env-injection
────────────────────────────────────────────────────────

  Create a ConfigMap named `app-config` in namespace `config-lab` with:
    DB_HOST=postgres.db.svc.cluster.local
    DB_PORT=5432

  Then create a Pod named `app-server` using image `busybox` that:
  1. Loads ALL keys from `app-config` as environment variables
  2. Runs: env | sort

  Time limit: 180s

[03:00] $ kubectl create configmap app-config --from-literal=DB_HOST=postgres.db.svc.cluster.local ...
[02:34] $ vim pod.yaml
[01:45] $ kubectl apply -f pod.yaml
[01:12] $ ckad-drill check

✅ configmap/app-config exists
✅ pod/app-server exists
✅ app-server container image is busybox
✅ envFrom references app-config
✅ All checks passed!
```

## Three Modes

### Learn Mode — Guided tutorials with real practice

Progressive lessons organized by CKAD domain. Each lesson explains a concept, shows a reference example, then gives you hands-on exercises with validation.

```bash
ckad-drill learn              # List all domains and lessons
ckad-drill learn --domain 1   # Start domain 1: Application Design & Build
```

### Drill Mode — Exam-style scenarios with immediate feedback

Single timed scenarios (3-8 minutes each), just like the real exam. Work in your terminal, check when ready.

```bash
ckad-drill drill                       # Random scenario
ckad-drill drill --domain 4            # Domain 4: Config & Security
ckad-drill drill --difficulty hard     # Hard scenarios only
```

### Exam Mode — Full mock exam simulation

15-20 questions, 2-hour timer, domain-weighted selection matching real CKAD percentages. No hints, no solutions — just like exam day.

```bash
ckad-drill exam                # Full 2-hour mock exam
ckad-drill exam --time 60m    # Shorter practice exam
ckad-drill exam list           # See all questions with status
ckad-drill exam submit         # Grade and see results
```

## Features

- **70+ scenarios** across all 5 CKAD domains
- **Real cluster validation** — kubectl checks against live Kubernetes resources
- **Exam-matched environment** — Calico, ingress, metrics-server, strict `k` alias only (ADR-03)
- **Countdown timer** in your bash prompt via PROMPT_COMMAND
- **Progress tracking** — per-domain stats, exam history, weak-area recommendations
- **Debug scenarios** — diagnose and fix broken resources
- **Helm scenarios** — deploy and manage Helm releases
- **Offline capable** — everything runs locally after install
- **Scenario validation tool** — contributors can test scenarios end-to-end

## CKAD Domain Coverage

| Domain | Exam Weight | Scenarios | Topics |
|--------|-------------|-----------|--------|
| 1. Application Design & Build | 20% | 14+ | Pods, multi-container, init containers, jobs, CronJobs, PVCs |
| 2. Application Deployment | 20% | 14+ | Deployments, rollouts, Helm, scaling, blue-green, canary |
| 3. Application Observability & Maintenance | 15% | 14+ | Probes, logging, debugging, metrics, resource monitoring |
| 4. Application Environment, Config & Security | 25% | 14+ | ConfigMaps, Secrets, RBAC, SecurityContext, quotas, ServiceAccounts |
| 5. Services & Networking | 20% | 14+ | Services, Ingress, NetworkPolicy, DNS, endpoint management |

## All Commands

```
Cluster Management:
  ckad-drill start             Create kind cluster and install addons
  ckad-drill stop              Delete kind cluster
  ckad-drill reset             Recreate kind cluster from scratch

Practice:
  ckad-drill drill [opts]      Start a drill scenario
  ckad-drill check             Validate your work on the current scenario
  ckad-drill hint              Show hint for current scenario
  ckad-drill solution          Show solution for current scenario
  ckad-drill next              Clean up and load next scenario
  ckad-drill skip              Skip current scenario without checking
  ckad-drill current           Reprint current scenario task

Learn Mode:
  ckad-drill learn [opts]      Start guided learning by domain

Exam Mode:
  ckad-drill exam [opts]       Start a mock exam session
  ckad-drill exam list         Show all questions with status
  ckad-drill exam next/prev    Navigate questions
  ckad-drill exam jump N       Jump to question N
  ckad-drill exam flag         Flag current question for review
  ckad-drill exam submit       End exam and see results

Progress:
  ckad-drill status            Show progress dashboard
  ckad-drill timer             Show remaining time

Tools:
  ckad-drill validate-scenario <file|dir>   Validate scenario YAML

Options:
  --help                       Show help
  --version                    Show version
```

## Timer Setup

For the countdown timer in your prompt, source the environment:

```bash
source <(ckad-drill env)       # Adds [MM:SS] countdown to your prompt
source <(ckad-drill env --reset)  # Restore original prompt
```

## Progress Dashboard

```bash
$ ckad-drill status

  CKAD Progress
  ──────────────────────────────────────────────
  Domain 1: Design & Build (20%)     ████████░░  14/20  80%
  Domain 2: Deployment (20%)         ██████░░░░   9/15  60%
  Domain 3: Observability (15%)      ████░░░░░░   5/12  42%
  Domain 4: Config & Security (25%)  ███░░░░░░░   4/18  22%
  Domain 5: Networking (20%)         ██░░░░░░░░   3/16  19%
  ──────────────────────────────────────────────
  Mock Exams: 2 taken, avg 58%  (need 66% to pass)
  Weakest: Domain 4 — try: ckad-drill drill --domain 4
  Streak: 3 days
```

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| Docker | Yes | Required by kind |
| kubectl | Yes | The tool you are practicing with |
| kind | Yes | Auto-installed by install script |
| yq | Yes | Auto-installed by install script |
| jq | Yes | Auto-installed by install script |
| Helm | Optional | Only needed for Helm-specific scenarios |
| bash | Yes | 4.0+ (macOS: install via brew) |

## Contributing

ckad-drill scenarios are YAML files — easy to write, easy to test. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on writing and validating new scenarios.

## License

MIT License. See [LICENSE](LICENSE).
```

**Step 2: Verify no broken formatting**

Review the file visually. Ensure:
- All markdown code blocks are properly closed
- The nested code block in Quick Start uses proper escaping
- The comparison table renders correctly
- All internal links point to real files

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: write README.md with install, features, and competitive comparison

Problem statement, 3-command quick start, demo walkthrough,
three mode descriptions, full command reference, progress dashboard,
domain coverage table, and competitive comparison from PRD."
```

---

### Task 2: Write CONTRIBUTING.md (Story 12.2)

**Files:**
- Create: `CONTRIBUTING.md`

**Step 1: Write CONTRIBUTING.md**

Create `CONTRIBUTING.md` with the following complete content:

```markdown
# Contributing to ckad-drill

Thank you for contributing to ckad-drill! The most impactful contribution is **new scenarios** — every YAML file you add gives CKAD candidates another practice opportunity.

## Table of Contents

- [Writing a Scenario](#writing-a-scenario)
- [Scenario YAML Schema](#scenario-yaml-schema)
- [Naming Conventions](#naming-conventions)
- [Validation Types Reference](#validation-types-reference)
- [Testing Your Scenario](#testing-your-scenario)
- [PR Checklist](#pr-checklist)
- [Code Contributions](#code-contributions)

## Writing a Scenario

### Step 1: Choose a Domain and Topic

Pick a CKAD domain that needs more scenarios. Check current coverage:

```bash
ls scenarios/domain-*/  # See what exists
```

The five CKAD domains:
1. **Application Design & Build** (20%) — Pods, multi-container, init containers, Jobs, CronJobs, PVCs
2. **Application Deployment** (20%) — Deployments, rollouts, Helm, scaling, blue-green, canary
3. **Application Observability & Maintenance** (15%) — Probes, logging, debugging, metrics
4. **Application Environment, Configuration & Security** (25%) — ConfigMaps, Secrets, RBAC, SecurityContext, quotas
5. **Services & Networking** (20%) — Services, Ingress, NetworkPolicy, DNS

### Step 2: Create the YAML File

Create a file in `scenarios/domain-N/your-scenario-id.yaml`:

```yaml
id: configmap-env-injection
domain: 4
title: Inject ConfigMap as Environment Variables
difficulty: easy
time_limit: 180
tags: [configmap, env, pod]
namespace: config-lab

description: |
  Create a ConfigMap named `app-config` in namespace `config-lab` with:
    DB_HOST=postgres.db.svc.cluster.local
    DB_PORT=5432

  Then create a Pod named `app-server` using image `busybox:1.36` that:
  1. Loads ALL keys from `app-config` as environment variables
  2. Runs the command: env | sort

hint: |
  Use `kubectl create configmap` with --from-literal flags.
  For loading all keys, use `envFrom` in the pod spec rather than
  individual `env` entries.

setup:
  - kubectl create namespace config-lab --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: configmap/app-config
    description: ConfigMap app-config exists
  - type: resource_field
    resource: configmap/app-config
    jsonpath: "{.data.DB_HOST}"
    expected: "postgres.db.svc.cluster.local"
    description: DB_HOST key has correct value
  - type: resource_field
    resource: configmap/app-config
    jsonpath: "{.data.DB_PORT}"
    expected: "5432"
    description: DB_PORT key has correct value
  - type: resource_exists
    resource: pod/app-server
    description: Pod app-server exists
  - type: container_image
    resource: pod/app-server
    container: app-server
    expected: "busybox:1.36"
    description: app-server uses busybox:1.36 image
  - type: command_output
    command: "kubectl get pod app-server -n config-lab -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}'"
    equals: "app-config"
    description: Pod uses envFrom to load app-config

solution: |
  kubectl create configmap app-config \
    --from-literal=DB_HOST=postgres.db.svc.cluster.local \
    --from-literal=DB_PORT=5432 \
    -n config-lab

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: app-server
    namespace: config-lab
  spec:
    containers:
    - name: app-server
      image: busybox:1.36
      command: ["/bin/sh", "-c", "env | sort"]
      envFrom:
      - configMapRef:
          name: app-config
  EOF
```

### Step 3: Validate Your Scenario

Run the validation tool against a live cluster:

```bash
# Make sure the cluster is running
ckad-drill start

# Validate your scenario (runs setup -> apply solution -> check validations -> cleanup)
ckad-drill validate-scenario scenarios/domain-4/configmap-env-injection.yaml
```

The validator will:
1. Parse the YAML and check all required fields
2. Create the namespace and run setup commands
3. Apply your solution
4. Run all validation checks (they must all pass)
5. Clean up the namespace

### Step 4: Submit a PR

See the [PR Checklist](#pr-checklist) below.

## Scenario YAML Schema

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier, descriptive hyphenated (e.g., `configmap-env-injection`) |
| `domain` | integer | CKAD domain 1-5 |
| `title` | string | Human-readable title |
| `difficulty` | string | `easy`, `medium`, or `hard` |
| `time_limit` | integer | Time limit in seconds (typically 120-480) |
| `description` | string | Task description shown to the user (YAML block scalar `\|`) |
| `validations` | list | Validation checks (see [Validation Types](#validation-types-reference)) |
| `solution` | string | Complete solution commands/YAML (YAML block scalar `\|`) |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tags` | list | `[]` | Tags for categorization (e.g., `[pod, configmap, rbac]`) |
| `weight` | integer | `1` | Exam selection weight (higher = more likely in exams) |
| `hint` | string | none | Hint text shown on `ckad-drill hint` |
| `setup` | list | `[]` | Shell commands to run before the scenario |
| `cleanup` | list | `[]` | Shell commands to run after the scenario (namespace deletion is automatic) |
| `namespace` | string | `drill-<id>` | Target namespace (use realistic names like `web-team`, `secure-ns`) |
| `learn` | boolean | `false` | Whether this is a learn-mode scenario |
| `concept_text` | string | none | Concept explanation for learn-mode scenarios |

### Scenario Types

**Regular scenarios** — standard drill/exam scenarios:
```yaml
id: rolling-update-strategy
```

**Learn scenarios** — guided tutorials with concept text:
```yaml
id: learn-pods-basics
learn: true
concept_text: |
  A Pod is the smallest deployable unit in Kubernetes...
```

**Debug scenarios** — setup deploys broken resources, user fixes them:
```yaml
id: debug-crashloop-backoff
setup:
  - kubectl apply -f broken-pod.yaml  # deploys broken resource
# validations check that the user FIXED the issue
```

## Naming Conventions

| Convention | Rule | Example |
|-----------|------|---------|
| Scenario ID | Descriptive, hyphenated, no numeric prefix | `configmap-env-injection` |
| Learn scenario ID | `learn-` prefix | `learn-pods-basics` |
| Debug scenario ID | `debug-` prefix | `debug-crashloop-backoff` |
| File name | Same as ID with `.yaml` extension | `configmap-env-injection.yaml` |
| File location | `scenarios/domain-N/` matching the `domain` field | `scenarios/domain-4/configmap-env-injection.yaml` |
| Namespace | Lowercase, hyphens only, realistic names | `web-team`, `secure-ns`, `config-lab` |
| Resource references | `kind/name` format | `pod/web-logger`, `deployment/api-server` |

## Validation Types Reference

Every scenario needs at least one validation check. Each check has a `type` and type-specific fields.

### resource_exists

Checks that a Kubernetes resource exists in the scenario namespace.

```yaml
- type: resource_exists
  resource: pod/web-logger
  description: Pod web-logger exists
```

### resource_field

Checks a specific field value via jsonpath.

```yaml
- type: resource_field
  resource: deployment/api-server
  jsonpath: "{.spec.replicas}"
  expected: "3"
  description: Deployment has 3 replicas
```

### container_count

Checks the number of containers in a pod.

```yaml
- type: container_count
  resource: pod/web-logger
  expected: 2
  description: Pod has 2 containers
```

### container_image

Checks the image used by a named container.

```yaml
- type: container_image
  resource: pod/web-logger
  container: nginx
  expected: "nginx:1.25"
  description: nginx container uses correct image
```

### container_env

Checks an environment variable value in a container.

```yaml
- type: container_env
  resource: pod/app-server
  container: app-server
  env_name: DB_HOST
  expected: "postgres.db.svc.cluster.local"
  description: DB_HOST env var is set correctly
```

### volume_mount

Checks that a volume is mounted at the expected path.

```yaml
- type: volume_mount
  resource: pod/web-logger
  container: nginx
  mount_path: /var/log/nginx
  description: nginx has volume mounted at /var/log/nginx
```

### container_running

Checks that a specific container is in Running state.

```yaml
- type: container_running
  resource: pod/web-logger
  container: logger
  description: logger container is running
```

### label_selector

Checks that resources with specific labels exist.

```yaml
- type: label_selector
  resource_type: pod
  labels: "app=web,tier=frontend"
  description: Pods with app=web,tier=frontend labels exist
```

### resource_count

Checks the number of resources matching a selector.

```yaml
- type: resource_count
  resource_type: pod
  selector: "app=web"
  expected: 3
  description: 3 pods match the app=web selector
```

### command_output

Runs a command and checks the output. Use this as an escape hatch when typed checks are not sufficient.

```yaml
# Check output contains a substring
- type: command_output
  command: "kubectl exec web-logger -n web-team -c logger -- cat /proc/1/cmdline"
  contains: "tail"
  description: logger container runs tail command

# Check output matches a regex
- type: command_output
  command: "kubectl get svc api-svc -n web-team -o jsonpath='{.spec.type}'"
  matches: "ClusterIP|NodePort"
  description: Service type is ClusterIP or NodePort

# Check output equals exactly
- type: command_output
  command: "kubectl get configmap app-config -n config-lab -o jsonpath='{.data.DB_PORT}'"
  equals: "5432"
  description: DB_PORT value is 5432
```

## Testing Your Scenario

### Prerequisites

```bash
# Ensure cluster is running
ckad-drill start

# Ensure validate-scenario works
ckad-drill validate-scenario --help
```

### Run Validation

```bash
# Validate a single scenario
ckad-drill validate-scenario scenarios/domain-4/configmap-env-injection.yaml

# Validate all scenarios in a domain
ckad-drill validate-scenario scenarios/domain-4/

# Validate all scenarios
ckad-drill validate-scenario scenarios/
```

### Manual Testing

You can also test manually:

```bash
# 1. Set up the scenario namespace
kubectl create namespace config-lab

# 2. Run any setup commands from your YAML

# 3. Apply the solution from your YAML manually

# 4. Run ckad-drill check (or verify with kubectl)
kubectl get configmap app-config -n config-lab
kubectl get pod app-server -n config-lab
```

## PR Checklist

Before submitting your PR, verify:

- [ ] **Scenario file** is in the correct `scenarios/domain-N/` directory
- [ ] **File name** matches the `id` field (e.g., `configmap-env-injection.yaml`)
- [ ] **All required fields** are present: `id`, `domain`, `title`, `difficulty`, `time_limit`, `description`, `validations`, `solution`
- [ ] **ID is unique** — does not duplicate any existing scenario ID
- [ ] **Domain is correct** — integer 1-5 matching the file location
- [ ] **Difficulty is calibrated** — easy (< 3 min), medium (3-5 min), hard (5-8 min)
- [ ] **Namespace uses a realistic name** — not `default`, not `test` (e.g., `web-team`, `config-lab`)
- [ ] **Validations are complete** — check all key requirements, not just one
- [ ] **Solution is complete** — a reader can copy-paste it and pass all validations
- [ ] **`ckad-drill validate-scenario` passes** — end-to-end validation succeeds
- [ ] **Description is clear** — a CKAD candidate can understand the task without ambiguity
- [ ] **Hint is helpful but not a giveaway** — points in the right direction without solving it

## Code Contributions

For changes to the bash tool itself (lib/*.sh, bin/ckad-drill):

1. Read the architecture doc: `_bmad-output/planning-artifacts/architecture.md`
2. Follow all bash conventions: 2-space indent, `"${braced}"` variables, `module_action()` function names
3. Write bats tests first (TDD)
4. Ensure `make test` passes (shellcheck + unit tests)
5. Ensure `make test-integration` passes if your change affects cluster interaction

### Developer Setup

```bash
scripts/dev-setup.sh   # Installs bats-core, shellcheck
make test              # Run shellcheck + unit tests
make test-integration  # Run integration tests (requires running cluster)
```
```

**Step 2: Verify the file**

Ensure:
- All markdown code blocks are properly closed
- The YAML examples are valid
- All validation types from ADR-01 are documented
- The PR checklist covers all acceptance criteria from Story 12.2

**Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: write CONTRIBUTING.md with scenario authoring guide

Scenario YAML schema reference, all 10 validation types with examples,
naming conventions, step-by-step write guide, validate-scenario usage,
and PR checklist for contributors."
```

---

### Task 3: Audit Scenario Counts and Identify Domain Gaps (Story 8.6)

**Goal:** Count scenarios produced by migration sprints (4 + 6), identify which domains fall short of the per-domain minimum (10 each) and overall 70+ target, then plan net-new authoring.

**Files:**
- None modified — this is an analysis task.

**Step 1: Count scenarios by domain**

```bash
cd /home/jeff/Projects/cka

echo "=== Scenario counts by domain ==="
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  echo "  Domain ${d}: ${count} scenarios"
done

total=$(find scenarios/ -name "*.yaml" -type f 2>/dev/null | wc -l)
echo "  TOTAL: ${total} scenarios"
echo ""

echo "=== Scenarios by type ==="
learn=$(grep -rl "^learn: true" scenarios/ 2>/dev/null | wc -l)
debug=$(find scenarios/ -name "debug-*.yaml" -type f 2>/dev/null | wc -l)
regular=$((total - learn - debug))
echo "  Regular: ${regular}"
echo "  Learn:   ${learn}"
echo "  Debug:   ${debug}"
echo ""

echo "=== Gap analysis ==="
target=70
gap=$((target - total))
if [ "${gap}" -gt 0 ]; then
  echo "  Need ${gap} more scenarios to reach ${target} target"
else
  echo "  Target met! ${total} >= ${target}"
fi

echo ""
echo "=== Per-domain gap (minimum 10 each) ==="
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  needed=$((10 - count))
  if [ "${needed}" -gt 0 ]; then
    echo "  Domain ${d}: needs ${needed} more (has ${count})"
  else
    echo "  Domain ${d}: OK (has ${count})"
  fi
done
```

**Step 2: Record results**

Document the actual counts and gaps. The estimates from the architecture doc predict ~50+ from migration (31 scenarios + 12 troubleshooting + tutorial exercises + domain exercises + quiz conversions). The gap from actual migration output to 70 must be filled with net-new scenarios.

**Step 3: Prioritize domains for net-new content**

Per Story 8.6 and CKAD exam weights:
- Domain 4 (Config & Security, 25% weight) — historically under-represented, highest exam weight
- Domain 5 (Networking, 20% weight) — NetworkPolicy and Ingress scenarios are complex and under-covered
- Any domain below 10 scenarios gets priority regardless

---

### Task 4: Author Net-New Domain 4 Scenarios (Story 8.6)

**Goal:** Write 3-5 new scenarios for Domain 4 (Application Environment, Configuration & Security) — the highest-weighted exam domain at 25%.

**Files:**
- Create: `scenarios/domain-4/<id>.yaml` (one per scenario)

**Step 1: Identify gaps in existing Domain 4 coverage**

Domain 4 topics that need coverage (from CKAD curriculum):
- ConfigMaps (creation, mounting as volume, env injection)
- Secrets (creation, types, mounting, env injection)
- ServiceAccounts and token projection
- RBAC (Role, RoleBinding, ClusterRole, ClusterRoleBinding)
- SecurityContext (runAsUser, readOnlyRootFilesystem, capabilities)
- Resource requests and limits
- ResourceQuotas and LimitRanges

Check which topics already have scenarios and fill gaps.

**Step 2: Write new scenario YAML files**

Below are 5 example scenarios. Write the actual files based on the gap analysis in Step 1. Each scenario must have all required fields and pass `ckad-drill validate-scenario`.

**Example 1: `scenarios/domain-4/secret-volume-mount.yaml`**

```yaml
id: secret-volume-mount
domain: 4
title: Mount Secret as Volume in Pod
difficulty: easy
time_limit: 180
tags: [secret, volume, pod]
namespace: secrets-lab

description: |
  In namespace `secrets-lab`:

  1. Create a Secret named `db-credentials` with:
     - username=admin
     - password=S3cureP@ss

  2. Create a Pod named `db-client` using image `busybox:1.36` that:
     - Mounts the secret as a volume at /etc/db-creds
     - Runs the command: cat /etc/db-creds/username && sleep 3600

hint: |
  Use `kubectl create secret generic` to create the secret.
  In the pod spec, define a volume with `secret.secretName` and
  mount it in the container with `volumeMounts`.

setup:
  - kubectl create namespace secrets-lab --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: secret/db-credentials
    description: Secret db-credentials exists
  - type: command_output
    command: "kubectl get secret db-credentials -n secrets-lab -o jsonpath='{.data.username}' | base64 -d"
    equals: "admin"
    description: Secret contains username=admin
  - type: command_output
    command: "kubectl get secret db-credentials -n secrets-lab -o jsonpath='{.data.password}' | base64 -d"
    equals: "S3cureP@ss"
    description: Secret contains correct password
  - type: resource_exists
    resource: pod/db-client
    description: Pod db-client exists
  - type: volume_mount
    resource: pod/db-client
    container: db-client
    mount_path: /etc/db-creds
    description: Secret mounted at /etc/db-creds
  - type: container_running
    resource: pod/db-client
    container: db-client
    description: db-client container is running

solution: |
  kubectl create secret generic db-credentials \
    --from-literal=username=admin \
    --from-literal=password='S3cureP@ss' \
    -n secrets-lab

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: db-client
    namespace: secrets-lab
  spec:
    containers:
    - name: db-client
      image: busybox:1.36
      command: ["/bin/sh", "-c", "cat /etc/db-creds/username && sleep 3600"]
      volumeMounts:
      - name: db-secret
        mountPath: /etc/db-creds
        readOnly: true
    volumes:
    - name: db-secret
      secret:
        secretName: db-credentials
  EOF
```

**Example 2: `scenarios/domain-4/rbac-developer-role.yaml`**

```yaml
id: rbac-developer-role
domain: 4
title: Create RBAC Role and RoleBinding for Developer
difficulty: medium
time_limit: 300
tags: [rbac, role, rolebinding, serviceaccount]
namespace: dev-team

description: |
  In namespace `dev-team`:

  1. Create a ServiceAccount named `developer`
  2. Create a Role named `pod-manager` that allows:
     - get, list, watch, create, delete on pods
     - get, list on services
  3. Create a RoleBinding named `developer-pod-access` that binds
     the `pod-manager` role to the `developer` ServiceAccount

hint: |
  Use `kubectl create serviceaccount`, `kubectl create role`, and
  `kubectl create rolebinding`. The --verb and --resource flags on
  `kubectl create role` accept comma-separated values.

setup:
  - kubectl create namespace dev-team --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: serviceaccount/developer
    description: ServiceAccount developer exists
  - type: resource_exists
    resource: role/pod-manager
    description: Role pod-manager exists
  - type: command_output
    command: "kubectl auth can-i create pods -n dev-team --as=system:serviceaccount:dev-team:developer"
    equals: "yes"
    description: developer can create pods
  - type: command_output
    command: "kubectl auth can-i list services -n dev-team --as=system:serviceaccount:dev-team:developer"
    equals: "yes"
    description: developer can list services
  - type: command_output
    command: "kubectl auth can-i create deployments -n dev-team --as=system:serviceaccount:dev-team:developer"
    equals: "no"
    description: developer cannot create deployments (least privilege)
  - type: resource_exists
    resource: rolebinding/developer-pod-access
    description: RoleBinding developer-pod-access exists

solution: |
  kubectl create serviceaccount developer -n dev-team

  kubectl create role pod-manager \
    --verb=get,list,watch,create,delete --resource=pods \
    --verb=get,list --resource=services \
    -n dev-team

  kubectl create rolebinding developer-pod-access \
    --role=pod-manager \
    --serviceaccount=dev-team:developer \
    -n dev-team
```

**Example 3: `scenarios/domain-4/security-context-nonroot.yaml`**

```yaml
id: security-context-nonroot
domain: 4
title: Pod Security Context — Run as Non-Root
difficulty: medium
time_limit: 240
tags: [securitycontext, pod, security]
namespace: secure-apps

description: |
  In namespace `secure-apps`:

  Create a Pod named `secure-app` using image `nginx:1.25` with:

  1. Pod-level security context: runAsNonRoot=true, fsGroup=1000
  2. Container-level security context: runAsUser=1000, readOnlyRootFilesystem=true
  3. The container should have an emptyDir volume mounted at /tmp
     (needed because the root filesystem is read-only)
  4. The container should also have an emptyDir mounted at /var/cache/nginx

hint: |
  nginx needs writable directories at /tmp and /var/cache/nginx to function
  with a read-only root filesystem. Use emptyDir volumes for both.
  Set securityContext at both pod and container levels.

setup:
  - kubectl create namespace secure-apps --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/secure-app
    description: Pod secure-app exists
  - type: container_image
    resource: pod/secure-app
    container: secure-app
    expected: "nginx:1.25"
    description: Uses nginx:1.25 image
  - type: resource_field
    resource: pod/secure-app
    jsonpath: "{.spec.securityContext.runAsNonRoot}"
    expected: "true"
    description: Pod-level runAsNonRoot is true
  - type: resource_field
    resource: pod/secure-app
    jsonpath: "{.spec.securityContext.fsGroup}"
    expected: "1000"
    description: fsGroup is 1000
  - type: resource_field
    resource: pod/secure-app
    jsonpath: "{.spec.containers[0].securityContext.runAsUser}"
    expected: "1000"
    description: Container runs as user 1000
  - type: resource_field
    resource: pod/secure-app
    jsonpath: "{.spec.containers[0].securityContext.readOnlyRootFilesystem}"
    expected: "true"
    description: readOnlyRootFilesystem is true
  - type: volume_mount
    resource: pod/secure-app
    container: secure-app
    mount_path: /tmp
    description: /tmp is mounted as writable volume
  - type: volume_mount
    resource: pod/secure-app
    container: secure-app
    mount_path: /var/cache/nginx
    description: /var/cache/nginx is mounted as writable volume

solution: |
  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: secure-app
    namespace: secure-apps
  spec:
    securityContext:
      runAsNonRoot: true
      fsGroup: 1000
    containers:
    - name: secure-app
      image: nginx:1.25
      securityContext:
        runAsUser: 1000
        readOnlyRootFilesystem: true
      volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: cache
        mountPath: /var/cache/nginx
    volumes:
    - name: tmp
      emptyDir: {}
    - name: cache
      emptyDir: {}
  EOF
```

**Example 4: `scenarios/domain-4/resource-quota-limitrange.yaml`**

```yaml
id: resource-quota-limitrange
domain: 4
title: ResourceQuota and LimitRange for Namespace
difficulty: hard
time_limit: 420
tags: [resourcequota, limitrange, namespace, resources]
namespace: constrained-ns

description: |
  In namespace `constrained-ns`:

  1. Create a LimitRange named `default-limits` that sets:
     - Default CPU request: 100m, default CPU limit: 500m
     - Default memory request: 64Mi, default memory limit: 256Mi

  2. Create a ResourceQuota named `team-quota` that limits:
     - Max 5 pods
     - Total CPU requests: 2 cores
     - Total memory requests: 1Gi

  3. Create a Pod named `quota-test` using image `nginx:1.25` with:
     - CPU request 200m, CPU limit 500m
     - Memory request 128Mi, memory limit 256Mi

hint: |
  Create the LimitRange first — it sets defaults for pods that don't specify
  their own requests/limits. Then create the ResourceQuota to cap total
  namespace consumption. Finally, create the pod with explicit resource specs.

setup:
  - kubectl create namespace constrained-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: limitrange/default-limits
    description: LimitRange default-limits exists
  - type: resource_exists
    resource: resourcequota/team-quota
    description: ResourceQuota team-quota exists
  - type: resource_field
    resource: resourcequota/team-quota
    jsonpath: "{.spec.hard.pods}"
    expected: "5"
    description: ResourceQuota limits to 5 pods
  - type: resource_exists
    resource: pod/quota-test
    description: Pod quota-test exists
  - type: resource_field
    resource: pod/quota-test
    jsonpath: "{.spec.containers[0].resources.requests.cpu}"
    expected: "200m"
    description: Pod has CPU request of 200m
  - type: resource_field
    resource: pod/quota-test
    jsonpath: "{.spec.containers[0].resources.requests.memory}"
    expected: "128Mi"
    description: Pod has memory request of 128Mi
  - type: container_running
    resource: pod/quota-test
    container: quota-test
    description: Pod is running within quota

solution: |
  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: LimitRange
  metadata:
    name: default-limits
    namespace: constrained-ns
  spec:
    limits:
    - default:
        cpu: 500m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 64Mi
      type: Container
  EOF

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: team-quota
    namespace: constrained-ns
  spec:
    hard:
      pods: "5"
      requests.cpu: "2"
      requests.memory: 1Gi
  EOF

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: quota-test
    namespace: constrained-ns
  spec:
    containers:
    - name: quota-test
      image: nginx:1.25
      resources:
        requests:
          cpu: 200m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
  EOF
```

**Example 5: `scenarios/domain-4/serviceaccount-token-projection.yaml`**

```yaml
id: serviceaccount-token-projection
domain: 4
title: ServiceAccount with Projected Token Volume
difficulty: hard
time_limit: 360
tags: [serviceaccount, token, projected, security]
namespace: auth-ns

description: |
  In namespace `auth-ns`:

  1. Create a ServiceAccount named `api-consumer`
  2. Create a Pod named `token-reader` using image `busybox:1.36` that:
     - Uses the `api-consumer` ServiceAccount
     - Has automountServiceAccountToken set to false at the pod level
     - Manually mounts a projected service account token at /var/run/secrets/tokens
       with audience "api-server" and expirationSeconds 3600
     - Runs: cat /var/run/secrets/tokens/token && sleep 3600

hint: |
  Set automountServiceAccountToken: false on the pod spec.
  Then use a projected volume with a serviceAccountToken source,
  specifying the audience and expirationSeconds fields.

setup:
  - kubectl create namespace auth-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: serviceaccount/api-consumer
    description: ServiceAccount api-consumer exists
  - type: resource_exists
    resource: pod/token-reader
    description: Pod token-reader exists
  - type: resource_field
    resource: pod/token-reader
    jsonpath: "{.spec.serviceAccountName}"
    expected: "api-consumer"
    description: Pod uses api-consumer ServiceAccount
  - type: resource_field
    resource: pod/token-reader
    jsonpath: "{.spec.automountServiceAccountToken}"
    expected: "false"
    description: automountServiceAccountToken is false
  - type: volume_mount
    resource: pod/token-reader
    container: token-reader
    mount_path: /var/run/secrets/tokens
    description: Projected token mounted at /var/run/secrets/tokens
  - type: container_running
    resource: pod/token-reader
    container: token-reader
    description: token-reader is running

solution: |
  kubectl create serviceaccount api-consumer -n auth-ns

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: token-reader
    namespace: auth-ns
  spec:
    serviceAccountName: api-consumer
    automountServiceAccountToken: false
    containers:
    - name: token-reader
      image: busybox:1.36
      command: ["/bin/sh", "-c", "cat /var/run/secrets/tokens/token && sleep 3600"]
      volumeMounts:
      - name: token-vol
        mountPath: /var/run/secrets/tokens
        readOnly: true
    volumes:
    - name: token-vol
      projected:
        sources:
        - serviceAccountToken:
            path: token
            audience: api-server
            expirationSeconds: 3600
  EOF
```

**Step 3: Validate each scenario**

```bash
for f in scenarios/domain-4/secret-volume-mount.yaml \
         scenarios/domain-4/rbac-developer-role.yaml \
         scenarios/domain-4/security-context-nonroot.yaml \
         scenarios/domain-4/resource-quota-limitrange.yaml \
         scenarios/domain-4/serviceaccount-token-projection.yaml; do
  echo "=== Validating ${f} ==="
  ckad-drill validate-scenario "${f}"
done
```

Expected: All PASS.

**Step 4: Commit**

```bash
git add scenarios/domain-4/secret-volume-mount.yaml \
        scenarios/domain-4/rbac-developer-role.yaml \
        scenarios/domain-4/security-context-nonroot.yaml \
        scenarios/domain-4/resource-quota-limitrange.yaml \
        scenarios/domain-4/serviceaccount-token-projection.yaml
git commit -m "content: add 5 net-new domain 4 scenarios (config & security)

Secret volume mounts, RBAC roles, SecurityContext non-root,
ResourceQuota + LimitRange, and ServiceAccount token projection.
Prioritized for 25% exam weight domain."
```

---

### Task 5: Author Net-New Domain 5 Scenarios (Story 8.6)

**Goal:** Write 3-5 new scenarios for Domain 5 (Services & Networking) — the second priority domain at 20% exam weight.

**Files:**
- Create: `scenarios/domain-5/<id>.yaml` (one per scenario)

**Step 1: Identify gaps in existing Domain 5 coverage**

Domain 5 topics that need coverage (from CKAD curriculum):
- ClusterIP, NodePort, LoadBalancer services
- Headless services
- Ingress resources and IngressClass
- NetworkPolicy (ingress and egress rules)
- DNS for services and pods
- Endpoint and EndpointSlice management
- Port forwarding

Check which topics already have scenarios and fill gaps.

**Step 2: Write new scenario YAML files**

**Example 1: `scenarios/domain-5/network-policy-deny-all.yaml`**

```yaml
id: network-policy-deny-all
domain: 5
title: Default Deny NetworkPolicy with Selective Allow
difficulty: medium
time_limit: 300
tags: [networkpolicy, security, networking]
namespace: restricted-net

description: |
  In namespace `restricted-net`:

  1. Create a Pod named `web-app` with image `nginx:1.25` and label `app=web`
  2. Create a Pod named `api-app` with image `nginx:1.25` and label `app=api`
  3. Create a default-deny-all NetworkPolicy named `deny-all` that blocks
     ALL ingress traffic to all pods in the namespace
  4. Create a NetworkPolicy named `allow-web-to-api` that allows ingress
     to pods labeled `app=api` ONLY from pods labeled `app=web` on port 80

hint: |
  A default deny policy uses an empty ingress array: `ingress: []`.
  The selective allow policy uses podSelector in the `from` field
  and port 80 in the `ports` field.

setup:
  - kubectl create namespace restricted-net --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/web-app
    description: Pod web-app exists
  - type: resource_exists
    resource: pod/api-app
    description: Pod api-app exists
  - type: label_selector
    resource_type: pod
    labels: "app=web"
    description: Pod with app=web label exists
  - type: label_selector
    resource_type: pod
    labels: "app=api"
    description: Pod with app=api label exists
  - type: resource_exists
    resource: networkpolicy/deny-all
    description: NetworkPolicy deny-all exists
  - type: resource_exists
    resource: networkpolicy/allow-web-to-api
    description: NetworkPolicy allow-web-to-api exists
  - type: resource_field
    resource: networkpolicy/allow-web-to-api
    jsonpath: "{.spec.ingress[0].from[0].podSelector.matchLabels.app}"
    expected: "web"
    description: allow-web-to-api allows from app=web pods
  - type: resource_field
    resource: networkpolicy/allow-web-to-api
    jsonpath: "{.spec.ingress[0].ports[0].port}"
    expected: "80"
    description: allow-web-to-api allows port 80

solution: |
  kubectl run web-app --image=nginx:1.25 -l app=web -n restricted-net
  kubectl run api-app --image=nginx:1.25 -l app=api -n restricted-net

  cat <<'EOF' | kubectl apply -f -
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: deny-all
    namespace: restricted-net
  spec:
    podSelector: {}
    policyTypes:
    - Ingress
  EOF

  cat <<'EOF' | kubectl apply -f -
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-web-to-api
    namespace: restricted-net
  spec:
    podSelector:
      matchLabels:
        app: api
    policyTypes:
    - Ingress
    ingress:
    - from:
      - podSelector:
          matchLabels:
            app: web
      ports:
      - protocol: TCP
        port: 80
  EOF
```

**Example 2: `scenarios/domain-5/ingress-path-routing.yaml`**

```yaml
id: ingress-path-routing
domain: 5
title: Ingress with Path-Based Routing
difficulty: medium
time_limit: 360
tags: [ingress, service, routing, networking]
namespace: web-routing

description: |
  In namespace `web-routing`:

  1. Create a Deployment named `frontend` with image `nginx:1.25`, 2 replicas,
     and label `app=frontend`
  2. Create a Deployment named `api-backend` with image `nginx:1.25`, 2 replicas,
     and label `app=api`
  3. Create a ClusterIP Service named `frontend-svc` on port 80 targeting
     pods with label `app=frontend`
  4. Create a ClusterIP Service named `api-svc` on port 80 targeting
     pods with label `app=api`
  5. Create an Ingress named `app-ingress` with:
     - Host: app.example.com
     - Path /frontend routes to frontend-svc:80
     - Path /api routes to api-svc:80
     - pathType: Prefix for both paths

hint: |
  Create the deployments and services first. The Ingress needs
  `ingressClassName: nginx` and uses `spec.rules[].http.paths[]` to
  define path-based routing.

setup:
  - kubectl create namespace web-routing --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: deployment/frontend
    description: Deployment frontend exists
  - type: resource_exists
    resource: deployment/api-backend
    description: Deployment api-backend exists
  - type: resource_field
    resource: deployment/frontend
    jsonpath: "{.spec.replicas}"
    expected: "2"
    description: frontend has 2 replicas
  - type: resource_exists
    resource: service/frontend-svc
    description: Service frontend-svc exists
  - type: resource_exists
    resource: service/api-svc
    description: Service api-svc exists
  - type: resource_exists
    resource: ingress/app-ingress
    description: Ingress app-ingress exists
  - type: resource_field
    resource: ingress/app-ingress
    jsonpath: "{.spec.rules[0].host}"
    expected: "app.example.com"
    description: Ingress host is app.example.com
  - type: command_output
    command: "kubectl get ingress app-ingress -n web-routing -o jsonpath='{.spec.rules[0].http.paths[?(@.path==\"/frontend\")].backend.service.name}'"
    equals: "frontend-svc"
    description: /frontend routes to frontend-svc
  - type: command_output
    command: "kubectl get ingress app-ingress -n web-routing -o jsonpath='{.spec.rules[0].http.paths[?(@.path==\"/api\")].backend.service.name}'"
    equals: "api-svc"
    description: /api routes to api-svc

solution: |
  kubectl create deployment frontend --image=nginx:1.25 --replicas=2 -n web-routing
  kubectl label deployment frontend app=frontend -n web-routing --overwrite
  kubectl create deployment api-backend --image=nginx:1.25 --replicas=2 -n web-routing
  kubectl label deployment api-backend app=api -n web-routing --overwrite

  kubectl expose deployment frontend --name=frontend-svc --port=80 --target-port=80 -n web-routing
  kubectl expose deployment api-backend --name=api-svc --port=80 --target-port=80 -n web-routing

  cat <<'EOF' | kubectl apply -f -
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: app-ingress
    namespace: web-routing
  spec:
    ingressClassName: nginx
    rules:
    - host: app.example.com
      http:
        paths:
        - path: /frontend
          pathType: Prefix
          backend:
            service:
              name: frontend-svc
              port:
                number: 80
        - path: /api
          pathType: Prefix
          backend:
            service:
              name: api-svc
              port:
                number: 80
  EOF
```

**Example 3: `scenarios/domain-5/headless-service-dns.yaml`**

```yaml
id: headless-service-dns
domain: 5
title: Headless Service for StatefulSet DNS
difficulty: hard
time_limit: 420
tags: [service, headless, dns, statefulset, networking]
namespace: stateful-app

description: |
  In namespace `stateful-app`:

  1. Create a Headless Service named `db-headless` (clusterIP: None)
     that selects pods with label `app=database`, on port 5432
  2. Create a StatefulSet named `db` with:
     - 3 replicas
     - Image: postgres:16-alpine
     - Label: app=database
     - serviceName: db-headless
     - Environment variable POSTGRES_PASSWORD=testpass
  3. Verify that individual pod DNS records are created
     (e.g., db-0.db-headless.stateful-app.svc.cluster.local)

hint: |
  A headless service has `clusterIP: None`. When used with a StatefulSet's
  `serviceName` field, Kubernetes creates DNS A records for each pod.
  The format is: <pod-name>.<service-name>.<namespace>.svc.cluster.local

setup:
  - kubectl create namespace stateful-app --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: service/db-headless
    description: Service db-headless exists
  - type: resource_field
    resource: service/db-headless
    jsonpath: "{.spec.clusterIP}"
    expected: "None"
    description: Service is headless (clusterIP=None)
  - type: resource_field
    resource: service/db-headless
    jsonpath: "{.spec.ports[0].port}"
    expected: "5432"
    description: Service port is 5432
  - type: resource_exists
    resource: statefulset/db
    description: StatefulSet db exists
  - type: resource_field
    resource: statefulset/db
    jsonpath: "{.spec.replicas}"
    expected: "3"
    description: StatefulSet has 3 replicas
  - type: resource_field
    resource: statefulset/db
    jsonpath: "{.spec.serviceName}"
    expected: "db-headless"
    description: StatefulSet references db-headless service
  - type: resource_count
    resource_type: pod
    selector: "app=database"
    expected: 3
    description: 3 database pods are running

solution: |
  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Service
  metadata:
    name: db-headless
    namespace: stateful-app
  spec:
    clusterIP: None
    selector:
      app: database
    ports:
    - port: 5432
      targetPort: 5432
  EOF

  cat <<'EOF' | kubectl apply -f -
  apiVersion: apps/v1
  kind: StatefulSet
  metadata:
    name: db
    namespace: stateful-app
  spec:
    serviceName: db-headless
    replicas: 3
    selector:
      matchLabels:
        app: database
    template:
      metadata:
        labels:
          app: database
      spec:
        containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
          - containerPort: 5432
          env:
          - name: POSTGRES_PASSWORD
            value: testpass
  EOF
```

**Example 4: `scenarios/domain-5/network-policy-egress.yaml`**

```yaml
id: network-policy-egress
domain: 5
title: Egress NetworkPolicy — Restrict Outbound Traffic
difficulty: hard
time_limit: 360
tags: [networkpolicy, egress, security, networking]
namespace: egress-control

description: |
  In namespace `egress-control`:

  1. Create a Pod named `restricted-pod` with image `busybox:1.36`,
     label `app=restricted`, running: sleep 3600
  2. Create a NetworkPolicy named `restrict-egress` that applies to pods
     labeled `app=restricted` and:
     - Blocks ALL egress traffic by default
     - Allows egress ONLY to DNS (UDP port 53 to kube-system pods)
     - Allows egress ONLY to TCP port 443 on any destination

hint: |
  Egress NetworkPolicies use `policyTypes: [Egress]` and `egress:` rules.
  For DNS, you need UDP port 53. For HTTPS, you need TCP port 443.
  Use `namespaceSelector` with label `kubernetes.io/metadata.name: kube-system`
  to target DNS pods.

setup:
  - kubectl create namespace egress-control --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/restricted-pod
    description: Pod restricted-pod exists
  - type: label_selector
    resource_type: pod
    labels: "app=restricted"
    description: Pod has app=restricted label
  - type: resource_exists
    resource: networkpolicy/restrict-egress
    description: NetworkPolicy restrict-egress exists
  - type: resource_field
    resource: networkpolicy/restrict-egress
    jsonpath: "{.spec.podSelector.matchLabels.app}"
    expected: "restricted"
    description: Policy applies to app=restricted pods
  - type: command_output
    command: "kubectl get networkpolicy restrict-egress -n egress-control -o jsonpath='{.spec.policyTypes}'"
    contains: "Egress"
    description: Policy type includes Egress
  - type: container_running
    resource: pod/restricted-pod
    container: restricted-pod
    description: restricted-pod is running

solution: |
  kubectl run restricted-pod --image=busybox:1.36 -l app=restricted \
    --command -- sleep 3600 -n egress-control

  cat <<'EOF' | kubectl apply -f -
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: restrict-egress
    namespace: egress-control
  spec:
    podSelector:
      matchLabels:
        app: restricted
    policyTypes:
    - Egress
    egress:
    - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
      ports:
      - protocol: UDP
        port: 53
    - to: []
      ports:
      - protocol: TCP
        port: 443
  EOF
```

**Example 5: `scenarios/domain-5/multiport-service.yaml`**

```yaml
id: multiport-service
domain: 5
title: Multi-Port Service with Named Ports
difficulty: easy
time_limit: 180
tags: [service, ports, networking]
namespace: multi-svc

description: |
  In namespace `multi-svc`:

  1. Create a Pod named `web-server` using image `nginx:1.25` with label `app=web`
     that exposes ports 80 (name: http) and 443 (name: https)
  2. Create a Service named `web-svc` of type ClusterIP that:
     - Selects pods with label `app=web`
     - Maps port 80 (named http) to target port 80
     - Maps port 443 (named https) to target port 443

hint: |
  Use `ports` in the pod container spec to name the ports.
  The Service `ports` array should have two entries, each with
  a `name`, `port`, and `targetPort`.

setup:
  - kubectl create namespace multi-svc --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/web-server
    description: Pod web-server exists
  - type: resource_exists
    resource: service/web-svc
    description: Service web-svc exists
  - type: resource_field
    resource: service/web-svc
    jsonpath: "{.spec.type}"
    expected: "ClusterIP"
    description: Service type is ClusterIP
  - type: command_output
    command: "kubectl get svc web-svc -n multi-svc -o jsonpath='{.spec.ports[?(@.name==\"http\")].port}'"
    equals: "80"
    description: Service has http port 80
  - type: command_output
    command: "kubectl get svc web-svc -n multi-svc -o jsonpath='{.spec.ports[?(@.name==\"https\")].port}'"
    equals: "443"
    description: Service has https port 443

solution: |
  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: web-server
    namespace: multi-svc
    labels:
      app: web
  spec:
    containers:
    - name: nginx
      image: nginx:1.25
      ports:
      - containerPort: 80
        name: http
      - containerPort: 443
        name: https
  EOF

  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: Service
  metadata:
    name: web-svc
    namespace: multi-svc
  spec:
    type: ClusterIP
    selector:
      app: web
    ports:
    - name: http
      port: 80
      targetPort: 80
    - name: https
      port: 443
      targetPort: 443
  EOF
```

**Step 3: Validate each scenario**

```bash
for f in scenarios/domain-5/network-policy-deny-all.yaml \
         scenarios/domain-5/ingress-path-routing.yaml \
         scenarios/domain-5/headless-service-dns.yaml \
         scenarios/domain-5/network-policy-egress.yaml \
         scenarios/domain-5/multiport-service.yaml; do
  echo "=== Validating ${f} ==="
  ckad-drill validate-scenario "${f}"
done
```

Expected: All PASS.

**Step 4: Commit**

```bash
git add scenarios/domain-5/network-policy-deny-all.yaml \
        scenarios/domain-5/ingress-path-routing.yaml \
        scenarios/domain-5/headless-service-dns.yaml \
        scenarios/domain-5/network-policy-egress.yaml \
        scenarios/domain-5/multiport-service.yaml
git commit -m "content: add 5 net-new domain 5 scenarios (networking)

NetworkPolicy deny-all + selective allow, Ingress path routing,
headless service with StatefulSet DNS, egress NetworkPolicy,
and multi-port service. Prioritized for 20% exam weight domain."
```

---

### Task 6: Author Net-New Scenarios for Remaining Domains (Story 8.6)

**Goal:** Fill remaining gaps in domains 1-3 to ensure each domain has at least 10 scenarios and the total reaches 70+.

**Files:**
- Create: `scenarios/domain-N/<id>.yaml` as needed

**Step 1: Re-run the gap analysis from Task 3**

```bash
cd /home/jeff/Projects/cka

echo "=== Updated scenario counts ==="
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  echo "  Domain ${d}: ${count} scenarios"
done
total=$(find scenarios/ -name "*.yaml" -type f 2>/dev/null | wc -l)
echo "  TOTAL: ${total}"
echo "  Gap to 70: $((70 - total))"
```

**Step 2: Author scenarios for under-represented domains**

Based on the gap analysis, write new scenarios for whichever domains are below 10. Use the same YAML structure and conventions from Tasks 4 and 5.

Example topic ideas per domain (if needed):

**Domain 1 (Application Design & Build):**
- `persistent-volume-claim` — Create PVC with specific access mode and storage class
- `cronjob-with-deadline` — CronJob with activeDeadlineSeconds and concurrencyPolicy
- `pod-with-init-container` — Init container that prepares config before main container starts

**Domain 2 (Application Deployment):**
- `blue-green-deployment` — Two deployments, switch service selector
- `helm-upgrade-rollback` — Install chart, upgrade, then rollback
- `hpa-cpu-autoscaling` — HorizontalPodAutoscaler targeting CPU utilization

**Domain 3 (Application Observability & Maintenance):**
- `liveness-readiness-probes` — Pod with HTTP liveness and TCP readiness probes
- `container-logging-debug` — Retrieve logs from multi-container pod
- `resource-monitoring-top` — Use kubectl top to identify resource-heavy pods

**Step 3: Validate all new scenarios**

```bash
ckad-drill validate-scenario scenarios/
```

Expected: All PASS.

**Step 4: Verify final counts**

```bash
echo "=== Final scenario counts ==="
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  echo "  Domain ${d}: ${count} scenarios"
done
total=$(find scenarios/ -name "*.yaml" -type f 2>/dev/null | wc -l)
echo "  TOTAL: ${total}"
if [ "${total}" -ge 70 ]; then
  echo "  NFR-06 MET: ${total} >= 70"
else
  echo "  NFR-06 NOT MET: ${total} < 70 — need $((70 - total)) more"
fi
```

Expected: Total >= 70, each domain >= 10.

**Step 5: Commit**

```bash
git add scenarios/
git commit -m "content: add net-new scenarios to close gap to 70+ target

Fill under-represented domains to ensure each has >= 10 scenarios
and total meets NFR-06 launch target of 70+."
```

---

### Task 7: V1.0 Release Preparation

**Goal:** Tag V1.0, update version string, run final verification.

**Files:**
- Modify: `bin/ckad-drill` (version string)

**Step 1: Update version in bin/ckad-drill**

Change the version string from development to release:

```bash
# In bin/ckad-drill, find:
#   --version) echo "ckad-drill 0.1.0-dev" ;;
# Replace with:
#   --version) echo "ckad-drill 1.0.0" ;;
```

Verify:

```bash
bin/ckad-drill --version
```

Expected: `ckad-drill 1.0.0`

**Step 2: Run full test suite**

```bash
make test
```

Expected: shellcheck passes, all unit tests pass.

**Step 3: Run integration tests**

```bash
make test-integration
```

Expected: All integration tests pass against a running kind cluster.

**Step 4: Validate all scenarios**

```bash
ckad-drill validate-scenario scenarios/
```

Expected: All scenarios pass validation.

**Step 5: Final scenario count verification**

```bash
echo "=== V1.0 Release Scenario Counts ==="
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  echo "  Domain ${d}: ${count}"
done
total=$(find scenarios/ -name "*.yaml" -type f 2>/dev/null | wc -l)
echo "  TOTAL: ${total}"
echo ""
echo "=== Checks ==="
echo "  [$([ "${total}" -ge 70 ] && echo 'PASS' || echo 'FAIL')] >= 70 scenarios (NFR-06)"
for d in 1 2 3 4 5; do
  count=$(find "scenarios/domain-${d}" -name "*.yaml" -type f 2>/dev/null | wc -l)
  echo "  [$([ "${count}" -ge 10 ] && echo 'PASS' || echo 'FAIL')] Domain ${d} >= 10 scenarios"
done
```

**Step 6: Verify README and CONTRIBUTING exist**

```bash
test -f README.md && echo "README.md: OK" || echo "README.md: MISSING"
test -f CONTRIBUTING.md && echo "CONTRIBUTING.md: OK" || echo "CONTRIBUTING.md: MISSING"
test -f LICENSE && echo "LICENSE: OK" || echo "LICENSE: MISSING"
```

**Step 7: Commit version bump**

```bash
git add bin/ckad-drill
git commit -m "chore: bump version to 1.0.0 for release"
```

**Step 8: Create git tag**

```bash
git tag -a v1.0.0 -m "v1.0.0 — ckad-drill initial release

Features:
- Three practice modes: Learn, Drill, Exam
- 70+ scenarios across all 5 CKAD domains
- Real-cluster validation via kind + kubectl
- Countdown timer in bash prompt
- Progress tracking with per-domain stats
- Scenario validation tool for contributors
- Exam-matched environment (Calico, ingress, metrics-server)"
```

Note: Do NOT push the tag until ready. When ready:

```bash
git push origin main
git push origin v1.0.0
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 12.1 | README.md | Visual review |
| 2 | 12.2 | CONTRIBUTING.md | Visual review |
| 3 | 8.6 | Gap analysis — scenario count audit | Shell script output |
| 4 | 8.6 | 5 net-new Domain 4 scenarios | `ckad-drill validate-scenario` |
| 5 | 8.6 | 5 net-new Domain 5 scenarios | `ckad-drill validate-scenario` |
| 6 | 8.6 | Net-new scenarios for domains 1-3 (as needed) | `ckad-drill validate-scenario` |
| 7 | — | V1.0 release prep: version bump, full test, git tag | `make test`, `make test-integration`, scenario validation |

**After Sprint 8:** README.md and CONTRIBUTING.md published. Total scenario count >= 70 across all 5 domains with each domain having >= 10. Version bumped to 1.0.0 and tagged. **V1.0 release ready.**

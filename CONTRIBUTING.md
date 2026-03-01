# Contributing to ckad-drill

Thank you for contributing. This guide covers how to set up a development environment, write new scenarios, and submit pull requests.

## Getting Started

```bash
# Clone the repo
git clone https://github.com/USER/ckad-drill.git
cd ckad-drill

# Install dev dependencies (bats, shellcheck)
scripts/dev-setup.sh

# Also required (install manually if not present): yq, jq, kind, kubectl, Docker

# Verify the setup
make shellcheck
make test-unit
```

## Writing a New Scenario

### 1. Pick a domain and difficulty

CKAD has five domains. Match your scenario to the correct one:

| Domain | Folder | Topic |
|--------|--------|-------|
| 1 | `scenarios/domain-1/` | Application Design and Build |
| 2 | `scenarios/domain-2/` | Application Deployment |
| 3 | `scenarios/domain-3/` | Application Observability and Maintenance |
| 4 | `scenarios/domain-4/` | Application Environment, Configuration, and Security |
| 5 | `scenarios/domain-5/` | Services and Networking |

Difficulty: `easy` (< 5 min), `medium` (5-10 min), `hard` (10-15 min).

### 2. Name your file

Follow these naming conventions:

| Type | Prefix | Example |
|------|--------|---------|
| Drill scenario | `sc-` | `sc-multi-container-pod.yaml` |
| Learn lesson | `learn-` | `learn-init-containers.yaml` |
| Debug/troubleshoot | `debug-` | `debug-crashloop.yaml` |

### 3. Write the YAML

Create your file in the appropriate `scenarios/domain-N/` directory.

**Minimal example** (`test/fixtures/valid/minimal-scenario.yaml`):

```yaml
id: test-minimal
domain: 1
title: "Run a minimal pod"
difficulty: easy
time_limit: 60
description: "Create a simple pod named nginx running the nginx image."

validations:
  - name: pod_exists
    type: resource_exists
    resource: pod/nginx
    namespace: drill-test-minimal

solution:
  steps:
    - "kubectl run nginx --image=nginx"
```

**Full example with all optional fields:**

```yaml
id: sc-sidecar-logging
domain: 1
title: "Add a sidecar logging container"
difficulty: medium
time_limit: 600
namespace: drill-sidecar-logging    # optional: defaults to drill-{id}
tags: [multi-container, sidecar]    # optional: for filtering

# Optional: shown in learn mode before the task
learn_intro: |
  The sidecar pattern adds a helper container to a pod that shares the
  same network and volume mounts as the main container. Common uses:
  log shipping, proxying, and configuration reloading.

description: |
  Create a pod named logger in namespace drill-sidecar-logging.
  The pod has two containers:
  - main: nginx image, writes logs to /var/log/app/access.log
  - sidecar: busybox image, tails the log file

hint: "Use an emptyDir volume shared between both containers."  # optional

# Optional: kubectl commands run before the scenario is shown
setup:
  - "kubectl create namespace drill-sidecar-logging"

validations:
  - name: pod_exists
    type: resource_exists
    resource: pod/logger
    namespace: drill-sidecar-logging

  - name: two_containers
    type: container_count
    resource: pod/logger
    namespace: drill-sidecar-logging
    expected: "2"

  - name: main_image
    type: container_image
    resource: pod/logger
    namespace: drill-sidecar-logging
    container: main
    expected: "nginx"

  - name: shared_volume
    type: volume_mount
    resource: pod/logger
    namespace: drill-sidecar-logging
    container: main
    mount_path: /var/log/app

solution:
  steps:
    - |
      kubectl apply -f - <<'EOF'
      apiVersion: v1
      kind: Pod
      metadata:
        name: logger
        namespace: drill-sidecar-logging
      spec:
        containers:
        - name: main
          image: nginx
          volumeMounts:
          - name: logs
            mountPath: /var/log/app
        - name: sidecar
          image: busybox
          command: [sh, -c, "tail -f /var/log/app/access.log"]
          volumeMounts:
          - name: logs
            mountPath: /var/log/app
        volumes:
        - name: logs
          emptyDir: {}
      EOF
```

### 4. Required fields reference

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier, kebab-case (e.g., `sc-my-scenario`) |
| `domain` | integer | 1-5, matching CKAD exam domains |
| `title` | string | Short title shown in listings |
| `difficulty` | string | `easy`, `medium`, or `hard` |
| `time_limit` | integer | Time limit in seconds |
| `description` | string | The task the user must complete (supports multi-line) |
| `validations` | array | One or more validation checks (see below) |
| `solution.steps` | array | Kubectl commands that solve the task |

### 5. Validation types reference

| Type | Required fields | Description |
|------|----------------|-------------|
| `resource_exists` | `resource`, `namespace` | Check a resource exists (`pod/nginx`, `deploy/web`) |
| `resource_field` | `resource`, `namespace`, `jsonpath`, `expected` | Check a jsonpath value (`{.spec.replicas}`) |
| `container_count` | `resource`, `namespace`, `expected` | Count containers in a pod |
| `container_image` | `resource`, `namespace`, `container`, `expected` | Check container image |
| `container_env` | `resource`, `namespace`, `container`, `env_name`, `expected` | Check env var value |
| `volume_mount` | `resource`, `namespace`, `container`, `mount_path` | Check a volume mount exists |
| `container_running` | `resource`, `namespace`, `container` | Check container is in Running state |
| `label_selector` | `resource`, `namespace`, `selector` | Check label selector matches resources |
| `resource_count` | `resource`, `namespace`, `expected` | Count resources matching a type |
| `command_output` | `command`, `expected` | Run a command and check its output |

**Example — resource_field:**

```yaml
validations:
  - name: replicas
    type: resource_field
    resource: deployment/web
    namespace: drill-deploy
    jsonpath: "{.spec.replicas}"
    expected: "3"
```

### 6. Validate your scenario

```bash
# Start the cluster if not already running
ckad-drill start

# Validate your scenario file
ckad-drill validate-scenario scenarios/domain-1/sc-my-scenario.yaml

# Validate all files in a directory
ckad-drill validate-scenario scenarios/domain-1/
```

`validate-scenario` checks YAML schema (required fields, valid types, valid difficulty) without running against the cluster.

## Running Tests

```bash
# Static analysis
make shellcheck

# Unit tests (no cluster required, ~30 seconds)
make test-unit

# Full test suite (requires running cluster)
ckad-drill start
make test
```

## PR Checklist

Before submitting:

- [ ] Scenario YAML passes `ckad-drill validate-scenario`
- [ ] `make shellcheck` passes with no errors
- [ ] `make test-unit` passes
- [ ] Scenario `id` is unique (search `scenarios/` for conflicts)
- [ ] Scenario is in the correct `domain` (1-5)
- [ ] Difficulty matches the expected completion time
- [ ] At least one validation check that fails before the solution is applied
- [ ] Solution steps actually solve the task (test manually with `ckad-drill drill` + `ckad-drill check`)
- [ ] `namespace` field uses a realistic name matching the scenario (not `default`)

## Project Structure

```
bin/ckad-drill          # Main CLI entrypoint
lib/
  common.sh             # Shared utilities, constants
  cluster.sh            # kind cluster management
  scenario.sh           # Scenario loading, display, cleanup
  validator.sh          # kubectl-based validation engine
  session.sh            # Drill/exam session state
  progress.sh           # Progress tracking
  timer.sh              # Shell prompt timer
  exam.sh               # Exam mode logic
  learn.sh              # Learn mode logic
scenarios/
  domain-1/             # Application Design and Build
  domain-2/             # Application Deployment
  domain-3/             # Observability and Maintenance
  domain-4/             # Environment, Config, and Security
  domain-5/             # Services and Networking
test/
  unit/                 # bats unit tests (no cluster)
  integration/          # bats integration tests (kind cluster)
  fixtures/             # Test YAML fixtures
scripts/
  install.sh            # End-user installer
  dev-setup.sh          # Dev environment setup
```

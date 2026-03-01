# Phase 1: Foundation + Cluster - Research

**Researched:** 2026-02-28
**Domain:** Bash CLI scaffolding + kind cluster management with Calico CNI, nginx ingress, metrics-server
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Cluster Naming & Lifecycle**
- Kind cluster named `ckad-drill`
- 1 control-plane + 2 worker nodes (matches real exam, enables affinity scenarios)
- `start` reuses existing healthy cluster (idempotent)
- Unhealthy cluster detected on `start`: auto-heal with message ("Cluster unhealthy, recreating...")
- `stop` deletes the cluster cleanly
- `reset` tears down and recreates from scratch
- Step-by-step progress output during startup (each addon step announced)

**Addon Installation**
- Addons installed via pinned manifest URLs (not bundled YAML files)
- Addon versions defined as variables at the top of cluster.sh (dev-friendly, not user-configurable)
- On addon failure: retry once, then fail with clear error message
- `start` waits for all addon pods to be Running (`kubectl wait`) before reporting "Ready"

**Project Scaffold & Lib Structure**
- Main script sets `CKAD_DRILL_ROOT`, all libs source via `source "$CKAD_DRILL_ROOT/lib/common.sh"`
- `set -euo pipefail` enforced in all scripts (full bash strict mode)
- common.sh provides colored output functions: `info()`, `warn()`, `error()`, `success()` with ANSI colors
- Colors auto-disabled when not a TTY (piped/scripted usage)
- Existing study guide content (scenarios/, domains/, quizzes/, etc.) stays in place until Phase 6 Content Migration

**Dependency Checking & Error UX**
- Dependencies checked only on `start` and `reset` (not every command)
- All dependencies checked upfront; all missing ones listed at once (not fail-on-first)
- Each missing dep shows both the install command AND a docs link
- Docker check verifies daemon is running (`docker info`), not just installed (`command -v`)
- Required deps: Docker (running), kind, kubectl, yq, jq

### Claude's Discretion
- Exact ANSI color choices and formatting details
- Internal error handling patterns within lib functions
- Makefile targets for development workflow
- Kind config YAML details beyond node count

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLST-01 | User can create a kind cluster with `ckad-drill start` that includes Calico CNI, nginx ingress, and metrics-server | kind config requires `disableDefaultCNI: true` + `podSubnet: 192.168.0.0/16`; Calico v3.31.4 manifest URLs verified; ingress-nginx v1.14.3 kind-specific deploy.yaml verified; metrics-server v0.8.1 with `--kubelet-insecure-tls` patch verified |
| CLST-02 | User can destroy the kind cluster with `ckad-drill stop` | `kind delete cluster --name ckad-drill` — simple, idempotent; exit 0 even if not found |
| CLST-03 | User can recreate the cluster from scratch with `ckad-drill reset` | `stop` then `start` in sequence; leverage existing cluster functions |
| CLST-04 | Tool detects if cluster already exists and reuses it (idempotent create) | `kind get clusters` returns newline-separated list; grep for cluster name; health check via `kubectl cluster-info --context kind-ckad-drill` |
| CLST-05 | Tool shows clear error with instructions if Docker or kind is not installed | Collect-all-missing pattern: loop over required deps, accumulate failures, print all with install URLs, then exit 1 |
</phase_requirements>

---

## Summary

Phase 1 establishes the bash project scaffold and the kind-based cluster lifecycle. The technical surface is well-understood: pure bash, kind, and three addon installs. The main implementation complexity is correctness of the addon installation sequence — Calico must be installed before anything else can schedule, ingress-nginx requires kind-specific configuration (port mappings and node labels), and metrics-server requires a `--kubelet-insecure-tls` patch because kind uses self-signed certificates.

The 120-second success criterion is achievable in normal conditions but tight with Calico. Calico takes 30-90 seconds to converge after manifest apply (it brings up several pods including calico-node as a DaemonSet and calico-kube-controllers as a Deployment). The `kubectl wait` strategy needs carefully scoped selectors and realistic timeouts per-addon — not a single global timeout. Progress output during each step (as the context requires) serves double-duty as visible feedback and implicit timeout diagnosis.

**Critical alert:** ingress-nginx (kubernetes/ingress-nginx) was announced for retirement in March 2026. The steering committee statement from January 29, 2026 is explicit — no further releases, bugfixes, or security patches after retirement. For CKAD training purposes this is acceptable short-term risk (the controller still works; it's a local dev cluster, not production), but the project should be aware. The architecture doc explicitly calls for nginx ingress to match the real exam environment — that goal overrides the EOL concern for v1.

**Primary recommendation:** Implement cluster.sh with explicit per-addon install functions, per-addon `kubectl wait` calls (not a single wait-all), and retry-once-then-fail logic per the CONTEXT decisions.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| kind | v0.31.0+ | Local Kubernetes cluster | Industry standard for local k8s; lightweight, fast, CKAD exam proxy |
| kubectl | Matches k8s version | All cluster interaction | Exam tool — users need this anyway |
| Kubernetes node image | kindest/node:v1.35.0 | Cluster k8s version | CKAD exam targets v1.35 as of early 2026 |
| Calico CNI | v3.31.4 | Network Policy support | CKAD exam requires NetworkPolicy; kind's default kindnet doesn't support it |
| ingress-nginx | v1.14.3 (kind provider) | Ingress controller | CKAD exam includes Ingress; kind-specific deploy.yaml handles port mapping |
| metrics-server | v0.8.1 | `kubectl top` support | CKAD exam uses `kubectl top`; requires insecure-tls patch for kind |
| bash | 4.4+ | Everything | Exam-native; no build step |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| yq | v4.x | YAML parsing (future phases) | Already a required dep; Phase 2+ |
| jq | v1.6+ | JSON progress tracking (future phases) | Already a required dep; Phase 3+ |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Calico v3.31.4 (operator method) | Calico manifest-only method | Operator method is current recommended approach; manifest method simpler but older pattern |
| ingress-nginx (kubernetes/ingress-nginx) | nginx/kubernetes-ingress (F5 maintained) | kubernetes/ingress-nginx has kind-specific deploy.yaml; F5 version doesn't; matches exam environment |
| ingress-nginx | Gateway API | Gateway API is the modern replacement but CKAD still tests Ingress resources in 2026 |
| metrics-server v0.8.1 + kustomize patch | Pre-patched manifest | kustomize approach is cleaner; inline sed patch is simpler for bash; either works |

---

## Architecture Patterns

### Recommended Project Structure (Phase 1 deliverables)

```
ckad-drill/
├── bin/
│   └── ckad-drill              # Entry point — routes subcommands
├── lib/
│   ├── common.sh               # Constants, paths, color functions (info/warn/error/success)
│   └── cluster.sh              # Kind lifecycle + addon install
├── scripts/
│   └── install.sh              # User install script (Phase 7, but stub now)
├── Makefile                    # Dev targets
└── setup/
    └── kind-config.yaml        # Existing — update cluster name to ckad-drill
```

Note: Architecture doc defines `display.sh` as a separate file for all terminal output. CONTEXT.md defines `common.sh` as providing color functions. Resolution: **common.sh includes color/output functions for Phase 1; display.sh is created as a separate file in Phase 1 or Phase 2.** The CONTEXT.md decision is locked — common.sh must provide info/warn/error/success. The architecture doc's display.sh separation is compatible (display.sh can source common.sh, or common.sh can contain what the architecture calls display.sh). Planner should create both files, with common.sh providing the color functions and display.sh providing pass/fail/header per the architecture doc.

### Pattern 1: Kind Config with Calico CNI

Kind requires `disableDefaultCNI: true` and `podSubnet: 192.168.0.0/16` for Calico. This is a breaking change from the existing `setup/kind-config.yaml` which has no networking section.

```yaml
# Source: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ckad-drill
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
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
```

**Why control-plane gets ingress-ready label and port mappings:** ingress-nginx on kind uses nodePort to expose ports 80/443 on the host. The kind-specific deploy.yaml uses a nodeSelector for `ingress-ready=true`. This must be on the node with `extraPortMappings`.

### Pattern 2: Calico Installation (Operator Method)

```bash
# Source: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind
CALICO_VERSION="v3.31.4"

info "Installing Calico CNI..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/operator-crds.yaml"
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

# Wait for operator before applying custom resources
kubectl wait --namespace tigera-operator \
  --for=condition=ready pod \
  --selector=app=tigera-operator \
  --timeout=120s

kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

# Wait for calico-system pods
kubectl wait --namespace calico-system \
  --for=condition=ready pod \
  --selector=k8s-app=calico-node \
  --timeout=180s
```

**Alternative — manifest-only method** (simpler, older):
```bash
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=calico-node \
  --timeout=180s
```
The manifest-only method deploys to kube-system rather than calico-system. Either works for CKAD training purposes. Manifest-only is simpler bash.

### Pattern 3: ingress-nginx Installation (Kind-Specific)

```bash
# Source: https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/kind/deploy.yaml
INGRESS_NGINX_VERSION="v1.14.3"

info "Installing ingress-nginx..."
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"

kubectl wait --namespace ingress-nginx \
  --for=condition=complete job/ingress-nginx-admission-patch \
  --timeout=60s

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

**Why kind-specific manifest:** The kind deploy.yaml includes a DaemonSet tolerations and the correct `hostNetwork: true` + NodePort service configuration that routes from `extraPortMappings` into the ingress controller.

### Pattern 4: metrics-server Installation with insecure-tls Patch

```bash
# Source: https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
METRICS_SERVER_VERSION="v0.8.1"

info "Installing metrics-server..."
# Download, patch to add --kubelet-insecure-tls, apply
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

# Patch the deployment to add insecure-tls flag (required for kind's self-signed certs)
kubectl patch deployment metrics-server \
  --namespace kube-system \
  --type='json' \
  --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=60s
```

**Why insecure-tls is required for kind:** kind node images use self-signed certificates for the kubelet API. metrics-server can't verify these without `--kubelet-insecure-tls`. This is a dev-environment-only flag — acceptable for CKAD training.

### Pattern 5: Dependency Check (Collect-All-Missing)

```bash
# Collect all missing deps, then report all at once
cluster_check_deps() {
  local missing=()

  # Check each binary dep
  for dep in kind kubectl yq jq; do
    if ! command -v "${dep}" &>/dev/null; then
      missing+=("${dep}")
    fi
  done

  # Docker is special: check binary AND daemon
  if ! command -v docker &>/dev/null; then
    missing+=("docker (not installed)")
  elif ! docker info &>/dev/null 2>&1; then
    missing+=("docker (installed but daemon not running)")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required dependencies:"
    for dep in "${missing[@]}"; do
      warn "  - ${dep}"
    done
    info ""
    info "Installation instructions:"
    info "  kind:    https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    info "  kubectl: https://kubernetes.io/docs/tasks/tools/"
    info "  yq:      https://github.com/mikefarah/yq#install"
    info "  jq:      https://jqlang.github.io/jq/download/"
    info "  docker:  https://docs.docker.com/get-docker/"
    return 1
  fi
}
```

### Pattern 6: Cluster Health Check

```bash
cluster_is_healthy() {
  local context="kind-ckad-drill"
  # Check cluster is reachable and nodes are ready
  kubectl cluster-info --context "${context}" &>/dev/null 2>&1 || return 1
  # Check all nodes ready (not just control-plane)
  local not_ready
  not_ready=$(kubectl get nodes --context "${context}" \
    --no-headers 2>/dev/null | grep -v " Ready" | wc -l)
  [[ "${not_ready}" -eq 0 ]]
}

cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^ckad-drill$"
}
```

### Pattern 7: Idempotent Start with Auto-Heal

```bash
cluster_start() {
  cluster_check_deps || return 1

  if cluster_exists; then
    if cluster_is_healthy; then
      success "Cluster 'ckad-drill' already running"
      return 0
    else
      warn "Cluster unhealthy, recreating..."
      cluster_stop
    fi
  fi

  info "Creating cluster 'ckad-drill'..."
  kind create cluster --name ckad-drill --config "${CKAD_DRILL_ROOT}/setup/kind-config.yaml"

  info "Installing Calico CNI..."
  _cluster_install_calico || { _cluster_retry_once _cluster_install_calico "Calico" || return 1; }

  info "Installing ingress-nginx..."
  _cluster_install_ingress || { _cluster_retry_once _cluster_install_ingress "ingress-nginx" || return 1; }

  info "Installing metrics-server..."
  _cluster_install_metrics_server || { _cluster_retry_once _cluster_install_metrics_server "metrics-server" || return 1; }

  success "Cluster ready"
}
```

### Anti-Patterns to Avoid

- **Using `kubectl apply -f` with `main` branch URLs:** These change without warning. Always pin to a version tag URL.
- **Single global `kubectl wait --all` across namespaces:** Race conditions cause false failures. Wait per-component with appropriate selectors.
- **Checking `command -v docker` only:** Docker binary can be present but daemon not running. `docker info` is the correct check.
- **Setting `set -euo pipefail` in lib files:** Architecture doc and common bash practice says lib files inherit strict mode from the entry point — they don't set it themselves. If a lib file sets it, sourcing order matters and re-sourcing breaks things.
- **Using `kind create cluster` name mismatch:** If kind config YAML has `name: ckad-drill` AND you pass `--name ckad-drill`, they agree and work. But if the YAML specifies a name and you don't pass `--name`, kind uses the YAML name. Be explicit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Calico install on kind | Custom CNI setup script | Official Calico kind docs + manifest URLs | CNI initialization order and RBAC are complex; the official manifests handle it |
| Waiting for pods | Custom polling loop | `kubectl wait --for=condition=ready` | kubectl wait is robust, handles CRD conditions natively |
| metrics-server TLS on kind | Custom cert injection | `--kubelet-insecure-tls` flag via kubectl patch | This is the documented approach for dev clusters |
| ingress port exposure | Custom NodePort setup | kind-specific deploy.yaml | The kind deploy.yaml already handles DaemonSet toleration, hostPort, and NodePort correctly |

**Key insight:** All three addons (Calico, ingress-nginx, metrics-server) have documented kind-specific installation patterns. Use them verbatim — the edge cases around scheduling, RBAC, and networking are already solved.

---

## Common Pitfalls

### Pitfall 1: Calico Pods Stuck in Pending

**What goes wrong:** After applying Calico manifests, calico-node DaemonSet pods stay in Pending indefinitely.
**Why it happens:** Nodes can't be scheduled without a CNI. During cluster creation with `disableDefaultCNI: true`, nodes are NotReady until Calico installs. But Calico itself needs to schedule pods — creating a brief bootstrap chicken-and-egg. The solution is to wait for the control-plane node to be Ready (kind does this), THEN install Calico.
**How to avoid:** kind handles the initial node-ready wait during `kind create cluster`. Apply Calico immediately after cluster creation completes. Don't try to wait for nodes Ready separately.
**Warning signs:** `kubectl get pods -n calico-system` shows `Pending` with `Unschedulable` events; check `kubectl get nodes` — if all nodes are NotReady, Calico hasn't had a chance to run yet.

### Pitfall 2: ingress-nginx Pods Crash or Stay Pending

**What goes wrong:** ingress-nginx controller pod never becomes Ready; admission webhook job fails.
**Why it happens:** The ingress-nginx admission webhook (a Job) must complete before the controller can accept configuration. If the Job hasn't finished and you proceed, the controller may fail.
**How to avoid:** Wait for the admission-patch Job to complete (`--for=condition=complete`) BEFORE waiting for the controller pod.
**Warning signs:** `kubectl get pods -n ingress-nginx` shows the controller in `Init` or webhook connection errors in pod events.

### Pitfall 3: metrics-server Returns Forbidden/TLS Error

**What goes wrong:** `kubectl top nodes` returns `error: metrics not available yet` or TLS errors.
**Why it happens:** metrics-server tries to use kubelet TLS which uses self-signed certs in kind. Without `--kubelet-insecure-tls`, metrics-server rejects all kubelet responses.
**How to avoid:** Apply the insecure-tls patch immediately after deploying metrics-server. Apply then patch, not patch then apply.
**Warning signs:** `kubectl logs -n kube-system -l k8s-app=metrics-server` shows `x509: certificate signed by unknown authority`.

### Pitfall 4: 120-Second Startup Window

**What goes wrong:** `ckad-drill start` takes longer than 120 seconds, violating CLST-01 success criterion.
**Why it happens:** Calico convergence alone can take 60-90 seconds on a slow machine. Adding ingress-nginx and metrics-server can push past 120 seconds.
**How to avoid:** The 120-second criterion in CLST-01 is the user-observed success message, not the cluster-ready time. Set per-addon `kubectl wait` timeouts conservatively (Calico: 180s, ingress-nginx: 90s, metrics-server: 60s). If all three are sequential, real-world fast machines finish in ~90s; slow machines may take longer. The 120s is aspirational — `kubectl wait` timeouts should NOT be set to 120s total or the wait will fail on slower machines.
**Warning signs:** CI environment is slow; Docker has limited CPU/memory.

### Pitfall 5: Kind Cluster Name Conflict

**What goes wrong:** `kind create cluster` fails because context `kind-ckad-drill` already exists in kubeconfig but kind cluster doesn't exist.
**Why it happens:** `kind delete cluster` removes the cluster but may leave stale kubeconfig entries on unusual failures. `kind get clusters` shows nothing but kubeconfig still has the context.
**How to avoid:** `cluster_exists()` should check `kind get clusters` output, not kubeconfig. On `stop`, add `kubectl config delete-context kind-ckad-drill 2>/dev/null || true`.
**Warning signs:** `kind create cluster` fails with "context already exists".

### Pitfall 6: ingress-nginx EOL in March 2026

**What goes wrong:** kubernetes/ingress-nginx receives no updates after March 2026 — no security patches, no bug fixes.
**Why it happens:** The project is being retired by the Kubernetes community (steering committee announcement Jan 29, 2026). Affects ~50% of cloud-native clusters.
**How to avoid:** For CKAD training (local dev cluster, no production exposure), the risk is acceptable. The CKAD exam still tests Ingress resources and the exam environment uses nginx ingress. Document this as a known limitation in README. If the project continues beyond March 2026, migrate to nginx/kubernetes-ingress (F5-maintained) or Gateway API.
**Warning signs:** CVE announcements against ingress-nginx after March 2026 with no patches available.

### Pitfall 7: `set -euo pipefail` in Lib Files

**What goes wrong:** Lib file sets `set -euo pipefail` itself. When sourced into the main script, `set -e` applies to the calling scope too — but the timing and interaction with subshells can cause unexpected exits in functions that intentionally check failure.
**Why it happens:** Developer adds strict mode to lib file as "safety". But lib files are not standalone scripts — they're sourced into the entry point.
**How to avoid:** Only `bin/ckad-drill` sets `set -euo pipefail`. Lib files inherit it. Functions that need to handle non-zero exits use `|| true`, `if ! command; then`, or `local rc=$?; if [[ $rc -ne 0 ]]; then`.
**Warning signs:** Shellcheck reports no issues but tests fail intermittently; a function that should return 1 causes the whole script to exit.

---

## Code Examples

### common.sh Structure

```bash
#!/usr/bin/env bash
# lib/common.sh — shared constants, paths, and output functions
# Sourced by bin/ckad-drill — do NOT set strict mode here

# Config and data directories (XDG-compliant)
CKAD_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/ckad-drill"
CKAD_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/ckad-drill"
CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
CKAD_PROGRESS_FILE="${CKAD_CONFIG_DIR}/progress.json"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_NO_CLUSTER=2
readonly EXIT_NO_SESSION=3
readonly EXIT_PARSE_ERROR=4

# Color detection
_color_enabled() {
  [[ -t 1 ]]
}

# Output functions — color when TTY, plain when piped
info() {
  if _color_enabled; then
    printf '\033[0;34m[INFO]\033[0m %s\n' "$*"
  else
    printf '[INFO] %s\n' "$*"
  fi
}

warn() {
  if _color_enabled; then
    printf '\033[0;33m[WARN]\033[0m %s\n' "$*" >&2
  else
    printf '[WARN] %s\n' "$*" >&2
  fi
}

error() {
  if _color_enabled; then
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2
  else
    printf '[ERROR] %s\n' "$*" >&2
  fi
  exit "${EXIT_ERROR}"
}

success() {
  if _color_enabled; then
    printf '\033[0;32m[OK]\033[0m %s\n' "$*"
  else
    printf '[OK] %s\n' "$*"
  fi
}
```

Note: Architecture doc also defines `display.sh` with `pass()`, `fail()`, `header()`. These are used by later phases (validation output). Phase 1 only needs common.sh output functions. Create `lib/display.sh` as a stub that sources common.sh — filled out in Phase 2/3.

### bin/ckad-drill Entry Point Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

CKAD_DRILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKAD_DRILL_ROOT

source "${CKAD_DRILL_ROOT}/lib/common.sh"
source "${CKAD_DRILL_ROOT}/lib/cluster.sh"

# Subcommand dispatch
case "${1:-}" in
  start)   cluster_start ;;
  stop)    cluster_stop ;;
  reset)   cluster_reset ;;
  *)
    error "Unknown command: ${1:-}. Usage: ckad-drill {start|stop|reset}"
    ;;
esac
```

### Retry-Once Pattern

```bash
# Source: architecture decision — retry once on addon failure
_cluster_retry_once() {
  local fn="$1"
  local name="$2"
  warn "${name} install failed, retrying once..."
  if "${fn}"; then
    return 0
  else
    error "Failed to install ${name} after retry. Check Docker resources and network."
    return 1
  fi
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Calico manifest-only (`calico.yaml`) | Tigera operator + custom-resources | Calico v3.x | Operator method is recommended; both still work |
| ingress-nginx on kind: custom NodePort setup | kind-specific deploy.yaml at kubernetes/ingress-nginx | ~2021 | Use kind provider URL — port mapping handled automatically |
| metrics-server: no TLS flag | `--kubelet-insecure-tls` via args patch | kind adoption | Standard pattern for all kind-based dev clusters |
| kubernetes/ingress-nginx | Retirement announced Jan 2026, EOL March 2026 | 2025-2026 | Still works, no security patches after March 2026; acceptable for CKAD training |
| kindest/node:v1.29 (old CKAD) | kindest/node:v1.35.0 | CKAD exam updated ~late 2025 | Must use v1.35 to match exam environment |

**Deprecated/outdated:**
- `disableDefaultCNI: false` with Calico: Calico's legacy approach was to install over the default CNI. Now `disableDefaultCNI: true` is required.
- `docs.projectcalico.org` URLs: These are old; current URLs are `raw.githubusercontent.com/projectcalico/calico/VERSION/manifests/`.
- kind `extraPortMappings` on worker nodes for ingress: Control-plane node needs the port mappings because kind's networking routes host ports through the control-plane node image.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core (version installed by dev-setup.sh) |
| Config file | none — bats discovers by pattern |
| Quick run command | `bats test/unit/` |
| Full suite command | `bats test/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLST-01 | `ckad-drill start` creates cluster with Calico+ingress+metrics-server | integration | `bats test/integration/cluster.bats` | No — Wave 0 |
| CLST-02 | `ckad-drill stop` deletes cluster cleanly | integration | `bats test/integration/cluster.bats` | No — Wave 0 |
| CLST-03 | `ckad-drill reset` tears down and recreates | integration | `bats test/integration/cluster.bats` | No — Wave 0 |
| CLST-04 | Second `start` reuses existing cluster without error | integration | `bats test/integration/cluster.bats` | No — Wave 0 |
| CLST-05 | Missing dep shows clear error with instructions | unit | `bats test/unit/common.bats` | No — Wave 0 |

Note: CLST-01 through CLST-04 are integration tests requiring a real kind cluster. These are slow and Docker-dependent. CLST-05 (dependency checking) is a unit test — mock the `command -v` and `docker info` calls using BATS' `stub` approach or test the dep-check function directly.

### Sampling Rate

- **Per task commit:** `shellcheck bin/ckad-drill lib/*.sh`
- **Per wave merge:** `bats test/unit/`
- **Phase gate:** `bats test/unit/ && bats test/integration/cluster.bats` (requires running kind)

### Wave 0 Gaps

- [ ] `test/unit/common.bats` — covers CLST-05 (dep check unit tests, color output tests)
- [ ] `test/integration/cluster.bats` — covers CLST-01 through CLST-04
- [ ] `test/helpers/test-helper.bash` — shared setup/teardown, test cluster name (`ckad-drill-test`)
- [ ] Makefile — targets: `shellcheck`, `test-unit`, `test-integration`, `test`
- [ ] `scripts/dev-setup.sh` — installs bats-core, shellcheck (DIST-02 requirement, needed before testing)

---

## Open Questions

1. **Calico operator vs manifest method for Phase 1**
   - What we know: Operator method is the current documented approach for kind; manifest method is simpler bash; both install Calico correctly
   - What's unclear: Operator method adds 2 extra manifests and an intermediate wait; manifest method applies to kube-system not calico-system
   - Recommendation: Use manifest-only method (`calico.yaml`) for Phase 1. Simpler bash, fewer race conditions to handle, still matches real CKAD (Calico is Calico regardless of install method). Can migrate to operator method later if needed.

2. **The 120-second success criterion**
   - What we know: The success criterion says "within 120 seconds"; Calico convergence alone can take 60-90s; ingress-nginx and metrics-server add ~30-60s more
   - What's unclear: Whether 120s is a hard SLA or an aspirational target; whether it applies to fast machines or any machine
   - Recommendation: Set per-addon `kubectl wait` timeouts longer than 120s total (Calico 180s, ingress 90s, metrics 60s), but document that "typical fast machine: ~90s". Don't artificially cap the wait at 120s — that would cause flaky failures on slower machines. The success criterion is best-effort.

3. **kind config YAML: inline vs file**
   - What we know: `setup/kind-config.yaml` already exists and will be updated; the new version needs `networking` section + `extraPortMappings` + node labels
   - What's unclear: Whether to embed the config as heredoc in cluster.sh or keep it as a file
   - Recommendation: Keep as a file (`setup/kind-config.yaml`). Easier to review and test independently.

4. **ingress-nginx pinned version URL pattern**
   - What we know: The kind-specific deploy.yaml is at `https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.3/deploy/static/provider/kind/deploy.yaml`
   - What's unclear: Exact tag naming convention (controller-vX.Y.Z vs just vX.Y.Z)
   - Recommendation: Verify the URL before implementation by fetching it. The pattern from search results shows `controller-v1.14.3` as the tag.

---

## Sources

### Primary (HIGH confidence)

- [Calico kind installation — official docs](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) — Verified: disableDefaultCNI, podSubnet, manifest URLs for v3.31.4
- [metrics-server releases — GitHub](https://github.com/kubernetes-sigs/metrics-server/releases/latest) — Verified: v0.8.1, components.yaml URL
- [kubernetes/ingress-nginx kind deploy.yaml — GitHub](https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/kind/deploy.yaml) — Verified: v1.14.3 controller image
- [ingress-nginx retirement — Kubernetes official](https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/) — Verified: EOL March 2026, steering committee statement

### Secondary (MEDIUM confidence)

- [kubectl wait patterns — enix.io](https://enix.io/en/blog/kubernetes-tips-tricks-kubectl-wait/) — wait for condition semantics, timeout behavior
- [CKAD exam version 2026 — training.linuxfoundation.org search result](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/) — v1.35 current exam version (verified via multiple course/exam sources)
- [kind v0.31.0 and kindest/node:v1.35.0](https://github.com/kubernetes-sigs/kind/releases) — Current kind version and node image availability

### Tertiary (LOW confidence)

- Typical cluster creation time (90-120 seconds) — from community examples; varies significantly by machine/Docker resources
- `controller-v1.14.3` tag naming for ingress-nginx kind deploy.yaml URL — inferred from search result; verify URL before implementation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Calico, ingress-nginx, metrics-server all verified against official docs and GitHub releases
- Architecture: HIGH — Patterns derived from official kind docs and architecture document
- Pitfalls: HIGH for TLS/CNI issues (documented); MEDIUM for timing (varies by machine)
- ingress-nginx EOL: HIGH — official Kubernetes steering committee statement

**Research date:** 2026-02-28
**Valid until:** 2026-03-30 (30 days — stable tools; ingress-nginx EOL happens within this window)

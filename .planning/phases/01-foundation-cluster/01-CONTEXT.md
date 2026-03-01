# Phase 1: Foundation + Cluster - Context

**Gathered:** 2026-02-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Project scaffold with shared bash libraries, kind cluster management (`start`/`stop`/`reset`), and dependency checking. Delivers a working `ckad-drill start` that creates a fully configured cluster with Calico, nginx ingress, and metrics-server. Scenario engine, drill mode, and all other modes are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Cluster Naming & Lifecycle
- Kind cluster named `ckad-drill`
- 1 control-plane + 2 worker nodes (matches real exam, enables affinity scenarios)
- `start` reuses existing healthy cluster (idempotent)
- Unhealthy cluster detected on `start`: auto-heal with message ("Cluster unhealthy, recreating...")
- `stop` deletes the cluster cleanly
- `reset` tears down and recreates from scratch
- Step-by-step progress output during startup (each addon step announced)

### Addon Installation
- Addons installed via pinned manifest URLs (not bundled YAML files)
- Addon versions defined as variables at the top of cluster.sh (dev-friendly, not user-configurable)
- On addon failure: retry once, then fail with clear error message
- `start` waits for all addon pods to be Running (`kubectl wait`) before reporting "Ready"

### Project Scaffold & Lib Structure
- Main script sets `CKAD_DRILL_ROOT`, all libs source via `source "$CKAD_DRILL_ROOT/lib/common.sh"`
- `set -euo pipefail` enforced in all scripts (full bash strict mode)
- common.sh provides colored output functions: `info()`, `warn()`, `error()`, `success()` with ANSI colors
- Colors auto-disabled when not a TTY (piped/scripted usage)
- Existing study guide content (scenarios/, domains/, quizzes/, etc.) stays in place until Phase 6 Content Migration

### Dependency Checking & Error UX
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

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `setup/kind-config.yaml`: Existing kind cluster config (1 CP + 2 workers) — update cluster name from ckad-practice to ckad-drill
- `setup/cluster-setup.md`: Reference guide with kind commands, shell setup, troubleshooting — useful as reference for cluster.sh logic
- `setup/shell-setup.sh`: Existing shell setup script — may inform exam environment setup pattern

### Established Patterns
- No existing bash lib patterns — this phase establishes them from scratch
- Architecture doc defines the project structure: `bin/ckad-drill`, `lib/*.sh`, `scenarios/`, `test/`, `scripts/`

### Integration Points
- `bin/ckad-drill` is the main entry point that routes subcommands to lib functions
- `lib/cluster.sh` is consumed by the main script and later by scenario.sh (Phase 2) for cluster health checks
- `lib/common.sh` is sourced by every other lib file — foundational dependency
- Config/state directory: `~/.config/ckad-drill/` (session.json, progress.json)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-cluster*
*Context gathered: 2026-02-28*

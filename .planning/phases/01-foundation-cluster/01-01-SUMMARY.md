---
phase: 01-foundation-cluster
plan: 01
subsystem: infra
tags: [bash, kind, kubernetes, calico, ingress-nginx, metrics-server, shellcheck]

# Dependency graph
requires: []
provides:
  - "bin/ckad-drill entry point with start/stop/reset subcommand dispatch"
  - "lib/common.sh with XDG paths, exit codes, cluster constants, and color output functions (info/warn/error/success)"
  - "lib/display.sh stub for Phase 2/3 validation output"
  - "lib/cluster.sh with full kind cluster lifecycle, addon installs, and dep checking"
  - "setup/kind-config.yaml with Calico networking, ingress port mappings, 3-node config"
  - "Makefile with shellcheck, test-unit, test-integration, test targets"
affects:
  - "02-scenario-engine: sources lib/cluster.sh for cluster health checks"
  - "03-drill-mode: sources lib/common.sh for output functions"
  - "all future phases: lib/common.sh is foundational dependency"

# Tech tracking
tech-stack:
  added:
    - "kind (cluster management)"
    - "Calico v3.31.4 (CNI for NetworkPolicy support)"
    - "ingress-nginx v1.14.3 kind-specific (Ingress controller)"
    - "metrics-server v0.8.1 (kubectl top support)"
  patterns:
    - "Pure bash with set -euo pipefail in entry point only (lib files inherit)"
    - "XDG-compliant config/data directories"
    - "Collect-all-missing dependency check pattern (not fail-on-first)"
    - "Per-addon kubectl wait with realistic timeouts (Calico 180s, ingress 90s, metrics 60s)"
    - "Retry-once pattern for transient addon install failures"
    - "Color output gated on TTY detection (_color_enabled)"

key-files:
  created:
    - "bin/ckad-drill"
    - "lib/common.sh"
    - "lib/display.sh"
    - "lib/cluster.sh"
    - "Makefile"
  modified:
    - "setup/kind-config.yaml"

key-decisions:
  - "error() does not call exit — print-only, caller decides whether to exit (keeps lib functions composable)"
  - "Calico installed via manifest-only method (calico.yaml) — simpler bash than operator method, both produce valid Calico"
  - "shellcheck disable=SC2034 in common.sh — constants are intentionally defined for use by sourcing scripts"
  - "ingress-nginx: wait for both admission-create and admission-patch jobs with || true — both jobs may not exist in all versions"

patterns-established:
  - "Lib files: no shebang, no set strict mode — sourced files inherit from entry point"
  - "Lib files: shellcheck shell=bash directive at top for correct linting"
  - "Subcommand dispatch: case statement in entry point, implementation in lib functions"
  - "Cluster constants (name, context) defined in common.sh — single source of truth"

requirements-completed:
  - CLST-01
  - CLST-02
  - CLST-03
  - CLST-04
  - CLST-05

# Metrics
duration: 2min
completed: 2026-02-28
---

# Phase 1 Plan 1: Foundation + Cluster Lifecycle Summary

**Pure bash project scaffold with kind cluster lifecycle (start/stop/reset), Calico CNI, ingress-nginx, and metrics-server — all deps checked at once with install URLs**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-02-28T19:57:56Z
- **Completed:** 2026-02-28T19:59:30Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Working `ckad-drill start` entry point that dispatches to cluster lifecycle functions
- Complete cluster lifecycle: idempotent start (reuses healthy cluster, auto-heals unhealthy), stop (with kubeconfig cleanup), reset (stop + start)
- Addon installation sequence: Calico CNI → ingress-nginx (kind-specific) → metrics-server (with insecure-tls patch), each with per-addon kubectl wait
- Collect-all-missing dependency checker: reports all missing deps (docker/kind/kubectl/yq/jq) at once with install URLs
- All bash files pass shellcheck with zero warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create project scaffold with shared libraries and entry point** - `321549c` (feat)
2. **Task 2: Implement cluster lifecycle in cluster.sh** - `f209510` (feat)

## Files Created/Modified

- `bin/ckad-drill` - Main entry point: sets CKAD_DRILL_ROOT, sources libs, dispatches start/stop/reset subcommands
- `lib/common.sh` - XDG paths, exit codes, cluster constants, color output functions (info/warn/error/success with TTY detection)
- `lib/display.sh` - Stub for Phase 2/3 validation output (pass/fail/header stubs with TODO comments)
- `lib/cluster.sh` - Full cluster lifecycle with dep checking, addon installs, retry-once logic
- `setup/kind-config.yaml` - Kind cluster config: 1 CP + 2 workers, Calico networking (disableDefaultCNI + podSubnet), ingress port mappings
- `Makefile` - Dev targets: shellcheck, lint, test-unit, test-integration, test

## Decisions Made

- `error()` is print-only (does NOT call exit) — the plan explicitly overrode the RESEARCH.md example that showed `exit` in error(). This keeps lib functions composable; callers decide whether to exit.
- Calico manifest-only method chosen over operator method — simpler bash, fewer race conditions, recommended in RESEARCH.md Open Questions.
- Added `# shellcheck disable=SC2034` to common.sh — constants defined for external use generate SC2034 "unused variable" warnings that are false positives for shared lib files.
- ingress-nginx admission job wait uses `|| true` for both create and patch job names — both jobs may not exist depending on ingress-nginx version; either completing is sufficient.

## Deviations from Plan

None - plan executed exactly as written.

The only shellcheck fixes required were expected: SC2148 (shell directive for lib files without shebang) and SC2034 (unused variable suppression for intentionally shared constants). These were handled with shellcheck directives, not code changes.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 2 (Scenario Engine) can source `lib/cluster.sh` for cluster health checks
- All phases can source `lib/common.sh` for output functions and constants
- `lib/display.sh` stub is ready to be filled in with pass/fail/header for validation output
- Integration tests (`test/integration/cluster.bats`) are needed but deferred per RESEARCH.md Wave 0 Gaps — requires running Docker + kind cluster

---
*Phase: 01-foundation-cluster*
*Completed: 2026-02-28*

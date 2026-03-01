---
phase: 06-content-migration
plan: 01
subsystem: content
tags: [yaml, scenarios, domain-1, domain-2, domain-3, kubectl, helm, kubernetes]

# Dependency graph
requires:
  - phase: 05-learn-mode
    provides: YAML scenario schema consumed by lib/scenario.sh and lib/validator.sh
provides:
  - "18 new YAML scenario files across domains 1-3 with typed validations"
  - "Domain 1: 6 YAML scenarios (init container, job, cronjob, PVC+pod, commands/args + existing multi-container)"
  - "Domain 2: 7 YAML scenarios (rolling-update, rollback, helm, scale-update, canary, HPA, rollout-pause-resume)"
  - "Domain 3: 6 YAML scenarios (liveness-probe, readiness-probe, debug-crash, logging, fix-probe, kubectl-debug)"
affects: [06-content-migration plan-02, drill mode, exam mode, learn mode]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "setup.commands for debug scenarios that need pre-broken resources"
    - "setup.manifest for fix-it scenarios with broken YAML to apply first"
    - "Realistic namespace names (batch-ops, canary-lab, autoscale-ns, probe-fix-ns) not drill-<id>"
    - "tags: [helm] on helm scenario gates helm binary check"

key-files:
  created:
    - scenarios/domain-1/sc-init-container.yaml
    - scenarios/domain-1/sc-job.yaml
    - scenarios/domain-1/sc-cronjob.yaml
    - scenarios/domain-1/sc-pod-with-pvc.yaml
    - scenarios/domain-1/sc-commands-args.yaml
    - scenarios/domain-2/sc-rolling-update.yaml
    - scenarios/domain-2/sc-rollback.yaml
    - scenarios/domain-2/sc-helm.yaml
    - scenarios/domain-2/sc-scale-update.yaml
    - scenarios/domain-2/sc-canary.yaml
    - scenarios/domain-2/sc-hpa.yaml
    - scenarios/domain-2/sc-rollout-pause-resume.yaml
    - scenarios/domain-3/sc-liveness-probe.yaml
    - scenarios/domain-3/sc-readiness-probe.yaml
    - scenarios/domain-3/sc-debug-crash.yaml
    - scenarios/domain-3/sc-logging.yaml
    - scenarios/domain-3/sc-fix-probe.yaml
    - scenarios/domain-3/sc-kubectl-debug.yaml
  modified: []

key-decisions:
  - "sc-configmap-secret already in domain-4 (not domain-2) — domain-2 has 7 not 8 total files"
  - "sc-network-policy not on disk — plan's '1 existing + 6 new = 7' for domain-3 becomes 6 new only"
  - "debug-crash and fix-probe use setup block to pre-create broken resources"
  - "kubectl-debug solution uses --copy-to approach (non-interactive) to avoid tty requirement in drill mode"

patterns-established:
  - "setup.commands: array of kubectl commands to run before scenario starts (creates broken state)"
  - "setup.manifest: inline YAML string applied before scenario (broken pod/config for fix-it scenarios)"
  - "All scenarios use namespace create with --dry-run=client -o yaml | kubectl apply -f - pattern"

requirements-completed: [CONT-01]

# Metrics
duration: 5min
completed: 2026-03-01
---

# Phase 6 Plan 1: Content Migration Domains 1-3 Summary

**18 YAML scenario files with typed validations migrated from markdown across domains 1-3: Jobs, CronJobs, PVC mounts, Helm, HPA, canary deployments, liveness/readiness/startup probes, and debug workflows.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-01T02:47:57Z
- **Completed:** 2026-03-01T02:52:29Z
- **Tasks:** 2
- **Files modified:** 18 created

## Accomplishments
- Domain 1 (design-build): 5 new YAML scenarios covering init containers, Jobs with completions/parallelism, CronJobs with history limits, PVC+Pod mounts, and command/args overrides
- Domain 2 (deployment): 7 new YAML scenarios covering rolling updates, rollbacks, Helm install/upgrade/rollback, scaling, canary with shared service, HPA, and pause/resume rollouts
- Domain 3 (observability): 6 new YAML scenarios covering liveness probes, triple-probe configuration, CrashLoopBackOff debugging, log access patterns, misconfigured probe fix, and kubectl debug ephemeral containers
- All scenarios use realistic namespace names, 2-5 typed validations, and complete solution.steps arrays

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert Domain 1 and Domain 2 markdown scenarios to YAML** - `bb02586` (feat)
2. **Task 2: Convert Domain 3 markdown scenarios to YAML** - `ef00698` (feat)

**Plan metadata:** (docs: complete plan — see below)

## Files Created/Modified
- `scenarios/domain-1/sc-init-container.yaml` - Init container with emptyDir volume shared to nginx
- `scenarios/domain-1/sc-job.yaml` - Job with completions=3, parallelism=2, backoffLimit=4
- `scenarios/domain-1/sc-cronjob.yaml` - CronJob every 10min with history limits and Forbid policy
- `scenarios/domain-1/sc-pod-with-pvc.yaml` - PVC 200Mi ReadWriteOnce mounted at /data in nginx pod
- `scenarios/domain-1/sc-commands-args.yaml` - Two pods: command override + env var in args
- `scenarios/domain-2/sc-rolling-update.yaml` - Deploy with RollingUpdate maxSurge=1, update to nginx:1.21
- `scenarios/domain-2/sc-rollback.yaml` - Deploy 3 image updates then rollback to revision 1
- `scenarios/domain-2/sc-helm.yaml` - Helm install bitnami/nginx, upgrade replicaCount, rollback (tags:[helm])
- `scenarios/domain-2/sc-scale-update.yaml` - Scale frontend from 2 to 5, update to httpd:2.4-alpine
- `scenarios/domain-2/sc-canary.yaml` - 4 stable + 1 canary replicas sharing app=myapp service
- `scenarios/domain-2/sc-hpa.yaml` - HPA min=2 max=8 cpu-percent=60 with resource requests
- `scenarios/domain-2/sc-rollout-pause-resume.yaml` - Pause rollout mid-update then resume to completion
- `scenarios/domain-3/sc-liveness-probe.yaml` - HTTP liveness probe port 80 with initialDelay=5
- `scenarios/domain-3/sc-readiness-probe.yaml` - Startup + liveness (/healthz) + readiness (/ready) probes
- `scenarios/domain-3/sc-debug-crash.yaml` - Debug CrashLoopBackOff (setup: broken pod), fix with sleep 3600
- `scenarios/domain-3/sc-logging.yaml` - Deployment log access: label selector, tail, follow patterns
- `scenarios/domain-3/sc-fix-probe.yaml` - Fix probe port 8080->80 (setup: broken probe manifest)
- `scenarios/domain-3/sc-kubectl-debug.yaml` - kubectl debug with --copy-to for ephemeral container access

## Decisions Made
- `sc-configmap-secret` is already in `scenarios/domain-4/` (pre-migrated). Domain 2 therefore has 7 not 8 total YAMLs — the plan's "1 existing + 7 new = 8" assumed it was still in domain-2.
- `sc-network-policy.yaml` does not exist on disk. The plan context showed it as an existing file in domain-3, but it has not yet been created. Domain 3 has 6 new YAMLs rather than 7 total.
- debug-crash and fix-probe use the `setup` block to pre-create broken resources before the student starts. This is the correct pattern for fix-it scenarios.
- kubectl-debug solution uses `--copy-to` (non-interactive background run) rather than the interactive `-it` flag to avoid TTY requirement in automated drill mode.

## Deviations from Plan

None - plan executed as written. Minor count discrepancy in success criteria (domain-2 = 7 files, domain-3 = 6 files vs planned 8 and 7 respectively) is because referenced "existing" files (sc-configmap-secret, sc-network-policy) were not on disk as assumed in the plan. All 18 new YAML files specified in the plan frontmatter (`files_modified`) were created.

## Issues Encountered

- `sc-configmap-secret.yaml` found in `scenarios/domain-4/` not `scenarios/domain-2/` — this was already migrated in a prior step. No action needed, plan's success criteria for 18 new files still met.
- `sc-network-policy.yaml` not on disk — the plan references it as an existing file but it hasn't been created yet. It will be created in Plan 02 (domain-5 scenarios).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- 18 YAML scenarios ready for drill/exam/learn mode consumption
- Plan 02 ready to execute: domain 4 (environment config, security), domain 5 (networking, services), and any remaining scenarios
- All files follow the YAML schema consumed by lib/scenario.sh and lib/validator.sh

---
*Phase: 06-content-migration*
*Completed: 2026-03-01*

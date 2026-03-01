---
phase: 06-content-migration
plan: "04"
subsystem: content
tags: [learn-mode, yaml, scenarios, tutorials, ckad]

requires:
  - phase: 05-learn-mode
    provides: "learn_intro field in YAML, lib/learn.sh learn_discover that filters by non-empty learn_intro"

provides:
  - "16 learn-prefix YAML scenario files with concept text across all 5 domains"
  - "Domain 1: learn-pods-volumes, learn-init-containers, learn-multi-container, learn-jobs-cronjobs"
  - "Domain 2: learn-deployments, learn-rolling-updates, learn-rollbacks"
  - "Domain 3: learn-probes, learn-debugging, learn-logging"
  - "Domain 4: learn-configmaps, learn-secrets, learn-security-context"
  - "Domain 5: learn-services, learn-ingress, learn-network-policies"

affects:
  - lib/learn.sh (learn_discover will find all 16 scenarios via learn_intro field)
  - ckad-drill learn command (now has content to serve)

tech-stack:
  added: []
  patterns:
    - "learn_intro field as YAML block scalar (>) with 2-5 sentence concept explanation"
    - "Progressive difficulty within domain: easy scenarios before medium"
    - "Solution steps include both imperative shortcuts and YAML manifests"
    - "Validations use resource_exists, jsonpath, container_image, pod_phase types"

key-files:
  created:
    - scenarios/domain-1/learn-pods-volumes.yaml
    - scenarios/domain-1/learn-init-containers.yaml
    - scenarios/domain-1/learn-multi-container.yaml
    - scenarios/domain-1/learn-jobs-cronjobs.yaml
    - scenarios/domain-2/learn-deployments.yaml
    - scenarios/domain-2/learn-rolling-updates.yaml
    - scenarios/domain-2/learn-rollbacks.yaml
    - scenarios/domain-3/learn-probes.yaml
    - scenarios/domain-3/learn-debugging.yaml
    - scenarios/domain-3/learn-logging.yaml
    - scenarios/domain-4/learn-configmaps.yaml
    - scenarios/domain-4/learn-secrets.yaml
    - scenarios/domain-4/learn-security-context.yaml
    - scenarios/domain-5/learn-services.yaml
    - scenarios/domain-5/learn-ingress.yaml
    - scenarios/domain-5/learn-network-policies.yaml
  modified: []

key-decisions:
  - "learn_intro extracted directly from tutorial lesson prose — not invented or paraphrased from scratch"
  - "Domain 4 and 5 directories created (domain-4/, domain-5/) as they did not exist yet"
  - "Difficulty ordering: easy before medium within each domain for progressive learning"
  - "Quiz questions not converted — all quiz questions in source files are knowledge-based recall, not practical tasks"

patterns-established:
  - "learn_intro: > (block scalar) for 2-5 sentences covering WHY and HOW of the concept"
  - "Simpler tasks than drill scenarios — learning exercises focus on one core concept per scenario"
  - "1-3 validations per learn scenario (fewer than drill scenarios)"
  - "solution.steps includes imperative shortcuts as first approach, YAML manifests as fallback"

requirements-completed: [CONT-03, CONT-04, CONT-05]

duration: 8min
completed: 2026-02-28
---

# Phase 6 Plan 4: Learn Scenarios Extraction Summary

**16 learn-prefix YAML scenario files extracted from tutorials across all 5 CKAD domains with progressive difficulty ordering and concept text in learn_intro field**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-02-28
- **Completed:** 2026-02-28
- **Tasks:** 2
- **Files modified:** 16 created

## Accomplishments

- 10 learn scenarios for Domains 1-3 extracted from tutorial lessons with concept text sourced directly from tutorial prose
- 6 learn scenarios for Domains 4-5 extracted covering ConfigMaps, Secrets, SecurityContext, Services, Ingress, and NetworkPolicy
- Created domain-4/ and domain-5/ directories that did not yet exist
- All 16 scenarios have learn_intro, validations, and solution.steps fields — ready for lib/learn.sh discover

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract learn scenarios for Domains 1-3** - `d46338b` (feat)
2. **Task 2: Extract learn scenarios for Domains 4-5** - `3b974ce` (feat)

**Plan metadata:** (this summary commit)

## Files Created/Modified

- `scenarios/domain-1/learn-pods-volumes.yaml` - Pod + emptyDir volume basics (easy)
- `scenarios/domain-1/learn-init-containers.yaml` - Init container file setup pattern (easy)
- `scenarios/domain-1/learn-multi-container.yaml` - Sidecar pattern with shared volume (medium)
- `scenarios/domain-1/learn-jobs-cronjobs.yaml` - Job completions and parallelism (medium)
- `scenarios/domain-2/learn-deployments.yaml` - Deployment creation and scaling (easy)
- `scenarios/domain-2/learn-rolling-updates.yaml` - Rolling update with maxSurge/maxUnavailable (medium)
- `scenarios/domain-2/learn-rollbacks.yaml` - Rollout history and undo (medium)
- `scenarios/domain-3/learn-probes.yaml` - Liveness and readiness probe configuration (easy)
- `scenarios/domain-3/learn-debugging.yaml` - Systematic pod failure diagnosis (medium)
- `scenarios/domain-3/learn-logging.yaml` - kubectl logs flags and patterns (easy)
- `scenarios/domain-4/learn-configmaps.yaml` - ConfigMap creation and envFrom injection (easy)
- `scenarios/domain-4/learn-secrets.yaml` - Secret volume mount with readOnly (easy)
- `scenarios/domain-4/learn-security-context.yaml` - SecurityContext runAsUser and readOnlyRootFilesystem (medium)
- `scenarios/domain-5/learn-services.yaml` - ClusterIP Service creation and DNS connectivity (easy)
- `scenarios/domain-5/learn-ingress.yaml` - Ingress path-based routing with pathType Prefix (medium)
- `scenarios/domain-5/learn-network-policies.yaml` - Default deny then selective allow pattern (medium)

## Decisions Made

- Quiz questions were not converted to learn scenarios — all quiz questions in source files (01-design-build.md, 02-deployment.md, etc.) are knowledge-based recall (multiple choice, definitions) rather than practical kubectl tasks
- Domain 4 and 5 directories had to be created since no YAML scenarios existed in those domains yet
- difficulty set easy or medium only — no hard scenarios in learn mode (consistent with plan spec)
- learn_intro text sourced from tutorial lesson prose, not invented — specifically from "Why X exists" and "How it works" sections

## Deviations from Plan

None — plan executed exactly as written. Domains 4 and 5 directory creation was an implicit prerequisite (Rule 3 - blocking), done inline.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 16 learn scenarios are ready for `ckad-drill learn` — lib/learn.sh learn_discover will find them via the learn_intro field
- Scenarios cover all 5 CKAD domains with progressive easy-to-medium ordering
- Domain-4 and domain-5 scenario directories established for future drill scenario expansion

---
*Phase: 06-content-migration*
*Completed: 2026-02-28*

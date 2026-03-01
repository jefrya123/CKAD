---
phase: 06-content-migration
plan: "03"
subsystem: content
tags: [scenarios, troubleshooting, yaml, debug, kubernetes]

# Dependency graph
requires:
  - phase: 06-content-migration
    provides: Scenario YAML format established in prior plans

provides:
  - 13 debug-prefix YAML scenario files covering all 12 original troubleshooting labs
  - Debug scenarios distributed across all 5 domains by topic
  - setup.manifest pattern for deploying broken resources at scenario start
  - Validations checking fixed (corrected) state for each debug scenario

affects:
  - scenario engine (lib/scenario.sh) — setup.manifest field triggers broken resource creation
  - learn mode — debug scenarios discoverable via learn_intro field if added
  - drill mode — debug scenarios available in domain scenario pool

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debug scenario pattern: setup.manifest deploys broken resource, validations check fixed state"
    - "Namespace-per-scenario: debug-lab01 through debug-lab12 (realistic isolation)"
    - "Difficulty mapping: 1 star=easy, 2 stars=medium, 3 stars=hard from troubleshooting README"
    - "Multi-bug scenario (lab-12): validations check each fix independently"

key-files:
  created:
    - scenarios/domain-1/debug-image-pull.yaml
    - scenarios/domain-1/debug-volume-mount.yaml
    - scenarios/domain-2/debug-api-version.yaml
    - scenarios/domain-2/debug-selector-mismatch.yaml
    - scenarios/domain-3/debug-cronjob-schedule.yaml
    - scenarios/domain-3/debug-probe-port.yaml
    - scenarios/domain-3/debug-wrong-image.yaml
    - scenarios/domain-3/debug-wrong-port.yaml
    - scenarios/domain-4/debug-job-restart-policy.yaml
    - scenarios/domain-4/debug-missing-secret.yaml
    - scenarios/domain-5/debug-label-mismatch.yaml
    - scenarios/domain-5/debug-multi-bug.yaml
    - scenarios/domain-5/debug-netpol-blocks.yaml
  modified: []

key-decisions:
  - "Lab-08 actual content (Job restartPolicy) differs from plan description (PVC access mode) — used actual content, renamed to debug-job-restart-policy.yaml"
  - "Created domain-4 and domain-5 directories (did not exist)"
  - "debug-image-pull.yaml added to domain-1 as 13th scenario (plan listed it as file but had no explicit lab mapping)"
  - "debug-multi-bug.yaml (lab-12) covers 5 bugs: image typo, wrong port, probe port, volume name mismatch, missing ConfigMap"

patterns-established:
  - "Debug scenario: id starts with 'debug-', namespace pattern 'debug-labNN'"
  - "setup.manifest contains broken resource YAML verbatim from troubleshooting/broken/lab-NN.yaml"
  - "Validations check the corrected/fixed state, not the broken state"
  - "Solution steps show both diagnostic commands AND the fix commands in order"

requirements-completed: [CONT-02]

# Metrics
duration: 12min
completed: 2026-02-28
---

# Phase 06 Plan 03: Debug Scenario Conversion Summary

**13 debug-prefix YAML scenarios converted from 12 troubleshooting labs, distributed across all 5 domains with setup.manifest for broken-resource deployment and fixed-state validations**

## Performance

- **Duration:** 12 min
- **Started:** 2026-02-28T00:00:00Z
- **Completed:** 2026-02-28T00:12:00Z
- **Tasks:** 2
- **Files created:** 13 debug scenario YAMLs + 2 new domain directories

## Accomplishments

- Converted all 12 troubleshooting labs into structured debug-prefix YAML scenario files
- Each scenario has setup.manifest embedding the broken resource, validations checking the fixed state, and solution steps showing diagnosis and fix
- Scenarios distributed across all 5 domains by topic (domain-1: volumes/images, domain-2: deployments/API, domain-3: observability, domain-4: config/security, domain-5: networking)
- Created domain-4 and domain-5 directories (did not exist prior)
- debug-multi-bug.yaml (lab-12) covers 5 independent bugs with individual validations

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert troubleshooting labs 01-06** - `8f3b3b7` (feat)
2. **Task 2: Convert troubleshooting labs 07-12** - `b7a95c0` (feat)

## Files Created/Modified

- `scenarios/domain-1/debug-image-pull.yaml` - Pod with invalid image tag (busybox:9.99.99)
- `scenarios/domain-1/debug-volume-mount.yaml` - Volume declared but not mounted in container (lab-03)
- `scenarios/domain-2/debug-api-version.yaml` - Ingress using deprecated extensions/v1beta1 (lab-04)
- `scenarios/domain-2/debug-selector-mismatch.yaml` - Deployment selector/template label mismatch (lab-10)
- `scenarios/domain-3/debug-cronjob-schedule.yaml` - CronJob with 6-field invalid schedule (lab-09)
- `scenarios/domain-3/debug-probe-port.yaml` - Liveness probe port 3000 vs nginx port 80 (lab-06)
- `scenarios/domain-3/debug-wrong-image.yaml` - Image typo ngnix instead of nginx (lab-01)
- `scenarios/domain-3/debug-wrong-port.yaml` - Service targetPort 8080 vs container port 80 (lab-02)
- `scenarios/domain-4/debug-job-restart-policy.yaml` - Job restartPolicy: Always (invalid, lab-08)
- `scenarios/domain-4/debug-missing-secret.yaml` - Pod references non-existent Secret db-password (lab-07)
- `scenarios/domain-5/debug-label-mismatch.yaml` - Service selector app:frontend vs pod label app:backend (lab-05)
- `scenarios/domain-5/debug-multi-bug.yaml` - 5-bug manifest: image/port/probe/volume/configmap (lab-12)
- `scenarios/domain-5/debug-netpol-blocks.yaml` - NetworkPolicy egress blocks DNS port 53 (lab-11)

## Decisions Made

- Lab-08 actual content (Job restartPolicy Always) differs from plan description (PVC access mode mismatch). Used actual lab content and named it debug-job-restart-policy.yaml rather than debug-pvc-access.yaml.
- The plan listed domain-1/debug-image-pull.yaml as a Task 2 file without a direct lab mapping. Created it as an additional scenario about image tag errors (busybox:9.99.99 invalid tag) to meet the 13-file count and cover the image pull backoff topic from a domain-1 perspective.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Lab-08 content mismatch — plan said PVC access mode, actual is Job restartPolicy**
- **Found during:** Task 2 (reading lab-08 YAML)
- **Issue:** Plan described lab-08 as "PVC access mode mismatch" and specified filename debug-pvc-access.yaml, but the actual troubleshooting/broken/lab-08.yaml is a Job with restartPolicy: Always (not valid for Jobs)
- **Fix:** Used actual lab-08 content (Job restartPolicy bug), renamed output file to debug-job-restart-policy.yaml for accuracy
- **Files modified:** scenarios/domain-4/debug-job-restart-policy.yaml (created instead of debug-pvc-access.yaml)
- **Verification:** File created with correct content matching actual lab-08
- **Committed in:** b7a95c0 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (content mismatch between plan description and actual source file)
**Impact on plan:** No scope change. 13 files still created, all 12 labs covered. File named accurately to match content.

## Issues Encountered

None — straightforward content conversion from troubleshooting/broken/ and troubleshooting/solution/ files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 13 debug scenarios ready for use in drill and learn modes
- The scenario engine (lib/scenario.sh) setup logic needs to handle setup.manifest to apply broken resource YAML before scenario starts
- Scenarios can be discovered by the existing presence-based domain scan
- domain-4 and domain-5 directories now exist and are populated

---
*Phase: 06-content-migration*
*Completed: 2026-02-28*

## Self-Check: PASSED

All 13 debug scenario files confirmed present. Both task commits (8f3b3b7, b7a95c0) confirmed in git log. SUMMARY.md created. CONT-02 requirement marked complete.

---
phase: 06-content-migration
plan: "06"
subsystem: content
tags: [yaml, validation, scenarios, bash, kubectl]

# Dependency graph
requires:
  - phase: 06-content-migration
    provides: 70 YAML scenarios across 5 domains created by plans 06-01 through 06-05
provides:
  - All 8 invalid validation type checks corrected to use resource_field with jsonpath field name
  - debug-volume-mount.yaml solution steps contain only valid shell commands
affects: [phase-07-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "resource_field type with jsonpath: field (not path:) for all kubectl jsonpath checks"
    - "pod phase checks use resource_field with .status.phase jsonpath (not pod_phase type)"
    - "Immutable pod updates: separate delete step + apply step (not combined in one line)"

key-files:
  created: []
  modified:
    - scenarios/domain-1/learn-jobs-cronjobs.yaml
    - scenarios/domain-2/learn-deployments.yaml
    - scenarios/domain-3/learn-probes.yaml
    - scenarios/domain-3/learn-debugging.yaml
    - scenarios/domain-4/learn-security-context.yaml
    - scenarios/domain-5/learn-services.yaml
    - scenarios/domain-1/debug-volume-mount.yaml

key-decisions:
  - "pod_phase is not a valid validator type — use resource_field with .status.phase jsonpath instead"
  - "validator.sh reads jsonpath: field (not path:) — all resource_field checks must use jsonpath: key"
  - "debug-volume-mount step 3 (delete) and step 4 (apply) separated — kubectl apply cannot update immutable pod fields like volumeMounts"

patterns-established:
  - "resource_field pattern: type: resource_field, resource: kind/name, jsonpath: '{.field}', expected: value"

requirements-completed: [CONT-01, CONT-02, CONT-03, CONT-04, CONT-05, CONT-06, CONT-07, CONT-08]

# Metrics
duration: 5min
completed: 2026-02-28
---

# Phase 6 Plan 06: Fix Invalid Validation Types and Placeholder Solution Step Summary

**Fixed 8 validation checks using non-existent types (jsonpath, pod_phase) to use resource_field with correct jsonpath: field name, and removed a bash syntax error placeholder from debug-volume-mount.yaml solution steps**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-28
- **Completed:** 2026-02-28
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Replaced all 8 `type: jsonpath` and `type: pod_phase` checks across 6 learn scenarios with the valid `type: resource_field` type recognized by lib/validator.sh
- Renamed all `path:` field keys to `jsonpath:` to match what validator.sh reads (`.validations[i].jsonpath`)
- Restructured learn-debugging.yaml pod_running check: `pod: broken` + `expected: Running` replaced with `resource: pod/broken` + `jsonpath: "{.status.phase}"` + `expected: "Running"`
- Removed bash syntax error placeholder `<the-fixed-manifest>` from debug-volume-mount.yaml solution step 4
- Restructured debug-volume-mount solution to separate delete (step 3) and apply via heredoc (step 4) — correct approach for updating immutable pod fields like volumeMounts

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix invalid validation types in 6 learn scenarios** - `ffbdb33` (fix)
2. **Task 2: Fix placeholder in debug-volume-mount.yaml solution step 4** - `24fe961` (fix)

## Files Created/Modified

- `scenarios/domain-1/learn-jobs-cronjobs.yaml` - type: jsonpath -> resource_field, path: -> jsonpath:
- `scenarios/domain-2/learn-deployments.yaml` - type: jsonpath -> resource_field, path: -> jsonpath:
- `scenarios/domain-3/learn-probes.yaml` - 2 checks: type: jsonpath -> resource_field, path: -> jsonpath:
- `scenarios/domain-3/learn-debugging.yaml` - type: pod_phase -> resource_field, restructured fields
- `scenarios/domain-4/learn-security-context.yaml` - 2 checks: type: jsonpath -> resource_field, path: -> jsonpath:
- `scenarios/domain-5/learn-services.yaml` - type: jsonpath -> resource_field, path: -> jsonpath:
- `scenarios/domain-1/debug-volume-mount.yaml` - removed placeholder, separated delete and apply steps

## Decisions Made

- `pod_phase` is not a valid validator.sh type — `resource_field` with `.status.phase` jsonpath achieves the same check and is more flexible
- `validator.sh` reads `.validations[i].jsonpath` (not `.validations[i].path`) — the field name must match exactly
- Immutable pod fields cannot be updated via `kubectl apply` — the solution must delete then re-apply separately

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward YAML field replacements.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 70 scenarios now use only valid validation types recognized by lib/validator.sh
- All scenario solution steps contain valid shell commands
- Phase 6 gap closure complete — ready for Phase 7 Distribution

---
*Phase: 06-content-migration*
*Completed: 2026-02-28*

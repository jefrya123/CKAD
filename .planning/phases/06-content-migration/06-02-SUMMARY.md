---
phase: 06-content-migration
plan: 02
subsystem: content
tags: [yaml, scenarios, domain-4, domain-5, kubernetes, configmap, rbac, security-context, networkpolicy, ingress]

# Dependency graph
requires:
  - phase: 06-content-migration
    provides: YAML scenario format established in plan 01 (domain-1 through domain-3 scenarios)
provides:
  - 6 YAML scenario files in scenarios/domain-4/ (Config & Security)
  - 6 YAML scenario files in scenarios/domain-5/ (Services & Networking)
  - sc-configmap-secret moved from domain-2 to domain-4 with correct domain field
  - sc-network-policy moved from domain-3 to domain-5, renamed to sc-netpol-deny
affects:
  - scenario engine (lib/scenario.sh reads these YAML files)
  - drill/learn/exam modes (scenario discovery includes all domains)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "command_output validation with mode: contains for DNS resolution checks"
    - "command_output validation with mode: exact for auth can-i checks"
    - "setup.commands for scenarios that need pre-created resources (DNS, Service)"

key-files:
  created:
    - scenarios/domain-4/sc-security-context.yaml
    - scenarios/domain-4/sc-rbac.yaml
    - scenarios/domain-4/sc-resource-limits.yaml
    - scenarios/domain-4/sc-resource-quota.yaml
    - scenarios/domain-4/sc-docker-registry-secret.yaml
    - scenarios/domain-5/sc-service.yaml
    - scenarios/domain-5/sc-ingress.yaml
    - scenarios/domain-5/sc-netpol-allow.yaml
    - scenarios/domain-5/sc-netpol-deny.yaml
    - scenarios/domain-5/sc-dns.yaml
    - scenarios/domain-5/sc-ingress-tls.yaml
  modified:
    - scenarios/domain-4/sc-configmap-secret.yaml (moved from domain-2, domain field updated to 4)

key-decisions:
  - "sc-configmap-secret moved from domain-2/ to domain-4/ — ConfigMap/Secret is domain 4 (Config & Security) content"
  - "sc-network-policy moved from domain-3/ to domain-5/, renamed to sc-netpol-deny — NetworkPolicy is domain 5 (Services & Networking) content"
  - "RBAC validation uses command_output with mode: exact for auth can-i (returns yes/no)"
  - "DNS scenario uses setup.commands to pre-create service before validation runs"
  - "docker-registry secret pod intentionally not validated for running state (image pull will fail in test cluster)"

patterns-established:
  - "command_output mode: exact for yes/no kubectl auth can-i responses"
  - "command_output mode: contains for nslookup output (output varies by cluster DNS)"
  - "setup.commands for scenarios requiring pre-existing cluster state"

requirements-completed: [CONT-01]

# Metrics
duration: 3min
completed: 2026-03-01
---

# Phase 06 Plan 02: Domain 4-5 Scenario YAML Migration Summary

**12 YAML scenarios covering Config & Security (domain 4) and Services & Networking (domain 5), with 2 files relocated from incorrect domains and 10 new scenarios created**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-01T02:47:44Z
- **Completed:** 2026-03-01T02:50:20Z
- **Tasks:** 2
- **Files modified:** 14 (12 created, 2 moved/renamed from wrong domains)

## Accomplishments

- Created 5 new domain-4 scenarios: security-context, rbac, resource-limits, resource-quota, docker-registry-secret
- Created 5 new domain-5 scenarios: service, ingress, netpol-allow, dns, ingress-tls
- Relocated 2 misplaced files: sc-configmap-secret (domain-2 → domain-4) and sc-network-policy (domain-3 → domain-5/sc-netpol-deny)
- All 12 files have valid YAML schema with 2+ typed validations per scenario

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert Domain 4 (Config & Security) scenarios to YAML** - `bd3770c` (feat)
2. **Task 2: Convert Domain 5 (Services & Networking) scenarios to YAML** - `4a017c5` (feat)

**Plan metadata:** (created in final commit)

## Files Created/Modified

- `scenarios/domain-4/sc-configmap-secret.yaml` - Moved from domain-2, domain field updated to 4
- `scenarios/domain-4/sc-security-context.yaml` - Pod securityContext: runAsUser, readOnlyRootFilesystem, no privilege escalation, capabilities
- `scenarios/domain-4/sc-rbac.yaml` - ServiceAccount + Role + RoleBinding with auth can-i validation
- `scenarios/domain-4/sc-resource-limits.yaml` - CPU/memory requests and limits on a pod
- `scenarios/domain-4/sc-resource-quota.yaml` - ResourceQuota (pods/cpu/memory) + LimitRange
- `scenarios/domain-4/sc-docker-registry-secret.yaml` - docker-registry secret type + imagePullSecrets
- `scenarios/domain-5/sc-service.yaml` - ClusterIP service exposing a deployment
- `scenarios/domain-5/sc-ingress.yaml` - Path-based Ingress routing two services
- `scenarios/domain-5/sc-netpol-allow.yaml` - NetworkPolicy allowing frontend-to-backend traffic
- `scenarios/domain-5/sc-netpol-deny.yaml` - Moved from domain-3/sc-network-policy.yaml, id/domain updated
- `scenarios/domain-5/sc-dns.yaml` - DNS resolution debugging with nslookup, setup.commands pre-creates service
- `scenarios/domain-5/sc-ingress-tls.yaml` - TLS Ingress with openssl self-signed cert + secret

## Decisions Made

- ConfigMap/Secret belongs in domain 4 (Config & Security), not domain 2 (Workload Management) — moved
- NetworkPolicy belongs in domain 5 (Services & Networking), not domain 3 (Observability) — moved and renamed
- RBAC validation uses `command_output` with `mode: exact` for `kubectl auth can-i` (returns "yes")
- DNS scenario requires `setup.commands` to pre-create deployment and service before validation
- Docker-registry pod not validated for running state since the registry.example.com image won't pull

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 12 domain-4 and domain-5 YAML scenarios complete with typed validations
- Domain 4 has 6 scenarios, domain 5 has 6 scenarios - meets plan success criteria
- Old misplaced files (domain-2/sc-configmap-secret.yaml, domain-3/sc-network-policy.yaml) removed
- Content migration phase 06 complete — all standard markdown scenarios converted to YAML

---
*Phase: 06-content-migration*
*Completed: 2026-03-01*

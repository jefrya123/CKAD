---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Ship It
status: unknown
last_updated: "2026-03-01T03:53:22.190Z"
progress:
  total_phases: 8
  completed_phases: 7
  total_plans: 24
  completed_plans: 23
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-28)

**Core value:** Unlimited, free, real-cluster CKAD practice with automated validation
**Current focus:** Milestone v1.1 Ship It — Phase 5 (Learn Mode) complete

## Current Position

Phase: 7 of 7 (Testing, CI, Distribution, Docs) — IN PROGRESS
Plan: 2/N complete (07-02 distribution scripts done)
Status: Phase 7 in progress — scripts/install.sh created (DIST-01), scripts/dev-setup.sh updated with dnf support (DIST-02)
Last activity: 2026-03-01 — 07-02 complete: curl-pipe-sh install.sh for Linux/macOS, dev-setup.sh extended with Fedora/RHEL support and version summary

Progress: [########--] 90% (6/7 phases complete, Phase 7 in progress)

## Performance Metrics

**Velocity (from v1.0):**
- Total plans completed: 11
- Average duration: ~4 min
- Total execution time: ~0.7 hours

**By Phase (v1.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation-cluster | 2 | 5 min | 2.5 min |
| 02-scenario-validation-engine | 2 | 11 min | 5.5 min |
| 03-cli-drill-mode | 6 | 16 min | 2.7 min |
| 03.1-drill-integration-fixes | 1 | 14 min | 14 min |
| 04-exam-mode | 2/2 | 22 min | 11 min |
| Phase 05-learn-mode P02 | 7 | 1 tasks | 2 files |
| Phase 06-content-migration P02 | 3 | 2 tasks | 14 files |
| Phase 06-content-migration P03 | 12 | 2 tasks | 13 files |
| Phase 06-content-migration P04 | 8 | 2 tasks | 16 files |
| Phase 06-content-migration P05 | 12 | 2 tasks | 93 files |
| Phase 06-content-migration P06 | 5 | 2 tasks | 7 files |
| Phase 07-testing-ci-distribution-docs P01 | 8 | 2 tasks | 7 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table and architecture.md ADRs.
Key decisions affecting v1.1 work:

- All phases: Pure bash, no build step — source is the product
- Phase 4: Exam mode as distinct component with separate session state (ADR-11)
- 04-01: D3 target set to 3 (not 2) so integer weights 3+3+3+4+3=16 total cleanly
- 04-01: exam_select_questions takes file paths as args (not internal discover) — caller controls pool
- 04-01: exam_grade implemented in pure jq (single invocation via group_by+reduce)
- 04-01: flagged=true overrides status icon in exam_list — [?] displayed instead of status
- Phase 5: Learn mode shares scenario engine; concept text in YAML `learn_intro` field
- Phase 6: Same repo, archive study guide (preserves git history, transforms in place)

**From v1.0 execution (patterns that carry forward):**
- error() is print-only (no exit) — callers decide on exit
- yq v3 syntax required (yq -r '.field // empty' file) — not v4
- ((n++)) || true required with set -e — arithmetic increment from 0 is falsy
- jq atomic write pattern (tmp + mv) for all file updates
- SCENARIO_NAMESPACE bridge pattern for cleanup paths
- Index-based yq extraction (.solution.steps[N]) for multi-line YAML block scalars
- [Phase 04-02]: Exam subcommands extracted to helper functions (_exam_start/_exam_submit) because local keyword not valid in case blocks
- [Phase 04-02]: check) branches on SESSION_MODE after session_require — avoids dual session_require/exam_require calls
- [Phase 05-01]: learn_intro YAML field gates learn-mode scenarios (no registry — presence-based discovery)
- [Phase 05-01]: progress .learn key is additive on first progress_record_learn — progress_init stays PROG-03 compatible
- [Phase 05-01]: Decorated sort pattern for progressive ordering within domain (easy->medium->hard)
- [Phase 05-02]: cluster_check_active before learn_next_lesson in _learn_start ensures cluster error fires before scenario discovery
- [Phase 05-02]: _learn_start/_learn_list helpers extracted — local keyword not valid in case blocks (same pattern as exam mode)
- [Phase 06-content-migration]: sc-configmap-secret moved from domain-2 to domain-4 (ConfigMap is Config & Security content)
- [Phase 06-content-migration]: sc-network-policy moved from domain-3 to domain-5, renamed to sc-netpol-deny (NetworkPolicy is Services & Networking content)
- [Phase 06-content-migration]: Lab-08 actual content is Job restartPolicy (not PVC access mode as described in plan) — renamed to debug-job-restart-policy.yaml for accuracy
- [Phase 06-content-migration]: learn_intro extracted from tutorial lesson prose not invented; domain-4 and domain-5 directories created; quiz questions not converted (knowledge-based recall only)
- [Phase 06-content-migration]: container_running check is timing-dependent in validate-scenario — use container_count + container_image + volume_mount for multi-container pod scenarios
- [Phase 06-content-migration]: sc-rbac-clusterrole creates cluster-scoped ClusterRole/ClusterRoleBinding — not cleaned up by namespace deletion, must be managed separately
- [Phase 06-06-gap-closure]: validator.sh reads jsonpath: field (not path:) — all resource_field checks must use jsonpath: key name
- [Phase 06-06-gap-closure]: pod_phase is not a valid validator type — use resource_field with .status.phase jsonpath
- [Phase 06-06-gap-closure]: immutable pod fields (volumeMounts) require delete-then-apply, not apply alone — solution steps must separate delete and apply
- [Phase 07-02]: install.sh uses ~/.local/share/ckad-drill for clone, symlinks to ~/.local/bin — no sudo required
- [Phase 07-02]: GITHUB_REPO variable at top of install.sh for easy customization when published
- [Phase 07-02]: dev-setup.sh dnf fallback added before npm for bats-core (apt-get first, dnf second, npm third)
- [Phase 07-01]: Smoke test uses single-pass yq multi-file call for performance (0.2s vs ~98s for 70 files)

### Pending Todos

None yet.

### Blockers/Concerns

- Learn mode detailed UX (lesson navigation, progression) not fully specified — design during Phase 5 planning
- PRD at docs/prd.md still references Go/Bubble Tea — architecture.md is source of truth

## Session Continuity

Last session: 2026-03-01
Stopped at: Completed 07-02-PLAN.md — distribution scripts: install.sh for curl-pipe-sh installs (DIST-01), dev-setup.sh with dnf/Fedora support and version summary (DIST-02)
Resume file: None

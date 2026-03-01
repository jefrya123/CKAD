---
status: active
project_name: ckad-drill
date: '2026-02-28'
currentSprint: 1
---

# Sprint Plan: ckad-drill

## Sprint 1: Foundation & Cluster Management

**Goal:** Establish project structure, shared utilities, and kind cluster lifecycle.
**Milestone:** Can create/manage kind cluster.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 1.1 | Create Project Directory Structure | pending | Scaffold dirs, Makefile, archive existing content |
| 1.2 | Implement lib/common.sh | pending | Shared constants, XDG paths, exit codes |
| 1.3 | Implement lib/display.sh | pending | Terminal output functions, color handling |
| 2.1 | Implement lib/cluster.sh | pending | Kind cluster create/delete/reset/health |
| 2.2 | Implement scripts/cluster-setup.sh | pending | Calico, nginx ingress, metrics-server addons |

**Dependencies:** None — root sprint.

---

## Sprint 2: Scenario & Validation Engines

**Goal:** Load, parse, validate YAML scenarios and run kubectl-based checks.
**Milestone:** Can load and validate scenarios against live cluster.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 3.1 | Define Scenario YAML Schema | pending | Schema doc + reference YAML example |
| 3.2 | Implement lib/scenario.sh | pending | Scenario loading, setup, cleanup, selection |
| 3.3 | Implement Scenario Schema Validation | pending | Field presence/type validation |
| 4.1 | Implement lib/validator.sh | pending | Core validation framework, dispatch + aggregate |
| 4.2 | Implement Typed Validation Checks | pending | 10 typed checks (resource_exists, resource_field, etc.) |

**Dependencies:** Sprint 1 (common.sh, display.sh, cluster.sh).

---

## Sprint 3: CLI Entry Point & Drill Mode

**Goal:** Wire components into `ckad-drill` command with working drill mode.
**Milestone:** Drill mode works end-to-end.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 5.1 | Implement bin/ckad-drill | pending | Entry point, subcommand dispatch, signal traps |
| 5.2 | Implement Drill Mode E2E Flow | pending | drill → display task → check → next cycle |
| 6.1 | Implement lib/timer.sh | pending | PROMPT_COMMAND countdown timer |
| 6.2 | Implement lib/progress.sh | pending | Progress tracking, per-domain stats, streaks |

**Dependencies:** Sprints 1-2.

---

## Sprint 4: Content Migration (First Batch)

**Goal:** Convert existing study guide content to YAML scenario format.
**Milestone:** 50+ scenarios available.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 8.1 | Migrate Existing Scenarios (31) | pending | Convert 31 markdown scenarios to YAML |
| 8.2 | Migrate Troubleshooting Labs (12) | pending | Convert to debug-prefix scenarios |
| 8.3 | Extract Tutorial Inline Exercises | pending | Learn-prefix scenarios with concept text |

**Dependencies:** Sprint 2 (scenario schema defined).

---

## Sprint 5: Exam Mode

**Goal:** Full mock exam with multi-scenario sessions, navigation, and scoring.
**Milestone:** Exam mode works.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 7.1 | Implement lib/exam.sh | pending | Session management, weighted selection, navigation |
| 7.2 | Implement Exam Submission & Scoring | pending | Score calculation, per-domain breakdown, 66% pass |

**Dependencies:** Sprints 1-3 (drill mode must work first).

---

## Sprint 6: Content Migration (Second Batch) & Learn Mode

**Goal:** Complete content migration and implement learn mode.
**Milestone:** All three modes working (learn, drill, exam).

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 8.4 | Extract Domain Exercises (~2,200 lines) | pending | Net-new scenarios from exercise files |
| 8.5 | Migrate Quizzes, Speed Drills & Cheatsheet | pending | Quiz → scenarios, rest → reference content |
| 9.1 | Implement Learn Mode Flow | pending | Progressive guided lessons with concept text |

**Dependencies:** Sprint 3 (drill flow), Sprint 4 (learn content exists).

---

## Sprint 7: Validation Tool, Install & CI

**Goal:** Contributor tooling, user installation, and automated testing.
**Milestone:** Distribution-ready.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 10.1 | Implement validate-scenario Subcommand | pending | End-to-end scenario validation tool |
| 10.2 | Implement scripts/install.sh | pending | curl-pipe-sh installer |
| 10.3 | Implement scripts/dev-setup.sh | pending | Developer dependency setup |
| 11.1 | Write Unit Tests (bats) | pending | Tests for all lib functions |
| 11.2 | Write Integration Tests (bats) | pending | Full lifecycle tests against real cluster |
| 11.3 | Write Schema Tests | pending | Valid/invalid scenario validation |
| 11.4 | Set Up CI Pipeline | pending | GitHub Actions: shellcheck + bats |

**Dependencies:** Sprints 1-6 (features complete).

---

## Sprint 8: Documentation & Content Gap

**Goal:** User-facing docs and reach 70+ scenario target.
**Milestone:** V1.0 Release.

| Story | Title | Status | Notes |
|-------|-------|--------|-------|
| 12.1 | Write README.md | pending | Quick start, feature overview, comparison table |
| 12.2 | Write CONTRIBUTING.md | pending | Scenario authoring guide |
| 8.6 | Author Net-New Scenarios to 70+ | pending | Fill domain gaps to meet NFR-06 |

**Dependencies:** All prior sprints.

---

## Summary

| Sprint | Stories | Key Deliverable |
|--------|---------|-----------------|
| 1 | 1.1, 1.2, 1.3, 2.1, 2.2 | Project scaffold + kind cluster |
| 2 | 3.1, 3.2, 3.3, 4.1, 4.2 | Scenario + validation engines |
| 3 | 5.1, 5.2, 6.1, 6.2 | Drill mode E2E |
| 4 | 8.1, 8.2, 8.3 | 50+ scenarios |
| 5 | 7.1, 7.2 | Exam mode |
| 6 | 8.4, 8.5, 9.1 | Learn mode + remaining content |
| 7 | 10.1, 10.2, 10.3, 11.1-11.4 | Tests, CI, install |
| 8 | 12.1, 12.2, 8.6 | Docs + V1.0 release |

**Total:** 12 epics, 29 stories, 8 sprints.

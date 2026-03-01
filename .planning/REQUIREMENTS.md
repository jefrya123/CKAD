# Requirements: ckad-drill

**Defined:** 2026-02-28
**Core Value:** Unlimited, free, real-cluster CKAD practice with automated validation

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Cluster Management

- [x] **CLST-01**: User can create a kind cluster with `ckad-drill start` that includes Calico CNI, nginx ingress, and metrics-server
- [x] **CLST-02**: User can destroy the kind cluster with `ckad-drill stop`
- [x] **CLST-03**: User can recreate the cluster from scratch with `ckad-drill reset`
- [x] **CLST-04**: Tool detects if cluster already exists and reuses it (idempotent create)
- [x] **CLST-05**: Tool shows clear error with instructions if Docker or kind is not installed

### Scenario Engine

- [x] **SCEN-01**: Scenarios are defined in YAML format with required fields: id, domain, title, difficulty, time_limit, description, validations, solution
- [x] **SCEN-02**: Scenario namespaces are created on setup and deleted on cleanup
- [x] **SCEN-03**: Scenarios can be filtered by domain (1-5) and difficulty (easy/medium/hard)
- [x] **SCEN-04**: External scenarios can be loaded from a user-provided directory path
- [x] **SCEN-05**: Duplicate scenario IDs across built-in and external sources produce a warning (first-loaded wins)
- [x] **SCEN-06**: Scenarios with `tags: [helm]` check for Helm and show clear error if not installed

### Validation Engine

- [x] **VALD-01**: `resource_exists` check verifies a resource exists in the correct namespace
- [x] **VALD-02**: `resource_field` check verifies any field via jsonpath matches expected value
- [x] **VALD-03**: `container_count` check verifies the number of containers in a pod
- [x] **VALD-04**: `container_image` check verifies the correct image is used by a named container
- [x] **VALD-05**: `container_env` check verifies an env var exists with the correct value
- [x] **VALD-06**: `volume_mount` check verifies a volume is mounted at the correct path
- [x] **VALD-07**: `container_running` check verifies a container is in Running state
- [x] **VALD-08**: `label_selector` check verifies resources exist matching label selector
- [x] **VALD-09**: `resource_count` check verifies the count of resources matching a selector
- [x] **VALD-10**: `command_output` check runs a command and checks output contains/matches/equals expected
- [x] **VALD-11**: Each validation runs once with no retry (exam-realistic)
- [x] **VALD-12**: Validation results show specific expected-vs-actual feedback for failures

### CLI & Drill Mode

- [x] **DRIL-01**: User can run `ckad-drill drill` to get a random scenario with task displayed
- [x] **DRIL-02**: User can run `ckad-drill drill --domain N --difficulty LEVEL` to filter scenarios
- [x] **DRIL-03**: User can run `ckad-drill check` to validate their work against the cluster
- [x] **DRIL-04**: User can run `ckad-drill hint` to see the scenario hint
- [x] **DRIL-05**: User can run `ckad-drill solution` to see the solution
- [x] **DRIL-06**: User can run `ckad-drill next` to clean up and get a new scenario
- [x] **DRIL-07**: User can run `ckad-drill skip` to skip without checking
- [x] **DRIL-08**: User can run `ckad-drill current` to reprint the active scenario
- [x] **DRIL-09**: Session state persists in session.json (active scenario, namespace, time)
- [x] **DRIL-10**: Strict exam environment on session start: `alias k=kubectl`, completion, `EDITOR=vim`, nothing else
- [x] **DRIL-11**: SIGINT/SIGTERM triggers cleanup via trap handler

### Timer & Progress

- [x] **TIMR-01**: `source <(ckad-drill env)` sets up PROMPT_COMMAND with countdown `[MM:SS]` in prompt
- [x] **TIMR-02**: Timer shows `[TIME UP]` when time expires
- [x] **TIMR-03**: `ckad-drill env --reset` cleanly restores original prompt
- [x] **TIMR-04**: `ckad-drill timer` prints remaining time for users who don't source env
- [x] **TIMR-05**: env output is safe for user's shell (no set -euo pipefail, idempotent)
- [x] **PROG-01**: Drill results are recorded to progress.json (passed, time, attempts)
- [x] **PROG-02**: `ckad-drill status` shows per-domain pass rates, exam history, streak, weak area recommendation
- [x] **PROG-03**: Progress schema is additive-only — missing fields get defaults on read
- [x] **PROG-04**: Progress file survives tool upgrades

### Exam Mode

- [x] **EXAM-01**: `ckad-drill exam` starts a mock exam with 15-20 questions weighted by CKAD domain percentages
- [x] **EXAM-02**: All exam namespaces are created at exam start
- [x] **EXAM-03**: Global timer (default 2 hours, configurable with `--time`)
- [x] **EXAM-04**: `ckad-drill exam list` shows all questions with status icons
- [x] **EXAM-05**: `ckad-drill exam next/prev/jump N` navigates between questions
- [x] **EXAM-06**: `ckad-drill exam flag` flags current question for review
- [x] **EXAM-07**: `ckad-drill check` during exam validates only the current question
- [x] **EXAM-08**: Hints and solutions are blocked during exam mode
- [x] **EXAM-09**: `ckad-drill exam submit` grades all questions, shows per-domain scores
- [x] **EXAM-10**: Pass threshold is 66% — clear PASS/FAIL display
- [x] **EXAM-11**: Exam results recorded to progress.json
- [x] **EXAM-12**: All exam namespaces cleaned up on submit or Ctrl+C

### Learn Mode

- [x] **LERN-01**: `ckad-drill learn` lists learn-mode scenarios by domain with completion status
- [x] **LERN-02**: `ckad-drill learn --domain N` presents lessons in progressive order (easy first)
- [x] **LERN-03**: Concept text displayed before the task description
- [x] **LERN-04**: Completing a lesson offers the next lesson in the domain
- [x] **LERN-05**: Completion tracked per-lesson in progress.json

### Content

- [x] **CONT-01**: 31 existing scenarios migrated to YAML format with typed validations
- [x] **CONT-02**: 12 troubleshooting labs converted to debug-prefix scenarios
- [x] **CONT-03**: Tutorial inline exercises extracted as learn-prefix scenarios with concept text
- [x] **CONT-04**: Domain exercises (~2,200 lines) extracted as additional scenarios
- [x] **CONT-05**: Quiz questions convertible to practical tasks become scenarios
- [ ] **CONT-06**: Speed drills and cheatsheet preserved as reference content
- [ ] **CONT-07**: Total scenario count >= 70 at launch
- [ ] **CONT-08**: Each domain has at least 10 scenarios

### Distribution & Quality

- [ ] **DIST-01**: `scripts/install.sh` installs ckad-drill via curl-pipe-sh (checks Docker, kubectl, installs kind/yq/jq)
- [ ] **DIST-02**: `scripts/dev-setup.sh` installs bats-core and shellcheck for developers
- [x] **DIST-03**: `ckad-drill validate-scenario <file>` runs full end-to-end validation (parse, setup, apply solution, validate, cleanup)
- [x] **DIST-04**: `ckad-drill validate-scenario <dir>` validates all scenarios in directory
- [ ] **TEST-01**: bats unit tests exist for all lib functions (no cluster required)
- [ ] **TEST-02**: bats integration tests cover full scenario lifecycle against real cluster
- [ ] **TEST-03**: Schema tests validate known-good and known-bad YAML files
- [ ] **TEST-04**: All bash scripts pass shellcheck with zero warnings
- [ ] **CICD-01**: CI runs shellcheck + bats unit tests on every PR
- [ ] **CICD-02**: CI runs shellcheck + bats unit + integration tests on merge to main
- [ ] **DOCS-01**: README with quick start, feature overview, and competitive comparison
- [ ] **DOCS-02**: CONTRIBUTING.md with scenario authoring guide and PR checklist

## v2 Requirements

### Notifications & Export

- **EXPRT-01**: Export progress/results as markdown
- **EXPRT-02**: Shell completion for subcommands

### Extended Content

- **EXTD-01**: CKA content pack
- **EXTD-02**: CKS content pack
- **EXTD-03**: Multi-node cluster scenarios (CKA node troubleshooting)
- **EXTD-04**: Multi-cluster context switching

### Community

- **CMTY-01**: Leaderboards (opt-in)
- **CMTY-02**: Scenario editor/builder

## Out of Scope

| Feature | Reason |
|---------|--------|
| Go/Bubble Tea TUI | Pivoted to bash — exam should feel like exam |
| Mobile app | Terminal tool only |
| Real-time chat/multiplayer | Not relevant to exam prep |
| OAuth/account system | Local tool, no server |
| Video content | Storage/bandwidth, not the product |
| WSL-specific support | Best-effort, not primary target |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLST-01 | Phase 1 | Complete |
| CLST-02 | Phase 1 | Complete |
| CLST-03 | Phase 1 | Complete |
| CLST-04 | Phase 1 | Complete |
| CLST-05 | Phase 1 | Complete |
| SCEN-01 | Phase 2 | Complete |
| SCEN-02 | Phase 2 | Complete |
| SCEN-03 | Phase 2 | Complete |
| SCEN-04 | Phase 2 | Complete |
| SCEN-05 | Phase 2 | Complete |
| SCEN-06 | Phase 2 | Complete |
| VALD-01 | Phase 2 | Complete |
| VALD-02 | Phase 2 | Complete |
| VALD-03 | Phase 2 | Complete |
| VALD-04 | Phase 2 | Complete |
| VALD-05 | Phase 2 | Complete |
| VALD-06 | Phase 2 | Complete |
| VALD-07 | Phase 2 | Complete |
| VALD-08 | Phase 2 | Complete |
| VALD-09 | Phase 2 | Complete |
| VALD-10 | Phase 2 | Complete |
| VALD-11 | Phase 2 | Complete |
| VALD-12 | Phase 2 | Complete |
| DRIL-01 | Phase 3 | Complete |
| DRIL-02 | Phase 3 | Complete |
| DRIL-03 | Phase 3.1 | Complete |
| DRIL-04 | Phase 3 | Complete |
| DRIL-05 | Phase 3.1 | Complete |
| DRIL-06 | Phase 3.1 | Complete |
| DRIL-07 | Phase 3.1 | Complete |
| DRIL-08 | Phase 3 | Complete |
| DRIL-09 | Phase 3 | Complete |
| DRIL-10 | Phase 3 | Complete |
| DRIL-11 | Phase 3.1 | Complete |
| TIMR-01 | Phase 3 | Complete |
| TIMR-02 | Phase 3 | Complete |
| TIMR-03 | Phase 3 | Complete |
| TIMR-04 | Phase 3 | Complete |
| TIMR-05 | Phase 3 | Complete |
| PROG-01 | Phase 3.1 | Complete |
| PROG-02 | Phase 3 | Complete |
| PROG-03 | Phase 3 | Complete |
| PROG-04 | Phase 3 | Complete |
| DIST-03 | Phase 3 | Complete |
| DIST-04 | Phase 3 | Complete |
| EXAM-01 | Phase 4 | Complete |
| EXAM-02 | Phase 4 | Complete |
| EXAM-03 | Phase 4 | Complete |
| EXAM-04 | Phase 4 | Complete |
| EXAM-05 | Phase 4 | Complete |
| EXAM-06 | Phase 4 | Complete |
| EXAM-07 | Phase 4 | Complete |
| EXAM-08 | Phase 4 | Complete |
| EXAM-09 | Phase 4 | Complete |
| EXAM-10 | Phase 4 | Complete |
| EXAM-11 | Phase 4 | Complete |
| EXAM-12 | Phase 4 | Complete |
| LERN-01 | Phase 5 | Complete |
| LERN-02 | Phase 5 | Complete |
| LERN-03 | Phase 5 | Complete |
| LERN-04 | Phase 5 | Complete |
| LERN-05 | Phase 5 | Complete |
| CONT-01 | Phase 6 | Complete |
| CONT-02 | Phase 6 | Complete |
| CONT-03 | Phase 6 | Complete |
| CONT-04 | Phase 6 | Complete |
| CONT-05 | Phase 6 | Complete |
| CONT-06 | Phase 6 | Pending |
| CONT-07 | Phase 6 | Pending |
| CONT-08 | Phase 6 | Pending |
| TEST-01 | Phase 7 | Pending |
| TEST-02 | Phase 7 | Pending |
| TEST-03 | Phase 7 | Pending |
| TEST-04 | Phase 7 | Pending |
| CICD-01 | Phase 7 | Pending |
| CICD-02 | Phase 7 | Pending |
| DIST-01 | Phase 7 | Pending |
| DIST-02 | Phase 7 | Pending |
| DOCS-01 | Phase 7 | Pending |
| DOCS-02 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 66 total
- Mapped to phases: 66
- Unmapped: 0

---
*Requirements defined: 2026-02-28*
*Last updated: 2026-02-28 after roadmap creation*

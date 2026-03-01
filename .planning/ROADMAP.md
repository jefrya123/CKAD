# Roadmap: ckad-drill

## Milestones

- ✅ **v1.0 Foundation + Drill Mode** - Phases 1-3.1 (shipped 2026-03-01)
- 🚧 **v1.1 Ship It** - Phases 4-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 Foundation + Drill Mode (Phases 1-3.1) - SHIPPED 2026-03-01</summary>

### Phase 1: Foundation + Cluster
**Goal**: Developers can run `ckad-drill start` against a working project skeleton with all shared utilities in place
**Depends on**: Nothing (first phase)
**Requirements**: CLST-01, CLST-02, CLST-03, CLST-04, CLST-05
**Success Criteria** (what must be TRUE):
  1. Running `ckad-drill start` creates a kind cluster with Calico, nginx ingress, and metrics-server within 120 seconds
  2. Running `ckad-drill stop` deletes the cluster cleanly
  3. Running `ckad-drill reset` tears down and recreates the cluster from scratch
  4. Running `ckad-drill start` a second time reuses the existing cluster without error
  5. Running `ckad-drill start` without Docker or kind installed prints a clear error with installation instructions
**Plans**: 2/2 complete

Plans:
- [x] 01-01-PLAN.md — Project scaffold, shared libs, and cluster lifecycle implementation
- [x] 01-02-PLAN.md — Dev tooling setup and unit tests for foundation code

### Phase 2: Scenario + Validation Engine
**Goal**: Scenarios can be loaded from YAML and validated against a live cluster with all 10 check types working
**Depends on**: Phase 1
**Requirements**: SCEN-01, SCEN-02, SCEN-03, SCEN-04, SCEN-05, SCEN-06, VALD-01, VALD-02, VALD-03, VALD-04, VALD-05, VALD-06, VALD-07, VALD-08, VALD-09, VALD-10, VALD-11, VALD-12
**Success Criteria** (what must be TRUE):
  1. A YAML scenario file is parsed and its namespace is created on setup and deleted on cleanup
  2. Scenarios can be filtered by domain (1-5) and difficulty (easy/medium/hard) and return matching results
  3. All 10 typed validation checks (`resource_exists`, `resource_field`, `container_count`, `container_image`, `container_env`, `volume_mount`, `container_running`, `label_selector`, `resource_count`, `command_output`) produce pass/fail results against a live cluster
  4. Each failed validation shows the specific expected value versus the actual value found
  5. Validations run exactly once with no retry; a pending pod does not cause a wait
**Plans**: 2/2 complete

Plans:
- [x] 02-01-PLAN.md — display.sh, scenario.sh, test fixtures, and scenario unit tests
- [x] 02-02-PLAN.md — validator.sh with all 10 check types and validator unit tests

### Phase 3: CLI + Drill Mode
**Goal**: A user can run a full drill session end-to-end from the terminal using subcommands
**Depends on**: Phase 2
**Requirements**: DRIL-01, DRIL-02, DRIL-03, DRIL-04, DRIL-05, DRIL-06, DRIL-07, DRIL-08, DRIL-09, DRIL-10, DRIL-11, TIMR-01, TIMR-02, TIMR-03, TIMR-04, TIMR-05, PROG-01, PROG-02, PROG-03, PROG-04, DIST-03, DIST-04
**Success Criteria** (what must be TRUE):
  1. `ckad-drill drill` shows a random scenario task; `ckad-drill drill --domain 2 --difficulty medium` filters correctly
  2. `source <(ckad-drill env)` adds a `[MM:SS]` countdown to the prompt that counts down and shows `[TIME UP]` when expired; `ckad-drill env --reset` restores the original prompt
  3. `ckad-drill check` runs validations and prints pass/fail per check; `ckad-drill hint` and `ckad-drill solution` display their content; `ckad-drill next` cleans up and starts a new scenario
  4. `ckad-drill status` shows per-domain pass rates, exam history, streak, and a weak domain recommendation
  5. `ckad-drill validate-scenario <file>` runs parse, setup, solution apply, validation, and cleanup and reports the result
**Plans**: 6/6 complete

Plans:
- [x] 03-01-PLAN.md — Session management (session.sh) and timer (timer.sh) with unit tests
- [x] 03-02-PLAN.md — Progress tracking (progress.sh) and sample YAML scenarios
- [x] 03-03-PLAN.md — Wire drill subcommands into bin/ckad-drill (drill, check, hint, solution, current, next, skip, env, timer)
- [x] 03-04-PLAN.md — Status display, validate-scenario tool, and drill dispatch unit tests

### Phase 3.1: Drill Integration Fixes (INSERTED — Gap Closure)
**Goal**: Fix 3 integration breaks found by v1.0 milestone audit so drill sessions work correctly end-to-end
**Depends on**: Phase 3
**Requirements**: DRIL-03, DRIL-05, DRIL-06, DRIL-07, DRIL-11, PROG-01
**Gap Closure**: Closes all gaps from v1.0-MILESTONE-AUDIT.md
**Success Criteria** (what must be TRUE):
  1. `ckad-drill check` on a failing scenario captures the exit code, prints pass/fail results, and records the attempt to progress.json (does not exit silently)
  2. `ckad-drill next` and `ckad-drill skip` delete the scenario namespace from the cluster before moving on
  3. Pressing Ctrl+C during a drill session deletes the scenario namespace from the cluster
  4. `ckad-drill solution` displays multi-line heredoc steps as complete numbered steps (not split across lines)
**Plans**: 1/1 complete

Plans:
- [x] 03.1-01-PLAN.md — Fix 4 defects in bin/ckad-drill (set-e guard, namespace bridge, trap fix, solution display) + regression tests

</details>

---

### v1.1 Ship It (In Progress)

**Milestone Goal:** Complete exam mode, learn mode, migrate 70+ scenarios, and ship with CI, install script, and docs.

**Parallelism note:** Phase 4 (Exam Mode) and Phase 5 (Learn Mode) both depend only on Phase 3 and can run in parallel. Phase 6 (Content Migration) depends on Phase 2 + Phase 3 and can begin as soon as Phase 3.1 completes. Phase 7 depends on Phase 6.

### Phase 4: Exam Mode
**Goal**: A user can run a full 2-hour mock exam with multiple questions, navigation, and graded results
**Depends on**: Phase 3
**Requirements**: EXAM-01, EXAM-02, EXAM-03, EXAM-04, EXAM-05, EXAM-06, EXAM-07, EXAM-08, EXAM-09, EXAM-10, EXAM-11, EXAM-12
**Success Criteria** (what must be TRUE):
  1. `ckad-drill exam` starts a session with 15-20 questions weighted by CKAD domain percentages, all namespaces created upfront, and a global 2-hour timer in the prompt
  2. `ckad-drill exam list` shows all questions with status icons; `ckad-drill exam jump N`, `next`, and `prev` navigate between them; `ckad-drill exam flag` marks a question for review
  3. `ckad-drill check` during an exam validates only the current question and hints and solutions are blocked
  4. `ckad-drill exam submit` grades all questions, shows per-domain scores, and displays a clear PASS (>=66%) or FAIL result
  5. All exam namespaces are cleaned up on submit or Ctrl+C and the exam result is recorded to progress.json
**Plans**: 2 plans

Plans:
- [ ] 04-01-PLAN.md — Exam session engine (lib/exam.sh) with question selection, navigation, flagging, and grading + unit tests
- [ ] 04-02-PLAN.md — Wire exam subcommands into CLI, extend progress recording, block hints/solutions in exam mode

### Phase 5: Learn Mode
**Goal**: A user can work through progressive domain lessons with concept explanations and validated exercises
**Depends on**: Phase 3
**Requirements**: LERN-01, LERN-02, LERN-03, LERN-04, LERN-05
**Success Criteria** (what must be TRUE):
  1. `ckad-drill learn` lists all learn-mode scenarios by domain with completion status shown
  2. `ckad-drill learn --domain 1` presents lessons in progressive order (easy scenarios first) with concept text shown before the task
  3. Completing a lesson shows the next lesson in that domain and records completion in progress.json
**Plans**: 2 plans

Plans:
- [ ] 05-01-PLAN.md — Learn engine (lib/learn.sh) with discovery, ordering, concept display, and progress tracking + unit tests
- [ ] 05-02-PLAN.md — Wire learn subcommands into CLI, extend check for learn mode

### Phase 6: Content Migration
**Goal**: The scenario library reaches 70+ validated YAML scenarios covering all 5 domains
**Depends on**: Phase 2 (YAML schema defined), Phase 3 (validate-scenario tool working)
**Requirements**: CONT-01, CONT-02, CONT-03, CONT-04, CONT-05, CONT-06, CONT-07, CONT-08
**Success Criteria** (what must be TRUE):
  1. All 31 existing markdown scenarios are converted to YAML format with typed validations and pass `ckad-drill validate-scenario`
  2. All 12 troubleshooting labs are converted to debug-prefix YAML scenarios
  3. Tutorial inline exercises are extracted as learn-prefix scenarios with concept text; domain exercises yield additional scenarios
  4. Total scenario count is at or above 70 with each of the 5 domains having at least 10 scenarios
  5. Speed drills and cheatsheet are preserved as reference content; existing study guide content is archived
**Plans**: 5 plans

Plans:
- [ ] 06-01-PLAN.md — Convert markdown scenarios for Domains 1-3 to YAML (18 files)
- [ ] 06-02-PLAN.md — Convert markdown scenarios for Domains 4-5 to YAML (12 files)
- [ ] 06-03-PLAN.md — Convert 12 troubleshooting labs to debug-prefix YAML scenarios
- [ ] 06-04-PLAN.md — Extract learn-prefix scenarios from tutorials, exercises, and quizzes (16 files)
- [ ] 06-05-PLAN.md — Audit counts, gap-fill to 70+, archive old content, preserve reference materials

### Phase 7: Testing, CI, Distribution, Docs
**Goal**: The project has a full test suite, automated CI, and a working install story
**Depends on**: Phase 6
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, CICD-01, CICD-02, DIST-01, DIST-02, DOCS-01, DOCS-02
**Success Criteria** (what must be TRUE):
  1. `make test-unit` runs all bats unit tests for lib functions without a cluster; all pass and shellcheck reports zero warnings
  2. `make test` runs the full suite including integration tests against a live cluster; all scenario lifecycle tests pass
  3. `curl -sSL .../install.sh | sh` installs ckad-drill with all dependencies on a clean Linux or macOS machine
  4. CI runs shellcheck and unit tests on every PR; CI runs full test suite on merge to main
  5. README provides a working quick-start and CONTRIBUTING.md explains how to write and validate a new scenario YAML
**Plans**: 3 plans

Plans:
- [ ] 07-01-PLAN.md — Test suite: schema validation tests, integration test scaffolding, unit test + shellcheck audit
- [ ] 07-02-PLAN.md — Distribution: install.sh for curl-pipe-sh, dev-setup.sh audit
- [ ] 07-03-PLAN.md — CI/CD workflows, README.md, CONTRIBUTING.md

## Progress

**Execution Order:**
v1.1 phases: 4 → 5 → 6 → 7
Phase 4 and Phase 5 can run in parallel (both depend only on Phase 3, which is complete).
Phase 6 can begin as soon as Phase 3.1 is complete (depends on Phase 2 + Phase 3).
Phase 7 begins after Phase 6 completes.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation + Cluster | v1.0 | 2/2 | Complete | 2026-02-28 |
| 2. Scenario + Validation Engine | v1.0 | 2/2 | Complete | 2026-02-28 |
| 3. CLI + Drill Mode | v1.0 | 6/6 | Complete | 2026-02-28 |
| 3.1 Drill Integration Fixes | v1.0 | 1/1 | Complete | 2026-03-01 |
| 4. Exam Mode | v1.1 | 2/2 | Complete | 2026-03-01 |
| 5. Learn Mode | v1.1 | 2/2 | Complete | 2026-03-01 |
| 6. Content Migration | 6/6 | Complete   | 2026-03-01 | - |
| 7. Testing, CI, Distribution, Docs | v1.1 | 0/3 | Not started | - |

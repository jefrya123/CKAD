---
status: validated
inputDocuments:
  - docs/prd.md
  - _bmad-output/planning-artifacts/architecture.md
workflowType: epics-and-stories
project_name: ckad-drill
date: '2026-02-28'
---

# Epics & Stories: ckad-drill

## Epic 1: Foundation & Project Scaffolding

**Goal:** Establish project structure, shared utilities, and terminal output system so all subsequent epics have a stable foundation.

**Dependencies:** None — this is the root.

### Story 1.1: Create Project Directory Structure

**As a** developer,
**I want** the full project directory structure created with placeholder files,
**So that** all subsequent stories have a consistent location for their code.

**Acceptance Criteria:**
- Given the repo root, when `ls` is run, then the structure matches the architecture doc: `bin/`, `lib/`, `scenarios/domain-{1..5}/`, `content/domain-{1..5}/`, `test/unit/`, `test/integration/`, `test/schema/`, `test/helpers/`, `scripts/`, `archive/`
- Given the structure exists, when `make` is run, then a Makefile exists with targets: `test`, `shellcheck`, `test-unit`, `test-integration`, `install`
- Given a developer clones the repo, when they run `make shellcheck`, then shellcheck runs against `bin/ckad-drill` and `lib/*.sh` (even if files are stubs)

**Notes:**
- Move existing study guide content to `archive/` (preserve it, don't delete)
- Create LICENSE (MIT)
- Stub files can contain only a header comment

---

### Story 1.2: Implement lib/common.sh — Shared Constants & Utilities

**As a** developer of any ckad-drill component,
**I want** a single source of truth for paths, constants, and shared utilities,
**So that** all lib files use consistent configuration without duplication.

**Acceptance Criteria:**
- Given common.sh is sourced, when `echo $CKAD_CONFIG_DIR` is run, then it outputs `~/.config/ckad-drill` (respects XDG_CONFIG_HOME if set)
- Given common.sh is sourced, when `echo $CKAD_DATA_DIR` is run, then it outputs `~/.local/share/ckad-drill` (respects XDG_DATA_HOME if set)
- Given common.sh is sourced, then `CKAD_SESSION_FILE`, `CKAD_PROGRESS_FILE`, `CKAD_ROOT` are all defined
- Given common.sh is sourced, then exit code constants are available: `EXIT_OK=0`, `EXIT_ERROR=1`, `EXIT_NO_CLUSTER=2`, `EXIT_NO_SESSION=3`, `EXIT_PARSE_ERROR=4`
- Given common.sh is sourced, then no top-level execution occurs (functions only)
- Given common.sh is sourced by another lib, then it does NOT set `set -euo pipefail` (that's only for `bin/ckad-drill`)

**Notes:**
- Variable style: `UPPER_SNAKE_CASE` for globals, `lower_snake_case` for locals
- All variables double-quoted, braces on all expansions: `"${var}"`

---

### Story 1.3: Implement lib/display.sh — Terminal Output Functions

**As a** developer writing any user-facing output,
**I want** standardized display functions with consistent formatting and color handling,
**So that** all output looks uniform and degrades gracefully when stdout is not a terminal.

**Acceptance Criteria:**
- Given display.sh is sourced, then functions exist: `pass()`, `fail()`, `info()`, `warn()`, `error()`, `header()`
- Given `pass "message"` is called, then output is green with ✅ prefix
- Given `fail "message"` is called, then output is red with ❌ prefix
- Given `info "message"` is called, then output is blue
- Given `warn "message"` is called, then output is yellow with ⚠ prefix
- Given `error "message"` is called, then output is red bold to stderr AND the function exits with code 1
- Given `header "text"` is called, then output is bold white with a horizontal rule
- Given stdout is not a terminal (`[[ ! -t 1 ]]`), then all color codes are stripped (plain text output)
- Given display.sh, when shellcheck is run, then zero warnings

---

## Epic 2: Cluster Management

**Goal:** Manage the kind cluster lifecycle so scenarios have a real Kubernetes API to validate against.

**Dependencies:** Epic 1 (common.sh, display.sh)

### Story 2.1: Implement lib/cluster.sh — Kind Cluster Lifecycle

**As a** user,
**I want** `ckad-drill start` to create a properly configured kind cluster and `ckad-drill stop` to destroy it,
**So that** I have a real Kubernetes environment for practice without manual setup.

**Acceptance Criteria:**
- Given Docker is running and kind is installed, when `cluster_create()` is called, then a kind cluster named `ckad-drill` is created
- Given the cluster already exists, when `cluster_create()` is called, then it detects the existing cluster and skips creation (idempotent)
- Given the cluster exists, when `cluster_ensure_running()` is called, then it returns 0 if healthy or exits with `EXIT_NO_CLUSTER` if unhealthy
- Given the cluster exists, when `cluster_delete()` is called, then the kind cluster `ckad-drill` is deleted
- Given the cluster exists, when `cluster_reset()` is called, then the cluster is deleted and recreated
- Given Docker is NOT running, when `cluster_create()` is called, then a clear error message is shown via `error()` explaining Docker is required
- Given kind is NOT installed, when `cluster_create()` is called, then a clear error message is shown with install instructions
- Given all functions, then they use `display.sh` functions for all output (no raw echo with escape codes)
- Given lib/cluster.sh, when shellcheck is run, then zero warnings

---

### Story 2.2: Implement scripts/cluster-setup.sh — Cluster Addons

**As a** user,
**I want** the kind cluster to include Calico CNI, nginx ingress, and metrics-server,
**So that** I can practice NetworkPolicy, Ingress, and HPA scenarios just like the real exam.

**Acceptance Criteria:**
- Given a fresh kind cluster, when `cluster-setup.sh` runs, then Calico CNI is installed and operational (NetworkPolicy support verified)
- Given a fresh kind cluster, when `cluster-setup.sh` runs, then nginx ingress controller is installed and has an IngressClass
- Given a fresh kind cluster, when `cluster-setup.sh` runs, then metrics-server is installed and `kubectl top nodes` returns data within 60s
- Given a fresh kind cluster, when `cluster-setup.sh` runs, then a default StorageClass exists
- Given the kind cluster creation alone (before addons), when timed, then it completes in under 60 seconds (NFR-02)
- Given the full setup (cluster + all addons), when timed, then it completes in under 120 seconds
- Given the kind config, then it uses a Kubernetes version matching the current CKAD exam (v1.31+)
- Given cluster-setup.sh, when shellcheck is run, then zero warnings

**Notes:**
- Kind YAML config file should be embedded or co-located with cluster-setup.sh
- Addon manifests applied via kubectl apply -f with appropriate URLs
- NFR-02 target of 60s applies to cluster creation only; addon installation adds additional time

---

## Epic 3: Scenario Engine

**Goal:** Load, parse, and manage the lifecycle of YAML-based scenarios — the core content delivery system.

**Dependencies:** Epic 1 (common.sh, display.sh), Epic 2 (cluster.sh — for namespace creation)

### Story 3.1: Define Scenario YAML Schema

**As a** content contributor,
**I want** a well-defined YAML schema for scenarios,
**So that** I know exactly what fields to include and how to structure my content.

**Acceptance Criteria:**
- Given the schema definition, then required fields are: `id`, `domain`, `title`, `difficulty`, `time_limit`, `description`, `validations`, `solution`
- Given the schema definition, then optional fields are: `tags`, `weight`, `hint`, `setup`, `cleanup`, `namespace`, `learn` (boolean), `concept_text`
- Given `domain`, then valid values are integers 1-5
- Given `difficulty`, then valid values are: `easy`, `medium`, `hard`
- Given `time_limit`, then value is a positive integer (seconds)
- Given `id`, then format is descriptive hyphenated (e.g., `multi-container-pod`), no numeric prefixes
- Given learn-mode scenarios, then `id` has `learn-` prefix
- Given debug scenarios, then `id` has `debug-` prefix
- Given `namespace`, then value is lowercase with hyphens only; if omitted, fallback is `drill-<id>`
- A reference scenario YAML file exists at `scenarios/domain-1/multi-container-pod.yaml` as a working example

**Notes:**
- This story produces documentation + one reference YAML file, not code
- Schema enforcement is in Story 3.3 and Epic 10 (validate-scenario)
- The `weight` field is used for exam question selection — scenarios with higher weight are more likely to be selected within their domain (default: 1). Story 7.1 uses this for weighted selection.
- ID format is descriptive hyphenated per architecture conventions — the PRD's `sc-NN-` prefix convention is superseded

---

### Story 3.2: Implement lib/scenario.sh — Scenario Loading & Lifecycle

**As a** user running drills,
**I want** scenarios loaded from YAML, set up against the cluster, and cleaned up afterward,
**So that** each drill starts clean and doesn't leave residual resources.

**Acceptance Criteria:**
- Given a valid scenario YAML, when `scenario_load(file)` is called, then all fields are parsed via yq and available as variables/functions
- Given a scenario with `setup` commands, when `scenario_setup()` is called, then each setup command is executed in order
- Given a scenario with a `namespace` field, when `scenario_setup()` is called, then the namespace is created if it doesn't exist
- Given a scenario without a `namespace` field, when `scenario_setup()` is called, then namespace `drill-<id>` is created
- Given an active scenario, when `scenario_cleanup()` is called, then the scenario's namespace is deleted (removing all resources in it)
- Given `scenario_select(--domain 3 --difficulty easy)` is called, then only matching scenarios from `scenarios/` are returned
- Given `scenario_select()` with no filters, then a random scenario is selected from all available
- Given a scenario is loaded, when `scenario_get_field(field_name)` is called, then the value is returned
- Given the `scenarios/` directory and an external scenarios path, when scenarios are listed, then both sources are included
- Given a duplicate ID across built-in and external scenarios, then first-loaded wins with a `warn()` message
- Given a scenario with `tags` containing `helm`, when `scenario_setup()` is called and `helm` is not installed, then an error message is shown: "Helm is required for this scenario. Install Helm and try again." (FR-20)
- Given lib/scenario.sh, when shellcheck is run, then zero warnings

---

### Story 3.3: Implement Scenario Schema Validation (lib function)

**As a** content contributor,
**I want** my scenario YAML validated for correctness before it's used,
**So that** I catch errors early and don't ship broken content.

**Acceptance Criteria:**
- Given a scenario YAML, when `scenario_validate(file)` is called, then all required fields are checked for presence
- Given a scenario with `domain: 6`, when validated, then an error is returned ("domain must be 1-5")
- Given a scenario with `difficulty: extreme`, when validated, then an error is returned ("difficulty must be easy/medium/hard")
- Given a scenario with `time_limit: -10`, when validated, then an error is returned ("time_limit must be positive")
- Given a scenario with `validations` containing an unknown type, when validated, then an error is returned listing valid types
- Given a scenario missing `solution`, when validated, then an error is returned ("solution is required")
- Given a valid scenario, when validated, then returns 0 with no output

**Notes:**
- This is the parsing/schema validation part only. Full end-to-end validation (setup → apply solution → run checks) is in Epic 10.

---

## Epic 4: Validation Engine

**Goal:** Run kubectl-based checks against the live cluster and return structured pass/fail results.

**Dependencies:** Epic 1 (common.sh, display.sh), Epic 2 (cluster must be running)

### Story 4.1: Implement lib/validator.sh — Core Validation Framework

**As a** developer,
**I want** a validation engine that dispatches typed checks and aggregates results,
**So that** scenarios can define what to check and get consistent pass/fail feedback.

**Acceptance Criteria:**
- Given a list of validation specs (from scenario YAML), when `validator_run_checks(namespace, validations_json)` is called, then each check is executed in order
- Given a check passes, then `pass("description")` is called and result is recorded as passed
- Given a check fails, then `fail("description: expected X, got Y")` is called and result is recorded as failed
- Given all checks complete, when `validator_get_results()` is called, then a summary is returned: total, passed, failed
- Given a validation with unknown type, then `fail("unknown validation type: foo")` is returned (not a crash)
- Given the cluster is unreachable, then checks fail with a clear error message (not a bash crash)
- Given lib/validator.sh, when shellcheck is run, then zero warnings

---

### Story 4.2: Implement Typed Validation Checks

**As a** scenario author,
**I want** 10 typed validation checks available,
**So that** I can validate common Kubernetes patterns without writing raw kubectl commands.

**Acceptance Criteria:**
- Given `resource_exists` check with `resource: pod/web-logger`, when the pod exists in the namespace, then check passes
- Given `resource_exists` check, when the resource does NOT exist, then check fails with "resource pod/web-logger not found"
- Given `resource_field` check with `resource`, `jsonpath`, and `expected`, when the jsonpath value matches expected, then check passes
- Given `container_count` check with `resource` and `expected: 2`, when the pod has 2 containers, then check passes
- Given `container_image` check with `resource`, `container`, and `expected`, when the named container uses the expected image, then check passes
- Given `container_env` check with `resource`, `container`, `env_name`, and `expected`, when the env var exists with expected value, then check passes
- Given `volume_mount` check with `resource`, `container`, and `mount_path`, when the mount exists, then check passes
- Given `container_running` check with `resource` and `container`, when the container status is Running, then check passes
- Given `label_selector` check with `resource_type` and `labels`, when `kubectl get <type> -l <labels>` returns results, then check passes
- Given `resource_count` check with `resource_type`, `selector`, and `expected`, when the count matches, then check passes
- Given `command_output` check with `command` and one of `contains`/`matches`/`equals`, when the output satisfies the condition, then check passes

**Notes:**
- Each check is implemented as `_validator_check_<type>()` private function
- ADR-07: Single check, no retry. Each validation runs once.

---

## Epic 5: CLI Entry Point & Drill Mode

**Goal:** Wire all components together into the main `ckad-drill` command with working drill mode.

**Dependencies:** Epics 1-4

### Story 5.1: Implement bin/ckad-drill — Entry Point & Subcommand Dispatch

**As a** user,
**I want** a single `ckad-drill` command with subcommands,
**So that** I can start clusters, run drills, check my work, and manage my session from one tool.

**Acceptance Criteria:**
- Given `bin/ckad-drill` is executed, then it sets `set -euo pipefail` and sources all libs in the correct order (common → display → cluster → scenario → validator → timer → progress → exam)
- Given `ckad-drill start`, then `cluster_create()` is called
- Given `ckad-drill stop`, then `cluster_delete()` is called
- Given `ckad-drill reset`, then `cluster_reset()` is called
- Given `ckad-drill drill [--domain N] [--difficulty LEVEL]`, then a scenario is selected, set up, and displayed
- Given `ckad-drill check`, then validations run for the current scenario
- Given `ckad-drill hint`, then the current scenario's hint is displayed (error "Hints are not available during exam mode" if exam is active)
- Given `ckad-drill solution`, then the current scenario's solution is displayed (error "Solutions are not available during exam mode" if exam is active)
- Given `ckad-drill next`, then the current scenario is cleaned up and a new one loaded
- Given `ckad-drill skip`, then the current scenario is cleaned up without checking
- Given `ckad-drill current`, then the active scenario's task description is reprinted
- Given `ckad-drill status`, then progress dashboard is shown
- Given `ckad-drill timer`, then remaining time is printed (dispatches to timer.sh)
- Given `ckad-drill env`, then shell code for PROMPT_COMMAND timer is output to stdout (dispatches to timer.sh)
- Given `ckad-drill env --reset`, then shell code to restore original prompt is output
- Given `ckad-drill learn [--domain N]`, then learn mode flow is started (dispatches to scenario.sh learn mode)
- Given `ckad-drill validate-scenario <file|dir>`, then scenario validation is run (dispatches to scenario.sh + validator.sh)
- Given `ckad-drill exam [--time Nm]`, then exam mode is started (dispatches to exam.sh)
- Given any session start (drill, learn, or exam), then the strict exam environment is set up: `alias k=kubectl`, `source <(kubectl completion bash)`, `export EDITOR=vim` — no additional aliases or tools (ADR-03)
- Given an unknown subcommand, then usage help is printed to stderr and exit code is 1
- Given `ckad-drill` with no arguments, then usage help is printed
- Given a signal (SIGINT/SIGTERM), then `trap cleanup EXIT INT TERM` triggers namespace/resource cleanup
- Given bin/ckad-drill, when shellcheck is run, then zero warnings

---

### Story 5.2: Implement Drill Mode End-to-End Flow

**As a** CKAD candidate,
**I want** to run `ckad-drill drill`, see a task, work on it in my terminal, then check my work,
**So that** I can practice exam-style scenarios with real feedback.

**Acceptance Criteria:**
- Given `ckad-drill drill` is run and cluster is healthy, then a random scenario is loaded, namespace created, setup run, and task description displayed with `header()`
- Given `ckad-drill drill --domain 4`, then only domain 4 scenarios are considered
- Given `ckad-drill drill --difficulty hard`, then only hard scenarios are considered
- Given a scenario is active, when `ckad-drill check` is run, then validations execute and pass/fail results are displayed
- Given all validations pass, then `pass("All checks passed!")` is displayed and result recorded to progress
- Given some validations fail, then each failure is displayed with expected vs actual, and result recorded to progress
- Given `ckad-drill hint`, then the scenario's hint text is displayed (or "No hint available" if none)
- Given `ckad-drill solution`, then the scenario's solution is displayed
- Given `ckad-drill next`, then cleanup runs, a new scenario is selected, and the flow repeats
- Given no active session exists, when `ckad-drill check` is run, then error message: "No active scenario. Run `ckad-drill drill` first."
- Given a drill completes (check or skip), then session.json is updated

---

## Epic 6: Timer & Progress Tracking

**Goal:** Add countdown timers and persistent progress tracking so users feel exam pressure and see improvement.

**Dependencies:** Epic 1 (common.sh), Epic 5 (drill flow integration)

### Story 6.1: Implement lib/timer.sh — PROMPT_COMMAND Timer

**As a** user,
**I want** a countdown timer visible in my bash prompt while working on a scenario,
**So that** I feel realistic exam time pressure.

**Acceptance Criteria:**
- Given `timer_start(seconds)` is called, then `CKAD_DRILL_END` is set to current epoch + seconds
- Given `ckad-drill env` is run, then shell code is output that sets up PROMPT_COMMAND with `__ckad_timer` function
- Given the timer is active, then the bash prompt shows `[MM:SS]` remaining time before the normal PS1
- Given time has expired, then the prompt shows `[⏰ TIME UP]`
- Given `ckad-drill env --reset` is run, then the original PS1 is restored and PROMPT_COMMAND unset
- Given `ckad-drill timer` is run, then the remaining time is printed to stdout (for users who don't source env)
- Given the env output, then it does NOT contain `set -euo pipefail` (shell boundary safety)
- Given the env output is sourced twice, then nothing breaks (idempotent)
- Given lib/timer.sh, when shellcheck is run, then zero warnings

---

### Story 6.2: Implement lib/progress.sh — Progress Tracking

**As a** user,
**I want** my drill and exam results saved and summarized per domain,
**So that** I can track my improvement and focus on weak areas.

**Acceptance Criteria:**
- Given `progress_record(scenario_id, passed, time_seconds)` is called, then the result is written to `progress.json`
- Given a scenario attempted multiple times, then `attempts` is incremented and `last_attempted` is updated
- Given `progress_record_exam(score, domain_scores)` is called, then exam result is appended to the `exams` array
- Given `progress_get_stats()` is called, then per-domain pass rates are calculated and returned
- Given `progress_get_weakest()` is called, then the domain with the lowest pass rate is returned
- Given `progress_get_streak()` is called, then the current daily streak is returned
- Given `progress.json` doesn't exist, when any progress function is called, then it is created with `version: 1` and empty data
- Given a progress.json from a previous version (missing new fields), when read, then missing fields get defaults (additive-only schema — ADR-05)
- Given `ckad-drill status` is run, then a formatted dashboard shows per-domain stats, exam history, and weak area recommendation
- Given lib/progress.sh, when shellcheck is run, then zero warnings

**Notes:**
- Progress file location: `~/.config/ckad-drill/progress.json` (from common.sh)
- All JSON manipulation via `jq`

---

## Epic 7: Exam Mode

**Goal:** Simulate a full CKAD exam with multi-scenario sessions, navigation, flagging, and scoring.

**Dependencies:** Epics 1-6 (drill mode must be working first)

### Story 7.1: Implement lib/exam.sh — Exam Session Management

**As a** CKAD candidate,
**I want** to take a full mock exam with 15-20 questions and a 2-hour timer,
**So that** I can simulate the real exam experience.

**Acceptance Criteria:**
- Given `ckad-drill exam` is run, then 15-20 scenarios are selected weighted by CKAD domain percentages (D1: 20%, D2: 20%, D3: 15%, D4: 25%, D5: 20%), using the scenario `weight` field for selection probability within each domain
- Given exam starts, then ALL namespaces for all questions are created at once
- Given exam starts, then a 2-hour timer is started (global, not per-question)
- Given `ckad-drill exam --time 60m`, then the timer is set to 60 minutes
- Given an active exam, when `ckad-drill exam list` is run, then all questions are shown with status: ✅ (passed), ❌ (failed), 🚩 (flagged), ⬜ (pending)
- Given an active exam, when `ckad-drill exam next` is run, then the next question is displayed
- Given an active exam, when `ckad-drill exam prev` is run, then the previous question is displayed
- Given an active exam, when `ckad-drill exam jump 5` is run, then question 5 is displayed
- Given an active exam, when `ckad-drill exam flag` is run, then the current question is flagged for review
- Given an active exam, when `ckad-drill check` is run, then only the current question's validations run
- Given hints/solutions, then they are NOT available during exam mode (error message if attempted)
- Given lib/exam.sh, when shellcheck is run, then zero warnings

---

### Story 7.2: Implement Exam Submission & Scoring

**As a** CKAD candidate,
**I want** to submit my exam and see detailed results with per-domain scores,
**So that** I know if I would have passed and where to improve.

**Acceptance Criteria:**
- Given `ckad-drill exam submit` is run, then ALL questions are validated (not just previously checked ones)
- Given scoring completes, then total score and per-domain scores are displayed as percentages
- Given total score >= 66%, then `pass("EXAM PASSED!")` is displayed
- Given total score < 66%, then `fail("EXAM FAILED")` is displayed with the score
- Given scoring completes, then per-domain breakdown is shown (e.g., "Domain 1: 80%, Domain 2: 60%...")
- Given scoring completes, then weakest domain is highlighted with recommendation
- Given submission completes, then exam results are recorded to progress.json via `progress_record_exam()`
- Given submission completes, then ALL exam namespaces are deleted (cleanup)
- Given the user quits mid-exam (Ctrl+C), then all namespaces are cleaned up via trap handler

---

## Epic 8: Content Migration

**Goal:** Convert ALL existing study guide content (scenarios, troubleshooting labs, exercises, quizzes, speed drills, cheatsheet) into YAML scenario format or reference content, and author net-new scenarios to reach the 70+ launch target (NFR-06).

**Dependencies:** Epic 3 (scenario schema must be defined)

### Story 8.1: Migrate Existing Scenarios (31) to YAML Format

**As a** user,
**I want** the existing 31 study guide scenarios converted to validated YAML,
**So that** ckad-drill launches with substantial content from day one.

**Acceptance Criteria:**
- Given each of the 31 existing scenarios in `archive/`, when converted, then a corresponding YAML file exists in `scenarios/domain-N/`
- Given each converted scenario, then it has: id, domain, title, difficulty, time_limit, description, validations (with appropriate typed checks), solution, and at least one hint
- Given each converted scenario, then the `id` uses the architecture's descriptive hyphenated format (e.g., `multi-container-pod`), NOT the PRD's `sc-NN-` prefix format
- Given each converted scenario, then `namespace` uses a realistic name per ADR-06 (not `default`); fallback is `drill-<id>` if no thematic name fits
- Given each scenario, when `scenario_validate()` is run, then it passes schema validation
- Given the full scenario set, then IDs are unique across all files
- Given the full scenario set, then all 5 domains have at least 5 scenarios each

---

### Story 8.2: Migrate Troubleshooting Labs (12) to Debug Scenarios

**As a** user,
**I want** the 12 troubleshooting labs converted to debug-style scenarios,
**So that** I can practice diagnosing and fixing broken Kubernetes resources.

**Acceptance Criteria:**
- Given each troubleshooting lab, when converted, then a YAML scenario exists with `debug-` prefix ID
- Given a debug scenario, then `setup` commands deploy the broken resources (from the existing broken YAML)
- Given a debug scenario, then `validations` check that the user has FIXED the issue (not just that the broken state exists)
- Given a debug scenario, then `solution` shows the fix steps
- Given all 12 debug scenarios, when validated, then setup deploys broken state and solution + validations confirm the fix works

---

### Story 8.3: Extract Tutorial Inline Exercises as Learn Scenarios

**As a** user in learn mode,
**I want** tutorial exercises available as guided scenarios with concept text,
**So that** I can learn concepts progressively with real-cluster validation.

**Acceptance Criteria:**
- Given each domain tutorial in `archive/`, when exercises are extracted, then learn scenarios exist with `learn-` prefix IDs
- Given a learn scenario, then `learn: true` is set and `concept_text` contains the relevant explanation
- Given learn scenarios, then they are ordered progressively within each domain (easy → hard)
- Given learn scenarios per domain, then at least 3 exist for each of the 5 domains
- Given learn scenario concept text, then corresponding markdown files exist in `content/domain-N/`

---

### Story 8.4: Extract Domain Exercises (~2,200 lines) as Scenarios

**As a** user,
**I want** the 5 domain exercise files converted to drill scenarios,
**So that** the existing practice content is preserved and usable in ckad-drill.

**Acceptance Criteria:**
- Given each of the 5 domain exercise files in `archive/`, when exercises are extracted, then corresponding YAML scenarios exist in `scenarios/domain-N/`
- Given each extracted scenario, then it has all required fields and passes `scenario_validate()`
- Given the extraction, then exercises that overlap with the 31 already-migrated scenarios (Story 8.1) are deduplicated (not duplicated)
- Given extraction completes, then at least 10 net-new scenarios are produced from the exercise files

**Notes:**
- Domain exercises are distinct from tutorials (Story 8.3) — exercises are standalone practice problems, tutorials have concept text

---

### Story 8.5: Migrate Quizzes, Speed Drills & Cheatsheet

**As a** user,
**I want** quiz content converted to exam-eligible scenarios, speed drills preserved as reference, and the cheatsheet integrated,
**So that** all existing study content is accessible through ckad-drill.

**Acceptance Criteria:**
- Given the 5 domain quizzes + 1 mock exam quiz in `archive/`, when converted, then quiz questions that map to practical tasks become YAML scenarios in `scenarios/domain-N/`
- Given quiz questions that are purely knowledge-based (not practical kubectl tasks), then they are archived as reference content in `content/` with a note that they're not convertible to validated scenarios
- Given the 3 speed drill documents, then they are preserved as reference markdown in `content/reference/speed-drills/`
- Given the cheatsheet, then it is preserved as reference markdown in `content/reference/cheatsheet.md`
- Given all conversions complete, then the total scenario count across all stories (8.1 + 8.2 + 8.3 + 8.4 + 8.5) is tracked to verify progress toward the 70+ target (NFR-06)

---

### Story 8.6: Author Net-New Scenarios to Reach 70+ Target

**As a** user,
**I want** at least 70 validated scenarios at launch,
**So that** ckad-drill has comprehensive coverage across all CKAD domains (NFR-06).

**Acceptance Criteria:**
- Given the total scenario count from migration stories (8.1-8.5) falls short of 70, then net-new original scenarios are authored to close the gap
- Given net-new scenarios, then they prioritize domains with the fewest scenarios (to ensure balanced coverage)
- Given net-new scenarios, then each passes `ckad-drill validate-scenario` end-to-end
- Given all content stories are complete, then the total scenario count is >= 70
- Given the final scenario set, then each domain has at least 10 scenarios

**Notes:**
- Architecture estimates ~50+ from migration. This story covers the gap from migration output to the 70+ NFR target.
- Prioritize domains 4 (Config & Security, 25% exam weight) and 5 (Networking, 20%) as they tend to have fewer existing scenarios.

---

## Epic 9: Learn Mode

**Goal:** Implement learn mode that presents guided, progressive lessons with concept explanations and validated exercises.

**Dependencies:** Epic 5 (drill flow), Epic 8 (learn content exists)

### Story 9.1: Implement Learn Mode Flow

**As a** beginner learning Kubernetes,
**I want** `ckad-drill learn --domain 1` to guide me through lessons progressively,
**So that** I learn concepts step-by-step with real practice.

**Acceptance Criteria:**
- Given `ckad-drill learn` is run, then learn-mode scenarios are listed by domain with completion status
- Given `ckad-drill learn --domain 1` is run, then domain 1 learn scenarios are presented in order (easiest first)
- Given a learn scenario is presented, then concept text is displayed BEFORE the task description
- Given a learn scenario, then hints are shown more readily (or auto-displayed after timeout)
- Given a learn scenario is completed (all checks pass), then the next lesson in the domain is offered
- Given all lessons in a domain are complete, then completion is shown and the next domain is suggested
- Given learn mode progress, then completion is tracked per-lesson in progress.json

**Notes:**
- Learn mode uses the same scenario engine — learn scenarios are just scenarios with `learn: true` and extra `concept_text`
- This is the unified content model from the architecture doc

---

## Epic 10: Scenario Validation Tool & Install

**Goal:** Provide tools for contributors to validate scenarios and for users to install ckad-drill.

**Dependencies:** Epics 3-4 (scenario engine + validator)

### Story 10.1: Implement validate-scenario Subcommand

**As a** content contributor,
**I want** to run `ckad-drill validate-scenario my-scenario.yaml` and get pass/fail,
**So that** I know my scenario works before submitting a PR.

**Acceptance Criteria:**
- Given `ckad-drill validate-scenario <file>`, then the scenario is:
  1. Parsed and schema-validated (all required fields present, correct types)
  2. Setup commands executed against the cluster
  3. Solution applied (kubectl apply the solution)
  4. Validations run (all checks must pass)
  5. Cleanup executed
- Given a valid scenario, then "PASS: scenario <id> validated successfully" is shown
- Given a schema error, then the specific error is shown and execution stops early
- Given validations fail after applying the solution, then each failing check is reported
- Given no cluster is running, then an error message says to run `ckad-drill start` first
- Given `ckad-drill validate-scenario scenarios/` (directory), then all YAML files in it are validated and a summary is shown

---

### Story 10.2: Implement scripts/install.sh — User Installation

**As a** user,
**I want** to run a single curl command to install ckad-drill,
**So that** I can start practicing immediately without manual setup.

**Acceptance Criteria:**
- Given `curl -sSL <url>/install.sh | sh`, then the script:
  1. Checks for Docker (error if missing)
  2. Checks for kubectl (error if missing)
  3. Checks/installs kind (if missing, downloads appropriate binary)
  4. Checks/installs yq (if missing)
  5. Checks/installs jq (if missing)
  6. Checks for Helm (warns if missing: "Helm is optional but required for Helm-specific scenarios")
  7. Downloads ckad-drill scripts + scenarios to `~/.local/share/ckad-drill/`
  8. Symlinks `ckad-drill` to `~/.local/bin/ckad-drill`
  9. Verifies `~/.local/bin` is in PATH (warns if not)
- Given installation completes, when `ckad-drill start` is run, then the cluster is created successfully
- Given the user is on macOS, then arm64/amd64 is detected correctly for kind/yq downloads
- Given the user is on Linux, then arm64/amd64 is detected correctly
- Given any download fails, then a clear error message is shown and the script exits

---

### Story 10.3: Implement scripts/dev-setup.sh — Developer Setup

**As a** developer,
**I want** a single script to install development dependencies,
**So that** I can start contributing immediately.

**Acceptance Criteria:**
- Given `scripts/dev-setup.sh` is run, then bats-core is installed (via git clone to test/helpers/bats-core or system package)
- Given the script runs, then shellcheck is installed (or verified present)
- Given the script completes, then `make test-unit` works
- Given the script runs on macOS, then brew is used if available
- Given the script runs on Linux, then apt/dnf is used as appropriate

---

## Epic 11: Testing & CI

**Goal:** Comprehensive test coverage with bats-core and shellcheck, plus CI pipeline.

**Dependencies:** Epics 1-7 (tests written alongside or after each component)

### Story 11.1: Write Unit Tests (bats) for All Lib Functions

**As a** developer,
**I want** bats unit tests for every lib file,
**So that** I can refactor with confidence and catch regressions.

**Acceptance Criteria:**
- Given `test/unit/common.bats`, then tests cover: path resolution, XDG overrides, constant values
- Given `test/unit/display.bats`, then tests cover: each output function, color stripping when not a terminal
- Given `test/unit/scenario.bats`, then tests cover: YAML parsing, field extraction, filtering by domain/difficulty, schema validation, duplicate ID warning, Helm tag guard
- Given `test/unit/validator.bats`, then tests cover: each typed check parsing, result aggregation (using mocked kubectl where needed)
- Given `test/unit/progress.bats`, then tests cover: JSON read/write, stats calculation, streak tracking, missing field defaults
- Given `test/unit/timer.bats`, then tests cover: env output generation, time calculation
- Given `make test-unit`, then all unit tests run without requiring a kind cluster
- Given any unit test, then it completes in under 2 seconds

---

### Story 11.2: Write Integration Tests (bats) for Scenario Lifecycle

**As a** developer,
**I want** integration tests that run full scenario lifecycles against a real cluster,
**So that** I know the tool works end-to-end.

**Acceptance Criteria:**
- Given `test/integration/lifecycle.bats`, then tests cover: load scenario → setup → validate (should fail) → apply solution → validate (should pass) → cleanup
- Given `test/integration/cluster.bats`, then tests cover: create, delete, reset, health check
- Given `test/integration/validation-types.bats`, then each of the 10 typed checks is tested against real resources
- Given `test/integration/exam.bats`, then tests cover: exam start → navigate → check → submit → score → cleanup
- Given `make test-integration`, then all integration tests run against an existing kind cluster
- Given no kind cluster exists, then integration tests skip with a clear message

---

### Story 11.3: Write Schema Tests for Scenario Validation

**As a** developer,
**I want** schema tests that verify validate-scenario catches all error types,
**So that** contributor errors are caught reliably.

**Acceptance Criteria:**
- Given `test/schema/valid-scenarios/`, then at least 3 known-good YAML files exist
- Given `test/schema/invalid-scenarios/`, then known-bad YAML files exist for: missing required fields, invalid domain, invalid difficulty, missing solution, unknown validation type
- Given `test/schema/schema-validation.bats`, then each valid scenario passes and each invalid scenario fails with the expected error message

---

### Story 11.4: Set Up CI Pipeline (.github/workflows/ci.yml)

**As a** maintainer,
**I want** automated shellcheck + tests on every PR,
**So that** contributions are verified before merge.

**Acceptance Criteria:**
- Given a PR is opened, then CI runs: shellcheck + bats unit tests
- Given a push to main, then CI runs: shellcheck + bats unit + bats integration (with kind cluster in CI)
- Given any check fails, then the PR is blocked from merge
- Given CI config, then kind is installed in CI with appropriate caching
- Given CI config, then bats-core, shellcheck, yq, jq are installed

---

## Epic 12: Documentation & Polish

**Goal:** User-facing documentation, README, and contributor guide.

**Dependencies:** All other epics (documented after feature-complete)

### Story 12.1: Write README.md

**As a** potential user discovering the project,
**I want** a clear README explaining what ckad-drill is and how to get started,
**So that** I can go from discovery to first drill in under 3 minutes.

**Acceptance Criteria:**
- Given the README, then it includes: problem statement, quick install command, first drill walkthrough (3 commands), feature overview, mode descriptions
- Given the README, then it includes a demo/screenshot section (can be ASCII initially)
- Given the README, then it includes the competitive comparison table from the PRD
- Given the README, then it links to CONTRIBUTING.md for scenario contributors

---

### Story 12.2: Write CONTRIBUTING.md — Scenario Contribution Guide

**As a** community member,
**I want** clear instructions for writing and testing new scenarios,
**So that** I can contribute content to the project.

**Acceptance Criteria:**
- Given CONTRIBUTING.md, then it includes: scenario YAML schema reference, naming conventions, step-by-step guide to write a scenario, how to run `ckad-drill validate-scenario`, PR checklist
- Given a contributor follows the guide, then they can create a valid scenario YAML and validate it locally

---

## Implementation Priority (Suggested Sprint Order)

| Sprint | Epics/Stories | Milestone |
|--------|-------|-----------|
| 1 | Epic 1 (Foundation) + Epic 2 (Cluster) | Can create/manage kind cluster |
| 2 | Epic 3 (Scenarios) + Epic 4 (Validation) | Can load and validate scenarios |
| 3 | Epic 5 (CLI + Drill) + Epic 6 (Timer + Progress) | **Drill mode works end-to-end** |
| 4 | Epic 8: Stories 8.1, 8.2, 8.3 (Content Migration — first batch) | 50+ scenarios available |
| 5 | Epic 7 (Exam Mode) | Exam mode works |
| 6 | Epic 8: Stories 8.4, 8.5 + Epic 9 (Learn Mode) | All three modes working |
| 7 | Epic 10 (Validate + Install) + Epic 11 (Tests + CI) | Distribution-ready |
| 8 | Epic 12 (Docs) + Epic 8: Story 8.6 (net-new to 70+) | **V1.0 Release** |

## Dependency Graph

```
Epic 1 (Foundation)
  ├── Epic 2 (Cluster)
  │     └── Epic 4 (Validation Engine)
  ├── Epic 3 (Scenario Engine) ← depends on Epic 4 (scenario calls validator)
  │     ├── Epic 8 (Content Migration)
  │     │     └── Epic 9 (Learn Mode) ← also depends on Epic 5
  │     └── Epic 10 (Validate Tool + Install)
  └── Epic 5 (CLI + Drill Mode) ← depends on 2, 3, 4
        ├── Epic 6 (Timer + Progress) ← timer.sh & progress.sh are independent modules,
        │                                grouped here for sprint convenience
        ├── Epic 7 (Exam Mode) ← depends on 5, 6
        └── Epic 11 (Testing & CI)

Epic 12 (Docs) ← after all features
```

**Cross-component dependency notes (from architecture):**
- `validator.sh` depends on `cluster.sh` (needs live cluster)
- `scenario.sh` depends on `validator.sh` (runs checks) and `progress.sh` (records results)
- `exam.sh` depends on `scenario.sh` (manages multiple scenarios)
- `timer.sh` is independent (just PROMPT_COMMAND)
- `progress.sh` is independent (just jq on JSON file)

## Descoped from V1.0

The following items are explicitly descoped to post-V1:
- **FR-19 markdown export** — progress.json is already JSON and human-readable; a dedicated `ckad-drill export --format markdown` subcommand is deferred
- **Multi-cluster context switching** — deferred to V1.2 per architecture
- **Shell completion for subcommands** — nice-to-have, not architecturally significant
- **WSL-specific testing** — WSL support is best-effort; Linux/macOS are primary targets (NFR-04 partially met)
- **Leaderboards, scenario editor** — deferred to V2.0 per PRD

## PRD Drift Notice

The PRD (`docs/prd.md`) still references Go, Bubble Tea, client-go, and `go install`. The **architecture doc is the source of truth** — it supersedes the PRD where they differ. Key drifts:
- Language: Go → Bash
- UI: Bubble Tea TUI → printf + ANSI (subcommand model, no interactive TUI)
- K8s client: client-go → kubectl + jsonpath
- Content: Go embed → YAML files on disk
- Distribution: `go install` → curl install script
- Dependencies: "no runtime deps" → bash + kubectl + kind + Docker + yq + jq

The PRD should be updated to reflect the bash pivot before onboarding new contributors.

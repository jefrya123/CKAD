---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - docs/prd.md
workflowType: 'architecture'
lastStep: 8
status: 'complete'
completedAt: '2026-02-28'
project_name: 'ckad-drill'
user_name: 'Jeff'
date: '2026-02-28'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
20 FRs organized into: cluster management (FR-01), scenario engine (FR-02, FR-07), terminal presentation (FR-03, FR-04, FR-06, FR-12, FR-13), validation (FR-05), modes (FR-08, FR-09, FR-10), progress tracking (FR-11, FR-15, FR-19), filtering/navigation (FR-14, FR-16), and extensibility (FR-17, FR-18, FR-20). The scenario engine and validation engine are the architectural core — everything else orchestrates around them.

**Non-Functional Requirements:**
- Minimal dependencies — bash + kubectl + kind + Docker (NFR-01 adapted: no binary build needed)
- Cross-platform Linux/macOS/WSL (NFR-04) — bash-native constrains to Unix-like systems
- Validation <5s (NFR-03) — kubectl + jsonpath is fast, can parallelize checks
- Cluster creation <60s (NFR-02) — kind performance, pre-baked configs
- Progress survives upgrades (NFR-07) — versioned schema for progress.json
- 70+ scenarios at launch (NFR-06) — content pipeline and validation tooling needed
- Offline-capable after install (NFR-05) — scenarios stored locally on disk

**Scale & Complexity:**
- Primary domain: Bash CLI + kubectl validation against Kubernetes API
- Complexity level: Medium-Low (simpler than Go approach)
- Estimated architectural components: 6-7 (main script, scenario loader, validator, cluster manager, progress tracker, timer, display)

### Repo Transformation Strategy

The existing repo transforms from a static CKAD study guide into the ckad-drill bash tool. Existing content is migrated, not discarded.

**Content Inventory (migration source):**
| Asset | Count | Migration Target |
|-------|-------|-----------------|
| Scenarios (markdown) | 31 | YAML scenario format with validations |
| Domain tutorials | 5 (~5,400 lines) | Learn mode content (concept text + validated exercises) |
| Troubleshooting labs | 12 (broken + solution YAML pairs) | "Debug" scenario type (setup broken state, validate fix) |
| Domain exercises | 5 (~2,200 lines) | Additional scenario extraction |
| Quizzes | 5 + 1 mock | Exam mode question selection, quiz scenarios |
| Speed drills | 3 | Reference content in Learn mode |
| Cheatsheet | 1 | Reference content |
| CKA archive | 1 folder | Preserved for V2.0 CKA content pack |

**Estimated scenario count after migration:** 50+ before writing new content (31 scenarios + 12 troubleshooting labs + tutorial inline exercises).

### Unified Content Model

Key architectural insight: **tutorials and scenarios share the same engine.** A tutorial lesson is a scenario with additional concept text and `learn: true` metadata. This eliminates the need for separate Learn/Drill systems.

- Learn mode = scenarios with concept explanations, progressive ordering, gentler time limits
- Drill mode = scenarios without concept text, randomized, exam-style time pressure
- Exam mode = drill scenarios composed into a timed multi-question session
- Debug scenarios = setup deploys broken resources, user diagnoses and fixes, validation checks the fix

The kodekloud-inspired model: learning is integrated into the doing. Progressive validated feedback, not separate "learn first, practice later" modes.

### Technical Constraints & Dependencies

- **Hard dependencies:** Docker (for kind), kind (for cluster), kubectl (user's exam tool), bash, yq, jq
- **Optional dependency:** Helm (for Helm-specific scenarios)
- **Content on disk:** YAML scenarios + content in `~/.local/share/ckad-drill/` or repo clone
- **External content:** User/community scenarios in configurable path
- **Cluster pre-requisites:** Calico CNI, nginx ingress, metrics-server, StorageClass configured at cluster creation time
- **No network required** post-install (offline-first design)

### Cross-Cutting Concerns Identified

1. **Signal handling & cleanup** — Ctrl+C/SIGTERM must trigger namespace/resource cleanup via bash traps
2. **Cluster connectivity** — every mode needs a healthy cluster; detection, health checks, and clear error messaging
3. **Namespace isolation** — each scenario creates/destroys its own namespace; lifecycle must be atomic and reliable
4. **Timer management** — shared across Drill and Exam modes with different behaviors (single vs cumulative)
5. **Error UX** — cluster errors, validation timeouts, and setup failures need clear, actionable terminal output
6. **Content versioning** — scenarios will change across releases; upgrade path must preserve user progress
7. **Troubleshooting/debug scenarios** — validation pattern where setup deploys broken resources and validation checks the user's fix

## Starter Template Evaluation

### Technology Decision: Pure Bash

**Decision:** ckad-drill is a bash-based tool, not a Go binary. The exam is bash + kubectl. The trainer should be too.

**Rationale:**
- CKAD candidates live in bash — the tool should feel like the exam, not like a separate application
- Every validation type is a `kubectl get` + jsonpath check — client-go adds complexity for the same result
- Bash scripts are trivially contributable by the community
- No build step, no compile, no Go toolchain needed
- Ships faster, iterates faster, forks easier (FOSS priority)
- Hands-on keyboard experience is the product — not a UI

### Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Bash | Exam-native, zero build step |
| Scenario format | YAML | Parsed with yq |
| Validation | kubectl + jsonpath | Same tools the user is practicing with |
| Progress tracking | JSON file | Managed with jq |
| Timer | PROMPT_COMMAND | Countdown in bash prompt, always visible |
| Cluster | kind | Lightweight local k8s |
| Content | YAML files on disk | Downloaded with install script |
| Display | printf + ANSI colors | Clean terminal output, no TUI framework |
| Testing | bats-core + shellcheck | Bash testing standard + static analysis |

### Dependencies

| Dependency | Required | Install Story |
|-----------|----------|---------------|
| bash | Yes | Already present on Linux/macOS |
| Docker | Yes | Required by kind |
| kind | Yes | Install script handles it |
| kubectl | Yes | User needs this for exam anyway |
| yq | Yes | Install script handles it (YAML parsing) |
| jq | Yes | Install script handles it (JSON progress) |
| bats-core | Dev only | For running tests |
| shellcheck | Dev only | For linting bash scripts |

### Distribution

**Install:**
```bash
curl -sSL https://raw.githubusercontent.com/<repo>/main/scripts/install.sh | sh
```

**What install.sh does:**
1. Checks/installs: kind, yq, jq
2. Downloads ckad-drill scripts + scenarios to `~/.local/share/ckad-drill/`
3. Symlinks `ckad-drill` to `~/.local/bin/`
4. Verifies Docker is available

### Project Structure

```
ckad-drill/
├── bin/ckad-drill              # Main entry point (bash)
├── lib/
│   ├── scenario.sh             # Scenario loader (YAML parsing)
│   ├── validator.sh            # Validation engine (kubectl checks)
│   ├── cluster.sh              # Kind cluster management
│   ├── progress.sh             # Progress tracking (jq)
│   ├── timer.sh                # PROMPT_COMMAND timer
│   ├── display.sh              # Terminal output formatting
│   ├── exam.sh                 # Exam mode session management
│   └── common.sh               # Shared utilities
├── scenarios/
│   ├── domain-1/
│   ├── domain-2/
│   ├── domain-3/
│   ├── domain-4/
│   └── domain-5/
├── content/                    # Learn mode concept text
│   ├── domain-1/
│   └── ...
├── test/                       # bats test files
│   ├── validator.bats
│   ├── scenario.bats
│   └── ...
├── scripts/
│   ├── install.sh              # User install
│   ├── dev-setup.sh            # Developer setup
│   └── cluster-setup.sh        # Kind + addons
├── archive/                    # Original study guide (reference)
├── Makefile                    # Dev targets (test, lint, shellcheck, install)
├── LICENSE
└── README.md
```

### Architectural Implications

- **No build step** — the tool is the source code
- **Scenarios are the product** — the bash wrapper is thin, content is king
- **Community contributions are frictionless** — add a YAML file, write a PR
- **Validation is transparent** — users can read how checks work, it's just kubectl
- **Future option preserved** — if a richer TUI is ever needed, a Go wrapper can call the same bash validation scripts

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
1. Validation schema: Hybrid typed checks + raw command escape hatch
2. User interaction: Subcommand-based — no interactive session
3. Environment: Strict exam-match by default
4. Cluster: Fat cluster matching real exam environment

**Important Decisions (Shape Architecture):**
5. Progress schema: Additive-only, no migration logic
6. Namespace strategy: Scenario-defined with fallback
7. Validation behavior: Single check, no retry
8. Scenario validation: Full schema validation, solutions required
9. Testing: bats-core + shellcheck
10. Timer: PROMPT_COMMAND-based prompt integration
11. Exam mode: Distinct component with multi-scenario session state

**Deferred Decisions (Post-V1):**
- Multi-cluster context switching (V1.2)
- Open-ended scenarios without solutions
- Leaderboards, export formats

### ADR-01: Validation Schema — Hybrid Typed + Raw

**Decision:** Typed shortcut checks for common patterns, `command_output` escape hatch for everything else.

**Rationale:** Common checks (resource_exists, container_image, label_selector) should be easy to write. Unusual checks shouldn't be blocked by missing types.

**Typed check types (V1):**
- `resource_exists` — kubectl get, check exit code
- `resource_field` — jsonpath, compare value
- `container_count` — jsonpath on .spec.containers, count
- `container_image` — jsonpath on container by name
- `container_env` — jsonpath on container env vars
- `volume_mount` — jsonpath on volumeMounts
- `container_running` — jsonpath on containerStatuses
- `label_selector` — kubectl get with -l flag
- `resource_count` — kubectl get with selector, count results
- `command_output` — raw command + contains/matches/equals check

**Affects:** lib/validator.sh, scenario YAML schema, contributor docs

### ADR-02: User Interaction Model — Subcommand-Based

**Decision:** `ckad-drill drill` prints the task and returns. User works in the same terminal. `ckad-drill check` runs validations. Navigation via subcommands.

**Rationale:** The real exam is one terminal. No separate app pane. Training should match.

**Commands:**
- `ckad-drill start` — create/verify kind cluster
- `ckad-drill drill [--domain N] [--difficulty LEVEL]` — show a scenario
- `ckad-drill check` — run validations for current scenario
- `ckad-drill hint` — show hint
- `ckad-drill solution` — show solution
- `ckad-drill next` — next scenario
- `ckad-drill skip` — skip without checking
- `ckad-drill current` — reprint active scenario
- `ckad-drill exam [--time 120m]` — start exam session
- `ckad-drill exam next/prev/jump N/flag/list/submit` — exam navigation
- `ckad-drill status` — show progress dashboard
- `ckad-drill timer` — show remaining time
- `ckad-drill stop` — delete kind cluster
- `ckad-drill reset` — recreate cluster
- `ckad-drill validate-scenario <file>` — test a scenario YAML

**Session state:** `~/.config/ckad-drill/session.json` tracks active scenario/exam.

**Drill session:**
```json
{
  "mode": "drill",
  "scenario_id": "sc-01-multi-container-pod",
  "namespace": "web-team",
  "started_at": "2026-02-28T10:30:00Z",
  "time_limit": 180
}
```

**Exam session:**
```json
{
  "mode": "exam",
  "started_at": "2026-02-28T14:00:00Z",
  "time_limit": 7200,
  "current_question": 3,
  "questions": [
    { "scenario_id": "sc-01", "namespace": "web-team", "status": "checked", "passed": true },
    { "scenario_id": "sc-18", "namespace": "secure-ns", "status": "flagged", "checked": false },
    { "scenario_id": "sc-07", "namespace": "deploy-ns", "status": "pending", "checked": false }
  ]
}
```

**Error handling:** `ckad-drill check` errors clearly if no session is active: "No active scenario. Run `ckad-drill drill` first."

**Affects:** bin/ckad-drill, lib/scenario.sh, lib/exam.sh, lib/progress.sh

### ADR-03: Strict Exam Environment by Default

**Decision:** Every session sets up exactly what the exam provides. Nothing more.

**Environment setup on session start:**
- `alias k=kubectl`
- `source <(kubectl completion bash)`
- `export EDITOR=vim`
- No additional aliases, functions, or tools

**Rationale:** Train how you fight. If you practice with only what the exam gives you, exam day has zero surprises.

**Affects:** bin/ckad-drill (session init), docs, README

### ADR-04: Exam-Matched Cluster Configuration

**Decision:** kind cluster replicates the real CKAD exam cluster environment.

**Cluster setup includes:**
- Calico CNI (NetworkPolicy support)
- nginx ingress controller
- metrics-server (kubectl top)
- Default StorageClass (kind default)
- CoreDNS (kind default)
- Helm pre-installed (user's machine, verified by install script)
- Single cluster for V1 (multi-cluster context switching deferred to V1.2)

**Kubernetes version:** Track CKAD exam version (currently v1.35). Update kind node image when exam updates.

**Affects:** lib/cluster.sh, scripts/cluster-setup.sh

### ADR-05: Additive-Only Progress Schema

**Decision:** Progress JSON uses additive-only schema. Never remove fields, only add. Missing fields get defaults on read.

**Schema:**
```json
{
  "version": 1,
  "scenarios": {
    "sc-01-multi-container-pod": {
      "passed": true,
      "time_seconds": 145,
      "attempts": 2,
      "last_attempted": "2026-02-28T10:30:00Z"
    }
  },
  "exams": [
    {
      "date": "2026-02-28T14:00:00Z",
      "score": 72,
      "passed": true,
      "domains": { "1": 80, "2": 60, "3": 75, "4": 70, "5": 65 }
    }
  ],
  "streak": { "current": 3, "last_date": "2026-02-28" }
}
```

**Location:** `~/.config/ckad-drill/progress.json`

**Affects:** lib/progress.sh

### ADR-06: Scenario-Defined Namespaces

**Decision:** Each scenario YAML specifies its namespace(s). Fallback to `drill-<id>` if not specified.

**Rationale:** Real exam uses realistic namespace names (production, web-team, etc.). Practicing with those names builds familiarity.

**Namespace lifecycle:**
- Drill mode: create namespace on scenario start, delete on next/skip/quit
- Exam mode: all namespaces created at exam start, deleted on submit/quit

**Affects:** scenario YAML schema, lib/scenario.sh, lib/exam.sh

### ADR-07: Single-Check Validation — No Retry

**Decision:** Each validation runs once and reports what it finds. No retry, no wait-for-ready.

**Rationale:** The exam doesn't retry. Learning to verify your own work (`kubectl get pod -w`, `kubectl wait`) is part of the skill.

**Affects:** lib/validator.sh

### ADR-08: Full Schema Validation, Required Solutions

**Decision:** `ckad-drill validate-scenario` performs full schema validation and requires every scenario to have a testable solution.

**Validation flow:**
1. Parse YAML, check all required fields (id, domain, title, description, validations, solution)
2. Validate field types and value ranges (domain 1-5, time_limit > 0, valid check types)
3. Check for duplicate IDs across scenario set
4. Run setup → apply solution → run validations → cleanup
5. Report pass/fail with specific errors

**Rationale:** Catches contributor errors early. Guarantees every scenario is testable.

**Affects:** bin/ckad-drill (validate-scenario command), lib/validator.sh

### ADR-09: Testing Infrastructure — bats-core + shellcheck

**Decision:** All bash scripts tested with bats-core for functional tests and shellcheck for static analysis.

**Rationale:** Bash scripts without tests become unmaintainable. shellcheck catches quoting issues, undefined variables, and portability problems. bats-core provides structured test cases with setup/teardown.

**Makefile targets:**
```makefile
test: shellcheck bats
shellcheck:
	shellcheck bin/ckad-drill lib/*.sh
bats:
	bats test/
```

**Test categories:**
- Unit tests: individual lib functions (validator checks, YAML parsing, progress read/write)
- Integration tests: full scenario lifecycle (setup → validate → cleanup) against real kind cluster
- Schema tests: validate-scenario against known-good and known-bad YAML files

**Affects:** test/ directory, Makefile, CI pipeline

### ADR-10: Prompt-Based Timer via PROMPT_COMMAND

**Decision:** Timer is displayed in the bash prompt via PROMPT_COMMAND integration. Always visible, zero extra UI.

**Implementation:**
```bash
# On session start (via source <(ckad-drill env)):
export ORIGINAL_PS1="$PS1"
export CKAD_DRILL_END=$(date -d "+180 seconds" +%s)
export PROMPT_COMMAND='__ckad_timer'

__ckad_timer() {
  local remaining=$((CKAD_DRILL_END - $(date +%s)))
  if [ $remaining -le 0 ]; then
    PS1="[⏰ TIME UP] $ORIGINAL_PS1"
  else
    PS1="[$(printf '%02d:%02d' $((remaining/60)) $((remaining%60)))] $ORIGINAL_PS1"
  fi
}

# On session end:
export PS1="$ORIGINAL_PS1"
unset PROMPT_COMMAND
```

**User experience:**
```bash
[03:00] $ kubectl get pods
[02:56] $ vim pod.yaml
[02:12] $ kubectl apply -f pod.yaml
[01:45] $ ckad-drill check
```

**Activation:** `source <(ckad-drill env)` — optional but recommended. Without it, `ckad-drill timer` shows remaining time manually.

**Affects:** lib/timer.sh, bin/ckad-drill (env subcommand)

### ADR-11: Exam Mode as Distinct Component

**Decision:** Exam mode has its own session management component (`lib/exam.sh`) separate from drill mode.

**Rationale:** Exam and drill modes differ fundamentally:

| | Drill Mode | Exam Mode |
|---|---|---|
| Scenarios | One at a time | 15-20 simultaneous |
| Namespaces | Create/destroy per scenario | All created at exam start |
| Navigation | Linear (next/skip) | Random access (jump/prev/next/flag) |
| Timer | Per-scenario (3-8 min) | Global (2 hours) |
| Cleanup | After each scenario | After exam submission |
| Scoring | Immediate per check | Aggregate at end |

**Exam-specific commands:**
- `ckad-drill exam` — start exam (creates all namespaces, shuffles questions)
- `ckad-drill exam list` — show all questions with status (✅ ❌ 🚩 ⬜)
- `ckad-drill exam next/prev` — navigate questions
- `ckad-drill exam jump N` — jump to question N
- `ckad-drill exam flag` — flag current question for review
- `ckad-drill exam submit` — end exam, grade all questions, show results

**Affects:** lib/exam.sh, bin/ckad-drill, lib/progress.sh (exam results storage)

### Decision Impact Analysis

**Implementation Sequence:**
1. lib/common.sh + lib/display.sh (foundation)
2. lib/cluster.sh + scripts/cluster-setup.sh (cluster must exist first)
3. lib/scenario.sh + lib/validator.sh (core engine)
4. lib/timer.sh + lib/progress.sh (session support)
5. bin/ckad-drill (wire it all together — drill mode first)
6. lib/exam.sh (exam mode on top of working drill mode)
7. Scenario content migration (convert markdown → YAML)
8. test/ (bats tests for all components)

**Cross-Component Dependencies:**
- validator.sh depends on cluster.sh (needs live cluster)
- scenario.sh depends on validator.sh (runs checks) and progress.sh (records results)
- exam.sh depends on scenario.sh (manages multiple scenarios)
- timer.sh is independent (just PROMPT_COMMAND)
- progress.sh is independent (just jq on JSON file)

## Implementation Patterns & Consistency Rules

### Bash Coding Style

- `set -euo pipefail` in `bin/ckad-drill` entry point ONLY — lib files inherit, do not set it themselves
- Functions that intentionally handle non-zero exits use `|| true` or `if ! command; then` patterns
- Always brace variables: `"${variable}"`
- Always double-quote variables
- Functions: `foo() {` (no `function` keyword — POSIX-compatible)
- Local variables: `local var_name` (lower_snake_case)
- Global constants: `UPPER_SNAKE_CASE`
- Indent: 2 spaces, no tabs
- shellcheck clean — no suppressed warnings without comment justifying why

### Scenario YAML Conventions

- Field names: `snake_case`
- IDs: descriptive, no numbers (e.g., `multi-container-pod`, not `sc-01-multi-container-pod`)
- Learn mode scenarios: `learn-` prefix (e.g., `learn-pods-and-volumes`)
- Debug scenarios: `debug-` prefix (e.g., `debug-crashloop`)
- Domain: integer 1-5
- Difficulty: `easy` | `medium` | `hard`
- Time limits: integer seconds
- Namespace names: lowercase, hyphens only
- Resource refs: `kind/name` (e.g., `pod/web-logger`)
- Multi-line text: YAML `|` block scalar

### Terminal Output

- All output via functions in `lib/display.sh` — no raw echo with escape codes
- `pass()` — green ✅
- `fail()` — red ❌
- `info()` — blue
- `warn()` — yellow ⚠
- `error()` — red bold, exits 1
- `header()` — bold white + horizontal rule
- Colors disabled when stdout is not a terminal (`[[ -t 1 ]]`)

### Error Handling & Exit Codes

- 0: success
- 1: general error
- 2: cluster not running
- 3: no active session
- 4: scenario YAML parse error
- Errors to stderr
- `trap cleanup EXIT INT TERM` in entry point
- Library functions return codes, never exit directly (except `error()` in display.sh)

### File & Function Organization

- One lib file per concern — no god files
- Lib files are source-only — no top-level execution, only function definitions
- Functions prefixed by module: `validator_run_checks()`, `scenario_load()`, `cluster_ensure_running()`, `progress_record_result()`
- Private helpers: `_validator_check_resource_exists()`
- `bin/ckad-drill` is sole entry point — sources libs in explicit order, dispatches subcommands
- No circular sourcing — `common.sh` and `display.sh` are leaf dependencies

**Sourcing order in bin/ckad-drill:**
```bash
#!/usr/bin/env bash
set -euo pipefail

CKAD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${CKAD_ROOT}/lib/common.sh"
source "${CKAD_ROOT}/lib/display.sh"
source "${CKAD_ROOT}/lib/cluster.sh"
source "${CKAD_ROOT}/lib/scenario.sh"
source "${CKAD_ROOT}/lib/validator.sh"
source "${CKAD_ROOT}/lib/timer.sh"
source "${CKAD_ROOT}/lib/progress.sh"
source "${CKAD_ROOT}/lib/exam.sh"
```

- Config paths defined once in `common.sh`: `CKAD_CONFIG_DIR`, `CKAD_DATA_DIR`, `CKAD_SESSION_FILE`, `CKAD_PROGRESS_FILE`

### ckad-drill env Safety Rules

`ckad-drill env` outputs shell code sourced into the user's shell. Special rules apply:
- No `set -euo pipefail` (would break user's shell)
- Minimal — only PROMPT_COMMAND setup and timer function
- Idempotent — sourcing twice doesn't break anything
- Resettable — `ckad-drill env --reset` cleanly restores original prompt
- This is the ONLY code that runs in the user's shell context

### Testing Structure

```makefile
test: shellcheck test-unit test-integration

shellcheck:
	shellcheck bin/ckad-drill lib/*.sh

test-unit:                    # No cluster needed
	bats test/unit/           # YAML parsing, progress, display

test-integration:             # Requires running kind cluster
	bats test/integration/    # Full scenario lifecycle
```

- Unit tests: fast, no cluster — test YAML parsing, progress read/write, display formatting, schema validation
- Integration tests: require live kind cluster — test full scenario lifecycle (setup → validate → cleanup)
- Developers run `make test-unit` for quick feedback, CI runs both

### Enforcement

- shellcheck runs on every PR (CI)
- bats tests cover all lib functions
- `ckad-drill validate-scenario` enforces YAML conventions
- PR template checklist: "shellcheck passes, bats pass, follows naming conventions"

## Project Structure & Boundaries

### Complete Project Directory Structure

```
ckad-drill/
├── bin/
│   └── ckad-drill                    # Entry point — sources libs, dispatches subcommands
├── lib/
│   ├── common.sh                     # Constants, paths, XDG config/data dirs, shared utils
│   ├── display.sh                    # pass/fail/info/warn/error/header — all terminal output
│   ├── cluster.sh                    # kind create/delete/status, addon install, health check
│   ├── scenario.sh                   # YAML parsing (yq), scenario load/setup/cleanup lifecycle
│   ├── validator.sh                  # Typed checks + command_output, result formatting
│   ├── timer.sh                      # PROMPT_COMMAND timer, env subcommand output
│   ├── progress.sh                   # jq read/write on progress.json, stats calculations
│   └── exam.sh                       # Multi-scenario session, navigation, scoring, submission
├── scenarios/
│   ├── domain-1/                     # Application Design & Build
│   │   ├── multi-container-pod.yaml
│   │   ├── init-container.yaml
│   │   ├── jobs-and-cronjobs.yaml
│   │   └── ...
│   ├── domain-2/                     # Application Deployment
│   │   ├── rolling-update.yaml
│   │   ├── helm-release.yaml
│   │   └── ...
│   ├── domain-3/                     # Application Observability & Maintenance
│   │   ├── liveness-probes.yaml
│   │   ├── debug-crashloop.yaml
│   │   └── ...
│   ├── domain-4/                     # Application Environment, Configuration & Security
│   │   ├── configmap-env.yaml
│   │   ├── rbac-role.yaml
│   │   └── ...
│   └── domain-5/                     # Services & Networking
│       ├── service-clusterip.yaml
│       ├── network-policy.yaml
│       └── ...
├── content/                          # Learn mode concept text (paired with learn-* scenarios)
│   ├── domain-1/
│   │   ├── pods-and-containers.md
│   │   ├── multi-container-patterns.md
│   │   └── ...
│   ├── domain-2/
│   ├── domain-3/
│   ├── domain-4/
│   └── domain-5/
├── test/
│   ├── unit/                         # No cluster needed — fast feedback
│   │   ├── validator.bats            # Typed check parsing, result formatting
│   │   ├── scenario.bats            # YAML parsing, field extraction
│   │   ├── progress.bats            # JSON read/write, stats calc
│   │   ├── display.bats             # Output formatting, color stripping
│   │   ├── timer.bats               # Env output, time calculation
│   │   └── common.bats              # Path resolution, config defaults
│   ├── integration/                  # Requires live kind cluster
│   │   ├── lifecycle.bats           # Full setup → validate → cleanup cycle
│   │   ├── cluster.bats             # Cluster create/delete/health
│   │   ├── exam.bats                # Multi-scenario session lifecycle
│   │   └── validation-types.bats    # Each typed check against real resources
│   ├── schema/                       # Scenario YAML validation
│   │   ├── valid-scenarios/          # Known-good YAML for positive tests
│   │   ├── invalid-scenarios/        # Known-bad YAML for error detection
│   │   └── schema-validation.bats
│   └── helpers/
│       ├── test-helper.bash          # bats setup/teardown, test cluster name
│       └── fixtures/                 # Test YAML snippets, mock progress files
├── scripts/
│   ├── install.sh                    # User install (kind, yq, jq, symlink)
│   ├── dev-setup.sh                  # Developer setup (bats-core, shellcheck)
│   └── cluster-setup.sh             # Kind config + Calico + ingress + metrics-server
├── archive/                          # Original study guide content (reference for migration)
├── Makefile                          # test, shellcheck, test-unit, test-integration, install
├── LICENSE                           # MIT
├── README.md
└── .github/
    └── workflows/
        └── ci.yml                    # shellcheck + bats-unit on PR, bats-integration on merge
```

### Architectural Boundaries

**CLI Boundary (bin/ckad-drill):**
The single entry point. All user-facing commands enter here. It sources libs, parses subcommands, and dispatches. No business logic lives in bin/ — it's pure routing.

**Validation Boundary (lib/validator.sh):**
The only component that talks to the Kubernetes API (via kubectl). All cluster queries flow through validator functions. Scenario.sh calls validator; validator calls kubectl. Nothing else touches the cluster except cluster.sh for lifecycle management.

**State Boundaries:**

| State | Location | Owner |
|-------|----------|-------|
| Session (active scenario/exam) | `~/.config/ckad-drill/session.json` | scenario.sh, exam.sh |
| Progress (historical results) | `~/.config/ckad-drill/progress.json` | progress.sh |
| Cluster state | kind cluster `ckad-drill` | cluster.sh |
| Content (scenarios) | `scenarios/` directory | scenario.sh (read-only) |
| Learn content | `content/` directory | scenario.sh (read-only) |

**Shell Boundary (timer.sh / env subcommand):**
Only `ckad-drill env` outputs code that runs in the user's shell. Everything else runs in ckad-drill's own process. This boundary is critical — env output must never include `set -euo pipefail` or anything that could break the user's shell.

### Requirements to Structure Mapping

**Cluster Management (FR-01):**
- `lib/cluster.sh` — create, delete, health check, addon install
- `scripts/cluster-setup.sh` — kind YAML config + post-create addon setup

**Scenario Engine (FR-02, FR-07):**
- `lib/scenario.sh` — load YAML, run setup, run cleanup, lifecycle management
- `scenarios/domain-*/` — all scenario YAML files

**Terminal Presentation (FR-03, FR-04, FR-06, FR-12, FR-13):**
- `lib/display.sh` — all formatted output (pass/fail/info/header)
- `lib/timer.sh` — countdown display via PROMPT_COMMAND
- `bin/ckad-drill` — subcommand dispatch for hint, solution, current

**Validation (FR-05):**
- `lib/validator.sh` — all 10 typed checks + command_output escape hatch

**Modes (FR-08, FR-09, FR-10):**
- `lib/scenario.sh` — drill mode (single scenario lifecycle)
- `lib/exam.sh` — exam mode (multi-scenario session, navigation, scoring)
- `content/domain-*/` + learn-prefixed scenarios — learn mode content

**Progress & Stats (FR-11, FR-15, FR-19):**
- `lib/progress.sh` — record results, calculate per-domain stats, recommend weak areas

**Filtering & Navigation (FR-14, FR-16):**
- `lib/scenario.sh` — domain/difficulty filtering, scenario selection
- `lib/exam.sh` — question flagging, jump/prev/next navigation

**Extensibility (FR-17, FR-18, FR-20):**
- `lib/scenario.sh` — external scenario path loading
- `bin/ckad-drill` validate-scenario — schema validation for contributors
- Helm scenarios live alongside other scenarios with `tags: [helm]`

### Cross-Cutting Concerns Mapping

| Concern | Where It Lives |
|---------|---------------|
| Signal handling / cleanup | `bin/ckad-drill` — `trap cleanup EXIT INT TERM` |
| Error codes (0-4) | `lib/common.sh` — constants; `lib/display.sh` — `error()` exits |
| XDG path resolution | `lib/common.sh` — `CKAD_CONFIG_DIR`, `CKAD_DATA_DIR` |
| Color/no-color detection | `lib/display.sh` — `[[ -t 1 ]]` check |
| Namespace lifecycle | `lib/scenario.sh` (drill), `lib/exam.sh` (exam batch create/delete) |

### Integration Points & Data Flow

**Drill Mode Flow:**
```
bin/ckad-drill drill
  → scenario.sh:scenario_select()        # Filter + pick scenario
  → scenario.sh:scenario_load()          # yq parse YAML
  → scenario.sh:scenario_setup()         # kubectl apply setup commands
  → display.sh:header() + scenario text  # Show task to user
  → timer.sh:timer_start()              # Set PROMPT_COMMAND deadline
  ─── user works in terminal ───
bin/ckad-drill check
  → validator.sh:validator_run_checks()  # kubectl checks against cluster
  → display.sh:pass()/fail()            # Show results
  → progress.sh:progress_record()       # Write to progress.json
bin/ckad-drill next
  → scenario.sh:scenario_cleanup()      # kubectl delete namespace
  → loop back to scenario_select()
```

**Exam Mode Flow:**
```
bin/ckad-drill exam
  → exam.sh:exam_start()                # Select 15-20 scenarios
  → scenario.sh:scenario_setup() × N    # Create all namespaces at once
  → timer.sh:timer_start(7200)          # 2-hour global timer
  → exam.sh:exam_show_question()        # Display current question
  ─── user works ───
bin/ckad-drill exam next/prev/jump/flag  # Navigate questions
bin/ckad-drill check                     # Check current question only
bin/ckad-drill exam submit
  → validator.sh × N                    # Grade all questions
  → exam.sh:exam_score()               # Calculate per-domain scores
  → progress.sh:progress_record_exam() # Write exam results
  → scenario.sh:scenario_cleanup() × N # Delete all namespaces
```

### Development Workflow Integration

**Quick feedback loop:**
```bash
make shellcheck        # Static analysis — seconds
make test-unit         # bats unit tests — seconds, no cluster
```

**Full verification:**
```bash
make test              # shellcheck + unit + integration (needs cluster)
```

**CI pipeline (.github/workflows/ci.yml):**
- On PR: shellcheck + test-unit (fast, no cluster needed)
- On merge to main: shellcheck + test-unit + test-integration (spins up kind in CI)

**Content development:**
```bash
ckad-drill validate-scenario scenarios/domain-1/new-scenario.yaml
# Runs: parse → schema check → setup → apply solution → run validations → cleanup
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All technology choices (bash, yq, jq, kubectl, kind, bats-core, shellcheck) are standard Unix tools with no version conflicts. YAML scenarios parsed by yq, progress JSON managed by jq — right tool for each format. PROMPT_COMMAND timer works in the same shell context the user practices in.

**Pattern Consistency:**
Naming conventions are uniform: `module_function_name()` for public, `_module_helper()` for private. All terminal output funneled through `display.sh`. Error codes (0-4) defined once in `common.sh`. YAML field names consistently `snake_case`, scenario IDs consistently hyphenated. No contradictions between any of the 11 ADRs.

**Structure Alignment:**
One lib file per concern matches one bats test file per concern. `bin/ckad-drill` is pure dispatch — ADR-02's subcommand model maps directly to case/esac. State boundaries (session.json, progress.json, cluster) each owned by exactly one lib file. Shell boundary (`ckad-drill env`) is explicitly isolated with safety rules.

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**

| FR | Status | Covered By |
|----|--------|------------|
| FR-01 Cluster management | ✅ | lib/cluster.sh, scripts/cluster-setup.sh, ADR-04 |
| FR-02 Scenario loading | ✅ | lib/scenario.sh, yq parsing |
| FR-03 Display task | ✅ | lib/display.sh, bin/ckad-drill |
| FR-04 Timer | ✅ | lib/timer.sh, ADR-10 |
| FR-05 Validation | ✅ | lib/validator.sh, ADR-01 (10 typed checks) |
| FR-06 Pass/fail feedback | ✅ | lib/display.sh pass()/fail() |
| FR-07 Cleanup | ✅ | lib/scenario.sh, ADR-06 namespace lifecycle |
| FR-08 Drill mode | ✅ | lib/scenario.sh, ADR-02 |
| FR-09 Exam mode | ✅ | lib/exam.sh, ADR-11 |
| FR-10 Learn mode | ✅ | content/ + learn-* scenarios, unified content model |
| FR-11 Progress tracking | ✅ | lib/progress.sh, ADR-05 |
| FR-12 Hints | ✅ | bin/ckad-drill hint subcommand |
| FR-13 Solutions | ✅ | bin/ckad-drill solution subcommand |
| FR-14 Domain/difficulty filter | ✅ | lib/scenario.sh filtering |
| FR-15 Weak area recommendations | ✅ | lib/progress.sh stats calculation |
| FR-16 Exam navigation/flagging | ✅ | lib/exam.sh, ADR-11 |
| FR-17 External scenarios | ✅ | lib/scenario.sh external path loading |
| FR-18 Scenario validation tool | ✅ | validate-scenario subcommand, ADR-08 |
| FR-19 Export results | ✅ | lib/progress.sh (progress.json is already JSON) |
| FR-20 Helm scenarios | ✅ | scenarios with `tags: [helm]`, Helm in cluster setup |

All 20 FRs covered. No gaps.

**Non-Functional Requirements Coverage:**

| NFR | Status | How Addressed |
|-----|--------|---------------|
| NFR-01 Minimal dependencies | ✅ | bash + kubectl + kind + Docker + yq + jq (all standard tools) |
| NFR-02 Cluster <60s | ✅ | kind with pre-baked config, ADR-04 |
| NFR-03 Validation <5s | ✅ | kubectl + jsonpath is fast, ADR-07 single-check no retry |
| NFR-04 Linux/macOS/WSL | ✅ | Pure bash, shellcheck for portability |
| NFR-05 Offline post-install | ✅ | Scenarios on disk, no network calls |
| NFR-06 70+ scenarios | ✅ | 50+ from migration + new content pipeline |
| NFR-07 Progress survives upgrades | ✅ | ADR-05 additive-only schema |

All 7 NFRs covered.

### Implementation Readiness Validation ✅

**Decision Completeness:**
All 11 ADRs include rationale, what's affected, and concrete examples. Session JSON schema defined with examples for both drill and exam modes. Progress JSON schema defined with version field. Validation check types enumerated with expected parameters. Subcommands fully listed with behavior described.

**Structure Completeness:**
Every lib file has a defined responsibility and module prefix. Sourcing order explicitly specified. Test directory mirrors lib structure. CI pipeline defined with PR vs merge triggers.

**Pattern Completeness:**
Bash coding style fully specified (indentation, quoting, variable naming, function style). Error handling patterns defined (exit codes, stderr, trap, library return-not-exit rule). Scenario YAML conventions documented (field names, ID conventions, prefixes). Display function list complete with color detection rules.

### Gap Analysis Results

**No critical gaps found.**

**Important gaps (addressable post-V1):**

1. **Learn mode flow** — The unified content model is well-conceived, but the exact UX for stepping through concept text + inline exercises within a learn session isn't fully specified (e.g., does `ckad-drill learn --domain 1` show a lesson list? sequential progression?). The architecture supports it — this is a detailed design question for the first learn-mode implementation story.

2. **Scenario ID uniqueness at runtime** — ADR-08 validates uniqueness via `validate-scenario`, but the architecture doesn't specify how `scenario.sh` handles duplicate IDs if found at runtime (e.g., user adds external scenario with same ID). Recommendation: first-loaded wins, with a warning via `display.sh:warn()`.

3. **PRD drift** — The PRD still references Go, Bubble Tea, client-go, and `go install`. It should be updated to reflect the bash pivot. The architecture doc is now the source of truth; the PRD needs a pass to align.

**Nice-to-have gaps:**
- `CONTRIBUTING.md` template (scenario contribution guide) — create during first content migration
- Shell completion for subcommands — trivial to add later, not architecturally significant

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped
- [x] Content migration strategy defined

**✅ Architectural Decisions**

- [x] 11 ADRs documented with rationale and impact
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed (single-check, fast validation)

**✅ Implementation Patterns**

- [x] Bash coding style established
- [x] Naming conventions for functions, variables, files, scenarios
- [x] Error handling and exit codes defined
- [x] Display/output patterns specified
- [x] Testing patterns defined (unit vs integration vs schema)

**✅ Project Structure**

- [x] Complete directory structure defined
- [x] Component boundaries established (CLI, validation, state, shell)
- [x] Integration points mapped (drill flow, exam flow)
- [x] All 20 FRs mapped to specific files
- [x] Cross-cutting concerns mapped to locations

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Extreme simplicity — bash scripts with clear module boundaries, no abstraction overhead
- Unified content model eliminates duplicate systems for learn/drill/exam
- Every ADR maps directly to one or two lib files — no ambiguity about where code lives
- Testing strategy is practical — fast unit tests for development, integration tests for CI
- Additive-only progress schema eliminates migration complexity

**Areas for Future Enhancement:**
- Learn mode detailed UX (lesson navigation, progression tracking within a domain)
- Multi-cluster context switching (explicitly deferred to V1.2)
- Shell completion for subcommands
- PRD update to reflect bash pivot

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all 11 ADRs exactly as documented
- Use module-prefixed function naming consistently (`module_action()`)
- Respect the shell boundary — only `ckad-drill env` outputs user-shell code
- All terminal output through `display.sh` functions
- All cluster interaction through `validator.sh` (queries) and `cluster.sh` (lifecycle)
- Test with shellcheck + bats before completing any component

**First Implementation Priority:**

1. `lib/common.sh` + `lib/display.sh` (foundation, no dependencies)
2. `lib/cluster.sh` + `scripts/cluster-setup.sh` (cluster must exist for everything else)
3. `lib/scenario.sh` + `lib/validator.sh` (core engine)
4. `bin/ckad-drill` (wire together with drill subcommands)
5. First batch of scenario YAML files for testing

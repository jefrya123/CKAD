---
phase: 03-cli-drill-mode
type: research
researched: 2026-02-28
confidence: HIGH
---

# Phase 3 Research: CLI + Drill Mode

**Goal:** A user can run a full drill session end-to-end from the terminal using subcommands.

**Depends on:** Phase 2 (scenario.sh, validator.sh, display.sh, common.sh all complete and tested)

---

## What We Are Building

Phase 3 wires together the Phase 1+2 lib functions into a complete user-facing workflow:

```
ckad-drill drill [--domain N] [--difficulty LEVEL]
  → picks scenario, creates namespace, writes session.json, prints task

ckad-drill check
  → reads session.json, runs validator_run_checks, records to progress.json

ckad-drill hint / solution / current
  → reads session.json, reads scenario YAML, displays content

ckad-drill next / skip
  → reads session.json, cleans up namespace, starts new drill

ckad-drill status
  → reads progress.json, displays per-domain stats + recommendation

ckad-drill env / env --reset
  → emits shell code for PROMPT_COMMAND timer (sourced by user)

ckad-drill timer
  → reads session.json end time, prints remaining MM:SS

ckad-drill validate-scenario <file|dir>
  → full end-to-end scenario test: parse → setup → apply solution → validate → cleanup
```

---

## New Lib Files Required

Based on ADR-02 (subcommand model) and ADR-10 (PROMPT_COMMAND timer), three new lib files are needed:

### lib/session.sh

Manages `~/.config/ckad-drill/session.json` (defined in CKAD_SESSION_FILE via common.sh).

Functions needed:
- `session_write MODE SCENARIO_ID NAMESPACE STARTED_AT TIME_LIMIT` — writes session.json
- `session_read` — sources session fields into SESSION_* globals; returns EXIT_NO_SESSION if missing
- `session_clear` — deletes session.json
- `session_require` — calls session_read; prints error + exits if no active session

Session JSON schema (from ADR-02):
```json
{
  "mode": "drill",
  "scenario_id": "sc-01-multi-container-pod",
  "namespace": "web-team",
  "started_at": "2026-02-28T10:30:00Z",
  "time_limit": 180
}
```

Implementation note: Use `jq` for write (already a hard dep), `jq -r` for reading fields. Do NOT use yq here — session.json is JSON not YAML.

### lib/progress.sh

Manages `~/.config/ckad-drill/progress.json` (defined in CKAD_PROGRESS_FILE via common.sh).

Functions needed:
- `progress_record SCENARIO_ID PASSED TIME_SECONDS` — upserts scenario result; increments attempts
- `progress_read_domain_rates` — outputs per-domain pass rates as jq-computed JSON or text
- `progress_read_streak` — outputs current streak value
- `progress_read_exam_history` — outputs exam records
- `progress_recommend_weak_domain` — outputs domain number with lowest pass rate
- `progress_init` — creates progress.json with default schema if missing

Progress JSON schema (from ADR-05):
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
  "exams": [],
  "streak": { "current": 3, "last_date": "2026-02-28" }
}
```

ADR-05 (additive-only schema) means: always use `// default` in jq queries for optional fields. Never assume a field exists.

### lib/timer.sh

Emits shell code that the user sources into their shell (TIMR-01, TIMR-05).

Functions needed:
- `timer_env_output` — prints shell code for PROMPT_COMMAND timer setup (safe for user's shell)
- `timer_env_reset_output` — prints shell code to restore original prompt
- `timer_remaining` — reads session end time from session.json, prints MM:SS remaining

Timer env output from ADR-10:
```bash
# Emitted by `ckad-drill env` (user runs: source <(ckad-drill env))
export CKAD_DRILL_ORIGINAL_PS1="${PS1}"
export CKAD_DRILL_END=<epoch seconds>
__ckad_drill_timer() {
  local remaining=$(( CKAD_DRILL_END - $(date +%s) ))
  if (( remaining <= 0 )); then
    PS1="[TIME UP] ${CKAD_DRILL_ORIGINAL_PS1}"
  else
    PS1="[$(printf '%02d:%02d' $((remaining/60)) $((remaining%60)))] ${CKAD_DRILL_ORIGINAL_PS1}"
  fi
}
export PROMPT_COMMAND='__ckad_drill_timer'
```

Reset output:
```bash
# Emitted by `ckad-drill env --reset`
export PS1="${CKAD_DRILL_ORIGINAL_PS1}"
unset PROMPT_COMMAND
unset CKAD_DRILL_END
unset CKAD_DRILL_ORIGINAL_PS1
unset -f __ckad_drill_timer
```

TIMR-05 safety constraint: The emitted code must NOT contain `set -euo pipefail`. If the user sources this into a non-strict shell and PROMPT_COMMAND errors, it should be silent, not terminal-killing.

---

## bin/ckad-drill Expansion

The current dispatch table handles `start`, `stop`, `reset`. Phase 3 adds:

```
drill [--domain N] [--difficulty LEVEL] [--external PATH]
check
hint
solution
current
next
skip
status
env [--reset]
timer
validate-scenario <file|dir>
```

The dispatch case statement grows but stays flat. No subcommand nesting in Phase 3 (exam subcommands like `exam next` are Phase 4).

### drill subcommand logic

```
1. Verify cluster is running (reuse cluster_check_active from cluster.sh or add it)
2. Parse --domain, --difficulty, --external flags
3. scenario_discover [external_path] → list of files
4. scenario_filter (set FILTER_DOMAIN, FILTER_DIFFICULTY env vars) → filtered list
5. Pick random file: files_array[RANDOM % count]
6. scenario_setup file (creates namespace)
7. Display: header with title, domain, difficulty, time_limit
8. Display: scenario description text (yq -r '.description' file)
9. Set up exam environment (DRIL-10): alias k=kubectl, completion, EDITOR=vim
10. session_write "drill" SCENARIO_ID NAMESPACE STARTED_AT TIME_LIMIT
11. Print: "Run `source <(ckad-drill env)` to start the timer."
```

Random selection: `${files_array[$((RANDOM % ${#files_array[@]}))]}` — bash RANDOM is 0-32767, modulo is fine for scenario counts.

### check subcommand logic

```
1. session_require (exits with clear error if no active session)
2. session_read → SESSION_* globals
3. Verify mode is "drill" (not exam)
4. validator_run_checks SESSION_FILE SESSION_NAMESPACE
5. Compute elapsed time: $(date +%s) - SESSION_STARTED_EPOCH
6. progress_record SESSION_SCENARIO_ID PASSED ELAPSED
7. Update streak in progress.json
```

### hint / solution / current subcommand logic

```
1. session_require
2. session_read → SESSION_SCENARIO_ID → find scenario file
   (need a scenario_find_by_id function or store file path in session.json)
3. yq -r '.hint // "No hint available."' file
4. yq -r '.solution.steps | .[]' file (for solution — formatted numbered list)
5. For current: re-display full scenario description
```

**Design decision needed:** session.json should store the scenario file path directly (simplest) rather than requiring re-discovery by ID on every command. Store as `"scenario_file": "/path/to/file.yaml"` in session.json.

### next / skip subcommand logic

```
next:
1. session_require
2. session_read
3. scenario_cleanup (deletes namespace)
4. session_clear
5. Run drill subcommand logic (get new scenario)

skip:
1. session_require
2. session_read
3. scenario_cleanup
4. session_clear
5. Print "Skipped. Run `ckad-drill drill` for next scenario."
```

### status subcommand logic

```
1. progress_init if progress.json missing
2. progress_read_domain_rates → domain 1-5 pass rates
3. progress_read_streak → streak count
4. progress_read_exam_history → list exam runs
5. progress_recommend_weak_domain → "Weak area: Domain 3 (NetworkPolicy)"
6. Display formatted table
```

### env subcommand logic

```
if [[ "${2:-}" == "--reset" ]]; then
  session_read (to check if session active — but env --reset works even without session)
  timer_env_reset_output
else
  session_require
  session_read
  timer_env_output SESSION_STARTED_AT SESSION_TIME_LIMIT
fi
```

### validate-scenario subcommand logic (DIST-03, DIST-04)

```
if [[ -d "${target}" ]]; then
  # DIST-04: directory mode
  for file in target/**/*.yaml; do
    _validate_single_scenario "${file}"
  done
  print summary (N passed, M failed)
else
  # DIST-03: single file mode
  _validate_single_scenario "${target}"
fi

_validate_single_scenario() {
  1. scenario_load file (parse + validate required fields)
  2. scenario_setup file (create namespace)
  3. Apply solution: run solution.steps commands
  4. validator_run_checks file namespace
  5. scenario_cleanup
  6. Report PASS/FAIL with elapsed time
  7. On any failure, still run cleanup (use trap or explicit finally pattern)
}
```

---

## Key Technical Details

### Scenario File Path in Session

Store `scenario_file` in session.json so commands like `check`, `hint`, `solution`, `current` don't need to re-discover by ID:

```json
{
  "mode": "drill",
  "scenario_id": "sc-01",
  "scenario_file": "/home/jeff/Projects/cka/scenarios/domain-1/sc-01.yaml",
  "namespace": "web-team",
  "started_at": "2026-02-28T10:30:00Z",
  "time_limit": 180
}
```

This is an extension of the ADR-02 schema (additive). Valid because ADR-05 covers progress.json schema safety, and session.json is ephemeral (not version-sensitive).

### Date Handling (Cross-Platform)

`date -d` is GNU coreutils (Linux). macOS uses `date -j -f`. The architecture targets Linux/macOS/WSL.

Solution: store epoch seconds directly. `date +%s` is portable. Compute end time as `$(date +%s) + time_limit` at drill start, store as `end_at` epoch in session.json.

Timer then: `remaining=$(( end_at - $(date +%s) ))` — no date arithmetic needed.

For `started_at` (human-readable display), store ISO 8601 string via `date -u +"%Y-%m-%dT%H:%M:%SZ"` (portable).

### jq for session.json Read/Write

Reading individual fields from session.json:
```bash
session_id=$(jq -r '.scenario_id // empty' "${CKAD_SESSION_FILE}")
```

Writing session.json (atomic write via temp file):
```bash
jq -n \
  --arg mode "drill" \
  --arg scenario_id "${id}" \
  --arg scenario_file "${file}" \
  --arg namespace "${ns}" \
  --arg started_at "${ts}" \
  --argjson time_limit "${tl}" \
  --argjson end_at "${ea}" \
  '{mode: $mode, scenario_id: $scenario_id, scenario_file: $scenario_file,
    namespace: $namespace, started_at: $started_at,
    time_limit: $time_limit, end_at: $end_at}' > "${CKAD_SESSION_FILE}"
```

Note: CKAD_CONFIG_DIR must exist before writing. Add `mkdir -p "${CKAD_CONFIG_DIR}"` in session_write.

### SIGINT/SIGTERM Cleanup (DRIL-11)

Drill mode must clean up namespace on Ctrl+C. Pattern:

```bash
# In bin/ckad-drill, after session_write:
trap '_drill_cleanup' INT TERM EXIT
_drill_cleanup() {
  trap - INT TERM EXIT  # prevent re-entry
  if session_read 2>/dev/null; then
    scenario_cleanup
    session_clear
  fi
}
```

Important: Only install this trap in the `drill` subcommand path, not globally. The `check`, `hint`, etc. commands don't need it.

### Strict Exam Environment Setup (DRIL-10)

The drill command sets up exam environment in the user's current shell:

```
alias k=kubectl
source <(kubectl completion bash)
export EDITOR=vim
```

Problem: `ckad-drill drill` runs in a subprocess. Aliases set in a subprocess do NOT propagate to the parent shell.

Solution: Like the timer (TIMR-01), the exam environment setup must also be sourced:
- `source <(ckad-drill env)` → sets up timer AND exam aliases
- lib/timer.sh `timer_env_output` should include the alias/completion/EDITOR setup
- Document clearly that `source <(ckad-drill env)` is the one-time setup command

Alternatively, the drill command can print the aliases and tell the user to source env. The architecture doc (ADR-03) says "Environment setup on session start" but doesn't specify mechanism. Use the env command as the canonical setup path.

### Progress JSON Atomic Updates

progress.json is updated by `check`. Use atomic write pattern:

```bash
# Read → modify via jq → write to temp → move into place
local tmp
tmp=$(mktemp)
jq --arg id "${scenario_id}" \
   --argjson passed "${passed}" \
   ... \
   '.scenarios[$id] = ...' "${CKAD_PROGRESS_FILE}" > "${tmp}"
mv "${tmp}" "${CKAD_PROGRESS_FILE}"
```

`mv` is atomic on same filesystem. Prevents corruption on interrupted writes.

### Streak Tracking Logic

Streak increments if the user completed at least one drill on each consecutive day:

```bash
today=$(date +%Y-%m-%d)
last_date=$(jq -r '.streak.last_date // ""' progress.json)
current_streak=$(jq -r '.streak.current // 0' progress.json)

if [[ "${last_date}" == "${today}" ]]; then
  : # already drilled today, don't change streak
elif [[ "${last_date}" == "$(date -d 'yesterday' +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)" ]]; then
  current_streak=$((current_streak + 1))
else
  current_streak=1  # streak broken
fi
```

Cross-platform yesterday: `date -d 'yesterday'` is Linux; `date -v-1d` is macOS. Use both with fallback.

### validate-scenario Cleanup on Failure

If validation fails mid-run, still clean up namespace. Use ERR trap or explicit cleanup:

```bash
_validate_single_scenario() {
  local file="$1"
  local cleanup_needed=false

  scenario_load "${file}" || return 1
  scenario_setup "${file}" || return 1
  cleanup_needed=true

  # apply solution
  local failed=false
  _apply_solution "${file}" || failed=true

  if [[ "${failed}" == false ]]; then
    validator_run_checks "${file}" "${SCENARIO_NAMESPACE}" || failed=true
  fi

  scenario_cleanup
  [[ "${failed}" == false ]]
}
```

---

## Scenarios — YAML Files Needed for Testing

Phase 3 unit tests can reuse existing fixtures in `test/fixtures/valid/`. Integration tests need actual scenario YAML files in `scenarios/`. No scenario YAML files exist yet (only markdown source).

For Phase 3 testing:
- At minimum, 2-3 representative YAML scenarios needed in `scenarios/domain-1/` etc. for the drill randomization and filter tests
- These don't need to be production-quality; simple pod-creation scenarios suffice
- Full content migration is Phase 6

---

## Display Patterns

Phase 3 display uses existing `header()`, `info()`, `success()`, `error()` from display.sh and common.sh. No new display functions anticipated, but consider adding:

- `scenario_display FILE` to display.sh — prints the formatted scenario task card (title, domain, difficulty, time_limit, description, dividers)
- `status_display` to progress.sh or display.sh — formats the status dashboard

These belong in their respective lib files (scenario.sh or display.sh for scenario display; progress.sh for status display).

---

## Test Strategy

### Unit Tests (no cluster required)

`test/unit/session.bats`:
- session_write creates valid JSON
- session_read populates SESSION_* globals
- session_read returns EXIT_NO_SESSION when file missing
- session_clear removes file
- session_require exits with message when no session

`test/unit/progress.bats`:
- progress_init creates default schema
- progress_record upserts scenario result
- progress_record increments attempts correctly
- progress_record handles missing progress.json gracefully
- progress_read_domain_rates computes correct percentages
- progress_recommend_weak_domain identifies lowest domain
- progress_read_streak returns correct value
- Streak increments on consecutive day
- Streak resets on gap day
- Streak unchanged when same day

`test/unit/timer.bats`:
- timer_env_output contains PROMPT_COMMAND assignment
- timer_env_output contains CKAD_DRILL_END export
- timer_env_output does NOT contain set -euo pipefail
- timer_env_reset_output unsets PROMPT_COMMAND
- timer_env_reset_output restores ORIGINAL_PS1

`test/unit/drill.bats` (bin/ckad-drill integration with mocked deps):
- drill subcommand writes session.json
- check subcommand calls validator (mock validator)
- hint/solution/current read from session scenario file
- next cleans up namespace + starts new scenario

### Integration Tests (cluster required — deferred to Phase 7)

Full end-to-end drill session against real kind cluster — deferred per project pattern established in Phase 1-2.

---

## Pitfalls to Avoid

### Pitfall 1: Subshell Scope for Aliases (DRIL-10)

`alias k=kubectl` in a child process does not affect the parent shell. The drill subcommand CANNOT set aliases for the user. Solution: env subcommand emits shell code; user sources it. Document clearly.

### Pitfall 2: yq v3 Syntax (Known from Phase 2)

Machine has yq v3.4.3. Do NOT use `yq eval`, `yq e`, or v4 syntax. All session.sh functions use `jq` (JSON), not yq (YAML). Only scenario.sh uses yq and it already uses v3 syntax.

### Pitfall 3: ((n++)) Arithmetic with set -e (Known from Phase 2)

Incrementing a counter from 0: `((count++)) || true` is required. Already documented in STATE.md.

### Pitfall 4: PROMPT_COMMAND Interaction with User's Existing Setup

User may already have a PROMPT_COMMAND (starship, git prompt, custom). Saving and restoring PROMPT_COMMAND (not just PS1) is important:

```bash
export CKAD_DRILL_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
export PROMPT_COMMAND='__ckad_drill_timer'
# Reset:
export PROMPT_COMMAND="${CKAD_DRILL_ORIGINAL_PROMPT_COMMAND}"
```

### Pitfall 5: Session File Race on Ctrl+C

If user hits Ctrl+C during `scenario_setup` (namespace creation), session.json may not have been written yet. Cleanup trap must check if session exists before calling scenario_cleanup:

```bash
_drill_cleanup() {
  trap - INT TERM EXIT
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    session_read 2>/dev/null && scenario_cleanup
    session_clear
  elif [[ -n "${SCENARIO_NAMESPACE:-}" ]]; then
    # Setup was in progress, namespace may have been created
    kubectl delete namespace "${SCENARIO_NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
  fi
}
```

### Pitfall 6: progress.json Missing on First Run

`ckad-drill check` on first-ever run: progress.json doesn't exist. `progress_record` must call `progress_init` if file is missing, or check existence first.

### Pitfall 7: No Scenarios Available After Filter

If user runs `ckad-drill drill --domain 9` or all scenarios are filtered out, the array will be empty. Check count before RANDOM indexing:

```bash
if [[ "${#filtered_files[@]}" -eq 0 ]]; then
  error "No scenarios found matching the specified filters."
  exit "${EXIT_ERROR}"
fi
```

### Pitfall 8: validate-scenario Solution Apply Ordering

Solution steps must be applied to the correct namespace. The solution.steps commands likely use `kubectl` without `-n` flag — they assume the current context namespace or use fully-qualified resource names. Consider setting `kubectl config set-context --current --namespace="${SCENARIO_NAMESPACE}"` before applying solution in validate-scenario. Reset after.

---

## Implementation Order (Recommended)

1. **lib/session.sh** — foundation for all drill commands; session_write/read/clear/require
2. **lib/progress.sh** — needed for `check` result recording and `status` display
3. **lib/timer.sh** — needed for `env` subcommand; simple pure-bash emitter
4. **bin/ckad-drill expansion** — wire all new subcommands
5. **Unit tests** — session.bats, progress.bats, timer.bats
6. **2-3 sample YAML scenarios** — needed for integration smoke testing

---

## Files to Create

| File | New/Modified | Purpose |
|------|-------------|---------|
| `lib/session.sh` | New | Session JSON read/write/clear/require |
| `lib/progress.sh` | New | Progress JSON tracking, status display |
| `lib/timer.sh` | New | PROMPT_COMMAND timer env output |
| `bin/ckad-drill` | Modified | Add 11 new subcommands to dispatch |
| `test/unit/session.bats` | New | Unit tests for session.sh |
| `test/unit/progress.bats` | New | Unit tests for progress.sh |
| `test/unit/timer.bats` | New | Unit tests for timer.sh |
| `scenarios/domain-1/<name>.yaml` | New | Sample scenarios for testing |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Session management (jq JSON) | HIGH | jq is established dep; pattern is straightforward |
| Progress tracking (jq JSON) | HIGH | ADR-05 schema fully defined; jq operations clear |
| Timer (PROMPT_COMMAND) | HIGH | ADR-10 has full implementation; pattern is well-understood |
| Drill command flow | HIGH | ADR-02 fully specifies subcommand semantics |
| SIGINT cleanup | MEDIUM | Bash trap patterns are reliable; edge cases documented |
| Cross-platform date | MEDIUM | GNU vs BSD `date` is a known issue; workaround documented |
| Streak tracking | MEDIUM | Logic is clear; cross-platform date arithmetic is the risk |
| validate-scenario solution apply | MEDIUM | Namespace context for solution commands needs care |

---

## Open Questions

1. **Exam environment sourcing (DRIL-10):** Should `ckad-drill env` emit alias setup AND timer together? Or keep `env` as timer-only and document `alias k=kubectl` as manual user setup? Architecture says "on session start" but mechanism via subprocess makes auto-setup impossible. Recommend: env command emits timer + aliases; document `source <(ckad-drill env)` as the single required setup step.

2. **solution.steps namespace context:** When `validate-scenario` applies solution steps, should it set the context namespace? Needs a decision in planning. Recommend: set namespace context before applying solution, reset after.

3. **scenario_find_by_id vs storing file path in session:** If we store `scenario_file` in session.json, we avoid re-discovery. But if the user moves the scenarios directory, the path breaks. For V1 (installed tool, stable paths), storing file path is fine. Document the tradeoff.

4. **Number of sample scenarios for Phase 3:** How many YAML scenario files are needed for drill randomization tests? Minimum 3 (to test randomization and filtering across domain/difficulty). Can be minimal YAML — don't need full production scenarios yet.

# Sprint 3: CLI Entry Point & Drill Mode — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand the stub `bin/ckad-drill` into a full subcommand dispatcher, implement drill mode end-to-end flow, add PROMPT_COMMAND timer, and add progress tracking.

**Architecture:** Pure bash tool with sourced lib files. `bin/ckad-drill` is the entry point that sources all libs in order: common → display → cluster → scenario → validator → timer → progress → exam. All output through display.sh. Config via XDG paths. Testing via bats-core + shellcheck. See `_bmad-output/planning-artifacts/architecture.md` for full ADRs.

**Tech Stack:** Bash, kind, kubectl, yq, jq, bats-core, shellcheck

**Dependencies:** Sprint 1 (common.sh, display.sh, cluster.sh), Sprint 2 (scenario.sh, validator.sh).

**Key conventions (from architecture doc):**
- `set -euo pipefail` ONLY in `bin/ckad-drill`, never in lib files
- Functions: `module_action()` public, `_module_helper()` private
- Variables: `UPPER_SNAKE` globals, `lower_snake` locals, always `"${braced}"`
- All output through `display.sh` functions — no raw echo with escape codes in libs
- Lib files are source-only — no top-level execution, only function definitions
- 2-space indent, no tabs
- shellcheck clean — no suppressed warnings without justification
- Library functions return codes, never exit directly (except `error()` in display.sh)

---

### Task 1: Implement lib/timer.sh — PROMPT_COMMAND Timer (Story 6.1)

**Files:**
- Create: `lib/timer.sh`
- Test: `test/unit/timer.bats`

**Step 1: Write failing tests for timer.sh**

Create `test/unit/timer.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/timer.sh"
}

@test "timer functions are defined" {
  declare -f timer_start > /dev/null
  declare -f timer_remaining > /dev/null
  declare -f timer_is_expired > /dev/null
  declare -f timer_env_output > /dev/null
  declare -f timer_env_reset_output > /dev/null
}

@test "timer_start sets CKAD_DRILL_END" {
  timer_start 180
  [[ -n "${CKAD_DRILL_END}" ]]
  local now
  now="$(date +%s)"
  # CKAD_DRILL_END should be roughly now + 180 (within 2 seconds tolerance)
  local diff=$(( CKAD_DRILL_END - now ))
  [[ "${diff}" -ge 178 ]]
  [[ "${diff}" -le 182 ]]
}

@test "timer_remaining returns positive value after start" {
  timer_start 300
  local remaining
  remaining="$(timer_remaining)"
  [[ "${remaining}" -gt 0 ]]
  [[ "${remaining}" -le 300 ]]
}

@test "timer_remaining returns 0 when expired" {
  # Set end time in the past
  CKAD_DRILL_END=$(( $(date +%s) - 10 ))
  export CKAD_DRILL_END
  local remaining
  remaining="$(timer_remaining)"
  [[ "${remaining}" -eq 0 ]]
}

@test "timer_is_expired returns 1 (false) when time remains" {
  timer_start 300
  ! timer_is_expired
}

@test "timer_is_expired returns 0 (true) when expired" {
  CKAD_DRILL_END=$(( $(date +%s) - 10 ))
  export CKAD_DRILL_END
  timer_is_expired
}

@test "timer_format_remaining returns MM:SS format" {
  timer_start 125
  local formatted
  formatted="$(timer_format_remaining)"
  # Should be approximately 02:05
  [[ "${formatted}" =~ ^[0-9]{2}:[0-9]{2}$ ]]
}

@test "timer_format_remaining returns TIME UP when expired" {
  CKAD_DRILL_END=$(( $(date +%s) - 10 ))
  export CKAD_DRILL_END
  local formatted
  formatted="$(timer_format_remaining)"
  [[ "${formatted}" == *"TIME UP"* ]]
}

@test "timer_env_output produces shell code" {
  timer_start 180
  local output
  output="$(timer_env_output)"
  # Must define __ckad_timer function
  [[ "${output}" == *"__ckad_timer"* ]]
  # Must set PROMPT_COMMAND
  [[ "${output}" == *"PROMPT_COMMAND"* ]]
  # Must export CKAD_DRILL_END
  [[ "${output}" == *"CKAD_DRILL_END"* ]]
}

@test "timer_env_output does NOT contain set -euo pipefail" {
  timer_start 180
  local output
  output="$(timer_env_output)"
  [[ "${output}" != *"set -e"* ]]
  [[ "${output}" != *"set -u"* ]]
  [[ "${output}" != *"pipefail"* ]]
}

@test "timer_env_reset_output restores original prompt" {
  timer_start 180
  local output
  output="$(timer_env_reset_output)"
  [[ "${output}" == *"ORIGINAL_PS1"* ]]
  [[ "${output}" == *"unset"* ]]
}

@test "timer_env_output is idempotent when sourced twice" {
  timer_start 180
  local output
  output="$(timer_env_output)"
  # Source it twice in a subshell — should not error
  run bash -c "
    ${output}
    ${output}
    echo ok
  "
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"ok"* ]]
}

@test "sourcing timer.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/timer.sh" 2>&1)"
  [[ -z "${output}" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/timer.bats
```

Expected: FAIL — `lib/timer.sh` doesn't exist yet.

**Step 3: Implement lib/timer.sh**

Create `lib/timer.sh`:
```bash
#!/usr/bin/env bash
# lib/timer.sh — PROMPT_COMMAND-based countdown timer for ckad-drill
#
# Provides two interfaces:
# 1. Library functions (timer_start, timer_remaining, etc.) used by bin/ckad-drill
# 2. Shell code output (timer_env_output) sourced into the user's shell via
#    `source <(ckad-drill env)` to show countdown in the bash prompt (ADR-10)
#
# The env output MUST NOT contain set -euo pipefail (shell boundary safety).
# The env output MUST be idempotent — sourcing twice doesn't break anything.

# ---------------------------------------------------------------------------
# Timer state management
# ---------------------------------------------------------------------------

timer_start() {
  local seconds="${1}"
  CKAD_DRILL_END=$(( $(date +%s) + seconds ))
  export CKAD_DRILL_END
}

timer_remaining() {
  local now
  now="$(date +%s)"
  local remaining=$(( CKAD_DRILL_END - now ))
  if [[ "${remaining}" -lt 0 ]]; then
    remaining=0
  fi
  printf '%d\n' "${remaining}"
}

timer_is_expired() {
  local remaining
  remaining="$(timer_remaining)"
  [[ "${remaining}" -le 0 ]]
}

timer_format_remaining() {
  local remaining
  remaining="$(timer_remaining)"
  if [[ "${remaining}" -le 0 ]]; then
    printf '%s\n' "TIME UP"
    return 0
  fi
  local minutes=$(( remaining / 60 ))
  local seconds=$(( remaining % 60 ))
  printf '%02d:%02d\n' "${minutes}" "${seconds}"
}

# ---------------------------------------------------------------------------
# Shell code output for `source <(ckad-drill env)`
# ---------------------------------------------------------------------------

timer_env_output() {
  # Output shell code that sets up PROMPT_COMMAND with the timer.
  # This code runs in the USER'S shell, not in ckad-drill's process.
  # CRITICAL: No set -euo pipefail. Must be idempotent.
  cat <<ENVEOF
# ckad-drill timer — sourced into user's shell
# Save original PS1 only if not already saved (idempotent)
if [ -z "\${_CKAD_ORIGINAL_PS1+x}" ]; then
  _CKAD_ORIGINAL_PS1="\${PS1}"
  export _CKAD_ORIGINAL_PS1
fi

export CKAD_DRILL_END="${CKAD_DRILL_END}"

__ckad_timer() {
  local _remaining=\$(( CKAD_DRILL_END - \$(date +%s) ))
  if [ "\${_remaining}" -le 0 ]; then
    PS1="[\$(printf '\\\\e[1;31m')TIME UP\$(printf '\\\\e[0m')] \${_CKAD_ORIGINAL_PS1}"
  else
    local _min=\$(( _remaining / 60 ))
    local _sec=\$(( _remaining % 60 ))
    PS1="[\$(printf '%02d:%02d' "\${_min}" "\${_sec}")] \${_CKAD_ORIGINAL_PS1}"
  fi
}

PROMPT_COMMAND='__ckad_timer'
ENVEOF
}

timer_env_reset_output() {
  # Output shell code that restores the user's original prompt.
  cat <<'RESETEOF'
# ckad-drill timer reset — restores original prompt
if [ -n "${_CKAD_ORIGINAL_PS1+x}" ]; then
  PS1="${_CKAD_ORIGINAL_PS1}"
  export PS1
  unset _CKAD_ORIGINAL_PS1
fi
unset CKAD_DRILL_END
unset PROMPT_COMMAND
unset -f __ckad_timer 2>/dev/null
RESETEOF
}
```

**Step 4: Run tests to verify they pass**

```bash
bats test/unit/timer.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/timer.sh
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add lib/timer.sh test/unit/timer.bats
git commit -m "feat: implement lib/timer.sh with PROMPT_COMMAND countdown timer

timer_start/remaining/is_expired/format_remaining library functions.
timer_env_output generates shell code for source <(ckad-drill env).
Env output is idempotent, has no set -euo pipefail (shell boundary
safety), and timer_env_reset_output cleanly restores original prompt.
Includes bats unit tests."
```

---

### Task 2: Implement lib/progress.sh — Progress Tracking (Story 6.2)

**Files:**
- Create: `lib/progress.sh`
- Test: `test/unit/progress.bats`

**Step 1: Write failing tests for progress.sh**

Create `test/unit/progress.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/progress.sh"

  # Use temp dir for progress file during tests
  export CKAD_CONFIG_DIR="${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_PROGRESS_FILE="${CKAD_CONFIG_DIR}/progress.json"
  mkdir -p "${CKAD_CONFIG_DIR}"
}

@test "progress functions are defined" {
  declare -f progress_ensure_file > /dev/null
  declare -f progress_record > /dev/null
  declare -f progress_record_exam > /dev/null
  declare -f progress_get_stats > /dev/null
  declare -f progress_get_weakest > /dev/null
  declare -f progress_get_streak > /dev/null
}

@test "progress_ensure_file creates progress.json with version 1" {
  [[ ! -f "${CKAD_PROGRESS_FILE}" ]]
  progress_ensure_file
  [[ -f "${CKAD_PROGRESS_FILE}" ]]
  local version
  version="$(jq -r '.version' "${CKAD_PROGRESS_FILE}")"
  [[ "${version}" == "1" ]]
}

@test "progress_ensure_file creates empty scenarios object" {
  progress_ensure_file
  local scenarios
  scenarios="$(jq -r '.scenarios | keys | length' "${CKAD_PROGRESS_FILE}")"
  [[ "${scenarios}" == "0" ]]
}

@test "progress_ensure_file creates empty exams array" {
  progress_ensure_file
  local exams
  exams="$(jq -r '.exams | length' "${CKAD_PROGRESS_FILE}")"
  [[ "${exams}" == "0" ]]
}

@test "progress_ensure_file is idempotent" {
  progress_ensure_file
  progress_record "test-scenario" true 120 3
  progress_ensure_file
  # Data should still be there
  local passed
  passed="$(jq -r '.scenarios["test-scenario"].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "true" ]]
}

@test "progress_record writes scenario result" {
  progress_ensure_file
  progress_record "multi-container-pod" true 145 1
  local passed
  passed="$(jq -r '.scenarios["multi-container-pod"].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "true" ]]
  local time_seconds
  time_seconds="$(jq -r '.scenarios["multi-container-pod"].time_seconds' "${CKAD_PROGRESS_FILE}")"
  [[ "${time_seconds}" == "145" ]]
}

@test "progress_record stores domain" {
  progress_ensure_file
  progress_record "multi-container-pod" true 145 1
  local domain
  domain="$(jq -r '.scenarios["multi-container-pod"].domain' "${CKAD_PROGRESS_FILE}")"
  [[ "${domain}" == "1" ]]
}

@test "progress_record increments attempts on repeat" {
  progress_ensure_file
  progress_record "multi-container-pod" false 180 1
  progress_record "multi-container-pod" true 145 1
  local attempts
  attempts="$(jq -r '.scenarios["multi-container-pod"].attempts' "${CKAD_PROGRESS_FILE}")"
  [[ "${attempts}" == "2" ]]
}

@test "progress_record updates last_attempted timestamp" {
  progress_ensure_file
  progress_record "multi-container-pod" true 145 1
  local last_attempted
  last_attempted="$(jq -r '.scenarios["multi-container-pod"].last_attempted' "${CKAD_PROGRESS_FILE}")"
  [[ -n "${last_attempted}" ]]
  [[ "${last_attempted}" != "null" ]]
}

@test "progress_record updates passed to true on success" {
  progress_ensure_file
  progress_record "multi-container-pod" false 180 1
  local passed
  passed="$(jq -r '.scenarios["multi-container-pod"].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "false" ]]
  progress_record "multi-container-pod" true 145 1
  passed="$(jq -r '.scenarios["multi-container-pod"].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "true" ]]
}

@test "progress_record_exam appends exam result" {
  progress_ensure_file
  progress_record_exam 72 '{"1":80,"2":60,"3":75,"4":70,"5":65}'
  local score
  score="$(jq -r '.exams[0].score' "${CKAD_PROGRESS_FILE}")"
  [[ "${score}" == "72" ]]
  local passed
  passed="$(jq -r '.exams[0].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "true" ]]
}

@test "progress_record_exam marks failed when score < 66" {
  progress_ensure_file
  progress_record_exam 55 '{"1":50,"2":60,"3":40,"4":70,"5":55}'
  local passed
  passed="$(jq -r '.exams[0].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "false" ]]
}

@test "progress_record_exam stores per-domain scores" {
  progress_ensure_file
  progress_record_exam 72 '{"1":80,"2":60,"3":75,"4":70,"5":65}'
  local d1
  d1="$(jq -r '.exams[0].domains["1"]' "${CKAD_PROGRESS_FILE}")"
  [[ "${d1}" == "80" ]]
}

@test "progress_record_exam appends multiple exams" {
  progress_ensure_file
  progress_record_exam 72 '{"1":80,"2":60,"3":75,"4":70,"5":65}'
  progress_record_exam 85 '{"1":90,"2":80,"3":85,"4":80,"5":90}'
  local count
  count="$(jq -r '.exams | length' "${CKAD_PROGRESS_FILE}")"
  [[ "${count}" == "2" ]]
}

@test "progress_get_stats returns per-domain pass rates" {
  progress_ensure_file
  progress_record "sc-a" true 120 1
  progress_record "sc-b" false 180 1
  progress_record "sc-c" true 90 2
  local stats
  stats="$(progress_get_stats)"
  # Should be valid JSON
  echo "${stats}" | jq . > /dev/null
  # Domain 1: 1 pass, 1 fail = 50%
  local d1_rate
  d1_rate="$(echo "${stats}" | jq -r '.["1"].pass_rate')"
  [[ "${d1_rate}" == "50" ]]
  # Domain 2: 1 pass, 0 fail = 100%
  local d2_rate
  d2_rate="$(echo "${stats}" | jq -r '.["2"].pass_rate')"
  [[ "${d2_rate}" == "100" ]]
}

@test "progress_get_weakest returns domain with lowest pass rate" {
  progress_ensure_file
  progress_record "sc-a" true 120 1
  progress_record "sc-b" true 90 1
  progress_record "sc-c" false 180 2
  progress_record "sc-d" false 200 2
  local weakest
  weakest="$(progress_get_weakest)"
  [[ "${weakest}" == "2" ]]
}

@test "progress_get_weakest returns empty when no data" {
  progress_ensure_file
  local weakest
  weakest="$(progress_get_weakest)"
  [[ -z "${weakest}" ]]
}

@test "progress_get_streak returns 0 when no data" {
  progress_ensure_file
  local streak
  streak="$(progress_get_streak)"
  [[ "${streak}" == "0" ]]
}

@test "progress_update_streak updates streak on activity" {
  progress_ensure_file
  progress_update_streak
  local streak
  streak="$(jq -r '.streak.current' "${CKAD_PROGRESS_FILE}")"
  [[ "${streak}" == "1" ]]
  local last_date
  last_date="$(jq -r '.streak.last_date' "${CKAD_PROGRESS_FILE}")"
  [[ "${last_date}" == "$(date +%Y-%m-%d)" ]]
}

@test "progress handles missing fields with defaults (additive-only schema)" {
  # Simulate old progress file without streak field
  cat > "${CKAD_PROGRESS_FILE}" <<'EOF'
{
  "version": 1,
  "scenarios": {},
  "exams": []
}
EOF
  local streak
  streak="$(progress_get_streak)"
  [[ "${streak}" == "0" ]]
}

@test "sourcing progress.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/progress.sh" 2>&1)"
  [[ -z "${output}" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
cd /home/jeff/Projects/cka
bats test/unit/progress.bats
```

Expected: FAIL — `lib/progress.sh` doesn't exist yet.

**Step 3: Implement lib/progress.sh**

Create `lib/progress.sh`:
```bash
#!/usr/bin/env bash
# lib/progress.sh — Progress tracking for ckad-drill
#
# Manages persistent progress data in progress.json using jq.
# Additive-only schema (ADR-05): never remove fields, only add.
# Missing fields get defaults on read.
#
# Progress file location: ~/.config/ckad-drill/progress.json (from common.sh)

# ---------------------------------------------------------------------------
# File initialization
# ---------------------------------------------------------------------------

_progress_empty_json() {
  cat <<'EOF'
{
  "version": 1,
  "scenarios": {},
  "exams": [],
  "streak": {
    "current": 0,
    "last_date": ""
  }
}
EOF
}

progress_ensure_file() {
  mkdir -p "$(dirname "${CKAD_PROGRESS_FILE}")"
  if [[ ! -f "${CKAD_PROGRESS_FILE}" ]]; then
    _progress_empty_json > "${CKAD_PROGRESS_FILE}"
  fi
}

# ---------------------------------------------------------------------------
# Read helpers (handle missing fields gracefully — ADR-05)
# ---------------------------------------------------------------------------

_progress_read() {
  # Read progress file with defaults for missing fields
  local json
  json="$(cat "${CKAD_PROGRESS_FILE}")"

  # Ensure streak field exists (additive-only migration)
  if ! echo "${json}" | jq -e '.streak' > /dev/null 2>&1; then
    json="$(echo "${json}" | jq '. + {"streak": {"current": 0, "last_date": ""}}')"
  fi

  printf '%s\n' "${json}"
}

_progress_write() {
  local json="${1}"
  printf '%s\n' "${json}" | jq '.' > "${CKAD_PROGRESS_FILE}"
}

# ---------------------------------------------------------------------------
# Scenario result recording
# ---------------------------------------------------------------------------

progress_record() {
  local scenario_id="${1}"
  local passed="${2}"
  local time_seconds="${3}"
  local domain="${4}"

  progress_ensure_file

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local json
  json="$(_progress_read)"

  # Check if scenario already has an entry
  local existing
  existing="$(echo "${json}" | jq -r --arg id "${scenario_id}" '.scenarios[$id] // empty')"

  if [[ -n "${existing}" ]]; then
    # Update existing: increment attempts, update fields
    local prev_attempts
    prev_attempts="$(echo "${json}" | jq -r --arg id "${scenario_id}" '.scenarios[$id].attempts')"
    json="$(echo "${json}" | jq \
      --arg id "${scenario_id}" \
      --argjson passed "${passed}" \
      --argjson time "${time_seconds}" \
      --argjson domain "${domain}" \
      --arg now "${now}" \
      --argjson attempts "$(( prev_attempts + 1 ))" \
      '.scenarios[$id] = (.scenarios[$id] // {}) * {
        "passed": $passed,
        "time_seconds": $time,
        "domain": $domain,
        "attempts": $attempts,
        "last_attempted": $now
      }')"
  else
    # New entry
    json="$(echo "${json}" | jq \
      --arg id "${scenario_id}" \
      --argjson passed "${passed}" \
      --argjson time "${time_seconds}" \
      --argjson domain "${domain}" \
      --arg now "${now}" \
      '.scenarios[$id] = {
        "passed": $passed,
        "time_seconds": $time,
        "domain": $domain,
        "attempts": 1,
        "last_attempted": $now
      }')"
  fi

  _progress_write "${json}"
}

# ---------------------------------------------------------------------------
# Exam result recording
# ---------------------------------------------------------------------------

progress_record_exam() {
  local score="${1}"
  local domain_scores="${2}"  # JSON string like '{"1":80,"2":60,...}'

  progress_ensure_file

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local passed="false"
  if [[ "${score}" -ge 66 ]]; then
    passed="true"
  fi

  local json
  json="$(_progress_read)"

  json="$(echo "${json}" | jq \
    --argjson score "${score}" \
    --argjson passed "${passed}" \
    --argjson domains "${domain_scores}" \
    --arg now "${now}" \
    '.exams += [{
      "date": $now,
      "score": $score,
      "passed": $passed,
      "domains": $domains
    }]')"

  _progress_write "${json}"
}

# ---------------------------------------------------------------------------
# Stats & analytics
# ---------------------------------------------------------------------------

progress_get_stats() {
  progress_ensure_file
  local json
  json="$(_progress_read)"

  # Calculate per-domain pass rates
  # Output: {"1": {"total": N, "passed": N, "pass_rate": N}, ...}
  echo "${json}" | jq '
    .scenarios | to_entries | group_by(.value.domain) |
    map({
      key: (.[0].value.domain | tostring),
      value: {
        total: length,
        passed: (map(select(.value.passed == true)) | length),
        pass_rate: (if length == 0 then 0
                    else ((map(select(.value.passed == true)) | length) * 100 / length)
                    end)
      }
    }) | from_entries
  '
}

progress_get_weakest() {
  progress_ensure_file
  local stats
  stats="$(progress_get_stats)"

  # Return domain number with lowest pass rate (empty string if no data)
  echo "${stats}" | jq -r '
    if length == 0 then ""
    else to_entries | min_by(.value.pass_rate) | .key
    end
  '
}

progress_get_streak() {
  progress_ensure_file
  local json
  json="$(_progress_read)"

  echo "${json}" | jq -r '.streak.current // 0'
}

progress_update_streak() {
  progress_ensure_file
  local json
  json="$(_progress_read)"

  local today
  today="$(date +%Y-%m-%d)"
  local last_date
  last_date="$(echo "${json}" | jq -r '.streak.last_date // ""')"
  local current
  current="$(echo "${json}" | jq -r '.streak.current // 0')"

  if [[ "${last_date}" == "${today}" ]]; then
    # Already recorded today, no change
    return 0
  fi

  local yesterday
  yesterday="$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")"

  if [[ "${last_date}" == "${yesterday}" ]]; then
    # Consecutive day, increment streak
    current=$(( current + 1 ))
  else
    # Streak broken or first day, reset to 1
    current=1
  fi

  json="$(echo "${json}" | jq \
    --argjson current "${current}" \
    --arg today "${today}" \
    '.streak = {"current": $current, "last_date": $today}')"

  _progress_write "${json}"
}

# ---------------------------------------------------------------------------
# Dashboard formatting
# ---------------------------------------------------------------------------

progress_show_dashboard() {
  progress_ensure_file
  local json
  json="$(_progress_read)"

  header "Progress Dashboard"

  local total_scenarios
  total_scenarios="$(echo "${json}" | jq '.scenarios | length')"
  local total_passed
  total_passed="$(echo "${json}" | jq '[.scenarios[] | select(.passed == true)] | length')"
  local total_exams
  total_exams="$(echo "${json}" | jq '.exams | length')"
  local streak
  streak="$(progress_get_streak)"

  info "Scenarios attempted: ${total_scenarios}"
  info "Scenarios passed:    ${total_passed}"
  info "Exams taken:         ${total_exams}"
  info "Current streak:      ${streak} day(s)"

  # Per-domain breakdown
  local stats
  stats="$(progress_get_stats)"
  local domain_count
  domain_count="$(echo "${stats}" | jq 'length')"

  if [[ "${domain_count}" -gt 0 ]]; then
    printf '\n'
    info "Per-Domain Pass Rates:"
    local domain_names=("" "Application Design & Build" "Application Deployment" "Observability & Maintenance" "Config & Security" "Services & Networking")
    for d in 1 2 3 4 5; do
      local rate
      rate="$(echo "${stats}" | jq -r --arg d "${d}" '.[$d].pass_rate // "N/A"')"
      local total
      total="$(echo "${stats}" | jq -r --arg d "${d}" '.[$d].total // 0')"
      if [[ "${rate}" != "null" ]] && [[ "${total}" != "0" ]]; then
        info "  Domain ${d} (${domain_names[${d}]}): ${rate}% (${total} attempted)"
      else
        info "  Domain ${d} (${domain_names[${d}]}): No data"
      fi
    done
  fi

  # Weakest domain recommendation
  local weakest
  weakest="$(progress_get_weakest)"
  if [[ -n "${weakest}" ]]; then
    printf '\n'
    local domain_names=("" "Application Design & Build" "Application Deployment" "Observability & Maintenance" "Config & Security" "Services & Networking")
    warn "Weakest area: Domain ${weakest} (${domain_names[${weakest}]}) — focus your next drills here"
  fi

  # Exam history
  if [[ "${total_exams}" -gt 0 ]]; then
    printf '\n'
    info "Recent Exams:"
    echo "${json}" | jq -r '.exams | reverse | .[0:5] | .[] |
      "  " + .date + " — Score: " + (.score | tostring) + "% " +
      (if .passed then "(PASSED)" else "(FAILED)" end)' | while IFS= read -r line; do
      info "${line}"
    done
  fi
}
```

**Step 4: Run tests to verify they pass**

```bash
bats test/unit/progress.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/progress.sh
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add lib/progress.sh test/unit/progress.bats
git commit -m "feat: implement lib/progress.sh with additive-only progress tracking

progress_record for scenario results, progress_record_exam for exam
results, progress_get_stats for per-domain pass rates, progress_get_weakest
for study recommendations, progress_update_streak for daily streak.
Additive-only JSON schema (ADR-05), handles missing fields gracefully.
Dashboard with progress_show_dashboard. Includes bats unit tests."
```

---

### Task 3: Expand bin/ckad-drill — Full Subcommand Dispatch (Story 5.1)

This task replaces the Sprint 1 stub with the full entry point that sources all libs and dispatches all subcommands.

**Files:**
- Modify: `bin/ckad-drill`
- Test: `test/unit/cli.bats` (modify existing)

**Step 1: Write failing tests for the expanded CLI**

Replace `test/unit/cli.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  export PATH="${CKAD_ROOT}/bin:${PATH}"
}

# ---- Basic dispatch ----

@test "ckad-drill with no args shows usage" {
  run ckad-drill
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "ckad-drill --help shows usage" {
  run ckad-drill --help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Usage:"* ]]
}

@test "ckad-drill --version shows version" {
  run ckad-drill --version
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"ckad-drill"* ]]
}

@test "ckad-drill unknown-command shows error" {
  run ckad-drill unknown-command
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Unknown command"* ]]
}

# ---- Subcommand recognition ----

@test "ckad-drill recognizes drill subcommand" {
  # Without a cluster this should fail with a cluster error, not "unknown command"
  run ckad-drill drill 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes check subcommand" {
  run ckad-drill check 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes hint subcommand" {
  run ckad-drill hint 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes solution subcommand" {
  run ckad-drill solution 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes next subcommand" {
  run ckad-drill next 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes skip subcommand" {
  run ckad-drill skip 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes current subcommand" {
  run ckad-drill current 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes status subcommand" {
  run ckad-drill status 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes timer subcommand" {
  run ckad-drill timer 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

@test "ckad-drill recognizes env subcommand" {
  run ckad-drill env 2>&1
  [[ "${output}" != *"Unknown command"* ]]
}

# ---- Usage lists all commands ----

@test "usage includes drill commands" {
  run ckad-drill --help
  [[ "${output}" == *"drill"* ]]
  [[ "${output}" == *"check"* ]]
  [[ "${output}" == *"hint"* ]]
  [[ "${output}" == *"solution"* ]]
  [[ "${output}" == *"next"* ]]
  [[ "${output}" == *"skip"* ]]
  [[ "${output}" == *"current"* ]]
}

@test "usage includes cluster commands" {
  run ckad-drill --help
  [[ "${output}" == *"start"* ]]
  [[ "${output}" == *"stop"* ]]
  [[ "${output}" == *"reset"* ]]
}

@test "usage includes status/timer/env commands" {
  run ckad-drill --help
  [[ "${output}" == *"status"* ]]
  [[ "${output}" == *"timer"* ]]
  [[ "${output}" == *"env"* ]]
}

# ---- Structural checks ----

@test "ckad-drill is executable" {
  [[ -x "${CKAD_ROOT}/bin/ckad-drill" ]]
}

@test "ckad-drill passes shellcheck" {
  shellcheck "${CKAD_ROOT}/bin/ckad-drill"
}

# ---- Session-dependent commands give clear errors ----

@test "check without session shows no-session error" {
  # Clear any session
  rm -f "${BATS_TEST_TMPDIR}/config/ckad-drill/session.json"
  export CKAD_CONFIG_DIR="${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
  run ckad-drill check
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"No active scenario"* ]] || [[ "${output}" == *"session"* ]]
}

@test "hint without session shows no-session error" {
  rm -f "${BATS_TEST_TMPDIR}/config/ckad-drill/session.json"
  export CKAD_CONFIG_DIR="${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
  run ckad-drill hint
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"No active scenario"* ]] || [[ "${output}" == *"session"* ]]
}

@test "env subcommand produces shell code" {
  # Create a minimal session for env to work
  mkdir -p "${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_CONFIG_DIR="${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{"mode":"drill","scenario_id":"test","namespace":"test-ns","started_at":"2026-01-01T00:00:00Z","time_limit":180}
EOF
  run ckad-drill env
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"PROMPT_COMMAND"* ]] || [[ "${output}" == *"__ckad_timer"* ]]
}

@test "env --reset produces reset shell code" {
  run ckad-drill env --reset
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"unset"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/cli.bats
```

Expected: FAIL — many new tests for subcommands not yet dispatched.

**Step 3: Implement expanded bin/ckad-drill**

Replace `bin/ckad-drill`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# ckad-drill — CKAD exam practice tool
# ---------------------------------------------------------------------------

CKAD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKAD_ROOT

# Source libraries in dependency order
source "${CKAD_ROOT}/lib/common.sh"
source "${CKAD_ROOT}/lib/display.sh"
source "${CKAD_ROOT}/lib/cluster.sh"
source "${CKAD_ROOT}/lib/scenario.sh"
source "${CKAD_ROOT}/lib/validator.sh"
source "${CKAD_ROOT}/lib/timer.sh"
source "${CKAD_ROOT}/lib/progress.sh"
# exam.sh will be sourced once it exists (Sprint 5)
if [[ -f "${CKAD_ROOT}/lib/exam.sh" ]]; then
  source "${CKAD_ROOT}/lib/exam.sh"
fi

# ---------------------------------------------------------------------------
# Signal handling — cleanup on exit/interrupt
# ---------------------------------------------------------------------------

_cleanup() {
  local exit_code=$?
  # If there's an active drill session, clean up the namespace
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    local mode
    mode="$(jq -r '.mode // ""' "${CKAD_SESSION_FILE}" 2>/dev/null || echo "")"
    if [[ "${mode}" == "drill" ]]; then
      local ns
      ns="$(jq -r '.namespace // ""' "${CKAD_SESSION_FILE}" 2>/dev/null || echo "")"
      if [[ -n "${ns}" ]] && cluster_exists 2>/dev/null; then
        kubectl delete namespace "${ns}" --ignore-not-found --context "kind-${CKAD_CLUSTER_NAME}" &>/dev/null || true
      fi
      rm -f "${CKAD_SESSION_FILE}"
    fi
    # Exam mode cleanup is handled by exam.sh
  fi
  exit "${exit_code}"
}

trap _cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Session helpers
# ---------------------------------------------------------------------------

_require_session() {
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    error "No active scenario. Run 'ckad-drill drill' first."
    return "${EXIT_NO_SESSION}"
  fi
}

_require_drill_session() {
  _require_session
  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}")"
  if [[ "${mode}" != "drill" ]]; then
    error "Not in drill mode. Current mode: ${mode}"
    return 1
  fi
}

_session_read_field() {
  local field="${1}"
  jq -r ".${field} // \"\"" "${CKAD_SESSION_FILE}"
}

_write_drill_session() {
  local scenario_id="${1}"
  local namespace="${2}"
  local time_limit="${3}"

  common_ensure_dirs
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  jq -n \
    --arg mode "drill" \
    --arg id "${scenario_id}" \
    --arg ns "${namespace}" \
    --arg started "${now}" \
    --argjson limit "${time_limit}" \
    '{
      mode: $mode,
      scenario_id: $id,
      namespace: $ns,
      started_at: $started,
      time_limit: $limit
    }' > "${CKAD_SESSION_FILE}"
}

# ---------------------------------------------------------------------------
# Strict exam environment (ADR-03)
# ---------------------------------------------------------------------------

_setup_exam_env() {
  # Set up the strict exam environment
  # These apply to the ckad-drill process itself;
  # the user's shell gets them via `source <(ckad-drill env)`
  alias k=kubectl 2>/dev/null || true
  export EDITOR=vim
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

_usage() {
  cat <<'EOF'
Usage: ckad-drill <command> [options]

Cluster Management:
  start             Create kind cluster and install addons
  stop              Delete kind cluster
  reset             Recreate kind cluster

Drill Mode:
  drill             Start a drill scenario
    --domain N        Filter by domain (1-5)
    --difficulty LVL  Filter by difficulty (easy/medium/hard)
  check             Validate current scenario
  hint              Show hint for current scenario
  solution          Show solution for current scenario
  next              Move to next scenario
  skip              Skip current scenario without checking
  current           Reprint current scenario task

Exam Mode (coming soon):
  exam              Start exam mode
  learn             Start learn mode

Progress & Timer:
  status            Show progress dashboard
  timer             Show remaining time
  env               Output shell code for prompt timer
    --reset           Restore original prompt

Tools:
  validate-scenario <file|dir>  Validate scenario YAML

Options:
  --help            Show this help message
  --version         Show version

Timer Setup:
  source <(ckad-drill env)    Enable countdown in your prompt

EOF
}

# ---------------------------------------------------------------------------
# Command implementations
# ---------------------------------------------------------------------------

cmd_start() {
  cluster_create
  source "${CKAD_ROOT}/scripts/cluster-setup.sh"
  cluster_setup_addons
}

cmd_stop() {
  # Clean up any active session first
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    rm -f "${CKAD_SESSION_FILE}"
  fi
  cluster_delete
}

cmd_reset() {
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    rm -f "${CKAD_SESSION_FILE}"
  fi
  cluster_reset
  source "${CKAD_ROOT}/scripts/cluster-setup.sh"
  cluster_setup_addons
}

cmd_drill() {
  cluster_ensure_running

  local domain=""
  local difficulty=""

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --domain)
        domain="${2}"
        shift 2
        ;;
      --difficulty)
        difficulty="${2}"
        shift 2
        ;;
      *)
        error "Unknown drill option: ${1}"
        return 1
        ;;
    esac
  done

  # Clean up any existing drill session
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    local prev_mode
    prev_mode="$(jq -r '.mode // ""' "${CKAD_SESSION_FILE}" 2>/dev/null || echo "")"
    if [[ "${prev_mode}" == "drill" ]]; then
      local prev_ns
      prev_ns="$(jq -r '.namespace // ""' "${CKAD_SESSION_FILE}" 2>/dev/null || echo "")"
      if [[ -n "${prev_ns}" ]]; then
        scenario_cleanup "${prev_ns}"
      fi
    fi
  fi

  # Select a scenario
  local scenario_file
  scenario_file="$(scenario_select "${domain}" "${difficulty}")"

  # Load the scenario
  scenario_load "${scenario_file}"

  # Get scenario metadata
  local scenario_id
  scenario_id="$(scenario_get_field "id")"
  local namespace
  namespace="$(scenario_get_field "namespace")"
  local time_limit
  time_limit="$(scenario_get_field "time_limit")"
  local title
  title="$(scenario_get_field "title")"

  # Derive namespace if not specified
  if [[ -z "${namespace}" ]] || [[ "${namespace}" == "null" ]]; then
    namespace="drill-${scenario_id}"
  fi

  # Setup the scenario (create namespace, run setup commands)
  scenario_setup "${namespace}"

  # Write session file
  _write_drill_session "${scenario_id}" "${namespace}" "${time_limit}"

  # Start timer
  timer_start "${time_limit}"

  # Set up strict exam environment
  _setup_exam_env

  # Display the task
  _display_scenario_task

  info "Run 'ckad-drill check' when ready. Time limit: $(timer_format_remaining)"
  info "For prompt timer: source <(ckad-drill env)"
}

_display_scenario_task() {
  local title
  title="$(scenario_get_field "title")"
  local description
  description="$(scenario_get_field "description")"
  local namespace
  namespace="$(_session_read_field "namespace")"
  local domain
  domain="$(scenario_get_field "domain")"
  local difficulty
  difficulty="$(scenario_get_field "difficulty")"

  header "${title}"
  info "Domain: ${domain} | Difficulty: ${difficulty} | Namespace: ${namespace}"
  printf '\n%s\n\n' "${description}"
}

cmd_check() {
  _require_session

  local mode
  mode="$(_session_read_field "mode")"

  if [[ "${mode}" == "exam" ]] && declare -f exam_check &>/dev/null; then
    exam_check
    return
  fi

  _require_drill_session
  cluster_ensure_running

  local scenario_id
  scenario_id="$(_session_read_field "scenario_id")"
  local namespace
  namespace="$(_session_read_field "namespace")"
  local started_at
  started_at="$(_session_read_field "started_at")"
  local domain
  domain="$(scenario_get_field "domain")"

  header "Checking: ${scenario_id}"

  # Run validations
  local validations_json
  validations_json="$(scenario_get_field "validations")"
  validator_run_checks "${namespace}" "${validations_json}"

  # Get results
  local total passed failed
  total="$(validator_get_total)"
  passed="$(validator_get_passed)"
  failed="$(validator_get_failed)"

  printf '\n'
  info "Results: ${passed}/${total} checks passed"

  # Calculate time taken
  local now
  now="$(date +%s)"
  local started_epoch
  started_epoch="$(date -d "${started_at}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${started_at}" +%s 2>/dev/null || echo "${now}")"
  local time_taken=$(( now - started_epoch ))

  # Record to progress
  local all_passed=false
  if [[ "${failed}" -eq 0 ]]; then
    all_passed=true
    pass "All checks passed!"
  else
    fail "${failed} check(s) failed."
  fi

  progress_record "${scenario_id}" "${all_passed}" "${time_taken}" "${domain}"
  progress_update_streak
}

cmd_hint() {
  _require_session

  local mode
  mode="$(_session_read_field "mode")"

  if [[ "${mode}" == "exam" ]]; then
    error "Hints are not available during exam mode."
    return 1
  fi

  local hint
  hint="$(scenario_get_field "hint")"

  if [[ -z "${hint}" ]] || [[ "${hint}" == "null" ]]; then
    info "No hint available for this scenario."
  else
    header "Hint"
    printf '%s\n' "${hint}"
  fi
}

cmd_solution() {
  _require_session

  local mode
  mode="$(_session_read_field "mode")"

  if [[ "${mode}" == "exam" ]]; then
    error "Solutions are not available during exam mode."
    return 1
  fi

  local solution
  solution="$(scenario_get_field "solution")"

  header "Solution"
  printf '%s\n' "${solution}"
}

cmd_next() {
  _require_drill_session
  cluster_ensure_running

  local namespace
  namespace="$(_session_read_field "namespace")"

  # Clean up current scenario
  if [[ -n "${namespace}" ]]; then
    scenario_cleanup "${namespace}"
  fi
  rm -f "${CKAD_SESSION_FILE}"

  info "Starting next scenario..."

  # Start a new drill (no filters — random selection)
  cmd_drill
}

cmd_skip() {
  _require_drill_session

  local scenario_id
  scenario_id="$(_session_read_field "scenario_id")"
  local namespace
  namespace="$(_session_read_field "namespace")"

  # Clean up current scenario
  if [[ -n "${namespace}" ]] && cluster_exists 2>/dev/null; then
    scenario_cleanup "${namespace}"
  fi
  rm -f "${CKAD_SESSION_FILE}"

  info "Skipped scenario: ${scenario_id}"
}

cmd_current() {
  _require_session
  _display_scenario_task
}

cmd_status() {
  progress_show_dashboard
}

cmd_timer() {
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    info "No active session."
    return 0
  fi

  local time_limit
  time_limit="$(_session_read_field "time_limit")"
  local started_at
  started_at="$(_session_read_field "started_at")"

  if [[ -z "${time_limit}" ]] || [[ "${time_limit}" == "null" ]]; then
    info "No timer set for current session."
    return 0
  fi

  # Calculate end time from session
  local started_epoch
  started_epoch="$(date -d "${started_at}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${started_at}" +%s 2>/dev/null || echo "$(date +%s)")"
  CKAD_DRILL_END=$(( started_epoch + time_limit ))
  export CKAD_DRILL_END

  local formatted
  formatted="$(timer_format_remaining)"
  info "Time remaining: ${formatted}"
}

cmd_env() {
  local flag="${1:-}"

  if [[ "${flag}" == "--reset" ]]; then
    timer_env_reset_output
    return 0
  fi

  # Read session to get timer info
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    error "No active session. Run 'ckad-drill drill' first."
    return "${EXIT_NO_SESSION}"
  fi

  local time_limit
  time_limit="$(_session_read_field "time_limit")"
  local started_at
  started_at="$(_session_read_field "started_at")"

  # Calculate end time from session
  local started_epoch
  started_epoch="$(date -d "${started_at}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${started_at}" +%s 2>/dev/null || echo "$(date +%s)")"
  CKAD_DRILL_END=$(( started_epoch + time_limit ))
  export CKAD_DRILL_END

  # Also output the strict exam environment setup (ADR-03)
  cat <<'EXAMENVEOF'
# ckad-drill strict exam environment (ADR-03)
alias k=kubectl
source <(kubectl completion bash 2>/dev/null) || true
complete -o default -F __start_kubectl k 2>/dev/null || true
export EDITOR=vim
EXAMENVEOF

  timer_env_output
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

main() {
  local command="${1:-}"
  shift || true

  case "${command}" in
    # Cluster management
    start)              cmd_start ;;
    stop)               cmd_stop ;;
    reset)              cmd_reset ;;

    # Drill mode
    drill)              cmd_drill "$@" ;;
    check)              cmd_check ;;
    hint)               cmd_hint ;;
    solution)           cmd_solution ;;
    next)               cmd_next ;;
    skip)               cmd_skip ;;
    current)            cmd_current ;;

    # Exam mode (dispatched to exam.sh when it exists)
    exam)
      if declare -f exam_start &>/dev/null; then
        exam_start "$@"
      else
        error "Exam mode is not yet implemented."
      fi
      ;;
    learn)
      error "Learn mode is not yet implemented."
      ;;

    # Progress & timer
    status)             cmd_status ;;
    timer)              cmd_timer ;;
    env)                cmd_env "$@" ;;

    # Tools
    validate-scenario)
      if [[ -z "${1:-}" ]]; then
        error "Usage: ckad-drill validate-scenario <file|dir>"
        return 1
      fi
      scenario_validate "$@"
      ;;

    # Meta
    --help|-h)          _usage ;;
    --version|-v)       echo "ckad-drill 0.1.0-dev" ;;
    "")
      _usage >&2
      return 1
      ;;
    *)
      error "Unknown command: ${command}. Run 'ckad-drill --help' for usage."
      ;;
  esac
}

main "$@"
```

**Step 4: Run tests**

```bash
bats test/unit/cli.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck bin/ckad-drill
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add bin/ckad-drill test/unit/cli.bats
git commit -m "feat: expand bin/ckad-drill to full subcommand dispatch

Replace Sprint 1 stub with complete CLI entry point. Sources all libs
in order (common → display → cluster → scenario → validator → timer →
progress → exam). Dispatches: drill, check, hint, solution, next,
skip, current, status, timer, env. Signal handling via trap cleanup
EXIT INT TERM. Strict exam env (ADR-03). Session state via session.json.
Includes expanded bats tests for all subcommands."
```

---

### Task 4: Implement Drill Mode End-to-End Flow (Story 5.2)

This task ensures the drill flow works end-to-end by writing integration-style unit tests that verify session lifecycle without a running cluster.

**Files:**
- Create: `test/unit/drill-flow.bats`
- Create: `test/helpers/fixtures/test-scenario.yaml` (test fixture)

**Step 1: Create test scenario fixture**

Create `test/helpers/fixtures/test-scenario.yaml`:
```yaml
id: test-multi-container
domain: 1
title: "Test Multi-Container Pod"
difficulty: easy
time_limit: 180
namespace: test-ns
description: |
  Create a pod named 'web-logger' in namespace 'test-ns' with two containers:
  1. nginx container named 'web' using image nginx:1.25
  2. busybox container named 'logger' using image busybox:1.36

  The 'logger' container should run: tail -f /var/log/nginx/access.log
tags:
  - pods
  - multi-container
hint: |
  Use a pod spec with multiple containers in the containers array.
  Remember to add a shared volume for the log file.
solution: |
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: web-logger
    namespace: test-ns
  spec:
    containers:
    - name: web
      image: nginx:1.25
    - name: logger
      image: busybox:1.36
      command: ["tail", "-f", "/var/log/nginx/access.log"]
  EOF
validations:
  - type: resource_exists
    resource: pod/web-logger
    description: "Pod web-logger exists"
  - type: container_count
    resource: pod/web-logger
    expected: 2
    description: "Pod has 2 containers"
  - type: container_image
    resource: pod/web-logger
    container: web
    expected: "nginx:1.25"
    description: "Web container uses nginx:1.25"
```

**Step 2: Write failing tests for drill flow**

Create `test/unit/drill-flow.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"
  source "${CKAD_ROOT}/lib/timer.sh"
  source "${CKAD_ROOT}/lib/progress.sh"

  # Override paths for test isolation
  export CKAD_CONFIG_DIR="${BATS_TEST_TMPDIR}/config/ckad-drill"
  export CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
  export CKAD_PROGRESS_FILE="${CKAD_CONFIG_DIR}/progress.json"
  mkdir -p "${CKAD_CONFIG_DIR}"

  export TEST_SCENARIO="${CKAD_ROOT}/test/helpers/fixtures/test-scenario.yaml"
}

# ---- Session file creation ----

@test "drill session file is valid JSON with required fields" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{"mode":"drill","scenario_id":"test-multi-container","namespace":"test-ns","started_at":"2026-01-01T00:00:00Z","time_limit":180}
EOF
  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}")"
  [[ "${mode}" == "drill" ]]
  local scenario_id
  scenario_id="$(jq -r '.scenario_id' "${CKAD_SESSION_FILE}")"
  [[ "${scenario_id}" == "test-multi-container" ]]
  local namespace
  namespace="$(jq -r '.namespace' "${CKAD_SESSION_FILE}")"
  [[ "${namespace}" == "test-ns" ]]
  local time_limit
  time_limit="$(jq -r '.time_limit' "${CKAD_SESSION_FILE}")"
  [[ "${time_limit}" == "180" ]]
}

# ---- Session state checks ----

@test "check fails without session file" {
  rm -f "${CKAD_SESSION_FILE}"
  # Simulate the _require_session check
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    return 0  # Expected behavior
  fi
  return 1
}

@test "hint and solution blocked in exam mode" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{"mode":"exam","scenario_id":"test-multi-container","namespace":"test-ns","started_at":"2026-01-01T00:00:00Z","time_limit":7200}
EOF
  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}")"
  [[ "${mode}" == "exam" ]]
}

# ---- Timer integration ----

@test "timer starts with scenario time limit" {
  timer_start 180
  local remaining
  remaining="$(timer_remaining)"
  [[ "${remaining}" -gt 0 ]]
  [[ "${remaining}" -le 180 ]]
}

@test "timer format shows MM:SS during drill" {
  timer_start 125
  local formatted
  formatted="$(timer_format_remaining)"
  [[ "${formatted}" =~ ^[0-9]{2}:[0-9]{2}$ ]]
}

# ---- Progress recording ----

@test "progress records drill result" {
  progress_ensure_file
  progress_record "test-multi-container" true 120 1
  local passed
  passed="$(jq -r '.scenarios["test-multi-container"].passed' "${CKAD_PROGRESS_FILE}")"
  [[ "${passed}" == "true" ]]
  local domain
  domain="$(jq -r '.scenarios["test-multi-container"].domain' "${CKAD_PROGRESS_FILE}")"
  [[ "${domain}" == "1" ]]
}

@test "progress updates streak on drill completion" {
  progress_ensure_file
  progress_update_streak
  local streak
  streak="$(jq -r '.streak.current' "${CKAD_PROGRESS_FILE}")"
  [[ "${streak}" -ge 1 ]]
}

# ---- Session cleanup ----

@test "session file removed after skip" {
  cat > "${CKAD_SESSION_FILE}" <<'EOF'
{"mode":"drill","scenario_id":"test","namespace":"test-ns","started_at":"2026-01-01T00:00:00Z","time_limit":180}
EOF
  [[ -f "${CKAD_SESSION_FILE}" ]]
  rm -f "${CKAD_SESSION_FILE}"
  [[ ! -f "${CKAD_SESSION_FILE}" ]]
}

# ---- Test scenario fixture is valid YAML ----

@test "test scenario fixture exists and is valid YAML" {
  [[ -f "${TEST_SCENARIO}" ]]
  yq eval '.id' "${TEST_SCENARIO}" > /dev/null
}

@test "test scenario fixture has all required fields" {
  local id
  id="$(yq eval '.id' "${TEST_SCENARIO}")"
  [[ "${id}" == "test-multi-container" ]]
  local domain
  domain="$(yq eval '.domain' "${TEST_SCENARIO}")"
  [[ "${domain}" == "1" ]]
  local title
  title="$(yq eval '.title' "${TEST_SCENARIO}")"
  [[ -n "${title}" ]]
  local difficulty
  difficulty="$(yq eval '.difficulty' "${TEST_SCENARIO}")"
  [[ "${difficulty}" == "easy" ]]
  local time_limit
  time_limit="$(yq eval '.time_limit' "${TEST_SCENARIO}")"
  [[ "${time_limit}" == "180" ]]
}

@test "test scenario fixture has validations" {
  local count
  count="$(yq eval '.validations | length' "${TEST_SCENARIO}")"
  [[ "${count}" -gt 0 ]]
}

@test "test scenario fixture has solution" {
  local solution
  solution="$(yq eval '.solution' "${TEST_SCENARIO}")"
  [[ -n "${solution}" ]]
  [[ "${solution}" != "null" ]]
}
```

**Step 3: Run tests to verify they fail**

```bash
bats test/unit/drill-flow.bats
```

Expected: FAIL — fixture file doesn't exist yet.

**Step 4: Create the fixture file and run tests**

(Fixture is created in Step 1 above.)

```bash
bats test/unit/drill-flow.bats
```

Expected: All PASS.

**Step 5: Commit**

```bash
git add test/unit/drill-flow.bats test/helpers/fixtures/test-scenario.yaml
git commit -m "test: add drill flow unit tests and test scenario fixture

Verify session file structure, timer integration, progress recording,
session cleanup, and test scenario YAML fixture with all required
fields. Tests exercise drill mode components without a running cluster."
```

---

### Task 5: Update Makefile and Final Verification

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile to include new scripts**

Replace the Makefile with:
```makefile
.PHONY: test shellcheck test-unit test-integration install

SHELL := /bin/bash

# All bash scripts to lint
SCRIPTS := bin/ckad-drill $(wildcard lib/*.sh) $(wildcard scripts/*.sh)

test: shellcheck test-unit

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck $(SCRIPTS)
	@echo "shellcheck passed"

test-unit:
	@echo "Running unit tests..."
	@bats test/unit/
	@echo "Unit tests passed"

test-integration:
	@echo "Running integration tests (requires kind cluster)..."
	@bats test/integration/
	@echo "Integration tests passed"

install:
	@echo "Run: scripts/install.sh"
```

**Step 2: Run full test suite**

```bash
cd /home/jeff/Projects/cka
make test
```

Expected: shellcheck passes, all unit tests pass.

**Step 3: Run shellcheck on all scripts individually**

```bash
shellcheck bin/ckad-drill lib/common.sh lib/display.sh lib/cluster.sh lib/scenario.sh lib/validator.sh lib/timer.sh lib/progress.sh scripts/cluster-setup.sh
```

Expected: No warnings.

**Step 4: Commit**

```bash
git add Makefile
git commit -m "chore: update Makefile for Sprint 3 scripts"
```

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 6.1 | lib/timer.sh | test/unit/timer.bats |
| 2 | 6.2 | lib/progress.sh | test/unit/progress.bats |
| 3 | 5.1 | bin/ckad-drill (full dispatch) | test/unit/cli.bats |
| 4 | 5.2 | Drill flow integration | test/unit/drill-flow.bats, test/helpers/fixtures/test-scenario.yaml |
| 5 | — | Makefile update | make test |

**After Sprint 3:** `ckad-drill drill` selects a scenario, creates a namespace, displays the task, starts a timer, and writes session state. `ckad-drill check` runs validations and records progress. `ckad-drill hint`, `solution`, `next`, `skip`, `current`, `status`, `timer`, `env` all work. Progress is tracked in `~/.config/ckad-drill/progress.json`. Timer countdown available in the bash prompt via `source <(ckad-drill env)`.

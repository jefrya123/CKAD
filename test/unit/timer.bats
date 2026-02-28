#!/usr/bin/env bats
# test/unit/timer.bats — unit tests for lib/timer.sh

setup() {
  CKAD_DRILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export CKAD_DRILL_ROOT

  load "${CKAD_DRILL_ROOT}/test/helpers/bats-support/load"
  load "${CKAD_DRILL_ROOT}/test/helpers/bats-assert/load"

  # shellcheck source=lib/common.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/common.sh"

  # Use a temp dir for session file
  TEST_CONFIG_DIR="$(mktemp -d)"
  export CKAD_CONFIG_DIR="${TEST_CONFIG_DIR}"
  export CKAD_SESSION_FILE="${TEST_CONFIG_DIR}/session.json"

  # shellcheck source=lib/session.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/session.sh"
}

teardown() {
  rm -rf "${TEST_CONFIG_DIR}"
}

_load_timer() {
  # shellcheck source=lib/timer.sh
  # shellcheck disable=SC1091
  source "${CKAD_DRILL_ROOT}/lib/timer.sh"
}

# --- timer_env_output: content checks ---

@test "timer_env_output: contains PROMPT_COMMAND assignment" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_success
  assert_output --partial "PROMPT_COMMAND"
}

@test "timer_env_output: contains CKAD_DRILL_END export" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "CKAD_DRILL_END"
}

@test "timer_env_output: contains __ckad_drill_timer function definition" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "__ckad_drill_timer"
}

@test "timer_env_output: contains MM:SS printf format for countdown" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_success
  # The function body must contain the MM:SS format via printf '%02d:%02d'
  assert_output --partial "%02d:%02d"
}

@test "timer_env_output: contains [TIME UP] logic for expired time" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "TIME UP"
}

@test "timer_env_output: DOES NOT contain set -euo pipefail (TIMR-05 safety)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_success
  [[ "${output}" != *"set -euo pipefail"* ]]
}

@test "timer_env_output: DOES NOT contain set -e (TIMR-05 safety)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  [[ "${output}" != *"set -e"* ]]
}

@test "timer_env_output: contains save of original PS1 (CKAD_DRILL_ORIGINAL_PS1)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "CKAD_DRILL_ORIGINAL_PS1"
}

@test "timer_env_output: contains save of original PROMPT_COMMAND (Pitfall 4)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "CKAD_DRILL_ORIGINAL_PROMPT_COMMAND"
}

@test "timer_env_output: contains exam alias k=kubectl (DRIL-10)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "alias k=kubectl"
}

@test "timer_env_output: contains EDITOR=vim export (DRIL-10)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "EDITOR=vim"
}

@test "timer_env_output: contains kubectl completion source (DRIL-10)" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "kubectl completion"
}

# --- timer_env_reset_output ---

@test "timer_env_reset_output: contains restore of PS1 from CKAD_DRILL_ORIGINAL_PS1" {
  _load_timer
  run timer_env_reset_output
  assert_success
  assert_output --partial "CKAD_DRILL_ORIGINAL_PS1"
}

@test "timer_env_reset_output: contains restore of PROMPT_COMMAND from original" {
  _load_timer
  run timer_env_reset_output
  assert_output --partial "CKAD_DRILL_ORIGINAL_PROMPT_COMMAND"
}

@test "timer_env_reset_output: unsets CKAD_DRILL_END" {
  _load_timer
  run timer_env_reset_output
  assert_output --partial "unset CKAD_DRILL_END"
}

@test "timer_env_reset_output: unsets __ckad_drill_timer function" {
  _load_timer
  run timer_env_reset_output
  assert_output --partial "unset -f __ckad_drill_timer"
}

@test "timer_env_reset_output: DOES NOT contain set -euo pipefail" {
  _load_timer
  run timer_env_reset_output
  [[ "${output}" != *"set -euo pipefail"* ]]
}

# --- timer_env_output: zsh shell detection ---

@test "timer_env_output: contains ZSH_VERSION shell detection block" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_success
  assert_output --partial "ZSH_VERSION"
}

@test "timer_env_output: zsh branch contains add-zsh-hook precmd" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "add-zsh-hook precmd __ckad_drill_timer"
}

@test "timer_env_output: zsh branch contains autoload add-zsh-hook" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "autoload -Uz add-zsh-hook"
}

@test "timer_env_output: zsh branch contains kubectl completion zsh" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "kubectl completion zsh"
}

@test "timer_env_output: zsh branch saves CKAD_DRILL_ORIGINAL_PROMPT" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  run timer_env_output "${end_at}"
  assert_output --partial "CKAD_DRILL_ORIGINAL_PROMPT"
}

# --- timer_env_reset_output: zsh branch ---

@test "timer_env_reset_output: zsh branch contains add-zsh-hook -d precmd" {
  _load_timer
  run timer_env_reset_output
  assert_output --partial "add-zsh-hook -d precmd"
}

@test "timer_env_reset_output: zsh branch unsets CKAD_DRILL_ORIGINAL_PROMPT" {
  _load_timer
  run timer_env_reset_output
  assert_output --partial "CKAD_DRILL_ORIGINAL_PROMPT"
}

# --- timer_remaining ---

@test "timer_remaining: prints MM:SS format when time remains" {
  _load_timer
  local end_at
  end_at=$(( $(date +%s) + 180 ))
  SESSION_END_AT="${end_at}"
  run timer_remaining
  assert_success
  # Should match MM:SS pattern (e.g., 02:59)
  [[ "${output}" =~ ^[0-9]{2}:[0-9]{2}$ ]]
}

@test "timer_remaining: prints TIME UP when time has expired" {
  _load_timer
  SESSION_END_AT=$(( $(date +%s) - 10 ))
  run timer_remaining
  assert_success
  assert_output "TIME UP"
}

@test "timer_remaining: prints TIME UP when end_at equals now" {
  _load_timer
  SESSION_END_AT=$(date +%s)
  run timer_remaining
  assert_success
  assert_output "TIME UP"
}

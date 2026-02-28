# lib/timer.sh — PROMPT_COMMAND timer env output and reset
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2016  # Single-quoted strings intentionally emit unexpanded shell code
# Provides: timer_env_output, timer_env_reset_output, timer_remaining
# Dependencies: common.sh must be sourced (EXIT_OK)
# NOTE: Functions here emit shell code to be sourced by the USER's shell.
#       The emitted code must NOT contain set -euo pipefail (TIMR-05).

# timer_env_output END_AT
# Prints shell code that sets up the PROMPT_COMMAND countdown timer and exam environment.
# Caller should pipe to: source <(ckad-drill env)
# The emitted code is safe for user shells — no set -e, errors are silent.
timer_env_output() {
  local end_at="$1"

  printf '%s\n' \
    '# ckad-drill exam environment — source this into your shell' \
    '# Save originals for restoration later' \
    'export CKAD_DRILL_ORIGINAL_PS1="${PS1:-}"' \
    'export CKAD_DRILL_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"' \
    "export CKAD_DRILL_END=${end_at}" \
    '' \
    '# Timer function — called by PROMPT_COMMAND on every prompt' \
    '__ckad_drill_timer() {' \
    '  local remaining' \
    '  remaining=$(( CKAD_DRILL_END - $(date +%s) ))' \
    '  if (( remaining <= 0 )); then' \
    '    PS1="[TIME UP] ${CKAD_DRILL_ORIGINAL_PS1}"' \
    '  else' \
    "    PS1=\"[\$(printf '%02d:%02d' \$((remaining/60)) \$((remaining%60)))] \${CKAD_DRILL_ORIGINAL_PS1}\"" \
    '  fi' \
    '}' \
    "export PROMPT_COMMAND='__ckad_drill_timer'" \
    '' \
    '# Exam environment setup (DRIL-10)' \
    'alias k=kubectl' \
    'source <(kubectl completion bash) 2>/dev/null || true' \
    'export EDITOR=vim'
}

# timer_env_reset_output
# Prints shell code that restores the original shell state set up by timer_env_output.
# Caller should pipe to: source <(ckad-drill env --reset)
timer_env_reset_output() {
  printf '%s\n' \
    '# ckad-drill exam environment reset' \
    'export PS1="${CKAD_DRILL_ORIGINAL_PS1}"' \
    'export PROMPT_COMMAND="${CKAD_DRILL_ORIGINAL_PROMPT_COMMAND}"' \
    'unset CKAD_DRILL_END' \
    'unset CKAD_DRILL_ORIGINAL_PS1' \
    'unset CKAD_DRILL_ORIGINAL_PROMPT_COMMAND' \
    'unset -f __ckad_drill_timer'
}

# timer_remaining
# Reads SESSION_END_AT (set by session_read) and prints MM:SS or "TIME UP".
# Caller must have called session_read before invoking timer_remaining.
timer_remaining() {
  local remaining
  remaining=$(( SESSION_END_AT - $(date +%s) ))

  if (( remaining <= 0 )); then
    printf 'TIME UP\n'
  else
    printf '%02d:%02d\n' $(( remaining / 60 )) $(( remaining % 60 ))
  fi
}

# lib/common.sh — shared constants, paths, and output functions
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used by sourcing scripts

# Config and data directories (XDG-compliant)
CKAD_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/ckad-drill"
CKAD_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/ckad-drill"
CKAD_SESSION_FILE="${CKAD_CONFIG_DIR}/session.json"
CKAD_PROGRESS_FILE="${CKAD_CONFIG_DIR}/progress.json"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_NO_CLUSTER=2
readonly EXIT_NO_SESSION=3
readonly EXIT_PARSE_ERROR=4

# Kind cluster constants
readonly CKAD_CLUSTER_NAME="ckad-drill"
readonly CKAD_KUBE_CONTEXT="kind-ckad-drill"

# Color detection — true when stdout is a TTY
_color_enabled() {
  [[ -t 1 ]]
}

# info — informational message to stdout (blue)
info() {
  if _color_enabled; then
    printf '\033[0;34m[INFO]\033[0m %s\n' "$*"
  else
    printf '[INFO] %s\n' "$*"
  fi
}

# warn — warning message to stderr (yellow)
warn() {
  if _color_enabled; then
    printf '\033[0;33m[WARN]\033[0m %s\n' "$*" >&2
  else
    printf '[WARN] %s\n' "$*" >&2
  fi
}

# error — error message to stderr (red); does NOT exit — caller decides
error() {
  if _color_enabled; then
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2
  else
    printf '[ERROR] %s\n' "$*" >&2
  fi
}

# success — success message to stdout (green)
success() {
  if _color_enabled; then
    printf '\033[0;32m[OK]\033[0m %s\n' "$*"
  else
    printf '[OK] %s\n' "$*"
  fi
}

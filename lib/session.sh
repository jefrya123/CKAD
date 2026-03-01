# lib/session.sh — session JSON read/write/clear/require
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # SESSION_* globals are used by sourcing scripts
# Provides: session_write, session_read, session_clear, session_require
# Dependencies: common.sh must be sourced (provides EXIT_NO_SESSION, EXIT_OK, error())

# session_write MODE SCENARIO_ID SCENARIO_FILE NAMESPACE TIME_LIMIT
# Writes session.json to CKAD_SESSION_FILE with all session fields.
# Creates CKAD_CONFIG_DIR if it does not exist.
session_write() {
  local mode="$1"
  local scenario_id="$2"
  local scenario_file="$3"
  local namespace="$4"
  local time_limit="$5"

  local started_at
  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local end_at
  end_at=$(( $(date +%s) + time_limit ))

  mkdir -p "${CKAD_CONFIG_DIR}"

  jq -n \
    --arg mode "${mode}" \
    --arg scenario_id "${scenario_id}" \
    --arg scenario_file "${scenario_file}" \
    --arg namespace "${namespace}" \
    --arg started_at "${started_at}" \
    --argjson time_limit "${time_limit}" \
    --argjson end_at "${end_at}" \
    '{
      mode: $mode,
      scenario_id: $scenario_id,
      scenario_file: $scenario_file,
      namespace: $namespace,
      started_at: $started_at,
      time_limit: $time_limit,
      end_at: $end_at
    }' > "${CKAD_SESSION_FILE}"
}

# session_read
# Reads session.json and populates SESSION_* globals.
# Returns EXIT_NO_SESSION (3) if session file is missing.
session_read() {
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    return "${EXIT_NO_SESSION}"
  fi

  SESSION_MODE=$(jq -r '.mode // empty' "${CKAD_SESSION_FILE}")
  SESSION_SCENARIO_ID=$(jq -r '.scenario_id // empty' "${CKAD_SESSION_FILE}")
  SESSION_SCENARIO_FILE=$(jq -r '.scenario_file // empty' "${CKAD_SESSION_FILE}")
  SESSION_NAMESPACE=$(jq -r '.namespace // empty' "${CKAD_SESSION_FILE}")
  SESSION_STARTED_AT=$(jq -r '.started_at // empty' "${CKAD_SESSION_FILE}")
  SESSION_TIME_LIMIT=$(jq -r '.time_limit // empty' "${CKAD_SESSION_FILE}")
  SESSION_END_AT=$(jq -r '.end_at // empty' "${CKAD_SESSION_FILE}")

  return "${EXIT_OK}"
}

# session_clear
# Removes the session file. Safe to call even if file does not exist.
session_clear() {
  rm -f "${CKAD_SESSION_FILE}"
}

# session_require
# Calls session_read. If no session exists, prints error and exits EXIT_NO_SESSION.
session_require() {
  if ! session_read; then
    error "No active session. Run 'ckad-drill drill' or 'ckad-drill exam start' first."
    exit "${EXIT_NO_SESSION}"
  fi
}

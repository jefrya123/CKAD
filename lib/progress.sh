# lib/progress.sh — progress tracking for drill results
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used by sourcing scripts

# progress_init
# Creates progress.json with default schema if it does not already exist.
# Idempotent — safe to call multiple times.
progress_init() {
  mkdir -p "${CKAD_CONFIG_DIR}"
  if [[ ! -f "${CKAD_PROGRESS_FILE}" ]]; then
    jq -n '{
      "version": 1,
      "scenarios": {},
      "exams": [],
      "streak": {
        "current": 0,
        "last_date": ""
      }
    }' > "${CKAD_PROGRESS_FILE}"
  fi
}

# _progress_yesterday
# Outputs yesterday's date as YYYY-MM-DD. Cross-platform: GNU date, BSD date, epoch math.
_progress_yesterday() {
  date -d 'yesterday' +%Y-%m-%d 2>/dev/null && return
  date -v-1d +%Y-%m-%d 2>/dev/null && return
  # Epoch fallback
  date -u -d "@$(($(date +%s) - 86400))" +%Y-%m-%d 2>/dev/null && return
  # Pure bash epoch fallback
  printf '%s' "$(date -u +%Y-%m-%d)"
}

# _progress_update_streak PROGRESS_FILE TODAY
# Reads current streak from PROGRESS_FILE and computes updated streak value.
# Outputs updated jq expression for streak.
# Logic: same day → unchanged; yesterday → increment; gap → reset to 1.
_progress_update_streak() {
  local file="$1"
  local today="$2"

  local last_date current
  last_date=$(jq -r '.streak.last_date // ""' "${file}")
  current=$(jq -r '.streak.current // 0' "${file}")

  if [[ "${last_date}" == "${today}" ]]; then
    # Same day — no change
    printf '%d' "${current}"
  elif [[ "${last_date}" == "$(_progress_yesterday)" ]]; then
    # Consecutive day — increment
    printf '%d' $(( current + 1 ))
  else
    # Gap or first time — reset to 1
    printf '1'
  fi
}

# progress_record SCENARIO_ID DOMAIN PASSED TIME_SECONDS
# Records or upserts a drill result for SCENARIO_ID.
# - passed: "true" or "false"
# - Increments attempts on repeated calls
# - Updates streak
# Atomic write via temp file + mv.
progress_record() {
  local scenario_id="$1"
  local domain="$2"
  local passed="$3"
  local time_seconds="$4"

  # Ensure file exists
  progress_init

  local today
  today=$(date -u +%Y-%m-%d)

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Compute new attempts count
  local attempts
  attempts=$(jq -r --arg sid "${scenario_id}" \
    '.scenarios[$sid].attempts // 0' "${CKAD_PROGRESS_FILE}")
  attempts=$(( attempts + 1 )) || true

  # Compute streak
  local new_streak
  new_streak=$(_progress_update_streak "${CKAD_PROGRESS_FILE}" "${today}")

  # Atomic update via temp file
  local tmp_file
  tmp_file="${CKAD_PROGRESS_FILE}.tmp.$$"

  jq --arg sid "${scenario_id}" \
     --argjson domain "${domain}" \
     --argjson passed "${passed}" \
     --argjson time "${time_seconds}" \
     --argjson attempts "${attempts}" \
     --arg ts "${timestamp}" \
     --argjson streak "${new_streak}" \
     --arg today "${today}" \
    '.scenarios[$sid] = {
        "passed": $passed,
        "time_seconds": $time,
        "domain": $domain,
        "attempts": $attempts,
        "last_attempted": $ts
      }
    | .streak = {"current": $streak, "last_date": $today}' \
    "${CKAD_PROGRESS_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_PROGRESS_FILE}"
}

# progress_record_exam SCORE PASSED DOMAIN_RESULTS_JSON
# Appends an exam result to the .exams array in progress.json.
# SCORE: integer percentage (0-100)
# PASSED: "true" or "false"
# DOMAIN_RESULTS_JSON: JSON array of per-domain results from exam_grade
# Atomic write via temp file + mv.
progress_record_exam() {
  local score="$1"
  local passed="$2"
  local domain_results="$3"

  progress_init

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp_file
  tmp_file="${CKAD_PROGRESS_FILE}.tmp.$$"

  jq --argjson score "${score}" \
     --argjson passed "${passed}" \
     --arg ts "${timestamp}" \
     --argjson domains "${domain_results}" \
    '.exams += [{
      "date": $ts,
      "score": $score,
      "passed": $passed,
      "domains": $domains
    }]' \
    "${CKAD_PROGRESS_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_PROGRESS_FILE}"
}

# progress_read_domain_rates
# Outputs space-separated "DOMAIN:PERCENT" pairs for each domain with data.
# Example: "1:75 2:50 3:100"
progress_read_domain_rates() {
  local file="${CKAD_PROGRESS_FILE}"
  if [[ ! -f "${file}" ]]; then
    return 0
  fi

  jq -r '
    .scenarios
    | to_entries
    | group_by(.value.domain // 0)
    | map(
        . as $group |
        {
          domain: ($group[0].value.domain // 0),
          total: ($group | length),
          passed: ($group | map(select(.value.passed == true)) | length)
        }
        | select(.domain != 0)
        | "\(.domain):\(if .total == 0 then 0 else ((.passed * 100 / .total) | floor) end)"
      )
    | join(" ")
  ' "${file}"
}

# progress_read_streak
# Outputs the current streak count.
progress_read_streak() {
  local file="${CKAD_PROGRESS_FILE}"
  if [[ ! -f "${file}" ]]; then
    printf '0\n'
    return 0
  fi
  jq -r '.streak.current // 0' "${file}"
}

# progress_read_exam_history
# Outputs the exams array as JSON.
progress_read_exam_history() {
  local file="${CKAD_PROGRESS_FILE}"
  if [[ ! -f "${file}" ]]; then
    printf '[]\n'
    return 0
  fi
  jq -r '.exams // []' "${file}"
}

# progress_record_learn SCENARIO_ID
# Records learn completion in progress.json under .learn[SCENARIO_ID].
# Schema: .learn[$sid] = { completed: true, completed_at: $timestamp }
# Additive — does NOT change progress_init schema (.learn added on first record).
# Atomic write via temp file + mv.
progress_record_learn() {
  local scenario_id="$1"

  # Ensure file exists
  progress_init

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp_file
  tmp_file="${CKAD_PROGRESS_FILE}.tmp.$$"

  jq --arg sid "${scenario_id}" \
     --arg ts "${timestamp}" \
    '.learn[$sid] = { "completed": true, "completed_at": $ts }' \
    "${CKAD_PROGRESS_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_PROGRESS_FILE}"
}

# progress_learn_completed SCENARIO_ID
# Returns 0 if lesson is completed (.learn[SCENARIO_ID].completed == true), 1 if not.
# Returns 1 if progress.json is missing or lesson is absent.
progress_learn_completed() {
  local scenario_id="$1"

  if [[ ! -f "${CKAD_PROGRESS_FILE}" ]]; then
    return 1
  fi

  jq -e --arg sid "${scenario_id}" \
    '.learn[$sid].completed == true' \
    "${CKAD_PROGRESS_FILE}" > /dev/null 2>&1
}

# progress_recommend_weak_domain
# Outputs the domain number with the lowest pass rate.
# Outputs empty string if no data.
progress_recommend_weak_domain() {
  local file="${CKAD_PROGRESS_FILE}"
  if [[ ! -f "${file}" ]]; then
    return 0
  fi

  jq -r '
    .scenarios
    | to_entries
    | group_by(.value.domain // 0)
    | map(
        . as $group |
        {
          domain: ($group[0].value.domain // 0),
          total: ($group | length),
          passed: ($group | map(select(.value.passed == true)) | length)
        }
        | select(.domain != 0)
        | {
            domain: .domain,
            rate: (if .total == 0 then 0 else (.passed * 100 / .total) end)
          }
      )
    | if length == 0 then ""
      else (sort_by(.rate) | first | .domain | tostring)
      end
  ' "${file}"
}

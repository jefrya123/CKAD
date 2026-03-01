# lib/exam.sh — exam session engine: question selection, navigation, flagging, grading
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # EXAM_* globals are used by sourcing scripts
# Provides: exam_select_questions, exam_session_write, exam_session_read,
#           exam_list, exam_navigate, exam_flag, exam_grade,
#           exam_update_question_status,
#           exam_setup_all_namespaces, exam_cleanup_all_namespaces
# Dependencies: common.sh, session.sh, scenario.sh must be sourced first

# CKAD domain weights for 16 questions:
#   D1: 20% → 3  D2: 20% → 3  D3: 15% → 3  D4: 25% → 4  D5: 20% → 3
# (remainder +1 distributed to D3 to reach 16 total)
readonly _EXAM_DOMAIN_WEIGHTS="1:3 2:3 3:3 4:4 5:3"

# _exam_weight DOMAIN
# Outputs the target question count for DOMAIN (default 3 if unknown).
_exam_weight() {
  local domain="$1"
  local pair
  for pair in ${_EXAM_DOMAIN_WEIGHTS}; do
    if [[ "${pair%%:*}" == "${domain}" ]]; then
      echo "${pair##*:}"
      return
    fi
  done
  echo "3"
}

# exam_select_questions COUNT FILE...
# Selects COUNT scenario files weighted by CKAD domain percentages.
# Outputs selected file paths one per line.
exam_select_questions() {
  local target_count="$1"
  shift
  local -a all_files=("$@")

  if [[ "${#all_files[@]}" -eq 0 ]]; then
    return 0
  fi

  # Group files by domain
  declare -A domain_files
  local f
  for f in "${all_files[@]}"; do
    local dom
    dom=$(yq -r '.domain // empty' "${f}" 2>/dev/null)
    if [[ -z "${dom}" ]]; then
      continue
    fi
    if [[ -z "${domain_files[$dom]+x}" ]]; then
      domain_files[$dom]=""
    fi
    domain_files[$dom]+="${f}"$'\n'
  done

  # For each domain, pick min(target, available) files using shuf
  local -a selected=()
  local dom
  for dom in 1 2 3 4 5; do
    local target
    target=$(_exam_weight "${dom}")
    local dom_files="${domain_files[$dom]:-}"
    if [[ -z "${dom_files}" ]]; then
      continue
    fi

    # Build array of files for this domain
    local -a dom_arr=()
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      dom_arr+=("${line}")
    done <<< "${dom_files}"

    local pick_count="${#dom_arr[@]}"
    if [[ "${pick_count}" -gt "${target}" ]]; then
      pick_count="${target}"
    fi

    # Shuffle and pick
    local -a shuffled=()
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      shuffled+=("${line}")
    done < <(printf '%s\n' "${dom_arr[@]}" | shuf)

    local i
    for (( i=0; i<pick_count; i++ )); do
      selected+=("${shuffled[$i]}")
    done
  done

  # If we still have room and didn't hit target, fill from remaining files
  local current_count="${#selected[@]}"
  if [[ "${current_count}" -lt "${target_count}" ]]; then
    # Build a set of already-selected files
    declare -A already_selected
    for f in "${selected[@]}"; do
      already_selected[$f]=1
    done

    # Shuffle all files and pick extras not already selected
    while IFS= read -r f; do
      [[ -z "${f}" ]] && continue
      if [[ -z "${already_selected[$f]+x}" ]]; then
        selected+=("${f}")
        already_selected[$f]=1
        (( current_count++ )) || true
        if [[ "${current_count}" -ge "${target_count}" ]]; then
          break
        fi
      fi
    done < <(printf '%s\n' "${all_files[@]}" | shuf)
  fi

  # Shuffle the final selection (not sorted by domain) and output
  printf '%s\n' "${selected[@]}" | shuf
}

# exam_session_write END_AT FILE...
# Creates session.json with mode=exam, questions array, current_question=0.
# Each question entry: {id, file, namespace, domain, status:"pending", flagged:false}
exam_session_write() {
  local end_at="$1"
  shift
  local -a question_files=("$@")

  local started_at
  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  mkdir -p "${CKAD_CONFIG_DIR}"

  # Build questions JSON array
  local questions_json="["
  local first=true
  local f
  for f in "${question_files[@]}"; do
    local q_id q_namespace q_domain
    q_id=$(yq -r '.id // empty' "${f}" 2>/dev/null)
    q_namespace=$(yq -r '.namespace // empty' "${f}" 2>/dev/null)
    q_domain=$(yq -r '.domain // empty' "${f}" 2>/dev/null)

    # Fallback namespace to drill-<id>
    if [[ -z "${q_namespace}" && -n "${q_id}" ]]; then
      q_namespace="drill-${q_id}"
    fi

    local q_json
    q_json=$(jq -n \
      --arg id "${q_id}" \
      --arg file "${f}" \
      --arg namespace "${q_namespace}" \
      --argjson domain "${q_domain:-0}" \
      '{
        id: $id,
        file: $file,
        namespace: $namespace,
        domain: $domain,
        status: "pending",
        flagged: false
      }')

    if [[ "${first}" == "true" ]]; then
      questions_json+="${q_json}"
      first=false
    else
      questions_json+=",${q_json}"
    fi
  done
  questions_json+="]"

  local total_time_limit=$(( end_at - $(date +%s) ))

  local tmp_file
  tmp_file="${CKAD_SESSION_FILE}.tmp.$$"

  jq -n \
    --arg mode "exam" \
    --arg started_at "${started_at}" \
    --argjson end_at "${end_at}" \
    --argjson time_limit "${total_time_limit}" \
    --argjson current_question 0 \
    --argjson questions "${questions_json}" \
    '{
      mode: $mode,
      started_at: $started_at,
      end_at: $end_at,
      time_limit: $time_limit,
      current_question: $current_question,
      questions: $questions
    }' > "${tmp_file}" && mv "${tmp_file}" "${CKAD_SESSION_FILE}"
}

# exam_session_read
# Reads exam session.json, populates EXAM_* globals.
# Returns EXIT_NO_SESSION (3) if missing or mode != exam.
exam_session_read() {
  if [[ ! -f "${CKAD_SESSION_FILE}" ]]; then
    return "${EXIT_NO_SESSION}"
  fi

  local mode
  mode=$(jq -r '.mode // empty' "${CKAD_SESSION_FILE}")
  if [[ "${mode}" != "exam" ]]; then
    return "${EXIT_NO_SESSION}"
  fi

  SESSION_MODE="exam"
  EXAM_QUESTIONS=$(jq -c '.questions // []' "${CKAD_SESSION_FILE}")
  EXAM_CURRENT=$(jq -r '.current_question // 0' "${CKAD_SESSION_FILE}")
  EXAM_END_AT=$(jq -r '.end_at // 0' "${CKAD_SESSION_FILE}")
  EXAM_QUESTION_COUNT=$(jq -r '.questions | length' "${CKAD_SESSION_FILE}")

  EXAM_CURRENT_FILE=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${EXAM_CURRENT}" '.[$idx].file // empty')
  EXAM_CURRENT_NAMESPACE=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${EXAM_CURRENT}" '.[$idx].namespace // empty')

  return "${EXIT_OK}"
}

# exam_require
# Calls exam_session_read. If no exam session, prints error and exits EXIT_NO_SESSION.
exam_require() {
  if ! exam_session_read; then
    error "No active exam session. Run 'ckad-drill exam start' first."
    exit "${EXIT_NO_SESSION}"
  fi
}

# exam_update_question_status INDEX STATUS
# Updates .questions[INDEX].status atomically.
exam_update_question_status() {
  local index="$1"
  local status="$2"

  local tmp_file
  tmp_file="${CKAD_SESSION_FILE}.tmp.$$"

  jq --argjson idx "${index}" --arg status "${status}" \
    '.questions[$idx].status = $status' \
    "${CKAD_SESSION_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_SESSION_FILE}"
}

# exam_list
# Reads exam session, outputs formatted question list with status icons.
# Status icons: pending=[ ], passed=[+], failed=[x], flagged=[?]
# Current question marked with >
exam_list() {
  exam_session_read || return $?

  local total="${EXAM_QUESTION_COUNT}"
  local current="${EXAM_CURRENT}"

  local i
  for (( i=0; i<total; i++ )); do
    local q_id q_file q_domain q_status q_flagged q_title
    q_id=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].id // empty')
    q_file=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].file // empty')
    q_domain=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].domain // empty')
    q_status=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].status // "pending"')
    q_flagged=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].flagged // false')

    # Get title from YAML file
    q_title="${q_id}"
    if [[ -f "${q_file}" ]]; then
      q_title=$(yq -r '.title // empty' "${q_file}" 2>/dev/null || echo "${q_id}")
    fi
    [[ -z "${q_title}" ]] && q_title="${q_id}"

    # Status icon
    local icon
    case "${q_status}" in
      passed)  icon="[+]" ;;
      failed)  icon="[x]" ;;
      *)       icon="[ ]" ;;
    esac

    # Flagged overrides status icon display
    if [[ "${q_flagged}" == "true" ]]; then
      icon="[?]"
    fi

    # Current marker
    local marker=" "
    if [[ "${i}" -eq "${current}" ]]; then
      marker=">"
    fi

    printf '%s %2d. %s %s (D%s)\n' "${marker}" "$(( i + 1 ))" "${icon}" "${q_title}" "${q_domain}"
  done
}

# exam_navigate TARGET
# Changes current_question. TARGET: "next", "prev", or 1-based integer.
# Clamps at bounds — does not wrap.
exam_navigate() {
  local target="$1"

  exam_session_read || return $?

  local current="${EXAM_CURRENT}"
  local max=$(( EXAM_QUESTION_COUNT - 1 ))
  local new_index

  case "${target}" in
    next)
      new_index=$(( current + 1 ))
      ;;
    prev)
      new_index=$(( current - 1 ))
      ;;
    *)
      # 1-based integer → convert to 0-based
      new_index=$(( target - 1 ))
      ;;
  esac

  # Clamp
  if [[ "${new_index}" -lt 0 ]]; then
    new_index=0
  fi
  if [[ "${new_index}" -gt "${max}" ]]; then
    new_index="${max}"
  fi

  local tmp_file
  tmp_file="${CKAD_SESSION_FILE}.tmp.$$"

  jq --argjson idx "${new_index}" \
    '.current_question = $idx' \
    "${CKAD_SESSION_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_SESSION_FILE}"

  # Update globals
  EXAM_CURRENT="${new_index}"
  EXAM_CURRENT_FILE=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${new_index}" '.[$idx].file // empty')
  EXAM_CURRENT_NAMESPACE=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${new_index}" '.[$idx].namespace // empty')
}

# exam_flag
# Toggles flagged field on current question. Atomic write.
exam_flag() {
  exam_session_read || return $?

  local current="${EXAM_CURRENT}"
  local current_flagged
  current_flagged=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${current}" '.[$idx].flagged // false')

  local new_flagged
  if [[ "${current_flagged}" == "true" ]]; then
    new_flagged="false"
  else
    new_flagged="true"
  fi

  local tmp_file
  tmp_file="${CKAD_SESSION_FILE}.tmp.$$"

  jq --argjson idx "${current}" --argjson flagged "${new_flagged}" \
    '.questions[$idx].flagged = $flagged' \
    "${CKAD_SESSION_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${CKAD_SESSION_FILE}"
}

# exam_grade
# Computes per-domain scores and overall pass/fail.
# Outputs JSON: {score, passed, domains: [{domain, passed, total, percent}], questions: [{id, passed, flagged}]}
exam_grade() {
  exam_session_read || return $?

  jq -r '
    # Compute per-question pass/fail
    (.questions | map({
      id: .id,
      domain: (.domain | tostring),
      passed: (.status == "passed"),
      flagged: .flagged
    })) as $questions |

    # Per-domain breakdown
    ($questions | group_by(.domain) | map(
      . as $group |
      {
        domain: $group[0].domain,
        passed: ($group | map(select(.passed)) | length),
        total: ($group | length),
        percent: (
          if ($group | length) == 0 then 0
          else (($group | map(select(.passed)) | length) * 100 / ($group | length) | floor)
          end
        )
      }
    )) as $domains |

    # Overall score
    ($questions | length) as $total |
    ($questions | map(select(.passed)) | length) as $total_passed |
    (if $total == 0 then 0 else ($total_passed * 100 / $total | floor) end) as $score |

    {
      score: $score,
      passed: ($score >= 66),
      total_questions: $total,
      total_passed: $total_passed,
      domains: $domains,
      questions: ($questions | map({id: .id, passed: .passed, flagged: .flagged}))
    }
  ' "${CKAD_SESSION_FILE}"
}


# exam_setup_all_namespaces
# Creates a namespace for each question in the exam session.
exam_setup_all_namespaces() {
  exam_session_read || return $?

  local count=0
  local i
  for (( i=0; i<EXAM_QUESTION_COUNT; i++ )); do
    local ns
    ns=$(echo "${EXAM_QUESTIONS}" | jq -r --argjson idx "${i}" '.[$idx].namespace // empty')
    if [[ -n "${ns}" ]]; then
      kubectl create namespace "${ns}" 2>/dev/null || true
      (( count++ )) || true
    fi
  done

  info "Created ${count} exam namespaces"
}

# exam_cleanup_all_namespaces
# Deletes all question namespaces and clears the session file.
exam_cleanup_all_namespaces() {
  # Try to read session; if fails, still attempt cleanup from file directly
  if [[ -f "${CKAD_SESSION_FILE}" ]]; then
    local mode
    mode=$(jq -r '.mode // empty' "${CKAD_SESSION_FILE}" 2>/dev/null || echo "")
    if [[ "${mode}" == "exam" ]]; then
      local questions
      questions=$(jq -c '.questions // []' "${CKAD_SESSION_FILE}")
      local count
      count=$(echo "${questions}" | jq 'length')
      local i
      for (( i=0; i<count; i++ )); do
        local ns
        ns=$(echo "${questions}" | jq -r --argjson idx "${i}" '.[$idx].namespace // empty')
        if [[ -n "${ns}" ]]; then
          kubectl delete namespace "${ns}" --ignore-not-found=true 2>/dev/null || true
        fi
      done
    fi
  fi

  session_clear
}

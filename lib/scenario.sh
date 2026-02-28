# lib/scenario.sh — YAML scenario loading, discovery, filtering, namespace lifecycle
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # SCENARIO_* globals are used by sourcing scripts
# Provides: scenario_discover, scenario_load, scenario_filter, scenario_setup, scenario_cleanup
# Dependencies: common.sh must be sourced (provides info/warn/error/EXIT_PARSE_ERROR/EXIT_ERROR)

# _scenario_register_file FILE SEEN_ARRAY_NAMEREF
# Internal helper: validates ID, checks for duplicates, emits path if valid.
_scenario_register_file() {
  local file="$1"
  local -n _seen="$2"

  local id
  id=$(yq -r '.id // empty' "${file}")
  if [[ -z "${id}" ]]; then
    warn "Skipping ${file}: missing required field 'id'"
    return 0
  fi

  # Check for duplicate (SCEN-05)
  if printf '%s\n' "${_seen[@]+"${_seen[@]}"}" | grep -q "^${id}$"; then
    warn "Duplicate scenario ID '${id}' in ${file} — skipping (first-loaded wins)"
    return 0
  fi

  _seen+=("${id}")
  echo "${file}"
}

# scenario_discover [EXTERNAL_PATH]
# Outputs list of valid scenario file paths (one per line), built-in first then external.
# Warns and skips files with duplicate or missing IDs (SCEN-03, SCEN-04, SCEN-05).
scenario_discover() {
  local external_path="${1:-}"
  local -a seen_ids=()
  # shellcheck disable=SC2034  # seen_ids is passed by nameref to _scenario_register_file

  # Built-in scenarios from repo scenarios/ directory
  local scenarios_dir="${CKAD_DRILL_ROOT}/scenarios"
  if [[ -d "${scenarios_dir}" ]]; then
    while IFS= read -r -d '' file; do
      _scenario_register_file "${file}" seen_ids
    done < <(find "${scenarios_dir}" -name "*.yaml" -type f -print0 | sort -z)
  fi

  # External scenarios (SCEN-04)
  if [[ -n "${external_path}" && -d "${external_path}" ]]; then
    while IFS= read -r -d '' file; do
      _scenario_register_file "${file}" seen_ids
    done < <(find "${external_path}" -name "*.yaml" -type f -print0 | sort -z)
  fi
}

# scenario_load FILE
# Parses a scenario YAML file and exports all fields as SCENARIO_* globals.
# Returns EXIT_PARSE_ERROR if any required field is missing (SCEN-01).
scenario_load() {
  local file="$1"

  # Required fields — fail if any are missing
  local id domain title difficulty time_limit
  id=$(yq -r '.id // empty' "${file}")
  domain=$(yq -r '.domain // empty' "${file}")
  title=$(yq -r '.title // empty' "${file}")
  difficulty=$(yq -r '.difficulty // empty' "${file}")
  time_limit=$(yq -r '.time_limit // empty' "${file}")

  for field in id domain title difficulty time_limit; do
    if [[ -z "${!field}" ]]; then
      error "Scenario ${file}: missing required field '${field}'"
      return "${EXIT_PARSE_ERROR}"
    fi
  done

  # Namespace: scenario-defined or fallback to drill-<id> (ADR-06)
  local namespace
  namespace=$(yq -r '.namespace // empty' "${file}")
  if [[ -z "${namespace}" ]]; then
    namespace="drill-${id}"
  fi

  # Tags — check for helm tag (SCEN-06)
  local has_helm_tag=false
  if yq -r '.tags // [] | .[]' "${file}" 2>/dev/null | grep -q "^helm$"; then
    has_helm_tag=true
  fi

  # Export as globals for the calling context
  SCENARIO_ID="${id}"
  SCENARIO_DOMAIN="${domain}"
  SCENARIO_TITLE="${title}"
  SCENARIO_DIFFICULTY="${difficulty}"
  SCENARIO_TIME_LIMIT="${time_limit}"
  SCENARIO_NAMESPACE="${namespace}"
  SCENARIO_HAS_HELM="${has_helm_tag}"
  SCENARIO_FILE="${file}"
}

# scenario_filter FILE...
# Reads FILTER_DOMAIN and FILTER_DIFFICULTY env vars; outputs only matching file paths (SCEN-03).
scenario_filter() {
  local -a all_files=("$@")
  local domain_filter="${FILTER_DOMAIN:-}"
  local diff_filter="${FILTER_DIFFICULTY:-}"

  local file
  for file in "${all_files[@]+"${all_files[@]}"}"; do
    local domain difficulty
    domain=$(yq -r '.domain // empty' "${file}")
    difficulty=$(yq -r '.difficulty // empty' "${file}")

    if [[ -n "${domain_filter}" && "${domain}" != "${domain_filter}" ]]; then
      continue
    fi

    if [[ -n "${diff_filter}" && "${difficulty}" != "${diff_filter}" ]]; then
      continue
    fi

    echo "${file}"
  done
}

# scenario_setup FILE
# Loads scenario, checks Helm if tagged, creates namespace, runs setup commands (SCEN-02, SCEN-06).
scenario_setup() {
  local file="$1"
  scenario_load "${file}" || return $?

  # Helm check (SCEN-06)
  if [[ "${SCENARIO_HAS_HELM}" == "true" ]]; then
    if ! command -v helm &>/dev/null; then
      error "Scenario '${SCENARIO_ID}' requires Helm, which is not installed."
      info "Install Helm: https://helm.sh/docs/intro/install/"
      return "${EXIT_ERROR}"
    fi
  fi

  # Create namespace — idempotent, ignore AlreadyExists error
  info "Setting up namespace '${SCENARIO_NAMESPACE}'..."
  kubectl create namespace "${SCENARIO_NAMESPACE}" 2>/dev/null || true

  # Apply setup commands/manifest if present
  local setup_commands
  setup_commands=$(yq -r '.setup.commands // [] | .[]' "${file}" 2>/dev/null)
  if [[ -n "${setup_commands}" ]]; then
    local setup_manifest
    setup_manifest=$(yq -r '.setup.manifest // empty' "${file}")
    while IFS= read -r cmd; do
      if [[ "${cmd}" == "kubectl apply -f -" && -n "${setup_manifest}" ]]; then
        echo "${setup_manifest}" | kubectl apply -f - -n "${SCENARIO_NAMESPACE}"
      else
        eval "${cmd}"
      fi
    done <<< "${setup_commands}"
  fi
}

# scenario_cleanup
# Deletes the current scenario namespace. Safe to call even if setup was partial (SCEN-02).
scenario_cleanup() {
  local namespace="${SCENARIO_NAMESPACE:-}"
  if [[ -z "${namespace}" ]]; then
    return 0
  fi
  info "Cleaning up namespace '${namespace}'..."
  kubectl delete namespace "${namespace}" --ignore-not-found=true
}

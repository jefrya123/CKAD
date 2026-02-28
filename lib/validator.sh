# lib/validator.sh — validation engine with 10 typed kubectl checks
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# Dependencies: common.sh (warn), display.sh (pass, fail)
# ADR-07: No retry. Each check invokes kubectl exactly once.

# validator_run_checks FILE NAMESPACE
# Runs all validations defined in the scenario YAML file.
# Dispatches to _validator_* handlers based on check type.
# Calls pass() or fail() from display.sh for each result.
# Returns 0 if all checks pass, 1 if any check fails.
validator_run_checks() {
  local file="$1"
  local namespace="$2"

  local total passed failed
  total=0
  passed=0
  failed=0

  local count
  count=$(yq -r '.validations | length' "${file}")

  local i
  for ((i = 0; i < count; i++)); do
    local check_type
    check_type=$(yq -r ".validations[${i}].type" "${file}")

    case "${check_type}" in
      resource_exists)
        if _validator_resource_exists "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      resource_field)
        if _validator_resource_field "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      container_count)
        if _validator_container_count "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      container_image)
        if _validator_container_image "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      container_env)
        if _validator_container_env "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      volume_mount)
        if _validator_volume_mount "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      container_running)
        if _validator_container_running "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      label_selector)
        if _validator_label_selector "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      resource_count)
        if _validator_resource_count "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      command_output)
        if _validator_command_output "${file}" "${i}" "${namespace}"; then
          ((passed++)) || true
        else
          ((failed++)) || true
        fi
        ;;
      *)
        warn "Unknown check type '${check_type}' at index ${i} — skipping"
        ;;
    esac
    ((total++)) || true
  done

  printf '\nResults: %d passed, %d failed of %d checks\n' "${passed}" "${failed}" "${total}"

  [[ "${failed}" -eq 0 ]]
}

# _validator_resource_exists FILE IDX NAMESPACE
# PASS when `kubectl get <resource> -n <ns>` exits 0.
# FAIL with "(not found)" when exits non-zero.
_validator_resource_exists() {
  local file="$1" idx="$2" ns="$3"

  local check_name resource
  check_name=$(yq -r ".validations[${idx}].name // \"resource_exists_${idx}\"" "${file}")
  resource=$(yq -r ".validations[${idx}].resource" "${file}")

  if kubectl get "${resource}" -n "${ns}" >/dev/null 2>&1; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "exists" "(not found)"
    return 1
  fi
}

# _validator_resource_field FILE IDX NAMESPACE
# PASS when kubectl jsonpath output matches expected value.
# FAIL with expected vs actual.
_validator_resource_field() {
  local file="$1" idx="$2" ns="$3"

  local check_name resource jsonpath expected
  check_name=$(yq -r ".validations[${idx}].name // \"resource_field_${idx}\"" "${file}")
  resource=$(yq -r ".validations[${idx}].resource" "${file}")
  jsonpath=$(yq -r ".validations[${idx}].jsonpath" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local actual
  actual=$(kubectl get "${resource}" -n "${ns}" -o "jsonpath=${jsonpath}" 2>/dev/null)

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

# _validator_container_count FILE IDX NAMESPACE
# PASS when jq container count matches expected number.
# FAIL with count mismatch.
_validator_container_count() {
  local file="$1" idx="$2" ns="$3"

  local check_name pod expected
  check_name=$(yq -r ".validations[${idx}].name // \"container_count_${idx}\"" "${file}")
  pod=$(yq -r ".validations[${idx}].pod" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local actual
  actual=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
    | jq '.spec.containers | length')

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

# _validator_container_image FILE IDX NAMESPACE
# PASS when jq image for named container matches expected.
# FAIL with image mismatch.
_validator_container_image() {
  local file="$1" idx="$2" ns="$3"

  local check_name pod container expected
  check_name=$(yq -r ".validations[${idx}].name // \"container_image_${idx}\"" "${file}")
  pod=$(yq -r ".validations[${idx}].pod" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local actual
  actual=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
    | jq -r --arg name "${container}" \
        '.spec.containers[] | select(.name==$name) | .image')

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

# _validator_container_env FILE IDX NAMESPACE
# PASS when jq env var value for named container matches expected.
# FAIL with value mismatch.
_validator_container_env() {
  local file="$1" idx="$2" ns="$3"

  local check_name pod container env_var expected
  check_name=$(yq -r ".validations[${idx}].name // \"container_env_${idx}\"" "${file}")
  pod=$(yq -r ".validations[${idx}].pod" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  env_var=$(yq -r ".validations[${idx}].env_var" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local actual
  actual=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" --arg ename "${env_var}" \
        '.spec.containers[] | select(.name==$cname) | .env[] | select(.name==$ename) | .value')

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

# _validator_volume_mount FILE IDX NAMESPACE
# PASS when mount at path exists on named container.
# FAIL when not found.
_validator_volume_mount() {
  local file="$1" idx="$2" ns="$3"

  local check_name pod container mount_path
  check_name=$(yq -r ".validations[${idx}].name // \"volume_mount_${idx}\"" "${file}")
  pod=$(yq -r ".validations[${idx}].pod" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")
  mount_path=$(yq -r ".validations[${idx}].mount_path" "${file}")

  local actual
  actual=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" --arg mpath "${mount_path}" \
        '.spec.containers[] | select(.name==$cname) | .volumeMounts[] | select(.mountPath==$mpath) | .name')

  if [[ -n "${actual}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "mount at ${mount_path}" "(not found)"
    return 1
  fi
}

# _validator_container_running FILE IDX NAMESPACE
# PASS when container state has "running".
# FAIL with actual state. Uses `// []` fallback for null containerStatuses (Pitfall 3).
_validator_container_running() {
  local file="$1" idx="$2" ns="$3"

  local check_name pod container
  check_name=$(yq -r ".validations[${idx}].name // \"container_running_${idx}\"" "${file}")
  pod=$(yq -r ".validations[${idx}].pod" "${file}")
  container=$(yq -r ".validations[${idx}].container" "${file}")

  local is_running actual_state
  is_running=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
    | jq -r --arg cname "${container}" \
        '.status.containerStatuses // [] | .[] | select(.name==$cname) | .state | has("running")')

  if [[ "${is_running}" == "true" ]]; then
    pass "${check_name}"
    return 0
  else
    actual_state=$(kubectl get "pod/${pod}" -n "${ns}" -o json 2>/dev/null \
      | jq -r --arg cname "${container}" \
          '.status.containerStatuses // [] | .[] | select(.name==$cname) | .state | keys[0] // "unknown"' \
          2>/dev/null || echo "unknown")
    fail "${check_name}" "running" "${actual_state:-not running}"
    return 1
  fi
}

# _validator_label_selector FILE IDX NAMESPACE
# PASS when kubectl get with -l selector returns results.
# FAIL when none found.
_validator_label_selector() {
  local file="$1" idx="$2" ns="$3"

  local check_name kind selector
  check_name=$(yq -r ".validations[${idx}].name // \"label_selector_${idx}\"" "${file}")
  kind=$(yq -r ".validations[${idx}].kind" "${file}")
  selector=$(yq -r ".validations[${idx}].selector" "${file}")

  local output
  output=$(kubectl get "${kind}" -n "${ns}" -l "${selector}" --no-headers 2>/dev/null)

  if echo "${output}" | grep -q .; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "resources matching '${selector}'" "(none found)"
    return 1
  fi
}

# _validator_resource_count FILE IDX NAMESPACE
# PASS when resource count matches expected.
# FAIL with count mismatch. Empty output = 0 (not 1).
_validator_resource_count() {
  local file="$1" idx="$2" ns="$3"

  local check_name kind selector expected
  check_name=$(yq -r ".validations[${idx}].name // \"resource_count_${idx}\"" "${file}")
  kind=$(yq -r ".validations[${idx}].kind" "${file}")
  selector=$(yq -r ".validations[${idx}].selector" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local raw_output actual
  raw_output=$(kubectl get "${kind}" -n "${ns}" -l "${selector}" --no-headers 2>/dev/null)

  # Handle empty output: empty string → 0, not 1 (wc -l counts newlines)
  if [[ -z "${raw_output}" ]]; then
    actual=0
  else
    actual=$(printf '%s\n' "${raw_output}" | wc -l | tr -d ' ')
  fi

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

# _validator_command_output FILE IDX NAMESPACE
# Supports three modes:
#   contains: grep -qF (fixed string substring match)
#   matches:  grep -qE (extended regex match)
#   equals:   [[ == ]] (exact string match)
# FAIL shows actual output.
_validator_command_output() {
  local file="$1" idx="$2"
  # namespace not used for command_output but kept for consistent signature
  # shellcheck disable=SC2034
  local ns="$3"

  local check_name command mode expected
  check_name=$(yq -r ".validations[${idx}].name // \"command_output_${idx}\"" "${file}")
  command=$(yq -r ".validations[${idx}].command" "${file}")
  mode=$(yq -r ".validations[${idx}].mode" "${file}")
  expected=$(yq -r ".validations[${idx}].expected" "${file}")

  local actual
  # eval required for complex commands with pipes, redirects, etc.
  # shellcheck disable=SC2086
  actual=$(eval ${command} 2>/dev/null)

  local matched=false
  case "${mode}" in
    contains)
      if printf '%s' "${actual}" | grep -qF "${expected}"; then
        matched=true
      fi
      ;;
    matches)
      if printf '%s' "${actual}" | grep -qE "${expected}"; then
        matched=true
      fi
      ;;
    equals)
      if [[ "${actual}" == "${expected}" ]]; then
        matched=true
      fi
      ;;
    *)
      warn "Unknown command_output mode '${mode}' — defaulting to contains"
      if printf '%s' "${actual}" | grep -qF "${expected}"; then
        matched=true
      fi
      ;;
  esac

  if [[ "${matched}" == "true" ]]; then
    pass "${check_name}"
    return 0
  else
    fail "${check_name}" "${expected}" "${actual}"
    return 1
  fi
}

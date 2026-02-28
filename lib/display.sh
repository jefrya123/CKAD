# lib/display.sh — terminal output functions for validation results
# Sourced by scenario.sh and other lib files in Phase 2/3.
# shellcheck shell=bash
# Provides pass/fail/header functions for displaying scenario check results.
# Dependency: _color_enabled() must be available from common.sh (sourced by caller).

# pass CHECK_NAME
# Prints a green [PASS] line for a passing validation check.
pass() {
  local check_name="$1"
  if _color_enabled; then
    printf '  \033[0;32m[PASS]\033[0m %s\n' "${check_name}"
  else
    printf '  [PASS] %s\n' "${check_name}"
  fi
}

# fail CHECK_NAME EXPECTED ACTUAL
# Prints a red [FAIL] line with expected/actual detail for a failing check.
fail() {
  local check_name="$1"
  local expected="$2"
  local actual="$3"
  if _color_enabled; then
    printf '  \033[0;31m[FAIL]\033[0m %s\n' "${check_name}"
  else
    printf '  [FAIL] %s\n' "${check_name}"
  fi
  printf '    expected: %s\n' "${expected}"
  printf '    actual:   %s\n' "${actual}"
}

# header TEXT
# Prints bold text with a dash underline of matching length.
header() {
  local text="$1"
  local len="${#text}"
  local dashes
  dashes=$(printf '%*s' "${len}" '' | tr ' ' '-')
  if _color_enabled; then
    printf '\033[1m%s\033[0m\n' "${text}"
  else
    printf '%s\n' "${text}"
  fi
  printf '%s\n' "${dashes}"
}

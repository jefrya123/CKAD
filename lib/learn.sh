# lib/learn.sh — learn mode discovery, ordering, and lesson progression
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used by sourcing scripts
# shellcheck disable=SC2120  # learn_discover accepts optional EXTERNAL_PATH arg — callers omit it internally
# Provides: learn_discover, learn_list_domain, learn_show_intro, learn_next_lesson
# Dependencies: common.sh, scenario.sh, progress.sh must be sourced first

# _learn_difficulty_rank DIFFICULTY
# Maps difficulty to a sort rank: easy=1, medium=2, hard=3.
# Used for progressive ordering within domains.
_learn_difficulty_rank() {
  case "$1" in
    easy)   echo "1" ;;
    medium) echo "2" ;;
    hard)   echo "3" ;;
    *)      echo "9" ;;
  esac
}

# _learn_sort_files FILE...
# Takes file paths as arguments, outputs them sorted by domain ascending then
# difficulty rank ascending (easy→medium→hard). Progressive ordering.
_learn_sort_files() {
  local -a files=("$@")
  local -a decorated=()

  local f domain difficulty rank
  for f in "${files[@]+"${files[@]}"}"; do
    domain=$(yq -r '.domain // 0' "${f}")
    difficulty=$(yq -r '.difficulty // empty' "${f}")
    rank=$(_learn_difficulty_rank "${difficulty}")
    decorated+=("${domain} ${rank} ${f}")
  done

  # Sort by domain then rank (both numeric), strip prefix
  printf '%s\n' "${decorated[@]+"${decorated[@]}"}" \
    | sort -k1,1n -k2,2n \
    | while IFS= read -r line; do
        # Strip "DOMAIN RANK " prefix (two fields + spaces)
        echo "${line#* * }"
      done
}

# learn_discover [EXTERNAL_PATH]
# Discovers all scenarios with a non-empty learn_intro field.
# Outputs file paths sorted progressively (domain asc, difficulty easy→hard).
learn_discover() {
  local external_path="${1:-}"
  local -a learn_files=()

  local file
  while IFS= read -r file; do
    local intro
    intro=$(yq -r '.learn_intro // empty' "${file}" 2>/dev/null)
    if [[ -n "${intro}" ]]; then
      learn_files+=("${file}")
    fi
  done < <(scenario_discover "${external_path}")

  if [[ "${#learn_files[@]}" -eq 0 ]]; then
    return 0
  fi

  _learn_sort_files "${learn_files[@]}"
}

# learn_list_domain DOMAIN
# Lists all learn scenarios for DOMAIN with completion status.
# Prints "[x] title" for completed, "[ ] title" for incomplete.
# Outputs nothing if no learn scenarios exist for that domain.
learn_list_domain() {
  local domain="$1"

  local file id title
  # shellcheck disable=SC2119
  while IFS= read -r file; do
    local file_domain
    file_domain=$(yq -r '.domain // empty' "${file}")
    if [[ "${file_domain}" != "${domain}" ]]; then
      continue
    fi
    id=$(yq -r '.id // empty' "${file}")
    title=$(yq -r '.title // empty' "${file}")
    if progress_learn_completed "${id}"; then
      printf '[x] %s\n' "${title}"
    else
      printf '[ ] %s\n' "${title}"
    fi
  done < <(learn_discover)
}

# learn_show_intro FILE
# Outputs the learn_intro text from a scenario YAML file.
# Outputs empty string if no learn_intro field exists.
learn_show_intro() {
  local file="$1"
  yq -r '.learn_intro // empty' "${file}" 2>/dev/null
}

# learn_next_lesson DOMAIN
# Outputs the file path of the first uncompleted learn scenario in DOMAIN
# (in progressive order: easy→medium→hard).
# Outputs empty string if all lessons in that domain are completed or none exist.
learn_next_lesson() {
  local domain="$1"

  local file id
  # shellcheck disable=SC2119
  while IFS= read -r file; do
    local file_domain
    file_domain=$(yq -r '.domain // empty' "${file}")
    if [[ "${file_domain}" != "${domain}" ]]; then
      continue
    fi
    id=$(yq -r '.id // empty' "${file}")
    if ! progress_learn_completed "${id}"; then
      echo "${file}"
      return 0
    fi
  done < <(learn_discover)

  # All completed or none found — output empty string
  return 0
}

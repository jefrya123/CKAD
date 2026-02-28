---
status: diagnosed
phase: 03-cli-drill-mode
source: 03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md
started: 2026-02-28T23:10:00Z
updated: 2026-02-28T23:25:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Help output lists all subcommands
expected: Running `bin/ckad-drill` with no args prints help text listing all available commands: start, stop, reset, drill, check, hint, solution, current, next, skip, env, timer, status, validate-scenario
result: pass

### 2. Drill without cluster shows clear error
expected: Running `bin/ckad-drill drill` without a kind cluster prints an error message about the cluster not being available (EXIT_NO_CLUSTER)
result: pass
note: Cluster was available so drill started correctly; unit tests confirm error path when cluster absent

### 3. Check/hint/solution without active session show error
expected: Running `bin/ckad-drill check` (or hint, solution, current, next, skip, timer) without an active drill session prints an error about no active session
result: pass

### 4. Status with no progress data
expected: Running `bin/ckad-drill status` with no prior drill history prints "No drill results yet" or similar empty-state message
result: pass

### 5. Validate-scenario with no args shows error
expected: Running `bin/ckad-drill validate-scenario` with no file argument prints a usage error
result: pass

### 6. Env output contains exam aliases and timer
expected: Running `bin/ckad-drill env` (without sourcing) prints shell code containing: alias k=kubectl, PROMPT_COMMAND with countdown format, EDITOR=vim
result: pass

### 7. Drill session end-to-end (requires cluster)
expected: With a kind cluster running: `ckad-drill drill` picks a random scenario, sets up namespace, displays task card with scenario name/domain/difficulty/description and time limit. A session file is created.
result: pass

### 8. Check validates and records progress (requires cluster)
expected: After starting a drill, `ckad-drill check` runs validations against the cluster, prints pass/fail per check, and records the result in progress history
result: pass

### 9. Timer countdown in prompt (requires cluster)
expected: After `source <(ckad-drill env)`, the terminal prompt shows `[MM:SS]` countdown that updates. When time expires it shows `[TIME UP]`. `ckad-drill env --reset` restores original prompt.
result: issue
reported: "Timer didn't show in prompt. Uses PROMPT_COMMAND which is bash-only, user shell is zsh."
severity: major

### 10. Validate-scenario runs full lifecycle (requires cluster)
expected: `ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml` runs: parse scenario, create namespace, apply solution steps, run validations, cleanup namespace, report result. Namespace is cleaned up even on failure.
result: issue
reported: "Lifecycle ran (setup, validate, cleanup, report) but solution steps were not applied — all checks failed. Solution should be applied before validation."
severity: major

## Summary

total: 10
passed: 8
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Timer countdown appears in prompt after sourcing env output"
  status: failed
  reason: "User reported: Timer didn't show in prompt. Uses PROMPT_COMMAND which is bash-only, user shell is zsh."
  severity: major
  test: 9
  root_cause: "timer_env_output emits PROMPT_COMMAND (bash-only); zsh ignores it and uses precmd hooks instead"
  artifacts:
    - path: "lib/timer.sh"
      issue: "timer_env_output uses PROMPT_COMMAND exclusively, no zsh precmd support"
  missing:
    - "Detect shell (ZSH_VERSION/BASH_VERSION) and emit precmd hook for zsh, PROMPT_COMMAND for bash"
    - "timer_env_reset_output needs add-zsh-hook -d precmd path for zsh"
    - "kubectl completion line should emit zsh completion in zsh"
  debug_session: ""

- truth: "validate-scenario applies solution steps before running validation checks"
  status: failed
  reason: "User reported: Lifecycle ran (setup, validate, cleanup, report) but solution steps were not applied — all checks failed. Solution should be applied before validation."
  severity: major
  test: 10
  root_cause: "while IFS= read -r splits multi-line heredoc steps at newlines; eval receives incomplete heredoc lines; errors suppressed by || true"
  artifacts:
    - path: "bin/ckad-drill"
      issue: "_validate_single_scenario solution loop uses line-by-line read, incompatible with multi-line steps"
  missing:
    - "Use yq with null-delimited or index-based extraction to get each step as a complete block before eval"
    - "Remove or reduce || true suppression so solution application failures are visible"
  debug_session: ".planning/debug/validate-scenario-solution-not-applied.md"

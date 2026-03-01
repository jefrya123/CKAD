---
status: resolved
trigger: "validate-scenario does not apply solution before validation — all checks fail"
created: 2026-02-28T00:00:00Z
updated: 2026-02-28T23:55:00Z
---

## Current Focus

hypothesis: yq extracts multi-line heredoc steps as literal strings with embedded newlines, which eval cannot execute as valid shell (heredoc delimiter is never seen)
test: inspect what `yq -r '.solution.steps[]'` emits for a step containing a heredoc
expecting: the heredoc step collapses into a single line, so eval receives `kubectl apply -f - <<EOF ... EOF` with no real newlines, which the shell cannot parse as a heredoc
next_action: DONE — root cause confirmed by code and YAML inspection

## Symptoms

expected: solution steps applied to cluster before validator runs
actual: all validation checks fail — resources were never created
errors: all validator_run_checks checks return failure (resources not found)
reproduction: `bin/ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml`
started: feature was written but solution application is broken by design of yq extraction

## Eliminated

- hypothesis: solution application code is missing entirely
  evidence: lines 224-228 in bin/ckad-drill contain the while-read loop and eval — the code exists
  timestamp: 2026-02-28

- hypothesis: yq path `.solution.steps[]` is wrong for the YAML structure
  evidence: YAML uses `solution.steps` as a sequence — yq path is correct
  timestamp: 2026-02-28

## Evidence

- timestamp: 2026-02-28
  checked: bin/ckad-drill lines 224-228
  found: |
    while IFS= read -r step; do
      if [[ -n "${step}" ]]; then
        eval "${step}" 2>/dev/null || true
      fi
    done < <(yq -r '.solution.steps[]' "${file}" 2>/dev/null)
  implication: reads yq output line-by-line via `read -r`, so a multi-line step (the heredoc) is fed one line at a time — each line becomes a separate `eval` call

- timestamp: 2026-02-28
  checked: scenarios/domain-1/sc-multi-container-pod.yaml lines 36-53
  found: step 2 is a block scalar (`|`) containing a heredoc — it spans 15 lines including `<<EOF` and `EOF` delimiter
  implication: yq emits this as a multi-line string; the while-read loop splits it at each newline; eval gets "kubectl apply -f - <<EOF" as one call and then each subsequent line as separate evals — the heredoc is never complete

- timestamp: 2026-02-28
  checked: step 1 — `kubectl create namespace web-team --dry-run=client -o yaml | kubectl apply -f -`
  found: single-line, no heredoc — would work correctly with the current loop
  implication: single-line steps are fine; only multi-line heredoc steps are broken

- timestamp: 2026-02-28
  checked: the `eval "${step}" 2>/dev/null || true` suppression
  found: errors silenced with `2>/dev/null || true` — the heredoc parse failure is swallowed silently
  implication: the broken eval produces no visible error, which is why the bug is silent (looks like it ran but did nothing)

## Resolution

root_cause: >
  The solution-application loop in _validate_single_scenario (bin/ckad-drill lines 224-228)
  reads yq output with `while IFS= read -r step` — one LINE per iteration. Multi-line solution
  steps (the heredoc in step 2) are split at every newline, so eval receives "kubectl apply -f - <<EOF"
  as one call (missing the body and EOF delimiter), which silently fails because `2>/dev/null || true`
  suppresses the error. Step 1 (single-line) would succeed; step 2 (heredoc) always fails silently.

fix: NOT APPLIED (diagnose-only mode)
verification: NOT APPLIED
files_changed: []

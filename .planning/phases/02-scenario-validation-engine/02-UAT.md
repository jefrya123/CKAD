---
status: complete
phase: 02-scenario-validation-engine
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md]
started: 2026-02-28T21:30:00Z
updated: 2026-02-28T21:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Display pass/fail/header output
expected: pass() prints green [PASS], fail() prints red [FAIL] with expected/actual detail lines, header() prints bold text with dash underline
result: pass

### 2. Scenario YAML loading
expected: scenario_load parses required fields into SCENARIO_* globals, returns EXIT_PARSE_ERROR (4) on invalid files
result: pass

### 3. Scenario discovery
expected: scenario_discover finds YAML files from directories, returns one path per line, count matches files
result: pass

### 4. Scenario filtering by domain and difficulty
expected: scenario_filter outputs matching files when FILTER_DOMAIN/FILTER_DIFFICULTY match, outputs nothing when they don't
result: pass

### 5. Namespace create and cleanup
expected: scenario_setup creates namespace (kubectl get shows it), scenario_cleanup deletes it (kubectl returns NotFound)
result: pass

### 6. Duplicate scenario ID warning
expected: Two YAML files with same id — [WARN] message about duplicate, only first-loaded file kept
result: pass

### 7. Helm tag detection
expected: scenario_setup on helm-tagged scenario without helm installed shows error and fails
result: pass

### 8. Validator: all 10 check types against live cluster
expected: All 10 typed checks (resource_exists, resource_field, container_count, container_image, container_env, volume_mount, container_running, label_selector, resource_count, command_output) produce [PASS] against correctly configured resources
result: pass

### 9. Failed validation shows expected vs actual
expected: When check fails, output shows [FAIL] check_name with "expected:" and "actual:" lines
result: pass

### 10. Entry point sources all libraries
expected: bin/ckad-drill has source lines for all 5 libs (common, display, cluster, scenario, validator) in correct dependency order
result: pass

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0

## Gaps

[none]

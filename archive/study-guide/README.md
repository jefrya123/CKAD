# Archived Study Guide Content

This directory contains content from the original CKAD study guide that was
archived during the Phase 6 content migration (migrating from markdown scenarios
to YAML-based scenarios for ckad-drill).

## What Was Archived

### scenarios/
The original 31 markdown scenario files (`scenario-01-*.md` through `scenario-31-*.md`)
and the original scenarios/README.md. These have been superseded by YAML scenarios
in `scenarios/domain-*/`.

### domains/
The original domain tutorial content organized by domain:
- `01-design-build/` — Application Design & Build tutorials and exercises
- `02-deployment/` — Application Deployment tutorials and exercises
- `03-observability/` — Observability & Maintenance tutorials and exercises
- `04-config-security/` — Configuration & Security tutorials and exercises
- `05-networking/` — Services & Networking tutorials and exercises

Each domain contained `tutorial.md`, `exercises.md`, and supporting YAML examples.
The tutorial prose was used as the source for `learn_intro` fields in YAML scenarios.

### quizzes/
Domain-specific quiz files with multiple-choice questions. These are knowledge-recall
exercises and were not converted to YAML scenarios (which test cluster operations).

### troubleshooting/
Hands-on troubleshooting lab exercises in markdown format.

## Where to Find Content Now

**YAML scenarios for ckad-drill:** `scenarios/domain-*/`
- `sc-*.yaml` — Standard drill/exam scenarios (70 total)
- `debug-*.yaml` — Troubleshooting/break-fix scenarios
- `learn-*.yaml` — Learn-mode scenarios with concept text

**Reference content (still in place):**
- `speed-drills/` — kubectl aliases, one-liners, vim tips
- `cheatsheet.md` — kubectl quick reference
- `exam-tips/` — CKAD exam strategy and tips

## Git History

The original study guide content is preserved in git history. Use
`git log --follow -- domains/` or `git log --all -- scenarios/scenario-*.md`
to view the history of archived files.

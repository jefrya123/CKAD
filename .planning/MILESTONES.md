# Milestones: ckad-drill

## v1.0 — Foundation + Scenario Engine + CLI Drill Mode

**Completed:** 2026-03-01
**Phases:** 1, 2, 3, 3.1 (4 phases, 11 plans)
**Requirements:** 45/45 satisfied
**Tests:** 214 pass, 0 fail
**Audit:** PASSED (see v1.0-MILESTONE-AUDIT.md)

**What shipped:**
- Kind cluster management with exam-matched addons (Calico, ingress, metrics-server)
- YAML scenario engine with 10 typed validation checks + command_output escape hatch
- Full drill mode: drill/check/hint/solution/next/skip/current/env/timer/status
- PROMPT_COMMAND timer with bash/zsh support
- Additive-only progress tracking (per-domain pass rates, streaks, weak area recommendation)
- validate-scenario tool for content contributors
- Dev tooling: bats-core + shellcheck, dev-setup.sh

**Key decisions validated:**
- Pure bash (exam should feel like exam)
- Subcommand model (no TUI)
- Hybrid typed + raw validation
- Single-check no retry (ADR-07)
- PROMPT_COMMAND timer (ADR-10)

---
*Last updated: 2026-02-28*

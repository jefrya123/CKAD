# ckad-drill

## What This Is

A free, open-source terminal tool that runs CKAD exam-style scenarios against a real kind cluster, automatically validates your work with kubectl checks, and builds you up from guided exercises to full mock exams with ticking clocks. Pure bash — the trainer feels like the exam.

## Core Value

Unlimited, free, real-cluster CKAD practice with automated validation — no other tool combines all four.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Spin up/manage kind cluster with exam-matched addons (Calico, ingress, metrics-server)
- [ ] Load and parse YAML scenario files with yq
- [ ] Display scenario task description with ANSI-formatted terminal output
- [ ] Countdown timer via PROMPT_COMMAND integration
- [ ] Run validation checks (10 typed + command_output escape hatch) against live cluster
- [ ] Display pass/fail results with specific expected-vs-actual feedback
- [ ] Clean up scenario namespaces between drills
- [ ] Drill mode: single random/filtered scenario with subcommand-based interaction
- [ ] Exam mode: 15-20 weighted questions, 2-hour timer, navigation, flagging, 66% pass threshold
- [ ] Learn mode: progressive guided lessons with concept text and validated exercises
- [ ] Track progress per domain with additive-only JSON schema
- [ ] Show hints (disabled in exam mode)
- [ ] Show solutions after completion/skip (disabled in exam mode)
- [ ] Filter drills by domain and difficulty
- [ ] Recommend weak domains based on pass rates
- [ ] Question flagging and navigation in exam mode
- [ ] External scenario loading from user-provided directory
- [ ] Scenario validation tool for content contributors (validate-scenario subcommand)
- [ ] 70+ scenarios covering all 5 CKAD domains at launch
- [ ] Helm scenario support (optional dependency)

### Out of Scope

- Go/Bubble Tea TUI — pivoted to pure bash (exam should feel like exam)
- Real-time chat or multiplayer features
- CKA/CKS content packs — V2.0
- Multi-cluster context switching — V1.2
- Leaderboards — V2.0
- Mobile app
- WSL-specific testing — best-effort, Linux/macOS primary

## Context

- **Existing repo:** This repo (`/home/jeff/Projects/cka`) is currently a CKAD study guide with 31 scenarios, 5 domain tutorials (~5,400 lines), 12 troubleshooting labs, domain exercises (~2,200 lines), quizzes, speed drills, and a cheatsheet. All existing content will be archived to `archive/` and migrated to YAML scenario format.
- **Estimated migration yield:** 50+ scenarios from existing content before writing net-new.
- **Unified content model:** Learn, drill, and exam modes share the same scenario engine. A tutorial is just a scenario with `learn: true` and extra concept text.
- **BMAD artifacts:** PRD at `docs/prd.md`, architecture at `_bmad-output/planning-artifacts/architecture.md`, epics/stories at `_bmad-output/planning-artifacts/epics-and-stories.md`, sprint plan at `_bmad-output/sprint-plan.md`.
- **PRD drift:** PRD still references Go/Bubble Tea. Architecture doc is source of truth.

## Constraints

- **Tech stack**: Pure bash + kubectl + kind + Docker + yq + jq — no compiled language, no build step
- **Dependencies**: bash, Docker, kind, kubectl, yq, jq (Helm optional)
- **Platform**: Linux and macOS primary. WSL best-effort.
- **Validation speed**: <5 seconds per check run (single-check, no retry per ADR-07)
- **Cluster creation**: <60 seconds (kind only), <120 seconds (with addons)
- **Offline-first**: No network required after install
- **Testing**: bats-core for functional tests, shellcheck for static analysis
- **Exam fidelity**: Strict exam environment by default — only `k` alias + bash completion

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bash over Go | Exam is bash+kubectl; trainer should match | — Pending |
| Subcommand model (no TUI) | Real exam is one terminal, no app pane | — Pending |
| Hybrid typed + raw validation | Common checks easy, uncommon not blocked | — Pending |
| Scenario-defined namespaces | Realistic names like real exam | — Pending |
| PROMPT_COMMAND timer | Always visible, zero extra UI | — Pending |
| Additive-only progress schema | No migration logic, survives upgrades | — Pending |
| Single-check no retry | Exam doesn't retry; learn to verify your work | — Pending |
| Same repo, archive study guide | Preserves git history, transforms in place | — Pending |
| Worktrees for parallel sprints | Independent sprints can run simultaneously | — Pending |
| bats-core + shellcheck | Bash testing standard + static analysis | — Pending |
| Fat cluster (Calico+ingress+metrics) | Match real CKAD exam environment | — Pending |

---
*Last updated: 2026-02-28 after initialization*

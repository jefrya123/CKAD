# ckad-drill

## What This Is

A free, open-source terminal tool that runs CKAD exam-style scenarios against a real kind cluster, automatically validates your work with kubectl checks, and builds you up from guided exercises to full mock exams with ticking clocks. Pure bash — the trainer feels like the exam.

## Core Value

Unlimited, free, real-cluster CKAD practice with automated validation — no other tool combines all four.

## Current Milestone: v1.1 Ship It

**Goal:** Complete all remaining modes (exam, learn), migrate content library to 70+ scenarios, and ship with CI, install script, and docs.

**Target features:**
- Exam mode: 15-20 weighted questions, 2-hour timer, navigation, flagging, 66% pass threshold
- Learn mode: progressive guided lessons with concept text and validated exercises
- Content migration: convert 31 scenarios + 12 labs + tutorials to YAML (70+ total)
- Testing, CI, distribution: bats suite, CI pipeline, install script, README, CONTRIBUTING.md

## Requirements

### Validated

<!-- Shipped and confirmed valuable in v1.0 -->

- ✓ Spin up/manage kind cluster with exam-matched addons (Calico, ingress, metrics-server) — v1.0
- ✓ Load and parse YAML scenario files with yq — v1.0
- ✓ Display scenario task description with ANSI-formatted terminal output — v1.0
- ✓ Countdown timer via PROMPT_COMMAND integration — v1.0
- ✓ Run validation checks (10 typed + command_output escape hatch) against live cluster — v1.0
- ✓ Display pass/fail results with specific expected-vs-actual feedback — v1.0
- ✓ Clean up scenario namespaces between drills — v1.0
- ✓ Drill mode: single random/filtered scenario with subcommand-based interaction — v1.0
- ✓ Track progress per domain with additive-only JSON schema — v1.0
- ✓ Show hints (disabled in exam mode) — v1.0
- ✓ Show solutions after completion/skip (disabled in exam mode) — v1.0
- ✓ Filter drills by domain and difficulty — v1.0
- ✓ Recommend weak domains based on pass rates — v1.0
- ✓ External scenario loading from user-provided directory — v1.0
- ✓ Scenario validation tool for content contributors — v1.0
- ✓ Helm scenario support (optional dependency) — v1.0

### Active

<!-- Current scope for v1.1 -->

- [ ] Exam mode: 15-20 weighted questions, 2-hour timer, navigation, flagging, 66% pass threshold
- [ ] Question flagging and navigation in exam mode
- [ ] Learn mode: progressive guided lessons with concept text and validated exercises
- [ ] 70+ scenarios covering all 5 CKAD domains at launch
- [ ] Install script, CI pipeline, full test suite, README, CONTRIBUTING.md

### Out of Scope

- Go/Bubble Tea TUI — pivoted to pure bash (exam should feel like exam)
- Real-time chat or multiplayer features
- CKA/CKS content packs — V2.0
- Multi-cluster context switching — V1.2
- Leaderboards — V2.0
- Mobile app
- WSL-specific testing — best-effort, Linux/macOS primary

## Context

- **v1.0 shipped:** Foundation + scenario engine + drill mode (45 requirements, 214 tests, audit PASSED)
- **Existing repo:** Study guide with 31 scenarios, 5 domain tutorials (~5,400 lines), 12 troubleshooting labs, domain exercises (~2,200 lines), quizzes, speed drills, and a cheatsheet — to be migrated to YAML
- **Estimated migration yield:** 50+ scenarios from existing content before writing net-new
- **Unified content model:** Learn, drill, and exam modes share the same scenario engine
- **BMAD artifacts:** PRD at `docs/prd.md`, architecture at `_bmad-output/planning-artifacts/architecture.md`
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
| Bash over Go | Exam is bash+kubectl; trainer should match | ✓ Good |
| Subcommand model (no TUI) | Real exam is one terminal, no app pane | ✓ Good |
| Hybrid typed + raw validation | Common checks easy, uncommon not blocked | ✓ Good |
| Scenario-defined namespaces | Realistic names like real exam | ✓ Good |
| PROMPT_COMMAND timer | Always visible, zero extra UI | ✓ Good |
| Additive-only progress schema | No migration logic, survives upgrades | ✓ Good |
| Single-check no retry | Exam doesn't retry; learn to verify your work | ✓ Good |
| Same repo, archive study guide | Preserves git history, transforms in place | ✓ Good |
| Worktrees for parallel sprints | Independent sprints can run simultaneously | ✓ Good |
| bats-core + shellcheck | Bash testing standard + static analysis | ✓ Good |
| Fat cluster (Calico+ingress+metrics) | Match real CKAD exam environment | ✓ Good |

---
*Last updated: 2026-02-28 after milestone v1.1 start*

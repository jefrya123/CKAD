# ckad-drill

Free, open-source CKAD exam practice with real cluster validation.

[![CI](https://github.com/USER/ckad-drill/actions/workflows/ci.yml/badge.svg)](https://github.com/USER/ckad-drill/actions/workflows/ci.yml)

## What is this?

ckad-drill is a terminal-based CKAD exam trainer that runs your kubectl commands against a real [kind](https://kind.sigs.k8s.io/) cluster and validates your work automatically. It is pure bash — no GUI, no TUI, no build step — because the real CKAD exam is also a terminal.

Practice feels like the real exam: you get a task description, a namespace, a time limit, and you solve it with `kubectl`. When you are done, `ckad-drill check` validates your work with the same jsonpath checks the exam graders would use.

## Quick Start

Prerequisites: Docker, kubectl

```bash
# Install ckad-drill and its dependencies (kind, yq, jq)
curl -sSL https://raw.githubusercontent.com/USER/ckad-drill/main/scripts/install.sh | sh

# Create the practice cluster (one-time setup, ~3 minutes)
ckad-drill start

# Run a random drill scenario
ckad-drill drill

# Start the exam timer in your shell prompt
source <(ckad-drill env)

# Solve the task with kubectl, then check your work
ckad-drill check
```

## Features

- 70+ scenarios across all 5 CKAD exam domains
- Three practice modes: Drill, Learn, and Exam
- Automated validation with real kubectl checks against a live kind cluster
- Timer integrated into your shell prompt via PROMPT_COMMAND
- Progress tracking across sessions
- Works offline once the cluster images are pulled
- Pure bash — no runtime dependencies beyond kubectl and Docker

## Modes

### Drill Mode

Random practice scenarios. Filter by domain or difficulty:

```bash
ckad-drill drill                    # random scenario from any domain
ckad-drill drill --domain 2         # random from Domain 2 (Workloads)
ckad-drill drill --difficulty hard  # hard scenarios only
```

### Learn Mode

Progressive lessons ordered easy to medium to hard within each domain. Use this to build knowledge before drilling:

```bash
ckad-drill learn              # list available lessons
ckad-drill learn --domain 1   # start Domain 1 lessons in order
```

### Exam Mode

Weighted mock exam: 16 questions, 2-hour timer, 66% pass threshold — matching real CKAD weightings:

```bash
ckad-drill exam            # start a mock exam
ckad-drill exam list       # show all questions and status
ckad-drill exam next       # go to next question
ckad-drill exam flag       # flag current question for review
ckad-drill exam submit     # grade and submit your exam
```

## Commands

| Command | Description |
|---------|-------------|
| `ckad-drill start` | Create the kind cluster |
| `ckad-drill stop` | Delete the cluster |
| `ckad-drill reset` | Delete and recreate the cluster |
| `ckad-drill drill [--domain N] [--difficulty L]` | Start a random drill scenario |
| `ckad-drill check` | Validate your work for the current scenario |
| `ckad-drill hint` | Show a hint for the current scenario |
| `ckad-drill solution` | Show the reference solution |
| `ckad-drill next` | Move to the next scenario |
| `ckad-drill skip` | Skip the current scenario |
| `ckad-drill current` | Reprint the current scenario task |
| `ckad-drill learn` | List available lessons |
| `ckad-drill learn --domain N` | Start domain N lessons |
| `ckad-drill exam` | Start a mock exam |
| `ckad-drill exam list/next/prev/jump/flag/submit` | Exam navigation |
| `ckad-drill env` | Print timer setup (source this into your shell) |
| `ckad-drill env --reset` | Restore original shell prompt |
| `ckad-drill timer` | Show remaining time for current scenario |
| `ckad-drill status` | Show progress statistics |
| `ckad-drill validate-scenario FILE/DIR` | Validate scenario YAML files |

## Scenarios

Scenarios are organized by CKAD exam domain:

| Domain | Name | Description |
|--------|------|-------------|
| 1 | Application Design and Build | Multi-container pods, jobs, init containers, volumes |
| 2 | Application Deployment | Deployments, rolling updates, Helm, canary patterns |
| 3 | Application Observability and Maintenance | Probes, logs, resource limits, API deprecations |
| 4 | Application Environment, Configuration, and Security | ConfigMaps, Secrets, RBAC, security contexts |
| 5 | Services and Networking | Services, NetworkPolicies, Ingress |

Difficulty levels: `easy`, `medium`, `hard`

## Requirements

| Dependency | Required | Notes |
|-----------|----------|-------|
| bash | >= 4.0 | macOS ships with 3.2 — upgrade with `brew install bash` |
| Docker | any recent | Needed by kind for the cluster |
| kubectl | any recent | Your primary tool |
| kind | v0.25.0+ | Installed by `install.sh` |
| yq | v4.x | Installed by `install.sh` |
| jq | v1.7+ | Installed by `install.sh` |

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for full contributor instructions.

```bash
# Clone and set up dev environment
git clone https://github.com/USER/ckad-drill.git
cd ckad-drill
scripts/dev-setup.sh

# Run checks
make shellcheck
make test-unit

# Run full test suite (requires cluster)
ckad-drill start
make test
```

## License

MIT

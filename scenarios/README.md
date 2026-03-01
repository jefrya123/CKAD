# Scenarios

YAML-based scenarios for ckad-drill. Organized by domain.

## Domains

- `domain-1/` — Application Design & Build
- `domain-2/` — Application Deployment
- `domain-3/` — Observability & Maintenance
- `domain-4/` — Application Environment, Configuration & Security
- `domain-5/` — Services & Networking

## Scenario Types

- `sc-*.yaml` — Standard drill/exam scenarios
- `debug-*.yaml` — Troubleshooting scenarios (broken resource provided, user must fix)
- `learn-*.yaml` — Learn-mode scenarios (concept text + guided exercise)

## Scenario Counts

| Domain | sc- | debug- | learn- | Total |
|--------|-----|--------|--------|-------|
| domain-1 (Design & Build) | 8 | 2 | 4 | 14 |
| domain-2 (Deployment) | 8 | 2 | 4 | 14 |
| domain-3 (Observability) | 8 | 4 | 3 | 15 |
| domain-4 (Config & Security) | 8 | 2 | 3 | 13 |
| domain-5 (Services & Networking) | 8 | 3 | 3 | 14 |
| **Total** | **40** | **13** | **17** | **70** |

## Usage

Run a scenario in drill mode:
```bash
ckad-drill drill
```

Run in learn mode (shows concept text before exercises):
```bash
ckad-drill learn
```

Validate a specific scenario or all scenarios:
```bash
ckad-drill validate-scenario scenarios/domain-1/sc-multi-container-pod.yaml
ckad-drill validate-scenario scenarios/
```

## Schema

Each scenario YAML contains:
- `id` — Unique identifier
- `domain` — Domain number (1-5)
- `title` — Human-readable name
- `difficulty` — easy | medium | hard
- `time_limit` — Seconds allowed
- `namespace` — Kubernetes namespace to use
- `description` — What the user must accomplish
- `hint` — Guidance without giving away the solution
- `validations` — List of automated checks
- `solution.steps` — Commands that solve the scenario
- `learn_intro` — (learn- scenarios only) Concept text shown before the exercise

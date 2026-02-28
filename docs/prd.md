# Product Requirements Document: ckad-drill

## 1. Overview

**Product Name:** ckad-drill
**Version:** 1.0
**Last Updated:** 2026-02-28

### 1.1 Problem Statement

Preparing for the CKAD exam means practicing real Kubernetes tasks under time pressure against a real cluster. Today, your options are:

- **killer.sh** — 2 sessions for $36, not repeatable, no learning progression
- **Random GitHub repos** — static markdown with solutions you can peek at, no validation
- **Your own kind cluster** — you do the task but have no way to verify you got it right

There is no free, open-source tool that combines progressive learning with real-cluster validation under exam-like time constraints. You either learn theory without practice, or practice without feedback.

### 1.2 Solution

A standalone terminal tool that runs CKAD exam-style scenarios against a real kind cluster, automatically validates your work, and builds you up from guided exercises to full mock exams with ticking clocks.

### 1.3 Value Proposition

- **Free and open source** — unlimited practice, forever
- **Real cluster validation** — not YAML diffing, actual `kubectl` checks against live resources
- **Progressive difficulty** — tutorials → exercises → timed drills → mock exams
- **Single binary** — `go install` or download, spins up kind, zero config
- **Exam-realistic** — same constraints, same time pressure, same tools available

### 1.4 Target Users

| User | Need |
|------|------|
| CKAD candidates | Unlimited exam-like practice with real feedback |
| DevOps engineers learning k8s | Structured hands-on exercises with validation |
| Bootcamp/course instructors | Assign drills, students self-validate |
| CKA candidates (future) | Same tool, different content pack |

## 2. User Experience

### 2.1 Core Flow

```
ckad-drill start          # Ensures kind cluster is running, launches TUI
ckad-drill learn           # Progressive tutorials with inline exercises
ckad-drill drill           # Single timed scenario, random or by domain
ckad-drill drill --domain 4  # Drill from specific domain
ckad-drill exam            # Full mock exam (15-20 questions, 2 hours)
ckad-drill exam --time 60m # Shorter practice exam
ckad-drill status          # Show progress across domains
```

### 2.2 Modes

#### Learn Mode
Progressive, guided lessons organized by CKAD domain. Each lesson:
1. Explains the concept briefly (why it exists, how it works)
2. Shows a reference example
3. Presents 2-3 inline exercises with increasing difficulty
4. Auto-validates each exercise before moving on
5. Tracks completion per lesson

The user works in their own terminal — the TUI shows the task and timer on one side while they use kubectl in their shell.

#### Drill Mode
Single scenarios with a time limit (3-8 minutes each, like the real exam). Flow:
1. Display task description and time limit
2. Timer starts counting down
3. User works in their terminal using kubectl
4. User presses "Check" (or hotkey) when done
5. Tool runs validation checks against the cluster
6. Shows pass/fail with specific feedback on what was wrong
7. Optionally shows the solution
8. Cleans up resources for next drill

Drills can be:
- Random across all domains
- Filtered by domain (weighted by exam weights)
- Filtered by difficulty (easy/medium/hard)
- Filtered by weak areas (domains with lowest scores)

#### Exam Mode
Simulates the real CKAD exam:
- 15-20 questions drawn from all domains (weighted by exam percentages)
- 2-hour countdown timer (configurable)
- Questions displayed one at a time with navigation (next/prev/flag)
- No hints or solutions during the exam
- Can flag questions to revisit
- Scoring at the end with per-domain breakdown
- Pass/fail threshold (66%)

### 2.3 Validation System

Each scenario has a validation spec — a set of checks run against the cluster:

```yaml
validations:
  - type: resource_exists
    resource: pod/web-logger
    namespace: default
  - type: container_count
    resource: pod/web-logger
    expected: 2
  - type: container_image
    resource: pod/web-logger
    container: nginx
    expected: "nginx"
  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /var/log/nginx
    volume_type: emptyDir
  - type: container_running
    resource: pod/web-logger
    container: logger
  - type: command_output
    command: "kubectl exec web-logger -c logger -- cat /proc/1/cmdline"
    contains: "tail"
```

Validation types needed for V1:
- `resource_exists` — does the resource exist in the right namespace?
- `resource_field` — check any field via jsonpath (catch-all)
- `container_count` — right number of containers in a pod
- `container_image` — correct image used
- `container_env` — env var exists with correct value
- `volume_mount` — volume mounted at correct path
- `container_running` — container is in Running state
- `command_output` — run a command and check output contains/matches expected
- `label_selector` — resource has expected labels
- `resource_count` — right number of resources matching a selector (e.g., 3 replicas)

### 2.4 TUI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ckad-drill                          ⏱ 04:32 remaining     │
│  Domain 1: Application Design & Build    Drill 7/31        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Create a pod named `web-logger` in namespace `default`:    │
│                                                             │
│  1. Container `nginx` using image `nginx`, port 80          │
│  2. Sidecar `logger` using `busybox` running:               │
│     tail -f /var/log/nginx/access.log                       │
│  3. Both containers share an emptyDir at /var/log/nginx     │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [c] Check  [h] Hint  [s] Skip  [n] Next  [q] Quit        │
│                                                             │
│  ✅ pod/web-logger exists                                   │
│  ✅ 2 containers found                                      │
│  ✅ nginx container image correct                           │
│  ❌ logger container: expected command contains "tail"       │
│     got: "sleep 3600"                                       │
└─────────────────────────────────────────────────────────────┘
```

The TUI runs in one terminal pane. The user has their regular terminal alongside it (or uses tmux/split). They run kubectl commands normally — ckad-drill just validates.

### 2.5 Progress Tracking

```
┌─────────────────────────────────────────────────────────────┐
│  CKAD Progress                                              │
├─────────────────────────────────────────────────────────────┤
│  Domain 1: Design & Build (20%)     ████████░░  14/20  80% │
│  Domain 2: Deployment (20%)         ██████░░░░   9/15  60% │
│  Domain 3: Observability (15%)      ████░░░░░░   5/12  42% │
│  Domain 4: Config & Security (25%)  ███░░░░░░░   4/18  22% │
│  Domain 5: Networking (20%)         ██░░░░░░░░   3/16  19% │
├─────────────────────────────────────────────────────────────┤
│  Mock Exams: 2 taken, avg 58%  (need 66% to pass)          │
│  Weakest: Domain 4 — recommend: ckad-drill drill -d 4      │
│  Streak: 3 days                                             │
└─────────────────────────────────────────────────────────────┘
```

Progress is stored locally in `~/.config/ckad-drill/progress.json`.

## 3. Content Structure

### 3.1 Scenario Format

Each scenario is a YAML file:

```yaml
id: sc-01-multi-container-pod
domain: 1
title: Multi-Container Pod with Shared Volume
difficulty: easy
time_limit: 180  # seconds
weight: 1  # for exam question selection
tags: [pod, sidecar, volume, emptyDir]

description: |
  Create a pod named `web-logger` in the `default` namespace with:

  1. A container named `nginx` using image `nginx` that serves on port 80
  2. A sidecar container named `logger` using image `busybox` that runs:
     tail -f /var/log/nginx/access.log
  3. Both containers share an emptyDir volume mounted at /var/log/nginx

hint: |
  Start with: kubectl run web-logger --image=nginx --dry-run=client -o yaml > pod.yaml
  Then add the second container and shared volume.

setup:
  # Commands to run before the scenario (optional)
  - kubectl create namespace default 2>/dev/null || true

cleanup:
  # Commands to run after the scenario
  - kubectl delete pod web-logger --ignore-not-found

validations:
  - type: resource_exists
    resource: pod/web-logger
  - type: container_count
    resource: pod/web-logger
    expected: 2
  - type: container_image
    resource: pod/web-logger
    container: nginx
    expected: "nginx"
  - type: container_image
    resource: pod/web-logger
    container: logger
    expected: "busybox"
  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /var/log/nginx
  - type: volume_mount
    resource: pod/web-logger
    container: logger
    mount_path: /var/log/nginx
  - type: command_output
    command: "kubectl get pod web-logger -o jsonpath='{.spec.volumes[0].emptyDir}'"
    expected: "{}"

solution: |
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: web-logger
  spec:
    containers:
    - name: nginx
      image: nginx
      ports:
      - containerPort: 80
      volumeMounts:
      - name: logs
        mountPath: /var/log/nginx
    - name: logger
      image: busybox
      command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
      volumeMounts:
      - name: logs
        mountPath: /var/log/nginx
    volumes:
    - name: logs
      emptyDir: {}
  ```
```

### 3.2 Content by Domain (V1)

Seeded from existing repo content, expanded with new scenarios:

| Domain | Exam Weight | Learn Lessons | Drills | Target |
|--------|-------------|---------------|--------|--------|
| 1. Design & Build | 20% | 5 lessons | 15+ | Pods, multi-container, init, jobs, cronjobs, PVCs |
| 2. Deployment | 20% | 4 lessons | 12+ | Deployments, rollouts, Helm, scaling, canary |
| 3. Observability | 15% | 3 lessons | 10+ | Probes, logging, debugging, monitoring |
| 4. Config & Security | 25% | 5 lessons | 18+ | ConfigMaps, Secrets, RBAC, SecurityContext, resources, quotas |
| 5. Networking | 20% | 4 lessons | 15+ | Services, Ingress, NetworkPolicy, DNS |
| **Total** | **100%** | **21 lessons** | **70+ drills** | |

### 3.3 Content Contribution

Scenarios are just YAML files in a `scenarios/` directory. Community can contribute:
- New scenarios via PR
- Validation is testable: `ckad-drill validate-scenario scenario.yaml` runs the scenario setup, applies the solution, runs validations, confirms they pass

## 4. Technical Architecture

### 4.1 Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Go | Single binary, k8s ecosystem native, fast |
| TUI | Bubble Tea (charmbracelet) | Best Go TUI framework, battle-tested |
| Cluster | kind | Lightweight, fast to create, standard for k8s testing |
| K8s client | client-go | Official Go client, direct API access for validation |
| Content | YAML files | Embedded in binary + external directory for custom scenarios |
| Progress | JSON file | Simple, no database needed |

### 4.2 System Components

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   TUI Layer  │────▶│  Scenario    │────▶│  Validation  │
│  (Bubble Tea)│     │  Engine      │     │  Engine      │
└──────────────┘     └──────────────┘     └──────────────┘
                            │                     │
                     ┌──────┴──────┐        ┌─────┴──────┐
                     │  Content    │        │  client-go  │
                     │  Loader     │        │  (k8s API)  │
                     └─────────────┘        └────────────┘
                            │                     │
                     ┌──────┴──────┐        ┌─────┴──────┐
                     │ YAML files  │        │ kind cluster│
                     │ (embedded)  │        │             │
                     └─────────────┘        └────────────┘
```

- **TUI Layer** — Renders scenarios, timer, progress. Handles keyboard input.
- **Scenario Engine** — Loads scenarios, manages lifecycle (setup → run → validate → cleanup), tracks state.
- **Validation Engine** — Runs validation checks against cluster via client-go. Returns structured pass/fail results.
- **Content Loader** — Reads embedded YAML scenarios + any user-provided external scenarios.

### 4.3 Cluster Management

```
ckad-drill start     # Creates kind cluster "ckad-drill" if not exists
ckad-drill stop      # Deletes the kind cluster
ckad-drill reset     # Deletes and recreates cluster (clean slate)
```

Kind cluster config includes:
- Single control-plane node (sufficient for CKAD scenarios)
- Ingress controller pre-installed (nginx)
- Metrics server pre-installed (for HPA scenarios)
- Default StorageClass configured (for PVC scenarios)

Cluster creation takes ~30 seconds. The tool detects if cluster already exists and reuses it.

### 4.4 Scenario Lifecycle

```
1. Load scenario YAML
2. Run setup commands (create namespaces, prerequisite resources)
3. Display task to user, start timer
4. User works in their terminal (kubectl, vim, etc.)
5. User triggers "Check"
6. Run validations via client-go
7. Display results (pass/fail per check)
8. If all pass OR user skips → run cleanup commands
9. Record result in progress file
10. Load next scenario or return to menu
```

### 4.5 Embedded vs External Content

Scenarios are embedded in the binary using Go's `embed` package. This means:
- `go install` gives you everything — no separate content download
- Custom scenarios can be added to `~/.config/ckad-drill/scenarios/`
- External scenarios override embedded ones by ID

## 5. Requirements

### 5.1 Functional Requirements

| ID | Requirement | Priority |
|----|------------|----------|
| FR-01 | Spin up/manage kind cluster automatically | Must |
| FR-02 | Load and parse YAML scenario files | Must |
| FR-03 | Display scenario task description in TUI | Must |
| FR-04 | Countdown timer with configurable duration | Must |
| FR-05 | Run validation checks against live cluster | Must |
| FR-06 | Display pass/fail results with specific feedback | Must |
| FR-07 | Clean up resources between scenarios | Must |
| FR-08 | Drill mode: single random/filtered scenario | Must |
| FR-09 | Exam mode: multi-question timed session | Must |
| FR-10 | Learn mode: progressive guided lessons | Must |
| FR-11 | Track progress per domain and overall | Must |
| FR-12 | Show hints (optional, disabled in exam mode) | Must |
| FR-13 | Show solution after completion/skip | Must |
| FR-14 | Filter drills by domain, difficulty | Should |
| FR-15 | Recommend weak domains based on scores | Should |
| FR-16 | Question flagging and navigation in exam mode | Should |
| FR-17 | Custom scenario loading from external directory | Should |
| FR-18 | Scenario validation tool for content contributors | Could |
| FR-19 | Export progress/results as JSON/markdown | Could |
| FR-20 | Helm scenarios (requires Helm installed) | Should |

### 5.2 Non-Functional Requirements

| ID | Requirement | Target |
|----|------------|--------|
| NFR-01 | Single binary, no runtime dependencies (except kind + docker) | Must |
| NFR-02 | Cluster creation under 60 seconds | Should |
| NFR-03 | Validation check execution under 5 seconds | Must |
| NFR-04 | Works on Linux, macOS, Windows (WSL) | Must |
| NFR-05 | Scenarios embedded — no network needed after install | Must |
| NFR-06 | 70+ scenarios covering all 5 CKAD domains at launch | Should |
| NFR-07 | Progress data survives tool upgrades | Must |

### 5.3 Dependencies

| Dependency | Required | Notes |
|-----------|----------|-------|
| Docker | Yes | Required by kind |
| kind | Yes | Auto-install or require pre-installed |
| kubectl | Yes | User must have kubectl (exam tool) |
| Helm | Optional | Only for Helm-specific scenarios |

## 6. Release Plan

### V1.0 — MVP

- kind cluster management (start/stop/reset)
- Scenario engine with YAML-based content
- Validation engine with core check types
- Drill mode (single timed scenarios)
- Exam mode (full mock exam)
- Basic TUI with timer and results
- 40+ scenarios across all domains
- Progress tracking
- `go install` distribution

### V1.1 — Learn Mode

- Progressive tutorial content integrated into TUI
- Guided exercises with validation
- Domain completion tracking

### V1.2 — Polish

- Weak-area recommendations
- Difficulty filtering
- Question flagging in exam mode
- Export results
- Community scenario contributions guide

### V2.0 — Expansion

- CKA content pack
- CKS content pack
- Multi-node cluster scenarios (for CKA node troubleshooting)
- Scenario editor/builder
- Leaderboards (optional, opt-in)

## 7. Success Metrics

| Metric | Target |
|--------|--------|
| GitHub stars (6 months) | 500+ |
| Scenarios at launch | 40+ |
| Community-contributed scenarios (6 months) | 20+ |
| User-reported pass rate improvement | Anecdotal positive feedback |
| Time to first drill (install → running) | Under 3 minutes |

## 8. Competitive Landscape

| Tool | Real Cluster | Free | Unlimited | Progressive | Offline |
|------|-------------|------|-----------|-------------|---------|
| killer.sh | Yes | No ($36) | No (2 sessions) | No | No |
| kodekloud | Yes | No (subscription) | Yes | Yes | No |
| CKAD-exercises (GitHub) | No | Yes | Yes | No | Yes |
| **ckad-drill** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |

The gap: no tool is free, unlimited, progressive, AND validates against a real cluster. ckad-drill fills that gap.

## 9. Open Questions

1. **Auto-install kind?** — Should the tool auto-download kind if not found, or just error with install instructions?
2. ~~**Namespace isolation**~~ — **Decision: own namespace per scenario.** Forces namespace practice (switching context, creating resources in specific namespaces) which mirrors the real exam. Scenarios specify their target namespace; some may use multiple.
3. **Scenario difficulty calibration** — How to determine easy/medium/hard? Time-based? Concept count? Community voting?
4. **Helm dependency** — Include Helm scenarios in V1 or defer? (Helm is ~5% of CKAD)
5. **Name** — `ckad-drill`? `kube-drill`? `k8s-exam`? Something catchier?

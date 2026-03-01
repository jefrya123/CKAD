# Sprint 6: Content Migration (Second Batch) & Learn Mode — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate domain exercises (~2,200 lines), quizzes, speed drills, and cheatsheet into ckad-drill format. Implement learn mode (`ckad-drill learn`) using the same scenario engine with `learn: true` scenarios.

**Architecture:** Learn mode uses the unified content model — learn scenarios are regular scenarios with `learn: true` and a `concept_text` field. Quiz questions that are practical kubectl tasks become YAML scenarios; knowledge-only questions go to `content/reference/`. Speed drills and cheatsheet are preserved as reference markdown. See `_bmad-output/planning-artifacts/architecture.md` for full ADRs.

**Tech Stack:** Bash, yq, jq, bats-core, shellcheck

**Key conventions (from architecture doc):**
- Scenario YAML: `snake_case` fields, descriptive hyphenated IDs, `learn-` prefix for learn scenarios
- Domain exercises are distinct from tutorials (Sprint 4) — exercises are standalone problems, tutorials have concept text
- Deduplicate against Sprint 4 migrations (31 original scenarios + 12 troubleshooting + tutorial learn scenarios)
- Knowledge-only quiz questions -> `content/reference/`, practical ones -> YAML scenarios
- Speed drills -> `content/reference/speed-drills/`
- Cheatsheet -> `content/reference/cheatsheet.md`
- All output through `display.sh` functions
- 2-space indent, no tabs, shellcheck clean

**Dependencies:** Sprint 3 (drill flow — scenario engine, validator, CLI dispatch), Sprint 4 (first content batch — learn content exists, tutorial learn scenarios exist)

**Content inventory for this sprint:**
| Source | Items | Target |
|--------|-------|--------|
| Domain exercises (5 files, ~2,200 lines) | 49 exercises | YAML scenarios (net-new after dedup) |
| Domain quizzes (5 files) | 50 questions | Practical -> YAML scenarios, knowledge -> reference |
| Mock exam quiz (1 file) | 20 questions | Practical -> YAML scenarios (most overlap with exercises) |
| Speed drills (3 files) | ~567 lines | `content/reference/speed-drills/` |
| Cheatsheet (1 file) | 559 lines | `content/reference/cheatsheet.md` |

---

### Task 1: Extract Domain 1 Exercises as Scenarios (Story 8.4 — partial)

**Files:**
- Create: `scenarios/domain-1/ambassador-pattern.yaml`
- Create: `scenarios/domain-1/init-container-wait-for-service.yaml`
- Create: `scenarios/domain-1/job-with-completions.yaml`

**Deduplication analysis for Domain 1 (8 exercises):**
| Exercise | Overlap | Action |
|----------|---------|--------|
| 1: Multi-Container Pod (Sidecar) | scenario-01 (Sprint 4) | SKIP — already migrated |
| 2: Init Container | scenario-02 (Sprint 4) | SKIP — already migrated |
| 3: Init Container - Wait for Service | unique | NEW scenario |
| 4: Job | scenario-03 (Sprint 4) | SKIP — already migrated |
| 5: Job with Completions | unique (parallelism aspect) | NEW scenario |
| 6: CronJob | scenario-04 (Sprint 4) | SKIP — already migrated |
| 7: Ambassador Pattern | unique | NEW scenario |
| 8: Pod with PVC | scenario-05 (Sprint 4) | SKIP — already migrated |

**3 net-new scenarios from Domain 1.**

**Step 1: Create scenarios/domain-1/init-container-wait-for-service.yaml**

```yaml
id: init-container-wait-for-service
domain: 1
title: "Init Container — Wait for Service"
difficulty: medium
time_limit: 300
weight: 1
namespace: init-svc-ns
tags: [init-containers, services]
description: |
  Create a pod named `app-with-init` in namespace `init-svc-ns` that:

  1. Has an init container named `wait-for-db` (image: busybox:1.36) that waits
     for a service named `db` to be resolvable via DNS before the main container starts.
     Use: `nslookup db.init-svc-ns.svc.cluster.local`
  2. Has a main container named `app` (image: nginx:1.25) serving on port 80.

  Also create the `db` service so the init container can resolve it.
  The `db` service should point to port 5432 with a selector `app=postgres`.

hint: |
  - Init containers run before the main container starts
  - Use `nslookup` in a loop: `until nslookup db...; do sleep 2; done`
  - The init container will block until the service DNS resolves
  - You need to create the Service (even without backing pods) for DNS to work

setup:
  - kubectl create namespace init-svc-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/app-with-init
    description: "Pod app-with-init exists"
  - type: container_image
    resource: pod/app-with-init
    container: app
    expected: "nginx:1.25"
    description: "Main container uses nginx:1.25"
  - type: resource_field
    resource: pod/app-with-init
    jsonpath: "{.spec.initContainers[0].name}"
    expected: "wait-for-db"
    description: "Init container named wait-for-db exists"
  - type: resource_exists
    resource: service/db
    description: "Service db exists"
  - type: container_running
    resource: pod/app-with-init
    container: app
    description: "Main container is running (init completed)"

solution: |
  # Create the service first so DNS resolves
  kubectl apply -f - <<'EOF'
  apiVersion: v1
  kind: Service
  metadata:
    name: db
    namespace: init-svc-ns
  spec:
    ports:
    - port: 5432
    selector:
      app: postgres
  EOF

  # Create the pod with init container
  kubectl apply -f - <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: app-with-init
    namespace: init-svc-ns
  spec:
    initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nslookup db.init-svc-ns.svc.cluster.local; do echo waiting for db; sleep 2; done']
    containers:
    - name: app
      image: nginx:1.25
      ports:
      - containerPort: 80
  EOF
```

**Step 2: Create scenarios/domain-1/job-with-completions.yaml**

```yaml
id: job-with-completions
domain: 1
title: "Job with Completions and Parallelism"
difficulty: medium
time_limit: 240
weight: 1
namespace: batch-ns
tags: [jobs, batch]
description: |
  Create a Job named `batch-processor` in namespace `batch-ns` that:

  1. Uses image `busybox:1.36`
  2. Runs the command: `echo "Processing batch item" && sleep 5`
  3. Completes 6 times total
  4. Runs 3 pods in parallel
  5. Has `restartPolicy: Never`

hint: |
  - Use `.spec.completions` to set total completions
  - Use `.spec.parallelism` to set parallel pods
  - The Job controller manages pod creation automatically

setup:
  - kubectl create namespace batch-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: job/batch-processor
    description: "Job batch-processor exists"
  - type: resource_field
    resource: job/batch-processor
    jsonpath: "{.spec.completions}"
    expected: "6"
    description: "Job has 6 completions"
  - type: resource_field
    resource: job/batch-processor
    jsonpath: "{.spec.parallelism}"
    expected: "3"
    description: "Job has parallelism of 3"
  - type: resource_field
    resource: job/batch-processor
    jsonpath: "{.spec.template.spec.restartPolicy}"
    expected: "Never"
    description: "Job has restartPolicy Never"

solution: |
  kubectl apply -f - <<'EOF'
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: batch-processor
    namespace: batch-ns
  spec:
    completions: 6
    parallelism: 3
    template:
      spec:
        containers:
        - name: processor
          image: busybox:1.36
          command: ["sh", "-c", "echo Processing batch item && sleep 5"]
        restartPolicy: Never
  EOF
```

**Step 3: Create scenarios/domain-1/ambassador-pattern.yaml**

```yaml
id: ambassador-pattern
domain: 1
title: "Multi-Container Pod — Ambassador Pattern"
difficulty: hard
time_limit: 420
weight: 1
namespace: ambassador-ns
tags: [multi-container, ambassador]
description: |
  Create a pod named `api-with-proxy` in namespace `ambassador-ns` that demonstrates
  the ambassador pattern:

  1. Main container named `api` (image: nginx:1.25) serving on port 80
  2. Ambassador container named `proxy` (image: haproxy:2.9) that listens on port 8080
  3. Both containers share a volume named `config` at `/etc/haproxy` in the proxy container
     and `/etc/proxy-config` in the main container
  4. Add label `pattern=ambassador` to the pod

hint: |
  - The ambassador pattern uses a sidecar to proxy network traffic
  - Both containers run simultaneously (not init containers)
  - The shared volume allows the main container to provide config to the proxy
  - Don't worry about haproxy actually routing — just set up the pod structure

setup:
  - kubectl create namespace ambassador-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: pod/api-with-proxy
    description: "Pod api-with-proxy exists"
  - type: container_count
    resource: pod/api-with-proxy
    expected: 2
    description: "Pod has 2 containers"
  - type: container_image
    resource: pod/api-with-proxy
    container: api
    expected: "nginx:1.25"
    description: "Main container uses nginx:1.25"
  - type: container_image
    resource: pod/api-with-proxy
    container: proxy
    expected: "haproxy:2.9"
    description: "Ambassador container uses haproxy:2.9"
  - type: volume_mount
    resource: pod/api-with-proxy
    container: proxy
    mount_path: "/etc/haproxy"
    description: "Proxy container mounts volume at /etc/haproxy"
  - type: label_selector
    resource_type: pod
    labels: "pattern=ambassador"
    description: "Pod has label pattern=ambassador"

solution: |
  kubectl apply -f - <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: api-with-proxy
    namespace: ambassador-ns
    labels:
      pattern: ambassador
  spec:
    containers:
    - name: api
      image: nginx:1.25
      ports:
      - containerPort: 80
      volumeMounts:
      - name: config
        mountPath: /etc/proxy-config
    - name: proxy
      image: haproxy:2.9
      ports:
      - containerPort: 8080
      volumeMounts:
      - name: config
        mountPath: /etc/haproxy
    volumes:
    - name: config
      emptyDir: {}
  EOF
```

**Step 4: Commit**

```bash
git add scenarios/domain-1/init-container-wait-for-service.yaml \
        scenarios/domain-1/job-with-completions.yaml \
        scenarios/domain-1/ambassador-pattern.yaml
git commit -m "feat: extract 3 net-new Domain 1 exercise scenarios

Ambassador pattern, init container wait-for-service, and job with
completions/parallelism. Deduplicated against Sprint 4 migrations."
```

---

### Task 2: Extract Domain 2 Exercises as Scenarios (Story 8.4 — partial)

**Files:**
- Create: `scenarios/domain-2/rolling-update-strategy.yaml`
- Create: `scenarios/domain-2/blue-green-deployment.yaml`
- Create: `scenarios/domain-2/kustomize-basics.yaml`
- Create: `scenarios/domain-2/helm-custom-values.yaml`
- Create: `scenarios/domain-2/rollout-to-revision.yaml`

**Deduplication analysis for Domain 2 (8 exercises):**
| Exercise | Overlap | Action |
|----------|---------|--------|
| 1: Create and Scale a Deployment | scenario-06/09 (Sprint 4) | SKIP — rolling-update + scale overlap |
| 2: Rolling Update Strategy | unique (maxSurge/maxUnavailable) | NEW scenario |
| 3: Helm - Install and Configure | scenario-08 (Sprint 4) | SKIP — already migrated |
| 4: Helm - Custom Values File | unique (values file) | NEW scenario |
| 5: Blue/Green Deployment | unique | NEW scenario |
| 6: Canary Deployment | scenario-10 (Sprint 4) | SKIP — already migrated |
| 7: Kustomize Basics | unique | NEW scenario |
| 8: Rollout to Specific Revision | unique (revision target) | NEW scenario |

**5 net-new scenarios from Domain 2.**

**Step 1: Create scenarios/domain-2/rolling-update-strategy.yaml**

```yaml
id: rolling-update-strategy
domain: 2
title: "Deployment with Rolling Update Strategy"
difficulty: medium
time_limit: 300
weight: 1
namespace: deploy-strategy-ns
tags: [deployments, rolling-update]
description: |
  Create a deployment named `api-server` in namespace `deploy-strategy-ns` with:

  1. Image: nginx:1.19
  2. 4 replicas
  3. Rolling update strategy with maxSurge=1 and maxUnavailable=1
  4. Container port 80

  Then update the image to nginx:1.25 and verify the rollout completes.

hint: |
  - Use `.spec.strategy.type: RollingUpdate`
  - Set `.spec.strategy.rollingUpdate.maxSurge` and `.maxUnavailable`
  - Use `kubectl rollout status` to watch the rollout
  - maxSurge=1 means at most 1 extra pod during update
  - maxUnavailable=1 means at most 1 pod unavailable during update

setup:
  - kubectl create namespace deploy-strategy-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: deployment/api-server
    description: "Deployment api-server exists"
  - type: resource_field
    resource: deployment/api-server
    jsonpath: "{.spec.replicas}"
    expected: "4"
    description: "Deployment has 4 replicas"
  - type: resource_field
    resource: deployment/api-server
    jsonpath: "{.spec.strategy.type}"
    expected: "RollingUpdate"
    description: "Strategy is RollingUpdate"
  - type: resource_field
    resource: deployment/api-server
    jsonpath: "{.spec.strategy.rollingUpdate.maxSurge}"
    expected: "1"
    description: "maxSurge is 1"
  - type: resource_field
    resource: deployment/api-server
    jsonpath: "{.spec.strategy.rollingUpdate.maxUnavailable}"
    expected: "1"
    description: "maxUnavailable is 1"
  - type: resource_field
    resource: deployment/api-server
    jsonpath: "{.spec.template.spec.containers[0].image}"
    expected: "nginx:1.25"
    description: "Image updated to nginx:1.25"

solution: |
  kubectl apply -f - <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: api-server
    namespace: deploy-strategy-ns
  spec:
    replicas: 4
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 1
    selector:
      matchLabels:
        app: api-server
    template:
      metadata:
        labels:
          app: api-server
      spec:
        containers:
        - name: nginx
          image: nginx:1.19
          ports:
          - containerPort: 80
  EOF

  kubectl rollout status deployment/api-server -n deploy-strategy-ns
  kubectl set image deployment/api-server nginx=nginx:1.25 -n deploy-strategy-ns
  kubectl rollout status deployment/api-server -n deploy-strategy-ns
```

**Step 2: Create scenarios/domain-2/blue-green-deployment.yaml**

```yaml
id: blue-green-deployment
domain: 2
title: "Blue/Green Deployment"
difficulty: hard
time_limit: 480
weight: 2
namespace: blue-green-ns
tags: [deployments, blue-green]
description: |
  Implement a blue/green deployment in namespace `blue-green-ns`:

  1. Create a "blue" deployment named `app-blue` with image nginx:1.24, 3 replicas,
     labels `app=myapp` and `version=blue`
  2. Create a "green" deployment named `app-green` with image nginx:1.25, 3 replicas,
     labels `app=myapp` and `version=green`
  3. Create a service named `app-svc` on port 80 that currently routes to the GREEN
     deployment (selector: `app=myapp,version=green`)

  The service should select the green deployment, simulating a completed switchover.

hint: |
  - Blue/green keeps both versions running simultaneously
  - The service selector determines which version gets traffic
  - Both deployments share `app=myapp` but differ on `version` label
  - Switching traffic = changing the service selector

setup:
  - kubectl create namespace blue-green-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: deployment/app-blue
    description: "Blue deployment exists"
  - type: resource_exists
    resource: deployment/app-green
    description: "Green deployment exists"
  - type: resource_field
    resource: deployment/app-blue
    jsonpath: "{.spec.template.spec.containers[0].image}"
    expected: "nginx:1.24"
    description: "Blue uses nginx:1.24"
  - type: resource_field
    resource: deployment/app-green
    jsonpath: "{.spec.template.spec.containers[0].image}"
    expected: "nginx:1.25"
    description: "Green uses nginx:1.25"
  - type: resource_exists
    resource: service/app-svc
    description: "Service app-svc exists"
  - type: resource_field
    resource: service/app-svc
    jsonpath: "{.spec.selector.version}"
    expected: "green"
    description: "Service routes to green deployment"

solution: |
  kubectl apply -f - <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: app-blue
    namespace: blue-green-ns
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: myapp
        version: blue
    template:
      metadata:
        labels:
          app: myapp
          version: blue
      spec:
        containers:
        - name: nginx
          image: nginx:1.24
          ports:
          - containerPort: 80
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: app-green
    namespace: blue-green-ns
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: myapp
        version: green
    template:
      metadata:
        labels:
          app: myapp
          version: green
      spec:
        containers:
        - name: nginx
          image: nginx:1.25
          ports:
          - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: app-svc
    namespace: blue-green-ns
  spec:
    selector:
      app: myapp
      version: green
    ports:
    - port: 80
      targetPort: 80
  EOF
```

**Step 3: Create remaining Domain 2 scenarios**

Create the following files using the same pattern as above:

- `scenarios/domain-2/kustomize-basics.yaml`
  - **id:** `kustomize-basics`
  - **difficulty:** medium, **time_limit:** 360
  - **namespace:** `kustomize-ns`
  - **Task:** Create a `kustomization.yaml` that patches a base nginx deployment with namespace, name prefix, and common labels. Apply with `kubectl apply -k`.
  - **Validations:** resource_exists deployment, resource_field on labels, resource_field on image
  - **Note:** Kustomize is built into kubectl — no extra tools needed

- `scenarios/domain-2/helm-custom-values.yaml`
  - **id:** `helm-custom-values`
  - **difficulty:** medium, **time_limit:** 300
  - **namespace:** `helm-values-ns`
  - **tags:** `[helm]`
  - **Task:** Create a values file and install a helm chart with custom values (replicas, service type). Verify the deployed resources match the values.
  - **Validations:** command_output checking `helm list`, resource_field on replicas
  - **Note:** Requires Helm — use `tags: [helm]` for the Helm guard

- `scenarios/domain-2/rollout-to-revision.yaml`
  - **id:** `rollout-to-revision`
  - **difficulty:** medium, **time_limit:** 300
  - **namespace:** `rollout-rev-ns`
  - **Task:** Create a deployment, update it twice (creating 3 revisions), then rollback to revision 1 specifically (not just undo).
  - **Validations:** resource_field on image matching revision 1's image, command_output on rollout history

**Step 4: Commit**

```bash
git add scenarios/domain-2/rolling-update-strategy.yaml \
        scenarios/domain-2/blue-green-deployment.yaml \
        scenarios/domain-2/kustomize-basics.yaml \
        scenarios/domain-2/helm-custom-values.yaml \
        scenarios/domain-2/rollout-to-revision.yaml
git commit -m "feat: extract 5 net-new Domain 2 exercise scenarios

Rolling update strategy, blue/green deployment, kustomize basics,
helm custom values, and rollout to specific revision."
```

---

### Task 3: Extract Domain 3 Exercises as Scenarios (Story 8.4 — partial)

**Files:**
- Create: `scenarios/domain-3/liveness-probe-exec.yaml`
- Create: `scenarios/domain-3/combined-probes.yaml`
- Create: `scenarios/domain-3/multi-container-logging.yaml`
- Create: `scenarios/domain-3/resource-monitoring.yaml`

**Deduplication analysis for Domain 3 (10 exercises):**
| Exercise | Overlap | Action |
|----------|---------|--------|
| 1: Liveness Probe (HTTP) | scenario-11 (Sprint 4) | SKIP |
| 2: Liveness Probe (Exec) | unique (exec type) | NEW scenario |
| 3: Readiness Probe | scenario-12 (Sprint 4) | SKIP |
| 4: Combined Probes | unique (startup + liveness + readiness) | NEW scenario |
| 5: Container Logging | scenario-14 (Sprint 4) | SKIP |
| 6: Debug a Failing Pod | scenario-13 / debug scenarios (Sprint 4) | SKIP |
| 7: Debug CrashLoopBackOff | debug scenarios (Sprint 4) | SKIP |
| 8: Exec into Running Pod | scenario-30 (Sprint 4) | SKIP |
| 9: Multi-Container Logging | unique (multi-container log tailing) | NEW scenario |
| 10: Resource Monitoring | unique (kubectl top, metrics) | NEW scenario |

**4 net-new scenarios from Domain 3.**

**Step 1: Create scenarios/domain-3/liveness-probe-exec.yaml**

Full YAML following the same pattern. Key fields:
- **id:** `liveness-probe-exec`
- **difficulty:** easy, **time_limit:** 240
- **namespace:** `probe-exec-ns`
- **Task:** Create pod `health-exec` with a liveness probe using `exec` type that checks a file exists (`cat /tmp/healthy`). The container creates the file on startup.
- **Validations:** resource_exists, resource_field on probe type/command, container_running

**Step 2: Create scenarios/domain-3/combined-probes.yaml**

- **id:** `combined-probes`
- **difficulty:** hard, **time_limit:** 360
- **namespace:** `probes-ns`
- **Task:** Create pod `full-probes` with all three probes: startup (exec, failureThreshold 30), liveness (HTTP GET / port 80, period 10s), and readiness (HTTP GET /ready port 80, period 5s).
- **Validations:** resource_field on each probe's fields, container_running

**Step 3: Create scenarios/domain-3/multi-container-logging.yaml**

- **id:** `multi-container-logging`
- **difficulty:** medium, **time_limit:** 300
- **namespace:** `logging-ns`
- **Task:** Create pod `log-aggregator` with 3 containers: app (nginx), log-tailer (busybox tailing access log), error-tailer (busybox tailing error log). Two emptyDir volumes for access and error logs.
- **Validations:** container_count (3), container_image for each, volume_mount checks

**Step 4: Create scenarios/domain-3/resource-monitoring.yaml**

- **id:** `resource-monitoring`
- **difficulty:** easy, **time_limit:** 240
- **namespace:** `monitoring-ns`
- **Task:** Create a deployment `monitored-app` (nginx, 3 replicas) with CPU/memory resource requests. Verify `kubectl top pods` returns metrics.
- **Validations:** resource_exists, resource_field on requests, command_output checking `kubectl top pods` contains the pod

**Step 5: Commit**

```bash
git add scenarios/domain-3/liveness-probe-exec.yaml \
        scenarios/domain-3/combined-probes.yaml \
        scenarios/domain-3/multi-container-logging.yaml \
        scenarios/domain-3/resource-monitoring.yaml
git commit -m "feat: extract 4 net-new Domain 3 exercise scenarios

Liveness probe exec, combined probes (startup+liveness+readiness),
multi-container logging, and resource monitoring with kubectl top."
```

---

### Task 4: Extract Domain 4 Exercises as Scenarios (Story 8.4 — partial)

**Files:**
- Create: `scenarios/domain-4/configmap-from-literals.yaml`
- Create: `scenarios/domain-4/configmap-as-volume.yaml`
- Create: `scenarios/domain-4/secret-from-literals.yaml`
- Create: `scenarios/domain-4/security-context-capabilities.yaml`
- Create: `scenarios/domain-4/service-account.yaml`
- Create: `scenarios/domain-4/limit-range.yaml`
- Create: `scenarios/domain-4/persistent-volume-claim.yaml`

**Deduplication analysis for Domain 4 (12 exercises):**
| Exercise | Overlap | Action |
|----------|---------|--------|
| 1: ConfigMap from Literals | unique (imperative creation) | NEW scenario |
| 2: Pod Using ConfigMap as Env Vars | scenario-16 (Sprint 4, combined) | SKIP — overlap with configmap-secret |
| 3: ConfigMap as Volume | unique (volume mount) | NEW scenario |
| 4: Secret from Literals | unique (focused secret) | NEW scenario |
| 5: Pod Using Secret | scenario-16 (Sprint 4, combined) | SKIP — overlap |
| 6: SecurityContext - Run as Non-Root | scenario-17 (Sprint 4) | SKIP |
| 7: SecurityContext - Capabilities | unique (add/drop caps) | NEW scenario |
| 8: ServiceAccount | unique (SA creation + binding) | NEW scenario |
| 9: Resource Requests and Limits | scenario-19 (Sprint 4) | SKIP |
| 10: ResourceQuota | scenario-20 (Sprint 4) | SKIP |
| 11: LimitRange | unique | NEW scenario |
| 12: PersistentVolumeClaim | unique (standalone PVC) | NEW scenario |

**7 net-new scenarios from Domain 4.**

**Step 1: Create scenarios/domain-4/configmap-from-literals.yaml**

```yaml
id: configmap-from-literals
domain: 4
title: "ConfigMap from Literals"
difficulty: easy
time_limit: 180
weight: 1
namespace: config-ns
tags: [configmap]
description: |
  In namespace `config-ns`:

  1. Create a ConfigMap named `app-settings` with these key-value pairs:
     - APP_ENV=production
     - LOG_LEVEL=info
     - MAX_CONNECTIONS=100

  2. Create a pod named `config-env-pod` (image: busybox:1.36, command: sleep 3600)
     that loads ALL ConfigMap keys as environment variables using `envFrom`.

hint: |
  - Use `kubectl create configmap --from-literal` for imperative creation
  - Use `envFrom` with `configMapRef` to load all keys at once
  - Verify with `kubectl exec config-env-pod -- env`

setup:
  - kubectl create namespace config-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: configmap/app-settings
    description: "ConfigMap app-settings exists"
  - type: resource_field
    resource: configmap/app-settings
    jsonpath: "{.data.APP_ENV}"
    expected: "production"
    description: "ConfigMap has APP_ENV=production"
  - type: resource_field
    resource: configmap/app-settings
    jsonpath: "{.data.LOG_LEVEL}"
    expected: "info"
    description: "ConfigMap has LOG_LEVEL=info"
  - type: resource_exists
    resource: pod/config-env-pod
    description: "Pod config-env-pod exists"
  - type: container_env
    resource: pod/config-env-pod
    container: busybox
    env_name: APP_ENV
    expected: "production"
    description: "Pod has APP_ENV from ConfigMap"

solution: |
  kubectl create configmap app-settings \
    --from-literal=APP_ENV=production \
    --from-literal=LOG_LEVEL=info \
    --from-literal=MAX_CONNECTIONS=100 \
    -n config-ns

  kubectl apply -f - <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: config-env-pod
    namespace: config-ns
  spec:
    containers:
    - name: busybox
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom:
      - configMapRef:
          name: app-settings
  EOF
```

**Step 2: Create scenarios/domain-4/configmap-as-volume.yaml**

```yaml
id: configmap-as-volume
domain: 4
title: "ConfigMap Mounted as Volume"
difficulty: medium
time_limit: 300
weight: 1
namespace: config-vol-ns
tags: [configmap, volumes]
description: |
  In namespace `config-vol-ns`:

  1. Create a ConfigMap named `app-config` with a key `app.properties` containing:
     ```
     database.host=localhost
     database.port=5432
     database.name=myapp
     ```
  2. Create a pod named `config-vol-pod` (image: nginx:1.25) that mounts the
     ConfigMap as a volume at `/etc/config`.

  The file `/etc/config/app.properties` should contain the config content.

hint: |
  - Create a ConfigMap from a file: `kubectl create configmap --from-file`
  - Or use `data:` in YAML with the filename as key
  - Mount the ConfigMap as a volume using `volumes` and `volumeMounts`

setup:
  - kubectl create namespace config-vol-ns --dry-run=client -o yaml | kubectl apply -f -

validations:
  - type: resource_exists
    resource: configmap/app-config
    description: "ConfigMap app-config exists"
  - type: resource_exists
    resource: pod/config-vol-pod
    description: "Pod config-vol-pod exists"
  - type: volume_mount
    resource: pod/config-vol-pod
    container: nginx
    mount_path: "/etc/config"
    description: "Volume mounted at /etc/config"
  - type: command_output
    command: "kubectl exec config-vol-pod -n config-vol-ns -- cat /etc/config/app.properties"
    contains: "database.host=localhost"
    description: "Config file contains expected content"

solution: |
  kubectl apply -f - <<'EOF'
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: app-config
    namespace: config-vol-ns
  data:
    app.properties: |
      database.host=localhost
      database.port=5432
      database.name=myapp
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: config-vol-pod
    namespace: config-vol-ns
  spec:
    containers:
    - name: nginx
      image: nginx:1.25
      volumeMounts:
      - name: config
        mountPath: /etc/config
    volumes:
    - name: config
      configMap:
        name: app-config
  EOF
```

**Step 3: Create remaining Domain 4 scenarios**

Create the following files using the same pattern:

- `scenarios/domain-4/secret-from-literals.yaml`
  - **id:** `secret-from-literals`, **difficulty:** easy, **time_limit:** 240
  - **namespace:** `secrets-ns`
  - **Task:** Create Secret `api-credentials` with `username=admin` and `password=s3cur3`. Create pod that mounts it as env vars `DB_USER` and `DB_PASS`.
  - **Validations:** resource_exists secret, resource_field on secret type, container_env checks

- `scenarios/domain-4/security-context-capabilities.yaml`
  - **id:** `security-context-capabilities`, **difficulty:** medium, **time_limit:** 300
  - **namespace:** `caps-ns`
  - **Task:** Create pod with NET_ADMIN capability added and ALL capabilities dropped except NET_BIND_SERVICE.
  - **Validations:** resource_field on securityContext.capabilities

- `scenarios/domain-4/service-account.yaml`
  - **id:** `service-account-rbac`, **difficulty:** medium, **time_limit:** 360
  - **namespace:** `sa-ns`
  - **Task:** Create ServiceAccount `deployer`, Role allowing get/list/create on deployments, RoleBinding. Create pod using the ServiceAccount.
  - **Validations:** resource_exists for SA/Role/RoleBinding, resource_field on pod's serviceAccountName

- `scenarios/domain-4/limit-range.yaml`
  - **id:** `limit-range`, **difficulty:** medium, **time_limit:** 300
  - **namespace:** `limits-ns`
  - **Task:** Create LimitRange with default CPU 200m/500m (request/limit) and memory 128Mi/256Mi. Create pod without specifying resources and verify defaults applied.
  - **Validations:** resource_exists limitrange, resource_field on pod's auto-assigned resources

- `scenarios/domain-4/persistent-volume-claim.yaml`
  - **id:** `persistent-volume-claim`, **difficulty:** easy, **time_limit:** 240
  - **namespace:** `storage-ns`
  - **Task:** Create PVC `data-vol` (1Gi, RWO). Create pod mounting it at `/data`. Write a file and verify persistence.
  - **Validations:** resource_exists pvc, resource_field on access modes and storage, volume_mount check

**Step 4: Commit**

```bash
git add scenarios/domain-4/configmap-from-literals.yaml \
        scenarios/domain-4/configmap-as-volume.yaml \
        scenarios/domain-4/secret-from-literals.yaml \
        scenarios/domain-4/security-context-capabilities.yaml \
        scenarios/domain-4/service-account-rbac.yaml \
        scenarios/domain-4/limit-range.yaml \
        scenarios/domain-4/persistent-volume-claim.yaml
git commit -m "feat: extract 7 net-new Domain 4 exercise scenarios

ConfigMap from literals, ConfigMap as volume, Secret from literals,
security context capabilities, service account RBAC, LimitRange,
and PersistentVolumeClaim."
```

---

### Task 5: Extract Domain 5 Exercises as Scenarios (Story 8.4 — partial)

**Files:**
- Create: `scenarios/domain-5/nodeport-service.yaml`
- Create: `scenarios/domain-5/service-named-ports.yaml`
- Create: `scenarios/domain-5/ingress-path-routing.yaml`
- Create: `scenarios/domain-5/netpol-allow-from-namespace.yaml`
- Create: `scenarios/domain-5/netpol-egress.yaml`
- Create: `scenarios/domain-5/headless-service.yaml`

**Deduplication analysis for Domain 5 (11 exercises):**
| Exercise | Overlap | Action |
|----------|---------|--------|
| 1: ClusterIP Service | scenario-21 (Sprint 4) | SKIP |
| 2: NodePort Service | unique (NodePort type) | NEW scenario |
| 3: Service with Named Ports | unique | NEW scenario |
| 4: Basic Ingress | scenario-22 (Sprint 4) | SKIP |
| 5: Ingress with Path-Based Routing | unique (multi-path) | NEW scenario |
| 6: NetworkPolicy - Deny All Ingress | scenario-23 (Sprint 4) | SKIP |
| 7: NetworkPolicy - Allow Specific Pods | scenario-24 (Sprint 4) | SKIP |
| 8: NetworkPolicy - Allow from Namespace | unique (namespace selector) | NEW scenario |
| 9: NetworkPolicy - Egress | unique (egress rules) | NEW scenario |
| 10: DNS Testing | scenario-25 (Sprint 4) | SKIP |
| 11: Headless Service | unique | NEW scenario |

**6 net-new scenarios from Domain 5.**

**Step 1: Create scenarios/domain-5/nodeport-service.yaml**

Full YAML following the established pattern:
- **id:** `nodeport-service`, **difficulty:** easy, **time_limit:** 240
- **namespace:** `nodeport-ns`
- **Task:** Create deployment `nodeport-app` (nginx, 2 replicas), expose as NodePort service on port 80.
- **Validations:** resource_exists deployment/service, resource_field on service type=NodePort

**Step 2: Create scenarios/domain-5/headless-service.yaml**

- **id:** `headless-service`, **difficulty:** medium, **time_limit:** 300
- **namespace:** `headless-ns`
- **Task:** Create a StatefulSet `web` with 3 replicas and a headless service (clusterIP: None). Verify individual pod DNS records.
- **Validations:** resource_exists service/statefulset, resource_field clusterIP=None, command_output nslookup

**Step 3: Create remaining Domain 5 scenarios**

- `scenarios/domain-5/service-named-ports.yaml`
  - **id:** `service-named-ports`, **difficulty:** medium, **time_limit:** 300
  - **Task:** Create pod with named ports (http: 80, metrics: 9090). Create service referencing the named ports.
  - **Validations:** resource_field on port names

- `scenarios/domain-5/ingress-path-routing.yaml`
  - **id:** `ingress-path-routing`, **difficulty:** medium, **time_limit:** 360
  - **Task:** Create two deployments (api-svc, web-svc). Create Ingress routing `/api` to api-svc and `/` to web-svc on `app.example.com`.
  - **Validations:** resource_exists ingress, resource_field on rules/paths

- `scenarios/domain-5/netpol-allow-from-namespace.yaml`
  - **id:** `netpol-allow-from-namespace`, **difficulty:** hard, **time_limit:** 420
  - **Task:** Create NetworkPolicy allowing ingress only from pods in a namespace labeled `team=frontend`.
  - **Validations:** resource_exists networkpolicy, resource_field on namespaceSelector

- `scenarios/domain-5/netpol-egress.yaml`
  - **id:** `netpol-egress`, **difficulty:** hard, **time_limit:** 420
  - **Task:** Create NetworkPolicy allowing egress only to port 443 (HTTPS) and port 53 (DNS/UDP). This is a common exam pattern.
  - **Validations:** resource_exists networkpolicy, resource_field on egress rules/ports

**Step 4: Commit**

```bash
git add scenarios/domain-5/nodeport-service.yaml \
        scenarios/domain-5/service-named-ports.yaml \
        scenarios/domain-5/ingress-path-routing.yaml \
        scenarios/domain-5/netpol-allow-from-namespace.yaml \
        scenarios/domain-5/netpol-egress.yaml \
        scenarios/domain-5/headless-service.yaml
git commit -m "feat: extract 6 net-new Domain 5 exercise scenarios

NodePort service, named ports, ingress path routing, NetworkPolicy
allow-from-namespace, NetworkPolicy egress, and headless service."
```

---

### Task 6: Migrate Quizzes to Scenarios and Reference Content (Story 8.5 — partial)

**Files:**
- Create: `content/reference/quizzes/domain-1-knowledge.md`
- Create: `content/reference/quizzes/domain-2-knowledge.md`
- Create: `content/reference/quizzes/domain-3-knowledge.md`
- Create: `content/reference/quizzes/domain-4-knowledge.md`
- Create: `content/reference/quizzes/domain-5-knowledge.md`
- Create: 3-5 new scenario YAML files from practical quiz questions

**Quiz triage strategy:**

The 50 domain quiz questions (10 per domain) and 20 mock exam questions must be classified:
- **Knowledge-only** (e.g., "What are the three multi-container patterns?") -> `content/reference/quizzes/`
- **Practical kubectl tasks** (e.g., "Write a one-liner to create a CronJob") -> YAML scenarios
- **Already covered** by exercise extraction (Tasks 1-5) -> SKIP

**Step 1: Triage quiz questions**

**Domain 1 quiz (10 questions):**
| Q | Type | Action |
|---|------|--------|
| Q1: kubectl dry-run command | knowledge | reference |
| Q2: Three multi-container patterns | knowledge | reference |
| Q3: What's wrong with this YAML? | knowledge (init vs containers) | reference |
| Q4: View logs from specific container | knowledge | reference |
| Q5: restartPolicy Never vs OnFailure | knowledge | reference |
| Q6: One-liner CronJob | practical — overlap scenario-04 | SKIP |
| Q7: emptyDir data on pod delete | knowledge | reference |
| Q8: PVC access modes | knowledge | reference |
| Q9: CronJob concurrencyPolicy | knowledge | reference |
| Q10: Job one-liner with completions | practical — overlap job-with-completions | SKIP |

**Domain 2 quiz (10 questions):**
| Q | Type | Action |
|---|------|--------|
| Q1: Two deployment strategies | knowledge | reference |
| Q2: Rollback to revision 3 | practical — overlap rollout-to-revision | SKIP |
| Q3: maxSurge/maxUnavailable meaning | knowledge | reference |
| Q4: Helm install with custom values | practical — overlap helm-custom-values | SKIP |
| Q5: helm template vs install --dry-run | knowledge | reference |
| Q6: Blue/green explanation | knowledge | reference |
| Q7: Canary traffic percentage | knowledge | reference |
| Q8: kubectl kustomize preview | knowledge | reference |
| Q9: Helm release history | knowledge | reference |
| Q10: helm upgrade --install | knowledge | reference |

**Domain 3 quiz (10 questions):** All 10 are knowledge-only -> reference

**Domain 4 quiz (10 questions):**
| Q | Type | Action |
|---|------|--------|
| Q1-Q4: Knowledge | knowledge | reference |
| Q5: Create SA, disable token mount | practical | NEW scenario: `service-account-no-automount` |
| Q6-Q10: Knowledge | knowledge | reference |

**Domain 5 quiz (10 questions):**
| Q | Type | Action |
|---|------|--------|
| Q1-Q4: Knowledge | knowledge | reference |
| Q5: NetworkPolicy deny all in+egress | practical | NEW scenario: `netpol-deny-all` |
| Q6-Q8: Knowledge | knowledge | reference |
| Q9: Test service reachability | knowledge/practical | reference (too simple for scenario) |
| Q10: kubectl get endpoints | knowledge | reference |

**Mock exam (20 questions):** Most overlap with exercise-extracted scenarios. A few may produce net-new:
| Q | Overlap? | Action |
|---|----------|--------|
| Q1-Q3 (D1) | Overlap sidecar, job-completions, cronjob | SKIP |
| Q4 (D2) | Overlap rolling-update | SKIP |
| Q5 (D2) | Overlap helm-custom-values | SKIP |
| Q6 (D3) | Overlap combined-probes | SKIP |
| Q7 (D3) | Overlap debug scenarios | SKIP |
| Q8 (D4) | Overlap configmap-from-literals | SKIP |
| Q9 (D4) | Overlap secret-from-literals | SKIP |
| Q10 (D4) | Unique: locked-down pod | NEW scenario: `locked-down-pod` |
| Q11 (D4) | Overlap service-account-rbac | SKIP |
| Q12 (D4) | Overlap resource-limits | SKIP |
| Q13 (D5) | Overlap nodeport-service | SKIP |
| Q14 (D5) | Overlap ingress-path-routing | SKIP |
| Q15 (D5) | Overlap netpol-allow | SKIP |
| Q16 (D1) | Overlap init-container-wait-for-service | SKIP |
| Q17 (D4) | Overlap persistent-volume-claim | SKIP |
| Q18 (D5) | Overlap netpol-egress | SKIP |
| Q19 (D3) | Unique: startup probe for slow app | NEW scenario: `startup-probe-slow-app` |
| Q20 (D2) | Overlap canary | SKIP |

**Net-new from quizzes: 4 scenarios** (service-account-no-automount, netpol-deny-all, locked-down-pod, startup-probe-slow-app)

**Step 2: Create content/reference/quizzes/ directory and knowledge reference files**

Create `content/reference/quizzes/domain-1-knowledge.md`:
```markdown
# Domain 1: Application Design & Build — Knowledge Reference

These are knowledge-check questions extracted from the CKAD study quizzes.
They test conceptual understanding rather than practical kubectl tasks.

## Q: What kubectl command creates a pod YAML template without creating the pod?
`kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml`

## Q: What are the three multi-container pod patterns?
1. **Sidecar** — enhances the main container (e.g., log shipper)
2. **Ambassador** — proxies network traffic (e.g., localhost proxy to DB)
3. **Adapter** — transforms output (e.g., reformats logs to JSON)

[... remaining knowledge questions for domain 1 ...]
```

Create the same pattern for domains 2-5. Each file collects the knowledge-only questions with their answers in readable markdown format.

**Step 3: Create the 4 net-new scenario YAMLs**

- `scenarios/domain-4/service-account-no-automount.yaml`
  - **id:** `service-account-no-automount`, **difficulty:** easy, **time_limit:** 180
  - **Task:** Create SA `restricted-sa` with `automountServiceAccountToken: false`. Create pod using it.
  - **Validations:** resource_exists sa, resource_field on automountServiceAccountToken

- `scenarios/domain-5/netpol-deny-all.yaml`
  - **id:** `netpol-deny-all`, **difficulty:** medium, **time_limit:** 300
  - **Task:** Create NetworkPolicy denying ALL ingress AND egress for all pods in namespace.
  - **Validations:** resource_exists, resource_field on policyTypes (Ingress,Egress), empty ingress/egress rules

- `scenarios/domain-4/locked-down-pod.yaml`
  - **id:** `locked-down-pod`, **difficulty:** medium, **time_limit:** 300
  - **Task:** Create pod running as UID 1000, GID 2000, read-only filesystem, no privilege escalation.
  - **Validations:** resource_field on securityContext fields (runAsUser, runAsGroup, readOnlyRootFilesystem, allowPrivilegeEscalation)

- `scenarios/domain-3/startup-probe-slow-app.yaml`
  - **id:** `startup-probe-slow-app`, **difficulty:** medium, **time_limit:** 300
  - **Task:** Create pod for app that takes 60s to start. Add startup probe (failureThreshold 30, periodSeconds 10) to prevent premature killing, plus liveness probe.
  - **Validations:** resource_field on startupProbe configuration, liveness probe exists

**Step 4: Commit**

```bash
git add content/reference/quizzes/ \
        scenarios/domain-4/service-account-no-automount.yaml \
        scenarios/domain-5/netpol-deny-all.yaml \
        scenarios/domain-4/locked-down-pod.yaml \
        scenarios/domain-3/startup-probe-slow-app.yaml
git commit -m "feat: migrate quizzes — knowledge to reference, practical to scenarios

50 domain quiz questions + 20 mock exam questions triaged.
Knowledge-only questions archived in content/reference/quizzes/.
4 net-new scenarios: service-account-no-automount, netpol-deny-all,
locked-down-pod, startup-probe-slow-app."
```

---

### Task 7: Migrate Speed Drills and Cheatsheet (Story 8.5 — partial)

**Files:**
- Create: `content/reference/speed-drills/one-liners.md`
- Create: `content/reference/speed-drills/aliases.md`
- Create: `content/reference/speed-drills/vim-tips.md`
- Create: `content/reference/cheatsheet.md`

**Step 1: Copy speed drills to content/reference/speed-drills/**

The speed drill files are reference content — quick-reference cards for practicing kubectl fluency. They don't map to validated scenarios (they're about speed, not correctness). Copy them with minor formatting updates.

```bash
mkdir -p content/reference/speed-drills
# Copy from archive/ (post-Sprint 1) or current location (pre-Sprint 1)
# Adjust source path based on whether Sprint 1 has run
cp archive/speed-drills/one-liners.md content/reference/speed-drills/one-liners.md
cp archive/speed-drills/aliases.md content/reference/speed-drills/aliases.md
cp archive/speed-drills/vim-tips.md content/reference/speed-drills/vim-tips.md
```

Add a header to each file:
```markdown
# Speed Drills: One-Liners
> Reference content for ckad-drill. Practice these until each takes < 30 seconds.
> Run `ckad-drill learn` for validated exercises.
```

**Step 2: Copy cheatsheet to content/reference/**

```bash
mkdir -p content/reference
cp archive/cheatsheet.md content/reference/cheatsheet.md
```

Add a header:
```markdown
# CKAD Cheatsheet
> Reference content for ckad-drill. Print this or keep it handy while practicing.
```

**Step 3: Verify all files are well-formed markdown**

```bash
# Quick sanity check — files should not be empty
wc -l content/reference/speed-drills/*.md content/reference/cheatsheet.md
```

**Step 4: Commit**

```bash
git add content/reference/speed-drills/ content/reference/cheatsheet.md
git commit -m "feat: migrate speed drills and cheatsheet to content/reference/

3 speed drill files (one-liners, aliases, vim-tips) and cheatsheet
preserved as reference markdown in content/reference/."
```

---

### Task 8: Scenario Count Audit and Content Summary (Story 8.4/8.5 wrap-up)

**Files:**
- No new files — this is a verification step

**Step 1: Count total scenarios after this sprint**

```bash
# Count all YAML scenario files across all domain directories
find scenarios/ -name "*.yaml" -type f | wc -l

# Count by domain
for d in 1 2 3 4 5; do
  echo "Domain $d: $(find scenarios/domain-$d -name '*.yaml' -type f 2>/dev/null | wc -l)"
done
```

**Expected scenario count after Sprint 6:**

| Source | Count |
|--------|-------|
| Sprint 4: Original 31 scenarios | 31 |
| Sprint 4: 12 troubleshooting/debug | 12 |
| Sprint 4: Tutorial learn scenarios | ~15 |
| Sprint 6 Task 1: Domain 1 exercises | 3 |
| Sprint 6 Task 2: Domain 2 exercises | 5 |
| Sprint 6 Task 3: Domain 3 exercises | 4 |
| Sprint 6 Task 4: Domain 4 exercises | 7 |
| Sprint 6 Task 5: Domain 5 exercises | 6 |
| Sprint 6 Task 6: Quiz-derived | 4 |
| **Total** | **~87** |

This exceeds the 70+ target (NFR-06). Verify each domain has >= 10 scenarios.

**Step 2: Validate all new scenarios pass schema validation**

```bash
# Run scenario validation on all new files (requires Sprint 2 scenario engine)
for f in scenarios/domain-*/ambassador-pattern.yaml \
         scenarios/domain-*/init-container-wait-for-service.yaml \
         scenarios/domain-*/job-with-completions.yaml \
         scenarios/domain-*/rolling-update-strategy.yaml \
         scenarios/domain-*/blue-green-deployment.yaml \
         scenarios/domain-*/kustomize-basics.yaml \
         scenarios/domain-*/helm-custom-values.yaml \
         scenarios/domain-*/rollout-to-revision.yaml \
         scenarios/domain-*/liveness-probe-exec.yaml \
         scenarios/domain-*/combined-probes.yaml \
         scenarios/domain-*/multi-container-logging.yaml \
         scenarios/domain-*/resource-monitoring.yaml \
         scenarios/domain-*/configmap-from-literals.yaml \
         scenarios/domain-*/configmap-as-volume.yaml \
         scenarios/domain-*/secret-from-literals.yaml \
         scenarios/domain-*/security-context-capabilities.yaml \
         scenarios/domain-*/service-account-rbac.yaml \
         scenarios/domain-*/limit-range.yaml \
         scenarios/domain-*/persistent-volume-claim.yaml \
         scenarios/domain-*/nodeport-service.yaml \
         scenarios/domain-*/service-named-ports.yaml \
         scenarios/domain-*/ingress-path-routing.yaml \
         scenarios/domain-*/netpol-allow-from-namespace.yaml \
         scenarios/domain-*/netpol-egress.yaml \
         scenarios/domain-*/headless-service.yaml \
         scenarios/domain-*/service-account-no-automount.yaml \
         scenarios/domain-*/netpol-deny-all.yaml \
         scenarios/domain-*/locked-down-pod.yaml \
         scenarios/domain-*/startup-probe-slow-app.yaml; do
  bin/ckad-drill validate-scenario "$f"
done
```

**Step 3: Check for duplicate IDs**

```bash
# Extract all scenario IDs and check for duplicates
grep -rh "^id:" scenarios/ | sort | uniq -d
```

Expected: No duplicates.

---

### Task 9: Implement lib/learn.sh — Learn Mode Logic (Story 9.1)

**Files:**
- Create: `lib/learn.sh`
- Test: `test/unit/learn.bats`

This task implements the learn mode flow. Learn mode presents learn-prefixed scenarios in progressive order (easy -> hard) within each domain, displays concept text before the task, and tracks per-lesson completion.

**Step 1: Write failing tests for learn.sh**

Create `test/unit/learn.bats`:
```bash
#!/usr/bin/env bats

setup() {
  load '../helpers/test-helper'
  source "${CKAD_ROOT}/lib/common.sh"
  source "${CKAD_ROOT}/lib/display.sh"

  # Create temporary scenario directory for testing
  CKAD_SCENARIOS_DIR="${BATS_TEST_TMPDIR}/scenarios"
  mkdir -p "${CKAD_SCENARIOS_DIR}/domain-1"
  mkdir -p "${CKAD_SCENARIOS_DIR}/domain-2"

  # Create test learn scenarios
  cat > "${CKAD_SCENARIOS_DIR}/domain-1/learn-pods-basics.yaml" <<'YAML'
id: learn-pods-basics
domain: 1
title: "Pods Basics"
difficulty: easy
time_limit: 180
learn: true
concept_text: |
  A Pod is the smallest deployable unit in Kubernetes.
  Every container runs inside a Pod.
description: "Create a simple nginx pod."
namespace: learn-pods
validations:
  - type: resource_exists
    resource: pod/nginx
    description: "Pod exists"
solution: "kubectl run nginx --image=nginx -n learn-pods"
YAML

  cat > "${CKAD_SCENARIOS_DIR}/domain-1/learn-multi-container.yaml" <<'YAML'
id: learn-multi-container
domain: 1
title: "Multi-Container Pods"
difficulty: medium
time_limit: 300
learn: true
concept_text: |
  Pods can contain multiple containers that share networking and storage.
  Common patterns include sidecar, ambassador, and adapter.
description: "Create a multi-container pod."
namespace: learn-multi
validations:
  - type: container_count
    resource: pod/multi
    expected: 2
    description: "Pod has 2 containers"
solution: "kubectl apply -f multi.yaml -n learn-multi"
YAML

  cat > "${CKAD_SCENARIOS_DIR}/domain-1/learn-volumes.yaml" <<'YAML'
id: learn-volumes
domain: 1
title: "Volumes"
difficulty: hard
time_limit: 360
learn: true
concept_text: |
  Volumes allow containers in a Pod to share data.
  emptyDir is the simplest volume type.
description: "Create a pod with an emptyDir volume."
namespace: learn-vols
validations:
  - type: resource_exists
    resource: pod/vol-pod
    description: "Pod exists"
solution: "kubectl apply -f vol.yaml -n learn-vols"
YAML

  # Non-learn scenario (should be excluded)
  cat > "${CKAD_SCENARIOS_DIR}/domain-1/multi-container-pod.yaml" <<'YAML'
id: multi-container-pod
domain: 1
title: "Multi-Container Pod"
difficulty: easy
time_limit: 180
description: "Create a multi-container pod."
namespace: drill-multi
validations:
  - type: resource_exists
    resource: pod/multi
    description: "Pod exists"
solution: "kubectl apply -f multi.yaml"
YAML

  cat > "${CKAD_SCENARIOS_DIR}/domain-2/learn-deployments.yaml" <<'YAML'
id: learn-deployments
domain: 2
title: "Deployments"
difficulty: easy
time_limit: 180
learn: true
concept_text: |
  Deployments manage ReplicaSets and provide declarative updates.
description: "Create a deployment."
namespace: learn-deploy
validations:
  - type: resource_exists
    resource: deployment/nginx
    description: "Deployment exists"
solution: "kubectl create deployment nginx --image=nginx -n learn-deploy"
YAML

  # Source learn.sh (mock scenario.sh and progress.sh dependencies)
  # Provide stubs for functions learn.sh depends on
  scenario_load() { : ; }
  scenario_setup() { : ; }
  scenario_cleanup() { : ; }
  scenario_get_field() { echo ""; }
  progress_record() { : ; }
  progress_get_learn_completion() { echo "{}"; }
  export -f scenario_load scenario_setup scenario_cleanup scenario_get_field
  export -f progress_record progress_get_learn_completion

  source "${CKAD_ROOT}/lib/learn.sh"
}

@test "learn functions are defined" {
  declare -f learn_list_domains > /dev/null
  declare -f learn_list_lessons > /dev/null
  declare -f learn_start > /dev/null
  declare -f _learn_get_scenarios > /dev/null
  declare -f _learn_sort_by_difficulty > /dev/null
}

@test "_learn_get_scenarios returns only learn: true scenarios" {
  local scenarios
  scenarios="$(_learn_get_scenarios "${CKAD_SCENARIOS_DIR}" "")"
  # Should include learn- prefixed scenarios
  [[ "${scenarios}" == *"learn-pods-basics"* ]]
  [[ "${scenarios}" == *"learn-multi-container"* ]]
  [[ "${scenarios}" == *"learn-volumes"* ]]
  [[ "${scenarios}" == *"learn-deployments"* ]]
  # Should NOT include non-learn scenarios
  [[ "${scenarios}" != *"multi-container-pod.yaml"* ]] || \
    { echo "Non-learn scenario included"; return 1; }
}

@test "_learn_get_scenarios filters by domain" {
  local scenarios
  scenarios="$(_learn_get_scenarios "${CKAD_SCENARIOS_DIR}" "1")"
  [[ "${scenarios}" == *"learn-pods-basics"* ]]
  [[ "${scenarios}" == *"learn-multi-container"* ]]
  [[ "${scenarios}" != *"learn-deployments"* ]]
}

@test "_learn_sort_by_difficulty orders easy < medium < hard" {
  local input="learn-volumes:hard
learn-multi-container:medium
learn-pods-basics:easy"
  local sorted
  sorted="$(_learn_sort_by_difficulty "${input}")"
  local first second third
  first="$(echo "${sorted}" | head -1)"
  second="$(echo "${sorted}" | sed -n '2p')"
  third="$(echo "${sorted}" | sed -n '3p')"
  [[ "${first}" == *"easy"* ]]
  [[ "${second}" == *"medium"* ]]
  [[ "${third}" == *"hard"* ]]
}

@test "learn_list_domains shows all domains with learn scenarios" {
  run learn_list_domains "${CKAD_SCENARIOS_DIR}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Domain 1"* ]]
  [[ "${output}" == *"Domain 2"* ]]
}

@test "learn_list_lessons shows lessons in order for a domain" {
  run learn_list_lessons "${CKAD_SCENARIOS_DIR}" "1"
  [[ "${status}" -eq 0 ]]
  # Lessons should appear in difficulty order
  local pods_line multi_line vols_line
  pods_line="$(echo "${output}" | grep -n "Pods Basics" | cut -d: -f1)"
  multi_line="$(echo "${output}" | grep -n "Multi-Container" | cut -d: -f1)"
  vols_line="$(echo "${output}" | grep -n "Volumes" | cut -d: -f1)"
  [[ "${pods_line}" -lt "${multi_line}" ]]
  [[ "${multi_line}" -lt "${vols_line}" ]]
}

@test "sourcing learn.sh produces no output" {
  local output
  output="$(source "${CKAD_ROOT}/lib/common.sh"; source "${CKAD_ROOT}/lib/display.sh"; source "${CKAD_ROOT}/lib/learn.sh" 2>&1)"
  [[ -z "${output}" ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/learn.bats
```

Expected: FAIL — `lib/learn.sh` doesn't exist yet.

**Step 3: Implement lib/learn.sh**

Create `lib/learn.sh`:
```bash
#!/usr/bin/env bash
# lib/learn.sh — Learn mode flow for ckad-drill
#
# Learn mode presents learn-prefixed scenarios in progressive order
# (easy -> medium -> hard) within each domain, displays concept text
# before the task description, and tracks per-lesson completion.
#
# Learn scenarios are regular scenarios with learn: true and concept_text.
# This file depends on: common.sh, display.sh, scenario.sh, progress.sh

# ---------------------------------------------------------------------------
# Difficulty ordering for progressive learning
# ---------------------------------------------------------------------------

_LEARN_DIFFICULTY_ORDER="easy:1 medium:2 hard:3"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Get the numeric sort key for a difficulty level
_learn_difficulty_rank() {
  local difficulty="${1}"
  case "${difficulty}" in
    easy)   echo "1" ;;
    medium) echo "2" ;;
    hard)   echo "3" ;;
    *)      echo "9" ;;
  esac
}

# Get all learn scenarios, optionally filtered by domain
# Output: one line per scenario: filename:id:domain:difficulty:title
_learn_get_scenarios() {
  local scenarios_dir="${1}"
  local domain_filter="${2:-}"
  local search_dirs=()

  if [[ -n "${domain_filter}" ]]; then
    search_dirs=("${scenarios_dir}/domain-${domain_filter}")
  else
    local d
    for d in 1 2 3 4 5; do
      if [[ -d "${scenarios_dir}/domain-${d}" ]]; then
        search_dirs+=("${scenarios_dir}/domain-${d}")
      fi
    done
  fi

  local dir file learn_val id domain difficulty title
  for dir in "${search_dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    for file in "${dir}"/*.yaml; do
      [[ -f "${file}" ]] || continue
      learn_val="$(yq '.learn // false' "${file}" 2>/dev/null)"
      if [[ "${learn_val}" == "true" ]]; then
        id="$(yq '.id' "${file}" 2>/dev/null)"
        domain="$(yq '.domain' "${file}" 2>/dev/null)"
        difficulty="$(yq '.difficulty' "${file}" 2>/dev/null)"
        title="$(yq '.title' "${file}" 2>/dev/null)"
        echo "${file}:${id}:${domain}:${difficulty}:${title}"
      fi
    done
  done
}

# Sort learn scenario lines by difficulty (easy -> medium -> hard)
# Input: lines of "id:difficulty" or full scenario lines with difficulty in field 4
_learn_sort_by_difficulty() {
  local input="${1}"
  echo "${input}" | while IFS=: read -r rest_or_id difficulty_or_rest; do
    # Detect format: if input has colons, difficulty might be in different positions
    local line="${rest_or_id}:${difficulty_or_rest}"
    local difficulty
    # Handle both "id:difficulty" and "file:id:domain:difficulty:title" formats
    local field_count
    field_count="$(echo "${line}" | tr ':' '\n' | wc -l)"
    if [[ "${field_count}" -ge 5 ]]; then
      difficulty="$(echo "${line}" | cut -d: -f4)"
    else
      difficulty="$(echo "${line}" | cut -d: -f2)"
    fi
    local rank
    rank="$(_learn_difficulty_rank "${difficulty}")"
    echo "${rank}:${line}"
  done | sort -t: -k1,1n | cut -d: -f2-
}

# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

# List all domains that have learn scenarios, with counts and completion
learn_list_domains() {
  local scenarios_dir="${1:-${CKAD_ROOT}/scenarios}"

  header "Learn Mode — Available Domains"

  local d count completed total_count=0
  for d in 1 2 3 4 5; do
    local scenarios
    scenarios="$(_learn_get_scenarios "${scenarios_dir}" "${d}")"
    if [[ -z "${scenarios}" ]]; then
      continue
    fi
    count="$(echo "${scenarios}" | wc -l)"
    total_count=$((total_count + count))
    # Get completion count from progress
    completed="$(_learn_domain_completion "${d}")"
    local domain_name
    domain_name="$(_learn_domain_name "${d}")"
    info "  Domain ${d}: ${domain_name} — ${completed}/${count} lessons"
  done

  if [[ "${total_count}" -eq 0 ]]; then
    warn "No learn scenarios found."
    return 1
  fi

  echo ""
  info "Run: ckad-drill learn --domain N"
}

# List lessons for a specific domain in progressive order
learn_list_lessons() {
  local scenarios_dir="${1:-${CKAD_ROOT}/scenarios}"
  local domain="${2}"

  if [[ -z "${domain}" ]]; then
    warn "No domain specified. Run: ckad-drill learn --domain N"
    return 1
  fi

  local domain_name
  domain_name="$(_learn_domain_name "${domain}")"
  header "Learn Mode — Domain ${domain}: ${domain_name}"

  local scenarios
  scenarios="$(_learn_get_scenarios "${scenarios_dir}" "${domain}")"

  if [[ -z "${scenarios}" ]]; then
    warn "No learn scenarios found for domain ${domain}."
    return 1
  fi

  local sorted
  sorted="$(_learn_sort_by_difficulty "${scenarios}")"

  local idx=1
  while IFS=: read -r file id dom difficulty title; do
    local status_icon
    if _learn_is_completed "${id}"; then
      status_icon="✅"
    else
      status_icon="⬜"
    fi
    printf '  %s %2d. [%s] %s\n' "${status_icon}" "${idx}" "${difficulty}" "${title}"
    idx=$((idx + 1))
  done <<< "${sorted}"

  echo ""
  info "Run: ckad-drill learn --domain ${domain} to start the first incomplete lesson."
}

# Start learn mode for a domain — present lessons progressively
learn_start() {
  local scenarios_dir="${1:-${CKAD_ROOT}/scenarios}"
  local domain="${2}"

  if [[ -z "${domain}" ]]; then
    # No domain specified — show domain list
    learn_list_domains "${scenarios_dir}"
    return $?
  fi

  local scenarios
  scenarios="$(_learn_get_scenarios "${scenarios_dir}" "${domain}")"

  if [[ -z "${scenarios}" ]]; then
    warn "No learn scenarios found for domain ${domain}."
    return 1
  fi

  local sorted
  sorted="$(_learn_sort_by_difficulty "${scenarios}")"

  # Find the first incomplete lesson
  local target_file="" target_id=""
  while IFS=: read -r file id dom difficulty title; do
    if ! _learn_is_completed "${id}"; then
      target_file="${file}"
      target_id="${id}"
      break
    fi
  done <<< "${sorted}"

  if [[ -z "${target_file}" ]]; then
    local domain_name
    domain_name="$(_learn_domain_name "${domain}")"
    pass "All lessons in Domain ${domain} (${domain_name}) are complete!"
    local next_domain
    next_domain="$(_learn_next_incomplete_domain "${scenarios_dir}" "${domain}")"
    if [[ -n "${next_domain}" ]]; then
      info "Next: ckad-drill learn --domain ${next_domain}"
    else
      pass "Congratulations — all learn mode lessons are complete!"
    fi
    return 0
  fi

  # Load and present the learn scenario
  _learn_present_scenario "${target_file}" "${target_id}" "${domain}" "${sorted}"
}

# Present a single learn scenario with concept text
_learn_present_scenario() {
  local file="${1}"
  local id="${2}"
  local domain="${3}"
  local sorted_list="${4}"

  # Get lesson position
  local total idx=0 current_pos=0
  total="$(echo "${sorted_list}" | wc -l)"
  while IFS=: read -r f i d diff t; do
    idx=$((idx + 1))
    if [[ "${i}" == "${id}" ]]; then
      current_pos="${idx}"
      break
    fi
  done <<< "${sorted_list}"

  # Display concept text
  local concept_text
  concept_text="$(yq '.concept_text // ""' "${file}" 2>/dev/null)"
  local title
  title="$(yq '.title' "${file}" 2>/dev/null)"
  local difficulty
  difficulty="$(yq '.difficulty' "${file}" 2>/dev/null)"

  header "Learn: ${title} (${current_pos}/${total})"

  if [[ -n "${concept_text}" && "${concept_text}" != "null" ]]; then
    printf '\n%s\n' "📖 Concept:"
    printf '%s\n' "${concept_text}"
    printf '%s\n' "────────────────────────────────────────"
  fi

  # Load the scenario through the standard engine
  scenario_load "${file}"
  scenario_setup

  # Display the task description
  local description
  description="$(yq '.description' "${file}" 2>/dev/null)"
  printf '\n%s\n\n' "📝 Task:"
  printf '%s\n' "${description}"

  info "Run 'ckad-drill check' when done. Hints are available: 'ckad-drill hint'"

  # Write learn session state
  _learn_save_session "${id}" "${file}" "${domain}"
}

# Check if the current learn scenario passed; advance to next
learn_advance() {
  local scenarios_dir="${1:-${CKAD_ROOT}/scenarios}"
  local current_id="${2}"
  local domain="${3}"
  local passed="${4}"

  if [[ "${passed}" == "true" ]]; then
    # Record completion
    _learn_mark_completed "${current_id}"
    pass "Lesson complete!"

    # Find and offer next lesson
    local scenarios sorted
    scenarios="$(_learn_get_scenarios "${scenarios_dir}" "${domain}")"
    sorted="$(_learn_sort_by_difficulty "${scenarios}")"

    local found_current=false next_file="" next_id=""
    while IFS=: read -r file id dom difficulty title; do
      if [[ "${found_current}" == "true" ]] && ! _learn_is_completed "${id}"; then
        next_file="${file}"
        next_id="${id}"
        break
      fi
      if [[ "${id}" == "${current_id}" ]]; then
        found_current=true
      fi
    done <<< "${sorted}"

    if [[ -n "${next_file}" ]]; then
      echo ""
      info "Next lesson available. Run 'ckad-drill next' to continue."
    else
      echo ""
      local domain_name
      domain_name="$(_learn_domain_name "${domain}")"
      pass "All lessons in Domain ${domain} (${domain_name}) are complete!"
      local next_domain
      next_domain="$(_learn_next_incomplete_domain "${scenarios_dir}" "${domain}")"
      if [[ -n "${next_domain}" ]]; then
        info "Next: ckad-drill learn --domain ${next_domain}"
      fi
    fi
  else
    info "Not all checks passed. Review the feedback above and try again."
    info "Run 'ckad-drill hint' for help, or 'ckad-drill check' to retry."
  fi
}

# ---------------------------------------------------------------------------
# Progress helpers (delegate to progress.sh)
# ---------------------------------------------------------------------------

_learn_is_completed() {
  local id="${1}"
  local completion
  completion="$(progress_get_learn_completion 2>/dev/null || echo "{}")"
  local val
  val="$(echo "${completion}" | jq -r --arg id "${id}" '.[$id] // "false"' 2>/dev/null)"
  [[ "${val}" == "true" ]]
}

_learn_mark_completed() {
  local id="${1}"
  progress_record "${id}" true 0 2>/dev/null || true
}

_learn_domain_completion() {
  local domain="${1}"
  local count=0
  local scenarios
  scenarios="$(_learn_get_scenarios "${CKAD_ROOT}/scenarios" "${domain}" 2>/dev/null)"
  [[ -z "${scenarios}" ]] && echo "0" && return
  while IFS=: read -r file id dom difficulty title; do
    if _learn_is_completed "${id}"; then
      count=$((count + 1))
    fi
  done <<< "${scenarios}"
  echo "${count}"
}

_learn_next_incomplete_domain() {
  local scenarios_dir="${1}"
  local current_domain="${2}"
  local d
  for d in 1 2 3 4 5; do
    [[ "${d}" -eq "${current_domain}" ]] && continue
    local scenarios
    scenarios="$(_learn_get_scenarios "${scenarios_dir}" "${d}")"
    [[ -z "${scenarios}" ]] && continue
    while IFS=: read -r file id dom difficulty title; do
      if ! _learn_is_completed "${id}"; then
        echo "${d}"
        return
      fi
    done <<< "${scenarios}"
  done
  echo ""
}

# ---------------------------------------------------------------------------
# Session state helpers
# ---------------------------------------------------------------------------

_learn_save_session() {
  local id="${1}"
  local file="${2}"
  local domain="${3}"
  local namespace
  namespace="$(yq '.namespace // "drill-'"${id}"'"' "${file}" 2>/dev/null)"
  local time_limit
  time_limit="$(yq '.time_limit // 300' "${file}" 2>/dev/null)"

  jq -n \
    --arg mode "learn" \
    --arg id "${id}" \
    --arg file "${file}" \
    --arg ns "${namespace}" \
    --arg domain "${domain}" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson time "${time_limit}" \
    '{mode: $mode, scenario_id: $id, scenario_file: $file, namespace: $ns, domain: ($domain | tonumber), started_at: $started, time_limit: $time}' \
    > "${CKAD_SESSION_FILE}"
}

# ---------------------------------------------------------------------------
# Domain name lookup
# ---------------------------------------------------------------------------

_learn_domain_name() {
  local domain="${1}"
  case "${domain}" in
    1) echo "Application Design & Build" ;;
    2) echo "Application Deployment" ;;
    3) echo "Application Observability & Maintenance" ;;
    4) echo "Application Environment, Configuration & Security" ;;
    5) echo "Services & Networking" ;;
    *) echo "Unknown Domain" ;;
  esac
}
```

**Step 4: Run tests to verify they pass**

```bash
bats test/unit/learn.bats
```

Expected: All PASS.

**Step 5: Run shellcheck**

```bash
shellcheck lib/learn.sh
```

Expected: No warnings.

**Step 6: Commit**

```bash
git add lib/learn.sh test/unit/learn.bats
git commit -m "feat: implement lib/learn.sh with progressive learn mode flow

Learn mode lists domains, shows lessons in difficulty order, presents
concept text before tasks, tracks per-lesson completion, and suggests
next lesson/domain. Uses same scenario engine with learn: true filter.
Includes bats unit tests."
```

---

### Task 10: Wire Learn Mode into bin/ckad-drill (Story 9.1 — CLI integration)

**Files:**
- Modify: `bin/ckad-drill`
- Modify: `test/unit/cli.bats`

**Step 1: Write failing tests for learn subcommand**

Add to `test/unit/cli.bats`:
```bash
@test "ckad-drill learn shows domain list" {
  run ckad-drill learn
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Learn Mode"* ]]
}

@test "ckad-drill learn --domain with invalid domain shows error" {
  run ckad-drill learn --domain 9
  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"domain"* ]]
}

@test "ckad-drill learn --help shows usage" {
  run ckad-drill learn --help
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"learn"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats test/unit/cli.bats
```

**Step 3: Add learn.sh sourcing and learn subcommand to bin/ckad-drill**

In `bin/ckad-drill`, add to the source block:
```bash
source "${CKAD_ROOT}/lib/learn.sh"
```

Add the learn command handler:
```bash
cmd_learn() {
  local domain=""
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --domain)
        domain="${2:-}"
        if [[ -z "${domain}" ]]; then
          error "Missing domain number. Usage: ckad-drill learn --domain N"
        fi
        if [[ ! "${domain}" =~ ^[1-5]$ ]]; then
          error "Invalid domain: ${domain}. Must be 1-5."
        fi
        shift 2
        ;;
      --help)
        cat <<'HELP'
Usage: ckad-drill learn [--domain N]

Learn mode presents guided lessons with concept explanations.
Lessons progress from easy to hard within each domain.

Options:
  --domain N    Start/resume lessons for domain N (1-5)
                Without --domain, shows available domains and progress.

Examples:
  ckad-drill learn              # List domains with completion status
  ckad-drill learn --domain 1   # Start domain 1 lessons
HELP
        return 0
        ;;
      *)
        error "Unknown option: ${1}. Run 'ckad-drill learn --help'."
        ;;
    esac
  done

  learn_start "${CKAD_ROOT}/scenarios" "${domain}"
}
```

Add to the main dispatch case:
```bash
    learn)   shift; cmd_learn "$@" ;;
```

**Step 4: Handle learn mode in check/next/hint subcommands**

Update `cmd_check` to call `learn_advance` when mode is "learn":
```bash
cmd_check() {
  # ... existing check logic ...
  local mode
  mode="$(jq -r '.mode' "${CKAD_SESSION_FILE}" 2>/dev/null)"

  # Run validations (existing logic)
  # ...

  if [[ "${mode}" == "learn" ]]; then
    local scenario_id domain
    scenario_id="$(jq -r '.scenario_id' "${CKAD_SESSION_FILE}")"
    domain="$(jq -r '.domain' "${CKAD_SESSION_FILE}")"
    learn_advance "${CKAD_ROOT}/scenarios" "${scenario_id}" "${domain}" "${all_passed}"
  fi
}
```

**Step 5: Run tests**

```bash
bats test/unit/cli.bats
```

Expected: All PASS.

**Step 6: Run shellcheck on everything**

```bash
shellcheck bin/ckad-drill lib/*.sh
```

Expected: No warnings.

**Step 7: Commit**

```bash
git add bin/ckad-drill test/unit/cli.bats
git commit -m "feat: wire learn mode into CLI — ckad-drill learn subcommand

Adds learn subcommand with --domain flag. Shows domain list without
args, starts progressive lessons with --domain N. Integrates with
check/next for learn-mode-aware flow. Includes CLI tests."
```

---

### Task 11: Run Full Test Suite and Final Verification

**Files:** None — verification only.

**Step 1: Run shellcheck on all scripts**

```bash
shellcheck bin/ckad-drill lib/*.sh scripts/*.sh
```

Expected: No warnings.

**Step 2: Run all unit tests**

```bash
make test-unit
```

Expected: All PASS.

**Step 3: Run scenario validation on all new scenarios**

```bash
# Validate all YAML files have required fields
for f in scenarios/domain-*/*.yaml; do
  echo "Validating: ${f}"
  id="$(yq '.id // ""' "$f")"
  domain="$(yq '.domain // ""' "$f")"
  title="$(yq '.title // ""' "$f")"
  difficulty="$(yq '.difficulty // ""' "$f")"
  [[ -n "${id}" ]] || echo "  MISSING: id"
  [[ -n "${domain}" ]] || echo "  MISSING: domain"
  [[ -n "${title}" ]] || echo "  MISSING: title"
  [[ -n "${difficulty}" ]] || echo "  MISSING: difficulty"
done
```

**Step 4: Verify scenario count meets target**

```bash
echo "Total scenarios: $(find scenarios/ -name '*.yaml' -type f | wc -l)"
for d in 1 2 3 4 5; do
  echo "  Domain ${d}: $(find scenarios/domain-${d} -name '*.yaml' -type f 2>/dev/null | wc -l)"
done
```

Expected: >= 70 total, >= 10 per domain.

**Step 5: Verify no duplicate IDs**

```bash
grep -rh "^id:" scenarios/ | sort | uniq -d
```

Expected: Empty output (no duplicates).

---

## Summary

| Task | Story | Deliverable | Tests |
|------|-------|-------------|-------|
| 1 | 8.4 | 3 Domain 1 exercise scenarios | Scenario validation |
| 2 | 8.4 | 5 Domain 2 exercise scenarios | Scenario validation |
| 3 | 8.4 | 4 Domain 3 exercise scenarios | Scenario validation |
| 4 | 8.4 | 7 Domain 4 exercise scenarios | Scenario validation |
| 5 | 8.4 | 6 Domain 5 exercise scenarios | Scenario validation |
| 6 | 8.5 | Quiz knowledge reference + 4 quiz scenarios | Scenario validation |
| 7 | 8.5 | Speed drills + cheatsheet in content/reference/ | — |
| 8 | 8.4/8.5 | Content audit and count verification | ID uniqueness + count check |
| 9 | 9.1 | lib/learn.sh | test/unit/learn.bats |
| 10 | 9.1 | bin/ckad-drill learn integration | test/unit/cli.bats |
| 11 | — | Full test suite verification | make test |

**After Sprint 6:**
- **29 net-new scenarios** from exercise extraction and quiz migration (3+5+4+7+6+4)
- All quiz knowledge content preserved in `content/reference/quizzes/`
- Speed drills and cheatsheet in `content/reference/`
- Learn mode fully functional: `ckad-drill learn [--domain N]`
- Progressive lesson ordering (easy -> hard) with concept text display
- Per-lesson completion tracking in progress.json
- Total scenario count exceeds 70+ NFR target
- All three modes (drill, exam, learn) are now operational

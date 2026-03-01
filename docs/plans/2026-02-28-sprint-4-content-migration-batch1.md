# Sprint 4: Content Migration (First Batch) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert existing study guide content into validated YAML scenario files: 31 drill scenarios, 12 troubleshooting debug scenarios, and 15+ learn-mode scenarios (at least 3 per domain). Target: 50+ scenarios ready for the engine built in Sprints 1-3.

**Architecture:** YAML scenario files in `scenarios/domain-{1..5}/`. Each file is a self-contained scenario definition parsed by `lib/scenario.sh` (yq). Validation types are the 10 typed checks from ADR-01 plus `command_output` escape hatch. See `_bmad-output/planning-artifacts/architecture.md` for full ADRs.

**Dependencies:** Sprint 3 complete (scenario engine, validator, CLI all working). `scenario_validate()` from Story 3.3 is available to verify each converted file.

**Key conventions (from architecture doc):**
- IDs: descriptive hyphenated (e.g., `multi-container-pod`), no numeric prefixes
- Learn mode IDs: `learn-` prefix (e.g., `learn-pods-and-volumes`)
- Debug scenario IDs: `debug-` prefix (e.g., `debug-image-typo`)
- Namespace: realistic names per ADR-06; fallback `drill-<id>`
- Difficulty: `easy` | `medium` | `hard`
- Domain: integer 1-5
- Time limits: integer seconds
- All text fields use YAML `|` block scalar for multi-line
- Validation: single-check, no retry (ADR-07)

**Source locations (pre-Sprint-1 originals / post-Sprint-1 archive/):**
- Scenarios: `archive/scenarios/scenario-{01..31}-*.md`
- Troubleshooting: `archive/troubleshooting/broken/lab-{01..12}.yaml` + `archive/troubleshooting/solution/lab-{01..12}.yaml`
- Tutorials: `archive/domains/{01..05}-*/tutorial.md`

**Validation workflow for each scenario file:**
```bash
# After writing each YAML file:
yq eval '.' scenarios/domain-N/my-scenario.yaml   # Syntax check
ckad-drill validate-scenario scenarios/domain-N/my-scenario.yaml  # Full validation (schema + cluster test)
```

---

## Domain-to-Scenario Mapping

Before starting, here is the mapping of existing scenarios to CKAD domains:

| Domain | Name | Existing Scenarios | Troubleshooting Labs | Tutorial Exercises |
|--------|------|-------------------|---------------------|-------------------|
| 1 | Application Design & Build | 01-05 (5), 28-29 (2) = 7 | lab-03 (volume), lab-08 (job restart) = 2 | Lessons 1-5 |
| 2 | Application Deployment | 06-10 (5), 27 (1), 31 (1) = 7 | lab-10 (selector mismatch) = 1 | Lessons 1-4 |
| 3 | Application Observability & Maintenance | 11-15 (5), 30 (1) = 6 | lab-06 (probe port) = 1 | Lessons 1-3 |
| 4 | Application Environment, Configuration & Security | 16-20 (5) = 5 | lab-05 (label), lab-07 (secret), lab-09 (cron) = 3 | Lessons 1-4 |
| 5 | Services & Networking | 21-26 (6) = 6 | lab-01 (image), lab-02 (port), lab-04 (ingress), lab-11 (netpol), lab-12 (multi-bug) = 5 | Lessons 1-3 |

---

## Task 1: Migrate Domain 1 Scenarios — Application Design & Build (Story 8.1 partial)

**Files to create:** `scenarios/domain-1/*.yaml` (7 scenarios)

**Step 1: Write the first complete scenario as the reference example**

Create `scenarios/domain-1/multi-container-pod.yaml`:
```yaml
id: multi-container-pod
domain: 1
title: "Multi-Container Pod with Shared Volume"
difficulty: easy
time_limit: 180
weight: 2
namespace: web-team
tags:
  - pods
  - volumes
  - sidecar

description: |
  Create a pod named `web-logger` in the `web-team` namespace with:

  1. A container named `nginx` using image `nginx` that serves on port 80
  2. A sidecar container named `logger` using image `busybox` that runs:
     `tail -f /var/log/nginx/access.log`
  3. Both containers share an emptyDir volume mounted at `/var/log/nginx`

hint: |
  Start with `kubectl run web-logger --image=nginx --dry-run=client -o yaml > pod.yaml`,
  then add the second container and shared volume. Both containers need the same
  volumeMount name and mountPath.

setup: []

validations:
  - type: resource_exists
    resource: pod/web-logger
    description: "Pod web-logger exists"
  - type: container_count
    resource: pod/web-logger
    expected: 2
    description: "Pod has 2 containers"
  - type: container_image
    resource: pod/web-logger
    container: nginx
    expected: nginx
    description: "Container nginx uses nginx image"
  - type: container_image
    resource: pod/web-logger
    container: logger
    expected: busybox
    description: "Container logger uses busybox image"
  - type: volume_mount
    resource: pod/web-logger
    container: nginx
    mount_path: /var/log/nginx
    description: "nginx container mounts /var/log/nginx"
  - type: volume_mount
    resource: pod/web-logger
    container: logger
    mount_path: /var/log/nginx
    description: "logger container mounts /var/log/nginx"
  - type: container_running
    resource: pod/web-logger
    container: nginx
    description: "nginx container is running"

solution: |
  cat <<'SOL' | kubectl apply -n web-team -f -
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
  SOL
```

**Step 2: Write the second complete example — init container**

Create `scenarios/domain-1/init-container.yaml`:
```yaml
id: init-container
domain: 1
title: "Init Container Setup"
difficulty: easy
time_limit: 180
weight: 1
namespace: init-ns
tags:
  - pods
  - init-containers

description: |
  Create a pod named `web-init` in the `init-ns` namespace with:

  1. An init container named `setup` using `busybox` that creates a file:
     `echo "Initialized" > /work/status.txt`
  2. A main container named `web` using `nginx` that mounts the same volume at `/usr/share/nginx/html`
  3. The shared volume is an emptyDir named `workdir`

  The init container must complete before the main container starts.

hint: |
  Init containers go in `spec.initContainers` (not `spec.containers`).
  They use the same volume syntax. The init container runs to completion,
  then the main container starts and can read what the init container wrote.

setup: []

validations:
  - type: resource_exists
    resource: pod/web-init
    description: "Pod web-init exists"
  - type: container_image
    resource: pod/web-init
    container: web
    expected: nginx
    description: "Main container uses nginx image"
  - type: container_running
    resource: pod/web-init
    container: web
    description: "Main container is running"
  - type: volume_mount
    resource: pod/web-init
    container: web
    mount_path: /usr/share/nginx/html
    description: "Web container mounts /usr/share/nginx/html"
  - type: command_output
    command: "kubectl exec -n init-ns web-init -- cat /usr/share/nginx/html/status.txt"
    contains: "Initialized"
    description: "Init container wrote status.txt"

solution: |
  cat <<'SOL' | kubectl apply -n init-ns -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: web-init
  spec:
    initContainers:
    - name: setup
      image: busybox
      command: ["/bin/sh", "-c", "echo Initialized > /work/status.txt"]
      volumeMounts:
      - name: workdir
        mountPath: /work
    containers:
    - name: web
      image: nginx
      volumeMounts:
      - name: workdir
        mountPath: /usr/share/nginx/html
    volumes:
    - name: workdir
      emptyDir: {}
  SOL
```

**Step 3: Write remaining Domain 1 scenarios**

Create the following files using the same pattern. Brief notes on each:

| File | Source | Namespace | Difficulty | Key Validations |
|------|--------|-----------|------------|-----------------|
| `scenarios/domain-1/job-completion.yaml` | scenario-03 | batch-jobs | easy | `resource_exists` (job), `command_output` (check completions), `resource_field` (job .status.succeeded) |
| `scenarios/domain-1/cronjob-schedule.yaml` | scenario-04 | batch-jobs | easy | `resource_exists` (cronjob), `resource_field` (schedule, image), `command_output` (check jobs created) |
| `scenarios/domain-1/pod-with-pvc.yaml` | scenario-05 | storage-team | medium | `resource_exists` (pvc, pod), `resource_field` (pvc accessModes, storage), `volume_mount` |
| `scenarios/domain-1/commands-and-args.yaml` | scenario-28 | workloads | easy | `resource_exists` (pod), `container_image`, `command_output` (check command/args via jsonpath) |
| `scenarios/domain-1/docker-registry-secret.yaml` | scenario-29 | registry-ns | medium | `resource_exists` (secret, pod), `resource_field` (secret type), `container_image` |

**Step 4: Validate all Domain 1 scenarios**

```bash
for f in scenarios/domain-1/*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML syntax error: $f"
done
ckad-drill validate-scenario scenarios/domain-1/
```

**Step 5: Commit**

```bash
git add scenarios/domain-1/
git commit -m "content: migrate 7 domain 1 scenarios to YAML format

Application Design & Build scenarios: multi-container-pod, init-container,
job-completion, cronjob-schedule, pod-with-pvc, commands-and-args,
docker-registry-secret. All validated against scenario schema."
```

---

## Task 2: Migrate Domain 2 Scenarios — Application Deployment (Story 8.1 partial)

**Files to create:** `scenarios/domain-2/*.yaml` (7 scenarios)

**Step 1: Write complete example — rolling update**

Create `scenarios/domain-2/rolling-update.yaml`:
```yaml
id: rolling-update
domain: 2
title: "Rolling Update a Deployment"
difficulty: easy
time_limit: 180
weight: 2
namespace: deployments
tags:
  - deployments
  - updates

description: |
  In the `deployments` namespace:

  1. Create a deployment named `web-app` with 3 replicas using `nginx:1.24`
  2. Update the image to `nginx:1.25` using a rolling update
  3. Verify the rollout completed successfully

hint: |
  Use `kubectl set image deployment/web-app nginx=nginx:1.25` or
  `kubectl edit deployment web-app` to change the image. Then check with
  `kubectl rollout status deployment/web-app`.

setup:
  - "kubectl create deployment web-app -n deployments --image=nginx:1.24 --replicas=3"

validations:
  - type: resource_exists
    resource: deployment/web-app
    description: "Deployment web-app exists"
  - type: resource_field
    resource: deployment/web-app
    jsonpath: "{.spec.template.spec.containers[0].image}"
    expected: "nginx:1.25"
    description: "Image updated to nginx:1.25"
  - type: resource_field
    resource: deployment/web-app
    jsonpath: "{.spec.replicas}"
    expected: "3"
    description: "Deployment has 3 replicas"
  - type: resource_field
    resource: deployment/web-app
    jsonpath: "{.status.updatedReplicas}"
    expected: "3"
    description: "All replicas updated"

solution: |
  kubectl set image deployment/web-app nginx=nginx:1.25 -n deployments
  kubectl rollout status deployment/web-app -n deployments
```

**Step 2: Write remaining Domain 2 scenarios**

| File | Source | Namespace | Difficulty | Key Validations |
|------|--------|-----------|------------|-----------------|
| `scenarios/domain-2/rollback-deployment.yaml` | scenario-07 | deployments | easy | `resource_field` (image reverted), `command_output` (rollout history) |
| `scenarios/domain-2/helm-install-upgrade.yaml` | scenario-08 | helm-apps | medium | `command_output` (helm list, helm status), `resource_exists` (deployment). Tags: `[helm]` |
| `scenarios/domain-2/scale-and-update.yaml` | scenario-09 | deployments | easy | `resource_field` (replicas, image), `resource_count` (pods) |
| `scenarios/domain-2/canary-deployment.yaml` | scenario-10 | canary-ns | hard | `resource_count` (pods by label), `label_selector`, `resource_field` (image per deployment) |
| `scenarios/domain-2/horizontal-pod-autoscaler.yaml` | scenario-27 | autoscale-ns | medium | `resource_exists` (hpa, deployment), `resource_field` (hpa target CPU, min/max replicas) |
| `scenarios/domain-2/rollout-pause-resume.yaml` | scenario-31 | deployments | medium | `resource_field` (image), `command_output` (rollout status paused) |

**Step 3: Validate and commit**

```bash
for f in scenarios/domain-2/*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML syntax error: $f"
done
ckad-drill validate-scenario scenarios/domain-2/
git add scenarios/domain-2/
git commit -m "content: migrate 7 domain 2 scenarios to YAML format

Application Deployment scenarios: rolling-update, rollback-deployment,
helm-install-upgrade, scale-and-update, canary-deployment,
horizontal-pod-autoscaler, rollout-pause-resume."
```

---

## Task 3: Migrate Domain 3 Scenarios — Application Observability & Maintenance (Story 8.1 partial)

**Files to create:** `scenarios/domain-3/*.yaml` (6 scenarios)

**Step 1: Write complete example — liveness probe**

Create `scenarios/domain-3/liveness-probe.yaml`:
```yaml
id: liveness-probe
domain: 3
title: "Configure a Liveness Probe"
difficulty: easy
time_limit: 180
weight: 2
namespace: monitoring
tags:
  - probes
  - health-checks

description: |
  Create a pod named `health-check` in the `monitoring` namespace with:

  1. A container named `web` using image `nginx`
  2. A liveness probe that performs an HTTP GET on path `/` on port 80
  3. The probe should check every 10 seconds with an initial delay of 5 seconds

hint: |
  Add a `livenessProbe` section under the container spec with `httpGet`,
  `periodSeconds`, and `initialDelaySeconds` fields.

setup: []

validations:
  - type: resource_exists
    resource: pod/health-check
    description: "Pod health-check exists"
  - type: container_image
    resource: pod/health-check
    container: web
    expected: nginx
    description: "Container uses nginx image"
  - type: resource_field
    resource: pod/health-check
    jsonpath: "{.spec.containers[0].livenessProbe.httpGet.port}"
    expected: "80"
    description: "Liveness probe checks port 80"
  - type: resource_field
    resource: pod/health-check
    jsonpath: "{.spec.containers[0].livenessProbe.httpGet.path}"
    expected: "/"
    description: "Liveness probe checks path /"
  - type: resource_field
    resource: pod/health-check
    jsonpath: "{.spec.containers[0].livenessProbe.periodSeconds}"
    expected: "10"
    description: "Probe period is 10 seconds"
  - type: container_running
    resource: pod/health-check
    container: web
    description: "Container is running"

solution: |
  cat <<'SOL' | kubectl apply -n monitoring -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: health-check
  spec:
    containers:
    - name: web
      image: nginx
      ports:
      - containerPort: 80
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
  SOL
```

**Step 2: Write remaining Domain 3 scenarios**

| File | Source | Namespace | Difficulty | Key Validations |
|------|--------|-----------|------------|-----------------|
| `scenarios/domain-3/readiness-probe.yaml` | scenario-12 | monitoring | easy | `resource_field` (readinessProbe config), `container_running` |
| `scenarios/domain-3/debug-crashloop.yaml` | scenario-13 | debug-ns | medium | `container_running` (pod fixed), `command_output` (pod is Running not CrashLoop) |
| `scenarios/domain-3/container-logging.yaml` | scenario-14 | logging-ns | easy | `resource_exists`, `command_output` (kubectl logs contains expected output) |
| `scenarios/domain-3/fix-broken-probe.yaml` | scenario-15 | monitoring | medium | `container_running`, `resource_field` (probe port corrected). Setup deploys broken pod. |
| `scenarios/domain-3/kubectl-debug-ephemeral.yaml` | scenario-30 | debug-ns | hard | `command_output` (verify debug technique was used or target pod is running) |

**Step 3: Validate and commit**

```bash
for f in scenarios/domain-3/*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML syntax error: $f"
done
ckad-drill validate-scenario scenarios/domain-3/
git add scenarios/domain-3/
git commit -m "content: migrate 6 domain 3 scenarios to YAML format

Application Observability & Maintenance scenarios: liveness-probe,
readiness-probe, debug-crashloop, container-logging, fix-broken-probe,
kubectl-debug-ephemeral."
```

---

## Task 4: Migrate Domain 4 Scenarios — Application Environment, Configuration & Security (Story 8.1 partial)

**Files to create:** `scenarios/domain-4/*.yaml` (5 scenarios)

**Step 1: Write complete example — configmap and secret**

Create `scenarios/domain-4/configmap-secret.yaml`:
```yaml
id: configmap-secret
domain: 4
title: "ConfigMap and Secret in a Pod"
difficulty: medium
time_limit: 240
weight: 2
namespace: app-config
tags:
  - configmaps
  - secrets
  - environment

description: |
  In the `app-config` namespace:

  1. Create a ConfigMap named `app-config` with keys `APP_ENV=production` and `LOG_LEVEL=info`
  2. Create a Secret named `db-creds` with keys `username=admin` and `password=s3cret`
  3. Create a pod named `config-pod` using `busybox` (command: `sleep 3600`) that:
     - Loads all ConfigMap keys as environment variables using `envFrom`
     - Loads `password` from the Secret as env var `DB_PASS`
     - Mounts the Secret as a volume at `/etc/secrets`

hint: |
  Use `envFrom` with `configMapRef` for bulk injection. Use `env[].valueFrom.secretKeyRef`
  for a single secret key. Use `volumes[].secret.secretName` for volume mount.

setup: []

validations:
  - type: resource_exists
    resource: configmap/app-config
    description: "ConfigMap app-config exists"
  - type: resource_exists
    resource: secret/db-creds
    description: "Secret db-creds exists"
  - type: resource_exists
    resource: pod/config-pod
    description: "Pod config-pod exists"
  - type: container_env
    resource: pod/config-pod
    container: app
    env_name: APP_ENV
    expected: production
    description: "APP_ENV loaded from ConfigMap"
  - type: container_env
    resource: pod/config-pod
    container: app
    env_name: DB_PASS
    expected: s3cret
    description: "DB_PASS loaded from Secret"
  - type: volume_mount
    resource: pod/config-pod
    container: app
    mount_path: /etc/secrets
    description: "Secret mounted at /etc/secrets"
  - type: container_running
    resource: pod/config-pod
    container: app
    description: "Pod is running"

solution: |
  kubectl create configmap app-config -n app-config \
    --from-literal=APP_ENV=production --from-literal=LOG_LEVEL=info
  kubectl create secret generic db-creds -n app-config \
    --from-literal=username=admin --from-literal=password=s3cret
  cat <<'SOL' | kubectl apply -n app-config -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: config-pod
  spec:
    containers:
    - name: app
      image: busybox
      command: ["sleep", "3600"]
      envFrom:
      - configMapRef:
          name: app-config
      env:
      - name: DB_PASS
        valueFrom:
          secretKeyRef:
            name: db-creds
            key: password
      volumeMounts:
      - name: secrets
        mountPath: /etc/secrets
        readOnly: true
    volumes:
    - name: secrets
      secret:
        secretName: db-creds
  SOL
```

**Step 2: Write remaining Domain 4 scenarios**

| File | Source | Namespace | Difficulty | Key Validations |
|------|--------|-----------|------------|-----------------|
| `scenarios/domain-4/security-context.yaml` | scenario-17 | secure-apps | medium | `resource_field` (securityContext runAsUser, readOnlyRootFilesystem), `container_running` |
| `scenarios/domain-4/rbac-service-account.yaml` | scenario-18 | rbac-ns | hard | `resource_exists` (sa, role, rolebinding), `resource_field` (role rules), `command_output` (auth can-i) |
| `scenarios/domain-4/resource-limits.yaml` | scenario-19 | resource-ns | easy | `resource_field` (requests.cpu, limits.memory), `container_running` |
| `scenarios/domain-4/resource-quota.yaml` | scenario-20 | quota-ns | medium | `resource_exists` (resourcequota), `resource_field` (quota spec hard.pods, hard.cpu), `command_output` (describe quota) |

**Step 3: Validate and commit**

```bash
for f in scenarios/domain-4/*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML syntax error: $f"
done
ckad-drill validate-scenario scenarios/domain-4/
git add scenarios/domain-4/
git commit -m "content: migrate 5 domain 4 scenarios to YAML format

Application Environment, Configuration & Security scenarios:
configmap-secret, security-context, rbac-service-account,
resource-limits, resource-quota."
```

---

## Task 5: Migrate Domain 5 Scenarios — Services & Networking (Story 8.1 partial)

**Files to create:** `scenarios/domain-5/*.yaml` (6 scenarios)

**Step 1: Write complete example — network policy**

Create `scenarios/domain-5/network-policy-deny-all.yaml`:
```yaml
id: network-policy-deny-all
domain: 5
title: "Network Policy — Deny All Ingress"
difficulty: medium
time_limit: 180
weight: 2
namespace: secure-web
tags:
  - network-policy
  - security

description: |
  In the `secure-web` namespace:

  1. A deployment `web` with 2 replicas of `nginx` already exists (created by setup)
  2. Create a NetworkPolicy named `deny-all-ingress` that:
     - Applies to all pods in the namespace
     - Denies ALL ingress traffic
  3. Verify: attempting to curl a web pod from another pod should time out

hint: |
  A deny-all ingress policy uses an empty `podSelector: {}` (matches all pods)
  and `policyTypes: ["Ingress"]` with no `ingress` rules defined.

setup:
  - "kubectl create deployment web -n secure-web --image=nginx --replicas=2"
  - "kubectl expose deployment web -n secure-web --port=80"

validations:
  - type: resource_exists
    resource: networkpolicy/deny-all-ingress
    description: "NetworkPolicy deny-all-ingress exists"
  - type: resource_field
    resource: networkpolicy/deny-all-ingress
    jsonpath: "{.spec.policyTypes[0]}"
    expected: "Ingress"
    description: "Policy type includes Ingress"
  - type: resource_field
    resource: networkpolicy/deny-all-ingress
    jsonpath: "{.spec.podSelector}"
    expected: "{}"
    description: "Policy applies to all pods"
  - type: command_output
    command: "kubectl get networkpolicy deny-all-ingress -n secure-web -o jsonpath='{.spec.ingress}'"
    equals: ""
    description: "No ingress rules defined (deny all)"

solution: |
  cat <<'SOL' | kubectl apply -n secure-web -f -
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: deny-all-ingress
  spec:
    podSelector: {}
    policyTypes:
    - Ingress
  SOL
```

**Step 2: Write remaining Domain 5 scenarios**

| File | Source | Namespace | Difficulty | Key Validations |
|------|--------|-----------|------------|-----------------|
| `scenarios/domain-5/service-clusterip.yaml` | scenario-21 | services | easy | `resource_exists` (svc, deploy), `resource_field` (svc type, port, targetPort), `label_selector` |
| `scenarios/domain-5/ingress-resource.yaml` | scenario-22 | ingress-ns | medium | `resource_exists` (ingress), `resource_field` (ingress rules host, path, backend) |
| `scenarios/domain-5/network-policy-allow.yaml` | scenario-24 | secure-web | medium | `resource_exists` (netpol), `resource_field` (ingress.from podSelector), `command_output` (connectivity test) |
| `scenarios/domain-5/dns-resolution.yaml` | scenario-25 | dns-test | easy | `resource_exists` (svc, pod), `command_output` (nslookup service name resolves) |
| `scenarios/domain-5/ingress-tls.yaml` | scenario-26 | tls-ns | hard | `resource_exists` (secret, ingress), `resource_field` (ingress tls host, secretName) |

**Step 3: Validate and commit**

```bash
for f in scenarios/domain-5/*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML syntax error: $f"
done
ckad-drill validate-scenario scenarios/domain-5/
git add scenarios/domain-5/
git commit -m "content: migrate 6 domain 5 scenarios to YAML format

Services & Networking scenarios: service-clusterip, ingress-resource,
network-policy-deny-all, network-policy-allow, dns-resolution, ingress-tls."
```

---

## Task 6: Migrate Troubleshooting Labs to Debug Scenarios — Domain-Distributed (Story 8.2)

**Files to create:** 12 debug scenarios distributed across domains by topic.

**Step 1: Write complete example — debug image typo (lab-01)**

Create `scenarios/domain-5/debug-image-typo.yaml`:
```yaml
id: debug-image-typo
domain: 5
title: "Debug: Fix Image Name Typo"
difficulty: easy
time_limit: 120
weight: 1
namespace: debug-images
tags:
  - debug
  - troubleshooting
  - images

description: |
  A pod named `lab01-web` has been deployed in the `debug-images` namespace
  but it is stuck in an error state.

  1. Diagnose why the pod is failing
  2. Fix the issue so the pod runs successfully

  Do NOT delete and recreate the pod — fix it in place.

hint: |
  Check the pod events with `kubectl describe pod lab01-web`. Look at the
  image name carefully. Use `kubectl edit` or `kubectl set image` to fix.

setup:
  - |
    cat <<'BROKEN' | kubectl apply -n debug-images -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: lab01-web
    spec:
      containers:
      - name: web
        image: ngnix
        ports:
        - containerPort: 80
    BROKEN

validations:
  - type: container_image
    resource: pod/lab01-web
    container: web
    expected: nginx
    description: "Image name corrected to nginx"
  - type: container_running
    resource: pod/lab01-web
    container: web
    description: "Container is running after fix"

solution: |
  # Diagnose:
  kubectl describe pod lab01-web -n debug-images
  # Events show: Failed to pull image "ngnix" — image not found

  # Fix:
  kubectl set image pod/lab01-web web=nginx -n debug-images
  kubectl wait --for=condition=ready pod/lab01-web -n debug-images --timeout=60s
```

**Step 2: Write complete example — debug service port mismatch (lab-02)**

Create `scenarios/domain-5/debug-service-port.yaml`:
```yaml
id: debug-service-port
domain: 5
title: "Debug: Service targetPort Mismatch"
difficulty: easy
time_limit: 120
weight: 1
namespace: debug-svc
tags:
  - debug
  - troubleshooting
  - services

description: |
  A deployment `lab02-app` and service `lab02-svc` have been created in the
  `debug-svc` namespace. The service should route traffic to the nginx pods
  but connections are failing.

  1. Diagnose why the service cannot reach the pods
  2. Fix the service configuration

hint: |
  Compare the service's `targetPort` with the container's actual port.
  Use `kubectl describe svc lab02-svc` and check the endpoints.
  If endpoints are empty or the port is wrong, that is your clue.

setup:
  - |
    cat <<'BROKEN' | kubectl apply -n debug-svc -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: lab02-app
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: lab02
      template:
        metadata:
          labels:
            app: lab02
        spec:
          containers:
          - name: nginx
            image: nginx
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: lab02-svc
    spec:
      selector:
        app: lab02
      ports:
      - port: 80
        targetPort: 8080
    BROKEN

validations:
  - type: resource_field
    resource: service/lab02-svc
    jsonpath: "{.spec.ports[0].targetPort}"
    expected: "80"
    description: "Service targetPort corrected to 80"
  - type: command_output
    command: "kubectl get endpoints lab02-svc -n debug-svc -o jsonpath='{.subsets[0].ports[0].port}'"
    equals: "80"
    description: "Endpoints show correct port"

solution: |
  # Diagnose:
  kubectl describe svc lab02-svc -n debug-svc
  # targetPort is 8080 but containers listen on 80

  # Fix:
  kubectl patch svc lab02-svc -n debug-svc --type=json \
    -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

**Step 3: Write remaining debug scenarios**

Distribute across domains by topic. Each deploys the broken YAML from `archive/troubleshooting/broken/` as setup, then validates the fix.

| File | Lab | Domain | Namespace | Difficulty | Bug | Key Validations |
|------|-----|--------|-----------|------------|-----|-----------------|
| `scenarios/domain-1/debug-missing-volume-mount.yaml` | lab-03 | 1 | debug-volumes | easy | Volume declared but not mounted | `volume_mount` (mount exists), `container_running` |
| `scenarios/domain-5/debug-ingress-api-version.yaml` | lab-04 | 5 | debug-ingress | medium | Old deprecated Ingress API version | `resource_exists` (ingress), `resource_field` (correct apiVersion via annotation or working state) |
| `scenarios/domain-4/debug-label-selector-mismatch.yaml` | lab-05 | 4 | debug-labels | medium | Service selector does not match pod labels | `command_output` (endpoints not empty), `label_selector` |
| `scenarios/domain-3/debug-liveness-probe-port.yaml` | lab-06 | 3 | debug-probes | medium | Liveness probe wrong port | `resource_field` (probe port corrected), `container_running` |
| `scenarios/domain-4/debug-missing-secret.yaml` | lab-07 | 4 | debug-secrets | medium | Secret ref does not exist | `resource_exists` (secret), `container_running` |
| `scenarios/domain-1/debug-job-restart-policy.yaml` | lab-08 | 1 | debug-jobs | easy | Job restartPolicy is Always (invalid) | `resource_field` (restartPolicy is Never or OnFailure), `resource_field` (job succeeded) |
| `scenarios/domain-4/debug-cronjob-schedule.yaml` | lab-09 | 4 | debug-cron | easy | Invalid cron schedule (6 fields) | `resource_exists` (cronjob), `resource_field` (valid schedule) |
| `scenarios/domain-2/debug-selector-mismatch.yaml` | lab-10 | 2 | debug-deploy | hard | Deployment selector does not match template | `resource_field` (selector matches labels), `resource_field` (available replicas > 0) |
| `scenarios/domain-5/debug-netpol-missing-dns.yaml` | lab-11 | 5 | debug-netpol | hard | NetworkPolicy blocks DNS egress | `command_output` (DNS resolution works from pod), `resource_exists` (netpol) |
| `scenarios/domain-5/debug-multi-bug.yaml` | lab-12 | 5 | debug-multi | hard | Multiple bugs in one manifest | `container_running`, `command_output` (service reachable), all resources healthy |

**Step 4: Validate all debug scenarios**

```bash
for d in scenarios/domain-{1..5}; do
  for f in "$d"/debug-*.yaml; do
    [[ -f "$f" ]] && yq eval '.' "$f" > /dev/null || echo "YAML error: $f"
  done
done
ckad-drill validate-scenario scenarios/  # Validates everything
```

**Step 5: Commit**

```bash
git add scenarios/domain-*/debug-*.yaml
git commit -m "content: migrate 12 troubleshooting labs to debug scenarios

Debug scenarios with setup that deploys broken resources and validations
that verify the fix. Distributed across domains:
- Domain 1: debug-missing-volume-mount, debug-job-restart-policy
- Domain 2: debug-selector-mismatch
- Domain 3: debug-liveness-probe-port
- Domain 4: debug-label-selector-mismatch, debug-missing-secret, debug-cronjob-schedule
- Domain 5: debug-image-typo, debug-service-port, debug-ingress-api-version,
  debug-netpol-missing-dns, debug-multi-bug"
```

---

## Task 7: Extract Domain 1 Learn Scenarios (Story 8.3 partial)

**Files to create:**
- `scenarios/domain-1/learn-pods-and-volumes.yaml`
- `scenarios/domain-1/learn-multi-container-patterns.yaml`
- `scenarios/domain-1/learn-init-containers.yaml`
- `content/domain-1/pods-and-volumes.md`
- `content/domain-1/multi-container-patterns.md`
- `content/domain-1/init-containers.md`

**Step 1: Write complete example — learn pods and volumes**

Create `content/domain-1/pods-and-volumes.md` — extract from `archive/domains/01-design-build/tutorial.md` Lesson 1 concept text (the "Why pods exist" and "How volumes work" sections, cleaned up for standalone use).

Create `scenarios/domain-1/learn-pods-and-volumes.yaml`:
```yaml
id: learn-pods-and-volumes
domain: 1
title: "Learn: Pods, Containers, and Shared Volumes"
difficulty: easy
time_limit: 300
weight: 1
namespace: learn-pods
learn: true
concept_text: |
  A pod is a group of one or more containers that share two things:

  1. **Network namespace** — all containers in a pod share the same IP.
     Container A can reach container B on localhost.
  2. **Storage volumes** — containers can mount the same volume and
     read/write the same files.

  Volumes are declared at the pod level, then each container mounts
  whichever volumes it needs. `emptyDir` is the simplest volume type —
  it exists as long as the pod does. When the pod is deleted, the data
  is gone.

  Generate pod YAML fast on the exam:
  ```
  kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml
  ```
tags:
  - learn
  - pods
  - volumes

description: |
  Create a pod named `vol-pod` in the `learn-pods` namespace using `busybox` that:

  1. Runs the command: `while true; do date >> /data/date.txt; sleep 5; done`
  2. Mounts an emptyDir volume named `data` at `/data`

  Verify the pod is running and that `/data/date.txt` is being written to.

hint: |
  Use `spec.volumes` to declare an emptyDir, and `spec.containers[].volumeMounts`
  to mount it. The command goes in `spec.containers[].command` as an array.

setup: []

validations:
  - type: resource_exists
    resource: pod/vol-pod
    description: "Pod vol-pod exists"
  - type: container_running
    resource: pod/vol-pod
    container: writer
    description: "Container is running"
  - type: volume_mount
    resource: pod/vol-pod
    container: writer
    mount_path: /data
    description: "Volume mounted at /data"
  - type: command_output
    command: "kubectl exec -n learn-pods vol-pod -- cat /data/date.txt"
    matches: "\\d{4}"
    description: "date.txt contains date output"

solution: |
  cat <<'SOL' | kubectl apply -n learn-pods -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: vol-pod
  spec:
    containers:
    - name: writer
      image: busybox
      command: ["/bin/sh", "-c", "while true; do date >> /data/date.txt; sleep 5; done"]
      volumeMounts:
      - name: data
        mountPath: /data
    volumes:
    - name: data
      emptyDir: {}
  SOL
```

**Step 2: Write remaining Domain 1 learn scenarios**

| Scenario File | Content File | Source Lesson | Exercise |
|---------------|-------------|--------------|----------|
| `learn-multi-container-patterns.yaml` | `content/domain-1/multi-container-patterns.md` | Lesson 2 | Build sidecar pod with shared volume |
| `learn-init-containers.yaml` | `content/domain-1/init-containers.md` | Lesson 3 | Create pod with init container that writes config |

Each learn scenario follows the same pattern: `learn: true`, `concept_text` with relevant excerpt, exercise as `description`, progressive difficulty (easy to medium).

**Step 3: Validate and commit**

```bash
for f in scenarios/domain-1/learn-*.yaml; do
  yq eval '.' "$f" > /dev/null || echo "YAML error: $f"
done
git add scenarios/domain-1/learn-*.yaml content/domain-1/
git commit -m "content: add 3 domain 1 learn scenarios with concept text

Learn mode scenarios extracted from domain 1 tutorial:
learn-pods-and-volumes, learn-multi-container-patterns, learn-init-containers.
Each includes concept_text and corresponding content/ markdown."
```

---

## Task 8: Extract Domain 2 Learn Scenarios (Story 8.3 partial)

**Files to create:**
- `scenarios/domain-2/learn-deployments-and-replicas.yaml`
- `scenarios/domain-2/learn-rolling-updates.yaml`
- `scenarios/domain-2/learn-rollback-strategies.yaml`
- `content/domain-2/deployments-and-replicas.md`
- `content/domain-2/rolling-updates.md`
- `content/domain-2/rollback-strategies.md`

**Step 1: Extract from `archive/domains/02-deployment/tutorial.md`**

Each learn scenario: `learn: true`, concept text about the deployment topic, exercise that creates/updates a deployment.

| Scenario | Difficulty | Exercise Focus | Key Validations |
|----------|-----------|----------------|-----------------|
| `learn-deployments-and-replicas` | easy | Create deployment, scale it | `resource_exists`, `resource_field` (replicas) |
| `learn-rolling-updates` | easy | Update image, watch rollout | `resource_field` (image), `command_output` (rollout status) |
| `learn-rollback-strategies` | medium | Trigger bad update, rollback | `resource_field` (image reverted), `command_output` (rollout history) |

**Step 2: Validate and commit**

```bash
git add scenarios/domain-2/learn-*.yaml content/domain-2/
git commit -m "content: add 3 domain 2 learn scenarios with concept text

Learn mode scenarios: learn-deployments-and-replicas,
learn-rolling-updates, learn-rollback-strategies."
```

---

## Task 9: Extract Domain 3 Learn Scenarios (Story 8.3 partial)

**Files to create:**
- `scenarios/domain-3/learn-probes.yaml`
- `scenarios/domain-3/learn-container-logging.yaml`
- `scenarios/domain-3/learn-debugging-pods.yaml`
- `content/domain-3/probes.md`
- `content/domain-3/container-logging.md`
- `content/domain-3/debugging-pods.md`

| Scenario | Difficulty | Exercise Focus | Key Validations |
|----------|-----------|----------------|-----------------|
| `learn-probes` | easy | Add liveness + readiness probes | `resource_field` (probe config), `container_running` |
| `learn-container-logging` | easy | Read logs, multi-container logs | `command_output` (kubectl logs output) |
| `learn-debugging-pods` | medium | Diagnose failing pod using describe/logs | `container_running` (after fix), `command_output` |

**Validate and commit:**

```bash
git add scenarios/domain-3/learn-*.yaml content/domain-3/
git commit -m "content: add 3 domain 3 learn scenarios with concept text

Learn mode scenarios: learn-probes, learn-container-logging,
learn-debugging-pods."
```

---

## Task 10: Extract Domain 4 Learn Scenarios (Story 8.3 partial)

**Files to create:**
- `scenarios/domain-4/learn-configmaps.yaml`
- `scenarios/domain-4/learn-secrets.yaml`
- `scenarios/domain-4/learn-security-contexts.yaml`
- `content/domain-4/configmaps.md`
- `content/domain-4/secrets.md`
- `content/domain-4/security-contexts.md`

| Scenario | Difficulty | Exercise Focus | Key Validations |
|----------|-----------|----------------|-----------------|
| `learn-configmaps` | easy | Create ConfigMap, inject as env vars | `resource_exists` (cm), `container_env`, `container_running` |
| `learn-secrets` | easy | Create Secret, mount as volume | `resource_exists` (secret), `volume_mount`, `command_output` (cat secret file) |
| `learn-security-contexts` | medium | Set runAsUser, readOnlyRootFilesystem | `resource_field` (securityContext fields), `container_running` |

**Validate and commit:**

```bash
git add scenarios/domain-4/learn-*.yaml content/domain-4/
git commit -m "content: add 3 domain 4 learn scenarios with concept text

Learn mode scenarios: learn-configmaps, learn-secrets,
learn-security-contexts."
```

---

## Task 11: Extract Domain 5 Learn Scenarios (Story 8.3 partial)

**Files to create:**
- `scenarios/domain-5/learn-services.yaml`
- `scenarios/domain-5/learn-network-policies.yaml`
- `scenarios/domain-5/learn-dns-and-discovery.yaml`
- `content/domain-5/services.md`
- `content/domain-5/network-policies.md`
- `content/domain-5/dns-and-discovery.md`

| Scenario | Difficulty | Exercise Focus | Key Validations |
|----------|-----------|----------------|-----------------|
| `learn-services` | easy | Expose deployment, understand ClusterIP | `resource_exists` (svc), `resource_field` (type, port), `command_output` (curl service) |
| `learn-network-policies` | medium | Create deny-all then allow specific | `resource_exists` (netpol), `resource_field` (policy rules) |
| `learn-dns-and-discovery` | easy | Resolve service by name and FQDN | `command_output` (nslookup), `resource_exists` (pod, svc) |

**Validate and commit:**

```bash
git add scenarios/domain-5/learn-*.yaml content/domain-5/
git commit -m "content: add 3 domain 5 learn scenarios with concept text

Learn mode scenarios: learn-services, learn-network-policies,
learn-dns-and-discovery."
```

---

## Task 12: Final Validation Pass and ID Uniqueness Check

**Step 1: Validate all scenarios pass schema validation**

```bash
ckad-drill validate-scenario scenarios/
```

All scenarios must pass. Fix any that fail.

**Step 2: Check ID uniqueness across all files**

```bash
# Extract all IDs and check for duplicates
grep -rh '^id:' scenarios/ | sort | uniq -d
# Expected: no output (no duplicates)
```

**Step 3: Check domain coverage**

```bash
for d in 1 2 3 4 5; do
  count=$(ls scenarios/domain-$d/*.yaml 2>/dev/null | wc -l)
  echo "Domain $d: $count scenarios"
done
```

Expected minimum per domain:
- Domain 1: 7 drill + 2 debug + 3 learn = 12
- Domain 2: 7 drill + 1 debug + 3 learn = 11
- Domain 3: 6 drill + 1 debug + 3 learn = 10
- Domain 4: 5 drill + 3 debug + 3 learn = 11
- Domain 5: 6 drill + 5 debug + 3 learn = 14
- **Total: 58 scenarios**

**Step 4: Verify all learn scenarios have content files**

```bash
for f in scenarios/domain-*/learn-*.yaml; do
  domain=$(yq '.domain' "$f")
  id=$(yq '.id' "$f")
  content_name="${id#learn-}"
  content_file="content/domain-${domain}/${content_name}.md"
  [[ -f "$content_file" ]] || echo "Missing content: $content_file for $f"
done
```

**Step 5: Final commit if any fixes were needed**

```bash
git add -A
git diff --cached --quiet || git commit -m "fix: address validation errors from final review pass"
```

---

## Summary

| Task | Story | Deliverable | Scenario Count |
|------|-------|-------------|----------------|
| 1 | 8.1 | Domain 1 drill scenarios | 7 |
| 2 | 8.1 | Domain 2 drill scenarios | 7 |
| 3 | 8.1 | Domain 3 drill scenarios | 6 |
| 4 | 8.1 | Domain 4 drill scenarios | 5 |
| 5 | 8.1 | Domain 5 drill scenarios | 6 |
| 6 | 8.2 | Debug scenarios (all domains) | 12 |
| 7 | 8.3 | Domain 1 learn scenarios + content | 3 |
| 8 | 8.3 | Domain 2 learn scenarios + content | 3 |
| 9 | 8.3 | Domain 3 learn scenarios + content | 3 |
| 10 | 8.3 | Domain 4 learn scenarios + content | 3 |
| 11 | 8.3 | Domain 5 learn scenarios + content | 3 |
| 12 | — | Final validation and uniqueness check | — |
| | | **Total** | **58** |

**After Sprint 4:** 58 validated YAML scenarios across all 5 domains (31 drill + 12 debug + 15 learn). Each domain has at least 10 scenarios. All drill scenarios have hints and solutions. All debug scenarios deploy broken state and validate the fix. All learn scenarios have concept text and corresponding `content/` markdown files. Sprint 5 (Exam Mode) and Sprint 6 (Stories 8.4/8.5 + Learn Mode) will push the total past the 70+ NFR-06 target.

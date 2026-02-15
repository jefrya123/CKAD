# CKAD Domain 3: Application Observability and Maintenance

Work through these lessons in order. Each one builds on the last, so by the end you can diagnose any failing pod, read its logs, check its resource usage, and ensure it uses the right API versions. The pattern is: learn why something exists, understand how it works, then practice.

**Prerequisites:** A running cluster and `kubectl` configured. metrics-server installed for Lesson 4 (`kubectl top` commands).

---

## Lesson 1: Health Probes (Liveness, Readiness, Startup)

Kubernetes knows if a container process is running. But "process running" and "application healthy" are two very different things. Your web server process might be up but returning 500 errors. Your app might be stuck in a deadlock. Probes let you tell Kubernetes how to actually check your application's health.

### Why probes exist

Without probes, Kubernetes only knows one thing: is the container process alive? If the process exits, the container restarts. But if the process is alive but broken (deadlocked, out of memory, can't reach its database), Kubernetes happily keeps sending traffic to it.

Probes fix this by giving you three distinct health signals:

1. **Liveness probe** - "Is this container still working?" If it fails, Kubernetes **kills and restarts** the container. Use this to recover from deadlocks.
2. **Readiness probe** - "Can this container accept traffic right now?" If it fails, the pod is **removed from Service endpoints** but stays running. Use this when the app is temporarily unable to serve (loading cache, waiting for dependency).
3. **Startup probe** - "Has this container finished starting up?" While it's active, liveness and readiness probes are **disabled**. Use this for slow-starting apps that would otherwise get killed by the liveness probe before they're ready.

### The four probe mechanisms

Each probe can check health in one of four ways:

```yaml
# HTTP GET - most common for web apps
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080

# TCP Socket - check if a port is open
livenessProbe:
  tcpSocket:
    port: 3306

# Exec command - run a command inside the container
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy

# gRPC - for gRPC services
livenessProbe:
  grpc:
    port: 50051
```

### Timing parameters

These control how probes behave:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5       # Wait 5s after container start before first probe
  periodSeconds: 10            # Check every 10 seconds
  timeoutSeconds: 1            # Probe must respond within 1 second
  failureThreshold: 3          # 3 consecutive failures = unhealthy
  successThreshold: 1          # 1 success = healthy again (always 1 for liveness)
```

### Startup probe interaction

For slow-starting applications, liveness probes are dangerous. If your app takes 60 seconds to start but the liveness probe starts checking at 10 seconds, it will kill the container before it's ready - causing a restart loop.

The startup probe solves this:

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30          # 30 checks × 10s period = 300s max startup time
  periodSeconds: 10
livenessProbe:                   # Won't start until startup probe succeeds
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
```

Once the startup probe succeeds, it stops running and the liveness probe takes over.

### Exercises

**1.1** Create a pod called `liveness-http` with an `nginx` container that has an HTTP liveness probe checking `/` on port 80 every 5 seconds, starting 3 seconds after the container starts.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
```

```bash
kubectl apply -f liveness-http.yaml
kubectl describe pod liveness-http | grep -A 5 Liveness
# Should show the probe configuration and "started" events
```

</details>

**1.2** Create a pod called `liveness-exec` using `busybox` that:
- On startup, creates `/tmp/healthy`, sleeps 20 seconds, deletes the file, then sleeps forever
- Has an exec liveness probe that checks `cat /tmp/healthy` every 5 seconds with a failure threshold of 3

Watch the pod. It should run normally for ~20 seconds, then the liveness probe should start failing and the container should restart.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: app
    image: busybox
    command:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 20; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

```bash
kubectl apply -f liveness-exec.yaml
kubectl get pod liveness-exec -w

# After ~35 seconds (20s file exists + 15s for 3 failures), the container restarts
# Check restart count:
kubectl get pod liveness-exec
# RESTARTS column should increase
```

</details>

**1.3** Create a pod called `readiness-pod` with an `nginx` container that has:
- A readiness probe checking `/` on port 80, with `initialDelaySeconds: 10`

Watch the pod status. It should start as `0/1 Running` (not ready), then transition to `1/1 Running` after 10 seconds when the readiness probe first succeeds.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-pod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
```

```bash
kubectl apply -f readiness-pod.yaml
kubectl get pod readiness-pod -w
```

You'll see:
- `0/1 Running` immediately (container running but not ready)
- `1/1 Running` after ~10 seconds (readiness probe passes)

The difference from liveness: if readiness fails, the pod is just removed from Service endpoints - it's not killed and restarted.

</details>

**1.4** Create a pod called `slow-start` with a `busybox` container that:
- Simulates a slow startup: `sleep 30 && touch /tmp/started && sleep 3600`
- Has a startup probe (exec: `cat /tmp/started`) with `periodSeconds: 5` and `failureThreshold: 12` (allows up to 60s startup)
- Has a liveness probe (exec: `cat /tmp/started`) with `periodSeconds: 10`

Verify the liveness probe doesn't interfere during the 30-second startup period.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slow-start
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c", "sleep 30 && touch /tmp/started && sleep 3600"]
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      periodSeconds: 5
      failureThreshold: 12
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/started
      periodSeconds: 10
```

```bash
kubectl apply -f slow-start.yaml
kubectl get pod slow-start -w

# The pod stays Running with 0 restarts during the 30s startup
# Without the startup probe, the liveness probe would kill it before /tmp/started exists
kubectl describe pod slow-start | grep -A 3 "Startup\|Liveness"
```

</details>

### Cleanup

```bash
kubectl delete pod liveness-http liveness-exec readiness-pod slow-start
```

---

## Lesson 2: Container Logging

Probes tell Kubernetes if your app is healthy. But when something goes wrong, you need to see *what* went wrong. That's where logs come in.

### How Kubernetes logging works

Kubernetes captures everything your container writes to **stdout** and **stderr**. That's it. There's no special logging framework - if your app prints to stdout, `kubectl logs` can read it.

```bash
kubectl logs <pod-name>
```

This is why most containerized apps are configured to log to stdout instead of files. If your app writes to a file instead, you need a sidecar to ship those logs (you did this in Domain 1, Lesson 2).

### Key flags

```bash
kubectl logs <pod>                        # All logs from the (only) container
kubectl logs <pod> -c <container>         # Specific container in multi-container pod
kubectl logs <pod> --all-containers       # All containers in the pod
kubectl logs <pod> --previous             # Logs from the previous (crashed) container
kubectl logs <pod> -f                     # Follow/stream logs in real time
kubectl logs <pod> --tail=20              # Last 20 lines only
kubectl logs <pod> --since=1h             # Logs from the last hour
kubectl logs <pod> --since=5m             # Logs from the last 5 minutes
kubectl logs -l app=web                   # Logs from all pods matching a label
kubectl logs -l app=web --all-containers  # All containers in all matching pods
```

### Ephemeral nature of logs

Pod logs disappear when the pod is deleted. If the container restarts within the same pod, `--previous` shows the last container's logs. But once the pod is gone, the logs are gone. For production, you need a log aggregation solution (EFK stack, Loki, etc.) - but that's beyond the CKAD exam.

### Exercises

**2.1** Create a pod called `logger` using `busybox` that prints the date and a counter every 2 seconds. Use `kubectl logs` to:
- View the last 5 lines
- Follow the logs in real time (Ctrl+C to stop)
- Show only logs from the last 10 seconds

<details>
<summary>Solution</summary>

```bash
kubectl run logger --image=busybox -- /bin/sh -c 'i=0; while true; do echo "$(date) - line $i"; i=$((i+1)); sleep 2; done'

# Wait a few seconds for some logs to accumulate
kubectl logs logger --tail=5
kubectl logs logger -f              # Ctrl+C to stop
kubectl logs logger --since=10s
```

</details>

**2.2** Create a pod called `multi-log` with two containers:
- `app`: busybox that prints `APP: <date>` every 3 seconds
- `sidecar`: busybox that prints `SIDECAR: <date>` every 5 seconds

View logs from each container individually, then from both at once.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-log
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c", "while true; do echo \"APP: $(date)\"; sleep 3; done"]
  - name: sidecar
    image: busybox
    command: ["/bin/sh", "-c", "while true; do echo \"SIDECAR: $(date)\"; sleep 5; done"]
```

```bash
kubectl apply -f multi-log.yaml

# Individual containers
kubectl logs multi-log -c app
kubectl logs multi-log -c sidecar

# Both at once
kubectl logs multi-log --all-containers

# Both with container name prefix (useful for distinguishing)
kubectl logs multi-log --all-containers --prefix
```

</details>

**2.3** Create a pod called `crash-log` using `busybox` that prints `"Starting up..."`, sleeps 5 seconds, then exits with error code 1. After it crashes and restarts, use `--previous` to see the logs from the crashed container.

<details>
<summary>Solution</summary>

```bash
kubectl run crash-log --image=busybox -- /bin/sh -c 'echo "Starting up..."; sleep 5; exit 1'

# Wait for it to crash and restart
kubectl get pod crash-log -w    # Wait until RESTARTS >= 1

# View logs from the crashed (previous) container
kubectl logs crash-log --previous
# Should show "Starting up..."

# View logs from the current container
kubectl logs crash-log
# Also shows "Starting up..." (the new run)
```

</details>

### Cleanup

```bash
kubectl delete pod logger multi-log crash-log
```

---

## Lesson 3: Debugging Running Applications

Logs tell you what your app is saying. But sometimes the app can't even start, or the issue is in the environment, not the app code. You need a systematic approach to debugging.

### The debugging hierarchy

When a pod isn't working, check these in order:

1. **Status** - `kubectl get pod` shows the current state
2. **Events** - `kubectl describe pod` shows what happened (scheduling, image pulls, probe failures)
3. **Logs** - `kubectl logs` shows what the app said
4. **Exec** - `kubectl exec` lets you poke around inside the container
5. **Debug** - `kubectl debug` for containers that lack debugging tools

### Common failure states and their causes

| Status | Meaning | Likely cause |
|---|---|---|
| `ImagePullBackOff` | Can't pull the container image | Wrong image name, tag doesn't exist, private registry without credentials |
| `CrashLoopBackOff` | Container keeps crashing | App error, missing config/dependency, bad command |
| `Pending` | Not scheduled to a node | Insufficient resources, unsatisfiable nodeSelector, no PV for PVC |
| `Running` but not Ready | Container running but readiness probe failing | App hasn't started, dependency unavailable, probe misconfigured |
| `ErrImagePull` | First failed attempt to pull image | Same as ImagePullBackOff (it escalates) |
| `CreateContainerConfigError` | Can't create container config | Referenced ConfigMap/Secret doesn't exist |

### The debugging toolkit

```bash
# See pod status and restart count
kubectl get pod <name> -o wide

# See events, conditions, container states
kubectl describe pod <name>

# Check recent cluster events
kubectl get events --sort-by='.lastTimestamp'

# Run commands inside a running container
kubectl exec <pod> -- <command>
kubectl exec -it <pod> -- /bin/sh        # Interactive shell

# Copy files to/from a container
kubectl cp <pod>:/path/to/file ./local-file
kubectl cp ./local-file <pod>:/path/to/file

# Debug with an ephemeral container (when the image lacks tools)
kubectl debug <pod> -it --image=busybox
```

### 30-second exam triage

When you see a failing pod on the exam, run this sequence:

```bash
kubectl get pod <name>                    # What's the status?
kubectl describe pod <name> | tail -20    # What do the events say?
kubectl logs <name>                       # What did the app say?
```

This covers 90% of debugging scenarios in under 30 seconds.

### Exercises

**3.1** Create a pod called `bad-image` using the image `nginx:nonexistent`. Diagnose why it's failing and fix it.

<details>
<summary>Solution</summary>

```bash
kubectl run bad-image --image=nginx:nonexistent

# Step 1: Check status
kubectl get pod bad-image
# STATUS: ErrImagePull or ImagePullBackOff

# Step 2: Check events
kubectl describe pod bad-image | tail -10
# Events show "Failed to pull image" with "manifest unknown" error

# Step 3: Fix it
kubectl set image pod/bad-image bad-image=nginx:latest
# Or delete and recreate:
kubectl delete pod bad-image
kubectl run bad-image --image=nginx
```

The image tag `nonexistent` doesn't exist in the registry. The fix is to use a valid tag.

</details>

**3.2** Create a pod called `crash-debug` using `busybox` with command `exit 1`. Diagnose the CrashLoopBackOff and fix it so the pod runs normally.

<details>
<summary>Solution</summary>

```bash
kubectl run crash-debug --image=busybox -- /bin/sh -c "exit 1"

# Step 1: Check status
kubectl get pod crash-debug
# STATUS: CrashLoopBackOff (after a few seconds)

# Step 2: Check events
kubectl describe pod crash-debug | tail -15
# Events show container started and then terminated with exit code 1

# Step 3: Check logs
kubectl logs crash-debug
# Empty - it exits immediately

# Step 4: Fix - the command needs to actually run something
kubectl delete pod crash-debug
kubectl run crash-debug --image=busybox -- /bin/sh -c "echo 'running'; sleep 3600"

kubectl get pod crash-debug
# STATUS: Running
```

</details>

**3.3** Create a running pod called `exec-test` with `nginx`. Use `kubectl exec` to:
- Check the environment variables inside the container
- Verify the nginx process is running
- Check network connectivity by curling localhost
- Read the nginx config file

<details>
<summary>Solution</summary>

```bash
kubectl run exec-test --image=nginx

# Check environment variables
kubectl exec exec-test -- env

# Check running processes
kubectl exec exec-test -- ps aux
# Or if ps isn't available:
kubectl exec exec-test -- cat /proc/1/cmdline

# Check network
kubectl exec exec-test -- curl -s localhost

# Read nginx config
kubectl exec exec-test -- cat /etc/nginx/nginx.conf

# Interactive shell for deeper investigation
kubectl exec -it exec-test -- /bin/bash
```

</details>

**3.4** Create a pod called `pending-pod` that requests `99Gi` of memory. Diagnose why it's stuck in `Pending` state.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "99Gi"
```

```bash
kubectl apply -f pending-pod.yaml

# Step 1: Check status
kubectl get pod pending-pod
# STATUS: Pending

# Step 2: Check events
kubectl describe pod pending-pod | tail -10
# Events show: "0/X nodes are available: X Insufficient memory"

# The pod requests more memory than any node has available.
# Fix: reduce the memory request to something reasonable
kubectl delete pod pending-pod
kubectl run pending-pod --image=nginx    # Uses default (no explicit request)
```

The scheduler can't find any node with 99Gi of available memory, so the pod stays Pending forever. On the exam, check `describe` events for scheduling failures.

</details>

### Cleanup

```bash
kubectl delete pod bad-image crash-debug exec-test pending-pod
```

---

## Lesson 4: Monitoring with metrics-server

You've learned to check if pods are healthy (probes) and what they're saying (logs). But how much CPU and memory are they actually using? That's what metrics-server provides.

### Why metrics-server exists

Kubernetes doesn't track resource usage by default. The metrics-server is a lightweight, in-cluster component that:

1. Collects CPU and memory usage from each node's kubelet
2. Makes it available via `kubectl top`
3. Powers Horizontal Pod Autoscaler (HPA) decisions

It's **not** a full monitoring solution - it only keeps the latest snapshot, not historical data. For dashboards and alerts, you'd use Prometheus/Grafana. But for quick checks and the CKAD exam, `kubectl top` is what you need.

### Using kubectl top

```bash
# Node resource usage
kubectl top nodes
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# Pod resource usage
kubectl top pods
kubectl top pods -n kube-system
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
kubectl top pods -l app=web              # Filter by label
kubectl top pod <pod-name> --containers  # Per-container breakdown
```

### Connection to requests and limits

The output of `kubectl top` shows actual usage. Compare this to what you've *requested*:

- **Requests** - guaranteed minimum resources. Used by the scheduler to place pods.
- **Limits** - maximum allowed. Container is throttled (CPU) or killed (memory) if exceeded.

```yaml
resources:
  requests:
    cpu: 100m          # Guaranteed 0.1 CPU cores
    memory: 128Mi      # Guaranteed 128 MiB
  limits:
    cpu: 500m          # Can burst to 0.5 CPU cores
    memory: 256Mi      # Killed if exceeds 256 MiB (OOMKilled)
```

If `kubectl top` shows a pod using 250Mi of memory and its limit is 256Mi, it's about to get OOMKilled. If it's using 10m CPU but requested 500m, you're wasting resources.

### Exercises

**4.1** Check the resource usage of all nodes and all pods in the default namespace. Sort pods by CPU usage. Which pod is using the most CPU?

<details>
<summary>Solution</summary>

```bash
kubectl top nodes
kubectl top pods --sort-by=cpu
```

The first pod in the CPU-sorted list uses the most. If no pods are running, create some first:

```bash
kubectl create deployment web --image=nginx --replicas=3
# Wait a minute for metrics to be collected
kubectl top pods --sort-by=cpu
```

</details>

**4.2** Create a deployment called `monitored` with 3 replicas of `nginx`. Set resource requests to `50m` CPU and `64Mi` memory. Wait for metrics to populate, then compare actual usage vs. requested resources.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitored
spec:
  replicas: 3
  selector:
    matchLabels:
      app: monitored
  template:
    metadata:
      labels:
        app: monitored
    spec:
      containers:
      - name: nginx
        image: nginx
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
```

```bash
kubectl apply -f monitored.yaml
# Wait 60-90 seconds for metrics-server to collect data
kubectl top pods -l app=monitored

# Compare: actual CPU vs 50m requested, actual memory vs 64Mi requested
# Nginx at idle typically uses ~2m CPU and ~5Mi memory
# So the requests are generous - that's fine for guaranteed scheduling
```

</details>

**4.3** Create a pod called `cpu-hog` that consumes CPU intentionally. Use `busybox` with command `dd if=/dev/zero of=/dev/null`. Set a CPU limit of `200m`. Watch the usage with `kubectl top` and verify it stays at or near the limit.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-hog
spec:
  containers:
  - name: hog
    image: busybox
    command: ["/bin/sh", "-c", "dd if=/dev/zero of=/dev/null"]
    resources:
      limits:
        cpu: 200m
        memory: 64Mi
```

```bash
kubectl apply -f cpu-hog.yaml
# Wait 60-90 seconds for metrics
kubectl top pod cpu-hog

# CPU usage should be ~200m - capped at the limit
# Without the limit, it would consume an entire CPU core (1000m)
# The kernel throttles it to the 200m limit
```

</details>

### Cleanup

```bash
kubectl delete deployment monitored web
kubectl delete pod cpu-hog
```

---

## Lesson 5: API Deprecations and Maintenance

Everything so far has been about running applications. But the Kubernetes API itself changes over time. Resources you create today might use an API version that gets deprecated tomorrow. Knowing how to check and update API versions is essential for maintaining your manifests.

### Why API versions change

Kubernetes uses a maturity progression for API resources:

```
alpha (v1alpha1) → beta (v1beta1) → stable (v1)
```

- **alpha** - experimental, disabled by default, can change or be removed without notice
- **beta** - well-tested, enabled by default, might change before going stable
- **stable** - GA (generally available), will be maintained with backward compatibility

When a resource "graduates" (e.g., CronJob moved from `batch/v1beta1` to `batch/v1`), the old API version is eventually removed. If your manifests still use the old version, they'll stop working after an upgrade.

### Discovery commands

```bash
# What API versions does this cluster support?
kubectl api-versions

# What resources are available and which API group are they in?
kubectl api-resources

# Filter by API group
kubectl api-resources --api-group=apps
kubectl api-resources --api-group=batch

# Detailed info about a specific resource's spec
kubectl explain deployment
kubectl explain deployment.spec
kubectl explain deployment.spec.strategy
kubectl explain cronjob.spec.schedule
```

`kubectl explain` is your best friend on the exam. It shows the exact field names, types, and descriptions - faster than searching documentation.

### Common exam-relevant API changes

| Resource | Old API | Current API |
|---|---|---|
| CronJob | `batch/v1beta1` | `batch/v1` |
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` |
| HorizontalPodAutoscaler | `autoscaling/v2beta1` | `autoscaling/v2` |

When you see an old manifest on the exam, check the `apiVersion` first. If it uses a deprecated version, update it to the current one.

### Exercises

**5.1** Use `kubectl api-versions` and `kubectl api-resources` to answer:
- Is `batch/v1` available in your cluster?
- What resources are in the `apps` API group?
- What is the shortname for Deployments?

<details>
<summary>Solution</summary>

```bash
# Check if batch/v1 is available
kubectl api-versions | grep batch

# Resources in the apps group
kubectl api-resources --api-group=apps

# Shortname for Deployments
kubectl api-resources | grep -i deployment
# NAME          SHORTNAMES   APIVERSION   NAMESPACED   KIND
# deployments   deploy       apps/v1      true         Deployment
```

The shortname `deploy` lets you type `kubectl get deploy` instead of `kubectl get deployments`.

</details>

**5.2** Here's a CronJob manifest using a deprecated API version. Fix it so it uses the current API version:

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["/bin/sh", "-c", "echo 'Cleaning up...'"]
          restartPolicy: OnFailure
```

<details>
<summary>Solution</summary>

Change `apiVersion: batch/v1beta1` to `apiVersion: batch/v1`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["/bin/sh", "-c", "echo 'Cleaning up...'"]
          restartPolicy: OnFailure
```

```bash
kubectl apply -f cleanup-cronjob.yaml
kubectl get cronjob cleanup
```

The CronJob spec itself didn't change between `v1beta1` and `v1` - only the `apiVersion` field needs updating. Verify with `kubectl api-versions | grep batch` that `batch/v1` is available.

</details>

**5.3** Use `kubectl explain` to explore the Ingress resource:
- What API group is Ingress in?
- What fields does `spec.rules` contain?
- What is the `pathType` field and what are its valid values?

<details>
<summary>Solution</summary>

```bash
# Find the Ingress API group
kubectl api-resources | grep -i ingress
# Shows networking.k8s.io/v1

# Explore the spec
kubectl explain ingress
kubectl explain ingress.spec.rules

# Drill into the HTTP paths
kubectl explain ingress.spec.rules.http.paths
kubectl explain ingress.spec.rules.http.paths.pathType
```

The `pathType` field is required and can be:
- `Exact` - matches the URL path exactly
- `Prefix` - matches based on a URL path prefix split by `/`
- `ImplementationSpecific` - matching depends on the IngressClass

This is faster than Googling. On the exam, `kubectl explain` works even without internet access.

</details>

### Cleanup

```bash
kubectl delete cronjob cleanup
```

---

## Final Challenge

This exercise combines everything from all 5 lessons. No hints - just the task.

Create a deployment called `observable-app` with 2 replicas using `nginx` that:

1. Has all three probes:
   - **Liveness**: HTTP GET on `/` port 80, every 10 seconds
   - **Readiness**: HTTP GET on `/` port 80, every 5 seconds, initial delay 5 seconds
   - **Startup**: HTTP GET on `/` port 80, failure threshold 12, period 5 seconds

2. Has a **sidecar** container called `log-tailer` (busybox) that reads nginx access logs via a shared `emptyDir` volume mounted at `/var/log/nginx`

3. Has resource requests of `50m` CPU and `64Mi` memory, with limits of `200m` CPU and `128Mi` memory

4. Uses the correct `apiVersion` for a Deployment

After deploying:
- Check the readiness state transitions with `kubectl describe`
- View logs from both containers
- Check actual resource usage with `kubectl top`
- Verify the apiVersion is correct with `kubectl explain deployment`

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observable-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: observable-app
  template:
    metadata:
      labels:
        app: observable-app
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        startupProbe:
          httpGet:
            path: /
            port: 80
          failureThreshold: 12
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        volumeMounts:
        - name: logs
          mountPath: /var/log/nginx
      - name: log-tailer
        image: busybox
        command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: logs
        emptyDir: {}
```

```bash
kubectl apply -f observable-app.yaml

# Check readiness transitions
kubectl describe deployment observable-app
kubectl get pods -l app=observable-app -w

# View logs from both containers
POD=$(kubectl get pod -l app=observable-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -c nginx
kubectl logs $POD -c log-tailer

# Generate some traffic and check sidecar
kubectl exec $POD -c nginx -- curl -s localhost
kubectl logs $POD -c log-tailer

# Check resource usage (wait 60-90 seconds for metrics)
kubectl top pods -l app=observable-app --containers

# Verify API version
kubectl explain deployment | head -5
```

</details>

### Cleanup

```bash
kubectl delete deployment observable-app
```

---

## Quick Reference

### Probe types

| Probe | Purpose | On failure |
|---|---|---|
| Liveness | Is the container working? | Kill and restart |
| Readiness | Can it accept traffic? | Remove from Service endpoints |
| Startup | Has it finished starting? | Keep checking (blocks liveness/readiness) |

### Probe mechanisms

```yaml
httpGet:                    tcpSocket:              exec:                  grpc:
  path: /healthz              port: 3306              command:               port: 50051
  port: 8080                                          - cat
                                                      - /tmp/healthy
```

### Log commands

```bash
kubectl logs <pod>                      # Basic logs
kubectl logs <pod> -c <container>       # Specific container
kubectl logs <pod> --previous           # Crashed container's logs
kubectl logs <pod> -f                   # Follow/stream
kubectl logs <pod> --tail=N             # Last N lines
kubectl logs <pod> --since=1h           # Time-based filter
kubectl logs <pod> --all-containers     # All containers
kubectl logs -l app=web                 # By label selector
```

### Debugging commands

```bash
kubectl get pod <name>                  # Status check
kubectl describe pod <name>             # Events and conditions
kubectl get events --sort-by='.lastTimestamp'  # Cluster events
kubectl exec <pod> -- <cmd>             # Run command in container
kubectl exec -it <pod> -- /bin/sh       # Interactive shell
kubectl debug <pod> -it --image=busybox # Ephemeral debug container
kubectl cp <pod>:/path ./local          # Copy files out
```

### Resource monitoring

```bash
kubectl top nodes                       # Node CPU/memory
kubectl top pods --sort-by=cpu          # Pod CPU usage (sorted)
kubectl top pods --sort-by=memory       # Pod memory usage (sorted)
kubectl top pod <name> --containers     # Per-container breakdown
```

### Common failure states

| Status | First check | Likely fix |
|---|---|---|
| `ImagePullBackOff` | `describe` events | Fix image name/tag |
| `CrashLoopBackOff` | `logs --previous` | Fix command/config |
| `Pending` | `describe` events | Reduce resource requests or fix selectors |
| `Running` (not ready) | `describe` probe config | Fix readiness probe or app |
| `CreateContainerConfigError` | `describe` events | Create missing ConfigMap/Secret |

### What goes where

| Thing | YAML path |
|---|---|
| Liveness probe | `spec.containers[].livenessProbe` |
| Readiness probe | `spec.containers[].readinessProbe` |
| Startup probe | `spec.containers[].startupProbe` |
| Probe HTTP check | `probe.httpGet.path` + `probe.httpGet.port` |
| Probe exec check | `probe.exec.command[]` |
| Probe timing | `probe.initialDelaySeconds`, `probe.periodSeconds` |
| Resource requests | `spec.containers[].resources.requests` |
| Resource limits | `spec.containers[].resources.limits` |
| API version | `apiVersion` (top-level field) |

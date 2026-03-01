# Quiz: Domain 3 — Observability & Maintenance

## Q1: What's the difference between liveness and readiness probes?

<details>
<summary>Answer</summary>

- **Liveness**: "Is the container alive?" → failure **restarts** the container
- **Readiness**: "Can it receive traffic?" → failure **removes it from Service endpoints** (no restart)

</details>

## Q2: What does a startup probe do?

<details>
<summary>Answer</summary>

Blocks liveness and readiness probes until it succeeds. Used for slow-starting apps so the liveness probe doesn't kill them during startup.

</details>

## Q3: What's wrong with this probe config?

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 1
  failureThreshold: 1
```

<details>
<summary>Answer</summary>

Too aggressive: checks every 1 second with only 1 failure allowed and no initial delay. This will restart the container instantly if the app takes more than 1 second to start. Better: `initialDelaySeconds: 10`, `periodSeconds: 10`, `failureThreshold: 3`.

</details>

## Q4: How do you view logs from a container that already crashed?

<details>
<summary>Answer</summary>

```bash
kubectl logs <pod> --previous
kubectl logs <pod> -c <container> --previous
```

</details>

## Q5: Name 4 common pod statuses and their likely causes.

<details>
<summary>Answer</summary>

| Status | Cause |
|---|---|
| **Pending** | No node has enough resources, or node selector doesn't match |
| **ImagePullBackOff** | Wrong image name, private registry without auth |
| **CrashLoopBackOff** | Container starts and crashes repeatedly |
| **ContainerCreating** | Waiting for volume mount, configmap, or secret |

</details>

## Q6: Write the command to view events for a specific pod, sorted by time.

<details>
<summary>Answer</summary>

```bash
kubectl get events --field-selector involvedObject.name=<pod-name> --sort-by='.lastTimestamp'
```

Or more simply: `kubectl describe pod <pod-name>` (events are at the bottom).

</details>

## Q7: What are the three probe mechanisms? Give an example use case for each.

<details>
<summary>Answer</summary>

1. **httpGet** — web apps: `GET /healthz` returns 200
2. **tcpSocket** — databases: check if port 3306 is open
3. **exec** — custom: `cat /tmp/healthy` exits 0 if file exists

(Also **grpc** for gRPC services)

</details>

## Q8: How do you check CPU/memory usage of pods?

<details>
<summary>Answer</summary>

```bash
kubectl top pods                # all pods
kubectl top pods --sort-by=cpu  # sorted by CPU
kubectl top pods --containers   # per-container breakdown
kubectl top nodes               # node-level
```

Requires metrics-server to be installed.

</details>

## Q9: How do you get a shell inside a running container?

<details>
<summary>Answer</summary>

```bash
kubectl exec -it <pod> -- /bin/sh
kubectl exec -it <pod> -c <container> -- /bin/bash
```

</details>

## Q10: A pod shows `Init:0/2`. What does this mean?

<details>
<summary>Answer</summary>

The pod has 2 init containers and neither has completed yet. The first init container is still running (or failing). Regular containers won't start until both init containers exit successfully.

</details>

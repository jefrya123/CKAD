# Scenario 12: Readiness + Liveness Probes

**Domain:** Observability & Maintenance
**Time Limit:** 4 minutes

## Task

Create a pod named `probe-pod` with:
- Image: `nginx`
- **Liveness probe**: HTTP GET `/healthz` on port 80, period 10s
- **Readiness probe**: HTTP GET `/ready` on port 80, period 5s, initial delay 5s
- **Startup probe**: HTTP GET `/` on port 80, failure threshold 30, period 10s

---

<details>
<summary>💡 Hint</summary>

All three probes go at the same level under the container spec. Startup probe blocks the others until it passes.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-pod
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
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

```bash
kubectl apply -f probe-pod.yaml
kubectl describe pod probe-pod | grep -A5 -E "Liveness|Readiness|Startup"
```

</details>

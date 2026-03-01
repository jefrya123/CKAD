# Scenario 15: Fix Failing Probe

**Domain:** Observability & Maintenance
**Time Limit:** 3 minutes

## Task

1. Create this pod — it will restart repeatedly because the liveness probe fails:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-fix
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 3
```

2. Fix the pod so it stays running (nginx serves on port 80, not 8080)

---

<details>
<summary>💡 Hint</summary>

The probe checks port 8080 but nginx listens on port 80. Fix the probe port.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -f probe-fix.yaml
kubectl get pod probe-fix -w           # Watch restarts increase
kubectl describe pod probe-fix         # "Liveness probe failed: connection refused"

# Fix: edit the probe port from 8080 to 80
kubectl delete pod probe-fix --force --grace-period=0
# Update YAML: change port: 8080 to port: 80, and path to /
kubectl apply -f probe-fix.yaml
```

Fixed YAML:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-fix
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
```

</details>

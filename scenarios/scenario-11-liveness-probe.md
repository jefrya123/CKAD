# Scenario 11: Add Liveness Probe

**Domain:** Observability & Maintenance
**Time Limit:** 3 minutes

## Task

Create a pod named `healthy-app` with:
- Image: `nginx`
- HTTP liveness probe checking `/` on port 80
- Initial delay: 5 seconds
- Period: 10 seconds
- Failure threshold: 3

---

<details>
<summary>💡 Hint</summary>

Generate pod YAML, then add `livenessProbe` under the container spec.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: healthy-app
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
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3
```

```bash
kubectl apply -f healthy-app.yaml
kubectl describe pod healthy-app | grep -A5 Liveness
```

</details>

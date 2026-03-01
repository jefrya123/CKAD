# Scenario 19: Resource Limits

**Domain:** Config & Security
**Time Limit:** 3 minutes

## Task

Create a pod named `limited-app` with:
- Image: `nginx`
- CPU request: 100m, CPU limit: 200m
- Memory request: 64Mi, Memory limit: 128Mi

---

<details>
<summary>💡 Hint</summary>

`resources.requests` and `resources.limits` under the container spec.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limited-app
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
```

```bash
kubectl apply -f limited-app.yaml
kubectl describe pod limited-app | grep -A6 "Limits\|Requests"
```

</details>

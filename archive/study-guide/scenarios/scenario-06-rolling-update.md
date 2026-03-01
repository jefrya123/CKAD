# Scenario 06: Rolling Update

**Domain:** Application Deployment
**Time Limit:** 3 minutes

## Task

1. Create a deployment named `webapp` with image `nginx:1.19` and 4 replicas
2. Set the strategy to `RollingUpdate` with `maxSurge=1` and `maxUnavailable=1`
3. Update the image to `nginx:1.21`
4. Verify the rollout completed

---

<details>
<summary>💡 Hint</summary>

Create the deployment, generate YAML to add strategy, then `kubectl set image` to update.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 4
  selector:
    matchLabels:
      app: webapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
```

```bash
kubectl apply -f webapp.yaml
kubectl set image deploy/webapp nginx=nginx:1.21
kubectl rollout status deploy/webapp
kubectl describe deploy webapp | grep Image
```

</details>

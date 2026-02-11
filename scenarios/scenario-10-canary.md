# Scenario 10: Canary Deployment

**Domain:** Application Deployment
**Time Limit:** 5 minutes

## Task

1. Create a deployment `app-stable` with image `nginx:1.19`, 4 replicas, labels `app=myapp, track=stable`
2. Create a deployment `app-canary` with image `nginx:1.21`, 1 replica, labels `app=myapp, track=canary`
3. Create a ClusterIP service `myapp` that selects `app=myapp` (matches both)
4. Verify both deployments' pods are in the service endpoints

---

<details>
<summary>💡 Hint</summary>

The service selector should only use `app=myapp` (the common label), not `track`.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 4
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
```

```bash
kubectl apply -f canary.yaml
kubectl get endpoints myapp   # Should show 5 IPs (4 stable + 1 canary)
```

</details>

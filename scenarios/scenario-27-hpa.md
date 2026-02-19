# Scenario 27: Horizontal Pod Autoscaler

**Domain:** Application Deployment
**Time Limit:** 4 minutes

## Task

1. Create a deployment called `cpu-app` with 1 replica using the `nginx` image.
2. Set resource requests of `50m` CPU and `64Mi` memory on the container.
3. Create a Horizontal Pod Autoscaler (HPA) for `cpu-app` that:
   - Maintains between 2 and 8 replicas
   - Targets 60% average CPU utilization
4. Verify the HPA is created and shows the correct configuration.
5. Check the current replica count and CPU metrics.

---

<details>
<summary>💡 Hint</summary>

Use `kubectl autoscale deployment` to create the HPA imperatively. The deployment must have CPU resource requests defined for the HPA to work.

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create deployment with resource requests
kubectl create deploy cpu-app --image=nginx --replicas=1 $do > cpu-app.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-app
  template:
    metadata:
      labels:
        app: cpu-app
    spec:
      containers:
      - name: nginx
        image: nginx
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
```

```bash
kubectl apply -f cpu-app.yaml

# Create HPA
kubectl autoscale deploy cpu-app --min=2 --max=8 --cpu-percent=60

# Verify
kubectl get hpa cpu-app
kubectl describe hpa cpu-app
kubectl get deploy cpu-app    # replicas should scale to at least 2 (the minimum)
```

</details>

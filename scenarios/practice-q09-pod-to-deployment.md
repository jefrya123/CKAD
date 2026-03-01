# Practice Q09 — Pod to Deployment Conversion

**Mirrors KillerShell CKAD Question 9**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true

kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-api
  labels:
    app: neptune-api
    env: production
spec:
  containers:
  - name: api
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: APP_MODE
      value: production
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
EOF
```

---

## Your Task

The standalone pod `neptune-api` in namespace `neptune` needs to be converted to a Deployment:

1. Create a Deployment named `neptune-api` in namespace `neptune` with **3 replicas**
   - Use the same container spec as the existing pod (image, env, resources, ports, labels)
2. Delete the original standalone pod
3. Expose the deployment as a ClusterIP Service named `neptune-api-svc` on port `80`

---

## Verification

```bash
kubectl get deploy neptune-api -n neptune           # 3/3 READY
kubectl get pods -n neptune -l app=neptune-api      # 3 pods Running
kubectl get svc neptune-api-svc -n neptune
kubectl get endpoints neptune-api-svc -n neptune    # 3 endpoints
kubectl get pod neptune-api -n neptune 2>&1         # should say NotFound
```

---

<details>
<summary>💡 Hint</summary>

- Export the pod: `kubectl get pod neptune-api -n neptune -oyaml`
- Scaffold a deployment: `kubectl create deploy neptune-api --image=nginx:1.21 --replicas=3 -n neptune --dry-run=client -oyaml`
- Copy env, resources, labels from the pod into the deployment template
- `kubectl expose deploy neptune-api --port=80 --name=neptune-api-svc -n neptune`

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -n neptune -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: neptune-api
  namespace: neptune
spec:
  replicas: 3
  selector:
    matchLabels:
      app: neptune-api
  template:
    metadata:
      labels:
        app: neptune-api
        env: production
    spec:
      containers:
      - name: api
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: APP_MODE
          value: production
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

kubectl delete pod neptune-api -n neptune --force --grace-period=0

kubectl expose deploy neptune-api --port=80 --name=neptune-api-svc -n neptune
```

</details>

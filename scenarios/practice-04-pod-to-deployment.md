# Practice Scenario 04 — Pod to Deployment Migration

**Domain:** Application Design & Build
**Realistic difficulty:** ⭐⭐
**Time target:** 7 minutes

---

## Setup

```bash
kubectl create namespace saturn

kubectl apply -n saturn -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
  labels:
    app: legacy-app
    version: v1
spec:
  containers:
  - name: app
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: ENV_MODE
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

## Your Tasks

1. Convert the `legacy-app` pod into a **Deployment** named `legacy-app` in namespace `saturn`.
   - Keep all container settings (image, env, resources, ports, labels)
   - Set **3 replicas**

2. Delete the original standalone pod.

3. Expose the deployment as a **ClusterIP service** named `legacy-svc` on port `80`.

4. Confirm all 3 pods are Running and the service has 3 endpoints.

---

## Verification

```bash
kubectl get pods -n saturn -l app=legacy-app      # 3 Running
kubectl get deploy legacy-app -n saturn            # 3/3 READY
kubectl get endpoints legacy-svc -n saturn         # 3 pod IPs listed
kubectl get pod legacy-app -n saturn 2>&1 | grep "not found"  # original pod gone
```

---

<details>
<summary>💡 Hints</summary>

- Export the pod YAML: `kubectl get pod legacy-app -n saturn -o yaml > pod.yaml`
- Build a deployment scaffold: `kubectl create deploy legacy-app --image=nginx:1.21 --replicas=3 -n saturn --dry-run=client -o yaml > deploy.yaml`
- Copy env, resources, ports from the pod into the deployment's `spec.template.spec.containers[]`
- `kubectl expose deploy legacy-app --port=80 --name=legacy-svc -n saturn`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Export pod spec for reference
kubectl get pod legacy-app -n saturn -o yaml > /tmp/pod.yaml

# Create deployment with correct spec
kubectl apply -n saturn -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-app
  namespace: saturn
spec:
  replicas: 3
  selector:
    matchLabels:
      app: legacy-app
  template:
    metadata:
      labels:
        app: legacy-app
        version: v1
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENV_MODE
          value: production
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# Delete the original pod
kubectl delete pod legacy-app -n saturn --force --grace-period=0

# Expose as service
kubectl expose deploy legacy-app --port=80 --name=legacy-svc -n saturn
```

</details>

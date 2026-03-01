# Practice Q21 — Requests, Limits + ServiceAccount

**Mirrors KillerShell CKAD Question 21**
**Time target:** 8 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true
```

---

## Your Task

In namespace `neptune`:

1. Create a ServiceAccount named `neptune-sa`

2. Create **3 pods** named `neptune-pod-1`, `neptune-pod-2`, `neptune-pod-3`, each with:
   - Image: `nginx:1.21`
   - ServiceAccount: `neptune-sa`
   - Resource requests: `cpu: 100m`, `memory: 64Mi`
   - Resource limits: `cpu: 200m`, `memory: 128Mi`
   - Label: `id=neptune-pods`

3. Save the names of all 3 pods (one per line) to `/tmp/q21-pods.txt`

---

## Verification

```bash
kubectl get pods -n neptune -l id=neptune-pods         # 3 Running
kubectl get pods -n neptune -l id=neptune-pods -o jsonpath='{range .items[*]}{.spec.serviceAccountName}{"\n"}{end}'
# all should show: neptune-sa

kubectl describe pod neptune-pod-1 -n neptune | grep -A4 "Requests:\|Limits:"
cat /tmp/q21-pods.txt
```

---

<details>
<summary>💡 Hint</summary>

- Create the SA first — pods that reference a non-existent SA won't run
- `kubectl run` supports `--requests` and `--limits` flags for simple resource specs
- Or use `--dry-run=client -oyaml` to scaffold one, set all fields, then apply 3 times with different names

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create ServiceAccount
kubectl create sa neptune-sa -n neptune

# Create 3 pods
for i in 1 2 3; do
kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-pod-$i
  namespace: neptune
  labels:
    id: neptune-pods
spec:
  serviceAccountName: neptune-sa
  containers:
  - name: nginx
    image: nginx:1.21
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF
done

# Save pod names
kubectl get pods -n neptune -l id=neptune-pods \
  --no-headers -o custom-columns=":metadata.name" > /tmp/q21-pods.txt
cat /tmp/q21-pods.txt
```

</details>

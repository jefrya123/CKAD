# Practice Q06 — ReadinessProbe

**Mirrors KillerShell CKAD Question 6**
**Time target:** 5 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true

# Deploy a pod WITHOUT a readiness probe — you will add one
kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-probe-pod
  labels:
    id: neptune-probe-pod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF
```

---

## Your Task

The pod `neptune-probe-pod` in namespace `neptune` has no readiness probe. Add one:

- Type: `httpGet`
- Path: `/`
- Port: `80`
- `initialDelaySeconds: 10`
- `periodSeconds: 5`

The pod must show `1/1 READY` after the probe passes.

---

## Verification

```bash
kubectl get pod neptune-probe-pod -n neptune
# READY column should show 1/1
kubectl describe pod neptune-probe-pod -n neptune | grep -A8 "Readiness"
```

---

<details>
<summary>💡 Hint</summary>

- Pods are immutable — you must export the YAML, edit it, then `kubectl replace --force -f`
- The readinessProbe goes inside `containers[]`, at the same level as `image` and `ports`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Export current pod spec
kubectl get pod neptune-probe-pod -n neptune -oyaml > /tmp/probe-pod.yaml

# Edit /tmp/probe-pod.yaml — add under containers[0]:
#     readinessProbe:
#       httpGet:
#         path: /
#         port: 80
#       initialDelaySeconds: 10
#       periodSeconds: 5

# Also remove: status, metadata.resourceVersion, metadata.uid,
#              metadata.creationTimestamp, metadata.managedFields

kubectl replace --force -f /tmp/probe-pod.yaml -n neptune

kubectl get pod neptune-probe-pod -n neptune -w
```

</details>

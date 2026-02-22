# Practice Q02 — Pods

**Mirrors KillerShell CKAD Question 2**
**Time target:** 5 minutes

---

## Setup

Run this to create a broken starting state — someone tried to deploy a pod but got it wrong:

```bash
kubectl create namespace neptune 2>/dev/null || true

# A teammate deployed this pod but the spec is wrong
kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-pod
  labels:
    id: wrong-id
    app: neptune
spec:
  containers:
  - name: neptune-pod
    image: nginx:1.99-broken
EOF
```

---

## Your Tasks

The pod `neptune-pod` in namespace `neptune` was deployed incorrectly. Fix it so that:

1. The pod **image** is `nginx:1.21` (not the broken one)
2. The **container name** is `neptune-container` (not `neptune-pod`)
3. The **label** `id` has the value `neptune-pod` (not `wrong-id`)
4. The pod must reach **Running** state and be **1/1 Ready**

Then save the command to check the pod's status to `/tmp/q02-status-cmd.txt`

---

## Verification

```bash
kubectl get pod neptune-pod -n neptune               # Running, 1/1
kubectl describe pod neptune-pod -n neptune | grep "Container ID\|Image:\|id:"
# Container name:
kubectl get pod neptune-pod -n neptune \
  -o jsonpath='{.spec.containers[0].name}'           # neptune-container
# Label:
kubectl get pod neptune-pod -n neptune --show-labels # id=neptune-pod
cat /tmp/q02-status-cmd.txt
```

---

<details>
<summary>💡 Hints</summary>

- The pod has a bad image (`nginx:1.99-broken`) so it's in `ImagePullBackOff` — check with `kubectl get pod -n neptune`
- Pods are **immutable** — you can't `kubectl edit` the container name. You must delete and recreate.
- Export the current spec, fix it, delete the old pod, apply the fixed one
- `kubectl get pod neptune-pod -n neptune -o yaml > /tmp/fix.yaml` then edit the file

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Check what's broken
kubectl get pod neptune-pod -n neptune           # ImagePullBackOff
kubectl describe pod neptune-pod -n neptune      # see Events for the image error

# Delete the broken pod
kubectl delete pod neptune-pod -n neptune --force --grace-period=0

# Recreate with correct spec
kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-pod
  namespace: neptune
  labels:
    id: neptune-pod
    app: neptune
spec:
  containers:
  - name: neptune-container
    image: nginx:1.21
EOF

# Verify
kubectl get pod neptune-pod -n neptune -w

# Save status command
echo "kubectl get pod neptune-pod -n neptune" > /tmp/q02-status-cmd.txt
```

</details>

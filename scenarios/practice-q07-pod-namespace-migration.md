# Practice Q07 — Pod Namespace Migration

**Mirrors KillerShell CKAD Question 7**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true
kubectl create namespace pluto   2>/dev/null || true

kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  labels:
    app: webserver
    id: migrate-me
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: APP_ENV
      value: production
EOF
```

---

## Your Task

The pod `webserver` is currently in namespace `neptune`. Move it to namespace `pluto`:

1. Recreate the pod in namespace `pluto` with all the same spec (same name, image, labels, env vars)
2. Delete the original pod from namespace `neptune`

---

## Verification

```bash
kubectl get pod webserver -n pluto          # should exist and be Running
kubectl get pod webserver -n neptune        # should say "not found"
kubectl describe pod webserver -n pluto | grep -E "Image:|Labels:|APP_ENV"
```

---

<details>
<summary>💡 Hint</summary>

- Export with `kubectl get pod webserver -n neptune -oyaml > /tmp/pod.yaml`
- In the YAML, change `metadata.namespace` to `pluto`
- Remove these fields before applying: `status`, `metadata.uid`, `metadata.resourceVersion`, `metadata.creationTimestamp`, `metadata.managedFields`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Export
kubectl get pod webserver -n neptune -oyaml > /tmp/pod.yaml

# Edit /tmp/pod.yaml:
# - metadata.namespace: pluto
# - Delete: status: {}, metadata.uid, metadata.resourceVersion,
#           metadata.creationTimestamp, metadata.managedFields

# Apply in new namespace
kubectl apply -f /tmp/pod.yaml

# Verify it's running before deleting original
kubectl get pod webserver -n pluto

# Delete original
kubectl delete pod webserver -n neptune --force --grace-period=0
```

</details>

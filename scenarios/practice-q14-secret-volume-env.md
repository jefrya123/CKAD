# Practice Q14 — Secret as Volume and Env Var

**Mirrors KillerShell CKAD Question 14**
**Time target:** 7 minutes

---

## Setup

```bash
kubectl create namespace moon 2>/dev/null || true

kubectl apply -n moon -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: moon-secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
EOF
```

---

## Your Task

1. Create a Secret named `moon-creds` in namespace `moon` with:
   - `username=moon-admin`
   - `password=M00nP@ss!`

2. Modify the existing pod `moon-secret-pod` to:
   - Inject `username` as env var `SECRET_USER`
   - Inject `password` as env var `SECRET_PASS`
   - Mount the entire secret as a volume at `/etc/moon-creds` (both keys become files)

The pod must be Running with all injections working.

---

## Verification

```bash
kubectl exec moon-secret-pod -n moon -- env | grep SECRET_
kubectl exec moon-secret-pod -n moon -- ls /etc/moon-creds
kubectl exec moon-secret-pod -n moon -- cat /etc/moon-creds/username
kubectl exec moon-secret-pod -n moon -- cat /etc/moon-creds/password
```

---

<details>
<summary>💡 Hint</summary>

- Create the secret first: `kubectl create secret generic moon-creds --from-literal=...`
- Export the pod YAML, add both the env vars AND the volume mount, then `kubectl replace --force -f`
- The volume type is `secret:`, and `secretName` points to `moon-creds`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create secret
kubectl create secret generic moon-creds \
  --from-literal=username=moon-admin \
  --from-literal=password='M00nP@ss!' \
  -n moon

# Replace pod with updated spec
kubectl replace --force -n moon -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: moon-secret-pod
  namespace: moon
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    env:
    - name: SECRET_USER
      valueFrom:
        secretKeyRef:
          name: moon-creds
          key: username
    - name: SECRET_PASS
      valueFrom:
        secretKeyRef:
          name: moon-creds
          key: password
    volumeMounts:
    - name: creds-vol
      mountPath: /etc/moon-creds
      readOnly: true
  volumes:
  - name: creds-vol
    secret:
      secretName: moon-creds
EOF
```

</details>

# Practice Q05 — ServiceAccount + Secret Token

**Mirrors KillerShell CKAD Question 5**
**Time target:** 6 minutes

---

## Setup

Run this — it creates a realistic state with multiple ServiceAccounts and Secrets so you have to actually find the right one:

```bash
kubectl create namespace neptune 2>/dev/null || true

kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: neptune-sa
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: neptune-sa-admin
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-sa-admin-token
  namespace: neptune
  annotations:
    kubernetes.io/service-account.name: neptune-sa-admin
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-sa-token
  namespace: neptune
  annotations:
    kubernetes.io/service-account.name: neptune-sa
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-db-password
  namespace: neptune
type: Opaque
stringData:
  password: hunter2
EOF
```

---

## Your Tasks

1. List all Secrets in namespace `neptune` and identify which one belongs to ServiceAccount `neptune-sa` (not `neptune-sa-admin`)

2. Decode the token from that Secret and save the decoded value to `/tmp/q05-token.txt`

3. Confirm the token is a valid JWT: it should start with `eyJ` and have 3 dot-separated sections

4. Also save the **base64-encoded** (raw, not decoded) token value to `/tmp/q05-token-b64.txt` — the exam sometimes asks for both

---

## Verification

```bash
# Decoded token (JWT format)
cat /tmp/q05-token.txt | cut -d. -f1   # should be a base64 header starting with eyJ
cat /tmp/q05-token.txt | tr '.' '\n' | wc -l   # should print 3 (JWT has 3 parts)

# Base64 version
cat /tmp/q05-token-b64.txt   # long base64 string ending with ==
```

---

<details>
<summary>💡 Hints</summary>

- `kubectl get secrets -n neptune` — look at TYPE and NAME columns
- `kubectl describe secret neptune-sa-token -n neptune` — check the `Annotations` field to confirm which SA it's for
- Get the raw base64 token: `kubectl get secret neptune-sa-token -n neptune -o jsonpath='{.data.token}'`
- Decode it: pipe to `| base64 -d`
- Don't confuse `neptune-sa-token` (the right one) with `neptune-sa-admin-token` or `neptune-db-password`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. List secrets and identify the right one
kubectl get secrets -n neptune
kubectl describe secret neptune-sa-token -n neptune | grep "service-account.name"
# Confirms it's for neptune-sa (not neptune-sa-admin)

# 2. Decode and save
kubectl get secret neptune-sa-token -n neptune \
  -o jsonpath='{.data.token}' | base64 -d > /tmp/q05-token.txt

# 3. Verify JWT structure
cat /tmp/q05-token.txt    # starts with eyJ...

# 4. Also save the raw base64 version
kubectl get secret neptune-sa-token -n neptune \
  -o jsonpath='{.data.token}' > /tmp/q05-token-b64.txt
```

</details>

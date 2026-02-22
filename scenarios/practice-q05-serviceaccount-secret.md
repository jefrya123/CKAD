# Practice Q05 — ServiceAccount + Secret Token

**Mirrors KillerShell CKAD Question 5**
**Time target:** 5 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true

kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: neptune-sa
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-sa-token
  namespace: neptune
  annotations:
    kubernetes.io/service-account.name: neptune-sa
type: kubernetes.io/service-account-token
EOF
```

---

## Your Task

1. Find the ServiceAccount `neptune-sa` in namespace `neptune`
2. Get the token from the associated Secret `neptune-sa-token`
3. Decode the token from base64 and save the decoded value to `/tmp/q05-token.txt`

---

## Verification

```bash
cat /tmp/q05-token.txt
# Should be a long JWT string starting with "eyJ..."
# Confirm it's decoded (not base64): it should NOT end with ==
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl get secret neptune-sa-token -n neptune -o jsonpath='{.data.token}'` gets the base64 token
- Pipe to `base64 -d` (Linux) or `base64 --decode` to decode it
- Save the result, not the base64 version

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl get secret neptune-sa-token -n neptune -o jsonpath='{.data.token}' \
  | base64 -d > /tmp/q05-token.txt

cat /tmp/q05-token.txt
```

</details>

# Practice Q22 — Labels and Annotations

**Mirrors KillerShell CKAD Question 22**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace sunny 2>/dev/null || true

kubectl apply -n sunny -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-1
  labels:
    app: sunny
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-2
  labels:
    app: sunny
    tier: backend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-3
  labels:
    app: sunny
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-4
  labels:
    app: other
spec:
  containers:
  - name: nginx
    image: nginx
EOF
```

---

## Your Task

In namespace `sunny`:

1. Find all pods with label `app=sunny` and save their names (one per line) to `/tmp/q22-sunny-pods.txt`

2. Add the label `team=alpha` to all pods that have `tier=frontend`

3. Add the annotation `contact=team-sunny@company.com` to ALL pods with `app=sunny`

4. Remove the label `tier` from `sunny-pod-2`

5. Confirm the final state

---

## Verification

```bash
cat /tmp/q22-sunny-pods.txt
# sunny-pod-1, sunny-pod-2, sunny-pod-3

kubectl get pods -n sunny --show-labels
# sunny-pod-1: app=sunny,team=alpha,tier=frontend
# sunny-pod-2: app=sunny  (tier removed)
# sunny-pod-3: app=sunny,team=alpha,tier=frontend
# sunny-pod-4: app=other  (not touched)

kubectl get pods -n sunny -l app=sunny -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.annotations.contact}{"\n"}{end}'
# all 3 should show: contact=team-sunny@company.com
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl get pods -n sunny -l app=sunny --no-headers -o custom-columns=":metadata.name"` for names
- `kubectl label pods -n sunny -l tier=frontend team=alpha` labels all matching pods at once
- `kubectl annotate pods -n sunny -l app=sunny contact=team-sunny@company.com` annotates all matching
- `kubectl label pod sunny-pod-2 -n sunny tier-` removes a label (note the trailing `-`)

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Save pod names with app=sunny
kubectl get pods -n sunny -l app=sunny --no-headers \
  -o custom-columns=":metadata.name" > /tmp/q22-sunny-pods.txt

# 2. Add team=alpha to all tier=frontend pods
kubectl label pods -n sunny -l tier=frontend team=alpha

# 3. Annotate all app=sunny pods
kubectl annotate pods -n sunny -l app=sunny contact=team-sunny@company.com

# 4. Remove tier label from sunny-pod-2
kubectl label pod sunny-pod-2 -n sunny tier-

# 5. Verify
kubectl get pods -n sunny --show-labels
```

</details>

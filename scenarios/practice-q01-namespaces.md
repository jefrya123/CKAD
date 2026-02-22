# Practice Q01 — Namespaces

**Mirrors KillerShell CKAD Question 1**
**Time target:** 4 minutes

---

## Setup

Run this to create a realistic multi-team cluster state:

```bash
kubectl create namespace neptune   2>/dev/null || true
kubectl create namespace pluto     2>/dev/null || true
kubectl create namespace saturn    2>/dev/null || true
kubectl create namespace moon      2>/dev/null || true
kubectl create namespace earth     2>/dev/null || true

# Each namespace has some stuff running in it
kubectl run api      --image=nginx  -n neptune
kubectl run frontend --image=nginx  -n pluto
kubectl run db       --image=nginx  -n saturn
kubectl run cache    --image=redis  -n moon
kubectl run worker   --image=busybox -n earth -- sh -c "sleep 3600"
```

---

## Your Tasks

A team lead needs a full cluster inventory. Complete ALL of the following:

1. Save the full list of all namespaces (with their STATUS and AGE) to `/tmp/q01-namespaces.txt`

2. Find which namespaces have a pod running and save just those namespace **names** (one per line) to `/tmp/q01-active-ns.txt`

3. Count how many total pods exist across **all** namespaces (excluding kube-system) and save just the number to `/tmp/q01-pod-count.txt`

4. Find the name of the pod running in namespace `moon` and save it to `/tmp/q01-moon-pod.txt`

---

## Verification

```bash
cat /tmp/q01-namespaces.txt
echo "---"
cat /tmp/q01-active-ns.txt
echo "---"
cat /tmp/q01-pod-count.txt
echo "---"
cat /tmp/q01-moon-pod.txt   # should be: cache
```

---

<details>
<summary>💡 Hints</summary>

- `kubectl get ns` for the namespace list
- `kubectl get pods -A` shows pods across all namespaces — look at the NAMESPACE column
- `kubectl get pods -A --no-headers | grep -v kube-system | wc -l` for the count
- `kubectl get pods -n moon --no-headers -o custom-columns=":metadata.name"` for pod name only

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Full namespace list
kubectl get namespaces > /tmp/q01-namespaces.txt

# 2. Namespaces with running pods (excluding kube-system and default system namespaces)
kubectl get pods -A --no-headers \
  | grep -v "kube-system\|kube-public\|kube-node-lease" \
  | awk '{print $1}' | sort -u > /tmp/q01-active-ns.txt

# 3. Total pod count excluding kube-system
kubectl get pods -A --no-headers \
  | grep -v "kube-system\|kube-public\|kube-node-lease" \
  | wc -l > /tmp/q01-pod-count.txt

# 4. Pod in moon namespace
kubectl get pods -n moon --no-headers \
  -o custom-columns=":metadata.name" > /tmp/q01-moon-pod.txt
```

</details>

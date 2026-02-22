# Practice Q01 — Namespaces

**Mirrors KillerShell CKAD Question 1**
**Time target:** 3 minutes

---

## Setup

```bash
# Nothing to apply — namespaces already exist in your cluster
kubectl get namespaces
```

---

## Your Task

1. List all namespaces in the cluster and save the output to `/tmp/q01-namespaces.txt`
2. Count how many namespaces exist and save ONLY the count (a number) to `/tmp/q01-count.txt`

---

## Verification

```bash
cat /tmp/q01-namespaces.txt
cat /tmp/q01-count.txt
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl get namespaces` or `kubectl get ns`
- To count: pipe to `wc -l` but account for the header line

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl get namespaces > /tmp/q01-namespaces.txt

# Count (subtract 1 for the header line)
kubectl get ns --no-headers | wc -l > /tmp/q01-count.txt
```

</details>

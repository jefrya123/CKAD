# Practice Q03 — Job

**Mirrors KillerShell CKAD Question 3**
**Time target:** 5 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true

# A broken job has been deployed — it's stuck and not completing
kubectl apply -n neptune -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: neb-broken-job
spec:
  completions: 3
  parallelism: 1
  template:
    metadata:
      labels:
        id: neb-broken-job
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox
        command: ["/bin/sh", "-c", "sleep 2 && echo done"]
EOF
```

---

## Investigate First

Before doing anything, look at what's already running:

```bash
kubectl get jobs -n neptune
kubectl get pods -n neptune
kubectl describe job neb-broken-job -n neptune
```

**What do you notice?**
- How many completions has it reached?
- Is parallelism doing anything useful with `completions: 3` and `parallelism: 1`?
- What does the pod label say?

---

## Your Task

The broken job `neb-broken-job` runs only 1 pod at a time — inefficient for 3 completions.

1. **Delete** `neb-broken-job`

2. **Create a new Job** named `neb-new-job` in namespace `neptune`:
   - Image: `busybox`
   - Command: `/bin/sh -c "sleep 2 && echo done"`
   - `completions: 3`
   - `parallelism: 2`  ← key difference: 2 pods run simultaneously
   - Pod label: `id=neb-new-job`

3. **Watch the pods** as they run — you should see 2 pods at a time, not 1

4. After the job completes, **save the pod names** to `/tmp/q03-pods.txt`

---

## Verification

```bash
kubectl get job neb-new-job -n neptune
# COMPLETIONS should show 3/3

kubectl get pods -n neptune -l id=neb-new-job
# Should show 3 pods (all Completed)

kubectl get pods -n neptune -l id=neb-new-job -o name | sort > /tmp/q03-pods.txt
cat /tmp/q03-pods.txt

# Confirm parallelism worked (2 pods ran at the same time):
kubectl describe job neb-new-job -n neptune | grep -E "Parallelism|Completions"
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl create job` doesn't support `--completions` or `--parallelism` flags — scaffold YAML and edit manually
- The pod label goes in `spec.template.metadata.labels`, NOT in `spec.selector`
- Watch pods: `kubectl get pods -n neptune -w`
- The old broken job must be deleted first or the name will conflict

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Delete the broken job
kubectl delete job neb-broken-job -n neptune

# Scaffold YAML
kubectl create job neb-new-job --image=busybox -n neptune \
  --dry-run=client -oyaml -- /bin/sh -c "sleep 2 && echo done" > /tmp/job.yaml
```

Edit `/tmp/job.yaml` — add under `spec:`:
```yaml
spec:
  completions: 3
  parallelism: 2
  template:
    metadata:
      labels:
        id: neb-new-job   # ← add this
    spec:
      restartPolicy: Never
      containers:
      ...
```

```bash
kubectl apply -f /tmp/job.yaml

# Watch pods come up 2 at a time
kubectl get pods -n neptune -l id=neb-new-job -w

# Wait for all 3 to complete
kubectl wait --for=condition=complete job/neb-new-job -n neptune --timeout=60s

# Save pod names
kubectl get pods -n neptune -l id=neb-new-job -o name > /tmp/q03-pods.txt
cat /tmp/q03-pods.txt
```

</details>

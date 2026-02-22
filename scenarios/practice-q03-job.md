# Practice Q03 — Job

**Mirrors KillerShell CKAD Question 3**
**Time target:** 5 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true
```

---

## Your Task

Create a Job in namespace `neptune` with:
- Job name: `neb-new-job`
- Image: `busybox`
- Command: `/bin/sh -c "sleep 2 && echo done"`
- `completions: 3`
- `parallelism: 2`
- Pod label: `id=neb-new-job`

After creating, save the names of the pods created by the job to `/tmp/q03-pods.txt`

---

## Verification

```bash
kubectl get job neb-new-job -n neptune
kubectl get pods -n neptune -l id=neb-new-job
kubectl get pods -n neptune -l id=neb-new-job -o name | sort > /tmp/q03-pods.txt
cat /tmp/q03-pods.txt
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl create job` doesn't support `--completions` or `--parallelism` flags — scaffold YAML and add them manually
- The pod label goes in `spec.template.metadata.labels`, not `spec.selector`

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create job neb-new-job --image=busybox -n neptune \
  --dry-run=client -oyaml -- /bin/sh -c "sleep 2 && echo done" > /tmp/job.yaml
```

Edit `/tmp/job.yaml` to add under `spec:`:
```yaml
spec:
  completions: 3
  parallelism: 2
  template:
    metadata:
      labels:
        id: neb-new-job   # add this
    spec:
      ...
```

```bash
kubectl apply -f /tmp/job.yaml

# Wait for completion
kubectl get job neb-new-job -n neptune -w

# Save pod names
kubectl get pods -n neptune -l id=neb-new-job -o name > /tmp/q03-pods.txt
```

</details>

# Scenario 03: Create a Job

**Domain:** Application Design & Build
**Time Limit:** 2 minutes

## Task

Create a Job named `data-export` that:
- Uses image `busybox`
- Runs the command: `echo "Export completed successfully"`
- Must complete **3** times
- Runs up to **2** pods in parallel
- Has a backoff limit of 4

---

<details>
<summary>💡 Hint</summary>

`kubectl create job data-export --image=busybox --dry-run=client -o yaml -- echo "Export completed successfully"` then add `completions`, `parallelism`, `backoffLimit`.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-export
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: export
        image: busybox
        command: ["echo", "Export completed successfully"]
      restartPolicy: Never
```

```bash
kubectl apply -f data-export.yaml
kubectl get jobs data-export -w
kubectl logs job/data-export
```

</details>

# Scenario 04: CronJob with History Limits

**Domain:** Application Design & Build
**Time Limit:** 3 minutes

## Task

Create a CronJob named `log-cleaner` that:
- Runs every 10 minutes
- Uses image `busybox`
- Runs: `/bin/sh -c "echo Cleaning logs at $(date)"`
- Keeps **2** successful job history
- Keeps **1** failed job history
- Uses `concurrencyPolicy: Forbid`

---

<details>
<summary>💡 Hint</summary>

`kubectl create cronjob log-cleaner --image=busybox --schedule="*/10 * * * *" --dry-run=client -o yaml` then add history limits and concurrency policy.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-cleaner
spec:
  schedule: "*/10 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleaner
            image: busybox
            command: ["/bin/sh", "-c", "echo Cleaning logs at $(date)"]
          restartPolicy: OnFailure
```

```bash
kubectl apply -f log-cleaner.yaml
kubectl describe cronjob log-cleaner | grep -E "Schedule|Concurrency|History"
```

</details>

# Scenario 14: Container Logging

**Domain:** Observability & Maintenance
**Time Limit:** 2 minutes

## Task

1. Create a deployment `log-app` with image `busybox` and 2 replicas, command: `sh -c "while true; do echo $(date) INFO log message; sleep 5; done"`
2. View logs from **all** pods of the deployment at once
3. View last 5 log lines from one pod
4. Follow logs from one pod

---

<details>
<summary>💡 Hint</summary>

`kubectl logs -l app=log-app` for all pods. `--tail=5` for last N lines. `-f` to follow.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create deploy log-app --image=busybox --replicas=2 -- sh -c "while true; do echo \$(date) INFO log message; sleep 5; done"

# All pods
kubectl logs -l app=log-app

# Last 5 lines from first pod
POD=$(kubectl get pods -l app=log-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD --tail=5

# Follow
kubectl logs $POD -f
```

</details>

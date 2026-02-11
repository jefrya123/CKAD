# Scenario 13: Debug CrashLoopBackOff

**Domain:** Observability & Maintenance
**Time Limit:** 3 minutes

## Task

A pod is crashing. Debug and fix it.

1. Create the broken pod: `kubectl run crasher --image=busybox -- /bin/sh -c "exit 1"`
2. Identify why it's in CrashLoopBackOff
3. Delete it and recreate with a working command that keeps it running

---

<details>
<summary>💡 Hint</summary>

Check `kubectl logs crasher --previous` and `kubectl describe pod crasher`. The container exits immediately with code 1.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl run crasher --image=busybox -- /bin/sh -c "exit 1"
kubectl get pod crasher           # CrashLoopBackOff
kubectl logs crasher --previous   # No useful output
kubectl describe pod crasher      # "Back-off restarting failed container"

# The command exits with code 1. Fix it:
kubectl delete pod crasher --force --grace-period=0
kubectl run crasher --image=busybox -- /bin/sh -c "echo running; sleep 3600"
kubectl get pod crasher           # Running
```

</details>

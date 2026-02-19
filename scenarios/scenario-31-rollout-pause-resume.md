# Scenario 31: Rollout Pause and Resume

**Domain:** Application Deployment
**Time Limit:** 3 minutes

## Task

1. Create a deployment called `rolling-app` with 4 replicas using `nginx:1.20`.
2. Start an image update to `nginx:1.21` but immediately **pause** the rollout before it completes.
3. Verify that the rollout is paused and only some pods have been updated (check the deployment status and ReplicaSets).
4. **Resume** the rollout and wait for it to complete.
5. Verify all pods are now running `nginx:1.21`.

---

<details>
<summary>💡 Hint</summary>

Use `kubectl rollout pause` immediately after setting the new image. Check `kubectl get replicasets` to see old and new ReplicaSets coexisting. Use `kubectl rollout resume` to continue.

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create deployment
kubectl create deploy rolling-app --image=nginx:1.20 --replicas=4
kubectl rollout status deploy/rolling-app

# Start update and immediately pause
kubectl set image deploy/rolling-app nginx=nginx:1.21
kubectl rollout pause deploy/rolling-app

# Verify paused state
kubectl rollout status deploy/rolling-app
# deployment "rolling-app" rollout paused

kubectl get rs -l app=rolling-app
# Two ReplicaSets: old (some pods) and new (some pods)

# Resume the rollout
kubectl rollout resume deploy/rolling-app
kubectl rollout status deploy/rolling-app
# deployment "rolling-app" successfully rolled out

# Verify all pods have new image
kubectl get pods -l app=rolling-app -o jsonpath='{.items[*].spec.containers[0].image}'
# nginx:1.21 nginx:1.21 nginx:1.21 nginx:1.21
```

</details>

# Practice Scenario 01 — Rollout Rescue

**Domain:** Deployment & Rollouts
**Realistic difficulty:** ⭐⭐⭐
**Time target:** 8 minutes

---

## Setup

Run this to create the starting state — don't read further until it's applied:

```bash
kubectl create namespace neptune
kubectl create deployment web --image=nginx:1.19 --replicas=3 -n neptune
kubectl set image deployment/web nginx=nginx:1.20 -n neptune
kubectl set image deployment/web nginx=nginx:1.21 -n neptune
kubectl set image deployment/web nginx=nginx:1.bad-version -n neptune
```

---

## Your Tasks

1. The `web` deployment in namespace `neptune` is broken — pods are failing. Find out what's wrong.

2. Roll back to the last **working** version (not just the previous revision — find the one where pods were actually healthy).

3. Scale the deployment to **5 replicas** after the rollback.

4. Add the annotation `"rollback-reason": "bad-image"` to the deployment.

5. Save the full rollout history to `/tmp/web-history.txt`

---

## Verification

```bash
kubectl get pods -n neptune                          # all 5 should be Running
kubectl get deploy web -n neptune                    # 5/5 READY
kubectl rollout history deploy/web -n neptune        # shows history
kubectl get deploy web -n neptune -o jsonpath='{.metadata.annotations}'
cat /tmp/web-history.txt
```

---

<details>
<summary>💡 Hints (read only if stuck)</summary>

- `kubectl rollout history deploy/web -n neptune` shows all revisions
- `kubectl rollout history deploy/web -n neptune --revision=N` shows the image used in revision N
- `kubectl rollout undo deploy/web -n neptune --to-revision=N` rolls back to a specific one
- Annotate with: `kubectl annotate deploy/web -n neptune rollback-reason="bad-image"`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Diagnose
kubectl get pods -n neptune                          # some in ImagePullBackOff
kubectl rollout history deploy/web -n neptune        # see 4 revisions

# 2. Find the last working revision (nginx:1.21 was the last good one — revision 3)
kubectl rollout history deploy/web -n neptune --revision=3
kubectl rollout undo deploy/web -n neptune --to-revision=3

# 3. Scale to 5
kubectl scale deploy/web --replicas=5 -n neptune

# 4. Annotate
kubectl annotate deploy/web -n neptune rollback-reason="bad-image"

# 5. Save history
kubectl rollout history deploy/web -n neptune > /tmp/web-history.txt
```

</details>

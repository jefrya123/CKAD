# Practice Q08 — Deployment Rollout Debug & Rollback

**Mirrors KillerShell CKAD Question 8**
**Time target:** 7 minutes

---

## Setup

```bash
kubectl create namespace neptune 2>/dev/null || true

# Create deployment and push it through 3 image updates — last one is bad
kubectl create deployment neptune-web --image=nginx:1.19 -n neptune
sleep 3
kubectl set image deployment/neptune-web nginx=nginx:1.20 -n neptune
sleep 3
kubectl set image deployment/neptune-web nginx=nginx:1.21 -n neptune
sleep 3
kubectl set image deployment/neptune-web nginx=nginx:99.99-broken -n neptune
```

---

## Your Task

The deployment `neptune-web` in namespace `neptune` is broken.

1. Find out what's wrong (what caused it to break)
2. Roll back to the last **working** revision — identify the specific revision number first, don't just blindly undo
3. Confirm all pods are Running after the rollback
4. Save the rollout history to `/tmp/q08-history.txt`

---

## Verification

```bash
kubectl get pods -n neptune                      # all Running
kubectl get deploy neptune-web -n neptune        # READY matches DESIRED
cat /tmp/q08-history.txt
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl rollout history deploy/neptune-web -n neptune` lists all revisions
- `kubectl rollout history deploy/neptune-web -n neptune --revision=N` shows what image was used
- The last working revision used `nginx:1.21` — find its revision number
- `kubectl rollout undo deploy/neptune-web -n neptune --to-revision=N`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Check status
kubectl rollout status deploy/neptune-web -n neptune   # error
kubectl get pods -n neptune                            # ImagePullBackOff

# 2. Check history
kubectl rollout history deploy/neptune-web -n neptune
# Revision 3 was nginx:1.21 (last good one)

# 3. Roll back to revision 3
kubectl rollout undo deploy/neptune-web -n neptune --to-revision=3

# 4. Verify
kubectl rollout status deploy/neptune-web -n neptune
kubectl get pods -n neptune

# 5. Save history
kubectl rollout history deploy/neptune-web -n neptune > /tmp/q08-history.txt
```

</details>

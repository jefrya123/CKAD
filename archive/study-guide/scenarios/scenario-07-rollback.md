# Scenario 07: Rollback Deployment

**Domain:** Application Deployment
**Time Limit:** 2 minutes

## Task

1. Create a deployment `api-server` with image `nginx:1.19` and 3 replicas
2. Update image to `nginx:1.20`
3. Update image to `nginx:1.21`
4. Rollback to revision 1 (nginx:1.19)
5. Verify the image is `nginx:1.19`

---

<details>
<summary>💡 Hint</summary>

`kubectl rollout history` to see revisions, `kubectl rollout undo --to-revision=1` to rollback.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create deploy api-server --image=nginx:1.19 --replicas=3
kubectl set image deploy/api-server nginx=nginx:1.20
kubectl set image deploy/api-server nginx=nginx:1.21
kubectl rollout history deploy/api-server
kubectl rollout undo deploy/api-server --to-revision=1
kubectl describe deploy api-server | grep Image
# Should show: nginx:1.19
```

</details>

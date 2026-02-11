# Scenario 09: Scale & Update Deployment

**Domain:** Application Deployment
**Time Limit:** 2 minutes

## Task

1. Create a deployment `frontend` with image `httpd:2.4` and 2 replicas
2. Scale to 5 replicas
3. Change the image to `httpd:2.4-alpine`
4. Verify all 5 pods are running the alpine image

---

<details>
<summary>💡 Hint</summary>

`kubectl scale` and `kubectl set image` — two commands.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create deploy frontend --image=httpd:2.4 --replicas=2
kubectl scale deploy frontend --replicas=5
kubectl set image deploy/frontend httpd=httpd:2.4-alpine
kubectl rollout status deploy/frontend
kubectl get pods -l app=frontend -o jsonpath='{.items[*].spec.containers[0].image}'
# Should show: httpd:2.4-alpine (5 times)
```

</details>

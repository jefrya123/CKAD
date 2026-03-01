# Scenario 21: Expose Deployment as Service

**Domain:** Services & Networking
**Time Limit:** 2 minutes

## Task

1. Create a deployment `web-app` with image `nginx` and 3 replicas
2. Expose it as a ClusterIP service named `web-svc` on port 80
3. Verify the service has 3 endpoints
4. Test connectivity from a temporary pod

---

<details>
<summary>💡 Hint</summary>

`kubectl expose deployment web-app --name=web-svc --port=80`

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create deploy web-app --image=nginx --replicas=3
kubectl expose deploy web-app --name=web-svc --port=80
kubectl get endpoints web-svc           # 3 IPs
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://web-svc
```

</details>

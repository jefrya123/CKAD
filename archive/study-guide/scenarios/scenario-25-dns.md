# Scenario 25: DNS Debugging

**Domain:** Services & Networking
**Time Limit:** 3 minutes

## Task

1. Create a deployment `dns-test` with image `nginx` in namespace `dns-ns`
2. Expose it as a ClusterIP service `dns-svc` on port 80
3. From a temporary busybox pod in the **same namespace**, resolve:
   - `dns-svc`
   - `dns-svc.dns-ns`
   - `dns-svc.dns-ns.svc.cluster.local`
4. From a temporary pod in the **default namespace**, resolve `dns-svc.dns-ns`

---

<details>
<summary>💡 Hint</summary>

Short names work within the same namespace. Cross-namespace needs `<svc>.<namespace>`.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create ns dns-ns
kubectl create deploy dns-test --image=nginx -n dns-ns
kubectl expose deploy dns-test --name=dns-svc --port=80 -n dns-ns

# Same namespace
kubectl run tmp --image=busybox -n dns-ns --rm -it --restart=Never -- nslookup dns-svc
kubectl run tmp2 --image=busybox -n dns-ns --rm -it --restart=Never -- nslookup dns-svc.dns-ns.svc.cluster.local

# Cross namespace
kubectl run tmp3 --image=busybox --rm -it --restart=Never -- nslookup dns-svc.dns-ns
```

</details>

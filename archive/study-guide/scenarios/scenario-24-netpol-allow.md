# Scenario 24: Network Policy — Allow Specific Traffic

**Domain:** Services & Networking
**Time Limit:** 5 minutes

## Task

1. Create namespace `app-ns`
2. Create pod `backend` with label `role=backend` running `nginx` in `app-ns`
3. Create pod `frontend` with label `role=frontend` running `busybox` (sleep 3600) in `app-ns`
4. Create pod `rogue` with label `role=rogue` running `busybox` (sleep 3600) in `app-ns`
5. Create a NetworkPolicy that:
   - Applies to pods with `role=backend`
   - Only allows ingress from pods with `role=frontend` on port 80

6. Verify: `frontend` can reach `backend`, `rogue` cannot.

---

<details>
<summary>💡 Hint</summary>

The `from` selector uses `podSelector.matchLabels`. The `ports` list specifies allowed ports.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create ns app-ns
kubectl run backend --image=nginx -n app-ns -l role=backend
kubectl run frontend --image=busybox -n app-ns -l role=frontend -- sleep 3600
kubectl run rogue --image=busybox -n app-ns -l role=rogue -- sleep 3600
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - port: 80
      protocol: TCP
```

```bash
kubectl apply -f netpol.yaml
# frontend → backend: works
kubectl exec -n app-ns frontend -- wget -qO- --timeout=3 http://backend
# rogue → backend: blocked
kubectl exec -n app-ns rogue -- wget -qO- --timeout=3 http://backend 2>&1
```

</details>

# Scenario 23: Network Policy — Deny All Ingress

**Domain:** Services & Networking
**Time Limit:** 3 minutes

## Task

1. Create namespace `secure-ns`
2. Create a pod `web` running `nginx` in `secure-ns`
3. Create a NetworkPolicy `deny-all` in `secure-ns` that denies all ingress to all pods

---

<details>
<summary>💡 Hint</summary>

Empty `podSelector: {}` selects all pods. `policyTypes: [Ingress]` with no `ingress` rules means deny all.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create ns secure-ns
kubectl run web --image=nginx -n secure-ns
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secure-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
kubectl apply -f deny-all.yaml
# Test: this should timeout
kubectl run tmp --image=busybox -n secure-ns --rm -it --restart=Never -- wget -qO- --timeout=3 http://web 2>&1
```

</details>

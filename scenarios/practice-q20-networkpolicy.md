# Practice Q20 — NetworkPolicy

**Mirrors KillerShell CKAD Question 20**
**Time target:** 8 minutes

---

## Setup

```bash
kubectl create namespace venus 2>/dev/null || true
kubectl create namespace mars   2>/dev/null || true

kubectl label namespace venus name=venus --overwrite
kubectl label namespace mars  name=mars  --overwrite

kubectl apply -n venus -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: venus-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: venus-app
  template:
    metadata:
      labels:
        app: venus-app
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: venus-svc
spec:
  selector:
    app: venus-app
  ports:
  - port: 80
EOF

kubectl run mars-pod --image=busybox -n mars --labels="app=mars-pod" \
  -- sh -c "sleep 3600"
kubectl run external-pod --image=busybox -n venus --labels="app=external" \
  -- sh -c "sleep 3600"
```

---

## Your Task

Apply a NetworkPolicy named `venus-netpol` in namespace `venus` that:

1. Targets pods with label `app: venus-app`
2. **Allows ingress** ONLY from pods in namespace `mars` (use the `name=mars` namespace label)
3. **Denies ingress** from everything else — including `external-pod` which is in the same namespace

Test both after applying.

---

## Verification

```bash
# Should SUCCEED (mars namespace is allowed):
kubectl exec -n mars mars-pod -- wget -qO- --timeout=3 \
  $(kubectl get svc venus-svc -n venus -o jsonpath='{.spec.clusterIP}') && echo "OK"

# Should FAIL (external-pod is in venus ns but not from mars):
kubectl exec -n venus external-pod -- wget -qO- --timeout=3 \
  $(kubectl get svc venus-svc -n venus -o jsonpath='{.spec.clusterIP}') && echo "OK" || echo "BLOCKED"
```

---

<details>
<summary>💡 Hint</summary>

- `namespaceSelector` with `matchLabels: {name: mars}` selects pods from the mars namespace
- List `policyTypes: [Ingress]` with explicit ingress rules — anything not listed is denied
- No need to specify `Egress` — leaving it out means egress is unrestricted

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -n venus -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: venus-netpol
  namespace: venus
spec:
  podSelector:
    matchLabels:
      app: venus-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: mars
EOF
```

</details>

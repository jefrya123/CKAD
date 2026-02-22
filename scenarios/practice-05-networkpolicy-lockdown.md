# Practice Scenario 05 — NetworkPolicy Lockdown

**Domain:** Services & Networking
**Realistic difficulty:** ⭐⭐⭐⭐
**Time target:** 10 minutes

---

## Setup

```bash
kubectl create namespace team-a
kubectl create namespace team-b

kubectl run frontend --image=nginx -n team-a --labels="app=frontend,tier=web"
kubectl run backend  --image=nginx -n team-a --labels="app=backend,tier=api"
kubectl run database --image=nginx -n team-a --labels="app=database,tier=db"
kubectl run external --image=busybox -n team-b --labels="app=external" \
  -- /bin/sh -c "sleep 3600"

# Wait for pods to be running
kubectl get pods -n team-a
kubectl get pods -n team-b
```

---

## Your Tasks

Apply NetworkPolicies to enforce these rules in namespace `team-a`:

1. **`database` pod** — only accept ingress from pods with label `tier=api` in `team-a`. Deny everything else including from `team-b`.

2. **`backend` pod** — accept ingress from `tier=web` pods in `team-a` AND from `team-b` namespace. Allow egress only to `tier=db` pods and to DNS (port 53).

3. **`frontend` pod** — allow all ingress. Allow egress only to `tier=api` pods and DNS.

Test each rule after applying.

---

## Verification

```bash
# Should SUCCEED: backend -> database
kubectl exec -n team-a backend -- wget -qO- --timeout=2 $(kubectl get pod database -n team-a -o jsonpath='{.status.podIP}') && echo OK

# Should FAIL: frontend -> database (blocked)
kubectl exec -n team-a frontend -- wget -qO- --timeout=2 $(kubectl get pod database -n team-a -o jsonpath='{.status.podIP}') && echo OK || echo BLOCKED

# Should SUCCEED: external (team-b) -> backend
kubectl exec -n team-b external -- wget -qO- --timeout=2 $(kubectl get pod backend -n team-a -o jsonpath='{.status.podIP}') && echo OK
```

---

<details>
<summary>💡 Hints</summary>

- You need **3 NetworkPolicy objects** — one per pod you're protecting
- To allow from a different namespace, use `namespaceSelector` with the namespace's labels
- Label the namespace first: `kubectl label namespace team-b name=team-b`
- DNS egress means allowing UDP/TCP port 53 to anywhere

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Label the namespaces so NetworkPolicy can select them
kubectl label namespace team-a name=team-a
kubectl label namespace team-b name=team-b

# Policy 1: database — only from tier=api in team-a
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      tier: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: team-a
      podSelector:
        matchLabels:
          tier: api
EOF

# Policy 2: backend — ingress from tier=web or team-b, egress to tier=db + DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
  - from:
    - namespaceSelector:
        matchLabels:
          name: team-b
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: db
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
EOF

# Policy 3: frontend — allow all ingress, egress only to tier=api + DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: api
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
EOF
```

</details>

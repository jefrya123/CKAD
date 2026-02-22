# Practice Q18 — Service Misconfiguration (Troubleshoot)

**Mirrors KillerShell CKAD Question 18**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace saturn 2>/dev/null || true

kubectl apply -n saturn -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: saturn-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: saturn-api
      tier: backend
  template:
    metadata:
      labels:
        app: saturn-api
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: saturn-svc
spec:
  selector:
    app: saturn-api
    tier: frontend
  ports:
  - port: 80
    targetPort: 3000
EOF
```

---

## Your Task

The service `saturn-svc` in namespace `saturn` is not routing traffic to any pods. There are **two bugs**. Find and fix both so that:

- `kubectl get endpoints saturn-svc -n saturn` shows pod IPs
- `curl` from inside the cluster reaches nginx

Do NOT modify the Deployment.

---

## Verification

```bash
kubectl get endpoints saturn-svc -n saturn     # must show IPs, not <none>
kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n saturn \
  -- curl -s saturn-svc
```

---

<details>
<summary>💡 Hint</summary>

- Start with: `kubectl get endpoints saturn-svc -n saturn` — empty means selector mismatch
- Then: `kubectl get pods -n saturn --show-labels` — what labels do the pods actually have?
- Also check `targetPort` — what port does nginx actually listen on?

</details>

<details>
<summary>✅ Solution</summary>

Two bugs:
1. `selector.tier: frontend` → should be `backend` (to match pod labels)
2. `targetPort: 3000` → should be `80` (nginx listens on 80)

```bash
kubectl patch svc saturn-svc -n saturn -p '{
  "spec": {
    "selector": {"app": "saturn-api", "tier": "backend"},
    "ports": [{"port": 80, "targetPort": 80}]
  }
}'

# Verify
kubectl get endpoints saturn-svc -n saturn
```

</details>

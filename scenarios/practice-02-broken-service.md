# Practice Scenario 02 — The Dead Service

**Domain:** Services & Networking
**Realistic difficulty:** ⭐⭐⭐
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace pluto

kubectl apply -n pluto -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      tier: backend
  template:
    metadata:
      labels:
        app: api
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
  name: api-svc
spec:
  selector:
    app: api
    tier: frontend
  ports:
  - port: 8080
    targetPort: 3000
EOF
```

---

## Your Tasks

There are **three problems** with the service. Find and fix all of them so that:

1. `kubectl get endpoints api-svc -n pluto` shows pod IPs
2. `kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n pluto -- curl api-svc:8080` returns an nginx response

Do not modify the Deployment.

---

## Verification

```bash
kubectl get endpoints api-svc -n pluto       # should show 2 pod IPs
kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n pluto \
  -- curl -s api-svc:8080
```

---

<details>
<summary>💡 Hints</summary>

- Check `kubectl describe svc api-svc -n pluto` — look at Selector, Port, TargetPort
- Check `kubectl get pods -n pluto --show-labels` — what labels do pods actually have?
- nginx listens on port 80, not 3000

</details>

<details>
<summary>✅ Solution</summary>

Three bugs:
1. Selector `tier: frontend` doesn't match pods which have `tier: backend`
2. `targetPort: 3000` should be `80` (nginx's port)
3. Service port 8080 is fine, but targetPort must match the container

```bash
kubectl edit svc api-svc -n pluto
# Change:
#   selector.tier: frontend  ->  backend
#   targetPort: 3000         ->  80
```

Or patch it:
```bash
kubectl patch svc api-svc -n pluto -p '{"spec":{"selector":{"app":"api","tier":"backend"},"ports":[{"port":8080,"targetPort":80}]}}'
```

</details>

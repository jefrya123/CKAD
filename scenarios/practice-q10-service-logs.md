# Practice Q10 — Service + Logs

**Mirrors KillerShell CKAD Question 10**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace pluto 2>/dev/null || true

kubectl apply -n pluto -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pluto-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pluto-api
  template:
    metadata:
      labels:
        app: pluto-api
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
```

---

## Your Task

1. Create a ClusterIP Service named `pluto-svc` in namespace `pluto` that exposes the `pluto-api` deployment on port `3000`, targeting container port `80`

2. Use a temporary pod to curl the service and confirm it returns an nginx response

3. Save the logs from ONE of the pluto-api pods to `/tmp/q10-logs.txt`

---

## Verification

```bash
kubectl get svc pluto-svc -n pluto
kubectl get endpoints pluto-svc -n pluto        # should show 2 pod IPs
cat /tmp/q10-logs.txt
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl expose deploy pluto-api --port=3000 --target-port=80 --name=pluto-svc -n pluto`
- Test: `kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n pluto -- curl pluto-svc:3000`
- Get a pod name: `kubectl get pods -n pluto -l app=pluto-api -o name | head -1`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Create service
kubectl expose deploy pluto-api --port=3000 --target-port=80 --name=pluto-svc -n pluto

# 2. Test connectivity
kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n pluto \
  -- curl -s pluto-svc:3000

# 3. Save logs
POD=$(kubectl get pods -n pluto -l app=pluto-api -o name | head -1 | cut -d/ -f2)
kubectl logs $POD -n pluto > /tmp/q10-logs.txt
cat /tmp/q10-logs.txt
```

</details>

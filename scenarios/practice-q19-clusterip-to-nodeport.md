# Practice Q19 — Service ClusterIP to NodePort

**Mirrors KillerShell CKAD Question 19**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace saturn 2>/dev/null || true

kubectl apply -n saturn -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: saturn-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: saturn-web
  template:
    metadata:
      labels:
        app: saturn-web
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
  name: saturn-web-svc
spec:
  type: ClusterIP
  selector:
    app: saturn-web
  ports:
  - port: 80
    targetPort: 80
EOF

# Wait for pods
kubectl rollout status deploy/saturn-web -n saturn
```

---

## Your Tasks

The `saturn-web-svc` service in namespace `saturn` is currently ClusterIP and only reachable from inside the cluster. The team needs it exposed externally.

1. Confirm the service is ClusterIP and that it currently has **working endpoints** (pods are healthy)

2. Convert `saturn-web-svc` to **NodePort** with a specific `nodePort` of `30080`

3. Confirm the service type changed AND traffic still works — curl it from inside the cluster using a temp pod

4. Save the NodePort number to `/tmp/q19-nodeport.txt`

---

## Verification

```bash
# Service type and port
kubectl get svc saturn-web-svc -n saturn
# TYPE=NodePort, PORT(S)=80:30080/TCP

# Endpoints still populated (pods didn't break)
kubectl get endpoints saturn-web-svc -n saturn

# Curl still works internally
kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n saturn \
  -- curl -s saturn-web-svc:80 | grep -i "welcome\|nginx"

# Saved nodeport
cat /tmp/q19-nodeport.txt   # 30080
```

---

<details>
<summary>💡 Hints</summary>

- First check current state: `kubectl get svc saturn-web-svc -n saturn` and `kubectl get endpoints saturn-web-svc -n saturn`
- `kubectl edit svc saturn-web-svc -n saturn` — change `type: ClusterIP` → `type: NodePort`, add `nodePort: 30080` under the port entry
- Or use `kubectl patch` with a JSON payload
- The ClusterIP doesn't go away — NodePort adds external access ON TOP, so internal curl still works

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Check current state
kubectl get svc saturn-web-svc -n saturn         # ClusterIP
kubectl get endpoints saturn-web-svc -n saturn   # 2 pod IPs

# 2. Convert to NodePort with specific port
kubectl patch svc saturn-web-svc -n saturn -p '{
  "spec": {
    "type": "NodePort",
    "ports": [{"port": 80, "targetPort": 80, "nodePort": 30080}]
  }
}'

# 3. Verify service changed
kubectl get svc saturn-web-svc -n saturn         # NodePort, 80:30080/TCP

# 3. Verify curl still works from inside cluster
kubectl run tmp --image=curlimages/curl --restart=Never -it --rm -n saturn \
  -- curl -s saturn-web-svc:80

# 4. Save nodeport
echo "30080" > /tmp/q19-nodeport.txt
```

</details>

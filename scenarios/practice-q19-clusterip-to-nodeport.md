# Practice Q19 — Service ClusterIP to NodePort

**Mirrors KillerShell CKAD Question 19**
**Time target:** 4 minutes

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
  replicas: 1
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
```

---

## Your Task

Convert the service `saturn-web-svc` in namespace `saturn` from `ClusterIP` to `NodePort`, using a specific nodePort of `30080`.

---

## Verification

```bash
kubectl get svc saturn-web-svc -n saturn
# TYPE should be NodePort
# PORT(S) should show 80:30080/TCP

# Test from the node (if using minikube/kind with port forwarding):
# curl localhost:30080
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl edit svc saturn-web-svc -n saturn` — change `type: ClusterIP` to `type: NodePort` and add `nodePort: 30080` under the port entry
- Or use `kubectl patch`

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl patch svc saturn-web-svc -n saturn -p '{
  "spec": {
    "type": "NodePort",
    "ports": [{"port": 80, "targetPort": 80, "nodePort": 30080}]
  }
}'

kubectl get svc saturn-web-svc -n saturn
```

</details>

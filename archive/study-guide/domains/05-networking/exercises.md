# Domain 5: Services and Networking - Exercises

## Exercise 1: ClusterIP Service

1. Create a deployment named `web` with nginx and 3 replicas
2. Expose it as a ClusterIP service on port 80
3. Test connectivity from another pod

<details>
<summary>Solution</summary>

```bash
# Create deployment
kubectl create deployment web --image=nginx --replicas=3

# Expose as ClusterIP
kubectl expose deployment web --port=80 --type=ClusterIP

# Verify
kubectl get svc web
kubectl get endpoints web

# Test connectivity
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://web

# Cleanup
kubectl delete deployment web
kubectl delete svc web
```
</details>

## Exercise 2: NodePort Service

1. Create a deployment named `nodeport-app` with nginx
2. Expose it as a NodePort service on port 80

<details>
<summary>Solution</summary>

```bash
# Create deployment
kubectl create deployment nodeport-app --image=nginx

# Expose as NodePort
kubectl expose deployment nodeport-app --port=80 --type=NodePort

# Get the assigned NodePort
kubectl get svc nodeport-app

# The service will be accessible at <NodeIP>:<NodePort>

# Cleanup
kubectl delete deployment nodeport-app
kubectl delete svc nodeport-app
```
</details>

## Exercise 3: Service with Named Ports

Create a service for a deployment that exposes multiple ports:
- HTTP on port 80
- HTTPS on port 443

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-port-app
  template:
    metadata:
      labels:
        app: multi-port-app
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
---
apiVersion: v1
kind: Service
metadata:
  name: multi-port-svc
spec:
  selector:
    app: multi-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
```

```bash
kubectl apply -f multi-port.yaml
kubectl get svc multi-port-svc
kubectl describe svc multi-port-svc

# Cleanup
kubectl delete -f multi-port.yaml
```
</details>

## Exercise 4: Basic Ingress

Create an Ingress that routes traffic to a service:
- Host: myapp.example.com
- Path: /
- Backend service: web-svc on port 80

<details>
<summary>Solution</summary>

```bash
# First create the backend
kubectl create deployment web --image=nginx
kubectl expose deployment web --name=web-svc --port=80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

```bash
kubectl apply -f ingress.yaml
kubectl get ingress
kubectl describe ingress simple-ingress

# Cleanup
kubectl delete ingress simple-ingress
kubectl delete deployment web
kubectl delete svc web-svc
```
</details>

## Exercise 5: Ingress with Path-Based Routing

Create an Ingress that routes:
- /api to api-svc
- /web to web-svc

<details>
<summary>Solution</summary>

```bash
# Create backend services
kubectl create deployment api --image=nginx
kubectl expose deployment api --name=api-svc --port=80
kubectl create deployment web --image=nginx
kubectl expose deployment web --name=web-svc --port=80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

```bash
kubectl apply -f path-ingress.yaml
kubectl get ingress path-ingress

# Cleanup
kubectl delete ingress path-ingress
kubectl delete deployment api web
kubectl delete svc api-svc web-svc
```
</details>

## Exercise 6: NetworkPolicy - Deny All Ingress

Create a NetworkPolicy that denies all ingress traffic to pods in the `secure` namespace.

<details>
<summary>Solution</summary>

```bash
# Create namespace and test pod
kubectl create namespace secure
kubectl run web --image=nginx -n secure
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: secure
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
kubectl apply -f deny-all.yaml

# Test - this should timeout
kubectl run tmp --image=busybox -n secure --rm -it --restart=Never -- wget -qO- --timeout=5 http://web 2>&1
# Expected: wget: download timed out

# Cleanup
kubectl delete namespace secure
```
</details>

## Exercise 7: NetworkPolicy - Allow Specific Pods

Create a NetworkPolicy that:
- Applies to pods labeled `app=backend`
- Only allows ingress from pods labeled `app=frontend`
- On port 80

<details>
<summary>Solution</summary>

```bash
# Create namespace
kubectl create namespace netpol-test

# Create backend pod
kubectl run backend --image=nginx -n netpol-test -l app=backend

# Create frontend pod
kubectl run frontend --image=busybox -n netpol-test -l app=frontend -- sleep 3600

# Create other pod (should be blocked)
kubectl run other --image=busybox -n netpol-test -l app=other -- sleep 3600
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: netpol-test
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f allow-frontend.yaml

# Test from frontend (should work)
kubectl exec -n netpol-test frontend -- wget -qO- --timeout=5 http://backend

# Test from other (should fail)
kubectl exec -n netpol-test other -- wget -qO- --timeout=5 http://backend 2>&1
# Expected: download timed out

# Cleanup
kubectl delete namespace netpol-test
```
</details>

## Exercise 8: NetworkPolicy - Allow from Namespace

Create a NetworkPolicy that allows traffic from the `monitoring` namespace to pods labeled `app=metrics`.

<details>
<summary>Solution</summary>

```bash
# Create namespaces
kubectl create namespace app-ns
kubectl create namespace monitoring
kubectl label namespace monitoring purpose=monitoring

# Create target pod
kubectl run metrics --image=nginx -n app-ns -l app=metrics

# Create monitoring pod
kubectl run prometheus --image=busybox -n monitoring -- sleep 3600
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      app: metrics
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
```

```bash
kubectl apply -f allow-monitoring.yaml

# Test from monitoring namespace (should work)
kubectl exec -n monitoring prometheus -- wget -qO- --timeout=5 http://metrics.app-ns

# Cleanup
kubectl delete namespace app-ns monitoring
```
</details>

## Exercise 9: NetworkPolicy - Egress

Create a NetworkPolicy that:
- Applies to all pods in namespace `restricted`
- Only allows egress to DNS (port 53 UDP) and HTTPS (port 443 TCP)

<details>
<summary>Solution</summary>

```bash
kubectl create namespace restricted
kubectl run test --image=busybox -n restricted -- sleep 3600
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: restricted
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
  - to: []
    ports:
    - protocol: TCP
      port: 443
```

```bash
kubectl apply -f egress-policy.yaml

# Test DNS (should work)
kubectl exec -n restricted test -- nslookup kubernetes

# Test HTTPS (should work)
kubectl exec -n restricted test -- wget -qO- --timeout=5 https://kubernetes.io 2>&1

# Test HTTP (should fail)
kubectl exec -n restricted test -- wget -qO- --timeout=5 http://kubernetes.io 2>&1

# Cleanup
kubectl delete namespace restricted
```
</details>

## Exercise 10: DNS Testing

1. Create a service
2. Test DNS resolution from within a pod
3. Verify different DNS formats work

<details>
<summary>Solution</summary>

```bash
# Create deployment and service
kubectl create deployment dns-test --image=nginx
kubectl expose deployment dns-test --port=80

# Create test pod
kubectl run tmp --image=busybox --rm -it --restart=Never -- sh

# Inside the pod, test different DNS formats:
nslookup dns-test
nslookup dns-test.default
nslookup dns-test.default.svc
nslookup dns-test.default.svc.cluster.local

# Check /etc/resolv.conf
cat /etc/resolv.conf

# Exit and cleanup
exit
kubectl delete deployment dns-test
kubectl delete svc dns-test
```
</details>

## Exercise 11: Headless Service

Create a headless service (clusterIP: None) and observe the DNS behavior.

<details>
<summary>Solution</summary>

```bash
# Create StatefulSet with headless service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
spec:
  clusterIP: None
  selector:
    app: headless-app
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: headless-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: headless-app
  template:
    metadata:
      labels:
        app: headless-app
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Wait for pods
kubectl get pods -l app=headless-app

# Test DNS - should return pod IPs directly
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup headless-svc

# Compare with regular service
kubectl expose deployment headless-app --name=regular-svc --port=80
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup regular-svc

# Cleanup
kubectl delete deployment headless-app
kubectl delete svc headless-svc regular-svc
```
</details>

## Cleanup

```bash
kubectl delete deployment web nodeport-app api multi-port-app dns-test headless-app 2>/dev/null
kubectl delete svc web web-svc nodeport-app api-svc multi-port-svc dns-test headless-svc regular-svc 2>/dev/null
kubectl delete ingress simple-ingress path-ingress 2>/dev/null
kubectl delete namespace secure netpol-test app-ns monitoring restricted 2>/dev/null
```

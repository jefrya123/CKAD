# CKAD Domain 5: Services and Networking

Work through these lessons in order. Each one builds on the last, so by the end you're routing external traffic through Ingress to Services, then locking it all down with NetworkPolicies. The pattern is: learn why something exists, understand how it works, then practice.

**Prerequisites:** A running cluster and `kubectl` configured. An Ingress controller installed (e.g., NGINX Ingress) for Lesson 3 exercises.

---

## Lesson 1: Service Types Deep Dive

You've already exposed deployments with `kubectl expose`. This lesson covers all five Service types and when to use each one.

### Why Services exist

Pods are ephemeral - they get new IP addresses every time they restart. If your frontend pod hard-codes the backend pod's IP, it breaks on the next restart. A Service gives you a stable DNS name and IP that automatically routes to whichever pods are currently running and match the selector.

Services use label selectors to find their target pods. Any pod with matching labels becomes an endpoint, regardless of which node it's on. Kubernetes maintains the endpoint list automatically as pods come and go.

### The five Service types

**ClusterIP** (default) - Internal only. Gets a virtual IP that's only reachable from inside the cluster. This is what you use for pod-to-pod communication (e.g., frontend → backend, backend → database).

```bash
kubectl expose deploy backend --port=80 --type=ClusterIP
```

**NodePort** - Exposes the Service on a static port (30000-32767) on every node's IP. Traffic to `<any-node-ip>:<node-port>` gets forwarded to the Service. Useful for development, rarely used in production.

```bash
kubectl expose deploy web --port=80 --type=NodePort
# Kubernetes assigns a port in 30000-32767
```

**LoadBalancer** - Creates an external load balancer (in cloud environments) that routes traffic to the Service. This is the standard way to expose a Service to the internet in production. On bare-metal clusters, it stays in "Pending" state unless you have something like MetalLB.

**ExternalName** - Not a real proxy. It creates a DNS CNAME record that maps a Service name to an external DNS name. No proxying, no port mapping. Used to give an in-cluster alias to an external service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com    # Resolves to this external hostname
```

Pods can now connect to `external-db` and it resolves to `db.example.com`.

**Headless** - A ClusterIP Service with `clusterIP: None`. It doesn't get a virtual IP. Instead, DNS returns the individual pod IPs directly. Used with StatefulSets where you need to address specific pods:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - port: 5432
```

### Port terminology

Services have three port-related fields that confuse everyone:

```yaml
spec:
  ports:
  - port: 80          # The port the Service listens on (what clients connect to)
    targetPort: 8080   # The port on the pod (where traffic is forwarded)
    nodePort: 30080    # The port on the node (NodePort type only)
```

If you don't specify `targetPort`, it defaults to the same value as `port`.

### Exercises

**1.1** Create a deployment called `web` with 3 replicas using nginx. Expose it as a ClusterIP Service called `web-svc` on port 80. Verify connectivity by curling the Service from a temporary pod.

<details>
<summary>Solution</summary>

```bash
kubectl create deploy web --image=nginx --replicas=3
kubectl expose deploy web --name=web-svc --port=80

# Verify from inside the cluster
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://web-svc
```

</details>

**1.2** Expose the same deployment as a NodePort Service called `web-np` on port 80. Find the assigned NodePort and verify it.

<details>
<summary>Solution</summary>

```bash
kubectl expose deploy web --name=web-np --port=80 --type=NodePort

# Find the NodePort
kubectl get svc web-np -o jsonpath='{.spec.ports[0].nodePort}'

# Verify endpoints
kubectl get endpoints web-np
```

</details>

**1.3** Create a headless Service called `web-headless` for the `web` deployment. Do a DNS lookup from a temporary pod and compare the result to a normal ClusterIP lookup.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector:
    app: web
  ports:
  - port: 80
```

```bash
kubectl apply -f web-headless.yaml

# Normal Service - returns the ClusterIP
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup web-svc

# Headless Service - returns individual pod IPs
kubectl run tmp2 --image=busybox --rm -it --restart=Never -- nslookup web-headless
```

The headless lookup returns multiple A records (one per pod), while the ClusterIP lookup returns a single IP.

</details>

### Cleanup

```bash
kubectl delete deploy web
kubectl delete svc web-svc web-np web-headless
```

---

## Lesson 2: DNS and Service Discovery

Now that you understand Service types, you need to know how pods actually find Services. Kubernetes has built-in DNS, and the naming pattern is critical for the exam.

### Why DNS matters

Every Service gets a DNS entry automatically. You don't need to look up ClusterIPs or configure anything - you just use the DNS name. This is how all pod-to-pod communication works in practice.

### The DNS naming pattern

The fully qualified domain name (FQDN) for a Service is:

```
<service-name>.<namespace>.svc.cluster.local
```

You can use shorter forms depending on where you're calling from:

```
web-svc                          # Same namespace (most common)
web-svc.default                  # Cross-namespace (namespace specified)
web-svc.default.svc.cluster.local # Full FQDN (always works)
```

From within the same namespace, just the Service name is enough. Cross-namespace calls need `<svc>.<namespace>`.

### Pod DNS

Pods also get DNS records, but in a different format. A pod with IP `10.244.1.5` gets:

```
10-244-1-5.<namespace>.pod.cluster.local
```

The dots in the IP are replaced with dashes. You rarely use this directly, but it's good to know for debugging.

### Debugging DNS with temporary pods

When something can't connect, the first thing to check is DNS resolution. Spin up a temporary pod with DNS tools:

```bash
# Quick connectivity test
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://web-svc

# DNS lookup
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup web-svc

# Full DNS resolution
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup web-svc.default.svc.cluster.local

# Test specific port connectivity
kubectl run tmp --image=busybox --rm -it --restart=Never -- nc -v -w 2 -z web-svc 80
```

The `--rm -it --restart=Never` flags are important: `--rm` deletes the pod when done, `-it` gives you interactive output, `--restart=Never` prevents Kubernetes from restarting it.

### Exercises

**2.1** Create a deployment `backend` (nginx, 2 replicas) in a namespace called `apps`. Expose it as a ClusterIP Service called `backend-svc` on port 80. From the default namespace, verify you can reach it using the cross-namespace DNS name.

<details>
<summary>Solution</summary>

```bash
kubectl create ns apps
kubectl create deploy backend --image=nginx --replicas=2 -n apps
kubectl expose deploy backend --name=backend-svc --port=80 -n apps

# From default namespace, use cross-namespace DNS
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://backend-svc.apps
```

</details>

**2.2** From a temporary pod in the default namespace, resolve the full FQDN of `backend-svc` in the `apps` namespace. Verify it returns the ClusterIP.

<details>
<summary>Solution</summary>

```bash
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup backend-svc.apps.svc.cluster.local
```

The result shows the ClusterIP address of the Service.

</details>

**2.3** Create a pod called `dns-test` (busybox, sleep 3600) in the default namespace. Exec into it and test connectivity to `backend-svc.apps` using `wget`, `nslookup`, and `nc -z` on port 80.

<details>
<summary>Solution</summary>

```bash
kubectl run dns-test --image=busybox -- sleep 3600
kubectl exec dns-test -- wget -qO- http://backend-svc.apps
kubectl exec dns-test -- nslookup backend-svc.apps
kubectl exec dns-test -- nc -v -w 2 -z backend-svc.apps 80
```

All three should succeed - `wget` returns the nginx default page, `nslookup` returns the ClusterIP, and `nc` reports the port is open.

</details>

### Cleanup

```bash
kubectl delete pod dns-test
kubectl delete ns apps
```

---

## Lesson 3: Ingress

Services make pods reachable inside the cluster (ClusterIP) or via raw node ports (NodePort). But for HTTP/HTTPS traffic from outside, you want routing by hostname and path. That's what Ingress does.

### Why Ingress exists

Without Ingress, every HTTP service you want to expose externally needs its own LoadBalancer (expensive) or NodePort (ugly URLs, no TLS termination). Ingress gives you a single entry point that routes traffic to different Services based on the hostname and URL path.

Ingress requires two things:
1. An **Ingress resource** (the routing rules you define)
2. An **Ingress controller** (the software that reads the rules and does the routing, e.g., NGINX Ingress Controller)

### Path-based routing

Route different URL paths to different Services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix             # Matches /api, /api/users, /api/users/123
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
```

### Host-based routing

Route different hostnames to different Services:

```yaml
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
  - host: web.example.com
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

### pathType values

- `Prefix` - matches the URL path prefix. `/api` matches `/api`, `/api/`, `/api/users`
- `Exact` - matches the exact path only. `/api` matches only `/api`, not `/api/users`
- `ImplementationSpecific` - matching depends on the Ingress controller

### TLS termination

To serve HTTPS, you create a TLS Secret containing the certificate and key, then reference it in the Ingress:

```bash
# Create TLS Secret from cert files
kubectl create secret tls my-tls-secret --cert=tls.crt --key=tls.key
```

```yaml
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: my-tls-secret       # Must be a TLS-type Secret
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

### The rewrite-target annotation

When you route `/api` to a backend Service, the backend receives the request as `/api/whatever`. If your backend expects just `/whatever`, use the rewrite annotation:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
```

This strips the path prefix before forwarding.

### Imperative shortcut

```bash
kubectl create ingress myingress --rule="myapp.example.com/api=api-svc:80" --dry-run=client -o yaml
```

### Exercises

**3.1** Create two deployments (`frontend` and `api`) using nginx, each with 2 replicas. Expose each as a ClusterIP Service on port 80. Create an Ingress called `app-ingress` that routes `myapp.local/` to `frontend` and `myapp.local/api` to `api`.

<details>
<summary>Solution</summary>

```bash
kubectl create deploy frontend --image=nginx --replicas=2
kubectl create deploy api --image=nginx --replicas=2
kubectl expose deploy frontend --port=80
kubectl expose deploy api --port=80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

```bash
kubectl apply -f app-ingress.yaml
kubectl get ingress app-ingress
kubectl describe ingress app-ingress
```

</details>

**3.2** Create a host-based Ingress called `multi-host` that routes `web.example.com` to a Service called `frontend` and `api.example.com` to a Service called `api` (both on port 80).

<details>
<summary>Solution</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

```bash
kubectl apply -f multi-host.yaml
kubectl describe ingress multi-host
```

</details>

**3.3** Create a self-signed TLS certificate and add TLS termination to the `app-ingress` for `myapp.local`.

<details>
<summary>Solution</summary>

```bash
# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=myapp.local"

# Create TLS Secret
kubectl create secret tls myapp-tls --cert=tls.crt --key=tls.key
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

```bash
kubectl apply -f app-ingress.yaml
kubectl describe ingress app-ingress
# Should show TLS section with the secret name
```

</details>

### Cleanup

```bash
kubectl delete ingress app-ingress multi-host
kubectl delete deploy frontend api
kubectl delete svc frontend api
kubectl delete secret myapp-tls
rm -f tls.crt tls.key
```

---

## Lesson 4: NetworkPolicy

You've learned how to route traffic to pods. Now you need to learn how to block it. By default, every pod can talk to every other pod in the cluster. NetworkPolicies let you restrict this.

### Why NetworkPolicies exist

In a multi-tenant cluster, you don't want every pod to reach every other pod. A compromised frontend pod shouldn't be able to connect directly to the database. NetworkPolicies implement firewall rules at the pod level, controlling both incoming (ingress) and outgoing (egress) traffic.

Important: NetworkPolicies only work if your cluster's CNI plugin supports them (Calico, Cilium, Weave Net do; Flannel does not). If the CNI doesn't support them, the policies are silently ignored.

### Default deny

The most common starting point is denying all traffic, then selectively allowing what you need:

```yaml
# Deny all ingress to all pods in the namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}               # Empty = applies to ALL pods in namespace
  policyTypes:
  - Ingress                     # Block incoming traffic
  # No ingress rules = deny all

# Deny all egress from all pods in the namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
  # No egress rules = deny all
```

An empty `podSelector: {}` matches all pods. Having `policyTypes: [Ingress]` with no `ingress` rules means "deny all ingress."

### Allow specific traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend                 # This policy applies to backend pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:                 # Allow traffic from pods with app=frontend
        matchLabels:
          app: frontend
    ports:
    - port: 80
      protocol: TCP
```

### AND vs OR selector logic

This is the trickiest part of NetworkPolicies and shows up on exams. When selectors are in the same `from` entry, they are ANDed. When they are separate entries, they are ORed:

```yaml
# AND: pod must match BOTH selectors (from frontend pods in monitoring namespace)
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
    namespaceSelector:             # Same list item = AND
      matchLabels:
        name: monitoring

# OR: pod must match EITHER selector (from any frontend pod OR any pod in monitoring)
ingress:
- from:
  - podSelector:                   # Separate list item = OR
      matchLabels:
        app: frontend
  - namespaceSelector:             # Separate list item = OR
      matchLabels:
        name: monitoring
```

The difference is the YAML indentation. In the AND case, both selectors are part of the same `-` list item. In the OR case, each selector is its own `-` list item.

### The DNS egress gotcha

When you deny all egress, you also block DNS lookups (port 53). If your pods use Service names instead of IPs (which they should), you need to explicitly allow DNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-dns-and-api
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - ports:                         # Allow DNS
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  - to:                            # Allow traffic to api pods
    - podSelector:
        matchLabels:
          app: api
    ports:
    - port: 80
```

Always remember to allow DNS egress when writing egress policies.

### Exercises

**4.1** Create a namespace called `netpol-test`. In it, create three deployments with 1 replica each: `frontend` (nginx, label `app=frontend`), `backend` (nginx, label `app=backend`), and `db` (nginx, label `app=db`). Expose each on port 80. Verify all three can reach each other.

<details>
<summary>Solution</summary>

```bash
kubectl create ns netpol-test
kubectl create deploy frontend --image=nginx --replicas=1 -n netpol-test
kubectl create deploy backend --image=nginx --replicas=1 -n netpol-test
kubectl create deploy db --image=nginx --replicas=1 -n netpol-test
kubectl expose deploy frontend --port=80 -n netpol-test
kubectl expose deploy backend --port=80 -n netpol-test
kubectl expose deploy db --port=80 -n netpol-test

# Test connectivity - all should work
kubectl run tmp --image=busybox --rm -it --restart=Never -n netpol-test -- wget -qO- --timeout=3 http://backend
kubectl run tmp --image=busybox --rm -it --restart=Never -n netpol-test -- wget -qO- --timeout=3 http://db
```

</details>

**4.2** Apply a default deny-all ingress NetworkPolicy in the `netpol-test` namespace. Verify that the frontend pod can no longer reach the backend.

<details>
<summary>Solution</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: netpol-test
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
kubectl apply -f deny-all.yaml

# This should now time out
kubectl run tmp --image=busybox --rm -it --restart=Never -n netpol-test -- wget -qO- --timeout=3 http://backend
# wget: download timed out
```

</details>

**4.3** Create a NetworkPolicy that allows the `frontend` pods to reach the `backend` pods on port 80. Verify that frontend → backend works, but frontend → db is still blocked.

<details>
<summary>Solution</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
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
    - port: 80
```

```bash
kubectl apply -f allow-frontend.yaml

# Get the frontend pod name
FRONTEND=$(kubectl get pod -n netpol-test -l app=frontend -o jsonpath='{.items[0].metadata.name}')

# frontend → backend: should work
kubectl exec -n netpol-test $FRONTEND -- wget -qO- --timeout=3 http://backend

# frontend → db: should still be blocked
kubectl exec -n netpol-test $FRONTEND -- wget -qO- --timeout=3 http://db
# wget: download timed out
```

</details>

**4.4** Create an egress NetworkPolicy for the `backend` pods that only allows traffic to `db` pods on port 80 and DNS on port 53. Verify that backend can reach db but cannot reach frontend.

<details>
<summary>Solution</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: netpol-test
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - port: 80
```

```bash
kubectl apply -f backend-egress.yaml

BACKEND=$(kubectl get pod -n netpol-test -l app=backend -o jsonpath='{.items[0].metadata.name}')

# backend → db: should work
kubectl exec -n netpol-test $BACKEND -- wget -qO- --timeout=3 http://db

# backend → frontend: should be blocked
kubectl exec -n netpol-test $BACKEND -- wget -qO- --timeout=3 http://frontend
# wget: download timed out
```

</details>

### Cleanup

```bash
kubectl delete ns netpol-test
```

---

## Final Challenge

This exercise combines everything from all 4 lessons. No hints - just the task.

Create a namespace called `shop` and set up the following:

1. Three deployments (1 replica each): `web` (nginx), `api` (nginx), `db` (nginx) — each exposed as ClusterIP Services on port 80
2. An Ingress called `shop-ingress` for host `shop.example.com` that routes `/` to `web` and `/api` to `api`
3. A default deny-all ingress NetworkPolicy
4. A NetworkPolicy allowing `web` to receive traffic from any source (so Ingress can reach it)
5. A NetworkPolicy allowing `api` to receive traffic only from `web` pods on port 80
6. A NetworkPolicy allowing `db` to receive traffic only from `api` pods on port 80
7. An egress NetworkPolicy on `api` that only allows traffic to `db` on port 80 and DNS on port 53

Verify the traffic flow: external → web (via Ingress), web → api, api → db, but NOT web → db or api → web.

<details>
<summary>Solution</summary>

```bash
kubectl create ns shop

# Deployments and Services
kubectl create deploy web --image=nginx -n shop
kubectl create deploy api --image=nginx -n shop
kubectl create deploy db --image=nginx -n shop
kubectl expose deploy web --port=80 -n shop
kubectl expose deploy api --port=80 -n shop
kubectl expose deploy db --port=80 -n shop
```

```yaml
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ingress
  namespace: shop
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
---
# Default deny
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: shop
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# Allow all ingress to web (for Ingress controller)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-ingress
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - port: 80
---
# Allow web → api
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - port: 80
---
# Allow api → db
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - port: 80
---
# API egress: only db + DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - port: 80
```

```bash
kubectl apply -f shop.yaml

# Verify traffic flow
WEB=$(kubectl get pod -n shop -l app=web -o jsonpath='{.items[0].metadata.name}')
API=$(kubectl get pod -n shop -l app=api -o jsonpath='{.items[0].metadata.name}')

# web → api: works
kubectl exec -n shop $WEB -- wget -qO- --timeout=3 http://api

# api → db: works
kubectl exec -n shop $API -- wget -qO- --timeout=3 http://db

# web → db: blocked
kubectl exec -n shop $WEB -- wget -qO- --timeout=3 http://db
# wget: download timed out

# api → web: blocked (by egress policy)
kubectl exec -n shop $API -- wget -qO- --timeout=3 http://web
# wget: download timed out
```

</details>

### Cleanup

```bash
kubectl delete ns shop
```

---

## Quick Reference

### Imperative shortcuts

```bash
kubectl expose deploy <name> --port=80 --type=ClusterIP
kubectl expose deploy <name> --port=80 --type=NodePort
kubectl create ingress <name> --rule="host/path=svc:80" --dry-run=client -o yaml
kubectl create secret tls <name> --cert=<file> --key=<file>
# Quick connectivity test
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://<svc>
# DNS lookup
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup <svc>
# Port test
kubectl run tmp --image=busybox --rm -it --restart=Never -- nc -v -w 2 -z <svc> <port>
```

### DNS patterns

| From | Format |
|---|---|
| Same namespace | `<svc>` |
| Cross namespace | `<svc>.<namespace>` |
| Full FQDN | `<svc>.<namespace>.svc.cluster.local` |
| Pod (by IP) | `<ip-with-dashes>.<namespace>.pod.cluster.local` |

### NetworkPolicy cheat table

| Goal | Key config |
|---|---|
| Deny all ingress | `podSelector: {}`, `policyTypes: [Ingress]`, no `ingress` rules |
| Deny all egress | `podSelector: {}`, `policyTypes: [Egress]`, no `egress` rules |
| Allow from specific pods | `ingress[].from[].podSelector.matchLabels` |
| Allow from namespace | `ingress[].from[].namespaceSelector.matchLabels` |
| AND logic | Both selectors in same `from` list item |
| OR logic | Each selector in separate `from` list item |
| Allow DNS (egress) | `egress[].ports: [{port: 53, protocol: UDP}]` |

### What goes where

| Thing | YAML path |
|---|---|
| Service type | `spec.type` |
| Service port | `spec.ports[].port` |
| Service target port | `spec.ports[].targetPort` |
| Service selector | `spec.selector` |
| Headless Service | `spec.clusterIP: None` |
| Ingress class | `spec.ingressClassName` |
| Ingress TLS secret | `spec.tls[].secretName` |
| Ingress host | `spec.rules[].host` |
| Ingress path | `spec.rules[].http.paths[].path` |
| Ingress pathType | `spec.rules[].http.paths[].pathType` |
| Ingress backend | `spec.rules[].http.paths[].backend.service` |
| NetworkPolicy target | `spec.podSelector` |
| NetworkPolicy ingress from | `spec.ingress[].from[]` |
| NetworkPolicy egress to | `spec.egress[].to[]` |

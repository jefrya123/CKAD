# Domain 5: Services and Networking (20%)

## Topics

- [ ] Service types (ClusterIP, NodePort, LoadBalancer)
- [ ] Ingress controllers and rules
- [ ] Network policies
- [ ] DNS for services and pods

## Services

### Service Types

| Type | Description | Use Case |
|------|-------------|----------|
| ClusterIP | Internal IP only | Pod-to-pod communication |
| NodePort | Exposes on node IP:port (30000-32767) | Development, direct access |
| LoadBalancer | Cloud provider LB | Production external access |
| ExternalName | CNAME to external service | Access external services |

### Imperative Commands

```bash
# Expose deployment as ClusterIP
kubectl expose deployment nginx --port=80 --target-port=80

# Expose as NodePort
kubectl expose deployment nginx --port=80 --type=NodePort

# Expose as NodePort with specific port
kubectl expose deployment nginx --port=80 --type=NodePort --node-port=30080

# Create service for specific pods
kubectl expose pod nginx --port=80 --name=nginx-svc

# Create service pointing to external
kubectl create service externalname ext-svc --external-name=api.example.com
```

### Service YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - port: 80        # Service port
    targetPort: 8080  # Container port
    protocol: TCP
```

### Multi-Port Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-svc
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
```

### Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
spec:
  clusterIP: None    # Makes it headless
  selector:
    app: myapp
  ports:
  - port: 80
```

## Ingress

### Basic Ingress

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
            name: myapp-service
            port:
              number: 80
```

### Path-Based Routing

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
            name: api-service
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### Host-Based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### Ingress with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: tls-secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Path Types

| Type | Description |
|------|-------------|
| Exact | Matches exact path only |
| Prefix | Matches path prefix |
| ImplementationSpecific | Depends on IngressClass |

## Network Policies

Network policies control pod-to-pod traffic. By default, all traffic is allowed.

### Default Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}     # Applies to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
  # No rules = deny all
```

### Allow Ingress from Specific Pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
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

### Allow Ingress from Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend-ns
```

### Allow Egress to Specific CIDR

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-external
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
        except:
        - 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 443
```

### Combined Ingress and Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: UDP
      port: 53      # Allow DNS
```

### Allow All Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  podSelector:
    matchLabels:
      app: public-web
  policyTypes:
  - Ingress
  ingress:
  - {}    # Empty rule = allow all
```

### Network Policy with Multiple Rules (OR logic)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-rule
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  # Rule 1: Allow from frontend pods
  - from:
    - podSelector:
        matchLabels:
          app: frontend
  # Rule 2: Allow from monitoring namespace
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
```

### Network Policy with AND logic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: and-logic
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    # AND: Must match BOTH namespace AND pod selector
    - namespaceSelector:
        matchLabels:
          team: frontend
      podSelector:
        matchLabels:
          app: web
```

## DNS

```bash
# Service DNS format
<service-name>.<namespace>.svc.cluster.local

# Examples
my-service.default.svc.cluster.local
my-service.production.svc.cluster.local

# Short names (within same namespace)
my-service
my-service.default

# Pod DNS format (rarely used)
<pod-ip-dashed>.<namespace>.pod.cluster.local
# Example: 10-244-0-5.default.pod.cluster.local

# Test DNS resolution
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup kubernetes
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup my-service.default.svc.cluster.local

# Check DNS config in pod
kubectl exec mypod -- cat /etc/resolv.conf
```

## Quick Commands

```bash
# Services
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc
kubectl describe svc my-service
kubectl get endpoints my-service

# Ingress
kubectl get ingress
kubectl describe ingress my-ingress

# Network Policies
kubectl get networkpolicies
kubectl describe networkpolicy my-policy

# Test connectivity
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://my-service
kubectl run tmp --image=busybox --rm -it --restart=Never -- nc -zv my-service 80
```

## Files in this Directory

- `exercises.md` - Practice exercises

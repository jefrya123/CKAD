# Domain 2: Application Deployment (20%)

## Topics

- [ ] Deployments, rolling updates, rollbacks
- [ ] Helm basics (install, upgrade, rollback, values)
- [ ] Blue/green and canary deployment patterns
- [ ] Kustomize basics

## Deployments

### Imperative Commands (Fast for Exam)

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Scale
kubectl scale deployment nginx --replicas=5

# Update image
kubectl set image deployment/nginx nginx=nginx:1.19

# Rollout commands
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2

# Expose as service
kubectl expose deployment nginx --port=80 --type=ClusterIP
```

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### Deployment Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| RollingUpdate | Gradual replacement | Default, zero-downtime |
| Recreate | Kill all, then create new | DB schema changes |

```yaml
# RollingUpdate (default)
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Extra pods during update
    maxUnavailable: 25%  # Pods that can be unavailable

# Recreate
strategy:
  type: Recreate
```

## Helm

### Helm Basics

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo nginx
helm search hub wordpress

# Install a release
helm install my-release bitnami/nginx
helm install my-release bitnami/nginx --namespace web --create-namespace

# Install with custom values
helm install my-release bitnami/nginx --set replicaCount=3
helm install my-release bitnami/nginx -f values.yaml

# List releases
helm list
helm list -A                # All namespaces
helm list --pending         # Pending installations

# Get release info
helm status my-release
helm get values my-release
helm get manifest my-release
```

### Helm Upgrade and Rollback

```bash
# Upgrade a release
helm upgrade my-release bitnami/nginx --set replicaCount=5
helm upgrade my-release bitnami/nginx -f new-values.yaml

# Upgrade or install if not exists
helm upgrade --install my-release bitnami/nginx

# View history
helm history my-release

# Rollback
helm rollback my-release 1           # Rollback to revision 1
helm rollback my-release             # Rollback to previous

# Uninstall
helm uninstall my-release
helm uninstall my-release --keep-history
```

### Working with Values

```bash
# View default values
helm show values bitnami/nginx

# Download chart to inspect
helm pull bitnami/nginx --untar
ls nginx/

# Create custom values file
cat <<EOF > my-values.yaml
replicaCount: 3
service:
  type: ClusterIP
  port: 80
resources:
  limits:
    cpu: 100m
    memory: 128Mi
EOF

helm install my-release bitnami/nginx -f my-values.yaml
```

### Helm Template and Dry Run

```bash
# Render templates without installing
helm template my-release bitnami/nginx

# Dry run (validates with server)
helm install my-release bitnami/nginx --dry-run

# Debug template rendering
helm template my-release bitnami/nginx --debug
```

## Blue/Green Deployments

Deploy new version alongside old, then switch traffic.

```yaml
# Blue deployment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0
---
# Green deployment (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:2.0
---
# Service - switch selector to route traffic
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue    # Change to green to switch
  ports:
  - port: 80
```

Switch traffic:
```bash
kubectl patch svc myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

## Canary Deployments

Route small percentage of traffic to new version.

```yaml
# Stable deployment (90% of pods)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: app
        image: myapp:1.0
---
# Canary deployment (10% of pods)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: app
        image: myapp:2.0
---
# Service selects both (traffic split by pod count)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp        # Matches both stable and canary
  ports:
  - port: 80
```

## Kustomize

### Basic Kustomize Structure

```
app/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

### Base kustomization.yaml

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
```

### Overlay kustomization.yaml

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: production

namePrefix: prod-

commonLabels:
  env: production

replicas:
- name: myapp
  count: 5

images:
- name: myapp
  newTag: v2.0
```

### Using Kustomize

```bash
# Preview output
kubectl kustomize overlays/prod/

# Apply
kubectl apply -k overlays/prod/

# View diff
kubectl diff -k overlays/prod/
```

## Quick Commands

```bash
# Deployments
kubectl create deployment nginx --image=nginx --replicas=3
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx

# Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install myapp bitnami/nginx --set replicaCount=2
helm upgrade myapp bitnami/nginx --set replicaCount=4
helm rollback myapp 1
helm uninstall myapp

# Kustomize
kubectl apply -k ./overlays/prod/
kubectl kustomize ./overlays/prod/
```

## Files in this Directory

- `exercises.md` - Practice exercises

# Domain 2: Application Deployment - Exercises

## Exercise 1: Create and Scale a Deployment

1. Create a deployment named `webapp` with image `nginx` and 3 replicas
2. Scale it to 5 replicas
3. Update the image to `nginx:1.21`
4. Check the rollout status
5. Rollback to the previous version

<details>
<summary>Solution</summary>

```bash
# Create deployment
kubectl create deployment webapp --image=nginx --replicas=3

# Verify
kubectl get deployment webapp
kubectl get pods -l app=webapp

# Scale to 5 replicas
kubectl scale deployment webapp --replicas=5

# Update image
kubectl set image deployment/webapp nginx=nginx:1.21

# Check rollout status
kubectl rollout status deployment/webapp

# View history
kubectl rollout history deployment/webapp

# Rollback
kubectl rollout undo deployment/webapp

# Verify rollback
kubectl describe deployment webapp | grep Image
```
</details>

## Exercise 2: Deployment with Rolling Update Strategy

Create a deployment named `api-server` with:
- Image: `nginx:1.19`
- 4 replicas
- Rolling update strategy: maxSurge=1, maxUnavailable=1
- Container port 80

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 4
  selector:
    matchLabels:
      app: api-server
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f api-server.yaml
kubectl get deployment api-server
kubectl describe deployment api-server | grep -A3 "Strategy"
```
</details>

## Exercise 3: Helm - Install and Configure

1. Add the bitnami repository
2. Search for the nginx chart
3. Install nginx with release name `my-web` with 2 replicas
4. List the release
5. Upgrade to 3 replicas
6. Rollback to the previous version

<details>
<summary>Solution</summary>

```bash
# Add repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search
helm search repo nginx

# Install with custom values
helm install my-web bitnami/nginx --set replicaCount=2

# List releases
helm list

# Check status
helm status my-web

# Upgrade
helm upgrade my-web bitnami/nginx --set replicaCount=3

# View history
helm history my-web

# Rollback
helm rollback my-web 1

# Cleanup
helm uninstall my-web
```
</details>

## Exercise 4: Helm - Custom Values File

Create a values file and install nginx with:
- 3 replicas
- Service type ClusterIP
- Resource limits: 100m CPU, 128Mi memory

<details>
<summary>Solution</summary>

```bash
# Create values file
cat <<EOF > custom-values.yaml
replicaCount: 3
service:
  type: ClusterIP
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
EOF

# Install with values file
helm install my-nginx bitnami/nginx -f custom-values.yaml

# Verify
kubectl get deployment
kubectl describe deployment my-nginx-nginx | grep -A10 "Limits"

# Cleanup
helm uninstall my-nginx
rm custom-values.yaml
```
</details>

## Exercise 5: Blue/Green Deployment

Implement a blue/green deployment:
1. Create "blue" deployment with `nginx:1.19` (3 replicas)
2. Create "green" deployment with `nginx:1.21` (3 replicas)
3. Create a service pointing to blue
4. Switch traffic to green

<details>
<summary>Solution</summary>

```yaml
# blue-green.yaml
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
      - name: nginx
        image: nginx:1.19
---
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
      - name: nginx
        image: nginx:1.21
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue
  ports:
  - port: 80
```

```bash
kubectl apply -f blue-green.yaml

# Verify blue is serving
kubectl get endpoints myapp

# Switch to green
kubectl patch svc myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Verify green is now serving
kubectl get endpoints myapp

# Cleanup
kubectl delete -f blue-green.yaml
```
</details>

## Exercise 6: Canary Deployment

Implement a canary deployment:
1. Create stable deployment with 9 replicas
2. Create canary deployment with 1 replica (new version)
3. Create a service that routes to both (90/10 split by pod count)

<details>
<summary>Solution</summary>

```yaml
# canary.yaml
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
      - name: nginx
        image: nginx:1.19
---
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
      - name: nginx
        image: nginx:1.21
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp  # Selects both stable and canary
  ports:
  - port: 80
```

```bash
kubectl apply -f canary.yaml

# Verify both deployments are selected
kubectl get endpoints myapp
kubectl get pods -l app=myapp

# Scale up canary for more traffic
kubectl scale deployment app-canary --replicas=3

# Full rollout - scale down stable, scale up canary
kubectl scale deployment app-stable --replicas=0
kubectl scale deployment app-canary --replicas=10

# Cleanup
kubectl delete -f canary.yaml
```
</details>

## Exercise 7: Kustomize Basics

Create a kustomize structure with base and prod overlay:
1. Base: nginx deployment with 1 replica
2. Prod overlay: 3 replicas, namespace "production", name prefix "prod-"

<details>
<summary>Solution</summary>

```bash
# Create directory structure
mkdir -p kustomize-demo/base kustomize-demo/overlays/prod

# Base deployment
cat <<EOF > kustomize-demo/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Base kustomization
cat <<EOF > kustomize-demo/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF

# Prod overlay
cat <<EOF > kustomize-demo/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: production

namePrefix: prod-

replicas:
- name: nginx
  count: 3
EOF

# Preview
kubectl kustomize kustomize-demo/overlays/prod/

# Create namespace and apply
kubectl create namespace production
kubectl apply -k kustomize-demo/overlays/prod/

# Verify
kubectl get deployment -n production

# Cleanup
kubectl delete -k kustomize-demo/overlays/prod/
kubectl delete namespace production
rm -rf kustomize-demo
```
</details>

## Exercise 8: Rollout to Specific Revision

1. Create a deployment with nginx:1.18
2. Update to nginx:1.19
3. Update to nginx:1.20
4. Rollback to revision 1 (nginx:1.18)

<details>
<summary>Solution</summary>

```bash
# Create initial deployment
kubectl create deployment rollout-test --image=nginx:1.18

# Record revisions
kubectl set image deployment/rollout-test nginx=nginx:1.19
kubectl set image deployment/rollout-test nginx=nginx:1.20

# View history
kubectl rollout history deployment/rollout-test

# Rollback to specific revision
kubectl rollout undo deployment/rollout-test --to-revision=1

# Verify
kubectl describe deployment rollout-test | grep Image

# Cleanup
kubectl delete deployment rollout-test
```
</details>

## Cleanup

```bash
kubectl delete deployment webapp api-server 2>/dev/null
helm uninstall my-web my-nginx 2>/dev/null
kubectl delete deployment app-blue app-green app-stable app-canary 2>/dev/null
kubectl delete service myapp 2>/dev/null
kubectl delete deployment rollout-test 2>/dev/null
```

# CKAD Exam Cheatsheet

## Shell Setup (Do First!)

```bash
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"
```

## Generate YAML Fast

```bash
# Pod
k run nginx --image=nginx $do > pod.yaml

# Deployment
k create deployment nginx --image=nginx $do > deploy.yaml

# Service
k expose deployment nginx --port=80 $do > svc.yaml

# ConfigMap
k create configmap myconfig --from-literal=key=val $do

# Secret
k create secret generic mysecret --from-literal=pass=123 $do

# ServiceAccount
k create sa mysa $do

# Job
k create job myjob --image=busybox $do -- echo "hello"

# CronJob
k create cronjob mycron --image=busybox --schedule="*/5 * * * *" $do -- echo "tick"
```

## Multi-Container Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ["/bin/sh", "-c", "while true; do date > /data/index.html; sleep 10; done"]
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    emptyDir: {}
```

## Init Containers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-pod
spec:
  initContainers:
  - name: init-svc
    image: busybox
    command: ['sh', '-c', 'until nc -z myservice 80; do sleep 2; done']
  containers:
  - name: app
    image: nginx
```

## Probes

```yaml
# Liveness Probe - restarts container if fails
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

# Readiness Probe - removes from service if fails
readinessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 5
  periodSeconds: 10

# Startup Probe - blocks other probes until success
startupProbe:
  httpGet:
    path: /ready
    port: 8080
  failureThreshold: 30
  periodSeconds: 10

# Exec Probe
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  periodSeconds: 5
```

## SecurityContext

```yaml
# Pod level
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000

# Container level
spec:
  containers:
  - name: app
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

## Resource Limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

## Helm Commands

```bash
# Repo management
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx

# Install
helm install myapp bitnami/nginx
helm install myapp bitnami/nginx --set replicaCount=3
helm install myapp bitnami/nginx -f values.yaml

# Manage releases
helm list
helm status myapp
helm get values myapp

# Upgrade/Rollback
helm upgrade myapp bitnami/nginx --set replicaCount=5
helm history myapp
helm rollback myapp 1

# Uninstall
helm uninstall myapp

# Debugging
helm template myapp bitnami/nginx
helm install myapp bitnami/nginx --dry-run
```

## Vim Essentials

```
i          Insert mode
Esc        Normal mode
:wq        Save and quit
:q!        Quit without saving
dd         Delete line
yy         Yank (copy) line
p          Paste below
u          Undo
/text      Search
n          Next match
:set nu    Show line numbers
:set paste Paste mode (preserves indentation)
```

## jsonpath Examples

```bash
# Get node IPs
k get nodes -o jsonpath='{.items[*].status.addresses[0].address}'

# Get pod images
k get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Get pod names and images
k get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Custom columns
k get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
```

## Quick Debugging

```bash
k describe pod <pod>          # Events, status
k logs <pod> [-c container]   # Logs
k logs <pod> --previous       # Previous crash
k logs <pod> -f               # Follow logs
k exec -it <pod> -- sh        # Shell access
k get events --sort-by='.lastTimestamp'
```

## Common Tasks

```bash
# Scale deployment
k scale deploy nginx --replicas=3

# Update image
k set image deploy/nginx nginx=nginx:1.19

# Rollback
k rollout undo deploy/nginx

# Create Job
k create job pi --image=perl -- perl -Mbignum=bpi -wle 'print bpi(100)'

# Create CronJob
k create cronjob hello --image=busybox --schedule="*/5 * * * *" -- echo "Hello"

# Check resource usage
k top pods
k top nodes
```

## Network Policies Quick Reference

```yaml
# Deny all ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]

# Allow from specific pods
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend

# Allow from namespace
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: prod
```

## ConfigMaps and Secrets Usage

```yaml
# Env from ConfigMap
env:
- name: MY_VAR
  valueFrom:
    configMapKeyRef:
      name: myconfig
      key: mykey

# Env from Secret
env:
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      name: mysecret
      key: password

# Mount as volume
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: myconfig
```

## Bookmarks for Exam

- kubectl cheatsheet: kubernetes.io/docs/reference/kubectl/cheatsheet/
- Pod spec: kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/
- NetworkPolicy: kubernetes.io/docs/concepts/services-networking/network-policies/
- Probes: kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Helm: helm.sh/docs/

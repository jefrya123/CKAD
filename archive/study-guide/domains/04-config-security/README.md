# Domain 4: Application Environment, Configuration and Security (25%)

## Topics

- [ ] ConfigMaps and Secrets
- [ ] SecurityContext (runAsUser, capabilities)
- [ ] ServiceAccounts
- [ ] Resource requests and limits
- [ ] ResourceQuotas and LimitRanges
- [ ] Persistent Volumes and Claims

## ConfigMaps

```bash
# Create ConfigMap imperatively
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

# From file
kubectl create configmap app-config --from-file=config.properties
kubectl create configmap app-config --from-file=mykey=config.properties

# From directory
kubectl create configmap app-config --from-file=/path/to/configs/
```

### Using ConfigMaps

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
  - name: app
    image: nginx
    # Single env var from ConfigMap
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    # All keys as env vars
    envFrom:
    - configMapRef:
        name: app-config
    # Mount as volume
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

## Secrets

```bash
# Create Secret imperatively
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret123

# From file
kubectl create secret generic tls-secret --from-file=tls.crt --from-file=tls.key

# Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass

# View decoded secret
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
```

### Using Secrets

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: password
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-creds
```

## SecurityContext

### Pod-level SecurityContext

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-pod
spec:
  securityContext:
    runAsUser: 1000           # User ID for all containers
    runAsGroup: 3000          # Group ID for all containers
    fsGroup: 2000             # Group for volume ownership
    runAsNonRoot: true        # Enforce non-root
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
```

### Container-level SecurityContext

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-pod
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

### Common Capabilities

| Capability | Purpose |
|------------|---------|
| NET_BIND_SERVICE | Bind to ports < 1024 |
| NET_ADMIN | Network configuration |
| SYS_TIME | Modify system clock |
| SYS_PTRACE | Debug processes |

## ServiceAccounts

```bash
# Create ServiceAccount
kubectl create serviceaccount myapp-sa

# List ServiceAccounts
kubectl get serviceaccounts

# View ServiceAccount details
kubectl describe serviceaccount myapp-sa
```

### Using ServiceAccounts

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-pod
spec:
  serviceAccountName: myapp-sa
  automountServiceAccountToken: false  # Disable token mount
  containers:
  - name: app
    image: nginx
```

### ServiceAccount with RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
subjects:
- kind: ServiceAccount
  name: pod-reader-sa
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## Resource Requests and Limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:           # Scheduler uses for placement
        memory: "64Mi"
        cpu: "250m"       # 0.25 CPU cores
      limits:             # Container cannot exceed
        memory: "128Mi"
        cpu: "500m"
```

### CPU Units
- `1` = 1 CPU core
- `500m` = 0.5 CPU (500 millicores)
- `100m` = 0.1 CPU

### Memory Units
- `128Mi` = 128 Mebibytes
- `1Gi` = 1 Gibibyte
- `256M` = 256 Megabytes

## ResourceQuotas

Limit total resources in a namespace.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "10"
    configmaps: "10"
    secrets: "10"
    persistentvolumeclaims: "5"
```

```bash
# Create ResourceQuota
kubectl create quota compute-quota \
  --hard=pods=10,requests.cpu=4,requests.memory=4Gi \
  -n dev

# View usage
kubectl describe resourcequota compute-quota -n dev
```

## LimitRanges

Set default and min/max for resources in a namespace.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: dev
spec:
  limits:
  - type: Container
    default:            # Default limits
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:     # Default requests
      cpu: "100m"
      memory: "64Mi"
    min:                # Minimum allowed
      cpu: "50m"
      memory: "32Mi"
    max:                # Maximum allowed
      cpu: "2"
      memory: "1Gi"
  - type: Pod
    max:
      cpu: "4"
      memory: "2Gi"
```

## Persistent Volumes

### Volume Types

| Type | Persistence | Use Case |
|------|-------------|----------|
| emptyDir | Pod lifetime | Temp storage, cache |
| hostPath | Node lifetime | Access node files |
| PV/PVC | Cluster lifetime | Persistent data |

### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # Optional: specific storage class
```

### Pod Using PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-pvc
```

### Access Modes

- `ReadWriteOnce (RWO)` - Single node read-write
- `ReadOnlyMany (ROX)` - Multiple nodes read-only
- `ReadWriteMany (RWX)` - Multiple nodes read-write

## Quick Commands

```bash
# ConfigMaps
kubectl create configmap myconfig --from-literal=key=value
kubectl get configmap myconfig -o yaml

# Secrets
kubectl create secret generic mysecret --from-literal=pass=secret
kubectl get secret mysecret -o jsonpath='{.data.pass}' | base64 -d

# ServiceAccounts
kubectl create sa mysa
kubectl get sa

# ResourceQuotas
kubectl create quota myquota --hard=pods=10 -n dev
kubectl describe quota -n dev

# Check resource usage
kubectl top pods
kubectl describe node | grep -A5 "Allocated resources"
```

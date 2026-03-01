# Domain 4: Application Environment, Configuration and Security - Exercises

## Exercise 1: ConfigMap from Literals

Create a ConfigMap named `app-settings` with:
- APP_ENV=production
- LOG_LEVEL=info
- MAX_CONNECTIONS=100

<details>
<summary>Solution</summary>

```bash
kubectl create configmap app-settings \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100

# Verify
kubectl get configmap app-settings -o yaml
kubectl describe configmap app-settings
```
</details>

## Exercise 2: Pod Using ConfigMap as Environment Variables

Create a pod named `config-env-pod` that uses the ConfigMap from Exercise 1:
- Use envFrom to load all ConfigMap keys as environment variables
- Verify the variables are set

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-settings
```

```bash
kubectl apply -f config-env-pod.yaml
kubectl exec config-env-pod -- env | grep -E "APP_ENV|LOG_LEVEL|MAX"
```
</details>

## Exercise 3: ConfigMap as Volume

Create a ConfigMap from a file and mount it as a volume:

1. Create a config file
2. Create ConfigMap from the file
3. Mount it in a pod at `/etc/config`

<details>
<summary>Solution</summary>

```bash
# Create config file
cat <<EOF > app.properties
database.host=localhost
database.port=5432
database.name=myapp
EOF

# Create ConfigMap from file
kubectl create configmap app-config --from-file=app.properties

# Create pod with volume mount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-volume-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: app-config
EOF

# Verify
kubectl exec config-volume-pod -- cat /etc/config/app.properties

# Cleanup
rm app.properties
```
</details>

## Exercise 4: Secret from Literals

Create a Secret named `db-credentials` with:
- username=admin
- password=supersecret

<details>
<summary>Solution</summary>

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=supersecret

# View secret (values are base64 encoded)
kubectl get secret db-credentials -o yaml

# Decode a value
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
```
</details>

## Exercise 5: Pod Using Secret

Create a pod that uses the secret from Exercise 4:
- Mount username as env var DB_USER
- Mount password as env var DB_PASS
- Also mount secret as volume at `/etc/secrets`

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
```

```bash
kubectl apply -f secret-pod.yaml

# Verify env vars
kubectl exec secret-pod -- env | grep DB_

# Verify volume mount
kubectl exec secret-pod -- cat /etc/secrets/username
kubectl exec secret-pod -- cat /etc/secrets/password
```
</details>

## Exercise 6: SecurityContext - Run as Non-Root

Create a pod named `secure-pod` that:
- Runs as user ID 1000
- Runs as group ID 3000
- Has read-only root filesystem
- Cannot escalate privileges

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
```

```bash
kubectl apply -f secure-pod.yaml

# Verify user/group
kubectl exec secure-pod -- id

# Verify read-only filesystem
kubectl exec secure-pod -- touch /test 2>&1
# Should fail: Read-only file system
```
</details>

## Exercise 7: SecurityContext - Capabilities

Create a pod that:
- Drops all capabilities
- Adds only NET_BIND_SERVICE capability

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

```bash
kubectl apply -f capability-pod.yaml
kubectl describe pod capability-pod | grep -A5 Capabilities
```
</details>

## Exercise 8: ServiceAccount

1. Create a ServiceAccount named `app-sa`
2. Create a pod that uses this ServiceAccount
3. Disable auto-mounting of the service account token

<details>
<summary>Solution</summary>

```bash
# Create ServiceAccount
kubectl create serviceaccount app-sa

# Verify
kubectl get sa app-sa
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-pod
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
```

```bash
kubectl apply -f sa-pod.yaml

# Verify ServiceAccount
kubectl get pod sa-pod -o jsonpath='{.spec.serviceAccountName}'

# Verify token not mounted
kubectl exec sa-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount 2>&1
# Should show: No such file or directory
```
</details>

## Exercise 9: Resource Requests and Limits

Create a pod named `resource-pod` with:
- Requests: 64Mi memory, 100m CPU
- Limits: 128Mi memory, 200m CPU

<details>
<summary>Solution</summary>

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
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
```

```bash
kubectl apply -f resource-pod.yaml
kubectl describe pod resource-pod | grep -A6 "Limits\|Requests"
```
</details>

## Exercise 10: ResourceQuota

Create a ResourceQuota named `dev-quota` in namespace `dev` that limits:
- Max 5 pods
- Max 2 CPU requests
- Max 2Gi memory requests

<details>
<summary>Solution</summary>

```bash
# Create namespace
kubectl create namespace dev

# Create ResourceQuota
kubectl create quota dev-quota \
  --hard=pods=5,requests.cpu=2,requests.memory=2Gi \
  -n dev

# Verify
kubectl describe resourcequota dev-quota -n dev

# Test by creating pods
kubectl run test1 --image=nginx -n dev
kubectl run test2 --image=nginx -n dev

# Check quota usage
kubectl describe resourcequota dev-quota -n dev

# Cleanup
kubectl delete namespace dev
```
</details>

## Exercise 11: LimitRange

Create a LimitRange in namespace `limited` that sets:
- Default CPU limit: 500m
- Default CPU request: 100m
- Default memory limit: 256Mi
- Default memory request: 64Mi

<details>
<summary>Solution</summary>

```bash
# Create namespace
kubectl create namespace limited
```

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: limited
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
```

```bash
kubectl apply -f limit-range.yaml

# Test by creating a pod without resource specs
kubectl run test --image=nginx -n limited

# Verify defaults were applied
kubectl describe pod test -n limited | grep -A6 "Limits\|Requests"

# Cleanup
kubectl delete namespace limited
```
</details>

## Exercise 12: PersistentVolumeClaim

Create a PVC named `data-pvc` requesting:
- 500Mi of storage
- ReadWriteOnce access mode
- Mount it in a pod at `/data`

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
```

```bash
kubectl apply -f pvc-pod.yaml

# Check PVC status
kubectl get pvc data-pvc

# Test writing to volume
kubectl exec pvc-pod -- sh -c "echo hello > /data/test.txt"
kubectl exec pvc-pod -- cat /data/test.txt
```
</details>

## Cleanup

```bash
kubectl delete configmap app-settings app-config 2>/dev/null
kubectl delete secret db-credentials 2>/dev/null
kubectl delete sa app-sa 2>/dev/null
kubectl delete pod config-env-pod config-volume-pod secret-pod secure-pod capability-pod sa-pod resource-pod pvc-pod 2>/dev/null
kubectl delete pvc data-pvc 2>/dev/null
kubectl delete namespace dev limited 2>/dev/null
```

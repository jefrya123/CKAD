# CKAD Domain 4: Application Environment, Configuration and Security

Work through these lessons in order. Each one builds on the last, so by the end you're wiring up complete application configurations with secrets, security constraints, RBAC, and resource budgets. The pattern is: learn why something exists, understand how it works, then practice.

**Prerequisites:** A running cluster and `kubectl` configured.

---

## Lesson 1: ConfigMaps Deep Dive

You've probably already created a ConfigMap or two in other exercises. This lesson goes deeper into the four creation methods and the three consumption methods, because the exam tests all of them.

### Why ConfigMaps exist

Hard-coding configuration inside a container image is a bad idea. Every time you change a value you'd need to rebuild and redeploy the image. ConfigMaps separate configuration from code: you store key-value pairs (or entire files) in a ConfigMap object, then inject them into pods as environment variables or mounted files. The same image can behave differently in dev, staging, and production just by pointing it at different ConfigMaps.

### Four ways to create a ConfigMap

```bash
# 1. From literals - one key-value pair per flag
kubectl create cm app-config --from-literal=APP_ENV=prod --from-literal=LOG_LEVEL=info

# 2. From a single file - filename becomes the key, contents become the value
kubectl create cm app-config --from-file=config.properties

# 3. From a file with a custom key name
kubectl create cm app-config --from-file=mykey=config.properties

# 4. From a directory - each file in the directory becomes a key
kubectl create cm app-config --from-file=./config-dir/
```

With `--from-file`, the entire file content (including newlines) becomes the value. This matters when you mount it as a volume - you get the original file back.

### Three ways to consume a ConfigMap in a pod

```yaml
# Method 1: envFrom - all keys become env vars at once
envFrom:
- configMapRef:
    name: app-config           # Every key in app-config becomes an env var

# Method 2: env with valueFrom - pick specific keys
env:
- name: LOG_LEVEL              # The env var name in the container
  valueFrom:
    configMapKeyRef:
      name: app-config         # ConfigMap name
      key: LOG_LEVEL           # Key to pull from

# Method 3: Volume mount - keys become files
volumeMounts:
- name: config-vol
  mountPath: /etc/config       # Each key becomes a file in this directory
volumes:
- name: config-vol
  configMap:
    name: app-config
```

The critical difference: environment variables are set at container start and never change. Volume-mounted ConfigMaps update automatically when the ConfigMap is modified (with a delay of up to a minute). If your app can reload config from disk, volume mounts are more flexible.

### Exercises

**1.1** Create a ConfigMap called `webapp-config` with three keys: `APP_ENV=production`, `LOG_LEVEL=warn`, and `MAX_RETRIES=3`. Verify the values with `kubectl describe`.

<details>
<summary>Solution</summary>

```bash
kubectl create cm webapp-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=warn \
  --from-literal=MAX_RETRIES=3
kubectl describe cm webapp-config
```

</details>

**1.2** Create a pod called `env-pod` using busybox that sleeps for 3600 seconds. Inject **all** keys from `webapp-config` as environment variables using `envFrom`. Exec into the pod and verify with `env | grep -E 'APP|LOG|MAX'`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: webapp-config
```

```bash
kubectl apply -f env-pod.yaml
kubectl exec env-pod -- env | grep -E 'APP|LOG|MAX'
# APP_ENV=production
# LOG_LEVEL=warn
# MAX_RETRIES=3
```

</details>

**1.3** Create a file called `app.properties` with the content `db.host=mysql\ndb.port=3306` (two lines). Create a ConfigMap called `file-config` from this file. Then create a pod called `vol-pod` that mounts `file-config` as a volume at `/etc/config`. Exec in and verify the file exists at `/etc/config/app.properties`.

<details>
<summary>Solution</summary>

```bash
# Create the file
printf 'db.host=mysql\ndb.port=3306\n' > app.properties
kubectl create cm file-config --from-file=app.properties
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vol-pod
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
      name: file-config
```

```bash
kubectl apply -f vol-pod.yaml
kubectl exec vol-pod -- cat /etc/config/app.properties
# db.host=mysql
# db.port=3306
```

</details>

### Cleanup

```bash
kubectl delete pod env-pod vol-pod
kubectl delete cm webapp-config file-config
rm app.properties
```

---

## Lesson 2: Secrets

Now that you understand ConfigMaps, Secrets are easy - they work almost identically but are designed for sensitive data like passwords, tokens, and certificates.

### Why Secrets exist

You could put a password in a ConfigMap, but ConfigMaps are stored in plain text in etcd and show up in plain text in `kubectl describe`. Secrets provide:

1. **Base64 encoding** - not encryption, but it prevents casual exposure in YAML and logs
2. **Access control** - RBAC can restrict who can read Secrets separately from ConfigMaps
3. **Reduced exposure** - Kubernetes can be configured to encrypt Secrets at rest in etcd

The important thing to remember: base64 is **encoding**, not **encryption**. Anyone who can read the Secret can decode it. The security comes from RBAC, not from the encoding.

### Three types of Secrets

```bash
# 1. generic - arbitrary key-value pairs (most common on the exam)
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=s3cret

# 2. tls - for TLS certificates (requires cert and key files)
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key

# 3. docker-registry - for pulling images from private registries
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com
```

### Encoding and decoding

When you create a Secret from literals, Kubernetes base64-encodes the values automatically. When you write Secret YAML by hand, you must encode the values yourself:

```bash
# Encode
echo -n 'admin' | base64          # YWRtaW4=

# Decode
echo 'YWRtaW4=' | base64 -d      # admin

# Or read a Secret value directly
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
```

The `-n` flag on `echo` is critical - without it, a newline character gets encoded into the value and your password becomes `admin\n` instead of `admin`.

### Using Secrets in pods

Secrets are consumed exactly like ConfigMaps - `envFrom`, `env` with `valueFrom`, or volume mounts:

```yaml
# All keys as env vars
envFrom:
- secretRef:
    name: db-creds

# Specific key
env:
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: password

# As volume (each key becomes a file containing the decoded value)
volumeMounts:
- name: creds
  mountPath: /etc/secrets
  readOnly: true              # Good practice for secrets
volumes:
- name: creds
  secret:
    secretName: db-creds
```

### imagePullSecrets

To pull images from a private registry, you create a `docker-registry` Secret and reference it in the pod spec:

```yaml
spec:
  containers:
  - name: app
    image: registry.example.com/myapp:latest
  imagePullSecrets:
  - name: regcred
```

### Exercises

**2.1** Create a Secret called `app-secret` with keys `DB_USER=admin` and `DB_PASS=hunter2`. Then decode the password using `kubectl` and `base64 -d`.

<details>
<summary>Solution</summary>

```bash
kubectl create secret generic app-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=hunter2

kubectl get secret app-secret -o jsonpath='{.data.DB_PASS}' | base64 -d
# hunter2
```

</details>

**2.2** Create a pod called `secret-env-pod` using busybox (sleep 3600) that injects the `DB_PASS` key from `app-secret` as an env var called `DATABASE_PASSWORD`. Exec in and verify.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: DB_PASS
```

```bash
kubectl apply -f secret-env-pod.yaml
kubectl exec secret-env-pod -- env | grep DATABASE_PASSWORD
# DATABASE_PASSWORD=hunter2
```

</details>

**2.3** Mount the entire `app-secret` as a volume at `/etc/db-creds` in a pod called `secret-vol-pod` (busybox, sleep 3600). Verify by listing the files and reading them.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-vol-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: creds
    secret:
      secretName: app-secret
```

```bash
kubectl apply -f secret-vol-pod.yaml
kubectl exec secret-vol-pod -- ls /etc/db-creds
# DB_PASS  DB_USER
kubectl exec secret-vol-pod -- cat /etc/db-creds/DB_PASS
# hunter2
```

Volume-mounted Secrets are automatically decoded - the files contain the plain text values, not base64.

</details>

### Cleanup

```bash
kubectl delete pod secret-env-pod secret-vol-pod
kubectl delete secret app-secret
```

---

## Lesson 3: SecurityContext

You can now configure your apps with ConfigMaps and Secrets. But by default, containers run as root, which is a security risk. SecurityContext lets you lock down what a container is allowed to do.

### Why SecurityContext exists

If an attacker breaks into your container, the damage they can do depends on the user it runs as and the Linux capabilities it has. SecurityContext controls this at two levels:

1. **Pod level** - applies to all containers in the pod (user/group IDs, filesystem group)
2. **Container level** - applies to a specific container (capabilities, read-only filesystem, privilege escalation)

Container-level settings override pod-level settings when they conflict.

### Pod-level settings

```yaml
spec:
  securityContext:
    runAsUser: 1000              # All containers run as UID 1000
    runAsGroup: 3000             # Primary GID 3000
    fsGroup: 2000                # Volumes are owned by GID 2000
```

`fsGroup` is especially important for PVCs - it ensures the volume files are writable by the pod's containers.

### Container-level settings

```yaml
containers:
- name: app
  securityContext:
    runAsNonRoot: true             # Fail to start if image runs as root
    readOnlyRootFilesystem: true   # Container can't write to its own filesystem
    allowPrivilegeEscalation: false # No setuid binaries
    capabilities:
      drop: ["ALL"]                # Remove all Linux capabilities
      add: ["NET_BIND_SERVICE"]    # Add back only what's needed
```

The most common exam pattern is combining `runAsUser`, `runAsNonRoot`, and `readOnlyRootFilesystem`. If you set `readOnlyRootFilesystem: true`, the container needs `emptyDir` or PVC volumes for any directories it writes to (like `/tmp`).

### How to remember the difference

- `runAsUser` / `runAsGroup` / `fsGroup` → pod level (affects all containers)
- `capabilities` / `readOnlyRootFilesystem` / `allowPrivilegeEscalation` → container level (per-container)
- `runAsNonRoot` → can go at either level

### Exercises

**3.1** Create a pod called `secure-pod` using busybox (sleep 3600) that:
- Runs as user ID 1000 and group ID 3000 (pod level)
- Has a read-only root filesystem (container level)
- Mounts an `emptyDir` at `/tmp` so the container can still write temp files

Exec in and verify: run `id` to check user/group, try writing to `/` (should fail), and try writing to `/tmp` (should succeed).

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
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

```bash
kubectl apply -f secure-pod.yaml
kubectl exec secure-pod -- id
# uid=1000 gid=3000

kubectl exec secure-pod -- touch /test
# touch: /test: Read-only file system

kubectl exec secure-pod -- touch /tmp/test
# works
```

</details>

**3.2** Create a pod called `cap-pod` using busybox (sleep 3600) that drops ALL capabilities and adds back only `NET_BIND_SERVICE`. Set `allowPrivilegeEscalation: false`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cap-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

```bash
kubectl apply -f cap-pod.yaml
kubectl exec cap-pod -- cat /proc/1/status | grep Cap
# CapBnd will show limited capabilities
```

</details>

**3.3** Create a pod called `nonroot-pod` using `nginx` with `runAsNonRoot: true` at the pod level. Apply it and observe what happens. Why does it fail? Fix it by using the `nginxinc/nginx-unprivileged` image instead.

<details>
<summary>Solution</summary>

```yaml
# This will fail - nginx image runs as root by default
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-pod
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: web
    image: nginx
```

```bash
kubectl apply -f nonroot-pod.yaml
kubectl describe pod nonroot-pod
# Error: container has runAsNonRoot and image will run as root
```

```yaml
# Fix: use an image that runs as non-root
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-pod
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged
```

The default nginx image runs as root (UID 0). `runAsNonRoot: true` tells Kubernetes to reject any container that would run as root. The `nginx-unprivileged` variant runs as UID 101.

</details>

### Cleanup

```bash
kubectl delete pod secure-pod cap-pod nonroot-pod
```

---

## Lesson 4: ServiceAccounts and RBAC

Now that you can lock down containers with SecurityContext, the next layer is controlling what a pod can do in the Kubernetes API itself. By default, every pod gets a default ServiceAccount that may have more access than it needs.

### Why ServiceAccounts exist

When your application code needs to talk to the Kubernetes API (list pods, create ConfigMaps, watch events), it authenticates as a ServiceAccount. Every namespace has a `default` ServiceAccount, but best practice is to create dedicated ones with only the permissions each app needs.

### The RBAC chain

RBAC has four objects, and they chain together:

1. **ServiceAccount** - the identity a pod runs as
2. **Role** - a set of permissions (verbs + resources) in a single namespace
3. **ClusterRole** - same as Role but cluster-wide
4. **RoleBinding** - connects a ServiceAccount (or user) to a Role
5. **ClusterRoleBinding** - connects to a ClusterRole cluster-wide

The chain is: Pod → ServiceAccount → RoleBinding → Role → permissions.

### Creating the chain imperatively

```bash
# Step 1: Create ServiceAccount
kubectl create sa app-sa

# Step 2: Create Role (namespace-scoped permissions)
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Step 3: Bind them together
kubectl create rolebinding app-rb --role=pod-reader --serviceaccount=default:app-sa
# Format: --serviceaccount=<namespace>:<sa-name>

# Step 4: Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:app-sa
# yes

kubectl auth can-i delete pods --as=system:serviceaccount:default:app-sa
# no
```

For cluster-wide permissions, use `clusterrole` and `clusterrolebinding`:

```bash
kubectl create clusterrole node-reader --verb=get,list --resource=nodes
kubectl create clusterrolebinding node-rb --clusterrole=node-reader --serviceaccount=default:app-sa
```

### Assigning a ServiceAccount to a pod

```yaml
spec:
  serviceAccountName: app-sa              # Use this SA instead of default
  automountServiceAccountToken: false     # Don't mount the token if not needed
  containers:
  - name: app
    image: nginx
```

Setting `automountServiceAccountToken: false` is a security hardening step. If your app doesn't talk to the Kubernetes API, there's no reason to mount the token.

### Exercises

**4.1** Create a ServiceAccount called `deploy-sa` in the default namespace. Create a Role called `deploy-manager` that allows `get`, `list`, `create`, and `delete` on `deployments`. Bind them with a RoleBinding called `deploy-binding`. Verify that `deploy-sa` can create deployments but cannot delete pods.

<details>
<summary>Solution</summary>

```bash
kubectl create sa deploy-sa
kubectl create role deploy-manager --verb=get,list,create,delete --resource=deployments
kubectl create rolebinding deploy-binding --role=deploy-manager --serviceaccount=default:deploy-sa

kubectl auth can-i create deployments --as=system:serviceaccount:default:deploy-sa
# yes

kubectl auth can-i delete pods --as=system:serviceaccount:default:deploy-sa
# no
```

</details>

**4.2** Create a pod called `sa-pod` using `busybox` (sleep 3600) that runs with the `deploy-sa` ServiceAccount. Disable the automatic token mount.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-pod
spec:
  serviceAccountName: deploy-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
```

```bash
kubectl apply -f sa-pod.yaml
kubectl exec sa-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount
# ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
```

The token directory doesn't exist because we disabled automounting.

</details>

**4.3** Create a ClusterRole called `namespace-viewer` that allows `get` and `list` on `namespaces`. Bind it to the `deploy-sa` ServiceAccount with a ClusterRoleBinding called `ns-view-binding`. Verify that `deploy-sa` can list namespaces.

<details>
<summary>Solution</summary>

```bash
kubectl create clusterrole namespace-viewer --verb=get,list --resource=namespaces
kubectl create clusterrolebinding ns-view-binding \
  --clusterrole=namespace-viewer \
  --serviceaccount=default:deploy-sa

kubectl auth can-i list namespaces --as=system:serviceaccount:default:deploy-sa
# yes
```

</details>

### Cleanup

```bash
kubectl delete pod sa-pod
kubectl delete rolebinding deploy-binding
kubectl delete role deploy-manager
kubectl delete clusterrolebinding ns-view-binding
kubectl delete clusterrole namespace-viewer
kubectl delete sa deploy-sa
```

---

## Lesson 5: Resource Management

You've secured your pods with SecurityContext and RBAC. The last piece is resource management - making sure pods request what they need and don't consume more than they should.

### Why resource management matters

Without resource limits, a single misbehaving pod can consume all CPU and memory on a node, starving other pods. Kubernetes uses two controls:

1. **Requests** - the guaranteed minimum. The scheduler uses this to decide which node a pod fits on. If you request 500m CPU, the scheduler won't place you on a node with less than 500m available.
2. **Limits** - the maximum allowed. What happens when a pod exceeds its limit depends on the resource:
   - **CPU** - the pod gets **throttled** (slowed down). It still runs, just slower.
   - **Memory** - the pod gets **OOMKilled** (terminated). Kubernetes restarts it based on `restartPolicy`.

This is a key exam concept: CPU over-limit = throttle, memory over-limit = kill.

### Setting requests and limits

```yaml
containers:
- name: app
  image: nginx
  resources:
    requests:
      cpu: "100m"        # 100 millicores = 0.1 CPU
      memory: "64Mi"     # 64 mebibytes
    limits:
      cpu: "500m"        # Can burst up to 0.5 CPU
      memory: "128Mi"    # Killed if exceeds 128Mi
```

CPU is measured in millicores: `1000m` = 1 full CPU core. Memory uses standard suffixes: `Ki`, `Mi`, `Gi`.

### ResourceQuota

A ResourceQuota limits the total resources a namespace can consume. This prevents any single team from hogging the cluster:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

When a ResourceQuota exists in a namespace, every pod created in that namespace **must** specify resource requests and limits, or the pod will be rejected.

### LimitRange

While ResourceQuota sets namespace-wide totals, LimitRange sets per-pod or per-container defaults and constraints:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: dev
spec:
  limits:
  - type: Container
    default:              # Default limits (applied if not specified)
      cpu: "500m"
      memory: "128Mi"
    defaultRequest:       # Default requests (applied if not specified)
      cpu: "100m"
      memory: "64Mi"
    max:                  # Maximum allowed
      cpu: "2"
      memory: "1Gi"
    min:                  # Minimum allowed
      cpu: "50m"
      memory: "32Mi"
```

LimitRange is useful because it provides defaults - you don't have to remember to set requests/limits on every pod if sensible defaults exist.

### Exercises

**5.1** Create a pod called `resource-pod` using nginx that requests 100m CPU and 64Mi memory, with limits of 200m CPU and 128Mi memory. Verify the resource settings with `kubectl describe`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
```

```bash
kubectl apply -f resource-pod.yaml
kubectl describe pod resource-pod | grep -A 6 "Limits\|Requests"
```

</details>

**5.2** Create a namespace called `quota-ns`. Apply a ResourceQuota called `compute-quota` that limits the namespace to 1 CPU and 1Gi memory for both requests and limits, and a maximum of 5 pods. Then try creating a pod without resource requests - it should be rejected.

<details>
<summary>Solution</summary>

```bash
kubectl create ns quota-ns
```

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: quota-ns
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "1"
    limits.memory: "1Gi"
    pods: "5"
```

```bash
kubectl apply -f quota.yaml

# This will fail - no resource requests specified
kubectl run test --image=nginx -n quota-ns
# Error: must specify requests/limits when ResourceQuota is active

# This will work
kubectl run test --image=nginx -n quota-ns $do > test-pod.yaml
# Edit to add resources, then apply
```

</details>

**5.3** In the `quota-ns` namespace, create a LimitRange called `default-limits` that sets default container limits of 200m CPU and 128Mi memory, and default requests of 100m CPU and 64Mi memory. Create a pod without specifying resources and verify the defaults were applied.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: quota-ns
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "128Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
```

```bash
kubectl apply -f limitrange.yaml
kubectl run auto-limits --image=nginx -n quota-ns
kubectl describe pod auto-limits -n quota-ns | grep -A 6 "Limits\|Requests"
# Should show the defaults from LimitRange
```

</details>

### Cleanup

```bash
kubectl delete pod resource-pod
kubectl delete ns quota-ns
```

---

## Final Challenge

This exercise combines everything from all 5 lessons. No hints - just the task.

Create a namespace called `secure-app` with the following setup:

1. A ResourceQuota allowing max 2 CPU, 2Gi memory, and 10 pods
2. A LimitRange with default container limits of 500m CPU / 256Mi memory and default requests of 100m CPU / 64Mi memory
3. A ConfigMap called `app-config` with keys `APP_ENV=production` and `LOG_LEVEL=warn`
4. A Secret called `db-creds` with keys `DB_USER=admin` and `DB_PASS=s3cret`
5. A ServiceAccount called `app-sa` with a Role allowing `get,list` on `pods` and `configmaps`, bound via RoleBinding
6. A pod called `secure-app` in the `secure-app` namespace that:
   - Uses the `app-sa` ServiceAccount
   - Injects all ConfigMap keys as env vars via `envFrom`
   - Mounts the Secret at `/etc/db-creds` as a read-only volume
   - Runs as user 1000 with a read-only root filesystem
   - Has an `emptyDir` at `/tmp` for writable temp space
   - Uses the `busybox` image with `sleep 3600`

<details>
<summary>Solution</summary>

```bash
kubectl create ns secure-app

# ResourceQuota
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: secure-app
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
    pods: "10"
EOF

# LimitRange
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: secure-app
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
EOF

# ConfigMap and Secret
kubectl create cm app-config -n secure-app \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=warn

kubectl create secret generic db-creds -n secure-app \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=s3cret

# RBAC
kubectl create sa app-sa -n secure-app
kubectl create role app-reader -n secure-app --verb=get,list --resource=pods,configmaps
kubectl create rolebinding app-rb -n secure-app --role=app-reader --serviceaccount=secure-app:app-sa
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secure-app
spec:
  serviceAccountName: app-sa
  securityContext:
    runAsUser: 1000
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-config
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: db-creds
    secret:
      secretName: db-creds
  - name: tmp
    emptyDir: {}
```

```bash
kubectl apply -f secure-app-pod.yaml

# Verify everything
kubectl exec secure-app -n secure-app -- id                    # uid=1000
kubectl exec secure-app -n secure-app -- env | grep APP_ENV    # production
kubectl exec secure-app -n secure-app -- cat /etc/db-creds/DB_PASS  # s3cret
kubectl exec secure-app -n secure-app -- touch /test           # Read-only file system
kubectl exec secure-app -n secure-app -- touch /tmp/test       # works
kubectl auth can-i get pods -n secure-app --as=system:serviceaccount:secure-app:app-sa  # yes
```

</details>

### Cleanup

```bash
kubectl delete ns secure-app
```

---

## Quick Reference

### Imperative shortcuts

```bash
kubectl create cm <name> --from-literal=K=V [--from-literal=K2=V2]
kubectl create cm <name> --from-file=<file>
kubectl create cm <name> --from-file=<dir>/
kubectl create secret generic <name> --from-literal=K=V
kubectl create secret tls <name> --cert=<file> --key=<file>
kubectl create secret docker-registry <name> --docker-server=<url> --docker-username=<u> --docker-password=<p>
kubectl create sa <name>
kubectl create role <name> --verb=<verbs> --resource=<resources>
kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa>
kubectl create clusterrole <name> --verb=<verbs> --resource=<resources>
kubectl create clusterrolebinding <name> --clusterrole=<cr> --serviceaccount=<ns>:<sa>
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>
# Add --dry-run=client -o yaml to any of these to get editable YAML
```

### What goes where

| Thing | YAML path |
|---|---|
| ConfigMap env (all keys) | `spec.containers[].envFrom[].configMapRef` |
| ConfigMap env (single key) | `spec.containers[].env[].valueFrom.configMapKeyRef` |
| ConfigMap volume | `spec.volumes[].configMap.name` |
| Secret env (all keys) | `spec.containers[].envFrom[].secretRef` |
| Secret env (single key) | `spec.containers[].env[].valueFrom.secretKeyRef` |
| Secret volume | `spec.volumes[].secret.secretName` |
| imagePullSecrets | `spec.imagePullSecrets[].name` |
| SecurityContext (pod) | `spec.securityContext` |
| SecurityContext (container) | `spec.containers[].securityContext` |
| Capabilities | `spec.containers[].securityContext.capabilities` |
| ServiceAccount | `spec.serviceAccountName` |
| Automount token | `spec.automountServiceAccountToken` |
| Resource requests | `spec.containers[].resources.requests` |
| Resource limits | `spec.containers[].resources.limits` |

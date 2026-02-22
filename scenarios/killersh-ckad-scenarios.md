# Killer Shell CKAD — All 17 Scenario Topics + Tips & Tricks

> Based on the Killer Shell CKAD simulator. Each section covers the task type, the workflow to solve it fast, and the key commands to know.

---

## General Exam Workflow

Before diving into questions, set these up **immediately** at the start of the exam:

```bash
# Alias kubectl to k
alias k=kubectl
export do="--dry-run=client -oyaml"

# Set vim to use 2-space indent (add to ~/.vimrc or run in vim)
# :set tabstop=2 shiftwidth=2 expandtab
```

**Per-question workflow:**
1. Read the full task — note the namespace, resource name, and verification step
2. Switch context/namespace first: `k config set-context --current --namespace=<ns>`
3. Use imperative commands + `--dry-run=client -oyaml > file.yaml` to scaffold YAML fast
4. Apply with `k apply -f file.yaml`
5. Verify with `k get`, `k describe`, or `k logs` before moving on

---

## Q1 — Namespaces: List and Save Resources

**Task type:** List all namespaces and save output to a file.

**Workflow:**
```bash
k get namespaces > /path/to/output.txt
# or save just the names:
k get ns -o jsonpath='{.items[*].metadata.name}' > /path/to/output.txt
```

**Tips:**
- `-o name` gives a clean list: `k get ns -o name`
- Always double-check the output file path the question specifies
- Use `cat` to verify the file was written correctly

---

## Q2 — Pods: Create a Pod with Specific Container Naming

**Task type:** Create a pod with a precise name, image, and container name.

**Workflow:**
```bash
# Imperative — fastest approach
k run <pod-name> --image=<image> --restart=Never $do > pod.yaml
# Edit container name in YAML if it differs from pod name
k apply -f pod.yaml
k get pod <pod-name>
```

**Tips:**
- `k run` sets the container name to the pod name by default — check if the task requires a different container name
- Use `$do` alias (`--dry-run=client -oyaml`) to scaffold and edit before applying
- Verify with `k describe pod <name>` to check container name

---

## Q3 — Jobs: Parallelism and Pod Labels

**Task type:** Create a Job with specific parallelism, completions, and label selectors.

**Workflow:**
```bash
k create job <job-name> --image=<image> $do > job.yaml
# Then edit job.yaml to add:
#   spec.parallelism: N
#   spec.completions: N
#   spec.template.metadata.labels: {key: val}
k apply -f job.yaml
k get jobs
k get pods -l <label-key>=<label-val>
```

**Tips:**
- Jobs don't have an imperative flag for parallelism — always go YAML
- Label the pod template (`spec.template.metadata.labels`), not the Job itself
- Check completion with `k get job <name>` — look for `COMPLETIONS` column

---

## Q4 — Helm: Delete, Upgrade, and Install Releases

**Task type:** Manage Helm releases — remove old, upgrade existing, or install new.

**Workflow:**
```bash
# List releases
helm list -n <namespace>

# Delete a release
helm uninstall <release-name> -n <namespace>

# Upgrade a release (change values)
helm upgrade <release-name> <chart> --set key=value -n <namespace>

# Install a new release
helm install <release-name> <chart> --set key=value -n <namespace>
```

**Tips:**
- Always specify `-n <namespace>` — releases are namespace-scoped
- `helm list -A` shows all namespaces at once
- `helm show values <chart>` lets you inspect available values before setting them
- If upgrading, use `--reuse-values` to keep existing values and only override what you need

---

## Q5 — ServiceAccount + Secret: Extract Base64-Decoded Token

**Task type:** Find the token from a ServiceAccount-bound Secret and decode it.

**Workflow:**
```bash
# Find the secret associated with the ServiceAccount
k get sa <sa-name> -n <namespace> -oyaml

# Get the token secret name (or find it directly)
k get secrets -n <namespace>

# Extract and decode the token
k get secret <secret-name> -n <namespace> -o jsonpath='{.data.token}' | base64 -d > /path/to/output.txt
```

**Tips:**
- In newer Kubernetes (1.24+), tokens are not auto-created — check for a manually created `kubernetes.io/service-account-token` type secret
- `base64 -d` on Linux; on exam nodes it's always Linux
- Always pipe `| base64 -d` — the task usually wants the decoded value saved to a file

---

## Q6 — ReadinessProbe: HTTP Check with Initial Delay

**Task type:** Add a readinessProbe to an existing pod/deployment.

**Workflow:**
```bash
k get pod <name> -oyaml > pod.yaml
# Edit pod.yaml — add under containers[]:
# readinessProbe:
#   httpGet:
#     path: /health
#     port: 8080
#   initialDelaySeconds: 10
#   periodSeconds: 5
k replace --force -f pod.yaml   # for pods (can't edit in place)
# OR for deployments:
k edit deploy <name>
```

**Tips:**
- Pods are immutable once created — use `k replace --force -f` to delete and recreate
- For deployments, `k edit` triggers a rolling update automatically
- Common probe types: `httpGet`, `tcpSocket`, `exec` — read the question carefully
- `initialDelaySeconds` gives the container time to start before probing begins

---

## Q7 — Pods Across Namespaces: Migrate a Pod

**Task type:** Move a pod from one namespace to another (recreate it in the target namespace).

**Workflow:**
```bash
# Export the existing pod
k get pod <name> -n <source-ns> -oyaml > pod.yaml

# Edit pod.yaml:
# - Change metadata.namespace to <target-ns>
# - Remove: status, resourceVersion, uid, creationTimestamp, managedFields

k apply -f pod.yaml -n <target-ns>
k delete pod <name> -n <source-ns>
```

**Tips:**
- You MUST clean the YAML — remove `status:`, `metadata.uid`, `metadata.resourceVersion`, `metadata.creationTimestamp`, and `metadata.managedFields`
- Quick cleanup: pipe through `k neat` if available, or use `grep -v` for the fields
- Verify the pod is Running in the new namespace before deleting the old one

---

## Q8 — Deployment Rollouts: Debug and Rollback

**Task type:** Find why a deployment is failing and roll back to the previous version.

**Workflow:**
```bash
# Check rollout status
k rollout status deploy/<name> -n <namespace>

# Check history
k rollout history deploy/<name> -n <namespace>

# Inspect current pods for errors
k get pods -n <namespace>
k describe pod <failing-pod> -n <namespace>
k logs <failing-pod> -n <namespace>

# Roll back
k rollout undo deploy/<name> -n <namespace>

# Roll back to specific revision
k rollout undo deploy/<name> --to-revision=<N> -n <namespace>
```

**Tips:**
- `k rollout history` shows revision numbers — use `--revision=N` to inspect a specific one
- Common failure causes: wrong image name, missing env vars, bad resource limits
- After rollback, verify with `k rollout status` and `k get pods`

---

## Q9 — Pod → Deployment Conversion

**Task type:** Convert a standalone pod spec into a Deployment.

**Workflow:**
```bash
# Get the pod YAML as a base
k get pod <name> -oyaml > pod.yaml

# Create deployment scaffold
k create deploy <deploy-name> --image=<image> $do > deploy.yaml

# Merge: copy the pod's containers[] spec into deploy.yaml's spec.template.spec.containers[]
# Set replicas if specified
k apply -f deploy.yaml
k delete pod <name>   # remove the original pod if asked
```

**Tips:**
- A Deployment wraps a pod template — the pod spec goes under `spec.template.spec`
- Don't copy pod-level fields like `restartPolicy: Never` into the deployment (deployments always restart)
- Set `spec.replicas` and `spec.selector.matchLabels` to match `spec.template.metadata.labels`

---

## Q10 — Services + Logs: ClusterIP and curl Testing

**Task type:** Expose a deployment as a ClusterIP service, then test connectivity with curl.

**Workflow:**
```bash
# Create service (expose)
k expose deploy <name> --port=<svc-port> --target-port=<container-port> --name=<svc-name> -n <namespace>

# Verify service
k get svc <svc-name> -n <namespace>

# Test with a temporary pod
k run tmp --image=busybox --restart=Never -it --rm -- wget -qO- <svc-name>.<namespace>.svc.cluster.local:<port>
# or with curl image:
k run tmp --image=curlimages/curl --restart=Never -it --rm -- curl <cluster-ip>:<port>

# Check logs
k logs <pod-name> -n <namespace>
k logs <pod-name> -n <namespace> --previous   # for crashed containers
```

**Tips:**
- ClusterIP is the default service type — no need to specify `--type`
- DNS format: `<service>.<namespace>.svc.cluster.local`
- `k logs` supports `-f` for follow and `--tail=N` to limit output
- Save log output to a file if the task asks: `k logs <pod> > /path/file.txt`

---

## Q11 — Working with Containers: Build with Docker/Podman

**Task type:** Build a container image from a Dockerfile and tag/push it.

**Workflow:**
```bash
# Build
docker build -t <registry>/<image>:<tag> .
# or with podman:
podman build -t <registry>/<image>:<tag> .

# Tag
docker tag <local-image> <registry>/<image>:<tag>

# Push
docker push <registry>/<image>:<tag>

# Save to file if required
docker save <image>:<tag> -o /path/image.tar
```

**Tips:**
- Read the Dockerfile path carefully — use `-f /path/Dockerfile` if not in current dir
- The exam may use `podman` instead of `docker` — they share the same CLI syntax
- Always verify the image exists after build: `docker images | grep <name>`
- If pushing to a local registry, the registry URL is usually given in the task

---

## Q12 — Storage: PersistentVolume, PVC, and Pod Volume Mount

**Task type:** Create a PV and PVC, then mount the volume into a pod.

**Workflow:**
```bash
# PV (cluster-scoped, no namespace)
cat <<EOF | k apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: <pv-name>
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data
EOF

# PVC (namespaced)
cat <<EOF | k apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <pvc-name>
  namespace: <ns>
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Add to pod spec:
# volumes:
# - name: data
#   persistentVolumeClaim:
#     claimName: <pvc-name>
# containers[].volumeMounts:
# - name: data
#   mountPath: /path/in/container
```

**Tips:**
- PV `accessModes` and `storage` must match PVC for binding to succeed
- Check PVC status: `k get pvc -n <ns>` — must show `Bound`
- `hostPath` PVs don't need a StorageClass — use `storageClassName: ""` to skip default SC

---

## Q13 — StorageClass + PVC with Custom Provisioner

**Task type:** Create a StorageClass with a specific provisioner, then use it in a PVC.

**Workflow:**
```bash
cat <<EOF | k apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: <sc-name>
provisioner: <provisioner-name>   # e.g. rancher.io/local-path
reclaimPolicy: Retain             # or Delete
volumeBindingMode: WaitForFirstConsumer
EOF

# PVC referencing the StorageClass
cat <<EOF | k apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <pvc-name>
spec:
  storageClassName: <sc-name>
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF
```

**Tips:**
- The provisioner name is always given in the task — copy it exactly
- `reclaimPolicy` and `volumeBindingMode` fields are often specified — read carefully
- With `WaitForFirstConsumer`, the PVC stays `Pending` until a pod uses it — that's normal

---

## Q14 — Secrets: Volume Mount and Environment Variable

**Task type:** Mount a Secret as a volume file and/or inject it as an env var.

**Workflow:**
```bash
# Create the secret
k create secret generic <name> --from-literal=<key>=<value> -n <ns>
# or from file:
k create secret generic <name> --from-file=<key>=<filepath> -n <ns>

# Mount as volume (in pod spec):
# volumes:
# - name: secret-vol
#   secret:
#     secretName: <name>
# containers[].volumeMounts:
# - name: secret-vol
#   mountPath: /etc/secret
#   readOnly: true

# Mount as env var:
# containers[].env:
# - name: MY_SECRET
#   valueFrom:
#     secretKeyRef:
#       name: <secret-name>
#       key: <key>
```

**Tips:**
- Volume-mounted secrets appear as files at the mountPath — filename = key name
- Env var injection uses `secretKeyRef`; volume injection uses `secretName`
- Verify: `k exec <pod> -- cat /etc/secret/<key>` or `k exec <pod> -- env | grep MY_SECRET`

---

## Q15 — ConfigMap: Volume and Environment Mounting

**Task type:** Create a ConfigMap and mount it into a pod as a volume or env var.

**Workflow:**
```bash
# Create ConfigMap
k create configmap <name> --from-literal=<key>=<value> -n <ns>
# or from file:
k create configmap <name> --from-file=<key>=<filepath> -n <ns>

# Mount as volume:
# volumes:
# - name: config-vol
#   configMap:
#     name: <cm-name>
# containers[].volumeMounts:
# - name: config-vol
#   mountPath: /etc/config

# Mount as env var:
# containers[].env:
# - name: MY_CONFIG
#   valueFrom:
#     configMapKeyRef:
#       name: <cm-name>
#       key: <key>

# Mount ALL keys as env vars:
# containers[].envFrom:
# - configMapRef:
#     name: <cm-name>
```

**Tips:**
- `envFrom` injects all keys at once — faster than listing each one individually
- Volume-mounted ConfigMaps update automatically if the CM changes (env vars don't)
- Verify: `k exec <pod> -- cat /etc/config/<key>` or `k exec <pod> -- env`

---

## Q16 — Logging Sidecar Pattern

**Task type:** Add a sidecar container that reads logs from a shared volume and writes to stdout.

**Workflow:**
```bash
# Pod with two containers sharing a volume:
# volumes:
# - name: logs
#   emptyDir: {}
#
# containers:
# - name: main-app
#   volumeMounts:
#   - name: logs
#     mountPath: /var/log/app
#
# - name: log-sidecar
#   image: busybox
#   command: ["sh", "-c", "tail -f /var/log/app/app.log"]
#   volumeMounts:
#   - name: logs
#     mountPath: /var/log/app
```

**Verify:**
```bash
k logs <pod-name> -c log-sidecar -n <ns>
```

**Tips:**
- The sidecar uses `tail -f` to stream the log file to stdout — `k logs` then captures it
- Both containers MUST share the same volume name
- `emptyDir` is the typical shared volume type for this pattern — lives as long as the pod

---

## Q17 — InitContainer: Pre-Initialize Volumes

**Task type:** Add an initContainer that runs before the main container to set up data.

**Workflow:**
```bash
# Pod spec with initContainers:
# initContainers:
# - name: init-setup
#   image: busybox
#   command: ["sh", "-c", "echo 'initialized' > /work-dir/data.txt"]
#   volumeMounts:
#   - name: work
#     mountPath: /work-dir
#
# containers:
# - name: main
#   image: nginx
#   volumeMounts:
#   - name: work
#     mountPath: /usr/share/nginx/html
#
# volumes:
# - name: work
#   emptyDir: {}
```

**Verify:**
```bash
k get pod <name>           # watch for Init:0/1 → PodInitializing → Running
k logs <pod> -c init-setup # check init container logs
k exec <pod> -- cat /usr/share/nginx/html/data.txt
```

**Tips:**
- InitContainers run sequentially and must complete (exit 0) before the main container starts
- Pod shows `Init:0/1` status while init is running — normal
- If the init fails, pod goes to `Init:CrashLoopBackOff` — check with `k logs <pod> -c <init-name>`
- Shared volume (`emptyDir`) persists between init and main containers within the same pod

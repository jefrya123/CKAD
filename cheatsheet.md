# CKAD Ultimate Cheatsheet

> Print this. Keep it next to you while practicing.

## Exam Setup (First 30 Seconds)

```bash
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```

---

## Generate YAML Fast

```bash
k run nginx --image=nginx $do > pod.yaml
k create deploy nginx --image=nginx --replicas=3 $do > deploy.yaml
k expose deploy nginx --port=80 --type=ClusterIP $do > svc.yaml
k create cm myconfig --from-literal=key=val $do
k create secret generic mysecret --from-literal=pass=123 $do
k create sa mysa $do
k create job myjob --image=busybox $do -- echo "hello"
k create cronjob mycron --image=busybox --schedule="*/5 * * * *" $do -- date
k create ingress myingress --rule="host/path=svc:80" $do
k create role myrole --verb=get,list --resource=pods $do
k create rolebinding myb --role=myrole --serviceaccount=default:mysa $do
```

---

## Pods

```bash
k run nginx --image=nginx                          # create pod
k run nginx --image=nginx -l app=web               # with labels
k run nginx --image=nginx --port=80                # with port
k run nginx --image=nginx --env="DB=mysql"         # with env var
k run nginx --image=nginx --command -- sleep 3600  # custom command
k delete pod nginx $now                            # fast delete
```

### Pod YAML Skeleton

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  containers:
  - name: myapp
    image: nginx
    ports:
    - containerPort: 80
    env:
    - name: KEY
      value: "value"
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

---

## Multi-Container Pods

```yaml
spec:
  initContainers:              # run first, sequentially
  - name: init
    image: busybox
    command: ['sh', '-c', 'echo init > /work/ready']
    volumeMounts:
    - name: shared
      mountPath: /work
  containers:
  - name: app                  # main container
    image: nginx
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar              # helper container
    image: busybox
    command: ['sh', '-c', 'tail -f /usr/share/nginx/html/access.log']
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  volumes:
  - name: shared
    emptyDir: {}
```

---

## Deployments

```bash
k create deploy web --image=nginx --replicas=3
k scale deploy web --replicas=5
k set image deploy/web nginx=nginx:1.21
k rollout status deploy/web
k rollout history deploy/web
k rollout undo deploy/web
k rollout undo deploy/web --to-revision=2
```

### Strategy

```yaml
strategy:
  type: RollingUpdate        # or Recreate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```

---

## Services

```bash
k expose deploy web --port=80 --type=ClusterIP       # default
k expose deploy web --port=80 --type=NodePort
k expose pod nginx --port=80 --name=nginx-svc
```

| Type | Scope | Port Range |
|------|-------|------------|
| ClusterIP | Internal only | any |
| NodePort | External via node IP | 30000–32767 |
| LoadBalancer | Cloud LB | any |

---

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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
            name: mysvc
            port:
              number: 80
```

---

## ConfigMaps & Secrets

```bash
# ConfigMap
k create cm app-config --from-literal=APP_ENV=prod --from-literal=LOG=info
k create cm app-config --from-file=config.properties

# Secret
k create secret generic db-creds --from-literal=user=admin --from-literal=pass=s3cret
k get secret db-creds -o jsonpath='{.data.pass}' | base64 -d
```

### Use in Pod

```yaml
# All keys as env vars
envFrom:
- configMapRef:
    name: app-config
- secretRef:
    name: db-creds

# Single key
env:
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: pass

# As volume
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: app-config
```

---

## Probes

```yaml
livenessProbe:           # restart if fails
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

readinessProbe:          # remove from service if fails
  tcpSocket:
    port: 3306
  initialDelaySeconds: 5
  periodSeconds: 10

startupProbe:            # blocks other probes until success
  exec:
    command: ["cat", "/tmp/ready"]
  failureThreshold: 30
  periodSeconds: 10
```

---

## Jobs & CronJobs

```bash
k create job pi --image=perl -- perl -Mbignum=bpi -wle 'print bpi(100)'
k create cronjob backup --image=busybox --schedule="0 2 * * *" -- echo "backup"
```

```yaml
# Job with completions/parallelism
spec:
  completions: 5
  parallelism: 2
  backoffLimit: 4
  activeDeadlineSeconds: 100
  template:
    spec:
      restartPolicy: Never

# CronJob fields
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid      # Allow | Forbid | Replace
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
```

### Cron Format

```
┌─ min (0-59)  ┌─ hour (0-23)  ┌─ day (1-31)  ┌─ month (1-12)  ┌─ dow (0-6)
*              *               *              *               *
```

---

## SecurityContext

```yaml
spec:
  securityContext:                    # pod level
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:                  # container level
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

---

## Resources

```yaml
resources:
  requests:
    cpu: "100m"        # 0.1 CPU
    memory: "64Mi"
  limits:
    cpu: "500m"        # 0.5 CPU
    memory: "128Mi"
```

---

## ServiceAccounts & RBAC

```bash
k create sa app-sa
k create role pod-reader --verb=get,list,watch --resource=pods
k create rolebinding rb --role=pod-reader --serviceaccount=default:app-sa
k auth can-i get pods --as=system:serviceaccount:default:app-sa
```

```yaml
# Disable token mount
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

---

## Network Policies

```yaml
# Deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress]

# Allow from specific pods on port 80
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 80

# Allow from namespace
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring

# Egress: DNS + HTTPS only
egress:
- ports:
  - port: 53
    protocol: UDP
- ports:
  - port: 443
    protocol: TCP
```

---

## Persistent Volumes

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
# In pod spec:
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc
```

---

## Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm install myapp bitnami/nginx --set replicaCount=3
helm install myapp bitnami/nginx -f values.yaml
helm list
helm upgrade myapp bitnami/nginx --set replicaCount=5
helm rollback myapp 1
helm uninstall myapp
helm template myapp bitnami/nginx          # render locally
helm install myapp bitnami/nginx --dry-run # validate with server
```

---

## Debugging

```bash
k describe pod <pod>                  # events, status, config
k logs <pod> [-c container]           # container logs
k logs <pod> --previous               # previous crash logs
k exec -it <pod> -- sh                # shell into container
k get events --sort-by='.lastTimestamp'
k top pods --sort-by=cpu              # resource usage
k auth can-i create pods              # RBAC check
```

---

## DNS

```
<svc>.<namespace>.svc.cluster.local
# Short forms (same namespace): <svc> or <svc>.<namespace>
```

---

## jsonpath & Custom Columns

```bash
k get pods -o jsonpath='{.items[*].metadata.name}'
k get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
k get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
k get pods --sort-by='.metadata.creationTimestamp'
```

---

## Vim Quick Reference

```
i         insert mode          dd   delete line
Esc       normal mode          yy   copy line
:wq       save & quit          p    paste below
:q!       quit no save         u    undo
/text     search               n    next match
:set nu   line numbers         :set paste  paste mode
```

# Comprehensive Mock Exam

> 20 questions covering all domains. Time yourself: 2 hours total. No peeking at answers until you've attempted everything.

---

## Q1 (Domain 1) — Create a pod `web-app` with nginx and a sidecar busybox container that tails `/var/log/nginx/access.log`. Share logs via emptyDir volume.

<details>
<summary>Answer</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: sidecar
    image: busybox
    command: ["tail", "-f", "/var/log/nginx/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  volumes:
  - name: logs
    emptyDir: {}
```

</details>

## Q2 (Domain 1) — Create a Job `pi-calc` that calculates pi to 50 digits, completes 3 times, runs 2 in parallel.

<details>
<summary>Answer</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calc
spec:
  completions: 3
  parallelism: 2
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(50)"]
      restartPolicy: Never
```

</details>

## Q3 (Domain 1) — Create a CronJob `heartbeat` that runs every 5 minutes, keeps 2 successful history, uses concurrencyPolicy Forbid.

<details>
<summary>Answer</summary>

```bash
kubectl create cronjob heartbeat --image=busybox --schedule="*/5 * * * *" --dry-run=client -o yaml -- echo "alive" > cj.yaml
# Edit to add:
#   successfulJobsHistoryLimit: 2
#   concurrencyPolicy: Forbid
kubectl apply -f cj.yaml
```

</details>

## Q4 (Domain 2) — Create deployment `api` with nginx:1.19, 3 replicas. Update to nginx:1.21. Rollback to 1.19.

<details>
<summary>Answer</summary>

```bash
kubectl create deploy api --image=nginx:1.19 --replicas=3
kubectl set image deploy/api nginx=nginx:1.21
kubectl rollout undo deploy/api
kubectl describe deploy api | grep Image  # nginx:1.19
```

</details>

## Q5 (Domain 2) — Install a Helm chart: add bitnami repo, install nginx as `my-web` with 2 replicas, upgrade to 4 replicas.

<details>
<summary>Answer</summary>

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-web bitnami/nginx --set replicaCount=2
helm upgrade my-web bitnami/nginx --set replicaCount=4
```

</details>

## Q6 (Domain 3) — Create pod `health-check` with nginx. Add liveness (HTTP GET / port 80, period 10s) and readiness (HTTP GET /ready port 80, period 5s) probes.

<details>
<summary>Answer</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: health-check
spec:
  containers:
  - name: nginx
    image: nginx
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      periodSeconds: 5
```

</details>

## Q7 (Domain 3) — A pod named `broken-app` is in CrashLoopBackOff. Write the commands to debug it.

<details>
<summary>Answer</summary>

```bash
kubectl describe pod broken-app          # check events
kubectl logs broken-app --previous       # check crash logs
kubectl get events --field-selector involvedObject.name=broken-app
```

</details>

## Q8 (Domain 4) — Create ConfigMap `app-settings` with DB_HOST=mysql and DB_PORT=3306. Create pod that loads both as env vars using envFrom.

<details>
<summary>Answer</summary>

```bash
kubectl create cm app-settings --from-literal=DB_HOST=mysql --from-literal=DB_PORT=3306
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-settings
```

</details>

## Q9 (Domain 4) — Create a Secret `api-key` with `token=abc123`. Mount it as env var `API_TOKEN` in a pod.

<details>
<summary>Answer</summary>

```bash
kubectl create secret generic api-key --from-literal=token=abc123
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: API_TOKEN
      valueFrom:
        secretKeyRef:
          name: api-key
          key: token
```

</details>

## Q10 (Domain 4) — Create pod `locked-down` running as user 1000, group 2000, read-only filesystem, no privilege escalation.

<details>
<summary>Answer</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: locked-down
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 2000
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
```

</details>

## Q11 (Domain 4) — Create ServiceAccount `deployer` in namespace `prod`. Create Role allowing create/delete on deployments. Bind them.

<details>
<summary>Answer</summary>

```bash
kubectl create ns prod
kubectl create sa deployer -n prod
kubectl create role deploy-manager -n prod --verb=create,delete --resource=deployments
kubectl create rolebinding deployer-binding -n prod --role=deploy-manager --serviceaccount=prod:deployer
kubectl auth can-i create deployments -n prod --as=system:serviceaccount:prod:deployer  # yes
```

</details>

## Q12 (Domain 4) — Create pod with resource requests (cpu: 100m, memory: 64Mi) and limits (cpu: 500m, memory: 256Mi).

<details>
<summary>Answer</summary>

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
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
```

</details>

## Q13 (Domain 5) — Create deployment `backend` with 3 replicas. Expose as NodePort service on port 80.

<details>
<summary>Answer</summary>

```bash
kubectl create deploy backend --image=nginx --replicas=3
kubectl expose deploy backend --port=80 --type=NodePort
kubectl get svc backend  # note the NodePort
```

</details>

## Q14 (Domain 5) — Create an Ingress routing `app.example.com/api` to `api-svc:80` and `app.example.com/` to `web-svc:80`.

<details>
<summary>Answer</summary>

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
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

</details>

## Q15 (Domain 5) — Create NetworkPolicy: only allow pods with label `role=frontend` to access pods with label `role=api` on port 8080.

<details>
<summary>Answer</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-access
spec:
  podSelector:
    matchLabels:
      role: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - port: 8080
      protocol: TCP
```

</details>

## Q16 (Domain 1) — Create a pod with an init container that waits for service `db` on port 5432, then starts nginx.

<details>
<summary>Answer</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: wait-for-db
spec:
  initContainers:
  - name: wait
    image: busybox
    command: ['sh', '-c', 'until nc -z db 5432; do sleep 2; done']
  containers:
  - name: app
    image: nginx
```

</details>

## Q17 (Domain 4) — Create a PVC `data-vol` (1Gi, RWO) and mount it in a pod at `/data`.

<details>
<summary>Answer</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-vol
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
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
      claimName: data-vol
```

</details>

## Q18 (Domain 5) — Create egress NetworkPolicy: pods labeled `app=worker` can only access HTTPS (443) and DNS (53/UDP).

<details>
<summary>Answer</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: worker-egress
spec:
  podSelector:
    matchLabels:
      app: worker
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
  - ports:
    - port: 443
      protocol: TCP
```

</details>

## Q19 (Domain 3) — Pod `slow-app` takes 60 seconds to start. Configure probes so it doesn't get killed during startup.

<details>
<summary>Answer</summary>

Use a startup probe with enough time:

```yaml
startupProbe:
  httpGet:
    path: /
    port: 80
  failureThreshold: 12
  periodSeconds: 10    # 12 * 10 = 120s max startup
livenessProbe:
  httpGet:
    path: /
    port: 80
  periodSeconds: 10
```

The startup probe blocks liveness checks until the app is ready.

</details>

## Q20 (Domain 2) — Create a canary setup: deployment `stable` (nginx:1.19, 9 replicas), deployment `canary` (nginx:1.21, 1 replica), service selecting both.

<details>
<summary>Answer</summary>

Both deployments use label `app=myapp`. Service selects `app=myapp`:

```bash
# stable
kubectl create deploy stable --image=nginx:1.19 --replicas=9 --dry-run=client -o yaml | \
  sed 's/app: stable/app: myapp/' | kubectl apply -f -

# Easier with YAML — see scenario 10 for full example
```

Key: service selector uses the common label, not deployment-specific labels.

</details>

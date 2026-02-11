# Domain 1: Application Design and Build - Exercises

## Exercise 1: Multi-Container Pod (Sidecar Pattern)

Create a pod named `web-with-logging` with two containers:
1. Main container: nginx serving on port 80
2. Sidecar container: busybox that tails the nginx access logs

Both containers should share a volume at `/var/log/nginx`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-with-logging
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: log-tailer
    image: busybox
    command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  volumes:
  - name: logs
    emptyDir: {}
```

```bash
kubectl apply -f web-with-logging.yaml
kubectl logs web-with-logging -c log-tailer
```
</details>

## Exercise 2: Init Container

Create a pod named `init-demo` that:
1. Has an init container that creates a file `/work/ready.txt` with content "initialized"
2. Main container (nginx) mounts the volume and serves the file

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
  - name: init
    image: busybox
    command: ['sh', '-c', 'echo initialized > /work/ready.txt']
    volumeMounts:
    - name: workdir
      mountPath: /work
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: workdir
      mountPath: /usr/share/nginx/html
  volumes:
  - name: workdir
    emptyDir: {}
```

```bash
kubectl apply -f init-demo.yaml
kubectl exec init-demo -- cat /usr/share/nginx/html/ready.txt
```
</details>

## Exercise 3: Init Container - Wait for Service

Create a pod named `app-with-init` that:
1. Has an init container that waits for a service named `db-service` to be available
2. Main container runs nginx after init completes

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nc -z db-service 5432; do echo waiting for db; sleep 2; done']
  containers:
  - name: app
    image: nginx
```

```bash
# First, create a service for testing
kubectl create deployment db --image=nginx
kubectl expose deployment db --name=db-service --port=5432 --target-port=80

# Then create the pod
kubectl apply -f app-with-init.yaml
kubectl get pod app-with-init -w
```
</details>

## Exercise 4: Job

Create a Job named `batch-calc` that:
- Uses the `perl` image
- Calculates pi to 100 decimal places
- Should complete successfully exactly once

<details>
<summary>Solution</summary>

```bash
kubectl create job batch-calc --image=perl -- perl -Mbignum=bpi -wle 'print bpi(100)'

# Or YAML:
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-calc
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(100)"]
      restartPolicy: Never
```

```bash
kubectl get jobs
kubectl logs job/batch-calc
```
</details>

## Exercise 5: Job with Completions

Create a Job named `batch-worker` that:
- Uses the `busybox` image
- Runs the command `echo "Processing item"`
- Must complete 5 times successfully
- Can run up to 2 pods in parallel

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-worker
spec:
  completions: 5
  parallelism: 2
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["echo", "Processing item"]
      restartPolicy: Never
```

```bash
kubectl apply -f batch-worker.yaml
kubectl get jobs -w
kubectl get pods -l job-name=batch-worker
```
</details>

## Exercise 6: CronJob

Create a CronJob named `backup-job` that:
- Runs every 5 minutes
- Uses the `busybox` image
- Runs the command `echo "Backup completed at $(date)"`
- Keeps 2 successful job history and 1 failed

<details>
<summary>Solution</summary>

```bash
kubectl create cronjob backup-job --image=busybox --schedule="*/5 * * * *" -- /bin/sh -c "echo Backup completed at $(date)"

# Or YAML for more control:
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "*/5 * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command: ["/bin/sh", "-c", "echo Backup completed at $(date)"]
          restartPolicy: OnFailure
```

```bash
kubectl get cronjobs
kubectl get jobs -w
```
</details>

## Exercise 7: Ambassador Pattern

Create a pod named `app-with-proxy` that demonstrates the ambassador pattern:
1. Main container runs nginx on port 80
2. Ambassador container runs a simple proxy (use nginx configured as reverse proxy)

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-proxy
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
  - name: proxy
    image: nginx
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: proxy-config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: proxy-config
    configMap:
      name: proxy-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-config
data:
  default.conf: |
    server {
      listen 8080;
      location / {
        proxy_pass http://localhost:80;
      }
    }
```
</details>

## Exercise 8: Pod with PVC

Create:
1. A PersistentVolumeClaim named `app-data` requesting 100Mi of storage
2. A Pod named `data-pod` that mounts the PVC at `/data`

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
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
      claimName: app-data
```

```bash
kubectl apply -f data-pod.yaml
kubectl get pvc
kubectl exec data-pod -- df -h /data
```
</details>

## Cleanup

```bash
kubectl delete pod web-with-logging init-demo app-with-init app-with-proxy data-pod
kubectl delete job batch-calc batch-worker
kubectl delete cronjob backup-job
kubectl delete pvc app-data
kubectl delete deployment db
kubectl delete service db-service
kubectl delete configmap proxy-config
```

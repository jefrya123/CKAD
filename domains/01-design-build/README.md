# Domain 1: Application Design and Build (20%)

## Topics

- [ ] Multi-container pods (sidecar, ambassador, adapter)
- [ ] Init containers
- [ ] Jobs and CronJobs
- [ ] Persistent volumes for applications
- [ ] Container image basics

## Multi-Container Pod Patterns

### Sidecar Pattern

A helper container that enhances or extends the main container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-example
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: log-shipper
    image: busybox
    command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  volumes:
  - name: logs
    emptyDir: {}
```

### Ambassador Pattern

A proxy container that handles external communication for the main app.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-example
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: DB_HOST
      value: "localhost"  # Talks to ambassador
    - name: DB_PORT
      value: "5432"
  - name: db-proxy
    image: envoyproxy/envoy
    ports:
    - containerPort: 5432
```

### Adapter Pattern

A container that transforms output from the main container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: adapter-example
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: log-adapter
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        cat /var/log/app/app.log | sed 's/ERROR/CRITICAL/' > /var/log/app/formatted.log
        sleep 10
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```

## Init Containers

Init containers run before app containers start. All init containers must complete successfully.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-container-example
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nc -z db-service 5432; do echo waiting for db; sleep 2; done']
  - name: download-config
    image: busybox
    command: ['wget', '-O', '/config/app.conf', 'http://config-server/app.conf']
    volumeMounts:
    - name: config
      mountPath: /config
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    emptyDir: {}
```

### Use Cases for Init Containers

- Wait for dependencies (database, service)
- Download configuration or secrets
- Set up permissions or directory structure
- Run database migrations

## Jobs

One-time tasks that run to completion.

```bash
# Create a Job imperatively
kubectl create job pi --image=perl -- perl -Mbignum=bpi -wle 'print bpi(2000)'

# Generate YAML
kubectl create job myjob --image=busybox --dry-run=client -o yaml -- echo "Hello"
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  completions: 3        # Number of successful completions needed
  parallelism: 2        # Max pods running in parallel
  backoffLimit: 4       # Retries before marking failed
  activeDeadlineSeconds: 100  # Max time for job
  template:
    spec:
      restartPolicy: Never  # or OnFailure
      containers:
      - name: worker
        image: busybox
        command: ["echo", "Processing batch item"]
```

```bash
# Monitor jobs
kubectl get jobs
kubectl describe job batch-job
kubectl logs job/batch-job
```

## CronJobs

Scheduled jobs that run periodically.

```bash
# Create CronJob imperatively
kubectl create cronjob backup --image=busybox --schedule="0 2 * * *" -- /bin/sh -c "echo backup"
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"           # Daily at 2 AM
  concurrencyPolicy: Forbid       # Allow, Forbid, Replace
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 200    # Max delay to start
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox
            command: ["/bin/sh", "-c", "echo Running backup at $(date)"]
```

### Cron Schedule Format

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday = 0)
│ │ │ │ │
* * * * *
```

Examples:
- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour
- `0 0 * * *` - Daily at midnight
- `0 0 * * 0` - Weekly on Sunday

## Persistent Volumes for Applications

```yaml
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# Pod using PVC
apiVersion: v1
kind: Pod
metadata:
  name: app-with-storage
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

## Quick Commands

```bash
# Multi-container pod
kubectl run multi --image=nginx --dry-run=client -o yaml > multi.yaml
# Then edit to add more containers

# Jobs
kubectl create job myjob --image=busybox -- echo "done"
kubectl get jobs -w
kubectl delete job myjob

# CronJobs
kubectl create cronjob mycron --image=busybox --schedule="*/5 * * * *" -- echo "tick"
kubectl get cronjobs
kubectl delete cronjob mycron
```

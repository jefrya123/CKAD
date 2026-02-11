# CKAD Domain 1: Application Design and Build

Work through these lessons in order. Each one builds on the last, so by the end you're combining everything together. The pattern is: learn why something exists, understand how it works, then practice.

**Prerequisites:** A running cluster and `kubectl` configured.

---

## Lesson 1: Pods, Containers, and Shared Volumes

Before multi-container patterns or jobs make sense, you need to understand what a pod actually is and how containers inside one talk to each other.

### Why pods exist

A pod is not just "a container." It's a group of one or more containers that share two things:

1. **Network namespace** - all containers in a pod share the same IP. Container A can reach container B on `localhost`. No service discovery needed.
2. **Storage volumes** - containers can mount the same volume and read/write the same files.

This is the foundation everything else builds on. Multi-container patterns work because of shared networking and storage. Init containers work because volumes persist across container restarts within a pod.

### How volumes work in a pod

Volumes are declared at the pod level, then each container mounts whichever volumes it needs:

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:          # Container picks which volumes to mount
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:                 # Pod declares available volumes
  - name: data
    emptyDir: {}           # Created when pod starts, deleted when pod dies
```

`emptyDir` is the simplest volume type - it's just an empty directory that lives as long as the pod does. It's stored on the node's disk (or in memory if you set `medium: Memory`). When the pod is deleted, the data is gone. That's fine for sharing temp files between containers but not for data you need to keep. We'll fix that in Lesson 5 with PVCs.

### How to generate pod YAML fast

On the exam, don't write YAML from scratch. Generate a scaffold and edit it:

```bash
kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml
```

This gives you a valid pod spec. You add volumes, extra containers, etc. from there.

### Exercises

**1.1** Create a pod called `web` using the `nginx` image. Verify it's running, then check what IP it was assigned.

<details>
<summary>Solution</summary>

```bash
kubectl run web --image=nginx
kubectl get pod web -o wide
```

The `-o wide` column shows the pod IP. You can also use:
```bash
kubectl get pod web -o jsonpath='{.status.podIP}'
```

</details>

**1.2** Create a pod called `vol-pod` using `busybox` that writes the current date to `/data/date.txt` every 5 seconds (use a `while true` loop). Mount an `emptyDir` volume at `/data`. Once it's running, exec into it and read the file.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vol-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c", "while true; do date >> /data/date.txt; sleep 5; done"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

```bash
kubectl apply -f vol-pod.yaml
kubectl exec vol-pod -- cat /data/date.txt
```

</details>

**1.3** Delete the `vol-pod` and recreate it. Is your `date.txt` file still there? Why or why not?

<details>
<summary>Solution</summary>

```bash
kubectl delete pod vol-pod
kubectl apply -f vol-pod.yaml
kubectl exec vol-pod -- cat /data/date.txt
```

The file starts fresh - previous data is gone. `emptyDir` is tied to the pod's lifecycle. When the pod is deleted, the volume is deleted with it. This is why `emptyDir` is only for temporary/shared data, not persistence.

</details>

### Cleanup

```bash
kubectl delete pod web vol-pod
```

---

## Lesson 2: Multi-Container Pods

Now that you understand shared volumes and networking, you can see why putting multiple containers in one pod is useful. Instead of modifying your app to add logging, monitoring, or proxying, you attach a helper container next to it.

### The three patterns

**Sidecar** - enhances the main container. Example: your app writes logs to a file, a sidecar ships them to a logging service. The app doesn't know or care about log shipping.

**Adapter** - transforms output from the main container into a different format. Example: your app writes logs in a custom format, an adapter container reformats them into standard JSON that your monitoring system expects.

**Ambassador** - proxies network traffic for the main container. Example: your app connects to `localhost:5432` for its database, an ambassador container handles the actual connection to the right database cluster. The app code stays simple.

All three patterns work the same way mechanically: multiple entries in `spec.containers`, sharing volumes and/or localhost networking. The pattern name just describes the *role* of the helper container.

### How it looks in YAML

Adding a second container is just another item in the `containers` list. The key thing that ties them together is the shared volume:

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: sidecar
    image: busybox
    command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  volumes:
  - name: logs
    emptyDir: {}
```

Both containers mount the same `logs` volume. Nginx writes to `/var/log/nginx/access.log`, the sidecar reads it. They don't know about each other - they just both happen to use the same files.

When a pod has multiple containers, you need `-c` to target one:

```bash
kubectl logs <pod> -c sidecar
kubectl exec <pod> -c sidecar -- <command>
```

### Exercises

**2.1** Create a pod called `sidecar-pod` with two containers:
- `app`: nginx (serves content on port 80)
- `logger`: busybox that runs `tail -f /var/log/nginx/access.log`

Share nginx's log directory between them using an `emptyDir` volume. Once running, exec into the `app` container and curl `localhost` to generate a log entry, then check the `logger` container's logs to see it.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: logger
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
kubectl apply -f sidecar-pod.yaml
# Generate a log entry
kubectl exec sidecar-pod -c app -- curl -s localhost
# See it in the sidecar's output
kubectl logs sidecar-pod -c logger
```

</details>

**2.2** Create a pod called `adapter-pod` with two containers sharing a volume at `/var/log/app`:
- `app`: busybox that appends `ERROR: disk full` and `WARN: high cpu` lines to `/var/log/app/raw.log` every 3 seconds
- `adapter`: busybox that reads `raw.log`, replaces `ERROR` with `CRITICAL`, and writes the result to `/var/log/app/clean.log` every 5 seconds

Verify by reading `clean.log` - it should contain `CRITICAL` instead of `ERROR`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: adapter-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        echo "ERROR: disk full" >> /var/log/app/raw.log
        echo "WARN: high cpu" >> /var/log/app/raw.log
        sleep 3
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: adapter
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        [ -f /var/log/app/raw.log ] && sed 's/ERROR/CRITICAL/g' /var/log/app/raw.log > /var/log/app/clean.log
        sleep 5
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```

```bash
kubectl apply -f adapter-pod.yaml
# Wait a few seconds, then verify
kubectl exec adapter-pod -c adapter -- cat /var/log/app/clean.log
# Should see CRITICAL instead of ERROR, WARN lines unchanged
```

</details>

### Cleanup

```bash
kubectl delete pod sidecar-pod adapter-pod
```

---

## Lesson 3: Init Containers

You now know how to run multiple containers side-by-side. But what if one container needs to finish *before* the others start? That's what init containers are for.

### Why init containers exist

Regular containers all start at the same time. But often your app can't start until something is ready: a config file needs to be downloaded, a database needs to be reachable, a directory needs specific permissions.

You *could* put retry logic in your app, but that bloats your app image with tooling it shouldn't need. Init containers solve this cleanly: they're separate containers that run first, do their setup work, then exit. Only after all init containers complete successfully does Kubernetes start your regular containers.

### How they work

- Defined in `spec.initContainers` (same schema as regular containers)
- They run **sequentially** - init-1 must exit 0 before init-2 starts
- If any init container fails, the pod restarts it (based on `restartPolicy`)
- Init containers can use completely different images than your app (e.g., a `curl` image to fetch config, even though your app image is `nginx`)
- Init containers share volumes with the regular containers - this is how they pass data to the app

```yaml
spec:
  initContainers:          # Run first, in order
  - name: setup
    image: busybox
    command: ['sh', '-c', 'echo ready > /work/status']
    volumeMounts:
    - name: workdir
      mountPath: /work
  containers:              # Start after all inits complete
  - name: app
    image: nginx
    volumeMounts:
    - name: workdir
      mountPath: /usr/share/nginx/html
  volumes:
  - name: workdir
    emptyDir: {}
```

The init container writes to the shared volume, then exits. Nginx starts and serves the file the init container created. This is the Lesson 1 volume pattern, just with a setup phase in front.

### What you see when watching

```bash
kubectl get pod <name> -w
```

You'll see the pod go through these phases:
- `Init:0/1` - init container hasn't finished yet
- `PodInitializing` - inits done, starting regular containers
- `Running` - everything is up

If the init container is stuck (e.g., waiting for a service that doesn't exist), the pod stays at `Init:0/1` forever. That's by design - it's blocking the app from starting until the dependency is ready.

### Exercises

**3.1** Create a pod called `init-files` where:
- An init container writes `<h1>ready</h1>` to `/work/index.html`
- The main container (nginx) serves that file by mounting the volume at `/usr/share/nginx/html`

Verify by curling the pod or exec'ing in to read the file.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-files
spec:
  initContainers:
  - name: setup
    image: busybox
    command: ['sh', '-c', 'echo "<h1>ready</h1>" > /work/index.html']
    volumeMounts:
    - name: web
      mountPath: /work
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: web
      mountPath: /usr/share/nginx/html
  volumes:
  - name: web
    emptyDir: {}
```

```bash
kubectl apply -f init-files.yaml
kubectl exec init-files -- cat /usr/share/nginx/html/index.html
```

</details>

**3.2** Create a pod called `init-wait` with an init container that waits for a service called `mydb` to be reachable on port 3306 (use `nc -z`). The main container should run nginx.

Apply the pod first - it should be stuck at `Init:0/1`. Then create the service to unblock it:
- Create a deployment called `mydb` with image `nginx`
- Expose it as a service called `mydb` on port 3306 targeting port 80

Watch the pod transition to `Running`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-wait
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nc -z mydb 3306; do echo waiting; sleep 2; done']
  containers:
  - name: app
    image: nginx
```

```bash
# Apply the pod - it stays in Init state
kubectl apply -f init-wait.yaml
kubectl get pod init-wait -w

# In another terminal, create the service
kubectl create deployment mydb --image=nginx
kubectl expose deployment mydb --port=3306 --target-port=80

# Watch the pod transition to Running
```

</details>

**3.3** Create a pod called `multi-init` with **two** init containers and one main container:
- Init 1 (`check-permissions`): creates a directory `/data/app` and writes a file `config.txt` containing `db_host=mysql`
- Init 2 (`check-config`): reads `/data/app/config.txt` and verifies it exists (exit 0 if it does)
- Main (`app`): nginx, mounts the volume at `/etc/app`

This exercises the sequential ordering - init 2 depends on init 1's output.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-init
spec:
  initContainers:
  - name: check-permissions
    image: busybox
    command: ['sh', '-c', 'mkdir -p /data/app && echo "db_host=mysql" > /data/app/config.txt']
    volumeMounts:
    - name: config
      mountPath: /data
  - name: check-config
    image: busybox
    command: ['sh', '-c', 'cat /data/app/config.txt']
    volumeMounts:
    - name: config
      mountPath: /data
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: config
      mountPath: /etc/app
  volumes:
  - name: config
    emptyDir: {}
```

```bash
kubectl apply -f multi-init.yaml
kubectl get pod multi-init -w    # Watch Init:0/2 -> Init:1/2 -> Running
kubectl exec multi-init -- cat /etc/app/app/config.txt
```

</details>

### Cleanup

```bash
kubectl delete pod init-files init-wait multi-init
kubectl delete deployment mydb
kubectl delete service mydb
```

---

## Lesson 4: Jobs and CronJobs

Everything so far has been pods that run forever (nginx, busybox loops). But not all workloads are long-running. Sometimes you need to run something once (a database migration, a calculation, a data export) and have Kubernetes make sure it actually completes.

### Why Jobs exist

If you just run a pod and the process crashes, what happens depends on `restartPolicy`. But there's no tracking of "did it succeed?" or "run it 5 times." A **Job** wraps a pod with completion tracking:

- It creates pods to do work
- It tracks how many have completed successfully
- If a pod fails, the Job creates a new one (up to `backoffLimit`)
- Once the required number of `completions` are done, the Job is finished

The key fields:
- `completions` - how many successful pod runs are needed (default: 1)
- `parallelism` - how many pods can run simultaneously (default: 1)
- `backoffLimit` - how many failures before the Job gives up (default: 6)
- `activeDeadlineSeconds` - hard timeout on the entire Job
- `restartPolicy` - must be `Never` or `OnFailure` (not `Always`, since the point is to finish)

### Creating Jobs fast

Imperatively (fastest for simple jobs):
```bash
kubectl create job myname --image=busybox -- echo "hello"
```

Generate YAML scaffold to edit:
```bash
kubectl create job myname --image=busybox --dry-run=client -o yaml -- echo "hello" > job.yaml
```

Then add `completions`, `parallelism`, etc. to the YAML.

Checking results:
```bash
kubectl get jobs                 # See completion status
kubectl logs job/myname          # Read output without finding pod name
kubectl get pods -l job-name=myname  # See the pods it created
```

### Why CronJobs exist

A CronJob is just "run this Job on a schedule." It creates a new Job at each trigger time. The schedule uses standard cron format:

```
┌─ minute (0-59)
│ ┌─ hour (0-23)
│ │ ┌─ day of month (1-31)
│ │ │ ┌─ month (1-12)
│ │ │ │ ┌─ day of week (0-6, Sun=0)
│ │ │ │ │
* * * * *
```

Common schedules: `*/5 * * * *` (every 5 min), `0 * * * *` (hourly), `0 0 * * *` (daily midnight).

The important CronJob-specific fields:
- `concurrencyPolicy` - what if the previous run hasn't finished? `Allow` (default, overlap OK), `Forbid` (skip this run), `Replace` (kill previous, start new)
- `successfulJobsHistoryLimit` - how many completed Jobs to keep around (default: 3)
- `failedJobsHistoryLimit` - how many failed Jobs to keep (default: 1)
- `startingDeadlineSeconds` - how late a run can start before being skipped

Imperatively:
```bash
kubectl create cronjob myname --image=busybox --schedule="*/5 * * * *" -- echo "hello"
```

There are three layers to debug: CronJob -> Job -> Pod. If something isn't working, check all three.

### Exercises

**4.1** Create a job called `hello-job` using busybox that prints "Hello from Kubernetes job" and exits. Verify it completed and check its logs.

<details>
<summary>Solution</summary>

```bash
kubectl create job hello-job --image=busybox -- echo "Hello from Kubernetes job"
kubectl get job hello-job
kubectl logs job/hello-job
```

</details>

**4.2** Create a job called `pi-job` using the `perl` image that calculates pi to 100 decimal places. The command is: `perl -Mbignum=bpi -wle 'print bpi(100)'`. Check the output.

<details>
<summary>Solution</summary>

```bash
kubectl create job pi-job --image=perl -- perl -Mbignum=bpi -wle 'print bpi(100)'
kubectl get job pi-job -w       # Wait for 1/1 completions
kubectl logs job/pi-job
```

</details>

**4.3** Create a job called `parallel-job` that:
- Uses `busybox`
- Runs the command `echo "Processing batch item"; sleep 2`
- Must complete **5** times
- Runs up to **3** pods in parallel
- Has a `backoffLimit` of 4

Watch it run. How many pods do you see running at once? How many total pods are created?

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 5
  parallelism: 3
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["/bin/sh", "-c", "echo Processing batch item; sleep 2"]
      restartPolicy: Never
```

```bash
kubectl apply -f parallel-job.yaml
kubectl get job parallel-job -w           # Watch completions climb to 5/5
kubectl get pods -l job-name=parallel-job  # See 3 running at a time, 5 total
```

</details>

**4.4** Create a CronJob called `tick` that runs every minute (`*/1 * * * *`), uses busybox, and runs `date`. Wait for it to trigger at least once and check the logs of the job it created.

<details>
<summary>Solution</summary>

```bash
kubectl create cronjob tick --image=busybox --schedule="*/1 * * * *" -- date
kubectl get cronjob tick
kubectl get jobs -w                # Wait for a job to appear
# Once a job appears (e.g., tick-12345678):
kubectl logs job/$(kubectl get jobs -o jsonpath='{.items[0].metadata.name}')
```

</details>

**4.5** Create a CronJob called `reporter` that:
- Runs every 2 minutes
- Uses busybox, runs `echo "Report at $(date)"`
- Keeps only **1** successful job in history and **2** failed
- Uses `concurrencyPolicy: Forbid`

Check with `kubectl describe` that the settings are correct.

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: reporter
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox
            command: ["/bin/sh", "-c", "echo Report at $(date)"]
          restartPolicy: OnFailure
```

```bash
kubectl apply -f reporter.yaml
kubectl describe cronjob reporter | grep -E "Schedule|Concurrency|History"
```

</details>

### Cleanup

```bash
kubectl delete job hello-job pi-job parallel-job
kubectl delete cronjob tick reporter
```

---

## Lesson 5: Persistent Volume Claims

Back in Lesson 1 you saw that `emptyDir` data disappears when the pod is deleted. For real applications - databases, file uploads, anything stateful - you need storage that outlives the pod. That's what PersistentVolumeClaims (PVCs) are for.

### How persistent storage works

There are three objects involved:

1. **PersistentVolume (PV)** - a piece of actual storage in the cluster (a disk, NFS share, cloud volume). Usually created by an admin or dynamically provisioned.
2. **PersistentVolumeClaim (PVC)** - your *request* for storage. You say "I need 1Gi with ReadWriteOnce access" and Kubernetes finds or creates a PV that matches.
3. **Pod** - mounts the PVC as a volume, just like `emptyDir` but persistent.

The PVC is the part you write on the exam. It decouples your app from the underlying storage implementation - your pod just says "give me this PVC" and doesn't care if it's backed by an AWS EBS volume, a local disk, or NFS.

### Access modes

- `ReadWriteOnce` (RWO) - one node can mount it read-write. Most common.
- `ReadOnlyMany` (ROX) - many nodes can mount it read-only.
- `ReadWriteMany` (RWX) - many nodes can mount it read-write. Requires storage that supports it (NFS, etc.).

### PVC YAML

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Mounting a PVC in a pod

Same pattern as `emptyDir` - declare the volume at pod level, mount it in the container. Just swap `emptyDir: {}` for `persistentVolumeClaim`:

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:      # Instead of emptyDir
      claimName: my-claim
```

If you compare this to the `emptyDir` examples from Lesson 1, the container side is identical. The only difference is what backs the volume. This is why we started with `emptyDir` - the mounting pattern is the same, only the persistence changes.

### Exercises

**5.1** Create a PVC called `my-pvc` that requests `50Mi` of storage with `ReadWriteOnce` access. Check that it gets bound.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Mi
```

```bash
kubectl apply -f my-pvc.yaml
kubectl get pvc my-pvc    # STATUS should be Bound (with dynamic provisioning)
```

</details>

**5.2** Create a pod called `pvc-pod` that mounts `my-pvc` at `/data`. Use busybox to write `"persistent data"` to `/data/test.txt`, then sleep. Verify the file exists. Delete the pod, recreate it, and verify the file is **still there** (unlike the `emptyDir` exercise from Lesson 1).

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c", "echo 'persistent data' > /data/test.txt; sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc
```

```bash
kubectl apply -f pvc-pod.yaml
kubectl exec pvc-pod -- cat /data/test.txt       # "persistent data"
kubectl delete pod pvc-pod
kubectl apply -f pvc-pod.yaml
kubectl exec pvc-pod -- cat /data/test.txt       # Still there!
```

</details>

**5.3** Now combine Lesson 2 and Lesson 5. Create a PVC called `shared-pvc` (100Mi, ReadWriteOnce) and a pod called `shared-pvc-pod` with two containers:
- `writer` (busybox): writes `"Written by writer at <date>"` to `/data/shared.txt` every 5 seconds
- `reader` (busybox): reads and prints `/data/shared.txt` every 10 seconds

Both containers mount the PVC at `/data`. Verify by checking the `reader` logs.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
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
  name: shared-pvc-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        echo "Written by writer at $(date)" > /data/shared.txt
        sleep 5
      done
    volumeMounts:
    - name: storage
      mountPath: /data
  - name: reader
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        [ -f /data/shared.txt ] && cat /data/shared.txt
        sleep 10
      done
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: shared-pvc
```

```bash
kubectl apply -f shared-pvc-pod.yaml
kubectl logs shared-pvc-pod -c reader
```

</details>

### Cleanup

```bash
kubectl delete pod pvc-pod shared-pvc-pod
kubectl delete pvc my-pvc shared-pvc
```

---

## Final Challenge

This exercise combines everything from all 5 lessons. No hints - just the task.

Create a pod called `full-stack` that:
1. Has an **init container** that creates a config file at `/config/app.conf` containing `mode=production`
2. Has a **main container** (nginx) that mounts the config at `/etc/app`
3. Has a **sidecar container** (busybox) that watches `/etc/app/app.conf` and prints its contents every 10 seconds
4. The config volume should use a **PVC** called `config-pvc` (50Mi, ReadWriteOnce) so the config survives pod restarts

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: config-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: full-stack
spec:
  initContainers:
  - name: config-init
    image: busybox
    command: ['sh', '-c', 'echo "mode=production" > /config/app.conf']
    volumeMounts:
    - name: config
      mountPath: /config
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: config
      mountPath: /etc/app
  - name: config-watcher
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        echo "--- Config check at $(date) ---"
        cat /etc/app/app.conf
        sleep 10
      done
    volumeMounts:
    - name: config
      mountPath: /etc/app
  volumes:
  - name: config
    persistentVolumeClaim:
      claimName: config-pvc
```

```bash
kubectl apply -f full-stack.yaml
kubectl get pod full-stack -w              # Watch Init -> Running
kubectl exec full-stack -c web -- cat /etc/app/app.conf
kubectl logs full-stack -c config-watcher
```

</details>

### Cleanup

```bash
kubectl delete pod full-stack
kubectl delete pvc config-pvc
```

---

## Quick Reference

### Imperative shortcuts

```bash
kubectl run <pod> --image=<img> --dry-run=client -o yaml > pod.yaml
kubectl create job <name> --image=<img> -- <cmd>
kubectl create cronjob <name> --image=<img> --schedule="<cron>" -- <cmd>
# Add --dry-run=client -o yaml to any of these to get editable YAML
```

### Volume patterns

```yaml
# Temporary (dies with pod)          # Persistent (survives pod deletion)
volumes:                              volumes:
- name: data                         - name: data
  emptyDir: {}                         persistentVolumeClaim:
                                         claimName: my-pvc
```

### Cron schedule

| Expression | Meaning |
|---|---|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Every hour |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday |

### What goes where

| Thing | YAML path |
|---|---|
| Regular containers | `spec.containers[]` |
| Init containers | `spec.initContainers[]` |
| Volumes (pod-level) | `spec.volumes[]` |
| Volume mounts (container-level) | `spec.containers[].volumeMounts[]` |
| Job completions | `spec.completions` |
| Job parallelism | `spec.parallelism` |
| CronJob schedule | `spec.schedule` |
| CronJob concurrency | `spec.concurrencyPolicy` |
| PVC access mode | `spec.accessModes[]` |
| PVC storage request | `spec.resources.requests.storage` |

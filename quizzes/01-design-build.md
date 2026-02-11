# Quiz: Domain 1 — Application Design & Build

## Q1: What kubectl command creates a pod YAML template without actually creating the pod?

<details>
<summary>Answer</summary>

```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
```

</details>

## Q2: What are the three multi-container pod patterns? Give a one-sentence use case for each.

<details>
<summary>Answer</summary>

1. **Sidecar** — enhances the main container (e.g., log shipper that tails log files)
2. **Ambassador** — proxies network traffic (e.g., localhost proxy to a database cluster)
3. **Adapter** — transforms output (e.g., reformats logs from custom format to JSON)

</details>

## Q3: What's wrong with this YAML?

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-pod
spec:
  containers:
  - name: init
    image: busybox
    command: ['sh', '-c', 'echo ready > /work/status']
  - name: app
    image: nginx
```

<details>
<summary>Answer</summary>

The "init" container is listed under `containers` instead of `initContainers`. Init containers run first and must complete before regular containers start. Fix:

```yaml
spec:
  initContainers:
  - name: init
    image: busybox
    command: ['sh', '-c', 'echo ready > /work/status']
  containers:
  - name: app
    image: nginx
```

</details>

## Q4: How do you view logs from a specific container in a multi-container pod?

<details>
<summary>Answer</summary>

```bash
kubectl logs <pod-name> -c <container-name>
```

</details>

## Q5: What's the difference between `restartPolicy: Never` and `restartPolicy: OnFailure` for Jobs?

<details>
<summary>Answer</summary>

- **Never**: If the container fails, the Job creates a **new pod** (old pod stays for log inspection)
- **OnFailure**: If the container fails, kubelet **restarts the container in the same pod**

Both count toward `backoffLimit`. Use `Never` if you need logs from failed attempts.

</details>

## Q6: Write a one-liner to create a CronJob that runs every day at midnight.

<details>
<summary>Answer</summary>

```bash
kubectl create cronjob daily-task --image=busybox --schedule="0 0 * * *" -- echo "daily task"
```

</details>

## Q7: What happens to data in an `emptyDir` volume when the pod is deleted?

<details>
<summary>Answer</summary>

The data is **deleted**. `emptyDir` lives and dies with the pod. For persistent data, use a PersistentVolumeClaim.

</details>

## Q8: What are the three PVC access modes? Which is most common?

<details>
<summary>Answer</summary>

1. **ReadWriteOnce (RWO)** — single node read-write ← most common
2. **ReadOnlyMany (ROX)** — multiple nodes read-only
3. **ReadWriteMany (RWX)** — multiple nodes read-write (requires NFS or similar)

</details>

## Q9: What's the `concurrencyPolicy` field on a CronJob, and what are the options?

<details>
<summary>Answer</summary>

Controls what happens if the previous job hasn't finished when the next one triggers:
- **Allow** (default) — run concurrently
- **Forbid** — skip the new run
- **Replace** — kill the old job, start the new one

</details>

## Q10: Create a Job that runs 5 completions, 3 at a time, with a one-liner.

<details>
<summary>Answer</summary>

Can't do the full thing imperatively — generate YAML:

```bash
kubectl create job batch --image=busybox --dry-run=client -o yaml -- echo "work" > job.yaml
```

Then edit to add `completions: 5` and `parallelism: 3`.

</details>

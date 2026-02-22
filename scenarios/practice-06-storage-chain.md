# Practice Scenario 06 — Storage Chain

**Domain:** Application Design & Build / Storage
**Realistic difficulty:** ⭐⭐⭐
**Time target:** 10 minutes

---

## Setup

No pre-setup needed — you build everything from scratch.

---

## Your Tasks

Build a full storage chain in namespace `storage-lab`:

1. Create the namespace `storage-lab`.

2. Create a **PersistentVolume** named `data-pv`:
   - Storage: `1Gi`
   - Access mode: `ReadWriteOnce`
   - Type: `hostPath` at `/tmp/storage-lab`
   - Reclaim policy: `Retain`

3. Create a **PersistentVolumeClaim** named `data-pvc` in `storage-lab`:
   - Requests `1Gi`, `ReadWriteOnce`
   - Should bind to `data-pv`

4. Create a **Pod** named `writer` in `storage-lab`:
   - Image: `busybox`
   - Mounts the PVC at `/data`
   - Runs this command: `while true; do echo "$(date): hello" >> /data/log.txt; sleep 10; done`

5. Create a second **Pod** named `reader` in `storage-lab`:
   - Image: `busybox`
   - Mounts the **same PVC** at `/data` (ReadOnly is fine)
   - Runs: `tail -f /data/log.txt`

6. Verify `reader` is printing the entries being written by `writer`.

---

## Verification

```bash
kubectl get pv data-pv                             # STATUS: Bound
kubectl get pvc data-pvc -n storage-lab            # STATUS: Bound
kubectl get pods -n storage-lab                    # both Running
kubectl logs reader -n storage-lab                 # should show timestamped lines
kubectl exec -n storage-lab writer -- cat /data/log.txt   # same content
```

---

<details>
<summary>💡 Hints</summary>

- PV is cluster-scoped (no namespace), PVC is namespaced
- Both pods can use the same PVC at the same time with `ReadWriteOnce` on the same node
- The `reader` pod doesn't need `readOnly: true` but it's good practice

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create namespace storage-lab

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /tmp/storage-lab
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: storage-lab
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: storage-lab
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh","-c","while true; do echo \"\$(date): hello\" >> /data/log.txt; sleep 10; done"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
---
apiVersion: v1
kind: Pod
metadata:
  name: reader
  namespace: storage-lab
spec:
  containers:
  - name: reader
    image: busybox
    command: ["/bin/sh","-c","tail -f /data/log.txt"]
    volumeMounts:
    - name: data
      mountPath: /data
      readOnly: true
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
EOF
```

</details>

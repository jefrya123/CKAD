# Practice Q12 — Storage: PV, PVC, Pod Volume

**Mirrors KillerShell CKAD Question 12**
**Time target:** 8 minutes

---

## Setup

```bash
kubectl create namespace earth 2>/dev/null || true
# Ensure /tmp/q12-data exists on the node
mkdir -p /tmp/q12-data 2>/dev/null || true
```

---

## Your Task

Create the following resources from scratch:

1. **PersistentVolume** named `earth-pv`:
   - Capacity: `2Gi`
   - Access mode: `ReadWriteOnce`
   - hostPath: `/tmp/q12-data`
   - Reclaim policy: `Retain`
   - No StorageClass (set `storageClassName: ""`)

2. **PersistentVolumeClaim** named `earth-pvc` in namespace `earth`:
   - Requests `2Gi`, `ReadWriteOnce`
   - Must bind to `earth-pv` (set `storageClassName: ""`)

3. **Pod** named `earth-pod` in namespace `earth`:
   - Image: `busybox`
   - Mounts the PVC at `/mnt/earth`
   - Command: `sh -c "echo 'written by earth-pod' > /mnt/earth/data.txt && sleep 3600"`

---

## Verification

```bash
kubectl get pv earth-pv                      # STATUS: Bound
kubectl get pvc earth-pvc -n earth           # STATUS: Bound
kubectl get pod earth-pod -n earth           # Running
kubectl exec earth-pod -n earth -- cat /mnt/earth/data.txt
```

---

<details>
<summary>💡 Hint</summary>

- PV is cluster-scoped — no namespace in the manifest
- Both PV and PVC must have `storageClassName: ""` to avoid the default StorageClass grabbing it
- The PVC won't bind if storage or accessModes don't match the PV exactly

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: earth-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /tmp/q12-data
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: earth-pvc
  namespace: earth
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: ""
---
apiVersion: v1
kind: Pod
metadata:
  name: earth-pod
  namespace: earth
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo 'written by earth-pod' > /mnt/earth/data.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /mnt/earth
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: earth-pvc
EOF
```

</details>

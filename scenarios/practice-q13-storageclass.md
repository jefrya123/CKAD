# Practice Q13 — StorageClass + PVC

**Mirrors KillerShell CKAD Question 13**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace moon 2>/dev/null || true
```

---

## Your Task

1. Create a **StorageClass** named `moon-sc`:
   - Provisioner: `rancher.io/local-path`
   - Reclaim policy: `Delete`
   - Volume binding mode: `WaitForFirstConsumer`

2. Create a **PersistentVolumeClaim** named `moon-pvc` in namespace `moon`:
   - Uses StorageClass `moon-sc`
   - Requests `500Mi`, `ReadWriteOnce`

3. Create a **Pod** named `moon-pod` in namespace `moon` that uses `moon-pvc` mounted at `/data` — this will cause the PVC to bind (because of `WaitForFirstConsumer`)

---

## Verification

```bash
kubectl get sc moon-sc
kubectl get pvc moon-pvc -n moon      # Pending until pod is created, then Bound
kubectl get pod moon-pod -n moon      # Running
kubectl exec moon-pod -n moon -- df -h /data
```

---

<details>
<summary>💡 Hint</summary>

- `WaitForFirstConsumer` means the PVC stays `Pending` until a pod requests it — that's correct behaviour
- Once the pod is created and scheduled, the PVC binds
- The provisioner name must be exact — `rancher.io/local-path` is common in kind clusters

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: moon-sc
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: moon-pvc
  namespace: moon
spec:
  storageClassName: moon-sc
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: moon-pod
  namespace: moon
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: moon-pvc
EOF
```

</details>

# Scenario 05: Pod with PVC

**Domain:** Application Design & Build
**Time Limit:** 3 minutes

## Task

1. Create a PersistentVolumeClaim named `app-storage` requesting `200Mi` with `ReadWriteOnce` access
2. Create a pod named `storage-pod` using `nginx` that mounts the PVC at `/data`

---

<details>
<summary>💡 Hint</summary>

Two resources: PVC first, then pod with `volumes[].persistentVolumeClaim.claimName`.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-storage
```

```bash
kubectl apply -f storage.yaml
kubectl get pvc app-storage
kubectl exec storage-pod -- df -h /data
```

</details>

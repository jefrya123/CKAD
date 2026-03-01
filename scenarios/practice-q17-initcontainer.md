# Practice Q17 — InitContainer

**Mirrors KillerShell CKAD Question 17**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace moon 2>/dev/null || true
```

---

## Your Task

Create a Pod named `moon-init-pod` in namespace `moon`:

- **InitContainer** named `init-data`:
  - Image: `busybox`
  - Writes the string `CKAD exam ready` to `/init-vol/init.txt`
  - Mounts a shared volume at `/init-vol`

- **Main container** named `web`:
  - Image: `nginx`
  - Mounts the same shared volume at `/usr/share/nginx/html`
  - (So nginx serves the file written by the initContainer)

- Shared volume: `emptyDir` named `shared-data`

After the pod is Running, curling localhost inside the container should return `CKAD exam ready`.

---

## Verification

```bash
kubectl get pod moon-init-pod -n moon
# Watch: Init:0/1 -> PodInitializing -> Running

kubectl exec moon-init-pod -n moon -- cat /usr/share/nginx/html/init.txt
# CKAD exam ready

kubectl exec moon-init-pod -n moon -- curl -s localhost/init.txt
# CKAD exam ready
```

---

<details>
<summary>💡 Hint</summary>

- `initContainers:` is at the same level as `containers:` in the pod spec
- The initContainer must have a `volumeMount` — this is where most people forget
- The main container mounts the same volume name at a different path

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl apply -n moon -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: moon-init-pod
  namespace: moon
spec:
  initContainers:
  - name: init-data
    image: busybox
    command: ["sh", "-c", "echo 'CKAD exam ready' > /init-vol/init.txt"]
    volumeMounts:
    - name: shared-data
      mountPath: /init-vol
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: shared-data
    emptyDir: {}
EOF

kubectl get pod moon-init-pod -n moon -w
```

</details>

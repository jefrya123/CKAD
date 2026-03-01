# Scenario 02: Init Container Setup

**Domain:** Application Design & Build
**Time Limit:** 3 minutes

## Task

Create a pod named `app-init` with:

1. An init container named `setup` using `busybox` that writes `<h1>Hello CKAD</h1>` to `/work/index.html`
2. A main container named `web` using `nginx` that mounts the volume at `/usr/share/nginx/html`
3. Use an `emptyDir` volume named `content`

---

<details>
<summary>💡 Hint</summary>

Init containers go under `spec.initContainers`. They share volumes with regular containers.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-init
spec:
  initContainers:
  - name: setup
    image: busybox
    command: ['sh', '-c', 'echo "<h1>Hello CKAD</h1>" > /work/index.html']
    volumeMounts:
    - name: content
      mountPath: /work
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: content
      mountPath: /usr/share/nginx/html
  volumes:
  - name: content
    emptyDir: {}
```

```bash
kubectl apply -f app-init.yaml
kubectl exec app-init -- cat /usr/share/nginx/html/index.html
```

</details>

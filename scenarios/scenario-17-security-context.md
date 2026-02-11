# Scenario 17: SecurityContext

**Domain:** Config & Security
**Time Limit:** 3 minutes

## Task

Create a pod named `secure-app` with:
- Image: `busybox`, command: `sleep 3600`
- Run as user ID 1000, group ID 3000
- Read-only root filesystem
- No privilege escalation
- Drop all capabilities, add only `NET_BIND_SERVICE`

---

<details>
<summary>💡 Hint</summary>

`runAsUser`/`runAsGroup` at pod level. `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, and `capabilities` at container level.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

```bash
kubectl apply -f secure-app.yaml
kubectl exec secure-app -- id           # uid=1000 gid=3000
kubectl exec secure-app -- touch /test  # Read-only file system
```

</details>

# Scenario 01: Multi-Container Pod

**Domain:** Application Design & Build
**Time Limit:** 3 minutes

## Task

Create a pod named `web-logger` in the `default` namespace with:

1. A container named `nginx` using image `nginx` that serves on port 80
2. A sidecar container named `logger` using image `busybox` that runs: `tail -f /var/log/nginx/access.log`
3. Both containers share an `emptyDir` volume mounted at `/var/log/nginx`

---

<details>
<summary>💡 Hint</summary>

Start with `kubectl run web-logger --image=nginx --dry-run=client -o yaml > pod.yaml`, then add the second container and shared volume.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-logger
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
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
kubectl apply -f pod.yaml
kubectl exec web-logger -c nginx -- curl -s localhost
kubectl logs web-logger -c logger
```

</details>

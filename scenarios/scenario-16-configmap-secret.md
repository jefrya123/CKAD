# Scenario 16: ConfigMap + Secret in Pod

**Domain:** Config & Security
**Time Limit:** 4 minutes

## Task

1. Create a ConfigMap `app-config` with `APP_ENV=production` and `LOG_LEVEL=info`
2. Create a Secret `db-creds` with `username=admin` and `password=s3cret`
3. Create a pod `config-pod` using `busybox` (command: `sleep 3600`) that:
   - Loads all ConfigMap keys as environment variables using `envFrom`
   - Loads `password` from the Secret as env var `DB_PASS`
   - Mounts the Secret as a volume at `/etc/secrets`

---

<details>
<summary>💡 Hint</summary>

Use `envFrom` for bulk ConfigMap injection. Use `env[].valueFrom.secretKeyRef` for single secret key. Use `volumes[].secret` for volume mount.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=LOG_LEVEL=info
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=s3cret
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-config
    env:
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: password
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: db-creds
```

```bash
kubectl apply -f config-pod.yaml
kubectl exec config-pod -- env | grep -E "APP_ENV|LOG_LEVEL|DB_PASS"
kubectl exec config-pod -- cat /etc/secrets/password
```

</details>

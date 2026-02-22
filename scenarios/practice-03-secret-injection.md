# Practice Scenario 03 — Secret Injection

**Domain:** Config & Security
**Realistic difficulty:** ⭐⭐
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace moon

kubectl apply -n moon -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx
EOF
```

---

## Your Tasks

1. Create a Secret named `db-creds` in namespace `moon` with these values:
   - `username=admin`
   - `password=S3cur3P@ss!`

2. Update the `webapp` deployment to:
   - Mount the secret as **environment variables** (`DB_USER` from `username`, `DB_PASS` from `password`)
   - Mount the secret as a **volume** at `/etc/db-creds` (each key becomes a file)

3. Verify both injection methods work inside the running pod.

---

## Verification

```bash
# Env vars
kubectl exec -n moon deploy/webapp -- env | grep DB_

# Volume mount
kubectl exec -n moon deploy/webapp -- ls /etc/db-creds
kubectl exec -n moon deploy/webapp -- cat /etc/db-creds/username
kubectl exec -n moon deploy/webapp -- cat /etc/db-creds/password
```

---

<details>
<summary>💡 Hints</summary>

- `kubectl create secret generic db-creds --from-literal=...`
- In the deployment, use both `env[].valueFrom.secretKeyRef` AND `volumes[]/volumeMounts[]`
- Use `kubectl edit deploy/webapp -n moon` or patch with a YAML file

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Create the secret
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='S3cur3P@ss!' \
  -n moon

# 2. Patch the deployment
kubectl patch deployment webapp -n moon --patch '
spec:
  template:
    spec:
      containers:
      - name: webapp
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-creds
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-creds
              key: password
        volumeMounts:
        - name: db-secret-vol
          mountPath: /etc/db-creds
          readOnly: true
      volumes:
      - name: db-secret-vol
        secret:
          secretName: db-creds
'
```

</details>

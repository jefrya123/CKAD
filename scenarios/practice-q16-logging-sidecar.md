# Practice Q16 — Logging Sidecar

**Mirrors KillerShell CKAD Question 16**
**Time target:** 7 minutes

---

## Setup

```bash
kubectl create namespace moon 2>/dev/null || true

kubectl apply -n moon -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon-logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon-logger
  template:
    metadata:
      labels:
        app: moon-logger
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "while true; do echo \"\$(date): request processed\" >> /var/log/app/app.log; sleep 3; done"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: logs
        emptyDir: {}
EOF
```

---

## Your Task

The `moon-logger` deployment in namespace `moon` writes logs to `/var/log/app/app.log` inside the container but there's no way to read them with `kubectl logs`.

Add a **sidecar container** named `log-reader` to the deployment that:
- Image: `busybox`
- Reads the same log file with: `tail -f /var/log/app/app.log`
- Shares the same `logs` volume as the `app` container

After updating, you should be able to stream logs with:
`kubectl logs -n moon deploy/moon-logger -c log-reader -f`

---

## Verification

```bash
kubectl get pods -n moon -l app=moon-logger
kubectl logs -n moon deploy/moon-logger -c log-reader --tail=5
# Should show timestamped "request processed" lines
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl edit deploy moon-logger -n moon`
- Add a second container under `spec.template.spec.containers[]`
- It must mount the same `logs` volume at the same path `/var/log/app`
- Do NOT add a new volume — reuse the existing `logs` emptyDir

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl patch deployment moon-logger -n moon --patch '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "app",
            "image": "busybox",
            "command": ["sh", "-c", "while true; do echo \"$(date): request processed\" >> /var/log/app/app.log; sleep 3; done"],
            "volumeMounts": [{"name": "logs", "mountPath": "/var/log/app"}]
          },
          {
            "name": "log-reader",
            "image": "busybox",
            "command": ["sh", "-c", "tail -f /var/log/app/app.log"],
            "volumeMounts": [{"name": "logs", "mountPath": "/var/log/app"}]
          }
        ]
      }
    }
  }
}'

# Verify
kubectl logs -n moon deploy/moon-logger -c log-reader --tail=5
```

</details>

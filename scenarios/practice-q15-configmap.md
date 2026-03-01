# Practice Q15 — ConfigMap + Volume

**Mirrors KillerShell CKAD Question 15**
**Time target:** 7 minutes

---

## Setup

```bash
kubectl create namespace moon 2>/dev/null || true

kubectl apply -n moon -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon-web
  template:
    metadata:
      labels:
        app: moon-web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
```

---

## Your Task

1. Create a ConfigMap named `moon-config` in namespace `moon` with:
   - `index.html` key containing the value: `Moon Mission Control`
   - `env` key containing the value: `production`

2. Update the `moon-web` deployment to:
   - Mount `index.html` from the ConfigMap as a volume at `/usr/share/nginx/html/index.html` (single file, not whole directory)
   - Inject `env` as an environment variable named `APP_ENV`

3. Confirm nginx serves `Moon Mission Control` when curled

---

## Verification

```bash
kubectl exec -n moon deploy/moon-web -- curl -s localhost
# Should return: Moon Mission Control
kubectl exec -n moon deploy/moon-web -- env | grep APP_ENV
# Should return: APP_ENV=production
```

---

<details>
<summary>💡 Hint</summary>

- To mount a single file from a ConfigMap use `subPath`: set `mountPath` to the full file path and add `subPath: index.html`
- Without `subPath`, mounting at `/usr/share/nginx/html` replaces the whole directory
- Use `kubectl edit deploy moon-web -n moon` to update

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create ConfigMap
kubectl create configmap moon-config \
  --from-literal=index.html="Moon Mission Control" \
  --from-literal=env=production \
  -n moon

# Patch deployment
kubectl patch deployment moon-web -n moon --patch '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "env": [{
            "name": "APP_ENV",
            "valueFrom": {
              "configMapKeyRef": {
                "name": "moon-config",
                "key": "env"
              }
            }
          }],
          "volumeMounts": [{
            "name": "config-vol",
            "mountPath": "/usr/share/nginx/html/index.html",
            "subPath": "index.html"
          }]
        }],
        "volumes": [{
          "name": "config-vol",
          "configMap": {
            "name": "moon-config"
          }
        }]
      }
    }
  }
}'
```

</details>

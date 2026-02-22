# Practice Q04 — Helm Management

**Mirrors KillerShell CKAD Question 4**
**Time target:** 6 minutes

---

## Setup

```bash
kubectl create namespace mercury 2>/dev/null || true

# Install helm if not present
# https://helm.sh/docs/intro/install/

# Add a repo and install two test releases to work with
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update

# Install the releases you'll manage
helm install internal-nginx bitnami/nginx --version 13.2.0 -n mercury --set replicaCount=1
helm install external-nginx bitnami/nginx --version 13.2.0 -n mercury --set replicaCount=1
```

---

## Your Task

In namespace `mercury`:

1. List all Helm releases and save the output to `/tmp/q04-releases.txt`
2. Uninstall the release named `internal-nginx`
3. Upgrade `external-nginx` to use `replicaCount=2`
4. Confirm `external-nginx` is running with 2 replicas

---

## Verification

```bash
helm list -n mercury
kubectl get pods -n mercury
cat /tmp/q04-releases.txt
```

---

<details>
<summary>💡 Hint</summary>

- `helm list -n <namespace>` lists releases
- `helm uninstall <name> -n <namespace>` removes a release
- `helm upgrade <name> <chart> --set key=val -n <namespace>` upgrades
- Use `--reuse-values` to keep existing config and only override what you change

</details>

<details>
<summary>✅ Solution</summary>

```bash
# 1. Save list
helm list -n mercury > /tmp/q04-releases.txt

# 2. Uninstall internal-nginx
helm uninstall internal-nginx -n mercury

# 3. Upgrade external-nginx to 2 replicas
helm upgrade external-nginx bitnami/nginx -n mercury --reuse-values --set replicaCount=2

# 4. Verify
kubectl get pods -n mercury
helm list -n mercury
```

</details>

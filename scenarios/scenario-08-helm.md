# Scenario 08: Helm Install & Upgrade

**Domain:** Application Deployment
**Time Limit:** 4 minutes

## Task

1. Add the bitnami repo: `https://charts.bitnami.com/bitnami`
2. Install nginx chart with release name `my-web` and `replicaCount=2`
3. Upgrade the release to `replicaCount=4`
4. View the release history
5. Rollback to the first revision

---

<details>
<summary>💡 Hint</summary>

`helm repo add`, `helm install --set`, `helm upgrade --set`, `helm history`, `helm rollback`.

</details>

<details>
<summary>✅ Solution</summary>

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-web bitnami/nginx --set replicaCount=2
helm upgrade my-web bitnami/nginx --set replicaCount=4
helm history my-web
helm rollback my-web 1
helm list
```

</details>

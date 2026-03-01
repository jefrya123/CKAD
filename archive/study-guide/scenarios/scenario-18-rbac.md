# Scenario 18: ServiceAccount with RBAC

**Domain:** Config & Security
**Time Limit:** 5 minutes

## Task

1. Create namespace `dev`
2. Create a ServiceAccount `app-sa` in namespace `dev`
3. Create a Role `pod-manager` in `dev` that allows `get`, `list`, `create`, `delete` on `pods`
4. Create a RoleBinding `app-sa-binding` binding the role to the service account
5. Verify: `kubectl auth can-i create pods -n dev --as=system:serviceaccount:dev:app-sa` returns yes

---

<details>
<summary>💡 Hint</summary>

Use imperative commands: `kubectl create role`, `kubectl create rolebinding`.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create ns dev
kubectl create sa app-sa -n dev
kubectl create role pod-manager -n dev --verb=get,list,create,delete --resource=pods
kubectl create rolebinding app-sa-binding -n dev --role=pod-manager --serviceaccount=dev:app-sa
kubectl auth can-i create pods -n dev --as=system:serviceaccount:dev:app-sa
# yes
kubectl auth can-i delete deployments -n dev --as=system:serviceaccount:dev:app-sa
# no
```

</details>

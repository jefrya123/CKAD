# RBAC Exercises

## Quick Reference - Imperative Commands

```bash
# Create ServiceAccount
kubectl create serviceaccount mysa

# Create Role
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Create RoleBinding
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=default:mysa

# Create ClusterRole
kubectl create clusterrole node-reader --verb=get,list --resource=nodes

# Create ClusterRoleBinding
kubectl create clusterrolebinding node-reader-binding \
  --clusterrole=node-reader \
  --user=jane
```

## Exercise 1: Create a Read-Only User

**Task:** Create a ServiceAccount that can only read pods and services in the `dev` namespace.

```bash
# Create namespace
kubectl create namespace dev

# Create ServiceAccount
kubectl create serviceaccount dev-reader -n dev

# Create Role
kubectl create role dev-reader-role \
  --verb=get,list,watch \
  --resource=pods,services \
  -n dev

# Create RoleBinding
kubectl create rolebinding dev-reader-binding \
  --role=dev-reader-role \
  --serviceaccount=dev:dev-reader \
  -n dev

# Test permissions
kubectl auth can-i get pods -n dev --as=system:serviceaccount:dev:dev-reader
kubectl auth can-i delete pods -n dev --as=system:serviceaccount:dev:dev-reader
```

## Exercise 2: Cluster Admin for Specific User

**Task:** Give user `alice` full admin access to a specific namespace `alice-ns`.

```bash
kubectl create namespace alice-ns

# Use built-in admin ClusterRole with RoleBinding (scoped to namespace)
kubectl create rolebinding alice-admin \
  --clusterrole=admin \
  --user=alice \
  -n alice-ns

# Verify
kubectl auth can-i '*' '*' -n alice-ns --as=alice
kubectl auth can-i '*' '*' -n default --as=alice  # Should be no
```

## Exercise 3: Debug RBAC Issues

```bash
# Check what a user can do
kubectl auth can-i --list --as=system:serviceaccount:default:mysa

# Check specific permission
kubectl auth can-i create deployments --as=jane

# View all roles in namespace
kubectl get roles,rolebindings -n <namespace>

# View cluster-wide
kubectl get clusterroles,clusterrolebindings
```

## Common Verbs

| Verb | Description |
|------|-------------|
| get | Read a specific resource |
| list | List all resources |
| watch | Watch for changes |
| create | Create new resources |
| update | Modify existing resources |
| patch | Partially modify resources |
| delete | Delete resources |
| deletecollection | Delete multiple resources |

## Common Resources

- pods, pods/log, pods/exec
- deployments, replicasets, daemonsets
- services, endpoints
- configmaps, secrets
- persistentvolumeclaims
- nodes (cluster-scoped)
- namespaces (cluster-scoped)

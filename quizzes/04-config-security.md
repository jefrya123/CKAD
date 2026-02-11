# Quiz: Domain 4 — Config & Security

## Q1: What's the difference between `env` and `envFrom` when using ConfigMaps?

<details>
<summary>Answer</summary>

- **`env`** — load specific keys: `env[].valueFrom.configMapKeyRef`
- **`envFrom`** — load ALL keys from a ConfigMap as env vars: `envFrom[].configMapRef`

</details>

## Q2: How do you decode a base64-encoded Secret value?

<details>
<summary>Answer</summary>

```bash
kubectl get secret mysecret -o jsonpath='{.data.password}' | base64 -d
```

</details>

## Q3: What's the difference between `runAsUser` at pod level vs container level?

<details>
<summary>Answer</summary>

- **Pod level** (`spec.securityContext.runAsUser`) — applies to all containers as default
- **Container level** (`spec.containers[].securityContext.runAsUser`) — overrides pod level for that container

Container level takes precedence.

</details>

## Q4: What does `readOnlyRootFilesystem: true` do?

<details>
<summary>Answer</summary>

Makes the container's root filesystem read-only. The container can't write to any path except explicitly mounted volumes. Good security practice — prevents attackers from writing malicious files.

</details>

## Q5: Create a ServiceAccount and disable token auto-mounting with imperative commands.

<details>
<summary>Answer</summary>

```bash
kubectl create sa app-sa
```

Then in the pod spec:
```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

Can't fully disable auto-mount imperatively — need YAML for the pod.

</details>

## Q6: What's the difference between a Role and a ClusterRole?

<details>
<summary>Answer</summary>

- **Role** — namespace-scoped permissions (pods, services, configmaps within a namespace)
- **ClusterRole** — cluster-wide permissions (nodes, PVs, namespaces) OR can be bound to a namespace via RoleBinding

</details>

## Q7: What does `kubectl auth can-i` do? Give an example.

<details>
<summary>Answer</summary>

Checks if a user/serviceaccount has permission to perform an action:

```bash
kubectl auth can-i create pods                                            # for yourself
kubectl auth can-i delete pods -n dev --as=system:serviceaccount:dev:mysa  # as another identity
kubectl auth can-i --list                                                  # list all permissions
```

</details>

## Q8: What's the difference between ResourceQuota and LimitRange?

<details>
<summary>Answer</summary>

- **ResourceQuota** — limits **total** resources in a namespace (e.g., max 10 pods, max 4 CPU total)
- **LimitRange** — sets **default/min/max** per container or pod (e.g., each container defaults to 100m CPU)

They work together: LimitRange sets per-pod defaults, ResourceQuota caps the namespace total.

</details>

## Q9: What CPU unit is `500m`? What about `1`?

<details>
<summary>Answer</summary>

- `500m` = 500 millicores = 0.5 CPU cores
- `1` = 1 full CPU core = 1000m

</details>

## Q10: What happens when a container exceeds its memory limit?

<details>
<summary>Answer</summary>

The container is **OOMKilled** (Out Of Memory) and restarted according to `restartPolicy`. Memory limits are hard — the kernel kills the process.

CPU limits are different — the container is **throttled** but not killed.

</details>

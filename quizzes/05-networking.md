# Quiz: Domain 5 — Services & Networking

## Q1: What are the four Service types? When do you use each?

<details>
<summary>Answer</summary>

| Type | Use Case |
|---|---|
| **ClusterIP** | Internal pod-to-pod communication (default) |
| **NodePort** | External access via `<NodeIP>:<30000-32767>` |
| **LoadBalancer** | Production external access via cloud LB |
| **ExternalName** | CNAME alias to external service |

</details>

## Q2: What's the DNS format for a service?

<details>
<summary>Answer</summary>

```
<service>.<namespace>.svc.cluster.local
```

Short forms within same namespace: `<service>` or `<service>.<namespace>`

</details>

## Q3: What's the difference between `pathType: Prefix` and `pathType: Exact` in an Ingress?

<details>
<summary>Answer</summary>

- **Prefix** — matches the path and anything under it (`/api` matches `/api`, `/api/users`, `/api/v2`)
- **Exact** — matches only the exact path (`/api` matches only `/api`, not `/api/users`)

</details>

## Q4: By default, can all pods communicate with each other?

<details>
<summary>Answer</summary>

**Yes.** Without any NetworkPolicy, all ingress and egress is allowed. A NetworkPolicy only affects pods it selects, and only the policy types it declares.

</details>

## Q5: Write a NetworkPolicy that denies all ingress AND egress for all pods in a namespace.

<details>
<summary>Answer</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

</details>

## Q6: What common problem occurs when you create an egress NetworkPolicy but forget DNS?

<details>
<summary>Answer</summary>

Pods can't resolve any service names because DNS (port 53 UDP) is blocked. Always include a DNS egress rule:

```yaml
egress:
- ports:
  - port: 53
    protocol: UDP
```

</details>

## Q7: What's a headless service and when would you use it?

<details>
<summary>Answer</summary>

A service with `clusterIP: None`. DNS returns the **individual pod IPs** instead of a single virtual IP. Used with StatefulSets where clients need to connect to specific pods (e.g., database replicas).

</details>

## Q8: In a NetworkPolicy, what's the difference between two items in the `from` array vs two selectors in one item?

<details>
<summary>Answer</summary>

```yaml
# OR logic: from pods with app=frontend OR from monitoring namespace
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
  - namespaceSelector:
      matchLabels:
        name: monitoring

# AND logic: from pods with app=web IN the frontend namespace
ingress:
- from:
  - podSelector:
      matchLabels:
        app: web
    namespaceSelector:
      matchLabels:
        name: frontend
```

Separate list items = OR. Same item = AND.

</details>

## Q9: How do you test if a service is reachable from within the cluster?

<details>
<summary>Answer</summary>

```bash
kubectl run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://my-service
# or
kubectl run tmp --image=busybox --rm -it --restart=Never -- nc -zv my-service 80
```

</details>

## Q10: What does `kubectl get endpoints <service>` tell you?

<details>
<summary>Answer</summary>

Shows the actual pod IPs and ports backing the service. If it's empty, the service selector doesn't match any running pods — most common cause of "service doesn't work."

</details>

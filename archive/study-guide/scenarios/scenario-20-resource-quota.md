# Scenario 20: ResourceQuota

**Domain:** Config & Security
**Time Limit:** 4 minutes

## Task

1. Create namespace `quota-ns`
2. Create a ResourceQuota `compute-quota` in `quota-ns` limiting:
   - Max 5 pods
   - Max 2 CPU in requests
   - Max 2Gi memory in requests
3. Create a LimitRange `default-limits` that sets default container limits to 200m CPU and 128Mi memory

---

<details>
<summary>💡 Hint</summary>

`kubectl create quota` for ResourceQuota. LimitRange needs YAML.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create ns quota-ns
kubectl create quota compute-quota -n quota-ns --hard=pods=5,requests.cpu=2,requests.memory=2Gi
```

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: quota-ns
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "128Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
```

```bash
kubectl apply -f limitrange.yaml
kubectl describe quota compute-quota -n quota-ns
kubectl describe limitrange default-limits -n quota-ns
```

</details>

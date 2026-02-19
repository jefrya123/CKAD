# Scenario 29: Docker Registry Secret and imagePullSecrets

**Domain:** Application Environment, Configuration and Security
**Time Limit:** 4 minutes

## Task

1. Create a docker-registry Secret called `regcred` with the following details:
   - Server: `registry.example.com`
   - Username: `docker-user`
   - Password: `docker-pass`
   - Email: `user@example.com`
2. Create a pod called `private-pod` using the image `registry.example.com/myapp:latest` that references the `regcred` Secret as an imagePullSecret.
3. Verify the pod spec shows the imagePullSecrets configuration (the pod will likely fail to pull since the registry doesn't exist, but the configuration should be correct).
4. Verify the Secret was created as type `kubernetes.io/dockerconfigjson`.

---

<details>
<summary>💡 Hint</summary>

Use `kubectl create secret docker-registry` to create the Secret. Reference it in the pod spec under `spec.imagePullSecrets`. The Secret type will be `kubernetes.io/dockerconfigjson` automatically.

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create docker-registry Secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=docker-user \
  --docker-password=docker-pass \
  --docker-email=user@example.com
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-pod
spec:
  containers:
  - name: app
    image: registry.example.com/myapp:latest
  imagePullSecrets:
  - name: regcred
```

```bash
kubectl apply -f private-pod.yaml

# Verify imagePullSecrets in pod spec
kubectl get pod private-pod -o jsonpath='{.spec.imagePullSecrets}'
# [{"name":"regcred"}]

# Verify Secret type
kubectl get secret regcred -o jsonpath='{.type}'
# kubernetes.io/dockerconfigjson
```

</details>

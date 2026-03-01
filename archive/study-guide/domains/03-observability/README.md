# Domain 3: Application Observability and Maintenance (15%)

## Topics

- [ ] Liveness, readiness, and startup probes
- [ ] Container logging
- [ ] Debugging running applications
- [ ] Monitoring basics (metrics-server)

## Probes

### Probe Types

| Probe | Purpose | Failure Action |
|-------|---------|----------------|
| Liveness | Is the container alive? | Restart container |
| Readiness | Can it receive traffic? | Remove from Service endpoints |
| Startup | Has the app started? | Block other probes until success |

### Probe Mechanisms

| Type | Description | Use Case |
|------|-------------|----------|
| httpGet | HTTP GET request | Web apps with health endpoint |
| tcpSocket | TCP connection | Databases, services without HTTP |
| exec | Run command in container | Custom health checks |
| grpc | gRPC health check | gRPC services |

### Liveness Probe

Restarts the container if it fails.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15    # Wait before first probe
      periodSeconds: 10          # How often to probe
      timeoutSeconds: 3          # Probe timeout
      failureThreshold: 3        # Failures before restart
      successThreshold: 1        # Successes to be healthy
```

### Readiness Probe

Controls traffic routing - pod removed from Service when failing.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-tcp
spec:
  containers:
  - name: app
    image: nginx
    readinessProbe:
      tcpSocket:
        port: 3306
      initialDelaySeconds: 5
      periodSeconds: 10
```

### Startup Probe

For slow-starting applications. Disables liveness/readiness until startup succeeds.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-example
spec:
  containers:
  - name: app
    image: slow-starting-app
    startupProbe:
      httpGet:
        path: /ready
        port: 8080
      failureThreshold: 30       # 30 * 10s = 300s max startup time
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      periodSeconds: 10
```

### Exec Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c", "touch /tmp/healthy; sleep 3600"]
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Complete Example with All Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-probes
spec:
  containers:
  - name: app
    image: myapp
    ports:
    - containerPort: 8080
    startupProbe:
      httpGet:
        path: /startup
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0     # Startup probe handles delay
      periodSeconds: 15
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 5
      failureThreshold: 1
```

## Container Logging

```bash
# View logs
kubectl logs <pod>
kubectl logs <pod> -c <container>     # Specific container
kubectl logs <pod> --all-containers   # All containers

# Follow logs
kubectl logs -f <pod>

# Previous container (after crash)
kubectl logs <pod> --previous

# Last N lines
kubectl logs <pod> --tail=100

# Since time
kubectl logs <pod> --since=1h
kubectl logs <pod> --since-time="2024-01-01T00:00:00Z"

# Multiple pods by label
kubectl logs -l app=nginx --all-containers

# Save logs to file
kubectl logs <pod> > pod.log
```

## Debugging Applications

### Basic Debugging Commands

```bash
# Pod status and events
kubectl get pods -o wide
kubectl describe pod <pod>

# Check events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<pod>

# Execute commands in container
kubectl exec <pod> -- ls /app
kubectl exec -it <pod> -- /bin/sh
kubectl exec -it <pod> -c <container> -- /bin/bash

# Copy files to/from pod
kubectl cp <pod>:/path/to/file ./local-file
kubectl cp ./local-file <pod>:/path/to/file
```

### Debug Running Containers

```bash
# Get shell access
kubectl exec -it <pod> -- /bin/sh

# Check environment variables
kubectl exec <pod> -- env

# Check network connectivity
kubectl exec <pod> -- nc -zv service-name 80
kubectl exec <pod> -- wget -qO- http://service-name

# Check DNS resolution
kubectl exec <pod> -- nslookup kubernetes
kubectl exec <pod> -- cat /etc/resolv.conf

# Check mounted volumes
kubectl exec <pod> -- ls -la /mounted-path
kubectl exec <pod> -- df -h
```

### Ephemeral Debug Containers

```bash
# Add debug container to running pod
kubectl debug -it <pod> --image=busybox --target=<container>

# Create debug copy of pod
kubectl debug <pod> -it --copy-to=debug-pod --container=debug --image=busybox
```

### Common Issues and Debug Steps

| Issue | Debug Steps |
|-------|-------------|
| ImagePullBackOff | Check image name, registry auth, network |
| CrashLoopBackOff | `logs --previous`, check command/args |
| Pending | `describe pod`, check resources, node selector |
| ContainerCreating | Check volumes, configmaps, secrets |

## Monitoring with Metrics Server

```bash
# Install metrics-server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View node metrics
kubectl top nodes

# View pod metrics
kubectl top pods
kubectl top pods -A
kubectl top pods --containers

# Sort by CPU/memory
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
```

## Quick Reference

```bash
# Add probes to existing deployment
kubectl edit deployment <name>
# Or patch:
kubectl patch deployment <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/livenessProbe",
   "value": {"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 10}}
]'

# Check if probes are configured
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].livenessProbe}'

# Check probe status in describe
kubectl describe pod <pod> | grep -A5 "Liveness\|Readiness"
```

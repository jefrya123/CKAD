# Domain 3: Application Observability and Maintenance - Exercises

## Exercise 1: Liveness Probe (HTTP)

Create a pod named `liveness-http` with:
- Image: nginx
- Liveness probe checking `/` on port 80
- Initial delay: 10 seconds
- Period: 5 seconds

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
```

```bash
kubectl apply -f liveness-http.yaml
kubectl describe pod liveness-http | grep -A10 Liveness
```
</details>

## Exercise 2: Liveness Probe (Exec)

Create a pod named `liveness-exec` with:
- Image: busybox
- Command: creates `/tmp/healthy` file, sleeps 30s, deletes it, sleeps forever
- Liveness probe: check if `/tmp/healthy` exists
- Period: 5 seconds, Failure threshold: 3

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600"]
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

```bash
kubectl apply -f liveness-exec.yaml
kubectl get pod liveness-exec -w
# Watch it restart after ~45 seconds
kubectl describe pod liveness-exec | grep -A5 "Last State"
```
</details>

## Exercise 3: Readiness Probe

Create a pod named `readiness-test` with:
- Image: nginx
- Readiness probe checking `/ready` on port 80
- Initial delay: 5 seconds
- The pod should not be ready initially (because /ready doesn't exist)

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-test
spec:
  containers:
  - name: nginx
    image: nginx
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

```bash
kubectl apply -f readiness-test.yaml
kubectl get pod readiness-test
# Notice READY is 0/1

# Create the /ready file to make it ready
kubectl exec readiness-test -- sh -c 'echo ok > /usr/share/nginx/html/ready'
kubectl get pod readiness-test
# Now READY should be 1/1
```
</details>

## Exercise 4: Combined Probes

Create a pod named `full-probes` with all three probe types:
- Startup probe: HTTP GET /healthz, failureThreshold 30, period 10s
- Liveness probe: HTTP GET /healthz, period 10s
- Readiness probe: HTTP GET /ready, period 5s

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-probes
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    startupProbe:
      httpGet:
        path: /healthz
        port: 80
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      periodSeconds: 5
```

```bash
kubectl apply -f full-probes.yaml
kubectl describe pod full-probes | grep -A5 "Startup\|Liveness\|Readiness"
```
</details>

## Exercise 5: Container Logging

1. Create a deployment named `logger` with 2 replicas running nginx
2. View logs from all pods at once
3. View logs from a specific container
4. Follow logs in real-time

<details>
<summary>Solution</summary>

```bash
# Create deployment
kubectl create deployment logger --image=nginx --replicas=2

# Wait for pods to be ready
kubectl get pods -l app=logger

# View logs from all pods (using label selector)
kubectl logs -l app=logger

# View logs from a specific pod
POD=$(kubectl get pods -l app=logger -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD

# Follow logs
kubectl logs -f $POD

# View last 10 lines
kubectl logs $POD --tail=10

# View logs from last hour
kubectl logs $POD --since=1h

# Cleanup
kubectl delete deployment logger
```
</details>

## Exercise 6: Debug a Failing Pod

Create a pod that fails and debug it:

1. Create a pod with a typo in the image name
2. Identify the issue using describe and events
3. Fix the issue

<details>
<summary>Solution</summary>

```bash
# Create broken pod (note the typo: ngnix instead of nginx)
kubectl run broken --image=ngnix

# Check status
kubectl get pod broken
# Shows ImagePullBackOff or ErrImagePull

# Debug with describe
kubectl describe pod broken
# Look at Events section - "Failed to pull image"

# Check events
kubectl get events --field-selector involvedObject.name=broken

# Fix the image
kubectl set image pod/broken broken=nginx

# Verify
kubectl get pod broken
kubectl describe pod broken | grep Image

# Cleanup
kubectl delete pod broken
```
</details>

## Exercise 7: Debug CrashLoopBackOff

1. Create a pod that crashes immediately
2. Debug using logs --previous
3. Fix the issue

<details>
<summary>Solution</summary>

```bash
# Create crashing pod
kubectl run crasher --image=busybox -- /bin/sh -c "exit 1"

# Check status
kubectl get pod crasher
# Shows CrashLoopBackOff

# Check previous container logs
kubectl logs crasher --previous
# No output because exit 1 doesn't produce logs

# Check describe for more info
kubectl describe pod crasher
# Shows: "Back-off restarting failed container"

# Fix by giving it a proper command
kubectl delete pod crasher
kubectl run crasher --image=busybox -- /bin/sh -c "echo hello; sleep 3600"

# Verify
kubectl get pod crasher
kubectl logs crasher

# Cleanup
kubectl delete pod crasher
```
</details>

## Exercise 8: Exec into Running Pod

1. Create a pod running nginx
2. Execute commands inside the pod
3. Check environment variables
4. Test network connectivity

<details>
<summary>Solution</summary>

```bash
# Create pod
kubectl run debug-pod --image=nginx

# Wait for ready
kubectl wait --for=condition=ready pod/debug-pod

# Execute single command
kubectl exec debug-pod -- ls /usr/share/nginx/html

# Get interactive shell
kubectl exec -it debug-pod -- /bin/bash

# Inside the pod:
# Check environment variables
env
# Check network
cat /etc/resolv.conf
# Exit
exit

# Check environment from outside
kubectl exec debug-pod -- env

# Test DNS resolution
kubectl exec debug-pod -- cat /etc/resolv.conf

# Cleanup
kubectl delete pod debug-pod
```
</details>

## Exercise 9: Multi-Container Logging

1. Create a pod with two containers (nginx and busybox sidecar)
2. View logs from each container separately
3. View logs from all containers

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-log
spec:
  containers:
  - name: nginx
    image: nginx
  - name: sidecar
    image: busybox
    command: ["/bin/sh", "-c", "while true; do echo sidecar log; sleep 5; done"]
```

```bash
kubectl apply -f multi-log.yaml

# View logs from specific container
kubectl logs multi-log -c nginx
kubectl logs multi-log -c sidecar

# View logs from all containers
kubectl logs multi-log --all-containers

# Follow logs from sidecar
kubectl logs multi-log -c sidecar -f

# Cleanup
kubectl delete pod multi-log
```
</details>

## Exercise 10: Resource Monitoring

1. Check node resource usage
2. Check pod resource usage
3. Sort pods by CPU usage

<details>
<summary>Solution</summary>

```bash
# Note: Requires metrics-server to be installed
# Check if metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# View node resource usage
kubectl top nodes

# View pod resource usage
kubectl top pods
kubectl top pods -A  # All namespaces

# View with containers
kubectl top pods --containers

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory

# View specific namespace
kubectl top pods -n kube-system
```
</details>

## Cleanup

```bash
kubectl delete pod liveness-http liveness-exec readiness-test full-probes 2>/dev/null
kubectl delete pod broken crasher debug-pod multi-log 2>/dev/null
kubectl delete deployment logger 2>/dev/null
```

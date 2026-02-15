# Domain 5: Troubleshooting (30%)

## Topics

- [ ] Debug pods (logs, exec, describe)
- [ ] Debug nodes
- [ ] Debug networking
- [ ] Debug control plane components

## Pod Troubleshooting

```bash
# Check pod status
kubectl get pods -o wide
kubectl describe pod <pod>

# Check logs
kubectl logs <pod>
kubectl logs <pod> -c <container>  # multi-container
kubectl logs <pod> --previous      # crashed container

# Execute into pod
kubectl exec -it <pod> -- /bin/sh
kubectl exec -it <pod> -c <container> -- /bin/sh

# Check events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<pod>
```

## Common Pod Issues

| Status | Likely Cause | Debug |
|--------|--------------|-------|
| Pending | No node available, resource constraints | `describe pod`, check requests |
| ImagePullBackOff | Wrong image, no access | Check image name, registry auth |
| CrashLoopBackOff | App crashing | `logs --previous`, check command |
| ContainerCreating | Volume/configmap issues | `describe pod`, check mounts |

## Node Troubleshooting

```bash
# Check node status
kubectl get nodes
kubectl describe node <node>

# Check kubelet (on node)
systemctl status kubelet
journalctl -u kubelet -f

# Check node conditions
kubectl get node <node> -o jsonpath='{.status.conditions[*].type}'
```

## Control Plane Troubleshooting

```bash
# Check control plane pods
kubectl get pods -n kube-system

# Check component logs (static pods)
kubectl logs kube-apiserver-<node> -n kube-system
kubectl logs kube-scheduler-<node> -n kube-system
kubectl logs kube-controller-manager-<node> -n kube-system

# Check static pod manifests
ls /etc/kubernetes/manifests/

# Check certificates
kubeadm certs check-expiration
```

## Network Troubleshooting

```bash
# Test DNS
kubectl run tmp --image=busybox --rm -it -- nslookup kubernetes

# Test connectivity
kubectl run tmp --image=busybox --rm -it -- wget -O- <service>:<port>

# Check service endpoints
kubectl get endpoints <service>

# Check network policies
kubectl get networkpolicies -A
```

## Exercises

### Exercise 1: Fix a Broken Pod

```bash
# Create broken pod
kubectl run broken --image=ngnix  # typo!

# Debug it
kubectl get pods
kubectl describe pod broken
# Note: "Failed to pull image"

# Fix it
kubectl set image pod/broken broken=nginx
```

### Exercise 2: Debug CrashLoopBackOff

```bash
# Create crashing pod
kubectl run crasher --image=busybox -- /bin/sh -c "exit 1"

# Debug
kubectl get pods
kubectl logs crasher --previous
kubectl describe pod crasher
```

### Exercise 3: Debug Pending Pod

```bash
# Create pod with impossible resource request
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "100Gi"
EOF

# Debug
kubectl describe pod pending-pod
# Note: "Insufficient memory"
```

# Domain 1: Cluster Architecture, Installation & Configuration (25%)

## Topics

- [x] Kubernetes architecture overview
- [ ] RBAC configuration
- [ ] kubeadm cluster installation
- [ ] Cluster upgrades
- [ ] etcd backup and restore

## Kubernetes Architecture

### Control Plane Components

| Component | Purpose |
|-----------|---------|
| kube-apiserver | Frontend for the control plane, handles all API requests |
| etcd | Key-value store for all cluster data |
| kube-scheduler | Assigns pods to nodes based on constraints |
| kube-controller-manager | Runs controller loops (node, replication, endpoints, etc.) |
| cloud-controller-manager | Cloud-specific control logic (optional) |

### Worker Node Components

| Component | Purpose |
|-----------|---------|
| kubelet | Agent that ensures containers are running in pods |
| kube-proxy | Maintains network rules for pod communication |
| Container runtime | Runs containers (containerd, CRI-O) |

### Key Concepts

```
┌─────────────────────────────────────────────────────────────┐
│                     Control Plane                            │
│  ┌──────────┐ ┌──────┐ ┌───────────┐ ┌──────────────────┐  │
│  │apiserver │ │ etcd │ │ scheduler │ │controller-manager│  │
│  └──────────┘ └──────┘ └───────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   Worker Node   │ │   Worker Node   │ │   Worker Node   │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │   kubelet   │ │ │ │   kubelet   │ │ │ │   kubelet   │ │
│ │  kube-proxy │ │ │ │  kube-proxy │ │ │ │  kube-proxy │ │
│ │  container  │ │ │ │  container  │ │ │ │  container  │ │
│ │   runtime   │ │ │ │   runtime   │ │ │ │   runtime   │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Exercises

### Exercise 1: Explore Cluster Components

```bash
# View control plane pods
kubectl get pods -n kube-system

# Check component status
kubectl get componentstatuses  # deprecated but may still appear

# View node details
kubectl describe node <node-name>

# Check kubelet status (on node)
systemctl status kubelet
```

### Exercise 2: API Server Interaction

```bash
# Direct API access
kubectl get --raw /api/v1/namespaces

# Check API resources
kubectl api-resources
kubectl api-versions

# Explain any resource
kubectl explain pod.spec.containers
```

## Files in this Directory

- `rbac/` - RBAC examples and exercises
- `kubeadm/` - Cluster installation notes
- `etcd/` - Backup and restore procedures
- `upgrades/` - Cluster upgrade procedures

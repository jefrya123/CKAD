# Cluster Upgrade Procedure

## Overview

Upgrade one minor version at a time (e.g., 1.27 → 1.28, not 1.27 → 1.29).

## Upgrade Order

1. Control plane nodes (one at a time if HA)
2. Worker nodes (one at a time)

## Step 1: Upgrade Control Plane

```bash
# Check current version
kubectl get nodes
kubeadm version

# Find available versions
apt update
apt-cache madison kubeadm

# Upgrade kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.28.0-00
apt-mark hold kubeadm

# Verify
kubeadm version

# Check upgrade plan
kubeadm upgrade plan

# Apply upgrade (first control plane node)
kubeadm upgrade apply v1.28.0

# For additional control plane nodes use:
kubeadm upgrade node

# Drain the node
kubectl drain <node-name> --ignore-daemonsets

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.28.0-00 kubectl=1.28.0-00
apt-mark hold kubelet kubectl

# Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

# Uncordon the node
kubectl uncordon <node-name>
```

## Step 2: Upgrade Worker Nodes

```bash
# On control plane: drain worker node
kubectl drain <worker-node> --ignore-daemonsets --delete-emptydir-data

# SSH to worker node
ssh <worker-node>

# Upgrade kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.28.0-00
apt-mark hold kubeadm

# Upgrade node config
kubeadm upgrade node

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.28.0-00 kubectl=1.28.0-00
apt-mark hold kubelet kubectl

# Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

# Exit worker, back on control plane: uncordon
kubectl uncordon <worker-node>
```

## Verification

```bash
# Check all nodes upgraded
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Verify cluster functionality
kubectl run test --image=nginx
kubectl get pods
kubectl delete pod test
```

## Quick Reference Commands

```bash
# Drain node (prepare for maintenance)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Uncordon node (make schedulable again)
kubectl uncordon <node>

# Cordon node (mark unschedulable, no eviction)
kubectl cordon <node>

# Check node status
kubectl describe node <node>
```

## Important Notes

- Always backup etcd before upgrading
- Read release notes for breaking changes
- Test upgrade procedure in non-production first
- Upgrade one minor version at a time
- Keep kubeadm, kubelet, kubectl versions aligned

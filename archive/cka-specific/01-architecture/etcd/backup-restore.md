# etcd Backup and Restore

## Overview

etcd stores all cluster state. Backing it up is critical for disaster recovery.

## Find etcd Configuration

```bash
# On control plane node, check etcd pod
kubectl describe pod etcd-<node> -n kube-system

# Key paths (usually):
# --cert-file=/etc/kubernetes/pki/etcd/server.crt
# --key-file=/etc/kubernetes/pki/etcd/server.key
# --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
# --data-dir=/var/lib/etcd

# Or check the manifest
cat /etc/kubernetes/manifests/etcd.yaml
```

## Backup etcd

```bash
# Set variables
ETCDCTL_API=3

# Backup command
etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
etcdctl snapshot status /tmp/etcd-backup.db --write-out=table
```

## Restore etcd

```bash
# Stop kube-apiserver (if running as static pod, move manifest)
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Restore to new data directory
etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Update etcd manifest to use new data directory
# Edit /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd-restored
# And update the hostPath volume

# Move kube-apiserver manifest back
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Wait for pods to restart
kubectl get pods -n kube-system
```

## Exercise: Practice Backup/Restore on kind

```bash
# 1. Create some resources
kubectl create namespace backup-test
kubectl create deployment nginx --image=nginx -n backup-test

# 2. Backup (exec into etcd container or control plane node)
# In kind, you need to exec into control-plane container
docker exec -it cka-practice-control-plane bash

# Inside container:
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 3. Delete resources
kubectl delete namespace backup-test

# 4. Restore and verify resources are back
```

## Important Notes

- Always backup before cluster upgrades
- etcdctl must match etcd server version (or be compatible)
- Restore creates a new data directory (don't overwrite existing)
- After restore, all cluster components need to reconnect

## Quick Reference

```bash
# Always export this
export ETCDCTL_API=3

# Snapshot commands
etcdctl snapshot save <file>
etcdctl snapshot restore <file>
etcdctl snapshot status <file>

# Health check
etcdctl endpoint health
etcdctl member list
```

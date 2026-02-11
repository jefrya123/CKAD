# Practice Environment Setup

## Quick Start

```bash
# 1. Install kind (if not already)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# 2. Create the practice cluster
kind create cluster --name ckad --config kind-config.yaml

# 3. Verify
kubectl get nodes    # Should show 1 control-plane + 2 workers

# 4. Install metrics-server (for `kubectl top`)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# For kind, patch to skip TLS:
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
]'

# 5. Install ingress controller (for Ingress scenarios)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 6. Deploy practice scenarios
./deploy-scenarios.sh

# 7. Set up shell
source shell-setup.sh
```

## Teardown

```bash
kind delete cluster --name ckad
```

## Alternative: Minikube

```bash
minikube start --nodes 3 --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server
```

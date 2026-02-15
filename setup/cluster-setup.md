# Cluster Setup Guide

## Option 1: kind (Kubernetes in Docker) - Recommended

### Install kind

```bash
# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Or via Go
go install sigs.k8s.io/kind@v0.20.0
```

### Install kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### Create a Multi-Node Cluster

```bash
# Create config file
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --name ckad-practice --config kind-config.yaml

# Verify
kubectl get nodes
kubectl cluster-info
```

### Shell Completion & Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# kubectl alias
alias k=kubectl
complete -o default -F __start_kubectl k

# kubectl completion
source <(kubectl completion bash)  # or zsh

# Useful aliases for exam
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Set default namespace
alias kns='kubectl config set-context --current --namespace'
```

### Cluster Management Commands

```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name ckad-practice

# Load local images into kind
kind load docker-image my-image:tag --name ckad-practice

# Get kubeconfig
kind get kubeconfig --name ckad-practice
```

## Option 2: minikube

```bash
# Install
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start with multiple nodes
minikube start --nodes 3

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
```

## Verification Checklist

- [ ] `kubectl get nodes` shows all nodes Ready
- [ ] `kubectl get pods -A` shows system pods running
- [ ] Can create a test pod: `kubectl run test --image=nginx`
- [ ] Shell completion works
- [ ] Aliases configured

## Troubleshooting

### kind cluster won't start
```bash
# Check Docker is running
docker ps

# Check for existing clusters
kind get clusters

# Delete and recreate
kind delete cluster --name cka-practice
```

### kubectl can't connect
```bash
# Check kubeconfig
echo $KUBECONFIG
cat ~/.kube/config

# Set context
kubectl config use-context kind-ckad-practice
```

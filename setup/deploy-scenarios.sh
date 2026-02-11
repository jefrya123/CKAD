#!/bin/bash
# Deploy practice resources for CKAD scenarios
set -e

echo "=== CKAD Practice Environment Setup ==="

# Create namespaces
echo "[1/5] Creating namespaces..."
kubectl create ns dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns secure --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns secure purpose=secure --overwrite

# Create sample ConfigMaps and Secrets
echo "[2/5] Creating ConfigMaps and Secrets..."
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONN=100 \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=practice123 \
  --dry-run=client -o yaml | kubectl apply -f -

# Create sample deployments
echo "[3/5] Creating deployments..."
kubectl create deploy web --image=nginx --replicas=3 --dry-run=client -o yaml | kubectl apply -f -
kubectl create deploy api --image=httpd --replicas=2 --dry-run=client -o yaml | kubectl apply -f -
kubectl create deploy backend --image=nginx -n dev --dry-run=client -o yaml | kubectl apply -f -

# Create services
echo "[4/5] Creating services..."
kubectl expose deploy web --port=80 --dry-run=client -o yaml | kubectl apply -f -
kubectl expose deploy api --port=80 --dry-run=client -o yaml | kubectl apply -f -

# Create some RBAC resources
echo "[5/5] Creating RBAC resources..."
kubectl create sa app-sa -n dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create role pod-reader -n dev --verb=get,list,watch --resource=pods --dry-run=client -o yaml | kubectl apply -f -
kubectl create rolebinding app-reader -n dev --role=pod-reader --serviceaccount=dev:app-sa --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Setup Complete ==="
echo "Resources created in: default, dev, prod, secure"
echo ""
echo "Quick checks:"
echo "  kubectl get all"
echo "  kubectl get all -n dev"
echo "  kubectl get cm,secret"
echo "  kubectl get sa,role,rolebinding -n dev"

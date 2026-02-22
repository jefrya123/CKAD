#!/bin/bash
# ============================================================
# CKAD Practice — Master Setup Script
# Deploys cluster state for ALL 22 practice scenarios
# Usage:
#   bash setup-all.sh          # deploy all
#   bash setup-all.sh q01      # deploy only Q01 setup
#   bash setup-all.sh clean    # teardown everything
# ============================================================

set -e

Q=${1:-all}

# ── Namespaces ──────────────────────────────────────────────
create_namespaces() {
  for ns in neptune pluto saturn moon earth venus mars sunny mercury; do
    kubectl create namespace $ns 2>/dev/null || true
  done

  # Label namespaces needed for NetworkPolicy (Q20)
  kubectl label namespace venus name=venus --overwrite 2>/dev/null || true
  kubectl label namespace mars  name=mars  --overwrite 2>/dev/null || true
}

# ── Q01: Namespaces ─────────────────────────────────────────
setup_q01() {
  echo "→ Q01: Setting up namespace pods..."
  for ns in neptune pluto saturn moon earth; do
    kubectl run q01-pod --image=nginx:1.21 -n $ns \
      --labels="app=q01,ns=$ns" 2>/dev/null || true
  done
}

# ── Q02: Pods (broken pod) ───────────────────────────────────
setup_q02() {
  echo "→ Q02: Deploying broken pod..."
  kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-pod
  labels:
    id: wrong-id
spec:
  containers:
  - name: neptune-pod
    image: nginx:1.99-broken
EOF
}

# ── Q03: Job (broken job) ────────────────────────────────────
setup_q03() {
  echo "→ Q03: Deploying broken job..."
  kubectl apply -n neptune -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: neb-broken-job
spec:
  completions: 3
  parallelism: 1
  template:
    metadata:
      labels:
        id: neb-broken-job
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox
        command: ["/bin/sh", "-c", "sleep 2 && echo done"]
EOF
}

# ── Q04: Helm ───────────────────────────────────────────────
setup_q04() {
  echo "→ Q04: Installing Helm releases..."
  helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
  helm repo update
  helm install internal-nginx bitnami/nginx --version 13.2.0 -n mercury \
    --set replicaCount=1 2>/dev/null || true
  helm install external-nginx bitnami/nginx --version 13.2.0 -n mercury \
    --set replicaCount=1 2>/dev/null || true
}

# ── Q05: ServiceAccount + Secrets ───────────────────────────
setup_q05() {
  echo "→ Q05: Creating SAs and Secrets..."
  kubectl create sa neptune-sa       -n neptune 2>/dev/null || true
  kubectl create sa neptune-sa-admin -n neptune 2>/dev/null || true

  kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: neptune-sa-token
  annotations:
    kubernetes.io/service-account.name: neptune-sa
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-sa-admin-token
  annotations:
    kubernetes.io/service-account.name: neptune-sa-admin
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Secret
metadata:
  name: neptune-db-creds
type: Opaque
stringData:
  username: db-user
  password: sup3rs3cr3t
EOF
}

# ── Q06: ReadinessProbe ──────────────────────────────────────
setup_q06() {
  echo "→ Q06: Deploying pod without readiness probe..."
  kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-probe-pod
  labels:
    id: neptune-probe-pod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF
}

# ── Q07: Pod Namespace Migration ─────────────────────────────
setup_q07() {
  echo "→ Q07: Creating pod in neptune to migrate to pluto..."
  kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  labels:
    app: webserver
    id: migrate-me
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: APP_ENV
      value: production
EOF
}

# ── Q08: Deployment Rollback ─────────────────────────────────
setup_q08() {
  echo "→ Q08: Creating deployment with broken image history..."
  kubectl create deployment neptune-web --image=nginx:1.19 -n neptune 2>/dev/null || true
  sleep 3
  kubectl set image deployment/neptune-web nginx=nginx:1.20 -n neptune
  sleep 3
  kubectl set image deployment/neptune-web nginx=nginx:1.21 -n neptune
  sleep 3
  kubectl set image deployment/neptune-web nginx=nginx:99.99-broken -n neptune
}

# ── Q09: Pod to Deployment ───────────────────────────────────
setup_q09() {
  echo "→ Q09: Creating standalone pod to convert..."
  kubectl apply -n neptune -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: neptune-api
  labels:
    app: neptune-api
    env: production
spec:
  containers:
  - name: api
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: APP_MODE
      value: production
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
EOF
}

# ── Q10: Service + Logs ──────────────────────────────────────
setup_q10() {
  echo "→ Q10: Deploying pluto-api..."
  kubectl apply -n pluto -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pluto-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pluto-api
  template:
    metadata:
      labels:
        app: pluto-api
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
}

# ── Q11: Containers (Docker) ─────────────────────────────────
setup_q11() {
  echo "→ Q11: Creating Dockerfile for build exercise..."
  mkdir -p /tmp/q11
  cat > /tmp/q11/Dockerfile <<'EOF'
FROM nginx:1.21
RUN echo "CKAD practice build" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF
  echo "   Dockerfile created at /tmp/q11/Dockerfile"
}

# ── Q12: Storage PV/PVC ──────────────────────────────────────
setup_q12() {
  echo "→ Q12: Creating /tmp/q12-data directory..."
  mkdir -p /tmp/q12-data 2>/dev/null || true
}

# ── Q13: StorageClass ────────────────────────────────────────
setup_q13() {
  echo "→ Q13: Namespace 'moon' ready (no pre-setup needed)"
}

# ── Q14: Secret Volume+Env ───────────────────────────────────
setup_q14() {
  echo "→ Q14: Deploying pod without secret..."
  kubectl apply -n moon -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: moon-secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
EOF
}

# ── Q15: ConfigMap ───────────────────────────────────────────
setup_q15() {
  echo "→ Q15: Deploying moon-web deployment..."
  kubectl apply -n moon -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon-web
  template:
    metadata:
      labels:
        app: moon-web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
}

# ── Q16: Logging Sidecar ─────────────────────────────────────
setup_q16() {
  echo "→ Q16: Deploying moon-logger without sidecar..."
  kubectl apply -n moon -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon-logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon-logger
  template:
    metadata:
      labels:
        app: moon-logger
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "while true; do echo \"\$(date): request processed\" >> /var/log/app/app.log; sleep 3; done"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: logs
        emptyDir: {}
EOF
}

# ── Q17: InitContainer ───────────────────────────────────────
setup_q17() {
  echo "→ Q17: Namespace 'moon' ready (no pre-setup needed)"
}

# ── Q18: Service Misconfiguration ────────────────────────────
setup_q18() {
  echo "→ Q18: Deploying broken service..."
  kubectl apply -n saturn -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: saturn-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: saturn-api
      tier: backend
  template:
    metadata:
      labels:
        app: saturn-api
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: saturn-svc
spec:
  selector:
    app: saturn-api
    tier: frontend
  ports:
  - port: 80
    targetPort: 3000
EOF
}

# ── Q19: ClusterIP to NodePort ───────────────────────────────
setup_q19() {
  echo "→ Q19: Deploying pluto-web + ClusterIP service..."
  kubectl apply -n pluto -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pluto-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pluto-web
  template:
    metadata:
      labels:
        app: pluto-web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: pluto-web-svc
spec:
  type: ClusterIP
  selector:
    app: pluto-web
  ports:
  - port: 80
    targetPort: 80
EOF
}

# ── Q20: NetworkPolicy ───────────────────────────────────────
setup_q20() {
  echo "→ Q20: Setting up venus/mars namespaces + pods..."
  kubectl apply -n venus -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: venus-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: venus-app
  template:
    metadata:
      labels:
        app: venus-app
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: venus-svc
spec:
  selector:
    app: venus-app
  ports:
  - port: 80
EOF
  kubectl run mars-pod     --image=busybox -n mars  --labels="app=mars-pod"  -- sh -c "sleep 3600" 2>/dev/null || true
  kubectl run external-pod --image=busybox -n venus --labels="app=external"  -- sh -c "sleep 3600" 2>/dev/null || true
}

# ── Q21: Requests/Limits + SA ────────────────────────────────
setup_q21() {
  echo "→ Q21: Namespace 'neptune' ready (no pre-setup needed)"
}

# ── Q22: Labels/Annotations ──────────────────────────────────
setup_q22() {
  echo "→ Q22: Creating pods with mixed labels..."
  kubectl apply -n sunny -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-1
  labels:
    app: sunny
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-2
  labels:
    app: sunny
    tier: backend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-3
  labels:
    app: sunny
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: sunny-pod-4
  labels:
    app: other
spec:
  containers:
  - name: nginx
    image: nginx
EOF
}

# ── Cleanup ──────────────────────────────────────────────────
cleanup_all() {
  echo "→ Cleaning up all CKAD practice namespaces..."
  for ns in neptune pluto saturn moon earth venus mars sunny mercury; do
    kubectl delete namespace $ns --ignore-not-found 2>/dev/null || true
  done

  # Clean up helm releases if helm is available
  if command -v helm &>/dev/null; then
    helm uninstall internal-nginx -n mercury 2>/dev/null || true
    helm uninstall external-nginx -n mercury 2>/dev/null || true
  fi

  # Clean up docker containers if docker is available
  if command -v docker &>/dev/null; then
    docker stop ckad-test 2>/dev/null || true
    docker rm   ckad-test 2>/dev/null || true
  fi

  echo "✅ Cleanup complete"
}

# ── Main ─────────────────────────────────────────────────────
main() {
  if [ "$Q" = "clean" ]; then
    cleanup_all
    exit 0
  fi

  create_namespaces

  case "$Q" in
    q01) setup_q01 ;;
    q02) setup_q02 ;;
    q03) setup_q03 ;;
    q04) setup_q04 ;;
    q05) setup_q05 ;;
    q06) setup_q06 ;;
    q07) setup_q07 ;;
    q08) setup_q08 ;;
    q09) setup_q09 ;;
    q10) setup_q10 ;;
    q11) setup_q11 ;;
    q12) setup_q12 ;;
    q13) setup_q13 ;;
    q14) setup_q14 ;;
    q15) setup_q15 ;;
    q16) setup_q16 ;;
    q17) setup_q17 ;;
    q18) setup_q18 ;;
    q19) setup_q19 ;;
    q20) setup_q20 ;;
    q21) setup_q21 ;;
    q22) setup_q22 ;;
    all)
      setup_q01; setup_q02; setup_q03
      setup_q05; setup_q06; setup_q07
      setup_q08; setup_q09; setup_q10
      setup_q11; setup_q12; setup_q13
      setup_q14; setup_q15; setup_q16
      setup_q18; setup_q19; setup_q20
      setup_q22
      echo ""
      echo "⚠️  Q04 (Helm) skipped in 'all' — run: bash setup-all.sh q04"
      echo "✅ All CKAD practice scenarios deployed."
      echo ""
      echo "Start with: kubectl get pods -A"
      ;;
    *)
      echo "Usage: bash setup-all.sh [q01..q22 | clean | all]"
      exit 1
      ;;
  esac
}

main

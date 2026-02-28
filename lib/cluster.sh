# lib/cluster.sh — kind cluster lifecycle management
# Sourced by bin/ckad-drill — do NOT add shebang or set strict mode here
# shellcheck shell=bash

# Addon version variables — pinned for reproducibility (dev-friendly, not user-configurable)
CALICO_VERSION="v3.31.4"
INGRESS_NGINX_VERSION="v1.14.3"
METRICS_SERVER_VERSION="v0.8.1"

# cluster_check_deps — verify all required dependencies are installed and functional
# Checks: docker (binary + daemon), kind, kubectl, yq, jq
# Accumulates ALL missing deps before reporting — does not fail on first missing dep
# Returns: 0 if all deps satisfied, 1 if any missing
cluster_check_deps() {
  local missing=()

  # Docker is special: check binary AND daemon running
  if ! command -v docker &>/dev/null; then
    missing+=("docker (not installed)")
  elif ! docker info &>/dev/null 2>&1; then
    missing+=("docker (installed but daemon not running)")
  fi

  # Check remaining binary deps
  for dep in kind kubectl yq jq; do
    if ! command -v "${dep}" &>/dev/null; then
      missing+=("${dep}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required dependencies:"
    for dep in "${missing[@]}"; do
      warn "  - ${dep}"
    done
    info ""
    info "Installation instructions:"
    info "  docker:  https://docs.docker.com/get-docker/"
    info "  kind:    https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    info "  kubectl: https://kubernetes.io/docs/tasks/tools/"
    info "  yq:      https://github.com/mikefarah/yq#install"
    info "  jq:      https://jqlang.github.io/jq/download/"
    return 1
  fi
}

# cluster_exists — check if the ckad-drill kind cluster is registered with kind
# Returns: 0 if cluster exists, 1 if not
cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^${CKAD_CLUSTER_NAME}$"
}

# cluster_is_healthy — check if the cluster is reachable and all nodes are Ready
# Returns: 0 if healthy, 1 if unreachable or any node is NotReady
cluster_is_healthy() {
  # Check cluster is reachable
  kubectl cluster-info --context "${CKAD_KUBE_CONTEXT}" &>/dev/null 2>&1 || return 1

  # Count nodes that are NOT in Ready state
  local not_ready
  not_ready=$(kubectl get nodes --context "${CKAD_KUBE_CONTEXT}" \
    --no-headers 2>/dev/null | grep -cv " Ready" || true)
  [[ "${not_ready}" -eq 0 ]]
}

# _cluster_install_calico — install Calico CNI using manifest-only method
# Waits for calico-node DaemonSet pods to be Ready before returning
_cluster_install_calico() {
  kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
  kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=k8s-app=calico-node \
    --timeout=180s
}

# _cluster_install_ingress — install ingress-nginx using kind-specific manifest
# Waits for admission job completion and controller pod Ready before returning
_cluster_install_ingress() {
  kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"

  # Wait for admission jobs — try both job names (create and patch), ignore failures
  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-create \
    --timeout=60s 2>/dev/null || true
  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-patch \
    --timeout=60s 2>/dev/null || true

  # Wait for controller pod to be Ready
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s
}

# _cluster_install_metrics_server — install metrics-server with insecure-tls patch
# The patch is required because kind uses self-signed certificates for the kubelet API
_cluster_install_metrics_server() {
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

  # Patch to add --kubelet-insecure-tls (required for kind's self-signed kubelet certs)
  kubectl patch deployment metrics-server \
    --namespace kube-system \
    --type='json' \
    --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

  kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=k8s-app=metrics-server \
    --timeout=60s
}

# _cluster_retry_once — retry a function once on failure, then report error and return 1
# Args: $1 = function name, $2 = display name for messages
_cluster_retry_once() {
  local fn="$1"
  local name="$2"
  warn "Retrying ${name} install..."
  if "${fn}"; then
    return 0
  else
    error "Failed to install ${name} after retry. Check Docker resources and network connectivity."
    return 1
  fi
}

# cluster_start — create the ckad-drill cluster with all addons
# Idempotent: reuses existing healthy cluster; auto-heals unhealthy cluster
# Checks all dependencies before proceeding
cluster_start() {
  cluster_check_deps || return 1

  if cluster_exists; then
    if cluster_is_healthy; then
      success "Cluster '${CKAD_CLUSTER_NAME}' already running"
      return 0
    else
      warn "Cluster unhealthy, recreating..."
      cluster_stop
    fi
  fi

  info "Creating cluster '${CKAD_CLUSTER_NAME}'..."
  kind create cluster --name "${CKAD_CLUSTER_NAME}" --config "${CKAD_DRILL_ROOT}/setup/kind-config.yaml"

  info "Installing Calico CNI..."
  _cluster_install_calico || _cluster_retry_once _cluster_install_calico "Calico" || return 1

  info "Installing ingress-nginx..."
  _cluster_install_ingress || _cluster_retry_once _cluster_install_ingress "ingress-nginx" || return 1

  info "Installing metrics-server..."
  _cluster_install_metrics_server || _cluster_retry_once _cluster_install_metrics_server "metrics-server" || return 1

  success "Cluster '${CKAD_CLUSTER_NAME}' is ready"
}

# cluster_stop — delete the ckad-drill cluster and clean up kubeconfig
cluster_stop() {
  info "Deleting cluster '${CKAD_CLUSTER_NAME}'..."
  kind delete cluster --name "${CKAD_CLUSTER_NAME}" 2>/dev/null || true

  # Remove stale kubeconfig context to prevent kind create conflicts
  kubectl config delete-context "${CKAD_KUBE_CONTEXT}" 2>/dev/null || true

  success "Cluster deleted"
}

# cluster_reset — tear down and recreate the cluster from scratch
cluster_reset() {
  cluster_check_deps || return 1
  info "Resetting cluster..."
  cluster_stop
  cluster_start
}

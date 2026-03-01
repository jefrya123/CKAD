#!/usr/bin/env bash
# scripts/dev-setup.sh — install development tooling for ckad-drill
# Sets up bats-core, shellcheck, and bats helper libraries
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KIND_VERSION="v0.25.0"
YQ_VERSION="v4.44.6"
JQ_VERSION="1.7.1"

echo "Setting up ckad-drill development environment..."
echo ""

# --- jq ---
if command -v jq &>/dev/null; then
  echo "jq already installed: $(jq --version)"
else
  echo "Installing jq..."
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install jq
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq
  else
    echo "jq not available via package manager. Install from: https://jqlang.github.io/jq/download/" >&2
    exit 1
  fi
  echo "jq installed: $(jq --version)"
fi

# --- yq ---
if command -v yq &>/dev/null; then
  echo "yq already installed: $(yq --version)"
else
  echo "Installing yq ${YQ_VERSION}..."
  local_bin="${HOME}/.local/bin"
  mkdir -p "${local_bin}"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac
  curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${os}_${arch}" -o "${local_bin}/yq"
  chmod +x "${local_bin}/yq"
  echo "yq installed: $(yq --version 2>/dev/null || echo "${YQ_VERSION}")"
fi

# --- kind ---
if command -v kind &>/dev/null; then
  echo "kind already installed: $(kind --version)"
else
  echo "Installing kind ${KIND_VERSION}..."
  local_bin="${HOME}/.local/bin"
  mkdir -p "${local_bin}"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac
  curl -sSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}" -o "${local_bin}/kind"
  chmod +x "${local_bin}/kind"
  echo "kind installed: $(kind --version 2>/dev/null || echo "${KIND_VERSION}")"
fi

# --- bats-core ---
if command -v bats &>/dev/null; then
  echo "bats already installed: $(bats --version)"
else
  echo "Installing bats-core..."
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install bats-core
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y bats
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y bats
  elif command -v npm &>/dev/null; then
    npm install -g bats
  else
    git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
    cd /tmp/bats-core
    sudo ./install.sh /usr/local
    cd "${REPO_ROOT}"
  fi
  echo "bats installed: $(bats --version)"
fi

# --- shellcheck ---
if command -v shellcheck &>/dev/null; then
  echo "shellcheck already installed: $(shellcheck --version | head -2 | tail -1)"
else
  echo "Installing shellcheck..."
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install shellcheck
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y shellcheck
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y ShellCheck
  else
    echo "shellcheck not available via package manager." >&2
    echo "Download from: https://github.com/koalaman/shellcheck/releases" >&2
    exit 1
  fi
  echo "shellcheck installed: $(shellcheck --version | head -2 | tail -1)"
fi

# --- bats helper libraries ---
echo ""
echo "Installing bats helper libraries into test/helpers/..."

if [[ ! -d "${REPO_ROOT}/test/helpers/bats-support" ]]; then
  echo "Cloning bats-support..."
  git clone --depth 1 https://github.com/bats-core/bats-support.git \
    "${REPO_ROOT}/test/helpers/bats-support"
else
  echo "bats-support already present"
fi

if [[ ! -d "${REPO_ROOT}/test/helpers/bats-assert" ]]; then
  echo "Cloning bats-assert..."
  git clone --depth 1 https://github.com/bats-core/bats-assert.git \
    "${REPO_ROOT}/test/helpers/bats-assert"
else
  echo "bats-assert already present"
fi

# --- Summary ---------------------------------------------------------------
echo ""
echo "Installed versions:"
printf "  %-15s %s\n" "jq:"         "$(jq --version 2>/dev/null || echo 'not found')"
printf "  %-15s %s\n" "yq:"         "$(yq --version 2>/dev/null || echo 'not found')"
printf "  %-15s %s\n" "kind:"       "$(kind --version 2>/dev/null || echo 'not found')"
printf "  %-15s %s\n" "bats:"       "$(bats --version 2>/dev/null || echo 'not found')"
printf "  %-15s %s\n" "shellcheck:" "$(shellcheck --version 2>/dev/null | grep 'version:' | awk '{print $2}' || echo 'not found')"

if [[ -d "${REPO_ROOT}/test/helpers/bats-support/.git" ]]; then
  _bats_support_sha=$(git -C "${REPO_ROOT}/test/helpers/bats-support" rev-parse --short HEAD 2>/dev/null || echo 'unknown')
  printf "  %-15s %s\n" "bats-support:"  "${_bats_support_sha}"
fi
if [[ -d "${REPO_ROOT}/test/helpers/bats-assert/.git" ]]; then
  _bats_assert_sha=$(git -C "${REPO_ROOT}/test/helpers/bats-assert" rev-parse --short HEAD 2>/dev/null || echo 'unknown')
  printf "  %-15s %s\n" "bats-assert:"   "${_bats_assert_sha}"
fi

echo ""
echo "Development environment ready."
echo ""
echo "Next steps:"
echo "  make shellcheck    — lint all bash files"
echo "  make test-unit     — run unit tests (no cluster required)"

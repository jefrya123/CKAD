#!/usr/bin/env bash
# scripts/install.sh — install ckad-drill and its runtime dependencies
# Usage: curl -sSL https://raw.githubusercontent.com/jefrya123/CKAD/main/scripts/install.sh | sh
set -euo pipefail

# ---- Configuration --------------------------------------------------------
GITHUB_REPO="${GITHUB_REPO:-jefrya123/CKAD}"
INSTALL_DIR="${CKAD_DRILL_HOME:-${HOME}/.local/share/ckad-drill}"
BIN_DIR="${HOME}/.local/bin"
KIND_VERSION="v0.25.0"
YQ_VERSION="v4.44.6"
JQ_VERSION="1.7.1"

# ---- Colors (only when stdout is a terminal) ------------------------------
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  RESET=''
fi

check() { printf "${GREEN}[ok]${RESET} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${RESET}  %s\n" "$1"; }
fail()  { printf "${RED}[x]${RESET}  %s\n" "$1" >&2; }
step()  { printf "\n%s\n" "==> $1"; }

# ---- Helpers --------------------------------------------------------------

# Detect OS: outputs "linux" or "darwin"
detect_os() {
  local raw
  raw="$(uname -s)"
  case "${raw}" in
    Linux*)  echo "linux"  ;;
    Darwin*) echo "darwin" ;;
    *)
      fail "Unsupported OS: ${raw}"
      exit 1
      ;;
  esac
}

# Detect architecture: outputs "amd64" or "arm64"
detect_arch() {
  local raw
  raw="$(uname -m)"
  case "${raw}" in
    x86_64)          echo "amd64" ;;
    arm64|aarch64)   echo "arm64" ;;
    *)
      fail "Unsupported architecture: ${raw}"
      exit 1
      ;;
  esac
}

# Ensure ~/.local/bin exists and is on PATH
ensure_bin_dir() {
  mkdir -p "${BIN_DIR}"
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
      warn "${BIN_DIR} is not in your PATH."
      warn "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
      warn "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
      ;;
  esac
}

# Download a file with curl or wget
download() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -sSL "${url}" -o "${dest}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "${url}" -O "${dest}"
  else
    fail "Neither curl nor wget found. Please install one and retry."
    exit 1
  fi
}

# ---- Preflight checks -----------------------------------------------------

check_bash_version() {
  step "Checking bash version"
  # BASH_VERSINFO is only available inside bash; this script runs with bash
  local major="${BASH_VERSINFO[0]}"
  if [ "${major}" -lt 4 ]; then
    fail "bash >= 4.0 required (found ${BASH_VERSION})"
    if [ "$(uname -s)" = "Darwin" ]; then
      warn "macOS ships with bash 3.2. Upgrade with: brew install bash"
    fi
    exit 1
  fi
  check "bash ${BASH_VERSION}"
}

check_docker() {
  step "Checking Docker"
  if ! command -v docker >/dev/null 2>&1; then
    fail "Docker is not installed."
    warn "Install Docker Desktop: https://docs.docker.com/get-docker/"
    exit 1
  fi
  check "Docker $(docker --version 2>/dev/null | head -1 | awk '{print $3}' | tr -d ',')"
}

check_kubectl() {
  step "Checking kubectl"
  if ! command -v kubectl >/dev/null 2>&1; then
    fail "kubectl is not installed."
    warn "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
  fi
  check "kubectl $(kubectl version --client --short 2>/dev/null | head -1 | awk '{print $3}' 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
}

# ---- Optional dependency installers ---------------------------------------

install_kind() {
  if command -v kind >/dev/null 2>&1; then
    check "kind already installed: $(kind --version 2>/dev/null)"
    return
  fi

  step "Installing kind ${KIND_VERSION}"
  local os arch url
  os="$(detect_os)"
  arch="$(detect_arch)"
  url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}"

  download "${url}" "${BIN_DIR}/kind"
  chmod +x "${BIN_DIR}/kind"
  check "kind ${KIND_VERSION} installed to ${BIN_DIR}/kind"
}

install_yq() {
  if command -v yq >/dev/null 2>&1; then
    check "yq already installed: $(yq --version 2>/dev/null)"
    return
  fi

  step "Installing yq ${YQ_VERSION}"
  local os arch suffix url
  os="$(detect_os)"
  arch="$(detect_arch)"

  # yq release asset naming: yq_linux_amd64, yq_darwin_arm64, etc.
  suffix="${os}_${arch}"
  url="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${suffix}"

  download "${url}" "${BIN_DIR}/yq"
  chmod +x "${BIN_DIR}/yq"
  check "yq ${YQ_VERSION} installed to ${BIN_DIR}/yq"
}

install_jq() {
  if command -v jq >/dev/null 2>&1; then
    check "jq already installed: $(jq --version 2>/dev/null)"
    return
  fi

  step "Installing jq ${JQ_VERSION}"
  local os arch asset url
  os="$(detect_os)"
  arch="$(detect_arch)"

  # jq release asset naming: jq-linux-amd64, jq-macos-amd64, jq-macos-arm64, etc.
  # macOS assets use "macos" not "darwin" in jq 1.7.x
  if [ "${os}" = "darwin" ]; then
    asset="jq-macos-${arch}"
  else
    asset="jq-${os}-${arch}"
  fi
  url="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/${asset}"

  download "${url}" "${BIN_DIR}/jq"
  chmod +x "${BIN_DIR}/jq"
  check "jq ${JQ_VERSION} installed to ${BIN_DIR}/jq"
}

# ---- Install ckad-drill itself --------------------------------------------

install_ckad_drill() {
  step "Installing ckad-drill"

  if [ -d "${INSTALL_DIR}/.git" ]; then
    echo "Updating existing installation at ${INSTALL_DIR}..."
    git -C "${INSTALL_DIR}" pull --ff-only
  else
    echo "Cloning ckad-drill to ${INSTALL_DIR}..."
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone "https://github.com/${GITHUB_REPO}.git" "${INSTALL_DIR}"
  fi

  # Create symlink for the main executable
  local link="${BIN_DIR}/ckad-drill"
  local target="${INSTALL_DIR}/bin/ckad-drill"

  if [ -L "${link}" ]; then
    # Update symlink if it points elsewhere
    local current_target
    current_target="$(readlink "${link}")"
    if [ "${current_target}" != "${target}" ]; then
      ln -sf "${target}" "${link}"
    fi
  else
    ln -sf "${target}" "${link}"
  fi

  chmod +x "${target}"
  check "ckad-drill installed: ${link} -> ${target}"
}

# ---- Main -----------------------------------------------------------------

main() {
  echo "ckad-drill installer"
  echo "===================="

  check_bash_version
  check_docker
  check_kubectl
  ensure_bin_dir
  install_kind
  install_yq
  install_jq
  install_ckad_drill

  echo ""
  check "Installation complete!"
  echo ""
  echo "Run: ckad-drill --help"
  echo ""

  # Remind user to update PATH if needed
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
      warn "Remember to add ${BIN_DIR} to your PATH before running ckad-drill."
      ;;
  esac
}

main "$@"

#!/usr/bin/env bash
#=============================================================================
# Lab 21: Install Minikube
# Install minikube and kubectl for local Kubernetes testing
#
# Usage: ./install-minikube.sh
# Prerequisites: RHEL 8, 9, 10, root privileges
#=============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

#=============================================================================
# CONFIGURATION
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Versions
readonly MINIKUBE_VERSION="latest"
readonly KUBECTL_VERSION="v1.28.0"

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

print_header ()
{
  local text="${1}"
  local width=57
  local padding=$(( width - ${#text} ))
  local pad=""
  if [[ ${padding} -gt 0 ]]; then
    pad="$(printf '%*s' "${padding}" '')"
  fi
  echo
  echo -e "${CYAN}┌─$(printf '─%.0s' $(seq 1 ${width}))─┐${NC}"
  echo -e "${CYAN}│${NC} ${BOLD}${text}${NC}${pad} ${CYAN}│${NC}"
  echo -e "${CYAN}└─$(printf '─%.0s' $(seq 1 ${width}))─┘${NC}"
  echo
}

print_step ()
{
  echo
  echo -e "  ${BOLD}▸ ${1}${NC}"
}

print_success ()
{
  echo -e "  ${GREEN}✓${NC} ${1}"
}

print_error ()
{
  echo -e "  ${RED}✗${NC} ${1}"
}

print_warning ()
{
  echo -e "  ${YELLOW}⚠${NC} ${1}"
}

print_info ()
{
  echo -e "  ${BLUE}ℹ${NC} ${1}"
}

error_exit ()
{
  print_error "${1}"
  exit 1
}

trap 'error_exit "Error occurred on line ${LINENO}"' ERR

#=============================================================================
# RHEL VERSION CHECK
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "This script requires Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 21: Install Minikube"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

MINIKUBE_FORCE=""
if [[ ${EUID} -eq 0 ]]; then
  print_warning "Running as root is not recommended for minikube."
  print_warning "Container drivers (podman/docker) may refuse to run as root."
  echo
  read -p "  Continue as root with --force? (y/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo
    echo "Re-run this script as a regular user instead."
    exit 0
  fi
  MINIKUBE_FORCE="--force"
fi
print_success "RHEL ${RHEL_VERSION} detected"
echo

# --- Step 2: Detect container runtime ---
print_step "Detect container runtime"

CONTAINER_DRIVER=""
if command -v docker &>/dev/null; then
  print_success "Docker found"
  CONTAINER_DRIVER="docker"
elif command -v podman &>/dev/null; then
  print_success "Podman found"
  CONTAINER_DRIVER="podman"
else
  # minikube needs a container runtime to host the Kubernetes node
  print_info "No container runtime found — installing podman..."
  sudo dnf install -y podman
  print_success "Podman installed"
  CONTAINER_DRIVER="podman"
fi
echo

# --- Step 3: Install kubectl ---
print_step "Install kubectl"

if command -v kubectl &>/dev/null; then
  print_success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  print_info "Downloading kubectl ${KUBECTL_VERSION}..."
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  print_success "kubectl installed"
fi
echo

# --- Step 4: Install minikube ---
print_step "Install minikube"

if command -v minikube &>/dev/null; then
  print_success "minikube already installed: $(minikube version --short)"
else
  print_info "Downloading minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube
  print_success "minikube installed"
fi
echo

# --- Step 5: Start minikube cluster ---
print_step "Start minikube cluster"

if minikube status &>/dev/null; then
  print_success "minikube is already running"
else
  print_info "Starting minikube with ${CONTAINER_DRIVER} driver..."
  # ingress addon enables TLS testing later without a separate install step
  if ! minikube start \
    --driver="${CONTAINER_DRIVER}" \
    --cpus=2 \
    --memory=2048 \
    --kubernetes-version=v1.28.0 \
    --addons=ingress \
    ${MINIKUBE_FORCE}; then
    echo
    print_error "Failed to start minikube."
    echo
    echo "  Common causes:"
    echo "    - Insufficient CPUs: Kubernetes requires at least 2 CPUs."
    echo "    - Insufficient memory: at least 2 GB of free RAM is needed."
    echo "    - Container runtime not running: ensure ${CONTAINER_DRIVER} is active."
    echo
    echo "  To check available resources:"
    echo "    nproc                  # available CPUs"
    echo "    free -h                # available memory"
    echo "    systemctl status ${CONTAINER_DRIVER}  # runtime status"
    echo
    echo "  To retry with fewer resources (not recommended for production):"
    echo "    minikube start --driver=${CONTAINER_DRIVER} --cpus=2 --memory=1800"
    exit 1
  fi
  print_success "minikube started"
fi
echo

# --- Step 6: Verify installation ---
print_step "Verify cluster is running"

if ! minikube status &>/dev/null; then
  error_exit "minikube is not running"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "kubectl cannot connect to cluster"
fi
if ! kubectl get nodes &>/dev/null; then
  error_exit "Cannot get cluster nodes"
fi
print_success "All checks passed"
echo

print_success "Minikube installation complete!"
echo
echo "Cluster information:"
kubectl cluster-info
echo
echo "Cluster nodes:"
kubectl get nodes
echo
echo "Next steps:"
echo "  - Run './install-cert-manager.sh' to install cert-manager"
echo "  - Use 'kubectl' commands to interact with the cluster"
echo "  - Run 'minikube dashboard' to open the Kubernetes dashboard"

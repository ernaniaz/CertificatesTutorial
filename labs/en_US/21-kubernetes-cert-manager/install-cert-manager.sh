#!/usr/bin/env bash
#=============================================================================
# Lab 21: Install Cert Manager
# Deploy cert-manager in Kubernetes cluster
#
# Usage: ./install-cert-manager.sh
# Prerequisites: RHEL 8, 9, 10
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

# cert-manager version
readonly CERT_MANAGER_VERSION="v1.14.1"
readonly CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

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

print_header "Lab 21: Install cert-manager"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found. Run ./install-minikube.sh first"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "Cannot connect to Kubernetes cluster. Is minikube running?"
fi
if ! minikube status &>/dev/null; then
  error_exit "minikube is not running. Run ./install-minikube.sh first"
fi
print_success "Prerequisites check passed"
echo

# --- Step 2: Install cert-manager ---
print_step "Install cert-manager"

print_info "Applying cert-manager ${CERT_MANAGER_VERSION} manifests..."
kubectl apply -f "${CERT_MANAGER_URL}"
print_success "cert-manager manifests applied"
echo

# --- Step 3: Wait for cert-manager pods ---
print_step "Wait for cert-manager pods"

print_info "Waiting for cert-manager pods to be ready (may take 1-2 minutes)..."
kubectl wait --for=condition=Ready --timeout=300s \
  namespace/cert-manager 2>/dev/null || true

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  print_info "Aguardando ${deployment}..."
  kubectl wait --for=condition=Available --timeout=300s \
    -n cert-manager "deployment/${deployment}"
  print_success "${deployment} is ready"
done
echo

# --- Step 4: Verify installation ---
print_step "Verify cert-manager installation"

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "CRD found: ${crd}"
  else
    error_exit "CRD not found: ${crd}"
  fi
done

print_info "Installed cert-manager CRDs:"
kubectl get crds | grep cert-manager || true

pod_count="$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l)"
if [[ ${pod_count} -ge 3 ]]; then
  print_success "All cert-manager pods are running (${pod_count} pods)"
else
  error_exit "Not enough cert-manager pods running (found ${pod_count}, expected 3+)"
fi
echo

print_success "cert-manager installation complete!"

echo
echo "cert-manager Status"
echo
kubectl get pods -n cert-manager
echo
kubectl get deployments -n cert-manager

echo
echo "Next steps:"
echo "  - Run './create-selfsigned-issuer.sh' to create a self-signed issuer"
echo "  - Run './create-ca-issuer.sh' to create a CA issuer"
echo "  - Run './create-letsencrypt-issuer.sh' to create a Let's Encrypt issuer"

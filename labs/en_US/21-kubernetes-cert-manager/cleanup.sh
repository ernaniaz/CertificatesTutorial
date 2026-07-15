#!/usr/bin/env bash
#=============================================================================
# Lab 21: Cleanup
# Remove all lab resources and optionally delete minikube
#
# Usage: ./cleanup.sh
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Full cleanup flag
FULL_CLEANUP=false
if [[ "${1:-}" == "--full" ]]; then
  FULL_CLEANUP=true
fi

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

print_header "Lab 21: Cleanup"

# --- Step 1: Delete Kubernetes resources ---
print_step "Delete Kubernetes resources"

if ! command -v kubectl &>/dev/null; then
  print_warning "kubectl not found, skipping Kubernetes cleanup"
else
  print_info "Removing test application and ingress..."
  kubectl delete deployment test-app -n default 2>/dev/null || true
  kubectl delete service test-app -n default 2>/dev/null || true
  kubectl delete ingress test-app-ingress -n default 2>/dev/null || true
  kubectl delete configmap test-app-html -n default 2>/dev/null || true

  print_info "Deleting certificates..."
  kubectl delete certificate --all -n default 2>/dev/null || true

  print_info "Deleting certificate secrets..."
  kubectl delete secret selfsigned-cert-tls -n default 2>/dev/null || true
  kubectl delete secret ca-signed-cert-tls -n default 2>/dev/null || true
  kubectl delete secret test-app-tls -n default 2>/dev/null || true
  kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true

  print_info "Deleting ClusterIssuers..."
  kubectl delete clusterissuer selfsigned-issuer 2>/dev/null || true
  kubectl delete clusterissuer ca-issuer 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-staging 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-production 2>/dev/null || true

  print_success "Kubernetes resources cleaned up"
  echo

  # --- Step 2: Uninstall cert-manager ---
  print_step "Uninstall cert-manager"

  if kubectl get namespace cert-manager &>/dev/null; then
    print_info "Deleting cert-manager namespace..."
    kubectl delete namespace cert-manager 2>/dev/null || true

    max_attempts=30
    attempt=0
    while kubectl get namespace cert-manager &>/dev/null && [[ ${attempt} -lt ${max_attempts} ]]; do
      sleep 1
      attempt=$((attempt + 1))
    done
    print_success "cert-manager removed"
  else
    print_info "cert-manager already removed"
  fi
  echo
fi

# --- Step 3: Clean up local files ---
print_step "Clean up local files"

if [[ -d "${SCRIPT_DIR}/ca-output" ]]; then
  rm -rf "${SCRIPT_DIR}/ca-output"
  print_success "Removed ca-output directory"
fi

if [[ -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml"
  print_success "Removed Let's Encrypt template"
fi
echo

# --- Step 4: Stop or delete minikube ---
print_step "Stop or delete minikube"

if [[ ${FULL_CLEANUP} == true ]]; then
  print_warning "Performing FULL cleanup — deleting minikube cluster..."
  if command -v minikube &>/dev/null; then
    minikube delete 2>/dev/null || true
    print_success "Minikube cluster deleted"
  else
    print_info "Minikube not installed"
  fi
else
  print_info "Stopping minikube (cluster preserved for quick restart)..."
  if command -v minikube &>/dev/null; then
    if minikube status &>/dev/null; then
      minikube stop
      print_success "Minikube stopped"
    else
      print_info "Minikube already stopped"
    fi
  else
    print_info "Minikube not installed"
  fi
fi
echo

# --- Step 5: Display summary ---
print_step "Display summary"

echo
echo "Cleanup Summary"
echo
if [[ ${FULL_CLEANUP} == true ]]; then
  print_success "Full cleanup completed"
  echo "  - Kubernetes resources deleted"
  echo "  - cert-manager removed"
  echo "  - Local files cleaned"
  echo "  - Minikube cluster deleted"
else
  print_success "Cleanup completed"
  echo "  - Kubernetes resources deleted"
  echo "  - cert-manager removed"
  echo "  - Local files cleaned"
  echo "  - Minikube stopped (not deleted)"
  echo
  print_info "To completely remove minikube:"
  echo "  ./cleanup.sh --full"
fi
echo

if [[ ${FULL_CLEANUP} == false ]]; then
  echo "To restart:"
  echo "  minikube start"
  echo "  ./install-cert-manager.sh"
  echo
  echo "To run lab again:"
  echo "  ./create-selfsigned-issuer.sh"
  echo "  ./create-ca-issuer.sh"
  echo "  ./request-certificate.sh"
fi

#!/usr/bin/env bash
#=============================================================================
# Lab 21: Create Selfsigned Issuer
# Create ClusterIssuer for self-signed certificates
#
# Usage: ./create-selfsigned-issuer.sh
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

print_header "Lab 21: Create Self-Signed Issuer"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager not installed. Run ./install-cert-manager.sh first"
fi
print_success "Prerequisites check passed"
echo

# --- Step 2: Create self-signed ClusterIssuer ---
print_step "Create self-signed ClusterIssuer"

print_info "Applying ClusterIssuer with spec.selfSigned..."
# selfSigned issuers need no external CA — ideal for local lab testing
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
print_success "Self-signed ClusterIssuer created"
echo

# --- Step 3: Wait for issuer to be ready ---
print_step "Wait for issuer to be ready"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer selfsigned-issuer \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Issuer is ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Issuer status unclear, but this is normal for self-signed issuers"
fi
echo

print_success "Self-signed issuer setup complete!"

echo
echo "Self-Signed Issuer Status"
echo
kubectl get clusterissuer
kubectl describe clusterissuer selfsigned-issuer

echo
echo "Usage:"
echo "  Reference this issuer in Certificate resources:"
echo "  issuerRef:"
echo "    name: selfsigned-issuer"
echo "    kind: ClusterIssuer"
echo
echo "Next steps:"
echo "  - Run './request-certificate.sh' to request a self-signed certificate"

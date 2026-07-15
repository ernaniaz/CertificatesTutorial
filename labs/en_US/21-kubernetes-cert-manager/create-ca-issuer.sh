#!/usr/bin/env bash
#=============================================================================
# Lab 21: Create Ca Issuer
# Create ClusterIssuer using a custom CA certificate
#
# Usage: ./create-ca-issuer.sh
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
readonly OUTPUT_DIR="${SCRIPT_DIR}/ca-output"

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

print_header "Lab 21: Create CA Issuer"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found"
fi
if ! command -v openssl &>/dev/null; then
  error_exit "openssl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager not installed. Run ./install-cert-manager.sh first"
fi
print_success "Prerequisites check passed"
echo

# --- Step 2: Generate CA certificate and key ---
print_step "Generate CA certificate and key"

print_info "Creating custom CA in ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"

# 4096-bit key matches common enterprise CA policies for lab realism
openssl genrsa -out "${OUTPUT_DIR}/ca.key" 4096
openssl req -x509 -new -nodes \
  -key "${OUTPUT_DIR}/ca.key" \
  -sha256 -days 3650 \
  -out "${OUTPUT_DIR}/ca.crt" \
  -subj "/C=US/ST=State/L=City/O=Lab Organization/CN=Lab CA"
print_success "CA certificate created"
echo

# --- Step 3: Store CA credentials in a Kubernetes secret ---
print_step "Create Kubernetes secret with CA"

print_info "Storing CA cert/key in secret ca-key-pair..."
kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true
kubectl create secret tls ca-key-pair \
  -n cert-manager \
  --cert="${OUTPUT_DIR}/ca.crt" \
  --key="${OUTPUT_DIR}/ca.key"
print_success "CA secret created"
echo

# --- Step 4: Create CA ClusterIssuer ---
print_step "Create CA ClusterIssuer"

print_info "Applying ClusterIssuer referencing ca-key-pair secret..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
print_success "CA ClusterIssuer created"
echo

# --- Step 5: Wait for issuer to be ready ---
print_step "Wait for issuer to be ready"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer ca-issuer \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Issuer is ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Issuer may still be initializing"
fi
echo

print_success "CA issuer setup complete!"

echo
echo "CA Certificate Information"
echo
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Subject:"
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Validity"
echo
echo "CA Issuer Status"
echo
kubectl get clusterissuer ca-issuer
kubectl describe clusterissuer ca-issuer

echo
echo "Usage:"
echo "  Reference this issuer in Certificate resources:"
echo "  issuerRef:"
echo "    name: ca-issuer"
echo "    kind: ClusterIssuer"
echo
echo "Next steps:"
echo "  - Run './request-certificate.sh' to request a CA-signed certificate"

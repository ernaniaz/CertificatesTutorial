#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configure Intermediate Ca
# Create and configure an intermediate CA
#
# Usage: ./configure-intermediate-ca.sh
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

print_header "Lab 22: Configure Intermediate CA"

# --- Step 1: Load Vault connection details ---
print_step "Loading Vault environment"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Environment loaded from vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Step 2: Verify root CA exists ---
print_step "Checking prerequisites"

if ! vault read pki/cert/ca &> /dev/null; then
  error_exit "Root CA not found. Run ./configure-root-ca.sh first"
fi

print_success "Root CA found"
echo

# --- Step 3: Enable intermediate PKI engine ---
print_step "Enabling intermediate PKI secrets engine"

if vault secrets list | grep -q "^pki_int/"; then
  print_warning "Intermediate PKI already enabled"
else
  if ! vault secrets enable -path=pki_int pki; then
    error_exit "Failed to enable intermediate PKI secrets engine"
  fi
  print_success "Intermediate PKI enabled at: pki_int/"
fi
echo

# --- Step 4: Tune intermediate PKI lease TTL ---
print_step "Configuring intermediate PKI lease TTL"

# Intermediate CAs typically have shorter lifetimes than the root
if ! vault secrets tune -max-lease-ttl=43800h pki_int; then
  error_exit "Failed to tune intermediate PKI max lease TTL"
fi

print_success "Max lease TTL set to: 43800h (5 years)"
echo

# --- Step 5: Generate intermediate CSR ---
print_step "Generating intermediate CA CSR"

if ! vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Lab Intermediate CA" \
  issuer_name="intermediate-2025" \
  > "${SCRIPT_DIR}/intermediate.csr"; then
  error_exit "Failed to generate intermediate CSR"
fi

print_success "Intermediate CSR generated"
print_info "CSR saved to: intermediate.csr"
echo

# --- Step 6: Sign CSR with root CA ---
print_step "Signing intermediate CSR with root CA"

# Root signs the intermediate — standard two-tier PKI hierarchy
if ! vault write -field=certificate pki/root/sign-intermediate \
  issuer_ref="root-2025" \
  csr=@"${SCRIPT_DIR}/intermediate.csr" \
  format=pem_bundle \
  ttl=43800h \
  > "${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Failed to sign intermediate CSR"
fi

print_success "Intermediate certificate signed"
print_info "Certificate saved to: intermediate.crt"
echo

# --- Step 7: Import signed certificate into intermediate engine ---
print_step "Setting intermediate certificate"

if ! vault write pki_int/intermediate/set-signed \
  certificate=@"${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Failed to set intermediate certificate"
fi

print_success "Intermediate certificate set"
echo

# --- Step 8: Configure intermediate CA URLs ---
print_step "Configuring intermediate CA URLs"

if ! vault write pki_int/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"; then
  error_exit "Failed to configure intermediate CA URLs"
fi

print_success "Intermediate URLs configured"
echo

print_success "Intermediate CA configuration complete"
echo

# --- Step 9: Display intermediate CA info and verify chain ---
print_step "Intermediate CA information"

print_info "Certificate details:"
openssl x509 -in "${SCRIPT_DIR}/intermediate.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "CA URL configuration:"
vault read pki_int/config/urls
echo
print_info "Intermediate CA from Vault:"
vault read pki_int/cert/ca
echo

print_step "Verifying certificate chain"

if openssl verify -CAfile "${SCRIPT_DIR}/root-ca.crt" "${SCRIPT_DIR}/intermediate.crt" &> /dev/null; then
  print_success "Certificate chain is valid"
else
  print_warning "Certificate chain verification had issues (may be normal in dev mode)"
fi

echo
echo "Next steps:"
echo "  - Run './create-role.sh' to create a PKI role"
echo "  - View intermediate CA: vault read pki_int/cert/ca"

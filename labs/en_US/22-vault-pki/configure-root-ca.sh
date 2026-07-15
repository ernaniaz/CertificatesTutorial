#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configure Root Ca
# Generate and configure root CA
#
# Usage: ./configure-root-ca.sh
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

print_header "Lab 22: Configure Root CA"

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

# --- Step 2: Verify PKI engine is enabled ---
print_step "Checking prerequisites"

if ! vault secrets list | grep -q "^pki/"; then
  error_exit "PKI secrets engine not enabled. Run ./enable-pki.sh first"
fi

print_success "PKI secrets engine found"
echo

# --- Step 3: Generate internal root CA ---
print_step "Generating root CA certificate"

# Internal generation keeps the private key inside Vault — never exported to disk
if ! vault write -field=certificate pki/root/generate/internal \
  common_name="Lab Root CA" \
  issuer_name="root-2025" \
  ttl=87600h \
  > "${SCRIPT_DIR}/root-ca.crt"; then
  error_exit "Failed to generate root CA"
fi

print_success "Root CA generated"
print_info "Root CA saved to: root-ca.crt"
echo

# --- Step 4: Configure CA and CRL distribution URLs ---
print_step "Configuring CA URLs"

# Clients need these URLs to build trust chains and check revocation
if ! vault write pki/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"; then
  error_exit "Failed to configure CA URLs"
fi

print_success "CA URLs configured"
echo

print_success "Root CA configuration complete"
echo

# --- Step 5: Display root CA information ---
print_step "Root CA information"

print_info "Certificate details:"
openssl x509 -in "${SCRIPT_DIR}/root-ca.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "CA URL configuration:"
vault read pki/config/urls
echo
print_info "Root CA from Vault:"
vault read pki/cert/ca

echo
echo "Next steps:"
echo "  - Run './configure-intermediate-ca.sh' to create intermediate CA"
echo "  - View CA: vault read pki/cert/ca"

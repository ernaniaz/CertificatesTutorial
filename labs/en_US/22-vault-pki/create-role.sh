#!/usr/bin/env bash
#=============================================================================
# Lab 22: Create Role
# Create role for certificate issuance
#
# Usage: ./create-role.sh
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

# Role configuration
ROLE_NAME="${1:-web-server}"

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

print_header "Lab 22: Create PKI Role"

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

# --- Step 2: Verify intermediate CA is ready ---
print_step "Checking prerequisites"

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "Intermediate CA not found. Run ./configure-intermediate-ca.sh first"
fi

print_success "Intermediate CA found"
echo

# --- Step 3: Create PKI role ---
print_step "Creating PKI role: ${ROLE_NAME}"

# Roles constrain what certificates Vault may issue — domains, TTL, key type, etc.
if ! vault write "pki_int/roles/${ROLE_NAME}" \
  allowed_domains="example.com,lab.local" \
  allow_subdomains=true \
  max_ttl="72h" \
  ttl="24h" \
  key_type="rsa" \
  key_bits=2048 \
  allow_ip_sans=true \
  server_flag=true \
  client_flag=true \
  code_signing_flag=false \
  email_protection_flag=false; then
  error_exit "Failed to create PKI role '${ROLE_NAME}'"
fi

print_success "PKI role '${ROLE_NAME}' created"
echo

print_success "PKI role configuration complete"
echo

# --- Step 4: Display role information ---
print_step "PKI role information"

print_info "Role: ${ROLE_NAME}"
echo
vault read "pki_int/roles/${ROLE_NAME}"
echo

# --- Step 5: Show usage examples ---
print_step "Usage examples"

print_info "Issue a certificate:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server01.lab.local\" \\"
echo "    ttl=\"24h\""
echo
print_info "Issue with IP SAN:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server02.lab.local\" \\"
echo "    ip_sans=\"192.168.1.100\" \\"
echo "    ttl=\"24h\""
echo
print_info "Issue short-lived certificate:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"temp.lab.local\" \\"
echo "    ttl=\"1h\""

echo
echo "Next steps:"
echo "  - Run './issue-certificate.sh' to issue certificates"
echo "  - List roles: vault list pki_int/roles"
echo "  - Read role: vault read pki_int/roles/${ROLE_NAME}"

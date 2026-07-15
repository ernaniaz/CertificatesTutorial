#!/usr/bin/env bash
#=============================================================================
# Lab 22: Revoke Certificate
# Demonstrate certificate revocation
#
# Usage: ./revoke-certificate.sh
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
readonly CERTS_DIR="${SCRIPT_DIR}/certs"

# Serial number
SERIAL_NUMBER="${1:-}"

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

print_header "Lab 22: Revoke Certificate"

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

# --- Step 2: Verify Vault is running ---
print_step "Checking Vault status"

if ! vault status &> /dev/null; then
  error_exit "Vault is not running. Run ./start-vault-dev.sh first"
fi

print_success "Vault is running"
echo

# --- Step 3: Find serial number if not provided ---
if [[ -z "${SERIAL_NUMBER}" ]]; then
  print_step "Finding certificate to revoke"

  latest_serial_file="$(find "${CERTS_DIR}" -maxdepth 1 -name '*.serial' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | awk '{print $2}')"

  if [[ -z "${latest_serial_file}" ]] || [[ ! -f "${latest_serial_file}" ]]; then
    error_exit "No certificates found. Run ./issue-certificate.sh first"
  fi

  SERIAL_NUMBER="$(cat "${latest_serial_file}")"
  print_success "Using most recent certificate: $(basename "${latest_serial_file%.serial}")"
  echo
fi

print_info "Serial number: ${SERIAL_NUMBER}"
echo

# --- Step 4: Confirm revocation with user ---
print_step "Confirming revocation"

print_warning "This will revoke the certificate!"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  print_info "Revocation cancelled"
  exit 0
fi
echo

# --- Step 5: Revoke certificate ---
print_step "Revoking certificate"

if ! vault write pki_int/revoke serial_number="${SERIAL_NUMBER}"; then
  error_exit "Failed to revoke certificate ${SERIAL_NUMBER}"
fi

print_success "Certificate revoked"
echo

# --- Step 6: Read and display CRL ---
print_step "Reading Certificate Revocation List"

if ! vault read -field=certificate pki_int/cert/crl > "${SCRIPT_DIR}/crl.pem"; then
  error_exit "Failed to read CRL from Vault"
fi

print_success "CRL saved to: crl.pem"
echo
print_info "CRL contents:"
openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | head -n 20
echo

# --- Step 7: Verify revocation in CRL ---
print_step "Verifying revocation"

print_info "Checking if serial ${SERIAL_NUMBER} appears in CRL..."

if openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | grep -q "${SERIAL_NUMBER}"; then
  print_success "Certificate found in CRL (revoked)"
else
  print_warning "Certificate not found in CRL"
fi
echo

# --- Step 8: Display revocation information ---
print_step "Revocation information"

print_info "Certificate Revocation:"
echo "  - Revoked certificates are added to the CRL"
echo "  - CRL URL: http://127.0.0.1:8200/v1/pki_int/crl"
echo "  - Applications must check CRL or use OCSP"
echo
print_info "Download CRL:"
echo "  curl http://127.0.0.1:8200/v1/pki_int/crl > crl.pem"
echo
print_info "View CRL:"
echo "  openssl crl -in crl.pem -noout -text"

echo
print_success "Certificate revocation demonstrated"
echo
echo "Next steps:"
echo "  - Run './verify.sh' to validate the entire lab"
echo "  - Issue new certificates: ./issue-certificate.sh"

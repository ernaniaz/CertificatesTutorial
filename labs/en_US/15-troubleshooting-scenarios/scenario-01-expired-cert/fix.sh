#!/usr/bin/env bash
#=============================================================================
# Lab 15: Fix
# Scenario 01: Fix expired certificate
#
# Usage: ./fix.sh
# Prerequisites: RHEL 7, 8, 9, 10, root privileges
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9, 10."
fi

#=============================================================================
# MAIN
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"
KEY_FILE="/etc/pki/tls/private/expired.key"

print_header "Scenario 01: Fixing Expired Certificate"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Step 1: Backup old certificate"
cp "${CERT_FILE}" "${CERT_FILE}.old"
print_success "Backed up to ${CERT_FILE}.old"
echo

print_info "Step 2: Generate new certificate (365 days validity)"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -days 365 \
  -subj "/CN=expired.example.com" 2>/dev/null

chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

print_success "New certificate generated"
echo

print_info "Step 3: Verify new certificate"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "New certificate is valid"
else
  print_error "Something went wrong"
  exit 1
fi

echo
print_success "Certificate renewed successfully"
echo
echo "Next steps:"
echo "  1. Restart services using this certificate"
echo "  2. Test connections"
echo "  3. Run ./verify-fix.sh to confirm"
echo
echo "Prevention:"
echo "  - Use certmonger/certbot for auto-renewal"
echo "  - Monitor expiration dates"
echo "  - Renew 30 days before expiration"

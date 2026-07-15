#!/usr/bin/env bash
#=============================================================================
# Lab 11: Test Renewal
# Force renewal of tracked certificate
#
# Usage: ./test-renewal.sh
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
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

CERT_FILE="/etc/pki/certmonger/self-signed.crt"

print_header "Lab 11: Test Certificate Renewal"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check if certificate is tracked
if ! getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_error "Error: Certificate ${CERT_FILE} is not tracked"
  echo "Run ./request-self-signed.sh first"
  exit 1
fi

# Get request ID
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

echo "Request ID: ${REQUEST_ID}"
echo "Certificate: ${CERT_FILE}"
echo

# Show current certificate dates
if [[ -f "${CERT_FILE}" ]]; then
  print_info "Current certificate:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_BEFORE="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_BEFORE}"
  echo
fi

# Force renewal
print_info "Forcing certificate renewal..."
getcert resubmit -i "${REQUEST_ID}"

print_success "Renewal request submitted"
echo

# Wait for renewal
print_info "Waiting for renewal to complete..."
sleep 5

# Check new status
echo "New status:"
STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
echo " ${STATUS}"

# Check if certificate was renewed
if [[ -f "${CERT_FILE}" ]]; then
  echo
  print_info "Renewed certificate:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_AFTER}"

  echo
  if [[ "${SERIAL_BEFORE}" != "${SERIAL_AFTER}" ]]; then
    print_success "Certificate was renewed (serial number changed)"
  else
    print_warning "Serial number unchanged (renewal may not have completed)"
  fi
fi

echo
print_success "Renewal test complete"
echo
echo "Monitor renewal with:"
echo "  journalctl -u certmonger -f"
echo "  getcert list -i ${REQUEST_ID}"

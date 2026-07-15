#!/usr/bin/env bash
#=============================================================================
# Lab 11: Request Self Signed
# Use certmonger to track a self-signed certificate
#
# Usage: ./request-self-signed.sh
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

CERT_DIR="/etc/pki/certmonger"
CERT_FILE="${CERT_DIR}/self-signed.crt"
KEY_FILE="${CERT_DIR}/self-signed.key"

print_header "Lab 11: Request Self-Signed Certificate"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Create directory
print_info "Creating certificate directory..."
mkdir -p "${CERT_DIR}"
chmod 755 "${CERT_DIR}"

# Check if already requested
if getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_warning "Certificate already tracked, stopping tracking first..."
  getcert stop-tracking -f "${CERT_FILE}"
fi

echo

# Request self-signed certificate
print_info "Requesting self-signed certificate..."

getcert request \
  -f "${CERT_FILE}" \
  -k "${KEY_FILE}" \
  -c local \
  -N CN=self-signed.example.com \
  -D self-signed.example.com \
  -D localhost \
  -U id-kp-serverAuth

print_success "Certificate request submitted"
echo

# Wait for certificate to be issued
print_info "Waiting for certificate to be issued..."
sleep 3

# Check status
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

if [[ -n "${REQUEST_ID}" ]]; then
  echo "Request ID: ${REQUEST_ID}"

  # Get status
  STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
  echo "Status: ${STATUS}"

  if [[ "${STATUS}" == "MONITORING" ]]; then
    print_success "Certificate successfully issued and monitored"
  else
    print_warning "Status: ${STATUS}"
  fi
fi

echo

# Display certificate details
if [[ -f "${CERT_FILE}" ]]; then
  print_success "Certificate file created"
  echo
  echo "Certificate details:"
  openssl x509 -in "${CERT_FILE}" -noout -subject -dates -ext subjectAltName 2>/dev/null || openssl x509 -in "${CERT_FILE}" -noout -subject -dates

  echo
  echo "File locations:"
  echo "  Certificate: ${CERT_FILE}"
  echo "  Private key: ${KEY_FILE}"
else
  print_warning "Certificate file not yet created"
fi

echo
print_success "Self-signed certificate request complete"
echo
echo "Check status with:"
echo "  getcert list"
echo "  getcert list -i ${REQUEST_ID}"

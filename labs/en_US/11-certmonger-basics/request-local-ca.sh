#!/usr/bin/env bash
#=============================================================================
# Lab 11: Request Local Ca
# Use certmonger with local CA helper
#
# Usage: ./request-local-ca.sh
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
CA_CERT_FILE="${CERT_DIR}/local-ca.crt"
CA_KEY_FILE="${CERT_DIR}/local-ca.key"
CERT_FILE="${CERT_DIR}/local-ca-signed.crt"
KEY_FILE="${CERT_DIR}/local-ca-signed.key"

print_header "Lab 11: Request from Local CA"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Create directory
mkdir -p "${CERT_DIR}"

# Check if CA exists from Lab 05
PREV_CA_DIR="../05-trust-store/output"
if [[ -f "${PREV_CA_DIR}/ca.crt" && -f "${PREV_CA_DIR}/ca.key" ]]; then
  print_info "Using CA from Lab 05..."
  cp "${PREV_CA_DIR}/ca.crt" "${CA_CERT_FILE}"
  cp "${PREV_CA_DIR}/ca.key" "${CA_KEY_FILE}"
  chmod 600 "${CA_KEY_FILE}"
  print_success "CA files copied"
else
  # Create simple local CA if needed
  print_info "Creating local CA..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CA_KEY_FILE}" \
    -out "${CA_CERT_FILE}" \
    -days 365 \
    -subj "/CN=Lab11 Local CA"
  chmod 600 "${CA_KEY_FILE}"
  print_success "Local CA created"
fi

echo

# Check if already requested
if getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_warning "Certificate already tracked, stopping tracking first..."
  getcert stop-tracking -f "${CERT_FILE}"
fi

# Request certificate using local CA (self-signed for lab purposes)
print_info "Requesting certificate from local CA..."

# Note: Using 'local' CA which is actually self-signed
# In production, you'd use IPA or external CA
getcert request \
  -f "${CERT_FILE}" \
  -k "${KEY_FILE}" \
  -c local \
  -N CN=local-ca-server.example.com \
  -D local-ca-server.example.com \
  -D localhost \
  -U id-kp-serverAuth \
  -T 90

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

  if [[ ${STATUS} == MONITORING ]]; then
    print_success "Certificate successfully issued and monitored"

    # Show expiration
    EXPIRES="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    echo "Expires: ${EXPIRES}"
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
  openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates 2>/dev/null

  echo
  echo "File locations:"
  echo "  Certificate: ${CERT_FILE}"
  echo "  Private key: ${KEY_FILE}"
  echo "  CA cert: ${CA_CERT_FILE}"
else
  print_warning "Certificate file not yet created"
fi

echo
print_success "Local CA certificate request complete"
echo
echo "Check status with:"
echo "  getcert list"
echo "  getcert list -i ${REQUEST_ID}"

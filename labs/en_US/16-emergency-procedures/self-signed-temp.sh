#!/usr/bin/env bash
#=============================================================================
# Lab 16: Self Signed Temp
# Quick self-signed certificate for emergencies
#
# Usage: ./self-signed-temp.sh
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

print_header "Lab 16: Temporary Self-Signed Certificate"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_warning "Creating temporary self-signed certificate"
echo "Use this when CA is unreachable and you need immediate cert"
echo

# Get domain name
read -p "Domain name (or press Enter for hostname): " DOMAIN
if [[ -z "${DOMAIN}" ]]; then
  DOMAIN="$(hostname)"
fi

echo
echo "Creating certificate for: ${DOMAIN}"
echo

# Generate temporary certificate
print_info "Generating certificate..."

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost" 2>/dev/null || \
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" 2>/dev/null

chmod 644 "${CERT_DIR}/temp-${DOMAIN}.crt"
chmod 600 "${KEY_DIR}/temp-${DOMAIN}.key"

print_success "Temporary certificate created"
echo

# Display certificate info
echo "Certificate details:"
openssl x509 -in "${CERT_DIR}/temp-${DOMAIN}.crt" -noout -subject -dates
echo

print_success "Certificate files created"
echo
echo "Certificate: ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "Private key: ${KEY_DIR}/temp-${DOMAIN}.key"
echo
print_warning "TEMPORARY 30-DAY CERTIFICATE"
echo "Replace with proper CA-signed certificate ASAP"
echo
echo "Deploy to service:"
echo "  # For Apache"
echo "  SSLCertificateFile ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "  SSLCertificateKeyFile ${KEY_DIR}/temp-${DOMAIN}.key"
echo
echo "  # For NGINX"
echo "  ssl_certificate ${CERT_DIR}/temp-${DOMAIN}.crt;"
echo "  ssl_certificate_key ${KEY_DIR}/temp-${DOMAIN}.key;"

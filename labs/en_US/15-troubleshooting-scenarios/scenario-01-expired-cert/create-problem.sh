#!/usr/bin/env bash
#=============================================================================
# Lab 15: Create Problem
# Scenario 01: Create expired certificate problem
#
# Usage: ./create-problem.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_FILE="/etc/pki/tls/certs/expired.crt"
KEY_FILE="/etc/pki/tls/private/expired.key"

print_header "Scenario 01: Creating Expired Certificate"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Creating an expired certificate..."

# OpenSSL 1.1.1+ (RHEL 8+) rejects -days 0, so we use openssl ca with
# explicit past dates to create an already-expired certificate portably.
WORK_DIR=$(mktemp -d)
mkdir -p "${WORK_DIR}/newcerts"
touch "${WORK_DIR}/index.txt"
echo "01" > "${WORK_DIR}/serial"

openssl genrsa -out "${KEY_FILE}" 2048 2>/dev/null

openssl req -new -key "${KEY_FILE}" \
  -out "${WORK_DIR}/expired.csr" \
  -subj "/CN=expired.example.com" 2>/dev/null

openssl req -x509 -new -key "${KEY_FILE}" \
  -out "${WORK_DIR}/ca.crt" -days 3650 \
  -subj "/CN=Lab 15 CA" 2>/dev/null

cat > "${WORK_DIR}/ca.cnf" << CONF
[ca]
default_ca = mini

[mini]
dir              = ${WORK_DIR}
database         = \$dir/index.txt
serial           = \$dir/serial
new_certs_dir    = \$dir/newcerts
certificate      = \$dir/ca.crt
private_key      = ${KEY_FILE}
default_md       = sha256
policy           = pol

[pol]
commonName = supplied
CONF

openssl ca -batch -notext \
  -config "${WORK_DIR}/ca.cnf" \
  -startdate 230101000000Z \
  -enddate 230102000000Z \
  -in "${WORK_DIR}/expired.csr" \
  -out "${CERT_FILE}" 2>/dev/null

rm -rf "${WORK_DIR}"

chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

print_success "Created expired certificate"
echo
echo "Certificate location: ${CERT_FILE}"
echo "Private key location: ${KEY_FILE}"
echo

# Show that it's expired
print_info "Certificate details:"
openssl x509 -in "${CERT_FILE}" -noout -dates

echo
print_error "⚠ Problem created: Certificate is expired!"
echo
echo "Next steps:"
echo "  1. Run ./diagnose.sh to investigate"
echo "  2. Run ./fix.sh to resolve"
echo "  3. Run ./verify-fix.sh to confirm"

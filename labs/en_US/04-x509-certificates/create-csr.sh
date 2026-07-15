#!/usr/bin/env bash
#=============================================================================
# Lab 04: CSR creation
# Generate CSR to submit to a Certificate Authority
#
# Usage: ./create-csr.sh
# Prerequisites: RHEL 7, 8, 9, 10
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

KEY_DIR="../02-key-generation/output"
OUTPUT_DIR="output"
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 04: Creating Certificate Signing Request"

# Check prerequisites
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: RSA key not found. Run Lab 02 first."
  exit 1
fi

# Create OpenSSL config for CSR with SANs
cat > "${OUTPUT_DIR}/csr.cnf" << 'EOF'
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Lab Organization
OU = Certificate Lab
CN = server.example.com
emailAddress = admin@example.com

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
DNS.3 = mail.example.com
IP.1 = 192.168.1.100
EOF

print_info "Generating Certificate Signing Request..."
echo

# Generate CSR
openssl req -new -sha256 \
  -key "${KEY_DIR}/rsa-2048.key" \
  -out "${OUTPUT_DIR}/server.csr" \
  -config "${OUTPUT_DIR}/csr.cnf"

print_success "CSR created: output/server.csr"
echo

# Display CSR info
echo "CSR details:"
openssl req -in "${OUTPUT_DIR}/server.csr" -noout -subject
echo
echo "Subject Alternative Names in CSR:"
if ! openssl req -in "${OUTPUT_DIR}/server.csr" -noout -text | grep -A 3 "Subject Alternative Name"; then
  echo "  (SANs included in request)"
fi
echo

print_success "CSR creation complete"
echo
echo "Next steps (in production):"
echo "  1. Submit server.csr to your Certificate Authority"
echo "  2. CA validates your identity"
echo "  3. CA signs and returns server.crt"
echo "  4. Install server.crt on your server"

#!/usr/bin/env bash
#=============================================================================
# Lab 04: Self-signed certificate
# Generate self-signed X.509 certificate with SANs
#
# Usage: ./create-self-signed.sh
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

print_header "Lab 04: Creating Self-Signed Certificate"

# Check prerequisites
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: RSA key not found. Run Lab 02 first."
  exit 1
fi

# Create OpenSSL config for SANs
cat > "${OUTPUT_DIR}/san.cnf" << 'EOF'
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

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
DNS.3 = *.example.com
IP.1 = 192.168.1.100
EOF

print_info "Generating self-signed certificate..."
echo

# Generate self-signed certificate with SANs
openssl req -new -x509 -sha256 \
  -key "${KEY_DIR}/rsa-2048.key" \
  -out "${OUTPUT_DIR}/server.crt" \
  -days 365 \
  -config "${OUTPUT_DIR}/san.cnf" \
  -extensions v3_req

print_success "Self-signed certificate created: output/server.crt"
echo

# Display certificate info
echo "Certificate details:"
openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -subject -issuer -dates
echo
echo "Subject Alternative Names:"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -text | grep -A2 "Subject Alternative Name"
else
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -ext subjectAltName
fi
echo

# RHEL version specific notes
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_success "RHEL 9+ detected: Certificate includes required SANs"
fi

echo
print_success "Self-signed certificate creation complete"
echo
echo "Validity: 365 days from today"
echo "Algorithm: SHA-256 with RSA (2048-bit)"

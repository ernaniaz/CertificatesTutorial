#!/usr/bin/env bash
#=============================================================================
# Lab 02: RSA key generation
# Generate RSA key pairs of different sizes
#
# Usage: ./generate-rsa-keys.sh
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

OUTPUT_DIR="output"
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 02: Generating RSA Keys"

# Generate 2048-bit RSA key (minimum for production)
print_info "Generating 2048-bit RSA key..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/rsa-2048.key" \
  -pkeyopt rsa_keygen_bits:2048

# Extract public key
openssl pkey -in "${OUTPUT_DIR}/rsa-2048.key" \
  -pubout -out "${OUTPUT_DIR}/rsa-2048.pub"

print_success "RSA 2048-bit key pair generated"
echo

# Generate 4096-bit RSA key (recommended for high security)
print_info "Generating 4096-bit RSA key..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/rsa-4096.key" \
  -pkeyopt rsa_keygen_bits:4096

# Extract public key
openssl pkey -in "${OUTPUT_DIR}/rsa-4096.key" \
  -pubout -out "${OUTPUT_DIR}/rsa-4096.pub"

print_success "RSA 4096-bit key pair generated"
echo

# Secure permissions
chmod 600 "${OUTPUT_DIR}"/*.key 2>/dev/null || true
chmod 644 "${OUTPUT_DIR}"/*.pub 2>/dev/null || true

echo "Keys generated in ${OUTPUT_DIR}/"
echo "  Private keys: rsa-2048.key, rsa-4096.key (mode 600)"
echo "  Public keys:  rsa-2048.pub, rsa-4096.pub (mode 644)"
echo
print_success "RSA key generation complete"

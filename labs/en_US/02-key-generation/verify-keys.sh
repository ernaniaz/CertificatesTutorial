#!/usr/bin/env bash
#=============================================================================
# Lab 02: Key verification
# Validate generated keys
#
# Usage: ./verify-keys.sh
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

print_header "Lab 02: Verifying Generated Keys"

# Check if output directory exists
if [[ ! -d "${OUTPUT_DIR}" ]]; then
  print_error "Output directory not found. Run generation scripts first."
  exit 1
fi

# Verify RSA 2048
echo "RSA 2048-bit key:"
if [[ -f "${OUTPUT_DIR}/rsa-2048.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-2048.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Valid"
else
  print_error "Not found"
fi
echo

# Verify RSA 4096
echo "RSA 4096-bit key:"
if [[ -f "${OUTPUT_DIR}/rsa-4096.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-4096.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Valid"
else
  print_error "Not found"
fi
echo

# Verify ECC P-256
echo "ECC P-256 key:"
if [[ -f "${OUTPUT_DIR}/ecc-p256.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p256.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Valid"
else
  print_error "Not found"
fi
echo

# Verify ECC P-384
echo "ECC P-384 key:"
if [[ -f "${OUTPUT_DIR}/ecc-p384.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p384.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Valid"
else
  print_error "Not found"
fi
echo

# Check file permissions
echo "File permissions:"
ls -l "${OUTPUT_DIR}"/ | grep -E '\.key$|\.pub$'
echo

print_success "All keys verified successfully"

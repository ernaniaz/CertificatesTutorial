#!/usr/bin/env bash
#=============================================================================
# Lab 03: File signature
# Create digital signature of a sample file
#
# Usage: ./sign-file.sh
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
SAMPLE_FILE="sample-data.txt"
SIGNATURE_FILE="sample-data.sig"

print_header "Lab 03: Creating Digital Signature"

# Check prerequisites
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: RSA key not found. Run Lab 02 first."
  exit 1
fi

if [[ ! -f "${SAMPLE_FILE}" ]]; then
  print_error "Error: Sample file not found."
  exit 1
fi

# Sign the file with RSA private key using SHA-256
print_info "Signing ${SAMPLE_FILE} with RSA-2048 key..."
openssl dgst -sha256 \
  -sign "${KEY_DIR}/rsa-2048.key" \
  -out "${SIGNATURE_FILE}" \
  "${SAMPLE_FILE}"

print_success "File signed: ${SIGNATURE_FILE}"
echo
echo "Signature details:"
echo "  Algorithm: SHA-256 with RSA"
echo "  Size: $(stat -f%z "${SIGNATURE_FILE}" 2>/dev/null || stat -c%s "${SIGNATURE_FILE}") bytes"
echo
echo "Signature (first 80 bytes in hex):"
hexdump -C "${SIGNATURE_FILE}" | head -n 5
echo
print_success "Signature creation complete"
echo
echo "Next: Run ./verify-signature.sh to verify"

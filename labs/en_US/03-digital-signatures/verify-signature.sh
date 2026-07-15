#!/usr/bin/env bash
#=============================================================================
# Lab 03: Signature verification
# Verify digital signature
#
# Usage: ./verify-signature.sh
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

print_header "Lab 03: Verifying Digital Signature"

# Check prerequisites
if [[ ! -f "${KEY_DIR}/rsa-2048.pub" ]]; then
  print_error "Error: Public key not found. Run Lab 02 first."
  exit 1
fi

if [[ ! -f "${SIGNATURE_FILE}" ]]; then
  print_error "Error: Signature file not found. Run ./sign-file.sh first."
  exit 1
fi

# Verify signature with public key
print_info "Verifying signature with public key..."
echo

if openssl dgst -sha256 \
  -verify "${KEY_DIR}/rsa-2048.pub" \
  -signature "${SIGNATURE_FILE}" \
  "${SAMPLE_FILE}"; then
  echo
  print_success "Signature verification successful!"
  echo
  echo "This proves:"
  echo "  ✓ File was signed by the holder of the private key"
  echo "  ✓ File has not been modified since signing"
  echo "  ✓ File integrity is intact"
else
  echo
  print_error "Signature verification FAILED"
  echo "This indicates tampering or wrong key"
  exit 1
fi

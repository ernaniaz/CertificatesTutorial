#!/usr/bin/env bash
#=============================================================================
# Lab 04: Format conversion
# Convert between PEM and DER formats
#
# Usage: ./convert-formats.sh
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
CERT_PEM="${OUTPUT_DIR}/server.crt"
CERT_DER="${OUTPUT_DIR}/server.der"
CERT_BACK="${OUTPUT_DIR}/server-from-der.pem"

print_header "Lab 04: Certificate Format Conversion"

# Check if certificate exists
if [[ ! -f "${CERT_PEM}" ]]; then
  print_error "Error: Certificate not found. Run ./create-self-signed.sh first"
  exit 1
fi

# Convert PEM to DER
print_info "Converting PEM to DER (binary format)..."
openssl x509 -in "${CERT_PEM}" -outform DER -out "${CERT_DER}"
print_success "Created: ${CERT_DER}"
echo

# Convert DER back to PEM
print_info "Converting DER back to PEM..."
openssl x509 -in "${CERT_DER}" -inform DER -out "${CERT_BACK}"
print_success "Created: ${CERT_BACK}"
echo

# Compare file sizes
echo "File size comparison:"
PEM_SIZE=$(stat -f%z "${CERT_PEM}" 2>/dev/null || stat -c%s "${CERT_PEM}")
DER_SIZE=$(stat -f%z "${CERT_DER}" 2>/dev/null || stat -c%s "${CERT_DER}")
echo "  PEM (Base64): ${PEM_SIZE} bytes"
echo "  DER (Binary): ${DER_SIZE} bytes"
echo

# Verify they contain the same certificate
echo "Verifying certificate content..."
PEM_HASH=$(openssl x509 -in "${CERT_PEM}" -noout -fingerprint -sha256 | cut -d= -f2)
DER_HASH=$(openssl x509 -in "${CERT_DER}" -inform DER -noout -fingerprint -sha256 | cut -d= -f2)

if [[ "${PEM_HASH}" == "${DER_HASH}" ]]; then
  print_success "Certificates match (same content, different encoding)"
else
  print_error "Certificates don't match"
  exit 1
fi
echo

# Display format characteristics
echo "Format Characteristics:"
echo
echo "PEM (Privacy Enhanced Mail):"
echo "  - Base64-encoded text"
echo "  - Has -----BEGIN/END----- headers"
echo "  - Human-readable (can view in text editor)"
echo "  - Most common on RHEL/Linux"
echo "  - Used by: Apache, NGINX, most Linux tools"
echo
echo "DER (Distinguished Encoding Rules):"
echo "  - Binary format"
echo "  - Smaller file size"
echo "  - Not human-readable"
echo "  - Used by: Java, Windows, some embedded devices"
echo

print_success "Format conversion complete"

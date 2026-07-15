#!/usr/bin/env bash
#=============================================================================
# Lab 04: Certificate inspection
# Show detailed certificate information
#
# Usage: ./inspect-cert.sh
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
CERT_FILE="${OUTPUT_DIR}/server.crt"

print_header "Lab 04: Certificate Inspection"

# Check if certificate exists
if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Error: Certificate not found. Run ./create-self-signed.sh first"
  exit 1
fi

# Subject
print_info "Subject (Who the certificate identifies):"
openssl x509 -in "${CERT_FILE}" -noout -subject
echo

# Issuer
print_info "Issuer (Who signed the certificate):"
openssl x509 -in "${CERT_FILE}" -noout -issuer
echo

# Validity dates
print_info "Validity Period:"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

# Check if expired
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 &>/dev/null; then
  print_success "Certificate is currently valid"
else
  print_error "Certificate has expired"
fi
echo

# Subject Alternative Names
print_info "Subject Alternative Names (SANs):"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  if ! openssl x509 -in "${CERT_FILE}" -noout -text | grep -A2 "Subject Alternative Name" 2>/dev/null; then
    echo "  No SANs (not recommended for RHEL 9+)"
  fi
else
  if ! openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null; then
    echo "  No SANs (not recommended for RHEL 9+)"
  fi
fi
echo

# Public key info
print_info "Public Key:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep -A 2 "Public Key Algorithm"
echo

# Signature algorithm
print_info "Signature Algorithm:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep "Signature Algorithm" | head -1
echo

# Fingerprints
print_info "Certificate Fingerprints:"
echo -n "  SHA-256: "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha256 | cut -d= -f2
echo -n "  SHA-1:   "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha1 | cut -d= -f2
echo

# RHEL version check
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  if openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_success "RHEL 9+ requirement: SANs present"
  else
    print_warning "RHEL 9+ warning: SANs missing (required for validation)"
  fi
fi

echo
print_success "Certificate inspection complete"

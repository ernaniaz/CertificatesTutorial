#!/usr/bin/env bash
#=============================================================================
# Lab 15: Diagnose
# Scenario 01: Diagnose expired certificate
#
# Usage: ./diagnose.sh
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
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9, 10."
fi

#=============================================================================
# MAIN
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"

print_header "Scenario 01: Diagnosing Certificate Issue"

if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Certificate not found. Run ./create-problem.sh first"
  exit 1
fi

print_info "Step 1: Check certificate validity dates"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

print_info "Step 2: Check if certificate is expired"
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "Certificate is still valid"
else
  print_error "Certificate has expired!"
fi
echo

print_info "Step 3: Show full certificate details"
openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates
echo

print_info "Step 4: Calculate days until/since expiration"
NOT_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)"
EXPIRE_EPOCH="$(date -d "${NOT_AFTER}" +%s 2>/dev/null || echo "0")"
NOW_EPOCH="$(date +%s)"
DAYS_DIFF="$(( (${EXPIRE_EPOCH} - ${NOW_EPOCH}) / 86400 ))"

if [[ ${DAYS_DIFF} -lt 0 ]]; then
  print_error "Certificate expired ${DAYS_DIFF#-} days ago"
else
  print_success "Certificate expires in ${DAYS_DIFF} days"
fi

echo
echo "======================================="
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "DIAGNOSIS: Certificate is still valid"
  echo
  echo "Note: This scenario expects an expired certificate."
  echo "If you see conflicting results above, inspect notBefore/notAfter closely."
else
  print_warning "DIAGNOSIS: Certificate has expired"
  echo
  echo "Impact:"
  echo "  - SSL/TLS connections will fail when this certificate is in use"
  echo "  - Services cannot use this certificate"
  echo "  - Clients will show security warnings"
  echo
  echo "Solution: Generate new certificate with future expiration"
  echo "Run ./fix.sh to resolve this issue"
fi

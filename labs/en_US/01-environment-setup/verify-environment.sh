#!/usr/bin/env bash
#=============================================================================
# Lab 01: Environment verification
# Validate that all certificate tools are installed correctly
#
# Usage: ./verify-environment.sh
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

print_header "Lab 01: Environment Verification"

# Check RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

# Check OpenSSL
if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  print_error "OpenSSL not found"
  exit 1
fi

# Check certutil
if command -v certutil &> /dev/null; then
  print_success "certutil available"
else
  print_error "certutil not found"
  exit 1
fi

# Check certmonger
if command -v getcert &> /dev/null; then
  print_success "certmonger available"
else
  print_warning "certmonger not found (optional for RHEL 7)"
fi

# Check crypto-policies (RHEL 8+)
if command -v update-crypto-policies &> /dev/null; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  print_success "Crypto-policies: ${POLICY}"
fi

echo
echo "Certificate directories:"

# Check directories
for dir in /etc/pki/tls/certs /etc/pki/tls/private /etc/pki/ca-trust; do
  if [[ -d "${dir}" ]]; then
    print_success "${dir}"
  else
    print_error "${dir} not found"
    exit 1
  fi
done

# Check CA bundle
if [[ -f "/etc/pki/tls/certs/ca-bundle.crt" ]]; then
  BUNDLE_SIZE=$(wc -l < /etc/pki/tls/certs/ca-bundle.crt)
  print_success "CA bundle: ${BUNDLE_SIZE} lines"
else
  print_error "CA bundle not found"
  exit 1
fi

echo
print_success "All validations passed!"
print_success "Lab 01 completed successfully."
echo
echo "Next: Proceed to Lab 02: Key Generation"
echo

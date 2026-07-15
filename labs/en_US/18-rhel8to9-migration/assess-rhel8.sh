#!/usr/bin/env bash
#=============================================================================
# Lab 18: Assess Rhel8
# Pre-migration assessment for RHEL 9
#
# Usage: ./assess-rhel8.sh
# Prerequisites: RHEL 8
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 18: RHEL 8 Certificate Assessment"

print_info "1. System Version:"
cat /etc/redhat-release
openssl version
echo

print_info "2. Certificate Analysis:"

SANS_MISSING=0
WEAK_KEYS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text >/dev/null 2>&1; then
    # Check for SANs
    if ! openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
      echo -e " ${YELLOW}⚠ No SAN: $(basename "${cert}")${NC}"
      ((SANS_MISSING+=1))
    fi

    # Check key size
    KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text | grep "Public-Key:" | grep -oP '\d+' | head -1)"
    if [[ -n "${KEY_SIZE}" && ${KEY_SIZE} -lt 2048 ]]; then
      echo -e " ${RED}✗ Weak key (${KEY_SIZE} bit): $(basename "${cert}")${NC}"
      ((WEAK_KEYS+=1))
    fi
  fi
done

if [[ ${SANS_MISSING} -eq 0 ]]; then
  echo -e " ${GREEN}✓ All certificates have SANs${NC}"
else
  echo -e " ${YELLOW}⚠ ${SANS_MISSING} certificates without SANs${NC}"
  echo "    (RHEL 9 prefers certificates with SANs)"
fi

if [[ ${WEAK_KEYS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ All keys meet minimum size${NC}"
else
  echo -e " ${RED}✗ ${WEAK_KEYS} weak keys found${NC}"
  echo "    (RHEL 9 requires RSA 2048+ bits)"
fi

echo

print_info "3. Current Crypto-Policy:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo " ${POLICY}"

echo

print_info "4. OpenSSL Configuration:"
if [[ -f /etc/pki/tls/openssl.cnf ]]; then
  if grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
    echo -e " ${YELLOW}⚠ Legacy provider enabled${NC}"
  else
    echo -e " ${GREEN}✓ Standard configuration${NC}"
  fi
fi

echo

print_info "Assessment Summary:"
echo "  Ready for RHEL 9 migration assessment"
echo

if [[ ${SANS_MISSING} -gt 0 || ${WEAK_KEYS} -gt 0 ]]; then
  print_warning "Recommendations before migration:"
  if [ ${SANS_MISSING} -gt 0 ]; then
    echo "  - Regenerate certificates with SANs"
  fi
  if [ ${WEAK_KEYS} -gt 0 ]; then
    echo "  - Regenerate with stronger keys (2048+ bits)"
  fi
fi

echo
echo "Next: back up certificates with ./backup-certificates.sh"

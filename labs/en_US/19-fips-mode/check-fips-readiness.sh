#!/usr/bin/env bash
#=============================================================================
# Lab 19: Check Fips Readiness
# Verify FIPS readiness
#
# Usage: ./check-fips-readiness.sh
# Prerequisites: RHEL 8, 9, 10
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
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 19: FIPS Readiness Check"

print_info "1. Current FIPS Status:"
if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --check
else
  echo "  fips-mode-setup command not found"
fi
echo

print_info "2. Kernel FIPS Flag:"
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS} -eq 1 ]]; then
    echo -e " ${GREEN}✓ FIPS enabled${NC}"
  else
    echo "  FIPS disabled"
  fi
else
  echo "  Not available"
fi
echo

print_info "3. Certificate Compatibility:"
WEAK_KEYS=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ ! (-f "${cert}") ]]; then
    continue
  fi
  KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep "Public-Key:" | grep -oP '\d+' | head -1)"
  if [[ -n "${KEY_SIZE}" ]] && [[ "${KEY_SIZE}" -lt 2048 ]]; then
    ((WEAK_KEYS+=1))
  fi
done

if [[ ${WEAK_KEYS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ All keys meet FIPS requirements${NC}"
else
  echo -e " ${RED}✗ ${WEAK_KEYS} keys too weak for FIPS${NC}"
fi

echo
if [[ ${RHEL_VERSION} -ge 10 ]]; then
  echo "RHEL 10: FIPS can only be enabled at installation time (fips=1 kernel parameter)."
else
  echo "To enable FIPS: sudo ./enable-fips.sh"
fi

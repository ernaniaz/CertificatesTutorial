#!/usr/bin/env bash
#=============================================================================
# Lab 19: Check Fips Status
# Verify whether FIPS mode is enabled
#
# Usage: ./check-fips-status.sh
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

print_header "Lab 19: FIPS Mode Status"

# Check FIPS mode
print_info "1. FIPS Mode Status:"
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_ENABLED="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_ENABLED} -eq 1 ]]; then
    echo -e " ${GREEN}✓ FIPS mode is ENABLED${NC}"
  else
    echo -e " ${YELLOW}⚠ FIPS mode is DISABLED${NC}"
  fi
else
  echo "  FIPS status file not found"
fi

echo

# Check fips-mode-setup command
print_info "2. fips-mode-setup Status:"
if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --check
  else
  echo "  fips-mode-setup command not found"
fi

echo

# Check kernel command line
print_info "3. Kernel Command Line:"
if grep -q "fips=1" /proc/cmdline; then
  echo -e " ${GREEN}✓ fips=1 in kernel parameters${NC}"
  else
  echo "  fips=1 not in kernel parameters"
fi

echo

# Check crypto-policy
print_info "4. Crypto-Policy:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Current: ${POLICY}"

if [[ ${POLICY} == FIPS ]]; then
  echo -e " ${GREEN}✓ Using FIPS policy${NC}"
elif [[ ${FIPS_ENABLED} -eq 1 ]]; then
  echo -e " ${YELLOW}⚠ FIPS enabled but not using FIPS policy${NC}"
fi

echo

# OpenSSL FIPS status
print_info "5. OpenSSL FIPS Status:"
if openssl list -providers 2>/dev/null | grep -q "fips"; then
  echo -e " ${GREEN}✓ FIPS provider available${NC}"
else
  echo "  FIPS provider not detected"
fi

echo
echo "======================================="

if [[ ${FIPS_ENABLED:-0} -eq 1 ]]; then
  print_success "System is running in FIPS mode"
else
  print_warning "System is NOT in FIPS mode"
  echo
  echo "To enable FIPS mode:"
  echo "  sudo ./enable-fips.sh"
fi

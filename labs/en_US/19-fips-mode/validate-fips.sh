#!/usr/bin/env bash
#=============================================================================
# Lab 19: Validate Fips
# Validate that FIPS mode is active
#
# Usage: ./validate-fips.sh
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

print_header "Lab 19: FIPS Mode Validation"

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ PASS: ${NC}${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC}${description}"
    ((FAIL+=1))
  fi
}

print_info "FIPS Mode Checks:"
test_check "FIPS enabled in kernel" "[[ -f /proc/sys/crypto/fips_enabled && \$(cat /proc/sys/crypto/fips_enabled) -eq 1 ]]"
test_check "FIPS boot parameter set" "grep -q 'fips=1' /proc/cmdline"
test_check "FIPS crypto-policy active" "update-crypto-policies --show | grep -q FIPS"
test_check "fips-mode-setup reports enabled" "fips-mode-setup --check 2>&1 | grep -q 'enabled'"

echo
print_info "OpenSSL FIPS:"
if [[ ${RHEL_VERSION} -le 8 ]]; then
  test_check "OpenSSL FIPS module active" "openssl version 2>/dev/null | grep -qi fips"
else
  test_check "OpenSSL FIPS provider available" "openssl list -providers 2>/dev/null | grep -q fips"
fi
test_check "Can generate RSA 2048 key" "openssl genrsa -out /tmp/fips-test.key 2048"
test_check "Cannot use MD5" "! openssl dgst -md5 /tmp/fips-test.key"

rm -f /tmp/fips-test.key

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "FIPS mode fully operational"
  exit 0
else
  print_error "FIPS validation failed"
  echo "System may not be in proper FIPS mode"
  exit 1
fi

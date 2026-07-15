#!/usr/bin/env bash
#=============================================================================
# Lab 15: Verify Fix
# Scenario 01: Verify fix
#
# Usage: ./verify-fix.sh
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

print_header "Scenario 01: Verifying Fix"

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ PASS: ${NC} ${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

test_check "Certificate file exists" "[ -f ${CERT_FILE} ]"
test_check "Certificate is valid (not expired)" "openssl x509 -in ${CERT_FILE} -noout -checkend 0"
test_check "Certificate is valid for 30+ days" "openssl x509 -in ${CERT_FILE} -noout -checkend 2592000"
test_check "Certificate has correct subject" "openssl x509 -in ${CERT_FILE} -noout -subject | grep -q expired.example.com"

echo
echo "Certificate validity:"
openssl x509 -in "${CERT_FILE}" -noout -dates

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Scenario 01 completed successfully"
  echo
  echo "Key learnings:"
  echo "  - Always check certificate expiration dates"
  echo "  - Implement monitoring before expiration"
  echo "  - Use automation for renewal"
  echo "  - Test renewal process regularly"
  exit 0
else
  print_error "Some checks failed"
  exit 1
fi

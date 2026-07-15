#!/usr/bin/env bash
#=============================================================================
# Lab 04: Test
# Automated validation
#
# Usage: ./test.sh
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

print_header "Lab 04: Automated Testing"

test_check "Certificate file exists" "[ -f output/server.crt ]"
test_check "CSR file exists" "[ -f output/server.csr ]"
test_check "DER file exists" "[ -f output/server.der ]"
test_check "Certificate is valid X.509" "openssl x509 -in output/server.crt -noout -text"
test_check "Certificate not expired" "openssl x509 -in output/server.crt -noout -checkend 0"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  test_check "Certificate has SANs" "openssl x509 -in output/server.crt -noout -text | grep -q 'Subject Alternative Name'"
else
  test_check "Certificate has SANs" "openssl x509 -in output/server.crt -noout -ext subjectAltName"
fi
test_check "CSR is valid" "openssl req -in output/server.csr -noout -text"
test_check "DER format valid" "openssl x509 -in output/server.der -inform DER -noout -text"
test_check "PEM and DER match" "pem=\$(openssl x509 -in output/server.crt -noout -fingerprint -sha256) && der=\$(openssl x509 -in output/server.der -inform DER -noout -fingerprint -sha256) && [[ -n \"\${pem}\" && \"\${pem}\" == \"\${der}\" ]]"

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 04 completed successfully"
  exit 0
else
  print_error "Some tests failed"
  exit 1
fi

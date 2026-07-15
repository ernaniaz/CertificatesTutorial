#!/usr/bin/env bash
#=============================================================================
# Lab 02: Test
# Automated key generation validation
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

print_header "Lab 02: Automated Testing"

# Run tests
test_check "RSA 2048-bit key exists" "[ -f output/rsa-2048.key ]"
test_check "RSA 2048-bit public key exists" "[ -f output/rsa-2048.pub ]"
test_check "RSA 4096-bit key exists" "[ -f output/rsa-4096.key ]"
test_check "RSA 4096-bit public key exists" "[ -f output/rsa-4096.pub ]"
test_check "ECC P-256 key exists" "[ -f output/ecc-p256.key ]"
test_check "ECC P-256 public key exists" "[ -f output/ecc-p256.pub ]"
test_check "ECC P-384 key exists" "[ -f output/ecc-p384.key ]"
test_check "ECC P-384 public key exists" "[ -f output/ecc-p384.pub ]"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  test_check "RSA 2048 key is valid" "openssl rsa -in output/rsa-2048.key -check -noout"
  test_check "ECC P-256 key is valid" "openssl ec -in output/ecc-p256.key -noout"
else
  test_check "RSA 2048 key is valid" "openssl pkey -in output/rsa-2048.key -check -noout"
  test_check "ECC P-256 key is valid" "openssl pkey -in output/ecc-p256.key -check -noout"
fi

echo
print_header "Test Results"
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "All tests passed!"
  print_success "Lab 02 completed successfully."
  exit 0
else
  print_error "Some tests failed."
  exit 1
fi

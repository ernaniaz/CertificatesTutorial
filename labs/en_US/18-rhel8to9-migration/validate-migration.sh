#!/usr/bin/env bash
#=============================================================================
# Lab 18: Validate Migration
# Validation on upgraded RHEL 9
#
# Usage: ./validate-migration.sh
# Prerequisites: RHEL 9
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
if [[ ${RHEL_VERSION} -ne 9 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 9 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 18: RHEL 9 Post-Upgrade Validation"

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

print_info "System Validation:"
test_check "Running RHEL 9" "grep -q 'release 9' /etc/redhat-release"
test_check "OpenSSL 3.x active" "openssl version | grep -q 'OpenSSL 3'"
test_check "Crypto-policies configured" "update-crypto-policies --show"

echo
print_info "Certificate Validation:"
test_check "Certificates readable" "ls /etc/pki/tls/certs/*.crt | head -1 | xargs -I {} openssl x509 -in {} -noout"
test_check "Trust store intact" "[ -d /etc/pki/ca-trust ]"

echo
print_info "OpenSSL 3.x Functionality:"
test_check "Can generate keys" "openssl genrsa -out /tmp/test.key 2048"
test_check "Can create certificates" "openssl req -new -x509 -key /tmp/test.key -out /tmp/test.crt -days 1 -subj '/CN=test' -addext 'subjectAltName=DNS:test'"

# Cleanup test files
rm -f /tmp/test.key /tmp/test.crt

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "RHEL 8→9 post-upgrade validation successful"
  echo
  echo "Migration complete! OpenSSL 3.x operational."
  exit 0
else
  print_error "Some validation checks failed"
  echo "Review and fix issues"
  exit 1
fi

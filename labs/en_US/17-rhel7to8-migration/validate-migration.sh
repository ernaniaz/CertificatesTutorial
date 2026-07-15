#!/usr/bin/env bash
#=============================================================================
# Lab 17: Validate Migration
# Validation on upgraded RHEL 8
#
# Usage: ./validate-migration.sh
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

print_header "Lab 17: RHEL 8 Post-Upgrade Validation"

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
test_check "Running RHEL 8" "grep -q 'release 8' /etc/redhat-release"
test_check "Crypto-policies available" "command -v update-crypto-policies"
test_check "Crypto-policy set" "update-crypto-policies --show"

echo
print_info "Certificate Validation:"
test_check "Certificate directory exists" "[ -d /etc/pki/tls/certs ]"
test_check "Certificates present" "ls /etc/pki/tls/certs/*.crt 2>/dev/null | grep -q ."
test_check "Trust store intact" "[ -d /etc/pki/ca-trust ]"

echo
print_info "Service Validation:"
for svc in httpd nginx postfix; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    test_check "${svc} service file exists" "systemctl cat ${svc}"
  fi
done

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "RHEL 7→8 post-upgrade validation successful"
  echo
  echo "RHEL 7→8 migration complete!"
  exit 0
else
  print_error "Some validation checks failed"
  echo "Review and fix issues"
  exit 1
fi

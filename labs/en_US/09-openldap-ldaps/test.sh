#!/usr/bin/env bash
#=============================================================================
# Lab 09: Test
# Automated validation for OpenLDAP LDAPS
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

print_header "Lab 09: Automated Testing"

test_check "slapd service running" "systemctl is-active slapd"
test_check "Port 389 listening" "ss -tlnp | grep -q ':389'"
test_check "Certificate file exists" "[ -f /etc/openldap/certs/ldap.crt ]"
test_check "Private key exists" "[ -f /etc/openldap/certs/ldap.key ]"
test_check "Private key has correct permissions" "[ \$(stat -c%a /etc/openldap/certs/ldap.key) == '600' ]"
test_check "Private key owned by ldap" "[ \$(stat -c%U /etc/openldap/certs/ldap.key) == 'ldap' ]"
test_check "TLS certificate configured in cn=config" "ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config '(objectClass=olcGlobal)' olcTLSCertificateFile 2>&1 | grep -q olcTLSCertificateFile"
test_check "LDAP connection works" "ldapsearch -x -H ldap://localhost -b '' -s base"
test_check "Client config exists" "[ -f /etc/openldap/ldap.conf ]"

# Optional: Port 636 (may not be enabled by default)
if ss -tlnp | grep -q ':636'; then
  test_check "LDAPS connection works" "timeout 5 ldapsearch -x -H ldaps://localhost -b '' -s base"
fi

echo
echo "======================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 09 completed successfully"
  exit 0
else
  print_error "Some tests failed"
  exit 1
fi

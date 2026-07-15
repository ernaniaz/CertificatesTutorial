#!/usr/bin/env bash
#=============================================================================
# Lab 09: Verify
# Manual verification steps
#
# Usage: ./verify.sh
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

print_header "Lab 09: OpenLDAP LDAPS Verification"

print_info "1. Checking slapd service..."
systemctl status slapd --no-pager | head -5
echo

print_info "2. Checking listening ports..."
ss -tlnp | grep slapd
echo

print_info "3. Checking TLS configuration in cn=config..."
echo "TLS certificate file:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateFile 2>/dev/null | grep "olcTLSCertificateFile"; then
  echo "Not configured"
fi
echo
echo "TLS key file:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateKeyFile 2>/dev/null | grep "olcTLSCertificateKeyFile"; then
  echo "Not configured"
fi
echo

print_info "4. Checking certificate files..."
if [[ -f /etc/openldap/certs/ldap.crt ]]; then
  print_success "Certificate exists"
  openssl x509 -in /etc/openldap/certs/ldap.crt -noout -subject -dates
else
  echo "Certificate not found"
fi
echo

print_info "5. Checking private key..."
if [[ -f /etc/openldap/certs/ldap.key ]]; then
  print_success "Private key exists"
  ls -l /etc/openldap/certs/ldap.key
  PERMS="$(stat -c%a /etc/openldap/certs/ldap.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissions correct (600)"
  else
    print_warning "Permissions: ${PERMS} (should be 600)"
  fi

  OWNER="$(stat -c%U:%G /etc/openldap/certs/ldap.key)"
  if [[ "${OWNER}" == "ldap:ldap" ]]; then
    print_success "Owner correct (ldap:ldap)"
  else
    print_warning "Owner: ${OWNER} (should be ldap:ldap)"
  fi
else
  echo "Private key not found"
fi
echo

print_info "6. Checking SLAPD_URLS configuration..."
if [[ -f /etc/sysconfig/slapd ]]; then
  if ! grep "SLAPD_URLS" /etc/sysconfig/slapd; then
    echo "Not configured"
  fi
else
  echo "sysconfig file not found"
fi
echo

print_info "7. Checking client configuration..."
if [[ -f /etc/openldap/ldap.conf ]]; then
  echo "Client TLS settings:"
  grep -E "^TLS_|^URI" /etc/openldap/ldap.conf | grep -v "^#"
else
  echo "Client config not found"
fi
echo

print_info "8. Testing LDAP connection..."
if ldapsearch -x -H ldap://localhost -b "" -s base &>/dev/null; then
  print_success "LDAP connection works"
else
  echo "LDAP connection failed"
fi

print_info "9. Testing LDAPS connection..."
if ldapsearch -x -H ldaps://localhost -b "" -s base &>/dev/null; then
  print_success "LDAPS connection works"
else
  echo "LDAPS connection failed (may need to enable port 636)"
fi

echo
print_success "Verification complete"

#!/usr/bin/env bash
#=============================================================================
# Lab 09: Test connection
# Test LDAP, STARTTLS, and LDAPS
#
# Usage: ./test-connection.sh
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

print_header "Lab 09: Testing LDAP Connections"

# Test plain LDAP (port 389)
print_info "1. Testing plain LDAP (port 389)..."
if ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "Plain LDAP connection successful"
else
  print_error "Plain LDAP connection failed"
  exit 1
fi

echo

# Test STARTTLS (port 389)
print_info "2. Testing STARTTLS (port 389 with -ZZ)..."
if ldapsearch -x -H ldap://localhost -b "" -s base -ZZ supportedSASLMechanisms &>/dev/null; then
  print_success "STARTTLS connection successful"
else
  print_warning "STARTTLS failed (may need TLS_REQCERT allow in ldap.conf)"
fi

echo

# Test LDAPS (port 636)
print_info "3. Testing LDAPS (port 636)..."
if ldapsearch -x -H ldaps://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "LDAPS connection successful"
else
  print_warning "LDAPS failed (check if port 636 is enabled)"
fi

echo

# Test with openssl s_client
print_info "4. Testing TLS handshake with openssl..."
if ss -tlnp | grep -q ':636'; then
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:636 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Server certificate"; then
    print_success "TLS handshake successful"

    # Extract certificate info
    SUBJECT="$(echo "${TLS_INFO}" | grep "subject=" | head -1)"
    if [[ -n "${SUBJECT}" ]]; then
      echo " ${SUBJECT}"
    fi

    # Extract protocol
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1)"
    if [[ -n "${PROTOCOL}" ]]; then
      echo " ${PROTOCOL}"
    fi

    # Extract cipher
    CIPHER="$(echo "${TLS_INFO}" | grep "Cipher" | head -1)"
    if [[ -n "${CIPHER}" ]]; then
      echo " ${CIPHER}"
    fi
  else
    print_warning "Could not verify TLS details"
  fi
else
  print_warning "Port 636 not listening"
fi

echo

# Query supported mechanisms
print_info "5. Querying supported SASL mechanisms..."
MECHANISMS="$(ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms 2>/dev/null | grep "supportedSASLMechanisms" | awk '{print $2}' | tr '\n' ' ')"
if [[ -n "${MECHANISMS}" ]]; then
  print_success "Supported SASL mechanisms: ${MECHANISMS}"
else
  echo "No SASL mechanisms reported"
fi

echo
print_success "Connection testing complete"
echo
echo "Manual test commands:"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base -ZZ"
echo "  openssl s_client -connect localhost:636"

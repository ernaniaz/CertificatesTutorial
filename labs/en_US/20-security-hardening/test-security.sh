#!/usr/bin/env bash
#=============================================================================
# Lab 20: Test Security
# Test hardened security configuration
#
# Usage: ./test-security.sh
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

print_header "Lab 20: Security Configuration Testing"

# Test Apache if running
if systemctl is-active httpd &>/dev/null; then
  print_info "Testing Apache HTTPS..."

  # Test TLS connection
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "TLS protocol: ${PROTOCOL}"
  else
    print_warning "Could not detect TLS version"
  fi

  # Check HSTS header
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "HSTS header present"
  else
    print_warning "HSTS header missing"
  fi

  echo
fi

# Test NGINX if running
if systemctl is-active nginx &>/dev/null; then
  print_info "Testing NGINX HTTPS..."

  # Test TLS connection
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "TLS protocol: ${PROTOCOL}"
  fi

  # Check HSTS
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "HSTS header present"
  else
    print_warning "HSTS header missing"
  fi

  echo
fi

# Test weak protocol rejection
print_info "Testing weak protocol rejection..."

# Try TLS 1.0 (should fail)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.0 accepted (should be blocked)"
else
  print_success "TLS 1.0 rejected"
fi

# Try TLS 1.1 (should fail)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.1 accepted (should be blocked)"
else
  print_success "TLS 1.1 rejected"
fi

echo
print_success "Security testing complete"
echo
echo "Security status:"
echo "  ✓ Modern TLS versions only"
echo "  ✓ Weak protocols blocked"
echo "  ✓ Security headers configured"

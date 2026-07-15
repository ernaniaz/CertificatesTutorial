#!/usr/bin/env bash
#=============================================================================
# Lab 20: Test Hardening
# Test applied security measures
#
# Usage: ./test-hardening.sh
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

print_header "Lab 20: Security Hardening Tests"

# Test Apache if running
if systemctl is-active httpd &>/dev/null; then
  print_info "Testing Apache HTTPS..."

  # Check HSTS header
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e " ${GREEN}✓ HSTS header present${NC}"
  else
    echo -e " ${YELLOW}⚠ HSTS header not found${NC}"
  fi

  # Check X-Frame-Options
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "x-frame-options"; then
    echo -e " ${GREEN}✓ X-Frame-Options present${NC}"
  else
    echo -e " ${YELLOW}⚠ X-Frame-Options not found${NC}"
  fi

  # Test TLS 1.0 (should fail)
  if echo | openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*is.*none"; then
    echo -e " ${GREEN}✓ TLS 1.0 blocked${NC}"
  else
    echo -e " ${YELLOW}⚠ TLS 1.0 may be allowed${NC}"
  fi

  echo
fi

# Test NGINX if running
if systemctl is-active nginx &>/dev/null; then
  print_info "Testing NGINX HTTPS..."

  # Check headers
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e " ${GREEN}✓ HSTS header present${NC}"
  else
    echo -e " ${YELLOW}⚠ HSTS header not found${NC}"
  fi

  echo
fi

# Test available ciphers
print_info "Testing cipher strength..."
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Available ciphers: ${CIPHER_COUNT}"

# Check for weak ciphers
WEAK="$(openssl ciphers -v 2>/dev/null | grep -iE "DES|RC4|MD5|NULL|EXPORT" | wc -l)"
if [[ ${WEAK} -eq 0 ]]; then
  echo -e " ${GREEN}✓ No weak ciphers detected${NC}"
else
  echo -e " ${YELLOW}⚠${WEAK} weak ciphers available${NC}"
fi

echo
print_success "Security testing complete"
echo
echo "For comprehensive testing, use:"
echo "  https://www.ssllabs.com/ssltest/ (for public sites)"
echo "  testssl.sh localhost:443 (command-line tool)"

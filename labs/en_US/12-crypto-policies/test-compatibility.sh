#!/usr/bin/env bash
#=============================================================================
# Lab 12: Test Compatibility
# Test system behavior under current policy
#
# Usage: ./test-compatibility.sh
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

print_header "Lab 12: Test Compatibility"

# Get current policy
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "Testing under policy: ${CURRENT_POLICY}"
echo

# Test OpenSSL ciphers
print_info "1. OpenSSL ciphers:"
echo "Available cipher count:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo " ${CIPHER_COUNT} ciphers available"
echo
echo "Sample ciphers (first 10):"
openssl ciphers -v 2>/dev/null | head -10 | sed 's/^/  /'

echo

# Test TLS versions
print_info "2. TLS/SSL versions:"
echo "Testing which TLS/SSL versions are available..."

# Test TLS 1.0
if echo | openssl s_client -connect www.google.com:443 -tls1 2>/dev/null | grep -q "Protocol.*TLSv1$"; then
  echo -e " ${GREEN}✓ TLS 1.0 available${NC}"
else
  echo "  ✗ TLS 1.0 not available"
fi

# Test TLS 1.1
if echo | openssl s_client -connect www.google.com:443 -tls1_1 2>/dev/null | grep -q "Protocol.*TLSv1.1"; then
  echo -e " ${GREEN}✓ TLS 1.1 available${NC}"
else
  echo "  ✗ TLS 1.1 not available"
fi

# Test TLS 1.2
if echo | openssl s_client -connect www.google.com:443 -tls1_2 2>&1 | grep -q "Protocol.*TLSv1.2"; then
  echo -e " ${GREEN}✓ TLS 1.2 available${NC}"
else
  echo "  ✗ TLS 1.2 not available"
fi

# Test TLS 1.3
if echo | openssl s_client -connect www.google.com:443 -tls1_3 2>&1 | grep -q "Protocol.*TLSv1.3"; then
  echo -e " ${GREEN}✓ TLS 1.3 available${NC}"
else
  echo "  ✗ TLS 1.3 not available"
fi

echo

# Test SSH ciphers
print_info "3. SSH ciphers:"
if command -v ssh &>/dev/null; then
  SSH_CIPHER_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo "Available SSH ciphers: ${SSH_CIPHER_COUNT}"
  echo "Sample SSH ciphers (first 5):"
  ssh -Q cipher 2>/dev/null | head -5 | sed 's/^/  /'
else
  echo "SSH not available for testing"
fi

echo

# Show backend configurations
print_info "4. Backend configurations:"
echo "OpenSSL config:"
if [[ -f /etc/crypto-policies/back-ends/opensslcnf.config ]]; then
  head -5 /etc/crypto-policies/back-ends/opensslcnf.config 2>/dev/null | sed 's/^/  /'
else
  echo "  Not found"
fi

echo
echo "OpenSSH config:"
if [[ -f /etc/crypto-policies/back-ends/openssh.config ]]; then
  cat /etc/crypto-policies/back-ends/openssh.config 2>/dev/null | sed 's/^/  /'
else
  echo "  Not found"
fi

echo
print_success "Compatibility testing complete"
echo
echo "Current policy: ${CURRENT_POLICY}"
echo
echo "Policy comparison:"
echo "  LEGACY: Most compatible, weakest security"
echo "  DEFAULT: Balanced"
echo "  FUTURE: Most secure, may break old clients"

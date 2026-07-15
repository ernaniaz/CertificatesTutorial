#!/usr/bin/env bash
#=============================================================================
# Lab 12: Verify
# Verification steps
#
# Usage: ./verify.sh
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

print_header "Lab 12: Crypto-Policy Verification"

# Check RHEL version
echo "RHEL Version: ${RHEL_VERSION}"

if [[ ${RHEL_VERSION} -lt 8 ]]; then
  echo "Note: Crypto-policies requires RHEL 8+"
  exit 0
fi

echo

print_info "1. Current policy:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo " ${POLICY}"

echo

print_info "2. Configuration file:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Content: $(cat /etc/crypto-policies/config)"
else
  echo "  Not found"
fi

echo

print_info "3. Available policies:"
if ! ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | sed 's/^/  /'; then
  echo "  None found"
fi

echo

print_info "4. Backend configurations:"
if ! ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | sed 's/^/  /'; then
  echo "  None found"
fi

echo

print_info "5. OpenSSL cipher count:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo " ${CIPHER_COUNT} ciphers"

echo

print_info "6. SSH ciphers available:"
if command -v ssh &>/dev/null; then
  SSH_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo " ${SSH_COUNT} SSH ciphers"
else
  echo "  SSH not installed"
fi

echo
print_success "Verification complete"

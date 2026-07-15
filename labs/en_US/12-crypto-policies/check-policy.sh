#!/usr/bin/env bash
#=============================================================================
# Lab 12: Check Policy
# Show current system cryptographic policy
#
# Usage: ./check-policy.sh
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

print_header "Lab 12: Check Crypto-Policy"

# Check RHEL version
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Error: Crypto-policies requires RHEL 8 or newer"
  echo "Current version: RHEL ${RHEL_VERSION}"
  exit 1
fi

echo "RHEL Version: ${RHEL_VERSION}"
echo

# Check current policy
print_info "Current crypto-policy:"
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || cat /etc/crypto-policies/config 2>/dev/null || echo "UNKNOWN")"
print_success " ${CURRENT_POLICY}"

echo

# Show policy configuration file
print_info "Policy configuration file:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Location: /etc/crypto-policies/config"
  echo "  Content: $(cat /etc/crypto-policies/config)"
else
  echo "  Configuration file not found"
fi

echo

# List available policies
print_info "Available policies:"
if [[ -d /usr/share/crypto-policies/policies/ ]]; then
  ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | while read policy; do
    if [[ ${policy} == ${CURRENT_POLICY} ]]; then
      echo -e " ${GREEN}*${policy} (current)${NC}"
    else
      echo "   ${policy}"
    fi
  done
else
  echo "  Policy directory not found"
fi

echo

# Show backend configurations
print_info "Backend configurations:"
if [[ -d /etc/crypto-policies/back-ends/ ]]; then
  echo "  Backend config directory: /etc/crypto-policies/back-ends/"
  ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | head -10
else
  echo "  Backend directory not found"
fi

echo

# Show policy details (sample)
print_info "Current policy details:"
if [[ -f "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" ]]; then
  echo "  Policy file: /usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol"
  echo
  echo "  Sample configuration (first 20 lines):"
  head -20 "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" 2>/dev/null | sed 's/^/    /'
else
  echo "  Policy file not found"
fi

echo
print_success "Policy check complete"
echo
echo "To change policy:"
echo "  sudo update-crypto-policies --set LEGACY"
echo "  sudo update-crypto-policies --set DEFAULT"
echo "  sudo update-crypto-policies --set FUTURE"

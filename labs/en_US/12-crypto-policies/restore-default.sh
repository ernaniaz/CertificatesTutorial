#!/usr/bin/env bash
#=============================================================================
# Lab 12: Restore Default
# Restore DEFAULT crypto-policy
#
# Usage: ./restore-default.sh
# Prerequisites: RHEL 8, 9, 10, root privileges
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

print_header "Lab 12: Restore DEFAULT Policy"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check RHEL version
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Error: Crypto-policies requires RHEL 8 or newer"
  exit 1
fi

# Show current policy
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Current policy: ${CURRENT_POLICY}"

if [[ ${CURRENT_POLICY} == DEFAULT ]]; then
  print_success "Already using DEFAULT policy"
  exit 0
fi

echo

# Switch to DEFAULT
print_info "Switching to DEFAULT policy..."
if update-crypto-policies --set DEFAULT; then
  print_success "Policy set to DEFAULT"
else
  print_error "Failed to set DEFAULT policy"
  exit 1
fi

echo

# Verify
NEW_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "New policy: ${NEW_POLICY}"

echo
print_info "Restarting affected services..."

# Services that might need restart
SERVICES="sshd httpd nginx postfix"
for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "  Restarting ${service}..."
    if ! systemctl restart ${service} 2>/dev/null; then
      echo "    (not installed or restart failed)"
    fi
  fi
done

echo
print_success "Restored to DEFAULT policy"
echo
echo "DEFAULT policy provides:"
echo "  - TLS 1.2 and 1.3"
echo "  - Strong ciphers"
echo "  - Good balance of security and compatibility"

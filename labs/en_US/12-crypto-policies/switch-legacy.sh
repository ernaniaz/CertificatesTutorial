#!/usr/bin/env bash
#=============================================================================
# Lab 12: Switch Legacy
# Enable LEGACY crypto-policy for maximum compatibility
#
# Usage: ./switch-legacy.sh
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

print_header "Lab 12: Switch to LEGACY Policy"

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

echo
print_warning "LEGACY policy allows weak cryptography for compatibility"
print_warning "  - TLS 1.0 and 1.1 allowed"
print_warning "  - Weak ciphers enabled"
print_warning "  - Use only for testing or legacy system compatibility"
echo

read -p "Continue with LEGACY policy? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 0
fi

echo

# Switch to LEGACY
print_info "Switching to LEGACY policy..."
if update-crypto-policies --set LEGACY; then
  print_success "Policy set to LEGACY"
else
  print_error "Failed to set LEGACY policy"
  exit 1
fi

echo

# Verify
NEW_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "New policy: ${NEW_POLICY}"

echo
print_info "Restarting affected services..."
print_warning "Note: Some services may need manual restart"

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
print_success "Switched to LEGACY policy"
echo
echo "Test with:"
echo "  openssl ciphers -v"
echo "  ssh -Q cipher"
echo
print_warning "Remember to restore DEFAULT policy when testing is complete:"
echo "  sudo update-crypto-policies --set DEFAULT"

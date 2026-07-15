#!/usr/bin/env bash
#=============================================================================
# Lab 19: Disable Fips
# Disable FIPS mode (if needed)
#
# Usage: ./disable-fips.sh
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

print_header "Lab 19: Disable FIPS Mode"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ does not support disabling FIPS after installation."
  echo
  echo "On RHEL 10, FIPS mode is set at installation time and cannot be"
  echo "changed afterwards. A reinstallation without the fips=1 kernel"
  echo "parameter is required to run without FIPS."
  echo
  echo "Current FIPS status:"
  fips-mode-setup --check 2>/dev/null || cat /proc/sys/crypto/fips_enabled
  exit 1
fi

print_warning "WARNING: Disabling FIPS mode"
echo
echo "This should only be done if:"
echo "  - FIPS compliance is not required"
echo "  - Testing/lab environment"
echo "  - Troubleshooting FIPS issues"
echo

read -p "Disable FIPS mode? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 0
fi

echo

# Check if FIPS is enabled
if [[ ! -f /proc/sys/crypto/fips_enabled || "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_success "FIPS mode already disabled"
  exit 0
fi

# Disable FIPS
print_info "Disabling FIPS mode..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --disable
  print_success "FIPS mode disabled"
else
  print_error "fips-mode-setup command not found"
  exit 1
fi

echo
print_error "⚠ REBOOT REQUIRED"
echo
echo "After reboot, FIPS mode will be disabled"
echo
echo "To reboot now:"
echo "  sudo reboot"

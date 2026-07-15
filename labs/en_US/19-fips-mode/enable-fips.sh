#!/usr/bin/env bash
#=============================================================================
# Lab 19: Enable Fips
# Script to enable FIPS for Lab 19
#
# Usage: ./enable-fips.sh
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

print_header "Lab 19: Enable FIPS Mode"

if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ does not support enabling FIPS after installation."
  echo
  echo "On RHEL 10, FIPS mode must be enabled during OS installation."
  echo "To reinstall with FIPS enabled, add the following kernel parameter"
  echo "to the installer boot command line:"
  echo "  fips=1"
  echo
  echo "Or select the FIPS option in the Anaconda installer security policy."
  echo
  echo "To check current FIPS status:"
  echo "  fips-mode-setup --check"
  exit 1
fi

print_warning "WARNING: Enabling FIPS mode will:"
echo "  - Require system reboot"
echo "  - Block non-FIPS algorithms"
echo "  - May break some applications"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cancelled"
  exit 0
fi

echo
print_info "Enabling FIPS mode..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --enable
  echo
  print_success "FIPS mode will be enabled after reboot"
  echo
  read -p "Reboot now? (y/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Yy]$ ]]; then
    reboot
  fi
else
  print_error "fips-mode-setup not available"
  exit 1
fi

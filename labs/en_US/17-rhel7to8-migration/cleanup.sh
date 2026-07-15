#!/usr/bin/env bash
#=============================================================================
# Lab 17: Cleanup
# Remove temporary files
#
# Usage: ./cleanup.sh
# Prerequisites: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 17: Migration Cleanup"

print_warning "This will remove migration test files"
print_warning "Backup archives will be preserved"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo
print_info "Cleaning up..."

# Remove any test files created during migration
rm -f /tmp/migration-test-*

print_success "Cleanup complete"
echo
echo "Backup archives preserved in:"
if ! ls -lh /root/rhel7-cert-backup-*.tar.gz 2>/dev/null; then
  echo "  None found"
fi
echo
echo "To remove backups (if no longer needed):"
echo "  rm /root/rhel7-cert-backup-*.tar.gz"

#!/usr/bin/env bash
#=============================================================================
# Lab 16: Cleanup
# Remove emergency certificates
#
# Usage: ./cleanup.sh
# Prerequisites: RHEL 7, 8, 9, 10, root privileges
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 16: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Removing emergency certificates..."

# Remove emergency certificates
rm -f /etc/pki/tls/certs/emergency.crt
rm -f /etc/pki/tls/private/emergency.key
rm -f /etc/pki/tls/certs/temp-*.crt
rm -f /etc/pki/tls/private/temp-*.key

# Remove backup and rollback files
rm -f /etc/pki/tls/certs/*.backup
rm -f /etc/pki/tls/certs/*.old
rm -f /etc/pki/tls/certs/*.rollback
rm -f /etc/pki/tls/private/*.backup
rm -f /etc/pki/tls/private/*.old
rm -f /etc/pki/tls/private/*.rollback

print_success "Emergency certificates removed"
echo

# Note about backup directories
if ls -d /root/cert-backup-* /root/cert-before-restore-* 2>/dev/null; then
  print_info "Backup directories found:"
  ls -d /root/cert-backup-* /root/cert-before-restore-* 2>/dev/null
  echo
  echo "These backups are preserved"
  echo "Remove manually if not needed:"
  echo "  rm -rf /root/cert-backup-*"
  echo "  rm -rf /root/cert-before-restore-*"
fi

echo
print_success "Cleanup complete"

#!/usr/bin/env bash
#=============================================================================
# Lab 06: Cleanup
# Remove Apache and restore system
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

print_header "Lab 06: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

echo "This will:"
echo "  - Stop Apache"
echo "  - Remove Apache packages"
echo "  - Remove SSL configuration"
echo "  - Remove certificates from system"
echo
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# Stop Apache
echo
echo "Stopping Apache..."
systemctl stop httpd || true
systemctl disable httpd || true

# Remove packages
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y httpd mod_ssl || true
else
  dnf remove -y httpd mod_ssl || true
fi

# Remove configuration
if [[ -f /etc/httpd/conf.d/lab-ssl.conf ]]; then
  rm -f /etc/httpd/conf.d/lab-ssl.conf
  print_success "Removed SSL configuration"
fi

# Remove certificates
rm -f /etc/pki/tls/certs/lab-server.crt
rm -f /etc/pki/tls/private/lab-server.key

# Remove firewall rules
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=http 2>/dev/null || true
  firewall-cmd --permanent --remove-service=https 2>/dev/null || true
  firewall-cmd --reload
  print_success "Firewall rules removed"
fi

echo
print_success "Cleanup complete"

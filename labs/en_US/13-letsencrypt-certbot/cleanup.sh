#!/usr/bin/env bash
#=============================================================================
# Lab 13: Cleanup
# Remove certbot and certificates
#
# Usage: ./cleanup.sh
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

print_header "Lab 13: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Confirmation
print_warning "This will remove certbot and all certificates."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo

# Delete all certificates
if command -v certbot &>/dev/null && [[ -d /etc/letsencrypt/live ]]; then
  print_info "Deleting certificates..."
  for cert_dir in /etc/letsencrypt/live/*/; do
    if [[ -d "${cert_dir}" ]]; then
      cert_name="$(basename "${cert_dir}")"
      echo "Deleting certificate: ${cert_name}"
      certbot delete --cert-name "${cert_name}" --non-interactive 2>/dev/null || true
    fi
  done
  print_success "Certificates deleted"
fi

echo

# Stop and disable timer
print_info "Disabling certbot timer..."
systemctl stop certbot-renew.timer 2>/dev/null || true
systemctl disable certbot-renew.timer 2>/dev/null || true
print_success "Timer disabled"

echo

# Remove certbot package
print_info "Removing certbot package..."

dnf remove -y certbot python3-certbot-apache python3-certbot-nginx 2>/dev/null || true

print_success "Certbot removed"
echo

# Remove Let's Encrypt directory
print_info "Removing Let's Encrypt directory..."
rm -rf /etc/letsencrypt
rm -rf /var/log/letsencrypt
print_success "Directories removed"

echo
print_success "Cleanup complete"
echo
echo "System restored to pre-lab state."

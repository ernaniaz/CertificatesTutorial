#!/usr/bin/env bash
#=============================================================================
# Lab 11: Cleanup
# Remove certmonger and tracked certificates
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

print_header "Lab 11: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Confirmation
print_warning "This will remove certmonger and all tracked certificates."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo

# Stop tracking all certificates
print_info "Stopping tracking of all certificates..."
REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':" || echo)"

if [[ -n "${REQUEST_IDS}" ]]; then
  for REQ_ID in ${REQUEST_IDS}; do
    echo "Stopping tracking: ${REQ_ID}"
    getcert stop-tracking -i "${REQ_ID}" 2>/dev/null || true
  done
  print_success "Stopped tracking certificates"
else
  echo "No certificates being tracked"
fi

echo

# Stop certmonger
if systemctl is-active certmonger &>/dev/null; then
  print_info "Stopping certmonger..."
  systemctl stop certmonger
  systemctl disable certmonger
  print_success "certmonger stopped"
fi

echo

# Remove certmonger package
print_info "Removing certmonger package..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y certmonger
else
  dnf remove -y certmonger
fi

print_success "certmonger removed"
echo

# Remove certificate files
print_info "Removing certificate files..."
if [[ -d /etc/pki/certmonger ]]; then
  rm -rf /etc/pki/certmonger
  print_success "Certificate files removed"
fi

echo
print_success "Cleanup complete"
echo
echo "System restored to pre-lab state."

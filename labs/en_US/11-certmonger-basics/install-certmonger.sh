#!/usr/bin/env bash
#=============================================================================
# Lab 11: Install Certmonger
# Install and configure certmonger service
#
# Usage: ./install-certmonger.sh
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

print_header "Lab 11: Installing certmonger"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Detect RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

# Install certmonger
print_info "Installing certmonger..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y certmonger
else
  dnf install -y certmonger
fi

print_success "certmonger installed"
echo

# Enable and start certmonger
print_info "Enabling and starting certmonger service..."
systemctl enable certmonger
systemctl start certmonger

print_success "certmonger service started"
echo

# Verify installation
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger is running"
else
  print_error "certmonger failed to start"
  exit 1
fi

# Display certmonger version
echo
echo "certmonger package version:"
rpm -q certmonger

# List available CAs
echo
echo "Available CAs:"
if ! getcert list-cas 2>/dev/null; then
  echo "No CAs configured yet"
fi

echo
print_success "certmonger installation complete"
echo
echo "certmonger status:"
systemctl status certmonger --no-pager | head -5

echo
echo "Try these commands:"
echo "  getcert list"
echo "  getcert list-cas"
echo "  journalctl -u certmonger -f"

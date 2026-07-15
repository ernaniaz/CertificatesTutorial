#!/usr/bin/env bash
#=============================================================================
# Lab 09: Install OpenLDAP
# Install OpenLDAP server and clients
#
# Usage: ./install-openldap.sh
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

print_header "Lab 09: Installing OpenLDAP"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Detect RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

# Install OpenLDAP
print_info "Installing OpenLDAP packages..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y openldap openldap-servers openldap-clients
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf install -y openldap openldap-servers openldap-clients
else
  # RHEL 9+: openldap-servers removed from base repos, install from EPEL
  dnf install -y epel-release || dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_VERSION}.noarch.rpm"
  dnf install -y openldap openldap-servers openldap-clients
fi

print_success "OpenLDAP installed"
echo

# Enable and start slapd
print_info "Enabling and starting slapd service..."
systemctl enable slapd
systemctl start slapd

print_success "slapd service started"
echo

# Configure firewall
print_info "Configuring firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=ldap
  firewall-cmd --permanent --add-service=ldaps
  firewall-cmd --reload
  print_success "Firewall configured (ports 389, 636)"
else
  echo "firewalld not running, skipping firewall configuration"
fi

echo

# Verify installation
if systemctl is-active slapd &>/dev/null; then
  print_success "slapd is running"
else
  print_error "slapd failed to start"
  exit 1
fi

# Check if listening on port 389
if ss -tlnp | grep -q ':389'; then
  print_success "LDAP listening on port 389"
fi

# Display OpenLDAP version
echo
echo "OpenLDAP version:"
slapd -VV 2>&1 | head -1

echo
print_success "OpenLDAP installation complete"
echo
echo "slapd status:"
systemctl status slapd --no-pager | head -5

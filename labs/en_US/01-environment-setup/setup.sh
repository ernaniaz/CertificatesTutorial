#!/usr/bin/env bash
#=============================================================================
# Lab 01: Setup
# Install certificate management tools
#
# Usage: ./setup.sh
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

print_header "Lab 01: Environment Setup (RHEL ${RHEL_VERSION})"

print_success "RHEL ${RHEL_VERSION} detected: $(cat /etc/redhat-release)"
echo

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "This script must be run as root (use sudo)"
fi

# Install packages
print_info "Installing certificate management tools..."
echo

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
else
  dnf install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
fi

echo
print_success "Package installation complete"
echo

# Verify installations
print_info "Verifying installations..."

if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  error_exit "OpenSSL installation failed"
fi

if command -v certutil &> /dev/null; then
  print_success "certutil (NSS tools) installed"
else
  error_exit "NSS tools installation failed"
fi

if command -v getcert &> /dev/null; then
  print_success "certmonger installed"
else
  print_error "certmonger not available (optional, may need EPEL)"
fi

# Check /etc/pki/ structure
if [[ -d "/etc/pki" ]]; then
  print_success "/etc/pki/ directory exists"
else
  error_exit "/etc/pki/ not found"
fi

echo
print_success "=== Setup Complete ==="
echo
echo "Next step: Run './verify-environment.sh' to validate installation"
echo

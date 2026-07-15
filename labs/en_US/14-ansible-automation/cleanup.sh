#!/usr/bin/env bash
#=============================================================================
# Lab 14: Cleanup
# Remove Ansible and lab configurations
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

print_header "Lab 14: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Confirmation
print_warning "This will undo all lab tasks: remove Apache, Ansible, certificates, and configs."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo

# Stop and disable Apache
print_info "Stopping and disabling Apache..."
if systemctl is-active httpd &>/dev/null; then
  systemctl stop httpd
fi
systemctl disable httpd 2>/dev/null || true
print_success "Apache stopped and disabled"

echo

# Remove Apache SSL configuration
print_info "Removing Apache SSL configuration..."
rm -f /etc/httpd/conf.d/ansible-ssl.conf
print_success "Apache SSL configuration removed"

echo

# Remove test page created by playbook
print_info "Removing test page..."
rm -f /var/www/html/index.html
print_success "Test page removed"

echo

# Remove deployed certificates
print_info "Removing deployed certificates..."
rm -f /etc/pki/tls/certs/lab-ansible.crt
rm -f /etc/pki/tls/private/lab-ansible.key
print_success "Certificates removed"

echo

# Remove Apache packages installed by playbook
print_info "Removing Apache packages (httpd, mod_ssl)..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y httpd mod_ssl 2>/dev/null || true
else
  dnf remove -y httpd mod_ssl 2>/dev/null || true
fi
print_success "Apache packages removed"

echo

# Remove Ansible configuration directory
print_info "Removing Ansible configuration..."
rm -rf /etc/ansible
print_success "Ansible configuration removed"

echo

# Remove inventory file
print_info "Removing inventory file..."
rm -f "${SCRIPT_DIR}/inventory.ini"
print_success "Inventory file removed"

echo

# Remove Ansible package
print_info "Removing Ansible package..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y ansible 2>/dev/null || true
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf remove -y ansible 2>/dev/null || true
else
  dnf remove -y ansible-core 2>/dev/null || true
fi
print_success "Ansible removed"

echo
print_success "Cleanup complete"
echo
echo "All lab tasks have been undone:"
echo "  - Apache (httpd, mod_ssl) removed"
echo "  - SSL configuration and test page removed"
echo "  - Certificates removed"
echo "  - Ansible configuration removed"
echo "  - Ansible package removed"

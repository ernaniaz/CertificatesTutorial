#!/usr/bin/env bash
#=============================================================================
# Lab 14: Verify
# Verification steps
#
# Usage: ./verify.sh
# Prerequisites: RHEL 8, 9, 10
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 14: Ansible Verification"

print_info "1. Ansible version:"
if command -v ansible &>/dev/null; then
  ansible --version | head -3
else
  echo "Ansible not installed"
fi

echo

print_info "2. Inventory file:"
if [[ -f "${SCRIPT_DIR}/inventory.ini" ]]; then
  print_success "Inventory exists"
  echo "File: ${SCRIPT_DIR}/inventory.ini"
else
  echo "Inventory not found"
fi

echo

print_info "3. Playbook files:"
for playbook in "${SCRIPT_DIR}"/playbook-*.yml; do
  if [[ -f "${playbook}" ]]; then
    echo "  $(basename "${playbook}")"
  fi
done

echo

print_info "4. Testing inventory connection:"
if command -v ansible &>/dev/null && [ -f "${SCRIPT_DIR}/inventory.ini" ]; then
  ansible all -i "${SCRIPT_DIR}/inventory.ini" -m ping 2>&1 | head -10
else
  echo "Cannot test (ansible or inventory missing)"
fi

echo

print_info "5. Checking deployed certificates:"
if [[ -f /etc/pki/tls/certs/lab-ansible.crt ]]; then
  print_success "Certificate deployed"
  openssl x509 -in /etc/pki/tls/certs/lab-ansible.crt -noout -subject -dates
else
  echo "Certificate not yet deployed"
fi

echo

print_info "6. Checking Apache configuration:"
if [[ -f /etc/httpd/conf.d/ansible-ssl.conf ]]; then
  print_success "Apache SSL config exists"
else
  echo "Apache SSL config not found"
fi

echo
print_success "Verification complete"

#!/usr/bin/env bash
#=============================================================================
# Lab 14: Create Inventory
# Configure Ansible inventory for the lab
#
# Usage: ./create-inventory.sh
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

print_header "Lab 14: Create Ansible Inventory"

# Create inventory file
print_info "Creating inventory file..."

cat > "${SCRIPT_DIR}/inventory.ini" << 'EOF'
# Lab 14: Ansible Certificate Automation Inventory

[control]
localhost ansible_connection=local

[webservers]
localhost ansible_connection=local

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=root
EOF

print_success "Inventory file created"
echo

# Display inventory
echo "Inventory file content:"
cat "${SCRIPT_DIR}/inventory.ini"

echo

# Test inventory
print_info "Testing inventory..."
if command -v ansible &>/dev/null; then
  if ! ansible all -i "${SCRIPT_DIR}/inventory.ini" -m ping; then
    echo -e "${YELLOW}Ping test failed (may need SSH setup)${NC}"
  fi
else
  echo "Install Ansible first to test inventory"
fi

echo
print_success "Inventory creation complete"
echo
echo "Inventory file: ${SCRIPT_DIR}/inventory.ini"
echo
echo "Usage:"
echo "  ansible all -i inventory.ini -m ping"
echo "  ansible-playbook -i inventory.ini playbook-apache.yml"

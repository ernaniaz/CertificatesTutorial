#!/usr/bin/env bash
#=============================================================================
# Lab 14: Install Ansible
# Install Ansible control node
#
# Usage: ./install-ansible.sh
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

print_header "Lab 14: Installing Ansible"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Detect RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

# Install Ansible
print_info "Installing Ansible..."

if [[ ${RHEL_VERSION} -eq 7 || ${RHEL_VERSION} -eq 8 ]]; then
  # RHEL 7 and 8: ansible package
  if [[ ${RHEL_VERSION} -eq 7 ]]; then
    # Enable EPEL for RHEL 7
    if ! rpm -q epel-release &>/dev/null; then
      echo "Installing EPEL repository..."
      yum install -y epel-release
    fi
    yum install -y ansible
  else
    dnf install -y ansible
  fi
else
  # RHEL 9+: ansible-core
  dnf install -y ansible-core
fi

print_success "Ansible installed"
echo

# Display Ansible version
ansible --version | head -1

echo

# Create ansible config directory
if [[ ! -d /etc/ansible ]]; then
  mkdir -p /etc/ansible
  print_success "Created /etc/ansible directory"
fi

# Create basic ansible.cfg if it doesn't exist
if [[ ! -f /etc/ansible/ansible.cfg ]]; then
  cat > /etc/ansible/ansible.cfg << 'EOF'
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF
  print_success "Created ansible.cfg"
fi

echo
print_success "Ansible installation complete"
echo
echo "Ansible commands:"
echo "  ansible --version"
echo "  ansible all -m ping"
echo "  ansible-playbook playbook-apache.yml"
echo "  ansible-galaxy list"

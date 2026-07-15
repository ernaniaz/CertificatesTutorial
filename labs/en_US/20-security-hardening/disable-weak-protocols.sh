#!/usr/bin/env bash
#=============================================================================
# Lab 20: Disable Weak Protocols
# Remove support for weak SSL/TLS protocols
#
# Usage: ./disable-weak-protocols.sh
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

print_header "Lab 20: Disable Weak Protocols"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Disabling weak protocols system-wide..."
echo

# RHEL 8+: Use crypto-policies
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  echo "Using crypto-policies to disable weak protocols..."

  CURRENT_POLICY="$(update-crypto-policies --show)"
  echo "Current policy: ${CURRENT_POLICY}"

  if [[ ${CURRENT_POLICY} == LEGACY ]]; then
    print_warning "LEGACY policy allows weak protocols"
    echo "Switching to DEFAULT policy..."
    update-crypto-policies --set DEFAULT
    print_success "Switched to DEFAULT (blocks TLS 1.0/1.1)"
  elif [[ ${CURRENT_POLICY} == DEFAULT ]]; then
    print_success "DEFAULT policy already active (TLS 1.2+)"
  elif [[ ${CURRENT_POLICY} == FUTURE ]]; then
    print_success "FUTURE policy active (strongest security)"
  fi

  echo
  echo "Restarting services..."
  for svc in httpd nginx postfix sshd; do
    if systemctl is-active ${svc} &>/dev/null; then
      if systemctl restart ${svc} 2>/dev/null; then
        echo "  ✓ ${svc} restarted"
      fi
    fi
  done
else
  # RHEL 7: Manual configuration
  echo "RHEL 7 detected - manual configuration required"
  echo "Ensure your service configs have:"
  echo "  SSLProtocol -all +TLSv1.2 +TLSv1.3"
fi

echo
print_success "Weak protocols disabled"
echo
echo "Blocked protocols:"
echo "  - SSLv2, SSLv3"
echo "  - TLS 1.0, TLS 1.1"
echo
echo "Allowed protocols:"
echo "  - TLS 1.2"
echo "  - TLS 1.3"

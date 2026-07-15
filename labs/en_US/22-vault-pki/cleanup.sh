#!/usr/bin/env bash
#=============================================================================
# Lab 22: Cleanup
# Stop Vault and remove all lab files
#
# Usage: ./cleanup.sh
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep Vault flag
KEEP_VAULT=false
if [[ "${1:-}" == "--keep-vault" ]]; then
  KEEP_VAULT=true
fi

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

print_header "Lab 22: Cleanup"

# --- Step 1: Confirm cleanup with user ---
print_step "Confirming cleanup"

print_warning "This will stop Vault and remove all lab files"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  print_info "Cleanup cancelled"
  exit 0
fi
echo

# --- Step 2: Stop Vault process ---
print_step "Stopping Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
fi

if [[ -n "${VAULT_PID:-}" ]] && kill -0 "${VAULT_PID}" 2>/dev/null; then
  kill "${VAULT_PID}" || true
  sleep 2
  print_success "Vault stopped (PID ${VAULT_PID})"
elif pgrep -x vault > /dev/null; then
  pkill vault || true
  sleep 2
  if pgrep -x vault > /dev/null; then
    pkill -9 vault || true
  fi
  print_success "Vault stopped"
else
  print_info "Vault not running"
fi
echo

# --- Step 3: Remove certificate files ---
print_step "Removing certificate files"

if [[ -d "${SCRIPT_DIR}/certs" ]]; then
  rm -rf "${SCRIPT_DIR}/certs"
  print_success "Certificates directory removed"
fi

rm -f "${SCRIPT_DIR}/root-ca.crt"
rm -f "${SCRIPT_DIR}/intermediate.csr"
rm -f "${SCRIPT_DIR}/intermediate.crt"
rm -f "${SCRIPT_DIR}/crl.pem"
print_success "CA and CRL files removed"
echo

# --- Step 4: Remove Vault configuration files ---
print_step "Removing Vault configuration files"

rm -f "${SCRIPT_DIR}/vault-env.sh"
rm -f "${SCRIPT_DIR}/vault.log"
print_success "Configuration files removed"
echo

# --- Step 5: Optionally remove Vault binary ---
if [[ ${KEEP_VAULT} == false ]]; then
  print_step "Removing Vault binary"

  if command -v vault &> /dev/null; then
    read -p "Remove Vault from /usr/local/bin/vault? (y/N): " -n 1 -r
    echo
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
      sudo rm -f /usr/local/bin/vault
      print_success "Vault binary removed"
    else
      print_info "Vault binary kept"
    fi
  else
    print_info "Vault binary not found"
  fi
  echo
else
  print_info "Keeping Vault binary (--keep-vault)"
  echo
fi

# --- Step 6: Display cleanup summary ---
print_step "Cleanup summary"

print_success "Cleanup completed"
echo "  - Vault stopped"
echo "  - Certificates removed"
echo "  - Configuration files removed"
if [[ ${KEEP_VAULT} == false ]]; then
  echo "  - Vault binary removal offered"
else
  echo "  - Vault binary kept"
fi
echo
print_warning "Note: In dev mode, all Vault data was stored in memory"
print_info "All PKI data has been lost (expected behavior)"

echo
echo "To run the lab again:"
echo "  1. ./start-vault-dev.sh"
echo "  2. ./enable-pki.sh"
echo "  3. Continue with remaining scripts"
echo
echo "Or to start completely fresh:"
echo "  ./install-vault.sh"

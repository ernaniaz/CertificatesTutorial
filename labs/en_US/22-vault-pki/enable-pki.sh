#!/usr/bin/env bash
#=============================================================================
# Lab 22: Enable Pki
# Enable and configure PKI secrets engine
#
# Usage: ./enable-pki.sh
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

print_header "Lab 22: Enable PKI Secrets Engine"

# --- Step 1: Load Vault connection details ---
print_step "Loading Vault environment"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Environment loaded from vault-env.sh"
else
  print_warning "vault-env.sh not found — using defaults"
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Step 2: Verify Vault is running and unsealed ---
print_step "Checking Vault status"

if ! command -v vault &> /dev/null; then
  error_exit "Vault not found. Run ./install-vault.sh first"
fi

if ! vault status &> /dev/null; then
  error_exit "Vault is not running. Run ./start-vault-dev.sh first"
fi

print_success "Vault is running and accessible"
echo

# --- Step 3: Enable PKI secrets engine ---
print_step "Enabling PKI secrets engine"

if vault secrets list | grep -q "^pki/"; then
  print_warning "PKI secrets engine already enabled"
else
  if ! vault secrets enable pki; then
    error_exit "Failed to enable PKI secrets engine"
  fi
  print_success "PKI secrets engine enabled at: pki/"
fi
echo

# --- Step 4: Configure maximum lease TTL ---
print_step "Configuring maximum lease TTL"

# Root CA certificates need a long TTL to avoid frequent re-issuance in labs
if ! vault secrets tune -max-lease-ttl=87600h pki; then
  error_exit "Failed to tune PKI max lease TTL"
fi

print_success "Max lease TTL set to: 87600h (10 years)"
echo

print_success "PKI secrets engine ready"
echo

# --- Step 5: Display PKI engine information ---
print_step "PKI secrets engine information"

print_info "Enabled secrets engines:"
vault secrets list | grep -E "Path|pki"
echo
print_info "PKI mount configuration:"
vault read sys/mounts/pki

echo
echo "Next steps:"
echo "  - Run './configure-root-ca.sh' to create root CA"
echo "  - Run 'vault read pki/config' to view configuration"

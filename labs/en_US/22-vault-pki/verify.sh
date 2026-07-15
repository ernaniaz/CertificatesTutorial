#!/usr/bin/env bash
#=============================================================================
# Lab 22: Verify
# Validate that all lab components are configured correctly
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
PASS=0
FAIL=0

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

print_header "Lab 22: Verification"

# --- Step 1: Load Vault connection details ---
print_step "Loading Vault environment"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Environment loaded from vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
  print_warning "vault-env.sh not found — using defaults"
fi
echo

# --- Step 2: Run verification tests ---
print_step "Running verification tests"

if pgrep -x vault &> /dev/null; then
  print_success "PASS: Vault is running"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Vault is running"
  FAIL=$((FAIL + 1))
fi

if vault status &> /dev/null; then
  print_success "PASS: Vault is accessible and unsealed"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Vault is accessible and unsealed"
  FAIL=$((FAIL + 1))
fi

if vault secrets list | grep -q '^pki/'; then
  print_success "PASS: PKI secrets engine is enabled"
  PASS=$((PASS + 1))
else
  print_error "FAIL: PKI secrets engine is enabled"
  FAIL=$((FAIL + 1))
fi

if vault read pki/cert/ca &> /dev/null; then
  print_success "PASS: Root CA exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Root CA exists"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/cert/ca &> /dev/null; then
  print_success "PASS: Intermediate CA exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Intermediate CA exists"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/roles/web-server &> /dev/null; then
  print_success "PASS: PKI role 'web-server' exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: PKI role 'web-server' exists"
  FAIL=$((FAIL + 1))
fi

if [[ -n "$(find "${SCRIPT_DIR}/certs" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null)" ]]; then
  print_success "PASS: Certificates were issued"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Certificates were issued"
  FAIL=$((FAIL + 1))
fi

echo

# --- Step 3: Display pass/fail summary ---
print_step "Verification summary"

echo
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "All validations passed!"
  print_success "Lab 22 completed successfully."
  echo
  echo "You have successfully:"
  echo "  - Installed HashiCorp Vault"
  echo "  - Configured PKI secrets engine"
  echo "  - Created root and intermediate CA hierarchy"
  echo "  - Created PKI roles and issued dynamic certificates"
  echo "  - Understood certificate revocation"
  exit 0
else
  print_error "Some validations failed."
  echo
  echo "Troubleshooting:"
  echo "  - Check Vault is running: vault status"
  echo "  - Check Vault logs: cat vault.log"
  echo "  - Verify environment: source vault-env.sh"
  echo "  - Rerun failed lab scripts"
  exit 1
fi

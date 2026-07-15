#!/usr/bin/env bash
#=============================================================================
# Lab 05: Update trust
# Run update-ca-trust to rebuild system trust store
#
# Usage: ./update-trust.sh
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

TRUST_ANCHOR="/etc/pki/ca-trust/source/anchors/lab-test-ca.crt"

print_header "Lab 05: Updating System Trust Store"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check if CA was added
if [[ ! -f "${TRUST_ANCHOR}" ]]; then
  print_error "Error: Custom CA not found in trust anchors"
  echo "Run ./add-custom-ca.sh first"
  exit 1
fi

# Count CAs before update
BEFORE=$(grep -c "BEGIN CERTIFICATE" /etc/pki/tls/certs/ca-bundle.crt || true)

print_info "Running update-ca-trust extract..."
update-ca-trust extract

# Count CAs after update
AFTER=$(grep -c "BEGIN CERTIFICATE" /etc/pki/tls/certs/ca-bundle.crt || true)

print_success "System trust store updated"
echo
echo "CA bundle statistics:"
echo "  Before: ${BEFORE} certificates"
echo "  After: ${AFTER} certificates"
echo "  Change: + $((AFTER - BEFORE)) certificate(s)"
echo
echo "Updated files:"
echo "  /etc/pki/tls/certs/ca-bundle.crt"
echo "  /etc/pki/tls/certs/ca-bundle.trust.crt"
echo
print_success "Custom CA is now trusted system-wide"

#!/usr/bin/env bash
#=============================================================================
# Lab 11: Verify
# Verification steps
#
# Usage: ./verify.sh
# Prerequisites: RHEL 7, 8, 9, 10
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

print_header "Lab 11: certmonger Verification"

print_info "1. Checking certmonger service..."
systemctl status certmonger --no-pager | head -5
echo

print_info "2. Checking certmonger version..."
rpm -q certmonger
echo

print_info "3. Listing tracked certificates..."
CERT_COUNT="$(getcert list 2>/dev/null | grep -c "Request ID:" || true)"
echo "Tracked certificates: ${CERT_COUNT}"
echo

if [[ ${CERT_COUNT} -gt 0 ]]; then
  getcert list 2>/dev/null | grep -E "Request ID:|status:|certificate:|expires:" | head -20
fi

echo

print_info "4. Checking available CAs..."
getcert list-cas
echo

print_info "5. Checking certificate files..."
for cert in /etc/pki/certmonger/*.crt; do
  if [[ -f "${cert}" ]]; then
    echo "Certificate: ${cert}"
    if ! openssl x509 -in "${cert}" -noout -subject -dates 2>/dev/null; then
      echo "  Could not read certificate"
    fi
    echo
  fi
done

print_info "6. Checking certmonger logs (last 10 entries)..."
journalctl -u certmonger --no-pager | tail -10

echo
print_success "Verification complete"

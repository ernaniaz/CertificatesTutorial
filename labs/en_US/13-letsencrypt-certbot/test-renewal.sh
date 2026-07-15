#!/usr/bin/env bash
#=============================================================================
# Lab 13: Test Renewal
# Test certbot renewal process
#
# Usage: ./test-renewal.sh
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

print_header "Lab 13: Test Certificate Renewal"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# List existing certificates
print_info "Existing certificates:"
if certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
  certbot certificates
else
  print_warning "No certificates found"
  echo "Run obtain-standalone.sh or obtain-webserver.sh first"
  exit 0
fi

echo

# Test renewal (dry-run)
print_info "Testing renewal (dry-run, will not actually renew)..."
echo

if certbot renew --dry-run 2>&1 | tee /tmp/certbot-renewal-test.log; then
  echo
  print_success "Renewal test successful"
  echo
  echo "Dry-run completed successfully"
  echo "Certificates would renew without errors"
else
  echo
  print_warning "Renewal test encountered issues"
  echo
  echo "This is normal in a lab environment"
  echo "Check /tmp/certbot-renewal-test.log for details"
fi

echo
print_info "Renewal configuration:"
if [[ -d /etc/letsencrypt/renewal ]]; then
  echo "Renewal configs:"
  ls -1 /etc/letsencrypt/renewal/*.conf 2>/dev/null | while read conf; do
    echo " ${conf}"
    grep -E "authenticator|installer|renewalparams" "${conf}" 2>/dev/null | head -5 | sed 's/^/    /'
  done
else
  echo "No renewal configs found"
fi

echo
print_success "Renewal testing complete"
echo
echo "Key concepts:"
echo "  - Certificates renew when <30 days remain"
echo "  - --dry-run tests without actually renewing"
echo "  - Renewal uses same method as original request"
echo
echo "Manual renewal:"
echo "  certbot renew"
echo "  certbot renew --force-renewal"

#!/usr/bin/env bash
#=============================================================================
# Lab 07: Verify
# Manual verification steps
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

print_header "Lab 07: NGINX SSL Verification"

print_info "1. Checking NGINX service..."
systemctl status nginx --no-pager | head -5
echo

print_info "2. Checking listening ports..."
ss -tlnp | grep nginx
echo

print_info "3. Checking NGINX configuration..."
nginx -t
echo

print_info "4. Checking certificate files..."
if [[ -f /etc/pki/nginx/server.crt ]]; then
  print_success "Certificate exists"
  openssl x509 -in /etc/pki/nginx/server.crt -noout -subject -dates
else
  echo "Certificate not found"
fi
echo

print_info "5. Checking private key..."
if [[ -f /etc/pki/nginx/private/server.key ]]; then
  print_success "Private key exists"
  ls -l /etc/pki/nginx/private/server.key
  PERMS=$(stat -c%a /etc/pki/nginx/private/server.key)
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissions correct (600)"
  else
    print_warning "Permissions: ${PERMS} (should be 600)"
  fi
else
  echo "Private key not found"
fi
echo

print_info "6. Checking SSL configuration..."
if [[ -f /etc/nginx/conf.d/lab-ssl.conf ]]; then
  print_success "SSL configuration exists"
  echo
  echo "SSL directives:"
  grep -E "ssl_|listen 443" /etc/nginx/conf.d/lab-ssl.conf | grep -v "^#"
else
  echo "SSL configuration not found"
fi
echo

print_info "7. Testing HTTPS connection..."
if curl -k -s https://localhost/ | grep -q "Lab 07"; then
  print_success "HTTPS working"
  curl -k -s https://localhost/ | head -3
else
  echo "HTTPS test failed"
fi

echo
print_success "Verification complete"

#!/usr/bin/env bash
#=============================================================================
# Lab 06: Test connection
# Test Apache HTTPS functionality
#
# Usage: ./test-connection.sh
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

print_header "Lab 06: Testing Apache HTTPS"

# Test 1: Check if Apache is running
print_info "Test 1: Apache service status"
if systemctl is-active httpd &>/dev/null; then
  print_success "Apache is running"
else
  print_error "Apache is not running"
  exit 1
fi
echo

# Test 2: Check port 443
print_info "Test 2: Port 443 listening"
if ss -tlnp | grep -q ':443'; then
  print_success "Port 443 is listening"
  ss -tlnp | grep ':443'
else
  print_error "Port 443 not listening"
  exit 1
fi
echo

# Test 3: HTTP connection
print_info "Test 3: HTTP connection (port 80)"
if curl -s http://localhost/ &>/dev/null; then
  print_success "HTTP connection successful"
else
  print_warning "HTTP connection failed (may be normal if HTTP disabled)"
fi
echo

# Test 4: HTTPS connection
print_info "Test 4: HTTPS connection (port 443)"
if curl -k -s https://localhost/ &>/dev/null; then
  print_success "HTTPS connection successful"
  echo
  echo "Response:"
  curl -k -s https://localhost/ | head -5
else
  print_error "HTTPS connection failed"
  exit 1
fi
echo

# Test 5: Certificate details
print_info "Test 5: Certificate served by Apache"
CERT_INFO=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null || echo)

if [[ -n "${CERT_INFO}" ]]; then
  print_success "Certificate retrieved"
  echo "${CERT_INFO}"
else
  print_error "Could not retrieve certificate"
fi
echo

# Test 6: TLS version
print_info "Test 6: TLS protocol version"
TLS_VERSION=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep -E "Protocol|New, TLS" | head -1)
if [[ -n "${TLS_VERSION}" ]]; then
  print_success "${TLS_VERSION}"
else
  print_warning "Could not determine TLS version"
fi
echo

# Test 7: Cipher
print_info "Test 7: Cipher suite"
CIPHER=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep "Cipher" | head -1)
if [[ -n "${CIPHER}" ]]; then
  print_success "${CIPHER}"
else
  print_warning "Could not determine cipher"
fi

echo
print_success "Apache HTTPS testing complete"

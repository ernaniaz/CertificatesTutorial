#!/usr/bin/env bash
#=============================================================================
# Lab 07: Test connection
# Test HTTP and HTTPS connectivity
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

print_header "Lab 07: Testing NGINX HTTPS"

# Test HTTP (should redirect to HTTPS)
print_info "Testing HTTP (port 80)..."
if curl -s -I http://localhost/ | grep -q "301\|302"; then
  print_success "HTTP redirects to HTTPS"
else
  HTTP_RESPONSE="$(curl -s http://localhost/)"
  if echo "${HTTP_RESPONSE}" | grep -q "Lab 07"; then
    print_warning "HTTP works but no redirect configured"
  else
    print_error "HTTP test failed"
  fi
fi

echo

# Test HTTPS
print_info "Testing HTTPS (port 443)..."
if curl -k -s https://localhost/ | grep -q "Lab 07"; then
  print_success "HTTPS responds correctly"
else
  print_error "HTTPS test failed"
  exit 1
fi

echo

# Test certificate
print_info "Testing certificate..."
CERT_INFO="$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1)"

if echo "${CERT_INFO}" | grep -q "Verify return code"; then
  print_success "TLS handshake successful"

  # Extract certificate subject
  SUBJECT=$(echo "${CERT_INFO}" | grep "subject=" | head -1)
  echo " ${SUBJECT}"

  # Extract TLS version
  TLS_VERSION=$(echo "${CERT_INFO}" | grep "Protocol" | head -1)
  if [[ -n "${TLS_VERSION}" ]]; then
    echo " ${TLS_VERSION}"
  fi

  # Extract cipher
  CIPHER=$(echo "${CERT_INFO}" | grep "Cipher" | head -1)
  if [[ -n "${CIPHER}" ]]; then
    echo " ${CIPHER}"
  fi
else
  print_error "Certificate test failed"
  exit 1
fi

echo

# Test with curl verbose
print_info "Testing TLS details..."
TLS_INFO="$(curl -kvs https://localhost/ 2>&1)"

if echo "${TLS_INFO}" | grep -q "SSL connection using"; then
  SSL_LINE=$(echo "${TLS_INFO}" | grep "SSL connection using")
  print_success "${SSL_LINE}"
fi

echo
print_success "All connection tests passed"
echo
echo "Try these manual tests:"
echo "  curl -v https://localhost/"
echo "  openssl s_client -connect localhost:443 -servername localhost < /dev/null"

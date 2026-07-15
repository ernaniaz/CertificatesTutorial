#!/usr/bin/env bash
#=============================================================================
# Lab 08: Verify
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

print_header "Lab 08: Postfix TLS Verification"

print_info "1. Checking Postfix service..."
systemctl status postfix --no-pager | head -5
echo

print_info "2. Checking listening ports..."
ss -tlnp | grep master
echo

print_info "3. Checking TLS configuration..."
echo "TLS certificate and key:"
postconf -n | grep -E "smtpd_tls_cert_file|smtpd_tls_key_file" || print_warning "Not configured yet"
echo
echo "TLS security levels:"
postconf -n | grep -E "smtpd_tls_security_level|smtp_tls_security_level" || print_warning "Not configured yet"
echo
echo "TLS protocols:"
postconf -n | grep -E "smtpd_tls_protocols" || print_warning "Not configured yet"
echo

print_info "4. Checking certificate files..."
if [[ -f /etc/pki/tls/certs/postfix.crt ]]; then
  print_success "Certificate exists"
  openssl x509 -in /etc/pki/tls/certs/postfix.crt -noout -subject -dates
else
  echo "Certificate not found"
fi
echo

print_info "5. Checking private key..."
if [[ -f /etc/pki/tls/private/postfix.key ]]; then
  print_success "Private key exists"
  ls -l /etc/pki/tls/private/postfix.key
  PERMS="$(stat -c%a /etc/pki/tls/private/postfix.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissions correct (600)"
  else
    print_warning "Permissions: ${PERMS} (should be 600)"
  fi
else
  echo "Private key not found"
fi
echo

print_info "6. Checking STARTTLS capability..."
EHLO_TEST="$(echo -e "EHLO localhost\nQUIT" | nc localhost 25 2>/dev/null || true)"
if echo "${EHLO_TEST}" | grep -q "STARTTLS"; then
  print_success "STARTTLS advertised on port 25"
else
  if ! command -v nc &>/dev/null; then
    print_warning "nc (netcat) not installed, skipping STARTTLS check"
  else
    print_warning "STARTTLS not advertised on port 25"
  fi
fi
echo

print_info "7. Checking submission port..."
if ss -tlnp | grep -q ':587'; then
  print_success "Port 587 active"
  if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
    print_success "Mandatory encryption configured"
  fi
else
  echo "Port 587 not listening"
fi
echo

print_info "8. Checking recent logs..."
echo "Recent Postfix TLS log entries:"
if [[ -f /var/log/maillog ]]; then
  if ! grep -i "tls\|starttls" /var/log/maillog 2>/dev/null | tail -5; then
    echo "No TLS logs yet"
  fi
elif [[ -f /var/log/messages ]]; then
  if ! grep -i "postfix.*tls" /var/log/messages 2>/dev/null | tail -5; then
    echo "No TLS logs yet"
  fi
else
  if ! journalctl -u postfix --no-pager | grep -i tls | tail -5; then
    echo "No TLS logs yet"
  fi
fi

echo
print_success "Verification complete"

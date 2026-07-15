#!/usr/bin/env bash
#=============================================================================
# Lab 19: Configure Services Fips
# Ensure services meet FIPS requirements
#
# Usage: ./configure-services-fips.sh
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

print_header "Lab 19: Configure Services for FIPS"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check if FIPS is enabled
if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_warning "FIPS mode not enabled"
  echo "Enable FIPS first with ./enable-fips.sh"
  echo
fi

print_info "Checking service configurations..."
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Apache (httpd):"
  echo "  In FIPS mode, crypto-policy automatically restricts ciphers"
  echo "  Remove manual SSLProtocol/SSLCipherSuite directives"
  echo

  if grep -r "^[^#]*SSLCipherSuite" /etc/httpd/conf.d/ 2>/dev/null | grep -q .; then
    echo -e " ${YELLOW}⚠ Manual cipher configuration found${NC}"
    echo "    Consider removing to use FIPS crypto-policy"
  else
    echo -e " ${GREEN}✓ Using crypto-policy defaults${NC}"
  fi
  echo
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "NGINX:"
  echo "  NGINX requires explicit cipher configuration"
  echo "  Use FIPS-approved ciphers only"
  echo

  echo "  Recommended FIPS ciphers for NGINX:"
  echo "    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';"
  echo
fi

# OpenSSH
if [[ -f /etc/ssh/sshd_config ]]; then
  print_info "OpenSSH:"
  echo "  Crypto-policy automatically configures FIPS-compliant algorithms"
  echo -e " ${GREEN}✓ No manual configuration needed${NC}"
  echo
fi

# Postfix
if [[ -f /etc/postfix/main.cf ]]; then
  print_info "Postfix:"
  echo "  Crypto-policy configures FIPS-compliant TLS"
  if grep -q "^smtpd_tls_ciphers = high" /etc/postfix/main.cf; then
    echo -e " ${GREEN}✓ High cipher grade configured${NC}"
  else
    echo "  Configure: smtpd_tls_ciphers = high"
  fi
  echo
fi

print_success "Service configuration review complete"
echo
echo "After FIPS enablement:"
echo "  1. Restart all services"
echo "  2. Test connectivity"
echo "  3. Monitor for errors"
echo "  4. Update non-compliant configurations"

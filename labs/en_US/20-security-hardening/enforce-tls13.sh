#!/usr/bin/env bash
#=============================================================================
# Lab 20: Enforce Tls13
# Configure TLS 1.3 as minimum version
#
# Usage: ./enforce-tls13.sh
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

print_header "Lab 20: Enforce TLS 1.3"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_warning "TLS 1.3 only mode"
echo "  Maximum security but may break compatibility"
echo "  Not all clients support TLS 1.3"
echo

read -p "Enforce TLS 1.3 minimum? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 0
fi

echo

# Check OpenSSL version (needs 1.1.1+)
OPENSSL_VERSION="$(openssl version | awk '{print $2}')"
echo "OpenSSL version: ${OPENSSL_VERSION}"

if ! openssl version | grep -qE "1\.1\.1|3\."; then
  print_error "TLS 1.3 requires OpenSSL 1.1.1+"
  echo "Current OpenSSL doesn't support TLS 1.3"
  exit 1
fi

print_success "OpenSSL supports TLS 1.3"
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Configuring Apache for TLS 1.3..."

  cat > /etc/httpd/conf.d/tls13-only.conf << 'EOF'
# Lab 20: TLS 1.3 Only
SSLProtocol -all +TLSv1.3
EOF

  if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
    print_success "Apache configured"
    systemctl reload httpd 2>/dev/null || true
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "Configuring NGINX for TLS 1.3..."

  cat > /etc/nginx/conf.d/tls13-only.conf << 'EOF'
# Lab 20: TLS 1.3 Only
ssl_protocols TLSv1.3;
EOF

  if nginx -t 2>&1 | grep -q "successful"; then
    print_success "NGINX configured"
    systemctl reload nginx 2>/dev/null || true
  fi
fi

echo
print_success "TLS 1.3 enforcement configured"
echo
print_warning "Warning: This breaks TLS 1.2-only clients"
echo
echo "To revert to TLS 1.2+:"
echo "  Remove /etc/httpd/conf.d/tls13-only.conf"
echo "  Remove /etc/nginx/conf.d/tls13-only.conf"
echo "  Restart services"

#!/usr/bin/env bash
#=============================================================================
# Lab 20: Enable Hsts
# Configure HTTP Strict Transport Security
#
# Usage: ./enable-hsts.sh
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

print_header "Lab 20: Enable HSTS"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

echo "HSTS forces browsers to use HTTPS only"
echo "Duration: 2 years (63072000 seconds)"
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Configuring HSTS for Apache..."

  cat > /etc/httpd/conf.d/hsts.conf << 'EOF'
# Lab 20: HTTP Strict Transport Security
<IfModule mod_headers.c>
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
</IfModule>
EOF

  if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
    print_success "Apache HSTS configured"
    systemctl reload httpd 2>/dev/null || true
  fi
fi

# NGINX
if [[ -d /etc/nginx/conf.d ]]; then
  print_info "Configuring HSTS for NGINX..."

  cat > /etc/nginx/conf.d/hsts.conf << 'EOF'
# Lab 20: HTTP Strict Transport Security
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
EOF

  if nginx -t 2>&1 | grep -q "successful"; then
    print_success "NGINX HSTS configured"
    systemctl reload nginx 2>/dev/null || true
  fi
fi

echo
print_success "HSTS enabled"
echo
echo "Test with:"
echo "  curl -I https://localhost/ | grep Strict-Transport-Security"

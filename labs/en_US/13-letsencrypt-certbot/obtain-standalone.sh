#!/usr/bin/env bash
#=============================================================================
# Lab 13: Obtain Standalone
# Obtain Let's Encrypt certificate in standalone mode
#
# Usage: ./obtain-standalone.sh
# Prerequisites: RHEL 8, 9, 10, root privileges
#=============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Pipeline returns first non-zero exit code

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

print_header "Lab 13: Obtain Certificate (Standalone)"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_warning "IMPORTANT: This lab uses standalone mode"
print_warning "  - Requires port 80 to be free"
print_warning "  - Will use test domain (not real Let's Encrypt)"
print_warning "  - For production, use a real domain name"
echo

# Domain name for testing (user should replace with their own)
DOMAIN="example.com"

echo "Domain to use: ${DOMAIN}"
echo
print_warning "For this lab, we'll use --staging and --register-unsafely-without-email"
print_warning "In production, use real domain and --email address"
echo

read -p "Continue with standalone test? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 0
fi

echo

# Stop any web servers using port 80
print_info "Checking for services on port 80..."
SERVICES="httpd nginx apache2"
STOPPED_SERVICES=""

for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "Stopping ${service}..."
    systemctl stop ${service}
    STOPPED_SERVICES="${STOPPED_SERVICES} ${service}"
  fi
done

if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_success "Stopped services: ${STOPPED_SERVICES}"
fi

echo

# Obtain certificate using standalone mode
print_info "Obtaining certificate using standalone mode..."
echo

# Use staging environment and agree to TOS
if certbot certonly \
  --standalone \
  --staging \
  --agree-tos \
  --register-unsafely-without-email \
  --domain "${DOMAIN}" \
  --non-interactive 2>&1 | tee /tmp/certbot-standalone.log; then
  echo
  print_success "Certificate obtained (staging)"
else
  echo
  print_warning "Certificate request failed (expected if no real domain)"
  echo "This is normal in a lab environment without a public domain"
  echo
  echo "For production use:"
  echo "  certbot certonly --standalone -d your-domain.com --email your@email.com"
fi

echo

# Restart stopped services
if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_info "Restarting stopped services..."
  for service in ${STOPPED_SERVICES}; do
    echo "Starting ${service}..."
    systemctl start ${service}
  done
fi

echo
print_success "Standalone mode demonstration complete"
echo
echo "Certificate locations (if successful):"
echo "  /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo
echo "List certificates:"
echo "  certbot certificates"
echo
echo "Production example:"
echo "  certbot certonly --standalone -d example.com --email admin@example.com"

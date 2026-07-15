#!/usr/bin/env bash
#=============================================================================
# Lab 13: Verify
# Verification steps
#
# Usage: ./verify.sh
# Prerequisites: RHEL 8, 9, 10
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

print_header "Lab 13: Certbot Verification"

print_info "1. Certbot version:"
certbot --version

echo

print_info "2. Existing certificates:"
if certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
  certbot certificates
else
  print_warning "No certificates found"
fi

echo

print_info "3. Certificate files:"
if [[ -d /etc/letsencrypt/live ]]; then
  echo "Certificate directories:"
  ls -1d /etc/letsencrypt/live/*/ 2>/dev/null | while read dir; do
    echo " ${dir}"
    ls -l "${dir}" 2>/dev/null | grep -E "\.pem$" | sed 's/^/    /'
  done
else
  echo "No certificate directories"
fi

echo

print_info "4. Renewal configuration:"
if [[ -d /etc/letsencrypt/renewal ]]; then
  echo "Renewal configs:"
  if ! ls -1 /etc/letsencrypt/renewal/*.conf 2>/dev/null | sed 's/^/  /'; then
    echo "  None"
  fi
else
  echo "No renewal configs"
fi

echo

print_info "5. Automatic renewal:"

if [[ ${RHEL_VERSION} -ge 8 ]]; then
  if systemctl is-active certbot-renew.timer &>/dev/null; then
    print_success "Systemd timer active"
    systemctl list-timers certbot-renew.timer --no-pager 2>/dev/null || true
  else
    echo "Timer not active"
  fi
else
  if crontab -l 2>/dev/null | grep -q "certbot renew"; then
    print_success "Cron job configured"
    crontab -l 2>/dev/null | grep "certbot renew"
  else
    echo "No cron job found"
  fi
fi

echo

print_info "6. Log files:"
if [[ -d /var/log/letsencrypt ]]; then
  echo "Recent log files:"
  if ! ls -lt /var/log/letsencrypt/*.log 2>/dev/null | head -3 | sed 's/^/  /'; then
    echo "  No logs"
  fi
else
  echo "Log directory not found"
fi

echo
print_success "Verification complete"

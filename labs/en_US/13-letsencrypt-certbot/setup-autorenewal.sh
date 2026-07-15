#!/usr/bin/env bash
#=============================================================================
# Lab 13: Setup Autorenewal
# Configure automatic certificate renewal
#
# Usage: ./setup-autorenewal.sh
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

print_header "Lab 13: Setup Automatic Renewal"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Detect RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

print_info "Checking systemd timer for certbot..."

if systemctl list-unit-files | grep -q "certbot-renew.timer"; then
  print_success "Certbot timer already exists"

  # Enable if not enabled
  if ! systemctl is-enabled certbot-renew.timer &>/dev/null; then
    systemctl enable certbot-renew.timer
    print_success "Timer enabled"
  fi

  # Start if not started
  if ! systemctl is-active certbot-renew.timer &>/dev/null; then
    systemctl start certbot-renew.timer
    print_success "Timer started"
  fi

  echo
  echo "Timer status:"
  systemctl status certbot-renew.timer --no-pager | head -10

  echo
  echo "Next run:"
  systemctl list-timers certbot-renew.timer --no-pager
else
  print_warning "Certbot timer not found"
  echo "Creating custom timer..."

  # Create timer unit
  cat > /etc/systemd/system/certbot-renew.timer << 'EOF'
[Unit]
Description=Certbot Renewal Timer

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # Create service unit
  cat > /etc/systemd/system/certbot-renew.service << 'EOF'
[Unit]
Description=Certbot Renewal

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet
EOF

  systemctl daemon-reload
  systemctl enable certbot-renew.timer
  systemctl start certbot-renew.timer

  print_success "Custom timer created and started"
fi

echo
print_success "Automatic renewal configured"
echo
echo "Renewal details:"
echo "  - Checks twice daily"
echo "  - Renews when <30 days remain"
echo "  - Logs to /var/log/letsencrypt/"
echo
echo "Monitor renewals:"
echo "  systemctl status certbot-renew.service"
echo "  journalctl -u certbot-renew"

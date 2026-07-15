#!/usr/bin/env bash
#=============================================================================
# Lab 10: Install PostgreSQL
# Install PostgreSQL database server
#
# Usage: ./install-postgresql.sh
# Prerequisites: RHEL 7, 8, 9, 10, root privileges
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

print_header "Lab 10: Installing PostgreSQL"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Detect RHEL version
echo "RHEL Version: ${RHEL_VERSION}"
echo

# Install PostgreSQL
print_info "Installing PostgreSQL packages..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y postgresql-server postgresql-contrib
else
  dnf install -y postgresql-server postgresql-contrib
fi

print_success "PostgreSQL installed"
echo

# Initialize database (if not already initialized)
if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
  print_info "Initializing PostgreSQL database..."
  if [[ ${RHEL_VERSION} -eq 7 ]]; then
    postgresql-setup initdb
  else
    postgresql-setup --initdb
  fi
  print_success "Database initialized"
else
  echo "Database already initialized"
fi

echo

# Enable and start PostgreSQL
print_info "Enabling and starting postgresql service..."
systemctl enable postgresql
systemctl start postgresql

print_success "PostgreSQL service started"
echo

# Configure firewall
print_info "Configuring firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=postgresql
  firewall-cmd --reload
  print_success "Firewall configured (port 5432)"
else
  echo "firewalld not running, skipping firewall configuration"
fi

echo

# Verify installation
if systemctl is-active postgresql &>/dev/null; then
  print_success "PostgreSQL is running"
else
  print_error "PostgreSQL failed to start"
  exit 1
fi

# Check if listening
if ss -tlnp | grep -q ':5432'; then
  print_success "PostgreSQL listening on port 5432"
fi

# Display PostgreSQL version
echo
echo "PostgreSQL version:"
sudo -u postgres psql --version

echo
print_success "PostgreSQL installation complete"
echo
echo "PostgreSQL status:"
systemctl status postgresql --no-pager | head -5
